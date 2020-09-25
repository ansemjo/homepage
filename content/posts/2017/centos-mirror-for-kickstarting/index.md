---
title: Create a CentOS mirror for Kickstarting
date: 2017-06-29
draft: false
toc: true
tags:
  - linux
  - homelab
---

_This is an update over my [earlier post] about PXE booting. I've learned a few more things and refined some rough edges._<br>

{{< hint info >}}
Update: By now I've learned even more. See [homelab/bootstrap]({{< ref "/docs/homelab/bootstrap.md" >}}) for an updated guide.
{{< /hint >}}

[earlier post]: {{< ref "/posts/2017/local-pxe-boot/index.md" >}}


My Motivation is similar to the last post: I started building my homelab with virtual machines. Most of them are based on a minimal CentOS 7 installation, and as such I have a lot of very similar systems. Yes, I could probably use containers to great effect. But I prefer the separation/isolation that I get from virtual machines on ESXi.

<!--more-->

Since I don't want to spend my time clicking through the installation wizard each time and repeating all those steps, I use kickstart. And since all those machines need the same rpm packages, I might aswell configure a local mirror for all those updates.

The next logical step up would be a provisioning system like [Katello / the Foreman] but I haven't gotten around to properly implementing that yet.

[Katello / the Foreman]: https://theforeman.org/

## 1. Draft

- prepare a minimal CentOS 7.3 installation
- plan your harddrive space! (~25 GB per architecture/version combination)
- you need to be able to set DHCP options for the network
- install & configure a tftp and a http server
- download packages from a mirror
- create kickstart configuration

## 2. Setup

I don't think the first few steps need any explanation. Make sure you provision enough harddrive space and configure your network, either through a static IP address or through a DHCP reservation. Also make sure you know how to configure DHCP options in your router / DHCP server. I will be showing the settings in LEDE later.

### 2.1 Install server packages

We need a TFTP server and some Syslinux packages. Those two enable booting kernels over the network. The CentOS mirrors provide appropriate images, which we will be using later. Furthermore, a simple HTTP server is required to serve our kickstart configuration and all the packages later.

Install all required packages with:
```
# yum install -y tftp-server syslinux-tftpboot httpd
```

This creates and populates the directories `/var/lib/tftpboot` and `/var/www/html`. The `tftp-server` serves Syslinux' files from the former by default and Apache `httpd` will serve files from the latter.

_Hint: take a look in `/etc/httpd/conf.d/welcome.conf` to disable the default Welcome page._

### 2.2 Synchronize mirror

Now would be a good time to select a fast mirror from the [mirrorlist](https://www.centos.org/download/mirrors/ List of CentOS mirrors), which also supports the `rsync` protocol.

After you have run any `yum` command, which populated the cache, there will be a list of 'timed hosts', indicating mirrors with good performance. The smaller the number, the better:

```
$ cat /var/cache/yum/x86_64/7/timedhosts.txt | awk '{print $2" "$1}' | sort
```

We'll want to synchronize at least the `os` and `updates` trees for a given version.

Since this is a very repetitive task, I have developed this little script to automate the creation of directory structures locally and incrementally synchronize the repositories with `rsync`:

```bash
#!/usr/bin/env bash

# synchronize files
# $1 source, $2 destination, $3 label
sync() {
  printf '\e[1mSynchronizing %s...\e[0m\n' "${3/%/ }";
  printf '\e[1m╭╴src╶─ \e[0m%s\n\e[1m╰╴dst╶→ \e[0m%s\n' "$1" "$2";
  mkdir -p "$2";
  rsync \
    --archive --hard-links --delete \
    --compress --no-motd --progress \
    "$1" "$2";
  printf '\n';
};

# remote and local mirror
remote="rsync://mirror.de.leaseweb.net"
mirror="/var/www/html/mirror"

# sync packages
for version in '7.3.1611'; do
  for repo in 'os' 'updates'; do
    
    sync {"$remote","$mirror"}"/centos/$version/$repo/x86_64/" "$version/$repo";
  
  done;
done;
```

Replace the `mirror="..."` assignment with your chosen mirror. You might want to create a simple `systemd.timer` in order to synchronize the repositories every night. But I'll leave that as an exercise for you.

Running the script will then create repositories under `/var/www/html/mirror/centos/7.3.1611/{os,updates}/x86_64/`.

### 2.3 Configure TFTP server

Point your DHCP clients to this mirror by specifying (at least) [options](http://www.networksorcery.com/enp/protocol/bootp/options.htm List of DHCP options) 67 and 150. I am using a router flashed with LEDE, so the options can be configured in a single field under `Network > DHCP and DNS > TFTP Settings`:

```
Network boot image:
gpxelinux.0,mirror.lab.example.com,192.168.1.10
```

![](/content/images/2017/06/Screenshot-from-2017-06-29-23-33-20.png)

Use `gpxelinux.0` here to be able to use `http://` links to your kernel and initrd in your pxelinux configuration and avoids the need to copy the `pxeboot` images into the TFTP root seperately. Speaking of configuration ..

Pxelinux expects to find its initial configuration in `$tftproot/pxelinux.cfg/default`. Thus, create the directory `/var/lib/tftpboot/pxelinux.cfg` and create a configuration in the file `default`. A very minimalistic file is sufficient for a single kickstart target:

```bash
#// general
default     menu.c32
kbdmap      de-latin1.ktl
prompt      0
timeout     600
ontimeout   reboot

#// text
menu title      mirror.lab.example.com
menu autoboot   Rebooting system in # seconds ...


#// menu entries

label       reboot
menu label  ^Reboot system

  kernel      reboot.c32
  append      --warm


label       kickstart-centos-7.3.1611
menu label  Kickstart: ^CentOS 7.3.1611

  kernel      http://mirror.lab.example.com/mirror/centos/7.3.1611/os/x86_64/images/pxeboot/vmlinuz
  initrd      http://mirror.lab.example.com/mirror/centos/7.3.1611/os/x86_64/images/pxeboot/initrd.img
  append      ramdisk_size=262144 ks=http://mirror.lab.example.com/kickstart/centos.ks
```

Adjust `kbdmap` and the hostname in `menu title`, `kernel`, `initrd` and `append` lines to fit your network. If you left out the `ks=...` assignment in the `append`, you would boot into a minimal CentOS installer by default. To further automate the process we need to create this kickstart configuration next.

### 2.4 Kickstart configuration

Chances are, the Anaconda installer left a kickstart file in `/root/anaconda-ks.cfg`. If you used that file, the installer would create an identical installation to your mirror server.

I used mine as a template, cleaned it up and consulted the [documentation](https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux/7/html/Installation_Guide/sect-kickstart-syntax.html) for additional commands and syntax. This is what I came up with:

```bash
#// installation mode and source
install
text
reboot
url --url http://mirror.lab.example.com/mirror/centos/7.3.1611/os/x86_64
repo --name=mirror.base --baseurl=http://mirror.lab.example.com/mirror/centos/7.3.1611/os/x86_64 --install --cost=100
repo --name=mirror.updates --baseurl=http://mirror.lab.example.com/mirror/centos/7.3.1611/updates/x86_64 --install --cost=100

#// language
lang en_GB.UTF-8
keyboard --vckeymap=de --xlayouts=de

#// time and network
%include /tmp/network.kick
timezone Europe/Berlin --utc

#// root authentication
auth --enableshadow --passalgo=sha512
rootpw --iscrypted $6$kXBCG...98MeGIR8AEpLRfc0

#// partitioning
ignoredisk --only-use=sda
bootloader --location=mbr --boot-drive=sda
autopart --type=btrfs
clearpart --none --initlabel

#// installed packages and services
%packages
@^minimal
@core
ntp
rng-tools
bash-completion
vim
git
%end
services --enabled=ntpd,rngd

#// pre-installation scripts
%pre

echo "network --device=ens160 --ipv6=auto --hostname=kick-$(< /dev/urandom tr -dc '0-9' | head -c4) --activate" > /tmp/network.kick

%end

#// post-installation scripts
%post

# add gpgkey in local repo definitions
tee -a /etc/yum.repos.d/mirror.{base,updates}.repo <<EOF
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7
EOF

# root pubkey auth
mkdir -m0700 /root/.ssh/
cat <<EOF >/root/.ssh/authorized_keys
ssh-rsa AAAAB3N...
EOF
chmod 0600 /root/.ssh/authorized_keys
restorecon -R /root/.ssh/

%end
```

This is placed in `/var/www/html/kickstart/centos.ks`, so anaconda can find it later. A few highlights:

- the mirrored repositories are used for the installation and in the installed system; i.e. any `yum` operations will prefer downloading from your local mirror first
- a pre-installation script creates a configuration for a random hostname like `kick-####`; if your DHCP server adds dynamic DNS entries, you can reach the installed system by hostname more easily
- the first disk is auto-partitioned with a BTRFS scheme
- a random number generator daemon is installed by default to remedy a lack of entropy in virtual machines
- a public SSH key is configured for `root`

This [answer on stackexchange.com](http://unix.stackexchange.com/a/76337) describes how you can create your own salted password hash for the `rootpw --iscrypted ..` line above. This oneliner creates the required SHA512 hash:

```bash
python -c'import crypt as c,getpass as p; print(c.crypt(p.getpass(),c.mksalt(c.METHOD_SHA512)))'
```
### 2.5 Enable services

Finally, enable the `tftp-server` and `httpd` services and open firewall ports:

```bash
systemctl enable --now tftp.socket httpd.service
firewall-cmd --permanent --add-service={tftp,http}
firewall-cmd --reload
```

### 2.6 Booting

You should now be greeted with a Pxelinux menu upon booting a new machine:

![](/content/images/2017/03/pxe_menu.png)

And if you select the second option, a fresh copy of CentOS should automatically be installed:

![](/content/images/2017/03/pxe_install.png)

----

I hope this tutorial was somewhat helpful to you. I have created a [repository](https://github.com/ansemjo/kickstart-mirror) on GitHub to track some of the relevant files and additional post-installation scripts. Take a look and leave a comment if you like!

Cheers.
