#!/bin/bash

ZTPFINISH=ztp_finished
TFTPBOOT=/var/www/html/tftpboot


rm $TFTPBOOT/$ZTPFINISH/*.ztp*finished*


## These lines are needed to echo back to apache server and avoid errors
echo Content-type: text/html
echo
