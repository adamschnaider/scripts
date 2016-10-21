#!/bin/bash

### standard funtion stack ###
functions_path="/home/yokadm/Monitors/functions"
. ${functions_path}/Contact_Management/contact_management_functions.bash
. ${functions_path}/bashIFS.bash
. ${functions_path}/sms/sendSMS.bash
. ${functions_path}/mail/sendMail.bash

SCRIPT_NAME=${0##*/} && SCRIPT_NAME=${SCRIPT_NAME%.*}
configuration_file=$(dirname $0)/${SCRIPT_NAME}.cfg
queue_directory=$(dirname $0)/locks
sender="IsilonMon"
#notifGroup=IT_STORAGE

[ ! -d ${queue_directory} ] && mkdir ${queue_directory}

tmp_path=/tmp
default_capacity_limit=89
high_capacity_limit=97

capacity_limit=$default_capacity_limit

tmpDIR=/tmp
workingNode=10g.mtlisilon

function lockExport()
{
        export=$(/bin/echo ${2} |/bin/sed 's/\.//g'| /bin/sed  's/\//./g')
        /bin/touch $(dirname $0)/locks/${1}.${export:1:${#export}}
}
function unlockExport()
{
        export=$(/bin/echo ${2} | /bin/sed 's/\.//g'| /bin/sed  's/\//./g')
        /bin/rm -f $(dirname $0)/locks/${1}.${export:1:${#export}}
}
function isExportLocked()
{
        export=$(/bin/echo ${2} | /bin/sed 's/\.//g'| /bin/sed  's/\//./g')
        [ -f $(dirname $0)/locks/${1}.${export:1:${#export}} ] && return 0
        return 1
}

cat /proc/mounts | grep "10g.mtlisilon.yok.mtl.com:/ifs/MLNX_DATA/IT /mnt/10g.mtlisilon_IT" > /dev/null 2>&1
[ "$?" -ne 0 ] && echo "Error: Isilon is not mounted" && exit 1
IFS=$'\n'

currExportUtil=$(df /mnt/10g.mtlisilon_IT|tail -1 |awk '{print $5}' | sed 's/%//')
currExport=/ifs/MLNX_DATA
notifGroup=IT_STORAGE
if [ ${currExportUtil} -gt ${capacity_limit} ] ; then
	if isExportLocked ${workingNode} ${currExport} ; then
		splitByLines
		sendMail "${sender} " "- WARNING - Export ${currExport} Still Have Space Problems ${currExportUtil}% Utilization" $(getMails ${notifGroup})
		if [ ${currExportUtil} -gt ${high_capacity_limit} ] ; then
			sendSMS ${sender} "- WARNING - Export ${currExport} Still Have Space Problems ${currExportUtil}% Utilization" $(getPhones ${notifGroup})
		fi
		splitByDefault
		#/bin/echo "still problems"
	else
		sendMail "${sender} " "- WARNING - Export ${currExport} Have Space Problems ${currExportUtil}% Utilization" $(getMails ${notifGroup})
		sendSMS ${sender} "- WARNING - Export ${currExport} Have Space Problems ${currExportUtil}% Utilization" $(getPhones ${notifGroup})
		splitByDefault
		lockExport ${workingNode} ${currExport}
		#/bin/echo "problems"
	fi
else
	if isExportLocked ${workingNode} ${currExport} ; then
		sendMail "${sender} " "- WARNING - Export ${currExport} Space Problems Resolved" $(getMails ${notifGroup})
		sendSMS ${sender} "- WARNING - Export ${currExport} Space Problems Resolved" $(getPhones ${notifGroup})
		splitByDefault
		unlockExport ${workingNode} ${currExport}
		#/bin/echo "problems resolved"
	fi
fi
