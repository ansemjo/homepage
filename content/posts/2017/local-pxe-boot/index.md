---
title: Local PXE Boot Server
date: 2017-03-09
draft: false
toc: true
tags:
  - linux
  - automation
---

# 1. motivation

Today I set out to setup a local CentOS mirror for quicker PXE installations of my virtual machines. In the long run this will probably be superseded by a [Spacewalk] machine (**update:** discontinued on May 31, 2020) and until now [netboot.xyz] has served me well. For the time being I just wanted a faster alternative.

The kpxe file for [netboot.xyz] is tiny and can easily be used with the builtin TFTP server of OpenWRT / LEDE project or any other TFTP server. It uses signatures to verify the downloaded files, _however_ it keeps downloading all the files over http because https keeps timing out for me. So, yeah. Also you are downloading a lot of data multiple times if you're deploying multiple machines.

[Spacewalk]: http://spacewalk.redhat.com/ "Free & Open Source Systems Management"
[netboot.xyz]: https://netboot.xyz/ "DHCP boot image file"

_I will be focusing on the TFTP server and the local mirror here. There's plenty of documentation around the net on how to enable PXE boot through DHCP options. For a LEDE project router it is as simple as `DHCP and DNS` > `TFTP Settings` > `Enable ..` > `Network boot image: pxelinux.0,,<ipaddr>`._

_There is also a HowTo for CentOS 6 on their [wiki](https://wiki.centos.org/HowTos/NetworkInstallServer)._

---

# 2. setup

The base system will be a recent [CentOS 7.3 minimal] installation. No additional packages were installed during setup, SElinux stays enabled in enforcing mode and `firewalld` is active per the default. A mirror of the current latest CentOS version is a little over 8GB. If you want to install more versions or perhaps other distributions, plan your harddrive space accordingly.

[CentOS 7.3 minimal]: http://isoredirect.centos.org/centos/7/isos/x86_64/CentOS-7-x86_64-Minimal-1611.iso "CentOS 7.3.1611 Minimal Download"


## 2.1 network configuration

First of all, make sure that your TFTP server has a static IP and a running DHCP server points to it for PXE boot. I'm going to skip this step here because I am assuming a seperate DHCP server. _([this wiki](https://wiki.centos.org/HowTos/NetworkInstallServer) might help)_


## 2.2 packages

We need some additional packages. Namely, we need the TFTP server, some Syslinux files for the PXE menu and a webserver to serve our kickstart file and the local CentOS mirror.

Install them all with:
```
root @pxe ~ # yum install tftp-server syslinux-tftpboot httpd
```

The `syslinux-tftpboot` package puts some files into `/var/lib/tftpboot/` and this is also the default directory served by `tftp-server`.

`httpd` serves files from `/var/www/html/` by default, so we're going to put our kickstart files and mirror there.


## 2.3 tftp-server

All the menu files for Syslinux are now present but it still lacks configuration. Syslinux expects those in a subdirectory `pxelinux.cfg/` and looks for a file called `default` in there. So let's add a configuration file now:

```
root @pxe /var/lib/tftpboot # mkdir pxelinux.cfg
root @pxe /var/lib/tftpboot # vi pxelinux.cfg/default
```

The contents should be similar to these:

```
default menu.c32
prompt 0
timeout 300
ONTIMEOUT local

MENU TITLE PXE Menu

LABEL local
	MENU LABEL Boot from local harddrive
	LOCALBOOT 0

LABEL centos
	MENU LABEL ^CentOS 7.3.1611 x86_64
	KERNEL images/centos/7.3.1611/x86_64/vmlinuz
	APPEND ks=http://pxe/kickstart/centos.ks initrd=images/centos/7.3.1611/x86_64/initrd.img ramdisk_size=100000
```

_You see my finished CentOS entry there. The appropriate files are still missing of course .. Observe however: `version='7.3.1611'; arch='x86_64';`. We'll need those values a few times._


## 2.4 select a mirror

Now would be a good moment to select a mirror, which delivers good performance for you. Either consult the [Mirrorlist] for mirrors close to you or - if your system has `yum-plugin-fastestmirrors`, which probably is the case - take a look at `/var/cache/yum/$arch/$version/timedhosts.txt`. The smaller the last number, the better.

Preferably, use both ressources and choose a mirror which supports the rsync protocol. Note down the HTTP and RSYNC locations.

[Mirrorlist]: https://www.centos.org/download/mirrors/ "List of CentOS Mirrors"


## 2.5 kernel images

The first thing that should load after the Syslinux menu is the kernel. So let's download the appropriate images.

I've created a  folder structure starting with `images/` and the distribution in the TFTP directory. The rest of the path is similar to the paths on the CentOS mirrors but slightly abbreviated:

```
root @pxe /var/lib/tftpboot # ll images/centos/7.3.1611/x86_64/
total 47628
-rw-r--r--. 1 1000 1000 43372552 Dec  5 14:20 initrd.img
-rwxr-xr-x. 1 1000 1000  5392080 Nov 22 17:53 vmlinuz*
```

These two files would be located under `/7.3.1611/os/x86_64/images/pxeboot/` on a regular CentOS mirror. If you look back at the Syslinux configuration above, you'll find the kernel and initrd lines matching these files.


## 2.6 kickstart

[Kickstart] is a way to perform automated system installations. This requires another configuration file, which is appended when loading the initrd. Let's create that kickstart file in `/var/www/html/` now. Actually, I'm going to use a subfolder `kickstart/` and a file named `centos.ks`:

[Kickstart]: https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux/5/html/Installation_Guide/ch-kickstart2.html "Kickstart Installations"

```
root @pxe /var/www/html # mkdir kickstart
root @pxe /var/www/html # vi kickstart/centos.ks
```

I am definitely no expert with these files but whenever you complete a CentOS installation, the installer drops such a kickstart file of the performed setup into root's home: `/root/anaconda-ks.cfg`. That is what I started with before tidying it up a little and ending up with this:

```bash
# perform automated installation in textmode
install
text
url --url="http://pxe/mirror/centos/7.3.1611/x86_64"

# language and keyboard
lang en_GB.UTF-8
keyboard --vckeymap=de --xlayouts='de'

# timezone and network settings
timezone Europe/Berlin --isUtc
services --enabled="chronyd"
network  --bootproto=dhcp --device=ens192 --ipv6=auto --activate

# account security
auth --enableshadow --passalgo=sha512
rootpw --iscrypted $6$6O.YX3JTEF30kWX3$UVE1dc4VxNLa3ie5rhh2F2C8wmK05RTQ/k2z5KhEvwRMQcDIyGrakzYewwNzxudFxA2DHWpnAEbEWbAXU64xy.

# disk partitioning
ignoredisk --only-use=sda
bootloader --append=" crashkernel=auto" --location=mbr --boot-drive=sda
autopart --type=lvm
clearpart --none --initlabel

# reboot when finished
reboot

# installed packages
%packages
@^minimal
@core
chrony
kexec-tools
%end

# enable kernel dumps
%addon com_redhat_kdump --enable --reserve-mb='auto'
%end

```

A few things to note here:

* you will most certainly want to adjust your localization settings, like language, keyboard layout and timezone
* check the network configuration too, especially the device
* the disk is simply automatically partitioned! careful with any existing partitions or special requirements
* the root password hash corresponds to a password of literally just `password`! you might want to change this too

### 2.6.1 password hash

There's a helpful [answer on stackexchange.com](http://unix.stackexchange.com/a/76337), that describes how to create these password hashes on the commandline. Some tutorials simply use openssl and set the algorithm to `md5`, because that's the only one that openssl can generate. Please don't do that. Here's a python one-liner to generate you own salted SHA512 hash:

`python -c 'import crypt,getpass; print(crypt.crypt(getpass.getpass(), crypt.mksalt(crypt.METHOD_SHA512)))'`

### 2.6.2 mirror url

You could skip the next step of creating a local CentOS mirror and simply use an existing mirror on the internet. That would work but that would actually be worse than simply using netboot.xyz. Helpful for debugging purposes though.


## 2.7 create a local mirror

In order for you to really profit from this local installation, you'll need to create a mirror of the CentOS installation directory. Again, there is a nice HowTo over at the [CentOS wiki].

The easiest possibility is to just rsync a subdirectory from a mirror, as you don't need a full mirror unless you want to be able to install every single version.

I automated both the synchronization of the kernel images and the specific mirror in a script:

```bash
#!/usr/bin/env sh

# transfer settings
sync() {
  rsync \
    --archive \
    --hard-links \
    --delete \
    --compress \
    --no-motd \
    --progress \
    "$1" "$2"
};

# version and architecture
version="7.3.1611"
architecture="x86_64"
release="centos/$version/$architecture"

# kernel directory and local mirror
images="/var/lib/tftpboot/images/$release"
httpd="/var/www/html/mirror/$release"

# upstream mirror (from: https://www.centos.org/download/mirrors/)
mirror="rsync://mirror.de.leaseweb.net/centos/"
upstream="$mirror/$version/os/$architecture"

# sync pxeimages
mkdir -p "$images"
sync "$upstream/images/pxeboot/" "$images/"

# sync local mirror
mkdir -p "$httpd"
sync "$upstream/" "$httpd/"
```

The last command mirrors the installation files for the current latest release at `/var/www/html/mirror/centos/7.3.1611/x86_64/`. This enables us to easily serve the files via http in a moment.

[CentOS wiki]: https://wiki.centos.org/HowTos/CreateLocalMirror "Create a Local Mirror"


## 2.8 enable services

As a last step we need to enable both the `tftp-server` as well as the `httpd` daemon. Enable and start both services in one command with systemd:

```
root @pxe ~ # systemctl enable --now tftp.socket httpd.service 
Created symlink from /etc/systemd/system/sockets.target.wants/tftp.socket to /usr/lib/systemd/system/tftp.socket.
Created symlink from /etc/systemd/system/multi-user.target.wants/httpd.service to /usr/lib/systemd/system/httpd.service.
```

Finally, allow incoming connections to both services:

```
root @pxe ~ # firewall-cmd --permanent --add-service=tftp --add-service=http
success
root @pxe ~ # firewall-cmd --reload
success
```

# 3 success

If all goes well and you fire up a new PXE-capable machine in this network, you should be greeted with the PXE menu:

![](/content/images/2017/03/pxe_menu.png)

And if you select the second option, a fresh copy of CentOS should automatically install:

![](/content/images/2017/03/pxe_install.png)

Cheers.
