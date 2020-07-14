#!/bin/bash

## Set SFDMODE to 1 converts switch to SFD managed, set to 0 puts in normal mode
SFDMODE=0
USER_NAME=admin
HOSTNAMES=
TMP=/tmp
HOME=/home
PASSWORD=admin
MGMT_IP=localhost
APP=https://
GREP=`type -tP grep`
ZTD_LOGFILE=post_script.log
LOG=$TMP/$ZTD_LOGFILE

## Extract the ip-address that was received from dhcp server
DHCP_IP=`curl -k -H "Accept: application/json" -u $USER_NAME:$PASSWORD -X GET $APP$MGMT_IP/restconf/data/ietf-interfaces:interfaces-state/interface=mgmt1%2F1%2F1/dell-ip:ipv4-info \
        | cut -d':' -f5 | cut -d'}' -f1`

## Get default gateway from dhcp lease
GW=`curl -k -H "Accept: application/json" -u $USER_NAME:$PASSWORD -X GET $APP$MGMT_IP/restconf/data/dell-management-routing:mgmt-if-route-oper/mgmt-rib=ipV4,nlriUnicast/route | cut -d',' -f2|cut -d':' -f2`

echo "DHCP IP Address received : $DHCP_IP" >> $LOG
echo "gateway received : $GW" >> $LOG

## Extract the mac address of the switch
STRING=`curl -k -H "Accept: application/json" -u $USER_NAME:$PASSWORD -X GET $APP$MGMT_IP/restconf/data/ietf-interfaces:interfaces-state/interface=mgmt1%2F1%2F1/phys-address`

STRING=${STRING##*\address\":\"}
MAC=${STRING%%\"*}

echo "MAC address switch mgt interface : $MAC" >> $LOG

## This is the hostname that needs to be set via a restcall
## 1. remove { at end
SWITCHNAME=$($GREP -B1 $MAC $HOME/$HOSTNAMES | $GREP host | cut -d'{' -f1)
## 2. remove host from begin
SWITCHNAME=${SWITCHNAME##*\host}
## 3. remove all spaces
SWITCHNAME=`echo -e $SWITCHNAME | tr -d '[:space:]'`
## 4. Add quotes
## SWITCHNAME=\"$SWITCHNAME\"

echo "Found switch hostname to use : $SWITCHNAME" >> $LOG

## Set hostname
curl -i -k -H "Accept: application/json" -H "Content-Type: application/json" -u $USER_NAME:$PASSWORD -d'{"dell-system:system":{"hostname": "'"$SWITCHNAME"'" }}' -X PATCH $APP$MGMT_IP/restconf/data/dell-system:system

## Delete dhcp setting from config
curl -i -k -H "Accept: application/json" -H "Content-Type: application/json" -u $USER_NAME:$PASSWORD -X DELETE $APP$MGMT_IP/restconf/data/ietf-interfaces:interfaces/interface=mgmt1%2F1%2F1/dell-ip:ipv4/dell-ip:dhcp-config

## Set mgmt address fixed in config
curl -i -k -H "Accept: application/json" -H "Content-Type: application/json" -u $USER_NAME:$PASSWORD -d'{"ietf-interfaces:interfaces":{"interface":[{"name":"mgmt1/1/1","dell-ip:ipv4":{"address":{"primary-addr": '$DHCP_IP' }}}]}}' -X PATCH $APP$MGMT_IP/restconf/data/ietf-interfaces:interfaces

## Set static default route
curl -i -k -H "Accept: application/json" -H "Content-Type: application/json" -u $USER_NAME:$PASSWORD -d '{"dell-management-routing:ipv4-mgmt-routes":{"route":[{"destination-prefix":"0.0.0.0/0","forwarding-router-address":'$GW'}]}}' -X PATCH $APP$MGMT_IP/restconf/data/dell-management-routing:ipv4-mgmt-routes

## Here you can set specific settings matched on the mac-address
## ============= START specific settings =========================

## Set some interface breakout maps for Spines from 100 to 40G
##SWITCHARRAY=( "54:bf:64:bf:f4:c0" "54:bf:64:b9:23:40" ) #Spine01, Spine02
##PORTARRAY=( "1/1/1" "1/1/2" "1/1/3" "1/1/4" )

##for c in ${!SWITCHARRAY[@]}; do
##        if [ $MAC == ${SWITCHARRAY[$c]} ]
##                then
##                        ## Set breakout from 100G to 40G
##                        for p in ${!PORTARRAY[@]}; do
##                                port=phy-eth${PORTARRAY[$p]}
##                                curl -i -k -H "Accept: application/json" -H "Content-Type: application/json" -u $USER_NAME:$PASSWORD -d '{"dell-port:ports":{"port":[{"name":"'"$port"'","breakout-mode":"BREAKOUT_1x1","speed":"40GIGE"}]}}' -X PATCH https://$MGMT_IP/restconf/data/dell-port:ports
##                                sleep 1
##                        done
##        fi
##done

## =============  END specific settings  =========================


## Set switch-mode to SFD managed
if [ $SFDMODE = 1 ]; then
        curl -i -k -H "Accept: application/json" -H "Content-Type: application/json" -u $USER_NAME:$PASSWORD -d '{"dell-system:system":{"system-mode":"sfd"}}' -X PATCH $APP$MGMT_IP/restconf/data/dell-system:system
         echo "switch mode set to SFD : SFDMODE=1" >> $LOG
fi

## Save config permanent
curl -i -k -H "Accept: application/json" -H "Content-Type: application/json" -u $USER_NAME:$PASSWORD -d'{"yuma-netconf:input":{"target":{"startup":[null]},"source":{"running":[null]}}}' -X POST $APP$MGMT_IP/restconf/operations/copy-config


