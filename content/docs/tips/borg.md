---
title: BorgBackup
weight: 10
---

# BorgBackup

## Pull-mode backups

Usually, a client pushes new backups to a repository. That means the client initiates the
connection and obviously needs to be able to access it at any time. Sometimes, you may
wish to initiate a backup from the "server" that holds the repository, if that direction
is easier. For example, you might want to create backups of a VPS and store it on a
server at home, which is behind a NAT etc.

{{< hint info >}}
This is based on the [deployment docs about "pull mode" in borgbackup/borg](https://github.com/borgbackup/borg/blob/1e7c1414b030b3dd09c7daa451a2e078328ce4fc/docs/deployment/pull-backup.rst#socat).
{{< /hint >}}

### Wrap `borg serve` with `socat`

The server holding the repository can start `borg serve`, which communicates over standard
input and output. Normally this is started as part of an SSH command, so there is no
special argument to make it listen on a socket instead. Luckily, `socat` can do that
for us:

    socat UNIX-LISTEN:/tmp/borg.sock,fork \
      EXEC:"borg serve --append-only --restrict-to-repository /path/to/repository"

The deployment docs go into a little more detail about permissions on the socket. If
you have multiple repositories and concurrently running jobs, you should probably use
temporary directories within `/tmp` with proper permissions.
    
{{< hint warning >}}
The ["append-only" mode is confusing](https://github.com/borgbackup/borg/issues/3504) in borg –
it probably does not do what you think it does.

It does **not** prevent that a client can issue deletions or prune old archives. Instead it
just keeps a transaction log on the server, so that you could *undo* these deletions.
**However**, you first need to find out *that* and *when* you were compromised, which does
not seem to be trivially easy at this point.
{{< /hint >}}

### Forward the socket

Next, forward this socket to the "client" machine which has the data you want to
backup:

    ssh -R /run/borg.sock:/tmp/borg.sock vps.example.com
    
You probably won't be able to use `/run/borg.sock` when you're not running as root remotely;
adjust accordingly.

{{< hint info >}}
In order to make the SSH server clean up "dangling" sockets, which could prevent a forwarding
you can add `StreamLocalBindUnlink yes` to the client's `/etc/ssh/sshd_config`.
{{< /hint >}}

### Connect to the socket interactively

If you ran the above interactively, you can now tell borg how to use this forwarded
socket and connect to it, either using the `--rsh` flag or `BORG_RSH` environment variable.
This command is what borg executes when it usually connects to a remote server over SSH;
again `borg` wants to communicate with standard input and output of this command and expects
a `borg serve` on the other end. So you can either wrap `socat` again or use the simpler
`nc` in this case.

The path to the repository needs to "look" like an `ssh://` path for borg to use the
RSH command. The hostname can obviously be anything you want but the path needs to match
the path to the repository on the server (as given above for `borg serve`).

    BORG_RSH="sh -c 'exec nc -U /run/borg.sock'" \
      borg list ssh://pullsock/path/to/repository
      
### Automate it with environment variables

If at this point you try the "all-in-one" command from the docs above, it won't work
because `ssh` will mangle the commandline and won't properly pass the `--rsh` flag in
one piece. You can escape that with `printf '%q'` or `${cmd@Q}` if you like.

Instead – and if you want to pass an encryption password you should do this anyway –
I propose to put everything in environment variables locally and forward them properly
with SSH. This requires that the `sshd` server on the "client" accepts the variables,
so adjust `AcceptEnv` accordingly:

    # Allow client to pass certain environment variables
    AcceptEnv LANG LC_* BORG_*

Now you can put everything in `BORG_*` environment variables [as usual](https://github.com/borgbackup/borg/blob/c88a37eea430d7ec2e5da1ae503e43519ee90cb1/docs/quickstart.rst#automating-backups)
and use SSH with `-o SendEnv="BORG_*"` like so:

```bash
export BORG_RSH="sh -c 'exec nc -U /run/borg.sock'"
export BORG_REPO="ssh://pullsock/path/to/repository"
export BORG_PASSPHRASE="MySuperSecurePassphrase"

ssh -o SendEnv="BORG_*" -R /run/borg.sock:/tmp/borg.sock vps.example.com \
  borg create ::{hostname}-{now} /path/to/data
```

Putting everything together in a script is left as an exercise to the reader. :P
