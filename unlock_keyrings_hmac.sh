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
iv_hex=$(parse_config iv)
ciphertext_b64=$(parse_config ciphertext)

if [[ -z "$rp_id" || -z "$credential_id" || -z "$salt" || -z "$iv_hex" || -z "$ciphertext_b64" ]]; then
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

# Fresh random challenge each time (authenticator signs it, but we don't verify here)
fresh_cdh=$(dd if=/dev/urandom bs=32 count=1 2>/dev/null | base64 -w 0)

assert_output=$(printf '%s\n%s\n%s\n%s\n' \
    "$fresh_cdh" "$rp_id" "$credential_id" "$salt" \
    | fido2-assert -G -h -p "${pin_opt[@]}" "$device" 2>/dev/null)

# For non-resident credential with hmac-secret, HMAC is on output line 5
hmac_b64=$(echo "$assert_output" | sed -n '5p')

if [[ "$hmac_b64" = '' ]]; then
    echo "Error: Failed to get HMAC secret from device." >&2
    exit 1
fi

key_hex=$(echo "$hmac_b64" | base64 -d | xxd -p -c 256)
plaintext=$(echo "$ciphertext_b64" | base64 -d \
    | openssl enc -d -aes-256-cbc -K "$key_hex" -iv "$iv_hex" -nosalt 2>/dev/null)

if [[ "$plaintext" = '' ]]; then
    echo "Error: Decryption failed. Wrong device or corrupted config?" >&2
    exit 1
fi

cd "$(where_am_i)"
echo "$plaintext" | bin/unlock_keyrings --secret-file - --quiet
exit $?
