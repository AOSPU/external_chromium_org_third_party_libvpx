#!/bin/bash -e
#
# Copyright (c) 2012 The Chromium Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# This script is used to compare vpx_config.h and vpx_config.asm to
# verify the two files have the same configuration.
#
# Arguments:
#
# h - C Header file.
# a - ASM file.
# p - Print the options if correct.
#
# Usage:
#
# # Compare the two configuration files and output the final results.
# $ ./lint_config.sh -h vpx_config.h -a vpx_config.asm -p
#

print_final="no"

while getopts "h:a:p" flag
do
  if [ "$flag" = "h" ]; then
    header_file=$OPTARG
  elif [ "$flag" = "a" ]; then
    asm_file=$OPTARG
  elif [ "$flag" = "p" ]; then
    print_final="yes"
  fi
done

if [ -z "$header_file" ]; then
  echo "Header file not specified."
  false
  exit
fi

if [ -z "$asm_file" ]; then
  echo "ASM file not specified."
  false
  exit
fi

# Concat header file and assembly file and select those ended with 0 or 1.
combined_config="$(cat $header_file $asm_file | grep -E ' +[01] *$')"

# Extra filtering for known exceptions.
combined_config="$(echo "$combined_config" | grep -v DO1STROUNDING)"

# Remove all spaces.
combined_config="$(echo "$combined_config" | sed 's/[ \t]//g')"

# Remove #define in the header file.
combined_config="$(echo "$combined_config" | sed 's/.*define//')"

# Remove equ in the ASM file.
combined_config="$(echo "$combined_config" | sed 's/\.equ//')" # gas style
combined_config="$(echo "$combined_config" | sed 's/equ//')" # rvds style

# Remove useless comma in gas style assembly file.
combined_config="$(echo "$combined_config" | sed 's/,//')"

# Substitute 0 with =no.
combined_config="$(echo "$combined_config" | sed 's/0$/=no/')"

# Substitute 1 with =yes.
combined_config="$(echo "$combined_config" | sed 's/1$/=yes/')"

# Find the mismatch variables.
odd_config="$(echo "$combined_config" | sort | uniq -u)"
odd_vars="$(echo "$odd_config" | sed 's/=.*//' | uniq)"

for var in $odd_vars; do
  echo "Error: Configuration mismatch for $var."
  echo "Header file: $header_file"
  echo "$(cat -n $header_file | grep "$var[ \t]")"
  echo "Assembly file: $asm_file"
  echo "$(cat -n $asm_file | grep "$var[ \t]")"
  echo ""
done

if [ -n "$odd_vars" ]; then
  false
  exit
fi

if [ "$print_final" = "no" ]; then
  exit
fi

# Do some additional filter to make libvpx happy.
combined_config="$(echo "$combined_config" | grep -v ARCH_X86=no)"
combined_config="$(echo "$combined_config" | grep -v ARCH_X86_64=no)"

# Print out the unique configurations.
echo "$combined_config" | sort | uniq
