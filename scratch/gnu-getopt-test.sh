#!/bin/bash

getopt -o "abc:" -l "eh,bee,see:" -n "foo.sh" -- "$@"
