# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A music player with a Flutter frontend (multi-platform) and a Spring Boot backend. The core feature is **peer-assisted streaming**: songs are split into 64 KB chunks, SHA-256 verified, served from the server or forwarded between peers via WebRTC DataChannels.

## Repository Structure

```
music-player-backend/   # Spring Boot 4.0.3, Java 25
music-player-frontend/  # Flutter, Dart SDK ^3.7.2
```

---

## Backend

### Commands

```bash
cd music-player-backend

# Start PostgreSQL (required before running the app)
docker-compose up -d

# Build (runs OpenAPI codegen)
./mvnw clean package -DskipTests

# Run
./mvnw spring-boot:run

# Run all tests (uses Testcontainers – Docker required)
./mvnw test

# Run a single test class
./mvnw test -Dtest=DataSyncServiceTest

# Run a single test method
./mvnw test -Dtest=DataSyncServiceTest#methodName
```

### Architecture

- **API-first**: All REST endpoints are defined in `src/main/resources/api.yml`. The `openapi-generator-maven-plugin` generates controller interfaces and DTO classes into `com.example.musicplayerbackend.controller` and `com.example.musicplayerbackend.domain` during `mvn compile`. **Never edit generated files manually.**
- **Packages**: `config/` (Spring config beans), `components/` (filters, WebSocket handler), `controller/` (REST implementations), `service/` (business logic), `data/` (JPA repositories), `domain/` (JPA entities + generated DTOs), `mapper/` (MapStruct), `exception/` (global handler).
- **Database**: PostgreSQL, schema `music_library`. Liquibase manages migrations (`src/main/resources/db/changelog/`). JPA DDL is `validate`-only—all schema changes go through Liquibase changesets.
- **Auth**: Email OTP + Google OAuth. JWT access + refresh tokens via JJWT. `JWTAuthenticationFilter` validates tokens on each request.
- **Chunked storage**: Songs are split into 64 KB chunks on upload. Each `Chunk` entity holds a `content_hash` (SHA-256) and `storage_path`. `SongChunk` is the ordered join table. Deduplication is by hash.
- **WebSocket signaling** (`SignalingHandler`): Peers register cached chunk indices, discover peers for a song, and exchange WebRTC OFFER/ANSWER/ICE_CANDIDATE messages. The server also pushes `SYNC_TRIGGER` events to all sessions of a user when their library changes.
- **Environment variables**: `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`, `MAIL_HOST`, `MAIL_USER`, `MAIL_PASSWORD`. Defaults for DB are `localhost:5432/music_player_db` with `admin/admin` (matching `docker-compose.yml`). Note: docker-compose maps host port **5445** → container 5432.

---

## Frontend

### Commands

```bash
cd music-player-frontend

# Get dependencies
flutter pub get

# Regenerate ObjectBox bindings (after changing @Entity classes)
dart run build_runner build

# Run on a specific platform
flutter run -d linux
flutter run -d chrome

# Run tests
flutter test

# Run a single test file
flutter test test/some_test.dart

# Analyze
flutter analyze
```

### Architecture

- **Platform split**: `lib/platforms/{android,ios,linux,macos,web,windows}/` each contain platform-specific `ui/` (screens, widgets, tabs) and `services/`. Platform entry points are `*_app.dart` files (e.g. `web_app.dart`, `macos_app.dart`).
- **Core (platform-agnostic)**: `lib/core/` contains all shared logic:
  - `entities/` – ObjectBox-annotated domain models (`Song`, `Album`, `Artist`, `Playlist`, `User`, `AppSettings`, `AudioSettings`).
  - `repository/interfaces/` – abstract repository interfaces; implementations in `objectbox/` (persistent, desktop/mobile), `memory/` (web/test), `storage/` (file-based chunk cache).
  - `services/` – business logic. Key services:
    - `AppAudioService` – wraps `just_audio` `AudioPlayer`, manages queue, builds `AudioSource` per platform.
    - `ChunkService` – fetches chunks with a hot RAM cache (15 entries), disk cache, and peer fallback. First 8 chunks always come from the server (prefix path); subsequent chunks try WebRTC peers first (200 ms timeout), then fall back to the server.
    - `P2PChunkedAudioSource` – `StreamAudioSource` implementation that streams audio by assembling chunks on demand with look-ahead prefetch.
    - `WebRTCService` – manages WebRTC peer connections and DataChannels. Signaling goes through a WebSocket to the backend. Binary chunk messages use an 8-byte header: `[songId: uint32BE][chunkIndex: uint32BE][data...]`.
    - `rest_clients/` – HTTP clients (`AuthService`, `SongRestService`, `StreamingRestService`, `DataSyncRestService`).
  - `providers/` – `ChangeNotifier` providers for UI state (songs, albums, artists, playlists, audio, selection, lyrics, user).
  - `database/` – ObjectBox store init (`objectBox.dart`) and generated code (`objectbox.g.dart`). Do not edit `objectbox.g.dart` manually; regenerate with `build_runner`.
- **State management**: `provider` package. Providers are composed at app startup and injected via `MultiProvider`.
- **Audio backends**: `just_audio` for web/Android/iOS; `media_kit` for Linux/Windows.
- **ObjectBox output dir** is `core/database` (set in `pubspec.yaml`).