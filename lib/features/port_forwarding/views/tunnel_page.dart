import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import '../../../app/app_theme.dart';
import '../../../core/exceptions.dart';
import '../../terminal/controllers/terminal_controller.dart';
import '../../terminal/models/terminal_session.dart';
import '../controllers/tunnel_controller.dart';
import '../models/tunnel_entry.dart';
import 'tunnel_form_dialog.dart';

class TunnelPage extends StatelessWidget {
  final TunnelController controller;
  final TerminalController terminalController;

  const TunnelPage({
    super.key,
    required this.controller,
    required this.terminalController,
  });

  TerminalSession? get _activeSession => terminalController.activeSession;

  Future<void> _openForm(BuildContext context) async {
    final session = _activeSession;
    if (session == null ||
        session.status != SessionStatus.connected ||
        session.client == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Connect to a host first.',
            style: TextStyle(color: AppColors.text, fontSize: 13),
          ),
          backgroundColor: AppColors.surface,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: AppColors.border),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    final result = await showDialog<TunnelFormResult>(
      context: context,
      builder: (_) => const TunnelFormDialog(),
    );
    if (result == null) return;

    try {
      await controller.create(
        client: session.client!,
        sessionId: session.id,
        localPort: result.localPort,
        remoteHost: result.remoteHost,
        remotePort: result.remotePort,
        label: result.label,
      );
    } on SshException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.message,
              style: const TextStyle(color: AppColors.text, fontSize: 13),
            ),
            backgroundColor: AppColors.surface,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: AppColors.border),
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<TunnelEntry>>(
      valueListenable: controller.tunnelsNotifier,
      builder: (context, tunnels, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TunnelHeader(
              count: tunnels.length,
              onAdd: () => _openForm(context),
            ),
            const Divider(height: 1),
            Expanded(
              child: tunnels.isEmpty
                  ? _EmptyState(onAdd: () => _openForm(context))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.s8,
                      ),
                      itemCount: tunnels.length,
                      itemBuilder: (context, i) => _TunnelRow(
                        entry: tunnels[i],
                        onClose: () => controller.close(tunnels[i].id),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _TunnelHeader extends StatelessWidget {
  final int count;
  final VoidCallback onAdd;

  const _TunnelHeader({required this.count, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s24,
        AppSpacing.s24,
        AppSpacing.s24,
        AppSpacing.s12,
      ),
      child: Row(
        children: [
          const Text(
            'Tunnels',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (count > 0) ...[
            const SizedBox(width: AppSpacing.s8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
          const Spacer(),
          _AddButton(onTap: onAdd),
        ],
      ),
    );
  }
}

class _AddButton extends StatefulWidget {
  final VoidCallback onTap;
  const _AddButton({required this.onTap});

  @override
  State<_AddButton> createState() => _AddButtonState();
}

class _AddButtonState extends State<_AddButton> {
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
            color: _hovered
                ? AppColors.accent
                : AppColors.accent.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(7),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, size: 14, color: Colors.white),
              SizedBox(width: 4),
              Text(
                'New Tunnel',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
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

// ── Tunnel row ────────────────────────────────────────────────────────────────

class _TunnelRow extends StatefulWidget {
  final TunnelEntry entry;
  final VoidCallback onClose;

  const _TunnelRow({required this.entry, required this.onClose});

  @override
  State<_TunnelRow> createState() => _TunnelRowState();
}

class _TunnelRowState extends State<_TunnelRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s16,
          vertical: 2,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s12,
          vertical: AppSpacing.s12,
        ),
        decoration: BoxDecoration(
          color: _hovered
              ? AppColors.surface.withValues(alpha: 0.8)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            // Active indicator dot
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: Color(0xFF4ADE80),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.displayLabel,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      _PortChip(label: entry.localAddress),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: AppSpacing.s8),
                        child: Icon(
                          Icons.arrow_forward,
                          size: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                      _PortChip(label: '${entry.remoteHost}:${entry.remotePort}'),
                    ],
                  ),
                ],
              ),
            ),
            AnimatedOpacity(
              opacity: _hovered ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 120),
              child: Row(
                children: [
                  _CopyButton(address: entry.localAddress),
                  const SizedBox(width: AppSpacing.s4),
                  _CloseButton(onTap: widget.onClose),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PortChip extends StatelessWidget {
  final String label;
  const _PortChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 11,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}

class _CopyButton extends StatelessWidget {
  final String address;
  const _CopyButton({required this.address});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Copy local address',
      waitDuration: const Duration(milliseconds: 600),
      child: GestureDetector(
        onTap: () {
          Clipboard.setData(ClipboardData(text: address));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Copied $address',
                style: const TextStyle(color: AppColors.text, fontSize: 13),
              ),
              backgroundColor: AppColors.surface,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: AppColors.border),
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        },
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppColors.border.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Icon(
            Icons.copy_outlined,
            size: 13,
            color: AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CloseButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Close tunnel',
      waitDuration: const Duration(milliseconds: 600),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: const Color(0xFFF87171).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Icon(
            Icons.close,
            size: 13,
            color: Color(0xFFF87171),
          ),
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.alt_route_outlined,
            size: 40,
            color: AppColors.textMuted.withValues(alpha: 0.25),
          ),
          const SizedBox(height: AppSpacing.s16),
          const Text(
            'No active tunnels',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppSpacing.s8),
          const Text(
            'Forward a remote port to your local machine.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
          ),
          const SizedBox(height: AppSpacing.s24),
          GestureDetector(
            onTap: onAdd,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s16,
                vertical: AppSpacing.s8,
              ),
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(7),
              ),
              child: const Text(
                'New Tunnel',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
