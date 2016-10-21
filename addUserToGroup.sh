#!/bin/bash

TR=/usr/bin/tr
ECHO=/bin/echo
AWK=/bin/awk
MKDIR=/bin/mkdir
RMDIR=/bin/rmdir
#################################################
SEMAPHORE=/var/lock/${0##*/}
#################################################

mklock(){
    if ! $MKDIR $SEMAPHORE
    then
        $ECHO "FATAL: Lock already exists. Another copy is running or manually lock clean up required."
        exit 1001
    fi
}

rmlock(){
    [[ ! -d $SEMAPHORE ]] \
        && $ECHO "WARNING: Lock is missing. $SEMAPHORE does not exist" \
        || $RMDIR $SEMAPHORE
}

__sig_exit(){

    [[ -e $SEMAPHORE ]] && rmlock
}

__sig_int(){
    echo -e "\nWARNING: SIGINT caught" && rmlock
    exit 1002
}

__sig_quit(){
    echo -e "\nSIGQUIT caught" && rmlock
    exit 1003
}

__sig_term(){
    echo -e "\nWARNING: SIGTERM caught" && rmlock
    exit 1015
}

trap __sig_exit EXIT    # SIGEXIT
trap __sig_int INT      # SIGINT
trap __sig_quit QUIT    # SIGQUIT
trap __sig_term TERM    # SIGTERM


# Create semaphore
mklock


if [ "X${USER}" != "Xroot" ] ; then
  if [ "X$USER" = "Xhelpdesk" ] ; then
        echo "-E- Please run as following '/usr/bin/sudo /home/yokadm/etc/nis/adduser.sh'"
  else echo "-E- You are not allowed to run this script"
  fi
 exit 1
fi

[ "X$(/bin/hostname -f)" != "Xmtlxnis.yok.mtl.com" ] && /bin/echo "-E- $0 must be run only from mtlxnis.yok.mtl.com host" && exit 1

/bin/echo -n "Enter Username: "
read user

# [YB] Force lower case for user name
user=$($ECHO $user | $TR '[:upper:]' '[:lower:]')

[ "X${user}" = "X" ] && /bin/echo "-E- Empty username is not allowed" && exit 1

if ! $(ypmatch ${user} passwd > /dev/null 2>&1) 
then
	/bin/echo "-E- User doesn't exists" && exit 1

fi

name=$(ypmatch ${user} passwd|awk -F':' '{print $5}')

/bin/echo -n "Enter Group Name: "
read group

[ "X${group}" = "X" ] && /bin/echo "-E- Empty group name is not allowed" && exit 1

if ! $(ypmatch ${group} group > /dev/null 2>&1)
then
        /bin/echo "-E- Group doesn't exists" && exit 1

fi

echo ""
echo "Adding user to group:"
echo "Username: $user"
echo "Full Name: $name"
echo "Group: $group"
echo "To STOP press ^C to CONTINUE press enter"
read stop

# Copy current configuration
cp -p /etc/passwd{,.`date +%d%m%y_%H%M`_`echo "$(($RANDOM % 10))"`}
cp -p /etc/group{,.`date +%d%m%y_%H%M`_`echo "$(($RANDOM % 10))"`}


/usr/sbin/usermod -a -G $group $user #2> /dev/null

if [ "$?" -ne "0" ]
then
	/bin/echo "-E- User Add Operation Failed" && exit 1
else
	/bin/echo -e "User Successfully Added To Group\n"
fi

/usr/bin/make -C /var/yp

if [ "$?" -ne "0" ]
then
        /bin/echo "-E- NIS Update Operation Failed" && exit 1
else
        /bin/echo -e "\nNIS is updated with the new changes, Done\n"
fi

rmlock
