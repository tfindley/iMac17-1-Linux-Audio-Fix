# iMac17,1 Linux Audio Fix

Proper speaker sound for the **27" 5K iMac (Late 2015, `iMac17,1`)** on Linux.

On macOS these iMacs sound full and rich. On a stock Linux install they sound
thin and tinny. There are two reasons:

1. **The speakers are wired as one stereo pair.** The iMac has separate
   tweeters and woofers, but the kernel doesn't recognise the board. It applies
   no Apple fixup, so all four drivers get the same full-range signal.
2. **There's no speaker tuning.** On these iMacs the "big" sound comes from DSP
   in macOS: crossover, EQ and bass enhancement. Linux plays the raw signal.

This repo fixes both. It sets the kernel's `imac27` codec option, which exposes
the tweeters and woofers as separate channels. It then installs a **measured**
PipeWire speaker tuning:
- per-speaker FIR crossover and EQ
- psychoacoustic bass enhancement
- loudness compensation
- woofer protection

## Supported systems

| Distro | Status |
|---|---|
| Fedora 45 (GNOME, PipeWire 1.6) | ✅ tested on real hardware |
| Ubuntu 26.04.1 (GNOME, PipeWire 1.6) | ✅ tested on real hardware |

You need PipeWire and WirePlumber 0.5+. The installer refuses to run on any
model other than `iMac17,1` unless you pass `--force`. The tuning was measured
on this model and may not suit others.

## Install

```bash
git clone https://github.com/tfindley/iMac17-1-Linux-Audio-Fix.git
cd iMac17-1-Linux-Audio-Fix/imac-audio-installer
./install.sh      # installs plugins + kernel option (asks for sudo)
sudo reboot
./install.sh      # run again after the reboot to finish
```

Afterwards, **iMac Speakers** is your default output. Use the normal volume
slider.

GNOME's output list also shows **"Speakers – Built-in Audio (raw, untuned)"**.
That's the raw hardware output, which can't be hidden from GNOME. Don't select
it.

To uninstall, run `./install.sh --uninstall`, then reboot.

See [imac-audio-installer/README.md](imac-audio-installer/README.md) for exactly
what gets installed where.

## Known limitations

- **Headphone jack:** untested with the `imac27` option, which changes how the
  driver handles the headphone pin.
- **Channel mapping:** if treble comes out of the woofers, the channels are
  swapped on your board. Uninstall and open an issue.

## Repository layout

| Path | What it is |
|---|---|
| `imac-audio-installer/` | the installer script and bundled tuning files |
| `imac-audio-installer.tar.gz` | packed copy of the installer for offline backup |
| `docs/HISTORY.md` | how this fix was worked out, including the dead ends |
| `docs/reference/simple-eq.conf` | an earlier hand-tuned stereo EQ (superseded, kept for reference) |
| `CLAUDE.md` | technical notes and gotchas, written for AI coding assistants but readable by anyone |

## Credits

- **Speaker tuning:** [taprobane99/iMac5KLinux](https://github.com/taprobane99/iMac5KLinux),
  measured on an iMac17,1 with a UMIK-1 microphone using the Asahi Linux audio
  method. MIT licensed; bundled unmodified apart from the filter file paths. See
  [`imac-audio-installer/files/LICENSE.upstream`](imac-audio-installer/files/LICENSE.upstream).
- **Hiding the raw output:** the approach comes from
  [MarkPronkin/imac5k-universal-linux-patcher](https://github.com/MarkPronkin/imac5k-universal-linux-patcher).
- **Plugins:** [bankstown](https://github.com/chadmed/bankstown) by chadmed and
  [LSP Plugins](https://lsp-plug.in/).

## Licence

MIT: see [LICENSE](LICENSE). The bundled speaker tuning keeps its own upstream
MIT licence.
