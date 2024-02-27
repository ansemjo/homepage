---
title: Tor
weight: 10
---

# Tor

## Local SOCKS Proxy

Running a local Tor client / proxy is currently the default if none of `ORPort`, `DirPort` or
`ControlPort` are defined.

Since most distributions should ship a default config with those commented out you only need to
download / install `tor` and start it. A possible obstacle is the configured `DataDirectory` if you
want to run it as an unprivileged user. In this case use this simple configuration:

```
SocksPort 9050
Log notice stderr
DataDirectory ~/.local/share/tor
```

Start `tor` with `tor -f ~/.config/torrc` or where-ever you saved that config.
