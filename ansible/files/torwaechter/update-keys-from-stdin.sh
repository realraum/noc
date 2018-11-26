#!/bin/sh
set -eu

## this script takes keys on STDIN and programs teenstep eeprom

MONIT_STOP="/etc/init.d/monit stop"
MONIT_START="/etc/init.d/monit start"
TUERDAEMON_STOP="/etc/init.d/tuer_core stop"
TUERDAEMON_START="/etc/init.d/tuer_core start"
UPDATE_KEYS_TOOL="/flash/tuer/update-keys /dev/door"

## stop monit. it monit not installed or error. don't start monit again later
${MONIT_STOP} || MONIT_START=""
## stop door daemon.
${TUERDAEMON_STOP}
## give daemons time to stop
sleep 1
# pipe me keys to program plz
${UPDATE_KEYS_TOOL}
## start daemon again
${TUERDAEMON_START}
${MONIT_START}

