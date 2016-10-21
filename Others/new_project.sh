#!/bin/bash

project_name()
{
while [ 1 ];
do
	echo "Enter new project's name:"
	read project
	echo -e "Project name: $project, continue?"
	read answer
	case "$answer" in
		YES|yes|y|Y )
			echo "Proceeding.."
			break
			;;
		NO|no|n|N )
			echo "Exiting.. Done nothing!"
			quit 2
			;;
		* )
			echo "Wrong answer"
			sleep 1
			project
			;;
	esac
done
}

project_name

[ -e "$project" ] && echo "Project is already exists, exiting..." && exit

while read line
do
	user=`echo $line | awk '{print $1}'`; perms=`echo $line | awk '{print $2}'`; path=`echo $line | awk '{print $3}'`
	mkdir -p $project/$path
done </root/new_project.cfg

chown -R yokadm:mtl $project
chown yokadm:layout $project

while read line
do
	user=`echo $line | awk '{print $1}'`; perms=`echo $line | awk '{print $2}'`; path=`echo $line | awk '{print $3}'`
	chmod $perms $project/$path ; chown $user $project/$path
done </root/new_project.cfg
