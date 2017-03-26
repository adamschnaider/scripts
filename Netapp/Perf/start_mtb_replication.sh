#!/bin/bash

MTB='ssh admin@mtbfsprd'
date=`date +"%Y.%m.%d_%T"`
scriptname=`echo $0`
logfile=/tmp/${scriptname}_${date}.txt

$MTB snapmirror show > "$logfile"
echo "" >> "$logfile"
echo "" >> "$logfile"
$MTB snapmirror resume -destination-path mtbfs*
sleep 5
$MTB snapmirror update -destination-path mtbfs*
sleep 5
$MTB snapmirror show >> "$logfile" 
