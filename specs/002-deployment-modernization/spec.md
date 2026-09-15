# Deployment Modernization

## Goal

Make backend and frontend releases verifiable and recoverable without a deliberate serving outage.

## Requirements

- The backend has a container health check, graceful stop allowance, start-first update, and
  rollback policy.
- Deployment publishes an immutable image digest, verifies every desired task and the public API,
  and explicitly rolls back on convergence failure.
- Frontend releases are uploaded to a versioned directory and atomically selected through a stable
  symlink while prior releases remain available.
- The single-node database and music bind mount are documented as non-replicated state.

## Out of Scope

No production mutation, database migration, second-server address, or high-availability claim is
introduced by this feature.
