#!/bin/bash
# Regression check for setup-persistent-identity on images without a
# separate /home (issue #8). It deletes /etc/ssh host keys, so it only runs
# inside a throwaway container:
#
#   podman run --rm -v "$PWD":/src:ro,Z docker.io/library/debian:bookworm \
#       bash /src/tests/test-setup-persistent-identity.sh
set -eu

if [ ! -f /.dockerenv ] && [ ! -f /run/.containerenv ]; then
    echo "Refusing to run outside a container: this deletes /etc/ssh host keys." >&2
    exit 2
fi

SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/usr/local/sbin/setup-persistent-identity"
command -v ssh-keygen >/dev/null || {
    apt-get -qq update >/dev/null
    apt-get -qq install -y --no-install-recommends openssh-client util-linux >/dev/null
}
mkdir -p /etc/ssh
if mountpoint -q /home; then
    echo "Precondition failed: /home must not be a mountpoint" >&2
    exit 2
fi

fail=0
check() {
    if [ "$2" = "$3" ]; then echo "ok   - $1"; else echo "FAIL - $1 (got '$2', want '$3')"; fail=1; fi
}
fp() { ssh-keygen -lf "/etc/ssh/ssh_host_$1_key.pub" | cut -d' ' -f2; }

# 1. No host keys: all three are generated, exit 0.
rm -f /etc/ssh/ssh_host_*
rc=0; bash "$SCRIPT" >/dev/null 2>&1 || rc=$?
check "no keys: exit status" "$rc" 0
for t in rsa ecdsa ed25519; do
    check "no keys: ssh_host_${t}_key created" "$([ -s "/etc/ssh/ssh_host_${t}_key" ] && echo yes)" yes
done

# 2. One key pair missing: only that pair is recreated.
rsa=$(fp rsa); ed=$(fp ed25519)
rm -f /etc/ssh/ssh_host_ecdsa_key /etc/ssh/ssh_host_ecdsa_key.pub
rc=0; bash "$SCRIPT" >/dev/null 2>&1 || rc=$?
check "partial: exit status" "$rc" 0
check "partial: ecdsa recreated" "$([ -s /etc/ssh/ssh_host_ecdsa_key ] && echo yes)" yes
check "partial: rsa unchanged" "$(fp rsa)" "$rsa"
check "partial: ed25519 unchanged" "$(fp ed25519)" "$ed"

# 3. ssh-keygen writes nothing but exits 0 (as it does on a write error):
#    the script must fail.
mock=$(mktemp -d)
printf '#!/bin/sh\nexit 0\n' > "$mock/ssh-keygen"
chmod +x "$mock/ssh-keygen"
rm -f /etc/ssh/ssh_host_*
rc=0; PATH="$mock:$PATH" bash "$SCRIPT" >/dev/null 2>&1 || rc=$?
check "keygen wrote nothing: exit status" "$rc" 1
rm -rf "$mock"

exit "$fail"
