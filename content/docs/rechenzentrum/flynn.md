## Installing [Flynn] on Debian

[Flynn]: https://flynn.io/

Flynn is mostly compatible with Debian. Some packages require the `contrib` repository though.

Installing a single-node Flynn "cluster" is as easy as:

* Perform a clean Debian 9 Stretch installation.
* Download the official script from [dl.flynn.io/install-flynn](https://dl.flynn.io/install-flynn)
* Patch the function `is_ubuntu_xenial()` to also check for `Debian GNU/Linux 9`.
* Enable or add  the `contrib` repository in `/etc/apt/sources.list`.
* Run the `install-flynn` script.
* Start and enable `flynn-host.service`.
* Export `CLUSTER_DOMAIN` to the appropriate FQDN. Apps will be `$app.CLUSTER_DOMAIN`.
* Bootstrap with `flynn-host bootstrap`.