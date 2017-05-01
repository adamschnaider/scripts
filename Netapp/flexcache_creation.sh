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
	$0 -n <src filer> -v <src volume> [ -d <dst filer> | -s <site1,site2,site3> ]

Usage like:
	$0 -n filer01 -v mswg -d filer02 -f mswg_flexcache -g 50G
	OR
	$0 -n filer01 -v mswg -s MTR,MTV,MTI -f mswg_flexcache -g 50G
EOF
exit 1
}

quit()
{
exit $1
}

[[ $# -lt 10 ]] && usage

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
		-* )
			echo "-E- WRONG ARGUMENTS"
			usage
			;;
	esac
	shift
done

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
		exit 1
	fi
	if ! echo $dst_vol_size | grep -q '^[0-9]*[gG]$' ; then
		echo "-E- INVALID SIZE ENTERED"
		usage
		exit 1
	fi
	aggr_list=$(netapp_7mode_list_aggr $dst_filer)
	echo "${aggr_list}"
	echo "Please enter desired aggregate name: "
	read dst_aggr
	if ! $(echo "$aggr_list" |awk '{print $2}' | grep -owq $dst_aggr > /dev/null 2>&1) ; then
		echo "-E- WRONG AGGREGATE CHOSEN FOR ${dst_filer}"
		exit 1
	fi
	netapp_7mode_vol_type $dst_filer $dst_volume > /dev/null
	if [[ "$?" -ne 1 ]] ; then
		echo "-E- VOLUME: $dst_volume ALREADY EXISTS ON DESTINATION: $dst_filer"
		exit 1
	fi
	if [[ $(netapp_7mode_list_aggr $dst_filer | grep -w $dst_aggr | awk '{print $8}' | sed 's/GB$//') -le $(echo $dst_vol_size | sed 's/[gG]$//') ]] ; then
		echo "-E- NOT ENOUGH FREE SPACE ON AGGR: $dst_aggr, FILER: $dst_filer"
		exit 1
	fi
	
	## FlexCache creation process:
	echo "-I- STARTING TO CREATE FLEXCACHE VOLUME(S)"
	echo -e "-I- FLEXCACHE DETAILS:\n SOURCE FILER: $filer \n SOURCE VOLUME: $volume \n DESTINATION FILER: $dst_filer \n DESTINATION VOLUME: $dst_volume \n DESTINATION AGGR: $dst_aggr"
	echo "PRESS ENTER TO CONTINUE OR CTRL+C TO EXIT"
	read answer
	echo "-E- ssh root@${dst_filer} vol create $dst_volume $dst_aggr $dst_vol_size -S ${filer}:${volume}"
	#ssh root@${dst_filer} vol create $dst_volume $dst_aggr $dst_vol_size -S ${filer}:${volume}
fi

if [[ ! -z $sites ]]; then
	if ! check_mysql ; then
		echo "-E- MySQL NOT RUNNING, CAN'T QUERY SITES FILERS"
		exit 1
	fi
	### MYSQL QUERY:
	### mysql MLNX -B --skip-column-names -e "select site,max(hostname),ip from storagesystems where vendor='Netapp' and hostname not regexp '-old$' and hostname regexp 'lab' group by site" |grep -wE "MTL|MTI|LDMZ"
fi	
