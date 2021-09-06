---
title: Raspberry Pi
weight: 10
---

# Raspberry Pi

## Add WiFi AP

{{< hint info >}}
Based on a [forum post by pugbot](https://www.raspberrypi.org/forums/viewtopic.php?p=1355569&sid=80347f0b7eea0a89968f4040c5301e32#p1355569).
{{< /hint >}}

### 1. Update the system ... duh'.

```
apt update && apt upgrade -y
```

### 2. Install necessary software

We need an access-point daemon and a DHCP service for connecting clients:

```
apt install -y hostapd dnsmasq
```

### 3. Create configuration files

{{< hint warning >}}
Do not attempt to edit and interface files as some older guides say. They are not used anymore since `buster`.
{{< /hint >}}

Configure a new static address in `/etc/dhcpcd.conf` and prevent `wpa_supplicant` from messing with the interface:

    interface uap0
      static ip_address=10.56.0.1/24
      nohook wpa_supplicant

Maybe backup the installed `/etc/dnsmasq.conf` config for reference and then configure it as follows:

```cfg
interface=lo,uap0
bind-interfaces
server=192.168.1.1   # upstream dns
#domain-needed       # reject short names?
#bogus-priv          # reject private address spaces?
dhcp-range=10.56.0.2,10.56.0.99,1h
```

Now configure the access-point network in `/etc/hostapd/hostapd.conf`. The channel should match the station network but I found that it is changed automatically anyway to follow the current station.

```cfg
channel=6
ssid=<some-name>
wpa_passphrase=<8-to-64-chars>
interface=uap0
hw_mode=g
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP
driver=nl80211
#wmm_enabled=1
#ht_capab=[HT40][SHORT-GI-20][DSSS_CCK-40]
```

Add the config in the service defaults in `/etc/default/hostapd`:

    DAEMON_CONF="/etc/hostapd/hostapd.conf"

### 4. Startup script

Until now the above configuration is not applied on boot. So you can write yourself a startup script to enable the access point (and add it to `/etc/rc.local` if you want).

```bash
#!/bin/bash
set -x

# redundant stops to make sure services are not running
systemctl stop hostapd.service
systemctl stop dnsmasq.service
systemctl stop dhcpcd.service

# recreate uap0 interface
iw dev uap0 del
iw dev wlan0 interface add uap0 type __ap

# modify iptables for routing of clients
sysctl net.ipv4.ip_forward=1
iptables -t nat -A POSTROUTING -s 10.56.0.0/24 ! -d 10.56.0.0/24 -j MASQUERADE

# bring up uap0 interface .. uncomment line if using dhcpcd.conf doesn't work
#ifconfig uap0 10.56.0.1 netmask 255.255.255.0 broadcast 10.56.0.255
ifconfig uap0 up

# start hostapd
systemctl start hostapd.service
sleep 10

# start the rest
systemctl start dhcpcd.service
sleep 5
systemctl start dnsmasq.service
```

