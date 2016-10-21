#!/bin/bash

usage()
{
cat <<EOF
This utility is used for Netapp Qtree creation.
Options:
   $0 mtlfs01 vol1 <new qtree>
EOF
exit 1
}

if [ "$#" -ne "3" ]; then
	usage
fi

if [ "$2" != "vol1" ]; then
	usage
fi

if [ "$1" != "mtlfs01" ]; then
        usage
fi

ping -c 2 $1 > /dev/null 2>&1
if [ "$?" -ne "0" ]; then
	echo -e "\n\e[31mERROR: Can't reach the host, exiting...\e[0m"
	exit
fi


VOL=$(\rsh $1 df -g $2 | egrep -v ".snapshot|^Filesystem|snap reserve" | awk '{print $5}')
if [ -z $VOL ]; then
	echo -e "\n\e[31mERROR: Wrong volume name, exiting..\e[0m"
	exit
fi

if [ -e /mnt/mtlfs01_vol1/${3} ]; then
	echo -e "\n\e[31mERROR: Qtree already exists, exiting..\e[0m"
	exit
fi

cat <<EOF
Configurations:
Filer: $1
Volume: $2
Qtree: $3

To STOP press CTRL+C to CONTINUE press enter
EOF

read stop

/usr/bin/rsh $1 qtree create /vol/${2}/${3}
sleep 3

if [ "$?" -eq "0" ]; then
	echo -e "\nQtree $1:/vol/${2}/${3} successfully created"
	echo "$3 Qtree $1 IT_STORAGE /vol/${2} /usr/svhome/${3}" >> /home/yokadm/Monitors/Storage_Monitoring/Storage_Capacity_Mon.cfg
	echo "$3 Qtree $1 IT_STORAGE /vol/${2} /usr/svhome/${3}" >> /home/yokadm/Monitors/Storage_Monitoring/SVHOME/Storage_Capacity_Mon_SVHOME.cfg
	chgrp sv1 /mnt/mtlfs01_vol1/${3}/
	echo -e "\n\e[032mDONE\e[0m"
else
	echo -e "\e[31mERROR: Qtree was not created"
fi
