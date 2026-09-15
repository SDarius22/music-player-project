#!/usr/bin/env bash
set -euo pipefail

label=${1:?required storage label}
[ "$(docker info --format '{{.Swarm.LocalNodeState}}')" = active ]
[ "$(docker info --format '{{.Swarm.ControlAvailable}}')" = true ]
docker node inspect self --format '{{index .Spec.Labels "'"$label"'"}}' | grep -qx true
