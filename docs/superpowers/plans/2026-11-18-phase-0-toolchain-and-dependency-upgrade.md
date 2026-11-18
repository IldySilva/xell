# Phase 0 — Toolchain + Dependency Upgrade Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move Xell to Flutter 3.50 / Dart 3.14 and current package majors without losing any user data, and close the host-key verification gap that the upgrade exposes.

**Architecture:** Upgrade one package family per task, with `flutter analyze` + `flutter test` + a manual smoke test after each, so a regression points to a single commit. The SDK constraint and CI pin move first. Packages follow in order of risk (lowest first), except where a package needs a staged migration (flutter_secure_storage).

**Tech Stack:** Flutter 3.50.0 (stable, 2026-11-09), Dart 3.14.0.

**Must land before Phase 1.** Phase 1 code is written against the upgraded `dartssh2`.

---

## Execution notes (2026-11-18, branch `chore/toolchain-upgrade`)

Phase 0 is done. Where reality differed from the plan:

- **Material moved out of the SDK.** Flutter 3.47+ deprecates `package:flutter/material.dart`; migrated with `dart fix --apply --code=migrate_design_widgets` to `material_ui ^1.11.1` (Task 1).
- **Dependency coupling.** `file_picker 13` requires `flutter_secure_storage >= 10` (shared `win32`), so Task 6 landed together with Task 3. `desktop_drop 0.9` needs `cross_file 0.4`, incompatible with `file_picker 13` → `desktop_drop 0.8.4`.
- **window_manager 0.7 is a rewrite** on nativeapi. Migrated to the native `Window` API. On macOS `TitleBarStyle.hidden` also removes the traffic lights, so the macOS title bar stays with `macos_window_utils` (`enableFullSizeContentView` + `hideTitle`). Removed the obsolete `hiddenWindowAtLaunch()` hook. Linux CI needs `libx11-dev libxi-dev`.
- **flutter_secure_storage 10** defaults `resetOnError: true` on Android, which wipes all credentials on one decrypt failure; disabled it and made reads fail soft (re-prompt).
- **Host key verification:** dartssh2 reports a rejected key as `SSHAuthAbortError`; `SshService` tracks the rejection to show the real reason. Verified end-to-end against OpenSSH 10.3 in Docker (`test/features/terminal/services/ssh_service_host_key_integration_test.dart`, opt-in via `XELL_SSH_TEST_PORT`).
- **Platform migrations by Flutter 3.50:** macOS minimum 12.0, iOS minimum 15.0, plugins via SwiftPM. Android: Gradle 9.5, AGP 9.3.1, Kotlin 2.4.20; `builtInKotlin`/`newDsl` stay `false` because plugins still apply `kotlin-android`.
- **Pre-existing bug fixed:** the iOS `AppIcon` set had only mac entries; current Xcode rejects that.

## Current → target

| Package | Current | Target in this phase | Notes |
|---|---|---|---|
| Dart SDK constraint | `^3.11.4` | `^3.14.0` | Local toolchain is already 3.14.0 |
| `dartssh2` | 2.17.1 | **4.1.0** | `close()` → `Future`; `identities` → `List<SSHIdentity>`; SHA-1 kex, `ssh-rsa` host-key sigs and CBC removed from defaults; host-key fingerprint is now `SHA256:<b64>` |
| `flutter_secure_storage` | 9.2.4 | **10.x (latest 10)** | **Not 11 yet.** 11 removes the v9 Android ciphers, so data saved by v9 becomes unreadable unless it was first migrated by v10. Ship 10 in v0.2.0 and move to 11 in v0.3.0 |
| `window_manager` | 0.4.3 | 0.7.0 | Desktop only |
| `file_picker` | 8.3.7 | 13.4.0 | Five majors; API used only by key-file picking and SFTP upload |
| `desktop_drop` | 0.7.1 | 0.9.2 | If 0.9 is blocked by a transitive constraint, take 0.8.4 (resolvable today) |
| `cupertino_icons` | 1.0.9 | 2.0.0 | |
| `shared_preferences`, `url_launcher` | minor | latest | |
| `xterm` | 4.0.0 | 4.0.0 | Already latest |

Files that touch `dartssh2` (all need review in Task 4):
`lib/features/terminal/services/ssh_service.dart`, `lib/features/terminal/models/terminal_session.dart`, `lib/features/terminal/controllers/terminal_controller.dart`, `lib/features/sftp/services/sftp_service.dart`, `lib/features/sftp/controllers/sftp_controller.dart`, `lib/features/remote_editor/controllers/remote_editor_controller.dart`, `lib/features/port_forwarding/services/tunnel_service.dart`, `lib/features/port_forwarding/controllers/tunnel_controller.dart`.

## Smoke test (referenced by every task as "run the smoke test")

Run on macOS (`flutter run -d macos`). For tasks marked *mobile*, also run on an Android emulator and the iOS simulator.

1. Launch, and the host list loads with existing hosts.
2. Connect with a **saved password** host, then with a **private key + passphrase** host.
3. Type `ls`, resize the window, run `vim` and quit, then close the tab.
4. SFTP: browse, upload a file via the picker and via drag-and-drop, download, rename, delete.
5. Open a remote file in the editor, edit it, save.
6. Create a local tunnel and `curl` it.
7. Settings: change the theme, restart the app, and confirm it persisted.

---

### Task 1: SDK constraint + CI pin

**Files:**
- Modify: `pubspec.yaml` (`environment.sdk`)
- Modify: `.github/workflows/ci.yml`, `.github/workflows/release.yml` (both `subosito/flutter-action` steps)

- [ ] **Step 1: Create the branch**

```bash
git checkout -b chore/toolchain-upgrade
```

- [ ] **Step 2: Bump the SDK constraint**

In `pubspec.yaml`:

```yaml
environment:
  sdk: ^3.14.0
```

- [ ] **Step 3: Pin Flutter in CI** so builds are reproducible. In every `subosito/flutter-action@v2` step (`ci.yml` line ~18, `release.yml` lines ~21 and ~101):

```yaml
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          flutter-version: 3.50.0
          cache: true
```

- [ ] **Step 4: Add tests to CI.** In `ci.yml`, after the `Analyze` step:

```yaml
      - name: Test
        run: flutter test
```

- [ ] **Step 5: Verify**

Run: `flutter pub get && flutter analyze && flutter test`
Expected: `No issues found!` and `All tests passed!`. If the new lints in Dart 3.14 report issues, fix them in this task. They are mechanical (for example `unnecessary_*`, `use_build_context_synchronously`).

- [ ] **Step 6: Commit**

```bash
git add pubspec.yaml pubspec.lock analysis_options.yaml .github/workflows/
git commit -m "chore: require Dart 3.14, pin Flutter 3.50.0 in CI, run tests in CI"
```

---

### Task 2: Low-risk minors

**Files:** `pubspec.yaml`, `pubspec.lock`

- [ ] **Step 1:** `flutter pub upgrade shared_preferences url_launcher`
- [ ] **Step 2:** In `pubspec.yaml` set `cupertino_icons: ^2.0.0`, then `flutter pub get`.
- [ ] **Step 3:** `flutter analyze && flutter test`. Expected: clean.
- [ ] **Step 4:** Run the smoke test, steps 1 and 7.
- [ ] **Step 5: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore(deps): bump shared_preferences, url_launcher, cupertino_icons"
```

---

### Task 3: Desktop packages — window_manager, desktop_drop, file_picker

**Files:** `pubspec.yaml`, `lib/main.dart`, `lib/core/window_preferences.dart`, and every file that `grep -rln "file_picker\|desktop_drop\|window_manager" lib` lists.

- [ ] **Step 1: Read the three changelogs first** (`https://pub.dev/packages/<name>/changelog`). Write down each breaking item that touches an API from the grep above.
- [ ] **Step 2:** Set `window_manager: ^0.7.0`, `desktop_drop: ^0.9.2`, `file_picker: ^13.4.0`, then `flutter pub get`. If resolution fails on `desktop_drop`, use `^0.8.4`.
- [ ] **Step 3:** `flutter analyze`. Fix each error at the call site using the notes from Step 1. Do not add wrappers or compatibility layers.
- [ ] **Step 4:** `cd macos && pod install --repo-update && cd ..`. Then `flutter build macos --debug` and `flutter build linux --debug` (Linux in CI or a VM).
- [ ] **Step 5:** Run the smoke test, steps 1, 3 (resize) and 4 (picker and drag-and-drop) on macOS. Also check that window size and position are restored on relaunch. *Mobile:* step 4 picker on Android and iOS.
- [ ] **Step 6: Commit**

```bash
git add -A pubspec.yaml pubspec.lock lib macos linux windows ios android
git commit -m "chore(deps): upgrade window_manager 0.7, desktop_drop, file_picker 13"
```

---

### Task 4: dartssh2 2.17 → 4.1

**Files:** the 8 dartssh2 files listed above, plus `test/features/terminal/services/ssh_service_test.dart` (new).

- [ ] **Step 1:** Set `dartssh2: ^4.1.0`, then run `flutter pub get && flutter analyze`.
- [ ] **Step 2: Fix `close()` now returning `Future<void>`.** In `ssh_service.dart`:

```dart
  Future<void> disconnect(SSHClient client) => client.close();
```

In `terminal_controller.dart`, `closeSession` and `dispose` (`session.client?.close();`), and in the SFTP and tunnel controllers, wrap fire-and-forget closes in `unawaited(...)` (from `dart:async`) where the caller is synchronous, and `await` them where the caller is already `async`:

```dart
    if (session.client != null) unawaited(session.client!.close());
```

Do the same for `SftpClient.close()` in `sftp_service.dart` / `sftp_controller.dart`.

- [ ] **Step 3: `identities`.** Passing `List<SSHKeyPair>` to the constructor still compiles in 4.x (`ssh_service.dart`, `identities: keyPairs`). Leave it. If analyze flags it, change it to `identities: [...keyPairs]` typed as `List<SSHIdentity>`.

- [ ] **Step 4: Handle the default-algorithm removal.** Old servers (CentOS 6, old network gear) that only offer `ssh-rsa`, SHA-1 key exchange or CBC will now fail to negotiate. Map that failure to a clear message instead of a raw exception. In `ssh_service.dart`'s `connect` catch-all, before `throw SshException('Connection failed: ...')`:

```dart
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('no matching') ||
          msg.contains('algorithm') ||
          msg.contains('negotiat')) {
        throw SshException(
          'The server only offers legacy algorithms (SHA-1 / ssh-rsa / CBC) '
          'that Xell disables by default for security.',
        );
      }
      throw SshException('Connection failed: ${e.toString()}');
    }
```

Before writing that test, confirm the exact error text by connecting to an `ssh-rsa`-only server, for example a Docker `linuxserver/openssh-server` with `HostKeyAlgorithms ssh-rsa` and `KexAlgorithms diffie-hellman-group14-sha1`. Adjust the `contains` checks to match. An opt-in "Allow legacy algorithms" host setting is **out of scope** here and goes on the backlog.

- [ ] **Step 5: SFTP attribute change.** `grep -rn "SftpFileAttrs(" lib`. If any call sets only `modifyTime` or only `accessTime`, set both (4.0 drops half-pairs):

```dart
SftpFileAttrs(accessTime: atime, modifyTime: mtime)
```

- [ ] **Step 6:** `flutter analyze && flutter test`. Expected: clean.
- [ ] **Step 7:** Run the **full** smoke test, *mobile* included.
- [ ] **Step 8: Commit**

```bash
git add -A pubspec.yaml pubspec.lock lib
git commit -m "chore(deps): upgrade dartssh2 to 4.1 (async close, legacy-algorithm error message)"
```

---

### Task 5: Host-key verification (TOFU) — security fix

Today `SSHClient` is created without `onVerifyHostKey`, so **any** host key is accepted and a man-in-the-middle cannot be detected. Add trust-on-first-use with a stored SHA-256 fingerprint, the same model as OpenSSH `known_hosts`.

**Files:**
- Create: `lib/features/hosts/data/known_hosts_storage.dart`
- Create: `lib/features/hosts/services/host_key_verifier.dart`
- Create: `lib/features/terminal/views/host_key_prompt_dialog.dart`
- Modify: `lib/features/terminal/services/ssh_service.dart` (`connect`)
- Modify: every caller of `SshService.connect` (`grep -rn "\.connect(" lib/features`) to pass the verifier
- Test: `test/features/hosts/services/host_key_verifier_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/features/hosts/services/host_key_verifier_test.dart
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
  setUp(() => store = _MemStore());

  test('unknown host → askFirstUse, nothing saved yet', () async {
    final v = HostKeyVerifier(store);
    expect(await v.check('h:22', 'SHA256:aaa'), HostKeyStatus.unknown);
    expect(store.map, isEmpty);
  });

  test('matching fingerprint → trusted', () async {
    store.map['h:22'] = 'SHA256:aaa';
    expect(await HostKeyVerifier(store).check('h:22', 'SHA256:aaa'),
        HostKeyStatus.trusted);
  });

  test('different fingerprint → changed', () async {
    store.map['h:22'] = 'SHA256:aaa';
    expect(await HostKeyVerifier(store).check('h:22', 'SHA256:bbb'),
        HostKeyStatus.changed);
  });

  test('trust() persists', () async {
    final v = HostKeyVerifier(store);
    await v.trust('h:22', 'SHA256:aaa');
    expect(store.map['h:22'], 'SHA256:aaa');
  });
}
```

- [ ] **Step 2: Run it.** `flutter test test/features/hosts/services/host_key_verifier_test.dart`. Expected: FAIL (`host_key_verifier.dart` not found).

- [ ] **Step 3: Implement**

```dart
// lib/features/hosts/services/host_key_verifier.dart
enum HostKeyStatus { trusted, unknown, changed }

abstract interface class KnownHostsStore {
  Future<String?> fingerprintFor(String hostPort);
  Future<void> save(String hostPort, String fingerprint);
}

class HostKeyVerifier {
  final KnownHostsStore _store;
  HostKeyVerifier(this._store);

  static String keyFor(String hostname, int port) => '$hostname:$port';

  Future<HostKeyStatus> check(String hostPort, String fingerprint) async {
    final known = await _store.fingerprintFor(hostPort);
    if (known == null) return HostKeyStatus.unknown;
    return known == fingerprint ? HostKeyStatus.trusted : HostKeyStatus.changed;
  }

  Future<void> trust(String hostPort, String fingerprint) =>
      _store.save(hostPort, fingerprint);
}
```

```dart
// lib/features/hosts/data/known_hosts_storage.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/host_key_verifier.dart';

/// Fingerprints are public data (not secrets), so shared_preferences is fine.
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
    final all = await _all()..[hostPort] = fingerprint;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(all));
  }
}
```

- [ ] **Step 4: Run the test.** Expected: PASS (4 tests).

- [ ] **Step 5: Wire into `SshService.connect`.** Add a parameter and pass `onVerifyHostKey` to **both** `SSHClient(...)` constructors:

```dart
  Future<SSHClient> connect({
    required SshHost host,
    String? password,
    String? passphrase,
    required Future<bool> Function(HostKeyStatus status, String fingerprint)
        approveHostKey,
  }) async {
    final verifier = HostKeyVerifier(KnownHostsStorage());
    final hostPort = HostKeyVerifier.keyFor(host.hostname, host.port);
```

```dart
            onVerifyHostKey: (type, fingerprint) async {
              final fp = fingerprint is String
                  ? fingerprint
                  : String.fromCharCodes(fingerprint);
              final status = await verifier.check(hostPort, fp);
              if (status == HostKeyStatus.trusted) return true;
              final ok = await approveHostKey(status, fp);
              if (ok) await verifier.trust(hostPort, fp);
              return ok;
            },
```

Check the exact `onVerifyHostKey` signature in `~/.pub-cache/hosted/pub.dev/dartssh2-4.1.0/lib/src/ssh_client.dart` (`grep -n "onVerifyHostKey" -A3`). Since 2.18 the fingerprint is the `SHA256:<base64>` string. If the typedef passes `Uint8List`, keep the `fromCharCodes` branch. Otherwise delete it.

- [ ] **Step 6: Prompt dialog.** `host_key_prompt_dialog.dart` returns `Future<bool>`:
  - `unknown`: title "Trust this server?", body shows `hostname:port` and the fingerprint in monospace, with the hint "Compare with `ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub` on the server." Buttons: **Cancel** / **Trust and connect**.
  - `changed`: title "⚠ Host key changed", red accent, body "This can mean someone is intercepting the connection, or the server was reinstalled." It shows the old and new fingerprints. Buttons: **Cancel** (default focus) / **Replace key and connect** (destructive style).
  - Use the existing `AppColors` / `AppSpacing`, matching `credential_prompt_dialog.dart` in the same folder.

  Thread `approveHostKey` from every `connect` caller (terminal, SFTP, remote editor, tunnels) as `(status, fp) => showHostKeyPromptDialog(context, host, status, fp)`.

- [ ] **Step 7:** `flutter analyze && flutter test`, then run the smoke test step 2. Expected: the first connect to each host prompts once and the second connect is silent. Edit the stored value in prefs (or connect to a re-provisioned Docker container on the same port) and confirm that the "changed" dialog appears.

- [ ] **Step 8: Commit**

```bash
git add -A lib test
git commit -m "feat(security): verify SSH host keys with trust-on-first-use"
```

---

### Task 6: flutter_secure_storage 9 → 10 (staged, data-preserving)

**Files:** `pubspec.yaml`, `lib/features/hosts/data/credential_storage.dart`, and any other `FlutterSecureStorage(` (`grep -rn "FlutterSecureStorage(" lib`).

- [ ] **Step 1: Prepare migration data.** On an Android emulator and on macOS, using the **current** build, save a password host and a passphrase host. Do not wipe these devices until Step 6.
- [ ] **Step 2:** Set `flutter_secure_storage: ^10.0.0` (resolve to the newest 10.x), then `flutter pub get`.
- [ ] **Step 3: Keep the macOS dev-signing fix.** The `useDataProtectionKeyChain: false` behaviour must be kept; it avoids error -34018 on ad-hoc signed builds. Since 10.3 the flag is only sent when explicitly enabled, so keep passing `false` explicitly. Add Android migration:

```dart
  static const _mOpts = MacOsOptions(
    accessibility: KeychainAccessibility.unlocked,
    useDataProtectionKeyChain: false,
  );

  static const _aOpts = AndroidOptions(migrateOnAlgorithmChange: true);

  static const _storage =
      FlutterSecureStorage(mOptions: _mOpts, aOptions: _aOpts);
```

Keep the per-call `mOptions: _mOpts` arguments (rename from `_opts`). If analyze reports that `AndroidOptions` has no `migrateOnAlgorithmChange` in the resolved 10.x, read that version's README "Migration" section and use the documented equivalent. Do not upgrade to 11 to get it.

- [ ] **Step 4:** `flutter analyze && flutter test`.
- [ ] **Step 5:** `cd macos && pod install && cd ..`, then `cd ios && pod install && cd ..`.
- [ ] **Step 6: Verify migration.** Install the new build **over** the old one on the Android emulator and on macOS. Without retyping anything, connect to both hosts from Step 1. Expected: no password prompt. Then run the full smoke test, *mobile* included.
- [ ] **Step 7: Commit**

```bash
git add -A pubspec.yaml pubspec.lock lib macos ios
git commit -m "chore(deps): flutter_secure_storage 10 with Android cipher migration"
```

- [ ] **Step 8: Backlog note.** Add to `product.spec.md` under post-MVP: "Upgrade flutter_secure_storage to 11 one release after 10 has shipped (users must have run v10 once so their data is migrated)."

---

### Task 7: Final verification + PR

- [ ] `flutter pub outdated`. Expected: the only remaining major gap is `flutter_secure_storage` (deliberate).
- [ ] `flutter analyze && flutter test`. Clean.
- [ ] Release-mode builds: `flutter build macos`, `flutter build apk --debug`, and `flutter build ios --no-codesign --debug`.
- [ ] Push and open a PR (`gh pr create`) titled **"chore: Flutter 3.50 / Dart 3.14, dependency upgrades, host-key verification"**. List the dependency table above and call out the two user-visible changes: the host-key prompt on first connect, and the legacy-algorithm error message.
