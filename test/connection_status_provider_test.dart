import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:railway_secretariat/core/providers/connection_status_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Ensure SharedPreferences returns empty (no saved server URL).
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('ConnectionStatusProvider', () {
    test('initial state is unknown', () {
      // Pass a URL so it doesn't immediately resolve to local.
      final provider = ConnectionStatusProvider(
        serverUrl: 'http://localhost:9999',
        pingInterval: const Duration(hours: 1), // prevent auto-pinging
      );

      // The very first state before any async work is unknown.
      expect(provider.state, ServerConnectionState.unknown);
      provider.dispose();
    });

    test('state becomes local when no server URL is configured', () async {
      final provider = ConnectionStatusProvider(
        serverUrl: null,
        pingInterval: const Duration(hours: 1),
      );

      // Give the async _init() time to complete.
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(provider.state, ServerConnectionState.local);
      expect(provider.isLocal, isTrue);
      expect(provider.isConnected, isFalse);
      provider.dispose();
    });

    test('state becomes local with empty string URL', () async {
      final provider = ConnectionStatusProvider(
        serverUrl: '   ',
        pingInterval: const Duration(hours: 1),
      );

      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(provider.state, ServerConnectionState.local);
      provider.dispose();
    });

    test('state becomes disconnected when server is unreachable', () async {
      final provider = ConnectionStatusProvider(
        serverUrl: 'http://127.0.0.1:1', // port 1 — nothing listening
        pingInterval: const Duration(hours: 1),
        pingTimeout: const Duration(seconds: 2),
      );

      // Wait for the first ping to fail.
      await Future<void>.delayed(const Duration(seconds: 3));

      expect(provider.state, ServerConnectionState.disconnected);
      expect(provider.isDisconnected, isTrue);
      expect(provider.lastChecked, isNotNull);
      provider.dispose();
    });

    test('updateServerUrl resets state and re-initializes', () async {
      final provider = ConnectionStatusProvider(
        serverUrl: null,
        pingInterval: const Duration(hours: 1),
      );

      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(provider.isLocal, isTrue);

      // Switch to a (unreachable) remote URL.
      provider.updateServerUrl('http://127.0.0.1:1');
      await Future<void>.delayed(const Duration(seconds: 3));

      expect(provider.isDisconnected, isTrue);
      provider.dispose();
    });

    test('updateServerUrl to null switches back to local', () async {
      final provider = ConnectionStatusProvider(
        serverUrl: 'http://127.0.0.1:1',
        pingInterval: const Duration(hours: 1),
        pingTimeout: const Duration(seconds: 1),
      );

      await Future<void>.delayed(const Duration(seconds: 2));

      provider.updateServerUrl(null);
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(provider.isLocal, isTrue);
      provider.dispose();
    });

    test('serverUrl getter returns the configured URL', () {
      final provider = ConnectionStatusProvider(
        serverUrl: 'http://example.com',
        pingInterval: const Duration(hours: 1),
      );

      expect(provider.serverUrl, 'http://example.com');
      provider.dispose();
    });

    test('notifies listeners on state change', () async {
      final provider = ConnectionStatusProvider(
        serverUrl: null,
        pingInterval: const Duration(hours: 1),
      );

      int notifyCount = 0;
      provider.addListener(() => notifyCount++);

      await Future<void>.delayed(const Duration(milliseconds: 200));

      // Should have been notified at least once (unknown -> local).
      expect(notifyCount, greaterThanOrEqualTo(1));
      provider.dispose();
    });

    test('dispose cancels timer without errors', () async {
      final provider = ConnectionStatusProvider(
        serverUrl: 'http://127.0.0.1:1',
        pingInterval: const Duration(milliseconds: 100),
        pingTimeout: const Duration(seconds: 1),
      );

      await Future<void>.delayed(const Duration(milliseconds: 300));

      // Should not throw.
      expect(() => provider.dispose(), returnsNormally);
    });
  });
}
