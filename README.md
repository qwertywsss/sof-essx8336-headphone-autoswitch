# sof-essx8336 headphone auto-switch

Fixes an audio bug on laptops with the ES8336 codec running the
`snd_soc_sof_es8336` driver (ALSA card `sof-essx8336`, common on several
Huawei MateBook models and similar laptops) where plugging/unplugging
headphones through the 3.5mm jack doesn't change the audio output: sound
keeps playing (or stays silent) through the speaker until the profile is
switched manually.

## Symptom

- Headphones don't produce sound when plugged in; audio keeps playing
  (or nothing plays at all) through the laptop speaker.
- Unplugging the headphones makes the speaker work normally again.
- `wpctl status` only ever shows one audio sink at a time (Speaker *or*
  Headphones, never both), and it doesn't switch on its own when
  plugging/unplugging.

## Root cause

On this card, the ALSA UCM configuration (`alsa-ucm-conf`) defines
"Speaker" and "Headphones" as two mutually exclusive card **profiles**
(instead of two ports of a single profile, which is the normal setup on
most laptops). On top of that, WirePlumber disables automatic profile
switching by default (`api.acp.auto-profile = false`,
`api.acp.auto-port = false`, see
`/usr/share/wireplumber/scripts/monitors/alsa.lua`), delegating dynamic
switching to its own "default nodes" logic — logic that only switches
the **active port within a single profile**, not the whole profile. As
a result, the jack is correctly detected at the kernel level
(`amixer -c0 cget numid=27` toggles between `on`/`off`), but nothing in
the system reacts to that change to switch the profile.

## Fix

Two pieces:

1. **`wireplumber.conf.d/51-sof-essx8336-auto-profile.conf`**: re-enables
   `api.acp.auto-profile` and `api.acp.auto-port` for this card only (in
   case it ever helps with port switching within a profile). On its own
   it does not solve the problem, because as explained above this card
   uses separate profiles, not ports.

2. **`headphone-jack-switch.sh`** + **`headphone-jack-switch.service`**:
   a systemd user service that runs `alsactl monitor hw:0` in the
   background, listens for events on the `Headphone Jack` control, and
   calls `pactl set-card-profile` to switch between the "Headphones" and
   "Speaker" profiles based on the sensor's actual state. This is the
   piece that actually fixes the automatic switching.

## Installation

```sh
./install.sh
```

This copies the files to `~/.local/bin`, `~/.config/systemd/user` and
`~/.config/wireplumber/wireplumber.conf.d`, enables the service, and
reminds you to restart PipeWire/WirePlumber once so the rule takes
effect.

## Verifying it works

```sh
systemctl --user status headphone-jack-switch.service
amixer -c0 cget numid=27                 # jack state
pactl list cards | grep 'Active Profile' # active profile
```

Plug/unplug the headphones and the profile (and the audio) should
switch on its own within a couple of seconds.

## Notes

- The profile names (`CARD_NAME`, `HP_PROFILE`, `SPK_PROFILE` in
  `headphone-jack-switch.sh`) are hardcoded for this specific card. If
  your `pactl list cards` shows different names, adjust them there.
- The jack sensor has some debounce (a second or two) before it reports
  the new state; it's normal for the switch not to be instant.
