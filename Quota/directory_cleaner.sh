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

WARN_MSG()
{
cat << EOF
Hello,

Automatic cleaning script found under ${FILESYSTEM}/${project}/${user} found the following files/directories that weren't accessed $WARN days:
`printf '%s\n' "${WARN_AREA[@]}"`

NOTICE: FILES OLDER THAN $TTL DAYS WILL BE DELETED!

Regards,
IT Department
Note: Please do not reply to this email.
EOF
}

DEL_MSG()
{
cat << EOF
Hello,

Automatic cleaning script found under ${FILESYSTEM}/${project}/${user} the following files/directories that weren't accessed $TTL days:
`printf '%s\n' "${DEL_AREA[@]}"`

NOTICE: FILES AND DIRECTORIES WILL BE DELETED!

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

#functions_path="/mtlfs01/home/yokadm/Monitors/functions"
functions_path="/home/yokadm/Monitors/functions"
#contact_list_path="/mtlfs01/home/yokadm/Monitors/Contact_Groups"
contact_list_path="/home/yokadm/Monitors/Contact_Groups"

#GROUP="IT_STORAGE"
GROUP="IT_STORAGE_adams"

# Source
. ${functions_path}/bashIFS.bash
. ${functions_path}/mail/sendMail.bash
. ${functions_path}/Contact_Management/contact_management_functions.bash
. ${functions_path}/LogHandler.bash

USERLOGFILEPATH="${LOGFILEPATH}/USER"
sender="AUTOMATIC CLEANER TESTING"

rotateLog
wrLog "-I- $sender START"

###############################################################################

# Source config file
if [[ -f $1 ]] && [[ -n $1 ]];then
	wrLog "-I- SOURCING CONFIG FILE: $1"
	source $1
else
	wrLog "-W- CONFIG FILE WASN'T ENTERED, SETTING DEFAULT PARAMETERS"
	USEMAIL="false"
	DELETE="false"
	LOGSIZE=300
	USR_REVOKE_LIST=()
	TEMP_FILE=$($MKTEMP)
	NFS_PATH="mtlfs03.yok.mtl.com:/vol/adams_test"
	TIMESTAMP=$(date +%Y%m%d_%H:%M)
	
	# Data retention (days)
	WARN=120
	TTL=180

	## Minimun file size to search (MB)
	MINSIZE="499M"

	MountPoint="/mnt/mtlfs03_adams_test_$$"
	FILESYSTEM="backend3"
fi

wrLog "-I- VARIABLES: USEMAIL=${USEMAIL}; DELETE=${DELETE}; LOGSIZE=${LOGSIZE} USR_REVOKE_LIST=${USR_REVOKE_LIST[*]}; TEMP_FILE=${NFS_PATH}; NFS_PATH=${NFS_PATH}; TIMESTAMP=${TIMESTAMP}; WARN=${WARN}; TTL=${TTL}; MINSIZE=${MINSIZE}; MountPoint=${MountPoint}; FILESYSTEM=${FILESYSTEM}"

###############################################################################


# Sanity check
host=$(hostname) && host=${host%%\.*}
if [ $host != "sysmon" -a $host != "sysmon02" -a $host != "mtlstadm01" ];then
	wrLog "-E- HOST IS NOT ALLOWED TO RUN $0"
	die
fi

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
		WARN_COUNT=0
		DEL_COUNT=0
		for area in $(ls ${MountPoint}/${project}/${user}/);do
			wrLog "-I- 		CHECKING AREA=${area} on ${MountPoint}/${project}/${user}/${area}"
			TTL_objectsAmount=$(find ${MountPoint}/${project}/${user}/${area} -type f -atime -${TTL} -print)
			if [ ! -z "$TTL_objectsAmount" ]; then
				WARN_objectsAmount=$(find ${MountPoint}/${project}/${user}/${area} -type f -atime -${WARN} -print)
				if [ -z "$WARN_objectsAmount" ]; then
					wrLog "-W- 			AREA ${area} WASN'T ACCESSED FOR ${WARN} DAYS"
					WARN_AREA[$WARN_COUNT]=$area
					let WARN_COUNT=$WARN_COUNT+1
				fi
			else
				wrLog "-D-			AREA ${area} WASN'T ACCESSED FOR ${TTL} DAYS AND WILL BE DELETED"
				DEL_AREA[$DEL_COUNT]=$area
				let DEL_COUNT=$DEL_COUNT+1
			fi
			wrLog "-I-		AREA=${area} ${MountPoint}/${project}/${user}/${area} CHECK FINISHED"
			wrLog "---------------------------------"
		done

	## Logging & Mail
	if [ ! -z "${WARN_AREA}" ];then
		wrLog "-I-		Found areas that haven't accessed $WARN days ago, check: ${USERLOGFILEPATH}/${user}/WARN_${TIMESTAMP} for areas list"
		if [ "$USEMAIL" == "true" ];then
			wrLog "-I-		Sending USER:${user} warning alert mail on areas that haven't accessed $WARN days ago"
			WARN_MSG | mail -s "Automatic cleaning on $FILESYSTEM - WARNING" ${user}@mellanox.com
		fi
		if [ ! -d "${USERLOGFILEPATH}/${user}" ];then
			mkdir ${USERLOGFILEPATH}/${user}
		fi
		printf '%s\n' "${WARN_AREA[@]}" >> ${USERLOGFILEPATH}/${user}/WARN_${TIMESTAMP}
	fi
	
	if [ ! -z "${DEL_AREA}" ];then
		wrLog "-I-		Found areas that haven't accessed $TTL days ago, check: ${USERLOGFILEPATH}/${user}/DELETE_${TIMESTAMP} for areas list"
		if [ "${DELETE}X" == "trueX" ]; then
			wrLog "-D-		Deleting areas older than ${TTL} days: ${DEL_AREA[*]}"
			for object in ${DEL_AREA[@]};do
				wrLog "rm -rf ${MountPoint}/${project}/${user}/${object}"
				wrLog "-D-		Deleting area ${object} completed"
			done
		fi
		if [ "$USEMAIL" == "true" ];then
			wrLog "-I-		Sending USER:${user} mail on areas to delete which exceeded access time of $TTL days ago"
			DEL_MSG | mail -s "Automatic cleaning on $FILESYSTEM - DELETION" ${user}@mellanox.com
		fi
		if [ ! -d ${USERLOGFILEPATH}/${user} ];then
			mkdir ${USERLOGFILEPATH}/${user}
		fi
		printf '%s\n' "${DEL_AREA[@]}" >> ${USERLOGFILEPATH}/${user}/DELETE_${TIMESTAMP}
	fi

		wrLog "-I- 	USER=${user} ${MountPoint}/${project}/${user} CHECK FINISHED"
		wrLog "------------------------------------------------------------------"
		unset DEL_AREA
		unset WARN_AREA
	done
	wrLog "-I- PROJECT=${project} ${MountPoint}/${project} CHECK FINISHED"
	wrLog "-------------------------------------------------------------------------------------------------------------------------------------"
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
