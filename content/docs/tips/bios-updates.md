# BIOS Updates

## Lenovo Laptops from Linux

Some modern Lenovo machines do not have an optical disc drive. The only option
for machines without Windows is a bootable .iso image though. What now?

Turns out inside that image there is another bootable format: an El Torito
image. You can extract that with a script called
[`geteltorito.pl`](/assets/geteltorito.pl) and flash it to a USB stick.

```shell
# ./geteltorito.pl -o n10ur17w-usb.img n10ur17w.iso
Booting catalog starts at sector: 20
Manufacturer of CD: NERO BURNING ROM
Image architecture: x86
Boot media type is: harddisk
El Torito image starts at sector 27 and has 47104 sector(s) of 512 Bytes

Image has been written to file "n10ur17w-usb.img".
# dd if=n10ur17w-usb.img of=/dev/sdb bs=1M
23+0 records in
23+0 records out
24117248 bytes (24 MB, 23 MiB) copied, 0.354471 s, 68.0 MB/s
```

!!!note
    This information and script is taken from
    [thinkwiki.de](http://thinkwiki.de/BIOS-Update_ohne_optisches_Laufwerk_unter_Linux)

## Supermicro Boards via IPMI

On boards that include the IPMI remote management feature you can just
upload the firmware file in the web interface. Easy peasy.

## Supermicro Boards with UEFI

On other boards you'll need to create a bootable USB stick with the BIOS
updater. With UEFI there's an easier way though. This is info and the script
below come from the [Thomas Krenn Wiki](https://www.thomas-krenn.com/de/wiki/BIOS_Update_per_UEFI_an_Supermicro_Mainboards_durchf%C3%BChren).

* create a USB stick with a FAT32 partition; it doesn't need to be bootable but
  using a GPT partition table and marking the partition as "EFI System" seems
  to help
* extract the [flash script (`flash.tar`)](/assets/smcflash.tar) to this
  partition; these files are from an X10DRI BIOS update package
* copy the downloaded firmware file for you motherboard to the partition
* reboot the server; maybe use the "Reboot with ME disable" mode to enable
  updates to the Management Engine
* use the boot menu to enter the "Built-in EFI Shell"
* navigate to your USB stick; that should be `fs0:` ...
* start the update with `flash.nsh {updatefile}`
