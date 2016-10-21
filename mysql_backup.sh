#!/bin/bash

DATE=`date +%d.%m.%y_%H.%M`
mkdir /Backup/STORAGE/mtlstadm01/mysql/$DATE
rsync -arv /var/lib/mysql/ /Backup/STORAGE/mtlstadm01/mysql/$DATE
find /Backup/STORAGE/mtlstadm01/mysql/ -maxdepth 1 -type d -ctime +30 -exec rm -rf {} \;
