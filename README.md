# biscuit-apk

A signed [apk](https://wiki.alpinelinux.org/wiki/Alpine_Package_Keeper) package
feed for the postmarketOS port of the **Amazon Echo Dot 2nd generation**
(2016, codename `biscuit`, model RS03QR).

The packages here are installed on top of a stock postmarketOS edge rootfs, so
they work on any Echo Dot 2 running pmOS — not just the device they were built
on. Nothing in the feed is device-serial specific.

## Using the feed

The feed is served by GitHub Pages from the `gh-pages` branch of this
repository:

```
https://liamtw22.github.io/biscuit-apk/edge
```

On the device, install the public key and add the repository:

```sh
wget -O /etc/apk/keys/biscuit-apk.rsa.pub \
  https://liamtw22.github.io/biscuit-apk/biscuit-apk.rsa.pub
echo 'https://liamtw22.github.io/biscuit-apk/edge' >> /etc/apk/repositories
apk update
```

`apk` appends `/<arch>/APKINDEX.tar.gz` to that URL itself, so the repository
line stops at `/edge`. The index is signed; installing the public key first is
what lets `apk add` work without `--allow-untrusted`.

Only this one key is needed. The `.apk` files are signed by the build machine's
own key, but `apk` verifies each package against the checksum recorded in the
signed index rather than against the package's own signature, so the build key
does not have to be trusted. Verified on apk-tools 3.0.8: with no keys trusted
the index is rejected as `UNTRUSTED signature`, with only this key trusted the
packages install, and a package altered after indexing is refused.

From `6-r230` onward neither step is needed on a device that already has the
core package: it ships this key at `/usr/share/biscuit/biscuit-apk.rsa.pub`, and
the `biscuit-persist` service copies it into `/etc/apk/keys/` and adds the
repository line on every boot. That matters because flashing an update replaces
the rootfs, which is where both of them live - without it a device would quietly
stop seeing its own updates.

## What is in the feed

| Package | Contents |
| --- | --- |
| `device-amazon-biscuit` | Core device support: audio, the LED ring, Wi-Fi and Bluetooth bring-up, the `:8080` settings page, persistence and time sync. A device with only this is a working Bluetooth speaker with a web UI. |
| `device-amazon-biscuit-voice` | Wake word detection and a Home Assistant voice satellite. |
| `device-amazon-biscuit-sendspin` | The [sendspin](https://github.com/liamtw22/sendspin-python-cli) player and the music visualiser that drives the ring. |
| `device-amazon-biscuit-pulseaudio` | Configuration, pulled in automatically if PulseAudio is installed. |

The two applications are independent - install either, both or neither:

```sh
apk add device-amazon-biscuit            # the device
apk add device-amazon-biscuit-voice      # + voice assistant
apk add device-amazon-biscuit-sendspin   # + music speaker
```

Both depend on the core package at the *same* pkgrel, so upgrade them together.

## What is deliberately not here

No Amazon assets. The LED ring runs on effects generated at runtime, and the
beamformer weights are computed from the measured microphone geometry under a
diffuse-field noise model rather than copied from anywhere. No earcons ship at
all: with the voice assistant installed the device uses that project's own
sounds, and without it it stays silent until its owner extracts stock sounds
from their own hardware into `/opt/persist/earcon`.

Stock's microphone tuning is still selectable, but only on a device whose owner
has imported the coefficient files from their own stock partition. Those files
are Amazon's and are never redistributed here.

## Verifying a download

```sh
apk verify device-amazon-biscuit-sendspin-*.apk
```

`APKINDEX.tar.gz` is signed with the key committed here as
`biscuit-apk.rsa.pub`, and every package's checksum is recorded in it. The
key's SHA-256 is printed by:

```sh
sha256sum biscuit-apk.rsa.pub
```

## Repository layout

`main` holds only this README, the public key and the publishing script — it
stays a few kilobytes so cloning it is cheap.

The feed itself lives on the orphan branch `gh-pages`, which is **replaced by a
single fresh commit on every publish**. Package binaries therefore never
accumulate in history: a clone of the feed costs one copy of the current
packages (~50 MB) no matter how many releases have been made.

To publish a newly built feed:

```sh
tools/publish-feed.sh /path/to/built/feed
```

## Building the packages

The packages are built from
[pmaports-biscuit](https://github.com/liamtw22/pmaports-biscuit) with
`pmbootstrap`. This repository only distributes the results.
