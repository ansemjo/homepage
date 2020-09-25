---
title: Secure Boot
weight: 10
---

# Secure Boot

These are guides to install your system with your own Secureboot keys and enforce
signed Linux kernels.

## Tools

Some useful tools I wrote for this job:

* [`ansemjo/mkefikeys`](https://github.com/ansemjo/mkefikeys): generate signing keys
* [`ansemjo/mksignkernels`](https://github.com/ansemjo/mksignkernels): bundle and sign kernel images

## Guides

### Arch Linux

My main system is running Arch in this configuration but I haven't done a writeup
for it yet ..

### Fedora

#### Installation

Do a somewhat standard installation on an UEFI system. I used the `Fedora 28 Server netinst` image.

During partitioning, make sure to select at least "custom" partitioning and add a seperate EFI system partition in `/boot/efi`. Tick the boxes to encrypt your `/` and any `swap` partitions you might create. Technically, a seperate `/boot` partition is not required with the bundled kernels we are going to use but Anaconda complains otherwise and you will not be able to boot the system after installation. You could probably do all these steps from within a live rescue system but I haven't tried that route yet.

#### Required Packages

You will need to additionally (after a minimal setup) install:
* git
* make
* binutils
* sbsigntools

Then clone and install the above two tools: `mkefikeys` and `mksignkernels`.

	cd /tmp/...
	git clone https://github.com/ansemjo/mkefikeys
	git clone https://github.com/ansemjo/mksignkernels
	(cd mkefikeys && make -f install.mk install)
	(cd mksignkernels && make -f install.mk install)
    
#### Signing keys

Create a set of signing keys in `/etc/efikeys`:

	mkdir /etc/efikeys && cd /etc/efikeys
	mkefikeys certs der
    
The `der` target is required to output DER-encoded certificates in case you need to install those in your firmware. This is the case for OVMF, i.e. KVM machines. My Thinkpad needs authenticated "efi signature lists" .. generate them with `mkefikeys auth`.

Copy files required for installation to the unencrypted ESP:

	cp /etc/efikeys/*.cer /boot/efi

Installing them in your firmware is out of the scope of this entry.

{{< hint danger >}}
Do not enable Secureboot yet. We haven't signed anything yet and your system will fail to boot.
{{< /hint >}}

#### Sign your kernels

Now we need to sign the kernels. Simply running `mksignkernels` will probably fail with a not-so-useful error message because something will be missing. On virtual machines the Intel microcode is usually not useful and thus not present. Add an empty `MICROCODE = ` line in `/etc/mksignkernels.mk`.

Additionally, you'll want to use the same kernel commandline as is used for your  default installation. You can get the commandline of currently running kernel from `cat /proc/cmdline`.

```make
# blablabla
# ------- custom targets --------

MICROCODE = 
CMDLINE = whatever_your_default_kernel_uses
```
    
Next, we need to create the output directory:

    mkdir /boot/efi/EFI/Linux
    
Running `mksignkernels` should succeed now. Otherwise check all the prerequisites:

* EFI stub in `/usr/lib/systemd/boot/efi/linuxx64.efi.stub`
* Signing keys in `/etc/efikeys/DatabaseKey.{key,crt}`
* Kernel in `/boot/vmlinuz-*`
* Initramfs in corresponding `/boot/initramfs-*.img`

#### Use systemd-boot

Check that `systemd-boot` is installed and you are indeed running UEFI, yadda yadda ..

	bootctl status
    
To install it as the default bootloader, simply issue:

	bootctl install
    
To enable the selection prompt uncomment the `timeout` in `/boot/efi/loader/loader.conf`. Otherwise it directly boots the default kernel.

#### Sign your bootloader

Before you reboot and attempt to enable Secureboot now, you need to sign the bootloader itself:


	mksignkernels sign SIGN=/boot/efi/systemd/systemd-bootx64.efi
	mksignkernels sign SIGN=/boot/efi/BOOT/BOOTX64.EFI
    
I actually do not know if both are necessary, I just signed both just in case.

#### Reboot

When you reboot you should see systemd-boot's selection prompt instead of GRUB. If that is the case, there should be an option to "Reboot into Firmware Setup".
Do that and enable Secureboot now.

If all went fine you should be able to normally boot your system now. Starting your machine via GRUB should fail though, as neither GRUB nor any of the kernels it tries to boot are signed.
