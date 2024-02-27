---
title: usbarmory
weight: 10
---

# usbarmory

![](https://raw.githubusercontent.com/wiki/f-secure-foundry/usbarmory/images/armory-mark-one.png)

> The USB armory from Inverse Path is an open source hardware design, implementing a flash drive sized computer.
>
> [USB armory on github.com](https://github.com/f-secure-foundry/usbarmory "GitHub repository")

These scripts and notes were taken for their Mk I release.


## LED

The onboard LED can be controlled via `/sys/class/leds/LED/`. There's a couple of automatic trigger modules
that can be loaded in the kernel. Alternatively its brightness can be controlled manually.

### Automatic Triggers

Enable either `cpu0` or `mmc0` triggers by writing the respective string into `/sys/class/leds/LED/trigger`.
The trigger names should be self-descriptory: CPU activity and SD card activity.

### Heartbeat

The heartbeat module may need to be loaded first:

```
modprobe ledtrig_heartbeat
```

Then enable it by writing `heartbeat` to `/sys/class/leds/LED/trigger`, like before.

### Manual

To control the LED manually, first disable any automatic triggers:

```
echo none > /sys/class/leds/LED/trigger
```

Now you can control the LED by writing `0` or `1` to `/sys/class/leds/LED/brightness`.


## USB Ethernet

A very simple dnsmasq configuration to enable serving DHCP on the USB armory's ethernet interface looks like this:

```
interface=usb0
dhcp-range=10.0.0.2,10.0.0.99,12h
```

There's a few more tricks necessary to ensure that any connected host always gets the same IP assignment,
which could then be used as a gateway for the armory, so it can reach the internet.

To enable routing on the host by providing NAT to the USB armory, use an iptables rule like this:

```
iptables -t nat -A POSTROUTING -s 10.0.0.1/32 -o ethernet -j MASQUERADE
echo 1 > /proc/sys/net/ipv4/ip_forward
```

In order to automate this firewalling, you may use a udev rule:

```
ACTION=="add", SUBSYSTEM=="net", SUBSYSTEMS=="usb", \
  DRIVERS=="cdc_ether", ATTRS{interface}=="CDC Ethernet Control Model (ECM)", \
  NAME="armory", RUN+="/usr/lib/armory/hostinit/init_routing"
ACTION=="remove", ENV{ID_MODEL}=="CDC_Composite_Gadget", \
  ENV{ID_MODEL_ID}=="a4aa", ENV{ID_VENDOR_ID}=="0525", \
  RUN+="/usr/lib/armory/hostinit/init_routing"
```

.. where `init_routing` is a script that handles an environment variable `$ACTION` of either `add` or `remove`.
