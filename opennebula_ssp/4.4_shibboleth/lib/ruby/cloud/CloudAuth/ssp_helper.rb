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

# Helper class to call methods in SSPCloudAuth module
class SSP_Helper

    attr_accessor :one_xmlrpc, :one_auth, :one_location, :config

    # initalize some instance variable
    def initialize
        @one_location=''
        
        # get ssp configuration
        if @one_location.empty?
            etc_location="/etc/one"
        else
            etc_location=@one_location+"/etc"
        end

        configuration_file=etc_location+"/sunstone-server.conf"

        begin
            @config = YAML.load_file(configuration_file)
        rescue Exception => e
            STDERR.puts "Error parsing config file #{configuration_file}: #{e.message}"
            exit 1
        end

        @one_xmlrpc=@config[:one_xmlrpc]
        @one_auth=@config[:one_auth_for_ssp]
    end 

    # creating new user
    # @param username username of user to be created
    def create_user(username)
        server=XMLRPC::Client.new2(@one_xmlrpc)
        
        session_string=self.get_credential["username"]+":"+self.get_credential["password"]
        
        begin
            response=server.call("one.user.allocate",session_string,username,self.generate_password,'')
        rescue Exception => e
            [false, e.message]
        end
    end

    # update user's group or create it's group
    # @param username username's group will be updated
    # @param groupname user's group
    def update_group(username,groupname)
        server=XMLRPC::Client.new2(@one_xmlrpc)
        
        session_string=self.get_credential["username"]+":"+self.get_credential["password"]

        if groupname.empty?
            groupname='users'
        end

        if self.get_groupid(groupname).empty?
            self.create_group(groupname)
        end

        begin
            response=server.call("one.user.chgrp",session_string,self.get_userid(username).to_i,self.get_groupid(groupname).to_i)
        rescue Exception => e
            [false, e.message]
        end
    end

    # get username and password from $ONE_AUTH file
    # @return username and password in a Hash
    def get_credential
        credential=Hash.new
        
        if File.readable?(@one_auth)
            File.open(@one_auth, 'r') do |line| 
                auth_line=line.gets.strip
                auth_line=auth_line.split(':')

                credential["username"]=auth_line[0]
                credential["password"]=auth_line[1]
            end
        else
            # TODO: write error into log (SSP_Helper ERROR: $ONE_AUTH file is not readable)
            raise "one auth file not readable"
        end
        return credential
    end

    # get user's ID
    # @param username username
    # @return user's ID
    def get_userid(username)
        server=XMLRPC::Client.new2(@one_xmlrpc)
        
        session_string=self.get_credential["username"]+":"+self.get_credential["password"]
        
        begin
            response=server.call("one.userpool.info",session_string)
        rescue Exception => e
            [false, e.message]
        end

        xml=Nokogiri::XML(response[1])
        return xml.xpath('//USER[NAME=\''+username+'\']/ID').inner_text
    end

    # get group ID of a group
    # @param groupname groupname
    # @return group's ID
    def get_groupid(groupname)
        server=XMLRPC::Client.new2(@one_xmlrpc)
        
        session_string=self.get_credential["username"]+":"+self.get_credential["password"]
        
        begin
            response=server.call("one.grouppool.info",session_string)
        rescue Exception => e
            [false, e.message]
        end

        xml=Nokogiri::XML(response[1])
        return xml.xpath('//GROUP[NAME=\''+groupname+'\']/ID').inner_text
    end

    # creating new group
    # @param groupname groupname of group to be created
    def create_group(groupname)
        server=XMLRPC::Client.new2(@one_xmlrpc)
        
        session_string=self.get_credential["username"]+":"+self.get_credential["password"]
        
        begin
            response=server.call("one.group.allocate",session_string,groupname)
        rescue Exception => e
            [false, e.message]
        end
    end

    # create random password for new users
    # @return random password
    def generate_password
        return rand(36**20).to_s(36)
    end
    
    def get_groups(entitlement_str)
		return entitlement_str.split(';').map {|x| x.split(':').last}
    end

end
