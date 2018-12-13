---
title: Installing Freeipa
date: 2017-03-10
draft: true
toc: true
tags:
  - linux
  - domain
---

* Quick and dirty draft ...

* fresh CentOS 7.3 install
* make sure it has a resolvable DNS name
* make sure it has some entropy daemon (haveged or rngd)
* `yum install -y ipa-server*`

<!--more-->

## master

* install:

```
ipa-server-install --setup-dns --mkhomedir --ssh-trust-dns --subject='C=DE, ST=Hamburg, L=Hamburg, O=semjonov.de, OU=Rechenzentrum' --ca-signing-algorithm=SHA512withRSA --forwarder=213.73.91.35 --forwarder=84.200.69.80 --domain=rz.semjonov.de --ds-password="$manager" --admin-password="$admin"
```

* open firewall:

```
firewall-cmd --add-service={freeipa-{ldap{,s},replication},dns} --permanent
firewall-cmd --reload
```

* curl ca certificate and install in browsers
```
curl http://ipa01.lab.semjonov.de/ipa/config/ca.crt -O
```

## replicas

* join the system to domain (e.g. the `ipa-easy-join` script installed during kickstart)
* open firewall as above
* install `ipa-server*` as above
* `kinit admin` to receive credentials
* install replica:

```
ipa-replica-install --mkhomedir --ssh-trust-dns --setup-dns --setup-ca --forwarder=213.73.91.35 --forwarder=84.200.69.80
```h
* 
* 
* 
