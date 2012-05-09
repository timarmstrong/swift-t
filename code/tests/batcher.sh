#!/bin/bash

set -x

THIS=$0
SCRIPT=${THIS%.sh}.tcl
OUTPUT=${THIS%.sh}.out

mkdir tests/data

source scripts/turbine-config.sh
${TURBINE_LAUNCH} -l -n 4 ${VALGRIND} ${TCLSH} ${SCRIPT} \
                  tests/batcher.txt >& ${OUTPUT}
[[ ${?} == 0 ]] || exit 1

LINES=$( ls tests/data/{1..4}.txt | wc -l )
(( ${LINES} == 4 )) || exit 1

rm tests/data/{1..4}.txt || exit 1

exit 0
