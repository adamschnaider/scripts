#! /bin/sh -f

###
#   <filer> <volName|all> [all]

filers="mtlfs01 mtlfs03 mtvfs01 labfs01 labfs02 bond navi mtlfsora01 mtlfsora02 10.0.7.122"

filer=$1
vol=$2
sortParam=$3

flag=0
for u in $filers ; do 
    if [ "x$u" == "x$filer" ] 
    then
	flag=1
    fi
done

if [ $flag -eq 0 ] 
then
    echo "-I- first parameter shall be NetApp host"
    echo "Usage: NetApp.latencyPerVolume.cli.sh <filer> <volName> [all]"
    exit 
fi
flag=0


case $vol in
    all)
	if [ "x$sortParam" == "xall" ] 
	then 
	    \rsh $filer "priv set diag ; stats show volume" | grep avg_latency
	else
	    echo "-I- Volumes on $filer with Average Latency >= 1 uni sec"
	    \rsh $filer "priv set diag ; stats show volume" | grep avg_latency 
	fi
    ;;
    *)
	flag=0
	for u in `\rsh $filer df -h | grep -v snap | grep -v Filesystem | cut -d"/" -f 3` ; do
	    if [ "x$u" == "x$vol" ]
	    then
		flag=1
	    fi
	done
	if [ $flag -eq 0 ]
	then
	    echo "-I- second parameter shall be volume name"
	    echo "Usage: NetApp.latencyPerVolume.cli.sh <filer> <volName> [all]"
	    exit
	fi
	if [ "x$sortParam" == "xall" ]
	then
	    \rsh $filer "priv set diag ; stats show volume" | grep avg_latency | grep $vol
	else
	    echo "-I- Volumes on $filer with Average Latency >= 1 uni sec"
	    \rsh $filer "priv set diag ; stats show volume" | grep avg_latency | grep $vol
	fi
    ;;
esac
