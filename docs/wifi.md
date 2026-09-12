# Wi-Fi provisioning

Enable `hardware.miniM8s.wifi.enable` and provide a runtime wpa_supplicant
configuration at `hardware.miniM8s.wifi.configFile`. The module loads the
RTL8723BS firmware through nixpkgs and starts `mini-m8s-wireless.service`
when `wlan0` exists. Credentials are not part of the flake.

For the default path, create the configuration on the target as root:

```sh
sudo -i
install -d -m 700 /var/lib/mini-m8s
umask 077
wpa_passphrase 'YOUR_SSID' | sed '/^[[:space:]]*#psk=/d' > /var/lib/mini-m8s/wpa_supplicant.conf
```

Enter the password at the tool's local prompt. The filter removes its
plaintext-password comment. Do not pass the password as a command-line
argument or commit this generated file. Add this line to the file for
local status queries:

```text
ctrl_interface=/run/mini-m8s-wpa
```

Then start the service:

```sh
systemctl start mini-m8s-wireless
wpa_cli -p /run/mini-m8s-wpa -i wlan0 status
```

The Wi-Fi service uses the existing DHCP configuration, defaulting
`networking.useDHCP` to true. WPA/WPA2 Personal was tested. Other
wpa_supplicant network types have not been validated on this board.

A root-owned secret-manager file or symlink is also suitable if its target
has mode 0400 or 0600 and exists before the service starts. When provisioning
the file after boot, explicitly start the service as above.
