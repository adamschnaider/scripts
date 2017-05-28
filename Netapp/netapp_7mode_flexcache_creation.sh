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
This utility use to create Netapp 7-Mode FlexCache Volumes
Usage:
	$0 -n <src filer> -v <src volume> [ -d <dst filer> | -s <site1,site2,site3> ] -o <perms>

Usage like:
	$0 -n filer01 -v mswg -d filer02 -f mswg_flexcache -g 50G -o rw
	OR
	$0 -n filer01 -v mswg -s MTR,MTV,MTI -f mswg_flexcache -g 50G -o ro
EOF
exit 1
}

quit()
{
exit $1
}

create_flexcache()
{
[[ $# -lt 12 ]] && usage

while (( "$#" )); do
	case "$1" in 
		-n )
			filer=$2
			;;
		-v )
			volume=$2
			;;
		-d )
			dst_filer=$2
			;;
		-s )
			sites=$2
			;;
		-f )
			dst_volume=$2
			;;
		-g )
			dst_vol_size=$2
			;;
		-o )
			if echo $2 | grep -wq ro || echo $2 |grep -wq rw ;then
				perms=$2
			else
				echo "-E- BAD PERMISSIONS PARAMETER ENTERED. USE rw OR ro."
				usage
			fi
			;;
		-* )
			echo "-E- WRONG ARGUMENTS"
			usage
			;;
	esac
	shift
done

if ! check_mysql ; then
	echo "-E- MySQL NOT RUNNING, CAN'T QUERY SITES FILERS"
	exit 1
fi

if ! ping_check $filer ; then
	echo "-E- CAN'T REACH SOURCE FILER: ${filer}"
	exit 1
fi

if [[ ! -z $dst_filer && ! -z $site ]]; then
	echo "-E- USE '-s' OR '-d', NOT BOTH"
	exit 1
fi

if ! netapp_7mode_vol_type $filer $volume>/dev/null ; then
	echo "-E- ERROR WITH SOURCE VOLUME"
	exit 1
fi

if [[ ! -z $dst_filer ]] ; then
	if ! ping_check $dst_filer ; then
		echo "-E- CAN'T REACH DESTINATION FILER: ${dst_filer}"
		return 1
	fi
	if ! echo $dst_vol_size | grep -q '^[0-9]*[gG]$' ; then
		echo "-E- INVALID SIZE ENTERED"
		usage
		exit 1
	fi
	aggr_list=$(netapp_7mode_list_aggr $dst_filer)
	if [ $(echo "${aggr_list=}" | wc -l) -eq 1 ]; then
		echo -e "\n${aggr_list}"
		dst_aggr=$(echo ${aggr_list=} | awk '{print $2}')
	else
		echo -e "\nPlease choose aggregate from ${dst_filer}:"
		echo "${aggr_list}"
		echo "Please enter desired aggregate name: "
		read dst_aggr
	fi
	if ! $(echo "$aggr_list" |awk '{print $2}' | grep -owq $dst_aggr > /dev/null 2>&1) ; then
		echo "-E- WRONG AGGREGATE CHOSEN FOR ${dst_filer}, FLEXCACHE VOLUME WASN'T CREATED"
		return 1
	fi
	netapp_7mode_vol_type $dst_filer $dst_volume > /dev/null
	if [[ "$?" -ne 1 ]] ; then
		echo "-E- VOLUME: $dst_volume ALREADY EXISTS ON DESTINATION: $dst_filer"
		return 1
	fi
	if [[ $(netapp_7mode_list_aggr $dst_filer | grep -w $dst_aggr | awk '{print $8}' | sed 's/GB$//') -le $(echo $dst_vol_size | sed 's/[gG]$//') ]] ; then
		echo "-E- NOT ENOUGH FREE SPACE ON AGGR: $dst_aggr, FILER: $dst_filer"
		return 1
	fi
	
	## FlexCache creation process:
	echo "-I- STARTING TO CREATE FLEXCACHE VOLUME(S)"
	echo -e "-I- FLEXCACHE DETAILS:\n SOURCE FILER: $filer \n SOURCE VOLUME: $volume \n DESTINATION FILER: $dst_filer \n DESTINATION VOLUME: $dst_volume \n DESTINATION AGGR: $dst_aggr"
	echo "PRESS ENTER TO CONTINUE OR CTRL+C TO EXIT"
	read answer
	echo "-I- RUNNING COMMAND: ssh root@${dst_filer} vol create $dst_volume $dst_aggr $dst_vol_size -S ${filer}:${volume}"
	ssh root@${dst_filer} vol create $dst_volume $dst_aggr $dst_vol_size -S ${filer}:${volume}
	
	## Setting exports:
	exports=$(mysql MLNX -B --skip-column-names -e "set @filer='${dst_filer}' ; select lab from exports where site=(select site from storagesystems where vendor='Netapp' and flexcache='true' and hostname not regexp '-old$' and (hostname=@filer or ip=@filer))")
	if [[ -z $exports ]]; then
		echo "-W NO EXPORTS CONFIGURATION FOUND, VOLUME CREATED WITH DEFAULT EXPORTS"
	else
		if [ $perms == "ro" ] ;then
			ssh root@${dst_filer} "exportfs -p sec=sys,ro=${exports}:10.0.10.100:10.4.0.123 /vol/${dst_volume}"
		else
			ssh root@${dst_filer} "exportfs -p sec=sys,rw=${exports}:10.0.10.100:10.4.0.123,root=10.0.10.100:10.4.0.123 /vol/${dst_volume}"
		fi
	fi
fi

if [[ ! -z $sites ]]; then
	### MYSQL QUERY:
	sites=$(echo $sites | sed 's/,/\|/g')
	output=$(mysql MLNX -B --skip-column-names -e "select site,hostname,ip from storagesystems as A where vendor='Netapp' and flexcache='true' and hostname not regexp '-old$' group by site,hostname,ip having hostname<=all(select hostname from storagesystems as B where B.vendor='Netapp' and B.flexcache='true' and B.hostname not regexp '-old$' and A.site=B.site group by site)" |grep -wE "${sites}")
	if [[ -z $output ]]; then
		echo "-E- NO RECORDS ARE MATCHING THE SITES ENTERED"
		exit 1
	fi
	echo "-I- FOLLOWING SITES CHOSEN:"
	echo "$output"
	for host in $(mysql MLNX -B --skip-column-names -e "select site,hostname,ip from storagesystems as A where vendor='Netapp' and flexcache='true' and hostname not regexp '-old$' group by site,hostname,ip having hostname<=all(select hostname from storagesystems as B where B.vendor='Netapp' and B.flexcache='true' and B.hostname not regexp '-old$' and A.site=B.site group by site)" |grep -wE "${sites}" | awk '{print $2}')
	do
		unset sites
		create_flexcache -n $filer -v $volume -d $host -f $dst_volume -g $dst_vol_size -o $perms
	done
fi	
}

create_flexcache $@
