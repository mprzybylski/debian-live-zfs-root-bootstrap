#!/bin/bash

getopt -o "abc:" -l "eh,bee,see:" -n "foo.sh" -- "$@"
echo $?

# Sample output:
# ./gnu-getopt-test.sh -abc fooo -defg bar baz plotz
# foo.sh: invalid option -- 'd'
# foo.sh: invalid option -- 'e'
# foo.sh: invalid option -- 'f'
# foo.sh: invalid option -- 'g'
#  -a -b -c 'fooo' -- 'bar' 'baz' 'plotz'
# ...