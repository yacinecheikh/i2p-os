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

sudo -u user bash <<END2
cd
wget https://files.i2p-projekt.de/2.7.0/i2pinstall_2.7.0.jar
echo -e "\n1\n1\n\nO\n1\n1\n" | java -jar i2pinstall_2.7.0.jar -console
END2
END1


# static IP address in the isolated network
cp "resources/router/Wired connection 2.nmconnection" "$target/etc/NetworkManager/system-connections/"

cp "resources/router/router-config" "$target/home/user/.i2p/clients.config.d/00-net.i2p.router.web.RouterConsoleRunner-clients.config"
