#!/bin/bash

MTB='ssh admin@mtbfsprd'

$MTB snapmirror show > /tmp/mtb_output.txt
echo ""
echo ""
$MTB snapmirror abort -destination-path mtbfsnas_dr:*
sleep 5
$MTB snapmirror quiesce -destination-path mtbfsnas_dr:*
sleep 5
$MTB snapmirror show >>  /tmp/mtb_output.txt
