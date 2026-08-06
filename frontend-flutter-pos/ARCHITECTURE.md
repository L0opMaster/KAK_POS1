# Frontend Architecture Overview

This document gives a concise overview of the `frontend-flutter-pos` architecture and the most important runtime flows for new developers.

High-level components

- Flutter App (frontend-flutter-pos)
  - UI: `lib/pos/screens` and `lib/pos/widgets`
  - State: Riverpod providers in `lib/pos/providers`
  - Domain services: `lib/pos/services` (product, customer, table, cart)
  - Core services: `lib/core/services` (`ApiService`, `AuthService`)
- Backend: Dockerized API (see `docker-compose.yml` in repo root)

Key responsibilities

- UI screens: build widgets, call providers to read/update state.
- Providers: orchestrate async calls and hold UI state (StateNotifier / FutureProvider).
- Domain services: small wrappers that call `ApiService` and map responses to models.
- `ApiService`: single Dio client, handles base URL, headers, JWT interceptor and common error handling.

Common flows (sequence)

```mermaid
flowchart TD
  A[Flutter Screen] -->|read/watch| B[Riverpod Provider]
  B -->|calls| C[Domain Service]
  C -->|GET/POST| D[ApiService (Dio)]
  D -->|HTTP| E[Backend API (docker-compose)]
  E -->|JSON| D
  D -->|response| C
  C -->|model| B
  B -->|state| A

  subgraph Auth
    A2[Login Screen] -->|login| AuthService
    AuthService -->|store token| SharedPreferences
    ApiService -->|reads token| SharedPreferences
  end

  click D href "lib/core/services/api_service.dart" "Open ApiService"
  click B href "lib/pos/providers" "Open providers directory"
  click C href "lib/pos/services" "Open domain services"
```

Notes for maintainers

- Keep `ApiService` generic: prefer `get<T>(path, fromJson: ...)` so domain services only map JSON → models.
- Keep providers thin: move heavy logic into `lib/pos/services` so unit tests can target services easily.
- Avoid calling `ref` after awaiting async operations in widgets — check `mounted` before accessing providers.

Where to start when changing code

- Add a new domain API call: add `getX()` to a service and a corresponding provider test.
- Add a UI screen: create a screen under `lib/pos/screens`, add provider(s) under `lib/pos/providers`, and wire into routes.

Files of interest

- `lib/core/services/api_service.dart` — Dio client, interceptors, error handling
- `lib/core/services/auth_service.dart` — login/logout and token persistence
- `lib/pos/screens/pos_screen.dart` — main POS screen
- `lib/pos/providers/*` — examples for StateNotifier and FutureProvider usage
