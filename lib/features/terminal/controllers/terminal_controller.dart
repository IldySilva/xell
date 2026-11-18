import 'dart:async';
import 'dart:convert';
import 'package:material_ui/material_ui.dart';
import 'package:xterm/xterm.dart';
import '../../hosts/models/os_type.dart';
import '../../hosts/models/ssh_host.dart';
import '../models/terminal_session.dart';
import '../models/workspace.dart';
import '../services/ssh_service.dart';

class TerminalController {
  final _service = SshService();
  final _commandStreamController = StreamController<String>.broadcast();

  void Function(String hostId, OsType os)? onOsDetected;
  static const _interactiveEchoFlushBytes = 32;

  Stream<String> get commandTypedStream => _commandStreamController.stream;

  final sessionsNotifier = ValueNotifier<List<TerminalSession>>([]);
  final activeSessionIdNotifier = ValueNotifier<String?>(null);

  // Split pane
  final splitAxisNotifier = ValueNotifier<Axis?>(null);
  final splitSessionIdNotifier = ValueNotifier<String?>(null);
  final activePaneNotifier = ValueNotifier<int>(
    0,
  ); // 0 = primary, 1 = secondary

  // Workspaces
  final workspacesNotifier = ValueNotifier<List<Workspace>>([
    Workspace.defaultWorkspace,
  ]);
  final activeWorkspaceIdNotifier = ValueNotifier<String>(kDefaultWorkspaceId);

  List<TerminalSession> get sessions => sessionsNotifier.value;

  TerminalSession? get activeSession {
    final id = activeSessionIdNotifier.value;
    if (id == null) return null;
    try {
      return sessions.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  TerminalSession? get splitSession {
    final id = splitSessionIdNotifier.value;
    if (id == null) return null;
    try {
      return sessions.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  List<TerminalSession> get activeWorkspaceSessions {
    final wsId = activeWorkspaceIdNotifier.value;
    return sessions.where((s) => s.workspaceId == wsId).toList();
  }

  // ── Session creation ──────────────────────────────────────────────────────

  Future<TerminalSession> createSession({
    required SshHost host,
    String? password,
    String? passphrase,
  }) async {
    final session = TerminalSession(
      id: TerminalSession.generateId(),
      host: host,
      workspaceId: activeWorkspaceIdNotifier.value,
    );

    sessionsNotifier.value = [...sessions, session];
    activeSessionIdNotifier.value = session.id;

    try {
      final client = await _service.connect(
        host: host,
        password: password,
        passphrase: passphrase,
      );
      final shellSession = await _service.openShell(client);

      final xterm = Terminal(maxLines: 5000);

      // Accumulate stdout+stderr chunks and flush once per event-loop turn.
      // This collapses bursts of SSH chunks (cat, git log, tail -f) into a
      // single xterm.write() call per frame instead of one per chunk,
      // cutting notifyListeners / repaint cycles proportionally.
      final outputBuf = StringBuffer();

      void flushOutput() {
        if (outputBuf.isEmpty) return;
        xterm.write(outputBuf.toString());
        outputBuf.clear();
      }

      void scheduleFlush() {
        session.outputFlushTimer ??= Timer(Duration.zero, () {
          flushOutput();
          session.outputFlushTimer = null;
        });
      }

      void handleOutput(List<int> data) {
        final text = utf8.decode(data, allowMalformed: true);

        // Interactive echo is usually tiny. Write it immediately so typing
        // does not wait behind the burst buffer used for large command output.
        if (session.outputFlushTimer == null &&
            outputBuf.isEmpty &&
            data.length <= _interactiveEchoFlushBytes) {
          xterm.write(text);
          return;
        }

        outputBuf.write(text);
        scheduleFlush();
      }

      session.stdoutSub = shellSession.stdout.listen(handleOutput);
      session.stderrSub = shellSession.stderr.listen(handleOutput);

      // Per-session input buffer for command capture.
      final inputBuffer = StringBuffer();

      xterm.onOutput = (data) {
        shellSession.stdin.add(utf8.encode(data));
        _bufferInput(data, inputBuffer);
      };

      xterm.onResize = (width, height, pixelWidth, pixelHeight) {
        shellSession.resizeTerminal(width, height);
      };

      shellSession.done
          .then((_) {
            session.status = SessionStatus.disconnected;
            _refresh();
          })
          .catchError((_) {});

      session.client = client;
      session.shellSession = shellSession;
      session.xterm = xterm;
      session.status = SessionStatus.connected;
      _refresh();

      unawaited(_detectOs(session, client));

      return session;
    } catch (e) {
      session.status = SessionStatus.error;
      session.errorMessage = e.toString();
      _refresh();
      rethrow;
    }
  }

  Future<void> closeSession(String id) async {
    final index = sessions.indexWhere((s) => s.id == id);
    if (index == -1) return;

    final session = sessions[index];
    session.outputFlushTimer?.cancel();
    session.stdoutSub?.cancel();
    session.stderrSub?.cancel();
    session.client?.close();
    session.status = SessionStatus.disconnected;

    final remaining = sessions.where((s) => s.id != id).toList();
    sessionsNotifier.value = remaining;

    if (activeSessionIdNotifier.value == id) {
      final wsId = activeWorkspaceIdNotifier.value;
      final wsRemaining = remaining
          .where((s) => s.workspaceId == wsId)
          .toList();
      activeSessionIdNotifier.value = wsRemaining.isEmpty
          ? null
          : wsRemaining.last.id;
    }

    if (splitSessionIdNotifier.value == id) {
      splitSessionIdNotifier.value = null;
      if (sessions.isEmpty) splitAxisNotifier.value = null;
    }
  }

  void setActiveSession(String id) {
    if (activePaneNotifier.value == 1) {
      splitSessionIdNotifier.value = id;
    } else {
      activeSessionIdNotifier.value = id;
    }
  }

  // ── Split pane ────────────────────────────────────────────────────────────

  void splitHorizontal() => _split(Axis.horizontal);
  void splitVertical() => _split(Axis.vertical);

  void _split(Axis axis) {
    final id = activeSessionIdNotifier.value;
    if (id == null) return;
    splitAxisNotifier.value = axis;
    splitSessionIdNotifier.value = id;
  }

  void closeSplit() {
    splitAxisNotifier.value = null;
    splitSessionIdNotifier.value = null;
    activePaneNotifier.value = 0;
  }

  void focusPane(int pane) => activePaneNotifier.value = pane;

  // ── Workspaces ────────────────────────────────────────────────────────────

  void createWorkspace(String name) {
    final ws = Workspace(id: Workspace.generateId(), name: name);
    workspacesNotifier.value = [...workspacesNotifier.value, ws];
    activeWorkspaceIdNotifier.value = ws.id;
    // Close split when switching workspace
    closeSplit();
  }

  void switchWorkspace(String id) {
    if (activeWorkspaceIdNotifier.value == id) return;
    activeWorkspaceIdNotifier.value = id;
    closeSplit();
    final wsSessions = sessions.where((s) => s.workspaceId == id).toList();
    activeSessionIdNotifier.value = wsSessions.isEmpty
        ? null
        : wsSessions.last.id;
  }

  void renameWorkspace(String id, String name) {
    final ws = workspacesNotifier.value.firstWhereOrNull((w) => w.id == id);
    if (ws == null) return;
    ws.name = name;
    workspacesNotifier.value = List.from(workspacesNotifier.value);
  }

  void deleteWorkspace(String id) {
    if (id == kDefaultWorkspaceId) return;
    final updated = workspacesNotifier.value.where((w) => w.id != id).toList();
    workspacesNotifier.value = updated;
    if (activeWorkspaceIdNotifier.value == id) {
      switchWorkspace(kDefaultWorkspaceId);
    }
  }

  // ── OS detection ─────────────────────────────────────────────────────────

  Future<void> _detectOs(TerminalSession session, dynamic client) async {
    final os = await _service.detectOs(client);
    if (os == OsType.unknown) return;
    session.detectedOs = os;
    _refresh();
    onOsDetected?.call(session.host.id, os);
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  void _bufferInput(String data, StringBuffer buf) {
    for (int i = 0; i < data.length; i++) {
      final code = data.codeUnitAt(i);
      if (code == 0x0D) {
        final cmd = buf.toString().trim();
        if (cmd.isNotEmpty) _commandStreamController.add(cmd);
        buf.clear();
      } else if (code == 0x7F || code == 0x08) {
        final s = buf.toString();
        if (s.isNotEmpty) {
          buf.clear();
          buf.write(s.substring(0, s.length - 1));
        }
      } else if (code == 0x1B) {
        buf.clear();
      } else if (code >= 32) {
        buf.write(data[i]);
      }
    }
  }

  void _refresh() {
    sessionsNotifier.value = List.from(sessions);
  }

  void dispose() {
    for (final s in sessions) {
      s.outputFlushTimer?.cancel();
      s.stdoutSub?.cancel();
      s.stderrSub?.cancel();
      s.client?.close();
    }
    _commandStreamController.close();
    sessionsNotifier.dispose();
    activeSessionIdNotifier.dispose();
    splitAxisNotifier.dispose();
    splitSessionIdNotifier.dispose();
    activePaneNotifier.dispose();
    workspacesNotifier.dispose();
    activeWorkspaceIdNotifier.dispose();
  }
}

extension _ListExt<T> on List<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}
