#!/bin/bash
TMPFILE=`mktemp`
LOGDIR="/home/adams/du_check/SPE"

if [ -e ${LOGDIR}/du.lock.file ]
then
	echo -e "`date`:\n" >> ${LOGDIR}/du.big_files.out.txt.$$
	echo -e "\e[31mERROR: $0 is already running; exiting...\e[0m" >> ${LOGDIR}/du.big_files.out.txt.$$
	echo -e "\n----------------------------------------------------------\n" >> ${LOGDIR}/du.big_files.out.txt.$$
	cat ${LOGDIR}/du.big_files.out.txt.$$ | cat - ${LOGDIR}/du.big_files.out.txt > $TMPFILE
	mv -f $TMPFILE ${LOGDIR}/du.big_files.out.txt
	rm -f $TMPFILE
	exit 1
fi

touch ${LOGDIR}/du.lock.file
du -sm /usr/spe/* | sort -h > ${LOGDIR}/du.out.$$.txt
echo -e "`date`:\n" >> ${LOGDIR}/du.big_files.out.txt.$$
ifs=$IFS
IFS=$'\n';for i in `df -h /usr/spe/`; do echo $i |gawk -v c=5 -v RS='[[:space:]]+' 'NR<=c{ORS=(NR<c?RT:"\n");print}'; done >> ${LOGDIR}/du.big_files.out.txt.$$
IFS=$ifs
echo "" >> ${LOGDIR}/du.big_files.out.txt.$$

while read line
do
	size=$(echo $line | awk '{print $1}')
	if [ "$size" -gt "10240" ]
	then
		PATH_A=$(echo $line | awk '{print $2}')
		size_a=$(( size / 1024 ))
		echo ${size_a}G $PATH_A >> ${LOGDIR}/du.big_files.out.txt.$$
		du -sm ${PATH_A}/* | sort -h >$TMPFILE
		while read LINE
		do
			SIZE=$(echo $LINE | awk '{print $1}')
			if [ "$SIZE" -gt "10240" ]
			then
				size_b=$(( SIZE / 1024 ))
				PATH_B=$(echo $LINE | awk '{print $2}')
				echo -e "\t ${size_b}G $PATH_B" >> ${LOGDIR}/du.big_files.out.txt.$$
			fi
		done <$TMPFILE
	fi
done <${LOGDIR}/du.out.$$.txt

#echo -e "\n`date`\n" >> /home/adams/du.big_files.out.txt.$$
echo -e "\n----------------------------------------------------------\n" >> ${LOGDIR}/du.big_files.out.txt.$$

cat ${LOGDIR}/du.big_files.out.txt.$$ | cat - ${LOGDIR}/du.big_files.out.txt > $TMPFILE
mv -f $TMPFILE ${LOGDIR}/du.big_files.out.txt
rm -f ${LOGDIR}/du.big_files.out.txt.$$
rm -f ${LOGDIR}/du.lock.file
rm -f $TMPFILE
cp ${LOGDIR}/du.big_files.out.txt ${LOGDIR}/du.big_files.out.`date +%d%m%y`.txt
echo -e "`date`:\n/.autodirect/spe/* details" | mail -r du_check@mtlstadm01.mtl.com -s "SPE FILESYSTEM USAGE" -a ${LOGDIR}/du.big_files.out.txt -a ${LOGDIR}/du.out.$$.txt -- it_storage@mellanox.com eamar@mellanox.com
mv ${LOGDIR}/du.out.$$.txt ${LOGDIR}
