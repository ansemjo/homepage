---
title: OpenSSH + YubiKey HMAC-SHA1 challenge-response
date: 2016-03-23
draft: false
toc: true
categories:
  - blog
  - technology
tags:
  - linux
  - openssh
  - security
---

_First off: this does __not__ work as I wanted it to work .. it has some interesting implications though._

## The idea

I am using a YubiKey NEO for various things. It holds my [PGP keys] in its secure element and has the YubiKey slots configured to use HMAC-SHA1 challenge response and static password. You can for example unlock your KeePass(X) database using [OATH-HOTP] or the [challenge-response] mechanism.

The idea was to use the [PAM module] in its challenge-response mode for authentication during SSH logins. This is certainly possible for Yubico OTP mode, as described in the above link to the PAM module, but it does not appear to be possible using challenge-response mode without patches to OpenSSH. It would enable me to login from unknown computers, where I have no ssh keys, based on something 'I know' (the users password) and something 'I have' (the YubiKey). I'd say this would be an adequately secure alternative to pubkey authentication.

[PGP keys]: https://www.semjonov.de/key/ "Contact me"

[OATH-HOTP]: https://www.yubico.com/applications/password-management/consumer/keepass/ "OATH-HOTP support in the Windows version of KeePass"

[challenge-response]: https://aur.archlinux.org/packages/keepassx2-yubikey-git/ "KeePassX2 with support for HMAC-SHA1 in the AUR"

[PAM module]: https://developers.yubico.com/yubico-pam/ "Yubico developer site: yubico-pam"

## Actual setup

The reason why it doesn't work is that the module tries to find the Yubikey locally, i.e. on the server you are connecting to. There appears to be a [patch] for OpenSSH which enables similar functionality for U2F. I would like to stick to the official Debian packages though.

[patch]: https://github.com/Yubico/pam-u2f/issues/12 "Github: Yubico/pam-u2f, Issue #12"

So, in fact I did get it to work only when inserting the YubiKey into the machine you are SSH'ing into:

+ First, install the libpam-yubico package (this is for Debian, for other systems follow the developer site link above ..):
`$ apt-get install libpam-yubico`

+ This installs `ykpamcfg` as a dependency. We are going to use it to generate an initial response: `$ ykpamcfg -v` This only works if the YubiKey is inserted into the machine. _(I had to run this as root, so I copied the generated file to the appropriate users home afterwards. Also, supply the `-2` option if your HMAC-SHA1 is configred on slot 2. See `$ man ykpamcfg` for details.)_

+ As per the documentation, the proper default path for this generated file is `~/.yubico/challenge-SERIALNO`, where `SERIALNO` is the decimal serial of your Yubikey.

+ Ensure that you have the yubico-pam module in the appropriate path. For Debian it was already installed into `/lib/security/pam_yubico.so` by the package installer.

+ Include it as a requirement in your PAM configuration for sshd (`/etc/pam.d/sshd`) above the `@include common-auth` line: `auth required pam_yubico.so mode=challenge-response debug`

+ Configure your OpenSSH daemon to use this PAM authentication .. based on my previous [sshd configuration], I changed the `AuthenticationMethods` option to read: `AuthenticationMethods keyboard-interactive:pam #publickey`, thereby disabling pubkey authentication! So be careful to always have a root console still open.

+ Restart sshd (`$ systemctl restart ssh.service`) and try it out.

[sshd configuration]: https://git.semjonov.de/server/sshd "GitLab: Server/sshd"

## bottom line

As written above, this only works when the YubiKey is inserted into a USB slot on my NAS which I am connecting to. I have to press the button on the YubiKey once I start connecting and then enter my password in the terminal afterwards.

It is not what I intended to do but I believe it is an interesting fallback method, when enabled in logical OR with publickey auth. The fact that it requires a YubiKey makes it vastly more secure than a password alone, so you don't leave your Server 'open' to attacks.

I might look into possibilities with OATH-HOTP with sshd in the future ... I refuse to use the Yubico OTP functionality for this, as it either required authentication by the Yubico Servers or installation of an additional local server. Also I lose the possibility to unlock my KeePassX databse then. :)
