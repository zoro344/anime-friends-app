# Anime Friends Backend

Node.js 20+ / Express / Socket.IO backend.

## Local checks

```bash
npm ci
npm run check
npm start
```

## Environment

Copy `.env.example` to `.env`. In production:
- Set `NODE_ENV=production`.
- Set a unique `JWT_SECRET` with at least 32 characters of random entropy.
- Set an explicit comma-separated `CORS_ORIGIN` allowlist. Wildcard CORS is rejected.
- Configure only reviewed HTTPS anime-news RSS feeds.
- For AnymeX room creation, set `WATCHIUM_SERVER_URL`, `WATCHIUM_API_TOKEN` (if required by your Watchium server), and `WATCHIUM_ALLOWED_IDENTITIES` to exact verified provider identities. Keep these secrets on the backend only.
- Keep `.env`, `data/db.json`, and backups out of Git.

## Data

The backend uses a JSON file for the current single-process prototype. Writes are serialized and use a temporary file plus rename. New collections are added additively when an older database is loaded. This is not a multi-instance database and is not suitable for horizontally scaled production hosting.

Back up `data/db.json` before deploying a new backend version. Test the additive schema behavior against a copy of the database first. The app source archive intentionally excludes private database files.

## API groups

- `/api/auth/*` — signup and login.
- `/api/me` — current account and profile update.
- `/api/posts` — feed, post creation/edit/delete, votes and comments.
- `/api/anime/search` — AniList search.
- `/api/library` — personal anime library.
- `/api/news` — configured RSS news, filtering and pagination.
- `/api/friends/*` — friend requests and accepted friends.
- `/api/chats/*` — friend-only direct messages and read timestamps.
- `/api/watch/rooms/*` — Anime Friends social room create/join/leave/close and host playback state.
- `/api/watchium/rooms` — server-side Watchium room creation and AnymeX deep-link handoff.
- `/api/notifications` — in-app notification records.
- `/api/blocks/*` and `/api/reports` — moderation API foundations.

Socket.IO authenticates with the same JWT supplied in `handshake.auth.token`. Feed, direct-message and Watch Together room events are available as documented in the source implementation.

## AnymeX / Watchium integration requirements

The Flutter app first asks the Anime Friends backend to create a Watchium room, then creates the matching Anime Friends social room and opens the returned `anymex://watchium/join/<CODE>` deep link. Joining an Anime Friends room opens its stored AnymeX deep link after the social join succeeds.

Room creation requires all of the following:
- AnymeX installed on the device that opens the deep link.
- A working Watchium server configured on the Anime Friends backend.
- The user's provider identity (AniList, MyAnimeList or Simkl) included in `WATCHIUM_ALLOWED_IDENTITIES` after verification.
- A valid public HTTP(S) episode stream URL. Local/private proxy streams are rejected. The first integration screen asks the room host to supply this URL; it does not yet import scraper results automatically.

This archive does not modify AnymeX. It uses the existing Watchium API and AnymeX deep-link contract found in the supplied AnymeX source. Room synchronization still depends on the Watchium server and compatible playback source/stream metadata; the Anime Friends app does not implement its own video player in this milestone. If AnymeX or Watchium changes its contract, this bridge must be revalidated.

## Current limitations

See `docs/TECHNICAL_IMPLEMENTATION_STATUS.md`. In particular, no production anime stream provider or playback engine is selected, and the Watch Together player UI/client synchronization is not complete.
