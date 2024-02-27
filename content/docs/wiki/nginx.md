---
title: nginx
weight: 10
---

# nginx

## Directory for ACME Challenges on CentOS

The ACME protocol that is used with certificate authorities like
LetsEncrypt uses a challenge mechanism to verify that the domain really
belongs to you. The basic `http-01` challenge expects a reply with a
specific content from your webserver. Certbot can place a file in a
directory in its manual "webroot" mode, which is then served by nginx.

### nginx Location

Use the following nginx location block to serve all ACME challenges from
a single directory under `/var/run`:

```nginx
location /.well-known/acme-challenge/ {
  default_type "text/plain";
  root /var/run/acme-challenge/;
}
```

### `tmpfiles.d` Config

This directory needs to exist of course. Because it is under `/var/run`, which
is typically a `tmpfs` mount -- i.e. not persistent across reboots -- I'll
use a configuration in `/etc/tmpfiles.d/` for this:

```
# webroot challenge directory for letsencrypt tools (acmetool, certbot, ..)
d /var/run/acme-challenge 0755 root root 1d -
```

Afterwards reboot or simply run `systemd-tmpfiles --create` to apply this change.

### SELinux Context

If you're running on CentOS or another Red Hat derivative and you have SELinux
enabled in enforcing mode, you'll need to change the directory context. Again,
because this is a temporary filesystem, this needs to be persistent; so a simple
`chcon` is not sufficient.

Use `semanage` to change the default SELinux type of this directory:

```
semanage fcontext -a -t httpd_sys_content_t /var/run/acme-challenge
restorecon -v /var/run/acme-challenge
```

Without this change, nginx will not be able to access the files in this
directory and the challenge will fail.

### Certbot Command

Now you should be able to get your certificates with `certbot`:

```
certbot certonly --webroot -w /var/run/acme-challenge -d example.com
```
