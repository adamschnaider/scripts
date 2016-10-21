#!/bin/bash

ok=0
usage(){
        echo "Usage $0: <Oracle Volume> <Clone Snapshot> [file|volume]"
        exit 1
}
[ $UID -ne 0 ] && exit 1
[ "X$1" = "X" ] && usage

SCRIPT_NAME=${0##*/} && SCRIPT_NAME=${SCRIPT_NAME%%.*}

### Source block ###
sender="OraClone"
sendTO="IT_STOR_BASIC_ERP_LOGS"
functions_path="/mtlfs01/home/yokadm/Monitors/functions"
functions_path="/root"
Netapp=mtlfsprd
. ${functions_path}/bashIFS.bash
#. ${functions_path}/sms/sendSMS.bash
#. ${functions_path}/mail/sendMail.bash
#. ${functions_path}/Contact_Management/contact_management_functions.bash
### Source block end ###

notificationGroup=IT_STOR_BASIC_ERP_LOGS

tmpRndFile="/tmp/output.${RANDOM}.$$"
vol=$1
shift
[[ "X${vol}" = "X" ]] && usage
snapshot=$1
shift
[[ "X${snapshot}" = "X" ]] && usage
guarantee_type=${1}
if [ "X${guarantee_type}" = "Xfile" ] ; then
         guarantee_type=file
fi
if [ "X${guarantee_type}" = "Xvolume" ] ; then
         guarantee_type=volume
fi
if [ "X${guarantee_type}" != "Xvolume" ] ; then
        if [ "X${guarantee_type}" != "Xfile" ] ; then
                guarantee_type=volume
        fi
fi


tmpPATHa=/tmp/OracleVolumes.$$
tmpPATHb=/tmp/OracleSnapshots.$$
getOracleVolumes(){
\ssh $Netapp -l avin vol show | grep oracle | awk '{print $2}' > ${tmpPATHa}
}
getOracleSnapshots(){
\ssh $Netapp -l avin snapshot show -volume vol_oracle_prod -fields snapshot|awk '{print $3}' |tail -n +3|sed '/^$/d' > ${tmpPATHb}
}
dieIfProd(){
                if [ "X${1}" = "Xvol_oracle_prod" ];then
                        echo "-E- Cannot destroy production volume"
                        echo "-E- Terminating"
                        splitByLines
                        #sendMail "${sender}:-E- $1 volume is a production volume" "- ERROR - ${sender} $1 volume is a production volume, terminating." $(getMails ${sendTO})
                        #sendSMS ${sender} "- ERROR - $1 volume is a production volume, terminating." $(getPhones ${sendTO})
                        splitByDefault
                        exit 1
                fi
}
makeNewUsage(){
local extra=$(echo "${1//[a-zA-Z]} * 0.2" | bc -l)
local suffix;
case $1 in
        [0-9]*TB)
                suffix=t;
                ;;
        [0-9]*GB)
                suffix=g;
                ;;
        [0-9]*MB)
                suffix=m;
                ;;
        [0-9]*KB)
                suffix=m;
                ;;
        esac
echo ${extra}${suffix}
}
makeSuffix(){
local extra=$(echo "${1//[a-zA-Z]} * 0.2" | bc -l)
local local;
case $1 in
        [0-9]*TB)
                value="${1//[a-zA-Z]}t";
                ;;
        [0-9]*GB)
                value="${1//[a-zA-Z]}g";
                ;;
        [0-9]*MB)
                value="${1//[a-zA-Z]}m";
                ;;
        [0-9]*KB)
                value="${1//[a-zA-Z]}k";
                ;;
        esac
echo ${value}
}
dieIfLackOfCapacity()
{
local workingAggr=$(/usr/bin/ssh $Netapp -l avin "vol show -volume ${1} -instance" | grep "Aggregate Name"|awk '{print $3}')
local workingAggrCapacity=$(/usr/bin/ssh $Netapp -l avin "df -aggregates $workingAggr -fs-type active -fields available-space -g" | tail -n +3| awk '{print $4}'|sed '/^$/d'| /bin/sed "s/[A-Za-z]//g"| sed '/^$/d')
local oracleProdCapacity=$(/usr/bin/ssh $Netapp -l avin "df -g -volume vol_oracle_prod -fs-type active" |tail -n +2| /bin/awk '{print $2}'| sed '/^$/d' | /bin/sed "s/[A-Za-z]//g"| sed '/^$/d')


if [ ${workingAggrCapacity} -lt ${oracleProdCapacity} ]; then
        echo "-E- WARNING - ${SCRIPT_NAME} - NOT ENOUGH SPACE ON CONTAINING AGGREGATE, VOLUME CLONE ABORTED"
        echo "-I- Sending SMS & MAIL Notification"
        #sendSMS $sender "WARNING - ${SCRIPT_NAME} - NOT ENOUGH SPACE ON CONTAINING AGGREGATE, VOLUME CLONE ABORTED" $(getPhones ${notificationGroup})
        #sendMail "$sender WARNING - ${SCRIPT_NAME} - NOT ENOUGH SPACE ON CONTAINING AGGREGATE, VOLUME CLONE ABORTED" "NOT ENOUGH SPACE ON CONTAINING AGGREAGE, VOLUME CLONE ABORTED" $(getMails ${notificationGroup})
        exit 1
fi
}
ping -c 3 $Netapp > /dev/null 2>&1
if [ "$?" == "0" ];then
                getOracleVolumes
                getOracleSnapshots
                if ! grep -w $vol ${tmpPATHa};then
                        echo "-E- ${vol} volume does not exists"
                        echo "-E- Terminating"
                        splitByLines
                        #sendMail "${sender}:-E- ${vol} volume does not exist" "- ERROR - ${sender} ${vol} volume does not exist, terminating." $(getMails ${sendTO})
                        #sendSMS ${sender} "- ERROR - ${vol} volume does not exist, terminating." $(getPhones ${sendTO})
                        splitByDefault
                        exit 1
                fi
                dieIfProd ${vol}
                if ! grep -w $snapshot ${tmpPATHb}; then
                        echo "-E- ${snapshot} snapshot does not exists"
                        echo "-E- Terminating"
                        splitByLines
                        #sendMail "${sender}:-E- ${snapshot} snapshot does not exist" "- ERROR - ${sender} ${snapshot} snapshot does not exist, terminating." $(getMails ${sendTO})
                        #sendSMS ${sender} "- ERROR - ${snapshot} snapshot does not exist, terminating." $(getPhones ${sendTO})
                        splitByDefault
                        exit 1
                fi
                dieIfLackOfCapacity ${vol}
                newVolsize=$(/usr/bin/ssh $Netapp -l avin "df -g" | /bin/grep -i vol_oracle_prod | /bin/grep -v .snapshot | /bin/awk '{print $3}' | /bin/awk '{sub(/GB/,"  ")}1' | /bin/awk '{print $1*1.1}'|/bin/sed 's/\.[0-9]*//g')
                echo "-I- Arguments are OK."
                echo "-I- Proceeding"
                       echo "-I- Making reserve copy of exports"
                       #/bin/cp /mtlfsora01/etc/exports /tmp/exports.$$
                       export_pol=$(/usr/bin/ssh $Netapp -l avin "volume show $vol -fields policy" | tail -n +3|awk '{print $3}'|sed '/^$/d')
                       echo "-I- DONE."
                       echo "-I- Restricting volume $vol"
                       \ssh $Netapp -l avin "vol restrict -vserver mtlfsora $vol"
                       echo "-I- DONE."
                       echo "-I- Bringing offline volume $vol"
                       \ssh $Netapp -l avin "vol offline -vserver mtlfsora $vol"
                       echo "-I- DONE."
                       echo "-I- Destroying volume $vol"
                       \ssh $Netapp -l avin "vol destroy -vserver mtlfsora $vol -f"
                       echo "-I- DONE."
                       echo "-I- Deleting snapshot snapshot.$vol"
                       \ssh $Netapp -l avin "snap delete -vserver mtlfsora vol_oracle_prod flex_for_${vol}"
                       echo "-I- DONE."
                       echo "-I- Renaming snapshot ${snapshot} to flex_for_${vol}"
                       \ssh $Netapp -l avin "snap rename -vserver mtlfsora vol_oracle_prod ${snapshot} flex_for_${vol}"
                       echo "-I- DONE."
                       echo "-I- Volume ${vol} destroyed"
                       echo "-I- Cloning Volume from vol_oracle_prod snapshot flex_for_${vol} to ${vol}"
                       \ssh $Netapp -l avin "vol clone create -vserver mtlfsora -flexclone ${vol} -parent-volume vol_oracle_prod -space-guarantee ${guarantee_type} -parent-snapshot flex_for_${vol}"
                       echo "-I- DONE."
                       echo "-I- Setting snapshot reserve to 0"
                       \ssh $Netapp -l avin "vol modify -vserver mtlfsora ${vol} -percent-snapshot-space 0"
                       echo "-I- DONE."
                       echo "-I- Setting snapshot schedule to 0"
                       \ssh $Netapp -l avin "vol modify -vserver mtlfsora ${vol} -snapshot-policy none"
                       echo "-I- DONE."
                       #echo "-I- Setting snapshot schedule to 0"
                       #\ssh $Netapp -l avin "snap sched ${vol} 0"
                       #echo "-I- DONE."
                       echo "-I- Setting ${vol} Volume capacity to used*1.1"
                       \ssh $Netapp -l avin "vol size -vserver mtlfsora ${vol} ${newVolsize}g"
                       echo "-I- DONE."
                       \ssh $Netapp -l avin "volume modify -vserver mtlfsora ${vol} -policy $export_pol"
                       #/bin/cp /tmp/exports.$$ /mtlfsora01/etc/exports
                       #\ssh $Netapp -l avin "exportfs -a"
                       echo "-I- DONE."
                       echo "-I- FINISHED."
else
                        echo "-E- $Netapp is not responding"
                        echo "-E- Terminating"
                        splitByLines
                        #sendMail "${sender}:-E- /mtlfsora01/etc/ not mounted on sysmon" "- ERROR - ${sender} /mtlfsora01/etc/ not mounted on sysmon, terminating." $(getMails ${sendTO})
                        #sendSMS ${sender} "- ERROR - /mtlfsora01/etc/ not mounted on sysmon, terminating." $(getPhones ${sendTO})
                        splitByDefault
                        \rm -f ${tmpPATHa}
                        \rm -f ${tmpPATHb}
                        exit 1
fi
\rm -f ${tmpPATHa}
\rm -f ${tmpPATHb}
