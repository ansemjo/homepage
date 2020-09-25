# Network Disk Decryption

Recently RedHat 7.4 introduced the possibility to bind your encrypted disks to a
network presence. It is called [Network-Bound Disk Encryption][NBDE]
and uses the projects [tang](https://github.com/latchset/tang) and
[clevis](https://github.com/latchset/clevis).

[NBDE]: https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux/7/html/Security_Guide/sec-Using_Network-Bound_Disk_Encryption.html

In essence, an encrypted payload is transformed with some ECDH key exchange magic with
the tang server and the disk is decrypted automatically. If however the tang server is
unavailable, this method fails and you must fall back to manually entering a passphrase.

I decided this is a nice addition to [my systemd decryption target](systemd-decryption-target.md),
so here's how I implemented it:

## `tang` server

First of all, install a release of the `tang` server. There's a package for CentOS and
a package in the AUR for Arch Linux. There are probably others, too. But it shouldn't
be too hard to build it yourself either.

    yum install tang

I didn't like tang running on port 80 by default, so I changed it with `systemctl edit tangd.socket`:

    [Socket]
    ListenStream=
    ListenStream=51653

Start and enable the service. Make sure to open the firewall on that port.

    systemctl enable --now tangd.socket

You can now make sure that a key is present and print the public key:

    tang-show-keys 51653
    4yWvhO4ZthpAGHDmdMn78Pe2Bg0

## `clevis` client

Now for the client part on my fileserver. There is a nice [post][rhpost] on the RedHat blog
describing the entire procedure. I'm assuming you already have some encrypted disks that you want
to set up for network-bound decryption. First, install clevis:

[rhpost]: https://www.redhat.com/en/blog/easier-way-manage-disk-decryption-boot-red-hat-enterprise-linux-75-using-nbde

    yum install clevis clevis-luks

And make sure that you can reach your tang server:

    curl -f tang.yourdomain:51653/adv | jq .

Now we bind a secret to this tang server and add it as a new key on our LUKS disks. This will
use the luksmeta storage, so you might want to take header backups on all disks to avoid data loss:

    cryptsetup luksHeaderBackup /dev/disk/by-id/ata-... --header-backup-file ...

Then bind the disks to the tang server:

    clevis luks bind -d /dev/disk/by-id/ata-... \
      tang '{"url":"http://tang.yourdomain:51653"}'

    The advertisement contains the following signing keys:
    4yWvhO4ZthpAGHDmdMn78Pe2Bg0

    Do you wish to trust these keys? [ynYN] y
    ...

Make sure the key matches the `tang-show-keys` output above! You'll be asked to initialize the LUKS
metadata storage and must then enter an existing passphrase to add the newly bound secret as a new
encryption key to your disk.

I didn't bother to setup automatic decryption on boot since I already have a semi-automatic decryption
environment in place with my systemd decryption target. I'm fine with decrypting disks with `clevis`
manually:

    clevis luks unlock -d /dev/disk/by-id/ata-... -n mappername

However, I automated this for all four disks in my array with a small script, which reads the disks and
names from `/etc/crypttab` and then starts [`continue.service`](systemd-decryption-target.md#continueservice):

```
#!/bin/sh

# unlock disks with tang and clevis
echo "+ unlock disks"
while read name disk opts; do
  echo "  $disk"
  clevis luks unlock -d "$disk" -n "$name"
done < /etc/crypttab

# continue system startup
sleep 2
echo "+ continue startup"
systemctl start continue.service
```
