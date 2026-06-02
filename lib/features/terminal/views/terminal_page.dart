import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart' hide TerminalController;
import '../../../app/app_theme.dart';
import '../../../features/sftp/views/sftp_page.dart';
import '../../../features/snippets/controllers/snippet_controller.dart';
import '../controllers/command_history_controller.dart';
import '../controllers/terminal_controller.dart';
import '../models/terminal_session.dart';
import '../models/terminal_theme_presets.dart';
import '../models/workspace.dart';
import '../widgets/terminal_keyboard_toolbar.dart';
import '../widgets/terminal_right_sidebar.dart';
import '../widgets/terminal_tab_bar.dart';
import '../widgets/terminal_widget.dart';

class TerminalPage extends StatefulWidget {
  final TerminalController controller;
  final double fontSize;
  final TerminalTheme terminalTheme;
  final Future<void> Function(String id)? onCloseSession;
  final Future<void> Function(String sessionId)? onReconnect;
  final VoidCallback? onNewTab;
  final SnippetController? snippetController;
  final CommandHistoryController? historyController;
  final ValueNotifier<TerminalThemeName>? themeNotifier;
  final ValueChanged<TerminalThemeName>? onThemeChanged;
  final void Function(String command)? onPaste;
  final void Function(String command)? onRun;

  const TerminalPage({
    super.key,
    required this.controller,
    this.fontSize = 13.5,
    this.terminalTheme = const TerminalTheme(
      cursor: Color(0xFFE6EAF2),
      selection: Color(0x445E81F4),
      foreground: Color(0xFFE6EAF2),
      background: Color(0xFF0F1115),
      black: Color(0xFF1E1E2E),
      red: Color(0xFFF38BA8),
      green: Color(0xFFA6E3A1),
      yellow: Color(0xFFF9E2AF),
      blue: Color(0xFF89B4FA),
      magenta: Color(0xFFCBA6F7),
      cyan: Color(0xFF89DCEB),
      white: Color(0xFFBAC2DE),
      brightBlack: Color(0xFF585B70),
      brightRed: Color(0xFFF38BA8),
      brightGreen: Color(0xFFA6E3A1),
      brightYellow: Color(0xFFF9E2AF),
      brightBlue: Color(0xFF89B4FA),
      brightMagenta: Color(0xFFCBA6F7),
      brightCyan: Color(0xFF89DCEB),
      brightWhite: Color(0xFFE6EAF2),
      searchHitBackground: Color(0xFFCBA6F7),
      searchHitBackgroundCurrent: Color(0xFFF9E2AF),
      searchHitForeground: Color(0xFF1E1E2E),
    ),
    this.onCloseSession,
    this.onReconnect,
    this.onNewTab,
    this.snippetController,
    this.historyController,
    this.themeNotifier,
    this.onThemeChanged,
    this.onPaste,
    this.onRun,
  });

  @override
  State<TerminalPage> createState() => _TerminalPageState();
}

class _TerminalPageState extends State<TerminalPage> {
  final _splitRatioNotifier = ValueNotifier<double>(0.5);
  final _sftpRatioNotifier = ValueNotifier<double>(0.55);
  bool _renamingWorkspace = false;
  String? _renamingWorkspaceId;
  final _renameController = TextEditingController();
  final _renameFocus = FocusNode();
  bool _sidebarOpen = false;
  bool _sftpSplitOpen = false;

  TerminalController get _c => widget.controller;

  @override
  void dispose() {
    _splitRatioNotifier.dispose();
    _sftpRatioNotifier.dispose();
    _renameController.dispose();
    _renameFocus.dispose();
    super.dispose();
  }

  Future<void> _closeSession(String id) async {
    if (widget.onCloseSession != null) {
      await widget.onCloseSession!(id);
    } else {
      await _c.closeSession(id);
    }
  }

  Future<void> _reconnect(String id) async {
    widget.onReconnect?.call(id);
  }

  void _startRename(String workspaceId, String currentName) {
    _renameController.text = currentName;
    setState(() {
      _renamingWorkspace = true;
      _renamingWorkspaceId = workspaceId;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _renameFocus.requestFocus());
  }

  void _commitRename() {
    final name = _renameController.text.trim();
    if (name.isNotEmpty && _renamingWorkspaceId != null) {
      _c.renameWorkspace(_renamingWorkspaceId!, name);
    }
    setState(() {
      _renamingWorkspace = false;
      _renamingWorkspaceId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<TerminalSession>>(
      valueListenable: _c.sessionsNotifier,
      builder: (context, sessions, _) {
        if (sessions.isEmpty) return const _EmptyTerminalState();

        return ValueListenableBuilder<List<Workspace>>(
          valueListenable: _c.workspacesNotifier,
          builder: (context, workspaces, _) {
            return ValueListenableBuilder<String>(
              valueListenable: _c.activeWorkspaceIdNotifier,
              builder: (context, activeWsId, _) {
                final showWorkspaceBar = workspaces.length > 1;
                final wsSessions = sessions
                    .where((s) => s.workspaceId == activeWsId)
                    .toList();

                return ValueListenableBuilder<String?>(
                  valueListenable: _c.activeSessionIdNotifier,
                  builder: (context, activeId, _) {
                    return ValueListenableBuilder<Axis?>(
                      valueListenable: _c.splitAxisNotifier,
                      builder: (context, splitAxis, _) {
                        return Column(
                          children: [
                            if (showWorkspaceBar)
                              _WorkspaceBar(
                                workspaces: workspaces,
                                activeWorkspaceId: activeWsId,
                                renamingId: _renamingWorkspace
                                    ? _renamingWorkspaceId
                                    : null,
                                renameController: _renameController,
                                renameFocus: _renameFocus,
                                onSwitch: _c.switchWorkspace,
                                onAdd: () => _c.createWorkspace('New Workspace'),
                                onDoubleClick: _startRename,
                                onRenameCommit: _commitRename,
                                onDelete: _c.deleteWorkspace,
                              ),
                            TerminalTabBar(
                              sessions: wsSessions,
                              activeSessionId: activeId,
                              splitAxis: splitAxis,
                              onSelectSession: _c.setActiveSession,
                              onCloseSession: _closeSession,
                              onNewTab: widget.onNewTab,
                              onSplitHorizontal: _c.splitHorizontal,
                              onSplitVertical: _c.splitVertical,
                              onCloseSplit: _c.closeSplit,
                              onToggleSidebar: widget.snippetController != null
                                  ? () => setState(() => _sidebarOpen = !_sidebarOpen)
                                  : null,
                              sidebarOpen: _sidebarOpen,
                              onToggleSftpSplit: () => setState(() => _sftpSplitOpen = !_sftpSplitOpen),
                              sftpSplitOpen: _sftpSplitOpen,
                            ),
                            Expanded(
                              child: _buildMainArea(
                                wsSessions,
                                activeId: activeId,
                                splitAxis: splitAxis,
                              ),
                            ),
                            if (Platform.isIOS || Platform.isAndroid)
                              TerminalKeyboardToolbar(
                                onSendKey: (seq) =>
                                    _c.activeSession?.xterm?.paste(seq),
                              ),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildMainArea(
    List<TerminalSession> wsSessions, {
    required String? activeId,
    required Axis? splitAxis,
  }) {
    final terminalWithSidebar = Row(
      children: [
        Expanded(
          child: _buildTerminalArea(
            wsSessions,
            activeId: activeId,
            splitAxis: splitAxis,
          ),
        ),
        if (_sidebarOpen && widget.snippetController != null)
          TerminalRightSidebar(
            snippetController: widget.snippetController!,
            historyController: widget.historyController!,
            themeNotifier: widget.themeNotifier!,
            onThemeChanged: widget.onThemeChanged!,
            onPaste: widget.onPaste ?? (_) {},
            onRun: widget.onRun ?? (_) {},
          ),
      ],
    );

    if (!_sftpSplitOpen) return terminalWithSidebar;

    return ValueListenableBuilder<double>(
      valueListenable: _sftpRatioNotifier,
      builder: (context, ratio, _) => _SplitLayout(
        axis: Axis.horizontal,
        ratio: ratio,
        onRatioChanged: (r) => _sftpRatioNotifier.value = r,
        primary: terminalWithSidebar,
        secondary: SftpPage(terminalController: _c),
      ),
    );
  }

  Widget _buildTerminalArea(
    List<TerminalSession> wsSessions, {
    required String? activeId,
    required Axis? splitAxis,
  }) {
    return ValueListenableBuilder<String?>(
      valueListenable: _c.splitSessionIdNotifier,
      builder: (context, splitId, _) {
        final primary = _c.activeSession;
        final secondary = _c.splitSession;

        if (splitAxis == null || secondary == null) {
          return primary == null
              ? const _EmptyTerminalState()
              : _pane(primary, focused: true);
        }

        return ValueListenableBuilder<double>(
          valueListenable: _splitRatioNotifier,
          builder: (context, ratio, _) {
            return ValueListenableBuilder<int>(
              valueListenable: _c.activePaneNotifier,
              builder: (context, activePane, _) {
                return _SplitLayout(
                  axis: splitAxis,
                  ratio: ratio,
                  onRatioChanged: (r) => _splitRatioNotifier.value = r,
                  primary: GestureDetector(
                    onTap: () => _c.focusPane(0),
                    child: _pane(
                      primary!,
                      focused: activePane == 0,
                      showFocusBorder: true,
                    ),
                  ),
                  secondary: GestureDetector(
                    onTap: () => _c.focusPane(1),
                    child: _pane(
                      secondary,
                      focused: activePane == 1,
                      showFocusBorder: true,
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _showTerminalContextMenu(
      BuildContext context, Offset globalPosition, TerminalSession session) {
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;

    // Capture the copy handler synchronously — no BuildContext needed later.
    final doCopy = Actions.handler<CopySelectionTextIntent>(
        context, CopySelectionTextIntent.copy);

    showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(globalPosition.dx, globalPosition.dy, 0, 0),
        Offset.zero & overlay.size,
      ),
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.border),
      ),
      items: [
        _terminalMenuItem('copy', Icons.copy_outlined, 'Copy'),
        _terminalMenuItem('paste', Icons.content_paste_outlined, 'Paste'),
      ],
    ).then((value) {
      if (value == 'copy') {
        doCopy?.call();
      } else if (value == 'paste') {
        Clipboard.getData(Clipboard.kTextPlain).then((data) {
          if (data?.text != null) session.xterm?.paste(data!.text!);
        });
      }
    });
  }

  PopupMenuItem<String> _terminalMenuItem(
      String value, IconData icon, String label) {
    return PopupMenuItem<String>(
      value: value,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s16,
        vertical: AppSpacing.s8,
      ),
      child: Row(
        children: [
          Icon(icon, size: 15, color: AppColors.textMuted),
          const SizedBox(width: AppSpacing.s12),
          Text(label,
              style:
                  const TextStyle(color: AppColors.text, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _pane(
    TerminalSession session, {
    bool focused = true,
    bool showFocusBorder = false,
  }) {
    final child = TerminalWidget(
      key: ValueKey(session.id),
      session: session,
      fontSize: widget.fontSize,
      terminalTheme: widget.terminalTheme,
      isFocused: focused,
      onReconnect: () => _reconnect(session.id),
    );

    Widget result = showFocusBorder
        ? AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              border: focused
                  ? Border.all(
                      color: AppColors.accent.withValues(alpha: 0.35),
                      width: 1.5,
                    )
                  : Border.all(color: Colors.transparent, width: 1.5),
            ),
            child: child,
          )
        : child;

    if (Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
      result = GestureDetector(
        onSecondaryTapUp: (d) =>
            _showTerminalContextMenu(context, d.globalPosition, session),
        child: result,
      );
    }

    return result;
  }
}

// ── Split layout ─────────────────────────────────────────────────────────────

class _SplitLayout extends StatelessWidget {
  final Axis axis;
  final double ratio;
  final ValueChanged<double> onRatioChanged;
  final Widget primary;
  final Widget secondary;

  const _SplitLayout({
    required this.axis,
    required this.ratio,
    required this.onRatioChanged,
    required this.primary,
    required this.secondary,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final total = axis == Axis.horizontal
            ? constraints.maxWidth
            : constraints.maxHeight;
        final primarySize = total * ratio;

        final children = [
          SizedBox(
            width: axis == Axis.horizontal ? primarySize : null,
            height: axis == Axis.vertical ? primarySize : null,
            child: primary,
          ),
          _SplitDivider(
            axis: axis,
            onDrag: (delta) {
              final newRatio = (ratio + delta / total).clamp(0.15, 0.85);
              onRatioChanged(newRatio);
            },
          ),
          Expanded(child: secondary),
        ];

        return axis == Axis.horizontal
            ? Row(children: children)
            : Column(children: children);
      },
    );
  }
}

class _SplitDivider extends StatefulWidget {
  final Axis axis;
  final ValueChanged<double> onDrag;

  const _SplitDivider({required this.axis, required this.onDrag});

  @override
  State<_SplitDivider> createState() => _SplitDividerState();
}

class _SplitDividerState extends State<_SplitDivider> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isHorizontal = widget.axis == Axis.horizontal;
    return MouseRegion(
      cursor: isHorizontal
          ? SystemMouseCursors.resizeColumn
          : SystemMouseCursors.resizeRow,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onHorizontalDragUpdate:
            isHorizontal ? (d) => widget.onDrag(d.delta.dx) : null,
        onVerticalDragUpdate:
            !isHorizontal ? (d) => widget.onDrag(d.delta.dy) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: isHorizontal ? 4 : double.infinity,
          height: isHorizontal ? double.infinity : 4,
          color: _hovered
              ? AppColors.accent.withValues(alpha: 0.5)
              : AppColors.border,
        ),
      ),
    );
  }
}

// ── Workspace bar ────────────────────────────────────────────────────────────

class _WorkspaceBar extends StatelessWidget {
  final List<Workspace> workspaces;
  final String activeWorkspaceId;
  final String? renamingId;
  final TextEditingController renameController;
  final FocusNode renameFocus;
  final ValueChanged<String> onSwitch;
  final VoidCallback onAdd;
  final void Function(String id, String name) onDoubleClick;
  final VoidCallback onRenameCommit;
  final ValueChanged<String> onDelete;

  const _WorkspaceBar({
    required this.workspaces,
    required this.activeWorkspaceId,
    required this.renamingId,
    required this.renameController,
    required this.renameFocus,
    required this.onSwitch,
    required this.onAdd,
    required this.onDoubleClick,
    required this.onRenameCommit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s8,
                vertical: 4,
              ),
              children: workspaces.map((ws) {
                final active = ws.id == activeWorkspaceId;
                final renaming = ws.id == renamingId;
                return _WorkspacePill(
                  workspace: ws,
                  isActive: active,
                  isRenaming: renaming,
                  renameController: renameController,
                  renameFocus: renameFocus,
                  onTap: () => onSwitch(ws.id),
                  onDoubleClick: () => onDoubleClick(ws.id, ws.name),
                  onRenameCommit: onRenameCommit,
                  onDelete: ws.id == kDefaultWorkspaceId
                      ? null
                      : () => onDelete(ws.id),
                );
              }).toList(),
            ),
          ),
          _AddWorkspaceButton(onTap: onAdd),
          const SizedBox(width: AppSpacing.s8),
        ],
      ),
    );
  }
}

class _WorkspacePill extends StatefulWidget {
  final Workspace workspace;
  final bool isActive;
  final bool isRenaming;
  final TextEditingController renameController;
  final FocusNode renameFocus;
  final VoidCallback onTap;
  final VoidCallback onDoubleClick;
  final VoidCallback onRenameCommit;
  final VoidCallback? onDelete;

  const _WorkspacePill({
    required this.workspace,
    required this.isActive,
    required this.isRenaming,
    required this.renameController,
    required this.renameFocus,
    required this.onTap,
    required this.onDoubleClick,
    required this.onRenameCommit,
    this.onDelete,
  });

  @override
  State<_WorkspacePill> createState() => _WorkspacePillState();
}

class _WorkspacePillState extends State<_WorkspacePill> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    if (widget.isRenaming) {
      return Container(
        height: 24,
        width: 110,
        margin: const EdgeInsets.only(right: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(5),
        ),
        child: TextField(
          controller: widget.renameController,
          focusNode: widget.renameFocus,
          style: const TextStyle(color: AppColors.text, fontSize: 11.5),
          decoration: const InputDecoration(
            border: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.zero,
          ),
          onSubmitted: (_) => widget.onRenameCommit(),
          onEditingComplete: widget.onRenameCommit,
        ),
      );
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        onDoubleTap: widget.onDoubleClick,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 24,
          margin: const EdgeInsets.only(right: 4),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: widget.isActive
                ? AppColors.accent.withValues(alpha: 0.15)
                : _hovered
                ? AppColors.surface
                : Colors.transparent,
            border: Border.all(
              color: widget.isActive
                  ? AppColors.accent.withValues(alpha: 0.4)
                  : Colors.transparent,
            ),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.workspace.name,
                style: TextStyle(
                  color: widget.isActive ? AppColors.accent : AppColors.textMuted,
                  fontSize: 11.5,
                  fontWeight: widget.isActive
                      ? FontWeight.w600
                      : FontWeight.w400,
                ),
              ),
              if (widget.onDelete != null && _hovered) ...[
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: widget.onDelete,
                  child: Icon(
                    Icons.close,
                    size: 10,
                    color: AppColors.textMuted.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AddWorkspaceButton extends StatefulWidget {
  final VoidCallback onTap;
  const _AddWorkspaceButton({required this.onTap});

  @override
  State<_AddWorkspaceButton> createState() => _AddWorkspaceButtonState();
}

class _AddWorkspaceButtonState extends State<_AddWorkspaceButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: _hovered ? AppColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(5),
          ),
          child: Icon(
            Icons.add,
            size: 14,
            color: _hovered ? AppColors.text : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyTerminalState extends StatelessWidget {
  const _EmptyTerminalState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.terminal_outlined,
            size: 40,
            color: AppColors.textMuted.withValues(alpha: 0.25),
          ),
          const SizedBox(height: AppSpacing.s16),
          const Text(
            'No active sessions',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppSpacing.s8),
          const Text(
            'Connect to a host from the Hosts tab.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}
