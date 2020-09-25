---
title: KVM on Alpine Linux
weight: 70
---

# KVM on Alpine

Installing a KVM hypervisor with absolutely minimal footprint:

## Install Alpine

Install Alpine Linux by booting from ISO or via `netboot` and running `setup-alpine`, choosing `sys`
as the disktype.

## Packages

Install KVM packages:

    apk add qemu-system-x86_64 libvirt libvirt-daemon dbus polkit qemu-img

## Load Modules

Reboot or just load necessary kernel modules:

    modprobe kvm-intel br_netfilter

{{< hint info >}}
`br_netfilter` is required for the network bridge below.
{{< /hint >}}

## Bridge Interface

Add a bridge configuration in `/etc/network/interfaces`:

```
auto lo
iface lo inet loopback

auto br0
iface br0 inet dhcp
	pre-up modprobe br_netfilter
	pre-up echo 0 > /proc/sys/net/bridge/bridge-nf-call-arptables
	pre-up echo 0 > /proc/sys/net/bridge/bridge-nf-call-iptables
	pre-up echo 0 > /proc/sys/net/bridge/bridge-nf-call-ip6tables
	bridge_ports eth0
```
