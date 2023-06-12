#!/bin/bash

DHCPD_CONF=/etc/dhcp/dhcpd.conf
TFTPBOOT=/var/www/html/tftpboot
HOSTNAMES=hostnames.dyn
SED=`type -p sed`
GREP=`type -tP grep`

## Find lines with string "host {" and string "hardware"
## delete all other lines
## Then remove all commented out lines
$SED '/host.*{/,/hardware/!d' $DHCPD_CONF | $GREP -v "#" > $TFTPBOOT/$HOSTNAMES

## These lines are needed to echo back to apache server and avoid errors
echo Content-type: text/html
echo


