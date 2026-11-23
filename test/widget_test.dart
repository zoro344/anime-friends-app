import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:anime_friends/core/network/api_client.dart';
import 'package:anime_friends/core/state/app_state.dart';
import 'package:anime_friends/main.dart';

class _FakeHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    throw StateError(
      'Unexpected HTTP request in widget test: ${request.method} ${request.url}',
    );
  }

  @override
  void close() {}
}

void main() {
  testWidgets('Anime Friends starts at the account sign-in gate', (
    tester,
  ) async {
    final testApi = AnimeFriendsApi(
      client: _FakeHttpClient(),
      storage: const FlutterSecureStorage(),
    );

    final testState = AppState(api: testApi)
      ..isInitializing = false;

    addTearDown(testState.dispose);

    await tester.pumpWidget(
      AnimeFriendsApp(appState: testState),
    );

    await tester.pumpAndSettle();

    expect(find.text('Anime Friends'), findsOneWidget);
    expect(find.text('Backend HTTPS URL'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('New here? Create an account'), findsOneWidget);
  });
}
