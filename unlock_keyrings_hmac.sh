#!/bin/bash
# Unlocks GNOME keyring at startup using a FIDO2 HMAC-Secret key (e.g. Thetis).
# Run this from GNOME autostart after creating a config with create_secret_file_hmac.sh.
#
# Usage: ./unlock_keyrings_hmac.sh <config_file> [device] [pin]
#
# Example:
#   ./unlock_keyrings_hmac.sh ~/.config/keyring-hmac.conf
#   ./unlock_keyrings_hmac.sh ~/.config/keyring-hmac.conf /dev/hidraw0
#   ./unlock_keyrings_hmac.sh ~/.config/keyring-hmac.conf /dev/hidraw0 123456

set -euo pipefail

_self_bin_name="$0"
config_file="${1:-}"
[[ "$config_file" = '' ]] && echo "Usage: $0 <config_file> [device] [pin]" && exit 1

function where_is_him() {
    local SOURCE="$1"
    while [ -h "$SOURCE" ]; do
        local DIR
        DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
        SOURCE="$(readlink "$SOURCE")"
        [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
    done
    echo -n "$( cd -P "$( dirname "$SOURCE" )" && pwd )"
}

function where_am_i() {
    local _my_path
    _my_path=$(type -p "${_self_bin_name}" 2>/dev/null || true)
    [[ "$_my_path" = "" ]] && where_is_him "$_self_bin_name" || where_is_him "$_my_path"
}

# Parse a key=value config file (handles base64 values that contain '=')
parse_config() {
    local key="$1"
    grep "^${key}=" "$config_file" | head -1 | cut -d= -f2-
}

rp_id=$(parse_config rp_id)
credential_id=$(parse_config credential_id)
salt=$(parse_config salt)
blob=$(parse_config blob)

if [[ -z "$rp_id" || -z "$credential_id" || -z "$salt" || -z "$blob" ]]; then
    echo "Error: config file '$config_file' is missing required fields." >&2
    exit 1
fi

# Detect device
if [[ "${2:-}" != '' ]]; then
    device="$2"
else
    device=$(fido2-token -L 2>/dev/null | head -1 | cut -d: -f1)
    if [[ "$device" = '' ]]; then
        echo "Error: No FIDO2 device found. Please insert your security key." >&2
        exit 1
    fi
fi

pin_opt=()
if [[ "${3:-}" != '' ]]; then
    pin_opt=(-t "pin=${3}")
fi

# Fresh random challenge each time (authenticator signs it, but we don't verify
# the signature here — we only need the hmac-secret output)
fresh_cdh=$(dd if=/dev/urandom bs=32 count=1 2>/dev/null | base64 -w 0)

if ! assert_output=$(printf '%s\n%s\n%s\n%s\n' \
        "$fresh_cdh" "$rp_id" "$credential_id" "$salt" \
        | timeout 30s fido2-assert -G -h -p "${pin_opt[@]}" "$device"); then
    echo "Error: fido2-assert failed (device not found, wrong PIN, or timed out)." >&2
    exit 1
fi

# For non-resident credential with hmac-secret, HMAC is on output line 5
hmac_b64=$(echo "$assert_output" | sed -n '5p')

# Validate: 32 bytes base64-encodes to exactly 44 characters
if [[ -z "$hmac_b64" || ${#hmac_b64} -ne 44 ]]; then
    echo "Error: Unexpected HMAC secret (expected 44 base64 chars, got ${#hmac_b64})." >&2
    echo "       fido2-assert output format may have changed." >&2
    exit 1
fi

# Decrypt with AES-256-GCM. Any tampering with the blob will cause an
# authentication failure here before the plaintext is used.
# Key is passed via environment variable to avoid exposure in the process table.
if ! plaintext=$(printf '%s' "$blob" | \
        HMAC_KEY="$hmac_b64" python3 -c '
import base64, os, sys
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.exceptions import InvalidTag
key = base64.b64decode(os.environ["HMAC_KEY"])
data = base64.b64decode(sys.stdin.read().strip())
nonce, ct = data[:12], data[12:]
try:
    pt = AESGCM(key).decrypt(nonce, ct, b"gnome-keyring-hmac")
except InvalidTag:
    sys.stderr.write("Error: Authentication failed. Wrong device or config tampered.\n")
    sys.exit(1)
sys.stdout.buffer.write(pt)
'); then
    exit 1
fi

cd "$(where_am_i)"
printf '%s\n' "$plaintext" | bin/unlock_keyrings --secret-file - --quiet
exit $?
