---
title: SSH
weight: 10
---

# OpenSSH

The focus of this page is a secure, useful and modern OpenSSH configuration.
Some options require a version of at least 7.0 or newer and some secure defaults
in these newer versions are simply omitted.

{{< hint info >}}
Another very good compilation are [Mozilla's OpenSSH guidelines](https://infosec.mozilla.org/guidelines/openssh).
You can find more explanation for some of the choices there.
{{< /hint >}}

## Client `~/.ssh/config`

```
# keep connections alive
ServerAliveInterval 60
ServerAliveCountMax 2

# connection multiplexing
ControlPath /run/user/%i/sshmux-%r@%h:%p.sock
ControlMaster auto
ControlPersist 20m

# this is annoying with little benefit
HashKnownHosts no

# apply trust-on-first-use: accept new hostkeys
StrictHostKeyChecking accept-new

# add keys to agent when needed
AddKeysToAgent yes
IdentityFile ~/.ssh/my_custom_key

# use agent locally but don't forward (use jumphosts!)
ForwardAgent no
```

* `ControlPath`, `ControlMaster`, `ControlPersist`: Define a socket to use for multiplexing & reusing connections.
  The first connection creates a socket which stays up after the connection is closed; drastically reduces overhead
  of opening many new connections within a short timeframe.

* `StrictHostKeyChecking`: Trusting a server on first use is usually what you want because you seldomly
  have the "correct" key to check against. This setting `accept-new` still catches changed keys though!
  
* `AddKeysToAgent`: When using a key that is pointed-to with an `IdentityFile` option, add it to the agent
  for later use. Optionally change this to `confirm` or a time value for more security.

### Using an SSH agent

Use one! Try [keychain](https://www.funtoo.org/Keychain) if you don't know which one.

After some dabbling with the ssh-agent functionality of the GPG agent, I actually stick
to the default one started with `gnome-keyring-daemon` right now. The GPG agent is annoying
because it copies the key into your GPG homedir upon adding – effectively breaking the link
to the original OpenSSH key file. Also there was some issue with handling certificates, if
I remember correctly.

### Keep agent socket on `sudo`

If you use the agent and would like to keep the `SSH_AUTH_SOCK` variable when
becoming `root`, put this in your `/etc/sudoers`:

    Defaults>root env_keep += "SSH_AUTH_SOCK"

### Stricter Cryptography defaults

{{< hint warning >}}
This selection of ciphers, MACs and key exchange algorithms may make this
configurations **incompatible** with some older or proprietary clients! You may
have to allow some more with host-specific sections.
{{< /hint >}}

Provide very strong defaults, favouring `ed25519` where possible.

```
Host *

# use only authenticated ciphers
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com

# if other ciphers are enabled, restrict the auth codes to always use EtM
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,umac-128-etm@openssh.com

# prefer ed25519 keys and use rsa as fallback
HostKeyAlgorithms ssh-ed25519-cert-v01@openssh.com,sk-ssh-ed25519-cert-v01@openssh.com,rsa-sha2-512-cert-v01@openssh.com,rsa-sha2-256-cert-v01@openssh.com,ssh-rsa-cert-v01@openssh.com,ssh-ed25519,sk-ssh-ed25519@openssh.com,rsa-sha2-512,rsa-sha2-256,ssh-rsa

# mainly use curve25519 for key exchange, enable the post-quantum algo
KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group-exchange-sha256,sntrup761x25519-sha512@openssh.com
```


## Server `/etc/ssh/sshd_config`

{{< hint info >}}
Parts of this section are copied from the [Mozilla's OpenSSH guidelines](https://infosec.mozilla.org/guidelines/openssh).
{{< /hint >}}

*Note:* The actual used cipher/algorithm is decided by the first entry in the
client configuration's preference list which is also supported by the server.
Thus the order in the server's configration is not really important.

```
# only use this tiny key
HostKey /etc/ssh/ssh_host_ed25519_key

# see above, may be unnecessarily strict!
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com
KexAlgorithms curve25519-sha256@libssh.org,diffie-hellman-group-exchange-sha256
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,umac-128-etm@openssh.com
PubkeyAcceptedKeyTypes ssh-ed25519-cert-v01@openssh.com,sk-ssh-ed25519-cert-v01@openssh.com,ssh-ed25519,sk-ssh-ed25519@openssh.com

# only allow pubkey authentication
AuthenticationMethods publickey
PermitRootLogin prohibit-password

# be stricter with unauthenticated connections
LoginGraceTime 20
MaxStartups 10:50:20

# use kernel sandbox mechanisms where possible
UsePrivilegeSeparation sandbox

# log user's key fingerprints for audit trail
LogLevel VERBOSE

# sftp subsystem with file access logging
Subsystem sftp /usr/lib/ssh/sftp-server -f AUTHPRIV -l INFO
```

### Only use long moduli

All Diffie-Hellman moduli in use should be at least 3072-bit-long (they are used for
`diffie-hellman-group-exchange-sha256`) as per our Key management Guidelines recommendations.
See also `man moduli`.

Deactivate short moduli in two commands:

    awk '$5 >= 3071' /etc/ssh/moduli > /etc/ssh/moduli.tmp
    mv /etc/ssh/moduli.tmp /etc/ssh/moduli
    
Alternatively you can generate your own, too. Check the `MODULI GENERATION` section
of `man ssh-keygen`.
