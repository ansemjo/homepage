!!! note
    This page needs tidying up.

## Network Booting

### Combined DHCP responses

Last time I changed my PXE procedure to use custom iPXE scripts and compiled iPXE binaries, I ran into the problem that the bootloop needs to be broken somehow, if you specify the iPXE binary as the boot target via DHCP and do _not_ want to recompile your binary with new scripts embedded every time. This assumed _dumb_ DHCP servers, which cannot react to different client classes. And while OpenWRT and the underlying `dnsmasq` are not exactly _dumb_, the necessary settings are not comfortably exposed in Luci. So I used an unused DHCP option to specify the _real_ PXE boot target and an embedded iPXE script which reads this option and then chainloads. Whew!

Today I [learned](https://coreos.com/matchbox/docs/latest/network-setup.html#pxe-enabled-dhcp) that clients can assemble responses from multiple DHCP servers and `dnsmasq` can act as a proxy just fine, meaning it will _only_ serve the settings relevant to PXE booting and leave all the IP assignments, DNS settings, etc. to the main DHCP server in the network. Yay!

This means that the same server that shall act as the target for PXE booting (possibly even containing a gRPC-enabled [`matchbox`](https://coreos.com/matchbox/docs/latest/)) can ___also___ serve the relevant DHCP settings so clients will use it.

### CoreOS containers

The CoreOS team provides containers for both `matchbox` and `dnsmasq`:

- [quay.io/coreos/matchbox](https://quay.io/repository/coreos/matchbox)
- [quay.io/coreos/dnsmasq](https://quay.io/repository/coreos/dnsmasq)

Together with the sample `systemd` service files provided in matchbox releases in the `contrib/systemd/` subdirectory, these can easily be used to bootstrap a fully functional network boot target on top of CoreOS.

```systemd
[Unit]
Description=CoreOS matchbox Server
Documentation=https://github.com/coreos/matchbox

[Service]
Environment="IMAGE=quay.io/coreos/matchbox"
Environment="VERSION=v0.7.1"
Environment="MATCHBOX_ADDRESS=0.0.0.0:8080"
Environment="MATCHBOX_RPC_ADDRESS=0.0.0.0:8081"
Environment="MATCHBOX_LOG_LEVEL=debug"
ExecStartPre=/usr/bin/mkdir -p /etc/matchbox
ExecStartPre=/usr/bin/mkdir -p /var/lib/matchbox/assets
ExecStart=/usr/bin/rkt run \
  --net=host \
  --inherit-env \
  --trust-keys-from-https \
  --mount volume=data,target=/var/lib/matchbox \
  --mount volume=config,target=/etc/matchbox \
  --volume data,kind=host,source=/var/lib/matchbox \
  --volume config,kind=host,source=/etc/matchbox \
  ${IMAGE}:${VERSION}

[Install]
WantedBy=multi-user.target
```

```systemd
[Unit]
Description=CoreOS dnsmasq DHCP proxy and TFTP server
Documentation=https://github.com/coreos/matchbox

[Service]
Environment="IMAGE=quay.io/coreos/dnsmasq"
Environment="VERSION=v0.5.0"
Environment="NETWORK=172.26.63.1"
Environment="MATCHBOX=172.26.63.242:8080"
# replace with %H ?

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

## Bootstrap Process

This is an overview of the necessary procedures to bootstrap the entire Rechenzentrum�:

- bootstrap the network boot target 'matchbox'
  - boot and install CoreOS to disk
  - generate tls keys for `matchbox` gRPC
  - enable systemd services for `matchbox` and `dnsmasq`
  - _optionally_ add custom iPXE scripts in `matchbox`' assets and tweak boot option
  - _optionally_ download and store kernel and initramfs locally in assets
- configure infrastructure with `terraform`
  - use providers for `matchbox` and `vsphere`/`libvirt`/...
  - configure profiles for machines that bootstrap until you can `ssh` in
  - `terraform apply` to bring them up and have them boot from pxe
- use `ansible` to do proper deployments and configuration management
  - _bonus points_ if you use `terraform` state as inventory for ansible
  
### Matchbox
 
Boot CoreOS into RAM through your preferred method, e.g. using the [CoreOS ISO](https://coreos.com/os/docs/latest/booting-with-iso.html) or [netboot.xyz](https://netboot.xyz/downloads/). Then install to disk with `coreos-install`:

```
curl -Lo install.json https://ks.surge.sh/matchbox.json
sudo coreos-install -d /dev/sda -i install.json
sudo reboot
```

Append `-o vmware_raw` to the installation command if you're installing on VMware and replace `/dev/sda` with `/dev/vda` if you're installing on KVM (or use scsi-virtio disks).

Reboot twice for the autologin to take effect. Then add this matchbox server in your DNS.
 
### Install CentOS over Serial Cable

Simply using `netboot.xyz.kpxe` is not sufficient when installing from network with only a serial connection (e.g. on my X10SBA) because it does not allow you to edit the kernel commandline - which does not include `console=ttyS0` by default. Thus boot into an iPXE shell and use the following script to start an interactive CentOS install over serial:

```
imgfree
set repo http://mirror.23media.de/centos/7/os/x86_64
kernel ${repo}/images/pxeboot/vmlinuz
initrd ${repo}/images/pxeboot/initrd.img
imgargs vmlinuz ramdisk_size=8192 console=ttyS0,115200 text method=${repo}/
boot
```

Careful when copy-pasting though. I have had incomplete pastes which lead to a missing `_64` in the repo URL, etc.

### Squid proxy

Instead of mirroring multiple repositories locally, you could run a [Squid](https://wiki.squid-cache.org/FrontPage) proxy in your network and point all `yum` clients at it. With some URL rewriting you can cache the same packages from many different mirrors in a deduplicated fashion.

I used the [sameersbn/squid](https://github.com/sameersbn/docker-squid) image on a CoreOS host, started with the following arguments:

```
docker run -d --net host --name squid \
  -v /var/spool/squid:/var/spool/squid \
  -v /etc/squid:/etc/squid sameersbn/squid
```

The configuration files cache all `.rpm`'s from any mirrors. This is probably too open and broad to be used as a general proxy, so be careful.

**`/etc/squid/storeid.db`**:

```
# /etc/squid/squid.conf

acl safe_ports port 80 21 443
acl tls_ports  port 443
acl CONNECT method CONNECT

http_access deny !safe_ports
http_access deny CONNECT !tls_ports

http_access allow localhost
http_access allow all

http_port 3128

# cache yum/rpm downloads:
# http://ma.ttwagner.com/lazy-distro-mirrors-with-squid/
# https://serverfault.com/questions/837291/squid-and-caching-of-dnf-yum-downloads

cache_replacement_policy heap LFUDA		# least-frequently-used
cache_dir aufs /var/spool/squid 20000 16 256	# 20GB disk cache
maximum_object_size 4096 MB			# up to 4GB files

store_id_program /usr/lib/squid/storeid_file_rewrite /etc/squid/storeid.db	# rewrite all centos mirror urls

coredump_dir /var/spool/squid

refresh_pattern -i \.(deb|rpm|tar|tar.gz|tgz)$ 10080 90% 43200 override-expire ignore-no-cache ignore-no-store ignore-private
refresh_pattern .	0	20%	4320
```

**`/etc/squid/storeid.db`**:

```
\/([0-9\.\-]+)\/([a-z]+)\/(x86_64|i386)\/(.*\.d?rpm)	http://rpmcache.squid.internal/$1/$2/$3/$4
```

**Note:** the `storeid.db` rules need **tabs** as whitespace, not spaces! And during initial creation I found out that squid sends a *quoted* string to the helper, so using any regular expression with `(.*\.rpm)$` at the end did not match. Use `debug_options ALL,5` and grep for `storeId` if you're having problems.

Finally, simply add `proxy=http://url.to.your.proxy:3128` in your clients' `/etc/yum.conf`.

#### reverse proxy

With a small addition to your `squid.conf` you can also make Squid act as a reverse proxy (or "accelerator" in Squid terms) for a mirror of your choice, using **the same cache**. Although the wiki still says that `cache_peer` requests do not pass through the `storeid` helper, it in fact seems to do just that. At the time of this writing, the latest container uses `Squid Cache: Version 3.5.27` from Ubuntu's repositories.

```
...

http_port 3128
http_port 80  accel defaultsite=ftp.halifax.rwth-aachen.de no-vhost

cache_peer ftp.halifax.rwth-aachen.de parent 80 0 no-query originserver name=mirror

acl mirror dstdomain ftp.halifax.rwth-aachen.de
http_access allow mirror
cache_peer_access mirror allow mirror
cache_peer_access mirror deny all

...
```

With this configuration, you could also use Squid as a mirror to install your machines via kickstart, because also the `.../os/x86_64/images/pxeboot/*` files will be cached. You might want to amend your `refresh_pattern` rules to account for that.