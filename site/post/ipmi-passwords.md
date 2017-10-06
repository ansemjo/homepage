---
title: Truncated IPMI Passwords
date: 2017-04-06
draft: false
toc: false
categories:
  - blog
  - technology
tags:
  - virtual-machines
  - security
---

__tl;dr:__ webui truncates new passwords to 19 chars

<!--more-->

I used KeePassX to generate a new, 24 character password with all character types enabled. This was supposed to replace the default `ADMIN/ADMIN` combination for IPMI on my ESXi box. So I opened the appropriate page through a browser, navigated to `Configuration > Users` and modified the ADMIN user.

It happily accepted the new password with no warning whatsoever and I logged out to test it .. oh well .. it didn't work.

While poking around for a way to reset the password, I found this article: [Supermicro IPMI – password vulnerability](http://kbdone.com/supermicro-ipmi-password-vulnerability/). The mentioned port is closed in my firmware, so I've got that going for me. Reading on, I found out that IPMI truncates long passwords entered through the web administration page.

Gah! My Samsung printer does that too .. whoever thought this was a great idea?! Anyway. Use the first __19__ characters of whatever password you've set through the web interface and you'll be allowed back in.


