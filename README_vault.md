Secrets and Vaults
==================

All secrets are stored inside encrypted ansible vault files which live
inside the secrets directory. Access to the vault files is controlled via
GPG keys. Anybody who uses this ansible repository needs to have a GPG key.


Creating a GPG key
------------------

You can use the following command to generate a new GPG key:

```
# gpg2 --full-gen-key
   - select "RSA and RSA" as kind (should be option: 1)
   - set keysize to: 4096
   - set key expiration to: 2y
   - set Real name and eMail adress
   - set a passphrase for the key (please use a strong passphrase!!!)
```

This command prints the fingerprint and other inforamtion about the newly
generated key. In the line starting with pub you can find the key ID. This
ID can be used to uniquely identify your key. Here is a sample output:

```
pub   rsa4096/0x1234567812345678 2017-01-01 [SC] [expires: 2019-01-01]
      Key fingerprint = 1234 5678 1234 5678 1234  5678 1234 5678 1234 5678
uid                   [ unknown] Firstname Lastname <lastname@example.com>
sub   rsa4096/0x8765432187654321 2017-01-01 [E] [expires: 2019-01-01]
```

The key ID is the hexadecimal number next to ```rsa4096/``` in the line
starting with ```pub``` (not ```sub```). In this case the key ID is: ```0x1234567812345678```

In order to add your key to the list of keys which can read the ansible vault
you first need to export the public part of your key using the following
command:

```
# gpg2 --armor --export "<your key id>" > mykey.asc
```



Adding a key to the Vault
-------------------------

Everybody who currently has access to the vault can add keys using the
following command:

```
# gpg/add-keys.sh mykey.asc
```

This will add the new key to the keyring stored inside the repository and
reencrypt the secret to unlock the vault for all keys inside the keyring.



Removing a key from the Vault
-----------------------------

Everybody who currently has access to the vault can remove keys using the
following command:

```
# gpg/remove-keys.sh "<key-id>"
```

This will remove the key from the keyring stored inside the repository and
reencrypt the secret to unlock the vault for all remaining keys inside the
keyring.

You can find out the key ID using the command:

```
# gpg/list-keys.sh
```

Here is an example output:

```
pub   rsa4096/0x1234567812345678 2017-01-01 [SC] [expires: 2019-01-01]
      Key fingerprint = 1234 5678 1234 5678 1234  5678 1234 5678 1234 5678
uid                   [ unknown] Firstname Lastname <lastname@example.com>
sub   rsa4096/0x8765432187654321 2017-01-01 [E] [expires: 2019-01-01]
```

The key ID is the hexadecimal number next to ```rsa4096/``` in the line
starting with ```pub``` (not ```sub```). In this case the key ID is: ```0x1234567812345678```



Working with Vault files
------------------------

 * create new vault:
   ```
# ansible-vault create secrets/foo.vault.yml
   ```
   This will open up an editor which allows you to add variables. Once you
   store and close the file the content is automatically encrypted.

 * edit a vault file:
   ```
# ansible-vault edit secrets/foo.vault.yml
   ```
   This will open up an editor which allows you to add/remove/change variables.
   Once you store and close the file the content is automatically encrypted.

 * show the contents of a vault file:
   ```
# ansible-vault view secrets/foo.vault.yml
   ```
   This will automatially decrypt the file and print it's contents.
