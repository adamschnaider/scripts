#!/bin/bash

filer=$1
count=$2
interval=$3
/usr/bin/rsh $filer "stats show -n $count -i $interval nfsv3:nfs:nfsv3_read_latency nfsv3:nfs:nfsv3_write_latency nfsv3:nfs:nfsv3_avg_op_latency nfsv3:nfs:nfsv3_read_ops nfsv3:nfs:nfsv3_write_ops nfsv3:nfs:nfsv3_ops"
