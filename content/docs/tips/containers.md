# Containers

## Docker Firewalling

By default, `docker` seems to start with `--iptables=true` everywhere. That means that the docker
daemon will insert its own iptables rules to enable inter-container communication and publish ports.
_However_ that means that published ports will be published **publicly** by default.

That means that a container started with `-p 8000:8000` will be open to the world on that port.
_Even if_ your firewalld configuration does not permit this port. This is because Docker completely
circumvents any firewall managers.

### Disable `iptables` tampering

To disable this behaviour add `--iptables=false` to the start arguments of docker. Either do that by
editing the systemd service, or set an `DOCKER_OPTS="..."` in `/etc/default/docker` if applicable.

    $ systemctl edit docker.service
    [Service]
    ExecStart=
    ExecStart=/usr/bin/dockerd -H fd:// --iptables=false

This also disables the forwarding rules however. Your containers will not be able to reach the
outside world anymore. To reenable the forwarding with `firewalld` use:

    $ firewall-cmd --add-masquerade --permanent

Or using raw `iptables` rules:

    -A FORWARD -i docker0 -o eth0 -j ACCEPT
    -A FORWARD -i eth0 -o docker0 -j ACCEPT

## Full systemd in container

Podman introduced some fixes that enable you running a full systemd init process inside of
a **rootless** container. That way you can start a normal CentOS image with
`podman run ... centos init` and login like you would in a virtual machine, enable systemd
services etc.

To properly login you need two small fixes however. First you need a known password. Since
moust images have passwords disabled or empty for all accounts you'll need to mount an
edited `/etc/shadow`. The following line for example sets the `root` password to literally
`password`:

    root:$6$1xZg0v5W$XgEfFIUlHB3EIGsxJvABkytPaUITLEfTb7WocHoeFaAwBFfui2tIKZq1l/MoKtZHMQ7Q/23Dnr.qLhGfzz4VH/:18061:0:99999:7:::

Another fix is required for PAM, since the console accepts your password but PAM fails to
[create a session for you](https://stackoverflow.com/questions/43323754/cannot-make-remove-an-entry-for-the-specified-session-cron). The fix is simple:

    sed -i '/^session.*pam_loginuid.so/s/^/#/' /etc/pam.d/login

Mount these two files inside the container and
[finally start it](https://asciinema.org/a/251687) with:

    podman run --rm -it -v ... centos:latest init
