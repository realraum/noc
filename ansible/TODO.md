TODO
====

Open findings from the inventory sweep on 2026-11-19 (see `hosts.ini`).

Inventory cleanup
-----------------

- [ ] Decide what to do with unreachable hosts that are still in the inventory:
      `alfred` (no route to host), `gnocchi0`, `gnocchi1`, `testvm` (timeouts),
      `ap0`-`ap2` and `wuerfel` (no DNS record). Remove them or move them to `offline`.
- [ ] `virtualservers-alfred` is out of date: athsdisc, ctf, entrance, galley,
      hacksch, metrics and r3home run on kunigunde now. The group still sets
      `vm_install_host=alfred`, and `host_vars` of ctf, metrics and testvm
      hard-code `vm_host: alfred`.

DNS (zones on oldgw, `/etc/bind/`)
----------------------------------

- [ ] Fix records that point to the wrong address:
  - `beamerremote.mgmt` is 192.168.32.20, the VM is on .45
  - `ipmi.kunigunde.mgmt` is 192.168.32.149, the iDRAC got .27 via DHCP
  - `drucker` is 192.168.127.240, the printer answers on .192
  - `real486` is 192.168.127.224, which is netbox-scanner
- [ ] Add missing records: `homepage` only has the name `tools`, and `ns` and
      `mysql` (phoxmox VMs 102/103) have none. The inventory uses IP addresses,
      so this only matters for humans; `ns` and `mysql` still need an
      `ansible_host` once they are installed.

Access
------

- [ ] No working credentials:
  - `immich`: root has no `authorized_keys` (only `pct enter 110` on phoxmox)
  - `homeassistant`, `smsgw`, `smallkiosk`, `phoxmox-idrac`, `kunigunde-idrac`:
    reject the `rr`, `sec` and `rr1` keys
- [ ] `amateur-radio` (kunigunde VM 114): address unknown, it is on VLAN 69
      (nt, 192.168.69.0/24), which is not reachable from guests/mgmt.
- [ ] `oldgw`: only offers an ssh-rsa host key and runs Debian squeeze. Ansible
      needs `HostKeyAlgorithms=+ssh-rsa` / `PubkeyAcceptedKeyTypes=+ssh-rsa`
      (not set in the inventory), and modules probably won't run on its old Python.

Unidentified devices (not in the inventory)
-------------------------------------------

- [ ] 192.168.127.251: Raspberry Pi 4, Debian 13, ssh + :8080, no DNS name
- [ ] 192.168.127.35: Ubuntu 18.04, ssh, in the DHCP range
- [ ] 192.168.127.109: Debian 12, ssh, in the DHCP range
