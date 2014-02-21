# -------------------------------------------------------------------------- #
# Copyright 2002-2013, OpenNebula Project (OpenNebula.org), C12G Labs        #
#                                                                            #
# Licensed under the Apache License, Version 2.0 (the "License"); you may    #
# not use this file except in compliance with the License. You may obtain    #
# a copy of the License at                                                   #
#                                                                            #
# http://www.apache.org/licenses/LICENSE-2.0                                 #
#                                                                            #
# Unless required by applicable law or agreed to in writing, software        #
# distributed under the License is distributed on an "AS IS" BASIS,          #
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.   #
# See the License for the specific language governing permissions and        #
# limitations under the License.                                             #
#--------------------------------------------------------------------------- #

DIR=File.dirname(__FILE__)
$: << DIR

require 'shib_helper.rb'
require 'xmlrpc/client'
require 'rubygems'
require 'nokogiri'
require 'json'
require 'net/http'
require 'set'

# @mainpage  Shibboleth Cloud Auth module for OpenNebula Sunstone
#
# @section desc Description
# This is a new authentication module for OpenNebula Sunstone.
# Shib Cloud Auth module is useful, when a SingleSignOn login is needed, where the Service Provider realised with a Shibboleth SP.
# In this case, login handled by Shibboleth and so the Sunstone 
# auth module (this one) controls the authorization of the users. \n
# If a new user wants to login, this module creates a new account for the user. The user's primary group and his secondary groups also created from the entitlements that come to Shibboleth in a SAML message.
# 
# @section conf Configuration
# Configuration file is at the end of the main Sunstone configuration file (sunstone-server.conf).
module ShibCloudAuth
    def do_auth(env, params={})
        auth = Rack::Auth::Basic::Request.new(env)

        if auth.provided? && auth.basic?

            # create helper
            shib = Shib_Helper.new(@conf, @logger)

            # get username from session
            username = params['shib_username']

            # if new user wants to login then create it
            userid = shib.get_userid(username)
            if userid.empty?
                userid = shib.create_user(username)
            end

            if !params['shib_entitlement'].empty?
                # get groupnames from entitlement
				groupnames = shib.get_groups(params['shib_entitlement'])
                # add user to given groups remove him from the old groups
                shib.handle_groups(username, groupnames)
            else
                # if new user does not have any entitlement then refuse to login
                return nil
            end            

            return username
        end

        return nil
    end
end
