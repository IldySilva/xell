// Opt-in: runs only against a disposable SSH server, e.g.
//   docker run -d --rm --name xell-sshtest -p 127.0.0.1:2222:2222 \
//     -e PASSWORD_ACCESS=true -e USER_NAME=xell -e USER_PASSWORD=xelltest \
//     lscr.io/linuxserver/openssh-server:latest
//   XELL_SSH_TEST_PORT=2222 flutter test test/features/terminal/services/ssh_service_host_key_integration_test.dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:xell/core/exceptions.dart';
import 'package:xell/features/hosts/models/ssh_host.dart';
import 'package:xell/features/hosts/services/host_key_verifier.dart';
import 'package:xell/features/terminal/services/ssh_service.dart';

class _MemStore implements KnownHostsStore {
  final map = <String, String>{};
  @override
  Future<String?> fingerprintFor(String hostPort) async => map[hostPort];
  @override
  Future<void> save(String hostPort, String fingerprint) async =>
      map[hostPort] = fingerprint;
}

void main() {
  final port = int.tryParse(Platform.environment['XELL_SSH_TEST_PORT'] ?? '');
  final skip = port == null ? 'set XELL_SSH_TEST_PORT to run' : null;

  final host = SshHost(
    id: 'it',
    name: 'it',
    hostname: '127.0.0.1',
    port: port ?? 2222,
    username: Platform.environment['XELL_SSH_TEST_USER'] ?? 'xell',
    authType: AuthType.password,
  );
  final password = Platform.environment['XELL_SSH_TEST_PASSWORD'] ?? 'xelltest';

  test('TOFU: prompt once, then silent; changed key prompts with previous; reject aborts', () async {
    final store = _MemStore();
    final service = SshService(hostKeys: HostKeyVerifier(store));
    final asked = <HostKeyCheck>[];

    // 1. First connection: unknown → approve → stored.
    var client = await service.connect(
      host: host,
      password: password,
      approveHostKey: (c) async {
        asked.add(c);
        return true;
      },
    );
    await service.disconnect(client);
    expect(asked.single.status, HostKeyStatus.unknown);
    expect(asked.single.fingerprint, startsWith('SHA256:'));
    final key = HostKeyVerifier.keyFor(host.hostname, host.port);
    expect(store.map[key], asked.single.fingerprint);

    // 2. Second connection: trusted → no prompt.
    asked.clear();
    client = await service.connect(
      host: host,
      password: password,
      approveHostKey: (c) async {
        asked.add(c);
        return true;
      },
    );
    await service.disconnect(client);
    expect(asked, isEmpty);

    // 3. Key "changed" (simulate by storing another fingerprint) → reject → abort.
    final real = store.map[key]!;
    store.map[key] = 'SHA256:somethingElse';
    await expectLater(
      service.connect(
        host: host,
        password: password,
        approveHostKey: (c) async {
          asked.add(c);
          return false;
        },
      ),
      throwsA(isA<SshException>()
          .having((e) => e.message, 'message', contains('host key was not trusted'))),
    );
    expect(asked.single.status, HostKeyStatus.changed);
    expect(asked.single.previous, 'SHA256:somethingElse');
    expect(asked.single.fingerprint, real);
    expect(store.map[key], 'SHA256:somethingElse', reason: 'rejected key not saved');
  }, skip: skip, timeout: const Timeout(Duration(seconds: 60)));
}
