---
title: Caddy
weight: 10
---

# Caddy

## Simple ACME DNS challenges with Caddy

I just want to quickly mirror the idea from [my traefik reverse-proxy with ACME certificates]({{< relref "traefik.md" >}}) for Caddy as well because I needed that recently. The overall setup followed the [manual installation method](https://caddyserver.com/docs/running#manual-installation) and I configured the required Hetzner token via a systemd `override.conf`, as suggested.

```Caddy
{

  # disable redirects to stop trying to bind to :80
  auto_https disable_redirects

  # use letsencrypt
  acme_ca https://acme-v02.api.letsencrypt.org/directory

}

# configure your hostname here
https://my.domain.tld:8443

# enable the file browser
root * /var/www/html/
file_server browse

tls {

  # use specific resolver for split-horizon dns setups
  resolvers helium.ns.hetzner.de 1.1.1.1

  # github.com/caddy-dns/hetzner with token in environ
  dns hetzner {env.HETZNER_API_TOKEN}

}
```
