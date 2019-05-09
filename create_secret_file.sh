#!/bin/bash

filename="$1"
gpg_pubkey_id="$2" # leave empty to use default receipt.

echo '>>> Please type keyring_name and password in the following format:

keyring1:password1
keyring2:password2

# Comment: This is a comment
login:12345678

>>> When you are done, use Ctrl-D to end.'

gpg --encrypt -o "$filename" -a -r "$gpg_pubkey_id"
exit $?
