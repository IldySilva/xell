import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/host_key_verifier.dart';

/// Host key fingerprints are public data (not secrets), so they live in
/// shared_preferences rather than the keychain.
class KnownHostsStorage implements KnownHostsStore {
  static const _key = 'xell.knownHosts';

  Future<Map<String, String>> _all() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return {};
    return (jsonDecode(raw) as Map<String, dynamic>).cast<String, String>();
  }

  @override
  Future<String?> fingerprintFor(String hostPort) async =>
      (await _all())[hostPort];

  @override
  Future<void> save(String hostPort, String fingerprint) async {
    final all = await _all();
    all[hostPort] = fingerprint;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(all));
  }
}
