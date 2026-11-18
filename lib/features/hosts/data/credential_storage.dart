import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class CredentialStorage {
  // usesDataProtectionKeychain: false keeps ad-hoc signed (no Apple Developer
  // account) builds working; the data-protection keychain needs a real
  // signature and fails with -34018 otherwise.
  static const _mOpts = MacOsOptions(
    accessibility: KeychainAccessibility.unlocked,
    usesDataProtectionKeychain: false,
  );

  // migrateOnAlgorithmChange moves v9-era ciphertext to the new ciphers.
  // resetOnError is disabled: by default a single decrypt failure wipes
  // *every* stored credential. We would rather fail one read and re-prompt.
  static final _aOpts = AndroidOptions(
    migrateOnAlgorithmChange: true,
    resetOnError: false,
  );

  static final _storage = FlutterSecureStorage(
    mOptions: _mOpts,
    aOptions: _aOpts,
  );

  static String _passwordKey(String hostId) =>
      'xell.host.$hostId.password';

  static String _passphraseKey(String hostId) =>
      'xell.host.$hostId.passphrase';

  /// Returns null when the secret is missing or cannot be decrypted; callers
  /// then prompt the user, which is the right recovery in both cases.
  Future<String?> _read(String key) async {
    try {
      return await _storage.read(key: key, mOptions: _mOpts);
    } catch (e) {
      debugPrint('CredentialStorage: could not read $key: $e');
      return null;
    }
  }

  Future<String?> loadPassword(String hostId) => _read(_passwordKey(hostId));

  Future<void> savePassword(String hostId, String password) =>
      _storage.write(
        key: _passwordKey(hostId),
        value: password,
        mOptions: _mOpts,
      );

  Future<String?> loadPassphrase(String hostId) =>
      _read(_passphraseKey(hostId));

  Future<void> savePassphrase(String hostId, String passphrase) =>
      _storage.write(
        key: _passphraseKey(hostId),
        value: passphrase,
        mOptions: _mOpts,
      );

  Future<void> deleteCredentials(String hostId) async {
    await _storage.delete(key: _passwordKey(hostId), mOptions: _mOpts);
    await _storage.delete(key: _passphraseKey(hostId), mOptions: _mOpts);
  }
}
