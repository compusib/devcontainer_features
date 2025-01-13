
RUNFILE="$_REMOTE_USER_HOME/.bashrcFeatureInstallCounter"

if [ -e $RUNFILE ]; then
  echo "RUNFILE exists"
else
  touch  $RUNFILE
  . ./do_install.sh
fi

# function run_count {
#     local RUNFILE=$1
#     local count;
#     if [ -e $RUNFILE ]; then
#         if [ ! -d $(dirname $RUNFILE) ]; then
#             mkdir -p $(dirname $RUNFILE)
#         fi
#     else
#         local count=$(cat $RUNFILE)
#     fi
#     ((count++))
#     echo $count > $RUNFILE
#     echo $count
# }
# count=$(run_count $RUNFILE)
# echo !!!!!!!!!!!!!!!!COUNT=$count
# if [ $count =  1 ] ; then

#    . ./do_install.sh
# fi

