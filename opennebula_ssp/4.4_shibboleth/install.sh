#!/bin/bash
# install scripts for Shibboleth OpenNebula Connector
# Milán Unicsovics, milan.unicsovics at sztaki dot mta dot hu
# usage: ./install.sh

# install files
sudo cp -r lib/ruby/* /usr/lib/one/ruby/
sudo cp -r lib/sunstone/* /usr/lib/one/sunstone/
# create config
sudo sed -i 's/:auth: .*/:auth: shib/' /etc/one/sunstone-server.conf
printf "################################################################################
## Shibboleth Auth module
#################################################################################
#
## shib_host:             		Shibboleth host url
## shib_logoutpage:       		Shibboleth logout page
## one_auth_for_shib:	  		$ONE_AUTH file location
## shib_username:		  		SAML attribute to use as a username
## shib_entitlement:      		SAML attribute to use as entitlement string
## shib_entitlement_priority	entitlement priority list
:shib_host: http://sp1.hexaa.eu
:shib_logoutpage: /Shibboleth.sso/Logout
:one_auth_for_shib: /var/lib/one/.one/one_auth
:shib_username: HTTP_EPPN
:shib_entitlement: HTTP_ENTITLEMENT
:shib_entitlement_priority:
    - admin
    - alpha
    - bravo" | sudo tee -a /etc/one/sunstone-server.conf
