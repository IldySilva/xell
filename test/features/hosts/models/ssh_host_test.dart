import 'package:flutter_test/flutter_test.dart';
import 'package:xell/features/hosts/models/os_type.dart';
import 'package:xell/features/hosts/models/ssh_host.dart';

void main() {
  final host = SshHost(
    id: 'h1',
    name: 'web-1',
    hostname: '10.0.0.5',
    port: 2222,
    username: 'deploy',
    authType: AuthType.privateKey,
    privateKeyPath: '/Users/me/.ssh/id_ed25519',
    tags: const ['prod', 'web'],
    isFavorite: true,
    lastConnectedAt: DateTime(2026, 11, 18, 10, 30),
    notes: 'behind VPN',
    detectedOs: OsType.values.first,
  );

  test('JSON round-trip keeps every field', () {
    final back = SshHost.fromJson(host.toJson());
    expect(back.toJson(), host.toJson());
  });

  test('reads JSON without optional fields', () {
    final back = SshHost.fromJson({
      'id': 'h2',
      'name': 'db',
      'hostname': 'db.local',
      'port': 22,
      'username': 'root',
      'authType': 'password',
      'tags': <String>[],
      'isFavorite': false,
    });
    expect(back.privateKeyPath, isNull);
    expect(back.lastConnectedAt, isNull);
    expect(back.detectedOs, isNull);
  });

  test('matchesQuery searches name, hostname, user and tags', () {
    expect(host.matchesQuery('WEB'), isTrue);
    expect(host.matchesQuery('10.0.0'), isTrue);
    expect(host.matchesQuery('deploy'), isTrue);
    expect(host.matchesQuery('prod'), isTrue);
    expect(host.matchesQuery('staging'), isFalse);
    expect(host.matchesQuery(''), isTrue);
  });
}
