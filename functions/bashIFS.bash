#!/bin/bash
###################################################################################################
## Changes the default bash internal field separator
##      Synosys: splitByLines
##      Return:  Internal bash field separator is changed to a 'newline'
##      Example: splitByLines
splitByLines(){
IFS=$'\n'
}
###################################################################################################
## Changes the default bash internal field separator
##      Synosys: splitByDefault
##      Return:  Internal bash field separator is changed to a 'space' ( default )
##      Example: splitByDefault
splitByDefault(){
unset IFS
}
