---
title: Install Ghost on an Arch VPS
date: 2016-04-29
draft: false
toc: true
tags:
  - linux
  - ghost
---

I recently got myself a small VPS from [Hetzner] to play around with. Using their 'rescue' function you can mount different installer images in the virtual disc drive and install the system via VNC or web console.

They provide an [Arch installer] too, so I chose that. I set up a very barebones system on a btrfs partition and with an nginx webserver.

To me, Arch seemed like an interesting choice for a webserver and so I cloned my [nginx config] from my nas and began to go through all the directives again and tidy up all the configs in the process, making as much as possible a global directive inside the `http { }` block.

[Hetzner]: https://www.hetzner.de/en/ "Hetzner Online GmbH"
[Arch installer]: https://www.archlinux.org/download/ "Download Arch Linux"
[nginx config]: https://git.semjonov.de/server/nginx-conf


# Setting up Ghost

__Update:__ There is also a package for Ghost in the [AUR](https://aur.archlinux.org/packages/ghost/) which also includes a patch to enable use of node.js 6 early on, thus making most of this guide obsolete. Check the config sections for some intersting bits though.

At one point I needed to have an app served through a socket to try some approaches for nginx config files. And I thought of Ghost as pretty straightforward possibility.

_I assume you have a basic nginx config up and running at this point._

## Create a seperate user

I wanted proper priviledge separation for Ghost. That means running everything related to ghost under a seperate user with no superuser rights.

Create a new user with a new homedir and give the webserver read access:
```
# useradd --system --create-home --home-dir /srv/ghostcms --gid webserver ghostcms
# chmod 750 ~ghostcms/
```
_(note that I set up nginx to run as user 'nginx' and with primary group 'webserver')_

## Download Ghost

We will now log in as `ghostcms` and download the latest Ghost release. Being a superuser / root it goes something like this:

```
# su ghostcms
```
_Depending on your default shell when adding a system user you might need to add `--shell /usr/bin/bash`._

Now download the latest zipped release and unpack it in the home folder. Note that the following commands are executed as the `ghostcms` user! Also, you might need to install `unzip` beforehand.

```
$ cd ~
$ curl -L https://ghost.org/zip/ghost-latest.zip -o ghost.zip
$ unzip ghost.zip && rm ghost.zip
```

Now your directory should look like this:
```
$ ls
content  core  config.example.js  Gruntfile.js  index.js  LICENSE  npm-shrinkwrap.json  package.json  PRIVACY.md  README.md
```

## Create your Ghost config

For production use, or if you want to configure Ghost to use a socket instead of the default localhost / port combination, you'll want to edit the default `config.example.js` in this folder and save it as `config.js`. There is some neat documentation [available]. We will just copy the example and edit it:

[available]: http://support.ghost.org/config/

```
$ cp config.{example.,}js
$ vi config.js
```

Substitute `vi` for your favourite editor here. I have it symlinked to `vim`. My rather minimal config for this test setup looks like this:

```
var path = require('path'),
    config;

config = {
    production: {
        url: 'https://your.domain.here',
        mail: {},
        database: {
            client: 'sqlite3',
            connection: {
                filename: path.join(__dirname, '/content/data/ghost.db')
            },
            debug: false
        },

        server: {
            socket: 'ghost.sock'
        }
    },
    development: {
        url: 'http://localhost:9999',
        mail: {},
        database: {
            client: 'sqlite3',
            connection: {
                filename: path.join(__dirname, '/content/data/ghost-dev.db')
            },
            debug: false
        },
        server: {
            host: '127.0.0.1',
            port: '9999'
        },
        paths: {
            contentPath: path.join(__dirname, '/content/')
        }
    },
};

module.exports = config;
```

Note the use of `socket: 'ghost.sock'` in the production server. Also, if you're going to configure an SMTP email account or mysql database access here, you might want to further restrict permissions on this file: `$ chmod 600 config.js`.

## Install node.js

Before running Ghost, we need to install `node` and `npm`.

Arch is a rolling release. That means you will usually get the very latest versions of any packages you install. 'Unfortunately' this means, that one would currently install `node.js 6.0.0-1`, which is [not supported] by Ghost.

Luckily, there's the [Arch User Repository]. You can install node frozen at [v0.10.40] or [node v0.12.x] or just build it from source right away. I use [pacaur], which is itself available in the AUR, to install packages on Arch.

[not supported]: http://support.ghost.org/supported-node-versions/ "Compatability list"
[Arch User Repository]: https://aur.archlinux.org/ "Arch User Repository"
[v0.10.40]: https://aur.archlinux.org/packages/nodejs10/
[node v0.12.x]: https://aur.archlinux.org/packages/nodejs-0.12/
[pacaur]: https://gist.github.com/ansemjo/c1761088e9dda47ddd046f6e4ce6aaf4 "Install script for pacaur"

```
# run this as a user with sudo permissions, not 'ghostcms' and not 'root' !
$ pacaur -S nodejs-0.12
$ pacaur -S npm
```

This will take a while, as you are effectively building from source when you are installing software from the AUR. After we installed any supported node version, we install all required packages for Ghost:

```
$ npm install --production
```

## Run Ghost

Now that everything is in place we can finally start Ghost:

```
$ npm start --production
```

We could now look at ["Deploying Ghost"] to make it run forever as a unit file in systemd, but for now I'll just leave it running and open another terminal to configure nginx. _(edit: I documented this step at the bottom of this post)_

["Deploying Ghost"]: http://support.ghost.org/deploying-ghost/#making-ghost-run-forever

---

# Configure nginx

As I said above, I assume you already have a basic nginx configuration up and running. In fact, the Ghost devs have published very barebones [config] for nginx to run Ghost.

[config]: http://support.ghost.org/basic-nginx-config/

However we want to use sockets, enable nginx to serve some files directly and maybe even enable caching to speed things up a little. There are various places around the net which document the individual parts, so I'll post my finished config here. This is the part which you should include in your `server { }` block, with your `listen` and `server_name` directives above it:

```
set $ghosthome "/srv/ghostcms";
set $ghosttheme "casper";
set $ghostsocket http://unix:$ghosthome/ghost.sock:;

error_page 403 404 /404/;

location ~ /(\.ht|README|LICENSE) {
    deny all; }

location /content/images {
    root $ghosthome;
    expires max; }

location /assets {
    root $ghosthome/content/themes/$ghosttheme;
    expires max; }

location /public {
    root $ghosthome/core/built;
    expires max; }

location /ghost/scripts {
    alias $ghosthome/core/built/scripts;
    expires max; }

location / {
    try_files $uri @ghost;
}

location @ghost {
    proxy_cache PROXY;
    proxy_ignore_headers X-Accel-Expires Expires Cache-Control;
    proxy_pass $ghostsocket;
}

location ~ ^/(?:ghost|signout) {
    proxy_cache off;
    proxy_pass $ghostsocket;
}
```

This serves some static files like *.css and images directly from the filesystem, to avoid unnecessary calls to the socket. It also caches most of the replies by the socket, which do not have to do with the admin interface. Note however, that you'll need to change the `$ghosttheme` variable when you switch your theme!

All of my proxy settings, including the proxy_cache settings are included globally. You do that by creating a file in your `/etc/nginx/conf.d/` folder. For example `/etc/nginx/conf.d/proxy_settings.conf`:

```
proxy_set_header Host $http_host;
proxy_set_header X-Real-IP $remote_addr;
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto $scheme;

proxy_hide_header Strict-Transport-Security;
proxy_hide_header X-Content-Type-Options;
proxy_hide_header X-Frame-Options;
proxy_hide_header X-XSS-Protection;

proxy_cache_path /var/run/nginx levels=1:2 keys_zone=PROXY:32m inactive=2h max_size=128m;
proxy_cache_valid 301 1h;
proxy_cache_valid 200 302 10m;
proxy_cache_valid any 1m;

add_header X-Cache $upstream_cache_status;
```

I hide several headers like `X-XSS-Protection` here, because I set my own values in my ssl configuration. For help on the individual directives I propose you consult the very excellent [nginx documentation].

[nginx documentation]: http://nginx.org/en/docs/dirindex.html "nginx docs: Index of directives"
[git repository]: https://git.semjonov.de/server/nginx-conf

You can also find these files in a larger context in my [git repository] of my nginx configuration.

This concludes this installation. Have fun with Ghost! :)

---

## Bonus: mysql + systemd file

I now migrated my database and made this 'test setup' my main landing page now. This came with two important changes:

* I use MariaDB as a database instead of SQLite.
* Ghost needs to autostart, thus I'm using a systemd service for that.

### MariaDB database

The necessary changes in Ghost's `config.js` are:
```
...
database: {
            client: 'mysql',
            connection: {
                socketPath  : '/run/mysqld/mysqld.sock',
                user        : 'ghostcms',
                password    : 'somesuperstrongpasswordhere',
                database    : 'ghostcms',
                charset     : 'utf8'
            },
            debug: false
        },
...
```

Also add a mailing configuration and [privacy settings] to your liking.
[privacy settings]: http://support.ghost.org/config/#privacy

### systemd service

The necessary systemd service file can actually be found on [GitHub]. I use it with some slight modifications to account for my different user and workingdir:

```
[Unit]
Description=Ghost CMS
After=network.target

[Service]
Type=simple
WorkingDirectory=/srv/ghostcms
User=ghostcms
Group=webserver
ExecStart=/usr/bin/npm start --production
ExecStop=/usr/bin/npm stop --production
Restart=always
SyslogIdentifier=Ghost

[Install]
WantedBy=multi-user.target
```

Put that into a file in a directory, where systemd looks for unit files, e.g. `/etc/systemd/system/ghost-cms.service`. Then reload the daemon, and start & enable the service:
```
# systemctl daemon-reload
# systemctl start ghost-cms.service
# systemctl enable ghost-cms.service
```

[GitHub]: https://github.com/TryGhost/Ghost-Config/blob/master/systemd/ghost.service
