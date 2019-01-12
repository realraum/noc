#!/bin/bash
cd "${BASH_SOURCE%/*}/"
exec ansible-lint _lint_roles.yml
