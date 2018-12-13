---
title: OpenSSH + OATH-TOTP
date: 2016-03-24
draft: false
toc: true
tags:
  - linux
  - openssh
  - security
---

I dug a little further after my last [post] and stumbled upon [this] excellent blog post. It turns out that using the libpam-oath module for two-factor authentication is a lot easier than the challenge-response module and it works rather fabulously.

I will document the steps I took here. Again, all credit goes to the author of that blog post above - I mainly followed his explanations and links.

[post]: https://www.semjonov.de/openssh-yubikey/ "OpenSSH + YubiKey challenge-response"
[this]: https://blog.kallisti.net.nz/2013/09/yubikey-logins-with-ssh/ "blog.kallisti.net.nz: Yubikey Logins with SSH"

---
### What we are going to do

We want to enable two-factor authentication when logging in via ssh. The two factors in this case mean that you need something _you know_ and something _you have_, i.e. your user's password and your YubiKey or any other device or app capable of generating OATH-TOTP tokens.

OATH-TOTP is an Open Authentication standard, where [TOTP] stands for "Time-based One-time Password Algorithm". Basically, that is a password which is generated from a secret key and a changing timestamp by means of hashing. The secret key is saved on your YubiKey or in the app, thus making it something _'you have'_.

We will then use both our unix password and this changing one-time password to login. You'll probably still want to use pubkey auth for the most part. But this is a great fallback option in case you lose or don't have access to your private keys.

[TOTP]: https://en.wikipedia.org/wiki/Time-based_One-time_Password_Algorithm "Wikipedia article on OATH-TOTP"

---

The following steps were performed on a server running Debian 'Jessie' 8 and using a YubiKey NEO + Yubico Authenticator app.

### Install packages

As stated above, these commands are for Debian Jessie but I assume these packages are available for many other systems too. We need:

+ `libpam-oath`: the PAM module itself, asking for our one-time password
+ `oathtool`: debugging and testing our tokens
+ `libmime-base32-perl`: for converting our generated token to base32

```
# apt-get install libpam-oath oathtool libmime-base32-perl
```

### Configure Yubikey / app of choice

For the sake of simplicity I will assume that your YubiKey is already set up for use with one-time passwords. The combination with Yubico's [Android app] works well for me and can be used with any service that supports two-factor auth with TOTP, e.g. GitHub and Dropbox, and any number of services. This requires a YubiKey NEO with enabled CCID applet. There is a [guide] by Yubico on how to do that.

If you don't have a YubiKey you can also use the [Google Authenticator] but there are, of course, many more choices ..

[Android app]: https://play.google.com/store/apps/details?id=com.yubico.yubioath "Google Playstore: Yubico Authenticator"

[guide]: https://developers.yubico.com/yubikey-neo-manager/Usage.html "YubiKey NEO manager"

[Google Authenticator]: https://play.google.com/store/apps/details?id=com.google.android.apps.authenticator2 "Google Playstore: Google Authenticator"

### Setting up the PAM module

We need to setup the libpam-oath module, so it is used together with our password when we login. This is done in `/etc/pam.d/sshd` for the OpenSSH daemon.

> __Make sure__ that you have a root console still open at this point in case something goes wrong. Breaking ssh login without an active session can be a massive pain.

By default `common-auth` is included at the very top of the file. We'll want to change this, as simply adding the oath module after the include leaks information about our password: if the password is incorrect, you don't get asked for the OATH token. This is described in more detail in step 5 [here][mikeboers].

[mikeboers]: http://mikeboers.com/blog/2011/05/28/one-time-passwords-for-ssh-on-ubuntu-and-os-x

We add `auth required pam_oath.so options..` and end up with something like this:

```
# PAM configuration for the Secure Shell service

# ask for unix password
auth required pam_unix.so nullok_secure

# ask for one-time password
auth required pam_oath.so usersfile=/etc/ssh/usertokens

# Standard Un*x authentication.
#@include common-auth
[..]
```

You may choose your usersfile freely but it should be only readable by root! Unfortunately, there does not seem to be a way to define a users home directory here, like it is done with the authorized_keys file for pubkey auth.
```
# chmod 600 /etc/ssh/usertokens
```

Possible options for this module are documented [here](http://www.nongnu.org/oath-toolkit/pam_oath.html).

### Configuring the OpenSSH daemon

In your `/etc/ssh/sshd_config` you need to enable `ChallengeResponseAuthentication` and `UsePAM`. The former is needed so PAM modules can ask you for password and one-time token separately. Also, you may want to define your `AuthenticationMethods` to allow either successful publickey auth OR two-factor auth with passwords. You can find my entire OpenSSH configuration [here][gitlab].

[gitlab]: https://git.semjonov.de/server/sshd "GitLab: server/sshd"

```
UsePAM yes
ChallengeResponseAuthentication yes
AuthenticationMethods publickey keyboard-interactive:pam
```

To apply changes, restart the ssh daemon: `# systemctl restart ssh.service`

### Generate and transfer secret key

__Note:__ Please generate your own key and do not use the examples from this post.

Now we need to generate the secret keys, associate them to a user and transfer them to our authenticator app of choice. First, generate some random hexadecimal key:

```
$ head -c 1024 /dev/urandom | openssl sha1 | tail -c 41
7f8997212e9fff4e66f601dd40b958ad6d084de1
```

Write this key into the usersfile at `/etc/ssh/usertokens` in the above example:

```
HOTP/T30 username - 7f8997212e9fff4e66f601dd40b958ad6d084de1
```

The `HOTP/T30` means, that we use OATH-TOTP with 30 second steps and this is the secret key for the user `username`.

For use with our TOTP app we need to convert our hexadecimal key to base32:

```
$ perl -e 'use MIME::Base32 qw( RFC ); print lc(MIME::Base32::encode(pack("H*","7f8997212e9fff4e66f601dd40b958ad6d084de1")))."\n";'

p6ezoijot77u4zxwahoubokyvvwqqtpb
```

Now add this key (`p6ezoijot77u4zxwahoubokyvvwqqtpb`) to your authenticator app of choice. This is described in great detail for various YubiKeys and the example of Dropbox [here][addkeys].

[addkeys]: https://www.yubico.com/why-yubico/for-individuals/how-to-use-your-yubikey-with-dropbox/ "How to use your YubiKey with Dropbox"

After you have added the new account you can verify the next few one-time passwords using `oathtool`. The passwords you see in your authenticator app should match the ones oathtool prints out using your original hexadecimal key:

```
$ oathtool --totp -w10 7f8997212e9fff4e66f601dd40b958ad6d084de1
883695
430045
135583
[..]
```

### Try it

If you can't authenticate with pubkey auth (move or rename it, so ssh can't find it) you'll be asked for your unix password and your current TOTP, which you need to get from your authenticator app:

```
$ ssh user@host -v

[..]
debug1: Authentications that can continue: publickey,keyboard-interactive
debug1: Next authentication method: publickey
debug1: Next authentication method: keyboard-interactive
Password: 
One-time password (OATH) for `user': 
debug1: Authentication succeeded (keyboard-interactive).
Authenticated to host ([ip]:port).
[..]
```

Et voilÃ . You can now login to your server from anywhere you want based on two-facor authentication, which makes it a lot more secure than password authentication alone.

