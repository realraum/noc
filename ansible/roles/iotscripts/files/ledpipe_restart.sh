#!/bin/zsh
timeout 7 nc r3lothrpipeleds.iot.realraum.at 23 <<< '_G.node.restart()'
exit 0
