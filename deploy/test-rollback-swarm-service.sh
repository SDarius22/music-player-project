#!/usr/bin/env bash
set -euo pipefail
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
printf 'GOOD\n' > "$tmp/spec"
cat > "$tmp/docker" <<'DOCKER'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$MOCK_LOG"
case "$*" in
  *'json .Spec}}'*) n=$(cat "$MOCK_COUNT"); n=$((n + 1)); printf '%s\n' "$n" > "$MOCK_COUNT"; if { [ "$MOCK_MODE" = auto ] && [ "$n" -ge 2 ]; } || { [ "$MOCK_MODE" = explicit ] && [ "$n" -ge 2 ]; }; then printf GOOD; else printf BAD; fi;;
  *'json .PreviousSpec'*) [ "$MOCK_MODE" = missing ] && exit 1; [ "$MOCK_MODE" = wrong ] && printf WRONG || printf GOOD;;
  *'PreviousSpec.TaskTemplate.ContainerSpec.Image'*) printf GOODIMG;;
  *UpdateStatus*) n=$(cat "$MOCK_STATE_COUNT"); n=$((n + 1)); printf '%s\n' "$n" > "$MOCK_STATE_COUNT"; case "$MOCK_MODE:$n" in auto:1|auto:2|explicit:2|explicit:3) printf rollback_started;; auto:*) printf rollback_completed;; explicit:1) printf updating;; explicit:*) printf rollback_completed;; timeout:*) printf updating;; failure:1) printf updating;; failure:*) printf rollback_failed;; recovery:1) printf updating;; recovery:*) printf rollback_completed;; wrong:1|missing:1) printf updating;; esac;;
esac
DOCKER
cat > "$tmp/timeout" <<'TIMEOUT'
#!/usr/bin/env bash
shift
if [[ "$*" == *'bash deploy/verify-swarm-rollout.sh'* ]]; then exit 0; fi
exec "$@"
TIMEOUT
chmod +x "$tmp/docker" "$tmp/timeout"
export PATH="$tmp:$PATH" MOCK_LOG="$tmp/log" MOCK_COUNT="$tmp/count" MOCK_STATE_COUNT="$tmp/state-count"
run_case() { : > "$MOCK_LOG"; printf 0 > "$MOCK_COUNT"; printf 0 > "$MOCK_STATE_COUNT"; MOCK_MODE=$1 ROLLBACK_TIMEOUT_SECONDS=${2:-5} bash deploy/rollback-swarm-service.sh svc GOODIMG "$tmp/spec" 1 http://fixture; }
run_case auto
if grep -q 'service update --rollback' "$MOCK_LOG"; then exit 1; fi
run_case explicit
grep -q 'service update --rollback' "$MOCK_LOG"
if run_case timeout 1; then exit 1; fi
if run_case failure; then exit 1; fi
if run_case recovery; then exit 1; fi
if run_case wrong; then exit 1; fi
if run_case missing; then exit 1; fi
printf 'stateful rollback helper PASS\n'
