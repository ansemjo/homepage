---
title: Serial Devices
weight: 10
---

# Serial

## `picocom` Autocompletion

Here is a simple config I put in my `.bashrc` to enable useful defaults and
device autocompletion for `picocom`:

```sh
# picocom config for usb serial
if iscommand picocom; then
  alias picocom='picocom --baud 115200 --omap crcrlf,delbs --quiet'
  _picocom_serials() { COMPREPLY=($(compgen -W "$(ls /dev/{ttyUSB,serial/by-id/}* 2>/dev/null)" "${COMP_WORDS[1]}")); }
  complete -F _picocom_serials picocom
fi
```


## `udev` Rule to Create Symbolic Links for Devices

As soon as you regularly have more than one USB serial adapter,
for example a Startech RS232 cable and a Sparkfun FTDI breakout board ...,
the `/dev/ttyUSB*` naming gets frustrating. There's symlinks in
`/dev/serial/by-id/*` which are stable. But do you really want to remember the
serial yourself?

A [page in the siduction wiki](https://wiki.siduction.de/index.php?title=Symlink_zur_eindeutigen_Erkennung_mittels_udev-Regel)
describes how you can create symlinks with `udev` rules.

Find your device's attributes with `udevadm info --attribute-walk --name=/dev/ttyUSB*`.
For example my Startech RS232 adapter lists:

```
/* ... */

  looking at device '[...]/ttyUSB0/tty/ttyUSB0':
    KERNEL=="ttyUSB0"
    SUBSYSTEM=="tty"
    DRIVER==""

/* ... */

  looking at parent device '/devices/pci0000:00/0000:00:14.0/usb1/1-3/1-3.3':
    KERNELS=="1-3.3"
    SUBSYSTEMS=="usb"
    DRIVERS=="usb"
    /* ... */
    ATTRS{idProduct}=="6001"
    ATTRS{idVendor}=="0403"
    /* ... */
    ATTRS{manufacturer}=="FTDI"
    ATTRS{product}=="FT232R USB UART"
    ATTRS{serial}=="AI05A7NY"
    /* ... */

/* ... */
```

Create a file in `/etc/udev/rules.d/` named like `20-serial-mydev.rules` with
the following content to create a custom symlink whenever the matching device
is attached:

```udev
# create an alias for the startech rs232 serial cable
SUBSYSTEM=="tty", ATTRS{idVendor}=="0403", ATTRS{idProduct}=="6001", ATTRS{serial}=="AI05A7NY", SYMLINK+="ttyUSBStartechRS232"
```

Use `picocom` with the new alias:

```
picocom /dev/ttyUSBStartechRS232
```
