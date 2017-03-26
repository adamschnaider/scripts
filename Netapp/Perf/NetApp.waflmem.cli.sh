#! /bin/bash

### standard funtion stack ###
functions_path="/home/yokadm/Monitors/functions"
. ${functions_path}/Contact_Management/contact_management_functions.bash
. ${functions_path}/bashIFS.bash
. ${functions_path}/sms/sendSMS.bash
. ${functions_path}/mail/sendMail.bash


filers="labfs02 labfs01"
interval=1
iteration=45
threshold=400
tmpFile=/tmp/wafl_memory_free_${filer}_$$.tmp
sender="WAFL_MEMORY_MON"
notification_group=IT_STOR_MNG
SEMAPHORE=/var/lock/waflmem

[ -e $SEMAPHORE ] && exit

touch $SEMAPHORE

for filer in $filers
do
rsh $filer stats show -i $interval -n $iteration wafl:wafl:wafl_memory_free wafl:wafl:wafl_memory_used > $tmpFile

count=0
total=0

for i in `cat $tmpFile |grep " wafl " | awk '{print $2}'`
	do
	total=$(echo $total+$i |bc)
	((count++))
	done
avg=`echo "scale=2; $total / $count" |bc`

#echo "$avg"
walfmem_free=${avg%.*}
#echo "$walfmem_free"
splitByLines
if [ $walfmem_free -le $threshold ] ; then
	sendMail "${sender} " "$filer LOW WAFL MEMORY ${walfmem_free}MB !!! Please consider takeover" $(getMails ${notification_group})					
	sendSMS ${sender} "$filer LOW WAFL MEMORY ${walfmem_free}MB !!! Please consider takeover" $(getPhones ${notification_group})
fi

/bin/rm $tmpFile
done

rm $SEMAPHORE
