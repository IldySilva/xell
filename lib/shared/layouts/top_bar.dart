import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:window_manager/window_manager.dart';
import '../../app/app_theme.dart';

const _topBarHeight = 52.0;

class TopBar extends StatelessWidget {
  final VoidCallback onCommandPaletteTap;
  final VoidCallback onSettingsTap;
  final bool isFullScreen;
  final VoidCallback onToggleFullscreen;

  /// Null means no active session. Non-null shows the connected hostname.
  final String? activeSession;

  const TopBar({
    super.key,
    required this.onCommandPaletteTap,
    required this.onSettingsTap,
    required this.isFullScreen,
    required this.onToggleFullscreen,
    this.activeSession,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop =
        Platform.isMacOS || Platform.isLinux || Platform.isWindows;
    final bar = Container(
      height: _topBarHeight,
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
      child: Row(
        children: [
          _SessionStatus(hostname: activeSession),
          const Spacer(),
          _CommandPaletteButton(onTap: onCommandPaletteTap),
          const SizedBox(width: AppSpacing.s8),
          _TopBarIconButton(
            icon: Icons.settings_outlined,
            tooltip: 'Settings',
            onTap: onSettingsTap,
          ),
          if (isDesktop) ...[
            const SizedBox(width: AppSpacing.s4),
            _TopBarIconButton(
              icon: isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
              tooltip: isFullScreen ? 'Exit fullscreen' : 'Enter fullscreen',
              onTap: onToggleFullscreen,
            ),
          ],
          if (Platform.isLinux || Platform.isWindows) ...[
            const SizedBox(width: AppSpacing.s8),
            const _WindowControls(),
          ],
        ],
      ),
    );
    return isDesktop ? DragToMoveArea(child: bar) : bar;
  }
}

class _SessionStatus extends StatelessWidget {
  final String? hostname;

  const _SessionStatus({this.hostname});

  @override
  Widget build(BuildContext context) {
    final connected = hostname != null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: connected
                ? const Color(0xFF4ADE80) // green
                : AppColors.textMuted.withValues(alpha: 0.4),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          connected ? hostname! : 'No active session',
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _CommandPaletteButton extends StatefulWidget {
  final VoidCallback onTap;

  const _CommandPaletteButton({required this.onTap});

  @override
  State<_CommandPaletteButton> createState() => _CommandPaletteButtonState();
}

class _CommandPaletteButtonState extends State<_CommandPaletteButton> {
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
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s12,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: _hovered ? AppColors.surfaceElevated : AppColors.surface,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.search, size: 13, color: AppColors.textMuted),
              const SizedBox(width: AppSpacing.s8),
              const Text(
                'Search or jump to...',
                style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
              ),
              const SizedBox(width: AppSpacing.s12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  Platform.isMacOS ? '⌘K' : 'Ctrl K',
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.textMuted,
                    letterSpacing: 0.2,
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

class _TopBarIconButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _TopBarIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  State<_TopBarIconButton> createState() => _TopBarIconButtonState();
}

class _TopBarIconButtonState extends State<_TopBarIconButton> {
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
            duration: const Duration(milliseconds: 120),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _hovered
                  ? AppColors.border.withValues(alpha: 0.6)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              widget.icon,
              size: 16,
              color: AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _WindowControls extends StatefulWidget {
  const _WindowControls();

  @override
  State<_WindowControls> createState() => _WindowControlsState();
}

class _WindowControlsState extends State<_WindowControls> with WindowListener {
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    windowManager.isMaximized().then((v) {
      if (mounted) setState(() => _isMaximized = v);
    });
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowMaximize() => setState(() => _isMaximized = true);

  @override
  void onWindowUnmaximize() => setState(() => _isMaximized = false);

  Future<void> _toggleMaximize() async {
    if (_isMaximized) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _WinButton(
          icon: Icons.remove,
          tooltip: 'Minimize',
          onTap: () => windowManager.minimize(),
        ),
        const SizedBox(width: 2),
        _WinButton(
          icon: _isMaximized ? Icons.filter_none : Icons.crop_square,
          tooltip: _isMaximized ? 'Restore' : 'Maximize',
          onTap: _toggleMaximize,
        ),
        const SizedBox(width: 2),
        _WinButton(
          icon: Icons.close,
          tooltip: 'Close',
          onTap: () => windowManager.close(),
          isClose: true,
        ),
      ],
    );
  }
}

class _WinButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool isClose;

  const _WinButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.isClose = false,
  });

  @override
  State<_WinButton> createState() => _WinButtonState();
}

class _WinButtonState extends State<_WinButton> {
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
            duration: const Duration(milliseconds: 120),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _hovered
                  ? (widget.isClose
                      ? const Color(0xFFE81123)
                      : AppColors.border.withValues(alpha: 0.6))
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              widget.icon,
              size: 14,
              color: _hovered && widget.isClose
                  ? Colors.white
                  : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}
