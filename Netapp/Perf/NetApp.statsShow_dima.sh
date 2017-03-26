#!/bin/bash

filer=$1
/usr/bin/rsh $filer stats show -c volume:*:total_ops volume:*:read_data volume:*:write_data |awk 'BEGIN{osum=0;rdsum=0;wdsum=0};{if(NR==2) {printf("\t\t\t%10s%11s%11s\n",$1,$2,$3)} else {osum+=$2;rdsum+=$3;wdsum+=$4;printf("%-25s%10s%11s%11s\n",$1,$2,$3,$4)}};END{printf("%-25s%10s%8.3f(MB/s)%8.3f(MB/s)\n","TOTAL=",osum,rdsum/2^20,wdsum/2^20)}'
