#!/bin/sh 
### standard funtion stack ###
functions_path="/home/yokadm/Monitors/functions"
. ${functions_path}/Contact_Management/contact_management_functions.bash
. ${functions_path}/bashIFS.bash
. ${functions_path}/sms/sendSMS.bash
. ${functions_path}/mail/sendMail.bash

SCRIPT_NAME=${0##*/} && SCRIPT_NAME=${SCRIPT_NAME%.*}
configuration_file=$(dirname $0)/${SCRIPT_NAME}.cfg 
queue_directory=$(dirname $0)/queue
sender="StorageMon"

[ ! -d ${queue_directory} ] && mkdir ${queue_directory}

default_capacity_limit=92
high_capacity_limit=98

checkVolCapacity(){
[ $(\rsh ${1} "df -g ${2}" | egrep -v ".snapshot|^Filesystem|snap reserve"|awk '{print $5}'|awk '{sub(/%/,"");print}') -gt ${capacity_limit} ] && echo $(\rsh ${1} "df -g ${2}" | egrep -v ".snapshot|^Filesystem|snap reserve"|awk '{print $5}'|awk '{sub(/%/,"");print}') > $(dirname $0)/capacity.tmp && return 1
return 0
}

generateQtreeStats()
{

for filer in $(/bin/cat ${configuration_file} | /bin/awk '{print $3}' | /bin/sort -u) ; do
	\rsh ${filer} "quota report" > $(dirname $0)/${filer}.quota
done

}


checkQtreeCapacity(){
/bin/grep -w ${3} $(dirname $0)/${1}.quota | /bin/grep -w ${2} > $(dirname $0)/getQtreeCapacity.$$
local used=$(awk '{print $5}' $(dirname $0)/getQtreeCapacity.$$)
local total=$(awk '{print $6}' $(dirname $0)/getQtreeCapacity.$$)
\rm -f $(dirname $0)/getQtreeCapacity.$$
local pCapacity=$(echo "scale=2;(${used} / ${total})*100"| bc -l)
local returnCode=$(echo "${pCapacity} > ${capacity_limit}" | bc -l)

echo ${pCapacity}| sed 's/\..*$//' > $(dirname $0)/capacity.tmp
return ${returnCode}
}

generateQtreeStats

splitByLines
for configuration_entry in $(grep -v '#' ${configuration_file});do
	
	filer=$(echo ${configuration_entry}|awk '{print $3}')
	object=$(echo ${configuration_entry}|awk '{print $1}')
	object_type=$(echo ${configuration_entry}|awk '{print $2}')
	[ "X${object_type}" = "XVolume" ] && callFuncName=checkVolCapacity && fullObject=$(echo ${filer}_${object}) && fullMountPath=$(echo ${configuration_entry} | awk -F':' '{print $1}' | awk '{print $5}')
	[ "X${object_type}" = "XQtree" ] && callFuncName=checkQtreeCapacity && fullQtreePath=$(echo ${configuration_entry} | awk '{print $5}') && fullObject=$(echo ${filer}_${object}) && fullMountPath=$(echo ${configuration_entry} | awk -F':' '{print $1}' | awk '{print $6}')
	#filer=$(echo ${configuration_entry}|awk '{print $3}')
	#notification_group=$(echo ${configuration_entry}|awk '{print $4}')
	notification_group=IT_STORAGE_adams
	capacity_limit=$(echo ${configuration_entry} | awk -F':' '{print $2}')
	[ -z ${capacity_limit} ] && capacity_limit=${default_capacity_limit}
	if ! ${callFuncName} ${filer} ${object} ${fullQtreePath} ; then
		capacity=$(cat $(dirname $0)/capacity.tmp)
		if [ -f ${queue_directory}/${fullObject} ] ; then
			if [ -z $fullMountPath ]; then
				sendMail "${sender} " "${object_type}_${fullObject}_Still_Have_Space_Problems_${capacity}%_Utilization" $(getMails ${notification_group})
				if [ $capacity -ge $high_capacity_limit ] ; then
					sendSMS ${sender} "${object_type}_${fullObject}_Still_Have_Space_Problems_${capacity}%_Utilization" $(getPhones ${notification_group})
				fi
			else
				sendMail "${sender} " "Directory: $fullMountPath is ${capacity}% full. Please take action and delete/archive/zip unnecessary files and folders. ${object_type}_${fullObject}_Still_Have_Space_Problems_${capacity}%_Utilization" $(getMails ${notification_group})
				if [ $capacity -ge $high_capacity_limit ] ; then
					sendSMS ${sender} "Directory: $fullMountPath is ${capacity}% full. Please take action and delete/archive/zip unnecessary files and folders. ${object_type}_${fullObject}_Still_Have_Space_Problems_${capacity}%_Utilization" $(getPhones ${notification_group})
				fi
			fi	
		else
			capacity=$(cat $(dirname $0)/capacity.tmp)
			if [ -z $fullMountPath ]; then
				sendMail "${sender} " "${object_type}_${fullObject}_Have_Space_Problems_${capacity}%_Utilization" $(getMails ${notification_group})
				sendSMS ${sender} "${object_type}_${fullObject}_Have_Space_Problems_${capacity}%_Utilization" $(getPhones ${notification_group})
				touch ${queue_directory}/${fullObject}
			else
				sendMail "${sender} " "Directory: $fullMountPath is ${capacity}% full. Please take action and delete/archive/zip unnecessary files and folders. ${object_type}_${fullObject}_Have_Space_Problems_${capacity}%_Utilization" $(getMails ${notification_group})
				sendSMS ${sender} "Directory: $fullMountPath is ${capacity}% full. Please take action and delete/archive/zip unnecessary files and folders. ${object_type}_${fullObject}_Have_Space_Problems_${capacity}%_Utilization" $(getPhones ${notification_group})
				touch ${queue_directory}/${fullObject}
			fi
		fi
	else
		if [ -f ${queue_directory}/${fullObject} ] ; then
			if [ -z $fullMountPath ]; then
				sendMail "${sender} " "${object_type}_${fullObject}_Space_Problems_Resolved" $(getMails ${notification_group})
        	                sendSMS ${sender} "${object_type}_${fullObject}_Space_Problems_Resolved" $(getPhones ${notification_group})
	                        \rm -f ${queue_directory}/${fullObject}
			else
				sendMail "${sender} " "Directory: $fullMountPath space problem resolved" $(getMails ${notification_group})
				sendSMS ${sender} "Directory: $fullMountPath space problem resolved" $(getPhones ${notification_group})
				\rm -f ${queue_directory}/${fullObject}
			fi
		fi
	fi
	[ -f $(dirname $0)/capacity.tmp ] && \rm -f $(dirname $0)/capacity.tmp
done

splitByLines
for configuration_entry in $(grep ^'##' ${configuration_file});do

        filer=$(echo ${configuration_entry}|awk '{print $3}')
        object=$(echo ${configuration_entry}|awk '{print $1}'|sed 's/##//g')
        object_type=$(echo ${configuration_entry}|awk '{print $2}')
        [ "X${object_type}" = "XVolume" ] && callFuncName=checkVolCapacity && fullObject=$(echo ${filer}_${object}) && fullMountPath=$(echo ${configuration_entry} | awk -F':' '{print $1}' | awk '{print $5}')
        [ "X${object_type}" = "XQtree" ] && callFuncName=checkQtreeCapacity && fullQtreePath=$(echo ${configuration_entry} | awk '{print $5}') && fullObject=$(echo ${filer}_${object}) && fullMountPath=$(echo ${configuration_entry} | awk -F':' '{print $1}' | awk '{print $6}')
        #filer=$(echo ${configuration_entry}|awk '{print $3}')
        #notification_group=$(echo ${configuration_entry}|awk '{print $4}')
        notification_group=IT_STORAGE_adams
        capacity_limit=$(echo ${configuration_entry} | awk -F':' '{print $2}')
        [ -z ${capacity_limit} ] && capacity_limit=${default_capacity_limit}
        if ! ${callFuncName} ${filer} ${object} ${fullQtreePath} ; then
                capacity=$(cat $(dirname $0)/capacity.tmp)
                if [ -f ${queue_directory}/${fullObject} ] ; then
                        if [ -z $fullMountPath ]; then
                                sendMail "${sender} " "${object_type}_${fullObject}_Still_Have_Space_Problems_${capacity}%_Utilization" $(getMails ${notification_group})
                                if [ $capacity -ge $high_capacity_limit ] ; then
                                        sendSMS ${sender} "${object_type}_${fullObject}_Still_Have_Space_Problems_${capacity}%_Utilization" $(getPhones ${notification_group})
                                fi
                        elif [ $filer == "mtlfs01" -a $object_type == "Qtree" -a $fullQtreePath == "/vol/vol1" ]; then
	                        recipient=`find $fullMountPath -maxdepth 1 -mtime -30 -exec ls -ld {} \; | awk '{print $3}'| uniq -u | sed -e 's/ /@mellanox.com /g' |sed -e 's/$/@mellanox.com/g'`
				echo -e "Directory: $fullMountPath is ${capacity}% full, please take actions and delete/archive/zip unnecessary files and folders. \n\nLatest user access log: $(find $fullMountPath -maxdepth 1 -mtime -30 -exec ls -ld {} \; |awk 'BEGIN{print "Latest user access log:\n"}{if(NF>2){print "User",$3,"accessed subdir "substr($0, index($0,$9))" on:",$6,$7,$8"\n"}}')" | mail -s "${sender}: $fullMountPath"  adams@mellanox.com
			else
                                sendMail "${sender} " "Directory: $fullMountPath is ${capacity}% full. Please take action and delete/archive/zip unnecessary files and folders. ${object_type}_${fullObject}_Still_Have_Space_Problems_${capacity}%_Utilization" $(getMails ${notification_group})
                                if [ $capacity -ge $high_capacity_limit ] ; then
                                        sendSMS ${sender} "Directory: $fullMountPath is ${capacity}% full. Please take action and delete/archive/zip unnecessary files and folders. ${object_type}_${fullObject}_Still_Have_Space_Problems_${capacity}%_Utilization" $(getPhones ${notification_group})
                                fi
                        fi
		else
                      capacity=$(cat $(dirname $0)/capacity.tmp)
                      if [ -z $fullMountPath ]; then
                                sendMail "${sender} " "${object_type}_${fullObject}_Have_Space_Problems_${capacity}%_Utilization" $(getMails ${notification_group})
                                sendSMS ${sender} "${object_type}_${fullObject}_Have_Space_Problems_${capacity}%_Utilization" $(getPhones ${notification_group})
                                touch ${queue_directory}/${fullObject}
                        else
                                sendMail "${sender} " "Directory: $fullMountPath is ${capacity}% full. Please take action and delete/archive/zip unnecessary files and folders. ${object_type}_${fullObject}_Have_Space_Problems_${capacity}%_Utilization" $(getMails ${notification_group})
                                sendSMS ${sender} "Directory: $fullMountPath is ${capacity}% full. Please take action and delete/archive/zip unnecessary files and folders. ${object_type}_${fullObject}_Have_Space_Problems_${capacity}%_Utilization" $(getPhones ${notification_group})
                                touch ${queue_directory}/${fullObject}
                        fi
                fi
	else
		if [ -f ${queue_directory}/${fullObject} ] ; then
                        if [ -z $fullMountPath ]; then
                                sendMail "${sender} " "${object_type}_${fullObject}_Space_Problems_Resolved" $(getMails ${notification_group})
                                sendSMS ${sender} "${object_type}_${fullObject}_Space_Problems_Resolved" $(getPhones ${notification_group})
                                \rm -f ${queue_directory}/${fullObject}
                        else
                                sendMail "${sender} " "Directory: $fullMountPath space problem resolved" $(getMails ${notification_group})
                                sendSMS ${sender} "Directory: $fullMountPath space problem resolved" $(getPhones ${notification_group})
                                \rm -f ${queue_directory}/${fullObject}
                        fi
                fi
        fi
        [ -f $(dirname $0)/capacity.tmp ] && \rm -f $(dirname $0)/capacity.tmp
done
