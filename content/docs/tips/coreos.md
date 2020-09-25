---
title: CoreOS
weight: 10
---

# CoreOS

{{< hint danger >}}
[CoreOS is deprecated.](https://coreos.com/os/eol/) I've played with its successor
Fedora CoreOS but I'm not sure how easily these tips translate to it.
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
