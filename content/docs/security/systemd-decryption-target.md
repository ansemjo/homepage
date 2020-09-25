---
title: Systemd Decryption Target
weight: 20
---

# Systemd Disk Decryption Target

In order to delay most of your systems services during boot until a bunch of harddisks are decrypted
but still bring up enough to allow for remote unlocking via `ssh` you'll need to use a
[systemd.target](https://www.freedesktop.org/software/systemd/man/systemd.target.html).

Most of the information here is based
[a mail on Debian's mailinglist](https://lists.debian.org/debian-user/2015/06/msg01259.html) by
Christian Seiler.

## `crypttab` entries

Add entries for your disks to `/etc/crypttab`. Use `-` to signal interactive passwords and add
`noauto` to avoid hanging at early boot:

```
# format: <name> <disk> <keyfile> <options>
HGST_HDN724040ALE640_PK1334PEHK98JS_LUKS  /dev/disk/by-id/ata-HGST_HDN724040ALE640_PK1334PEHK98JS-part1  - luks,noauto
HGST_HDN724040ALE640_PK1334PEHLZA1S_LUKS  /dev/disk/by-id/ata-HGST_HDN724040ALE640_PK1334PEHLZA1S-part1  - luks,noauto
WDC_WD40EZRX-00SPEB0_WD-WCC4E0284683_LUKS /dev/disk/by-id/ata-WDC_WD40EZRX-00SPEB0_WD-WCC4E0284683-part1 - luks,noauto
WDC_WD40EZRX-00SPEB0_WD-WCC4E0496927_LUKS /dev/disk/by-id/ata-WDC_WD40EZRX-00SPEB0_WD-WCC4E0496927-part1 - luks,noauto
```

## Systemd Units

Then you need to add a few unit files to create proper dependencies.

### `unlockme.target`

Mostly just copy and edit `/usr/lib/systemd/system/multi-user.target`:

```
[Unit]
Description=System waiting for decryption of disks
Requires=basic.target
Conflicts=rescue.service rescue.target
After=basic.target rescue.service rescue.target
AllowIsolate=yes
```

Copy wanted symlinks from `/usr/lib`:

```
mkcd /etc/systemd/system/unlockme.target.wants/
for w in /usr/lib/systemd/system/multi-user.target.wants/*; do
  ln -s $(readlink -f $w)
done
```

And add any services that you might require to be able to login via `ssh`:

{{< hint danger >}}
Do not forget required networking services!
{{< /hint >}}

```
ln -s /usr/lib/systemd/system/sshd.service
ln -s /usr/lib/systemd/system/NetworkManager.service
```

### `unlocked.target`

This target depends on all disks to be decrypted. The service's instance name is the `<name>` from
your crypttab.


```
[Unit]
Description=Decrypted all disks

Conflicts=systemd-ask-password-console.path systemd-ask-password-console.service
Conflicts=systemd-ask-password-plymouth.path systemd-ask-password-plymouth.service

Requires=unlockme.target \
  systemd-cryptsetup@HGST_HDN724040ALE640_PK1334PEHK98JS_LUKS.service \
  systemd-cryptsetup@HGST_HDN724040ALE640_PK1334PEHLZA1S_LUKS.service \
  systemd-cryptsetup@WDC_WD40EZRX\x2d00SPEB0_WD\x2dWCC4E0284683_LUKS.service \
  systemd-cryptsetup@WDC_WD40EZRX\x2d00SPEB0_WD\x2dWCC4E0496927_LUKS.service
```

{{< hint warning >}}
Remember to escape any names which might contain special characters in systemd's sense, i.e.
run names though `systemd-escape` first.
{{< /hint >}}

{{< hint info >}}
I needed a little override in `/etc/systemd/system/systemd-cryptsetup@.service.d/dependencies.conf`
to make sure that this target properly waits for all `systemd-cryptsetup@***.service` units without
specifying them all in `After=` manually:

    [Unit]
    DefaultDependencies=yes
{{< /hint >}}

### `continue.service`

Add the service which depends on those targets and then kicks off the rest of the startup
procedures:

```
[Unit]
Description=Continue system startup after disk decryption
Requires=unlocked.target
After=unlocked.target

[Service]
Type=oneshot
ExecStart=/usr/bin/systemctl --no-block start multi-user.target
```

## Change Default Target

Finally, change your default target to `unlockme.target` to use this procedure:

```
systemctl set-default unlockme.target
```

Now reboot, login with `ssh` and then start the continuation service to unlock your disks and carry
on:

```
systemctl start continue
```

You should be asked to enter the passwords on the commandline directly.

{{< hint info >}}
If you have trouble booting after any changes, apped `init=/sysroot/bin/sh` to your kernel
commandline!
{{< /hint >}}
