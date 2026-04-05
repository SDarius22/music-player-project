# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A hybrid peer-assisted music streaming system. Songs are stored as deduplicated 64 KB SHA-256-verified chunks. Playback uses a hybrid model: first 8 chunks from the server, remaining chunks from WebRTC peers with 200ms timeout fallback to server.

## Repository Structure

```
music-player-backend/   — Spring Boot 4.0.3, Java 25
music-player-frontend/  — Flutter (Dart ^3.7.2), multi-platform
diagrams/               — PlantUML architecture diagrams
```

---

## Backend

### Common Commands

```bash
# Start PostgreSQL + Redis (required before running backend)
docker-compose up -d

# Run backend (port 9000)
./mvnw spring-boot:run

# Run all tests
./mvnw test

# Run a single test class
./mvnw test -Dtest=ClassName

# Build (skip tests)
./mvnw clean package -DskipTests

# Regenerate API controllers/DTOs from api.yml
./mvnw compile
```

### Architecture

**API-first design**: All REST endpoints are defined in `src/main/resources/api.yml`. On `mvn compile`, openapi-generator generates controller interfaces and DTOs into `target/generated-sources/openapi/`. Never hand-edit generated files — edit `api.yml` instead.

**Key packages** (all under `com.example.musicplayerbackend`):
- `controller/` — implements generated interfaces; thin, delegates to services
- `service/` — business logic (SongService handles chunk deduplication; StreamingService handles hybrid delivery)
- `data/` — Spring Data JPA repositories
- `domain/` — JPA entities
- `mapper/` — MapStruct mappers (generated; add mappings in interface, run compile)
- `config/` — Spring configuration (security, WebSocket, Redis, Jackson)
- `components/` — `JWTAuthenticationFilter`, `SignalingHandler` (WebSocket), `RedisSignalingListener`

**Chunk deduplication**: `Chunk` entity holds 64 KB binary data keyed by SHA-256 hash. `SongChunk` is a join table ordering chunks per song. Upload computes hashes client-side; server only stores new chunks.

**WebSocket signaling** (`SignalingHandler`): handles `OFFER`/`ANSWER`/`ICE` (WebRTC negotiation) and `REGISTER_CACHE`/`DISCOVER_PEERS`/`SYNC_TRIGGER` (peer discovery). Redis pub/sub (`RedisSignalingListener`) fan-outs signals across backend replicas.

**Database migrations**: Liquibase changelogs in `src/main/resources/db/changelog/`. Add new migrations as numbered XML files — never modify existing ones.

**Testing pattern**: Integration tests use Testcontainers with a static initializer (not `@Testcontainers`/`@Container` annotations) to avoid port churn. See `BaseRepositoryTest` for the pattern.

---

## Frontend

### Common Commands

```bash
# Get dependencies
flutter pub get

# Run on Linux desktop
flutter run -d linux

# Run on Chrome
flutter run -d chrome

# Run all tests
flutter test

# Run a single test file
flutter test test/path/to/test.dart

# Regenerate ObjectBox code (after entity changes)
dart run build_runner build --delete-conflicting-outputs
```

### Architecture

**Repository pattern**: Interfaces in `lib/core/repository/interfaces/`. Two implementations:
- `objectbox/` — used on desktop/mobile (persistent, ObjectBox ORM)
- `memory/` — used on web and in tests

**ObjectBox generated code** lives in `lib/core/database/`. Run `build_runner` after modifying any `@Entity`-annotated class.

**State management**: Provider. Providers live in `lib/core/providers/`. Screens consume providers via `context.watch`/`context.read`.

**Audio stack**: `just_audio` on mobile/web, `media_kit` on desktop, bridged by the local `just_audio_media_kit` library in `lib/local_libs/`.

**Platform entry point**: `lib/main.dart` selects a platform-specific app variant. Platform-specific runner code is in the top-level `linux/`, `windows/`, `macos/`, `android/`, `ios/`, `web/` directories.

**Screens** (`lib/core/ui/screens/`): 19 screens covering the full app flow — home, artist/album/playlist detail, track detail, login/register, upload, settings, etc.

**Services** (`lib/core/services/`): abstract interfaces under `abstract/`, REST clients under `rest_clients/`. Services are injected via Provider.