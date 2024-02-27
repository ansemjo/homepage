---
title: OpenWRT
weight: 10
---

# OpenWRT

## [Image Builder](https://openwrt.org/docs/guide-user/additional-software/imagebuilder)

{{< hint info >}}
### Update
I wrote [openwrtbuilder](https://github.com/ansemjo/openwrtbuilder) to automate
these steps for arbitrary configurations, so I can quickly build a new custom firmware.
{{< /hint >}}

> The Image Builder (previously called the Image Generator) is a pre-compiled environment
> suitable for creating custom images without the need for compiling them from source.
> It downloads pre-compiled packages and integrates them in a single flashable image.

Look for the `openwrt-imagebuilder-<target>-<type>.Linux-x86_64.tar.xz` in the
firmware image folder for your device. Download and extract it somewhere.

Get a list of available profiles with `make info`. For my TP-Link Archer C7 v2:

* imagebuilder: [openwrt-imagebuilder-ar71xx-generic.Linux-x86_64.tar.xz](https://downloads.openwrt.org/snapshots/targets/ar71xx/generic/openwrt-imagebuilder-ar71xx-generic.Linux-x86_64.tar.xz)
* profile: `archer-c7-v2`

You can include extra packages by configuring `PACKAGES=`.

    make image PROFILE="archer-c7-v2" PACKAGES="-ppp -ppp-mod-pppoe luci-ssl wireguard"

The result will be stored in `./bin/targets/<target>/<type>/`.

