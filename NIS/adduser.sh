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

    [[ -n $SEMAPHORE ]] && rmlock
}

__sig_int(){
    echo "WARNING: SIGINT caught" && rmlock
    exit 1002
}

__sig_quit(){
    echo "SIGQUIT caught" && rmlock
    exit 1003
}

__sig_term(){
    echo "WARNING: SIGTERM caught" && rmlock
    exit 1015
}

trap __sig_exit EXIT    # SIGEXIT
trap __sig_int INT      # SIGINT
trap __sig_quit QUIT    # SIGQUIT
trap __sig_term TERM    # SIGTERM


##############
# Create semaphore
mklock

if [ "X${USER}" != "Xroot" ] ; then
  if [ "X$USER" = "Xhelpdesk" ] ; then
 	echo "-E- Please run as following '/usr/bin/sudo /home/yokadm/etc/nis/adduser.sh'"
  else echo "-E- You are not allowed to run this script"
  fi
 exit 1
fi

# Generate a random password
#  $1 = number of characters; defaults to 32
#  $2 = include special characters; 1 = yes, 0 = no; defaults to 1
function randpass() {
  [ "$2" == "0" ] && CHAR="[:alnum:]" || CHAR="[:graph:]"
    cat /dev/urandom | tr -cd "$CHAR" | head -c ${1:-32}
    echo
}

[ "X$(/bin/hostname -f)" != "Xmtlxnis.yok.mtl.com" ] && /bin/echo "-E- $0 must be run only from mtlxnis.yok.mtl.com host" && exit 1

HOMEDIR=/mnt/home_dirs
AUTOHOME=/etc/auto.home
AUTO_HOME=/etc/auto_home
NEWAUTOHOME=/etc/auto.mtlicdhome
RHOST_FILE=/home/yokadm/etc/rhost_file


if [ ! -d $HOMEDIR ] ; then
	/bin/echo "-E- $HOMEDIR directory does not exist"
	exit 1
else
	if ! /bin/grep $HOMEDIR /proc/mounts >& /dev/null; then
		/bin/echo "-E- $HOMEDIR is not mounted"
		exit 1
	fi
fi

/bin/echo -n "Name  (first, last e.g. David Cohen):"
read name

[ "X${name}" = "X" ] && /bin/echo "-E- Empty name is not allowed" && exit 1

/bin/echo -n "Username:"
read user

# [YB] Force lower case for user name
user=$($ECHO $user | $TR '[:upper:]' '[:lower:]')

/bin/echo -n "Need Chip Design Account (yes/no, default=no):"
read chipdesign

if [ "X${chipdesign}" = "X" ] ; then
	chipdesign=no
fi

[ "X${user}" = "X" ] && /bin/echo "-E- Empty username is not allowed" && exit 1

if /bin/grep -iw ^${user} /etc/passwd; then
	/bin/echo "-E- User with username ${user} already exists, try another $username"
	exit 1
fi

if [ -d ${HOMEDIR}/${user} ] ; then
	/bin/echo "-E- Home directory with ${user} name already exists"
	exit 1
fi

if /bin/grep -wi ^${user} ${AUTOHOME}; then
	/bin/echo "-E- Home directory automount map is already exists in $AUTOHOME"
	exit 1
fi

if /bin/grep -wi ^${user} ${AUTO_HOME}; then
	/bin/echo "-E- Home directory automount map is already exists in ${AUTO_HOME}"
	exit 1
fi

lastUID=$(/usr/bin/ypcat passwd | /bin/awk -F':' '{print $3}' | /bin/grep -E '^[0-9][0-9][0-9][0-9]$' | /bin/sort -n | /usr/bin/tail -n 1)
let uid=$lastUID+1
userSHADOW=${user}:$(/usr/bin/perl -e "print crypt('11Mellanox11',join '', ('.', '/', 0..9, 'A'..'Z', 'a'..'z')[rand 64, rand 64])"):$(perl -e "print int(time() /60 /60 /24)"):14:90:14:::
userPASSWD=${user}:x:${uid}:101:${name}:/home/${user}:/usr/bin/tcsh
auto_home="${user} mtlfs01:/vol/vol0/home/${user}"

echo "Setting New User"
echo "Name: ..... $name"
echo "Account:... $user"
echo "User Id:... $uid" 
echo "Group:..... 101"
echo "Chip Design Account:.. ${chipdesign}"

echo "Adding User $user to NIS"
echo " "
echo "To STOP press ^C to CONTINUE press enter"
read stop

echo $userSHADOW >> /etc/shadow
echo $userPASSWD >> /etc/passwd
# AUTO MOUNT:
# add to auto_home table:
echo $auto_home >> $AUTOHOME
echo $auto_home >> $AUTO_HOME
echo $auto_home >> $NEWAUTOHOME

# Create home directory
mkdir ${HOMEDIR}/${user}
chmod 700 ${HOMEDIR}/${user}
mkdir ${HOMEDIR}/${user}/MyDocuments
mkdir ${HOMEDIR}/${user}/Helpdesk
cp ${HOMEDIR}/yokadm/etc/Helpdesk.exe ${HOMEDIR}/${user}/Helpdesk
cp ${HOMEDIR}/yokadm/etc/Helpdesk.exe ${HOMEDIR}/${user}/Helpdesk

# .LOGIN AND .CSHRC AND .DTPROFILE

ln -s /home/yokadm/mtl/login ${HOMEDIR}/${user}/.login
ln -s /home/yokadm/mtl/cshrc ${HOMEDIR}/${user}/.cshrc
chown root:root ${HOMEDIR}/${user}/.cshrc
cp /home/yokadm/mtl/dtprofile ${HOMEDIR}/${user}/.dtprofile
chown ${user}:mtl ${HOMEDIR}/${user}/.dtprofile

chown -Rh ${user}:mtl ${HOMEDIR}/${user}
chmod 700 ${HOMEDIR}/${user}/MyDocuments

# FLEXLM fix For build tool

mkdir /home/${user}/.flexlmrc/
touch /home/${user}/.flexlmrc/.x
chown -R root:other  /home/${user}/.flexlmrc
chmod -R 444 /home/${user}/.flexlmrc

#creation of .rhosts file
$AWK -v newUser=$user '{print $1" "newUser}' $RHOST_FILE > ${HOMEDIR}/${user}/.rhosts
$ECHO "+ ${user}" >> ${HOMEDIR}/${user}/.rhosts

chown ${user}:mtl ${HOMEDIR}/${user}/.rhosts
chmod 600 ${HOMEDIR}/${user}/.rhosts
#creation of .forward file
echo ${user}@mellanox.com >/home/${user}/.forward

if [ "${chipdesign}" = "no" ] ;then
	randpass | /usr/bin/passwd --stdin ${user}
	/usr/sbin/usermod -s /bin/fault ${user}
fi


/usr/bin/make -C /var/yp

# Create home directory for non-mtl sites
# MTDK
/home/yokadm/etc/nis/addUserHomeDir.sh -u ${user} -s mtdk -f
# MTSP
/home/yokadm/etc/nis/addUserHomeDir.sh -u ${user} -s mtsp -f
##############################################################
rmlock
