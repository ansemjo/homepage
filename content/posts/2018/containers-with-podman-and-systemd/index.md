---
title: Managing containers with podman and systemd
description: Use simple systemd units to supervise your containers.
date: 2018-11-06T17:32:54+01:00

tags:
  - linux
  - container
  - systemd
---

A while ago I stumbled upon [podman](https://podman.io/), which touts itself as an alternative to
Docker. Not only does `podman` not use any _big fat daemons™_ but it makes it rather easy to run
containers in a user-namespace, i.e. with greatly restricted privileges on your system. The fun
thing is: you are still `root` _within the container!_

<!--more-->

To be honest, I have not investigated Docker's user-namespace capabilities much. But the fact that
`podman` has an almost identical cli to Docker greatly reduces the hurdles to just installing and
trying it out. There's even jokes that you should simply put `alias docker=podman` in your
`.bashrc`.

## lack of a daemon

The fact that it is just a couple of forking processes and does not use an almighty daemon to fire
up containers behind the scenes already fascinated me about `rkt` when I began reading up on CoreOS
and their environment. There was (or still is?) an issue with running `rkt` on CentOS 7 though, so I
just never tried it. And while `podman` is not directly equivalent to `rkt`, it is a lot closer in
principle than Docker.

Then I watched a couple of streams from this year's
[All Systems Go!](https://media.ccc.de/c/asg2018) conference recently. And suddenly
[podman](https://media.ccc.de/v/ASG2018-177-replacing_docker_with_podman), user-namespaces and
`systemd` [_with_](https://media.ccc.de/v/ASG2018-192-state_of_systemd_facebook) and
[_within_](https://media.ccc.de/v/ASG2018-179-container_run-times_and_fun-times) containers seemed
to be everywhere.

Most of us already do have this powerful supervisor running on our systems: `systemd`. Many still
seem to hate it and sure: deploying a simple scheduled command is a lot trickier than just using a
`crontab` and at times `systemd` seems to violate the _KISS_ principle by trying to do too much. But
I am not going to go down this rabbit hole.

The point is: why should we use yet another supervisor (the Docker daemon in this case) to launch
our services? Well: with Docker you don't really have a choice, since the container itself is
started by the daemon and not the commandline tool. But with `podman` both `conmon` and the final
`runc` are direct descendants of your executed command. (There are more
[advantages](https://opensource.com/article/18/10/podman-more-secure-way-run-containers) that arise
from this model. See the linked ASG2018 talk by Dan Walsh above.)

## supervise rootless containers

Now combine the fact that you can run containers without being `root` with `podman` on the one hand
and `systemctl`'s `--user` mode on the other hand and you've got yourself a nice service supervisor.

Let's assume you want to run a PostgreSQL container on a specific port. Doing so manually in a
rootless container would look like this:

    podman pull postgres:11-alpine
    podman run --rm -it --net host postgres:11-alpine postgres -p 5000

Looking at some [previuous](https://github.com/containers/libpod/issues/893)
[attempts](https://podman.io/blogs/2018/09/13/systemd.html) at running `podman` from within
`systemd`, I came up with this unit file for PostgreSQL:

    [Unit]
    Description=Postgres 11 container on port %i
    After=network.target

    [Service]
    Type=simple
    Restart=always

    ExecStartPre=-/usr/bin/podman create --net host --name %n postgres:11-alpine postgres -p %i
    ExecStart=/usr/bin/podman start -a --sig-proxy %n

    [Install]
    WantedBy=multi-user.target

This does not recreate the container on every restart and simply proxies the signals to the
container to stop or restart instead of running seperate `podman` commands. PostgreSQL might not be
the best example in this case because usually you would really want to persist your databases
somehow. But this could be solved by adding appropriate volume mounts with `-v ...` to the
container. If this was some sort of NodeJS backend taking a `PORT` environment variable and if you
added configuration via an `EnvironmentFile=...` line, this might make more sense.

Anyhow, you get the idea.

Put this unit in `~/.config/systemd/user/postgres@.service`, reload your daemon and you can start
containers on various ports:

    systemctl --user daemon-reload
    systemctl --user start postgres@5000.service postgres@4000.service

You should now see both containers in `podman ps` and you should be able to connect locally:

    $ podman ps
    CONTAINER ID   IMAGE                                  COMMAND                  CREATED             STATUS                 PORTS   NAMES
    b6faebb5cd0b   docker.io/library/postgres:11-alpine   docker-entrypoint.s...   31 seconds ago      Up 30 seconds ago              postgres@5000.service
    7d698833cd08   docker.io/library/postgres:11-alpine   docker-entrypoint.s...   About an hour ago   Up About an hour ago           postgres@4000.service
    $ psql -h localhost -p 5000 -U postgres
    psql (10.5, server 11.0)
    WARNING: psql major version 10, server major version 11.
             Some psql features might not work.
    Type "help" for help.

    postgres=#

Do this with a proper backend service as noted above, use a dedicated user and run a load-balancing
proxy in front of it. Tada!

After a few [more](https://github.com/containers/libpod/pull/1761)
[issues](https://github.com/systemd/systemd/pull/10646) are resolved you might even be able to use
`systemd` within rootless containers to also enable proper service supervision within the container.

## compose

Right now, I really miss a feature like Docker's `docker-compose.yml` files. However I hear that
such a feature is planned. Until then building dependencies through `After=` and `Requires=` and
possibly the use of `pods` in `podman` might be a viable alternative.
