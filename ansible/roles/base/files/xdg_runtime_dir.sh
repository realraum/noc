# Set XDG_RUNTIME_DIR correctly
if [ "$UID" -ne 0 ] && [ -z "${XDG_RUNTIME_DIR}" ]; then
    export XDG_RUNTIME_DIR="/run/user/$(id -u)"
fi
