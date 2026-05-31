#!/usr/bin/env bash
set -euo pipefail

EXP=""
REPS=1
PRICE="0.09"
CHUNK_KIB="64"
DB_URL="postgresql://admin:admin@localhost:5432/music_player_db"
BACKEND="http://localhost:9000"
RESULTS_ROOT="evaluation/results"
CLIENTS=()

SMOKE=false
SMOKE_TOKEN=""
SMOKE_SONG=""
DEVICE="macos"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUMMARY_SQL="$SCRIPT_DIR/chunk_stats_summary.sql"
PARSER="$SCRIPT_DIR/parse_metrics.py"

usage() {
  cat <<EOF
Usage:
  evaluation/run_experiment.sh --exp <name> [--reps 10] [--client "<cmd>"]
  evaluation/run_experiment.sh --smoke --token <jwt> --song <hash>

Common options:
  --db <url>          Postgres URL. Default: $DB_URL
  --backend <url>     Backend health URL base. Default: $BACKEND
  --results <dir>     Result root. Default: $RESULTS_ROOT
  --price <usd/GB>    Egress price. Default: $PRICE
  --chunk-kib <kib>   Chunk size. Default: $CHUNK_KIB
EOF
}

need_value() {
  [[ $# -ge 2 && -n "${2:-}" ]] || { echo "missing value for $1" >&2; exit 2; }
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --exp) need_value "$@"; EXP="$2"; shift 2 ;;
    --reps) need_value "$@"; REPS="$2"; shift 2 ;;
    --price) need_value "$@"; PRICE="$2"; shift 2 ;;
    --chunk-kib) need_value "$@"; CHUNK_KIB="$2"; shift 2 ;;
    --db) need_value "$@"; DB_URL="$2"; shift 2 ;;
    --backend) need_value "$@"; BACKEND="$2"; shift 2 ;;
    --results) need_value "$@"; RESULTS_ROOT="$2"; shift 2 ;;
    --client) need_value "$@"; CLIENTS+=("$2"); shift 2 ;;
    --smoke) SMOKE=true; shift ;;
    --token) need_value "$@"; SMOKE_TOKEN="$2"; shift 2 ;;
    --song) need_value "$@"; SMOKE_SONG="$2"; shift 2 ;;
    --device) need_value "$@"; DEVICE="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if $SMOKE; then
  [[ -n "$EXP" ]] || EXP="smoke"
  if [[ ${#CLIENTS[@]} -eq 0 ]]; then
    [[ -n "$SMOKE_TOKEN" && -n "$SMOKE_SONG" ]] || {
      echo "--smoke needs --client or both --token and --song" >&2
      exit 2
    }
    CLIENTS=("flutter run -d $DEVICE -t lib/main_eval.dart \
--dart-define=ROLE=listener --dart-define=AUTH_TOKEN=$SMOKE_TOKEN --dart-define=SONG_HASHES=$SMOKE_SONG")
  fi
fi

[[ -n "$EXP" ]] || { echo "--exp is required" >&2; usage >&2; exit 2; }
AUTO_MODE=false
[[ ${#CLIENTS[@]} -gt 0 ]] && AUTO_MODE=true

log() { printf '\033[1;34m[run]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[warn]\033[0m %s\n' "$*" >&2; }
die() { printf '\033[1;31m[fail]\033[0m %s\n' "$*" >&2; exit 1; }
now_pg() { date -u +"%Y-%m-%d %H:%M:%S+00"; }

preflight() {
  command -v psql >/dev/null || die "psql not found on PATH"
  command -v python3 >/dev/null || die "python3 not found on PATH"
  [[ -f "$SUMMARY_SQL" ]] || die "missing $SUMMARY_SQL"
  [[ -f "$PARSER" ]] || die "missing $PARSER"

  psql "$DB_URL" -tAc 'SELECT 1' >/dev/null 2>&1 \
    || die "cannot reach Postgres at $DB_URL"

  if command -v curl >/dev/null; then
    curl -fsS --max-time 5 "$BACKEND/actuator/health" >/dev/null 2>&1 \
      || warn "backend health check failed at $BACKEND; continuing"
  fi

  log "preflight OK"
}

reset_stats() {
  psql "$DB_URL" -q -c 'TRUNCATE music_library.chunk_stats;' \
    || die "failed to truncate chunk_stats"
  log "chunk_stats truncated"
}

drive_clients() {
  local rundir="$1"

  if $AUTO_MODE; then
    local pids=()
    local i=0
    for cmd in "${CLIENTS[@]}"; do
      i=$((i + 1))
      log "client $i: $cmd"
      (
        cd "$SCRIPT_DIR/../music-player-frontend"
        eval "$cmd"
      ) >"$rundir/client_$i.log" 2>&1 &
      pids+=("$!")
    done

    local failed=0
    for pid in "${pids[@]}"; do
      wait "$pid" || failed=1
    done
    [[ $failed -eq 0 ]] || warn "one or more clients exited non-zero"
    return
  fi

  cat <<EOF

Manual step for '$EXP'
  1. Run the clients described in evaluation/README.md.
  2. Tee each client log into $rundir/<client>.log.
  3. Let every listener finish the track.

Press ENTER here when the repetition is complete.
EOF
  read -r _
}

append_results_row() {
  local rep="$1"
  local since="$2"
  local out="$RESULTS_ROOT/$EXP/results.csv"
  local row

  row=$(psql "$DB_URL" -tAF',' \
    -v since="$since" -v price="$PRICE" -v chunk_kib="$CHUNK_KIB" <<'SQL'
WITH final_rows AS (
  SELECT DISTINCT ON (user_id, song_file_hash)
         user_id, song_file_hash, local_cached_chunks, p2p_chunks,
         server_chunks, total_chunks
  FROM   music_library.chunk_stats
  WHERE  timestamp >= :'since'::timestamptz
  ORDER  BY user_id, song_file_hash, total_chunks DESC, timestamp DESC
)
SELECT sum(total_chunks),
       sum(server_chunks),
       sum(p2p_chunks),
       sum(local_cached_chunks),
       count(*),
       round(100.0 * sum(server_chunks) / NULLIF(sum(total_chunks), 0), 2),
       round(100.0 * sum(p2p_chunks) / NULLIF(sum(total_chunks), 0), 2),
       round(100.0 * sum(local_cached_chunks) / NULLIF(sum(total_chunks), 0), 2),
       round(100.0 * (sum(total_chunks) - sum(server_chunks)) / NULLIF(sum(total_chunks), 0), 2),
       round((((sum(total_chunks) - sum(server_chunks)) * :chunk_kib * 1024.0 / 1e9) * :price)::numeric, 4)
FROM final_rows;
SQL
)

  if [[ ! -f "$out" ]]; then
    echo "rep,total_chunks,server_chunks,p2p_chunks,cache_chunks,sessions,server_share_pct,p2p_offload_pct,cache_share_pct,egress_saving_pct,projected_saving_usd" >"$out"
  fi
  echo "$rep,$row" >>"$out"
  log "appended rep $rep to $out"
}

analyze() {
  local rundir="$1"
  local since="$2"
  local rep="$3"

  log "summarising chunk stats since $since"
  psql "$DB_URL" -v since="$since" -v price="$PRICE" -v chunk_kib="$CHUNK_KIB" \
    -f "$SUMMARY_SQL" | tee "$rundir/summary.txt"

  if compgen -G "$rundir/*.log" >/dev/null; then
    python3 "$PARSER" "$rundir"/*.log --label-from-filename \
      -o "$rundir/metrics.csv" || warn "no metric lines found"
  else
    warn "no log files in $rundir; metrics skipped"
  fi

  append_results_row "$rep" "$since"
}

stats_row_count() {
  local since="$1"
  psql "$DB_URL" -tAc \
    "SELECT count(*) FROM music_library.chunk_stats
     WHERE timestamp >= '$since'::timestamptz AND total_chunks > 0;" 2>/dev/null \
    | tr -d '[:space:]'
}

metric_count() {
  local rundir="$1"
  local name="$2"
  if compgen -G "$rundir/*.log" >/dev/null; then
    grep -ho "\\[METRIC\\] $name=[0-9.]*" "$rundir"/*.log 2>/dev/null | wc -l | tr -d ' '
  else
    echo 0
  fi
}

run_smoke() {
  local rundir="$RESULTS_ROOT/smoke/$(date -u +%Y%m%dT%H%M%SZ)"
  mkdir -p "$rundir"

  log "smoke test -> $rundir"
  reset_stats

  local since
  since="$(now_pg)"
  echo "$since" >"$rundir/since.txt"

  drive_clients "$rundir"

  local rows
  rows="$(stats_row_count "$since")"
  rows="${rows:-0}"
  log "chunk_stats rows since run start: $rows"
  log "ttfa_ms lines: $(metric_count "$rundir" ttfa_ms)"
  log "ice_setup_ms lines: $(metric_count "$rundir" ice_setup_ms)"

  if [[ "$rows" -gt 0 ]]; then
    psql "$DB_URL" -v since="$since" -v price="$PRICE" -v chunk_kib="$CHUNK_KIB" \
      -f "$SUMMARY_SQL" | tee "$rundir/summary.txt" || true
    printf '\033[1;32m[PASS]\033[0m smoke OK - %s chunk_stats row(s) landed.\n' "$rows"
    return 0
  fi

  cat >&2 <<EOF
[FAIL] no chunk_stats rows landed.
Check the backend URL, DB URL, AUTH_TOKEN, SONG_HASHES, and the client log in:
  $rundir
EOF
  return 1
}

preflight

if $SMOKE; then
  run_smoke
  exit $?
fi

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
log "experiment=$EXP reps=$REPS mode=$($AUTO_MODE && echo auto || echo manual)"

for rep in $(seq 1 "$REPS"); do
  rundir="$RESULTS_ROOT/$EXP/$STAMP/rep-$(printf '%02d' "$rep")"
  mkdir -p "$rundir"
  log "rep $rep/$REPS -> $rundir"

  reset_stats
  since="$(now_pg)"
  echo "$since" >"$rundir/since.txt"

  drive_clients "$rundir"
  analyze "$rundir" "$since" "$rep"
done

log "done; per-rep folders are under $RESULTS_ROOT/$EXP/$STAMP"
log "aggregate CSV: $RESULTS_ROOT/$EXP/results.csv"
