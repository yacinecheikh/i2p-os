# Manual build instructions

## End user install

If you just want to use i2p-os, go to the [Virtual machine setup (virtiofs image)](#virtual-machine-setup-virtiofs-image) section

## Platforms

Implemented platforms:
- Debian VM on Virtiofs

Planned platforms:
- Docker (with a VNC-controlled browser for example)
- qcow2 virtual disk VM


# Router

## Base environment bootstrapping

The i2p-os router is a Debian-based diskless virtual machine.
The Debian environment is created using debootstrap.

```sh
./bootstrap-router i2p-router
```


# Environment setup

I2p-os is currently based on Debian, and is built in a chroot with debootstrap.

## Chroot install:

This step will bootstrap a minimal Debian install from scratch with Debootstrap. This approach is used because bootstrapping gives more flexibility in unusual configurations like booting on a virtiofs root, and because the process can be automated.

```sh
# create the environment
mnt=test-i2p
mkdir $mnt
debootstrap --include=ca-certificates stable $mnt  # add ssl certificates before chrooting
# TODO: replace by a versioned file import (the current system cannot be built without a pre-installed debian)
sudo cp /etc/apt/sources.list $mnt/etc/apt/sources.list  # import
```

```sh
# install the system
LANG=C.UTF-8 sudo arch-chroot $mnt
apt install bash-completion command-not-found vim
#update-alternatives --config editor
# choose 2 for vim
# The name of the virtiofs rootfs is "fs"
echo "fs    /       virtiofs        defaults        0       0" >> $mnt/etc/fstab

# linux kernel and firmware
apt install linux-image-amd64 firmware-linux

# initramfs (requires the virtiofs driver)
echo "virtiofs" >> /etc/initramfs-tools/modules
update-initramfs -u

# internet access
apt install network-manager

apt install locales
# TODO: automate (currently prompts for the keyboard layout, choose US)
apt install console-setup
        > ENTER, ENTER
        (pour bépo: choisir FR (BÉPO))

# TODO: automate to skip the prompt (UTC) or leave the default configuration
# dpkg-reconfigure tzdata

# users
apt install sudo
adduser user
        -> password random
passwd -d user (retire le mdp)

# XFCE
tasksel install xfce-desktop

echo "i2p-os" > /etc/hostname
exit
```

## Virtual machine setup (virtiofs image)

This step has to be done by the end user in order to use the virtual machine, and is currently required for manual builders in order to manually install the i2prouter, dependencies and configurations.

On virt-manager, create a manually configured virtual machine for Debian, without storage, and with these configurations:
- (in the RAM configuration) enable shared memory
- (in the boot options) enable direct kernel boot
    - kernel path: /path/to/i2p-os/vmlinuz
    - initrd path: /path/to/i2p-os/initrd.img
    - kernel args: rootfstype=virtiofs root=fs
- (in the add device menu) add a filesystem
    - driver: virtiofs
    - target path: fs
    - source path: /path/to/i2p-os
- (optional) add another filesystem to exchange files with the host
    - driver: virtiofs
    - target path: storage
    - source path: /path/to/shared-folder

Then, start the virtual machine. The default user is user, and the password is empty.

If you added a shared folder, you will have to mount it manually or add it in the /etc/fstab of i2p-os.


## I2P install on a VM

This step is not required for users who downloaded a pre-built VM.

After starting the VM, download the I2P router from [the I2P project website](https://geti2p.net/en/download) and run:
```sh
sudo apt install default-jdk
java -jar ~/Downloads/i2pinstall*.jar
```

I would recommend to keep the default settings and English language in the I2P installer, in order to minimize privacy leaks in case the i2p-os VM gets hacked.


Run the I2P router:
```sh
cd ~/i2p
./i2prouter console
```
This will open the I2P setup process in your browser (Firefox).
The settings in the pre-built images are:
- light mode
- bandwidth test done on a consumer laptop (should be reconfigured by the end user)

Once the I2P setup is finished, go to the Firefox network settings and configure:
- manual proxy configuration
- HTTP Proxy: 127.0.0.1, port: 4444
- HTTPS Proxy: 127.0.0.1, port: 4444

![Outdated Firefox configuration screen](https://geti2p.net/_static/images/firefox57.connectionsettings.png)

Then, open a tab and type `about:config` to access the advanced firefox configurations, and set:
- `media.peerconnection.ice.proxy_only` to `true`
- `keyword.enabled` to `false`

![Firefox settings screen](https://geti2p.net/_static/images/firefox.webrtc.png)

You can verify that Firefox will always use I2P by trying to access I2P websites like `i2p-projekt.i2p`, and by checking you IP address on [whatismyipaddress.com](https://whatismyipaddress.com/) or [monip.net](https://monip.net/) (french equivalent with less tracker popups and distraction).


To make the I2P service into a background service, stop the i2prouter with Ctrl+C, add this SystemD file to /etc/systemd/system/i2prouter.service:

```
[Unit]
Description=i2prouter
After=network.target

[Service]
Type=simple
ExecStart=/home/user/i2p/i2prouter console
User=user
Group=user

[Install]
WantedBy=multi-user.target
```

And run:
```sh
sudo systemctl daemon-reload
sudo systemctl start i2prouter.service
sudo systemctl enable i2prouter.service
```

That's it, you now have a dedicated VM for I2P browsing!
