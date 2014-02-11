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

# Helper class to call methods in SSPCloudAuth module
class SSP_Helper

    # initalize some instance variable
    def initialize(config, logger)
        @config = config
        @logger = logger
        
        one_xmlrpc = @config[:one_xmlrpc]
        @one_auth = @config[:one_auth_for_ssp]

        @server = XMLRPC::Client.new2(one_xmlrpc)
        credential = get_credential
        @session_string = credential['username'] + ':' + credential['password']
    end 

    # creating new user
    # @param username username of user to be created
    # @return userid of the created user
    def create_user(username)
        begin
            response = @server.call('one.user.allocate', @session_string, username, generate_password, '')
            return response[1]
        rescue Exception => e
            @logger.error{'SAML module error! Can not create new user!'}
            [false, e.message]
        end
    end

    # update user's group or create it's group
    # @param username username's group will be updated
    # @param groupname user's group
    def update_group(username,groupname)
        if groupname.empty?
            groupname = 'users'
        end

        if get_groupid(groupname).empty?
            create_group(groupname)
        end

        begin
            response = @server.call('one.user.chgrp', @session_string, get_userid(username).to_i, get_groupid(groupname).to_i)
        rescue Exception => e
            @logger.error{'SAML module error! Can not change users group!'}
            [false, e.message]
        end
    end

    # get username and password from $ONE_AUTH file
    # @return username and password in a Hash
    def get_credential
        credential = Hash.new
        
        if File.readable?(@one_auth)
            File.open(@one_auth, 'r') do |line| 
                auth_line = line.gets.strip.split(':')

                credential['username'] = auth_line[0]
                credential['password'] = auth_line[1]
            end
        else
            @logger.error{'SAML module error! $ONE_AUTH file is not readable!'}
        end
        return credential
    end

    # get user's ID
    # @param username username
    # @return user's ID
    def get_userid(username)
        begin
            response = @server.call('one.userpool.info', @session_string)
        rescue Exception => e
            @logger.error{'SAML module error! Can not get users id!'}
            [false, e.message]
        end

        xml = Nokogiri::XML(response[1])
        return xml.xpath('//USER[NAME=\'' + username + '\']/ID').inner_text
    end

    # get group ID of a group
    # @param groupname groupname
    # @return group's ID
    def get_groupid(groupname)
        begin
            response = @server.call('one.grouppool.info', @session_string)
        rescue Exception => e
            @logger.error{'SAML module error! Can not get users group id!'}
            [false, e.message]
        end

        xml = Nokogiri::XML(response[1])
        return xml.xpath('//GROUP[NAME=\'' + groupname + '\']/ID').inner_text
    end

    # creating new group
    # @param groupname groupname of group to be created
    def create_group(groupname)
        begin
            response = @server.call('one.group.allocate', @session_string, groupname)
        rescue Exception => e
            @logger.error{'SAML module error! Can not create new group!'}
            [false, e.message]
        end
    end

    # create random password for new users
    # @return random password
    def generate_password
        return rand(36 ** 20).to_s(36)
    end
    
    def get_groups(entitlement_str)
		return entitlement_str.split(';').map {|x| x.split(':').last}
    end

end