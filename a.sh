#!/bin/bash
. /root/b.sh
size=$1
max_size=3000
#max_size=$((${1}*(1.25)))
#max_size=$(echo "${size} * 1.25" | bc -l |awk -F'.' '{print $1}')
size_double $1
echo $size
echo "Before: $size"
echo "After: $max_size"
size_triple
