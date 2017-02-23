#!/bin/bash

#########################################
#       Convert .xlsx to .csv file      #
#       Created by: Adam Schnaider      #
#               Date: Feb 2017          #
#########################################

functions_path="/root/scripts/functions"
base_path="/root/scripts"

usage()
{
cat <<EOF
This utility use to convert .xlsx to .csv file
Usage:
	$0 <input file (.xlsx)> <output file (.csv)>
EOF
exit 1
}

[ $# -ne 2 ] && usage

XLSX=$1
CSV=$2

## CHECK FILES
if [[ ! -f ${XLSX} ]]; then
	echo "-E- XLSX FILE DOESN'T EXISTS"
	exit 1
fi

## CONVERT
${base_path}/xlsx2csv-0.7.2/xlsx2csv.py ${XLSX} ${CSV}
