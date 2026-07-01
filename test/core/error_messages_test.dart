import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zynk/core/utils/error_messages.dart';

void main() {
  test('prefers the edge function\'s {error} message', () {
    final e = FunctionException(status: 401, details: {'error': 'Invalid PIN'});
    expect(friendlyError(e), 'Invalid PIN');
  });

  test('maps bare status codes to friendly text (no raw code leaks)', () {
    for (final status in [401, 403, 404, 409, 429, 500]) {
      final msg = friendlyError(FunctionException(status: status));
      expect(msg.contains(status.toString()), isFalse, reason: 'status $status leaked');
      expect(msg, isNotEmpty);
    }
  });

  test('strips the "Exception:" prefix from plain exceptions', () {
    expect(friendlyError(Exception('Please select a branch')),
        'Please select a branch');
  });

  test('detects network errors', () {
    expect(friendlyError('SocketException: Failed host lookup'),
        contains('internet'));
  });
}
