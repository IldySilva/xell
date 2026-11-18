import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:xell/features/hosts/services/host_key_verifier.dart';

class _MemStore implements KnownHostsStore {
  final map = <String, String>{};
  @override
  Future<String?> fingerprintFor(String hostPort) async => map[hostPort];
  @override
  Future<void> save(String hostPort, String fingerprint) async =>
      map[hostPort] = fingerprint;
}

void main() {
  late _MemStore store;
  late HostKeyVerifier v;
  setUp(() {
    store = _MemStore();
    v = HostKeyVerifier(store);
  });

  test('keyFor brackets non-default ports like OpenSSH', () {
    expect(HostKeyVerifier.keyFor('web', 22), 'web');
    expect(HostKeyVerifier.keyFor('web', 2222), '[web]:2222');
  });

  test('unknown host → unknown, nothing saved', () async {
    final c = await v.check('h', 'SHA256:aaa');
    expect(c.status, HostKeyStatus.unknown);
    expect(c.previous, isNull);
    expect(store.map, isEmpty);
  });

  test('matching fingerprint → trusted', () async {
    store.map['h'] = 'SHA256:aaa';
    expect((await v.check('h', 'SHA256:aaa')).status, HostKeyStatus.trusted);
  });

  test('different fingerprint → changed, with the previous one', () async {
    store.map['h'] = 'SHA256:aaa';
    final c = await v.check('h', 'SHA256:bbb');
    expect(c.status, HostKeyStatus.changed);
    expect(c.previous, 'SHA256:aaa');
    expect(c.fingerprint, 'SHA256:bbb');
  });

  test('trust() persists', () async {
    await v.trust('h', 'SHA256:aaa');
    expect(store.map['h'], 'SHA256:aaa');
  });

  test('fingerprintToString decodes dartssh2 byte fingerprints', () {
    final bytes = Uint8List.fromList(ascii.encode('SHA256:abc+/='));
    expect(HostKeyVerifier.fingerprintToString(bytes), 'SHA256:abc+/=');
  });

  group('verify (the onVerifyHostKey flow)', () {
    test('trusted host → true without asking', () async {
      store.map['h'] = 'SHA256:aaa';
      var asked = false;
      final ok = await v.verify('h', 'SHA256:aaa', (_) async {
        asked = true;
        return false;
      });
      expect(ok, isTrue);
      expect(asked, isFalse);
    });

    test('approved unknown host → saved', () async {
      final ok = await v.verify('h', 'SHA256:new', (_) async => true);
      expect(ok, isTrue);
      expect(store.map['h'], 'SHA256:new');
    });

    test('rejected changed host → false, old key kept', () async {
      store.map['h'] = 'SHA256:old';
      final ok = await v.verify('h', 'SHA256:evil', (_) async => false);
      expect(ok, isFalse);
      expect(store.map['h'], 'SHA256:old');
    });
  });
}
