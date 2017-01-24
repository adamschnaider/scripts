#! /bin/sh

filer=$1
interval=$2

outFile=/tmp/nfsstat.NetApp.$filer.out
tmpFile=/tmp/nfsstat.NetApp.$filer.tmp
tmpFileHead=/tmp/nfsstat.NetApp.$filer.tmpHead


/bin/rm $tmpFile
/bin/touch $tmpFile

/bin/rm $tmpFileHead
/bin/touch $tmpFileHead

/bin/rm $outFile
/bin/touch $outFile

/bin/date >> $outFile
/bin/echo "NFS OPS Stats for $filer for $interval seconds." >> $outFile
/bin/echo "IP              HOST                            NFS OPS         CNT    %       OpS" >> $outFile


if [ x$filer == "x" ]
then 
	echo "USAGE: nfsstat.NetApp.sh NetAppFiler"
	exit
fi
/usr/bin/rsh $filer nfsstat -z
/bin/sleep $interval
/usr/bin/rsh $filer nfsstat -l >> $tmpFile
/bin/cat $tmpFile | head >> $tmpFileHead


/bin/cat $tmpFileHead | awk -v interval=$interval '{if ($3=="NFSOPS") {printf ("%s %8d\n",$0,$5/interval)} else if ($4=="NFSOPS") {printf ("%s %8d\n",$0,$6/interval)} else print $0 }' >> $outFile
/bin/cat $tmpFile | grep NFSOPS | cut -d"=" -f 2 | awk -v interval=$interval 'BEGIN{cnt=0}{cnt=cnt+$1}END{printf("   Total NFSOPS:    %8d \n   OPS per second:  %8d\n",cnt,cnt/interval)}' >> $outFile



/bin/cat $outFile

