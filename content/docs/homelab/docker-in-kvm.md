---
title: Docker in QEMU/KVM
weight: 90
---

# Docker in QEMU/KVM

Some applications may require a properly isolated Docker engine where users of the API have every freedom but when they must not be able to compromise the host security. Since access to the Docker socket is equivalent to being `root` ([or worse](https://opensource.com/article/18/10/podman-more-secure-way-run-containers)) we must preferably run the engine on a seperate machine.

Long story short: virtualization with QEMU/KVM provides all the required isolation and CoreOS is easy to deploy and bundles Docker by default.

The following steps are designed for a CentOS 7 hypervisor.

## Prerequisites

First of all, we need to prepare our hypervisor, so install QEMU and libvirt.

    yum install qemu-kvm libvirt virt-install
    modprobe kvm
    systemctl enable --now libvirtd

Make sure you have hardware virtualization available. If you're running in a virtual machine already you may need to enable passthrough explicitly. On an Intel machine you should have a module `kvm_intel` loaded as well.

{{< hint info >}}
We are going to use `virt-install` as well, however the version in EPEL is not recent enough to use the `kernel=` and`initrd=` arguments with `--location`. Thus prefer a local manager and append `--connect qemu+ssh://root@hypervisor/system` to `virsh` or `virt-install` commands.
{{< /hint >}}

## Boot a CoreOS Virtual Machine

There is [a guide](https://coreos.com/os/docs/latest/booting-with-libvirt.html) on how to boot CoreOS with `libvirt` but I prefer to perform a clean installation to disk. Therefore we need to boot CoreOS to RAM and deploy using an Ignition configuration. Preferably, this is done with the provided PXE images.

Depending on your version of `virt-install` there are different installation methods available: in the terminal via text console or remotely over VNC.

### Via Text Console (modern `virt-install`)

If you don't want to bother with VNC connections and would prefer to install via a text console on the hypervisor itself, you can download and run the CoreOS `vmlinuz` and `cpio.gz` directly by specifying them in the `--location` argument:

```sh
virt-install --name core --memory 2048 --vcpus 2 \
  --accelerate --rng /dev/urandom --autostart --graphics none \
  --disk size=20,bus=virtio --os-variant virtio26 \
  --location "https://stable.release.core-os.net/amd64-usr/current/,kernel=coreos_production_pxe.vmlinuz,initrd=coreos_production_pxe_image.cpio.gz" \
  --extra-args "coreos.autologin console=ttyS0"
```

If you prefer to download and verify [an ISO](https://stable.release.core-os.net/amd64-usr/current/coreos_production_iso_image.iso) locally instead, you can substitute the `--location` argument:

```sh
  --location ../path/to/coreos.iso,kernel=/coreos/vmlinuz,initrd=/coreos/cpio.gz \
```

This is useful when you're doing many installs to avoid the repeated downloads.

{{< hint info >}}
You can find files inside an ISO with `isoinfo -Jf -i /path/to/disc.iso`.
{{< /hint >}}

### Via Text Console (older `virt-install`)

Older versions of `virt-install` -- among them version 1.5.0 that is shipped with CentOS 7 -- do not support the `--location ...,kernel=...,initrd=...` syntax and complain about unreachable URLs. In this case you can download the files and fake a Debain installation directory that is autodetected simply by passing the directory path to `virt-install`.

Download and verify the PXE image as per the CoreOS docs:

```sh
cd /var/lib/libvirt/images
mkdir -p coreos && cd coreos
stable=https://stable.release.core-os.net/amd64-usr/current/
wget $stable/coreos_production_pxe.vmlinuz
wget $stable/coreos_production_pxe.vmlinuz.sig
wget $stable/coreos_production_pxe_image.cpio.gz
wget $stable/coreos_production_pxe_image.cpio.gz.sig
gpg --verify coreos_production_pxe.vmlinuz.sig
gpg --verify coreos_production_pxe_image.cpio.gz.sig
```

Create a fake `MANIFEST` and a directory structure that mimics a Debian netboot installer:

```sh
mkdir -p amd64/current/images/netboot/debian-installer/amd64/
echo debian-installer > amd64/current/images/MANIFEST
ln -sr coreos_production_pxe.vmlinuz amd64/current/images/netboot/debian-installer/amd64/linux
ln -sr coreos_production_pxe_image.cpio.gz amd64/current/images/netboot/debian-installer/amd64/initrd.gz
```

Pass the `amd64` subdirectory as the installer location:

```sh
virt-install --name core --memory 2048 --vcpus 2 \
  --accelerate --rng /dev/urandom --autostart --graphics none \
  --disk size=20,bus=virtio --os-variant virtio26 \
  --location /var/lib/libvirt/images/coreos/amd64 \
  --extra-args "coreos.autologin console=ttyS0"
```

This method is probably useful for other distributions that don't get detected automatically either as well.

### Via VNC Viewer

Sometimes an installer may just refuse to start on the serial console or you're more confident in a graphical installer. This method also applies when you want to use an ISO image without specifying additional kernel parameters.
As an example, this section uses an image of [netboot.xyz](https://netboot.xyz), which can be used to interactively boot many different distributions.

First, download the `netboot.xyz` image:

    cd /var/lib/libvirt/boot
    curl -LO https://boot.netboot.xyz/ipxe/netboot.xyz.iso

Now create the virtual machine with `virt-install`, specifying the ISO with the `--cdrom` argument:

```
virt-install --name core --memory 2048 --vcpus 2 \
  --accelerate --rng /dev/urandom --autostart \
  --disk size=20,bus=virtio --os-variant virtio26 \
  --graphics vnc,listen=0.0.0.0 --noautoconsole \
  --cdrom /var/lib/libvirt/boot/netboot.xyz.iso
```

This should start the installation process and enable a VNC console. You can check the port with `virsh vncdisplay runner` and verify with `ss -tln` if in doubt. In my case a default of `:0` corresponds to port 5900 on the host, so temporarily open that port in the firewall:

    firewall-cmd --add-port 5900/tcp

Connect with your favourite VNC client and complete the installation.

{{< hint info >}}
You can't currently change the keyboard map on the console. Set a password with
`sudo passwd core` and connect with `ssh` instead if you run into problems.
{{< /hint >}}

## Install CoreOS to Disk

### Prepare Ignition

By now you should have prepared an Ignition configuration. There is of course a lot of variation possible here but most importantly you should enable `rngd.service` and `docker.service` and make sure that you can connect with SSH public keys. Mine looks somewhat like this:

```yaml
---
# enable docker service
systemd:
  units:
    - name: rngd.service
      enabled: yes
    - name: docker.service
      enabled: yes

# ssh public keys
passwd:
  users:
    - name: core
      ssh_authorized_keys:
        - # add your keys here

# automatic updates during maintenance window
locksmith:
  reboot_strategy: reboot
  window_start: 04:00
  window_length: 3h

# enable console autologin
storage:
  filesystems:
    - name: OEM
      mount:
        device: /dev/disk/by-label/OEM
        format: ext4
  files:
    - filesystem: OEM
      path: /grub.cfg
      mode: 0644
      append: true
      contents:
        inline: |
          set linux_append="$linux_append coreos.autologin"
```

### Installation

After transpiling, I am using [surge.sh](https://surge.sh) to host small static files quickly. Download the configuration and finally install CoreOS to disk:

```sh
curl -LO "https://ks.surge.sh/coreos/docker.json"
sudo coreos-install -d /dev/vda -i docker.json
sudo udevadm settle
sudo reboot
```

## Miscellaneous

### Fixed DHCP Address

You can add a fixed address for this virtual machine by creating an IP assignment for its MAC address with `virsh`:

```sh
virsh net-dhcp-leases default   # see current leases
virsh net-update default add-last ip-dhcp-host \
  --xml "<host mac='52:54:00:e7:b6:4d' ip='192.168.122.2' />" \
  --live --config
```

### SSH Client Configuration

Add an appropriate SSH config on the hypervisor:

    Host runner
      User core
      HostName 192.168.122.2
      StrictHostKeyChecking no
      UserKnownHostsFile /dev/null
