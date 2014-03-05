#!/bin/bash
# install scripts for Shibboleth OpenNebula Connector
# Milán Unicsovics, milan.unicsovics at sztaki dot mta dot hu
# usage: ./install.sh

sudo cp -r etc/* /etc/one/
sudo cp -r lib/ruby/* /usr/lib/one/ruby/
sudo cp -r lib/sunstone/* /usr/lib/one/sunstone/
