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
	Useage: $0 <7mode filer> <volume> <size> <aggr>
EOF
exit 1
}

[[ $# -ne 4 ]] && echo "Invalid argument count" && usage

filer=$1
volume=$2
size=$3
aggr=$4
max_autosize=$(echo "${size} * 1.25" | bc -l |awk -F'.' '{print $1}')
[[ $size -gt 20 ]] && autoIncr="20G" || autoIncr="1G"

# Volume creation
echo -e "Creating volume:"
ssh root@${filer} vol create $volume $aggr ${size}G
ssh root@${filer} vol options $volume fractional_reserve 0
ssh root@${filer} snap autodelete $volume state on commitment disrupt target_free_space 5
ssh root@${filer} vol autosize $volume on
ssh root@${filer} vol autosize $volume -m ${max_autosize}G -i $autoIncr

echo -e "Creating LUN:"
ssh root@${filer} lun create -s ${size}g -t vmware -o noreserve /vol/${volume}/${volume}.lun

echo -e "Adding volume to SIS:"
ssh root@${filer} sis on /vol/${volume}
ssh root@${filer} sis config -s sun-sat@0 /vol/${volume}
ssh root@${filer} sis start -s /vol/${volume}

echo "DONE"
