---
title: Set up 2FA app for PayPal
description: the option to add TOTP security keys on PayPal is somewhat hidden, it uses Verisign Identity Protection provisioning
date: 2018-03-03T15:17:00+01:00

draft: false
toc: true

categories:
  - blog
  - guide

tags:
  - 2fa
  - security
---

It is becoming common knowledge that you should use two-factor authentication
whenever possible. Some services allow the use of TOTP apps on your smartphone,
some only want so send you SMS codes .. and others use proprietary tokens.

<!--more-->

I had activated SMS codes with PayPal for a while now but I always had the urge
to centralize all my 2FA codes in my [FreeOTP] app. Sites like GitHub, Backblaze
and Dropbox all easily support this. However, PayPal always appeared to only support
SMS codes. Then I stumbled upon [this blog post] saying otherwise. I'll summarize
the necessary steps below.

[FreeOTP]: https://freeotp.github.io/
[this blog post]: https://medium.com/@dubistkomisch/set-up-2fa-two-factor-authentication-for-paypal-with-google-authenticator-or-other-totp-client-60fee63bfa4f

# Preparations

## Install `python-vipaccess`

[Apparently] the VIP Access tokens are based on the open TOTP standard, which is supported
by most authenticator apps. 

[Apparently]: https://www.cyrozap.com/2014/09/29/reversing-the-symantec-vip-access-provisioning-protocol
