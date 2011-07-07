
# Generate the turbine TCL package

puts [ ::pkg::create -name turbine -version 0.1 -load libtclturbine.so -load libtcladlb.so -source turbine.tcl -source turbine-engine.tcl -source turbine-engine-adlb.tcl -source helpers.tcl ]
