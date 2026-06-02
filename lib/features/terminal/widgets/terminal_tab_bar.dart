import 'dart:io';

import 'package:flutter/material.dart';
import '../../../app/app_theme.dart';
import '../../../shared/widgets/os_icon.dart';
import '../models/terminal_session.dart';

class TerminalTabBar extends StatelessWidget {
  final List<TerminalSession> sessions;
  final String? activeSessionId;
  final Axis? splitAxis;
  final ValueChanged<String> onSelectSession;
  final ValueChanged<String> onCloseSession;
  final VoidCallback? onNewTab;
  final VoidCallback? onSplitHorizontal;
  final VoidCallback? onSplitVertical;
  final VoidCallback? onCloseSplit;
  final VoidCallback? onToggleSidebar;
  final bool sidebarOpen;
  final VoidCallback? onToggleSftpSplit;
  final bool sftpSplitOpen;

  const TerminalTabBar({
    super.key,
    required this.sessions,
    required this.activeSessionId,
    required this.onSelectSession,
    required this.onCloseSession,
    this.splitAxis,
    this.onNewTab,
    this.onSplitHorizontal,
    this.onSplitVertical,
    this.onCloseSplit,
    this.onToggleSidebar,
    this.sidebarOpen = false,
    this.onToggleSftpSplit,
    this.sftpSplitOpen = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                ...sessions.map(
                  (s) => _Tab(
                    session: s,
                    isActive: s.id == activeSessionId,
                    onTap: () => onSelectSession(s.id),
                    onClose: () => onCloseSession(s.id),
                  ),
                ),
                _NewTabButton(onTap: onNewTab),
              ],
            ),
          ),
          _SplitControls(
            splitAxis: splitAxis,
            onSplitHorizontal: onSplitHorizontal,
            onSplitVertical: onSplitVertical,
            onCloseSplit: onCloseSplit,
            onToggleSidebar: onToggleSidebar,
            sidebarOpen: sidebarOpen,
            onToggleSftpSplit: onToggleSftpSplit,
            sftpSplitOpen: sftpSplitOpen,
          ),
        ],
      ),
    );
  }
}

// ── Split controls ────────────────────────────────────────────────────────────

class _SplitControls extends StatelessWidget {
  final Axis? splitAxis;
  final VoidCallback? onSplitHorizontal;
  final VoidCallback? onSplitVertical;
  final VoidCallback? onCloseSplit;
  final VoidCallback? onToggleSidebar;
  final bool sidebarOpen;
  final VoidCallback? onToggleSftpSplit;
  final bool sftpSplitOpen;

  const _SplitControls({
    this.splitAxis,
    this.onSplitHorizontal,
    this.onSplitVertical,
    this.onCloseSplit,
    this.onToggleSidebar,
    this.sidebarOpen = false,
    this.onToggleSftpSplit,
    this.sftpSplitOpen = false,
  });

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS || Platform.isAndroid) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (splitAxis != null) ...[
            _SplitIconButton(
              icon: Icons.close,
              tooltip: 'Close split',
              onTap: onCloseSplit,
            ),
            const SizedBox(width: 2),
            Container(width: 1, height: 14, color: AppColors.border),
            const SizedBox(width: 2),
          ],
          _SplitIconButton(
            icon: Icons.vertical_split_outlined,
            tooltip: Platform.isMacOS ? 'Split right  ⌘D' : 'Split right  Ctrl D',
            onTap: onSplitHorizontal,
            active: splitAxis == Axis.horizontal,
          ),
          const SizedBox(width: 2),
          _SplitIconButton(
            icon: Icons.horizontal_split_outlined,
            tooltip: Platform.isMacOS ? 'Split down  ⌘⇧D' : 'Split down  Ctrl Shift D',
            onTap: onSplitVertical,
            active: splitAxis == Axis.vertical,
          ),
          if (onToggleSidebar != null) ...[
            const SizedBox(width: 2),
            Container(width: 1, height: 14, color: AppColors.border),
            const SizedBox(width: 2),
            _SplitIconButton(
              icon: Icons.code_outlined,
              tooltip: sidebarOpen ? 'Close panel' : 'Open panel',
              onTap: onToggleSidebar,
              active: sidebarOpen,
            ),
          ],
          const SizedBox(width: 2),
          Container(width: 1, height: 14, color: AppColors.border),
          const SizedBox(width: 2),
          _SplitIconButton(
            icon: Icons.folder_open_outlined,
            tooltip: sftpSplitOpen ? 'Close SFTP' : 'Open SFTP',
            onTap: onToggleSftpSplit,
            active: sftpSplitOpen,
          ),
        ],
      ),
    );
  }
}

class _SplitIconButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool active;

  const _SplitIconButton({
    required this.icon,
    required this.tooltip,
    this.onTap,
    this.active = false,
  });

  @override
  State<_SplitIconButton> createState() => _SplitIconButtonState();
}

class _SplitIconButtonState extends State<_SplitIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: widget.active
                  ? AppColors.accent.withValues(alpha: 0.15)
                  : _hovered
                  ? AppColors.border.withValues(alpha: 0.8)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Icon(
              widget.icon,
              size: 14,
              color: widget.active ? AppColors.accent : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

// ── New tab button ────────────────────────────────────────────────────────────

class _NewTabButton extends StatefulWidget {
  final VoidCallback? onTap;
  const _NewTabButton({this.onTap});

  @override
  State<_NewTabButton> createState() => _NewTabButtonState();
}

class _NewTabButtonState extends State<_NewTabButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'New connection',
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 36,
            height: 36,
            color: _hovered
                ? AppColors.border.withValues(alpha: 0.4)
                : Colors.transparent,
            child: const Icon(Icons.add, size: 14, color: AppColors.textMuted),
          ),
        ),
      ),
    );
  }
}

// ── Tab ───────────────────────────────────────────────────────────────────────

class _Tab extends StatefulWidget {
  final TerminalSession session;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onClose;

  const _Tab({
    required this.session,
    required this.isActive,
    required this.onTap,
    required this.onClose,
  });

  @override
  State<_Tab> createState() => _TabState();
}

class _TabState extends State<_Tab> {
  bool _hovered = false;

  Color get _statusColor => switch (widget.session.status) {
    SessionStatus.connecting => AppColors.textMuted.withValues(alpha: 0.5),
    SessionStatus.connected => const Color(0xFF4ADE80),
    SessionStatus.disconnected => AppColors.textMuted.withValues(alpha: 0.3),
    SessionStatus.error => const Color(0xFFF87171),
  };

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
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12),
          decoration: BoxDecoration(
            color: widget.isActive
                ? AppColors.background
                : _hovered
                ? AppColors.border.withValues(alpha: 0.3)
                : Colors.transparent,
            border: widget.isActive
                ? const Border(
                    top: BorderSide(color: AppColors.accent, width: 2),
                  )
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: _statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              if (widget.session.detectedOs != null) ...[
                OsIcon(os: widget.session.detectedOs!, size: 13),
                const SizedBox(width: AppSpacing.s4),
              ],
              Text(
                widget.session.host.name,
                style: TextStyle(
                  color: widget.isActive
                      ? AppColors.text
                      : AppColors.textMuted,
                  fontSize: 12.5,
                  fontWeight: widget.isActive
                      ? FontWeight.w500
                      : FontWeight.w400,
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              GestureDetector(
                onTap: widget.onClose,
                behavior: HitTestBehavior.opaque,
                child: AnimatedOpacity(
                  opacity: _hovered || widget.isActive || (Platform.isIOS || Platform.isAndroid) ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 120),
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(
                      Icons.close,
                      size: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
