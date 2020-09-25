---
title: ZFS in-place Encryption
---

# ZFS in-place Encryption

There are basically two possibilities to encrypt an existing array's disks:

1. perform in-place encryption of _cold_ disks with `luksipc`
    - requires that you have enough free space at the end
    - will not work if your array is assembled from `/dev/disk/by-id/*` paths, since those will
      change

2. iterate over _hot_ disks by overwriting and resilvering each one
    - will leave your array in a degraded but usable state
    - you should overwrite the entire disk to make sure plaintext traces are removed
    - depending on how full your array is you might need to write up to twice your raw accumulated
      disk size worth of data .. this takes **a lot** of time!

## Hot Encryption

I chose to use the latter method because there was not enough space at the end of the drives and I
was not sure how ZFS could handle the changed disk paths. A couple things to note:

- make sure you align all partitions / containers!
    - check your _real_ physical block size (the drive might lie)
    - check the `ashift` property of your pool

- use partitions, do not make the LUKS partition span the entire drive!
    - begin the first partition at a multiple of your `pbs`, e.g. 4096 sectors / 2 MiB is a safe bet
    - account for the LUKS header (usually should be 2 MiB)
    - do not enlarge your partitions by too much, so you can replace them later on
    - **however** make sure that the mapped device cannot be smaller than your original partition!

### Example

For example, I originally had four `7809835008` sector partitions (`fdisk` uses 512 byte sectors
here).

| Partition          | sectors (512 bytes) | approximate size |
| -------------------| ------------------: | ---------------: |
| Original ZFS       |          7809835008 |      3813396 MiB |
| Full disk          |          7814037168 |    ~ 3815447 MiB |
| Nominal 4 TiB disk |          7812500000 |    ~ 3814697 MiB |
| New ZFS            |          7811072000 |      3814000 MiB |
| New LUKS           |          7811076096 |      3814002 MiB |

### Rinse & Repeat

Assume the original pool looked like this:

    kourier
      mirror-0                                                          ONLINE
        /dev/disk/by-id/ata-WDC_WD40EZRX-00SPEB0_WD-WCC4E0496927-part2  ONLINE
        /dev/disk/by-id/ata-HGST_HDN724040ALE640_PK1334PEHLZA1S-part2   ONLINE
      mirror-1                                                          ONLINE
        /dev/disk/by-id/ata-WDC_WD40EZRX-00SPEB0_WD-WCC4E0284683-part2  ONLINE
        /dev/disk/by-id/ata-HGST_HDN724040ALE640_PK1334PEHK98JS-part2   ONLINE

Take the first drive offline:

    export DISK="WDC_WD40EZRX-00SPEB0_WD-WCC4E0496927"
    zpool offline kourier ata-${DISK}-part2

Overwrite with zeroes or random data:

    dd if=/dev/zero of=/dev/disk/by-id/ata-${DISK} status=progress bs=1M

Create a new partition table and one partition with your desired size (the UUID sets the partition
type to `FreeBSD ZFS`):

    #!bash
    sfdisk /dev/disk/by-id/ata-${DISK} <<EOF
    label: gpt
    start=2M size=7811076096 type=516E7CBA-6ECF-11D6-8FF8-00022D09712B
    EOF

Create and open the LUKS container with your desired cipher / hash / keysize settings:

    #!bash
    cryptsetup luksFormat /dev/disk/by-id/ata-${DISK}-part1
    cryptsetup open /dev/disk/by-id/ata-${DISK}-part1 ${DISK}_LUKS

Replace the drive in the pool and wait for it to resilver:

    #!bash
    zpool replace kourier ata-${DISK}-part2 /dev/mapper/${DISK}_LUKS
    watch -d zpool status -P

Rinse and repeat with all four disks. This is what my pool looks like now:

    kourier
      mirror-0                                                 ONLINE
        /dev/mapper/WDC_WD40EZRX-00SPEB0_WD-WCC4E0496927_LUKS  ONLINE
        /dev/mapper/HGST_HDN724040ALE640_PK1334PEHLZA1S_LUKS   ONLINE
      mirror-1                                                 ONLINE
        /dev/mapper/WDC_WD40EZRX-00SPEB0_WD-WCC4E0284683_LUKS  ONLINE
        /dev/mapper/HGST_HDN724040ALE640_PK1334PEHK98JS_LUKS   ONLINE

## `systemd` Target

My next task will be to create proper dependencies for all my systemd services. I do not want my
system to block boot, so I can later login and manually decrypt the disks. However I also don't want
to have services randomly fail or attempt to create nonexistent paths because the zpool is not
imported yet. They should just queue and wait for me to decrypt the drives and then automatically
continue once I've done that.

Useful pointers:

- `systemd-cryptsetup@.service`
- bundling all encrypted disks in a `*.target`
- `After=`, `RequiredBy=`/`WantedBy=` and `BindsTo=` properties of services
- [systemd.unit(5)](https://www.freedesktop.org/software/systemd/man/systemd.unit.html)

!!! note
    See [Systemd Decryption Target](systemd-decryption-target.md) for the finished result.
