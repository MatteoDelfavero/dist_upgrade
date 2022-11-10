#!/bin/bash

#! sudo ellenorzese
sudo chown administrator:administrator /home/administrator/.bash_history # bugfix

#!############## Global variables ###################
USER_NAME="user"
USER_UID=$(id -u $USER_NAME)

WORKING_DIR=$(pwd)
# LOG_DIR=$WORKING_DIR/log.$(date +%s)
LOG_DIR="/home/ansible/log.$(date +%s)"
file="/home/ansible/releaseupgrade"
BA_OFFLINE_LOGO="/home/$USER_NAME/ba.png"

runtype="APT UPDATE"
runtype2="APT UPGRADE"
runtype3="APT DISTUPGRADE"

OS=""
VER="0"

#!############## Functions ###############
#* dpkg log filebol kiolvassuk, hogy volt-e hiba az upgrade kozben.
function fix_errors_from_dpkgLog() {
    # local logfile=/var/log/dpkg.log
    # local logfile=$LOG_DIR/apt.autoremove.log
    local logfile=$LOG_DIR/upgrade.log

    if [ ! -f $logfile ]; then
        notify 0 "WARNING" "Nincs dpkg log file, sajat log hasznalat!"
    fi

    sudo echo "STARTED" >$LOG_DIR/fix_errors_from_dpkgLog.function
    #* Biztonsagi masolat keszitese a regi logfilerol
    #sudo mv $logfile $logfile.$(date +%s)

    sudo dpkg --configure -a --force confdef 2>&1 | tee -a $LOG_DIR/dpkg.log
    sudo apt-get --allow-unauthenticated -y clean 2>&1 | tee -a $LOG_DIR/apt.clean.log
    sudo apt-get --allow-unauthenticated -y autoremove 2>&1 | tee -a $LOG_DIR/apt.autoremove.log
    for package in $(sudo cat $logfile | grep "a fájllista fájl hiányzik a következő csomaghoz" | grep -Po '(?<=„).*?(?=”)'); do
        echo "$package csomag áthelyezve a //var//lib//dpkg//info/ mappabol a //tmp// mappaba." -a $LOG_DIR/package.move.log >tee
        # notify 0 "INFO" "$package csomag athelyezve a tmp konyvtarba"
        #* athelyezzuk a tmp mappaba
        sudo mv /var/lib/dpkg/info/$package.* /tmp/ 2>&1 | tee -a $LOG_DIR/file.log
    done
    sudo apt-get --allow-unauthenticated -y install --fix-broken 2>&1 | tee -a $LOG_DIR/fix-broken.log
    sudo echo "OK" >>$LOG_DIR/fix_errors_from_dpkgLog.function
}

#* Beallituj a helyes idozonat, hogy telepites kozbe ne kerdezze
function set_timezone() {
    sudo timedatectl set-timezone Europe/Budapest
}

#* /var/run/motd.dynamic file-ba frissitjuk a helyes verziot
function update_version_in_sshd() {
    if [ ! -f /etc/os-release ]; then
        notify 0 "WARNING" "Nincs /etc/os-release file, lepes kihagyva!"
        return
    fi

    . /etc/os-release
    local motdFile=/var/run/motd.dynamic
    local originalVerStr="Ubuntu $VER.5 LTS"

    if [ ! -f $motdFile ]; then
        notify 0 "WARNING" "Nincs $motdFile file, lepes kihagyva!"
        return
    fi

    if ! grep -q $originalVerStr "$motdFile"; then
        notify 0 "WARNING" "Nem talalhato verzio a /var/run/motd.dynamic file-ba!"
        return
    fi

    sed -i "s/$originalVerStr/$PRETTY_NAME/g" $motdFile
}

#* Ellenorizzuk, hogy a Bardi Auto logo le van e toltve az uzenetekhez.
function assets() {
    local BA_ONLINE_LOGO="http://opsrepo.bardiauto.hu/installers/bardi_auto_logo-v1.png"
    if [ ! -d $LOG_DIR ]; then
        sudo mkdir -p $LOG_DIR
    fi

    if [ ! -f "$BA_OFFLINE_LOGO" ]; then
        sudo wget -qO $BA_OFFLINE_LOGO $BA_ONLINE_LOGO
    fi
}

#* Asztali ertesites kuldese a felhasznalonak
# usage: notify [Public 0 | 1:int] [InfoType:str] [Message:str]  |  notify 1 "INFO" "apt fix missing futtatasa"
function notify() {
    local PUBLIC=$1
    local HEADER=$2
    local MSG=$3
    local DATE=$(date +%Y-%m-%d' '%T)

    echo "[$HEADER] $DATE $MSG" 2>&1 | tee -a $LOG_DIR/script.log
    if [ $PUBLIC != "1" ]; then
        return
    fi

    case $VER in
    '16.04')
        sudo su $USER_NAME -c ' DISPLAY=:0 notify-send -t 0 "$MSG" --icon=dialog-information'
        ;;
    '18.04')
        sudo -u user DISPLAY=:0 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/$USER_NAME/$USER_UID/bus notify-send -a batify -t 60000 --icon=$BA_OFFLINE_LOGO "$HEADER Rendszer frissites" "$MSG"
        # sudo -u $USER_NAME DISPLAY=:0 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/$USER_NAME/$USER_UID/bus | notify-send -t 60000 --icon=$BA_OFFLINE_LOGO "$HEADER Rendszer frissites" "$MSG"
        ;;
    '20.04')
        sudo -u user DISPLAY=:0 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/$USER_NAME/$USER_UID/bus notify-send -a batify -t 60000 --icon=$BA_OFFLINE_LOGO "$HEADER Rendszer frissites" "$MSG"
        ;;
    '22.04')
        sudo -u user DISPLAY=:0 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/$USER_NAME/$USER_UID/bus notify-send -a batify -t 60000 --icon=$BA_OFFLINE_LOGO "$HEADER Rendszer frissites" "$MSG"
        ;;
    *)
        sudo -u user DISPLAY=:0 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/$USER_NAME/$USER_UID/bus notify-send -a batify -t 60000 --icon=$BA_OFFLINE_LOGO "$HEADER Rendszer frissites" "$MSG"
        sudo su $USER_NAME -c ' DISPLAY=:0 notify-send -t 0 "$MSG" --icon=dialog-information'
        ;;
    esac
}

#* Lekerjuk a distro verziojat
function get_os_ver() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
    else
        notify 0 "FATAL" "I need the file /etc/os-release to determine what my distribution is..."
    fi
}

#* Beallitjuk, hogy a teljes telepites noninteractive.
function set_non_interactive_install() {
    echo "Non-interactive telepites globalis beallitasa"
    echo "debconf debconf/frontend select Noninteractive" | sudo debconf-set-selections
}

#* Szabad hely ellenorzese
# usage: disc_space [ellenorizni kivant minimum GB:int]  |  disk_space 5
function disc_space() {
    echo "Szabad tarhely ellenorzese"
    local CHANGE=1024
    local MIN_GBIT=$1 #Megadott minimum GB
    local RGBIT=$(((($MIN_GBIT * $CHANGE)) * $CHANGE))
    local FREE=$(sudo df -k --output=avail "$PWD" | tail -n1) #Szabad hely
    local FREEGB=$(((($FREE / $CHANGE)) / $CHANGE))           #Szabad hely GB-ba
    if [[ $FREE -lt $RGBIT ]]; then
        notify 1 "FATAL" "Nincs elegendo hely! Rendelkezésre áll: $FREEGB GB. Szukseges lemezterulet a muvelet elinditasahoz $MIN_GBIT GB!"
        exit 1
    else
        echo "Van elegendo hely '$FREEGB'GB"
    fi
}

#* kilojjuk a systemd-s processzeket amik foghatjak az apt-ot
function kill_systemd_p() {
    echo "Systemd-s processzek kilovese"
    sudo ps aux | grep apt.systemd | grep -v gre0p | awk '{print $2}' | while read line; do kill -9 $line; done
    #* es az ahhoz tartozo lockfajlt is
    sudo rm -f /var/lib/dpkg/lock* 2>&1 | tee -a $LOG_DIR/file.log
}

#* ha tobb mint fel napig nem sikerult frissiteni, ujrakezdjuk az egeszet
function watchdog_timelimit() {
    echo "Whatchdog beallistasa"
    if [ -f $file ] && [ $(find $file -mmin -720 | wc -l) -eq 0 ]; then
        sudo rm -f $file 2>&1 | tee -a $LOG_DIR/file.log
    fi
}

function main() {
    echo "Upgrade inditasa"
    if [ -f $file ]; then
        #* Ha minden lefutott, akkor nem megyunk tovabb
        if [ $(grep -E "\[FATAL\]|\[SUCCESS\]" $file | wc -l) -ne 0 ]; then
            echo -e "[INFO] A szkript vegigfutott:\n$(cat $file)"
            exit 0
        else
            if [ $(grep "$runtype OK" $file | wc -l) -ne 0 ] && [ $(grep "$runtype2 OK" $file | wc -l) -ne 0 ] && [ $(grep "$runtype3 OK" $file | wc -l) -ne 0 ]; then
                old=$(head -1 $file)
                new=$(sudo cat /etc/os-release | grep -i PRETT | cut -d '"' -f 2 | cut -d "." -f 1)
                notify 0 "INFO" "Kiindulasi verzio: $old | Uj verzio: $new"
                if [[ "$old" = "$new" ]]; then
                    notify 0 "FATAL" "A frissites sikertelen volt."
                    mv $file $file.$(date +%s)
                    if [ -f /var/run/reboot-required ]; then
                        sudo reboot
                    fi
                else
                    notify 0 "SUCCESS" "A frissites sikeres volt."
                fi
                notify 1 "SUCCESS" "Verziovaltas kesz, eredmenyek a MGMT feluleten."
                exit 0
            fi
        fi
    fi

    #* ha fut folyamat, akkor nem megyunk tovabb
    if [ -f $file ] && [ $(grep "IN PROGRESS" $file | wc -l) -ne 0 ]; then
        echo -e "[INFO] Folyamat fut:\n$(cat $file)"
        exit 0
    fi

    # echo 'DPkg::options { "--force-confdef"; "--force-confnew"; }' | sudo tee /etc/apt/apt.conf.d/local
    echo 'DPkg::options {  "--force-confnew"; }' | sudo tee /etc/apt/apt.conf.d/local

    #* alapesetben fel oraig varna rebootkor az unattended-upgrades servicere, ezt levesszuk 15mp-re
    sudo find /etc/ -type f -name "*unattended-upgrades*" | while read line; do if [ $(grep -i timeout $line | wc -l) -ne 0 ]; then
        echo $line
        sed "s/1800/15/g" -i $line
    fi; done

    if [ ! -f $file ] || [ $(grep "$runtype OK" $file | wc -l) -eq 0 ]; then
        cat /etc/os-release | grep -i PRETT | cut -d '"' -f 2 | cut -d "." -f 1 >$file
        echo "$(date +%Y-%m-%d' '%T) $runtype IN PROGRESS" | sudo tee -a $file
        notify 1 "INFO" "$runtype Folyamatban"
        sudo dpkg --configure -a 2>&1 | tee -a $LOG_DIR/dpkg.log
        sudo rm -f /var/lib/apt/lists/* 2>&1 | tee -a $LOG_DIR/file.log
        sudo apt-get -y update

        exitcode=$?
        sed '/IN PROGRESS/d' -i $file
        #! what? na ezt ne igy
        if [ $exitcode -ne 0 ] && [ $exitcode -ne 100 ]; then
            notify 0 "INFO" "Nem sikerult lekerni a frissitesek listajat. Visszateresi ertek: $exitcode"
        else
            echo "$(date +%Y-%m-%d' '%T) $runtype OK" | sudo tee -a $file
            notify 0 "INFO" "Sikerult lekerni a frissitesek listajat. Visszateresi ertek: $exitcode"
            notify 1 "INFO" "Sikeres adat lekeres"
        fi
    fi

    echo ""

    if [ -f $file ] && [ $(grep "$runtype OK" $file | wc -l) -ne 0 ] && [ $(grep "$runtype2 OK" $file | wc -l) -eq 0 ]; then
        echo "$(date +%Y-%m-%d' '%T) $runtype2 IN PROGRESS" | sudo tee -a $file
        notify 1 "INFO" "Frissites folyamatban."
        yes | sudo dpkg --configure -a 2>&1 | tee -a $LOG_DIR/dpkg.log

        if [ $(sudo cat /etc/os-release | grep VERSION_ID | grep 18 | wc -l) -ne 0 ]; then
            notify 0 "INFO" "apt-bol telepitett Chromium eltavolitasa"
            yes | sudo apt remove chromium-browser-l10n -y                                                                           # via Zsolt
            sudo snap set system proxy.http="http://dc-proxy01.server.bardihu.lan:3128"                                              # via Zsolt
            sudo snap set system proxy.http="https://dc-proxy01.server.bardihu.lan:3128"                                             # via Zsolt
            sudo sh -c "echo ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true | debconf-set-selections" # via Zsolt

            #* keyboard-configuration telepites kozben ha kerne a "ket enteres reszt" beallitjuk, hogy mi legyen a layout, igy nem fogja kerni
            echo "keyboard-configuration keyboard-configuration/layout select 'Hungarian'" | sudo debconf-set-selections
            echo "keyboard-configuration keyboard-configuration/layoutcode select 'hu'" | sudo debconf-set-selections
            sudo DEBIAN_FRONTEND=noninteractive apt-get -yq install keyboard-configuration # via Zsolt

            sudo apt-get --allow-unauthenticated -y -f install # via Zsolt TODO
            sudo apt-get -y update
            sudo apt-get --allow-unauthenticated -y install msttcorefonts -qq # via Zsolt
            sudo snap install chromium                                        # via Zsolt
        fi

        sudo apt-get --allow-unauthenticated -y --fix-broken install 2>&1 | tee -a $LOG_DIR/fix-broken.log
        #sleep 60
        #sudo timeout 7200 apt upgrade -o Acquire::http::Dl-Limit=512 -y --allow-unauthenticated </dev/null # ketto oraig futhat max
        #* upgrade elott beallitjuk az idozonat
        set_timezone

        #* Toroljuk azokat a lock fileokat amik lock-olhatjak az apt-t
        sudo rm -f /var/lib/dpkg/lock* 2>&1 | tee -a $LOG_DIR/file.log
        sudo apt-get -y update
        sudo apt-get -o Acquire::http::Dl-Limit=512 -y --allow-unauthenticated --with-new-pkgs upgrade 2>&1 | tee -a $LOG_DIR/upgrade.log
        fix_errors_from_dpkgLog
        #yes | sudo timeout 7200 apt upgrade -fy --allow-unauthenticated --with-new-pkgs </dev/null

        exitcode=$?
        sed '/IN PROGRESS/d' -i $file
        if [[ $exitcode -eq 0 ]] || [[ $exitcode -eq 124 ]]; then
            echo "$(date +%Y-%m-%d' '%T) $runtype2 OK" | sudo tee -a $file
            notify 0 "INFO" "Sikeresen lefutott az apt upgrade. Visszateresi ertek: $exitcode"
            notify 1 "INFO" "Frissites sikeres."
            if [ -f /var/run/reboot-required ]; then
                notify 1 "INFO" "Kliens ujrainditasa 1 percen belul!"
                sleep 15
                sudo reboot
            fi
        else
            notify 0 "INFO" "Nem sikerult lefuttatni az apt upgrade-t. Visszateresi ertek: $exitcode"
            notify 1 "FATAL" "Sikertelen frissites probalkozas a helyreallitasra..."
            notify 0 "INFO" "apt fix missing futtatasa"
            sudo apt-get update --fix-missing 2>&1 | tee -a $LOG_DIR/apt.update-fix-missing.log
            if [ -f /var/run/reboot-required ]; then
                notify 1 "INFO" "Kliens ujrainditasa 1 percen belul!"
                sleep 15
                sudo reboot
            fi
        fi
    fi

    echo ""

    if [ -f $file ] && [ $(grep "$runtype OK" $file | wc -l) -ne 0 ] && [ $(grep "$runtype2 OK" $file | wc -l) -ne 0 ] && [ $(grep "$runtype3 OK" $file | wc -l) -eq 0 ]; then
        echo "$(date +%Y-%m-%d' '%T) $runtype3 IN PROGRESS" | sudo tee -a $file
        notify 1 "INFO" "Verzio frissites folyamatban."

        sudo snap set system proxy.http="http://dc-proxy01.server.bardihu.lan:3128"
        sudo snap set system proxy.http="https://dc-proxy01.server.bardihu.lan:3128"

        #?! Ellenorizni, hogy ez kell e nekunk
        sudo rm -f /var/lib/apt/lists/* 2>&1 | tee -a $LOG_DIR/file.log
        sudo dpkg --configure -a 2>&1 | tee -a $LOG_DIR/dpkg.log
        sudo apt-get update --fix-missing 2>&1 | tee -a $LOG_DIR/apt.update-fix-missing.log

        # yes | sudo apt install -f -y > /dev/null

        #* Beallitjuk, hogy ha upgrade kozben force restart kezi megereositest kerne, akkor ne dobja fel, mert alapbol true ra allitottuk
        echo 'libssl1.1 libraries/restart-without-asking boolean true' | sudo debconf-set-selections
        echo 'libc6 libraries/restart-without-asking boolean true' | sudo debconf-set-selections
        echo 'libc6:amd64 libraries/restart-without-asking boolean true' | sudo debconf-set-selections
        echo 'libpam0g libraries/restart-without-asking boolean true' | sudo debconf-set-selections

        #* bonus biztosra mehetunk, hogy package-nel se jojjon fel
        echo '* libraries/restart-without-asking boolean true' | sudo debconf-set-selections

        # yes | sudo timeout 7200 DEBIAN_FRONTEND=noninteractive do-release-upgrade -f DistUpgradeViewNonInteractive </dev/null # ketto oraig futhat max
        # yes | sudo timeout 7200 do-release-upgrade -f DistUpgradeViewNonInteractive </dev/null # ketto oraig futhat max

        #* Ismet beallitjuk a noninteractive-ot
        set_non_interactive_install

        sudo apt-get --allow-unauthenticated -y dist-upgrade 2>&1 | tee -a $LOG_DIR/dist-upgrade.log

        #* 16, 18 as verzional letrehozzuk ezt a filet /etc/apt/apt.conf.d/local
        #! athelyezve
        #echo 'DPkg::options { "--force-confdef"; "--force-confnew"; }' | sudo tee /etc/apt/apt.conf.d/local

        sudo dpkg --configure -a --force confdef
        #! timeout-ra errorozott az Ubuntu
        #! "--force-confdef"; "--force-confnew" az do-release-upgrade-nél
        #! Használni apt-get: --allow-unauthenticated -y
        sudo DEBIAN_FRONTEND=noninteractive do-release-upgrade -f DistUpgradeViewNonInteractive 2>&1 | tee -a $LOG_DIR/do-release-upgrade.log
        # sudo sh -c 'echo "y\n\ny\ny\ny\ny\ny\ny\ny\ny\ny\ny\ny\ny\n" | DEBIAN_FRONTEND=noninteractive /usr/bin/do-release-upgrade'
        #* Telepites utan toroljuk az ideiglenesen letrehozott filet, kesobbiekben nem kell

        exitcode=$?
        sed '/IN PROGRESS/d' -i $file

        sudo apt update -y # via Zsolt
        #! "--force-confdef"; "--force-confnew" az upgrade-nél
        sudo apt -y upgrade 2>&1 | tee -a $LOG_DIR/upgrade.log # via Zsolt
        #! "--force-confdef"; "--force-confnew" az autoremove-nél
        sudo apt-get --allow-unauthenticated -y autoremove 2>&1 | tee -a $LOG_DIR/apt.autoremove.log # via Zsolt
        sudo apt-get --allow-unauthenticated -y clean 2>&1 | tee -a $LOG_DIR/clean.log               # via Zsolt

        sudo rm -f /etc/apt/apt.conf.d/local 2>&1 | tee -a $LOG_DIR/file.log
        #* grub reinstall
        sudo grep -v rootfs /proc/mounts | grep "^/dev/" | awk '{print $1}' | tr -d '0123456789' >/tmp/grubmbrbd.tmp
        df -h /boot | grep "^/dev/" | awk '{print $1}' | tr -d '0123456789' >>/tmp/grubmbrbd.tmp
        sudo fdisk -l | grep "^Disk" | grep dev | awk '{print $2}' | cut -d ":" -f 1 >>/tmp/grubmbrbd.tmp
        cat /boot/grub/grub.cfg | grep UUID | awk '{print $3}' | cut -d "=" -f 3 | sort | uniq | while read uuid; do blkid | grep "$uuid" | cut -d ":" -f 1 | tr -d '0123456789'; done >>/tmp/grubmbrbd.tmp

        cat /tmp/grubmbrbd.tmp | sort | uniq | while read bd; do sudo grub-install $bd; done

        echo "$(date +%Y-%m-%d' '%T) $runtype3 OK" | sudo tee -a $file
        notify 1 "INFO" "Verzio frissites sikeres!"
        notify 1 "INFO" "Kliens ujrainditasa 1 percen belul!"
        if [ $(find /etc/systemd/system/multi-user.target.wants/x11vnc.service -type l | wc -l) -eq 0 ]; then # Ubi 18 alatt mar nem indul el systemd alatt, ha nem symlink
            sudo mv /etc/systemd/system/multi-user.target.wants/x11vnc.service /lib/systemd/system
            sudo ln -s /lib/systemd/system/x11vnc.service /etc/systemd/system/multi-user.target.wants/
        fi

        update_version_in_sshd

        sudo passwd -d user
        sleep 15
        sudo reboot
    fi

    exit 0
}

get_os_ver                  # Lekerjuk a distro verziojat
assets                      # Ellenorizzuk, hogy a Bardi Auto logo le van e toltve az uzenetekhez.
set_non_interactive_install # Globalisan beallitjuk, hogy non interactive a telepites
disc_space 5                # Le ellenorizzuk, hogy van-e minimum 5 Gb szabad hely a gepen (18>20 ra minimum 3Gb kell neki)
kill_systemd_p              # kilojjuk a systemd-s processzeket amik foghatjak az apt-ot
watchdog_timelimit          # ha tobb mint fel napig nem sikerult frissiteni, ujrakezdjuk az egeszet
main                        # main upgrade release-upgrade futtatasa
