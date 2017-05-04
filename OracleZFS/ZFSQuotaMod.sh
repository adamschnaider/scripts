#!/bin/bash

. /root/scripts/functions/sizeHandler.bash

ZFSHOSTS="mtlzfs01 mtlzfs02"

usage() {
cat <<EOF
Usage: $0 <username> <directory> [size in G] [-f]
EOF
exit 1
}

resize_check()
{
if ! [[ $(echo $size |grep '^[0-9]*[gG]$') ]]; then
        echo -e "\nERROR: The size you entered is invalid! Please try again"
        usage
fi
}

## Arguments
username=$1
dir=$2
size=$3
[[ $4 == "-f" ]] && force=yes

[[ "$#" -gt 4 || "$#" -lt 2 ]] && usage
[[ "$#" -eq 3 ]] && resize_check $size

## Check user
if ! ypmatch ${username} passwd > /dev/null 2>&1; then echo -e "ERROR: User doesn't exists" && exit 1; fi

## Find requested share and count
count=0
for host in $ZFSHOSTS; do
	for share in $(ssh $host "shares list"); do
		for filesystem in $(ssh $host shares select $share list | tail -n +5 | awk '{print $1}') ; do
			echo $filesystem |grep -wq $dir
			if [ $? -eq 0 ] ; then
				let count++
				HOST=$host
				SHARE=$share
				FILESYSTEM=$filesystem
			fi
		done
	done
done

if [ $count -gt 1 ] ; then
	echo -e "ERROR: More than one quota directory matching"
	exit 1
elif [ $count -eq 0 ] ; then
	echo -e "ERROR: Quota directory wasn't found"
	exit 1
fi

## Quota fully detailed
QUOTA=$(ssh ${HOST} shares select ${SHARE} select ${FILESYSTEM} users list | awk -v directory=$dir '{print "user" ,$2,directory,$3,$4}' |grep -w $username)
[[ -z $QUOTA ]] && echo -e "ERROR: No user quota for user $username on $dir" && exit 1
[[ $(echo "$QUOTA" | wc -l) -gt 1 ]] && echo -e "ERROR: Found more than one user quota for user $username on $dir" && exit 1

## Current quota
echo -e "Current quota:"
echo "$QUOTA"

## Continue if size was entered
[[ "$#" -eq "2" ]] && exit

## Check size parameter
resize_check $size

## Check if quota entered is less than current quota
current_quota=$(getScaleInG $(echo $QUOTA | awk '{print $5}')) && current_quota=${current_quota%%.*}
current_used=$(getScaleInG $(echo $QUOTA | awk '{print $4}')) && current_used=${current_used%%.*}
if ([ $(echo $QUOTA | awk '{print $5}') != "-" -a $current_quota -ge ${size%%G*} ] || [ $(echo $QUOTA | awk '{print $5}') = "-" -a $current_used -ge ${size%%G*} ]) &&  [ "$force" != "yes" ] ; then
        echo -e "ERROR: Quota entered is less than OR equal to current user quota"
        exit 1
fi

## Quota modification
ssh $HOST shares select $SHARE select $FILESYSTEM users select $username set quota=${size} >/dev/null 2>&1

echo -e "\nNew quota:"
ssh $HOST shares select $SHARE select $FILESYSTEM users list | awk '{print "user" ,$2,$3,$4}' |grep $username
