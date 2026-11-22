# Anime Streaming App — Flutter source

## Included
- Anime catalogue search and episode metadata adapter.
- Anime and Watch History tabs.
- Local watch-history persistence.
- Media Kit video player.
- Automatic episode-to-player flow through a configurable, authorized video resolver.
- Multiple returned qualities can be selected in-app.

## Video resolver integration

The app does not extract protected links from AnimePahe or Kwik. AnimePahe episode IDs are metadata, not playable media URLs. To enable automatic playback, configure an HTTPS endpoint for a provider/service that you own or are authorized to use. Tap the network/settings icon in the app bar and save the endpoint.

The app sends a GET request to that endpoint with these query parameters:

- `animeSession`: catalogue anime session ID
- `episodeSession`: selected episode session ID
- `episode`: episode number
- `title`: anime title

Expected JSON response:

```json
{
  "sources": [
    {
      "url": "https://media.example.org/path/master.m3u8",
      "label": "1080p",
      "type": "hls"
    },
    {
      "url": "https://media.example.org/path/video.mp4",
      "label": "720p",
      "type": "mp4"
    }
  ]
}
```

The `sources` property can also be a top-level JSON array. Each source must have an HTTP(S) `url` (or `src`); `label`/`quality` and `type`/`format` are optional. The app validates URLs, displays multiple choices, saves the selected URL to watch history, and opens the player.

**Important:** this ZIP implements the client-side resolver and player connection. It does not include a video-hosting service or a resolver backend, and it cannot produce playable URLs from AnimePahe episode metadata by itself. A configured authorized provider must return direct playable HLS or MP4 URLs. The endpoint must allow requests from the app and should use HTTPS.

## Setup
1. Create a Flutter project to obtain normal platform scaffolding.
2. Replace its `pubspec.yaml` with this one.
3. Copy all Dart files from `lib/` into your project's `lib/`.
4. Merge the INTERNET permission from `android/app/src/main/AndroidManifest.xml` into your Android manifest.
5. Run `flutter pub get`, then `flutter run`.

## Limitations / verification
- This ZIP contains source files, not a compiled APK or a complete generated Flutter platform project.
- The AnimePahe catalogue API has not been live-tested; availability and response formats may change.
- The resolver requires an endpoint from an authorized provider; none is supplied in this project.
- No Flutter build, analyzer, API request, or device test has been run in this environment.
