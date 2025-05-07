
set -e
curl -sS https://starship.rs/install.sh | sh -s -- -y

DOCKERHOSTALIAS=${DOCKERHOSTALIAS:-"host"}
SET_ETC_HOSTS_CMD=$(cat <<EOCMD

GATEWAY_IP=\$(ip route show default | cut -d ' ' -f 3)
if ! grep "\$GATEWAY_IP " /etc/hosts; then
  echo Setting $DOCKERHOSTALIAS and host.docker.internal to \$GATEWAY_IP
  echo  \$GATEWAY_IP $DOCKERHOSTALIAS host.docker.internal | sudo tee -a /etc/hosts > /dev/null
fi

EOCMD
)
if [ -d "$_REMOTE_USER_HOME/.bashrc.d" ] ; then 
    #bashrc installed
    
    echo "$SET_ETC_HOSTS_CMD" > "$_REMOTE_USER_HOME/.bashrc.d/20_docker_host.sh"
    chown $_REMOTE_USER "$_REMOTE_USER_HOME/.bashrc.d/20_docker_host.sh"
else
    #bashrc not installed
    echo "$SET_ETC_HOSTS_CMD" >> "$_REMOTE_USER_HOME/.bashrc"
fi

