

env > /tmp/init
#echo "\nBASH_SOURCE=$( eval ${BASH_SOURCE[0]})" >>/tmp/init
cat >/tmp/hellotmp <<EOS
echo '############################################################'
echo /tmp/init
echo '############################################################'
cat /tmp/init
echo '############################################################'
echo /tmp/post_attach_env
echo '############################################################'
cat /tmp/post_attach_env
echo '############################################################'
echo /tmp/post_start_env
echo '############################################################'
cat /tmp/post_start_env
echo '############################################################'
echo /tmp/post_create_env
echo '############################################################'
cat /tmp/post_create_env
echo '############################################################'
echo /tmp/on_create_env
echo '############################################################'
cat /tmp/on_create_env
echo '############################################################'
echo /tmp/update_content_env
echo '############################################################'
cat /tmp/update_content_env
exit 1
EOS