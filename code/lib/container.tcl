
# Turbine builtin container operations

# Rule debug token conventions:
#  1) Use shorthand notation from Turbine Internals Guide
#  2) Preferably, just specify output TDs.  Input TDs are reported by
#     the WAITING TRANSFORMS list and the rule debugging lines

namespace eval turbine {
    namespace export container_f_get container_f_insert
    namespace export f_reference
    namespace export f_container_create_nested

    # Just like adlb::container_reference but add logging
    proc container_reference { c i r type } {
        log "creating reference: <$c>\[$i\] <- <*$r> ($type)"
        adlb::container_reference $c $i $r $type
        # TODO: need to move refcount from container to referenced item
        # once reference set
    }

    # Same as container_lookup, but fail if item does not exist
    proc container_lookup_checked { c i } {
        set res [ container_lookup $c $i ]
        if { $res == 0 } {
            error "lookup failed: container_lookup <$c>\[$i\]"
        }
        return $res
    }

    # When i is closed, set d := c[i] (by value copy)
    # d: the destination, an integer
    # inputs: [ list c i ]
    # c: the container
    # i: the subscript (any type)
    proc container_f_get_integer { parent d inputs } {
        set c [ lindex $inputs 0 ]
        set i [ lindex $inputs 1 ]

        rule "container_f_get-$c-$i" $i $turbine::LOCAL $adlb::RANK_ANY \
            "turbine::container_f_get_integer_body $d $c $i"
    }

    proc container_f_get_integer_body { d c i } {
        set s [ retrieve $i ]
        set t [ container_lookup $c $s ]
        if { $t == 0 } {
            error "lookup failed: container_f_get <$c>\[$s\]"
        }
        set value [ retrieve_integer $t ]
        store_integer $d $value
    }

    # When i is closed, set c[i] := d (by insertion)
    # inputs: [ list c i d ]
    # c: the container
    # i: the subscript (any type)
    # d: the data
    # outputs: ignored.  To block on this, use turbine::reference
    proc container_f_insert { parent outputs inputs } {
        set c [ lindex $inputs 0 ]
        set i [ lindex $inputs 1 ]
        set d [ lindex $inputs 2 ]
        nonempty c i d
        adlb::slot_create $c

        rule "container_f_insert-$c-$i" $i $turbine::LOCAL $adlb::RANK_ANY \
            [ list turbine::container_f_insert_body $c $i $d ]
    }

    proc container_f_insert_body { c i d } {
        set s [ retrieve $i ]
        container_insert $c $s $d 1
    }

    # When i and r are closed, set c[i] := *(r)
    # inputs: [ list c i r ]
    # r: a reference to a turbine ID
    proc container_f_deref_insert { parent outputs inputs } {
        set c [ lindex $inputs 0 ]
        set i [ lindex $inputs 1 ]
        set r [ lindex $inputs 2 ]

        nonempty c i r
        adlb::slot_create $c

        rule "container_f_deref_insert-$c-$i" "$i $r" $turbine::LOCAL $adlb::RANK_ANY \
            "turbine::container_f_deref_insert_body $c $i $r"
    }

    proc container_f_deref_insert_body { c i r } {
        set t1 [ retrieve_integer $i ]
        set d [ retrieve $r ]
        container_insert $c $t1 $d
    }

    # When r is closed, set c[i] := *(r)
    # inputs: [ list c i r ]
    # i: an integer which is the index to insert into
    # r: a reference to a turbine ID
    proc container_deref_insert { parent outputs inputs } {
        set c [ lindex $inputs 0 ]
        set i [ lindex $inputs 1 ]
        set r [ lindex $inputs 2 ]

        nonempty c i r
        adlb::slot_create $c

        rule "container_deref_insert-$c-$i" "$r" $turbine::LOCAL $adlb::RANK_ANY \
            "turbine::container_deref_insert_body $c $i $r"
    }

    proc container_deref_insert_body { c i r } {
        set d [ retrieve $r ]
        container_insert $c $i $d
    }

    # Immediately insert data into container without affecting open slot count
    # c: the container
    # i: the subscript
    # d: the data
    # outputs: ignored.
    proc container_immediate_insert { c i d } {
        # adlb::slot_create $c
        container_insert $c $i $d 0
    }

    # When i is closed, get a reference on c[i] in TD r
    # Thus, you can block on r and be notified when c[i] exists
    # r is an integer.  The value of r is the TD of c[i]
    # inputs: [ list c i r adlb_type ]
    # outputs: None.  You can block on d with turbine::dereference
    # c: the container
    # i: the subscript (any type)
    # r: the reference TD
    # ref_type: internal representation type for reference
    proc f_reference { parent outputs inputs } {
        set c [ lindex $inputs 0 ]
        set i [ lindex $inputs 1 ]
        set r [ lindex $inputs 2 ]
        debug "f_reference: <$c>\[<$i>\] <- <*$r>"
        set ref_type [ lindex $inputs 3 ]
        # nonempty c i r

        rule "f_reference_body-$c-$i" $i $turbine::LOCAL $adlb::RANK_ANY \
            "turbine::f_reference_body $c $i $r $ref_type"
    }
    proc f_reference_body { c i r ref_type } {
        debug "f_reference_body: <$c>\[<$i>\] <- <*$r>"
        set t1 [ retrieve $i ]
        debug "f_reference_body: <$c>\[$t1\] <- <$r>"
        container_reference $c $t1 $r $ref_type
    }

    # When reference r is closed, copy its (integer) value in v
    proc f_dereference_integer { parent v r } {

        rule "f_dereference-$v-$r" $r $turbine::LOCAL $adlb::RANK_ANY \
            "turbine::f_dereference_integer_body $v $r"
    }
    proc f_dereference_integer_body { v r } {
        # Get the TD from the reference
        set id [ retrieve_integer $r ]
        # When the TD has a value, copy the value
        read_refcount_incr $id
        copy_integer no_stack $v $id
    }

    # When reference r is closed, copy its (float) value into v
    proc f_dereference_float { parent v r } {
        rule "f_dereference-$v-$r" $r $turbine::LOCAL $adlb::RANK_ANY \
            "turbine::f_dereference_float_body $v $r"
    }

    proc f_dereference_float_body { v r } {
        # Get the TD from the reference
        set id [ retrieve_integer $r ]
        # When the TD has a value, copy the value
        read_refcount_incr $id
        copy_float no_stack $v $id
    }

    # When reference r is closed, copy its (string) value into v
    proc f_dereference_string { parent v r } {

        rule "f_dereference-$v-$r" $r $turbine::LOCAL $adlb::RANK_ANY \
            "turbine::f_dereference_string_body $v $r"
    }
    proc f_dereference_string_body { v r } {
        # Get the TD from the reference
        set id [ retrieve_integer $r ]
        # When the TD has a value, copy the value
        read_refcount_incr $id
        copy_string no_stack $v $id
    }

    # When reference r is closed, copy file to v
    proc f_dereference_file { parent v r } {

        rule "f_dereference-$v-$r" $r $turbine::LOCAL $adlb::RANK_ANY \
            [ list turbine::f_dereference_file_body $v $r ]
    }
    proc f_dereference_file_body { v r } {
        # Get the TD from the reference
        set handle [ retrieve_string $r ]
        # When the TD has a value, copy the value
        file_read_refcount_incr $handle
        copy_file no_stack [ list $v ] [ list $handle ]
    }

    # When reference r is closed, copy blob to v
    proc f_dereference_blob { parent v r } {
        rule "f_dereference-$v-$r" $r $turbine::LOCAL $adlb::RANK_ANY \
            [ list turbine::f_dereference_blob_body $v $r ]
    }
    proc f_dereference_blob_body { v r } {
        # Get the TD from the reference
        set handle [ retrieve_integer $r ]
        # When the TD has a value, copy the value
        read_refcount_incr $handle
        copy_blob no_stack [ list $v ] [ list $handle ]
    }

    # When reference cr is closed, store d = (*cr)[i]
    # Blocks on cr
    # inputs: [ list cr i d d_type]
    #       cr is a reference to a container
    #       i is a literal int
    #       d is the destination ref
    #       d_type is the turbine type name for representation of d
    # outputs: ignored
    proc f_cref_lookup_literal { parent outputs inputs } {
        set cr [ lindex $inputs 0 ]
        set i [ lindex $inputs 1 ]
        set d [ lindex $inputs 2 ]
        set d_type [ lindex $inputs 3 ]

        log "creating reference: <*$cr>\[$i\] <- <*$d>"

        rule "f_cref_lookup_literal-$cr" "$cr" $turbine::LOCAL $adlb::RANK_ANY \
            "turbine::f_cref_lookup_literal_body $cr $i $d $d_type"

    }

    proc f_cref_lookup_literal_body { cr i d d_type } {
        # When this procedure is run, cr should be set and
        # i should be the literal index
        set c [ retrieve_integer $cr ]
        container_reference $c $i $d $d_type
    }

    # When reference cr is closed, store d = (*cr)[i]
    # Blocks on cr and i
    # inputs: [ list cr i d ]
    #       cr: reference to container
    #       i:  subscript (any type)
    #       d is the destination ref
    #       d_type is the turbine type name for representation of d
    # outputs: ignored
    proc f_cref_lookup { parent outputs inputs } {
        set cr [ lindex $inputs 0 ]
        set i [ lindex $inputs 1 ]
        set d [ lindex $inputs 2 ]
        set d_type [ lindex $inputs 3 ]

        rule "f_cref_lookup-$cr" "$cr $i" $turbine::LOCAL $adlb::RANK_ANY \
            "turbine::f_cref_lookup_body $cr $i $d $d_type"
    }

    proc f_cref_lookup_body { cr i d d_type } {
        # When this procedure is run, cr and i should be set
        set c [ retrieve_integer $cr ]
        set t1 [ retrieve $i ]
        container_reference $c $t1 $d $d_type
    }

    # When reference r on c[i] is closed, store c[i][j] = d
    # Blocks on r and j
    # oc is outer container
    # inputs: [ list r j d oc ]
    # outputs: ignored
    proc f_cref_insert { parent outputs inputs } {
        set r [ lindex $inputs 0 ]
        # set c [ lindex $inputs 1 ]
        set j [ lindex $inputs 1 ]
        set d [ lindex $inputs 2 ]
        set oc [ lindex $inputs 3 ]
        adlb::slot_create $oc

        log "insert (future): <*$r>\[<$j>\]=<$d>"

        rule "f_cref_insert-$r-$j-$d-$oc" "$r $j" $turbine::LOCAL $adlb::RANK_ANY \
            [ list turbine::f_cref_insert_body $r $j $d $oc ]
    }
    proc f_cref_insert_body { r j d oc } {
        # s: The subscripted container
        set c [ retrieve_integer $r ]
        set s [ retrieve_integer $j ]
        container_insert $c $s $d
        log "insert: (now) <$c>\[$s\]=<$d>"
        adlb::slot_drop $oc
    }

    # When reference cr on c[i] is closed, store c[i][j] = d
    # Blocks on cr, j must be a tcl integer
    # oc is a direct handle to the top-level container
    #       which cr will be inside
    # inputs: [ list r j d oc ]
    # outputs: ignored
    proc cref_insert { parent outputs inputs } {
        set cr [ lindex $inputs 0 ]
        set j [ lindex $inputs 1 ]
        set d [ lindex $inputs 2 ]
        set oc [ lindex $inputs 3 ]
        adlb::slot_create $oc

        rule "cref_insert-$cr-$j-$d-$oc" "$cr" $turbine::LOCAL $adlb::RANK_ANY \
            [ list turbine::cref_insert_body $cr $j $d $oc ]
    }
    proc cref_insert_body { cr j d oc } {
        set c [ retrieve_integer $cr ]
        # insert and drop slot
        container_insert $c $j $d
        adlb::slot_drop $oc
    }

    # j: tcl integer index
    # oc: direct handle to outer container
    proc cref_deref_insert { parent outputs inputs } {
        set cr [ lindex $inputs 0 ]
        set j [ lindex $inputs 1 ]
        set dr [ lindex $inputs 2 ]
        set oc [ lindex $inputs 3 ]
        adlb::slot_create $oc

        rule "cref_deref_insert-$cr-$j-$dr-$oc" "$cr $dr" $turbine::LOCAL $adlb::RANK_ANY \
            "turbine::cref_deref_insert_body $cr $j $dr $oc"
    }
    proc cref_deref_insert_body { cr j dr oc } {
        set c [ retrieve_integer $cr ]
        set d [ retrieve $dr ]
        container_insert $c $j $d
        adlb::slot_drop $oc
    }

    proc cref_f_deref_insert { parent outputs inputs } {
        set cr [ lindex $inputs 0 ]
        set j [ lindex $inputs 1 ]
        set dr [ lindex $inputs 2 ]
        set oc [ lindex $inputs 3 ]
        adlb::slot_create $oc

        rule "cref_f_deref_insert-$cr-$j-$dr-$oc" "$cr $j $dr" $turbine::LOCAL $adlb::RANK_ANY \
            "turbine::cref_f_deref_insert_body $cr $j $dr $oc"
    }
    proc cref_f_deref_insert_body { cr j dr oc } {
        set c [ retrieve_integer $cr ]
        set d [ retrieve $dr ]
        set jval [ retrieve_integer $j ]
        container_insert $c $jval $d
        adlb::slot_drop $oc
    }


    # Insert c[i][j] = d
    proc f_container_nested_insert { c i j d } {

        rule "fcni" "$i $j" $turbine::LOCAL $adlb::RANK_ANY \
            [ list f_container_nested_insert_body_1 $c $i $j $d ]
    }

    proc f_container_nested_insert_body_1 { c i j d } {

        if [ container_insert_atomic $c $i ] {
            # c[i] does not exist
            set t [ data_new ]
            allocate_container t integer 0
            container_insert $c $i $t
        } else {
            allocate r integer 0
            container_reference $r $c $i "integer"

            rule fcnib "$r" $turbine::LOCAL $adlb::RANK_ANY \
                "container_nested_insert_body_2 $r $j $d"
        }
    }

    proc f_container_nested_insert_body_2 { r j d } {
        container_insert $r $j $d
    }

    # Create container c[i] inside of container c
    # c[i] may already exist, if so, that's fine
    proc container_create_nested { c i type } {
      log "creating nested container: <$c>\[$i\] ($type)"
      if [ adlb::insert_atomic $c $i ] {
        debug "$c\[$i\] doesn't exist, creating"
        # Member did not exist: create it and get reference
        allocate_container t $type
        adlb::insert $c $i $t
        # setup rule to close when outer container closes

        rule "autoclose-$t" "$c" $turbine::LOCAL $adlb::RANK_ANY \
               "adlb::slot_drop $t"
        return $t
      } else {
        # Another engine is creating it right this second, poll
        # until we get it.  Note: this should require at most one
        # or two polls to get a result
        debug "<$c>\[$i\] already exists, retrieving"
        set container_id 0
        while { $container_id == 0 } {
          set container_id [ adlb::lookup $c $i ]
        }
        return $container_id
      }
    }

    # puts a reference to a nested container at c[i]
    # into reference variable r.
    # i: an integer future
    proc f_container_create_nested { r c i type } {

        upvar 1 $r v

        # Create reference
        allocate tmp_r integer 0
        set v $tmp_r


        rule fccn "$i" $turbine::LOCAL $adlb::RANK_ANY \
               "f_container_create_nested_body $tmp_r $c $i $type"
    }

    # Create container at c[i]
    # Set r, a reference TD on c[i]
    proc f_container_create_nested_body { r c i type } {

        debug "f_container_create_nested: $r $c\[$i\] $type"

        set s [ retrieve $i ]
        set res [ container_create_nested $c $s $type ]
        store_integer $r $res
    }

    # Create container at c[i]
    # Set r, a reference TD on (cr*)[i]
    proc cref_create_nested { r cr i type } {
        upvar 1 $r v

        # Create reference
        allocate tmp_r integer 0
        set v $tmp_r


        rule fcrcn "$cr" $turbine::LOCAL $adlb::RANK_ANY \
           "cref_create_nested_body $tmp_r $cr $i $type"
    }

    proc cref_create_nested_body { r cr i type } {
        set c [ retrieve_integer $cr ]
        set res [ container_create_nested $c $i $type ]
        store_integer $r $res
    }

    # Create container at c[i]
    # Set r, a reference TD on (cr*)[i]
    proc f_cref_create_nested { r cr i type } {
        upvar 1 $r v

        # Create reference
        allocate tmp_r integer 0
        set v $tmp_r

        rule fcrcn "$cr $i" $turbine::LOCAL $adlb::RANK_ANY \
           "f_cref_create_nested_body $tmp_r $cr $i $type"
    }

    proc f_cref_create_nested_body { r cr i type } {
        set c [ retrieve_integer $cr ]
        set s [ retrieve $i ]
        set res [ container_create_nested $c $s $type ]
        store_integer $r $res
    }

    # When container is closed, concatenate its keys in result
    # container: The container to read
    # result: A string
    proc enumerate { stack result container } {

        rule "enumerate-$container" $container $turbine::LOCAL $adlb::RANK_ANY \
            "enumerate_body $result $container"
    }

    proc enumerate_body { result container } {
        set s [ container_list $container ]
        store_string $result $s
    }

    # When container is closed, count the members
    # result: a turbine integer
    proc container_size { stack result container } {

        rule "container_size-$container" $container $turbine::LOCAL $adlb::RANK_ANY \
            "container_size_body $result $container"
    }

    proc container_size_body { result container } {
        set sz [ adlb::enumerate $container count all 0 ]
        store_integer $result $sz
    }

    # When container c is closed, return whether it contains c[i]
    # result: a turbine integer, 0 if not present, 1 if true
    proc contains { stack result inputs } {
        set c [ lindex $inputs 0 ]
        set i [ lindex $inputs 1 ]
        rule "contains-$c" "$c $i" $turbine::LOCAL $adlb::RANK_ANY \
            "contains_body $result $c $i"
    }

    proc contains_body { result c i } {
        set i_val [ turbine::retrieve_integer $i ]
        set res [ container_lookup $c $i_val ]
        if { $res == 0 } {
            set exists 0
        } else {
            set exists 1
        }
        store_integer $result $exists
    }

    # If a reference to a struct is represented as a Turbine string
    # future containing a serialized TCL dict, then lookup a
    # struct member
    proc struct_ref_lookup { structr field result type } {
        rule "struct_ref_lookup-$structr" "$structr" $turbine::LOCAL $adlb::RANK_ANY \
            "struct_ref_lookup_body $structr $field $result $type"
    }

    proc struct_ref_lookup_body { structr field result type } {
        set struct_val [ retrieve_string $structr ]
        debug "<${result}> <= \{ ${struct_val} \}.${field}"
        set result_val [ dict get $struct_val $field ]
        if { $type == "integer" } {
            store_integer $result $result_val
        } elseif { $type == "string" } {
            store_string $result $result_val
        } else {
            error "Unknown reference representation type $type"
        }
    }

    # Wait, recursively for container contents
    # Supports plain futures and files
    # rule_prefix: prefix for rule names
    # inputs: list of tds to wait on
    # nest_levels: list corresponding to inputs with nesting level
    #             of containers
    # is_file: list of booleans: whether file
    # target: where to send work
    # cmd: command to execute when closed
    proc deeprule { rule_prefix inputs nest_levels is_file action_type action } {
      # signals: list of variables that must be closed to signal deep closing
      # allocated_signals: signal variables that were allocated
      set signals [ list ]
      set allocated_signals [ list ]
      set i 0
      foreach input $inputs {
        set isf [ lindex $is_file $i ]
        set nest_level [ lindex $nest_levels $i ]
        if { $nest_level < 0 } {
          error "nest_level $nest_level must be non-negative"
        }
        if { $nest_level == 0 } {
          # Just need to wait on right thing
          if { $isf } {
            lappend signals [ get_file_status $input ]
          } else {
            lappend signals $input
          }
        } else {
          # Wait for deep close of container
          # Use void variable to signal recursive container closing
          set signal [ allocate void 0 ]
          lappend signals $signal
          lappend allocated_signals $signal # make sure cleaned up later
          container_deep_wait $rule_prefix $input $nest_level $isf $signal
        }
        incr i
      }

      # Once all signals closed, run finalizer
      rule "${rule_prefix}-final" $signals $action_type \
            [ list deeprule_finish $allocated_signals $action ]
    }

    # Check for container contents being closed and once true,
    # set signal
    # Called after container itself is closed
    proc container_deep_wait { rule_prefix container nest_level is_file signal } {
      if { $nest_level == 1 } {
        # First wait for container to be closed
        set rule_name "${rule_prefix}-$container-close"
        rule $rule_name $container $turbine::LOCAL $adlb::RANK_ANY \
            [ list container_deep_wait_continue $rule_name $container 0 -1 \
                                            $nest_level $is_file $signal ]
      } else {
        set rule_name "${rule_prefix}-$container-close"
        rule $rule_name $container $turbine::LOCAL $adlb::RANK_ANY \
            [ list container_rec_deep_wait $rule_name $container \
                                    $nest_level $is_file $signal ]
      }
    }

    proc container_deep_wait_continue { rule_prefix container progress n
                                        nest_level is_file signal } {
      set MAX_CHUNK_SIZE 64
      # TODO: could divide and conquer instead of doing linear search
      if { $n == -1 } {
        set n [ adlb::enumerate $container count all 0 ]
      }
      while { $progress < $n } {
        set chunk_size [ expr min($MAX_CHUNK_SIZE, $n - $progress) ]
        set members [ adlb::enumerate $container members \
                                      $chunk_size $progress ]
        foreach member $members {
          if {$is_file} {
            set td [ get_file_status $member ]
          } else {
            set td $member
          }
          if { [ adlb::exists $td ] } {
            incr progress
          } else {
            # Suspend execution until next item closed
            rule "${rule_prefix}-$signal" $td $turbine::LOCAL $adlb::RANK_ANY \
                [ list container_deep_wait_continue $rule_prefix $container \
                          $progress $n $nest_level $is_file $signal ]
            return
          }
        }
      }
      # Finished
      log "Container <$container> deep closed"
      store_void $signal
    }

    proc container_rec_deep_wait { rule_prefix container nest_level is_file
                                   signal } {
      set inner_signals [ list ]

      set members [ adlb::enumerate $container members all 0 ]
      if { [ llength $members ] == 0 } {
        # short-circuit
        store_void $signal
        return
      } elseif { [ llength $members ] == 1 } {
        # skip allocating new signal
        set inner [ lindex $members 0 ]
        container_deep_wait "$rule_prefix-$inner-close" $inner \
                     [ expr $nest_level - 1 ] $is_file $signal
      } else {
        foreach inner $members {
          set inner_signal [ allocate void 0 ]
          lappend inner_signals $inner_signal
          container_deep_wait $rule_prefix $inner \
                       [ expr $nest_level - 1 ] $is_file $inner_signal
        }
        rule "$rule_prefix-final" $inner_signals $turbine::LOCAL $adlb::RANK_ANY \
          [ list deeprule_finish $inner_signals [ list store_void $signal ] ]
      }
    }

    # Cleanup allocated things for
    # Decrement references for signals
    proc deeprule_finish { allocated_signals cmd } {
      foreach signal $allocated_signals {
        read_refcount_decr $signal
      }
      eval $cmd
    }
}
