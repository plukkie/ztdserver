#!/bin/bash

ZTD_SERVER_IP=
CGI_HOSTNAME_SCRIPT=
ZTD_PATH=
HOSTNAMES=
IMAGE_PATH=
OS_IMAGE=
POSTSCRIPT_PATH=
POSTSCRIPT_FILE=
CLI_CONF_FILE=
CLI_CONF_PATH=
TMP=/tmp/
HOME=/home
ZTD_LOGFILE=ztd.log
LOG=$TMP$ZTD_LOGFILE
APP="http://"
CURL=`type -tP curl`

#IMG_FILE="$APP$ZTD_SERVER_IP$ZTD_PATH$IMAGE_PATH/$OS_IMAGE"
CLI_CONFIG_FILE="$APP$ZTD_SERVER_IP$ZTD_PATH$CLI_CONF_PATH/$CLI_CONF_FILE"
#POST_SCRIPT_FILE="http://192.168.99.99/tftpboot/post_script.py"
POST_SCRIPT_FILE="$APP$ZTD_SERVER_IP$ZTD_PATH$POSTSCRIPT_PATH/$POSTSCRIPT_FILE"

## Execute server side script that will fetch hostnames and mac mapping
$CURL $APP$ZTD_SERVER_IP$CGI_HOSTNAME_SCRIPT

echo "Request server side hostname mapping preperation :  $APP$ZTD_SERVER_IP$CGI_HOSTNAME_SCRIPT" >> $LOG

## Download the file with hostname to mac mapping
$CURL -o $HOME/$HOSTNAMES $APP$ZTD_SERVER_IP$ZTD_PATH/$HOSTNAMES

echo "Retreived $HOSTNAMES from server and saved to $HOME/$HOSTNAMES" >> $LOG

################### DO NOT MODIFY THE LINES BELOW ##################
sudo os10_ztd_start.sh "$IMG_FILE" "$CLI_CONFIG_FILE" "$POST_SCRIPT_FILE"
############################# **END** #################################
