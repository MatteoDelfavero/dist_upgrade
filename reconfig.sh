#!/bin/bash



cat << text
Multi line
comments
and
print
text

:'
asd
asd
asd'

# HINT: ha restartot ker
# if [ -f /var/run/reboot-required ]; then
# 	sudo reboot
# fi

-u user DISPLAY=:0 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus notify-send -t 60000 "Rendszer frissites" "asd"

sudo su user -c 'DISPLAY=:0 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus | notify-send -t 60000 "Rendszer frissites" "asd"'
        # echo '<package-and-setting-string>' | sudo debconf-set-selections




        #* Azokat a package-eket melyek hibaasak ujra telepitjuk
        # for package in $(sudo apt-get upgrade -y --allow-unauthenticated --with-new-pkgs 2>&1 | grep "a fájllista fájl hiányzik a következő csomaghoz" | grep -Po '(?<=„).*?(?=”)'); do
        #     echo "Package: $package - serult dpkg, reinstall futtatasa"
        #     sudo apt-get install -y --reinstall "$package"
        # done


#!/bin/bash
exp()
{
	"$1" <(cat <<-EOF
	spawn passwd $USER
	expect "Enter new UNIX password:"
	send -- "$passw\r"
	expect "Retype new UNIX password:"
	send -- "$passw\r"
	expect eof
	EOF
	)
	echo "password for USER $USER updated successfully - adding to sudoers file now"
}

if [ ! -f /usr/bin/expect ] && [ ! -f /bin/expect ];then
    apt-get update
    apt install -y expect
    exp "/usr/bin/expect"
else
    exp "/usr/bin/expect"
fi





#!/bin/bash
OS=""
VER="0"
get_os_ver() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
    else
        notify 0 "FATAL" "I need the file /etc/os-release to determine what my distribution is..."
        exit
    fi
}
get_os_ver

case $VER in
    '18.04')
        echo "18"
        ;;
    '20.04')
        echo "20"
        ;;
    '22.04')
        echo "22"
        ;;
    *)
        echo "FATAL"
        ;;

esac







#https://phoenixnap.com/kb/linux-expect
#TODO non interactive
for i in $(sudo dpkg -l | grep '^ii' | awk '{print $2}'); do
    echo $i
    sudo dpkg-reconfigure $i
done


sudo rm -f /var/lib/dpkg/lock*
sudo apt-get update
for package in $(sudo apt-get upgrade 2>&1 | grep "a fájllista fájl hiányzik a következő csomaghoz" | grep -Po '(?<=„).*?(?=”)'); do
    echo "$package serult dpkg, reinstall futtatasa"
    sudo apt --fix-broken install "$package"
    sudo apt-get install --reinstall "$package"
done
sudo apt autoremove -y
#sudo apt --fix-broken install chromium-codecs-ffmpeg

./d
#!/bin/bash
sudo apt-get update
sudo rm upgradelog
sudo apt-get upgrade -y --allow-unauthenticated --with-new-pkgs 2>&1 | tee upgradelog
for package in $(cat upgradelog 2>&1 | grep "a fájllista fájl hiányzik a következő csomaghoz" | grep -Po '(?<=„).*?(?=”)'); do
    echo "$package serult dpkg, reinstall futtatasa"
    apt-get install --reinstall "$package"
done
sudo mv upgradelog upgradelog.$(date +%s)

sudo apt-get upgrade -y --allow-unauthenticated --with-new-pkgs 2>&1 | tee upgradelog

send_user "password?\ "
expect_user -re "(.*)\n"
for {} 1 {} {
    if {[fork]!=0} {sleep 3600;continue}
    disconnect
    spawn priv_prog
    expect Password:
    send "$expect_out(1,string)\r"
    . . .
    exit
}



#!/usr/bin/expect
spawn sudo apt --fix-broken install
expect "=N:nem" { send "\r" }

for i in $(sudo dpkg -l | grep '^ii' | awk '{print $2}'); do
    echo $i
    spawn sudo dpkg-reconfigure $i
    expect "=N:nem" { send "\r" }
done




# for package in $(test.txt |
#     grep "a fájllista fájl hiányzik a következő csomaghoz" |
#     grep -Po "[^'\n ]+'" | grep -Po "[^']+"); do
#     echo "$package serult dpkg, reinstall futtatasa"
#     apt-get install --reinstall "$package"
# done
# dpkg: figyelj!: a fájllista fájl hiányzik a következő csomaghoz: „libavahi-core7:amd64”
# feltételezem, hogy a csomagnak nincsenek jelenleg telepített fájljai

# cat test.txt | grep "a fájllista fájl hiányzik a következő csomaghoz" | grep -Po "[^„\n ]+'" | grep -Po "[^”]+"
# cat test.txt | grep "a fájllista fájl hiányzik a következő csomaghoz" | grep -Po '(?<=„).*?(?=”)'
