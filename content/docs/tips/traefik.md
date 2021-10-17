---
title: traefik
weight: 10
---

# traefik

For a long time I juggled with all sorts of virtualized homelab networks, when in the end all that I wanted was to selfhost a few services in my network with proper TLS. In the beginning there was FreeIPA with its `certmonger`. Then I switched to a simple OpenSSL CA with long-lived certificates. Later `mkcert` made this a lot easier. The last experiment used StepCA to host an ACME CA internally .... Sure, I learned a lot but *whyyy?*

`traefik` may be a cloud-native technology, which "automatically discovers your infrastructure" when used with Kubernetes / Docker / etc. However, for my purposes it is simply a very handy reverse-proxy with very powerful builtin ACME providers.



## traefik v2 as reverse-proxy for various applications

Assume that you have a decently powerful server, which hosts a number of applications. Some of them run directly on the host. Some of them may run -- for security or simply portability -- in a container with published ports. You may even forward ports from a QEMU virtual machine with userspace networking. You want to have a TLS-secured domain name for each of those applications.

### Start the container

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

