# Sourced from https://stackoverflow.com/questions/56280806/ansible-dynamic-inventory-with-bash-script
#! /bin/bash

INVENTORY=$(mktemp -t dynhostsXXXX.yaml)

cat << EOF > ${INVENTORY}
all:
  hosts:
    siteframework.service.consul:
  children:
    ssh:
      children:
        ApplicationFoo:
        AutoScalingGroupBar:
        zabbix:
EOF

aws --profile example-prod \
    --region eu-west-1 \
    --output json \
    ec2 describe-instances  |\
    jq -r '.Reservations[].Instances[] | "\(
    if .Tags then .Tags[] |
        select ( .Key == "Environment" ) | .Value else "-" end
    )%\(
        if .Tags then .Tags[] | select ( .Key == "Name" ) |
        .Value else "-" end
    )%\(
        .InstanceId
    )%\(
        if .PrivateIpAddress then .PrivateIpAddress else "-" end
    )%\(
       .State.Name 
    )"' |\
   grep "%running" |\
   sort |\
   awk -F'%' '
       $2FS==x{
           printf "        %s:\n          ansible_host: %s\n", $3, $4
           next
       }
       {
           x=$2FS
           printf "\n    %s:\n      hosts:\n        %s:\n          ansible_host: %s\n", x, $3, $4
       }
       END {
           printf "\n"
       }' |  sed 's/%//g' >> ${INVENTORY}

if [ "$1" == "--list" ]; then
    ansible-inventory -i ${INVENTORY} --list
elif [ "$1" == "--host" ]; then
    echo '{"_meta": {hostvars": {}}}'
else
    echo "{ }"
fi

rm ${INVENTORY}