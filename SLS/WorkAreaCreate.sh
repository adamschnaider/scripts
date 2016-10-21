#!/bin/bash

args=( $@ )
ISILON="10.5.1.1"
MTLZFS01="10.5.6.223"
LOGFILE="/home/yokadm/etc/nis/WorkAreaCreate.log"

usage() {
cat <<EOF
 This utility is used to create user work area.
 Usage: $0 <username> <location>
 Choose location from following list:

 LAB:
    fwgwork
    swgwork
    mgwork
    vmgwork
    sysgwork
    qa
    mtrsysgwork
    mtrswgwork

RDMZ:
    rdmzsysgwork

 Chip Design (FE):
    veri4
    GL/<project_name>/<version>

 Chip Design (BE):
    backend3/<project_name>
    backend4/<project_name>
    ip/<project_name>
    ip_all/<project_name>
    hertmp2/<project_name>
    hertmp3/<project_name>
    hertmp4/<project_name>
EOF
exit 1
}

SIG_INT() {
  echo -e "\nWARNING: CTRL-C caught, exiting script."
  exit 1
}

trap SIG_INT INT

[[ ${args[2]} == "-f" ]] && force=yes

netapp_workdir() {
filer=$1
path=$2
user=$3
group=$4
perm=$5

[[ $(stat --file-system --format=%T $path) != "nfs" ]] && echo -e "\e[031mError: $path is not mounted on the server\e[0m" && exit 1
local dirName=$(dirname $path)
local dirCheck=$(ls -ld $dirName 2>/dev/null)
[[ -z $dirCheck ]] && echo -e "\e[031mError: Base directory: $dirName does not exist!\e[0m" && exit 1
dirCheck=$(ls -ld $path 2>/dev/null)
[[ -z $dirCheck ]] && echo -e "\e[031mError: Directory: '${workdir}' does not exists!\e[0m" && exit 1
dirCheck=$(ls -ld ${path}/${user} 2>/dev/null)
[[ ! -z $dirCheck ]] && echo -e "\e[031mError: User working directory: '${workdir}/${user}' already exists!\e[0m" && exit 1
ssh root@${filer} qtree create /vol/${workdir}/${user}
[[ ! -d ${path}/${user} ]] && echo -e "\e[031mError: Failed to create working directory!\e[0m" && exit 1
chown ${user}:${group} ${path}/${user}/;chmod $perm ${path}/${user}
echo -n "$name,$user,$workdir/$user,`date`," >> $LOGFILE
echo -e "\n\e[032mDone\e[0m"
}

isilon_workdir() {
path=$1
user=$2
group=$3
perm=$4

#check if dir exist
local dirName=$(dirname $path)
local dirCheck=$(ssh $ISILON ls -ld $dirName 2>/dev/null)
[[ -z $dirCheck ]] && echo -e "\e[031mError: Base directory: $dirName does not exist!\e[0m" && exit 1
dirCheck=$(ssh $ISILON ls -ld $path 2>/dev/null)
[[ -z $dirCheck ]] && echo -e "\e[031mError: Project directory: '$(basename $path)' does not exists!\e[0m" && exit 1
dirCheck=$(ssh $ISILON ls -ld ${path}/${user} 2>/dev/null)
[[ ! -z $dirCheck ]] && echo -e "\e[031mError: User working directory: '${workdir}/${user}' already exists!\e[0m" && exit 1
ssh $ISILON "mkdir ${path}/${user};chown ${user}:${group} ${path}/${user};chmod $perm ${path}/${user}"
echo -n "$name,$user,$workdir/$user,`date`," >> $LOGFILE
echo -e "\n\e[032mDone\e[0m"
}

zfs_workdir() {
path=$1
user=$2
group=$3
perm=$4

[[ $(stat --file-system --format=%T $path) != "nfs" ]] && echo -e "\e[031mError: $path is not mounted on the server\e[0m" && exit 1
local dirName=$(dirname $path)
local dirCheck=$(ls -ld $dirName 2>/dev/null)
[[ -z $dirCheck ]] && echo -e "\e[031mError: Base directory: $dirName does not exist!\e[0m" && exit 1
dirCheck=$(ls -ld $path 2>/dev/null)
[[ -z $dirCheck ]] && echo -e "\e[031mError: Project directory: '$(basename $path)' does not exists under '$(dirname $workdir)' !\e[0m" && exit 1
dirCheck=$(ls -ld ${path}/${user} 2>/dev/null)
[[ ! -z $dirCheck ]] && echo -e "\e[031mError: User working directory: '${workdir}/${user}' already exists!\e[0m" && exit 1
mkdir ${path}/${user};chown ${user}:${group} ${path}/${user};chmod $perm ${path}/${user}
[[ ! -d ${path}/${user} ]] && echo -e "\e[031mError: Failed to create working directory!\e[0m" && exit 1
echo -n "$name,$user,$workdir/$user,`date`," >> $LOGFILE
echo -e "\n\e[032mDone\e[0m"
}

[[ $# -eq '2' || $# -eq '3' ]] && user=${args[0]} && workdir=${args[1]}
[[ ($# -ne 0) && ($# -ne 2) && ($# -ne 3) ]] && echo -e "\e[031mError: Wrong arguments, exiting..\e[0m" && usage

if [ "$#" -eq 0 ]; then
	echo -n "Enter username: "
	read user
	user=$(echo $user | tr '[:upper:]' '[:lower:]')
	[ "X${user}" = "X" ] && /bin/echo -e "\e[031mError: Empty username is not allowed\e[0m" && exit 1
	echo -n "Enter working area: "
	read workdir
fi

if ! $(ypmatch ${user} passwd > /dev/null 2>&1); then echo -e "\e[031mError: User doesn't exists\e[0m" && exit 1; fi

name=$(ypmatch ${user} passwd|awk -F':' '{print $5}')

[[ $(/home/yokadm/bin/quotaReport.sh $user | grep -iE "veri[4-5]|backend[2-4]|/ip/|ip_all/|gwork|qa" | wc -l) -gt 0 ]] && echo -e "\n\e[031mError: User has already one or more working directories\n\e[0m" && /home/yokadm/bin/quotaReport.sh $user | (head -2 ; grep -iE "veri[4-5]|backend[2-4]|/ip/|ip_all/|gwork|qa")

if [ -z $force ]; then
	echo -e "\nApprove following details:"
	echo "Username: $user"
	echo "Full Name: $name"
	echo "Working directory: $workdir"
	echo -e "To \e[031mSTOP\e[0m press ^C to \e[032mCONTINUE\e[0m press enter"
	read stop
fi

case "$workdir" in
	veri4 )
		isilon_workdir /ifs/MLNX_DATA/FE/veri4/user $user mtl 755
		;;
	backend3/[a-z]* )
		isilon_workdir /ifs/MLNX_DATA/${workdir} $user layout 755
		;;
	ip/[a-z]* )
		isilon_workdir /ifs/MLNX_DATA/BE/${workdir} $user usr_ip 755
		;;

	ip_all/[a-z]* )
		zfs_workdir /mnt/mtlzfs01_${workdir} $user 170 755
		;;
	GL/[a-z]*/[a-z]* )
		isilon_workdir /ifs/MLNX_DATA/FE/${workdir} $user mtl 755
		;;
	backend4/[a-z]* | hertmp2/[a-z]* | hertmp3/[a-z]* | hertmp4/[a-z]* )
		zfs_workdir /mnt/mtlzfs01_${workdir} $user layout 755
		;;
	swgwork|vmgwork )
		netapp_workdir labfs01 /mnt/labfs01_${workdir} $user mtl 755
		;;
	fwgwork|mgwork|sysgwork|qa )
		[[ $workdir == "qa" ]] && workdir=QA
		netapp_workdir labfs02 /mnt/labfs02_${workdir} $user mtl 755
		;;
	mtrsysgwork )
		netapp_workdir mtrlabfs02 /mnt/mtrlabfs02_${workdir} $user mtl 755
		;;
	mtrswgwork )
                netapp_workdir mtrlabfs01 /mnt/mtrlabfs01_${workdir} $user mtl 755
                ;;
	rdmzsysgwork )
		netapp_workdir rdmzlabfs01 /mnt/rdmzlabfs01_${workdir} $user mtl 777
		;;
	help )
		usage
		;;
	* )
		echo -e "\n\e[031mError: wrong working directory was choosen, see following details:\e[0m"
		usage
		;;
esac
