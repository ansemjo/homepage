---
title: Arduino / AVR
weight: 10
---

# Arduino / AVR

## Flashing over ISP header

Recently I had the need to program an Arduino that was not responding over USB,
i.e. the bootloader was probably broken somehow. I wrote a [blog entry][blog] about that.

[blog]: https://semjonov.de/post/2019-11/flash-arduino-without-a-bootloader-from-a-raspberry-pi/

The usual ISP header on an Arduino is mapped like this:

```
     ┏─────╮
MISO │ 1 2 │ VCC
 SCK │ 3 4 │ MOSI
 RST │ 5 6 │ GND
     ╰─────╯
```

### Sparkfun FTDI FT232R Breakout Board

The FT232R provides a straightforward ["bit-bang" mode][bitbang] to drive these pins. Some
breakout boards come with an ISP header directly soldered on but you can also just use the
breadboard pins on a full breakout. I'm using a Sparkfun FT232R Breakout to do this.

[bitbang]: https://www.ftdichip.com/Support/Documents/AppNotes/AN_232R-01_Bit_Bang_Mode_Available_For_FT232R_and_Ft245R.pdf

These are the pins of a FT232R which correspond to the above ISP header:

```
     ┏─────╮
 CTS │ 1 2 │ VCC
 DSR │ 3 4 │ DCD
  RI │ 5 6 │ GND
     ╰─────╯
```

On the bottom of the Sparkfun breakout the legs are mapped like this:

```
         USB
┏───────────────────╮
│ ■ DCD     PWREN □ │
│ ■ DSR     TXDEN □ │
│ ■ GND     SLEEP □ │
│ ■ RI        CTS ■ │
│ □ RXD      V3.3 □ │
│ □ VCCIO     VCC ■ │
│ □ RTS     RXLED □ │
│ □ DTR     TXLED □ │
│ □ TXD       GND □ │
│      □ □ □ □      │
╰───────────────────╯
```

This configuration should come shipped with a decently modern `avrdude` version
already. If it's not, here is a copy:

```
# see http://www.geocities.jp/arduino_diecimila/bootloader/index_en.html
# Note: pins are numbered from 1!
programmer
  id    = "arduino-ft232r";
  desc  = "Arduino: FT232R connected to ISP";
  type  = "ftdi_syncbb";
  connection_type = usb;
  miso  = 3;  # CTS X3(1)
  sck   = 5;  # DSR X3(2)
  mosi  = 6;  # DCD X3(3)
  reset = 7;  # RI  X3(4)
;
```

Using `avrdude` like this is said to be slower than other methods but in my testing it
turned out to be decently quick -- not "minutes" like some comments suggest anyway.

    avrdude -c arduino-ft232r -p m328p -v


### Adafruit FTDI FT232H Breakout Board

Even better, the FT232H provides a proper MPSSE SPI interface. I mentioned above that
bit-banging is said to be slower but I didn't perceive it as too bad. Oh it *does* make
a difference! Performing a simple benchmark with successive readout and writebacks of
the `eeprom` and `flash` areas on an Arduino Nano clone took **16 seconds** using the
FT232H while it took over **two minutes** on the FT232R.

Looking from the top, the pins on the Adafruit board are used like this:

```
        USB
┏──────────────────╮
│ ■ 5V        C9 □ │
│ ■ GND       C8 □ │
│ ■ D0 SCK    C7 □ │
│ ■ D1 MOSI   C6 □ │
│ ■ D2 MISO   C5 □ │
│ ■ D3 RST    C4 □ │
│ □ D4        C3 □ │
│ □ D5        C2 □ │
│ □ D6        C1 □ │
│ □ D7        C0 □ │
╰──────────────────╯
```

The pins are all nicely in one row, so you can easily craft a custom cable, too.

![](/assets/ft232h.png)

The `avrdude` config was first described on [helix.air.net.au][helix] and is now integrated in the
systemwide config as programmer `UM232H`:

[helix]: http://www.jdunman.com/ww/AmateurRadio/SDR/helix_air_net_au%20%20AVRDUDE%20and%20FTDI%20232H.htm "Mirror"

```
# UM232H module from FTDI and Glyn.com.au.
# See helix.air.net.au for detailed usage information.
# /* ... */
# Use the -b flag to set the SPI clock rate eg -b 3750000 is the fastest I could get
# a 16MHz Atmega1280 to program reliably.  The 232H is conveniently 5V tolerant.
programmer
  id         = "UM232H";
  desc       = "FT232H based module from FTDI and Glyn.com.au";
  type       = "avrftdi";
  usbvid     = 0x0403;
  usbpid     = 0x6014;
  usbdev     = "A";
  usbvendor  = "";
  usbproduct = "";
  usbsn      = "";
#ISP-signals
  sck    = 0;
  mosi   = 1;
  miso   = 2;
  reset  = 3;
;
```

I've created two straightforward programmer aliases in my `~/.avrduderc` config and
can use these two breakout boards with `avrdude -c ft232r` and `avrdude -c ft232h`
respectively:

```
# alias for adafruit ft232h
programmer parent "UM232H"
  id         = "ft232h";
  desc       = "Adafruit FT232H based SPI programmer";
;

# alias for sparkfun ft232r breakout
programmer parent "arduino-ft232r"
  id         = "ft232r";
  desc       = "Sparkfun FT232R breakout bit-banging";
;
```

### Raspberry Pi

At the time, however, I used the GPIO pins on a Raspberry Pi Zero W and amended the
`avrdude` configuration to use bit-banging as well. Here is a possible
mapping of the GPIO pins on the 40-pin header:

```
                15 ┆ · · ┆ 16
          3.3V  17 │ x · │ 18
(GPIO 10) MOSI  19 │ x x │ 20  GND
(GPIO 09) MISO  21 │ x x │ 22  Reset (GPIO 25)
(GPIO 11) SCLK  23 │ x · │ 24
                25 ┆ · · ┆ 25
```

This wiring can be used with the following `avrdude` programmer configuration:

```
# avr programmer via linux gpio pins
programmer
  id    = "gpio";
  desc  = "Use the Linux sysfs to bitbang GPIO lines";
  type  = "linuxgpio";
  reset = 25;
  sck   = 11;
  mosi  = 10;
  miso  = 9;
;
```

Put that in `~/.avrduderc` or a seperate file, which can be included with
`avrdude -C +gpio.conf ...`. Now use this programmer config like this:

    sudo avrdude -c gpio -p m1284p -v

