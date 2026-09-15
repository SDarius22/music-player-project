#!/usr/bin/env bash
set -euo pipefail
service=${1:?service required}; known_good_image=${2:?known-good image required}; known_good_spec_file=${3:?known-good spec required}; replicas=${4:?replica count required}; endpoint=${5:?endpoint required}
known_good_spec=$(cat "$known_good_spec_file")
deadline=$((SECONDS + ${ROLLBACK_TIMEOUT_SECONDS:-210}))
state=$(docker service inspect "$service" --format '{{if .UpdateStatus}}{{.UpdateStatus.State}}{{end}}')
automatic=false
if [[ "$state" == rollback_started || "$state" == rollback_completed ]]; then automatic=true; else
  case "$state" in rollback_failed|rollback_paused) echo "rollback already failed: $state" >&2; exit 1;; esac
  previous_spec=$(docker service inspect "$service" --format '{{json .PreviousSpec}}')
  previous_image=$(docker service inspect "$service" --format '{{.PreviousSpec.TaskTemplate.ContainerSpec.Image}}')
  [ "$previous_image" = "$known_good_image" ] || { echo 'PreviousSpec does not match known-good image' >&2; exit 1; }
  [ "$previous_spec" = "$known_good_spec" ] || { echo 'PreviousSpec does not match known-good spec' >&2; exit 1; }
  timeout 30s docker service update --rollback --detach=true "$service"
fi
while [ "$SECONDS" -lt "$deadline" ]; do
  current_spec=$(docker service inspect "$service" --format '{{json .Spec}}')
  state=$(docker service inspect "$service" --format '{{if .UpdateStatus}}{{.UpdateStatus.State}}{{end}}')
  case "$state" in
    rollback_failed|rollback_paused) echo "rollback reached terminal failure state: $state" >&2; exit 1;;
    rollback_completed)
      [ "$current_spec" = "$known_good_spec" ] || { printf 'rollback completed with the wrong service spec: current=%q known=%q\n' "$current_spec" "$known_good_spec" >&2; exit 1; }
      timeout 210s bash deploy/verify-swarm-rollout.sh "$service" "$known_good_image" "$replicas" "$endpoint"; exit $?;;
    rollback_started|updating|paused|completed|'') sleep 1;;
    *) [ "$automatic" = false ] || { echo "rollback did not settle: $state" >&2; exit 1; }; sleep 1;;
  esac
done
echo "rollback timed out after ${ROLLBACK_TIMEOUT_SECONDS:-210}s" >&2
exit 1
