# AGENTS.md

## Scope and source of truth
- This is a hybrid peer-assisted streaming system: 64 KB SHA-256 chunking, server bootstrap, then WebRTC peer delivery with server fallback.
- Prefer `CLAUDE.md` over `music-player-frontend/README.md` (the frontend README is generic starter text).

## Repo map
- Backend: `music-player-backend/` (Spring Boot 4, Java 25, OpenAPI-first).
- Frontend: `music-player-frontend/` (Flutter, Provider DI/state, platform-specific repos).
- Architecture flows: `diagrams/`, especially `diagrams/flow_press_play.puml`.

## Backend conventions
- API-first: edit `music-player-backend/src/main/resources/api.yml`; never hand-edit generated files in `music-player-backend/target/generated-sources/openapi/`.
- Keep controllers thin adapters; business logic belongs in services (`SongService`, `StreamingService`).
- Dedup + chunk storage is in `music-player-backend/src/main/java/com/example/musicplayerbackend/service/SongService.java` (`processFileIntoChunks()`, negotiated upload: `/songs/negotiate` + `/songs/{fileHash}/chunks/{chunkIndex}`).
- Hybrid streaming endpoints and manifest/chunk reads are in `music-player-backend/src/main/java/com/example/musicplayerbackend/service/StreamingService.java` and `/stream/*` in `api.yml`.
- Liquibase is append-only: add numbered files in `music-player-backend/src/main/resources/db/changelog/changes/` and include them in `music-player-backend/src/main/resources/db/changelog/changelog.yml`.

## Signaling and cross-node behavior
- Signaling WS handling lives in `music-player-backend/src/main/java/com/example/musicplayerbackend/components/SignalingHandler.java`.
- Active message types: `REGISTER_CACHE`, `DISCOVER_PEERS`, `OFFER`, `ANSWER`, `ICE_CANDIDATE`, `SYNC_TRIGGER`, `PLAYBACK_STATE_CHANGED`, `PING`.
- Cross-replica fan-out is Redis pub/sub via `music-player-backend/src/main/java/com/example/musicplayerbackend/components/RedisSignalingListener.java` channels: `signaling:webrtc`, `signaling:sync`, `signaling:playback`.

## Frontend conventions
- Main wiring is in `music-player-frontend/lib/main.dart` and `music-player-frontend/lib/core/ui/abstract_app.dart` (DI graph + `API_BASE_URL`/`WS_BASE_URL`).
- Platform repo split is required: ObjectBox on desktop/mobile (e.g. `music-player-frontend/lib/platforms/linux/linux_app.dart`), in-memory on web (e.g. `music-player-frontend/lib/platforms/web/web_app.dart`).
- Chunk fetch strategy is in `music-player-frontend/lib/core/services/chunk_service.dart`: server prefix (`index < _serverPrefixCount`), then staggered peer requests (200 ms), timeout fallback, hash revalidation.
- Peer ranking/transport is in `music-player-frontend/lib/core/services/webrtc_service.dart` (RTT + throughput scoring; DataChannel chunk protocol).
- Web-specific interception/statistics lives in `music-player-frontend/web/p2p-worker.js`.

## Critical workflows
- Backend (`music-player-backend/`): `docker-compose up -d`; `./mvnw spring-boot:run`; `./mvnw compile` after `api.yml`/MapStruct changes; `./mvnw test` (`-Dtest=ClassName` for single class).
- Frontend (`music-player-frontend/`): `flutter pub get`; `flutter run -d linux` or `flutter run -d chrome`; `flutter test`; `dart run build_runner build --delete-conflicting-outputs` after `@Entity` changes.

## Change guardrails
- Repository integration tests rely on static Testcontainers startup pattern in `music-player-backend/src/test/java/com/example/musicplayerbackend/data/BaseRepositoryTest.java`.
- For backend/frontend contract changes: update `api.yml` first, regenerate backend code (`./mvnw compile`), then update Flutter REST clients/services.
- For playback or P2P regressions, validate against `diagrams/flow_press_play.puml` and relevant `/stream`, signaling, and `/statistics` endpoints in `api.yml`.

