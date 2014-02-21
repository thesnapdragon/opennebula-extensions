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

# Helper class to call methods in ShibCloudAuth module
class Shib_Helper

    # initalize some instance variable
    def initialize(config, logger)
        @config = config
        @logger = logger
        
        one_xmlrpc = @config[:one_xmlrpc]
        @one_auth = @config[:one_auth_for_shib]

        @server = XMLRPC::Client.new2(one_xmlrpc)
        credential = get_credential
        @session_string = credential['username'] + ':' + credential['password']
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

    # creating new user
    # @param username username of user to be created
    def create_user(username)
        call_xmlrpc('one.user.allocate', 'SAML module error! Can not create new user!', username, generate_password, '')[1]
    end

    # create groups if they do not exists
    # @param groupnames groupnames to be created
    def create_groups(groupnames)
        groupnames.map {|groupname|
            if get_groupid(groupname).empty?
                call_xmlrpc('one.group.allocate', 'SAML module error! Can not create new group!', groupname)
            end
        }
    end

    # get user's ID
    # @param username username
    # @return user's ID
    def get_userid(username)
        response = call_xmlrpc('one.userpool.info', 'SAML module error! Can not get userpool info!')
        xml = Nokogiri::XML(response[1])
        return xml.xpath('//USER[NAME=\'' + username + '\']/ID').inner_text
    end

    # get group ID of a group
    # @param groupname groupname
    # @return group's ID
    def get_groupid(groupname)
        response = call_xmlrpc('one.grouppool.info', 'SAML module error! Can not get users group id!')
        xml = Nokogiri::XML(response[1])
        return xml.xpath('//GROUP[NAME=\'' + groupname + '\']/ID').inner_text
    end

    # handle user's group
    # @param username user's name
    # @param groupnames groupnames in which the user belongs
    def handle_groups(username, groupnames)
        userid = get_userid(username).to_i
        userinfo = call_xmlrpc('one.user.info', 'SAML module error! Can not get user info!', userid)[1]

        xml = Nokogiri::XML(userinfo)
        old_groupids = Set.new xml.xpath('//GROUPS/ID').map {|x| x.inner_text.to_i}
        create_groups(groupnames)
        new_groupids = Set.new groupnames.map {|groupname| get_groupid(groupname).to_i}

        groups_to_remove = (old_groupids - new_groupids).to_a
        groups_to_add = (new_groupids - old_groupids).to_a
        @logger.debug{groups_to_add.to_a.join(",")}
        @logger.debug{groups_to_remove.to_a.join(",")}

        if !groups_to_add.empty?
            primary_groupid = groups_to_add.shift
            @logger.debug{primary_groupid.to_a.join(",")}
            call_xmlrpc('one.user.chgrp', 'SAML module error! Can not set users primary group!', userid, primary_groupid)
        end
        
        @logger.debug{groups_to_add.to_a.join(",")}
        @logger.debug{groups_to_remove.to_a.join(",")}

        groups_to_add.map {|new_groupid|
            call_xmlrpc('one.user.addgroup', 'SAML module error! Can not add user to secondary group!', userid, new_groupid)
        }

        groups_to_remove.map {|old_groupid|
            call_xmlrpc('one.user.delgroup', 'SAML module error! Can not remove user from secondary group!', userid, old_groupid)
        }
    end

    # call an xml rpc method
    # @param command xml rpc command to call
    # @param errormsg error message to log when call fails
    # xmlrpc_args vararg that contains all the xml rpc method parameters
    # @return xml rpc response
    def call_xmlrpc(command, errormsg, *xmlrpc_args)
        begin
            case xmlrpc_args.length
            when 0
                @server.call(command, @session_string)
            when 1
                @server.call(command, @session_string, xmlrpc_args[0])
            when 2
                @server.call(command, @session_string, xmlrpc_args[0], xmlrpc_args[1])
            else
                @logger.error{'SAML module error! Not supported XMLRPC call!'}
            end
        rescue Exception => e
            @logger.error{errormsg}
            [false, e.message]
        end
    end

    # get array of groupnames created from saml entitlement string
    # @param entitlement_str saml entitlement string
    # @return array of groupnames
    def get_groups(entitlement_str)
        return entitlement_str.split(';').map {|x| x.split(':').last}
    end

    # create random password for new users
    # @return random password
    def generate_password
        return rand(36 ** 20).to_s(36)
    end

end
