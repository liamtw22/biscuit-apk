#!/bin/sh
# Publish a built, signed apk feed to the gh-pages branch.
#
# The feed branch is rewritten as a single orphan commit each time, so package
# binaries never accumulate in the repository's history and a clone always
# costs one copy of the current packages.
#
# Usage: tools/publish-feed.sh <dir containing APKINDEX.tar.gz and *.apk>
set -eu

SRC=${1:-}
ARCH=${ARCH:-aarch64}
BRANCH=${BRANCH:-gh-pages}

die() { echo "publish-feed: $*" >&2; exit 1; }

[ -n "$SRC" ] || die "usage: $0 <feed dir>"
[ -f "$SRC/APKINDEX.tar.gz" ] || die "no APKINDEX.tar.gz in $SRC"
ls "$SRC"/*.apk >/dev/null 2>&1 || die "no .apk files in $SRC"

# The index must be signed, or apk will reject the feed unless every install
# passes --allow-untrusted.
tar tzf "$SRC/APKINDEX.tar.gz" | grep -q '^\.SIGN\.RSA\.' \
  || die "APKINDEX.tar.gz is not signed (run abuild-sign on it first)"

REPO=$(git rev-parse --show-toplevel)
ORIGIN=$(git -C "$REPO" remote get-url origin)
KEY="$REPO/biscuit-apk.rsa.pub"
[ -f "$KEY" ] || die "missing $KEY"

# The key that signed the index must be the key we publish, or the device will
# fetch a key it cannot verify anything with.
SIGNER=$(tar tzf "$SRC/APKINDEX.tar.gz" | sed -n 's/^\.SIGN\.RSA\.//p' | head -1)
[ "$SIGNER" = "$(basename "$KEY")" ] \
  || die "index was signed by '$SIGNER' but this repo publishes '$(basename "$KEY")'"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/edge/$ARCH"
cp "$SRC"/*.apk "$SRC/APKINDEX.tar.gz" "$TMP/edge/$ARCH/"
cp "$KEY" "$TMP/"
cp "$REPO/.gitattributes" "$TMP/"
: > "$TMP/.nojekyll"

cat > "$TMP/index.html" <<'HTML'
<!doctype html>
<meta charset="utf-8">
<title>biscuit-apk</title>
<meta name="viewport" content="width=device-width,initial-scale=1">
<style>
  :root { color-scheme: light dark; --fg:#1c1c1e; --bg:#fbfbfd; --mut:#6b6b70; --line:#dcdce1; }
  @media (prefers-color-scheme: dark) {
    :root { --fg:#e9e9ec; --bg:#141416; --mut:#9a9aa1; --line:#2c2c31; }
  }
  body { margin:0 auto; padding:2.5rem 1rem; max-width:44rem; background:var(--bg); color:var(--fg);
         font:16px/1.6 ui-sans-serif,-apple-system,Segoe UI,Roboto,sans-serif; }
  h1 { font-size:1.6rem; margin:0 0 .25rem; }
  p.sub { color:var(--mut); margin:0 0 2rem; }
  pre { background:color-mix(in srgb, var(--fg) 6%, transparent); border:1px solid var(--line);
        border-radius:8px; padding:.85rem 1rem; overflow-x:auto; font-size:.9rem; }
  code { font-family:ui-monospace,SFMono-Regular,Menlo,Consolas,monospace; }
  h2 { font-size:1.05rem; margin:2rem 0 .5rem; }
  a { color:inherit; }
</style>
<h1>biscuit-apk</h1>
<p class="sub">Signed apk feed for the postmarketOS port of the Amazon Echo Dot 2 (2016, <code>biscuit</code>).</p>
<h2>Add the feed</h2>
<pre><code>wget -O /etc/apk/keys/biscuit-apk.rsa.pub \
  https://liamtw22.github.io/biscuit-apk/biscuit-apk.rsa.pub
echo 'https://liamtw22.github.io/biscuit-apk/edge' &gt;&gt; /etc/apk/repositories
apk update</code></pre>
<h2>Install</h2>
<pre><code>apk add device-amazon-biscuit-sendspin</code></pre>
<h2>Contents</h2>
<pre><code><a href="edge/aarch64/">edge/aarch64/</a></code></pre>
<p class="sub">Source: <a href="https://github.com/liamtw22/biscuit-apk">github.com/liamtw22/biscuit-apk</a></p>
HTML

STAMP=$(date -u '+%Y-%m-%d %H:%M UTC')
COUNT=$(ls -1 "$SRC"/*.apk | wc -l | tr -d ' ')

cd "$TMP"
git init -q -b "$BRANCH"
git add -A
git -c user.name="$(git -C "$REPO" config user.name)" \
    -c user.email="$(git -C "$REPO" config user.email)" \
    commit -q -m "feed: $COUNT package(s), $STAMP"

echo "about to force-push this to $BRANCH of $ORIGIN:"
git -c core.pager=cat show --stat --oneline HEAD | sed 's/^/  /'
printf 'continue? [y/N] '
read -r reply
case "$reply" in
  y|Y|yes|YES) ;;
  *) die "aborted" ;;
esac

git push --force "$ORIGIN" "$BRANCH"
echo "published. Pages must be set to deploy from branch '$BRANCH' / root."
