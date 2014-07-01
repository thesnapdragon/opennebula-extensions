# Shibboleth Cloud Auth module for OpenNebula Sunstone

## Description

This is a new authentication module for OpenNebula Sunstone.
Shib Cloud Auth module is useful, when a SingleSignOn login is needed, where the Service Provider realised with a Shibboleth SP.
In this case, login handled by Shibboleth and so the Sunstone 
auth module (this one) controls the authorization of the users.
If a new user wants to login, this module creates a new account for the user. The user's primary group and his secondary groups also created from the entitlements that come to Shibboleth in a SAML message.

## Install

* Run `install.sh`.

## Configuration

Configuration file is at the end of the main Sunstone configuration file (*sunstone-server.conf*).
Some configuration option is self-describing (like :shib_host, :shib_logoutpage, :one_auth_for_shib). The rest of the options modify the behaviour of this authentication module.
First an Apache HTTP VirtualHost location have to be created, a possible example can be see here:

~~~
<Location /one>
   shibboleth shield 
   AllowOverride all 
   Order allow,deny 
   Allow from all 
   AuthType shibboleth
   require valid-user
   ShibUseHeaders On
   ShibRequireSession On
</Location>
~~~

When OpenNebula authorizes a user this module uses some Apache HTTP header variable, where the SAML message datas are stored. After a successful authentication from the Apache HTTP header variables this module can read the actual user's datas.

### Example:

~~~
:shib_username: HTTP_EPPN
:shib_entitlement: HTTP_ENTITLEMENT
:shib_entitlement_priority:
   - admin
   - alpha
   - bravo
~~~

In the example above the names of the users are stored in the *HTTP_EPPN* header variable, and the entitlements / privileges are stored in the *HTTP_ENTITLEMENT* header variable. The primary group of the user is calculated from the *shib_entitlement_priority* list, where the first existing groupname will be his primary group, the others will be the secondary groups of the user.