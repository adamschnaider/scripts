#!/bin/bash

#########################################
#	Mail Processing Agent		#
#	Created By:			#
#	Adam Schnaider			#
#########################################

copy_mail_path=/root/Mail
orig_mail_path=/var/spool/mail/root

[ ! -e $orig_mail_path ] && exit
cp -pf $orig_mail_path $copy_mail_path

[ `du /var/mail/root|awk '{print $1}'` -eq "0" ] && exit

FROM=`cat /var/spool/mail/root |grep "^From:" | head -1 |awk '{print $2,$3}'`
if [ "$FROM" != "Adam Schnaider" ] && [ "$FROM" != "Nir Boyarsky" ]; then mv $orig_mail_path ${copy_mail_path}/root.`date +%d%m%y.%H%M`; exit; fi
SUB=`cat $copy_mail_path/root | grep "^Subject:" | head -1 | awk -F':' '{print $2}'`
NUM=$(echo $SUB | wc -w)
for (( i=1; i<=$NUM; i++ ))
do
	ARG[$i]=$(echo $SUB | awk -v var=$i '{print $var}')
	#echo ${ARG[$i]}
done

case "${ARG[1]}" in
	7resize|7Resize )
		echo -e "Date: `date` \nReceived request to ${ARG[@]} \n" >> $copy_mail_path/volResizer.maillog.$$
		echo -e "\nSent by: $FROM" >> $copy_mail_path/volResizer.maillog.$$
		/root/volResizer.sh -n ${ARG[2]} -v ${ARG[3]} -s ${ARG[4]} -f >> $copy_mail_path/volResizer.maillog.$$
		if [ "$?" -eq "0" ]; then
			cat -v $copy_mail_path/volResizer.maillog.$$ | mail -s "Succeeded: Volume resized" -- it_storage@mellanox.com
		else
			cat -v $copy_mail_path/volResizer.maillog.$$ | mail -s "Error: Volume did not reized" -- it_storage@mellanox.com
		fi
		;;
	Cresize|cresize )
		echo -e "Date: `date` \nReceived request to ${ARG[@]} \n" >> $copy_mail_path/volResizer.maillog.$$
		echo -e "\nSent by: $FROM" >> $copy_mail_path/volResizer.maillog.$$
		/root/CmodeVolResizer.sh -n ${ARG[2]} -v ${ARG[3]} -s ${ARG[4]} -f >> $copy_mail_path/volResizer.maillog.$$
		if [ "$?" -eq "0" ]; then
			cat -v $copy_mail_path/volResizer.maillog.$$ | mail -s "Succeeded: Volume resized" -- it_storage@mellanox.com
		else
			cat -v $copy_mail_path/volResizer.maillog.$$ | mail -s "Error: Volume did not reized" -- it_storage@mellanox.com
		fi
		;;
	show|Show )
		echo -e "Date: `date` \nReceived request to ${ARG[@]} \n" >> $copy_mail_path/volResizer.maillog.$$
		echo -e "\nSent by: $FROM" >> $copy_mail_path/volResizer.maillog.$$
		if [ "${ARG[2]}" == "cmode" -o "${ARG[2]}" == "Cmode" ]; then
			/root/CmodeVolResizer.sh -n ${ARG[3]} -v ${ARG[4]} -s >> $copy_mail_path/volResizer.maillog.$$
			if [ "$?" -eq "0" ]; then
				cat -v $copy_mail_path/volResizer.maillog.$$ | mail -s "Succeeded: Volume show" -- it_storage@mellanox.com
			else
				cat -v $copy_mail_path/volResizer.maillog.$$ | mail -s "Error: Volume show" -- it_storage@mellanox.com
			fi
		fi
		if [ "${ARG[2]}" == "7Mode" -o "${ARG[2]}" == "7mode" ]; then
			/root/volResizer.sh -n ${ARG[3]} -v ${ARG[4]} -s >> $copy_mail_path/volResizer.maillog.$$
			if [ "$?" -eq "0" ]; then
				cat -v $copy_mail_path/volResizer.maillog.$$ | mail -s "Succeeded: Volume show" -- it_storage@mellanox.com
			else
				cat -v $copy_mail_path/volResizer.maillog.$$ | mail -s "Error: Volume show" -- it_storage@mellanox.com
			fi
		fi
		;;
	* )
		echo -e "\nDate: `date` \nWrong keyword, done noting \nArgs: `echo ${ARG[@]}`" >> $copy_mail_path/volResizer.maillog.$$
		echo -e "\nSent by: $FROM" >> $copy_mail_path/volResizer.maillog.$$
		cat $copy_mail_path/volResizer.maillog.$$ | mail -s "Error: Wrong Keyword" -- it_storage@mellanox.com
		;;
esac

rm -f $orig_mail_path
