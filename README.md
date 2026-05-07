# Music Player

A cross-platform, peer-assisted music streaming application. The server delivers
the first chunks of every song (a small "prefix") and then steps aside while
clients exchange the remaining chunks directly with each other over WebRTC,
falling back to the server whenever a peer is missing or slow. The goal is to
keep the server bandwidth bill flat as the number of concurrent listeners
grows, without sacrificing the playback experience.

This repository contains the backend, the cross-platform client, the diagrams,
and the LaTeX sources of the bachelor's thesis that documents the system.

## What it does

- Serves a music library with the usual catalogue features: artists, albums,
  songs, search, sort, playlists, library management.
- Streams audio in 64 KiB chunks identified by their SHA-256, which both
  deduplicates storage on the server and lets the client verify every chunk
  it receives, regardless of the source.
- Establishes WebRTC data channels between currently-listening clients and
  pulls non-prefix chunks directly from peers. If a peer is slow or absent,
  the server fallback kicks in transparently.
- Synchronises playback position, shuffle and repeat across the user's devices
  through a small WebSocket push. Library mutations (likes, play counts, last
  played) are propagated through per-song REST PATCH calls.
- Runs on Linux, macOS, Windows, Android, iOS and the web from a single
  Flutter codebase.

## Hosted instance

The reference deployment runs on the author's VPSes:

- API: `https://api.dariussala.com/music-player`
- Signaling WebSocket: `wss://wss.dariussala.com/music-player/signaling`

Native binaries (Android APK, Linux tarball, Windows zip, macOS app) are
published as artifacts on every GitHub release of this repository.

## Repository layout

```
music-player-project/
  music-player-backend/          Java 25 + Spring Boot 4 backend
  music-player-frontend/         Flutter client (Linux/macOS/Windows/Android/iOS/web)
  diagrams/                      PlantUML diagrams used in the thesis
  written-thesis-latex-sources/  Bachelor's thesis (LaTeX)
  .github/workflows/             CI pipelines for build and deploy
```

## Tech stack

**Backend.** Java 25, Spring Boot 4, Maven, PostgreSQL 18 (with Liquibase
migrations under `src/main/resources/db/changelog/`), Redis (used for
cross-replica pub/sub and the peer chunk index), Spring WebSocket, OpenAPI-first
REST contract in `src/main/resources/api.yml` with code generation through
the OpenAPI generator and DTO mappers through MapStruct.

**Frontend.** Flutter (stable channel), `provider` for dependency injection,
ObjectBox for local persistence on desktop and mobile, in-memory storage on
the web, `just_audio` on Android/iOS/web, `media_kit` on Linux/macOS/Windows,
`flutter_webrtc` for the P2P data channels, and a Service Worker
(`web/p2p-worker.js`) to bridge the browser audio element to the chunk service.

**Deployment.** Backend images are built and pushed to
`ghcr.io/sdarius22/music-player-project/music-player-backend`. The production
deployment uses Docker Swarm with two backend replicas behind a reverse
proxy, a single PostgreSQL instance, and a single Redis instance.

## Prerequisites for local development

- JDK 25 (Temurin or any other distribution)
- Maven (the wrapper at `music-player-backend/mvnw` is fine)
- Docker and Docker Compose
- Flutter SDK (stable channel) for the client
- On Linux, the system packages required by `media_kit`:
  `clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev`
  `libstdc++-12-dev libsecret-1-dev libjsoncpp-dev libmpv-dev mpv`
  `libayatana-appindicator3-dev`

## Building and running the backend

The backend expects PostgreSQL and Redis to be running. The committed
`docker-compose.yml` is tuned for production (Docker Swarm); for local
development the easiest path is to start ad-hoc containers:

```bash
docker run --name music-pg -e POSTGRES_USER=admin -e POSTGRES_PASSWORD=admin \
           -e POSTGRES_DB=music_player_db -p 5432:5432 -d postgres:18
docker run --name music-redis -p 6379:6379 -d redis:alpine
```

Then, from `music-player-backend/`:

```bash
./mvnw spring-boot:run
```

The application listens on `http://localhost:9000`. The OpenAPI document is
at `src/main/resources/api.yml`; after editing it, run `./mvnw compile` to
regenerate the controllers and DTOs.

### Backend environment variables

The defaults in `application.yml` work out of the box with the Docker
commands above. In production, the following variables override them:

| Variable        | Default              | Used for                                    |
|-----------------|----------------------|---------------------------------------------|
| `DB_HOST`       | `localhost`          | PostgreSQL host                             |
| `DB_PORT`       | `5432`               | PostgreSQL port                             |
| `DB_NAME`       | `music_player_db`    | PostgreSQL database name                    |
| `DB_USER`       | `admin`              | PostgreSQL user                             |
| `DB_PASSWORD`   | `admin`              | PostgreSQL password                         |
| `REDIS_HOST`    | `localhost`          | Redis host (port is fixed at `6379`)        |
| `MAIL_HOST`     | (required in prod)   | SMTP server used for verification codes     |
| `MAIL_USER`     | (required in prod)   | SMTP username                               |
| `MAIL_PASSWORD` | (required in prod)   | SMTP password                               |

The Spring Boot Mail starter expects port `587` with STARTTLS enabled.

## Building and running the frontend

From `music-player-frontend/`:

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run -d <platform>
```

Where `<platform>` is one of `linux`, `macos`, `windows`, `chrome`, an
attached Android device id, or an iOS simulator id. The
`build_runner` step is required after editing the ObjectBox `@Entity`
classes; if you only edit UI code, you can skip it.

### Frontend configuration

The two endpoints the client connects to are passed at build time through
`--dart-define`. They default to a local backend, so a plain
`flutter run -d linux` is enough during development:

| Define          | Default                                 |
|-----------------|-----------------------------------------|
| `API_BASE_URL`  | `http://localhost:9000/api/v1`          |
| `WS_BASE_URL`   | `ws://localhost:9000/ws/signaling`      |

To build against the hosted backend:

```bash
flutter build linux --release \
  --dart-define=API_BASE_URL=https://api.dariussala.com/music-player \
  --dart-define=WS_BASE_URL=wss://wss.dariussala.com/music-player/signaling
```

The web target uses a separate entrypoint, `lib/main_web.dart`:

```bash
flutter build web -t lib/main_web.dart --release \
  --dart-define=API_BASE_URL=https://api.dariussala.com/music-player \
  --dart-define=WS_BASE_URL=wss://wss.dariussala.com/music-player/signaling
```

The web build needs a secure origin in production because the Service
Worker that intercepts audio range requests refuses to register on
non-HTTPS origins (with the usual `localhost` exemption during
development).

## Running the tests

```bash
# Backend (uses Testcontainers, Docker has to be running)
cd music-player-backend && ./mvnw test

# Frontend
cd music-player-frontend && flutter test
```

A single backend test class can be run with `-Dtest=ClassName`. The
backend integration tests spin up real PostgreSQL and Redis containers
through Testcontainers, so they take noticeably longer than the unit
tests but verify the full stack.

## Deployment

The repository ships three GitHub Actions workflows under
`.github/workflows/`:

- `deploy-backend.yml`: on every push to `master` that touches
  `music-player-backend/`, runs the backend tests, builds the image, pushes
  it to GHCR, copies `docker-compose.yml` to the VPS over SSH, and runs
  `docker stack deploy` against a Swarm running there.
- `deploy-frontend.yml`: on every push to `master` that touches
  `music-player-frontend/`, builds the web target with the production
  `--dart-define` values and rsync-copies it to the VPS web root.
- `build-publish.yml`: on every release tag, builds the Android, Linux,
  Windows and macOS binaries with the production endpoints and uploads
  them as release artifacts.

The required secrets are `VPS_HOST`, `VPS_USER`, `VPS_SSH_KEY`,
`DB_PASSWORD`, `MAIL_HOST`, `MAIL_USER`, `MAIL_PASSWORD`, and the
equivalents for the secondary VPS (`VPS_HOST_CLUJ`).

## Documentation

The full design and implementation are documented in the bachelor's thesis
under `written-thesis-latex-sources/`. The chapter outline is:

1. Introduction and the cost problem.
2. Theoretical background and the abstract system model.
3. System implementation: schema, services, client architecture, streaming
   pipeline, multi-instance coordination, testing, limitations.
4. Graphical interface and application execution.

The diagrams that the thesis uses live in `diagrams/` as PlantUML sources.

## License

No license is currently attached to the repository. All rights reserved by
the author until a license is added.
