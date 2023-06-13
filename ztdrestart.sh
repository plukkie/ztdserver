#!/bin/bash

containerid_jenkins=`docker ps -a | grep jenkins-blueocean | awk '{print $1}'`
containerid_ztdserver=`docker ps -a | grep ztd.*httpd | awk '{print $1}'`
ztdefault_network='ztdserver_default'

docker network disconnect $ztdefault_network $containerid_jenkins

cd /home/peter/ztdserver
docker-compose down && docker-compose up -d
docker start $containerid_jenkins

docker network connect $ztdefault_network $containerid_jenkins
docker network connect jenkins $containerid_ztdserver

