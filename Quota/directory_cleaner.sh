#!/bin/bash
#################################################
## 	Directory clean script:			#
##      Synosys: directory_cleaner.sh		#
##      Return:  exit code			#
#################################################

die(){
rm -f $TEMP_FILE
exit 1
}

msg_first_alert()
{
cat << EOF
Hello,

Automatic cleaning script under ${MountPoint}/${project}/${user} found the following files older than $FIRST_ALERT_TTL days:
`echo "$FTTL_objectsAmount"`

Files older than $TTL will be deleted.

Regards,
IT Department
Note: Please do not reply to this email.
EOF
}

msg_second_alert()
{
cat << EOF
Hello,

Automatic cleaning script under ${MountPoint}/${project}/${user} found the following files older than $SECOND_ALERT_TTL days:
`echo "$STTL_objectsAmount"`

Files older than $TTL will be deleted.

Regards,
IT Department
Note: Please do not reply to this email.
EOF
}

msg_delete_area()
{
cat << EOF
Hello,

Automatic cleaning script under ${MountPoint}/${project}/${user} found the following files older than $TTL days:
`echo "$objectsUnderTTL"`

FILES WILL BE DELETED.

Regards,
IT Department
Note: Please do not reply to this email.
EOF
}

msg_delete_file()
{
cat << EOF
Hello,

Automatic cleaning script under ${MountPoint}/${project}/${user} found the following files older than $TTL days:
`echo "$TTL_objectsAmount"`

FILES WILL BE DELETED IN $(( $DTTL - $TTL )) DAYS

Regards,
IT Department
Note: Please do not reply to this email.
EOF
}

#################################################################

STAT=/usr/bin/stat
ID=/usr/bin/id
GETENT=/usr/bin/getent
AWK=/bin/awk
USERMOD=/usr/sbin/usermod
LN=/bin/ln
MV=/bin/mv
TOUCH=/bin/touch
ECHO=/bin/echo
MKDIR=/bin/mkdir
RM=/bin/rm
RMDIR=/bin/rmdir
GREP=/bin/grep
WC=/usr/bin/wc
MKTEMP=/bin/mktemp
DATE=/bin/date
CAT=/bin/cat

###############################################################################

LOGSIZE=300
#LOGFILEPATH=$(dirname $0)/hertmp3.cleaner.log
#LOGFILEPATH=$(basename $0) && LOGFILEPATH=${LOGFILEPATH%%.*}.log
USR_REVOKE_LIST=()
TEMP_FILE=$($MKTEMP)
#NFS_PATH="10g.mtlisilon:/ifs/MLNX_DATA/hertmp3";
#NFS_PATH="mtlzfs01.yok.mtl.com:/export/BE/hertmp3";
NFS_PATH="mtlfs03.yok.mtl.com:/vol/adams_test"
FIRST_ALERT_TTL=20
SECOND_ALERT_TTL=25
TTL=30
DTTL=35
#LAST_ALERT_TTL=25
## Minimun file size to search (MB)
MINSIZE="499M"
#MountPoint="/mnt/hertmp3$$"
#MountPoint="/mnt/mtlfs03_adams_test_$$"
MountPoint="/usr/backend3"
FILESYSTEM="backend3"

###############################################################################

#functions_path="/mtlfs01/home/yokadm/Monitors/functions"
functions_path="/home/yokadm/Monitors/functions"
#contact_list_path="/mtlfs01/home/yokadm/Monitors/Contact_Groups"
contact_list_path="/home/yokadm/Monitors/Contact_Groups"

#GROUP="IT_STORAGE"
GROUP="IT_STORAGE_adams"

# Sanity check
host=$(hostname) && host=${host%%\.*}
if [ $host != "sysmon" -a $host != "sysmon02" -a $host != "mtlstadm01" ];then
	die
fi
# Source
. ${functions_path}/bashIFS.bash
. ${functions_path}/mail/sendMail.bash
. ${functions_path}/Contact_Management/contact_management_functions.bash

. /root/scripts/functions/LogHandler.bash
USERLOGFILEPATH="${LOGFILEPATH}/USER"
sender="AUTOMATIC CLEANER TESTING"

rotateLog
###############################################################################
wrLog "-I- $sender START"
wrLog "-I- NFS PATH IS SET TO ${NFS_PATH}, MOUNTPOINT IS SET TO ${MountPoint}"
wrLog "-I- TRYING TO CREATE MOUNTPOINT ${MountPoint}"
# Create mount point
if ! /bin/mkdir ${MountPoint};then
	wrLog "-E- FAILED TO CREATE DIRECTORY ${MountPoint}, terminating..."
	sendMail "${sender}" "-E- FAILED TO CREATE DIRECTORY ${MountPoint}" $(getMails $GROUP)
    die
fi

# Try to mount the mountpoint
wrLog "-I- MOUNTPOINT ${MountPoint} CREATED"
wrLog "-I- TRYING TO MOUNT NFS PATH ${NFS_PATH} TO ${MountPoint}..." 
if ! /bin/mount ${NFS_PATH} ${MountPoint};then
	wrLog "-E- FAILED TO MOUNT ${NFS_PATH} TO ${MountPoint}, terminatting"
	sendMail "${sender}" "-E- FAILED TO MOUNT ${NFS_PATH} TO ${MountPoint}" $(getMails $GROUP)
    die
fi
wrLog "-I- MOUNTED NFS PATH ${NFS_PATH} TO ${MountPoint} CREATED"

# Create USER log directory
if [ ! -d ${USERLOGFILEPATH} ];then
	wrLog "-I- TRYING TO CREATE USER LOG DIRECTORY ${USERLOGFILEPATH}"
	if ! /bin/mkdir ${USERLOGFILEPATH}; then
		wrLog "-E- FAILED TO CREATE USER LOG DIRECTORY ${USERLOGFILEPATH}"
		sendMail "${sender}" "-E- FAILED TO CREATE USER LOG DIRECTORY ${USERLOGFILEPATH}"
		die
	fi
fi

splitByLines
for project in $(ls ${MountPoint}/);do
wrLog "-I- CHECKING PROJECT=${project} on  ${MountPoint}/${project} DIRECTORY"
	for user in $(ls ${MountPoint}/${project}/);do
		wrLog "-I- 	CHECKING USER=${user} on ${MountPoint}/${project}/${user} DIRECTORY"
		#objectsUnderTTL=$(find ${MountPoint}/${project}/${user}/${area} -atime -${TTL} -print )
		FTTL_objectsAmount=$(find ${MountPoint}/${project}/${user}/${area} -type f -size +${MINSIZE} -atime +${FIRST_ALERT_TTL} -atime -${SECOND_ALERT_TTL} -print )
		### STTL_objectsAmount=$(find ${MountPoint}/${project}/${user}/${area} -type f -size +${MINSIZE} -atime +${SECOND_ALERT_TTL} -atime -${LAST_ALERT_TTL} -print )
		STTL_objectsAmount=$(find ${MountPoint}/${project}/${user}/${area} -type f -size +${MINSIZE} -atime +${SECOND_ALERT_TTL} -atime -${TTL} -print )
		### LTTL_objectsAmount=$(find ${MountPoint}/${project}/${user}/${area} -type f -size +${MINSIZE} -atime +${LAST_ALERT_TTL} -atime -${TTL} -print )
		TTL_objectsAmount=$(find ${MountPoint}/${project}/${user}/${area} -type f -size +${MINSIZE} -atime +${TTL} -print )
		### # Delete whole area if all objects inside have not been accessed for last $TTL days
		### if [ -z "$objectsUnderTTL" ] ; then
		### 	wrLog "-I- 		No objects found which were accessed during last $TTL days in ${MountPoint}/${project}/${user}/${area}"
		###	wrLog "-D- 		Deleting AREA=${MountPoint}/${project}/${user}/${area}"
		###	if [ -d "${MountPoint}/${project}/${user}/${area}" -a "X${MountPoint}" != "X" -a "X${user}" != "X" -a "X${project}" != "X" -a "X${area}" != "X" ] ;then
		###		### /bin/rm -rf ${MountPoint}/${project}/${user}/${area}
		###		msg_delete_area | mail -s "Automatic cleaning on $FILESYSTEM" ${user}@mellanox.com
		###		# go to next iteration since current area has been removed
		###		continue
		###	fi
		### fi
		wrLog "-I- 		Will try to delete every file in ${MountPoint}/${project}/${user} which has not been accessed for last $TTL days"
		# Delete every file in ${MountPoint}/${project}/${user}/${area} which has not been accessed area if all objects inside have not been accessed for last 7 days
		#for fileToDel in $(find ${MountPoint}/${project}/${user}/${area} -maxdepth 1 -type f -atime -${TTL} -print ) ; do
		# -${TTL} - File was accessed TTL days ago
		# ${TTL}  - Matches files accessed less than two days ago
		###            for fileToDel in $(find ${MountPoint}/${project}/${user}/${area} -maxdepth 1 -type f -atime ${TTL} -print ) ; do
		###                wrLog "-D-      Deleting file $fileToDel in AREA=${MountPoint}/${project}/${user}/${area}"
		###			    /bin/rm -f ${fileToDel}
		###            done
		###            wrLog "-I-      DONE."
		if [ ! -z $FTTL_objectsAmount ];then
			wrLog "-I-		Sending USER:${user} first alert mail on files that haven't accessed between ${FIRST_ALERT_TTL}-${SECOND_ALERT_TTL} days ago"
			msg_first_alert | mail -s "Automatic cleaning on $FILESYSTEM" ${user}@mellanox.com
		fi
		if [ ! -z $STTL_objectsAmount ];then
			wrLog "-I-		Sending USER:${user} second alert mail on files that haven't accessed between ${SECOND_ALERT_TTL}-${TTL} days ago"
			msg_second_alert | mail -s "Automatic cleaning on $FILESYSTEM" ${user}@mellanox.com
		fi
		if [ ! -z $TTL_objectsAmount ];then
			wrLog "-D-		Deleting files: $TTL_objectsAmount"
			wrLog "-I-		Sending USER:${user} mail on files to delete which exceeded access time of $TTL days ago"
			msg_delete_file | mail -s "Automatic cleaning on $FILESYSTEM" ${user}@mellanox.com
				
		fi
		### if [ -d ${MountPoint}/${project}/${user}/${area}/ ];then
		###	for cell in $(ls ${MountPoint}/${project}/${user}/${area}/);do
		###		wrLog "-I- 			CHECKING CELL=${cell}  ${MountPoint}/${project}/${user}/${area}/${cell} DIRECTORY"
		###		# verify that area is not symbolic link poiting to non-hertmp3 area
		###		if [ -d ${MountPoint}/${project}/${user}/${area}/${cell} ] ; then
		###			filesAmount=$(ls ${MountPoint}/${project}/${user}/${area}/${cell} |wc -l)
		###			if [ ${filesAmount} -eq 0 ];then
		###				wrLog "-I- 			NO FILES UNDER ${MountPoint}/${project}/${user}/${area}/${cell}, DELETING DIRECTORY"
		###				if [ "X${MountPoint}" != "X" -a "X${user}" != "X" -a "X${project}" != "X" -a "X${area}" != "X" -a "X${cell}" != "X" ] ;then
		###					if /bin/rmdir ${MountPoint}/${project}/${user}/${area}/${cell}; then
		###						wrLog "-D- 			DELETED ${MountPoint}/${project}/${user}/${area}/${cell}"
		###					else
		###						wrLog "-E- 			FAILED TO DELETE ${MountPoint}/${project}/${user}/${area}/${cell}"
		###						sendMail "${sender}" "-E- FAILED TO DELETE ${MountPoint}/${project}/${user}/${area}/${cell}"
		###					fi
		###				fi
		###			else
		###				continue
		###			fi
		###		fi
		###		wrLog "-I- 			CELL=${cell} ${MountPoint}/${project}/${user}/${area}/${cell} CHECK FINISHED"
		###	done
		###	wrLog "-I- 		AREA=${area} ${MountPoint}/${project}/${user}/${area} CHECK FINISHED"
		### fi
		# Deleting old and empty user directories using find -mtime
		#if [[ $(ls ${MountPoint}/${project}/${user}/ | wc -l) -eq 0 && $(find ${MountPoint}/${project}/${user} -type d -mtime -${TTL} -print |wc -l) -eq 0 ]]; then
		#    wrLog "-D-  Deleting user directory ${MountPoint}/${project}/${user} which is empty and has not been modified for last $TTL days"
		#    rmdir ${MountPoint}/${project}/${user}
		#fi

		wrLog "-I- 	USER=${user} ${MountPoint}/${project}/${user} CHECK FINISHED"
		wrLog "--------------------------"
	done
	wrLog "-I- PROJECT=${project} ${MountPoint}/${project} CHECK FINISHED"
	wrLog "--------------------------------------------------------------------------------"
done
wrLog "-I- CLEANING PROCEDURE FINISHED"
wrLog "-I- TRYING TO UNMOUNT ${MountPoint} "
if ! /bin/umount ${MountPoint};then
	wrLog "-E- FAILED TO UNMOUNT ${MountPoint}, terminatting"
	sendMail "${sender}" "-E- FAILED TO UNMOUNT ${MountPoint}" $(getMails $GROUP)
    die
fi

wrLog "-I- ${MountPoint} UNMOUNTED"
wrLog "-I- TRYING TO REMOVE MOUNTPOINT ${MountPoint}"
if ! /bin/rmdir ${MountPoint};then
	wrLog "-E- FAILED TO REMOVE DIRECTORY ${MountPoint}, terminatting"
	sendMail "${sender}" "-E- FAILED TO REMOVE DIRECTORY ${MountPoint}" $(getMails $GROUP)
    die
fi
wrLog "-I- REMOVED MOUNTPOINT ${MountPoint}"

wrLog "-I- $sender END"
wrLog "-------------------------------------------------------------------------------------------------------------------------------------"
wrLog "-------------------------------------------------------------------------------------------------------------------------------------"
rm -f $TEMP_FILE
exit 0
