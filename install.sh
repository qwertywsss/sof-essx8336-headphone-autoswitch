#!/bin/bash
# Installs the auto-switch fix for the current user.
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p ~/.local/bin
cp "$DIR/headphone-jack-switch.sh" ~/.local/bin/headphone-jack-switch.sh
chmod +x ~/.local/bin/headphone-jack-switch.sh

mkdir -p ~/.config/systemd/user
cp "$DIR/headphone-jack-switch.service" ~/.config/systemd/user/headphone-jack-switch.service

mkdir -p ~/.config/wireplumber/wireplumber.conf.d
cp "$DIR/wireplumber.conf.d/51-sof-essx8336-auto-profile.conf" \
   ~/.config/wireplumber/wireplumber.conf.d/51-sof-essx8336-auto-profile.conf

systemctl --user daemon-reload
systemctl --user enable --now headphone-jack-switch.service

echo "Listo. Reinicia PipeWire/WirePlumber una vez para aplicar la regla de auto-profile:"
echo "  systemctl --user restart wireplumber pipewire pipewire-pulse"
