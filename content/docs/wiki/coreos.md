---
title: CoreOS
weight: 10
---

# CoreOS

{{< hint danger >}}
The original [CoreOS is deprecated](https://coreos.com/os/eol/).
{{< /hint >}}

## QEMU Guest Agent

When CoreOS is running in a virtual machine, the guest agent `qemu-ga` is required
for the host to discover the machine's network setup, specifically it's IP.
You can start the guest agent in an Alpine container:

```sh
docker run -d \
  -v /dev:/dev \
  --privileged \
  --net host \
  alpine ash -c 'apk add qemu-guest-agent && exec qemu-ga -v'
```

An alternative for very minimal machines deployed with virt-install exists,
where the necessary channel needs to be created in the domain XML first.

Add the following device by editing the domain definiton with `virsh edit $name`:

```xml
<channel type='unix'>
  <target type='virtio' name='org.qemu.guest_agent.0'/>
</channel>
```

You'll need to fully shut the machine down and start it again. A single reboot
is not enough. Now download a [`qemu-guest-agent` package](https://pkgs.org/download/qemu-guest-agent) in a TAR archive.

Extract the contained `qemu-ga` binary to `/opt/bin` and use the following
systemd service:

```systemd
[Unit]
Description=QEMU Guest Agent
ConditionPathExists=/dev/virtio-ports/org.qemu.guest_agent.0

[Service]
ExecStart=/opt/bin/qemu-ga

[Install]
WantedBy=multi-user.target
```

## Simple Jumphost Ignition with Autologin

I've used the following Butane config when installing a Fedora CoreOS machine as
a simple, auto-updating jumphost:

```yaml
variant: fcos
version: 1.4.0

# set authorized ssh keys
passwd:
  users:
    - name: core
      ssh_authorized_keys:
        - ssh-ed25519 ...
    - name: jump
      ssh_authorized_keys:
        - ssh-ed25519 ...

storage:
  files:

    # set a hostname
    - path: /etc/hostname
      mode: 0644
      contents:
        inline: |
          jumphost

    # configure autoupdater settings
    - path: /etc/zincati/config.d/55-updates-strategy.toml
      mode: 0644
      contents:
        inline: |
          [updates]
          strategy = "periodic"
          [[updates.periodic.window]]
          days = [ "Sat", "Sun" ]
          start_time = "22:00"
          length_minutes = 120

systemd:
  units:

    # autologin on graphical console
    - name: getty@tty1.service
      dropins:
        - name: autologin-core.conf
          contents: |
            [Service]
            ExecStart=
            ExecStart=-/sbin/agetty --autologin core --noclear %I $TERM

    # autologin on serial console
    - name: serial-getty@ttyS0.service
      dropins:
        - name: autologin-core.conf
          contents: |
            [Service]
            ExecStart=
            ExecStart=-/sbin/agetty --autologin core --noclear %I $TERM
```

Then I used the given container to convert this config into an Ignition file:

```
docker run --rm -i quay.io/coreos/butane:release \
  --pretty --strict < config.bu > config.ign
```


## `fcos` Installer

I wrote a little script to create new Fedora CoreOS based virtual machines while
playing around with it. I'm pubishing it here before cleaning up some unused files:

```bash
#!/usr/bin/env bash

# helpers
err() { echo "err: $1" >&2; }
required() { if [[ -z $1 ]]; then err "$2 required"; exit 1; fi; }
usage() { cat <<USAGE
usage: $ fcos-install [-args] [extra]
  -n name     : machine name
  -c cpus     : number of vcpu cores
  -m memory   : memory in MiB
  -N netname  : use network name
  -d disk     : size of disk in GiB
  -D          : download latest iso
USAGE
}

# default config
VCPUS="2"
MEMORY="2048"
NETWORK="vf-eno4"
DISKSIZE="24"
DOWNLOAD="false"

# commandline parser
while getopts ":n:c:m:N:d:Dh" OPTION; do
  case "$OPTION" in
    # invalid cases
   \?) err "invalid option: $OPTARG"; exit 1;;
    :) err "invalid option: $OPTARG requires an argument"; exit 1;;
    h) usage; exit 0;;
    # arguments
    n) MACHINE="$OPTARG";;
    c) VCPUS="$OPTARG";;
    m) MEMORY="$OPTARG";;
    N) NETWORK="$OPTARG";;
    d) DISKSIZE="$OPTARG";;
    D) DOWNLOAD="true";;
  esac
done
shift "$((OPTIND-1))"

# check required values
required "$MACHINE" "machine name"
required "$VCPUS" "number of cpu cores"
required "$MEMORY" "amount of memory"
required "$NETWORK" "network name"
required "$DISKSIZE" "disk size"

# download and use latest available iso
if [[ $DOWNLOAD = true ]]; then
  podman run --privileged --pull=always --rm \
    -v /var/lib/libvirt/boot:/data -w /data \
    quay.io/coreos/coreos-installer:release -- download -f iso
fi
ISO=$(ls /var/lib/libvirt/boot/fedora-coreos-*-live.x86_64.iso | sort -rV | head -1)

# run virt-install
virt-install --name="$MACHINE" --os-variant="fedora31" \
  --vcpus="$VCPUS" --memory="$MEMORY" --memorybacking="hugepages=on" \
  --network="network=$NETWORK" --graphics="none" --disk="size=$DISKSIZE" \
  --location="$ISO,kernel=/images/pxeboot/vmlinuz,initrd=/images/pxeboot/initrd.img" \
  --extra-args="initrd=/images/pxeboot/initrd.img,/images/ignition.img mitigations=auto,nosmt systemd.unified_cgroup_hierarchy=0 coreos.liveiso=$(basename "${ISO%%-live.x86_64.iso}") ignition.firstboot ignition.platform.id=qemu console=tty0 console=ttyS0,115200n8"
```
