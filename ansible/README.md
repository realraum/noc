Overview
========

This should provide a short overview on how to use ansible

### basic ansible playbook call

```
#   -C ... check
#   -D ... show diff of changes
ansible-playbook foo.yml -D -C
```

### basic ansible call
```
#   -m ... load module shell
#   -a ... arguments to module call
ansible vex -m shell -a 'uname -a'
ansible servers -m apt -a 'name=foo state=present'
ansible desktops -m file -a 'name=/make/sure/this/file/is/gone state=absent'
```

### check if all server are reachable
```
ansible servers -m ping
```

### deploy playbook
```
ansible-playbook foo.yml
```

### deploy a single role to a single host
```
./apply-role.sh wuerfel base
```

### deploy a single role to a group of hosts with check-mode to see what would be done
```
./apply-role.sh servers base -C -D
```

ansible-lint
------------

We use ansible-lint to check all roles when changes are pushed to Github.
Some rules have been globally disabled. See [.ansible-lint](/ansible/.ansible-lint)
for a list of all disabled rules. If ansible-lint produces a false positive for
a specific task you can disable it by adding the following to the task:

```
  tags:
  - skip_ansible_lint
```

For now only roles and now playbooks are checked. Every role must be manually added
to the generic playbook [_lint_roles.yml](/ansible/_lint_roles.yml) in order to be
checked.
If an entire role should be skipped please add it to the playbook commented out
and supply a reason why this role must be skipped.


Local ssh config
----------------

By default hosts in the inventory use the FQDNs as the name so most
hosts should be reachable without any special configuration.
In addition r3 NOC uses the `localconfig` playbook/role to generate a
ssh config snippet to add nicer/shorter aliases for the hosts and also
to automatically add jump hosts and some other special settings.

The way this works is that config snippets are generated inside
`~/.ssh/config.d/` and (optionally) then compiled to a single file
`~/.ssh/config`. If you want to use it as well you should move your
current ssh config file to `~/.ssh/config.d/` and run the playbook
`localconfig.yml`.
In order to make the generated config snippet work for different
people the role sources the file `~/.ssh/r3_localconfig.yml`.
All variables inside that file will take precedence of files from
`host_vars`, `group_vars`, gathered facts, etc.


Secrets
-------

See [README_vault.md](/ansible/README_vault.md) on how to create vaults.

In general vaults should live in `host_vars/<hostname>/vault.yml` or
`group_vars/<groupname>/vault.yml`. The variables defined inside the
vaults should be prefixed with `vault_` and be referenced by other
variables and not used directly in plays and roles. For example if you
want to set a secret variable `root_pasword` for host `foo` there should
be two files:
  * `host_vars/foo/main.yml`:
    ```
    root_password: "{{ vault_root_password }}"
    ```
  * `host_vars/foo/vault.yml`:
    ```
    vault_root_password: "this-is-very-secret"
    ```

Of course the latter file needs to be created using `ansible-vault`.

If you want to store secrets that by default shouldn't be automatically
exposed to hosts and groups as variables please put the vault files into
`secrets` directory and name them <some-name>.vault.yml.

r3 NOC uses [ansible-vault-tools](https://github.com/building5/ansible-vault-tools)
to manage/diff/merge changes in vaults.
