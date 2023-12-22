#!/bin/bash

##########################################
# This script uploads and overwrites     #
# a startup configuration on a SONiC     #
# switch.                                #
#                                        #
# dependencies                           #
# - sshpass                              #
# - jq                                   #
# - curl                                 #
##########################################

#########       CONSTANTS        ######### 
username='admin'
passwordlist=( "admin123" "YourPaSsWoRd" )
urlprot="https://"
##########################################

## If no arguments found, display help
if [ "$#" -eq 0 ] || [ "$1" == "help" ] || [ "$1" == "-help" ] || [ "$1" == "-h" ]; then
  echo
  echo "No arguments provided. Options are:"
  echo " -c, -f <configfile>            Configuration file to upload"
  echo " -i, -s <hostname/ip-address>   IP-address or hostname of target switch"
  echo " -a     <load>	                Copy uploaded config to startup and to running config"
  echo "        <reboot>                Copy uploaded config to startup and reboot switch (default)"
  echo
  exit
fi

## Get CLI arguments
while getopts c:f:i:s:a: flag
  do
    case "${flag}" in
        c) config=${OPTARG};;
        f) config=${OPTARG};;
        i) host=${OPTARG};;
        s) host=${OPTARG};;
	a) activate=${OPTARG};;
    esac
done

## Set defaults
if [ -z $activate ] ; then activate="reboot" ; fi

echo -e "\nItems used:"
echo -e "------------------------------------"
echo -e " - config: $config";
echo -e " - target switch: $host";
echo -e " - activate: $activate\n";
sleep 3

echo -e "Fetching authorization token..."

for pwd in ${passwordlist[@]}; do
  ## Construct authentication credentials json
  json="{ \"username\" : \"$username\", \"password\" : \"$pwd\" }"
  ## Authenticate to SONiC and receive JWT token
  resp=`curl -s -k -X POST $urlprot$host/authenticate -d "$json"`
  ## Substract access_token key value
  token=`echo $resp |jq -r '.access_token'`
  ##If there is a token received and thus not zero or auth failure create auth string
  if [ ! -z "$token" ] && [ "$token" != null ]
    then
      ## Construct json string for token auth and set defaultpwd
      authstring="Authorization: Bearer $token"
      defaultpwd=$pwd
      break
  fi
done

if [ "$authstring" == "" ] || [ -z "$authstring" ]
  ## No token received
  then
    echo -e "ERROR, was not able to receive a token.\nFaulty username or password?\n"
    exit
fi

sleep 3 && echo -e "Successfully received authorization token..." && sleep 3

## Upload configfile to switch
echo -e "Upload configfile '$config' to $host..." && sleep 3
sshpass -p "$defaultpwd" scp -o StrictHostKeyChecking=no $config $username@$host:
echo "Done" && sleep 3

# Receive system metadata
#resp=`curl -s -k -X GET  $urlprot$host/restconf/data/sonic-device-metadata:sonic-device-metadata -H \"accept: application/yang-data+json\" -H "$authstring"|jq|sed '$ s/}$/,/'`

## Upload configuration to homedir and write it to startup config
curl -k -X POST $urlprot$host/restconf/operations/openconfig-file-mgmt-private:copy -H "accept: application/yang-data+json" -H "$authstring" -H "Content-Type: application/yang-data+json" -d "{\"openconfig-file-mgmt-private:input\":{\"source\":\"home://$config\",\"destination\":\"startup-configuration\"}}"

if [ "$activate" == "load" ]
  then ## Copy config to running

    curl -k -X POST $urlprot$host/restconf/operations/openconfig-file-mgmt-private:copy -H "accept: application/yang-data+json" -H "$authstring" -H "Content-Type: application/yang-data+json" -d "{\"openconfig-file-mgmt-private:input\":{\"source\":\"home://$config\",\"destination\":\"running-configuration\", \"copy-config-option\":\"REPLACE\"}}"

  else ## Reboot switch (default)

    ## Reboot switch
    echo -e "Send switch reboot command, this will take some minutes..." && sleep 3
    sshpass -p "$defaultpwd" ssh -t -o StrictHostKeyChecking=no $username@$host "sudo /sbin/shutdown -r now"
    echo -e "Rebooting...\n"
fi
