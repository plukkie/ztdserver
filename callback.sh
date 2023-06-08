#!/bin/bash

DHCPD_CONF=/etc/dhcp/dhcpd.conf
TFTPBOOT=/var/www/html/tftpboot
CALLBACK=callback
SED=`type -p sed`
GREP=`type -tP grep`

# Extract hostname from dhcpd.conf matching dhcp ip-address
grep -i "[^#]host\|[^#]fixed-address.*${REMOTE_ADDR}\;" ${DHCPD_CONF} | \
grep -B1 ${REMOTE_ADDR} | sed 's/^.*host *//' | sed 's/ {//' | \
grep -v ${REMOTE_ADDR} > $TFTPBOOT/$CALLBACK/$REMOTE_ADDR

## These lines are needed to echo back to apache server and avoid errors
echo Content-type: text/html
echo

