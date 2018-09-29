#!/bin/bash -ex
. ../config/config.sh $1 $2
if [ "$#" -ne 2 ]; then
    echo "Illegal number of parameters"
fi
arn_sample=$(sudo aws --profile letsencrypt_certs iam list-server-certificates --max-items 1 | jq .ServerCertificateMetadataList[0].Arn |  sed 's/\"//g')
sudo aws --profile letsencrypt_certs elb create-load-balancer-listeners --load-balancer-name $load_balancer_name --listeners "Protocol=HTTPS,LoadBalancerPort=443,InstanceProtocol=HTTP,InstancePort=8080,SSLCertificateId=$arn_sample"
sudo certbot --debug -v  certonly  --preferred-challenges http  --webroot -w $webroot -d $domain #-d  www.$domain
#copying the cert to both
for web_box in ${web_boxes[*]}; do
    sudo rsync --copy-links -r -e "ssh -i $ssh_priv_path" $base_path/ "admin@$web_box:$docroot/"
done
#uploading the cert to iam
arn=$(sudo aws --profile letsencrypt_certs iam upload-server-certificate --server-certificate-name $cur_cert_name --certificate-body file://$base_path/cert.pem --private-key file://$base_path/privkey.pem --certificate-chain file://$base_path/chain.pem | jq .ServerCertificateMetadata.Arn | sed 's/\"//g')
sleep 40
#Asudo elb create-load-balancer-listeners --load-balancer-name $load_balancer_name --listeners "Protocol=HTTPS,LoadBalancerPort=443,InstanceProtocol=TCP,InstancePort=8080,SSLCertificateId=$arn"
sudo aws --profile letsencrypt_certs elb set-load-balancer-listener-ssl-certificate --region us-west-2 --load-balancer-name $load_balancer_name  --load-balancer-port 443 --ssl-certificate-id "$arn"
#elb_dns_name=$(sudo aws --profile letsencrypt_certs elbv2 create-load-balancer --load-balancer-name $load_balancer_name --listeners "Protocol=TCP,LoadBalancerPort=80,InstanceProtocol=TCP,InstancePort=8082" "Protocol=HTTPS,LoadBalancerPort=443,InstanceProtocol=TCP,InstancePort=8080,SSLCertificateId=$arn" --security-groups $security_groups --tags "Purpose:$domain\ elb" "Owner:Oshin\ Agarwal"  --availability-zones "us-west-2a" --scheme "internet-facing" --subnet "subnet-c67ef0a1" | jq .DNSName  | sed 's/\"//g')
#sudo aws --profile letsencrypt_certs elbv2 configure-health-check --load-balancer-name $load_balancer_name --health-check "Target=HTTP:8080/index.php,Interval=30,UnhealthyThreshold=2,HealthyThreshold=5,Timeout=5"
#sudo elbv2 register-instances-with-load-balancer --load-balancer-name $load_balancer_name --instances "i-032a22d38d71316bc" "i-02bf63cb4b740d052"
echo $domain $load_balancer_name  >> $script_path/domain_elb_map.txt
echo imap.email.$domain
echo smtp.email.$domain
sudo  php $mysql_users_add_path/generatePwd.php $environment $domain
sudo scp -i $ssh_priv_path  $mysql_users_add_path/user_Data/$mysql_load_file admin@$mysql_master:$mysql_secure_priv
mysql -h $mysql_master -u db_admin -p --execute "delete from $mysql_temp_table  ;LOAD DATA INFILE '$mysql_secure_priv/$mysql_load_file' INTO TABLE $mysql_temp_table(EmailUser,EmailHost,EmailDir,EmailPassword) set PerDayEmailThreshold=6,status=0;select count(*) from $mysql_temp_table"
