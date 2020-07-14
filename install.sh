#!/bin/bash

################################################
# This script will install required application
# packages for the ZTD server.
# You do not need to set variable values.
# The script has default values set. Just run
# and enjoy your zero touch deployment setup
# in minutes!
# 
# Tested on:
# - Ubuntu 20.04 LTS
#
# requirements
# - A base Linux server with internet connectivity
# - The server needs to be directly connected
#   to the management network. This is the network
#   where the network fabric switches have their
#   management interfaces connected.
# - run this installer as root
#
# greetings from plukkie@gmail.com
################################################

DHCPPOOL=0
DHCPSTART=151
DHCPSTOP=170
DOCKERHUB_HTTP_IMAGE="enonicio/apache2"
DOCKERHUB_DHCP_IMAGE="rackhd/isc-dhcp-server"
WWWUSER="www-data"
TFTPBOOT=/tftpboot
HTTPCONTAINERNAME=ztd-httpd
DHCPCONTAINERNAME=ztd-dhcpd
HTTPPATH=/var/www/html
CGISCRIPT=catch_hostnames.sh
HOSTNAMESFILE=hostnames.dyn
DHCP_PATH=/etc/dhcp
DHCPD_CONF=dhcpd.conf
ONIE_DEFAULT_BOOT=onie-installer-x86_64
OS_IMAGES=/osimages
ZTD_PATH=/ztd
ZTD_SCRIPT=ztd.sh
CLI_CONFIG_PATH=/cli_config
CLI_CONFIG_FILE=cli_config
POST_SCRIPT_PATH=/post_script
POST_SCRIPT_FILE=post_script.sh
APT=`type -tP apt`
APTCACHE=`type -fP apt-cache`
APTKEY=`type -tP apt-key`
APT_DOCKER_REPO=`type -tP add-apt-repository`
CURL=`type -tP curl`
SYSCTL=`type -tP systemctl`
USERMOD=`type -tP usermod`
USER=`logname`
ETH_INT=`ip addr show | grep -i UP | grep -iv docker | grep -iv loop | cut -d':' -f2`
IP=`ifconfig ${ETH_INT} | grep -i inet.*netmask | awk '/inet/{print $2}'`
SUBNETDATA=`netstat -rn | grep ${ETH_INT} | grep -v G | awk '{print $1, $3}'`
SUBNET=`echo ${SUBNETDATA} | cut -d' ' -f1`
NETMASK=`echo ${SUBNETDATA} | cut -d' ' -f2`
GW=`netstat -rn | grep ${ETH_INT} | grep G | awk '{print $2}'`

## ======================== START PROGRAM ====================
echo -e "\n-- update existing list of packages\n"
$APT update

echo -e "\n-- install a few prerequisite packages which let apt use packages over HTTPS\n"
$APT install -y apt-transport-https ca-certificates curl software-properties-common net-tools

echo -e "\n-- add the GPG key for the official Docker repository to your system\n"
$CURL -fsSL https://download.docker.com/linux/ubuntu/gpg | $APTKEY add -

echo -e "\n-- Add the Docker repository to APT sources\n"
$APT_DOCKER_REPO "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable"

echo -e "\n-- update existing list of packages\n"
$APT update

echo -e "\n-- Policy for docker-ce should be from Docker repo\n"
$APTCACHE policy docker-ce

echo -e "\n-- Install docker-ce\n"
$APT install -y docker-ce

echo -e "\n-- Calling status docker\n"
$SYSCTL status docker -n0

echo -e "\n-- Adding current user '${USER}' to the the dockergroup."
echo -e "   This avoids the need to 'sudo' the docker command.\n"
$USERMOD -aG docker ${USER}

echo -e "\n-- Setting up ZTD staging folder structure...\n"
echo -e "    ${TFTPBOOT}"
[ ! -d "${TFTPBOOT}" ] && mkdir ${TFTPBOOT}
echo -e "    ${TFTPBOOT}${OS_IMAGES}"
[ ! -d "${TFTPBOOT}${OS_IMAGES}" ] && mkdir ${TFTPBOOT}${OS_IMAGES}
echo -e "    ${TFTPBOOT}${ZTD_PATH}"
[ ! -d "${TFTPBOOT}${ZTD_PATH}" ] && mkdir ${TFTPBOOT}${ZTD_PATH}
echo -e "    ${TFTPBOOT}${CLI_CONFIG_PATH}"
[ ! -d "${TFTPBOOT}${CLI_CONFIG_PATH}" ] && mkdir ${TFTPBOOT}${CLI_CONFIG_PATH}
echo -e "    ${TFTPBOOT}${POST_SCRIPT_PATH}\n"
[ ! -d "${TFTPBOOT}${POST_SCRIPT_PATH}" ] && mkdir ${TFTPBOOT}${POST_SCRIPT_PATH}
touch ${TFTPBOOT}${OS_IMAGES}/${DUMMY_OS_BIN}

cat /etc/passwd | grep -q ${WWWUSER}
if [ $? -eq 0 ] ; then
	echo -e "-- User '${WWWUSER}' Exists, no need to create :-)\n"
else
	echo -e "-- Creating user and group '${WWWUSER}'\n"
	useradd -c ${WWWUSER} -d /var/www -M -U -s /usr/sbin/nologin ${WWWUSER}
fi

## Setting up dhcpd.conf file with some mandatory items
[ ! -d "${DHCP_PATH}" ] && mkdir ${DHCP_PATH}

grep "### Inserted by Plukkie's ZTD Github project - DON'T EDIT THIS LINE ###"  ${DHCPD_CONF}
if [ $? -eq 1 ] ; then ## First run, file is not updated before by this install script

echo "" >> ${DHCPD_CONF}
echo -e "### Inserted by Plukkie's ZTD Github project - DON'T EDIT THIS LINE ###\n" >> ${DHCPD_CONF}
sed -i 's/#authoritative;/authoritative;/g' ${DHCPD_CONF}
if grep -Fxq "authoritative;" ${DHCPD_CONF}; then
	echo
else ## string not found
	echo -e "authoritative;\n" >> ${DHCPD_CONF}
fi

grep "^option domain-name-servers" ${DHCPD_CONF}
if [ $? -eq 1 ] ; then ## Does not exist
	echo -e "option domain-name-servers 8.8.8.8, 8.8.4.4;\n" >> ${DHCPD_CONF}
fi

echo -e "## option to specifiy Dell vendor specific ztd staging code" >> ${DHCPD_CONF}
echo -e "option ztd-provision-url code 240 = text;\n" >>  ${DHCPD_CONF}
echo -e "#This is the subnet where the management interfaces connect to" >> ${DHCPD_CONF}
echo -e "subnet ${SUBNET} netmask ${NETMASK} {" >> ${DHCPD_CONF}
if [ ${DHCPPOOL} = 1 ]; then
	echo -e "        range ${SUBNET%\.*}.${DHCPSTART} ${SUBNET%\.*}.${DHCPSTOP};"  >> ${DHCPD_CONF}
fi
echo -e "        option routers ${GW};" >> ${DHCPD_CONF}
echo -e "}\n" >> ${DHCPD_CONF}
echo -e "## Per switch entry for fixed IP and ZTD kickoff script" >> ${DHCPD_CONF}
echo -e "group {" >> ${DHCPD_CONF}
echo -e "        option ztd-provision-url \"http://${IP}${TFTPBOOT}${ZTD_PATH}/${ZTD_SCRIPT}\";" >> ${DHCPD_CONF}
echo -e "\n#        host SPINE01 {" >> ${DHCPD_CONF}
echo -e "#                hardware ethernet 54:bf:64:00:00:01;" >> ${DHCPD_CONF}
echo -e "#                fixed-address 10.11.12.11;" >> ${DHCPD_CONF}
echo -e "#        }" >> ${DHCPD_CONF}
echo -e "#        host LEAF01 {" >> ${DHCPD_CONF}
echo -e "#                hardware ethernet 54:bf:64:00:01:01;" >> ${DHCPD_CONF}
echo -e "#                fixed-address 10.11.12.21;" >> ${DHCPD_CONF}
echo -e "#        }" >> ${DHCPD_CONF}
echo -e "}\n" >> ${DHCPD_CONF}
fi ## End dhcp file, first run

cp ${DHCPD_CONF} ${DHCP_PATH}/${DHCPD_CONF}

DOCKER=`type -tP docker`

echo -e "\n-- Pulling Images from Docker Hub...\n"
${DOCKER} pull ${DOCKERHUB_HTTP_IMAGE}
echo
${DOCKER} pull ${DOCKERHUB_DHCP_IMAGE}

## Start apache container
echo -e "\n-- Starting ${HTTPCONTAINERNAME} container...\n"
${DOCKER} run -v ${DHCP_PATH}:${DHCP_PATH} -v ${TFTPBOOT}:${HTTPPATH}${TFTPBOOT} -d -p80:80 -p443:443 --name ${HTTPCONTAINERNAME} ${DOCKERHUB_HTTP_IMAGE}
HTTPCONTAINERID=`${DOCKER} ps | grep ${HTTPCONTAINERNAME} | awk '{print $1}'`

echo -e "\n-- Modifying ${HTTPCONTAINERNAME} container..."
## Add symbolic link for the onie default boot image
echo -e "   Add symbolic link for ONIE default boot location..."
${DOCKER} exec -t ${HTTPCONTAINERNAME} ln -s ${HTTPPATH}${TFTPBOOT}${OS_IMAGES}/${ONIE_DEFAULT_BOOT} ${HTTPPATH}/${ONIE_DEFAULT_BOOT}
echo -e "   Enabling cgi mods..."
${DOCKER} exec -t ${HTTPCONTAINERNAME} bash -c "cd /etc/apache2/mods-enabled/ && \
	ln -s ../mods-available/cgid.conf cgid.conf && \
	ln -s ../mods-available/cgi.load cgi.load && \
	ln -s ../mods-available/cgid.load cgid.load"

## Find apache cgi-bin path where scripts are executed
echo -e "   Looking for the cgi-script path..."
APACHECGIPATH=$(${DOCKER} exec -t ${HTTPCONTAINERNAME} grep Directory.*cgi-bin /etc/apache2/conf-available/serve-cgi-bin.conf|grep -oP '"\K[^"\047]+(?=["\047])')
## create symbolic link for cgi-bin folder
${DOCKER} exec -t ${HTTPCONTAINERNAME} ln -s ${APACHECGIPATH} ${HTTPPATH}/cgi-bin

## Prepare script catch_hostnames.sh and copy to container
echo -e "   Preparing script file ${CGISCRIPT}..."
sed -i '/DHCPD_CONF=/ c\DHCPD_CONF='"${DHCP_PATH}"/"${DHCPD_CONF}"'' ${CGISCRIPT}
sed -i '/TFTPBOOT=/ c\TFTPBOOT='"${HTTPPATH}${TFTPBOOT}"'' ${CGISCRIPT}
sed -i '/HOSTNAMES=/ c\HOSTNAMES='"${HOSTNAMESFILE}"'' ${CGISCRIPT}
## Set 'x' and copy script to container
chmod a+x ${CGISCRIPT}
chown root.root ${CGISCRIPT}
echo -e "   Copy script ${CGISCRIPT} to container ${HTTPCONTAINERNAME}:${APACHECGIPATH}/${CGISCRIPT}..."
${DOCKER} cp ${CGISCRIPT} ${HTTPCONTAINERNAME}:${APACHECGIPATH}/${CGISCRIPT}
echo -e "   Restart container..."
${DOCKER} restart ${HTTPCONTAINERNAME}
echo -e "   Commit changes in container and save new image..."
${DOCKER} commit -m "ztd initial install" ${HTTPCONTAINERID} ${HTTPCONTAINERNAME}:v1
echo -e "   Stopping and removing current active container and image..."
${DOCKER} stop ${HTTPCONTAINERNAME}
${DOCKER} rm ${HTTPCONTAINERNAME}
${DOCKER} image rm ${DOCKERHUB_HTTP_IMAGE}
echo -e "   Starting new container from image ${HTTPCONTAINERNAME}:v1..."
${DOCKER} run -v ${DHCP_PATH}:${DHCP_PATH} -v ${TFTPBOOT}:${HTTPPATH}${TFTPBOOT} -d --restart=always -p80:80 -p443:443 --name ${HTTPCONTAINERNAME} ${HTTPCONTAINERNAME}:v1


## Prepare Dell OS10 scripts
echo -e "\n-- Preparing Dell OS10 staging scripts: ${ZTD_SCRIPT}, ${CLI_CONFIG_FILE}, ${POST_SCRIPT_FILE}..."
echo -e "\n   Edit scripts..."
sed -i '/ZTD_SERVER_IP=/ c\ZTD_SERVER_IP="'"${IP}"'"' ${ZTD_SCRIPT}
sed -i '/CGI_HOSTNAME_SCRIPT=/ c\CGI_HOSTNAME_SCRIPT=/cgi-bin/'"${CGISCRIPT}"'' ${ZTD_SCRIPT}
sed -i '/HOSTNAMES=/ c\HOSTNAMES='"${HOSTNAMESFILE}"'' ${ZTD_SCRIPT}
sed -i '/ZTD_PATH=/ c\ZTD_PATH='"${TFTPBOOT}"'' ${ZTD_SCRIPT}
sed -i '/IMAGE_PATH=/ c\IMAGE_PATH='"${OS_IMAGES}"'' ${ZTD_SCRIPT}
sed -i '/POSTSCRIPT_PATH=/ c\POSTSCRIPT_PATH='"${POST_SCRIPT_PATH}"'' ${ZTD_SCRIPT}
sed -i '/POSTSCRIPT_FILE=/ c\POSTSCRIPT_FILE='"${POST_SCRIPT_FILE}"'' ${ZTD_SCRIPT}
sed -i '/CLI_CONF_PATH=/ c\CLI_CONF_PATH='"${CLI_CONFIG_PATH}"'' ${ZTD_SCRIPT}
sed -i '/CLI_CONF_FILE=/ c\CLI_CONF_FILE='"${CLI_CONFIG_FILE}"'' ${ZTD_SCRIPT}
sed -i '/OS_IMAGE=/ c\OS_IMAGE='"${ONIE_DEFAULT_BOOT}"'' ${ZTD_SCRIPT}
sed -i '/HOSTNAMES=/ c\HOSTNAMES='"${HOSTNAMESFILE}"'' ${POST_SCRIPT_FILE}

echo -e "   Copy to staging folder ${TFTPBOOT}..."
cp ${ZTD_SCRIPT} ${TFTPBOOT}${ZTD_PATH}/${ZTD_SCRIPT}
cp ${CLI_CONFIG_FILE} ${TFTPBOOT}${CLI_CONFIG_PATH}/${CLI_CONFIG_FILE}
cp ${POST_SCRIPT_FILE} ${TFTPBOOT}${POST_SCRIPT_PATH}/${POST_SCRIPT_FILE}
chown -R ${WWWUSER}.${WWWUSER} ${TFTPBOOT}
echo -e "\n-- Changed all files and subfolders in ${TFTPBOOT} to user/group ${WWWUSER}.${WWWUSER}..."

## Starting DHCPD container
echo -e "\n-- Starting container ${DHCPCONTAINERNAME}..."
${DOCKER} run -d  -v /var/lib/dhcp:/var/lib/dhcp -v ${DHCP_PATH}:${DHCP_PATH} --restart=always --net=host --name=${DHCPCONTAINERNAME} ${DOCKERHUB_DHCP_IMAGE}


echo -e "\n####################  All Done  ####################"
echo -e " Some actions to do:"
echo -e " - Upload a default ONIE image to '${TFTPBOOT}${OS_IMAGES}/'"
echo -e "   and name it '${ONIE_DEFAULT_BOOT}'"
echo -e "   This will be picked up by a switch if no OS is present.\n"

## su - ${USER} ## Activating group for user
