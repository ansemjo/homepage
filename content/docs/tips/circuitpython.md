---
title: CircuitPython
weight: 10
---

# CircuitPython

> CircuitPython is a programming language designed to simplify experimenting
> and learning to code on low-cost microcontroller boards.

https://circuitpython.org/


## QT Py with Winbond 16MB Flash Chip

I bought a couple of [QT Py](https://learn.adafruit.com/adafruit-qt-py) boards to
experiment and play with them. They com with a nice bootloader which enabled you
to update the firmware simply by copying a file to a virtual disk device over USB.

They also have a footprint for SPI Flash chips on their underside. This can be used
as a filesystem in CircuitPython, which greatly extends the available storage for your
programs and possibly logged data, etc. From a previous tinkering attempt with OpenWRT
routers I had a couple of [Winbond W25Q128JVSIQ](https://www.digikey.de/product-detail/de/winbond-electronics/W25Q128JVSIQ/W25Q128JVSIQ-ND/5803943)
16MB chips still around.

Now, there are two firmwares for the QT Py: the "normal" one that comes shipped on
the board and uses remaining space on the internal flash for storage. And then there's
a ["Haxpress" variant](https://circuitpython.org/board/qtpy_m0_haxpress/), which is built
with support for the GD25Q16 chips that you can buy from Adafruit. Sadly, simply flashing
the latter and hoping for it to "automagically" detect my different flash chip did not
work. But don't fret, CircuitPython already has builtin [support for many different devices][devices]!
You just need to enable the correct one and build a firmware yourself.

[devices]: https://github.com/adafruit/circuitpython/blob/main/supervisor/shared/external_flash/devices.h

### Building the Firmware

Instructions for building are given in [BUILDING.md][building] of the [CircuitPython repository][repo].

First, prepare the cloned repository by initializing submodules and compiling the
required `mpy-cross`:

```
git submodule sync
git submodule update --init   # this takes a while!
make -C mpy-cross/
```

Now check that your flash chip is already supported in the above `devices.h` file.
Mine was already supported through a very similar chip of the same family:
`W25Q128JV_SQ`. A comment in an issue on GitHub pointed me in the correct direction
then. You need to edit `ports/atmel-samd/boards/qtpy_m0_haxpress/mpconfigboard.mk`
and set `EXTERNAL_FLASH_DEVICES` to the correct chip definition:

```diff
diff --git a/ports/atmel-samd/boards/qtpy_m0_haxpress/mpconfigboard.mk b/ports/atmel-samd/boards/qtpy_m0_haxpress/mpconfigboard.mk
index 8773c5771..10b018938 100644
--- a/ports/atmel-samd/boards/qtpy_m0_haxpress/mpconfigboard.mk
+++ b/ports/atmel-samd/boards/qtpy_m0_haxpress/mpconfigboard.mk
@@ -10,7 +10,7 @@ INTERNAL_FLASH_FILESYSTEM = 0
 LONGINT_IMPL = MPZ
 SPI_FLASH_FILESYSTEM = 1
 EXTERNAL_FLASH_DEVICE_COUNT = 1
-EXTERNAL_FLASH_DEVICES = GD25Q16C
+EXTERNAL_FLASH_DEVICES = W25Q128JV_SQ
 
 CIRCUITPY_AUDIOBUSIO = 0
 CIRCUITPY_BITBANGIO = 0
```

Finally, just enter the build directory of your port and run `make`:

```
cd ports/atmel-samd
make BOARD=qtpy_m0_haxpress -j$(nproc)
```

The built firmware will be in `build-qtpy_m0_haxpress/firmware.uf2` and can be uploaded
to the board just like you would with the official ones: a quick double-press of the
reset switch and simply copy the file to the virtual disk that pops up.

I [have attached][firmware] a built firmware with the above modification.

[building]: https://github.com/adafruit/circuitpython/blob/main/BUILDING.md
[repo]: https://github.com/adafruit/circuitpython/
[firmware]: /assets/cpy-v1.9.4-9810-g6a76b6002-qtpy_m0_haxpress-W25Q128.uf2
