#!/bin/sh
# Make an offline install bundle from a built, signed feed.
#
# The feed directory is already a valid apk repository, so "offline" needs no
# new format: it needs the same tree, the public key beside it, and the two
# commands that use them. This exists because a device that cannot reach
# GitHub - no route, a locked-down network, or a first boot before Wi-Fi is
# configured - otherwise cannot install the applications at all.
#
# Usage: tools/make-offline-bundle.sh <feed dir> [output.tar.gz]
set -eu

SRC=${1:-}
OUT=${2:-biscuit-apk-offline.tar.gz}
[ -n "$SRC" ] || { echo "usage: $0 <feed dir> [out.tar.gz]" >&2; exit 1; }
[ -f "$SRC/APKINDEX.tar.gz" ] || { echo "no APKINDEX.tar.gz in $SRC" >&2; exit 1; }

# An unsigned index would force --allow-untrusted at the far end, which is
# exactly the habit an offline path should not teach.
tar tzf "$SRC/APKINDEX.tar.gz" | grep -q '^\.SIGN\.RSA\.' || {
	echo "APKINDEX.tar.gz is not signed" >&2; exit 1; }

REPO=$(cd "$(dirname "$0")/.." && pwd)
KEY="$REPO/biscuit-apk.rsa.pub"
[ -f "$KEY" ] || { echo "missing $KEY" >&2; exit 1; }

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/biscuit-apk-offline/edge/aarch64"
cp "$SRC"/*.apk "$SRC/APKINDEX.tar.gz" "$TMP/biscuit-apk-offline/edge/aarch64/"
cp "$KEY" "$TMP/biscuit-apk-offline/"

cat > "$TMP/biscuit-apk-offline/INSTALL.txt" <<'TXT'
Offline install for the Amazon Echo Dot 2 postmarketOS port.

Copy this whole directory onto the device - USB, scp, a memory card, whatever
reaches it - then, as root:

    cp biscuit-apk.rsa.pub /etc/apk/keys/
    apk add --repository "$PWD/edge" device-amazon-biscuit

and, if wanted:

    apk add --repository "$PWD/edge" device-amazon-biscuit-voice
    apk add --repository "$PWD/edge" device-amazon-biscuit-sendspin

The path given to --repository stops at edge; apk appends /aarch64/APKINDEX.tar.gz
itself. Install the key first: the index is signed, and without the key apk
rejects it as UNTRUSTED rather than falling back to installing it anyway.

The applications depend on device-amazon-biscuit at the SAME pkgrel, so install
them from this same bundle rather than mixing it with an older one.

These packages contain no Amazon assets. The ring runs on generated effects,
and no earcons ship: with the voice assistant installed the device uses that
project's own sounds, otherwise it stays silent until you extract stock sounds
from your own hardware into /opt/persist/earcon.
TXT

( cd "$TMP" && tar czf - biscuit-apk-offline ) > "$OUT"
echo "wrote $OUT ($(stat -c%s "$OUT") bytes)"
echo "  packages: $(ls "$SRC"/*.apk | wc -l), index signed by $(tar tzf "$SRC/APKINDEX.tar.gz" | sed -n 's/^\.SIGN\.RSA\.//p')"
