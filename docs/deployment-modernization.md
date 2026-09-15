# Deployment Modernization

Backend releases require an active Swarm manager with `music_storage=true`; provisioning owns node
initialization and labels. The workflow pulls and deploys the exact published image digest, verifies
health, and only rolls back when the previous service image is still required.

Frontend releases use unique SHA/run/attempt directories, an atomic `current` switch, and a
`release-id` HTTP marker. The initial root migration and nginx validation are operator prerequisites;
before the workflow is enabled, `current` must point to a valid root containing `index.html`,
`main.dart.js`, `flutter_bootstrap.js`, `.well-known/assetlinks.json`, and a one-line `release-id`
equal to that root's exact release ID.
cached asset URL compatibility still requires a shared asset-versioning decision. Production rollout
and restore drills remain unperformed locally.
