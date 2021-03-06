# -------------------------------------------------------------------------- #
# Copyright 2002-2012, OpenNebula Project Leads (OpenNebula.org)             #
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

require 'ssp_helper.rb'
require 'xmlrpc/client'
require 'rubygems'
require 'nokogiri'
require 'json'
require 'net/http'

# @mainpage  SSP Cloud Auth module for OpenNebula Sunstone
#
# @section desc Description
# This is a new authentication module for OpenNebula Sunstone. In its name SSP means 
# Simple SAML PHP (http://simplesamlphp.org/).
# SSP Cloud Auth module is useful, when a SingleSignOn is login needed, which service is realised 
# with SimpleSAMLphp. In this case, login handled by SimpleSAMLphp and so the Sunstone 
# auth module (this one) makes only the identification of the users. \n
# If new user wants to login, this module creates a new account for the user.
# 
# @section conf Configuration
# Configuration file is at the end of the main Sunstone configuration file (sunstone-server.conf).
module SSPCloudAuth

    attr_accessor :sessionid, :session
    
    @sessionid=''
    @session=''

    # original do_auth function
    # gets login datas from SimpleSAMLphp and authenticates the user
    # if new user wants to login, then creates its user
    # updates user's group
    # @param params['ssp_sessionid'] SSP session id from cookie
    # @return username if authentication success
    def do_auth(env, params={})
        auth = Rack::Auth::Basic::Request.new(env)

        # initialize some variable
        @sessionid=params['ssp_sessionid']

        if auth.provided? && auth.basic?

            # create helper
            ssp=SSP_Helper.new

            # get login datas from ssp
            @session=ssp.get_ssp_session(@sessionid)

            # test if user is authorized
            if (@session['is_auth']!=true)
                return nil
            end

            # get name from session
            @username=@session['data']['eduPersonPrincipalName'].join

            # if any privilege was sent then get it; if it was not sent and strict auth needed then deny login
            if @session['data'].has_key?('eduPersonEntitlement')
                @groupname=@session['data']['eduPersonEntitlement'].join
            else
                @groupname=''
            end

            # if new user wants to login then create it
            if ssp.get_userid(@username).empty?
                ssp.create_user(@username)
            end

            # update user's group
            ssp.update_group(@username,@groupname)

            return @username
        end

        return nil
    end
end
