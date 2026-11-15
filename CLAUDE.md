# soundfix: iMac17,1 speaker tuning

Restores proper speaker sound on a 27" 5K iMac (Late 2015, **iMac17,1**) on Linux
with PipeWire. Fedora 45 is working and tested. Ubuntu 26.04 is supported by the
script but untested.

- `imac-audio-installer/`: the deliverable (installer script + bundled tuning).
- `imac-audio-installer.tar.gz`: a packed copy of that folder for off-machine backup.
  Rebuild it after any change:
  `tar czf imac-audio-installer.tar.gz imac-audio-installer`.
- `docs/HISTORY.md`: how we got here, including the wrong turns.
- `README.md`: the public-facing overview. The repo is
  `github.com/tfindley/iMac17-1-Linux-Audio-Fix`; it's private for now and may
  be made public, so keep committed content free of personal data.

## Hardware facts (verified on the machine)

- **Codec:** Cirrus Logic **CS4206**, subsystem `106b:8200`. Driver is
  `snd_hda_codec_cs420x`. The ALSA card is `HDA Intel PCH` at PCI `0000:00:1f.3`.
- **Without a quirk** the kernel logs `picked fixup for codec SSID 106b:0000`
  (none applied). It then exposes only one stereo speaker pin (`0x0b`) and the
  speakers sound thin.
- **`options snd-hda-intel model=imac27`** applies the `imac27` fixup and
  `line_outs=2 (0xa/0xb)`. The 4.0 profile then works: **FL/FR = tweeters,
  RL/RR = woofers**. The user verified this mapping with per-channel tone tests.
- **Not the CS4208:** the other 2015 iMacs use a CS4208 codec, so projects for
  those (e.g. `iscy/imac-speakers-linux-pipewire`) don't apply here.
- **Untested:** the headphone jack with the `imac27` quirk. The user doesn't use
  headphones yet.

## How the working setup is built

| Piece | Location (installed) |
|---|---|
| Driver option | `/etc/modprobe.d/imac-audio.conf` (sudo, reboot) |
| Tuning filter-chain, sink `audio_effect.iMac convolver` ("iMac Speakers") | `~/.config/pipewire/pipewire.conf.d/70-imac-audio.conf` |
| FIR filter WAVs | `~/.local/share/imac-audio/` |
| WirePlumber rules | `~/.config/wireplumber/wireplumber.conf.d/51-imac-audio-profile.conf` |
| Plugins | Fedora `lsp-plugins-lv2 lv2-bankstown pipewire-module-filter-chain-lv2`; Ubuntu `lsp-plugins-lv2 bankstown-lv2 libspa-0.2-modules-extra pulseaudio-utils` |

The WirePlumber rules do three things:
- select the `output:analog-surround-40+input:analog-stereo` profile
- hide the raw 4.0 sink (`media.class = Audio/Sink/Internal`)
- rename the card to "Built-in Audio (raw, untuned)"

The hardware 4.0 sink is set to **79%**, the level the tuning's author recommends.

The tuning is **taprobane99/iMac5KLinux**, `Audio/` folder, bundled from commit
`4618023e43a5a580232fcdb1dee6706996b6d887`. It's MIT licensed and was measured
on an iMac17,1 with a UMIK-1 microphone. Our config differs from upstream only
in the filter file paths (template `files/iMacAudio.conf.in`, placeholder
`@IRS_DIR@`). `files/SHA256SUMS` guards the bundle; regenerate it if you change
a file.

## Gotchas learned the hard way

- **GNOME's output list is built from card ports, not sinks.** Hiding the raw
  sink does not remove GNOME's "Speakers – Built-in Audio" entry, and PipeWire
  can't hide a port. The user chose to **rename the card** rather than drop ACP
  card management. Dropping it would remove the entry but kill the headphone
  jack.
- **Once the raw sink is hidden, `pactl` can't see it.** Set its volume with
  `wpctl set-volume <id>`, finding the node id via `pw-dump` (the installer
  does this). `wpctl` only takes numeric ids, not node names.
- **WirePlumber remembers the card profile in `~/.local/state/wireplumber/`.**
  The profile rule matters on a fresh install. It was verified by clearing that
  saved state and restarting.
- **`sudo` isn't passwordless here.** Commands that need root go to the user to
  run as `! <cmd>`. Check afterwards that they actually took effect: a chained
  `dnf … && tee …` once only half-ran.
- **Stacking EQs:** don't leave both the old hand EQ and the measured tuning
  active. The old one is kept only for reference in
  `docs/reference/simple-eq.conf`.

## Useful checks

```bash
journalctl -k -b | grep -i cs4206                  # expect "picked fixup imac27"
cat /sys/module/snd_hda_intel/parameters/model     # expect imac27,...
pactl list cards | sed -n '/1f.3/,$p' | grep 'Active Profile'
pactl get-default-sink                             # expect audio_effect.iMac convolver
pw-link -l | grep -A1 'effect_output.iMac convolver'   # 4 links to analog-surround-40
```

## Working on this repo

- **Re-run the installer to test:** `./imac-audio-installer/install.sh` is
  idempotent, and re-running it is the test. Uninstall with `--uninstall`.
- **When tuning or the installer changes:**
  - update `imac-audio-installer/README.md`
  - rebuild the tarball
  - add a line to `docs/HISTORY.md`
- **Keep the session transcript out of git.** The raw Claude Code transcript
  lives in `~/.claude/projects/-home-tristan-devel-llm-soundfix/` and contains
  private account info. On the original machine it can be resumed with
  `claude --resume ca7e11a6-9c15-42f5-b5db-f6ca227ccfa6`.
