#!/bin/bash

filer=$1
count=$2
interval=$3
vol=$4
/usr/bin/ssh $filer "stats show -n $count -i $interval volume:$vol:read_latency volume:$vol:write_latency volume:$vol:other_latency volume:$vol:read_ops volume:$vol:write_ops volume:$vol:other_ops"
