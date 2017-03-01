#!/bin/bash

#########################################
#   Create, load, refresh MySQL table   #
#       Created by: Adam Schnaider      #
#               Date: Feb 2017          #
#########################################

usage()
{
cat <<EOF
This utility use to create/load/refresh MySQL table
Usage:
	$0 <create|load|refresh> <MySQL DB> <MySQL Table> <CSV File>
EOF
exit 1
}

[[ $# -ne 4 && $# -ne 3 ]] && usage

[[ $1 != "refresh" && $1 != "create" && $1 != "load" ]] && usage

ACTION=$1
DB=$2
TABLE=$3
CSV=$4

storagesystems="create table storagesystems ( geo varchar(30), state varchar(30), city varchar(30), sla varchar(30), dept varchar(30), site varchar(30), building varchar(30), floor varchar(30), rack varchar(30), hostname varchar(30), name varchar(30), vendor varchar(30), model varchar(30), sn varchar(30), support varchar(30), warranty date, ip varchar(30), dfm varchar(30), rlm varchar(30), rlm_ip varchar(30), eol varchar(30), version varchar(30), future_plan varchar(30), comment varchar(30), primary key (hostname, sn));"

DB_CHECK()
{
## CHECK DATABASE
if [[ -z "`mysql -qfsBe "SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME='${DB}'" 2>&1`" ]]; then
	echo "-E- DATABASE DOES NOT EXIST"
	exit 1
fi
}

TABLE_CHECK()
{
## CHECK TABLE
if [[ -z "`mysql -qfsBe "SELECT TABLE_SCHEMA,TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='${DB}' AND TABLE_NAME='${TABLE}'" 2>&1`" ]]; then
	return 0
else
	return 1
fi
}

ATTR_CHECK()
{
if [[ -z $(echo ${!TABLE}) ]]; then
	echo "-E- NO ATTRIBUTES CONFIGURATION FOR ${TABLE} TABLE"
	exit 1
fi
}

TABLE_CREATE()
{
## CREATING NEW TABLE
mysql ${DB} -qfsBe "${!TABLE}"
}

DROP_TABLE()
{
mysql ${DB} -qfsBe "drop table ${TABLE}"
}

CSV_CHECK()
{
## CHECK CSV FILE
if [[ -z $CSV || ! -e $CSV ]]; then
	echo "-E- ERROR WITH CSV FILE"
	exit 1
fi
}

TABLE_LOAD()
{
## LOAD INTO TABLE
mysql --show-warnings -qBe "LOAD DATA LOCAL INFILE '${CSV}' into table ${DB}.${TABLE} FIELDS TERMINATED BY ',' ENCLOSED BY '\"' LINES TERMINATED BY '\n' IGNORE 1 LINES;"
}

case "${ACTION}" in 
	create )
		echo "-I- CREATING TABLE ${TABLE}"
		DB_CHECK
		TABLE_CHECK
		if [ $? -eq 1 ]; then
			echo "-E- TABLE ALREADY EXISTS, USE REFRESH/LOAD INSTEAD"
			exit 1
		fi
		ATTR_CHECK
		TABLE_CREATE
		;;
	load )
		echo "-I- LOADING INTO TABLE ${TABLE}"
		DB_CHECK
		TABLE_CHECK
		if [ $? -eq 0 ]; then
			echo "-E- TABLE DOES NOT EXISTS, USE CREATE/REFRESH INSTEAD"
			exit 1
		fi
		CSV_CHECK
		TABLE_LOAD
		;;
	refresh )
		echo "-I- REFRESHING TABLE ${TABLE}"
		DB_CHECK
		TABLE_CHECK
		if [ $? -eq 1 ];then
			echo "-I- TABLE ${TABLE} AREADY EXISTS, DELETING AND RECREATING.."
			DROP_TABLE
		else
			echo "-I- TABLE ${TABLE} DOES NOT EXISTS, CREATING.."
		fi
		ATTR_CHECK
		TABLE_CREATE
		;;
esac
