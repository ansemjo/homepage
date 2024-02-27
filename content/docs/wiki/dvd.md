---
title: DVD Backups
weight: 10
---

# DVD Backups

A [post on the reliability of optical discs](https://blog.ligos.net/2022-04-02/The-Reliability-Of-Optical-Disks.html) revived my interest in using this medium for backups today, so I wanted to copy the information from [my gist](https://gist.github.com/ansemjo/6f1cf9d9b8f7ce8f70813f52c63b74a6) here.

## Encrypted `squashfs` Images

I've used [`squashfs` filesystems before]({{< relref "../../posts/2021/mksquashfs-from-stdin-and-sign/index.md" >}}) and wrote about their advantages. Basically, it's a highly compressed readonly-filesystem format, which doubles as an archive nicely. In particular, it is contained in a single file and can be mounted and browsed without needing to read or uncompress the whole thing. So it's perfect for archival purposes on a readonly medium.

### 1. Create a compressed `squashfs` image

Use `mksquashfs` to create a compressed image from a directory or list of files. Depending on how compressible the files are you could end up putting much more than the DVD's raw capacity on a single disc.

```sh
mksquashfs /path/to/my/files image.sqfs -comp zstd -Xcompression-level 22
```

You can try to choose another compression algorithm (e.g. `-comp xz`) or append to the same archive multiple times to fill it up to capacity.

### 2. Encrypt the image with LUKS

Add a little bit of extra space to the image and use `cryptsetup reencrypt --encrypt` to encrypt the archive *in place*. The additonal space is needed for the LUKS header and a little bit of space to shuffle data around during encryption. Only half of the added space is actually used for the header, so you can trim the file again at the end. The manpage recommends using double the recommended minimum header size – so 32 MiB for LUKS2. Less than that is okay if you don't need the metadata space.

The following operation **can eat your data**, so make sure you can regenerate the archive from step one:

```sh
truncate -s +32M image.sqfs
cryptsetup -q reencrypt --encrypt --type luks2 \
  --resilience none --disable-locks --reduce-device-size 32M image.sqfs
truncate -s -16M image.sqfs
```

### 3. Burn the encrypted archive to a disc

Now simply burn the `archive.sqfs` file to disc as if it were an `*.iso`. In graphical tools you might need to select "All Files" to be able to see it in the selection dialog. On the commandline, simply use `growisofs`:

```sh
growisofs -dvd-compat -Z /dev/sr0=image.sqfs
```

Replace `/dev/sr0` with the path to your disc drive accordingly. The arguments `-dvd-compat` and `-Z` create a finalized disc with a single track.

### 4. Mount the archive from disc

Congratulations. If your graphical desktop uses some kind of automounter, you should already see a password prompt pop up after the disc tray is reloaded. Otherwise handle the disc like you would any other encrypted block device; open a `dm-crypt` mapper and mount the `squashfs` filesystem inside it into some directory:

```sh
sudo cryptsetup open /dev/sr0 cryptdvd
sudo mount -t squashfs /dev/mapper/cryptdvd /mnt/dvd
```

---

## Adding Integrity Checking and Error Correction

With a compressed and encrypted image like the one above, everything can go to *sh\*t* if there is a single bit flip in the encrypted container, leading to a chain of unrecoverable errors. I'm not going into any longevity comparisons between optical media and hard disks but you should be aware that DVDs – like any other medium – can go bad over time; through scratches, dirt or decomposition. Ideally, you would able to correct erroneous sectors but at the absolute minimum you'll want to know when your data is garbled.

I see two easy possibilities to add integrity protection to your data – in addition to the error correction inherent in the optical medium.

### Parity blocks with PAR2

The simpler approach would be to just generate some parity blocks with `par2`. This is a widespread tool, which will probably still be easily obtainable in a few years' time. It uses Reed-Solomon erasure coding and you can specify the amount of parity that you want to generate freely, in percent. The calculcations take a lot of time but can repair any errors up to that amount of parity.

```sh
par2 create -r10 image.sqfs
```

This will generate 10% parity files in a number of files next to the archive. You won't be able to burn the archive as a single image directly to disk anymore but burning them all together in a standard UDF filesystem is the next best thing:

```sh
growisofs -Z /dev/sr0 -udf ./
```

### Integrity and Error-Correction with `dm-verity`

Another solution is to use another device-mapper layer of the Linux kernel. Although this is a relatively new feature, it should be widely available already in a recent Linux distributions. `dm-verity` creates a tree-like structure of block hashes up to a root hash. The root hash needs to be stored externally somehow, unfortunately. But it creates a cryptographically secure method to verify the integrity of the disc and it allows adding – again Reed-Solomon coded – parity blocks to restore detected bad blocks.

Since it is a device-mapper which is supposed to work with raw disk devices, I would *expect* it to fare better with unresponsive or badly scratched discs, that return many bad sectors. But for lack of a reliable way to inject precise faults on optical discs I cannot test this assumption. I am not sure how this method behaves if you were to have a bad sector exactly where the verity superblock is supposed to be on the disc.

There is two methods to this. Either you create the hash-tree and parity blocks as files next to the encrypted image and then burn them in a UDF filesystem like in the method above. Or you reuse the same image file and specify offsets for the different parts. The former has have the advantage that you could add README files and reuse existing recovery tools to read the files from disc and then try to restore them locally. The latter would minimize the number of layers but does require some calculation for the offsets beforehand. Either way you somehow *need to store the generated root hash* for this to make any sense at all! I would propose encoding it in a QR code and printing it on the leaflet.

#### Calculating Offsets

If you want to reuse a single file with `veritysetup`, you need to know where to place the hash and error correction blocks. The hash offset is relatively straightforward, since it is simply the amount of data you have, i.e. the size of the image. First of all make sure that it is a multiple of `4096` bytes, which is the default blocksize of `veritysetup`! `mksquashfs` uses a default block size of 128 KiB, so this should be a given. Therefore `--hash-offset`and `--data-blocks` arguments are calculated as follows:

```
stat -c%s image.sqfs |\
  awk '{ printf "--hash-offset=%d --data-blocks=%d\n", $1, $1/4096 }'
```

The `--fec-offset` is a little more tricky because you need to know how many hash blocks are going to be written, which is not *completely trivial* due to the tree structure. You can calculate it recursively though. The following Python snippet assumes 4k data and hash sectors and 32 bit hashes, thereby fitting 128 hashes into one hash block.

```
import math
# hs := hash sectors, ds := data sectors
def hs(ds, superblock=False):
  h = 1 if superblock else 0
  while ds > 1:
    ds = math.ceil(ds / 128)
    h += ds
  return h
```

For a small file with 72884224 bytes or 17794 data blocks, it would result in 144 hash blocks. The `--fec-offset` would then be `(data-blocks + hash-blocks) * 4096` – in this case 73474048. The format command for my small test file would then be:

```
veritysetup format --data-blocks=17794 --hash-offset=72884224 \
  --fec-roots=24 --fec-offset=73474048 \
  {--fec-device=,,}image.sqfs
```

**Note**: So far I haven't tried to repair any actual corruption cases with this method. Previous experiments with overwriting parts of the file with `dd` were unsuccessful but that might have been due to bug [cryptsetup/cryptsetup#554](https://gitlab.com/cryptsetup/cryptsetup/-/issues/554), which has since been fixed.