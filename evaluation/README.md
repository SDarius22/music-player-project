# Evaluation

This folder holds the Chapter 4 evaluation notes, runner scripts, SQL summaries, and raw
result files for the hybrid streaming prototype.

The short version:

- The backend is the bootstrap/origin path.
- The clients fetch the server prefix first, then try WebRTC peers, then fall back to the
  server when peer delivery misses the deadline.
- The evaluation measures whether that actually lowers origin egress without making
  startup or playback fragile.

## Files

| File | Purpose |
| --- | --- |
| `chunk_stats_summary.sql` | Summarises `music_library.chunk_stats` into per-listener and swarm rows. |
| `parse_metrics.py` | Extracts `[METRIC] *_ms=...` lines from Flutter logs and prints median/p75/p95. |
| `run_experiment.sh` | Repeats an experiment, resets stats, runs clients, and writes summaries. |
| `get_token.sh` | Gets an auth token for the headless runner. |
| `results/` | Raw logs and CSVs from the measured runs. |

Only `README.md` is kept as documentation in this folder. Older plan/runbook/results
Markdown was folded into this file so the procedure does not drift.

## What Gets Measured

Delivery stats come from the real frontend pipeline:

`chunk_service.dart -> POST /api/v1/statistics -> music_library.chunk_stats`

The frontend emits cumulative rows every few seconds and again on completion. Because the
rows are cumulative, the SQL keeps only the latest row per `(user_id, song_file_hash)` for a
run window before summing the swarm.

The headline fields are:

| Field | Meaning |
| --- | --- |
| `server_share_pct` | Origin/server chunks divided by total chunks. |
| `p2p_offload_pct` | Chunks received from peers. |
| `cache_share_pct` | Chunks served from the local client cache. |
| `egress_saving_pct` | Anything not served by the origin: `1 - server_share`. |
| `projected_saving_usd` | Saved egress bytes multiplied by the configured `$/GB`. |

Startup/network timings come from client log lines:

```text
[METRIC] ttfa_ms=312.4 song=...
[METRIC] ice_setup_ms=287.5 peer=...
```

`ttfa_ms` is the GUI click-to-sound metric. The headless runner exercises the chunk path,
so it can report ICE setup but not real audible startup.

## Setup

Start the backend dependencies and backend from the repo root:

```bash
docker run --name music-pg -e POSTGRES_USER=admin -e POSTGRES_PASSWORD=admin \
  -e POSTGRES_DB=music_player_db -p 5432:5432 -d postgres:18
docker run --name music-redis -p 6379:6379 -d redis:alpine

cd music-player-backend
./mvnw spring-boot:run
```

Use a fixed test catalogue. For the current measured run the catalogue was one synthetic
240 s, 320 kbps MP3 track with 147 chunks of 64 KiB. For final thesis numbers, use the
short/normal/long set:

| Track | Length | Use |
| --- | --- | --- |
| short | about 60 s | Startup-heavy case. |
| normal | 3-4 min | Main headline run. |
| long | 8-10 min | Sustained peer delivery and prefetch. |

Keep bitrate and format the same inside one numeric comparison.

Get a token for the headless runner:

```bash
eval "$(evaluation/get_token.sh you@example.com | grep -E '^(AUTH|REFRESH)_TOKEN=')"
export AUTH_TOKEN REFRESH_TOKEN
```

Find test song hashes:

```bash
psql "postgresql://admin:admin@localhost:5432/music_player_db" \
  -c "SELECT file_hash, name FROM music_library.songs ORDER BY name;"
```

Build the headless runner once if you are launching a swarm:

```bash
cd music-player-frontend
flutter build macos -t lib/main_eval.dart
BIN="$(pwd)/build/macos/Build/Products/Release/"*.app/Contents/MacOS/*
```

## Manual Runs

Before each repetition:

```sql
TRUNCATE music_library.chunk_stats;
```

Then capture one log per client:

```bash
flutter run -d macos 2>&1 | tee evaluation/results/C-warm-swarm/seeder.log
flutter run -d chrome -t lib/main_web.dart 2>&1 | tee evaluation/results/C-warm-swarm/web2.log
```

Play the track to completion on every listener. Completion matters because that is when the
final cumulative `chunk_stats` row is emitted.

Summarise delivery shares and cost:

```bash
psql "postgresql://admin:admin@localhost:5432/music_player_db" \
  -v since="2026-05-29 19:00:00+00" \
  -v price=0.09 \
  -v chunk_kib=64 \
  -f evaluation/chunk_stats_summary.sql
```

Parse timing metrics:

```bash
python3 evaluation/parse_metrics.py evaluation/results/C-warm-swarm/*.log \
  --label-from-filename -o evaluation/results/C-warm-swarm/metrics.csv
```

## Headless Runs

`lib/main_eval.dart` is a UI-less Flutter entrypoint that wires the real auth, streaming,
stats, WebRTC, and `ChunkService` path. It simulates playback by requesting chunks in order.

Useful environment/config keys:

| Key | Notes |
| --- | --- |
| `AUTH_TOKEN` | Required unless passed by `--dart-define`. |
| `REFRESH_TOKEN` | Optional refresh token. |
| `SONG_HASHES` | Required comma-separated song hashes. |
| `ROLE` | `seeder` or `listener`. |
| `SPEED` | `max` or a playback multiplier. |
| `START_DELAY_MS` | Delay before playback starts. |
| `SEED_HOLD_SECONDS` | How long a seeder stays up after warming. |
| `API_BASE_URL` / `WS_BASE_URL` | Backend URLs. |
| `BITRATE_BPS` | Used to pace simulated playback. |

Smoke-test the full chain:

```bash
evaluation/run_experiment.sh --smoke --token "$AUTH_TOKEN" --song "$HASH"
```

One server-only listener:

```bash
evaluation/run_experiment.sh --exp A-server-only --reps 10 \
  --client "ROLE=listener SONG_HASHES=$HASH AUTH_TOKEN=$AUTH_TOKEN $BIN"
```

Warm swarm:

```bash
evaluation/run_experiment.sh --exp C-warm-swarm --reps 10 \
  --client "ROLE=seeder SEED_HOLD_SECONDS=300 SONG_HASHES=$HASH AUTH_TOKEN=$AUTH_TOKEN $BIN" \
  --client "ROLE=listener START_DELAY_MS=20000 SONG_HASHES=$HASH AUTH_TOKEN=$AUTH_TOKEN $BIN" \
  --client "ROLE=listener START_DELAY_MS=20000 SONG_HASHES=$HASH AUTH_TOKEN=$AUTH_TOKEN $BIN"
```

For the scaling run, repeat the warm-swarm command for `N = 1, 2, 3, 5` listeners and plot
`server_chunks` against listener count. The comparison lines are:

- Pure server: `N * total_chunks`.
- Ideal peer-assisted: `N * prefix_chunks`.
- Measured prototype: summed `server_chunks`.

## Experiment Set

| ID | Scenario | Status | What it proves |
| --- | --- | --- | --- |
| A | Server-only baseline | runnable | Pure origin cost and baseline startup. |
| B | Cold peer-assisted | runnable | No useful peers still falls back cleanly. |
| C | Warm-cache peer-assisted | runnable, main result | Server/P2P/cache split and egress saving. |
| D | Egress scaling with swarm size | runnable, main figure | Server load grows far slower than pure server. |
| E | Prefix size trade-off | needs `PREFIX_FRACTION` | Measures 0/1 chunk/5%/10% startup vs cost. |
| F | Next-track prefix prefetch | partial | Wrong-skip waste is runnable; on/off control needs a flag. |
| G | WebRTC setup and peer transfer | partial | ICE timing exists; cross-network runs still needed. |
| H | Churn and fallback | partial | Shares are runnable; exact stall timing needs a counter. |
| I | Corrupt peer chunk recovery | log-level runnable | Hash rejection and server recovery. |
| J | Storage deduplication | SQL runnable | Physical chunk reuse for duplicate uploads. |
| K | Mobile resource cost | device-dependent | Battery/CPU/upload impact. |

The minimum defensible Chapter 4 is A, C, D, a GUI `ttfa_ms` comparison, one churn run, one
wrong-prefetch run, and the dedup SQL.

## Current Measured Run

First live run: 2026-05-29, local macOS machine, Spring Boot 4 / Java 25, PostgreSQL 18,
Redis, mocked email code, headless macOS eval runner. Each client used a distinct user.

Test track:

- 240 s, 320 kbps MP3.
- 147 chunks, 64 KiB each, about 9.6 MB.
- Server prefix: `max(1, round(147 * 0.05)) = 7` chunks.
- Theoretical offload ceiling: `1 - 7/147 = 95.24%`.

Headline rows:

| Experiment | Server | P2P | Cache | Total | Server share | P2P offload | Egress saving | ICE setup |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| A, one listener, no peers | 147 | 0 | 0 | 147 | 100.00% | 0.00% | 0.00% | n/a |
| C, one seeder + one listener | 17 | 130 | 0 | 147 | 11.56% | 88.44% | 88.44% | 243 ms median |

The 17 server chunks in C are the 7 prefix chunks plus 10 early fallback chunks while the
peer channel is coming up. Measured offload was 88.44%, 6.8 percentage points below the
theoretical 95.24% ceiling.

Scaling after the signaling write fix:

| Listeners | Server | P2P | Total | Server share |
| ---: | ---: | ---: | ---: | ---: |
| 2 | 34 | 260 | 294 | 11.56% |
| 3 | 51 | 390 | 441 | 11.56% |
| 5 | 85 | 650 | 735 | 11.56% |
| 5 staggered | 85 | 650 | 735 | 11.56% |

Before the fix, simultaneous listeners were a connection lottery because several threads
wrote to one Tomcat `WebSocketSession` at the same time and dropped signaling messages. The
backend fix was to wrap sessions in `ConcurrentWebSocketSessionDecorator`. After that,
`TEXT_PARTIAL_WRITING` errors dropped to zero and every listener offloaded normally.

Keep these caveats in the thesis text:

- Localhost/single-machine measurements do not model NAT, WAN RTT, or mobile networks.
- The synthetic 9.6 MB track is useful for shares and slopes, not meaningful dollar totals.
- `ttfa_ms` still needs GUI capture; the headless runner bypasses audible playback.
- Do not claim to beat Spotify. Spotify's 8.8% server share is a production reference point,
  not a pass/fail target for this prototype.

## Dedup Query

For duplicate-upload storage checks:

```sql
SELECT count(*) AS logical_chunks,
       count(DISTINCT chunk_id) AS physical_chunks
FROM   music_library.song_chunks sc
JOIN   music_library.songs s ON s.id = sc.song_id
WHERE  s.file_hash IN ('<hashA>', '<hashB>');
```

Report `1 - physical_chunks / logical_chunks`. Expect strong deduplication for exact
duplicates and little deduplication for unrelated compressed audio.

## Notes

- Desktop clients share the ObjectBox store under `MusicPlayer_Debug`; do not run two GUI
  desktop clients against the same store. Use one desktop seeder plus web clients, separate
  OS users/devices, or the in-memory headless runner.
- Clear caches for cold runs. On desktop, remove the `MusicPlayer_Debug` directory. On web,
  use a fresh profile or a new incognito window.
- Count local cache separately from P2P. Both save origin egress, but only peer chunks prove
  peer delivery.
- Use medians/p75/p95 across at least 10 repetitions for thesis numbers. Single runs are
  useful for debugging only.
