#!/usr/bin/env bash
set -euo pipefail

root=${1:?frontend root required}
release=${2:?release path required}
previous=${3:?previous current target required}
endpoint=${4:?endpoint required}

for file in index.html main.dart.js flutter_bootstrap.js .well-known/assetlinks.json release-id; do
  test -f "$root/releases/$release/$file"
done
current=$(readlink -f "$root/current")
test -f "$current/index.html" && test -f "$current/release-id"
test "$current" = "$previous"
test "$(cat "$root/releases/$release/release-id")" = "$release"
temporary="$root/.current.$$"
ln -s "$root/releases/$release" "$temporary"
rollback() {
  rm -f "$temporary"
  local link="$root/.rollback.$$"
  ln -s "$previous" "$link" && mv -T "$link" "$root/current"
}
if ! mv -T "$temporary" "$root/current"; then rollback; exit 1; fi
if [ "$(curl --fail --silent --show-error --connect-timeout 2 --max-time 10 "$endpoint/release-id")" != "$release" ]; then
  rollback
  exit 1
fi
