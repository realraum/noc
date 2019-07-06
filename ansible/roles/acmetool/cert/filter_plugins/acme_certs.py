from __future__ import (absolute_import, division, print_function)
__metaclass__ = type

from functools import partial

from ansible import errors


def acme_cert_nonexistent(data, hostnames):
    try:
        return [hostnames[i] for i, d in enumerate(data) if d['stat']['exists'] == False]
    except Exception as e:
        raise errors.AnsibleFilterError("acme_cert_nonexistent(): %s" % str(e))


class FilterModule(object):

    ''' acme certificate filters '''
    filter_map = {
        'acme_cert_nonexistent': acme_cert_nonexistent,
    }

    def filters(self):
        return self.filter_map
