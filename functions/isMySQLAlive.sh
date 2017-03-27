#!/bin/bash 

###################################################
#       Bash source file for MySQL functions 	  #
#       Created by: Adam Schnaider                #
#               Date: March 2017                  #
###################################################

# Return codes:
# 0 - service is running
# 3 - service is stopped
check_mysql() {
/etc/init.d/mysqld status >/dev/null 2>&1
return $?
}
