import 'dart:convert';

/// Trust-on-first-use host key verification, the same model as OpenSSH's
/// known_hosts: remember a server's key fingerprint the first time the user
/// approves it, and warn loudly if it ever changes.
enum HostKeyStatus { trusted, unknown, changed }

class HostKeyCheck {
  final HostKeyStatus status;
  final String hostPort;
  final String fingerprint;

  /// The stored fingerprint when [status] is [HostKeyStatus.changed].
  final String? previous;

  const HostKeyCheck({
    required this.status,
    required this.hostPort,
    required this.fingerprint,
    this.previous,
  });
}

/// Asks the user whether to trust an unknown or changed key.
typedef HostKeyApprover = Future<bool> Function(HostKeyCheck check);

abstract interface class KnownHostsStore {
  Future<String?> fingerprintFor(String hostPort);
  Future<void> save(String hostPort, String fingerprint);
}

class HostKeyVerifier {
  final KnownHostsStore _store;
  HostKeyVerifier(this._store);

  /// Same key format as OpenSSH known_hosts: `host`, or `[host]:port`.
  static String keyFor(String hostname, int port) =>
      port == 22 ? hostname : '[$hostname]:$port';

  /// dartssh2 passes the `SHA256:<base64>` fingerprint as ASCII bytes.
  static String fingerprintToString(List<int> fingerprint) =>
      ascii.decode(fingerprint, allowInvalid: true);

  Future<HostKeyCheck> check(String hostPort, String fingerprint) async {
    final known = await _store.fingerprintFor(hostPort);
    final status = known == null
        ? HostKeyStatus.unknown
        : known == fingerprint
            ? HostKeyStatus.trusted
            : HostKeyStatus.changed;
    return HostKeyCheck(
      status: status,
      hostPort: hostPort,
      fingerprint: fingerprint,
      previous: status == HostKeyStatus.changed ? known : null,
    );
  }

  Future<void> trust(String hostPort, String fingerprint) =>
      _store.save(hostPort, fingerprint);

  /// Full flow for dartssh2's `onVerifyHostKey`: trusted keys pass silently;
  /// anything else needs [approve], and an approved key is remembered.
  Future<bool> verify(
    String hostPort,
    String fingerprint,
    HostKeyApprover approve,
  ) async {
    final result = await check(hostPort, fingerprint);
    if (result.status == HostKeyStatus.trusted) return true;
    final ok = await approve(result);
    if (ok) await trust(hostPort, fingerprint);
    return ok;
  }
}
