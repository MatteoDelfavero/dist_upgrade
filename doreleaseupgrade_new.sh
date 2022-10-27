#!/bin/bash

sudo chown administrator:administrator /home/administrator/.bash_history # bugfix

file="/home/ansible/releaseupgrade"
runtype="APT UPDATE"
runtype2="APT UPGRADE"
runtype3="APT DISTUPGRADE"


# kilojjuk a systemd-s processzeket amik foghatjak az apt-ot
kill_systemd_p(){
    # kilojjuk a systemd-s processzeket amik foghatjak az apt-ot
    ps aux | grep apt.systemd | grep -v gre0p | awk '{print $2}' | while read line; do kill -9 $line; done
    # es az ahhoz tartozo lockfajlt is
    sudo rm -f /var/lib/dpkg/lock* 
}

# ha tobb mint fel napig nem sikerult frissiteni, ujrakezdjuk az egeszet  
watchdog_timelimit(){
    if [ -f $file ] && [ $(find $file -mmin -720 | wc -l) -eq 0 ];
    then
        rm -f $file;
    fi
}


main(){
    if [ -f $file ]; then
        # Ha minden lefutott, akkor nem megyunk tovabb
        if [ $(grep -E "\[FATAL\]|\[SUCCESS\]" $file | wc -l) -ne 0 ];
        then 
            echo -e "[INFO] A szkript vegigfutott:\n$(cat $file)"
            exit 0
        else
            if [ $(grep "$runtype OK" $file | wc -l) -ne 0 ] && [ $(grep "$runtype2 OK" $file | wc -l) -ne 0 ] && [ $(grep "$runtype3 OK" $file | wc -l) -ne 0 ];
            then
                old=$(head -1 $file)
                new=$(cat /etc/os-release  | grep -i PRETT | cut -d '"' -f 2 | cut -d "." -f 1)
                echo "[INFO] Kiindulasi verzio: $old | Uj verzio: $new"
                if [[ "$old" = "$new" ]];
                then
                    echo "[FATAL] A frissites sikertelen volt."
                    mv $file $file.$(date +%s)
                    sudo reboot
                else
                    echo "[SUCCESS] A frissites sikeres volt."
                fi
                sudo su user -c ' DISPLAY=:0 notify-send -t 0 "VERZIOVALTAS KESZ, EREDMENYEK AZ MGMTFELULETEN" --icon=dialog-information'
                exit 0
            fi
        fi
    fi

    # ha fut folyamat, akkor nem megyunk tovabb
    if [ -f $file ] && [ $(grep "IN PROGRESS" $file | wc -l) -ne 0 ];
    then 
        echo -e "[INFO] Folyamat fut:\n$(cat $file)"
        exit 0
    fi

    # alapesetben fel oraig varna rebootkor az unattended-upgrades servicere, ezt levesszuk 15mp-re
    sudo find /etc/ -type f -name "*unattended-upgrades*" | while read line; do if [ $(grep -i timeout $line | wc -l) -ne 0 ]; then echo $line; sed "s/1800/15/g" -i $line; fi ; done 


    if [ ! -f $file ] || [ $(grep "$runtype OK" $file | wc -l) -eq 0 ];
    then
        cat /etc/os-release  | grep -i PRETT | cut -d '"' -f 2 | cut -d "." -f 1 > $file
        echo "$(date +%Y-%m-%d' '%T) $runtype IN PROGRESS" | sudo tee -a $file
        sudo su user -c ' DISPLAY=:0 notify-send -t 0 "UPDATE IN PROGRESS" --icon=dialog-information'
        
        yes | sudo dpkg --configure -a > /dev/null
        sudo rm -f /var/lib/apt/lists/* > /dev/null
        sudo apt-get update -y

        exitcode=$?; sed '/IN PROGRESS/d' -i $file
        if [ $exitcode -ne 0 ] && [ $exitcode -ne 100 ];
        then
                echo "[INFO] Nem sikerult lekerni a frissitesek listajat. Visszateresi ertek: $exitcode"
                sudo su user -c ' DISPLAY=:0 notify-send -t 0 "UPDATE FAILED" --icon=dialog-information'
                exit 1
        else
                echo "[INFO] Sikerult lekerni a frissitesek listajat. Visszateresi ertek: $exitcode"
                sudo su user -c ' DISPLAY=:0 notify-send -t 0 "UPDATE OK" --icon=dialog-information'
                echo "$(date +%Y-%m-%d' '%T) $runtype OK" | sudo tee -a $file
        fi
    fi

    echo ""

    if [ -f $file ] && [ $(grep "$runtype OK" $file | wc -l) -ne 0 ] && [ $(grep "$runtype2 OK" $file | wc -l) -eq 0 ];
    then
        echo "$(date +%Y-%m-%d' '%T) $runtype2 IN PROGRESS" | sudo tee -a $file
        sudo su user -c ' DISPLAY=:0 notify-send -t 0 "UPGRADE IN PROGRESS" --icon=dialog-information'
        
        yes | sudo dpkg --configure -a > /dev/null

        if [ $(sudo cat /etc/os-release | grep VERSION_ID | grep 18 | wc -l) -ne 0 ];
        then
            echo "[INFO] apt-bol telepitett Chromium eltavolitasa"
            yes | sudo apt remove chromium-browser-l10n -y # via Zsolt
            sudo snap set system proxy.http="http://dc-proxy01.server.bardihu.lan:3128" # via Zsolt
            sudo snap set system proxy.http="https://dc-proxy01.server.bardihu.lan:3128" # via Zsolt
            sudo sh -c "echo ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true | debconf-set-selections" # via Zsolt
            sudo DEBIAN_FRONTEND=noninteractive apt-get -yq install keyboard-configuration # via Zsolt
            # sudo apt-get install -y -q # via Zsolt TODO
            sudo apt-get update -y
            sudo apt-get install msttcorefonts -qq # via Zsolt
            sudo snap install chromium # via Zsolt
        fi
    
        #sleep 60 
        #sudo timeout 7200 apt upgrade -o Acquire::http::Dl-Limit=512 -y --allow-unauthenticated </dev/null # ketto oraig futhat max
        # ketto oraig futhat max
        yes | sudo timeout 7200 apt upgrade -fy --allow-unauthenticated --with-new-pkgs </dev/null

        exitcode=$?; sed '/IN PROGRESS/d' -i $file
        if [[ $exitcode -eq 0 ]] || [[ $exitcode -eq 124 ]];
        then
            echo "[INFO] Sikeresen lefutott az apt upgrade. Visszateresi ertek: $exitcode"
            sudo su user -c ' DISPLAY=:0 notify-send -t 0 "UPGRADE OK" --icon=dialog-information'
            echo "$(date +%Y-%m-%d' '%T) $runtype2 OK" | sudo tee -a $file
            if [ -f /var/run/reboot-required ];
            then 
                echo "[INFO] Ujrainditas szukseges"
                sudo su user -c ' DISPLAY=:0 notify-send -t 0 "KLIENS UJRAINDITASA EGY PERCEN BELUL" --icon=dialog-information'
                sleep 5; sudo reboot
            fi
        else
            echo "[INFO] Nem sikerult lefuttatni az apt upgrade-t. Visszateresi ertek: $exitcode"
            sudo su user -c ' DISPLAY=:0 notify-send -t 0 "UPGRADE FAILED" --icon=dialog-information'
            echo "[INFO] apt fix missing futtatasa"
            sudo apt-get update --fix-missing >/dev/null
            sudo su user -c ' DISPLAY=:0 notify-send -t 0 "KLIENS UJRAINDITASA EGY PERCEN BELUL" --icon=dialog-information'
            sleep 5; sudo reboot
            exit 1
        fi
    fi

    echo ""

    if [ -f $file ] && [ $(grep "$runtype OK" $file | wc -l) -ne 0 ] && [ $(grep "$runtype2 OK" $file | wc -l) -ne 0 ] && [ $(grep "$runtype3 OK" $file | wc -l) -eq 0 ]; then
        echo "$(date +%Y-%m-%d' '%T) $runtype3 IN PROGRESS" | sudo tee -a $file
        sudo su user -c ' DISPLAY=:0 notify-send -t 0 "DISTUPGRADE IN PROGRESS" --icon=dialog-information'

        echo 'DPkg::options { "--force-confdef"; "--force-confnew"; }' | sudo tee /etc/apt/apt.conf.d/local
        sudo snap set system proxy.http="http://dc-proxy01.server.bardihu.lan:3128"
        sudo snap set system proxy.http="https://dc-proxy01.server.bardihu.lan:3128"

        sudo rm -f /var/lib/apt/lists/* > /dev/null
        yes | sudo dpkg --configure -a > /dev/null
        yes | sudo apt-get update --fix-missing >/dev/null # via Zsolt

        # yes | sudo apt install -f -y > /dev/null
        # yes | DEBIAN_FRONTEND=noninteractive sudo timeout 7200 apt -o Dpkg::Options::="--force-confnew" --force-yes -fuy dist-upgrade  --allow-unauthenticated  < /dev/null
        # yes | DEBIAN_FRONTEND=noninteractive sudo timeout 7200 apt -o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold' --force-yes -fuy dist-upgrade#  --allow-unauthenticated  < /dev/null
        yes | sudo apt dist-upgrade -y # via Zsolt
        yes | sudo timeout 7200 do-release-upgrade -f DistUpgradeViewNonInteractive </dev/null # ketto oraig futhat max
        exitcode=$?; sed '/IN PROGRESS/d' -i $file
    
        yes | sudo apt update -y # via Zsolt
        yes | sudo apt upgrade -y # via Zsolt
        yes | sudo apt autoremove -y # via Zsolt
        yes | sudo apt clean # via Zsolt

        sudo rm -f /etc/apt/apt.conf.d/local
        # grub reinstall
        grep -v rootfs /proc/mounts | grep "^/dev/" | awk '{print $1}' | tr -d '0123456789' > /tmp/grubmbrbd.tmp
        df -h /boot | grep "^/dev/" | awk '{print $1}' | tr -d '0123456789' >> /tmp/grubmbrbd.tmp
        sudo fdisk -l | grep "^Disk" | grep dev | awk '{print $2}' | cut -d ":" -f 1 >> /tmp/grubmbrbd.tmp
        cat /boot/grub/grub.cfg  | grep UUID | awk '{print $3}' | cut -d "=" -f 3 | sort | uniq | while read uuid; do blkid | grep "$uuid" | cut -d ":" -f 1 | tr -d '0123456789'; done >> /tmp/grubmbrbd.tmp

        cat /tmp/grubmbrbd.tmp | sort | uniq | while read bd; do sudo grub-install $bd; done

        echo "$(date +%Y-%m-%d' '%T) $runtype3 OK" | sudo tee -a $file
        sudo su user -c ' DISPLAY=:0 notify-send -t 0 "DISTUPGRADE OK" --icon=dialog-information'
        sudo su user -c ' DISPLAY=:0 notify-send -t 0 "KLIENS UJRAINDITASA EGY PERCEN BELUL" --icon=dialog-information'

        if [ $(find /etc/systemd/system/multi-user.target.wants/x11vnc.service -type l | wc -l) -eq 0 ]; then # Ubi 18 alatt mar nem indul el systemd alatt, ha nem symlink
            sudo mv /etc/systemd/system/multi-user.target.wants/x11vnc.service /lib/systemd/system
            sudo ln -s /lib/systemd/system/x11vnc.service /etc/systemd/system/multi-user.target.wants/
        fi
        sudo passwd -d user
        sleep 5; sudo reboot
    fi	

    exit 0
}

kill_systemd_p
watchdog_timelimit
main