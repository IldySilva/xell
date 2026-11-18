import 'package:flutter_test/flutter_test.dart';
import 'package:xell/features/terminal/services/ssh_service.dart';

void main() {
  group('isLegacyAlgorithmError', () {
    test('matches every dartssh2 negotiation failure', () {
      for (final kind in [
        'key exchange',
        'host key',
        'client cipher',
        'server cipher',
        'client MAC',
        'server MAC',
      ]) {
        expect(
          SshService.isLegacyAlgorithmError(StateError('No matching $kind algorithm')),
          isTrue,
          reason: kind,
        );
      }
    });

    test('ignores unrelated errors', () {
      expect(SshService.isLegacyAlgorithmError(StateError('Connection reset')), isFalse);
      expect(SshService.isLegacyAlgorithmError(Exception('timeout')), isFalse);
    });
  });
}
