#!/usr/bin/env bash
set -euo pipefail
workflow=.github/workflows/deploy-backend.yml
grep -Fq 'strip_components: 1' "$workflow"
grep -Fq 'bash preflight-swarm.sh music_storage' "$workflow"
grep -Fq 'bash rollback-swarm-service.sh' "$workflow"
grep -Fq 'GHCR_TOKEN' "$workflow"
grep -Fq 'previous_spec_file' "$workflow"
grep -Fq 'bash deploy/test-rollback-swarm-service.sh' "$workflow"
frontend=.github/workflows/deploy-frontend.yml
grep -Fq 'source: "music-player-frontend/build/web.tar.gz"' "$frontend"
grep -Fq 'target: "/tmp/"' "$frontend"
grep -Fq '/home/deployer/music-player/deploy/activate-frontend-release.sh' "$frontend"
grep -Fq 'bash deploy/test-frontend-release.sh' "$frontend"
if grep -Fq 'target: /home/deployer/music-player/deploy/' "$frontend"; then exit 1; fi
printf 'pipeline path contract PASS\n'
