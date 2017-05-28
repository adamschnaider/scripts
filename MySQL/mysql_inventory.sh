#!/bin/bash

##########################################
# Create Netapp 7-Mode FlexCache Volumes #
#      Created by: Adam Schnaider        #
#             Date: March 2017           #
##########################################

# SOURCING
. /root/scripts/functions/bashIFS.bash
. /root/scripts/functions/MySQLHandler.bash
. /root/scripts/functions/sizeHandler.bash
. /root/scripts/functions/NetappHandler.bash

usage()
{
cat <<EOF
This utility use to inventory MySQL DB
Usage:
        $0

Usage like:
        $0
EOF
exit 1
}

inventory_volumes_table()
{

}
