#!/bin/bash

filer=labfs01
script="${0##*/}"
date=`date +"%Y%m%d_%H%M%S"`
LOGPATH=/home/nirb/scripts/output
LOGFILE="$LOGPATH"/"$script"_"$filer"_"$date".out

while [ 1 ]
do
	/home/nirb/scripts/bin/Netapp/NetApp.nfsstat.ontap8.cli.sh labfs01 10 >> $LOGFILE
done
