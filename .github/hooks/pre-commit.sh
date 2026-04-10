#!/bin/sh
set -eu

PUBSPEC="music-player-frontend/pubspec.yaml"

if ! git diff --cached --name-only | grep -q '^music-player-frontend/lib/'; then
  echo "No staged changes in music-player-frontend/lib; skipping version bump."
  exit 0
fi

if [ ! -f "$PUBSPEC" ]; then
  exit 0
fi

current="$(awk '/^version:/{print $2; exit}' "$PUBSPEC" || true)"
if [ -z "${current:-}" ]; then
  echo "Could not find version in $PUBSPEC"
  exit 1
fi

base="${current%%+*}"
build="${current##*+}"

if [ "$base" = "$build" ]; then
  build=0
fi

case "$build" in
  ''|*[!0-9]*)
    echo "Invalid build number in version: $current"
    exit 1
    ;;
esac

next_build=$((build + 1))
next_version="${base}+${next_build}"

perl -i -pe "s/^version:\\s*.*/version: ${next_version}/" "$PUBSPEC"

git add "$PUBSPEC"
echo "Bumped version: $current -> $next_version"
