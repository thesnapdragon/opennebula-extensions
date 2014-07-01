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

module ShibCloudAuth
    def do_auth(env, params={})
        auth = Rack::Auth::Basic::Request.new(env)

        if auth.provided? && auth.basic?
            # if username or entitlement is not provided then refuse the login
            if params['shib_username'].empty? || params['shib_entitlement'].empty?
                @logger.error{'SAML module error! Header variables are missing!'}
                return nil
            end

            # create helper
            shib = Shib_Helper.new(@conf, @logger)

            # get username from session
            username = params['shib_username']

            # if new user wants to login then create it
            userid = shib.get_userid(username).to_i
            if userid == 0
                userid = shib.create_user(username).to_i
            end

            # get groupnames from entitlement
            groupnames = shib.get_groups(params['shib_entitlement'])
            # add user to given groups remove him from the old groups
            shib.handle_groups(userid, groupnames)

            return username
        end

        return nil
    end
end
