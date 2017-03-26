#!/bin/bash
client_host=$1

echo "run pktt on LABFS02"
/usr/bin/rsh labfs02 "priv set diag; pktt start failover -i 10.208.3.102 -i 10.208.0.102 -i 10.211.0.102 -i 172.30.0.102 -d /etc/log -b 2m -m 1518"

echo "run pktt on MTRLABFS01"
/usr/bin/rsh mtrlabfs01 "priv set diag; pktt start failover -i 10.4.0.103 -i 10.128.0.103 -i 10.7.136.35 -i $client_host -d /etc/log -b 2m -m 1518"
