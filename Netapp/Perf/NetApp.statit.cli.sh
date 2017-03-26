#! /bin/sh

filer=$1
interval=$2

/bin/date


if [ x$filer == "x" ]
then 
	echo "USAGE: nfsstat.NetApp.sh NetAppFiler interval_in_sec"
	exit
fi
/usr/bin/rsh $filer "priv set diag ; statit -b"
/bin/sleep $interval
/usr/bin/rsh $filer "priv set diag ; statit -e" | less


