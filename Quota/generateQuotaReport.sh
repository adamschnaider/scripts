#!/bin/bash

HOSTNAME=/bin/hostname
SSH=/usr/bin/ssh
RSH=/usr/bin/rsh

LOCKFILE=$(dirname $0)/${0##*/}.lock

[ -f $LOCKFILE ] && exit 1

/bin/touch $LOCKFILE


executeViaSSH(){
    $SSH -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o LogLevel=quiet -o PasswordAuthentication=no -o BatchMode=yes -o ConnectTimeout=1 -o ConnectionAttempts=1 $1 "$2"
}


setConfigBySite(){

SELF_NAME=$($HOSTNAME -s)

    case $SELF_NAME in 
            mtdkx*)
                NetAppList="mtdkfs01 mtdkfs02"
                IsilonList=""
                ZFSList=""
		VNXList=""
                DST_FILER=mtdkfs01
            ;;
            mtix*)
                NetAppList="mtifseda"
                IsilonList=""
                ZFSList=""
		VNXList=""
                DST_FILER=mtifseda
            ;;
            *)
                NetAppList="mtlfs01 mtlfs03 labfs01 labfs02 mtrlabfs01 mtrlabfs02 mtdkfs01 mtdkfs02 manasfs1 manasfs2"
		NetAppCdotList="mtbufsprd-mtbufshw"
                IsilonList="10g.mtlisilon"
                ZFSList="mtlzfs01"
		VNXList="vnx7600-cs0"
                DST_FILER=mtlfs01
    esac

    quota_file_path=/${DST_FILER}/home/yokadm/tmp/quotaOutFormatedAll.tmp
    quota_file_path_tmp=/${DST_FILER}/home/yokadm/tmp/quotaOutFormatedAllTemp.tmp
    isi_output_tmp=/${DST_FILER}/home/yokadm/tmp/isi_tmp
    zfs_output_tmp=/${DST_FILER}/home/yokadm/tmp/zfs_tmp
    vnx_output_tmp=/${DST_FILER}/home/yokadm/tmp/vnx_tmp
}

getScaleInG()
{
        local property=$1
        if [ "${property//[0-9.]}X" = "TX" ]
        then
                property=$( echo "${property//[a-zA-Z]} * 1024"|bc -l )
        elif [ "${property//[0-9.]}X" = "GX" ]
        then
                property=${property//[a-zA-Z]}
        elif [ "${property//[0-9.]}X" = "MX" ]
        then
                property=$(echo "${property//[a-zA-Z]} / 1024"|bc -l )
        elif [ "${property//[0-9.]}X" = "KX" ]
        then
                property=$(echo "${property//[a-zA-Z]} / 1048576"|bc -l)
        elif [ "${property//[0-9.]}X" = "bX" ]
        then
                property=0
        fi
        echo $property
}
function initQuotaFile()
{
	/bin/echo "" > ${quota_file_path_tmp}
}


function getVNXQuotas()
{
ssh root@ezhp "ypcat passwd" > $vnx_output_tmp
for VNXHost in $VNXList ; do
	IFS=$'\n'
	for share in $(executeViaSSH nasadmin@${VNXHost} "source /home/nasadmin/.bash_profile >/dev/null; nas_fs -list" | awk '$4 == "1" {print $0}'| awk '{print $7, $8}' |grep -v root) ; do
		vnxDM=$(echo $share | awk '{print $2}')
		let vnxDM=${vnxDM}+1
		shareName=$(echo $share | awk '{print $1}')
		for line in $(executeViaSSH nasadmin@${VNXHost} "source /home/nasadmin/.bash_profile >/dev/null; nas_quotas -report -user -fs ${shareName}" |grep '#') ; do
			objtype=user
			username=$(echo $line |awk -F'|' '{print $2}'|sed 's/#//;s/^[ \t]*//;s/[ \t]*$//')
			[[ -e $vnx_output_tmp ]] && username=$(awk -F':' -v var="$username" '$3 == var { print $1 }' $vnx_output_tmp)
			path=${shareName}
			quota="$(echo $line | awk -F'|' '{print $4}' | sed 's/^[ \t]*//;s/[ \t]*$//')K"
			used="$(echo $line | awk -F'|' '{print $3}' | sed 's/^[ \t]*//;s/[ \t]*$//')K"
			if [[ ${quota} == "0" ]] ; then
				#echo "no quota defined"
				quota=1
				quotaUnlimited=1
			fi
			usedG=$(getScaleInG ${used})
			quotaG=$(getScaleInG ${quota})
			if [ "${used}X" = "0KX" ] ; then
				usedPrcnt=0
			else
				if [ "${usedG:0:1}" = "." ] ; then
					usedG="0${usedG}"
				fi
				if [ "${quotaG:0:1}" = "." ] ; then
					quotaG="0${quotaG}"
				fi
				if [ $(/bin/echo "${quotaG} == 0" | /usr/bin/bc -l) -eq 1 ] ; then
					usedPrcnt=100
				else
					usedPrcnt=$(/bin/echo "scale=2;${usedG} / ${quotaG} * 100" | /usr/bin/bc -l)
				fi
			fi
			if [ -z ${quotaUnlimited} ] ; then
				printf '%-15s %-12s %-15s %-40s %-9.1f %-9.2f %-9s\n' "vnxdm${vnxDM}" "$objtype" "$username" "$path" "$quotaG" "$usedG" "${usedPrcnt//.*}" >> ${quota_file_path_tmp}
			else
				printf '%-15s %-12s %-15s %-40s %-9s %-9.2f %-9s\n' "vnxdm${vnxDM}" "$objtype" "$username" "$path" "0" "$usedG" "${usedPrcnt//.*}" >> ${quota_file_path_tmp}
			fi
			unset quotaUnlimited
		done
		shareProp=$(executeViaSSH nasadmin@${VNXHost} "source /home/nasadmin/.bash_profile >/dev/null; nas_fs -size $shareName| head -1")
		objtype=directory
		username=na
		path=${shareName}
		quota="$(/bin/echo ${shareProp} | /bin/awk '{print $3}')M"
		used="$(/bin/echo ${shareProp} | /bin/awk '{print $9}')M"
		if [[ ${quota} == "0" ]] ; then
	                #echo "no quota defined"
	                quota=1
	                quotaUnlimited=1
                fi
		usedG=$(getScaleInG ${used})
		quotaG=$(getScaleInG ${quota})
		if [ "${used}X" = "0KX" ] ; then
                        usedPrcnt=0
                else
                	if [ "${usedG:0:1}" = "." ] ; then
                        	usedG="0${usedG}"
                        fi
                        if [ "${quotaG:0:1}" = "." ] ; then
	                        quotaG="0${quotaG}"
                        fi
                        if [ $(/bin/echo "${quotaG} == 0" | /usr/bin/bc -l) -eq 1 ] ; then
        	                usedPrcnt=100
                        else
                	        usedPrcnt=$(/bin/echo "scale=2;${usedG} / ${quotaG} * 100" | /usr/bin/bc -l)
                        fi
                fi
		if [ -z ${quotaUnlimited} ] ; then
			printf '%-15s %-12s %-15s %-40s %-9.1f %-9.2f %-9s\n' "vnxdm${vnxDM}" "$objtype" "$username" "$path" "$quotaG" "$usedG" "${usedPrcnt//.*}" >> ${quota_file_path_tmp}
		else
			printf '%-15s %-12s %-15s %-40s %-9s %-9.2f %-9s\n' "vnxdm${vnxDM}" "$objtype" "$username" "$path" "0" "$usedG" "${usedPrcnt//.*}" >> ${quota_file_path_tmp}
		fi
		unset quotaUnlimited
	done
	unset IFS
done
}

function getZFSQuotas()
{
tmpDIR=/tmp
for ZFSHost in $ZFSList ; do
	IFS=$'\n'
	for project in $(executeViaSSH $ZFSHost "shares list") ; do
		for share in $(executeViaSSH $ZFSHost "shares select $project list"|tail -n +5 |awk '{print $1}') ; do
			for line in $(executeViaSSH $ZFSHost "shares select $project select $share users list" | tail -n +2) ; do
				objtype=user
				username=$(echo $line | awk '{print $2}')
				path=$share
				quota=$(echo $line | awk '{print $4}')
				used=$(echo $line | awk '{print $3}')
				if [[ ${quota} =~ - ]] ; then
					#echo "no quota defined"
					quota=1
					quotaUnlimited=1
				fi
				usedG=$(getScaleInG ${used})
				quotaG=$(getScaleInG ${quota})
				if [ "${used}X" = "0bX" ] ; then
					usedPrcnt=0
				else
					if [ "${usedG:0:1}" = "." ] ; then
						usedG="0${usedG}"
					fi
					if [ "${quotaG:0:1}" = "." ] ; then
						quotaG="0${quotaG}"
					fi
					if [ $(/bin/echo "${quotaG} == 0" | /usr/bin/bc -l) -eq 1 ] ; then
						usedPrcnt=100
					else
						usedPrcnt=$(/bin/echo "scale=2;${usedG} / ${quotaG} * 100" | /usr/bin/bc -l)
					fi
				fi
				if [ -z ${quotaUnlimited} ] ; then
					printf '%-15s %-12s %-15s %-40s %-9.1f %-9.2f %-9s\n' "$ZFSHost" "$objtype" "$username" "$path" "$quotaG" "$usedG" "${usedPrcnt//.*}" >> ${quota_file_path_tmp}
				else
					printf '%-15s %-12s %-15s %-40s %-9s %-9.2f %-9s\n' "$ZFSHost" "$objtype" "$username" "$path" "0" "$usedG" "${usedPrcnt//.*}" >> ${quota_file_path_tmp}
				fi
				unset quotaUnlimited
			done
		shareProper=$(executeViaSSH $ZFSHost "shares select $project select $share get quota space_data")
		objtype=directory
		username=na
		path=$share
		quota=$(echo $shareProper | awk '{print $3}')
		used=$(echo $shareProper | awk '{print $6}')
		if [[ ${quota} == '0' ]] ; then
			quota=1
			quotaUnlimited=1
		fi
		usedG=$(getScaleInG ${used})
		quotaG=$(getScaleInG ${quota})
		if [ "${used}X" = "0bX" ] ; then
			usedPrcnt=0
		else
			if [ "${usedG:0:1}" = "." ] ; then
	                        usedG="0${usedG}"
			fi
			if [ "${quotaG:0:1}" = "." ] ; then
				quotaG="0${quotaG}"
			fi
			if [ $(/bin/echo "${quotaG} == 0" | /usr/bin/bc -l) -eq 1 ] ; then
				usedPrcnt=100
			else
				usedPrcnt=$(/bin/echo "scale=2;${usedG} / ${quotaG} * 100" | /usr/bin/bc -l)
			fi
		fi
		if [ -z ${quotaUnlimited} ] ; then
			printf '%-15s %-12s %-15s %-40s %-9.1f %-9.2f %-9s\n' "$ZFSHost" "$objtype" "$username" "$path" "$quotaG" "$usedG" "${usedPrcnt//.*}" >> ${quota_file_path_tmp}
		else
			printf '%-15s %-12s %-15s %-40s %-9s %-9.2f %-9s\n' "$ZFSHost" "$objtype" "$username" "$path" "0" "$usedG" "${usedPrcnt//.*}" >> ${quota_file_path_tmp}
		fi
		unset quotaUnlimited
		done
	done
	unset IFS
done
}

function getIsiQuotas()
{
tmpDIR=/tmp

for IsiHost in $IsilonList ; do
    executeViaSSH $IsiHost "isi quota list |sed 's/~//'| egrep -w 'user|group|directory' | egrep -v '^default-user|\*' " > ${isi_output_tmp}
    IFS=$'\n'
    for line in $(/bin/cat ${isi_output_tmp}) ; do
        mainobjtype=$(/bin/echo ${line} | /bin/awk '{print $1}')
        if /bin/echo $mainobjtype | /bin/grep ':' -q ; then
            objtype=$(/bin/echo ${line} | /bin/awk '{print $1}' | /bin/awk -F':' '{print $1}')
        else
            objtype=$mainobjtype
        fi
        if [ $objtype = "directory" ] ; then
            username=na
        else
            username=$(/bin/echo ${line} | /bin/awk '{print $2}')
            username=${username//NTYOK.MTL.COM\\}
        fi
        path=$(/bin/echo ${line} | /bin/awk '{print $3}')
        quota=$(/bin/echo ${line} | /bin/awk '{print $5}')
        used=$(/bin/echo ${line}| /bin/awk '{print $8}')
        if [[ ${quota} =~ - ]] ; then
            #echo "no quota defined"
            quota=1
    	    quotaUnlimited=1
        fi
        usedG=$(getScaleInG ${used})
        quotaG=$(getScaleInG ${quota})
        
        if [ "${used}X" = "0bX" ] ; then
            usedPrcnt=0
        else
            if [ "${usedG:0:1}" = "." ]
                    then
                        usedG="0${usedG}"
                    fi
                    if [ "${quotaG:0:1}" = "." ]
                    then
                        quotaG="0${quotaG}"
                    fi
            if [ $(/bin/echo "${quotaG} == 0" | /usr/bin/bc -l) -eq 1 ] ; then
                usedPrcnt=100
            else
            usedPrcnt=$(/bin/echo "scale=2;${usedG} / ${quotaG} * 100" | /usr/bin/bc -l)
            fi
        fi
	    if [ -z ${quotaUnlimited} ] ; then
                printf '%-15s %-12s %-15s %-40s %-9.1f %-9.2f %-9s\n' "$IsiHost" "$objtype" "$username" "$path" "$quotaG" "$usedG" "${usedPrcnt//.*}" >> ${quota_file_path_tmp}
	    else
		printf '%-15s %-12s %-15s %-40s %-9s %-9.2f %-9s\n' "$IsiHost" "$objtype" "$username" "$path" "0" "$usedG" "${usedPrcnt//.*}" >> ${quota_file_path_tmp}
	    fi
        unset quotaUnlimited
        done
    /bin/rm -f ${isi_output_tmp}
    unset IFS
done
}

function getNetAppQuotas()
{
tmpDIR=/tmp
for filer in $NetAppList ; do
	IFS=$'\n'
	host=$filer
	for line in $($RSH $host "quota report" |grep -w -v root |  tail -n +4 | grep -v Adminis|grep -v terminalProfiles) ; do
        	mainobjtype=$(/bin/echo ${line} | /bin/awk '{print $1}')
		if [ $mainobjtype = "tree" ] ; then
			mainobjtype=directory
		fi
        	if /bin/echo $mainobjtype | /bin/grep ':' -q ; then
                	objtype=$(/bin/echo ${line} | /bin/awk '{print $1}' | /bin/awk -F':' '{print $1}')
        	else
                	objtype=$mainobjtype
        	fi
        	if [ $objtype = "directory" ] ; then
                	username=na
        	else
                	username=$(/bin/echo ${line} | /bin/awk '{print $2}')
        	fi
        	path="/vol/$(/bin/echo ${line} | /bin/awk '{print $3}')/$(/bin/echo ${line} | /bin/awk '{print $4}')"
        	quota="$(/bin/echo ${line} | /bin/awk '{print $6}')K"
        	used="$(/bin/echo ${line}| /bin/awk '{print $5}')K"
		if [[ ${quota} =~ - ]] ; then
			#echo "no quota defined"
			quota=1
			quotaUnlimited=1
		fi
		if [ "${used}X" = "0X" ] ; then
                	usedPrcnt=0
        	else
                	usedG=$(getScaleInG ${used})
                	quotaG=$(getScaleInG ${quota})
			if [ "${usedG:0:1}" = "." ]
                        then
                                usedG="0${usedG}"
                        fi
			if [ "${quotaG:0:1}" = "." ]
                        then
                                quotaG="0${quotaG}"
                        fi
			if [ $(/bin/echo "${quotaG} == 0" | /usr/bin/bc -l) -eq 1 ] ; then
				usedPrcnt=100
			else
				usedPrcnt=$(/bin/echo "scale=2;${usedG} / ${quotaG} * 100" | /usr/bin/bc -l)
			fi
        	fi
		if [ -z ${quotaUnlimited} ] ; then
			printf '%-15s %-12s %-15s %-40s %-9.1f %-9.2f %-9s\n' "$host" "$objtype" "$username" "$path" "$quotaG" "$usedG" "${usedPrcnt//.*}" >> ${quota_file_path_tmp}
		else
			printf '%-15s %-12s %-15s %-40s %-9s %-9.2f %-9s\n' "$host" "$objtype" "$username" "$path" "0" "$usedG" "${usedPrcnt//.*}" >> ${quota_file_path_tmp}
		fi
		unset quotaUnlimited
	done
done
unset IFS
}
function getNetAppCdotQuotas()
{
tmpDIR=/tmp
for filer in $NetAppCdotList ; do
        IFS=$'\n'
        host=$(echo $filer | awk -F'-' '{print $1}')
	vserver=$(echo $filer | awk -F'-' '{print $2}')
        for line in $(executeViaSSH admin@${host} "set -units KB; quota report -fields quota-type ,quota-target ,volume ,tree ,disk-used ,disk-limit -vserver ${vserver}" | tail  -n +4 | head -n -2) ; do
                mainobjtype=$(/bin/echo ${line} | /bin/awk '{print $5}')
                if [ $mainobjtype = "tree" ] ; then
                        mainobjtype=directory
                fi
                if /bin/echo $mainobjtype | /bin/grep ':' -q ; then
                        objtype=$(/bin/echo ${line} | /bin/awk '{print $1}' | /bin/awk -F':' '{print $1}')
                else
                        objtype=$mainobjtype
                fi
                if [ $objtype = "directory" ] ; then
                        username=na
                else
                        username=$(/bin/echo ${line} | /bin/awk '{print $6}')
                fi
                path="/vol/$(/bin/echo ${line} | /bin/awk '{print $2}')/$(/bin/echo ${line} | /bin/awk '{print $4}')"
                quota="$(/bin/echo ${line} | sed 's/KB//g' | /bin/awk '{print $8}')K"
                used="$(/bin/echo ${line} | sed 's/KB//g' | /bin/awk '{print $7}')K"
                if [[ ${quota} =~ - ]] ; then
                        #echo "no quota defined"
                        quota=1
                        quotaUnlimited=1
                fi
                if [ "${used}X" = "0X" ] ; then
                        usedPrcnt=0
                else
                        usedG=$(getScaleInG ${used})
                        quotaG=$(getScaleInG ${quota})
                        if [ "${usedG:0:1}" = "." ]
                        then
                                usedG="0${usedG}"
                        fi
                        if [ "${quotaG:0:1}" = "." ]
                        then
                                quotaG="0${quotaG}"
                        fi
                        if [ $(/bin/echo "${quotaG} == 0" | /usr/bin/bc -l) -eq 1 ] ; then
                                usedPrcnt=100
                        else
                                usedPrcnt=$(/bin/echo "scale=2;${usedG} / ${quotaG} * 100" | /usr/bin/bc -l)
                        fi
                fi
                if [ -z ${quotaUnlimited} ] ; then
                        printf '%-15s %-12s %-15s %-40s %-9.1f %-9.2f %-9s\n' "$vserver" "$objtype" "$username" "$path" "$quotaG" "$usedG" "${usedPrcnt//.*}" >> ${quota_file_path_tmp}
                else
                        printf '%-15s %-12s %-15s %-40s %-9s %-9.2f %-9s\n' "$vserver" "$objtype" "$username" "$path" "0" "$usedG" "${usedPrcnt//.*}" >> ${quota_file_path_tmp}
                fi
                unset quotaUnlimited
        done
done
unset IFS
}

function postActivities()
{
/bin/cp ${quota_file_path_tmp} ${quota_file_path}
/bin/rm -f ${quota_file_path_tmp}
}
setConfigBySite
initQuotaFile
getVNXQuotas
getZFSQuotas
getNetAppQuotas
getNetAppCdotQuotas
getIsiQuotas
postActivities
/bin/rm -f $LOCKFILE
