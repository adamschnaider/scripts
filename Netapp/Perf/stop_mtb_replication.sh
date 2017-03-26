#!/bin/bash

MTB='ssh admin@mtbfsprd'
date=`date +"%Y.%m.%d_%T"`
scriptname=`echo $0`
logfile=/tmp/${scriptname}_${date}.txt

$MTB snapmirror show > $logfile
echo "" >> $logfile
echo "" >> $logfile
$MTB snapmirror abort -destination-path mtbfs*
sleep 5
$MTB snapmirror quiesce -destination-path mtbfs*
sleep 5
$MTB snapmirror show >> $logfile 
