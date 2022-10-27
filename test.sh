#!/bin/bash

for pkg in `dpkg --get-selections | awk '{print $1}' | egrep -v '(dpkg|apt|mysql|mythtv)'` ; do sudo apt-get -y --force-yes install --reinstall $pkg ; done




# sudo apt --fix-missing update
# sudo apt clean
# sudo apt autoremove
# sudo apt update
# sudo apt full-upgrade -y
