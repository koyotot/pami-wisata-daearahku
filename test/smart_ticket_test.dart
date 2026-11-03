import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:wisata_daerahku/data/ticket_scanner_state.dart';
import 'user_support.dart';

void main() {
  test(
      'scanner previews once and retries unknown confirm with same payload and key',
      () async {
    final pending = Completer<http.Response>();
    var previews = 0;
    final keys = <String?>[];
    final bodies = <String>[];
    final session = await signedInSession((request) async {
      if (request.url.path.endsWith('/scope')) {
        return jsonResponse({
          'data': {'global': true, 'destinations': []}
        });
      }
      if (request.url.path.endsWith('/preview')) {
        previews++;
        return pending.future;
      }
      expect(request.url.path, endsWith('/confirm'));
      keys.add(request.headers['Idempotency-Key']);
      bodies.add(request.body);
      if (keys.length == 1) return jsonResponse({}, 503);
      return jsonResponse({
        'data': {'ticket_guid': 'ticket-1', 'status': 'checked_in'}
      });
    });
    session.role = 2;
    final state = TicketScannerState(repositoryFor(session));
    await state.loadScope();
    final scan = state.capture('WDR1.opaque');
    await state.capture('WDR1.other');
    await Future<void>.delayed(Duration.zero);
    expect(previews, 1);
    expect(keys, isEmpty);
    pending.complete(jsonResponse({
      'data': {'can_confirm': true, 'ticket_guid': 'ticket-1'}
    }));
    await scan;
    await state.confirm();
    expect(state.confirmUncertain, isTrue);
    state.reset();
    expect(state.hasCapture, isTrue);
    await state.confirm();
    expect(keys.length, 2);
    expect(keys.last, keys.first);
    expect(
        keys.first,
        matches(RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
    expect(bodies.last, bodies.first);
    expect(jsonDecode(bodies.first), {'qr_payload': 'WDR1.opaque'});
    expect(state.result?['status'], 'checked_in');
    expect(state.hasCapture, isFalse);
    state.dispose();
  });

  test('session change drops scanner preview and prevents confirm', () async {
    var confirms = 0;
    final session = await signedInSession((request) async {
      if (request.url.path.endsWith('/scope')) {
        return jsonResponse({
          'data': {
            'global': false,
            'destinations': [
              {'guid': 'dest-1'}
            ]
          }
        });
      }
      if (request.url.path.endsWith('/preview')) {
        return jsonResponse({
          'data': {'can_confirm': true}
        });
      }
      if (request.url.path.endsWith('/confirm')) confirms++;
      return jsonResponse({'data': {}});
    });
    session.role = 1;
    final state = TicketScannerState(repositoryFor(session));
    await state.loadScope();
    await state.capture('WDR1.opaque');
    expect(state.canConfirm, isTrue);
    await session.logout();
    expect(state.preview, isNull);
    expect(state.hasCapture, isFalse);
    await state.confirm();
    expect(confirms, 0);
    state.dispose();
  });
}
