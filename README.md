# gnome-keyring-yubikey-unlock

![](https://img.shields.io/badge/CXXSTD-C%2B%2B14-green)

Use GnuPG to unlock gnome-keyring, which is supported by yubikey and other smartcard.

## Problem

If you're logging into Linux with yubikey `pam_u2f.so`, gnome will ask you to unlock `login` keyring with your login password. 
But why are you using yubikey for login? Because I don't want to type the FUCKING LONG PASSWORD.

Currently the only solution is to set the password of `login` keyring to empty. But it's not secure. (If your harddisk got fucked one day, the hacker can get ALL your password saved by chromium, get everything in your keyring.)

## Solution

I encrypt the `keyring-name : password` pair with GnuPG and save it as `secret-file`. Then on starting gnome, you have yubikey inserted. Then an auto-started script call GnuPG to decrypt the secret file, and pipe use the password to unlock your keyring. GnuPG will ask you to insert yubikey.

## Dependencies
The project uses libgnome-keyring-dev

### Ubuntu 20.04
libgnome-keyring-dev is not in the repositories, you have to install it and its dependencies manually:
```
wget http://archive.ubuntu.com/ubuntu/pool/main/g/glibc/multiarch-support_2.27-3ubuntu1_amd64.deb
wget http://security.ubuntu.com/ubuntu/pool/universe/libg/libgnome-keyring/libgnome-keyring-common_3.12.0-1build1_all.deb
wget http://security.ubuntu.com/ubuntu/pool/universe/libg/libgnome-keyring/libgnome-keyring0_3.12.0-1build1_amd64.deb
wget http://security.ubuntu.com/ubuntu/pool/universe/libg/libgnome-keyring/gir1.2-gnomekeyring-1.0_3.12.0-1build1_amd64.deb
wget http://security.ubuntu.com/ubuntu/pool/universe/libg/libgnome-keyring/libgnome-keyring-dev_3.12.0-1build1_amd64.deb

sudo dpkg -i multiarch-support_2.27-3ubuntu1_amd64.deb
sudo dpkg-reconfigure multiarch-support
sudo dpkg -i libgnome-keyring-common_3.12.0-1build1_all.deb libgnome-keyring0_3.12.0-1build1_amd64.deb gir1.2-gnomekeyring-1.0_3.12.0-1build1_amd64.deb libgnome-keyring-dev_3.12.0-1build1_amd64.deb
```

## Usage

> I recommend you to **configure Yubikey as GPG smartcard**. The system would just ask you to unlock gnome-keyring with your default GPG software. You may generate a new GPG key for yubikey, or move your existing GPG key into yubikey. Refer to google for these knowledge. 

First, build the project from source.
```
git clone https://github.com/recolic/gnome-keyring-yubikey-unlock --recursive
cd gnome-keyring-yubikey-unlock/src && make && cd ..
```

Then, create your secret file.
```
gnome-keyring-yubikey-unlock/create_secret_file.sh /path/to/your_secret [Your GnuPG public key]
# input your keyring:password
```

Then, add the following command to gnome-autostart. You should know how to auto-run a command after starting gnome.

```
/path/to/this/project/unlock_keyrings.sh /path/to/your_secret
```

You're all set! Re-login and have a try!

## FAQ

- Keyring not exist? The name is correct.

run `tools/list_keyrings.sh` to check name of your keyrings. The `login` keyring may be shown as `登录` based on your locale.

## TODO

This program is using deprecated `libgnome-keyring-1` rather than `libsecret`, only because the author can not understand how to use `libsecret`. There's almost no document! (If you think auto-generated document is document, then all source code are well documented. )
