
// Checks that basic task failure is handled properly

// THIS-TEST-SHOULD-NOT-RUN

import io;

() f() "turbine" "0.0" [ "error \"MY USER ERROR MESSAGE\"" ];

main
{
  f();
}
