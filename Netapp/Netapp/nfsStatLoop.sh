#!/bin/bash


filer=$1
interval=$2
#seconds=$3

script="${0##*/}"
date=`date +"%Y%m%d_%H%M%S"`
LOGPATH=/home/nirb/scripts/output
LOGFILE="$LOGPATH"/"$script"_"$filer"_"$date".out

while [ 1 ]
do
	/home/nirb/scripts/bin/Netapp/NetApp.nfsstat.ontap8.cli.sh $filer $interval >> $LOGFILE
done
