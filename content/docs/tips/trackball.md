---
title: Trackballs
weight: 10
---

# Trackballs

List of trackballs that I owned / used:

| Name | Notes |
|:-----|:------|
| Logitech M570 | Trusty friend, left mouse button needed to [be fixed](#fix-the-microswitches) a lot. |
| Kensington Expert | It's huuge! Scrollwheel is a little awkward but the precision is great and it forces you to move your wrist. |
| Logitech ERGO M575 | Not sure what is particularly "ergo" about it, almost identical to M570. Nicer finish though. |
| Perixx PERIPRO-303 | Not a mouse but a 34 mm replacement ball that fits the Logitechs. Lots of colours. |

## Button Scrolling

If you have either a very large trackball (think Kensington Expert) or an older model
without a wheel (e.g. Logitech Marble) you may want to use the ball itself to scroll.
This is the so-called "scrollwhell-emulation" mode, where you press and hold a button
to use the vertical trackball axis to scroll. However, even if you have a thumb-operated
ball, this might be preferrable in some situations, especially if you need to scroll
long distances.

### With `xinput`

In an Xorg session you can simply use `xinput` to set properties on your input devices. It
can be a little tricky to find the right property to set, however. The following command will
enable the button scrolling method with the middle mouse button on my Logtech M575:

    xinput set-prop "Logitech ERGO M575" "libinput Scroll Method Enabled" 0 0 1

### On Wayland

On Wayland sessions, however, `xinput` only sees virtual devices, so you can't use it
to set properties directly on the mouse. The `libinput` documentation gave me a little
bit of a runaround by saying "Use the configuration tool provided by your desktop environment
(e.g. gnome-control-center)" -- but the control center does not expose this option!

A first lead pointed to setting environment variables in `/etc/udev/hwdb.d/` -- but again:
what would be the correct option to set?! After a lot of searching I found that you can
set `ID_INPUT_POINTINGSTICK=1` and get the desired scroll behaviour. Annoyingly, this also
changed sensitivity and acceleration defaults because you just made your trackball a trackpoint.

Finally I found a key that can be configured via `dconf` in
`/org/gnome/desktop/peripherals/trackball/`: `scroll-wheel-emulation-button`.
It takes a number between 0 and 24, so what is the right option here? The
[switch-case statement][switchcase] expects `1` for the left mouse button, `2` for
the middle mouse button and `3` for the right mouse button. A setting of `0` disables the
behviour. *Ah, finally!*

    dconf write /org/gnome/desktop/peripherals/trackball/scroll-wheel-emulation-button 2

Not quite! My Logitech ERGO M575 was not properly classified as a trackball -- only as a mouse!
So apparently this setting was never applied. You can check the classification by checking
the output of `udevadm info /sys/class/input/event...`. The solution in my case was to use
the above hwdb method with the following configuration file:

    # /etc/udev/hwdb.d/70-mouse.hwdb
    mouse:*:name:Logitech ERGO M575:
      ID_INPUT_TRACKBALL=1

Update the database with `systemd-hwdb update`, replug the dongle *et voilà!*

[switchcase]: https://gitlab.gnome.org/GNOME/mutter/-/blob/63d969537f1dba623c1827cf0070ee6b4dfefee2/src/backends/native/meta-input-settings-native.c#L392


## Cleaning

Only clean the muck off the bearings with a dry brush or a small cloth. **Never** use alcohol
on the bearings or the ball unless *really* necessary. I believe I destroyed the bearings on
my first M570 by cleaning them too hard or often, until the ball would no longer glide easily
and become sticky and "jump".

## Fix the Microswitches

The left mouse button started to double-click at some point due to wear (the first time after
~ 2 years). If you open up the mouse you can unclip the top part of the microswitch housing
(*make sure you don't loose the small white piece!*) and then use tweezers to take out and
re-tighten the spring by bending it out a little further.

This is certainly not meant to be a user-serviceable part and you can easily break the spring
or fail to assemble it correctly afterwards. But it saved me from buying a new mouse two or three
times in the M570's lifetime.
