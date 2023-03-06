---
title: Kubernetes
weight: 10
---

# Kubernetes

These following sections cannot be complete guides, of course, but rather some specific tasks. I like to use the lightweight Kubernetes distribution [k3s](https://k3s.io/) for my nodes.

## Certificates with ACME DNS01

At home I started using [`traefik` to host my applications]({{< relref "traefik.md" >}}), which also includes support for automatically requesting certificates from ACME certificate authorities – even for internal hostnames, when using the DNS01 challenge type with a supported DNS provider. At work I still use a small Kubernetes cluster, so I researched how I can use [`cert-manager`](https://cert-manager.io/) to do the same.

### Install `cert-manager`

First, create a new namespace for `cert-manager`:

    kubectl create namespace cert-manager
    kubectl config set-context --current --namespace=cert-manager

Then deploy `cert-manager` to this namespace. I chose to use the [`kubectl` plugin](https://cert-manager.io/docs/usage/kubectl-plugin/). Since we have a split-brain domain, I tried to [add options](https://cert-manager.io/docs/configuration/acme/dns01/#setting-nameservers-for-dns01-self-check) to make `cert-manager` use only external nameservers for checking; I am not sure that these options are effective though.

    kubectl cert-manager x install \
      --set prometheus.enabled=false \
      --set 'extraArgs={--dns01-recursive-nameservers-only,--dns01-recursive-nameservers=193.47.99.5:53\,1.1.1.1:53}'

After that I installed another helm chart with a [webhook solver plugin](https://github.com/vadimkim/cert-manager-webhook-hetzner) for the Hetzner DNS API:

    helm repo add cert-manager-webhook-hetzner \
      https://vadimkim.github.io/cert-manager-webhook-hetzner
    helm install --namespace cert-manager cert-manager-webhook-hetzner \
      cert-manager-webhook-hetzner/cert-manager-webhook-hetzner \
      --set groupName=mydomain.de

### Configure Issuer

Next, configure the `ClusterIssuer` with the necessary API secret. **Note:** change the `server`, `email`, `{group,zone}Name` and the `api-key`, of course. For more information check the Readme of [vadimkim/cert-manager-webhook-hetzner](https://github.com/vadimkim/cert-manager-webhook-hetzner).

```yaml
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt
spec:
  acme:
    # change endpoint to remove "-staging" for production:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: webmaster@yourdomain.tld # changeme
    privateKeySecretRef:
      name: letsencrypt
    solvers:
      - dns01:
          webhook:
            groupName: mydomain.de # changeme
            solverName: hetzner
            config:
              secretName: hetzner-secret
              zoneName: mydomain.de # changeme
              apiUrl: https://dns.hetzner.com/api/v1

---
apiVersion: v1
kind: Secret
metadata:
  name: hetzner-secret
type: Opaque
data:
  api-key: your-base64-encoded-key # changeme
```

In order to check if certificate issuance works, you can apply this simple `Certificate` resource:

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: example-cert
  namespace: cert-manager
spec:
  commonName: example.mydomain.de
  dnsNames:
    - example.mydomain.de
    - test.mydomain.de
  issuerRef:
    name: letsencrypt
    kind: ClusterIssuer
  secretName: example-cert
```

After a while you can check with `kubectl describe certificate example-cert` and ideally you should see something like:

```
...
Events:
  Type    Reason     Age   From          Message
  ----    ------     ----  ----          -------
  Normal  Issuing    2m6s  cert-manager  Issuing certificate as Secret does not exist
  Normal  Generated  2m5s  cert-manager  Stored new private key in temporary Secret resource "example-cert-dlp6k"
  Normal  Requested  2m5s  cert-manager  Created new CertificateRequest resource "example-cert-rbp6k"
  Normal  Issuing    47s   cert-manager  The certificate has been successfully issued
```

<details>
    <summary>Rancher logo example with automatic certificate</summary>

Of course, you can also use annotations on an `Ingress` to automatically issue certificates instead of creating resources beforehand. Here is a complete example that deploys a simple demo application:

```yaml
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: rancher-logo-app
spec:
  selector:
    matchLabels:
      name: rancher-logo-backend
  template:
    metadata:
      labels:
        name: rancher-logo-backend
    spec:
      containers:
        - name: backend
          image: ruanbekker/logos:rancher
          ports:
            - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: rancher-logo-service
spec:
  ports:
    - name: http
      port: 80
      protocol: TCP
      targetPort: 80
  selector:
    name: rancher-logo-backend
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: rancher-logo-ingress
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt
spec:
  tls:
    - secretName: logo-test-cert
      hosts:
        - logo.mydomain.de
  rules:
  - host: logo.mydomain.de
    http:
      paths:
        - path: /
          pathType: Prefix
          backend:
            service:
              name: rancher-logo-service
              port:
                name: http
```

</details>

## Internal DNS resolution

I often have some applications in Kubernetes deployments, that need to access some internal services "behind" my firewall. These internal domains usually have a "split-brain" configuration, where I buy a domain, create stubs in the provider's public nameserver and then point all machines to a DNS server within the network, which actually knows how to resolve the names to RFC 1918 private addresses.

Probably due to [k3s #4087](https://github.com/k3s-io/k3s/issues/4087#issuecomment-928438828) my K3s node does not pick up the host's `/etc/resolv.conf` (as it contains IPv6 addresses). In this situation, there are two solutions:

* Either create a separate `resolv.conf` file for use with K3s – e.g. at `/etc/resolv-k3s.conf` – and point the installer to it with `--resolv-conf <file>`, as suggested in the above issue comment.

* Or configure the CoreDNS configuration file and add a [`forward` rule](https://coredns.io/plugins/forward/):
  * The configuration file should be located at `/var/lib/rancher/k3s/server/manifests/coredns.yaml`
  * Look for the `coredns` `ConfigMap` and add a line like `forward anrz.de. 10.0.0.1` in the `.:53 { ... }` block.
  * Restart CoreDNS with `kubectl rollout restart -n kube-system deployment coredns`.

You should probably use the first option, since it is stable between K3s updates. I had to reapply the second solution today after I ran an update.
