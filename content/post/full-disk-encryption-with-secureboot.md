---
title: Full Disk Encryption With SecureBoot
date: 2017-10-08T22:25:40+02:00
draft: true
toc: true
categories:
  - blog
  - technology
  - guide
tags:
  - linux
  - security
  - encryption
  - luks
---

I've been thinking about cleanly reinstalling Linux on my laptop for a while now and move away from Samsung's proprietary full-disk encryption while I do. It always bugged me that the "Self-Encrypting" function was sort of a black-box and even though Lenovo's ATA password implementation mostly seemed to be secure, you also need a [special tool][lenovo-hdd-password] to convert your password if you want to unlock that drive on another computer.

Why not use open-source technologies for encryption? And while I'm at it, make the UEFI on my laptop really mine and install my own SecureBoot keys?

While I don't particularly have a threat model which would require any such measures, the fact that I can do all that with open-source tools at no cost is fascinating to me. Moreover, I feel like I finally understood how SecureBoot works.

# Installation

## Hardware

My laptop is a Lenovo X250 Laptop with a Samsung SSD 850 EVO. Some aspects might be different for your system. But mostly it should apply to all UEFI-based systems.

## Operating System

I will be using Arch Linux and its Wiki for this guide. While there are many distributions, most of which are much more user-friendly, I found Arch to be the most customizable one. Basically, you could probably do all these steps on any Linux-based OS, as long as the partitioning tool during installation allows for sufficient customization.

Many distributions also allow you to tick a box to set up an encrypted system easily. But while the system and user homes are in fact encrypted, the bootloader usually is not. More on that later.

Unsurprisingly, I will also assume an UEFI-based system, as noted above.

## Partitioning

The Arch Wiki provides rough guidelines for many different scenarios. I prefer to use BTRFS as my file system, thus I used the section about [encrypting an entire system with btrfs subvolumes][dmcrypt-btrfs-subvolumes] as an inspiration. This means, that I need two or three partitions:

- *unencrypted* EFI system partition
- *LUKS encrypted* BTRFS root
- *plain encrypted* swap space (optional)

In contrast to the proposal in the wiki I will not be using any bootloader though. Modern Linux kernels support [EFISTUB][arch-efistub] booting, meaning they can be executed directly by the firmware.

# LUKS

# SecureBoot

# Automation

# Links

[Lenovo ThinkPad HDD Password tool][lenovo-hdd-password]
[lenovo-hdd-password]: https://github.com/jethrogb/lenovo-password

[Dealing with Secure Boot, Rod Smith][rod--dealing-with]
[rod--dealing-with]: http://www.rodsbooks.com/efi-bootloaders/secureboot.html

[Encrypting an entire System, BTRFS Subvolumes][arch-btrfs-subvolumes]
[arch-btrfs-subvolumes]: https://wiki.archlinux.org/index.php/Dm-crypt/Encrypting_an_entire_system#Btrfs_subvolumes_with_swap

[Linux EFISTUB][arch-efistub]
[arch-efistub]: https://wiki.archlinux.org/index.php/EFISTUB