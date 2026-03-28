#!/bin/bash
# One-time setup: creates a FIDO2 HMAC-Secret protected secret file.
# The credential is created on your FIDO2 key (e.g. Thetis), and a local salt
# is generated. The HMAC output (device + salt) is used as an AES-256-GCM key
# to encrypt your keyring credentials. No GPG required.
#
# Usage: ./create_secret_file_hmac.sh <config_file> [device] [pin]
#
# Example:
#   ./create_secret_file_hmac.sh ~/.config/keyring-hmac.conf
#   ./create_secret_file_hmac.sh ~/.config/keyring-hmac.conf /dev/hidraw0
#   ./create_secret_file_hmac.sh ~/.config/keyring-hmac.conf /dev/hidraw0 123456
#
# Dependencies: fido2-cred, fido2-assert, fido2-token (libfido2),
#               python3-cryptography, xxd

set -euo pipefail

config_file="${1:-}"
[[ "$config_file" = '' ]] && echo "Usage: $0 <config_file> [device] [pin]" && exit 1

# Check dependencies
for cmd in fido2-cred fido2-assert fido2-token xxd python3; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "Error: '$cmd' not found. Please install it." >&2
        exit 1
    fi
done
if ! python3 -c "from cryptography.hazmat.primitives.ciphers.aead import AESGCM" 2>/dev/null; then
    echo "Error: python3-cryptography not found. Install with: sudo apt install python3-cryptography" >&2
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
    echo "Using device: $device"
fi

pin_opt=()
if [[ "${3:-}" != '' ]]; then
    pin_opt=(-t "pin=${3}")
fi

RP_ID="gnome-keyring-unlock"

# Random 32-byte client data hash (WebAuthn-style challenge)
cdh=$(dd if=/dev/urandom bs=32 count=1 2>/dev/null | base64 -w 0)
user_id=$(dd if=/dev/urandom bs=16 count=1 2>/dev/null | base64 -w 0)

echo ">>> Step 1: Creating FIDO2 credential on your security key..."
echo "    Touch your key when it blinks."

cred_output=$(printf '%s\n%s\n%s\n%s\n' \
    "$cdh" "$RP_ID" "gnome-keyring-user" "$user_id" \
    | timeout 60s fido2-cred -M -h "${pin_opt[@]}" "$device")

# Credential ID is on output line 5 (cdh, rp_id, format, auth_data, cred_id, ...)
credential_id=$(echo "$cred_output" | sed -n '5p')
if [[ -z "$credential_id" ]]; then
    echo "Error: Could not extract credential ID from fido2-cred output." >&2
    exit 1
fi
echo "    Credential created (ID: ${credential_id:0:20}...)"

# 32-byte random salt; the device HMAC output is a function of this salt
# and the device's per-credential secret — neither alone is sufficient.
salt=$(dd if=/dev/urandom bs=32 count=1 2>/dev/null | base64 -w 0)

echo ">>> Step 2: Getting HMAC secret from your security key..."
echo "    Touch your key when it blinks."

fresh_cdh=$(dd if=/dev/urandom bs=32 count=1 2>/dev/null | base64 -w 0)
assert_output=$(printf '%s\n%s\n%s\n%s\n' \
    "$fresh_cdh" "$RP_ID" "$credential_id" "$salt" \
    | timeout 30s fido2-assert -G -h -p "${pin_opt[@]}" "$device")

# For non-resident credential with hmac-secret and no user-id in output,
# the HMAC secret is on output line 5 (cdh, rp_id, auth_data, sig, hmac).
hmac_b64=$(echo "$assert_output" | sed -n '5p')

# Validate: 32 bytes base64-encodes to exactly 44 characters
if [[ -z "$hmac_b64" || ${#hmac_b64} -ne 44 ]]; then
    echo "Error: Unexpected HMAC secret (expected 44 base64 chars, got ${#hmac_b64})." >&2
    echo "       Does your key support hmac-secret? fido2-assert output may have changed." >&2
    exit 1
fi
echo "    HMAC secret obtained."

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

# Encrypt with AES-256-GCM (authenticated encryption).
# Key is passed via environment variable to avoid exposure in the process table.
# Output blob = nonce (12 bytes) || ciphertext || tag (16 bytes), base64-encoded.
blob=$(printf '%s' "$plaintext" | \
    HMAC_KEY="$hmac_b64" python3 -c '
import base64, os, sys
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
key = base64.b64decode(os.environ["HMAC_KEY"])
nonce = os.urandom(12)
pt = sys.stdin.buffer.read()
ct = AESGCM(key).encrypt(nonce, pt, b"gnome-keyring-hmac")
sys.stdout.write(base64.b64encode(nonce + ct).decode())
')

mkdir -p "$(dirname "$config_file")"
cat > "$config_file" <<EOF
# FIDO2 HMAC-Secret protected keyring credentials
# Created by create_secret_file_hmac.sh
# Requires: fido2-assert (libfido2), python3-cryptography, xxd
rp_id=$RP_ID
credential_id=$credential_id
salt=$salt
blob=$blob
EOF
chmod 600 "$config_file"

echo ""
echo ">>> Config saved to: $config_file"
echo ""
echo "Add the following to GNOME autostart:"
echo "  $(dirname "$0")/unlock_keyrings_hmac.sh $config_file"
echo ""
echo "See doc/how-to-gnome-autostart.md for instructions."
