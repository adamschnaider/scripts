#!/bin/bash

###################################################
#	Bash source file for Netapp functions     #
#       Created by: Adam Schnaider      	  #
#               Date: Apr 2016			  #
###################################################

ID=$RANDOM
DIR=`dirname $0`

# Args: filer hostname/ip
# Return codes:
# 0 - ping succeeded
# 1 - ping failed
ping_check() {
	ping -c 2 $1 > /dev/null 2>&1
	[[ "$?"  -eq "0" ]] && return 0
	return 1
}

resize_check() {
echo $1 | grep '^\+[0-9]*[gG]$' > /dev/null 2>&1
[[ "$?" -eq "0" ]] && return 0 || echo -e "\n\e[31mERROR: The size you entered is invalid! Please try again\e[0m" && exit 1
}

# Gets filer's hostname/ip and checks version
# Agrs: filer hostname/ip
# Return: name of physical filer if vfiler was entered
# Return codes:
# 1 - Netapp cDOT
# 2 - Netapp 7-mode
# 3 - Not a Netapp - currently not working
# 4 - Can't reach 
netapp_get_version() {
	local filer=$1
	ping_check $filer ; [[ $? -ne "0" ]] && return 4
	(nc -z $filer 22 >/dev/null 2>&1) || return 3
	local fFiler=$(netapp_vfiler_check $filer) ; [[ $? = "0" ]] && filer=$fFiler
	local version=$(ssh root@${filer} "version" | grep NetApp | awk '{print $4}'|sed 's/://')
	if [ $version == "Cluster-Mode" ]; then
		echo "Cluster-Mode"
		return 1
	elif [[ $version == "7-Mode" || -z $version ]]; then
		echo "7Mode"
		return 2
	else
		echo "ERROR: Can't get filer version"
	fi
}

# Gets filer's hostname/ip and checks if vfiler
# Agrs: filer hostname/ip
# Return: Netapp physical filer
# Return codes:
# 1 - Netapp cDOT
# 2 - Netapp 7-mode
# 3 - Not a Netapp
# 4 - Can't reach
netapp_vfiler_check() {
	local vfilers=(mtlfs01-labfs01 mtlfs03-labfs02 bond-mtrlabfs01 mthfs01-mthlabfs01 mthfs02-mthlabfs02 mtvfs02-mtvlabfs01)
	local filer=$1
	for i in ${vfilers[@]}; do
		[[ "$(echo $i |awk -F'-' '{print $1}')" == "${filer}" ]] && echo "$(echo $i |awk -F'-' '{print $2}')" && return 0
	done
	echo "$filer"
	return 1
}

# Gets filer's hostname/ip, resize detalis and check volume resize possibility
# Agrs: filer hostname/ip(1), volume(2), size increasement(3), force(3)
# Return codes:
# 0 - pass
# 1 - error
netapp_7mode_vol_resize() {
	AGGR_USAGE_THRESHOLD=90
	local filer=$1
	local volume=$2
	local size=$3
	local vfiler
	[[ $4 == "-f"  ]] && force=yes || force=no
	
	echo -e "\e[032mWelcome to the automatic volume resizing system\e[0m"
#	echo $size | grep '^\+[0-9]*[gG]$' > /dev/null 2>&1 ; [[ "$?" -ne "0" ]] && echo "Invalid size entered" && return 1
	[[ ! -z $size ]] && resize_check $size || echo -e "\n\e[31mNote: No size was inserted, showing \"$volume\" details only!\e[0m"
	if ! $(ping_check $filer ); then echo -e "\n\e[31mERROR: Can't reach the host, exiting...\e[0m"; exit 1; fi
	[[ ! -z $size ]] && clean_resize=$(echo $size | sed 's/^+//' | sed 's/[gG]$//')
	vol_usage=$(ssh root@${filer} df -g -x $volume | egrep -v "^Filesystem|snap reserve" | awk '{print $5}')
	[[ -z $vol_usage ]] && echo -e "\n\e[31mERROR: Wrong volume name, exiting..\e[0m" && return 1
	vol_snap_percentage=$(ssh root@${filer} df -g $volume | egrep .snapshot | awk '{print $5}' | awk '{sub(/%/,"") sub(/---/,"");print}')
	aggr=$(ssh root@${filer} vol status $volume | grep -w "Containing aggregate" | awk '{print $3}' | cut -d "'" -f 2)
	## Check if vFiler
	[[ $filer != $(netapp_vfiler_check $filer) ]] && vfiler=$filer && filer=$(netapp_vfiler_check $filer)
#	local local_aggr=$(ssh root@${filer} df -Agx $aggr | egrep -v "^Aggregate\s+ total")
	local local_aggr_f=$(ssh root@${filer} df -Ag $aggr)
	local local_aggr_usage=$(echo "$local_aggr_f" | egrep -v ".snapshot|^Aggregate\s+ total" | awk '{print $5}' | awk '{sub(/%/,"");print}')
	local local_aggr_free_space=$(echo "$local_aggr_f" | egrep -v ".snapshot|^Aggregate\s+ total" | awk '{print $4}' | sed 's/GB$//')
	if [ -z $size ]; then
		echo -e "\n\e[96mVolume size:\e[0m"
		ssh root@${filer} vol size $volume $size
		echo -e "\n\e[96mVolume usage:\e[0m"
		ssh root@${filer} df -g $volume
		echo -e "\n\e[96mSnapshot reserve percentage:\e[0m"
		ssh root@${filer} snap reserve $volume
		[[ $vol_snap_percentage -gt 100 ]] && echo -e "\n\e[96mSnapshots:\n(Snapshots are over 100%)\e[0m" && ssh root@${filer} snap list $volume
		echo -e "\n\e[96mAggregate usage:\e[0m"
		echo "$local_aggr_f"
	fi
	[[ ! -z $vfiler ]] && filer=$vfiler
	[[ $clean_resize -ge $local_aggr_free_space ]] && echo "Not enough free space for volume $volume in $aggr on $filer" && return 1
#	snapmirror=$(ssh root@${filer} snapmirror status $volume | egrep -v "^Snapmirror is|^Source\s+ Destination")
	snapmirror=$(ssh root@${filer} snapmirror status $volume)
	snapmirror_count=$(echo "$snapmirror" | egrep -v "^Snapmirror is|^Source\s+ Destination" | wc -l) ### breaks the output into its original lines instead of one long output
	[[ $snapmirror_count -gt 0 ]] && netapp_7mode_snapmirror_handler $filer $volume #|| echo "No SnapMirror replationships found"
	[[ ! -z $size ]] && echo -e "\n\e[96mStarting to resize local system: $filer, Volume: $volume\e[0m"
	[[ $filer != $(netapp_vfiler_check $filer) ]] && vfiler=$filer && filer=$(netapp_vfiler_check $filer)
	[[ ! -z $size ]] && ssh root@${filer} vol size $volume $size
	[[ ! -z $vfiler ]] && filer=$vfiler
	echo "$ID,$filer,$volume,$size,$vol_usage,$aggr,${local_aggr_usage}%,${local_aggr_free_space}GB,X,,,,,,`date +%d/%m/%y`,`date +%R`" >> $DIR/NEW_volResizer.csv
	echo -e "\n\e[032mDONE\e[0m"
}

netapp_cmode_vol_resize() {
	echo "NULL"
}


netapp_7mode_snapmirror_handler() {
	local filer=$1
	local volume=$2
	local vfiler
	snapmirror_counter=1
	echo -e "\nSnapmirror relationships found! Processing..."
	[[ -z $size ]] && echo -e "\n\e[96mSnapmirror status:\e[0m" && echo "$snapmirror"
	while [ $snapmirror_counter -le $snapmirror_count ]; do
		snapmirror_dest_filer[$snapmirror_counter]=$(echo "$snapmirror" | egrep -v "^Snapmirror is|^Source\s+ Destination" | sed -n ${snapmirror_counter}p | awk '{print $2}' | awk -F: '{print $1}')
		$(ping_check ${snapmirror_dest_filer[$snapmirror_counter]}) || $(echo "Can't reach snapmirror destination ${snapmirror_dest_filer[$snapmirror_counter]}" && return 1)
		snapmirror_dest_volume[$snapmirror_counter]=$(echo "$snapmirror" | egrep -v "^Snapmirror is|^Source\s+ Destination" | sed -n ${snapmirror_counter}p | awk '{print $2}' | awk -F: '{print $2}')
		snapmirror_status[$snapmirror_counter]=$(echo "$snapmirror" | egrep -v "^Snapmirror is|^Source\s+ Destination" | sed -n ${snapmirror_counter}p | awk '{print $3}')
		[[ (${snapmirror_status[$snapmirror_counter]} == "Snapmirrored" ) && (${snapmirror_dest_volume[$snapmirror_counter]} == $volume) ]] && echo "ERROR: $filer is a snapmirror destination for $volume" && return 1
		# Checking filer to vfiler match:
		[[ ${snapmirror_dest_filer[$snapmirror_counter]} != $(netapp_vfiler_check ${snapmirror_dest_filer[$snapmirror_counter]}) ]] && vfiler[$snapmirror_counter]=${snapmirror_dest_filer[$snapmirror_counter]} && snapmirror_dest_filer[$snapmirror_counter]=$(netapp_vfiler_check ${snapmirror_dest_filer[$snapmirror_counter]})
		snapmirror_dest_volume_size[$snapmirror_counter]=$(ssh root@${snapmirror_dest_filer[$snapmirror_counter]} vol size ${snapmirror_dest_volume[$snapmirror_counter]} 2>/dev/null | tail -1 | awk '{print $NF }')
		[[ -z ${snapmirror_dest_volume_size[$snapmirror_counter]} ]] && snapmirror_dest_volume_size[$snapmirror_counter]="N/A"
		snapmirror_dest_aggr[$snapmirror_counter]=$(ssh root@${snapmirror_dest_filer[$snapmirror_counter]} vol container ${snapmirror_dest_volume[$snapmirror_counter]} | awk '{print $7}' | cut -d "'" -f 2)
#		remote_aggr[$snapmirror_counter]=$(ssh root@${snapmirror_dest_filer[$snapmirror_counter]} df -Agx ${snapmirror_dest_aggr[$snapmirror_counter]} | egrep -v ".snapshot|^Aggregate\s+ total")
		remote_aggr_f[$snapmirror_counter]=$(ssh root@${snapmirror_dest_filer[$snapmirror_counter]} df -Ag ${snapmirror_dest_aggr[$snapmirror_counter]})
		remote_aggr_usage[$snapmirror_counter]=$(echo "${remote_aggr_f[$snapmirror_counter]}" | egrep -v ".snapshot|^Aggregate\s+ total" | awk '{print $5}' | awk '{sub(/%/,"");print}')
		remote_aggr_free_space[$snapmirror_counter]=$(echo "${remote_aggr_f[$snapmirror_counter]}" | egrep -v ".snapshot|^Aggregate\s+ total" | awk '{print $4}' | sed 's/GB$//')
		# Restore filer/vfiler variables
		[[ ! -z ${vfiler[$snapmirror_counter]} ]] && snapmirror_dest_filer[$snapmirror_counter]=${vfiler[$snapmirror_counter]}
		[[ -z $size ]] && echo -e "\n\e[96mSnapmirror destinations:\e[0m Filer: ${snapmirror_dest_filer[$snapmirror_counter]} -> Volume: ${snapmirror_dest_volume[$snapmirror_counter]} (${snapmirror_dest_volume_size[$snapmirror_counter]}) -> Aggregate: ${snapmirror_dest_aggr[$snapmirror_counter]} -> Aggr usage: ${remote_aggr_usage[$snapmirror_counter]}%"
		[[ (! -z $clean_resize)  && ($clean_resize -ge ${remote_aggr_free_space[$snapmirror_counter]}) ]] && echo -e "\n\e[31mERROR: Not enough free space for ${snapmirror_dest_volume[$snapmirror_counter]} in ${snapmirror_dest_aggr[$snapmirror_counter]} on ${snapmirror_dest_filer[$snapmirror_counter]}\e[0m" && exit 1
		if [ ! -z $clean_resize ] && [ ${remote_aggr_usage[$snapmirror_counter]} -ge $AGGR_USAGE_THRESHOLD ] && [ $force == "no" ]; then
			echo -e "\n\e[31mWarning: Volume ${snapmirror_dest_volume[$snapmirror_counter]} that reside on Aggregate ${snapmirror_dest_aggr[$snapmirror_counter]} (snapmirrored) on ${snapmirror_dest_filer[$snapmirror_counter]} has\e[0m ${remote_aggr_usage[$snapmirror_counter]}% \e[31mof aggregate usage (limit set by:\e[0m AGGR_THRESHOLD=${AGGR_USAGE_THRESHOLD}%\e[31m) and ${remote_aggr_free_space[$snapmirror_counter]}GB free space\e[0m"
			echo -e "Continue resize? [Y/N]"
			read answer
			case "$answer" in
			        YES|yes|y|Y )
			                echo "Proceeding.."
			                ;;
			        NO|no|n|N )
			                echo "Exiting.. Done nothing!"
			                exit 2
			                ;;
			        * )
			                echo "Wrong answer"
					echo "Exiting.. Done nothing!"
                                        exit 2
			                ##netapp_7mode_snapmirror_handler $filer $volume
			                ;;
			esac
		fi
		let snapmirror_counter+=1
	done
	let snapmirror_counter-=1
	while [ $snapmirror_counter -ge "1" ] && [ ! -z $size ]
	do
		echo -e "\n\e[96mStarting to resize remote system:\e[0m"
		echo -e "Resizing remote Netapp system: ${snapmirror_dest_filer[$snapmirror_counter]}, Volume: ${snapmirror_dest_volume[$snapmirror_counter]}\n"
		[[ ${snapmirror_dest_filer[$snapmirror_counter]} != $(netapp_vfiler_check ${snapmirror_dest_filer[$snapmirror_counter]}) ]] && vfiler[$snapmirror_counter]=${snapmirror_dest_filer[$snapmirror_counter]} && snapmirror_dest_filer[$snapmirror_counter]=$(netapp_vfiler_check ${snapmirror_dest_filer[$snapmirror_counter]})
		ssh root@${snapmirror_dest_filer[$snapmirror_counter]} vol size ${snapmirror_dest_volume[$snapmirror_counter]} $size
		[[ ! -z ${vfiler[$snapmirror_counter]} ]] && snapmirror_dest_filer[$snapmirror_counter]=${vfiler[$snapmirror_counter]}
		echo "$ID,$filer,$volume,$size,$vol_usage,$aggr,${local_aggr_usage}%,${local_aggr_free_space}GB,V,${snapmirror_dest_filer[$snapmirror_counter]},${snapmirror_dest_volume[$snapmirror_counter]},${snapmirror_dest_aggr[$snapmirror_counter]},${remote_aggr_usage[$snapmirror_counter]}%,${remote_aggr_free_space[$snapmirror_counter]}GB,`date +%d/%m/%y`,`date +%R`" >> $DIR/NEW_volResizer.csv
		let snapmirror_counter=$snapmirror_counter-1
	done
#	echo -e "\n\e[032mDONE WITH REMOTE SYSTEMS\e[0m"
}

netapp_quota_handler() {
echo "NULL"
}
