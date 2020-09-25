---
title: Transforming an encrypted array from RAID 1 to RAID 6
date: 2016-05-16
draft: false
toc: true
tags:
  - linux
  - homelab
  - encryption
---

## Introduction

### Some context
I have a NAS at home which runs on Debian Jessie. A NAS wouldn't be a NAS without some storage, so I put in two disks with 4 TB each when I built it. Those two disks have actually been used in a setup with [OpenMediaVault] before that and already had a software-RAID on them. When migrating the disks (to Ubuntu at first) I learned about [mdadm] and that OpenMediaVault uses it. Great, that was a rather painless transition!

### Current situation

In the meantime I migrated my system to Debian and put and encryption layer with LUKS on top of the RAID. Now I bought two more drives and want to extend my capacity.

Output from `lsblk` currently looks kind of like this:

[OpenMediaVault]: http://www.openmediavault.org/
[mdadm]: https://raid.wiki.kernel.org/index.php/RAID_setup

```
sdc                       8:32   0   3.7T  0 disk  
└─sdc1                    8:33   0   3.7T  0 part  
  └─md127                 9:127  0   3.7T  0 raid1 
    └─greens_crypt      254:3    0   3.7T  0 crypt /mnt/arr
sdd                       8:48   0   3.7T  0 disk  
└─sdd1                    8:49   0   3.7T  0 part  
sde                       8:64   0   3.7T  0 disk  
└─sde1                    8:65   0   3.7T  0 part  
  └─md127                 9:127  0   3.7T  0 raid1 
    └─greens_crypt      254:3    0   3.7T  0 crypt /mnt/arr
sdf                       8:80   0   3.7T  0 disk  
└─sdf1                    8:81   0   3.7T  0 part  
```

_Nevermind the sorting .. I must have switched some cables when I put in the new drives. Mounting happens by UUID anyway._

We see a software-RAID with level 1 on across two partitions `sdc1` and `sde1`. On top of that is a dm-crypt device using [LUKS encryption] mode, which is then formatted with ext4 and mounted at `/mnt/arr`.

## Preparation

### Replicate the partitioning layout

The new disks are `sdd` and `sdf`. First, I copied the partitioning layout from one of the old disks. `blockdev` reports the exact same size for all four disks. But it is a good idea to create a partition which is slightly smaller than that anyway - just in case you ever have to replace a drive with another which lacks just a couple of megabytes at the end ..

To do that, you can use the replication command of [sgdisk]:

```
• root ~ # SOURCE='/dev/sdc'; TARGETS='/dev/sdd /dev/sdf';
• root ~ # for target in $TARGETS; do
> sgdisk --replicate=$target $SOURCE
> sgdisk --randomize-guids $target
> done
```

That will copy the partitioning table from `/dev/sdc` to `/dev/sdd` and `/dev/sdf` and then randomize the GUIDs of the latter two.

[LUKS encryption]: https://wiki.archlinux.org/index.php/Dm-crypt/Device_encryption#Encryption_options_for_LUKS_mode
[sgdisk]: https://packages.debian.org/jessie/gdisk

### How to extend the array?

I searched the web for a while, looking for the best approach here ..

> Options like BTRFS or ZFS?

They looked very interesting but would have made the encryption layer rather difficult.

> Should I use RAID 5 and have ~ 12 terabytes of capacity?

No. Search for 'RAID 5' and 'URE' and bear in mind I have 4 TB disks here. You'll find a reason pretty quickly. _(hint: disks are likely to fail on rebuilding)_

> Create a new degraded RAID 6, copy files and then add the old disks?

That would require two re-synchronizations if you want to make sure to have a working array at all times and it would _still_ leave you in state with two degraded arrays at one point. Also you'll need to unmount the old array and change all your entries in fstab and crypttab etc.

> Add the two disks as spares to the existing array and then convert it?

This is definitely the cleanest approach, is a function of mdadm itself since version 3.-something and you can just keep using your array without worrying about inconsistent states between old and new array. It requires two reshaping operations though because it is not currently possible to go from RAID 1 to RAID 6 directly. So that's what we're going to do.

## Let's do it

### Add the new disks as spares

If you replicated the partition layout properly this should be rather painless and instant:

```
• root ~ # mdadm /dev/md127 --add /dev/sdd
mdadm: added /dev/sdd
• root ~ # mdadm /dev/md127 --add /dev/sdf
mdadm: added /dev/sdf
```

If you look at your array with `mdadm --detail /dev/md127` you should see the new drives added as spares at the end of the output.

### Grow the RAID to level 5

Now we grow the RAID to level 5 across three disks and thereby initiate a re-sync:

```
• root ~ # mdadm /dev/md127 --grow --level=5 --raid-devices=3
mdadm: level of /dev/md127 changed to raid5
```

This will initiate a reshape and your `mdadm --detail` output should look similar to this:

```
• root ~ # mdadm --detail /dev/md127
/dev/md127:
        Version : 1.2
  Creation Time : Fri Nov 20 18:15:36 2015
     Raid Level : raid5
     Array Size : 3906885440 (3725.90 GiB 4000.65 GB)
  Used Dev Size : 3906885440 (3725.90 GiB 4000.65 GB)
   Raid Devices : 3
  Total Devices : 4
    Persistence : Superblock is persistent

  Intent Bitmap : Internal

    Update Time : Sun May 22 16:02:44 2016
          State : clean, reshaping 
 Active Devices : 3
Working Devices : 4
 Failed Devices : 0
  Spare Devices : 1

         Layout : left-symmetric
     Chunk Size : 64K

 Reshape Status : 7% complete
  Delta Devices : 1, (2->3)

           Name : fractal:greens
           UUID : e096[...]e57e
         Events : 52263

    Number   Major   Minor   RaidDevice State
       0       8       65        0      active sync   /dev/sde1
       2       8       33        1      active sync   /dev/sdc1
       4       8       81        2      active sync   /dev/sdf1

       3       8       49        -      spare   /dev/sdd1
```

I performed the `--grow` operation this morning and it has been running since. If you look at `/proc/mdstat` you can get an idea of how long this takes:

```
• root ~ # cat /proc/mdstat 
Personalities : [raid1] [raid6] [raid5] [raid4] 
md127 : active raid5 sdf1[4] sdd1[3](S) sde1[0] sdc1[2]
      3906885440 blocks super 1.2 level 5, 64k chunk, algorithm 2 [3/3] [UUU]
      [=>...................]  reshape =  7.2% (284918016/3906885440) finish=3292.1min speed=18336K/sec
      bitmap: 0/30 pages [0KB], 65536KB chunk

unused devices: <none>
```

That is a little more than two days remaining. It does get a little bit faster if it is not mounted and the LUKS device is not opened. But that's the beauty of this: you _can_ have the array mounted and in use while you do this. If you can live with slow performance, that is ...

After this operation is finished you should already have more capacity. (Close to 8 TB in this case.)

Keep in mind, this system has an Intel Celeron [J1900] (on a Supermicro [X10SBA]), which is great in terms of power efficiency but not exactly the fastest processor around. The drives are not the fastest either, so YMMV.

[J1900]: http://ark.intel.com/products/78867/Intel-Celeron-Processor-J1900-2M-Cache-up-to-2_42-GHz
[X10SBA]: http://www.supermicro.com/products/motherboard/celeron/X10/X10SBA.cfm

### Grow the RAID to level 6

After the first reshaping finished after almost three days, I quickly verified that the array grew to 8 TB and issued the command for the next reshaping operation:

```
• root ~ # mdadm /dev/md127 --grow --level=6 --raid-devices=4
mdadm: level of /dev/md127 changed to raid6
```

As noted above, the array can stay live during all this time, so I decided to resize the filesystem while I'm at it.

### Resize the dm-crypt device

As we are growing in size, we need to resize from the bottom up. The array already grew, so now we resize the dm-crypt device with this simple command:

```
• root ~ # cryptsetup resize /dev/mapper/greens_crypt
```

_Obviously, replace with your device accordingly._

### Resize the filesystem

Lastly we need to resize the filesystem that we have on top of our encrypted device. In my case that is a simple `ext4` filesystem and no additional partitioning or LVMs.

The steps of course vary for each filesystem and configuration. In case of an `ext4` you first check the filesystem before you resize it. Unfortunately, you have to unmount the device to run `e2fsck`:

```
# umount /mnt/arr
# e2fsck -f /dev/mapper/greens_crypt
# resize2fs /dev/mapper/greens_crypt
# mount /dev/mapper/greens_crypt /mnt/arr
```

The resize will take a while. It took about 15 minutes in my case with the reshaping operation already running in the background.

For a `btrfs` filesystem you actually have to do the resizing while the device is mounted:

```
# btrfs filesystem resize max /mnt/arr
```

## Conclusion

_Right now, the second reshaping is in progress and it looks like it might take up to three days again._
