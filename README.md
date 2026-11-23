# Anime Friends

Anime Friends is an anime-focused community Android application built with Flutter and a Node.js / Socket.IO backend.

## Important release truth

This archive contains real API-backed foundations, not a fully deployed production service. It contains **no bundled demo anime titles or fake chat conversations**. Empty states are intentional when the backend has no data. Direct messages use authenticated backend storage and Socket.IO notifications; Watch Together still needs its complete Flutter room socket/player synchronization UI and live integration testing. No hosted backend, production streaming provider, or video player is included. See `docs/REAL_DATA_AND_REALTIME_RULES.md` and `docs/TECHNICAL_IMPLEMENTATION_STATUS.md` before treating any feature as complete.

## Structure

- `app/` — Flutter Android application.
- `backend/` — Node.js API and Socket.IO service.
- `docs/` — implementation status and technical decisions.

## Flutter

```bash
cd app
flutter pub get
dart format lib test
flutter analyze
flutter test
flutter build apk --debug
```

The app starts at sign-in. Configure the public backend URL in the sign-in screen. Public backend URLs must use HTTPS. No hosted backend is configured by this source milestone.

## Backend

```bash
cd backend
npm ci
cp .env.example .env
# Edit .env with a unique JWT secret, exact CORS allowlist and reviewed RSS feeds.
npm run check
npm start
```

The JSON database is a single-process prototype. Back up existing data before updating a running backend. No database migration or deployment is included.

## Project status

Read `docs/TECHNICAL_IMPLEMENTATION_STATUS.md` for implemented scope, remaining work and validation evidence. Read `docs/PLAYER_PROVIDER_DECISION.md` for the provider policy and player comparison. The player engine remains unselected pending a physical-device benchmark.


## Watch Together / AnymeX bridge (first integration milestone)

The Watch Together create flow now requests a Watchium room through the Anime Friends backend, creates the matching social room, and opens AnymeX with its Watchium deep link. Friends join the Anime Friends room by its social room code; after joining, the app opens the stored AnymeX room link. Configure Watchium backend environment variables as documented in `backend/README.md`. A public stream URL and approved provider identity are required.
