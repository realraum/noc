#!/usr/bin/python
# -*- coding: utf-8 -*-

from __future__ import absolute_import, division, print_function
__metaclass__ = type


import traceback
import time

try:
    import libvirt
except ImportError:
    HAS_VIRT = False
else:
    HAS_VIRT = True

from ansible.module_utils.basic import AnsibleModule
from ansible.module_utils._text import to_native


VIRT_FAILED = 1
VIRT_SUCCESS = 0
VIRT_UNAVAILABLE = 2

VIRT_STATE_NAME_MAP = {
    0: "running",
    1: "running",
    2: "running",
    3: "paused",
    4: "shutdown",
    5: "shutdown",
    6: "crashed"
}


class VMNotFound(Exception):
    pass


class LibvirtConnection(object):

    def __init__(self, uri, module):

        self.module = module

        cmd = "uname -r"
        rc, stdout, stderr = self.module.run_command(cmd)

        if "xen" in stdout:
            conn = libvirt.open(None)
        elif "esx" in uri:
            auth = [[libvirt.VIR_CRED_AUTHNAME, libvirt.VIR_CRED_NOECHOPROMPT], [], None]
            conn = libvirt.openAuth(uri, auth)
        else:
            conn = libvirt.open(uri)

        if not conn:
            raise Exception("hypervisor connection failure")

        self.conn = conn

    def find_vm(self, vmid):
        """
        Extra bonus feature: vmid = -1 returns a list of everything
        """
        conn = self.conn

        vms = []

        # this block of code borrowed from virt-manager:
        # get working domain's name
        ids = conn.listDomainsID()
        for id in ids:
            vm = conn.lookupByID(id)
            vms.append(vm)
        # get defined domain
        names = conn.listDefinedDomains()
        for name in names:
            vm = conn.lookupByName(name)
            vms.append(vm)

        if vmid == -1:
            return vms

        for vm in vms:
            if vm.name() == vmid:
                return vm

        raise VMNotFound("virtual machine %s not found" % vmid)

    def get_status(self, vmid):
        state = self.find_vm(vmid).info()[0]
        return VIRT_STATE_NAME_MAP.get(state, "unknown")


class Virt(object):

    def __init__(self, uri, module):
        self.module = module
        self.uri = uri

    def __get_conn(self):
        self.conn = LibvirtConnection(self.uri, self.module)
        return self.conn

    def status(self, vmid):
        """
        Return a state suitable for server consumption.  Aka, codes.py values, not XM output.
        """
        self.__get_conn()
        return self.conn.get_status(vmid)


def core(module):

    states = module.params.get('states', None)
    guest = module.params.get('name', None)
    uri = module.params.get('uri', None)
    delay = module.params.get('delay', None)
    sleep = module.params.get('sleep', None)
    timeout = module.params.get('timeout', None)

    v = Virt(uri, module)
    res = {'changed': False, 'failed': True}

    if delay > 0:
        time.sleep(delay)

    for _ in range(0, timeout, sleep):
        state = v.status(guest)
        if state in states:
            res['state'] = state
            res['failed'] = False
            res['msg'] = "guest '%s' has reached state: %s" % (guest, state)
            return VIRT_SUCCESS, res

        time.sleep(sleep)

    res['msg'] = "timeout waiting for guest '%s' to reach one of states: %s" % (guest, ', '.join(states))
    return VIRT_FAILED, res


def main():

    module = AnsibleModule(argument_spec=dict(
        name=dict(aliases=['guest'], required=True),
        states=dict(type='list', required=True),
        uri=dict(default='qemu:///system'),
        delay=dict(type='int', default=0),
        sleep=dict(type='int', default=1),
        timeout=dict(type='int', default=300),
    ))

    if not HAS_VIRT:
        module.fail_json(
            msg='The `libvirt` module is not importable. Check the requirements.'
        )

    for state in module.params.get('states', None):
        if state not in set(VIRT_STATE_NAME_MAP.values()):
            module.fail_json(
                msg="states contains invalid state '%s', must be one of %s" % (state, ', '.join(set(VIRT_STATE_NAME_MAP.values())))
            )

    rc = VIRT_SUCCESS
    try:
        rc, result = core(module)
    except Exception as e:
        module.fail_json(msg=to_native(e), exception=traceback.format_exc())

    if rc != 0:  # something went wrong emit the msg
        module.fail_json(rc=rc, msg=result)
    else:
        module.exit_json(**result)


if __name__ == '__main__':
    main()
