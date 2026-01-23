#!/bin/sh
set -eu

## this script takes keys on STDIN and programs teenstep eeprom

TUERDAEMON_STOP="/etc/init.d/doord stop"
TUERDAEMON_START="/etc/init.d/doord start"
UPDATE_KEYS_TOOL="/usr/local/bin/update-keys /dev/door"

## stop door daemon.
${TUERDAEMON_STOP}
## give daemons time to stop
sleep 1
# pipe me keys to program plz
${UPDATE_KEYS_TOOL}
## start daemon again
${TUERDAEMON_START}

