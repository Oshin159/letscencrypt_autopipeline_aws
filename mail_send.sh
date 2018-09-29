#!/bin/bash
#specify first  the subject then the mail body
mailbody=$2
subject=$1
sender="XXX"
#smtp_relay="XXX"
#smtp_auth_user="XXX"
#smtp_auth_pass="XXX"
receiver="XXX"
echo $mailbody | mailx  -s "$subject" -S from=$sender  -S ssl-verify=ignore  -S nss-config-dir="/etc/pki/nssdb/" $receiver
#echo $mailbody |mail -r "iphonesysad" -s  "$subject" $receiver
if [ $? -ne 0 ] ;then
 echo "Mail sending failed:$subject $mailbody" >>/var/log/cert_renew.log
fi
