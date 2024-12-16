#!/bin/sh

target="$1"

useage() {
	echo "Useage: ./bootstrap-router.sh <install directory>"
}

if [ -z "$target" ]
then
	useage
	exit 0
fi

if [ -d "$target" ]
then
	useage
	exit 0
fi

echo $target

mkdir $target

# bootstrap with SSL certificates (to fetch from https repositories)
debootstrap --include=ca-certificates stable $target

# add debian repositories
echo "\
deb https://deb.debian.org/debian/ stable main contrib non-free-firmware
deb-src https://deb.debian.org/debian/ stable main contrib non-free-firmware

deb https://security.debian.org/debian-security stable-security main contrib non-free-firmware
deb-src https://security.debian.org/debian-security stable-security main contrib non-free-firmware

deb https://deb.debian.org/debian stable-updates main contrib non-free-firmware
deb-src https://deb.debian.org/debian stable-updates main contrib non-free-firmware" > $target/etc/apt/sources.list


LANG=C.UTF-8 arch-chroot $target /bin/bash <<END
apt update
apt install -y bash-completion command-not-found vim linux-image-amd64 network-manager locales sudo
DEBIAN_FRONTEND=noninteractive apt install -y console-setup

# TODO: check if needed in a (diskless) virtual machine
# apt install -y firmware-linux

echo "virtiofs" >> /etc/initramfs-tools/modules
update-initramfs -u

adduser --disabled-password --comment "" user
# just to make sure
# TODO: check what --disabled-password gives in /etc/shadow
passwd -d user
adduser user sudo

echo "i2p-os-router" > /etc/hostname

echo "fs	/       virtiofs        defaults        0       0" >> /etc/fstab
END




# install I2P
LANG=C.UTF-8 arch-chroot $target /bin/bash <<END1
apt install -y wget default-jdk

# wget https://geti2p.net/en/download/2.7.0/clearnet/https/files.i2p-projekt.de/i2pinstall_2.7.0.jar/download -O i2pinstall_2.7.0.jar

# java -jar i2pinstall_2.7.0.jar -console

# install and initialize the I2P router
sudo -u user bash <<END2
cd
wget https://files.i2p-projekt.de/2.7.0/i2pinstall_2.7.0.jar
echo -e "\n1\n1\n\nO\n1\n1\n" | java -jar i2pinstall_2.7.0.jar -console

# initialize the I2P router (before overriding its configurations in ~/.i2p)
cd ~/i2p
# the i2prouter cannot start as a daemon (with ./i2prouter start) inside an arch-chroot
# instead, fork the router process with ./i2prouter console &, and wait for it to initialize the ~/.i2p folder

#./i2prouter start
#./i2prouter stop
./i2prouter console &
sleep 10
# rm ~/.i2p/router.ping
END2
# wait for mountpoints not to be busy
sleep 1
END1


#TODO: test the following


# static IP address in the isolated network
cp "resources/router/Wired connection 2.nmconnection" "$target/etc/NetworkManager/system-connections/"

# i2p router configuration: serve over the IP address in the isolated network
cp "resources/router/router-config" "$target/home/user/.i2p/clients.config.d/00-net.i2p.router.web.RouterConsoleRunner-clients.config"

# systemd service: i2prouter
cp "resources/router/i2prouter.service" "$target/etc/systemd/system/"
# enable the service
LANG=C.UTF-8 arch-chroot $target /bin/bash <<END
#systemctl daemon-reload
systemctl enable i2prouter.service
# without this, exiting gives a "target is busy" error
sync
END

# override default tunnel configurations to allow access from the workstation
# (diff: 127.0.0.1 -> 192.168.101.1)
cp "resources/router/00-I2P HTTP Proxy-i2ptunnel.config" "$target/home/user/.i2p/i2ptunnel.config.d/"
cp "resources/router/05-I2P HTTPS Proxy-i2ptunnel.config" "$target/home/user/.i2p/i2ptunnel.config.d/"

