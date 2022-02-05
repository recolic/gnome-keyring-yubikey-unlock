# How To Autostart On Gnome

To automatically unlock keyrings right after logging into Gnome, you need to autostart
`unlock_keyrings.sh`. There are different ways to to this.

## Start Via Systemd

Create a new file at `~/.config/systemd/user/unlock-keyring.service` with the following content
(adapt the command after `ExecStart` to your setup):

```ini
[Unit]
Description=Unlock keyring using YubiKey
BindsTo=gnome-session.target

[Service]
Type=oneshot
ExecStart=/path/to/this/project/unlock_keyrings.sh /path/to/your_secret 123456

[Install]
WantedBy=gnome-session.target
```

Run the following command (not root):

```sh
systemctl --user enable unlock-keyring.service
```

When doing changes to the service file, run

```sh
systemctl --user daemon-reload
```
