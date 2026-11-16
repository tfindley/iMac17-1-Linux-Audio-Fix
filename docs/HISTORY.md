# History

The original work was done in a single Claude Code session on 2026-11-14/15. Its transcript is not in this repo, because it contains private account data.

## 2026-11-14: diagnosis and first fix

1. **Diagnosis.** Inspected the codec: CS4206, SSID `106b:8200`. The kernel
   applied no Apple fixup and exposed a single stereo speaker pin.
   - *Wrong conclusion at this point:* we decided there were no hidden channels.
     A 4-channel project we found, `iscy/imac-speakers-linux-pipewire`, is for
     the CS4208-based 2015 iMac, so it was set aside.
2. **Hand-tuned EQ.** Built a PipeWire `filter-chain` virtual sink "iMac Speakers
   (Tuned)" from builtin biquads. Kept in [reference/simple-eq.conf](reference/simple-eq.conf).
   It had:
   - −6 dB headroom
   - a 45 Hz high-pass
   - a low-shelf bass boost at 140 Hz
   - a low-mid cut
   - presence and air lifts

   Iterated on it at the user's request:
   - bass +6 → **+3 dB** ("bass sounds a bit high")
   - low-mid cut −2 dB @ 450 Hz → **−3.5 dB @ 400 Hz, Q 1.0**, presence +1.5 → **+2.5 dB**
     ("a bit muddy")
3. **Found a measured tuning.** Searched for published iMac17,1 settings and found
   `taprobane99/iMac5KLinux`. Its `Audio/` folder has:
   - FIR crossover/EQ filters measured with a UMIK-1 microphone
   - bankstown bass enhancement
   - LSP loudness compensation
   - woofer compressor and limiter

   It was also packaged by `MarkPronkin/imac5k-universal-linux-patcher`, where
   issue #9 reports it working on an iMac17,1. **This corrected the earlier
   diagnosis:** `snd-hda-intel model=imac27` exposes 4 channels on this machine.
4. **Installed it.**
   - Packages installed via dnf.
   - Modprobe option set; the first attempt silently didn't write the file and
     had to be re-run.
   - Rebooted.
   - Confirmed `picked fixup imac27`.
   - Switched to the 4.0 profile and set the hardware level to 79%.
   - Tone test: 3 kHz to FL/FR and 80 Hz to RL/RR. The user heard both
     correctly, so the mapping is right.
   - The hand EQ was disabled. The user's earlier bass/clarity tweaks don't
     carry over to the measured tuning; the user was happy with the result as is.
5. **Installer.** Created `imac-audio-installer/`:
   - an idempotent `install.sh` with `--uninstall`/`--force` and a checksummed
     bundle
   - a WirePlumber profile rule, verified by clearing WirePlumber's saved state
6. **Raw output in the sound menu.**
   - Hid the raw 4.0 sink (`Audio/Sink/Internal`, as the patcher does). This
     broke `pactl` volume setting, so the installer switched to `wpctl` by node id.
   - GNOME still listed "Speakers – Built-in Audio", because it lists card
     ports. The user chose to rename the card to "Built-in Audio (raw,
     untuned)" over removing card management, which would have lost the
     headphone jack.

## 2026-11-15: Ubuntu support

7. Added apt support to the installer:
   - Ubuntu 26.04 package names checked on packages.ubuntu.com.
   - `bankstown-lv2` (universe) and `libspa-0.2-modules-extra` confirmed to
     ship the same `libspa-filter-graph-plugin-lv2.so` as Fedora's package.
   - The apt code path was exercised with stub commands only; it is **not
     tested on real Ubuntu**.
8. Added `CLAUDE.md` and this history for git.

## 2026-11-16: Ubuntu tested on hardware

9. Fresh Ubuntu 26.04.1 (kernel 7.0, PipeWire 1.6.2, WirePlumber 0.5.13):
   - Before installing, checked that the debs ship every LV2 URI, control and
     port the config uses (LSP 1.2.27, bankstown 1.1.0). `pulseaudio-utils`
     doesn't pull in the PulseAudio daemon. The initramfs has no sound modules,
     so no `update-initramfs` is needed.
   - Ran the installer, rebooted, ran it again; no script changes needed. The
     quirk applied (`imac27`, `line_outs=2`) and every check passed.
   - The user confirmed by ear: music sounds right, and per-channel tones play
     on all four channels.
