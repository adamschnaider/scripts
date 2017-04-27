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
	$0 -n filer01 -v mswg -d filer02
	OR
	$0 -n filer01 -v mswg -s MTR,MTV,MTI
EOF
exit 1
}

quit()
{
exit $1
}

[[ $# -lt 6 ]] && usage

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
			site=$2
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
	echo "-E- ERROR WITH SOURCE VOLUME TYPE"
	exit 1
fi

if [[ ! -z $dst_filer ]] ; then
	if ! ping_check $dst_filer ; then
		echo "-E- CAN'T REACH DESTINATION FILER: ${dst_filer}"
		exit 1
	fi
	aggr_list=$(netapp_7mode_list_aggr $dst_filer)
	echo "${aggr_list}"
	echo "Please enter desired aggregate name: "
	read aggr
	if ! $(echo "$aggr_list" |awk '{print $2}' | grep -owq $aggr > /dev/null 2>&1) ; then
		echo "-E- WRONG AGGREGATE CHOSEN ON ${dst_filer}"
	fi
fi
