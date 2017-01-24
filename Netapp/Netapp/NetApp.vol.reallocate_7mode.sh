#! /bin/bash

### standard funtion stack ###
functions_path="/home/yokadm/Monitors/functions"
. ${functions_path}/Contact_Management/contact_management_functions.bash
. ${functions_path}/bashIFS.bash
. ${functions_path}/sms/sendSMS.bash
. ${functions_path}/mail/sendMail.bash


controller=$1
SEMAPHORE=/var/lock/reallocate_$controller
VOL_LIST=/tmp/vols_to_reallocate_7mode

[ -e $SEMAPHORE ] && exit

touch $SEMAPHORE

#for vol in `ssh $cluster -l admin "vol show -vserver $vserver -node $controller -type RW -field volume" | grep $vserver |awk '{print $2}'`
for vol in `rsh $controller "aggr show_space -h SAS_aggr1" |grep -w volume |awk '{print $1}'` 
do
	echo "$vol"
	echo "idle for next 10 seconds..."
	sleep 10

	#rStatus=$(ssh mtrfsprd -l admin "reallocate status -vserver mtrfsbit" |egrep 'Running|Queued')
	rStatus=$(rsh $controller "reallocate status" |egrep 'Reallocating')
        if [[ -n $rStatus ]]
        then
#		continue
#		while [[ -n $(ssh mtrfsprd -l admin "reallocate status -vserver mtrfsbit" |egrep 'Running|Queued') ]]
		while [[ -n $(rsh $controller "reallocate status" |egrep 'Reallocating') ]]
		do
			#progress=$(ssh mtrfsprd -l admin "reallocate status -vserver mtrfsbit" |grep Progress)
			progress=$(rsh $controller "reallocate status" |grep Reallocating)
			echo "`date +"%Y%m%d_%H:%M:%S"`... $vol Reallocate on $progress"
	                sleep 60
		done
	else
                echo "going to start reallocation of vol $vol in 15 seconds......"
                sleep 15
                echo "not running, starting to reallocate vol $vol"
                #ssh mtrfsprd -l admin "reallocate start -vserver mtrfsbit -space-optimized true -force true -path /vol/$vol"
                rsh $controller "reallocate start  -p -f -o /vol/$vol"
                prev_vol=$vol
                #while [[ -n $(ssh mtrfsprd -l admin "reallocate status -vserver mtrfsbit" |egrep 'Running|Queued') ]]
                while [[ -n $(rsh $controller "reallocate status" |egrep 'Reallocating') ]]
	        do
                        #progress=$(ssh mtrfsprd -l admin "reallocate status -vserver mtrfsbit" |grep Progress)
                        progress=$(rsh $controller "reallocate status" |grep Reallocating)
                        echo "`date +"%Y%m%d_%H:%M:%S"`... $prev_vol Reallocate on $progress"
                        sleep 60
       	        done

	fi
done
	
rm $SEMAPHORE
