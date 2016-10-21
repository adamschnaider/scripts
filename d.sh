#!/bin/bash

args=( $@ )

#for i in {0..3};do
#echo ${args[$i]}
#done

echo ${0}
echo ${0##*/}
echo ${0%.*}
