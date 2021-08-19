---
title: GnuPG
weight: 10
---

# GnuPG

## Use as ssh-agent on Gnome

In order to use the gpg-agent's builtin ssh agent, you need to inhibit
the default gnome-keyring-daemon and set `SSH_AUTH_SOCK` to the correct
path. First disable the default keyring agent:

    cat /etc/xdg/autostart/gnome-keyring-ssh.desktop <(echo "Hidden=true") \
      > ~/.config/autostart/gnome-keyring-ssh.desktop'

Then place the following in `~/.config/systemd/user/ssh-auth-sock.service` and
do the usual `systemctl --user daemon-reload && systemctl --user enable --now ssh-auth-sock`
dance. (See [here](https://git.gnome.org/browse/gnome-session/tree/gnome-session/main.c?h=3.24.0#n419) on why we need the `GSM_SKIP_SSH_AGENT_WORKAROUND`).


```systemd
[Unit]
Description=Set SSH_AUTH_SOCK to GnuPG agent

[Service]
Type=oneshot
ExecStart=/usr/bin/bash -c 'systemctl --user set-environment \
  SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket) \
  GSM_SKIP_SSH_AGENT_WORKAROUND="true"'

[Install]
WantedBy=default.target
```

You might also need to add this to your `~/.bashrc` or similar:

    echo UPDATESTARTUPTTY | gpg-connect-agent >/dev/null

Then logout or reboot.

