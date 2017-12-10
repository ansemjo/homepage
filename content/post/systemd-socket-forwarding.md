---
title: On-Demand Socket Forwarding with Systemd
date: 2016-06-06
draft: false
toc: true
categories:
  - blog
  - notes
tags:
  - systemd
  - mysql
  - sockets
  - linux
---

Sooner or later when setting up a server you'll want to create some MySQL databses and users. If you're not proficient in writing SQL queries or just wanted to use a nice GUI tool for the task, you'd need to connect remotely to your databse host. But of course you do not want to expose your MySQL port to the internet ... Or suppose you want to debug some remote service, which is only accessible locally on the remote machine ...

<!--more-->

Either way, you will need some kind of port and/or __socket forwarding__, preferably by means of an SSH tunnel.


## A simple ssh tunnel

[socket forwarding]: https://lwn.net/Articles/609321/ "OpenSSH 6.7 will bring socket forwarding and more"
[possible]: man.openbsd.org/ssh "OpenSSH man page"

Current versions of OpenSSH allow [socket forwarding] in every [possible] combination right away, without the help of `socat` or similar tools.

[MariaDB]: https://mariadb.org/

Suppose you have [MariaDB] running with a default configuration on your server. That means MariaDB listens on `127.0.0.1` at port `3306`.

The following command would forward that port to your local machine:
```
$ ssh -L 3306:localhost:3306 myuser@your.server.com
```

_Note: in case it's not obvious .. replace 'myuser' and 'your.server.com' with your username and your server's FQDN respectively._

You can now open a second terminal and verify the forwarding works by inspecting `netstat -tlupn`'s output:

```
• ~ $ netstat -tulpn
Proto Recv-Q Send-Q Local Address       Foreign Address     State       PID/Program name    
...
tcp        0      0 127.0.0.1:3306      0.0.0.0:*           LISTEN      23080/ssh: /home/myuser
...
```

Or you know .. try connecting with `$ mysql -u root -p -h 127.0.0.1`.


## A simple socket forward

Now suppose you configured your MySQL database server to only listen on a unix socket and skip networking completely ...

```
[mysqld]
socket		= /run/mysqld/mysqld.sock
skip-networking
```

Modify the ssh command slightly and achieve the same result:
```
$ ssh -L 3306:/run/mysqld/mysqld.sock myuser@your.server.com
```

Okay, so that works ... but you need to keep your terminal window open the entire time or let ssh fork into the background. And more importantly, you need to do this every time you want to connect to your database! Sure, you could script that. But why not let systemd handle it for us?

## systemd.socket

[since 2010]: https://github.com/systemd/systemd/commit/1f812feafb4b98d5cfa2934886bbdd43325780bb
[manpage]: https://www.freedesktop.org/software/systemd/man/systemd.socket.html
[This post]: https://tilde.town/~cel/irc-socket-activation.html "IRC socket activation"

_I'm not sure since which version systemd has support for socket activation but the manpage has been there [since 2010], so chances are the following pieces will work for you, given you have a distribution with systemd._

Systemd gives us a tool to dynamically trigger services on a connection to a socket or port with systemd.socket. The [manpage] says:

> A unit configuration file whose name ends in ".socket" encodes information about an IPC or network socket or a file system FIFO controlled and supervised by systemd, for socket-based activation.

Ideally, we want to have a socket locally to which we can connect with out MySQL program or GUI of choice and 'magically' have a SSH tunnel established for this socket. [This post] gives some insight on how to do this, albeit with a different usecase.

__First__, make sure that you can connect via ssh with public keys and without a password, e.g. via an agent or by specifying an appropriate key on the commandline.

__Then__, we create two files in `~/.config/systemd/user/`. You might need to create the directory first with `$ mkdir -p ~/.config/systemd/user/`. Also, the 'user' in this path shall _not_ be replaced by your username, that is a literal 'user'.

##### `~/.config/systemd/user/mysqlsock.socket`
```
[Socket]
ListenStream=/home/myuser/.ssh/mysqlsock.socket
Accept=true

[Install]
WantedBy=sockets.target
```

##### `~/.config/systemd/user/mysqlsock@.service`
```
[Service]
ExecStart=/usr/bin/ssh -T -S none your.server.com 'nc -U /run/mysqld/mysqld.sock'
StandardInput=socket
```

In the first file, specify the location of the socket that you want to listen to with `ListenStream=`. You can also specify a port if you prefer. In the second file specify the ssh command to connect to the remote socket.

[socat]: http://www.ralf-lang.de/2011/11/22/using-socat-to-debug-unix-sockets-like-telnet-for-tcp/

This requires the `openbsd-netcat` to be installed on your server, to be able to use the `-U` option. Alternatively you can try using [socat]. Also, adjust the path to `mysqld.sock` if you have a nondefault configuration.

Finally, the `-S none` is there to disable use of multiplexing for this connection. While it might be desirable to have multiplexing if you open and close the connection rapidly and repeatedly, it can also lead to hard-to-diagnose problems.

__Reload__ your user's systemd instance with ..
```
$ systemctl --user daemon-reload
```
.. and start listening on the socket with ..
```
$ systemctl --user start mysqlsock.socket
```

You should notice that an appropriate socket appeared:
```
• ~ $ ls -l ~/.ssh/mysqlsock.socket
srw-rw-rw- 1 myuser users 0 Jun  6 02:53 /home/myuser/.ssh/mysqlsock.socket
```

Now you can try to connect to this socket. We'll first try with `netcat`:
```
• ~ $ nc -U ~/.ssh/mysqlsock.socket
Y
5.5.5-10.1.14-MariaDB<[W~75B/`��!?�xY6B':1%eP@0mysql_native_password
```
Not really readable. But you see that the connection apparently succeeded.

To make this persistent, enable the socket on boot:
```
$ systemctl --user enable mysqlsock.socket
```

#### _Update for ssh-agent:_

If you do not use your user's systemd instance but specify them as system-wide unit files, then when the systemd service is started by the socket, it has no knowledge of your `$SSH_AUTH_SOCK` and thus the ssh command within will fail with a denied pubkey. MySQL Workbench apparently interprets this as an offline server since you are using a local socket, 'fails' silently and tells you the server is shut off. You will probably see exit code 255 on your mysqlsock@... services when that happens.

Either stick to using per-user systemd units as shown above or alternatively we need to tell systemd where to find our ssh-agent by manually specifying the `SSH_AUTH_SOCK` environment variable. For this to work it obviously needs to be a fixed location. If you use Gnome's built-in ssh-agent aka. keyring this is usually `/run/user/$UID/keyring/ssh`. If you are using ssh-agent you can specify the desired socket on the commandline. So just add the line starting with `Environment=...` in your mysqlsock@.service and replace `$EUID` accordingly. _(You can find it simply with `$ echo $UID` or `$ id`)_

```
[Service]
Environment="SSH_AUTH_SOCK=/run/user/$UID/keyring/ssh"
ExecStart=...
StandardInput=socket
```

## Point your MySQL GUI to it

In my case I wanted to have an easy way to connect to my database hosts with 'MySQL Workbench' and with systemd.socket I finally achieved this goal.

![](/content/images/2016/06/Screenshot-from-2016-06-06-04-49-45.png)
