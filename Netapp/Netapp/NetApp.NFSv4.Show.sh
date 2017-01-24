#!/bin/bash

filer=$1
count=$2
interval=$3
/usr/bin/rsh $filer "stats show -n $count -i $interval nfsv4:nfs:nfsv4_read_latency nfsv4:nfs:nfsv4_write_latency nfsv4:nfs:nfsv4_avg_op_latency nfsv4:nfs:nfsv4_read_ops nfsv4:nfs:nfsv4_write_ops nfsv4:nfs:nfsv4_ops"
