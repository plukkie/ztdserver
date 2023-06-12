#!/bin/bash

#######################################
# This script collects inventory data
# - JWT token
# - LLDP neighbors
#######################################

# BEGIN CONSTANTS
username='admin'
password='YourPaSsWoRd'
inventorypath=/tftpboot/ifabric_inventory/
scriptname="get_inventory.sh"
filtered_lldp_filesuffix='.lldp_neighbors'
# END CONSTANTS

cd $inventorypath

for pid in $(pidof -x $scriptname); do
    if [ $pid != $$ ]; then
        echo "[$(date)] : $scriptname : Process is already running with PID $pid"
        exit 1
    fi
done

for file in *
do
  if [ ! -z "$file" ] && [ $file != '*' ]
    then
       # construct authentication credentials json
       json="{ \"username\" : \"$username\", \"password\" : \"$password\" }"
       # Authenticate to SONiC and receive JWT token
       resp=`curl -s -k -X POST https://$file/authenticate -d "$json"`
       # Substract access_token key value
       token=`echo $resp |jq -r '.access_token'`

       if [ ! -z "$token" ] #If there is a token received and thus not zero
         then

           authstring="Authorization: Bearer $token" # Construct json string for token auth
           
           # Receive system metadata
	   resp=`curl -s -k -X GET https://$file/restconf/data/sonic-device-metadata:sonic-device-metadata -H \"accept: application/yang-data+json\" -H "$authstring"|jq|sed '$ s/}$/,/'`
	   json=$resp

	   # Receive interfaces
           resp=`curl -s -k -X GET https://$file/restconf/data/openconfig-interfaces:interfaces -H \"accept: application/yang-data+json\" -H "$authstring"|jq|sed 's/^{//'|sed '$ s/}$/,/'`
	   json=$json$resp

	   # Receive LLDP neighbor data
           resp=`curl -s -k -X GET https://$file/restconf/data/openconfig-lldp:lldp -H \"accept: application/yang-data+json\" -H "$authstring"|jq|sed 's/^{//'`
	   json=$json$resp

	   # Add all data in JSON nice organized to file
	   echo $json|jq > $file

	   # Create filtered LLDP neighbors file
	   jq -r '."openconfig-lldp:lldp".interfaces.interface|.[] | select(.neighbors.neighbor != null)|.neighbors.neighbor[]|[ .id, .state ]' $file > $file$filtered_lldp_filesuffix

         else # API access to device failed
           echo -e "\nCan not get API access to $file\n"
       fi
  fi
done
