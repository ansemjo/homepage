---
title: PostgreSQL with TLS on CentOS 7.3
date: 2017-03-28
draft: true
toc: true
tags:
  - postgresql
  - linux
  - database
  - tls
---

# Install PostgreSQL server

* install
```
yum -y install postgresql-{server,contrib}
```

* check the database directory `/var/lib/pgsql/`. for example, you might want to mount a nfs share here

* init db
```
postgresql-setup initdb
```

* allow in firewall
```
firewall-cmd --add-service=postgresql --permanent 
firewall-cmd --reload
```

* start and enable service
```
systemctl enable --now postgresql.service
```


# TLS certificate via FreeIPA

* join domain:
```
ipa-client-install --mkhomedir --ssh-trust-dns --force-ntpd
```

* get certificate
```
tls=/etc/pki/tls
id=$(hostname --fqdn)

ipa-getcert request -I $id -k $tls/private/$id.key -f $tls/certs/$id.crt

chown postgres:postgres $tls/{private/$id.key,certs/$id.crt}
```

* enable ssl in `$PGDATA/postgresql.conf`
```
diff postgresql.conf.bak postgresql.conf
83c83
< #ssl = off
---
> ssl = on
87,89c87,89
< #ssl_cert_file = 'server.crt'
< #ssl_key_file = 'server.key'
< #ssl_ca_file = ''
---
> ssl_cert_file = 'server.crt'
> ssl_key_file = 'server.key'
> ssl_ca_file = 'ca.crt'
```
.. and symlink the above requested certificate and key, and ca certificate from `/etc/ipa/ca.crt`.

* allow password auth over ssl in `pg_hba.conf`
```
# Remote connections only via SSL
hostssl all             all             samenet     password
```

* restart service
