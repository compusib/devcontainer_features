
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

if [ $PATHAPPEND ]; then
    echo "export PATH=${PATH}:$PATHAPPEND" > ${_REMOTE_USER_HOME}/.bashrc.d/10_bash_path_append.sh
fi

if [ $GITROOT ]; then
    echo "export GIT_ROOT=$GITROOT" >  ${_REMOTE_USER_HOME}/.bashrc.d/01_GIT_ROOT_env.sh
fi


chown -R "${_REMOTE_USER}" "${_REMOTE_USER_HOME}/.bashrc.d"
