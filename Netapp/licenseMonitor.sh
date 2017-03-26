#!/bin/bash

### Netapp License Monitoring

THRESHOLD="15"	# in days

EXP_LICENSE=$(ssh admin@mtlfsprd "system license show -owner mtlfsprd -expiration < $(date -d ${THRESHOLD}\ days +%m/%d/%Y\ %T)" | grep demo)

[[ ! -z ${EXP_LICENSE} ]] && echo "${EXP_LICENSE}" | mail -s "MTLFSPRD License Issue" -- it_storage@mellanox.com
