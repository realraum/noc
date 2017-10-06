SSH Hardening
=========

This is a role to give a baseline level of security to SSH on systems.

Role Variables
--------------

#### SSH Bind Addresses

Addresses to bind SSH to. Note that port is required on each entry.

```
sshd_config_bind_addresses: ['0.0.0.0:22']
```

#### Root Login

Whether or not to allow root logins.

Remember to make a new user with sudo if using root for ansible ssh.

```
sshd_config_root_login: yes
```

#### Advanced

Additional variables are for more advanced usage and should not be modified unless you know what you're doing:

- `sshd_config_kex_algorithms`
- `sshd_config_macs`
- `sshd_config_ciphers`
- `sshd_config_x11_forwarding`

Example
----------------

```
- hosts: servers
  var_files:
    - vars.yml
  roles:
    - ameliaikeda.ssh-hardening
```


License
-------

BSD
