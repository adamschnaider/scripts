#!/usr/bin/python
import sys
import mysql.connector

config = {
    'user': 'ssluser',
    'password': 'Password123!',
    'host': '127.0.0.1',
    'ssl_ca': '/var/lib/mysql/ca.pem',
    'ssl_cert': '/var/lib/mysql/client-cert.pem',
    'ssl_key': '/var/lib/mysql/client-key.pem',
    'database': 'MLNX'
}

if (len(sys.argv) > 1):
	command=sys.argv[1]
else:
	command=str(raw_input())
cn=mysql.connector.connect(**config)
cn.autocommit = True
cur=cn.cursor()
cur.execute(command)
row=cur.fetchone()
while row is not None:
	print row
	row=cur.fetchone()
