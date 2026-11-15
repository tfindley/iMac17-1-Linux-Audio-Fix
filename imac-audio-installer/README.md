# iMac17,1 speaker tuning installer

Restores proper speaker sound on a **27" 5K iMac (Late 2015, iMac17,1)** running
Fedora or Ubuntu with PipeWire.

| Distro | Status |
|---|---|
| Fedora 45 | tested on the real machine |
| Ubuntu 26.04 | supported by the script; package names checked, not yet tested on hardware |

## Why it's needed

The iMac has separate tweeters and woofers, plus software speaker tuning in
macOS. Linux doesn't recognise the board, so out of the box it:

- drives all four speakers as one stereo pair, and
- plays them with no tuning.

This installer fixes both. It sets the `snd-hda-intel model=imac27` driver
option, which exposes 4 channels (FL/FR = tweeters, RL/RR = woofers). It then
installs a measured PipeWire filter-chain, which applies the crossover, per-speaker
EQ, bass enhancement, loudness compensation and woofer protection.

## Install

```bash
./install.sh      # installs packages + driver option (asks for sudo)
# reboot
./install.sh      # run again after reboot to finish
```

The script is safe to re-run.

When it's done, "iMac Speakers" is the default output. Use the normal volume
slider. The raw 4.0 hardware output is hidden from the sound menu, so it can't be
picked by accident; it stays at the 79% level the tuning's author recommends.

## Uninstall

```bash
./install.sh --uninstall   # then reboot
```

## What gets installed

| Path | Purpose |
|---|---|
| `/etc/modprobe.d/imac-audio.conf` | `options snd-hda-intel model=imac27` |
| `~/.config/pipewire/pipewire.conf.d/70-imac-audio.conf` | the tuning filter-chain ("iMac Speakers" sink) |
| `~/.local/share/imac-audio/*.wav` | measured FIR filters used by the chain |
| `~/.config/wireplumber/wireplumber.conf.d/51-imac-audio-profile.conf` | auto-selects the 4.0 card profile, hides the raw 4.0 output, and renames the card "Built-in Audio (raw, untuned)" |
| Fedora: `lsp-plugins-lv2 lv2-bankstown pipewire-module-filter-chain-lv2` | LV2 plugins used by the chain |
| Ubuntu: `lsp-plugins-lv2 bankstown-lv2 libspa-0.2-modules-extra pulseaudio-utils` | same plugins, plus `pactl`; `bankstown-lv2` is in *universe*, which the script enables if needed |

## Notes

- **Headphones:** the `imac27` option changes how the driver handles the
  headphone pin. The headphone jack hasn't been tested with this setup.
- **GNOME output list:** GNOME also lists the card's own "Speakers" port. A port
  can't be hidden, so the card is renamed instead and the entry reads
  "Speakers – Built-in Audio (raw, untuned)". Use "iMac Speakers". The mic
  shows the same card name, which is harmless.
- **Channel check:** if treble ever comes from the woofers, the channels are
  swapped. Run `--uninstall` to restore the previous setup.

## Credits

The speaker tuning comes from [taprobane99/iMac5KLinux](https://github.com/taprobane99/iMac5KLinux).
taprobane99 measured it on an iMac17,1 with a UMIK-1 microphone, following the
Asahi Linux audio method.

- Bundled from commit `4618023e43a5a580232fcdb1dee6706996b6d887`.
- MIT licensed; the licence is in `files/LICENSE.upstream`.
- The config differs from upstream only in the filter file path.
