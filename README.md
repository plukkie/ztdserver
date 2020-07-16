# ztdserver
This repo will setup a zero touch deployment server for ONIE based network switches.  
Native support is available for Dells OS10 switches, but multivendor ZTD is supported.  
You just have to add the customized scripts for your vendor.  

The default settings in the install.sh script will be fine for most people.  
If you want to customize upfront, you can modify some variables.  
One of worth noting is if a dynamic pool of addresses should be activated.  
The default is NOT. If you want a dynamic dhcp pool, change below variable:  

* set DHCPPOOL=1  
  This activates a pool of addresses for the subnet detected where the server runs  
  Default range will be for last octet: .151 - .170  
  This can be changed with variables DHCPSTART=151 and DHCPSTOP=170  

What the script will do?
- install some required packages to have docker and docker-composer enabled
- create user.group for ztd folder, default www-data
- setup the ztd folder structure for images, scripts, config leds.  
  The default is /tftpboot/...
- create dhcpd.conf file with mandatory default settings  
  In there you can add your Switches with desired hostname,  
  mac-address and fixed ip address. Scroll down to practically the EoF,  
  where you find the line which which mentions "DON'T EDIT THIS LINE".  
  Below there you see examples of a Spine and a Leaf switch.
  Please adapt to your setup.  
  Restart container ztd-dhcpd after changes.  
  [ docker-composer restart ztd-dhcpd ]
- create some other scripts which are used by the zero touch deployment process. 
  1. /tftpboot/cli_config/cli_config 
     Contains OS10 cli config statements
  2. /tftpboot/post_script/post_script.sh
     Contains bash script and is used to automate some tasks
  3. /tftpboot/ztd/ztd.sh
     Main bash scripts which is executed as first and retreives the other files
- create containers for dhcp service and httpd service (ztd-dhcpd and ztd-httpd)  
  Please use 'docker-compose down' to manually shut containers.  
  Please use 'docker-compose up -d' to manually start containers.

# requirements
1. Ubuntu host or VM (tested on 20.04)
   Allthough the ZTD daemons are deployed as containers and thus would be portable
   and deployable on multiple Linux distro's, the install.sh script uses some command
   outputs and tools like packet manager and naming standards that only work on Ubuntu.
2. git to get the ztdserver repo : install git with "apt -y install git"
3. run installer as "sudo ./install.sh" or just login as root and run "./install.sh"
 
# short install steps
1. Have your base ubuntu server ready
2. cd to your folder of choice (prefer your home)
3. git clone https://github.com/plukkie/ztdserver.git
4. cd ztdserver
5. sudo ./install.sh
6. check service up with: docker-compose ps

# problems
- if your ubuntu vm has more then one active interface, it could be that the ip-address  
  can not be determined automatically for the www server. Please then add the ip-address  
  manually after installation. Edit script /tftpboot/ztd/ztd.sh and set the variable
  ZTD_SERVER_IP=<ip address of server interface>
  Also, the subnet could be misconfigured in the /etc/dhcp/dhcpd.conf.
  Edit the dhcp file and restart container: docker-compose restart ztd-dhcpd
- Be sure you do not have already a webserver or dhcp server running on your host
  This will obviously interfear with the default ports of tcp:80, tcp:443 and udp:67. 
  It will break a succesfull installation

# reinstall  
You can execute the sudo ./install.sh safely again if you  
need to reinstall. Your content is preserved and/or copied to .bak  

Enjoy the ZTD environment.  

Greetings,

Plukkie
plukkie@gmail.com

