import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dartssh2/dartssh2.dart';
import '../../../core/exceptions.dart';
import '../../hosts/data/known_hosts_storage.dart';
import '../../hosts/models/os_type.dart';
import '../../hosts/models/ssh_host.dart';
import '../../hosts/services/host_key_verifier.dart';

class SshService {
  final HostKeyVerifier _hostKeys;

  SshService({HostKeyVerifier? hostKeys})
      : _hostKeys = hostKeys ?? HostKeyVerifier(KnownHostsStorage());

  /// [approveHostKey] is asked when the server's key is unknown or changed.
  /// Rejecting it aborts the connection before any credential is sent.
  Future<SSHClient> connect({
    required SshHost host,
    required HostKeyApprover approveHostKey,
    String? password,
    String? passphrase,
  }) async {
    final SSHSocket socket;
    final hostPort = HostKeyVerifier.keyFor(host.hostname, host.port);
    // dartssh2 reports a rejected host key as a generic auth abort, so
    // remember the rejection to give the user the real reason.
    var hostKeyRejected = false;
    Future<bool> verifyHostKey(String type, List<int> fingerprint) async {
      final ok = await _hostKeys.verify(
        hostPort,
        HostKeyVerifier.fingerprintToString(fingerprint),
        approveHostKey,
      );
      if (!ok) hostKeyRejected = true;
      return ok;
    }
    const hostKeyRejectedMessage =
        'The server\'s host key was not trusted. Connection cancelled.';

    try {
      socket = await SSHSocket.connect(
        host.hostname,
        host.port,
        timeout: const Duration(seconds: 10),
      );
    } on SocketException {
      throw SshException(
        'Could not connect to ${host.hostname}:${host.port}. '
        'Check the hostname, port, and network connection.',
      );
    } on TimeoutException {
      throw SshException('Connection to ${host.hostname} timed out.');
    }

    try {
      final SSHClient client;

      switch (host.authType) {
        case AuthType.password:
          client = SSHClient(
            socket,
            username: host.username,
            onVerifyHostKey: verifyHostKey,
            onPasswordRequest: () => password ?? '',
          );

        case AuthType.privateKey:
          if (host.privateKeyPath == null) {
            throw SshException('No private key path configured for this host.');
          }
          final String keyContent;
          try {
            keyContent = await File(host.privateKeyPath!).readAsString();
          } on FileSystemException {
            throw SshException(
              'Could not read private key at "${host.privateKeyPath}". '
              'Check that the file exists and is readable.',
            );
          }
          final List<SSHKeyPair> keyPairs;
          try {
            keyPairs = SSHKeyPair.fromPem(keyContent, passphrase);
          } catch (_) {
            throw SshException(
              'Could not parse private key. '
              'If the key is encrypted, check your passphrase.',
            );
          }
          client = SSHClient(
            socket,
            username: host.username,
            onVerifyHostKey: verifyHostKey,
            identities: keyPairs,
          );

        case AuthType.sshAgent:
          socket.close();
          throw SshException('SSH Agent auth is not yet supported.');
      }

      await client.authenticated;
      return client;
    } on SshException {
      rethrow;
    } on SSHAuthFailError {
      throw SshException('Authentication failed. Check your credentials.');
    } on SSHAuthAbortError {
      if (hostKeyRejected) throw const SshException(hostKeyRejectedMessage);
      throw SshException('Authentication was aborted by the server.');
    } on SSHHostkeyError {
      throw const SshException(hostKeyRejectedMessage);
    } on SSHKeyDecryptError {
      throw SshException(
        'Could not decrypt the private key. Check your passphrase.',
      );
    } catch (e) {
      if (isLegacyAlgorithmError(e)) {
        throw SshException(
          'The server only offers legacy algorithms (SHA-1 key exchange, '
          'ssh-rsa host keys or CBC ciphers), which Xell disables by default '
          'for security. Update the server\'s SSH configuration.',
        );
      }
      throw SshException('Connection failed: ${e.toString()}');
    }
  }

  /// dartssh2 4.x removed weak algorithms from its defaults; when the server
  /// offers nothing else, negotiation fails with "No matching ... algorithm".
  static bool isLegacyAlgorithmError(Object e) =>
      e.toString().contains('No matching');

  Future<SSHSession> openShell(
    SSHClient client, {
    int width = 80,
    int height = 24,
  }) async {
    return client.shell(
      pty: SSHPtyConfig(width: width, height: height),
    );
  }

  Future<void> disconnect(SSHClient client) => client.close();

  Future<OsType> detectOs(SSHClient client) async {
    try {
      final uname = await _exec(client, 'uname -s');
      final distroId = uname.trim().toLowerCase() == 'linux'
          ? await _exec(client, "grep '^ID=' /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '\"'")
          : null;
      return OsType.fromUname(uname, distroId);
    } catch (_) {
      return OsType.unknown;
    }
  }

  Future<String> _exec(SSHClient client, String command) async {
    final session = await client.execute(command);
    final buf = StringBuffer();
    await for (final chunk in session.stdout) {
      buf.write(utf8.decode(chunk, allowMalformed: true));
    }
    return buf.toString().trim();
  }
}
