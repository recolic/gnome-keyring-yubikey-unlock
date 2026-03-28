#!/bin/bash
# One-time setup: creates a FIDO2 HMAC-Secret protected secret file.
# The credential is created on your FIDO2 key (e.g. Thetis), and a local salt
# file is generated. The HMAC output (device + salt) is used as an AES-256 key
# to encrypt your keyring credentials. No GPG required.
#
# Usage: ./create_secret_file_hmac.sh <config_file> [device] [pin]
#
# Example:
#   ./create_secret_file_hmac.sh ~/.config/keyring-hmac.conf
#   ./create_secret_file_hmac.sh ~/.config/keyring-hmac.conf /dev/hidraw0
#   ./create_secret_file_hmac.sh ~/.config/keyring-hmac.conf /dev/hidraw0 123456

set -euo pipefail

config_file="${1:-}"
[[ "$config_file" = '' ]] && echo "Usage: $0 <config_file> [device] [pin]" && exit 1

# Detect device
if [[ "${2:-}" != '' ]]; then
    device="$2"
else
    device=$(fido2-token -L 2>/dev/null | head -1 | cut -d: -f1)
    if [[ "$device" = '' ]]; then
        echo "Error: No FIDO2 device found. Please insert your security key." >&2
        exit 1
    fi
    echo "Using device: $device"
fi

pin_opt=()
if [[ "${3:-}" != '' ]]; then
    pin_opt=(-t "pin=${3}")
fi

RP_ID="gnome-keyring-unlock"

# Random 32-byte client data hash (used as WebAuthn-style challenge)
cdh=$(dd if=/dev/urandom bs=32 count=1 2>/dev/null | base64 -w 0)
user_id=$(dd if=/dev/urandom bs=16 count=1 2>/dev/null | base64 -w 0)

echo ">>> Step 1: Creating FIDO2 credential on your security key..."
echo "    Touch your key when it blinks."

cred_output=$(printf '%s\n%s\n%s\n%s\n' \
    "$cdh" "$RP_ID" "gnome-keyring-user" "$user_id" \
    | fido2-cred -M -h "${pin_opt[@]}" "$device")

# Credential ID is on output line 5 (cdh, rp_id, format, auth_data, cred_id, ...)
credential_id=$(echo "$cred_output" | sed -n '5p')
echo "    Credential created (ID: ${credential_id:0:20}...)"

# 32-byte random salt stored alongside the config; the device HMAC output
# is the combination of this salt and the device's per-credential secret.
salt=$(dd if=/dev/urandom bs=32 count=1 2>/dev/null | base64 -w 0)

echo ">>> Step 2: Getting HMAC secret from your security key to test..."
echo "    Touch your key when it blinks."

fresh_cdh=$(dd if=/dev/urandom bs=32 count=1 2>/dev/null | base64 -w 0)
assert_output=$(printf '%s\n%s\n%s\n%s\n' \
    "$fresh_cdh" "$RP_ID" "$credential_id" "$salt" \
    | fido2-assert -G -h -p "${pin_opt[@]}" "$device")

# For non-resident credential with hmac-secret and no user-id in output,
# the HMAC secret is on output line 5 (cdh, rp_id, auth_data, sig, hmac).
hmac_b64=$(echo "$assert_output" | sed -n '5p')

if [[ "$hmac_b64" = '' ]]; then
    echo "Error: HMAC secret not returned by device. Does your key support hmac-secret?" >&2
    exit 1
fi
echo "    HMAC secret obtained."

# Random 16-byte IV for AES-256-CBC
iv_hex=$(dd if=/dev/urandom bs=16 count=1 2>/dev/null | xxd -p -c 256)
key_hex=$(echo "$hmac_b64" | base64 -d | xxd -p -c 256)

echo ""
echo ">>> Step 3: Enter keyring credentials (input hidden)."
echo "    Format: keyring_name:password  (one per line, # for comments)"
echo "    Example: login:My_Very_Long_Login_Password"
echo "    Press Enter then Ctrl-D when done."
echo ""

plaintext=""
while IFS= read -r -s line; do
    plaintext="${plaintext}${line}"$'\n'
done
plaintext="${plaintext%$'\n'}"  # strip trailing newline added by the loop
ciphertext_b64=$(printf '%s' "$plaintext" \
    | openssl enc -aes-256-cbc -K "$key_hex" -iv "$iv_hex" -nosalt \
    | base64 -w 0)

mkdir -p "$(dirname "$config_file")"
cat > "$config_file" <<EOF
# FIDO2 HMAC-Secret protected keyring credentials
# Created by create_secret_file_hmac.sh
# Requires: fido2-assert (libfido2), openssl, xxd
rp_id=$RP_ID
credential_id=$credential_id
salt=$salt
iv=$iv_hex
ciphertext=$ciphertext_b64
EOF
chmod 600 "$config_file"

echo ""
echo ">>> Config saved to: $config_file"
echo ""
echo "Add the following to GNOME autostart:"
echo "  $(dirname "$0")/unlock_keyrings_hmac.sh $config_file"
echo ""
echo "See doc/how-to-gnome-autostart.md for instructions."
