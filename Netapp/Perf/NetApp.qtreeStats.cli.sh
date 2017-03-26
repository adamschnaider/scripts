#! /bin/sh

filer=$1
interval=$2

/bin/date


if [ x$filer == "x" ]
then 
	echo "USAGE: nfsstat.NetApp.sh NetAppFiler"
	exit
fi
/usr/bin/rsh $filer "qtree stats -z"
/bin/sleep $interval
/usr/bin/rsh $filer "qtree stats" | less


