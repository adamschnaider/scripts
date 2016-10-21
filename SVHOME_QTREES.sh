#!/bin/bash

for i in `cat /tmp/svhome_Monitored`
do 
QTREE=`cat /home/yokadm/Monitors/Storage_Monitoring/Storage_Capacity_Mon.cfg |grep -w $i | awk '{print $1}'`;
GROUP=`cat /home/yokadm/Monitors/Storage_Monitoring/Storage_Capacity_Mon.cfg |grep -w $i | awk '{print $4}'`; 
GROUP_CONTACTS=`cat /home/yokadm/Monitors/Contact_Groups/$GROUP | awk -F: '{print $1}'`; 
echo "$QTREE,$GROUP,$GROUP_CONTACTS" >> /tmp/svhome_monitored_qtrees.csv; 
done
