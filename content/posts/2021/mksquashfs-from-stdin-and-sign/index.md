---
title: "Create squashfs archive from stdin and sign it on-the-fly"
date: 2021-05-08T09:46:26+02:00
tags: [ "linux", "network" ]
---

The use-case might be a little specific but I'll describe it nonetheless, hoping it may help someone. A while ago I read [Practical Forensic Imaging](https://nostarch.com/forensicimaging) by Bruce Nikkel and tried out the [`sfsimage`](https://digitalforensics.ch/sfsimage/) script that he presented therein.

The idea is as simple as it is brilliant: combine open-source disk recovery tools like `dc3dd` with the great compression and usability of readonly `squashfs` filesystems. The imaged disk is piped directly into a virtual file inside the archive and some metadata of the acquisition is added alongside it to create a "forensic image". This image can be mounted and inspected without elevated privileges using `squashfuse` -- all the while usually only taking a fraction of the original disk size.

## Why?!

Yesterday I migrated one of my small virtual servers at Hetzner to a new one -- no big deal in itself. But before I finally deleted the server, I wanted to have a complete "backup image" -- just in case I forgot to migrate something. Sure, I could just archive the entire filesystem with `tar` or `zip`. But a ZIP can't be sent back over SSH on-the-fly and a TAR is not really browseable without first decompressing the entire thing -- *meh.* Furthermore, neither would allow me to restore the entire machine simply by writing out the disk image.

{{< hint info >}}
You could of course always use a "reverse" SSHFS mount and just not bother with piping your archives through standard output. Courtesy of [boltblog](https://blog.dhampir.no/content/reverse-sshfs-mounts-fs-push):

    dpipe /usr/lib/ssh/sftp-server = ssh vps.example.com sshfs \
      :/path/on/local/machine /tmp/mnt -o slave
{{< /hint >}}

Either way, there's so many different ways you could generate *some sort* of useful data on standard output. So the *obvious* solution was to just image the entire disk with `dd` and mount it in a loopback device if I should need it later. Luckily Hetzner allows you to reboot into a rescue environment, where your disk is completely quiescent.

## Speaking in pseudofiles

I took a look at `sfsimage` to see how the tool writes disk image files and it turns out that `mksquashfs` has a concept of [pseudofiles](https://github.com/plougher/squashfs-tools/blob/master/RELEASE-READMEs/pseudo-file.example) to create block and character devices in the archive without elevated privileges. It also allows you to use the output of a command as a file's contents. In order to image a disk you would use `dd` or `dc3dd` and omit the `of=` argument so it writes to standard output. If you simply used `cat`, the file would contain whatever you pipe into the `mksquashfs` command. A simple example that writes the current date to a file called `now` inside the archive might look like this:

    date | mksquashfs /dev/null archive.sqsh -p "now f 644 0 0 cat"

{{< hint info >}}
Notice the `/dev/null` there? This will end up writing a character special file called `null` in the archive. To avoid that, you can use an empty directory; this is exactly what `sfsimage` does, too.
{{< /hint >}}

## On-the-fly checksumming

At this point I wanted to add a signed checksum of the raw disk image, so that I could theoretically verify that the image has not been altered later. I don't really have any particular reason for that; it's more a case of "just because I can".

Preferably, you would do that without re-reading the entire disk image a second time, which would effectively double the time required. You cannot simply use a second pseudofile either, because the first command "gobbles" up the entire input until EOF. The solution is to split the input stream with `tee` and use a process substitution, which will write the checksum to a temporary file. That file can then be signed and quietly appended to the squashfs archive. (You could probably split into additional file descriptors and avoid the temporary file but I haven't tried that yet.)

Looking at `sfsimage` again, there is already an example of using "plain old `dd`" with `tee` and `md5sum` all in a single pipe. However, at this point the somewhat inflexible configuration and usage of `sudo` thorughout the script (it assumes that you want to image a block device after all ...) was annoying me and I wanted it simpler. So without much further ado, this is the simplified core in just a couple of lines:

    ssh root@vps.example.com dd if=/dev/sda |\
      tee >(sha256sum | sed 's/-/disk.img/' >/tmp/checksum) |\
      mksquashfs /tmp/emptydir archive.sqsh -comp zstd -p "disk.img f 644 0 0 cat" \
    && mksquashfs /tmp/checksum archive.sqsh -quiet

It does add some overhead but I believe that is mostly due to `sha256sum` and `mksquashfs` contending for CPU cycles. Depending on your bandwidth you might also want to compress the stream remotely and decompress it again locally before archival; using the `-C` option of `ssh` is utterly useless though because it uses the same algorithm as `gzip` -- which actually made the transfer **slower** in my tests. Instead use `zstd`:

    ssh root@vps.example.com "dd if=... | zstd" | zstd -d |\
      ...

## Signing the checksum

At this point it is trivial to just sign the checksum file however you like before you append both the `checksum` and `checksum.sig` to the archive. I like `signify` as a lightweight alternative to GPG -- but you do you. Signify can't directly sign the disk image because it limits the length of the message that you can sign.

## Wrap it up

In the end I wrote myself a small replacement script for `sfsimage` that did just this one thing: checksum and write whatever it receives on standard input into a new squashfs archive. Hence, I've called the result `squashpipe` and saved it [to my dotfiles](https://github.com/ansemjo/dotfiles/blob/master/bash/aliases.d/squashpipe.sh):

    ... | ./squashpipe archive.sqsh

The script handles `-n` to specify the filename inside the archive, `-m` to adjust the file mode and `-s` to optionally sign the checksum with a `signify` key as described above:

    signify -Gn -p ~/key.pub -s ~/key.sec
    ... | ./squashpipe -s ~/key.sec archive.sqsh

The checksum contains a BSD-style tag that `signify` can verify directly. Mount the archive and verify the signature and checksum easily with:

    mkdir mnt/ && squashfuse archive.sqsh mnt/ && mnt/
    signify -Cx checksum.sig -p ~/key.pub
