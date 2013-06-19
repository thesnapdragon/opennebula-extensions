#!/bin/bash
# install scripts for SimpleSAMLphp OpenNebula Connector
# Milán Unicsovics, u.milan at gmail dot com
# usage: ./install.sh

sudo cp -r etc/* /etc/one/
sudo cp -r lib/ruby/* /usr/lib/one/ruby/
sudo cp -r lib/sunstone/* /usr/share/opennebula/sunstone/
