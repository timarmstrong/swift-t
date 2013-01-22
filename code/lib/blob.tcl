# Turbine builtin functions for blob manipulation

namespace eval turbine {

  proc blob_size_async { stack out blob } {
    rule "blob_size-$out-$blob" "$blob" \
        $turbine::LOCAL $adlb::RANK_ANY "blob_size_body $out $blob"
  }

  proc blob_size_body { out blob } {
    set blob_val [ retrieve_decr_blob $blob ]
    set sz [ blob_size $blob_val ]
    store_integer $out $sz
    adlb::blob_free $blob
  }

  proc blob_size { blob_val } {
    return [ lindex $blob_val 1 ]
  }

  proc blob_null { stack result input } {
      store_blob $result 0 0
  }

  proc blob_from_string { stack result input } {
    rule "bfs-$input-$result" $input $turbine::LOCAL $adlb::RANK_ANY \
      "blob_from_string_body $input $result"
  }
  proc blob_from_string_body { input result } {
    set t [ retrieve_decr $input ]
    store_blob_string $result $t
  }

  proc string_from_blob { stack result input } {
    rule "sfb-$input-$result" $input $turbine::LOCAL $adlb::RANK_ANY \
      "string_from_blob_body $input $result"
  }
  proc string_from_blob_body { input result } {
    set s [ retrieve_decr_blob_string $input ]
    store_string $result $s
  }

  proc floats_from_blob { stack result input } {
      rule "floats_from_blob-$result" $input $turbine::LOCAL $adlb::RANK_ANY \
          "floats_from_blob_body $result $input"
  }
  proc floats_from_blob_body { result input } {
      log "floats_from_blob_body: result=<$result> input=<$input>"
      set s      [ SwiftBlob_sizeof_float ]
      set L      [ adlb::retrieve_blob $input ]
      set p      [ SwiftBlob_cast_int_to_dbl_ptr [ lindex $L 0 ] ]
      set length [ lindex $L 1 ]

      set n [ expr $length / $s ]
      for { set i 0 } { $i < $n } { incr i } {
          set d [ SwiftBlob_double_get $p $i ]
          literal t float $d
          container_immediate_insert $result $i $t
      }
      adlb::refcount_incr $result $adlb::WRITE_REFCOUNT -1
      adlb::blob_free $input
      log "floats_from_blob_body: done"
  }

  # Container must be indexed from 0,N-1
  proc blob_from_floats { stack result input } {
    rule "blob_from_floats-$result" $input $turbine::LOCAL $adlb::RANK_ANY \
      "blob_from_floats_body $input $result"
  }
  proc blob_from_floats_body { container result } {

      set type [ container_typeof $container ]
      set N  [ adlb::container_size $container ]
      c::log "blob_from_floats_body start"
      complete_container $container \
          "blob_from_floats_store $result $container $N"
  }
  # This is called when every entry in container is set
  proc blob_from_floats_store { result container N } {
    set A [ list ]
    for { set i 0 } { $i < $N } { incr i } {
      set td [ container_lookup $container $i ]
      set v  [ retrieve_decr_float $td ]
      lappend A $v
    }
    set waiters [ adlb::store_blob_floats $result $A ]
    turbine::notify_waiters $result $waiters
  }

  # Assumes A is closed
  proc complete_container { A action } {
      set n [ adlb::container_size $A ]
      log "complete_container: <$A> size: $n"
      complete_container_continue $A $action 0 $n
  }
  proc complete_container_continue { A action i n } {
      log "complete_container_continue: <$A> $i/$n"
      if { $i < $n } {
          set x [ container_lookup $A $i ]
          if { $x == 0 } {
              error "complete_container: <$A>\[$i\]=<0>"
          }
          rule "complete_container_continue-$A" [ list $x ] \
              $turbine::LOCAL $adlb::RANK_ANY \
              "complete_container_continue_body $A {$action} $i $n"
      } else {
          eval $action
      }
  }
  proc complete_container_continue_body { A action i n } {
      complete_container_continue $A $action [ incr i ] $n
  }
}
