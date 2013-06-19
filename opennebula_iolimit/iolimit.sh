#!/bin/bash

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

## @author Unicsovics Milan, u.milan@gmail.com, MTA SZTAKI
## @file iolimit.sh
## @version 1.0

## @mainpage OpenNebula IO limit hook
## @section desc DESCRIPTION
## With this hook, specified IO limits can be set for virtual machines (VM) in OpenNebula. The IO limits can be configured in VM's template through the 'IOLIMIT' custom variable. The hooks should be executed after the VM is successfully booted. \n
## The hook uses a program, called <i>cgroup</i> to set IO limits. The IO limit settings are handled by the <i>blkio</i> subsystem of cgroup, which can be used to specify upper IO rate limits on devices.
##
## @section contents CONTENTS:
## \li \ref setup
## \li \ref doc

## @page setup Setup
## Requirement of the script is the cgroup program, which is usually in the main Linux repository, so it can be installed by the command:
## Debian / Ubuntu:
## \code
## # apt-get install cgroup-bin
## \endcode
## Red Hat Enterprise / Fedora Linux / Suse Linux / Cent OS:
## \code
## # yum install libcgroup.i686
## \endcode
## or
## \code
## # yum install libcgroup.x86_64
## \endcode
## 
## Cgroup can set IO limits only on block devices. Recommended to use LVM, for instance: \n
## shared lvm patch:
## http://dev.opennebula.org/issues/1341
##
## <b>Hook configuration</b> \n
## COMMON: Path to scripts_common.sh, used for log functions \n
## DEVICEDIR: Path to the mounted VM devices \n
## CGROUP: Path to cgroup directory
##
## For right behavior 'IOLIMIT' custom variable must be present in VM's template. 'IOLIMIT' variable specifies upper limit on write- and read rate to the device. IO rate is specified in bytes per second.\n
## Options for adding custom variables:
## \li In Sunstone by VM Template Wizard in section 'Add custom variables'
## \li Manually by editing a template
##
## Example for template with 1024 byte/sec IO limit: \n
## \code
## CPU="1"
## DISK=[
##     IMAGE="ttylinux - kvm",
##     IMAGE_UNAME="oneadmin" ]
## FEATURES=[
##     PAE="no" ]
## IOLIMIT="1024"
## MEMORY="512"
## NAME="example"
## OS=[
##     ARCH="x86_64",
##     BOOT="hd" ]
## RAW=[
##     TYPE="kvm" ]
## TEMPLATE_ID="1"\n
## \endcode
##
## After setting 'IOLIMIT' variables in, a VM hook must be defined in $ONE_LOCATION/etc/oned.conf:
## \code
## VM_HOOK = [
##      name      = "iolimit",
##      on        = "RUNNING",
##      command   = "/var/tmp/one/hooks/iolimit.sh",
##      arguments = "$TEMPLATE",
##      remote    = "YES" ]
## \endcode
##
## @page doc Developer documentation
## @section def GLOBAL DEFINITIONS
## COMMON: OpenNebula's helper scripts, used for log functions \n
## @details Example: \n
## \code
## COMMON='/var/tmp/one/scripts_common.sh'
## \endcode
## DEVICEDIR: directory where the devices were mounted \n
## @details Example: \n
## \code
## DEVICEDIR='/dev/shared_lvm'
## \endcode
## CGROUP: path to cgroup directory \n
## @details Example: \n
## \code
## CGROUP='/cgroup'
## \endcode
##
## @section func FUNCTIONS
## @details <b>function init():</b> check if $DEVICEDIR is readable \n
## @details <b>function read_dom():</b> read DOM element value \n
## @details <b>function get_element():</b> get DOM element value from DOM elements
## @param[in] entity DOM element
## @return DOM element value 
## @details <b>function decodebase64():</b> decode base64 encoded text
## @param[in] text base64 encoded text
## @details <b>function get_numbers():</b> get major and minor id of the device, and save cgroup rules in a tempfile
## @param[in] id virtual machine's ID
## @param[in] iolimit IO limit value from virtual machine's template
## @details <b>function cgroup_setup():</b> mount cgroup's block IO controller, and set it up
## @details <b>function main():</b> main function
## @param[in] encoded_template base64 encoded template xml

# Configuration
COMMON=/var/tmp/one/scripts_common.sh
DEVICEDIR='/dev/shared_lvm/'
CGROUP='/cgroup'

. $COMMON

function init(){
    if ! [ -r $DEVICEDIR ]; then
        log_error "ERROR! $DEVICEDIR is not readable"
    fi
}

function read_dom(){
    local IFS=\>
    read -d \< ENTITY CONTENT
}

function get_element(){
    while read_dom; do
        if [[ $ENTITY = $1 ]] ; then
            echo $CONTENT
        fi
    done < $plain
}

function decodebase64(){
    # decode base64 template xml
    plain=`mktemp -q`
    echo $1 | base64 -d > $plain
    
    # delete CDATA-s 
    sed -ni 's/<!\[CDATA\[//g p' $plain
    sed -ni 's/\]\]>//g p' $plain
}

function get_numbers(){
    # get links
    devlinks=`mktemp -q`
    ls -la $DEVICEDIR | grep -E "lv-one.*\-$1\ " | sed -n 's/.* -> ..\/\(.*\)/\1/g p' > $devlinks

    devnames=`mktemp -q`
    while read line; do
        ls -la /dev/$line >> $devnames
    done < $devlinks

    # cleanup
    rm $devlinks
    
    # get numbers
    numbers=`mktemp -q`
    while read line; do
        major=`echo $line | sed -n 's/,//p' | cut -d ' ' -f 5`
        minor=`echo $line | sed -n 's/,//p' | cut -d ' ' -f 6`
        echo $major':'$minor $2 >> $numbers
    done < $devnames

    # cleanup
    rm $devnames
}

function cgroup_setup(){
    # check if cgroup-bin installed
    if ! [ -e $CGROUP/blkio/ ]; then
        log_error 'ERROR! cgroup has not been installed' 
    else
        sudo mkdir -p $CGROUP/blkio
        
        # mount blkio if it's not mounted
        if ! mountpoint -q $CGROUP/blkio/; then
            sudo mount -t cgroup -o blkio none $CGROUP/blkio
        fi

        # add rules from created file
        while read line; do
            echo $line | sudo tee -a $CGROUP/blkio/blkio.throttle.read_bps_device
            echo $line | sudo tee -a $CGROUP/blkio/blkio.throttle.write_bps_device
        done < $numbers
    fi
}

function main(){
    # decode base64 template
    decodebase64 $1

    # get vm's id
    id=`get_element "ID"`
    
    # get vm's iolimit
    iolimit=`get_element "IOLIMIT"`

    if ! [ -z $iolimit ]; then
        # create cgroup rule for device: <major>:<minor>  <bytes_per_second>
        get_numbers $id $iolimit

        # cgroup setup
        cgroup_setup

        # cleanup
        rm $numbers
    fi 
        # cleanup
        rm $plain
}

# main function
main "$@"
