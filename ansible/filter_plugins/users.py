from __future__ import (absolute_import, division, print_function)
__metaclass__ = type

from ansible import errors


def user_ssh_keys(data, db):
    try:
        ssh_keys = []
        for user in data:
            try:
                for key in db[user]['ssh']:
                    ssh_keys.append(key)
            except KeyError:
                pass

        return ssh_keys
    except Exception as e:
        raise errors.AnsibleFilterError("user_ssh_keys(): %s" % str(e))


class FilterModule(object):

    ''' extract values form users db '''
    filter_map = {
        'user_ssh_keys': user_ssh_keys,
    }

    def filters(self):
        return self.filter_map
