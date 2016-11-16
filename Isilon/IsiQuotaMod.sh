usage() {
cat <<EOF
Usage: $0 <username> <directory> [size in G]
EOF
exit 1
}

resize_check()
{
if ! [[ $(echo $size |grep '^[0-9]*[gG]$') ]]; then
        echo -e "\n\e[31mERROR: The size you entered is invalid! Please try again\e[0m"
        usage
fi
}

## Arguments
username=$1
dir=$2
size=$3

#[[ "$#" -ne 3 && "$#" -ne 2 ]] && usage
if [ "$#" -ne 2 ]; then
	if [ "$#" -eq 3 ]; then
		resize_check $size
	else
		usage
	fi
fi

## Check user
if ! ypmatch ${username} passwd > /dev/null 2>&1; then echo -e "ERROR: User doesn't exists" && exit 1; fi

## Check quota count
[[ $(ssh 10.5.1.1 isi quota quotas list --user=${username} | grep $dir | wc -l) -ne 1 ]] && echo "ERROR: Quota problem, check details" && exit 1

## Quota fully detailed
QUOTA=$(ssh 10.5.1.1 isi quota quotas list --user=${username} | grep $dir | awk '{print $1,$2,$3,$8,$5}')

## Current quota
echo -e "\e[032mCurrent quota:\e[0m"
echo "$QUOTA"

## Continue if size was entered
[[ "$#" -eq "2" ]] && exit

## Check size parameter
resize_check $size
## If size entered is OK, change 'g' to upper case
size=$(echo $size | tr '[:lower:]' '[:upper:]')

## Check if quota entered is less than current quota
if [ $(ssh 10.5.1.1 isi quota quotas list --user=${username} --format=csv | grep $dir | awk -F',' '{print $5}') -gt ${size%%G*} ]; then
	echo -e "ERROR: Quota entered is less than current user quota"
	exit 1
fi

## Quota modification

[[ $(ssh 10.5.1.1 isi quota quotas view  --user=${username} --type=$(echo $QUOTA|awk '{print $1}') --path=$(echo $QUOTA|awk '{print $3}')|grep Linked | awk '{print $2}') == "Yes" ]] && ssh 10.5.1.1 isi quota quotas modify --user=${username} --type=$(echo $QUOTA|awk '{print $1}') --path=$(echo $QUOTA|awk '{print $3}') --linked=no

ssh 10.5.1.1 isi quota quotas modify --user=${username} --type=user --path=$(echo $QUOTA|awk '{print $3}') --hard-threshold=${size} --advisory-threshold=${size}

echo -e "\n\e[032mNew quota:\e[0m"
ssh 10.5.1.1 isi quota quotas list --user=${username} --type=user --path=$(echo $QUOTA|awk '{print $3}') --no-footer --no-header
