#!/bin/bash
# Watches the internal sof-essx8336 sound card's headphone jack detect
# control and switches the ALSA/PipeWire card profile between
# "Headphones" and "Speaker" accordingly, since this card exposes them
# as two separate, mutually-exclusive profiles instead of ports of one
# profile (so WirePlumber's built-in auto-port switching can't bridge them).

CARD_NAME="alsa_card.pci-0000_00_1f.3-platform-sof-essx8336"
HP_PROFILE="HiFi (HDMI1, HDMI2, HDMI3, Headphones, Headset, Mic)"
SPK_PROFILE="HiFi (HDMI1, HDMI2, HDMI3, Headset, Mic, Speaker)"

apply_profile() {
    local state
    state=$(amixer -c0 cget numid=27 2>/dev/null | grep -o 'values=on\|values=off' | cut -d= -f2)
    if [[ "$state" == "on" ]]; then
        pactl set-card-profile "$CARD_NAME" "$HP_PROFILE" 2>/dev/null
    elif [[ "$state" == "off" ]]; then
        pactl set-card-profile "$CARD_NAME" "$SPK_PROFILE" 2>/dev/null
    fi
}

# Sync once at startup in case the jack state changed while this wasn't running.
apply_profile

alsactl monitor hw:0 | while read -r line; do
    if [[ "$line" == *"Headphone Jack"* ]]; then
        apply_profile
    fi
done
