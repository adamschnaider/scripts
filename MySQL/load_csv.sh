#!/bin/bash

#########################################
#       Load CSV file to MySQL DB       #
#       Created by: Adam Schnaider      #
#               Date: Feb 2017          #
#########################################

usage()
{
cat <<EOF
This utility use to load CSV file into MySQL DB
Usage:
	$0 <MySQL DB> <MySQL Table> <CSV File>
EOF
exit 1
}

[ $# -ne 3 ] && usage

DB=$1
TABLE=$2
CSV=$3

## CHECK DATABASE
if [[ -z "`mysql -qfsBe "SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME='${DB}'" 2>&1`" ]]; then
	echo "-E- DATABASE DOES NOT EXIST"
	exit 1
fi

## CHECK TABLE
if [[ -z "`mysql -qfsBe "SELECT TABLE_SCHEMA,TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='${DB}' AND TABLE_NAME='${TABLE}'" 2>&1`" ]]; then
        echo "-E- TABLE DOES NOT EXIST"
        exit 1
fi

## CHECK CSV FILE
if [[ ! -e $CSV ]]; then
	echo "-E- CSV file doesn't exist"
	exit 1
fi

## LOAD INTO TABLE
mysql --show-warnings -qBe "LOAD DATA LOCAL INFILE '${CSV}' into table ${DB}.${TABLE} FIELDS TERMINATED BY ',' ENCLOSED BY '\"' LINES TERMINATED BY '\n' IGNORE 1 LINES;"
