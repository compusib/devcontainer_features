
set -e
curl -sS https://starship.rs/install.sh | sh -s -- -y


ENV_CMD=$(cat <<EOCMD

if [ -f "$CONFIGFILE" ]; then
    export STARSHIP_CONFIG="$CONFIGFILE"
fi

EOCMD
)
START_CMD='eval $(starship init bash)'
env >> $_REMOTE_USER_HOME/.bashrc

if [ -d "$_REMOTE_USER_HOME/.bashrc.d" ] ; then 
    #bashrc installed
    
    echo "$ENV_CMD" > "$_REMOTE_USER_HOME/.bashrc.d/50_starship.sh"

    if [ "$STARTFROMBASHRC" = "true" ]; then
        echo "$START_CMD" >> "$_REMOTE_USER_HOME/.bashrc.d/50_starship.sh"
    fi
    chown $_REMOTE_USER "$_REMOTE_USER_HOME/.bashrc.d/50_starship.sh"
else
    #bashrc not installed
    
    echo "$ENV_CMD" >> "$_REMOTE_USER_HOME/.bashrc"
    
    if [ "$STARTFROMBASHRC" = "true" ]; then
        echo "$START_CMD" >> "$_REMOTE_USER_HOME/.bashrc"
    fi
fi

