
#. debug.sh
mkdir -p "${_REMOTE_USER_HOME}/.bashrc.d"
cat >> "$_REMOTE_USER_HOME/.bashrc" <<EOBASHRC 
######## CONTAINER FEATURE bashrc #####################
#This reads all files ending in .sh from ~/.bashrc.d

for filename in \$HOME/.bashrc.d/*.sh; do
    . \$filename
done
######### end CONTAINER FEATURE bashrc ################
EOBASHRC
chown -R "${_REMOTE_USER}" "${_REMOTE_USER_HOME}/.bashrc.d"
