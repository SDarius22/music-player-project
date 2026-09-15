#!/usr/bin/env bash
set -euo pipefail
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/site/releases/old/.well-known" "$tmp/site/releases/new/.well-known"
for release in old new; do
  printf '%s\n' "$release" > "$tmp/site/releases/$release/release-id"
  touch "$tmp/site/releases/$release/index.html" "$tmp/site/releases/$release/main.dart.js" "$tmp/site/releases/$release/flutter_bootstrap.js" "$tmp/site/releases/$release/.well-known/assetlinks.json"
done
ln -s "$tmp/site/releases/old" "$tmp/site/current"
cat > "$tmp/bin/curl" <<'CURL'
#!/usr/bin/env bash
[ "${FAIL:-0}" = 1 ] && exit 1
printf 'new'
exit 0
CURL
chmod +x "$tmp/bin/curl"
PATH="$tmp/bin:$PATH" bash deploy/activate-frontend-release.sh "$tmp/site" new "$tmp/site/releases/old" http://fixture
test "$(readlink -f "$tmp/site/current")" = "$tmp/site/releases/new"
if FAIL=1 PATH="$tmp/bin:$PATH" bash deploy/activate-frontend-release.sh "$tmp/site" old "$tmp/site/releases/new" http://fixture; then
  exit 1
fi
test "$(readlink -f "$tmp/site/current")" = "$tmp/site/releases/new"
