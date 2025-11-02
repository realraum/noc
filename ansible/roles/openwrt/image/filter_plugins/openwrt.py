from __future__ import (absolute_import, division, print_function)
__metaclass__ = type

from ansible import errors


def openwrt_mixin_type(data, mixin_type):
    try:
        return [{'key': x, 'value': data[x]} for x in data if mixin_type in data[x]]

    except Exception as e:
        raise errors.AnsibleFilterError("openwrt_mixin_type(): %s" % str(e))


class FilterModule(object):

    filter_map = {
        'openwrt_mixin_type': openwrt_mixin_type,
    }

    def filters(self):
        return self.filter_map
