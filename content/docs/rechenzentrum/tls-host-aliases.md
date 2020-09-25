# TLS for Host Aliases

You can request certificates for host aliases without creating a seperate host entry with no
enrolled machine.

!!! note "Minimum version"
    According to [this discussion](https://www.redhat.com/archives/freeipa-users/2017-May/msg00058.html)
    _at least_ FreeIPA version 4.5 is required.

## Add Principal Alias

In FreeIPA on the [Identity > Services](https://ipa0.rz.semjonov.de/ipa/ui/#identity/service) page
add a `HTTP` service for an actual, enrolled host.

Edit that service and add a principal alias:

```
Service Settings
  Principal alias   HTTP/ifrit.rz.semjonov.de@RZ.SEMJONOV.DE  [Delete]
                    HTTP/s3.rz.semjonov.de@RZ.SEMJONOV.DE     [Delete]
                    [Add]
```

## Request Certificate

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


