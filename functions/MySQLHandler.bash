#!/bin/bash 

###################################################
#       Bash source file for MySQL functions 	  #
#       Created by: Adam Schnaider                #
#               Date: March 2017                  #
###################################################

### FUNCTIONS

# Return codes:
# 0 - service is running
# 3 - service is stopped
check_mysql() {
/etc/init.d/mysqld status >/dev/null 2>&1
return $?
}

### CONFIGURATIONS

#storagesystems="create table storagesystems ( geo varchar(30), state varchar(30), city varchar(30), sla varchar(30), dept varchar(30), site varchar(30), building varchar(30), floor varchar(30), rack varchar(30), hostname varchar(30), name varchar(30), vendor varchar(30), model varchar(30), sn varchar(30), support varchar(30), warranty date, ip varchar(30), dfm varchar(30), rlm varchar(30), rlm_ip varchar(30), eol varchar(30), version varchar(30), future_plan varchar(30), comment varchar(30), primary key (hostname, sn));"

storagesystems="CREATE TABLE storagesystems (geo varchar(30),state varchar(30),city varchar(30),sla varchar(30),dept varchar(30),site varchar(30),building varchar(30),floor varchar(30),rack varchar(30),hostname varchar(30),name varchar(30),vendor varchar(30),model varchar(30),sn varchar(30),isActive enum('true','false'),support varchar(30),warranty date,ip varchar(30),dfm varchar(30),rlm varchar(30),rlm_ip varchar(30),eol varchar(30),flexcache enum('true','false'),version varchar(30),future_plan varchar(30),comment varchar(30),PRIMARY KEY (hostname,sn))"

exports="CREATE TABLE exports (site varchar(30),lab varchar(300),prod varchar(300),PRIMARY KEY (site))"

volumes="CREATE TABLE volumes (hostname varchar(30),vol varchar(60),state varchar(20),type varchar(20),id varchar(50),used varchar(3),PRIMARY KEY (id))"

contacts="CREATE TABLE contacts (name varchar(30),mail varchar(30),PRIMARY KEY (name))"

thresholds="CREATE TABLE thresholds (name varchar(30), FOREIGN KEY (name) REFERENCES contacts(name), id varchar(50), FOREIGN KEY (id) REFERENCES volumes(id), threshold varchar(3) not null,PRIMARY KEY (name,id))"
