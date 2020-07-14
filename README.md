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
- install some required packages to have docker enabled
- create user.group for ztd folder, default www-data
- setup the ztd folder structure for images, scripts, config leds.  
  The default is /tftpboot/...
- create dhcpd.conf file with mandatory default settings  
  In there you can add your Switches with desired hostname,  
  mac-address and fixed ip address. Scroll down to practically EoF.  
  Restart container ztd-dhcpd after changes.  
  [ docker restart ztd-dhcpd ]
- create some other scripts which are used by the zero touch deployment process.  
- create containers for dhcp service and httpd service.  
  ztd-dhcpd and ztd-httpd  

 
# short install steps
1. Have your base ubuntu server ready
2. git clone https://github.com/plukkie/ztdserver.git
3. cd ztdserver
4. sudo ./install.sh

