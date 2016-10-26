#!/bin/bash
quota_file_path=/home/yokadm/tmp/quotaOutFormatedAll.tmp


usage(){
cat <<EOF
    $0: Bad parameters
    USAGE: $0 [user|group|pattern]  [ <unixname> ] | All
EOF
exit 1
}

if [ -f /home/yokadm/tmp/quotaOutFormatedAll.tmp ] ; then
    quotaFile="/home/yokadm/tmp/quotaOutFormatedAll.tmp"
elif [ -f /home_prod/yokadm/tmp/quotaOutFormatedAll.tmp ] ; then
    quotaFile="/home_prod/yokadm/tmp/quotaOutFormatedAll.tmp"
fi
    

case ${1} in
	generate)
		hostName=$(hostname) && hostName=${hostName%%.*} && usr=$(whoami)
		if [ ${hostName} = 'sysmon' -a ${usr} = 'root' ]; then
			source $(dirname $0)/getAllQuotas.sh
		else
			echo "-E- You are not authorized to run this command"
			exit 1
		fi
		;;
	-h)
		 usage
		;;
	user|group)
		[[ "X${1}" = "X" ]] && usage
		printf '%-15s %-12s %-15s %-40s %-9s %-9s %-9s\n' 'Filer' 'Type' 'ID' 'Path' 'Quota(G)' 'Used(G)' 'Used(%)'
		printf '%-15s %-12s %-15s %-40s %-9s %-9s %-9s\n' '--------' '-----' '----------'  '---------------------' '-------' '-------' '-------'
		cat ${quotaFile} | grep -w ${1} | grep -w "${2}"
		;;
	all|All)
		[[ "X${1}" = "X" ]] && usage
		printf '%-15s %-12s %-15s %-40s %-9s %-9s %-9s\n' 'Filer' 'Type' 'ID' 'Path' 'Quota(G)' 'Used(G)' 'Used(%)'
		printf '%-15s %-12s %-15s %-40s %-9s %-9s %-9s\n' '--------' '-----' '----------'  '---------------------' '-------' '-------' '-------'
		cat ${quotaFile} 
		;;
	*)
		[[ "X${1}" = "X" ]] && usage
		printf '%-15s %-12s %-15s %-40s %-9s %-9s %-9s\n' 'Filer' 'Type' 'ID' 'Path' 'Quota(G)' 'Used(G)' 'Used(%)'
		printf '%-15s %-12s %-15s %-40s %-9s %-9s %-9s\n' '--------' '-----' '----------'  '---------------------' '-------' '-------' '-------'
                cat ${quotaFile} | grep -w ${1} 
                ;;
esac

