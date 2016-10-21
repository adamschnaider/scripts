#!/bin/bash

size_double() {
sizee=$1
local max_size=$(echo "${sizee} * 1.25" | bc -l |awk -F'.' '{print $1}')
sizee=$max_size
echo "B: $sizee"
}

size_triple() {
let sizee=$sizee+300
echo "C: $sizee"
}
