#!/bin/bash
# force reboot
sudo chown administrator:administrator /home/administrator/.bash_history # bugfix

############### Globalis valtozok ###################
file="/home/ansible/releaseupgrade"
BA_ONLINE_LOGO="opsrepo.bardiauto.hu/installers/bardi_auto_logo-v1.png"
BA_OFFLINE_LOGO="$(pwd)/ba.png"
runtype="APT UPDATE"
runtype2="APT UPGRADE"
runtype3="APT DISTUPGRADE"
USER_NAME="user"
USER_UID=$(id -u $USER_NAME)
OS=""
VER=""

############### Funkciok ###############
# Ellenorizzuk, hogy a Bardi Auto logo le van e toltve az uzenetekhez.
assets(){
    if [ ! -f "$BA_OFFLINE_LOGO" ]; then
        wget -qO $BA_OFFLINE_LOGO $BA_ONLINE_LOGO
    fi
}

# Lekerjuk a distro verziojat
get_os_ver(){
    if [ -f /etc/os-release ];
    then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
    else
        echo "ERROR: I need the file /etc/os-release to determine what my distribution is..."
        # If you want, you can include older or distribution specific files here...
        exit
    fi
}
# Asztali ertesites kuldese a felhasznalonak
# notify [Public 0 | 1:int] [InfoType:str] [Message:str]  |  notify 1 "INFO" "apt fix missing futtatasa"
notify(){
    PUBLIC=$1
    HEADER=$2
    MSG=$3
    echo "[$HEADER] $MSG $BA_OFFLINE_LOGO"
    if [ $PUBLIC != "1" ]; then
        return
    fi
    
    if [ "$VER" = "16.04" ]; then
        sudo su user -c ' DISPLAY=:0 notify-send -t 0 "$MSG" --icon=$BA_OFFLINE_LOGO'
    elif [ "$VER" = "18.04" ]; then
        sudo -u user DISPLAY=:0 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/$USER_NAME/$USER_UID/bus notify-send -a batify -t 60000 --icon=$BA_OFFLINE_LOGO "$HEADER" "$MSG"
        #sudo su user -c ' DISPLAY=:0 notify-send -t 0 "$MSG" --icon=$BA_OFFLINE_LOGO'
        # DISPLAY=:0.0 /usr/bin/notify-send --icon=$BA_OFFLINE_LOGO -t 60000 -a batify "$HEADER" "$MSG"
    elif [ "$VER" = "20.04" ]; then
        sudo -u user DISPLAY=:0 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/$USER_NAME/$USER_UID/bus notify-send -a batify -t 60000 --icon=$BA_OFFLINE_LOGO "$HEADER" "$MSG"
    else
        DISPLAY=:0 notify-send -t 0 "$MSG" --icon=dialog-information
    fi
}

# sudo su user -c  'DISPLAY=:0.0 /usr/bin/notify-send --icon=/home/user/scrips/dist_upgrade/ba.png -t 60000 -a batify "asd" "asd"'

#Beallitjuk, hogy a teljes telepites noninteractive.
set_non_interactive_install(){
    echo "Non-interactive telepites globalis beallitasa"
    echo "debconf debconf/frontend select Noninteractive" | sudo debconf-set-selections
}

#Szabad hely ellenorzese
# disc_space [ellenorizni kivant minimum Gb:int]  |  disk_space 2
disc_space(){
    echo "Szabad tarhely ellenorzese"
    CHANGE=1024
    MIN_GBIT=$1 #Megadott minimum Gb
    RGBIT=$(((($MIN_GBIT * $CHANGE)) * $CHANGE))
    FREE=`df -k --output=avail "$PWD" | tail -n1` #Szabad hely
    FREEGB=$(((($FREE / $CHANGE)) / $CHANGE )) #Szabad hely Gb-ba
    if [[ $FREE -lt $RGBIT ]];
    then
        notify 1 "FATAL" "Nincs elegendo hely! Rendelkezésre áll: $FREEGB Gb. Szukseges lemezterulet a muvelet elinditasahoz $MIN_GBIT Gb!"
        exit 1
    else
        echo "Van elegendo hely '$FREEGB'GB"
    fi;
}



# kilojjuk a systemd-s processzeket amik foghatjak az apt-ot
kill_systemd_p(){
    echo "Systemd-s processzek kilovese"
    ps aux | grep apt.systemd | grep -v gre0p | awk '{print $2}' | while read line; do kill -9 $line; done
    # es az ahhoz tartozo lockfajlt is
    sudo rm -f /var/lib/dpkg/lock* 
}

# ha tobb mint fel napig nem sikerult frissiteni, ujrakezdjuk az egeszet  
watchdog_timelimit(){
    echo "Whatchdog beallistasa"
    if [ -f $file ] && [ $(find $file -mmin -720 | wc -l) -eq 0 ];
    then
        rm -f $file;
    fi
}


main(){
    echo "Upgrade inditasa"
    if [ -f $file ];
    then
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
            

            #keyboard-configuration telepites kozben ha kerne a "ket enteres reszt" beallitjuk, hogy mi legyen a layout, igy nem fogja kerni
            #echo "debconf debconf/frontend select Noninteractive" | sudo debconf-set-selections
            echo "keyboard-configuration keyboard-configuration/layout select 'Hungarian'" | sudo debconf-set-selections
            echo "keyboard-configuration keyboard-configuration/layoutcode select 'hu'" | sudo debconf-set-selections
            sudo DEBIAN_FRONTEND=noninteractive apt-get -yq install keyboard-configuration # via Zsolt

            sudo apt-get install -y -q # via Zsolt TODO
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

    if [ -f $file ] && [ $(grep "$runtype OK" $file | wc -l) -ne 0 ] && [ $(grep "$runtype2 OK" $file | wc -l) -ne 0 ] && [ $(grep "$runtype3 OK" $file | wc -l) -eq 0 ];
    then
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
        
        #Beallitjuk, hogy ha upgrade kozben force restart kezi megereositest kerne, akkor ne dobja fel, mert alapbol true ra allitottuk
        # echo '<package-and-setting-string>' | sudo debconf-set-selections
        echo 'libssl1.1 libraries/restart-without-asking boolean true' | sudo debconf-set-selections
        echo 'libc6 libraries/restart-without-asking boolean true' | debconf-set-selections
        echo 'libc6:amd64 libraries/restart-without-asking boolean true' | debconf-set-selections
        echo 'libpam0g libraries/restart-without-asking boolean true' | debconf-set-selections

        #bonus biztosra mehetunk, hogy package-nel se jojjon fel
        echo '* libraries/restart-without-asking boolean true' | sudo debconf-set-selections


        # Vagy ha minden kotel szakad es a 20. stackoverflow sem segit akkor csak remove-oljuk a needrestart-ot :)
        # apt remove needrestart

        yes | sudo DEBIAN_FRONTEND=noninteractive apt dist-upgrade -y # via Zsolt
        yes | sudo timeout 7200 DEBIAN_FRONTEND=noninteractive do-release-upgrade -f DistUpgradeViewNonInteractive </dev/null # ketto oraig futhat max
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

        if [ $(find /etc/systemd/system/multi-user.target.wants/x11vnc.service -type l | wc -l) -eq 0 ];
        then # Ubi 18 alatt mar nem indul el systemd alatt, ha nem symlink
            sudo mv /etc/systemd/system/multi-user.target.wants/x11vnc.service /lib/systemd/system
            sudo ln -s /lib/systemd/system/x11vnc.service /etc/systemd/system/multi-user.target.wants/
        fi
        sudo passwd -d user
        sleep 5; sudo reboot
    fi	

    exit 0
}


get_os_ver # Lekerjuk a distro verziojat
assets # Ellenorizzuk, hogy a Bardi Auto logo le van e toltve az uzenetekhez.
# set_non_interactive_install # Globalisan beallitjuk, hogy non interactive a telepites
disc_space 200 # Le ellenorizzuk, hogy van-e minimum 2 Gb szabad hely a gepen
# kill_systemd_p # kilojjuk a systemd-s processzeket amik foghatjak az apt-ot
# watchdog_timelimit # ha tobb mint fel napig nem sikerult frissiteni, ujrakezdjuk az egeszet 
# main


 notify 1 "INFO" "apt fix missing futtatasa"
