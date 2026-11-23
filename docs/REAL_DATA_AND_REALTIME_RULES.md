# Real data and real-time release rules

Updated: 2026-11-22

These rules are mandatory for Anime Friends. A UI preview is not a working feature.

## Data rules

- Do not bundle sample anime titles, fake accounts, fake conversations, fake posts, fake notifications, or pretend stream URLs.
- Do not insert fabricated content when an API returns an empty list or an error.
- Empty results must show an honest empty state. Network failures must show an unavailable/retry state.
- Anime search results must come from the configured catalogue API. The current catalogue integration is AniList search only.
- User-generated content must be stored by the backend and returned from authenticated API endpoints.

## Real-time rules

- Direct messages are written through the authenticated backend API. The backend emits Socket.IO `chat:new-message` events to both participants; the app responds by refreshing the affected chat data.
- Feed updates use authenticated Socket.IO subscriptions and server events.
- Watch Together currently has backend room membership, playback-state and room-chat Socket.IO handlers. The Flutter client does not yet provide the complete room socket UI/synchronization lifecycle. Do not describe Watch Together as fully real-time until that client work and live integration tests pass.
- A Socket.IO connection failure must not be presented as a successful live session.
- Real multi-user operation requires a reachable hosted HTTPS backend. No hosted backend is included or configured in this source archive.

## Release gate

Do not mark a feature complete until it has automated API/authorization tests, client integration tests, reconnect/offline tests where applicable, and physical-device verification. Do not claim the whole app is production-ready based only on syntax checks or a successful ZIP operation.

## Current known limitations

See `TECHNICAL_IMPLEMENTATION_STATUS.md`. In particular, the archive still lacks a production anime streaming provider and video player, and Watch Together is not yet end-to-end complete in the Flutter client. These are intentionally stated rather than hidden behind demo content.
