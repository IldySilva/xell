# Phase 1 — Shell Integration + Command Blocks Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Prerequisite:** Phase 0 (`2026-11-18-phase-0-toolchain-and-dependency-upgrade.md`) is merged.

**Goal:** Turn every command typed in an Xell SSH tab into a structured `CommandBlock` (command, cwd, output range, exit code, duration). Use the blocks for right-click block actions, a tab status indicator, "finished while away" notices and accurate history — without adding visible chrome.

**Architecture:** After the first prompt appears on a bash/zsh host, Xell types one leading-space line that `eval`s a base64-encoded hook script. Nothing is written to the server's disk. An `OutputGate` hides the echo of that line until the script prints a ready marker. If the marker never arrives, the gate releases everything it held, so the user sees exactly what was typed. The hooks emit OSC 133 (A prompt / B input / C executed / D finished;exit), OSC 7 (cwd) and a private `OSC 6973;cmd;<base64>` (exact command line). xterm.dart passes unknown OSCs to `Terminal.onPrivateOSC`. `parseShellOsc` turns them into `ShellEvent`s, and `CommandBlockTracker` builds blocks anchored to buffer lines with xterm `CellAnchor`s, so blocks stay correct as scrollback scrolls and trims.

**Tech Stack:** Dart 3.14, Flutter 3.50, xterm 4.0.0 (`onPrivateOSC`, `CellAnchor`, `BufferRangeLine`, `Buffer.getText`), dartssh2 4.1, `fake_async` (comes with `flutter_test`; added explicitly as a dev dependency).

**Out of scope (later phases):** ghost-text suggestions, risk guard, gutter rendering, block navigation, AI.

---

## File structure

```
lib/features/terminal/shell_integration/
  shell_event.dart              ShellEvent types + parseShellOsc()            (pure Dart)
  shell_bootstrap.dart          hook script + injection line + shell support  (pure Dart)
  output_gate.dart              hides injection echo until ready marker       (pure Dart)
  command_block.dart            CommandBlock, BlockState, LineRef             (pure Dart)
  command_block_tracker.dart    ShellEvent stream → blocks                    (pure Dart + ValueNotifier)
  xterm_blocks.dart             LineRef over CellAnchor; block text helpers   (xterm)
  integration_runner.dart       timing: wait for prompt → inject → ready/timeout, input queue
lib/features/terminal/models/captured_command.dart   what history receives

test/features/terminal/shell_integration/
  shell_event_test.dart
  shell_bootstrap_test.dart
  output_gate_test.dart
  command_block_tracker_test.dart
  xterm_blocks_test.dart        (real xterm Terminal — end-to-end of parser+tracker+buffer)
  integration_runner_test.dart  (fake_async)
test/features/terminal/models/command_history_entry_test.dart
```

Modified: `terminal_session.dart`, `ssh_service.dart`, `terminal_controller.dart`, `terminal_widget.dart`, `terminal_page.dart`, `terminal_tab_bar.dart`, `command_history_entry.dart`, `command_history_controller.dart`, `app_shell.dart`, `snippet_form_dialog.dart`, `settings_storage.dart`, `settings_controller.dart`, `settings_page.dart`, `pubspec.yaml`, `README.md`. New doc: `docs/shell-integration.md`.

---

### Task 1: Branch + test dependency

- [ ] **Step 1:**

```bash
git checkout master && git pull
git checkout -b feat/shell-integration-blocks
```

- [ ] **Step 2:** In `pubspec.yaml` under `dev_dependencies`, add:

```yaml
  fake_async: ^1.3.3
```

Run: `flutter pub get`. Expected: success.

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore: add fake_async for timer tests"
```

---

### Task 2: ShellEvent + OSC parser

**Files:**
- Create: `lib/features/terminal/shell_integration/shell_event.dart`
- Test: `test/features/terminal/shell_integration/shell_event_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/features/terminal/shell_integration/shell_event_test.dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:xell/features/terminal/shell_integration/shell_event.dart';

void main() {
  group('OSC 133', () {
    test('A/B/C', () {
      expect(parseShellOsc('133', ['A']), isA<PromptStarted>());
      expect(parseShellOsc('133', ['B']), isA<InputStarted>());
      expect(parseShellOsc('133', ['C']), isA<CommandExecuted>());
    });

    test('D with exit code', () {
      final e = parseShellOsc('133', ['D', '127']);
      expect(e, isA<CommandFinished>().having((e) => e.exitCode, 'exitCode', 127));
    });

    test('D without exit code', () {
      final e = parseShellOsc('133', ['D']);
      expect(e, isA<CommandFinished>().having((e) => e.exitCode, 'exitCode', isNull));
    });

    test('unknown subcommand / empty → null', () {
      expect(parseShellOsc('133', ['Z']), isNull);
      expect(parseShellOsc('133', []), isNull);
    });
  });

  group('OSC 7 cwd', () {
    test('plain path', () {
      final e = parseShellOsc('7', ['file://web-1/var/www']);
      expect(e, isA<CwdChanged>().having((e) => e.path, 'path', '/var/www'));
    });

    test('path with spaces and percent-encoding', () {
      expect((parseShellOsc('7', ['file://h/home/u/My Docs']) as CwdChanged).path,
          '/home/u/My Docs');
      expect((parseShellOsc('7', ['file://h/a%20b']) as CwdChanged).path, '/a b');
    });

    test('path containing ";" was split by the parser → rejoined', () {
      expect((parseShellOsc('7', ['file://h/a', 'b']) as CwdChanged).path, '/a;b');
    });

    test('empty host', () {
      expect((parseShellOsc('7', ['file:///tmp']) as CwdChanged).path, '/tmp');
    });

    test('non-file uri → null', () {
      expect(parseShellOsc('7', ['http://x/y']), isNull);
    });
  });

  group('OSC 6973 (xell private)', () {
    test('ready', () {
      expect(parseShellOsc('6973', ['ready']), isA<IntegrationReady>());
    });

    test('cmd is base64 utf8', () {
      final b64 = base64.encode(utf8.encode('echo "olá; mundo" | grep -v x'));
      final e = parseShellOsc('6973', ['cmd', b64]);
      expect(e, isA<CommandLineReported>()
          .having((e) => e.command, 'command', 'echo "olá; mundo" | grep -v x'));
    });

    test('cmd with bad base64 → null', () {
      expect(parseShellOsc('6973', ['cmd', '!!!']), isNull);
    });
  });

  test('unrelated OSC → null', () {
    expect(parseShellOsc('1337', ['SetMark']), isNull);
  });
}
```

- [ ] **Step 2: Run it.** `flutter test test/features/terminal/shell_integration/shell_event_test.dart`. Expected: FAIL (`shell_event.dart` not found).

- [ ] **Step 3: Implement**

```dart
// lib/features/terminal/shell_integration/shell_event.dart
import 'dart:convert';

/// Events emitted by Xell's shell hooks (see shell_bootstrap.dart).
sealed class ShellEvent {
  const ShellEvent();
}

/// OSC 133;A — the shell is about to draw the prompt.
final class PromptStarted extends ShellEvent {
  const PromptStarted();
}

/// OSC 133;B — prompt drawn; user input starts at the cursor.
final class InputStarted extends ShellEvent {
  const InputStarted();
}

/// OSC 133;C — the command was accepted and output starts at the cursor.
final class CommandExecuted extends ShellEvent {
  const CommandExecuted();
}

/// OSC 133;D[;exit] — the command finished.
final class CommandFinished extends ShellEvent {
  final int? exitCode;
  const CommandFinished(this.exitCode);
}

/// OSC 7 — working directory changed.
final class CwdChanged extends ShellEvent {
  final String path;
  const CwdChanged(this.path);
}

/// OSC 6973;cmd;<base64> — exact command line, reported before 133;C.
final class CommandLineReported extends ShellEvent {
  final String command;
  const CommandLineReported(this.command);
}

/// OSC 6973;ready — hooks installed.
final class IntegrationReady extends ShellEvent {
  const IntegrationReady();
}

/// Xell's private OSC number ("XE" → 0x58 0x45 → reads as 6973 on a phone pad).
const kXellOsc = '6973';

/// Converts an OSC delivered by xterm's `onPrivateOSC(code, args)` into a
/// [ShellEvent]. xterm splits the payload on ';', so [args] may need rejoining.
ShellEvent? parseShellOsc(String code, List<String> args) {
  switch (code) {
    case '133':
      if (args.isEmpty) return null;
      return switch (args[0]) {
        'A' => const PromptStarted(),
        'B' => const InputStarted(),
        'C' => const CommandExecuted(),
        'D' => CommandFinished(args.length > 1 ? int.tryParse(args[1]) : null),
        _ => null,
      };
    case '7':
      return _parseCwd(args.join(';'));
    case kXellOsc:
      if (args.isEmpty) return null;
      if (args[0] == 'ready') return const IntegrationReady();
      if (args[0] == 'cmd' && args.length > 1) {
        try {
          return CommandLineReported(utf8.decode(base64.decode(args[1])));
        } on FormatException {
          return null;
        }
      }
      return null;
  }
  return null;
}

CwdChanged? _parseCwd(String raw) {
  const prefix = 'file://';
  if (!raw.startsWith(prefix)) return null;
  final rest = raw.substring(prefix.length);
  final slash = rest.indexOf('/');
  if (slash < 0) return null;
  var path = rest.substring(slash);
  try {
    path = Uri.decodeComponent(path);
  } catch (_) {
    // Not percent-encoded (shells print $PWD raw) — keep as-is.
  }
  return CwdChanged(path);
}
```

- [ ] **Step 4: Run the test.** Expected: PASS.
- [ ] **Step 5: Commit**

```bash
git add lib/features/terminal/shell_integration/shell_event.dart test/features/terminal/shell_integration/shell_event_test.dart
git commit -m "feat(terminal): parse OSC 133/7/6973 shell integration events"
```

---

### Task 3: Hook script + injection line

**Files:**
- Create: `lib/features/terminal/shell_integration/shell_bootstrap.dart`
- Test: `test/features/terminal/shell_integration/shell_bootstrap_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/features/terminal/shell_integration/shell_bootstrap_test.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:xell/features/terminal/shell_integration/shell_bootstrap.dart';

void main() {
  group('supports', () {
    test('bash and zsh by path or name', () {
      expect(ShellBootstrap.supports('/bin/bash'), isTrue);
      expect(ShellBootstrap.supports('/usr/bin/zsh\n'), isTrue);
      expect(ShellBootstrap.supports('zsh'), isTrue);
    });
    test('others are not supported', () {
      for (final s in ['/bin/sh', '/usr/bin/fish', '/bin/ash', '', 'cmd.exe']) {
        expect(ShellBootstrap.supports(s), isFalse, reason: s);
      }
    });
  });

  group('injectionLine', () {
    final line = ShellBootstrap.injectionLine();

    test('starts with a space (kept out of history) and ends with CR', () {
      expect(line.startsWith(' '), isTrue);
      expect(line.endsWith('\r'), isTrue);
    });

    test('is a single line', () {
      expect(line.substring(0, line.length - 1).contains(RegExp(r'[\r\n]')), isFalse);
    });

    test('does not contain the ready marker in clear text (echo must not trigger it)', () {
      expect(line.contains('6973;ready'), isFalse);
    });

    test('embeds the script as base64', () {
      final b64 = RegExp(r"'([A-Za-z0-9+/=]+)'").firstMatch(line)!.group(1)!;
      expect(utf8.decode(base64.decode(b64)), ShellBootstrap.script);
    });
  });

  group('script', () {
    test('emits every marker', () {
      const s = ShellBootstrap.script;
      for (final m in ['133;A', '133;B', '133;C', '133;D', ']7;file://', '6973;cmd', '6973;ready']) {
        expect(s.contains(m), isTrue, reason: m);
      }
    });

    test('ready marker is followed by clear-line so the gate output is clean', () {
      expect(ShellBootstrap.script.trimRight().endsWith(r"printf '\033]6973;ready\007\r\033[2K'"), isTrue);
    });

    for (final shell in ['bash', 'zsh']) {
      test('is valid $shell syntax', () async {
        final which = await Process.run('which', [shell]);
        if (which.exitCode != 0) {
          markTestSkipped('$shell not installed');
          return;
        }
        final f = File('${Directory.systemTemp.createTempSync().path}/xell_hooks.sh')
          ..writeAsStringSync(ShellBootstrap.script);
        final r = await Process.run(shell, ['-n', f.path]);
        expect(r.exitCode, 0, reason: '${r.stderr}');
      });
    }
  });
}
```

- [ ] **Step 2: Run it.** Expected: FAIL (file not found).

- [ ] **Step 3: Implement**

```dart
// lib/features/terminal/shell_integration/shell_bootstrap.dart
import 'dart:convert';

/// The hook script Xell evaluates in the remote interactive shell.
///
/// It lives only in shell memory for this session. Nothing is written to disk.
/// It is documented line by line in docs/shell-integration.md, and that doc
/// must be updated whenever this script changes.
class ShellBootstrap {
  static const _supported = {'bash', 'zsh'};

  /// [loginShell] is the output of `printf %s "$SHELL"` on the server.
  static bool supports(String loginShell) {
    final name = loginShell.trim().split('/').last;
    return _supported.contains(name);
  }

  static const script = r'''
if [ -z "$__xell_hooked" ]; then
__xell_hooked=1
__xell_b64() { printf %s "$1" | base64 | tr -d '\n'; }
__xell_emit_exec() { __xell_ran=1; printf '\033]6973;cmd;%s\007\033]133;C\007' "$(__xell_b64 "$1")"; }
__xell_emit_prompt() {
  if [ -n "$__xell_ran" ]; then printf '\033]133;D;%s\007' "$1"; fi
  __xell_ran=
  printf '\033]7;file://%s%s\007\033]133;A\007' "${HOSTNAME:-${HOST:-}}" "$PWD"
}
if [ -n "$ZSH_VERSION" ]; then
  __xell_precmd() {
    __xell_emit_prompt $?
    case "$PS1" in *'133;B'*) ;; *) PS1="$PS1%{$(printf '\033]133;B\007')%}" ;; esac
  }
  autoload -Uz add-zsh-hook
  add-zsh-hook precmd __xell_precmd
  add-zsh-hook preexec __xell_emit_exec
elif [ -n "$BASH_VERSION" ]; then
  __xell_precmd() { __xell_emit_prompt $?; }
  __xell_arm() {
    case "$PS1" in *'133;B'*) ;; *) PS1="$PS1\[\033]133;B\007\]" ;; esac
    __xell_armed=1
  }
  __xell_debug() {
    [ -n "$__xell_armed" ] || return 0
    case "$BASH_COMMAND" in __xell_*) return 0 ;; esac
    __xell_armed=
    # Plain bash has no reliable way to read the full command line here
    # (`history 1` is wrong for leading-space commands), so report it empty;
    # Xell then reads the command from the screen (commandFromScreen).
    __xell_emit_exec ""
  }
  if declare -p preexec_functions >/dev/null 2>&1; then
    precmd_functions=(__xell_precmd "${precmd_functions[@]}" __xell_arm)
    preexec_functions+=(__xell_emit_exec)
  elif [ -z "$(trap -p DEBUG)" ]; then
    trap '__xell_debug' DEBUG
    PROMPT_COMMAND="__xell_precmd${PROMPT_COMMAND:+;$PROMPT_COMMAND};__xell_arm"
  fi
fi
fi
printf '\033]6973;ready\007\r\033[2K'
''';

  /// One line typed into the shell. The leading space keeps it out of history
  /// where `HISTCONTROL=ignorespace` (bash) or `HIST_IGNORE_SPACE` (zsh) is set.
  /// It is base64-encoded so that its echo cannot contain the ready marker.
  static String injectionLine() {
    final b64 = base64.encode(utf8.encode(script));
    return " eval \"\$(printf %s '$b64' | base64 -d)\"\r";
  }
}
```

Notes the reviewer should check:
- bash: `__xell_precmd` is **first** in `PROMPT_COMMAND`, so `$?` is the user's exit code. `__xell_arm` is **last**, so the DEBUG trap ignores the other prompt commands (for example `history -a`, starship). The B marker is re-appended in `__xell_arm` / `__xell_precmd` because prompt frameworks (starship, p10k, oh-my-zsh themes) rebuild `PS1` every prompt.
- If the user already has a DEBUG trap and no bash-preexec, preexec is skipped. Blocks then never reach `C`, and the tracker drops them as "editing", which is a silent no-op.

- [ ] **Step 4: Run the test.** Expected: PASS (the syntax tests run when bash/zsh are present, as on macOS).
- [ ] **Step 5: Manual sanity check** (two minutes, catches hook-ordering bugs that unit tests cannot):

```bash
dart run - <<'EOF' > /tmp/xell_hooks.sh
import 'package:xell/features/terminal/shell_integration/shell_bootstrap.dart';
void main() => print(ShellBootstrap.script);
EOF
bash --norc -i -c 'source /tmp/xell_hooks.sh; true' 2>&1 | cat -v
```

If `dart run -` is unavailable, paste the script into `/tmp/xell_hooks.sh` by hand. Then run `bash --norc`, then `source /tmp/xell_hooks.sh`, then `ls; false`, and check with `cat -v` that you see `^[]133;C^G` before the output and `^[]133;D;1^G` after `false`. Repeat in `zsh -f`.

- [ ] **Step 6: Commit**

```bash
git add lib/features/terminal/shell_integration/shell_bootstrap.dart test/features/terminal/shell_integration/shell_bootstrap_test.dart
git commit -m "feat(terminal): in-memory bash/zsh shell integration hook script"
```

---

### Task 4: OutputGate

**Files:**
- Create: `lib/features/terminal/shell_integration/output_gate.dart`
- Test: `test/features/terminal/shell_integration/output_gate_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/features/terminal/shell_integration/output_gate_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:xell/features/terminal/shell_integration/output_gate.dart';

void main() {
  const marker = OutputGate.readyMarker;

  test('passes everything through when not holding', () {
    final g = OutputGate();
    expect(g.process('hello'), 'hello');
  });

  test('swallows until marker, then returns marker + rest', () {
    final g = OutputGate()..hold();
    expect(g.process(' eval "\$(printf ...)"\r\n'), '');
    expect(g.isHolding, isTrue);
    expect(g.process('${marker}\r\x1b[2Kuser@h:~\$ '), '$marker\r\x1b[2Kuser@h:~\$ ');
    expect(g.isHolding, isFalse);
    expect(g.process('next'), 'next');
  });

  test('marker split across chunks', () {
    final g = OutputGate()..hold();
    final cut = marker.length ~/ 2;
    expect(g.process('junk${marker.substring(0, cut)}'), '');
    expect(g.process('${marker.substring(cut)}tail'), '${marker}tail');
  });

  test('release returns held text and stops holding', () {
    final g = OutputGate()..hold();
    g.process('a');
    g.process('b');
    expect(g.release(), 'ab');
    expect(g.isHolding, isFalse);
    expect(g.process('c'), 'c');
  });
}
```

- [ ] **Step 2: Run it.** Expected: FAIL.
- [ ] **Step 3: Implement**

```dart
// lib/features/terminal/shell_integration/output_gate.dart

/// Hides remote output between injecting the hook line and the hooks'
/// ready marker, so the user never sees the injection echo.
class OutputGate {
  static const readyMarker = '\x1b]6973;ready\x07';

  final _held = StringBuffer();
  bool _holding = false;

  bool get isHolding => _holding;

  void hold() => _holding = true;

  /// Returns the text that should be written to the terminal now.
  /// When the marker arrives, the marker itself is passed on (xterm turns it
  /// into an [IntegrationReady] event) together with everything after it.
  String process(String chunk) {
    if (!_holding) return chunk;
    _held.write(chunk);
    final all = _held.toString();
    final i = all.indexOf(readyMarker);
    if (i < 0) return '';
    _holding = false;
    _held.clear();
    return all.substring(i);
  }

  /// Gives up waiting: returns everything held so it can be shown to the user.
  String release() {
    final s = _held.toString();
    _held.clear();
    _holding = false;
    return s;
  }
}
```

- [ ] **Step 4: Run the test.** Expected: PASS.
- [ ] **Step 5: Commit**

```bash
git add lib/features/terminal/shell_integration/output_gate.dart test/features/terminal/shell_integration/output_gate_test.dart
git commit -m "feat(terminal): output gate that hides shell-integration injection echo"
```

---

### Task 5: CommandBlock + CommandBlockTracker

**Files:**
- Create: `lib/features/terminal/shell_integration/command_block.dart`
- Create: `lib/features/terminal/shell_integration/command_block_tracker.dart`
- Test: `test/features/terminal/shell_integration/command_block_tracker_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/features/terminal/shell_integration/command_block_tracker_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:xell/features/terminal/shell_integration/command_block.dart';
import 'package:xell/features/terminal/shell_integration/command_block_tracker.dart';
import 'package:xell/features/terminal/shell_integration/shell_event.dart';

class FakeRef implements LineRef {
  @override
  final int x;
  @override
  final int y;
  @override
  bool attached = true;
  FakeRef(this.x, this.y);
}

void main() {
  late int cx, cy;
  late DateTime now;
  late List<FakeRef> refs;
  late CommandBlockTracker t;

  setUp(() {
    cx = 0;
    cy = 0;
    now = DateTime(2026, 1, 1, 12);
    refs = [];
    t = CommandBlockTracker(
      cursor: () {
        final r = FakeRef(cx, cy);
        refs.add(r);
        return r;
      },
      clock: () => now,
    );
  });

  void runCommand(String cmd, {int exit = 0, int lines = 1, Duration took = const Duration(seconds: 1)}) {
    t.handle(const PromptStarted());
    cx = 2;
    t.handle(const InputStarted());
    t.handle(CommandLineReported(cmd));
    cy += 1;
    cx = 0;
    t.handle(const CommandExecuted());
    cy += lines;
    now = now.add(took);
    t.handle(CommandFinished(exit));
  }

  test('ready flag', () {
    expect(t.isActive, isFalse);
    t.handle(const IntegrationReady());
    expect(t.isActive, isTrue);
  });

  test('full lifecycle produces a finished block', () {
    t.handle(const CwdChanged('/srv/app'));
    runCommand('ls -la', exit: 0, lines: 3, took: const Duration(milliseconds: 1500));
    final b = t.blocks.single;
    expect(b.command, 'ls -la');
    expect(b.cwd, '/srv/app');
    expect(b.state, BlockState.finished);
    expect(b.exitCode, 0);
    expect(b.failed, isFalse);
    expect(b.duration, const Duration(milliseconds: 1500));
    expect(b.promptLine.y, 0);
    expect(b.inputStart!.x, 2);
    expect(b.outputStart!.y, 1);
    expect(b.end!.y, 4);
  });

  test('non-zero exit marks failed', () {
    runCommand('false', exit: 1);
    expect(t.blocks.single.failed, isTrue);
  });

  test('empty Enter (A without C) does not leave an empty block', () {
    t.handle(const PromptStarted());
    t.handle(const InputStarted());
    cy++;
    t.handle(const PromptStarted());
    expect(t.blocks, hasLength(1));
    expect(t.blocks.single.state, BlockState.editing);
  });

  test('new prompt while running (no D) closes block with unknown exit', () {
    t.handle(const PromptStarted());
    t.handle(const CommandExecuted());
    cy += 2;
    t.handle(const PromptStarted());
    expect(t.blocks.first.state, BlockState.finished);
    expect(t.blocks.first.exitCode, isNull);
    expect(t.blocks.first.failed, isFalse);
  });

  test('onFinished emits each finished block once', () async {
    final got = <String>[];
    final sub = t.onFinished.listen((b) => got.add(b.command));
    runCommand('a');
    runCommand('b');
    await Future<void>.delayed(Duration.zero);
    expect(got, ['a', 'b']);
    await sub.cancel();
  });

  test('blockAtLine finds the block containing a buffer line', () {
    runCommand('one', lines: 3); // prompt y=0, output 1..3, end y=4
    runCommand('two', lines: 2); // prompt y=4
    expect(t.blockAtLine(0)!.command, 'one');
    expect(t.blockAtLine(3)!.command, 'one');
    expect(t.blockAtLine(5)!.command, 'two');
    expect(t.blockAtLine(-1), isNull);
  });

  test('detached blocks (prompt trimmed from scrollback) are pruned', () {
    runCommand('old');
    (t.blocks.single.promptLine as FakeRef).attached = false;
    runCommand('new');
    expect(t.blocks.map((b) => b.command).toList(), ['new']);
  });

  test('caps the number of blocks', () {
    final small = CommandBlockTracker(cursor: () => FakeRef(0, 0), maxBlocks: 3);
    for (var i = 0; i < 5; i++) {
      small.handle(const PromptStarted());
      small.handle(CommandLineReported('c$i'));
      small.handle(const CommandExecuted());
      small.handle(const CommandFinished(0));
    }
    expect(small.blocks.map((b) => b.command).toList(), ['c2', 'c3', 'c4']);
  });

  test('blocksNotifier notifies on changes', () {
    var n = 0;
    t.blocksNotifier.addListener(() => n++);
    runCommand('x');
    expect(n, greaterThan(0));
  });
}
```

- [ ] **Step 2: Run it.** Expected: FAIL (files missing).

- [ ] **Step 3: Implement the model**

```dart
// lib/features/terminal/shell_integration/command_block.dart

/// A position in the terminal buffer that follows scrolling.
/// Backed by xterm's CellAnchor in the app and by a fake in tests.
abstract interface class LineRef {
  int get x;
  int get y;

  /// False once the line has been trimmed from scrollback.
  bool get attached;
}

enum BlockState { editing, running, finished }

class CommandBlock {
  CommandBlock({required this.id, required this.promptLine, this.cwd});

  final int id;
  final LineRef promptLine;
  final String? cwd;

  LineRef? inputStart;
  LineRef? outputStart;
  LineRef? end;

  /// Exact command reported by the hooks. Empty if the hooks could not report
  /// it — use `commandOf()` in xterm_blocks.dart, which falls back to the screen.
  String command = '';

  BlockState state = BlockState.editing;
  int? exitCode;
  DateTime? startedAt;
  DateTime? finishedAt;

  bool get isRunning => state == BlockState.running;
  bool get failed =>
      state == BlockState.finished && exitCode != null && exitCode != 0;

  Duration? get duration => (startedAt != null && finishedAt != null)
      ? finishedAt!.difference(startedAt!)
      : null;
}
```

- [ ] **Step 4: Implement the tracker**

```dart
// lib/features/terminal/shell_integration/command_block_tracker.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'command_block.dart';
import 'shell_event.dart';

class CommandBlockTracker {
  CommandBlockTracker({
    required LineRef Function() cursor,
    DateTime Function()? clock,
    this.maxBlocks = 300,
  })  : _cursor = cursor,
        _clock = clock ?? DateTime.now;

  final LineRef Function() _cursor;
  final DateTime Function() _clock;
  final int maxBlocks;

  final blocksNotifier = ValueNotifier<List<CommandBlock>>(const []);
  final _finished = StreamController<CommandBlock>.broadcast();

  bool _ready = false;
  int _nextId = 0;
  String? cwd;

  /// True once the hooks reported ready on this session.
  bool get isActive => _ready;
  List<CommandBlock> get blocks => blocksNotifier.value;
  CommandBlock? get current => blocks.isEmpty ? null : blocks.last;
  Stream<CommandBlock> get onFinished => _finished.stream;

  void handle(ShellEvent e) {
    switch (e) {
      case IntegrationReady():
        _ready = true;
      case CwdChanged(:final path):
        cwd = path;
      case PromptStarted():
        _onPrompt();
      case InputStarted():
        final c = current;
        if (c != null && c.state == BlockState.editing) {
          c.inputStart = _cursor();
        }
      case CommandLineReported(:final command):
        final c = current;
        if (c != null && c.state == BlockState.editing) c.command = command;
      case CommandExecuted():
        final c = current;
        if (c != null && c.state == BlockState.editing) {
          c.state = BlockState.running;
          c.startedAt = _clock();
          c.outputStart = _cursor();
          _notify();
        }
      case CommandFinished(:final exitCode):
        final c = current;
        if (c != null && c.state == BlockState.running) {
          _finish(c, exitCode);
          _notify();
        }
    }
  }

  /// The block whose prompt starts at or above buffer line [y].
  CommandBlock? blockAtLine(int y) {
    for (final b in blocks.reversed) {
      if (b.promptLine.attached && b.promptLine.y <= y) return b;
    }
    return null;
  }

  void _onPrompt() {
    final list = [...blocks];
    final c = list.isEmpty ? null : list.last;
    if (c != null) {
      if (c.state == BlockState.editing) {
        list.removeLast(); // empty Enter / Ctrl-C at the prompt
      } else if (c.state == BlockState.running) {
        _finish(c, null); // shell skipped D (e.g. hooks lost mid-command)
      }
    }
    list.add(CommandBlock(id: _nextId++, promptLine: _cursor(), cwd: cwd));
    list.removeWhere((b) => !b.promptLine.attached);
    if (list.length > maxBlocks) list.removeRange(0, list.length - maxBlocks);
    blocksNotifier.value = list;
  }

  void _finish(CommandBlock b, int? exitCode) {
    b
      ..exitCode = exitCode
      ..finishedAt = _clock()
      ..end = _cursor()
      ..state = BlockState.finished;
    _finished.add(b);
  }

  void _notify() => blocksNotifier.value = [...blocks];

  void dispose() {
    _finished.close();
    blocksNotifier.dispose();
  }
}
```

Check against the tests: `'caps the number of blocks'` expects `['c2','c3','c4']`. After the 5th command the list holds 3 finished blocks, and no editing block is left because no prompt followed the last D. Each `PromptStarted` appends before the cap is applied: on the 5th prompt the list is [c1,c2,c3,new] → capped to [c2,c3,new], and new becomes c4. ✓. The `'detached blocks (prompt trimmed from scrollback) are pruned'` test ends with `['new']` for the same reason (no trailing prompt). ✓

- [ ] **Step 5: Run the test.** Expected: PASS.
- [ ] **Step 6: Commit**

```bash
git add lib/features/terminal/shell_integration/command_block*.dart test/features/terminal/shell_integration/command_block_tracker_test.dart
git commit -m "feat(terminal): command block model and tracker"
```

---

### Task 6: xterm binding + end-to-end buffer test

**Files:**
- Create: `lib/features/terminal/shell_integration/xterm_blocks.dart`
- Test: `test/features/terminal/shell_integration/xterm_blocks_test.dart`

- [ ] **Step 1: Write the failing test.** It uses a real `Terminal`, so it also proves that xterm delivers our OSCs through `onPrivateOSC` with the cursor in the right place.

```dart
// test/features/terminal/shell_integration/xterm_blocks_test.dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm/xterm.dart';
import 'package:xell/features/terminal/shell_integration/command_block_tracker.dart';
import 'package:xell/features/terminal/shell_integration/xterm_blocks.dart';

String osc(String s) => '\x1b]$s\x07';
String cmdOsc(String c) => osc('6973;cmd;${base64.encode(utf8.encode(c))}');
String prompt(String cwd) => '${osc('7;file://h$cwd')}${osc('133;A')}\$ ${osc('133;B')}';

void main() {
  late Terminal term;
  late CommandBlockTracker tracker;

  setUp(() {
    term = Terminal(maxLines: 1000);
    tracker = attachBlockTracker(term);
  });

  test('ls with two lines of output', () {
    term.write(osc('6973;ready'));
    term.write(prompt('/home/u'));
    term.write('ls\r\n'); // echo of typed command
    term.write('${cmdOsc('ls')}${osc('133;C')}');
    term.write('a.txt\r\nb.txt\r\n');
    term.write('${osc('133;D;0')}${prompt('/home/u')}');

    expect(tracker.isActive, isTrue);
    expect(tracker.blocks, hasLength(2));
    final b = tracker.blocks.first;
    expect(b.command, 'ls');
    expect(b.cwd, '/home/u');
    expect(b.exitCode, 0);
    expect(blockOutput(term, b), 'a.txt\nb.txt');
    expect(commandFromScreen(term, b), 'ls');
    expect(commandOf(term, b), 'ls');
  });

  test('output without trailing newline', () {
    term.write(prompt('/'));
    term.write('printf hi\r\n${osc('133;C')}hi');
    term.write('${osc('133;D;0')}\r\n${prompt('/')}');
    expect(blockOutput(term, tracker.blocks.first), 'hi');
  });

  test('command falls back to screen when not reported', () {
    term.write(prompt('/'));
    term.write('echo  spaced\r\n${osc('133;C')}spaced\r\n${osc('133;D;0')}${prompt('/')}');
    final b = tracker.blocks.first;
    expect(b.command, '');
    expect(commandOf(term, b), 'echo  spaced');
  });

  test('blockAtLine with real buffer lines', () {
    term.write(prompt('/'));
    term.write('ls\r\n${osc('133;C')}x\r\ny\r\n${osc('133;D;0')}');
    term.write(prompt('/'));
    final first = tracker.blocks.first;
    expect(tracker.blockAtLine(first.outputStart!.y + 1), same(first));
  });

  test('chains an existing onPrivateOSC handler', () {
    final t2 = Terminal();
    final seen = <String>[];
    t2.onPrivateOSC = (code, args) => seen.add(code);
    attachBlockTracker(t2);
    t2.write(osc('1337;Foo'));
    expect(seen, ['1337']);
  });
}
```

- [ ] **Step 2: Run it.** Expected: FAIL.
- [ ] **Step 3: Implement**

```dart
// lib/features/terminal/shell_integration/xterm_blocks.dart
import 'package:xterm/xterm.dart';
import 'command_block.dart';
import 'command_block_tracker.dart';
import 'shell_event.dart';

class XtermLineRef implements LineRef {
  XtermLineRef(this._anchor);
  final CellAnchor _anchor;
  @override
  int get x => _anchor.x;
  @override
  int get y => _anchor.y;
  @override
  bool get attached => _anchor.attached;
}

/// Creates a tracker fed by [terminal]'s private OSCs. Anchors are always taken
/// on the main buffer, so full-screen apps (vim, htop) cannot corrupt blocks.
CommandBlockTracker attachBlockTracker(Terminal terminal) {
  final tracker = CommandBlockTracker(
    cursor: () => XtermLineRef(terminal.mainBuffer.createAnchorFromCursor()),
  );
  final previous = terminal.onPrivateOSC;
  terminal.onPrivateOSC = (code, args) {
    final e = parseShellOsc(code, args);
    if (e != null) {
      tracker.handle(e);
    } else {
      previous?.call(code, args);
    }
  };
  return tracker;
}

String blockOutput(Terminal t, CommandBlock b) {
  final s = b.outputStart;
  if (s == null || !s.attached) return '';
  final e = b.end;
  final buf = t.mainBuffer;
  final endOffset = (e != null && e.attached)
      ? CellOffset(e.x, e.y)
      : CellOffset(buf.cursorX, buf.absoluteCursorY);
  return buf.getText(BufferRangeLine(CellOffset(0, s.y), endOffset)).trimRight();
}

String commandFromScreen(Terminal t, CommandBlock b) {
  final s = b.inputStart, e = b.outputStart;
  if (s == null || e == null || !s.attached || !e.attached) return '';
  return t.mainBuffer
      .getText(BufferRangeLine(CellOffset(s.x, s.y), CellOffset(e.x, e.y)))
      .trim();
}

String commandOf(Terminal t, CommandBlock b) =>
    b.command.isNotEmpty ? b.command : commandFromScreen(t, b);
```

- [ ] **Step 4: Run the test.** Expected: PASS. If `blockOutput` returns an extra trailing empty line or misses the last character, inspect `Buffer.getText`'s end-x handling (`~/.pub-cache/hosted/pub.dev/xterm-4.0.0/lib/src/core/buffer/buffer.dart:558`) and adjust **only** the end offset (for example `e.x` vs `e.x - 1`). The tests are the specification.
- [ ] **Step 5: Commit**

```bash
git add lib/features/terminal/shell_integration/xterm_blocks.dart test/features/terminal/shell_integration/xterm_blocks_test.dart
git commit -m "feat(terminal): bind block tracker to xterm buffer anchors"
```

---

### Task 7: Integration runner (timing, gate, input queue)

**Files:**
- Create: `lib/features/terminal/shell_integration/integration_runner.dart`
- Test: `test/features/terminal/shell_integration/integration_runner_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/features/terminal/shell_integration/integration_runner_test.dart
import 'dart:async';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xell/features/terminal/shell_integration/integration_runner.dart';
import 'package:xell/features/terminal/shell_integration/output_gate.dart';
import 'package:xell/features/terminal/shell_integration/shell_bootstrap.dart';

void main() {
  late List<String> sent;
  late List<String> written;

  ShellIntegrationRunner make(Future<bool> supported) => ShellIntegrationRunner(
        shellSupported: supported,
        sendToShell: sent.add,
        writeToTerminal: written.add,
      );

  setUp(() {
    sent = [];
    written = [];
  });

  test('injects after the prompt goes quiet', () {
    fakeAsync((fa) {
      final r = make(Future.value(true));
      expect(r.onRemoteOutput('Welcome\r\n\$ '), 'Welcome\r\n\$ ');
      fa.elapse(const Duration(milliseconds: 100));
      expect(sent, isEmpty);
      fa.elapse(const Duration(milliseconds: 300));
      expect(sent, [ShellBootstrap.injectionLine()]);
      expect(r.isHolding, isTrue);
      r.dispose();
    });
  });

  test('unsupported shell → never injects, output untouched', () {
    fakeAsync((fa) {
      final r = make(Future.value(false));
      r.onRemoteOutput('\$ ');
      fa.elapse(const Duration(seconds: 5));
      expect(sent, isEmpty);
      expect(r.onRemoteOutput('x'), 'x');
      r.dispose();
    });
  });

  test('injects at the hard deadline even if output never goes quiet', () {
    fakeAsync((fa) {
      final r = make(Future.value(true));
      for (var i = 0; i < 40; i++) {
        r.onRemoteOutput('.');
        fa.elapse(const Duration(milliseconds: 100));
      }
      expect(sent, hasLength(1));
      r.dispose();
    });
  });

  test('input typed while holding is queued and flushed after ready', () {
    fakeAsync((fa) {
      final r = make(Future.value(true));
      r.onRemoteOutput('\$ ');
      fa.elapse(const Duration(milliseconds: 400));
      expect(r.queueInputIfHolding('ls'), isTrue);
      expect(sent, hasLength(1));
      final out = r.onRemoteOutput('echo...${OutputGate.readyMarker}\r\x1b[2K\$ ');
      expect(out, '${OutputGate.readyMarker}\r\x1b[2K\$ ');
      expect(sent.last, 'ls');
      expect(r.queueInputIfHolding('x'), isFalse);
      r.dispose();
    });
  });

  test('timeout releases held output transparently and flushes input', () {
    fakeAsync((fa) {
      final r = make(Future.value(true));
      r.onRemoteOutput('\$ ');
      fa.elapse(const Duration(milliseconds: 400));
      r.queueInputIfHolding('pwd');
      r.onRemoteOutput('bash: base64: command not found\r\n');
      fa.elapse(const Duration(seconds: 4));
      expect(written.single, contains('base64: command not found'));
      expect(sent.last, 'pwd');
      expect(r.isHolding, isFalse);
      r.dispose();
    });
  });

  test('shell detection that fails counts as unsupported', () {
    fakeAsync((fa) {
      final r = make(Future.error(Exception('exec denied')));
      r.onRemoteOutput('\$ ');
      fa.elapse(const Duration(seconds: 5));
      expect(sent, isEmpty);
      r.dispose();
    });
  });
}
```

- [ ] **Step 2: Run it.** Expected: FAIL.
- [ ] **Step 3: Implement**

```dart
// lib/features/terminal/shell_integration/integration_runner.dart
import 'dart:async';
import 'output_gate.dart';
import 'shell_bootstrap.dart';

/// Decides when to inject the hooks, hides the echo, and queues keystrokes
/// typed in the meantime. One instance per terminal session.
class ShellIntegrationRunner {
  ShellIntegrationRunner({
    required Future<bool> shellSupported,
    required this.sendToShell,
    required this.writeToTerminal,
    this.quietPeriod = const Duration(milliseconds: 300),
    this.maxWaitForPrompt = const Duration(seconds: 3),
    this.readyTimeout = const Duration(seconds: 3),
  }) {
    shellSupported.then((ok) {
      _supported = ok;
      if (!ok) _done = true;
      _maybeInject();
    }, onError: (Object _) {
      _supported = false;
      _done = true;
    });
    _deadline = Timer(maxWaitForPrompt, () {
      _promptSeen = true;
      _maybeInject();
    });
  }

  final void Function(String) sendToShell;
  final void Function(String) writeToTerminal;
  final Duration quietPeriod;
  final Duration maxWaitForPrompt;
  final Duration readyTimeout;

  final _gate = OutputGate();
  final _pendingInput = StringBuffer();
  bool? _supported;
  bool _promptSeen = false;
  bool _injected = false;
  bool _done = false;
  Timer? _quiet;
  Timer? _deadline;
  Timer? _readyTimer;

  bool get isHolding => _gate.isHolding;

  /// Filters remote output. Returns what must be written to the terminal.
  String onRemoteOutput(String text) {
    if (!_injected && !_done) {
      _quiet?.cancel();
      _quiet = Timer(quietPeriod, () {
        _promptSeen = true;
        _maybeInject();
      });
    }
    final wasHolding = _gate.isHolding;
    final out = _gate.process(text);
    if (wasHolding && !_gate.isHolding) _complete();
    return out;
  }

  /// Returns true when [data] was queued, in which case the caller must not
  /// send it to the shell.
  bool queueInputIfHolding(String data) {
    if (!_gate.isHolding) return false;
    _pendingInput.write(data);
    return true;
  }

  void _maybeInject() {
    if (_injected || _done || _supported != true || !_promptSeen) return;
    _injected = true;
    _quiet?.cancel();
    _deadline?.cancel();
    _gate.hold();
    sendToShell(ShellBootstrap.injectionLine());
    _readyTimer = Timer(readyTimeout, () {
      if (!_gate.isHolding) return;
      final held = _gate.release();
      if (held.isNotEmpty) writeToTerminal(held);
      _complete();
    });
  }

  void _complete() {
    _done = true;
    _readyTimer?.cancel();
    if (_pendingInput.isNotEmpty) {
      sendToShell(_pendingInput.toString());
      _pendingInput.clear();
    }
  }

  void dispose() {
    _quiet?.cancel();
    _deadline?.cancel();
    _readyTimer?.cancel();
  }
}
```

- [ ] **Step 4: Run the test.** Expected: PASS.
- [ ] **Step 5: Commit**

```bash
git add lib/features/terminal/shell_integration/integration_runner.dart test/features/terminal/shell_integration/integration_runner_test.dart
git commit -m "feat(terminal): shell integration runner (inject, hide echo, queue input, timeout)"
```

---

### Task 8: Wire into SshService, TerminalSession, TerminalController

**Files:**
- Modify: `lib/features/terminal/services/ssh_service.dart`
- Modify: `lib/features/terminal/models/terminal_session.dart`
- Create: `lib/features/terminal/models/captured_command.dart`
- Modify: `lib/features/terminal/controllers/terminal_controller.dart`

- [ ] **Step 1: Login shell lookup.** In `SshService`, below `detectOs`:

```dart
  /// The user's login shell path, read over a separate exec channel (never
  /// typed into the interactive shell).
  Future<String> loginShell(SSHClient client) =>
      _exec(client, r'printf %s "$SHELL"');
```

- [ ] **Step 2: Session fields.** In `TerminalSession`, add imports and fields:

```dart
import '../shell_integration/command_block_tracker.dart';
import '../shell_integration/integration_runner.dart';
```

```dart
  /// Null until connected. Inactive (isActive == false) when the shell is
  /// unsupported or integration is disabled.
  CommandBlockTracker? blocks;
  ShellIntegrationRunner? integration;
  StreamSubscription<dynamic>? blockFinishedSub;
```

- [ ] **Step 3: CapturedCommand.**

```dart
// lib/features/terminal/models/captured_command.dart
class CapturedCommand {
  final String command;
  final String hostId;
  final String? cwd;
  final int? exitCode;
  final Duration? duration;

  const CapturedCommand({
    required this.command,
    required this.hostId,
    this.cwd,
    this.exitCode,
    this.duration,
  });
}
```

- [ ] **Step 4: Controller.** In `terminal_controller.dart`:

1. Imports:

```dart
import '../models/captured_command.dart';
import '../shell_integration/integration_runner.dart';
import '../shell_integration/xterm_blocks.dart';
```

2. Replace the `String` command stream with `CapturedCommand`, add the setting flag and finished-block callback:

```dart
  final _commandStreamController = StreamController<CapturedCommand>.broadcast();
  Stream<CapturedCommand> get commandCapturedStream => _commandStreamController.stream;

  /// Mirrors Settings → Terminal → Shell integration. Read when a session opens.
  bool shellIntegrationEnabled = true;

  /// Called for every finished block (used for "finished while away" notices).
  void Function(TerminalSession session, CommandBlock block)? onBlockFinished;
```

(Delete the old `commandTypedStream` getter. Add `import '../shell_integration/command_block.dart';`.)

3. In `createSession`, right after `final xterm = Terminal(maxLines: 5000);`:

```dart
      final tracker = attachBlockTracker(xterm);
      session.blocks = tracker;

      final runner = ShellIntegrationRunner(
        shellSupported: shellIntegrationEnabled
            ? _service.loginShell(client).then(ShellBootstrap.supports)
            : Future.value(false),
        sendToShell: (s) => shellSession.stdin.add(utf8.encode(s)),
        writeToTerminal: xterm.write,
      );
      session.integration = runner;

      session.blockFinishedSub = tracker.onFinished.listen((b) {
        final cmd = commandOf(xterm, b);
        if (cmd.isNotEmpty) {
          _commandStreamController.add(CapturedCommand(
            command: cmd,
            hostId: host.id,
            cwd: b.cwd,
            exitCode: b.exitCode,
            duration: b.duration,
          ));
        }
        onBlockFinished?.call(session, b);
        _refresh();
      });
```

Add `import '../shell_integration/shell_bootstrap.dart';`.

4. Route output through the runner. Replace the first line of `handleOutput`:

```dart
      void handleOutput(List<int> data) {
        final text = runner.onRemoteOutput(utf8.decode(data, allowMalformed: true));
        if (text.isEmpty) return;
```

Then change the small-echo fast path to use `text.length` instead of `data.length`:

```dart
        if (session.outputFlushTimer == null &&
            outputBuf.isEmpty &&
            text.length <= _interactiveEchoFlushBytes) {
```

5. Input: queue while holding, and keep keystroke capture only as the fallback:

```dart
      xterm.onOutput = (data) {
        if (runner.queueInputIfHolding(data)) return;
        shellSession.stdin.add(utf8.encode(data));
        if (!tracker.isActive) _bufferInput(data, inputBuffer, host.id);
      };
```

6. Update `_bufferInput` to emit `CapturedCommand`:

```dart
  void _bufferInput(String data, StringBuffer buf, String hostId) {
    for (int i = 0; i < data.length; i++) {
      final code = data.codeUnitAt(i);
      if (code == 0x0D) {
        final cmd = buf.toString().trim();
        if (cmd.isNotEmpty) {
          _commandStreamController.add(CapturedCommand(command: cmd, hostId: hostId));
        }
        buf.clear();
```

(The rest of the method is unchanged.)

7. Cleanup. Add a helper and call it from `closeSession` (next to the existing cancels) and from `dispose` (inside the loop):

```dart
  void _disposeIntegration(TerminalSession s) {
    s.integration?.dispose();
    s.blockFinishedSub?.cancel();
    s.blocks?.dispose();
  }
```

- [ ] **Step 5: Update the single consumer** in `lib/shared/layouts/app_shell.dart` (lines ~83–84):

```dart
    _commandStreamSub = _terminalController.commandCapturedStream
        .listen(_historyController.addCaptured);
```

Change the field type to `StreamSubscription<CapturedCommand>?` and add the import. `addCaptured` is created in Task 9. Until then, temporarily use `.listen((c) => _historyController.add(c.command))` so this task compiles on its own.

- [ ] **Step 6:** `flutter analyze && flutter test`. Expected: clean.
- [ ] **Step 7: Manual check** (`flutter run -d macos`). Connect to an Ubuntu bash host and to a zsh host (macOS `localhost` with Remote Login enabled works). Expected:
  - There is no visible injection line. The prompt looks the same as before, and the MOTD is intact.
  - `history | tail -3` on bash does **not** show the eval line.
  - Typing immediately after connect is not lost.
  - Connect to an Alpine container (`/bin/ash`). It behaves exactly like today, with no injection.
- [ ] **Step 8: Commit**

```bash
git add -A lib
git commit -m "feat(terminal): enable shell integration and command blocks per session"
```

---

### Task 9: Enriched history

**Files:**
- Modify: `lib/features/terminal/models/command_history_entry.dart`
- Modify: `lib/features/terminal/controllers/command_history_controller.dart`
- Modify: `lib/shared/layouts/app_shell.dart`
- Test: `test/features/terminal/models/command_history_entry_test.dart`

- [ ] **Step 1: Failing test**

```dart
// test/features/terminal/models/command_history_entry_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:xell/features/terminal/models/command_history_entry.dart';

void main() {
  test('reads legacy JSON (v0.1.x) without new fields', () {
    final e = CommandHistoryEntry.fromJson({
      'id': '1', 'command': 'ls', 'ranAt': '2026-01-01T00:00:00.000',
    });
    expect(e.hostId, isNull);
    expect(e.exitCode, isNull);
  });

  test('round-trips new fields', () {
    final e = CommandHistoryEntry(
      id: '1', command: 'make', ranAt: DateTime(2026),
      hostId: 'h1', cwd: '/srv', exitCode: 2,
      duration: const Duration(milliseconds: 1234),
    );
    final back = CommandHistoryEntry.fromJson(e.toJson());
    expect(back.hostId, 'h1');
    expect(back.cwd, '/srv');
    expect(back.exitCode, 2);
    expect(back.duration, const Duration(milliseconds: 1234));
  });

  test('omits null fields from JSON', () {
    final j = CommandHistoryEntry(id: '1', command: 'x', ranAt: DateTime(2026)).toJson();
    expect(j.containsKey('exitCode'), isFalse);
  });
}
```

- [ ] **Step 2: Run it.** Expected: FAIL.
- [ ] **Step 3: Implement.** Replace the class body in `command_history_entry.dart`:

```dart
class CommandHistoryEntry {
  final String id;
  final String command;
  final DateTime ranAt;
  final String? hostId;
  final String? cwd;
  final int? exitCode;
  final Duration? duration;

  const CommandHistoryEntry({
    required this.id,
    required this.command,
    required this.ranAt,
    this.hostId,
    this.cwd,
    this.exitCode,
    this.duration,
  });

  bool get failed => exitCode != null && exitCode != 0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'command': command,
        'ranAt': ranAt.toIso8601String(),
        if (hostId != null) 'hostId': hostId,
        if (cwd != null) 'cwd': cwd,
        if (exitCode != null) 'exitCode': exitCode,
        if (duration != null) 'durationMs': duration!.inMilliseconds,
      };

  factory CommandHistoryEntry.fromJson(Map<String, dynamic> json) =>
      CommandHistoryEntry(
        id: json['id'] as String,
        command: json['command'] as String,
        ranAt: DateTime.parse(json['ranAt'] as String),
        hostId: json['hostId'] as String?,
        cwd: json['cwd'] as String?,
        exitCode: json['exitCode'] as int?,
        duration: json['durationMs'] == null
            ? null
            : Duration(milliseconds: json['durationMs'] as int),
      );

  static String generateId() =>
      DateTime.now().microsecondsSinceEpoch.toString();
}
```

- [ ] **Step 4: Controller.** In `command_history_controller.dart`, add:

```dart
  Future<void> addCaptured(CapturedCommand c) async {
    final trimmed = c.command.trim();
    if (trimmed.isEmpty) return;
    final entry = CommandHistoryEntry(
      id: CommandHistoryEntry.generateId(),
      command: trimmed,
      ranAt: DateTime.now(),
      hostId: c.hostId,
      cwd: c.cwd,
      exitCode: c.exitCode,
      duration: c.duration,
    );
    final current = entries.where((e) => e.command != trimmed).toList();
    entriesNotifier.value = [entry, ...current];
    await _storage.save(entriesNotifier.value);
  }
```

Then **delete** the old `add(String)`. Its only caller was `app_shell.dart`, which moves to `addCaptured` in Step 5. Confirm with `grep -rn "istoryController.add(" lib` (expected: no matches after Step 5). Import `../models/captured_command.dart`.

- [ ] **Step 5:** In `app_shell.dart`, switch to `.listen(_historyController.addCaptured)` (the final form from Task 8, Step 5).
- [ ] **Step 6: Subtle UI.** In the history list in `terminal_right_sidebar.dart` (the widget around line 405 that uses `controller.entriesNotifier`), show a 6px red dot before the command when `entry.failed`. Add **nothing** else visible.
- [ ] **Step 7:** `flutter analyze && flutter test`. Then run manually: `false`, `ls`, and `cd /tmp && pwd`. The history shows them, and `false` has the red dot.
- [ ] **Step 8: Commit**

```bash
git add -A lib test
git commit -m "feat(history): record host, cwd, exit code and duration from command blocks"
```

---

### Task 10: Block actions in the right-click menu

**Files:**
- Modify: `lib/features/terminal/widgets/terminal_widget.dart`
- Modify: `lib/features/terminal/views/terminal_page.dart` (`_showTerminalContextMenu` ~306, `_pane` ~365–398)
- Modify: `lib/features/snippets/views/snippet_form_dialog.dart`

- [ ] **Step 1: Pass the clicked cell up.** In `TerminalWidget` and `_ConnectedView`, add:

```dart
  final void Function(Offset globalPosition, CellOffset cell)? onSecondaryTap;
```

Thread it through the constructors. Set it on `TerminalView`:

```dart
          child: TerminalView(
            terminal,
            controller: _xtermController,
            theme: widget.terminalTheme,
            textStyle: _textStyle,
            autofocus: widget.autofocus,
            padding: const EdgeInsets.all(AppSpacing.s8),
            onSecondaryTapUp: widget.onSecondaryTap == null
                ? null
                : (details, cell) =>
                    widget.onSecondaryTap!(details.globalPosition, cell),
          ),
```

- [ ] **Step 2: Use it in the page.** In `_pane`, delete the `GestureDetector(onSecondaryTapUp: ...)` wrapper and pass instead:

```dart
      onSecondaryTap: (Platform.isMacOS || Platform.isLinux || Platform.isWindows)
          ? (pos, cell) => _showTerminalContextMenu(context, pos, session, cell)
          : null,
```

- [ ] **Step 3: Snippet prefill.** In `SnippetFormDialog`, add `final String? initialCommand;` to the constructor (`this.initialCommand`). Change:

```dart
  late final _commandCtrl = TextEditingController(
      text: widget.existing?.command ?? widget.initialCommand ?? '');
```

- [ ] **Step 4: Menu.** Change the signature to `_showTerminalContextMenu(BuildContext context, Offset globalPosition, TerminalSession session, CellOffset cell)`. Build the items:

```dart
    final tracker = session.blocks;
    final block = (tracker != null && tracker.isActive)
        ? tracker.blockAtLine(cell.y)
        : null;
    final blockHasCommand =
        block != null && block.state != BlockState.editing;

    final items = <PopupMenuEntry<String>>[
      _terminalMenuItem('copy', Icons.copy_outlined, 'Copy'),
      _terminalMenuItem('paste', Icons.content_paste_outlined, 'Paste'),
      if (blockHasCommand) ...[
        const PopupMenuDivider(height: 8),
        _terminalMenuItem('b_copy_cmd', Icons.terminal, 'Copy command'),
        _terminalMenuItem('b_copy_out', Icons.subject, 'Copy output'),
        _terminalMenuItem('b_insert', Icons.keyboard_return, 'Insert command'),
        _terminalMenuItem('b_rerun', Icons.replay, 'Run again'),
        if (widget.snippetController != null)
          _terminalMenuItem('b_snippet', Icons.bookmark_add_outlined, 'Save as snippet'),
      ],
    ];
```

Then pass `items: items` to `showMenu`. Handle the new values in `.then`:

```dart
      final term = session.xterm;
      if (block == null || term == null) return;
      final cmd = commandOf(term, block);
      final atPrompt = tracker!.current?.state == BlockState.editing;
      switch (value) {
        case 'b_copy_cmd':
          Clipboard.setData(ClipboardData(text: cmd));
        case 'b_copy_out':
          Clipboard.setData(ClipboardData(text: blockOutput(term, block)));
        case 'b_insert' when atPrompt:
          term.textInput(cmd);
        case 'b_rerun' when atPrompt:
          term.textInput('$cmd\r');
        case 'b_insert' || 'b_rerun':
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('A command is still running in this tab.'),
            behavior: SnackBarBehavior.floating,
          ));
        case 'b_snippet':
          showDialog<void>(
            context: context,
            builder: (_) => SnippetFormDialog(
              controller: widget.snippetController!,
              initialCommand: cmd,
            ),
          );
      }
```

Keep the existing `copy` and `paste` handling above this block. Add the imports `../shell_integration/command_block.dart`, `../shell_integration/xterm_blocks.dart`, `../../snippets/views/snippet_form_dialog.dart` and `package:xterm/xterm.dart' show CellOffset`. If the async `.then` triggers the `use_build_context_synchronously` lint, capture `ScaffoldMessenger.of(context)` before calling `showMenu`, the same way `doCopy` is captured today.

- [ ] **Step 5:** `flutter analyze && flutter test`.
- [ ] **Step 6: Manual check.** Run `ls -la /etc`, then right-click inside the output:
  - **Copy output** → the clipboard holds exactly the listing.
  - **Copy command** → `ls -la /etc`.
  - **Run again** → reruns it.
  - **Insert command** → the command is typed and not run.
  - **Save as snippet** → the dialog opens prefilled.

  Start `sleep 30`. While it runs, use **Run again** on an earlier block and confirm the snackbar appears. On a host without integration (Alpine), the menu shows only Copy/Paste.
- [ ] **Step 7: Commit**

```bash
git add -A lib
git commit -m "feat(terminal): block actions in context menu (copy, rerun, insert, save as snippet)"
```

---

### Task 11: Tab status + "finished while away" notice

**Files:**
- Modify: `lib/features/terminal/widgets/terminal_tab_bar.dart` (`_statusColor` ~276, dot ~308–316)
- Modify: `lib/shared/layouts/app_shell.dart`

- [ ] **Step 1: Tab dot reflects the last block.** It shows the connection colour as today. A running command shows the accent colour, and a last command that failed shows red. Add this widget at the bottom of `terminal_tab_bar.dart`:

```dart
class _StatusDot extends StatelessWidget {
  final TerminalSession session;
  final Color connectionColor;
  const _StatusDot({required this.session, required this.connectionColor});

  Widget _dot(Color c) => Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
      );

  @override
  Widget build(BuildContext context) {
    final tracker = session.blocks;
    if (tracker == null || session.status != SessionStatus.connected) {
      return _dot(connectionColor);
    }
    return ValueListenableBuilder<List<CommandBlock>>(
      valueListenable: tracker.blocksNotifier,
      builder: (context, blocks, _) {
        CommandBlock? last;
        for (final b in blocks.reversed) {
          if (b.state != BlockState.editing) {
            last = b;
            break;
          }
        }
        final color = last == null
            ? connectionColor
            : last.isRunning
                ? AppColors.accent
                : last.failed
                    ? const Color(0xFFF87171)
                    : connectionColor;
        return _dot(color);
      },
    );
  }
}
```

Replace the existing dot `Container(width: 6, height: 6, ... color: _statusColor ...)` (around line 308) with `_StatusDot(session: widget.session, connectionColor: _statusColor)`. Import `../shell_integration/command_block.dart`.

- [ ] **Step 2: Notice.** In `app_shell.dart` `initState`, after creating `_terminalController`:

```dart
    _terminalController.onBlockFinished = (session, block) {
      final d = block.duration;
      if (d == null || d < const Duration(seconds: 10)) return;
      final isVisible = _terminalController.activeSessionIdNotifier.value == session.id ||
          _terminalController.splitSessionIdNotifier.value == session.id;
      if (isVisible && _windowFocused) return;
      final ok = !block.failed;
      final cmd = block.command.isEmpty ? 'Command' : block.command;
      _scaffoldMessengerKey.currentState?.showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
        content: Text('${ok ? '✓' : '✗'} ${session.host.name}: '
            '${cmd.length > 60 ? '${cmd.substring(0, 60)}…' : cmd} '
            '· ${d.inSeconds}s${ok ? '' : ' · exit ${block.exitCode}'}'),
        action: SnackBarAction(
          label: 'Show',
          onPressed: () => _terminalController.setActiveSession(session.id),
        ),
      ));
    };
```

- `_windowFocused`: `AppShell` already mixes in `WindowListener` on desktop. Add `bool _windowFocused = true;` and override `onWindowFocus() => _windowFocused = true` and `onWindowBlur() => _windowFocused = false`. On mobile it stays `true`.
- `_scaffoldMessengerKey`: if `XellApp`'s `MaterialApp` has no `scaffoldMessengerKey`, add a global `final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();` in `lib/app/xell_app.dart`, pass it to `MaterialApp`, and use it here.

- [ ] **Step 3:** `flutter analyze && flutter test`.
- [ ] **Step 4: Manual check.** In tab A run `sleep 12; false`, then switch to tab B. After about 12s a snackbar reads `✗ host: sleep 12; false · 12s · exit 1`, and **Show** switches to tab A. Tab A's dot is the accent colour while the command runs and red afterwards. Run `true` and the dot returns to green.
- [ ] **Step 5: Commit**

```bash
git add -A lib pubspec.yaml pubspec.lock
git commit -m "feat(terminal): tab status from last command and finished-while-away notice"
```

---

### Task 12: Settings toggle

**Files:**
- Modify: `lib/features/settings/data/settings_storage.dart`
- Modify: `lib/features/settings/controllers/settings_controller.dart`
- Modify: `lib/features/settings/views/settings_page.dart`
- Modify: `lib/shared/layouts/app_shell.dart`

- [ ] **Step 1: Storage**

```dart
  static const _shellIntegrationKey = 'xell.shellIntegration';

  Future<bool> loadShellIntegration() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_shellIntegrationKey) ?? true;
  }

  Future<void> saveShellIntegration(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_shellIntegrationKey, enabled);
  }
```

- [ ] **Step 2: Controller.** Add `final shellIntegrationNotifier = ValueNotifier<bool>(true);`. Load it in `load()` with `shellIntegrationNotifier.value = await _storage.loadShellIntegration();`. Add:

```dart
  Future<void> setShellIntegration(bool enabled) async {
    shellIntegrationNotifier.value = enabled;
    await _storage.saveShellIntegration(enabled);
  }
```

Dispose it in `dispose()`.

- [ ] **Step 3: Page.** Add `_ShellIntegrationSetting(controller: controller)` to the **Terminal** `_Section`, after `_TerminalThemeSetting`:

```dart
class _ShellIntegrationSetting extends StatelessWidget {
  final SettingsController controller;
  const _ShellIntegrationSetting({required this.controller});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: controller.shellIntegrationNotifier,
      builder: (context, enabled, _) => _SettingRow(
        label: 'Shell Integration',
        description:
            'Command blocks, exit codes and accurate history on bash and zsh. '
            'Runs in memory only; nothing is written on the server. '
            'Applies to new tabs.',
        trailing: Switch.adaptive(
          value: enabled,
          activeTrackColor: AppColors.accent,
          onChanged: controller.setShellIntegration,
        ),
      ),
    );
  }
}
```

Check `_SettingRow`'s constructor at `settings_page.dart:114` and match its parameter names.

- [ ] **Step 4: Wire.** In `app_shell.dart`, after the settings controller is created:

```dart
    _settingsController.shellIntegrationNotifier.addListener(() {
      _terminalController.shellIntegrationEnabled =
          _settingsController.shellIntegrationNotifier.value;
    });
```

- [ ] **Step 5:** `flutter analyze && flutter test`. Turn the toggle off, open a new tab, and confirm there are no blocks: right-click shows only Copy/Paste, and history still records via keystrokes. Turn it back on and open a new tab: blocks work.
- [ ] **Step 6: Commit**

```bash
git add -A lib
git commit -m "feat(settings): shell integration toggle"
```

---

### Task 13: Transparency docs + QA matrix + PR

**Files:**
- Create: `docs/shell-integration.md`
- Modify: `README.md` ("What it is" list)

- [ ] **Step 1: `docs/shell-integration.md`** must contain:
  1. What it is, in one paragraph.
  2. The **full script**, copied verbatim from `ShellBootstrap.script`.
  3. A line-by-line explanation of every function and of the OSC codes (133 A/B/C/D, 7, 6973 cmd/ready).
  4. Guarantees: in memory only; nothing written on the server; the injected line starts with a space; detection reads `$SHELL` over a separate exec channel; on failure, everything that was typed is shown.
  5. Known limitations: on plain bash (without bash-preexec), the command text is read from the screen rather than reported by the shell; zsh without `HIST_IGNORE_SPACE` records the eval line in history; `sudo -i`, `su -`, `exec bash` and nested SSH lose the hooks; inside tmux/screen, OSC passthrough is required; fish and sh are unsupported; an existing bash DEBUG trap without bash-preexec disables command-start detection.
  6. How to turn it off (Settings → Terminal).
- [ ] **Step 2: README.** Add this bullet under "What it is": `- **Smart terminal** — every command becomes a block with exit code, duration and cwd; right-click to copy output, rerun, or save as a snippet (bash/zsh, nothing installed on the server)`.
- [ ] **Step 3: QA matrix.** Run each row and record the result in the PR description:

| Host | Shell / setup | Expect |
|---|---|---|
| Ubuntu 24.04 | bash default (`HISTCONTROL=ignoreboth`) | blocks; no eval in history |
| Debian 12 | bash + `PROMPT_COMMAND='history -a'` | blocks; `history -a` still runs |
| Ubuntu | bash + starship | blocks; prompt unchanged |
| Ubuntu | bash + bash-preexec + atuin | blocks; atuin still records |
| macOS localhost | zsh default | blocks |
| macOS localhost | zsh + oh-my-zsh + powerlevel10k | blocks; prompt unchanged; no flicker |
| Alpine | ash | no injection; terminal unchanged |
| any | `vim`, `htop`, `less` then quit | blocks intact after exit |
| any | `sudo -i` | blocks stop silently; terminal fine |
| any | `tmux` | no blocks inside tmux; no garbage |
| any | `yes \| head -n 200000`, `cat` of a 50MB file | no visible slowdown versus master (time it) |
| Android / iOS | bash host | blocks; queued typing during connect is not lost |

- [ ] **Step 4:** `flutter analyze && flutter test`. All green.
- [ ] **Step 5: Commit, push, PR**

```bash
git add docs/shell-integration.md README.md
git commit -m "docs: shell integration transparency doc and README"
git push -u origin feat/shell-integration-blocks
gh pr create --title "feat: shell integration + command blocks" --body-file - <<'EOF'
## Summary
- In-memory bash/zsh hooks (OSC 133/7) turn each command into a block: command, cwd, exit code, duration
- Right-click a block: copy command / copy output / insert / run again / save as snippet
- Tab dot shows running/failed; notice when a long command finishes in a background tab
- History now records host, cwd, exit code, duration
- Settings → Terminal → Shell Integration (default on); docs/shell-integration.md shows the exact script

## QA matrix
(paste the table from the plan with results)

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
```
