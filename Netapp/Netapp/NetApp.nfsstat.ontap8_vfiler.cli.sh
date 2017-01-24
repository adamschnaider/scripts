#! /bin/sh

filer=$1
vfiler=$2
interval=$3

outFile=/tmp/nfsstat.NetApp.$filer_$vfiler.out
tmpFile=/tmp/nfsstat.NetApp.$filer_$vfiler.tmp
tmpFileHead=/tmp/nfsstat.NetApp.$filer_$vfiler.tmpHead


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
	echo "USAGE: nfsstat.NetApp.sh NetAppFiler NetAppVFiler"
	exit
fi
/usr/bin/rsh $filer vfiler run $vfiler nfsstat -z
/bin/sleep $interval
/usr/bin/rsh $filer vfiler run $vfiler nfsstat -l >> $tmpFile
/bin/cat $tmpFile | head >> $tmpFileHead


/bin/cat $tmpFileHead | awk -v interval=$interval '{if ($3=="NFSOPS") {printf ("%s %8d\n",$0,$5/interval)} else if ($4=="NFSOPS") {printf ("%s %8d\n",$0,$6/interval)} else print $0 }' >> $outFile
/bin/cat $tmpFile | grep NFSOPS | cut -d"=" -f 2 | awk -v interval=$interval 'BEGIN{cnt=0}{cnt=cnt+$1}END{printf("   Total NFSOPS:    %8d \n   OPS per second:  %8d\n",cnt,cnt/interval)}' >> $outFile



/bin/cat $outFile

