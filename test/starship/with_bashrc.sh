#!/bin/bash
 
set -e
source dev-container-features-test-lib

echo "USER ENVS:"
# cat /root/user
#cat ~/.bashrc
#ls  ~/test

check 'starship executable is installed' which starship | grep starship
#check 'config file exists' ls ~/.bashrc.d/50_starship.sh


reportResults
