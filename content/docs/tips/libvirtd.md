---
title: libvirtd
weight: 10
---

# libvirtd


## SR-IOV Virtual Interfaces

I've experimented with the SR-IOV functionality of my Supermicro X10SDV's network
interfaces a little.
Virtual machines using these virtual function interfaces do not reach the same
speeds between different virtual machines on the same hypervisor as is the case
with `macvtap` networking. In return however, host to guest networking just works
without any strage workarounds.


### Enable

First you'll need to enable this function in the BIOS and in the kernel. I am not
sure if the following kernel arguments are only necessary for classic PCI-E passthrough
or for SR-IOV in general. But I've added these to `/etc/defaults/grub`:

    intel_iommu=on iommu=pt

You can now add virtual functions by writing a number to
`/sys/class/net/<interface>/device/sriov_numvfs`.


### Tame NetworkManager

By default, NetworkManager will try to manage each new virtual function automatically
so you will receive lots and lots of IP adresses on interfaces like `eno4v1` etc. In order
to prevent that, you can add a `[keyfile]` section in `/etc/NetworkManager/NetworkManager.conf`:

```ini
...
[keyfile]
# prevent networkmanager on sr-iov virtual functions
unmanaged-devices=interface-name:eno*v*
...
```

Alternatively, you can prevent "driver probing" on the new virtual functions, so they
will not appear as network interfaces to the host at all. This needs to be done before
adding virtual functions, obviously.

```sh
echo 0 > /sys/class/net/<interface>/device/sriov_drivers_autoprobe
```


### Add on Startup

[nomethod]: https://lists.freedesktop.org/archives/systemd-devel/2015-January/027454.html

Somehow, [there does not appear to be a method to add functions on startup][nomethod]
besides manually scripting writes to the sysfs. Since `rc.local` is not reliable in times
of systemd -- it especially lacks any ordering guarantees -- I wrote a simple *oneshot*
service file `interface-vf@.service`:

```systemd
[Unit]
Description = initialize sr-iov virtual functions on %i interface
After = systemd-udevd.service

[Service]
Type = oneshot
RemainAfterExit = true

# disable driver probing and add virtual functions
ExecStart = sh -c "echo  0 >/sys/class/net/%i/device/sriov_drivers_autoprobe"
ExecStart = sh -c "echo 10 >/sys/class/net/%i/device/sriov_numvfs"

# remove virtual functions
ExecStop  = sh -c "echo  0 >/sys/class/net/%i/device/sriov_numvfs"
```

This service can be required by `libvirtd.service` with an override, so the virtual
functions are created before starting the virtual machine manager.



## Shared Filesystems with `virtio-fs`

After moving away from an ESXi hypervisor to a Linux box with KVM, I looked for
possibilities of sharing parts of the host filesystem with the guest machines.
[`virtio-fs`](https://virtio-fs.gitlab.io/) is a relatively new approach, which replaces
shared folders based on the `9p` filesystem. Instead of using network filesystem
semantics over a virtualized pipe, `virtio-fs` uses shared memory directly.

In order to use it, you need very recent versions of QEMU and libvirt. Neither CentOS 8
nor Ubuntu 20.04 provide sufficiently recent packages at the moment. However, there is
a PPA for Ubuntu at [ppa:jacob/virtualisation](https://launchpad.net/~jacob/+archive/ubuntu/virtualisation).

An upstream guide is [available on libvirt.org](https://libvirt.org/kbase/virtiofs.html).

The XML snippet required in virt-manager for this new filesystem share looks like this:

```xml
<filesystem type="mount" accessmode="passthrough">
  <driver type="virtiofs"/>
  <source dir="/path/to/shared/directory"/>
  <target dir="hostshare"/>
</filesystem>
```

You also need to add a NUMA node for the shared memory region. I think there is a better /
more automatic way. But this works for now:

```xml
<cpu mode="custom" match="exact" check="none">
  <model fallback="forbid">qemu64</model>
  <topology sockets="1" dies="1" cores="2" threads="1"/>
  <numa>
    <cell id="0" cpus="0-1" memory="2097152" unit="KiB" memAccess="shared"/>
  </numa>
</cpu>
```

Inside the virtual machine, you can mount the share with:

```sh
mount -t virtiofs hostshare /mnt
```
