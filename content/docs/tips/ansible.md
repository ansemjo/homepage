# Ansible

## Inline Vault usage

The [Ansible vault] can encrypt your secrets so you can add them to your inventory files and track
those in your preferred version control system.

[ansible vault]: https://docs.ansible.com/ansible/2.6/user_guide/vault.html

Since version 2.3, Ansible allows using encrypted values inline in an otherwise unencrypted file.

### Create key

In a simple setup with a single user you my want to use a password file with a high-entropy secret
inside. Just don't add that to any VCS.

```shell
$ high-entropy-password-gen > ~/.ansible/vaultkey

# e.g. my diceware words alias:
$ words 10 - > ~/.ansible/vaultkey
```

Edit your `ansible.cfg` to use that key without prompting:

```ini
# If set, configures the path to the Vault password file as an alternative to
# specifying --vault-password-file on the command line.
vault_password_file = ~/.ansible/vaultkey
```

### Encrypt secret values

Then use `ansible-vault encrypt_string` to encrypt your secrets:

```shell
$ echo mysecret | ansible-vault encrypt_string
Reading plaintext input from stdin. (ctrl-d to end input)
!vault |
          $ANSIBLE_VAULT;1.1;AES256
          34326362313132393835323362663331323238393837613134646465333339623034653666626633
          6439616237613939393666363530626663373132616232300a346164363933613934333830613932
          36356235323665346530626438313935653537333836373935313336343265343061656262396337
          3832666631623739330a316363336463613530343132633765366166363532303135333736653931
          62386637636532363064346134333735313737356666613233623166653239333832
Encryption successful
```

If your secret is in the clipboard and my aliases are installed, a `clipboard` pipe works great:

```shell
$ clipboard | ansible-vault encrypt_string | clipboard
```

Finally paste the encrypted secret in your inventory or variable file:

```yaml
[...]
        runner.rz.semjonov.de:
          ansemjo_gitlab_runner_registration_token: !vault |
            $ANSIBLE_VAULT;1.1;AES256
            35376637383563383661366562613932306437653533623461303032346566633032626435356538
            3564376461343131613165386135303534666166393138650a356233333030323730666562613637
            36653561396430346539373966366338633861346130623135633732383030666130393765323431
            6333393837336665650a343738646135323235323331306630333465303535363530653435383532
            35633834666138373661336436363963363766393236336536306134653136343064
          ansemjo_gitlab_runner_registration_url: https://git.rz.semjonov.de/
[...]
```
