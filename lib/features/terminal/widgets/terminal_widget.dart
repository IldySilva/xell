import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart' hide TerminalController;
import 'package:xterm/ui.dart' as xterm_ui show TerminalController;
import '../../../app/app_theme.dart';
import '../models/terminal_session.dart';

// Fallback used when no theme is provided.
const _kDefaultTheme = TerminalTheme(
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
);

class TerminalWidget extends StatelessWidget {
  final TerminalSession session;
  final double fontSize;
  final TerminalTheme terminalTheme;
  final VoidCallback? onReconnect;
  final bool isFocused;

  const TerminalWidget({
    super.key,
    required this.session,
    this.fontSize = 12,
    this.terminalTheme = _kDefaultTheme,
    this.onReconnect,
    this.isFocused = true,
  });

  @override
  Widget build(BuildContext context) {
    return switch (session.status) {
      SessionStatus.connecting => _ConnectingView(host: session.host.hostname),
      SessionStatus.connected => _ConnectedView(
        session: session,
        fontSize: fontSize,
        terminalTheme: terminalTheme,
        autofocus: isFocused,
      ),
      SessionStatus.disconnected => _EndedView(
        host: session.host.hostname,
        onReconnect: onReconnect,
      ),
      SessionStatus.error => _ErrorView(
        message: session.errorMessage ?? 'Unknown error',
        onReconnect: onReconnect,
      ),
    };
  }
}

class _ConnectedView extends StatefulWidget {
  final TerminalSession session;
  final double fontSize;
  final TerminalTheme terminalTheme;
  final bool autofocus;

  const _ConnectedView({
    required this.session,
    required this.fontSize,
    required this.terminalTheme,
    this.autofocus = true,
  });

  @override
  State<_ConnectedView> createState() => _ConnectedViewState();
}

class _ConnectedViewState extends State<_ConnectedView> {
  final _xtermController = xterm_ui.TerminalController();
  late TerminalStyle _textStyle;

  @override
  void initState() {
    super.initState();
    _textStyle = TerminalStyle(
        fontSize: widget.fontSize, fontFamily: 'monospace');
  }

  @override
  void didUpdateWidget(_ConnectedView old) {
    super.didUpdateWidget(old);
    if (old.fontSize != widget.fontSize) {
      _textStyle = TerminalStyle(
          fontSize: widget.fontSize, fontFamily: 'monospace');
    }
  }

  @override
  void dispose() {
    _xtermController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final terminal = widget.session.xterm!;
    return Shortcuts(
      shortcuts: defaultTerminalShortcuts,
      child: Actions(
        actions: {
          CopySelectionTextIntent: CallbackAction<CopySelectionTextIntent>(
            onInvoke: (_) async {
              final sel = _xtermController.selection;
              if (sel == null) return null;
              final text = terminal.buffer.getText(sel);
              await Clipboard.setData(ClipboardData(text: text));
              return null;
            },
          ),
          PasteTextIntent: CallbackAction<PasteTextIntent>(
            onInvoke: (_) async {
              final data = await Clipboard.getData(Clipboard.kTextPlain);
              final text = data?.text;
              if (text != null) {
                terminal.paste(text);
                _xtermController.clearSelection();
              }
              return null;
            },
          ),
          SelectAllTextIntent: CallbackAction<SelectAllTextIntent>(
            onInvoke: (_) {
              _xtermController.setSelection(
                terminal.buffer.createAnchor(
                    0, terminal.buffer.height - terminal.viewHeight),
                terminal.buffer.createAnchor(
                    terminal.viewWidth, terminal.buffer.height - 1),
                mode: SelectionMode.line,
              );
              return null;
            },
          ),
        },
        child: RepaintBoundary(
          child: TerminalView(
            terminal,
            controller: _xtermController,
            theme: widget.terminalTheme,
            textStyle: _textStyle,
            autofocus: widget.autofocus,
            padding: const EdgeInsets.all(AppSpacing.s8),
          ),
        ),
      ),
    );
  }
}

class _ConnectingView extends StatelessWidget {
  final String host;
  const _ConnectingView({required this.host});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            host,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppSpacing.s8),
          const Text(
            'Connecting...',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: AppSpacing.s32),
          SizedBox(
            width: 220,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: const LinearProgressIndicator(
                backgroundColor: AppColors.border,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
                minHeight: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback? onReconnect;

  const _ErrorView({required this.message, this.onReconnect});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 32, color: Color(0xFFF87171)),
          const SizedBox(height: AppSpacing.s16),
          const Text(
            'Connection failed',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppSpacing.s8),
          Text(
            message,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5),
            textAlign: TextAlign.center,
          ),
          if (onReconnect != null) ...[
            const SizedBox(height: AppSpacing.s24),
            _ReconnectButton(onTap: onReconnect!),
          ],
        ],
      ),
    );
  }
}

class _EndedView extends StatelessWidget {
  final String host;
  final VoidCallback? onReconnect;

  const _EndedView({required this.host, this.onReconnect});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.terminal_outlined,
            size: 32,
            color: AppColors.textMuted.withValues(alpha: 0.3),
          ),
          const SizedBox(height: AppSpacing.s16),
          Text(
            'Session ended — $host',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          if (onReconnect != null) ...[
            const SizedBox(height: AppSpacing.s24),
            _ReconnectButton(onTap: onReconnect!),
          ],
        ],
      ),
    );
  }
}

class _ReconnectButton extends StatefulWidget {
  final VoidCallback onTap;
  const _ReconnectButton({required this.onTap});

  @override
  State<_ReconnectButton> createState() => _ReconnectButtonState();
}

class _ReconnectButtonState extends State<_ReconnectButton> {
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
            horizontal: AppSpacing.s16,
            vertical: AppSpacing.s8,
          ),
          decoration: BoxDecoration(
            color: _hovered
                ? AppColors.accent.withValues(alpha: 0.15)
                : AppColors.accent.withValues(alpha: 0.08),
            border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
            borderRadius: BorderRadius.circular(7),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.refresh, size: 13, color: AppColors.accent),
              SizedBox(width: AppSpacing.s8),
              Text(
                'Reconnect',
                style: TextStyle(
                  color: AppColors.accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
