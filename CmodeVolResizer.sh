#!/bin/bash				
#########################################
#	Automatic Volumes Resizing	#
# 		Version 2		#
#	Created by: Adam Schnaider	#
#		Date: May 2014		#
#########################################

echo -e "\e[032mWelcome to the automatic volume resizing system\e[0m"
arr=( $@ )
DIR=`dirname $0`
ID=$RANDOM
AGGR_THRESHOLD=90			#Choose aggregate throshold
STTY=$(stty -g)
stty intr undef


usage()
{
cat <<EOF 
This utility is used for Netapp volume resizing.
Options:
   -h, --help				Print this help menu
   -n, --host	<hostname/IP>		Use to specify the hostname or ip of the remote Netapp machine
   -v, --volume	<vol-name>		Use to specify the volume name you choose to resize
   -s, --size	[{+size}{g|G}]		Use to specify the volume resize amount
   -f, --force				Use to ignore aggr. threshold
Usage like: $0 -n Netapp01 -v vol1 -s +50g
OR
Usage like: $0 -n Netapp01 -v vol1 -s
EOF
quit 1
}

quit()
{
stty $STTY
exit $1
}

resize_check()
{
echo $1 | grep '^\+[0-9]*[gG]$' > /dev/null 2>&1
if [ "$?" -eq "0" ]
then
	environment_check $1
	return
else
	echo -e "\n\e[31mERROR: The size you entered is invalid! Please try again\e[0m"
	usage
fi
}

environment_check()
{
if [ ! -z "$NetApp" ] && [ ! -z $VOL ]
then
	ping -c 2 $NetApp > /dev/null 2>&1
	if [ "$?" -ne "0" ]
	then
		echo -e "\n\e[31mERROR: Can't reach the host, exiting...\e[0m"
		quit 200
	fi
	clean_resize=`echo $1 | sed 's/^+//' | sed 's/[gG]$//'`
	VOL_COUNT=$(\ssh -l admin $NetApp vol show $VOL | grep -w $VOL | wc -l)
	if [ $VOL_COUNT -gt "1" ]
	then
		echo -e "\n\e[31mERROR: Found $VOL_COUNT volumes matching this name: $VOL \n\tPlease run again with \"-l <vserver>\"\e[0m"
		quit 100
	fi
	VOL_USAGE=$(\ssh -l admin $NetApp df -g -x $VOL | grep -w $VOL | awk '{print $5}' | grep -v "entries" )
	if [ -z $VOL_USAGE ]
	then
		echo -e "\n\e[31mERROR: Wrong volume name, exiting..\e[0m"
		quit 202
	fi
	VOL_STATUS=$(\ssh -l admin $NetApp vol show $VOL | grep -w $VOL | awk '{print $5}')
	if [ "$VOL_STATUS" != "RW" ]
	then
		echo -e "\n\e[31mERROR: Volume $VOL is snapmirror destination, exiting..\e[0m"
		quit 123
	fi
	if [ -z $VSERVER ]
	then
		VSERVER=$(\ssh -l admin $NetApp vol show $VOL | grep -w $VOL | awk '{print $1}')
	fi
	VOL_SNAP_PERCENTAGE=$(\ssh -l admin $NetApp df -g $VOL | egrep .snapshot | awk '{print $5}' | awk '{sub(/%/,"") sub(/---/,"");print}')
	AGGR=$(\ssh -l admin $NetApp vol show $VOL | grep -w $VOL | awk '{print $3}')
	LOCAL_AGGR_USAGE=$(\ssh -l admin $NetApp df -aggregates -g -x $AGGR | grep -w "$AGGR" | awk '{print $5}' | cut -d '%' -f 1 )
	LOCAL_AGGR_FREE_SPACE=$(\ssh -l admin $NetApp df -aggregates -g -x $AGGR | grep -w $AGGR | awk '{print $4}' | sed 's/GB$//')
	if [ ! -z "$clean_resize" ]
	then
		if [ "$clean_resize" -ge "$LOCAL_AGGR_FREE_SPACE" ]
		then
			echo -e "\n\e[31mERROR: Not enough free space for volume $VOL in $AGGR on $NetApp (${LOCAL_AGGR_FREE_SPACE}GB left)\e[0m"
			quit 205
		fi
	fi
	SNAP_MIRROR_COUNT=$(\ssh -l admin $NetApp snapmirror list -source-volume $VOL | grep -w $VOL | egrep -v "^Snapmirror is|^Source\s+ Destination" | wc -l)
	local_aggr_space_error=0
	if [ "$LOCAL_AGGR_USAGE" -ge "$AGGR_THRESHOLD" ]
	then
		local_aggr_space_error=1
	fi
else
	echo -e "\nNo NetApp host and/or Volume name entered"
	echo -e "\nExiting script.. Done nothing.."
	quit 3
fi
}

snapmirrorHandler()
{
if [ "$SNAP_MIRROR_COUNT" -gt 0 ]
then
	snap_count=1
	while [ "$snap_count" -le "$SNAP_MIRROR_COUNT" ]
	do
		snap_error[$snap_count]=0
		SNAP_MIRROR_DEST_VSERVER[$snap_count]=$(\ssh -l admin $NetApp snapmirror list -source-volume $VOL | grep -w $VOL | egrep -v "^Snapmirror is|^Source\s+ Destination" | sed -n ${snap_count}p | awk '{print $3}' | awk -F: '{print $1}')
		if [[ "${SNAP_MIRROR_DEST_VSERVER[$snap_count]}" =~ ^mtl && "${SNAP_MIRROR_DEST_VSERVER[$snap_count]}" =~ dr$ ]]; then SNAP_MIRROR_DEST_NETAPP[$snap_count]=mtrfsprd; elif [[ "${SNAP_MIRROR_DEST_VSERVER[$snap_count]}" =~ ^mtr && "${SNAP_MIRROR_DEST_VSERVER[$snap_count]}" =~ dr$ ]]; then SNAP_MIRROR_DEST_NETAPP[$snap_count]=mtlfsprd; elif [[ "${SNAP_MIRROR_DEST_VSERVER[$snap_count]}" =~ ^mtl ]]; then SNAP_MIRROR_DEST_NETAPP[$snap_count]=mtlfsprd; elif [[ "${SNAP_MIRROR_DEST_VSERVER[$snap_count]}" =~ ^mtr ]]; then SNAP_MIRROR_DEST_NETAPP[$snap_count]=mtrfsprd; elif [[ "${SNAP_MIRROR_DEST_VSERVER[$snap_count]}" =~ ^mti ]]; then SNAP_MIRROR_DEST_NETAPP[$snap_count]=mtifsprd; elif [[ "${SNAP_MIRROR_DEST_VSERVER[$snap_count]}" =~ ^mtb ]]; then SNAP_MIRROR_DEST_NETAPP[$snap_count]=mtbfsprd; fi
		ping -c 3 ${SNAP_MIRROR_DEST_NETAPP[$snap_count]} > /dev/null 2>&1
		if [ "$?" -ne "0" ]
		then
			echo -e "\n\e[31mERROR: Can't reach snapmirror destination ${SNAP_MIRROR_DEST_NETAPP[$snap_count]}, exiting..\e[0m"
			quit 201
		fi
		SNAP_MIRROR_DEST_VOL[$snap_count]=$(\ssh -l admin $NetApp snapmirror list -source-volume $VOL | grep -w $VOL | egrep -v "^Snapmirror is|^Source\s+ Destination" | sed -n ${snap_count}p | awk '{print $3}' | awk -F: '{print $2}')
		SNAP_MIRROR_DEST_VOL_SIZE[$snap_count]=$(\ssh -l admin ${SNAP_MIRROR_DEST_NETAPP[$snap_count]} vol size ${SNAP_MIRROR_DEST_VOL[$snap_count]} -vserver ${SNAP_MIRROR_DEST_VSERVER[$snap_count]} | grep -w ${SNAP_MIRROR_DEST_VOL[$snap_count]} | awk '{print $(NF-1)}')
		SNAP_MIRROR_STATUS=$(\ssh -l admin $NetApp vol show $VOL | grep -w $VOL | awk '{print $5}')
		if [ "$SNAP_MIRROR_STATUS" != "RW" ]
		then
			if [ "${SNAP_MIRROR_DEST_VOL[$snap_count]}" == "$VOL" ]
			then
				echo -e "\n\e[31mERROR: $NetApp is a snapmirror destination for $VOL, exiting..\e[0m"
				quit 204
			fi
		fi
		SNAP_MIRROR_DEST_AGGR[$snap_count]=$(\ssh -l admin ${SNAP_MIRROR_DEST_NETAPP[$snap_count]} vol show ${SNAP_MIRROR_DEST_VOL[$snap_count]} | grep -w ${SNAP_MIRROR_DEST_VOL[$snap_count]} | awk '{print $3}')
		REMOTE_AGGR_USAGE[$snap_count]=$(\ssh -l admin ${SNAP_MIRROR_DEST_NETAPP[$snap_count]} df -aggregates -g -x ${SNAP_MIRROR_DEST_AGGR[$snap_count]} | grep -w ${SNAP_MIRROR_DEST_AGGR[$snap_count]} | awk '{print $5}' | cut -d '%' -f 1)
		REMOTE_AGGR_FREE_SPACE[$snap_count]=$(\ssh -l admin ${SNAP_MIRROR_DEST_NETAPP[$snap_count]} df -aggregates -g -x ${SNAP_MIRROR_DEST_AGGR[$snap_count]} | egrep -w ${SNAP_MIRROR_DEST_AGGR[$snap_count]} | awk '{print $4}' | sed 's/GB$//')
		if [ ! -z "$clean_resize" ]
		then
			if [ "$clean_resize" -ge "${REMOTE_AGGR_FREE_SPACE[$snap_count]}" ]
			then
				echo -e "\n\e[31mERROR: Not enough free space for ${SNAP_MIRROR_DEST_VOL[$snap_count]} in ${SNAP_MIRROR_DEST_AGGR[$snap_count]} on ${SNAP_MIRROR_DEST_NETAPP[$snap_count]}\e[0m"
                	        quit 205
			fi
		fi
		if [[ "${REMOTE_AGGR_USAGE[$snap_count]}" -ge "$AGGR_THRESHOLD" ]]
		then
			let snap_error[$snap_count]=1
		fi
		let snap_count=$snap_count+1
	done
else
	echo -e "\nNo Snapmirror connection found. fatal error"
	quit 10
fi
}

actualResizer()
{
if [ ! -z $NetApp ] && [ ! -z $VOL ] && [ ! -z $check_s ] && [ -z $RESIZE ]
then
	environment_check
	echo -e "\n\e[31mNote: No size was inserted, showing \"$VOL\" details only!\e[0m"
	echo -e "\n\e[96mVolume size:\e[0m"
	ssh -l admin $NetApp vol size $VOL -vserver $VSERVER | grep -v -w "(volume size)"
	echo -e "\n\e[96mVolume usage:\e[0m"
	ssh -l admin $NetApp df -g $VOL
	if [ ! -z $VOL_SNAP_PERCENTAGE ]
	then
		if [ "$VOL_SNAP_PERCENTAGE" -gt "100" ]
		then
			echo -e "\n\e[96mSnapshots:\n(Snapshot is over 100%)\e[0m"
			ssh -l admin $NetApp snap show $VOL
		fi
	fi
	echo -e "\n\e[96mAggregate usage:\e[0m"
	ssh -l admin $NetApp df -aggregates -g -x $AGGR
	if [ "$SNAP_MIRROR_COUNT" -gt 0 ]
	then
		echo -e "\nSnapmirror relationships found! Processing.."
		echo -e "\n\e[96mSnapMirror status:\e[0m"
		ssh -l admin $NetApp snapmirror list -source-volume $VOL
		snapmirrorHandler
		num=1
		while [ "$num" -le "$SNAP_MIRROR_COUNT" ]
		do
			echo -e "\n\e[96mSnapmirror destinations:\e[0m Filer: ${SNAP_MIRROR_DEST_NETAPP[$num]} -> Volume: ${SNAP_MIRROR_DEST_VOL[$num]} (${SNAP_MIRROR_DEST_VOL_SIZE[$num]}) -> Aggregate: ${SNAP_MIRROR_DEST_AGGR[$num]} -> Aggr usage: ${REMOTE_AGGR_USAGE[$num]}%"
			let num=$num+1
		done
	else
		echo -e "\nNo snapmirror relationships found"
	fi
	quit 1
elif [ ! -z $NetApp ] && [ ! -z $VOL ] && [ ! -z $check_s ] && [ ! -z $RESIZE ]
then
	resize_check $RESIZE
	if [ "$local_aggr_space_error" -eq "1" ] && [ "$force" != "yes" ]
	then
		echo -e "\n\e[31mWarning: Volume $VOL that reside on Aggregate $AGGR (local) on $NetApp has\e[0m ${LOCAL_AGGR_USAGE}% \e[31mof aggregate usage (limit set by:\e[0m AGGR_THRESHOLD=${AGGR_THRESHOLD}%\e[31m) and ${LOCAL_AGGR_FREE_SPACE}GB free space\e[0m"
		echo -e "Continue resize? [Y/N]"
		read answer
		case "$answer" in
			YES|yes|y|Y )
				echo "Proceeding.."
				;;
			NO|no|n|N )
				echo "Exiting.. Done nothing!"
				quit 2
				;;
			* )
				echo "Wrong answer"
				actualResizer
				;;
		esac
	fi
	if [ "$SNAP_MIRROR_COUNT" -gt "0" ]
	then
		echo -e "\nSnapmirror relationships found! Processing.."
		snapmirrorHandler
		for (( i=1; i<=${#snap_error[@]}; i++ ))
		do
			if [ "${snap_error[$i]}" -eq "1" ] && [ "$force" != "yes" ]
			then
				echo -e "\n\e[31mWarning: Volume ${SNAP_MIRROR_DEST_VOL[$i]} that reside on Aggregate ${SNAP_MIRROR_DEST_AGGR[$i]} (snapmirrored) on ${SNAP_MIRROR_DEST_NETAPP[$i]} has\e[0m ${REMOTE_AGGR_USAGE[$i]}% \e[31mof aggregate usage (limit set by:\e[0m AGGR_THRESHOLD=${AGGR_THRESHOLD}%\e[31m) and ${REMOTE_AGGR_FREE_SPACE[$i]}GB free space\e[0m"
				echo -e "Continue resize? [Y/N]"
		                read answer
		                case "$answer" in
		                        YES|yes|y|Y )
		                                echo "Proceeding.."
		                                ;;
		                        NO|no|n|N )
		                                echo "Exiting.. Done nothing!"
		                                quit 2
		                                ;;
		                        * )
		                                echo "Wrong answer"
		                                actualResizer
		                                ;;
		                esac
			#else
			#	echo "SCRIPT CHECKING: ${SNAP_MIRROR_DEST_NETAPP[$i]}, ${SNAP_MIRROR_DEST_VOL[$i]}, ${SNAP_MIRROR_DEST_AGGR[$i]}, ${REMOTE_AGGR_USAGE[$i]}, ${REMOTE_AGGR_FREE_SPACE[$i]} snap_error ok, no value of '1' inside it"
			fi
		done
		let snap_count=$snap_count-1
		while [ $snap_count -ge "1" ]
		do
			echo -e "\n\e[96mStarting to resize remote systems:\e[0m"
			echo -e "Resizing remote Netapp system: ${SNAP_MIRROR_DEST_NETAPP[$snap_count]}, Volume: ${SNAP_MIRROR_DEST_VOL[$snap_count]}\n"
			ssh -l admin ${SNAP_MIRROR_DEST_NETAPP[$snap_count]} vol size ${SNAP_MIRROR_DEST_VOL[$snap_count]} -vserver ${SNAP_MIRROR_DEST_VSERVER[$snap_count]} $RESIZE | grep -v -w "(volume size)"
			echo "$ID,$NetApp,$VOL,$RESIZE,$VOL_USAGE,$AGGR,$LOCAL_AGGR_USAGE%,${LOCAL_AGGR_FREE_SPACE}GB,V,${SNAP_MIRROR_DEST_NETAPP[$snap_count]},${SNAP_MIRROR_DEST_VOL[$snap_count]},${SNAP_MIRROR_DEST_AGGR[$snap_count]},${REMOTE_AGGR_USAGE[$snap_count]}%,${REMOTE_AGGR_FREE_SPACE[$snap_count]}GB,`date +%d/%m/%y`" >> $DIR/volResizer.csv
			let snap_count=$snap_count-1
		done
	fi
	echo -e "\n\e[96mStarting to resize local system: $NetApp, Volume: $VOL\e[0m"
	ssh -l admin $NetApp vol size $VOL -vserver $VSERVER $RESIZE | grep -v -w "(volume size)"
	echo "$ID,$NetApp,$VOL,$RESIZE,$VOL_USAGE,$AGGR,$LOCAL_AGGR_USAGE%,${LOCAL_AGGR_FREE_SPACE}GB,X,,,,,,`date +%d/%m/%y`,`date +%R`" >> $DIR/volResizer.csv
	echo -e "\n\e[032mDONE\e[0m"
	quit 0
else
	echo -e "\n\e[031mERROR: Arguments error\e[0m"
	quit 0
fi
}

if [ "$#" -lt "5" ]
then
	usage
else
	i=0
	while [[ "$i" -lt "$#" ]]
	do
		n=$i
		v=$i
		s=$i
		case "${arr[$i]}" in
			-h|--help )
				usage
				;;
			-n|--host )
				let n=n+1
				NetApp=${arr[$n]}
			#	echo "NetApp: $NetApp"
				;;
			-v|--volume )
				let v=v+1
				VOL=${arr[$v]}
			#	echo "Volume: $VOL"
				;;
			-s|--size )
				let s=s+1
				RESIZE=${arr[$s]}
				check_s=1
			#	echo "Resize by: $RESIZE"
				;;
			-f|--force )
				force=yes
				;;
			-* )	
				echo -e "\e[31mERROR: Wrong arguments!\e[0m"
				usage
				;;
		esac	

		let i=i+1
	done
fi

actualResizer
