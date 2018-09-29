#!/bin/bash
. ../config/config.sh $3 $1

elb_name=$2
domain_name=$1
eco_system=$3

echo $cur_cert_name

for ip in ${web_boxes[*]}
do
ssh_error=$(sudo scp -r -i $ssh_priv_path  $base_path  admin@$ip:$docroot)
subject="updated renewed certs at servers"
mail_body=""
if [ $? -ne 0 ];then
  subject="could not update renewed certs at the servers"
  mail_body="Server ip:$ip \n Error:$ssh_error "
fi
sudo /opt/scripts/mail_send.sh "$subject" "$mail_body" >/dev/null 2>/dev/null
done
upload_cert=$(sudo aws  --profile letsencrypt_certs iam upload-server-certificate --server-certificate-name $cur_cert_name --certificate-body file://$base_path/cert.pem --private-key file://$base_path/privkey.pem --certificate-chain file://$base_path/chain.pem 2>&1 )
if [ $? -eq 0 ];then
   arn=$(echo $upload_cert | jq .ServerCertificateMetadata.Arn | sed 's/\"//g' )
   if [ ! -z "$arn" ];then
       sleep 40
       elb_update=$(sudo aws elb set-load-balancer-listener-ssl-certificate --region us-west-2 --load-balancer-name $elb_name  --load-balancer-port 443 --ssl-certificate-id "$arn" 2>&1)
       if [ $? -ne  0 ];then
         subject="$domain cert renewed ,upload to acm successful,elb update failed"
         mail_body="Error:$elb_update"
       else
         subject="$domain cert renewed,updated in acm and elb succesfully"
         mail_body="Don't worry"
       fi
   else
       subject="$domain cert renewed,upload to aws failed"
       mail_body="arn not found"
   fi
else
   subject="$domain cert renewed, but upload to elb failed"
   mail_body="Error: $upload_cert"
fi
sudo /opt/scripts/mail_send.sh "$subject" "$mail_body" >/dev/null 2>/dev/null
#aws iam get-server-certificate --server-certificate-name $cur_cert_name | jq .ServerCertificate.ServerCertificateMetadata.Arn | jq .ServerCertificate.ServerCertificateMetadata.Arn | sed 's/\"//g'
