# FreeIPA

### Request Certificates Manually

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
