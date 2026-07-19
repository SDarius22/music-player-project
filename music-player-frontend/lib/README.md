# Frontend architecture

The Flutter application is organized by responsibility and feature:

- `app/` is the composition root. It owns dependency injection, app-wide state,
  theming, and startup UI.
- `features/` contains user-facing capabilities. Each feature owns its
  presentation state, screens, and feature-specific widgets.
- `shared/presentation/` contains UI building blocks that are intentionally
  reusable across features, such as responsive layout, scaffolds, entity tiles,
  cover rendering, search, and routing helpers.
- `core/` contains framework-independent entities and DTOs plus infrastructure
  shared by multiple features. The peer-to-peer transport is grouped under
  `core/p2p/` because it is an internal subsystem with direct application
  dependencies, not an independently reusable package.
- `platforms/` contains only platform-specific composition and services. Native
  platforms inherit their common ObjectBox and `MaterialApp` setup from
  `NativeMusicPlayerApp`.

Dependencies should point inward: platform entry points compose app/core and
features; features may use core and shared code; shared presentation code must
not depend on a concrete feature unless the component is moved into that
feature.
