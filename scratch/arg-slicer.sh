#!/bin/bash

ARRAY=( "$@" )

for arg in "${ARRAY[@]}"; do
  echo "$arg"
done