#!/bin/bash

##########################################
# Create Netapp 7-Mode FlexCache Volumes #
#      Created by: Adam Schnaider        #
#             Date: March 2017           #
##########################################

# SOURCING
. /root/scripts/functions/bashIFS.bash
. /root/scripts/functions/MySQLHandler.bash
. /root/scripts/functions/sizeHandler.bash
. /root/scripts/functions/NetappHandler.bash

usage()
{
cat <<EOF
This utility use to inventory into MySQL DB
Usage:
        $0

Usage like:
        $0
EOF
exit 1
}

mysql_inventory_volumes_table()
{
filer=$1
[[ $filer != $(netapp_vfiler_check $filer) ]] && vfiler=$filer && filer=$(netapp_vfiler_check $filer)
splitByLines
for line in $(/root/scripts/Netapp/netapp_7mode_inventory_volumes.py $filer); do
	volume=$(echo $line | awk '{print $1}')
	state=$(echo $line | awk '{print $2}')
	type=$(echo $line | awk '{print $3}')
	id=$(echo $line | awk '{print $4}')
	used=$(echo $line | awk '{print $5}')
	[[ ! -z $vfiler ]] && filer=$vfiler
	/root/scripts/MySQL/mysql_execute.py "insert into volumes (hostname,vol,state,type,id,used) values ('${filer}','${volume}','${state}','${type}','${id}','${used}') on duplicate key update vol='${volume}',state='${state}',type='${type}',used='${used}'"
done
}

mysql_inventory_volumes_table mtlfs01
