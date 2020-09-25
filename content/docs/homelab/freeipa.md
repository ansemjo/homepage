---
title: FreeIPA
weight: 50
---

# FreeIPA

## Request Certificates Manually

You can request TLS certificates manually for hosts that are not fully enrolled in the domain or don't have any
FreeIPA tools installed at all (CoreOS hosts, for example). This requires however, that you either are an admin
in the domain or at least have the rights to create new hosts and service principals.

First of all, create a signing request on the host:

    openssl req -nodes -new -newkey rsa:2048 -sha256 \
      -out test.csr -keyout test.key \
      -subj '/CN=test.example.com/'

Now switch to a machine with the FreeIPA tools installed and add a host entry. You'll want to do this anyway to
properly be able to set DNS records for your host.

    kinit admin
    ipa host-add test.example.com --ip-address 192.168.1.100

Now transfer the CSR to this machine and sign the request while simulateneously adding the `HTTP/` service principal:

    ipa cert-request test.csr \
      --principal HTTP/test.example.com --add \
      --certificate-out test.crt

This command will display the serial number, which can later be used to fetch information about the certificate or
revoke it. Finally, just copy the `test.crt` back to your host and configure whatever service you want to secure with
TLS.

## TLS for Host Aliases

You can request certificates for host aliases without creating a seperate host entry with no
enrolled machine.

{{< hint warning >}}
According to [this discussion](https://www.redhat.com/archives/freeipa-users/2017-May/msg00058.html) _at least_ FreeIPA version 4.5 is required.
{{< /hint >}}

### Add Principal Alias

In FreeIPA on the [Identity > Services](https://ipa0.rz.semjonov.de/ipa/ui/#identity/service) page
add a `HTTP` service for an actual, enrolled host.

Edit that service and add a principal alias:

```
Service Settings
  Principal alias   HTTP/ifrit.rz.semjonov.de@RZ.SEMJONOV.DE  [Delete]
                    HTTP/s3.rz.semjonov.de@RZ.SEMJONOV.DE     [Delete]
                    [Add]
```

### Request Certificate

Request the certificate for the alias with `ipa-getcert`:

```sh
$ export S3=s3.rz.semjonov.de
$ export tls=/etc/pki/tls
$ ipa-getcert request \
  -k $tls/private/$S3.key \
  -f $tls/certs/$S3.crt \
  -D $S3 \
  -N CN=ifrit.rz.semjonov.de \
  -K HTTP/ifrit.rz.semjonov.de@RZ.SEMJONOV.DE \
  -I $S3
$ ipa-getcert list
Number of certificates and requests being tracked: 1.
Request ID 's3.rz.semjonov.de':
[...]
	subject: CN=ifrit.rz.semjonov.de,OU=Rechenzentrum,O=rz.semjonov.de,C=DE
	expires: 2020-07-26 22:04:55 UTC
	dns: s3.rz.semjonov.de,ifrit.rz.semjonov.de
	principal name: HTTP/ifrit.rz.semjonov.de@RZ.SEMJONOV.DE
	[...]
```


