import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:anime_friends/core/network/api_client.dart';
import 'package:anime_friends/core/state/app_state.dart';
import 'package:anime_friends/main.dart';
import 'package:flutter/material.dart';

class _FakeHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    throw StateError(
      'Unexpected HTTP request in widget test: '
      '${request.method} ${request.url}',
    );
  }

  @override
  void close() {}
}

void main() {
  testWidgets('Sign-in screen displays email authentication', (tester) async {
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
    expect(find.text('Your anime community starts here.'), findsOneWidget);
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Email address'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.text('Forgot password?'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('New here? Create an account'), findsOneWidget);
  });

  testWidgets('Registration screen displays required account fields', (
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

    await tester.tap(find.text('New here? Create an account'));
    await tester.pumpAndSettle();

    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Display name (optional)'), findsOneWidget);
    expect(find.text('Email address'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(4));
    expect(find.text('Create account'), findsNWidgets(2));
    expect(find.text('Already have an account? Sign in'), findsOneWidget);
    expect(find.text('Forgot password?'), findsNothing);
  });

  testWidgets('Profile recovery screen offers retry and sign out', (
    tester,
  ) async {
    final testApi = AnimeFriendsApi(
      client: _FakeHttpClient(),
      storage: const FlutterSecureStorage(),
    );

    final testState = AppState(api: testApi)
      ..isInitializing = false
      ..needsProfileRecovery = true
      ..authError = 'Your profile could not be loaded.';

    addTearDown(testState.dispose);

    await tester.pumpWidget(
      AnimeFriendsApp(appState: testState),
    );
    await tester.pumpAndSettle();

    expect(find.text('Restore your account'), findsOneWidget);
    expect(find.text('Your profile could not be loaded.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);

    expect(find.text('Email address'), findsNothing);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('Invalid email is rejected on sign-in', (tester) async {
    final testApi = AnimeFriendsApi(
      client: _FakeHttpClient(),
      storage: const FlutterSecureStorage(),
    );

    final testState = AppState(api: testApi)..isInitializing = false;
    addTearDown(testState.dispose);

    await tester.pumpWidget(AnimeFriendsApp(appState: testState));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'invalid-email');
    await tester.enterText(find.byType(TextField).at(1), 'ExamplePassword123');

    final signInButton = find.widgetWithText(ElevatedButton, 'Sign in');
    await tester.ensureVisible(signInButton);
    await tester.tap(signInButton);
    await tester.pump();

    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(testState.isBusy, isFalse);
  });
  testWidgets('Invalid username is rejected during registration', (
    tester,
  ) async {
    final testApi = AnimeFriendsApi(
      client: _FakeHttpClient(),
      storage: const FlutterSecureStorage(),
    );

    final testState = AppState(api: testApi)..isInitializing = false;
    addTearDown(testState.dispose);

    await tester.pumpWidget(AnimeFriendsApp(appState: testState));
    await tester.pumpAndSettle();

    await tester.tap(find.text('New here? Create an account'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'ab');
    await tester.enterText(find.byType(TextField).at(2), 'user@example.com');
    await tester.enterText(find.byType(TextField).at(3), 'ExamplePassword123');

    final createButton = find.widgetWithText(ElevatedButton, 'Create account');
    await tester.ensureVisible(createButton);
    await tester.tap(createButton);
    await tester.pump();

    expect(
      find.text(
        'Username must be 3–24 characters: lowercase letters, numbers or underscores.',
      ),
      findsOneWidget,
    );
    expect(testState.isBusy, isFalse);
  });

  testWidgets('Invalid email is rejected for password reset', (tester) async {
    final testApi = AnimeFriendsApi(
      client: _FakeHttpClient(),
      storage: const FlutterSecureStorage(),
    );

    final testState = AppState(api: testApi)..isInitializing = false;
    addTearDown(testState.dispose);

    await tester.pumpWidget(AnimeFriendsApp(appState: testState));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'invalid-email');

    final resetButton = find.text('Forgot password?');
    await tester.ensureVisible(resetButton);
    await tester.tap(resetButton);
    await tester.pump();

    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(testState.isBusy, isFalse);
  });
}
