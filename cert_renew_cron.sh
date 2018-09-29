#!/bin/bash -x
. ../config/config.sh $1

function cron_renew {
domain=$1
elb=$2
script_path=$3
eco_system=$4 #production or staging
renew=$(sudo certbot renew --renew-hook "$script_path/post_renew.sh $domain $elb $eco_system" --cert-name $domain )
if [ $? -ne 0 ];then
   subject="Error in renewing cert $domain,cert due for renewal"
   mail_body=" "
   sudo /opt/scripts/mail_send.sh "$subject" "$mail_body"
fi
}
filepath="$script_path/domain_elb_map.txt"
while IFS= read line
do
domain=$(echo "$line" | awk '{print $1}')
elb=$(echo "$line" | awk '{print $2}')
cron_renew $domain $elb $script_path $1
done <"$filepath"
