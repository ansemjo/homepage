# Network Boot

!!! todo
    This page is a work in progress.

See the [coreos dnsmasq image](https://quay.io/repository/coreos/dnsmasq/manifest/sha256:910710beddb9cf3a01fe36450b4188b160a03608786c11e0c39b81f570f55377) for details on how to create a simple dnsmasq container.

The service that is started with rkt on my matchbox host is:

```systemd
# from: coreos/matchbox --> contrib/systemd/matchbox-for-tectonic.service
# from: coreos/matchbox --> contrib/dnsmasq/README.md

[Unit]
Description=CoreOS dnsmasq DHCP proxy and TFTP server
Documentation=https://github.com/coreos/matchbox

[Service]
Environment="IMAGE=quay.io/coreos/dnsmasq"
Environment="VERSION=v0.5.0"
Environment="NETWORK=172.26.63.1"
Environment="MATCHBOX=%H:8080"

ExecStart=/usr/bin/rkt run \
  --net=host \
  --trust-keys-from-https \
  ${IMAGE}:${VERSION} \
  --caps-retain=CAP_NET_ADMIN,CAP_NET_BIND_SERVICE,CAP_SETGID,CAP_SETUID,CAP_NET_RAW \
  -- -d -q \
    --dhcp-range=${NETWORK},proxy,255.255.255.0 \
    --enable-tftp --tftp-root=/var/lib/tftpboot \
    --dhcp-userclass=set:ipxe,iPXE \
    --pxe-service=tag:#ipxe,x86PC,"PXE chainload to iPXE",undionly.kpxe \
    --pxe-service=tag:ipxe,x86PC,"iPXE",http://${MATCHBOX}/boot.ipxe \
    --log-queries \
    --log-dhcp

[Install]
WantedBy=multi-user.target
```

Important bits are probably `--net host` and the `userclass`, `pxe-service` and `dhcp-range` stuff in dnsmasq's options.

I also need to build iPXE binaries:

- `undionly.kpxe` (bios -> ipxe)
- `ipxe.efi` (uefi -> ipxe)

With the two files above present in `/var/tftp` the following seems to work:

```
dnsmasq -d -q --port 0 \
  --dhcp-range=172.26.63.0,proxy --enable-tftp --tftp-root=/var/tftp \
  --dhcp-userclass=set:ipxe,iPXE \
  --pxe-service=tag:#ipxe,x86PC,"chainload bios --> ipxe",undionly.kpxe \
  --pxe-service=tag:ipxe,x86PC,"load menu",http://boot.rz.semjonov.de/ks/menu.ipxe \
  --pxe-service=tag:#ipxe,BC_EFI,"chainload bc_efi --> ipxe",ipxe.efi \
  --pxe-service=tag:ipxe,BC_EFI,"load menu",http://boot.rz.semjonov.de/ks/menu.ipxe \
  --pxe-service=tag:#ipxe,x86-64_EFI,"chainload efi --> ipxe",ipxe.efi \
  --pxe-service=tag:ipxe,x86-64_EFI,"load menu",http://boot.rz.semjonov.de/ks/menu.ipxe
```

!!! hint
    Add `--log-dhcp` to get more verbose information about served DHCP requests.
