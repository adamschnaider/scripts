#!/bin/bash
##################################################################################################
## Backups rotation script
##      Synosys: hertmp3_cleaner.sh
##      Return:  exit code
##      Example: hertmp3_cleaner.sh
die(){
exit 1
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
#################################################################
LOGSIZE=300
LOGFILEPTH=$(dirname $0)/hertmp3.cleaner.log
USR_REVOKE_LIST=()
#RECIPIENTS=yuribu@mellanox.com
#RECIPIENTS=yuribu@mellanox.com,it_storage@mellanox.com
TEMP_FILE=$($MKTEMP)
#NFS_PATH="10g.mtlisilon:/ifs/MLNX_DATA/hertmp3";
NFS_PATH="mtlzfs01.yok.mtl.com:/export/BE/hertmp3";
TTL=7
MountPoint="/mnt/hertmp3$$"
###############################################################################
functions_path="/mtlfs01/home/yokadm/Monitors/functions"
contact_list_path="/mtlfs01/home/yokadm/Monitors/Contact_Groups"
grp="IT_BASIC"
# Sanity check
host=$(hostname) && host=${host%%\.*}
if [ $host != "sysmon" -a $host != "sysmon02" ];then
	die
fi
# Source
. ${functions_path}/bashIFS.bash
. ${functions_path}/mail/sendMail.bash
. ${functions_path}/Contact_Management/contact_management_functions.bash
sender="HERTMP3 AUTOMATIC CLEANER"

# Write to log file
wrLog(){
[ ! -d ${LOGFILEPTH} ] && $MKDIR ${LOGFILEPTH}
$ECHO "$(date) $(hostname) $0[$$]: $1" >> ${LOGFILEPTH}/log.0
}

# Perform log rotation
rotateLog(){

[ ! -f ${LOGFILEPTH}/log ] && $LN -s ${LOGFILEPTH}/log.0 ${LOGFILEPTH}/log
[ ! -f ${LOGFILEPTH}/log.0 ] && $TOUCH ${LOGFILEPTH}/log.0
[ ! -f ${LOGFILEPTH}/log.1 ] && $TOUCH ${LOGFILEPTH}/log.1
[ ! -f ${LOGFILEPTH}/log.2 ] && $TOUCH ${LOGFILEPTH}/log.2
[ ! -f ${LOGFILEPTH}/log.3 ] && $TOUCH ${LOGFILEPTH}/log.3
[ ! -f ${LOGFILEPTH}/log.4 ] && $TOUCH ${LOGFILEPTH}/log.4

if [ $(du -sk ${LOGFILEPTH}/log.0 | awk '{print $1}') -gt ${LOGSIZE} ]; then
        $MV ${LOGFILEPTH}/log.3 ${LOGFILEPTH}/log.4
        $MV ${LOGFILEPTH}/log.2 ${LOGFILEPTH}/log.3
        $MV ${LOGFILEPTH}/log.1 ${LOGFILEPTH}/log.2
        $MV ${LOGFILEPTH}/log.0 ${LOGFILEPTH}/log.1
        $TOUCH ${LOGFILEPTH}/log.0
fi
}

rotateLog
##########################################################################################################
wrLog "-I- $sender START"
wrLog "-I- NFS PATH IS SET TO ${NFS_PATH}, MOUNTPOINT IS SET TO ${MountPoint}"
wrLog "-I- TRYING TO CREATE MOUNTPOINT ${MountPoint}"
# Create mount point
if ! /bin/mkdir ${MountPoint};then
	wrLog "-E- FAILED TO CREATE DIRECTORY ${MountPoint}, terminating..."
	sendMail "${sender}" "-E- FAILED TO CREATE DIRECTORY ${MountPoint}" $(getMails IT_UNIX)
    die
fi

# Try to mount the mountpoint
wrLog "-I- MOUNTPOINT ${MountPoint} CREATED"
wrLog "-I- TRYING TO MOUNT NFS PATH ${NFS_PATH} TO ${MountPoint}..." 
if ! /bin/mount ${NFS_PATH} ${MountPoint};then
	wrLog "-E- FAILED TO MOUNT ${NFS_PATH} TO ${MountPoint}, terminatting"
	sendMail "${sender}" "-E- FAILED TO MOUNT ${NFS_PATH} TO ${MountPoint}" $(getMails IT_UNIX)
    die
fi


wrLog "-I- MOUNTED NFS PATH ${NFS_PATH} TO  ${MountPoint} CREATED"
for project in $(ls ${MountPoint}/);do
wrLog "-I- CHECKING PROJECT ${MountPoint}/${project} DIRECTORY"
	for user in $(ls ${MountPoint}/${project}/);do
		wrLog "-I-  CHECKING USER=${user} - ${MountPoint}/${project}/${user} DIRECTORY"
		for area in $(ls ${MountPoint}/${project}/${user}/);do
			wrLog "-I-      CHECKING AREA=${area} ${MountPoint}/${project}/${user}/${area} DIRECTORY"
                        # verify that area is not symbolic link poiting to non-hertmp3 area
                        if [ -L ${MountPoint}/${project}/${user}/${area} ] ; then
                                wrLog "-W-      area=${area} is a symbolic link, skipping"
                                continue
                        fi
            objectsAmount=0
			filesAmount=0

            objectsAmount=$(find ${MountPoint}/${project}/${user}/${area} -atime -${TTL} -print |wc -l)
            # Delete whole area if all objects inside have not been accessed for last 7 days
            if [ $objectsAmount -eq 0 ] ; then
                wrLog "-I-      No objects found which were accessed during last $TTL days in ${MountPoint}/${project}/${user}/${area}"
                wrLog "-I-      Deleting AREA=${MountPoint}/${project}/${user}/${area}"
					if [ -d "${MountPoint}/${project}/${user}/${area}" -a "X${MountPoint}" != "X" -a "X${user}" != "X" -a "X${project}" != "X" -a "X${area}" != "X" ] ;then
						    /bin/rm -rf ${MountPoint}/${project}/${user}/${area}
                        # go to next iteration since current area has been removed
                        continue
					fi
            fi
            wrLog "-I-      Will try to delete every file in ${MountPoint}/${project}/${user}/${area} which has not been accessed for last $TTL days"
            # Delete every file in ${MountPoint}/${project}/${user}/${area} which has not been accessed  area if all objects inside have not been accessed for last 7 days
            #for fileToDel in $(find ${MountPoint}/${project}/${user}/${area} -maxdepth 1 -type f -atime -${TTL} -print ) ; do
            # -${TTL} - File was accessed TTL days ago
            # ${TTL}  - Matches files accessed less than two days ago
            for fileToDel in $(find ${MountPoint}/${project}/${user}/${area} -maxdepth 1 -type f -atime ${TTL} -print ) ; do
                wrLog "-I-      Deleting file $fileToDel in AREA=${MountPoint}/${project}/${user}/${area}"
			    /bin/rm -f ${fileToDel}
            done
            wrLog "-I-      DONE."

			for cell in $(ls ${MountPoint}/${project}/${user}/${area}/);do
				wrLog "-I-          CHECKING CELL=${cell}  ${MountPoint}/${project}/${user}/${area}/${cell} DIRECTORY"
                            # verify that area is not symbolic link poiting to non-hertmp3 area
                            if [ -L ${MountPoint}/${project}/${user}/${area}/${cell} ] ; then
                                    wrLog "-W-      cell=${cell} is a symbolic link, skipping"
                                    continue
                            fi
                if [ -f ${MountPoint}/${project}/${user}/${area}/${cell} ] ; then
                    wrLog "-W-          CELL=${cell} ${MountPoint}/${project}/${user}/${area}/${cell} is a file, skipping..."
                    continue
                fi
				filesAmount=$(find ${MountPoint}/${project}/${user}/${area}/${cell} -type f -atime -${TTL} -print |wc -l)
				#### We use 'f' type because direcotry access time changes every time we make find via it, due to this its not reliable to do it on directories.
				#### Instead we check if there are files newer than $TTL days within directory, if not the whole directory will be removed.
				if [ ${filesAmount} -eq 0 ];then
					wrLog "-I-          NO FILES WHICH HAD ACCESS TIME NEWER THAN ${TTL} DAYS"
					wrLog "-I-          DELETED ${MountPoint}/${project}/${user}/${area}/${cell}"
					if [ -d "${MountPoint}/${project}/${user}/${area}/${cell}" -a "X${MountPoint}" != "X" -a "X${user}" != "X" -a "X${project}" != "X" -a "X${area}" != "X" -a "X${cell}" != "X" ] ;then
                                        /bin/rm -rf ${MountPoint}/${project}/${user}/${area}/${cell}

					fi
				else
					wrLog "-I-          RETAIN ${MountPoint}/${project}/${user}/${area}/${cell}, SINCE HAS ${filesAmount} FILES NEWER THAN ${TTL} days"
				fi
				wrLog "-I-           CELL=${cell} ${MountPoint}/${project}/${user}/${area}/${cell} CHECK FINISHED"
			done
				wrLog "-I-      AREA=${area} ${MountPoint}/${project}/${user}/${area} CHECK FINISHED"
		done
        # Deleting old and empty user directories using find -mtime
        if [[ $(ls ${MountPoint}/${project}/${user}/ | wc -l) -eq 0 && $(find ${MountPoint}/${project}/${user} -type d -mtime -${TTL} -print |wc -l) -eq 0 ]]; then
            wrLog "-I-  Deleting user directory ${MountPoint}/${project}/${user} which is empty and has not been modified for last $TTL days"
            rmdir ${MountPoint}/${project}/${user}
        fi
		wrLog "-I-  USER=${user} ${MountPoint}/${project}/${user} CHECK FINISHED"
	done
	wrLog i"-I- PROJECT=${project} ${MountPoint}/${project} CHECK FINISHED"
done
wrLog "-I- HERTMP3 CLEANING PROCEDURE FINISHED"
wrLog "-I- TRYING TO UNMOUNT ${MountPoint} "
if ! /bin/umount ${MountPoint};then
	wrLog "-E- FAILED TO UNMOUNT ${MountPoint}, terminatting"
	sendMail "${sender}" "-E- FAILED TO UNMOUNT ${MountPoint}" $(getMails IT_UNIX)
    die
fi

wrLog "-I- ${MountPoint} UNMOUNTED"
wrLog "-I- TRYING TO REMOVE MOUNTPOINT ${MountPoint}"
if ! /bin/rmdir ${MountPoint};then
	wrLog "-E- FAILED TO REMOVE DIRECTORY ${MountPoint}, terminatting"
	sendMail "${sender}" "-E- FAILED TO REMOVE DIRECTORY ${MountPoint}" $(getMails IT_UNIX)
    die
fi
wrLog "-I- REMOVED MOUNTPOINT ${MountPoint}"

wrLog "-I- $sender END"
exit 0
