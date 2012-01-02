
# Test distributed range creation functionality

# SwiftScript
# int i = 1;
# int j = 4;
# int c[] = [i:j];
# string s = @sprintf(c)
# trace(s);

package require turbine 0.0.1

proc rules { } {

    set i [ turbine::data_new ]
    turbine::integer_init $i
    set j [ turbine::data_new ]
    turbine::integer_init $j
    set c [ turbine::data_new ]
    turbine::container_init $c integer
    set p [ turbine::data_new ]
    turbine::integer_init $p

    global env
    if { [ info exists env(COUNT) ] } {
        set count $env(COUNT)
    } else {
        set count 100
    }
    puts "count: $count"
    turbine::integer_set $i 1
    turbine::integer_set $j $count
    turbine::integer_set $p $env(TURBINE_ENGINES)

    turbine::drange $c $i $j $p
}

global env
turbine::init $env(TURBINE_ENGINES) $env(ADLB_SERVERS)
turbine::start rules
turbine::finalize
puts OK

