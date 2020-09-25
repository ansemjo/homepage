---
title: 389 Directory Server on Centos 7
date: 2017-02-10
modified: 2017-06-29
draft: true
toc: true
tags:
  - database
  - linux
---

_This is an evolving article. I will probably add more chapters as I complete further steps._

___Update:___ _Nevermind. Actually, learning FreeIPA is *very* well worth your time!_

# The 389 Directory Server

Recently, I set up a new machine as an ESXi host and I am currently experimenting with a bunch of virtual machines.

As a part of this new environment, I wanted to set up centralized identity management and a proper certificate authority. I looked at [FreeIPA](https://www.freeipa.org/), which was easily installed in another Centos VM, but found it to be rather confusing - possibly because of the sheer amount of functionality.

After that I looked at the seperate parts of FreeIPA and decided to try them one by one. The first one I looked at was [Dogtag](http://pki.fedoraproject.org/), which installs nicely under Fedora and which I found to be rather intuitive quickly. That was a test setup though, so I decided to _do it right_&trade;.

One of the center pieces holding everything in FreeIPA together is a directory server. The server of their choosing is [389-ds](http://directory.fedoraproject.org/), which seems to be deployed in many enterprise environments:

> The enterprise-class Open Source LDAP server for Linux. It is hardened by real-world use, is full-featured, supports multi-master replication, and already handles many of the largest LDAP deployments in the world. The 389 Directory Server can be downloaded for free, and set up in less than an hour.
- http://directory.fedoraproject.org/

Sound good, eh? I am using a guide over at [unixmen.com](https://www.unixmen.com/install-and-configure-ldap-server-in-centos-7/) as a base and simply document the actual steps I took.

# Setup the Machines

## Virtual Machines

I am running ESXi 6.5 with a free license and provisioned two virtual machines with 2 vCPUs, 2048 MB of RAM and a default thin-provisioned 16 GB disk on a SSD datastore for my directory servers. Since this is a home setup, it is probably already over-provisioned ..

## Operating System

Both machines are installed with a [Centos 7](https://www.centos.org/download/ "Download CentOS 7") minimal installation:
```
• root @directory-a ~ # cat /etc/centos-release
CentOS Linux release 7.3.1611 (Core) 
```

## Hostnames

I configured the hostnames during the Centos installation procedure and I have another VM with OPNsense serving a local management network, complete with some static DHCP leases and local DNS resolution. Thus I did not further touch the `/etc/hosts` file, as pinging both short and full domain names works fine.

I will assume `management.tld` as a domain for the rest of this post. Therefore the hostnames for both machines would be:

* Master: `directory-a.management.tld`
* Replica: `directory-b.management.tld`

## Firewall

I will defer this step for later, to decide which ports are actually needed. I.e. I might use TLS, which would use a port different from `389`. For now, all I need is `ssh` access, which is already enabled by default.

## Limits

First we should edit a few system limits, as the installer will complain about those otherwise. Basically we lower the TCP keepalive duration and increase the limit on open file descriptors. See the linked guide above for details.

Here are snippets of code to do all the edits:

```bash
cat <<EOF >> /etc/sysctl.d/10-limits.conf
net.ipv4.tcp_keepalive_time = 300
net.ipv4.ip_local_port_range = 1024 65000
fs.file-max = 64000
EOF
cat <<EOF >> /etc/security/limits.conf 
*               soft     nofile          8192   
*               hard     nofile          8192
EOF
echo 'ulimit -n 8192' >> /etc/profile
echo 'session  required  /lib64/security/pam_limits.so' >> /etc/pam.d/login`
```

Afterwards, reboot the server to apply those settings.

## User

It is good practice to use an unpriviledged account for daemons which do not require superuser permissions. The `389-ds` packages created a user and group during installation in my case, so there is no need to create one manually. Also do not set a password on that account. You probably don't want to login with it anyway and not having a password makes it _more_ secure by disallowing logins enitrely.

## Packages

To install packages, all you need is the EPEL repository. Enable it with:

```bash
yum install --assumeyes epel-release
```

Afterwards we can install all the packages at once with a little shell expansion magic:

```bash
yum install 389-{ds-{base,console},admin{,util},{admin,}console} idm-console-framework --asumeyes
```

.. which expands to these packages:

* 389-ds-base
* 389-ds-console
* 389-admin
* 389-adminutil
* 389-adminconsole
* 389-console
* idm-console-framework

_To be honest, you probably don't need all of those, as some of those are admin utilities but they don't hurt either I guess._

# Installation

Basically you run `setup-ds-admin.pl` on the first host and then `setup-ds.pl` on every other host. The installation process is pretty self-explanatory.
