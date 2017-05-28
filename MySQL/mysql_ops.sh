#!/bin/bash

#########################################
#   Create, load, refresh MySQL table   #
#       Created by: Adam Schnaider      #
#               Date: Feb 2017          #
#########################################

## SOURCE TABLE CREATE CONFIGURATIONS
. /root/scripts/functions/MySQLHandler.bash

usage()
{
cat <<EOF
This utility use to create/load/refresh MySQL table
Usage:
	$0 <check|create|load|refresh> <MySQL DB> <MySQL Table> <CSV File>
EOF
exit 1
}

[[ $# -ne 4 && $# -ne 3 ]] && usage

[[ $1 != "refresh" && $1 != "create" && $1 != "load" && $1 != "check" ]] && usage

ACTION=$1
DB=$2
TABLE=$3
CSV=$4

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
mysql -qBe "LOAD DATA LOCAL INFILE '${CSV}' into table ${DB}.${TABLE} FIELDS TERMINATED BY ',' ENCLOSED BY '\"' LINES TERMINATED BY '\n' IGNORE 1 LINES;"
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
		echo "-I- DONE"
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
		echo "-I- DONE"
		;;
	refresh )
		echo "-I- REFRESHING TABLE ${TABLE}"
		DB_CHECK
		ATTR_CHECK
		TABLE_CHECK
		if [ $? -eq 1 ];then
			echo "-I- TABLE ${TABLE} AREADY EXISTS, DELETING AND RECREATING"
			DROP_TABLE
		else
			echo "-I- TABLE ${TABLE} DOES NOT EXISTS, CREATING"
		fi
		TABLE_CREATE
		echo "-I- DONE"
		;;
	check )
		echo "-I- CHECKING DB:"
		DB_CHECK
		echo "-I- DB OK"
		echo "-I- CHECKING TABLE:"
		TABLE_CHECK
		if [ $? -eq 0 ]; then
			echo "-E- TABLE DOES NOT EXISTS, USE CREATE/REFRESH"
			exit 1
		fi
		echo "-I- TABLE OK"
		;;
esac
