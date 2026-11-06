import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:wisata_daerahku/data/ticket_scanner_state.dart';
import 'package:wisata_daerahku/services/auth_session.dart';
import 'admin_test_support.dart';

void main() {
  for (final scenario in ['role downgrade', 'assignment revoke']) {
    test('scanner drops stale preview after same-generation $scenario',
        () async {
      var role = scenario == 'role downgrade' ? 2 : 1;
      var revoked = false;
      var writes = 0;
      final session = AuthSession(
          baseUrl: 'https://example.test/api/v1',
          store: MemoryStore(),
          client: MockClient((request) async {
            if (request.url.path.endsWith('/auth/login')) {
              return jsonResponse({
                'data': {
                  'access_token': 'fixture-access',
                  'refresh_token': 'fixture-refresh',
                  'user': {
                    'guid': 'qa-actor',
                    'name': 'QA',
                    'email': 'qa@example.test'
                  }
                }
              });
            }
            if (request.url.path.endsWith('/auth/me')) {
              return jsonResponse({
                'data': {
                  'guid': 'qa-actor',
                  'name': 'QA',
                  'email': 'qa@example.test',
                  'role': role,
                  'status': 'active',
                  'phone': null
                }
              });
            }
            if (request.url.path.endsWith('/scope')) {
              return jsonResponse({
                'data': {
                  'global': role == 2,
                  'destinations': revoked
                      ? []
                      : [
                          {'guid': 'qa-destination'}
                        ]
                }
              });
            }
            if (request.url.path.endsWith('/preview')) {
              return jsonResponse({
                'data': {'can_confirm': true}
              });
            }
            if (request.url.path.endsWith('/confirm')) writes++;
            return jsonResponse({'data': {}});
          }));
      await session.login('qa@example.test', 'fixture-password');
      final generation = session.sessionGeneration;
      final scanner = TicketScannerState(repositoryFor(session));
      addTearDown(scanner.dispose);
      await scanner.loadScope();
      await scanner.capture('WDR1.fixture');
      expect(scanner.canConfirm, isTrue);
      role = 1;
      revoked = true;
      await session.me();
      expect(session.sessionGeneration, generation);
      expect(writes, 0);
      expect(scanner.canConfirm, isFalse,
          reason:
              'Revalidated access must invalidate the previous QR preview.');
      expect(scanner.preview, isNull);
      expect(scanner.scope, isNull);
    });
  }
}
