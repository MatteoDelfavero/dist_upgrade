#!/bin/bash

sudo chown administrator:administrator /home/administrator/.bash_history # bugfix

file="/home/ansible/releaseupgrade"
runtype="APT UPDATE"
runtype2="APT UPGRADE"
runtype3="APT DISTUPGRADE"

chech_nala(){
    return command -v "nala" &> /dev/null
}

nala_install(){
    echo "deb http://deb.volian.org/volian/ scar main" | sudo tee /etc/apt/sources.list.d/volian-archive-scar-unstable.list
    wget -qO - https://deb.volian.org/volian/scar.key | sudo tee /etc/apt/trusted.gpg.d/volian-archive-scar-unstable.gpg
    if [ "$1" -eq 1 ];
    then
        sudo apt update 
        sudo apt -y install nala
    fi
}

if ! check_nala;
then
    nala_install 1
fi


# kilojjuk a systemd-s processzeket amik foghatjak az apt-ot
kill_systemd_p(){
    ps aux | grep apt.systemd | grep -v gre0p | awk '{print $2}' | while read line; do kill -9 $line; done # kilojjuk a systemd-s processzeket amik foghatjak az apt-ot
    sudo rm -f /var/lib/dpkg/lock* # es az ahhoz tartozo lockfajlt is
}

# ha tobb mint fel napig nem sikerult frissiteni, ujrakezdjuk az egeszet  
watchdog_timelimit(){
    if [ -f $file ] && [ $(find $file -mmin -720 | wc -l) -eq 0 ];
    then
        rm -f $file;
    fi
}


kill_systemd_p
watchdog_timelimit