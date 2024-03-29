---
title: traefik
weight: 10
---

# traefik

For a long time I juggled with all sorts of virtualized homelab networks, when in the end all that I wanted was to host a few services in my network with proper TLS. In the beginning there was FreeIPA with its `certmonger`. Then I switched to a simple OpenSSL CA with long-lived certificates. Later `mkcert` made this a lot easier. The last experiment used StepCA to host an ACME CA internally .... Sure, I learned a lot but *whyyy?*

`traefik` may be a cloud-native technology, which "automatically discovers your infrastructure" when used with Kubernetes / Docker / etc. However, for my purposes it is simply a very handy reverse-proxy with very powerful builtin ACME providers.



## traefik v2 as reverse-proxy for various applications

Assume that you have a decently powerful server, which hosts a number of applications. Some of them run directly on the host. Some of them may run -- for security or simply portability -- in a container with published ports. You may even forward ports from a QEMU virtual machine with userspace networking. You want to have a TLS-secured domain name for each of those applications.

### Start the container

{{< hint info >}}
This sections shows how to use the official `traefik` container image. [Below, I also show how to use the binary release directly.](#alternative-use-the-binary)
{{< /hint >}}

In order to be able to proxy ports of applications running directly on the host, you need to either run the `traefik` binary directly or use the container image with `host` networking. I chose the latter with `podman`:

```bash
podman run -d --name traefik \
  --net host \
  -v /etc/traefik:/etc/traefik \
  -v /etc/ssl/certs/ca-certificates.crt:/etc/ssl/certs/ca-certificates.crt \
  -e HETZNER_API_KEY_FILE=/etc/traefik/hetzner-token \
  traefik:v2.4
```

* The configuration directory `/etc/traefik` does not exist yet .. see below.
* You can see already that I am going to use the Hetzner DNS provider for my ACME challenges. This enables me to get certificates for a domain that is *never* publicly reachable! Check the [list of `dnsChallenge` providers](https://doc.traefik.io/traefik/https/acme/#providers) to see if your domain registrar is supported.
* After you've created a container with `podman` you can use `podman generate systemd <name>` to create a systemd unit file and start the container on boot.

### Configuration and discovery

Great. How do we tell `traefik` about the applications and domains? As I said, it's meant to be used with orchestrators in larger cloud systems, so there's [lots of configuration providers](https://doc.traefik.io/traefik/providers/overview/), too. But thankfully there's a very simple one as well: `file`. Just drop a YAML into a directory and `traefik` will automatically pick it up & reload.

Here is my main configuration in `/etc/traefik/traefik.yml`:

```yaml
# Configuration for traefik v2

global: # Disable telemetry.
  checkNewVersion: false
  sendAnonymousUsage: false

log: # Be more verbose.
  level: INFO

api: # Disable the dashboard.
  insecure: false
  dashboard: false

entrypoints:
  http: # Plaintext
    address: :80
    http: # Redirect to HTTPS
      redirections:
        entrypoint:
          to: https
          scheme: https
          permanent: false
  https: # TLS secured
    address: :443
  mqtts: # Secure MQTT
    address: :8883

certificatesResolvers:
  hetzner:
    acme:
      # Replace with your actual email.
      email: webmaster@example.com
      # Should be inside the /etc/traefik mount ...
      storage: /etc/traefik/acme.json
      # Optional but I prefer elliptic curves.
      keytype: EC384
      dnsChallenge:
        # Pick your own. Depending on your provider you may need to
        # configure different API keys in environment variables.
        provider: hetzner
        # I am using an internal DNS, so traefik will never resolve
        # the challenge – even if it was successfully set in Hetzner.
        delayBeforeCheck: 5
        disablePropagationCheck: true

providers:
  file: # Use files in mounted directory.
    directory: /etc/traefik/routers

```

The options are mostly commented within the file.

* The certificate storage and `file` provider directory should be within the `/etc/traefik` mount, if you're using a container.
* The `hetzner` provider I used here requires an API key in `HETZNER_API_KEY` or inside a mounted file whose path is given in `HETZNER_API_KEY_FILE`.
* Yep, you can proxy TCP services if those use TLS. I.e. PostgreSQL apparently won't work (unless you manually wrap it with `stunnel`) but `mqtts://` does.

### Configure applications with examples

Each application you want to proxy can now be configured with a file in the `/etc/traefik/routers` directory. The configuration is immediately reloaded whenever you save a file in that directory.

Basically, each file needs to define [`routers`](https://doc.traefik.io/traefik/routing/routers/) and [`services`](https://doc.traefik.io/traefik/routing/services/) for the protocol you want to use.

#### Example 1: Gitea

I have Gitea running as a binary directly on the host, so this is a very simple configuration:

```yaml
http:

  routers:
    gitea:
      rule: "Host(`git.anrz.de`)"
      service: gitea
      tls: { certresolver: hetzner }
  
  services:
    gitea:
      loadBalancer:
        servers:
          - url: http://localhost:3000
```

#### Example 2: Mosquitto

Mosquitto is running inside a container with a published port. Additionally, it is *not* a HTTP service and the `mqtts://` protocol uses a different port by default. So you need to use a `HostSNI(...)` rule to match the traffic and specify an `address` instead of a `url` in the service:

```yaml
tcp:

  routers:
    mosquitto:
      rule: "HostSNI(`mqtt.anrz.de`)"
      service: mosquitto
      tls: { certresolver: hetzner }
      entrypoints:
        - mqtts
  
  services:
    mosquitto:
      loadBalancer:
        servers:
          - address: localhost:1883
```

#### Example 3: Verify client certificates

This is just an example how you can specify additional `tls` options to make `traefik` verify client certificates. The example uses client certificates signed with `mkcert`, hence the additional CA certificate in the mounted directory:

```yaml
http:

  routers:
    demo:
      rule: "Host(`demo.anrz.de`)"
      service: demo
      tls: 
        certresolver: hetzner
        options: authme

  services:
    demo:
      loadBalancer:
        servers:
          - url: http://localhost:8080

tls:
  options:
    authme:
      minVersion: VersionTLS13
      clientAuth:
        caFiles:
          - /etc/traefik/ca/mkcert.pem
        clientAuthType: RequireAndVerifyClientCert

```

### Alternative: Use the Binary

Alternatively to the container image used above, you can also [download the binary from GitHub](https://doc.traefik.io/traefik/getting-started/install-traefik/#use-the-binary-distribution) and use a hardened Systemd service file to start traefik.

The following script can be placed in `/usr/local/bin/update-traefik` to download and extract the latest `traefik` binary from GitHub:

```bash
#!/usr/bin/env bash
set -eu
set -x

# download latest binary from github
cd /usr/local/bin
url=$(curl -sH "Accept: application/vnd.github.v3+json" \
  "https://api.github.com/repos/traefik/traefik/releases/latest" \
  | jq -r .assets[].browser_download_url \
  | grep -E 'linux_amd64\.tar\.gz$')
curl -#RL -O "$url"
tar="$(basename "$url")"; bin="${tar%.tar.gz}";
trap "rm -f \"${tar}\"" EXIT

# extract from archive
tar xf "$tar" traefik \
  --no-same-owner \
  --transform "s/traefik/$bin/"

# replace symlink
ln -sf "$bin" traefik
```

It can then be used with a Systemd service file like this one:

```ini
[Unit]
# https://github.com/traefik/traefik/blob/master/contrib/systemd/traefik.service
Description=Traefik - The Cloud Native Application Proxy
Documentation=https://doc.traefik.io/traefik/
After=network.target
AssertFileIsExecutable=/usr/local/bin/traefik
AssertPathExists=/etc/traefik/traefik.yml

[Service]
Type=notify
Restart=always
WatchdogSec=1s
ExecStart=/usr/local/bin/traefik --configFile=/etc/traefik/traefik.yml
WorkingDirectory=/etc/traefik

Environment=HETZNER_API_KEY_FILE=/etc/traefik/hetzner-token

# lock down system access
NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=strict
ProtectHome=yes
PrivateDevices=yes
DevicePolicy=closed
ProtectKernelModules=yes
ProtectKernelTunables=yes
ProtectControlGroups=yes
RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6 AF_NETLINK
RestrictNamespaces=yes
RestrictSUIDSGID=yes
MemoryDenyWriteExecute=yes
LockPersonality=yes

# hide some directories
PrivateMounts=yes
InaccessiblePaths=/srv

# allow writing of acme.json
ReadWritePaths=/etc/traefik/acme.json

[Install]
WantedBy=multi-user.target
```

In my experience, I am more likely to download a new binary and restart a service than I am to pull a new tag and recreate the container. With all the hardening knobs in the service file above, the isolation should be almost as good as a container anyway.

## traefik with automatic discovery

Above, I used `traefik` in a `podman` container and as such it made no sense to use the automatic discovery feature, since there was no compatible Docker socket *to discover the containers with*. Recently, I've had reason to set up a host which uses Docker to host the containers and so I wanted to adapt the above configuration with automatic discovery.

I planned to use `docker-compose` to deploy the applications on this host, so it made sense to deploy `traefik` itself with a `docker-compose.yml` file aswell. Since the complete configuration can also be done in environment variables, this single file contains almost all the information required to run the service. Only a single mounted volume is required to the ACME storage (and in my case the Hetzner token). Without much further ado, here's my file.

{{< hint danger >}}

**Access to the Docker socket**

Mounting the Docker socket directly, like I did here, [is a security concern](https://doc.traefik.io/traefik/providers/docker/#docker-api-access). There are a few examples on how to use [Tecnativa/docker-socket-proxy](https://github.com/Tecnativa/docker-socket-proxy) to filter the API requests and only allow read-only access. In my first few attempts I couldn't make this work reliably with `host` networking though. If you don't need to forward applications that run on the host directly, you should definitely consider this though.

{{< /hint >}}

```yaml
version: "3"
services:

  # https://doc.traefik.io/traefik/reference/static-configuration/env/
  traefik:
    container_name: traefik
    image: traefik:2.9
    restart: always
    network_mode: host
    volumes:
      - ./acmedata:/data # store certificates and mount token
      - /var/run/docker.sock:/var/run/docker.sock:ro
    environment:

      # disable telemetry
      TRAEFIK_GLOBAL_CHECKNEWVERSION: false
      TRAEFIK_GLOBAL_SENDANONYMOUSUSAGE: false

      # be more verbose
      TRAEFIK_LOG_LEVEL: INFO # or DEBUG

      # disable the dashboard
      TRAEFIK_API_DASHBOARD: false
      TRAEFIK_API_INSECURE: false

      # define http entrypoints
      TRAEFIK_ENTRYPOINTS_http_ADDRESS: ":80"
      TRAEFIK_ENTRYPOINTS_https_ADDRESS: ":443"
      TRAEFIK_ENTRYPOINTS_https_HTTP_TLS_CERTRESOLVER: hetzner

      # redirect http to https
      TRAEFIK_ENTRYPOINTS_http_HTTP_REDIRECTIONS_ENTRYPOINT_TO: https
      TRAEFIK_ENTRYPOINTS_http_HTTP_REDIRECTIONS_ENTRYPOINT_SCHEME: https
      TRAEFIK_ENTRYPOINTS_http_HTTP_REDIRECTIONS_ENTRYPOINT_PERMANENT: false

      # use the docker provider
      TRAEFIK_PROVIDERS_DOCKER: true
      TRAEFIK_PROVIDERS_DOCKER_EXPOSEDBYDEFAULT: false
      TRAEFIK_PROVIDERS_DOCKER_DEFAULTRULE: "Host(`{{ or (index .Labels \"de.anrz.hostname\") (normalize .Name) }}.anrz.de`)"

      # hetzner certificateresolver for tls
      TRAEFIK_CERTIFICATESRESOLVERS_hetzner: true
      TRAEFIK_CERTIFICATESRESOLVERS_hetzner_ACME_STORAGE: /data/acme.json
      TRAEFIK_CERTIFICATESRESOLVERS_hetzner_ACME_EMAIL: webmaster@example.com
      TRAEFIK_CERTIFICATESRESOLVERS_hetzner_ACME_KEYTYPE: EC384
      TRAEFIK_CERTIFICATESRESOLVERS_hetzner_ACME_DNSCHALLENGE: true
      TRAEFIK_CERTIFICATESRESOLVERS_hetzner_ACME_DNSCHALLENGE_PROVIDER: hetzner
      TRAEFIK_CERTIFICATESRESOLVERS_hetzner_ACME_DNSCHALLENGE_DELAYBEFORECHECK: 5
      TRAEFIK_CERTIFICATESRESOLVERS_hetzner_ACME_DNSCHALLENGE_DISABLEPROPAGATIONCHECK: true
      HETZNER_API_KEY_FILE: /data/hetznertoken

```

I added an interesting bit in the default rule for Docker containers, which looks for a label `de.anrz.hostname` on the container and uses it for the default hostname rule. With traefik deployed like this, you can start containers with exposed ports and two short annotations and have them show up with a valid certificate in a few short seconds. This example uses the `nginxdemos/hello` image:

```yaml
version: "3"
services:

  hello:
    image: nginxdemos/hello
    labels:
      traefik.enable: true
      de.anrz.hostname: hello
```

{{< hint info >}}

This image uses an `EXPOSE 80` statement in its Dockerfile, hence you don't even need to specify the port that traefik should listen on.

{{< /hint >}}
