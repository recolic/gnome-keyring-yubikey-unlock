# gnome-keyring-yubikey-unlock

Use GnuPG to unlock gnome-keyring, which is supported by yubikey and other smartcard.

## Problem

If you're logging into Linux with yubikey `pam_u2f.so`, gnome will ask you to unlock `login` keyring with your login password. 
But why are you using yubikey for login? Because I don't want to type the FUCKING LONG PASSWORD.

Currently the only solution is to set the password of `login` keyring to empty. But it's not secure. (If your harddisk got fucked one day, the hacker can get ALL your password saved by chromium, get everything in your keyring.)

## TODO

This program is using deprecated `libgnome-keyring-1` rather than `libsecret`, only because the author can not understand how to use `libsecret`. There's almost no document! (If you think auto-generated document is document, then all source code are well documented. )
