#!/usr/bin/env bash
set -euo pipefail

service_name=${1:?service name required}
expected_image=${2:?image required}
expected_replicas=${3:?replica count required}
endpoint=${4:?endpoint required}
deadline=$((SECONDS + 180))
stable=0

node_count=$(docker node ls --format '{{.ID}}' | wc -l)
if [ "$node_count" -gt 1 ]; then
  printf 'multi-node Swarm detected; remote task health verification is not configured\n' >&2
  exit 2
fi

while [ "$SECONDS" -lt "$deadline" ]; do
  healthy=0
  running=0
  wrong_image=0
  update_state=$(docker service inspect --format '{{if .UpdateStatus}}{{.UpdateStatus.State}}{{end}}' "$service_name" 2>/dev/null || true)
  case "$update_state" in paused|rollback_paused|rollback_failed) printf 'service update state is %s\n' "$update_state" >&2; exit 1 ;; esac
  for task in $(docker service ps "$service_name" --filter desired-state=running --format '{{.ID}}'); do
    image=$(docker inspect --format '{{.Spec.ContainerSpec.Image}}' "$task" 2>/dev/null || true)
    if [ "$image" != "$expected_image" ]; then wrong_image=$((wrong_image + 1)); continue; fi
    state=$(docker inspect --format '{{.Status.State}}' "$task" 2>/dev/null || true)
    [ "$state" = running ] || continue
    container=$(docker inspect --format '{{.Status.ContainerStatus.ContainerID}}' "$task" 2>/dev/null || true)
    [ -n "$container" ] || continue
    running=$((running + 1))
    health=$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}missing{{end}}' "$container" 2>/dev/null || true)
    [ "$health" = healthy ] && healthy=$((healthy + 1))
  done

  if [ "$running" -eq "$expected_replicas" ] && [ "$wrong_image" -eq 0 ] \
      && [ "$healthy" -eq "$expected_replicas" ] \
      && curl --fail --silent --show-error --connect-timeout 2 --max-time 5 "$endpoint" >/dev/null; then
    stable=$((stable + 1))
    [ "$stable" -ge 3 ] && exit 0
  else
    stable=0
  fi
  sleep 2
done

docker service ps "$service_name" --no-trunc >&2 || true
exit 1
