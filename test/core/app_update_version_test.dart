import 'package:flutter_test/flutter_test.dart';
import 'package:zynk/core/services/app_update_service.dart';

void main() {
  test('detects a newer release, ignoring a leading v and build metadata', () {
    expect(isNewerVersion('v1.2.0', '1.1.5'), isTrue);
    expect(isNewerVersion('2.0.0', '1.9.9'), isTrue);
    expect(isNewerVersion('1.10.0', '1.9.0'), isTrue); // numeric, not lexical
  });

  test('same or older is not an update', () {
    expect(isNewerVersion('1.1.5', '1.1.5'), isFalse);
    expect(isNewerVersion('v1.2.0+9', '1.2.0+3'), isFalse); // build ignored
    expect(isNewerVersion('1.1.4', '1.1.5'), isFalse);
    expect(isNewerVersion('1.2.0', '1.10.0'), isFalse);
  });
}
