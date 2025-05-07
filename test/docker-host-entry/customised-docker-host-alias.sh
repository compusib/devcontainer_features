#!/bin/bash
 
set -e
source dev-container-features-test-lib

echo "USER ENVS:"
# cat /root/user
#cat ~/.bashrc
#ls  ~/test

check 'alias is found in /etc/hosts' grep customised-docker-host-alias /etc/hosts
check 'alias ip is found in /etc/hosts' grep "$GATEWAY_IP " /etc/hosts

#check 'config file exists' ls ~/.bashrc.d/50_starship.sh


reportResults
