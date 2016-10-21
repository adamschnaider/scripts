#!/bin/bash
#########################################
#	   LUN Create Automation	#
#               Version 1               #
#       Created by: Adam Schnaider      #
#               Date: Apr 2016          #
#########################################

echo -e "\e[032mAutomatic LUN Creation\e[0m"
arg=( $@ )
DIR=`dirname $0`
ID=$RANDOM
AGGR_THRESHOLD=90                       #Choose aggregate throshold
STTY=$(stty -g)


usage () {
cat <<EOF
	Useage: $0 <Cdot filer> <volume> <vserver> <size in G> <aggr>
EOF
exit 1
}

[[ $# -ne 5 ]] && echo "Invalid argument count" && usage

filer=$1
volume=$2
vserver=$3
size=$4
aggr=$5
max_autosize=$(echo "${size} * 1.25" | bc -l |awk -F'.' '{print $1}')
netapp_version=$(ssh admin@${filer} version | grep NetApp |awk '{print $3}' | sed 's/\..*//g')
[[ $size -gt 20 ]] && autoIncr="20G" || autoIncr="1G"

# Volume creation
echo -e "Creating volume:"
if [ $netapp_version -lt 9 ]; then
	ssh admin@${filer} vol create -vserver $vserver -volume $volume -aggregate $aggr -size ${size}g -percent-snapshot-space 0 -snapshot-policy default-1weekly -autosize true -autosize-increment $autoIncr -max-autosize ${max_autosize}g -state online
else
	ssh admin@${filer} vol create -vserver $vserver -volume $volume -aggregate $aggr -size ${size}g -percent-snapshot-space 0 -snapshot-policy default-1weekly -autosize-mode grow  -max-autosize ${max_autosize}g -state online
fi
ssh admin@${filer} vol modify -vserver $vserver -volume $volume -fractional-reserve 0


echo -e "Creating LUN:"
ssh admin@${filer} lun create -vserver $vserver -path /vol/${volume}/${volume}.lun -size ${size}g -ostype vmware -space-reserve disabled
ssh admin@${filer} snapshot autodelete modify -vserver $vserver -volume $volume -enabled true -commitment destroy -target-free-space 10% -destroy-list lun_clone

if [ $netapp_version -lt 9 ]; then
	echo -e "Adding volume to SIS:"
	ssh admin@${filer} sis on -vserver $vserver -volume $volume
	ssh admin@${filer} sis config -vserver $vserver -volume $volume -policy sis_3AM
	ssh admin@${filer} sis start -scan-all true -scan-old-data true -vserver $vserver -volume $volume
fi

echo "DONE"
