#!/bin/bash -ex
if [ "$#" -ne 2 ]; then
    echo "Illegal number of parameters"
    echo "param 1:production or staging"
    echo "param 2: domain_name"
fi
. ../config/config.sh $1 $2
elb_dns_name=$(sudo aws --profile letsencrypt_certs elb create-load-balancer --load-balancer-name $load_balancer_name --listeners "Protocol=TCP,LoadBalancerPort=80,InstanceProtocol=TCP,InstancePort=8082" --security-groups $security_groups --tags "Key=Purpose,Value=$domain elb" "Key=Owner,Value=Oshin Agarwal"  --scheme "internet-facing" --subnet $subnet | jq .DNSName  | sed 's/\"//g')
sudo aws --profile letsencrypt_certs elb configure-health-check --load-balancer-name $load_balancer_name --health-check "Target=HTTP:8080/elbtest.php,Interval=30,UnhealthyThreshold=2,HealthyThreshold=2,Timeout=5"
sudo aws --profile letsencrypt_certs elb register-instances-with-load-balancer --load-balancer-name $load_balancer_name --instances ${web_instance_ids[@]}
echo $elb_dns_name
sudo sed -e "s/\$domain/$domain/g" -e "s/\$elb_name/$elb_dns_name/g" dns.txt >$dns_file_name
