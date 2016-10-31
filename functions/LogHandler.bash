#!/bin/bash

###################################################
#       Bash source file for log files functions  #
#       Created by: Adam Schnaider                #
#               Date: Oct 2016                    #
###################################################

LOGSIZE=300
LOGFILEPATH=$(basename $0) && LOGFILEPATH=${LOGFILEPATH%%.*}.log

wrLog() {
[ ! -d ${LOGFILEPATH} ] && mkdir ${LOGFILEPATH}
echo "$(date) $(hostname) $0[$$]: $1" >> ${LOGFILEPATH}/log.0
}

rotateLog(){
[ ! -d ${LOGFILEPATH} ] && mkdir ${LOGFILEPATH}
[ ! -f ${LOGFILEPATH}/log ] && ln -s log.0 ${LOGFILEPATH}/log
[ ! -f ${LOGFILEPATH}/log.0 ] && touch ${LOGFILEPATH}/log.0
[ ! -f ${LOGFILEPATH}/log.1 ] && touch ${LOGFILEPATH}/log.1
[ ! -f ${LOGFILEPATH}/log.2 ] && touch ${LOGFILEPATH}/log.2
[ ! -f ${LOGFILEPATH}/log.3 ] && touch ${LOGFILEPATH}/log.3
[ ! -f ${LOGFILEPATH}/log.4 ] && touch ${LOGFILEPATH}/log.4

if [ $(du -sk ${LOGFILEPATH}/log.0 | awk '{print $1}') -gt ${LOGSIZE} ]; then
        mv ${LOGFILEPATH}/log.3 ${LOGFILEPATH}/log.4
        mv ${LOGFILEPATH}/log.2 ${LOGFILEPATH}/log.3
        mv ${LOGFILEPATH}/log.1 ${LOGFILEPATH}/log.2
        mv ${LOGFILEPATH}/log.0 ${LOGFILEPATH}/log.1
        touch ${LOGFILEPATH}/log.0
fi
}
