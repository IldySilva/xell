import 'dart:io';

import 'package:flutter/material.dart';
import '../../../app/app_theme.dart';
import '../../../shared/widgets/os_icon.dart';
import '../models/ssh_host.dart';

class HostRow extends StatefulWidget {
  final SshHost host;
  final bool isKeyboardFocused;
  final VoidCallback onConnect;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleFavorite;

  const HostRow({
    super.key,
    required this.host,
    required this.onConnect,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleFavorite,
    this.isKeyboardFocused = false,
  });

  @override
  State<HostRow> createState() => _HostRowState();
}

class _HostRowState extends State<HostRow> {
  bool _hovered = false;

  SshHost get host => widget.host;

  void _showDesktopContextMenu(BuildContext context, Offset globalPosition) {
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
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
        _menuItem('connect', Icons.terminal_outlined, 'Connect',
            color: AppColors.accent),
        _menuItem('edit', Icons.edit_outlined, 'Edit'),
        _menuItem(
          'favorite',
          host.isFavorite ? Icons.star : Icons.star_border,
          host.isFavorite ? 'Remove Favorite' : 'Add to Favorites',
        ),
        const PopupMenuDivider(height: 1),
        _menuItem('delete', Icons.delete_outline, 'Delete',
            color: const Color(0xFFF87171)),
      ],
    ).then((value) {
      switch (value) {
        case 'connect':
          widget.onConnect();
        case 'edit':
          widget.onEdit();
        case 'favorite':
          widget.onToggleFavorite();
        case 'delete':
          widget.onDelete();
      }
    });
  }

  PopupMenuItem<String> _menuItem(
    String value,
    IconData icon,
    String label, {
    Color color = AppColors.text,
  }) {
    return PopupMenuItem<String>(
      value: value,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s16,
        vertical: AppSpacing.s8,
      ),
      child: Row(
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: AppSpacing.s12),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 13),
          ),
        ],
      ),
    );
  }

  void _showMobileMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (_) => _MobileHostMenu(
        host: host,
        onConnect: () { Navigator.pop(context); widget.onConnect(); },
        onEdit: () { Navigator.pop(context); widget.onEdit(); },
        onDelete: () { Navigator.pop(context); widget.onDelete(); },
        onToggleFavorite: () { Navigator.pop(context); widget.onToggleFavorite(); },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Platform.isIOS || Platform.isAndroid;
    return MouseRegion(
      onEnter: isMobile ? null : (_) => setState(() => _hovered = true),
      onExit: isMobile ? null : (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onConnect,
        onLongPress: isMobile ? () => _showMobileMenu(context) : null,
        onSecondaryTapUp: isMobile
            ? null
            : (d) => _showDesktopContextMenu(context, d.globalPosition),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s8,
            vertical: 1,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s12,
            vertical: AppSpacing.s12,
          ),
          decoration: BoxDecoration(
            color: widget.isKeyboardFocused
                ? AppColors.accent.withValues(alpha: 0.08)
                : _hovered
                ? AppColors.surface.withValues(alpha: 0.8)
                : Colors.transparent,
            border: widget.isKeyboardFocused
                ? Border.all(color: AppColors.accent.withValues(alpha: 0.3))
                : null,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              _StatusDot(connected: false),
              const SizedBox(width: AppSpacing.s12),
              if (host.detectedOs != null) ...[
                OsIcon(os: host.detectedOs!, size: 16),
                const SizedBox(width: AppSpacing.s8),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          host.name,
                          style: const TextStyle(
                            color: AppColors.text,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s12),
                        Text(
                          '${host.username}@${host.hostname}:${host.port}',
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    if (host.tags.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 4,
                        children: host.tags
                            .map((t) => _TagChip(label: t))
                            .toList(),
                      ),
                    ],
                    if (host.lastConnectedAt != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        _formatAge(host.lastConnectedAt!),
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (isMobile)
                GestureDetector(
                  onTap: () => _showMobileMenu(context),
                  behavior: HitTestBehavior.opaque,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.s8,
                      vertical: AppSpacing.s4,
                    ),
                    child: Icon(
                      Icons.more_horiz,
                      size: 18,
                      color: AppColors.textMuted,
                    ),
                  ),
                )
              else
                AnimatedOpacity(
                  opacity: _hovered ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 120),
                  child: Row(
                    children: [
                      _RowIconButton(
                        icon: Icons.edit_outlined,
                        tooltip: 'Edit',
                        onTap: widget.onEdit,
                      ),
                      const SizedBox(width: 2),
                      _RowIconButton(
                        icon: Icons.delete_outline,
                        tooltip: 'Delete',
                        onTap: widget.onDelete,
                        danger: true,
                      ),
                      const SizedBox(width: AppSpacing.s8),
                    ],
                  ),
                ),
              _FavoriteButton(
                isFavorite: host.isFavorite,
                onTap: widget.onToggleFavorite,
              ),
              const SizedBox(width: AppSpacing.s8),
              AnimatedOpacity(
                opacity: isMobile ? 1.0 : (_hovered ? 1.0 : 0.3),
                duration: const Duration(milliseconds: 120),
                child: _ConnectButton(onTap: widget.onConnect),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatAge(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    return 'Long ago';
  }
}

class _StatusDot extends StatelessWidget {
  final bool connected;
  const _StatusDot({required this.connected});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        color: connected
            ? const Color(0xFF4ADE80)
            : AppColors.textMuted.withValues(alpha: 0.35),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;
  const _TagChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.border,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 10.5,
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}

class _FavoriteButton extends StatelessWidget {
  final bool isFavorite;
  final VoidCallback onTap;
  const _FavoriteButton({required this.isFavorite, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(
          isFavorite ? Icons.star : Icons.star_border,
          size: 15,
          color: isFavorite
              ? AppColors.accent
              : AppColors.textMuted.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}

class _ConnectButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ConnectButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Icon(
          Icons.arrow_forward,
          size: 14,
          color: AppColors.accent,
        ),
      ),
    );
  }
}

class _RowIconButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool danger;

  const _RowIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.danger = false,
  });

  @override
  State<_RowIconButton> createState() => _RowIconButtonState();
}

class _RowIconButtonState extends State<_RowIconButton> {
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
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: _hovered
                  ? (widget.danger
                        ? const Color(0xFFF87171).withValues(alpha: 0.12)
                        : AppColors.border.withValues(alpha: 0.8))
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              widget.icon,
              size: 14,
              color: _hovered && widget.danger
                  ? const Color(0xFFF87171)
                  : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Mobile context menu ───────────────────────────────────────────────────────

class _MobileHostMenu extends StatelessWidget {
  final SshHost host;
  final VoidCallback onConnect;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleFavorite;

  const _MobileHostMenu({
    required this.host,
    required this.onConnect,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s24, AppSpacing.s8, AppSpacing.s24, AppSpacing.s16,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      host.name,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '${host.username}@${host.hostname}',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            _MenuAction(
              icon: Icons.terminal_outlined,
              label: 'Connect',
              color: AppColors.accent,
              onTap: onConnect,
            ),
            _MenuAction(
              icon: Icons.edit_outlined,
              label: 'Edit',
              onTap: onEdit,
            ),
            _MenuAction(
              icon: host.isFavorite ? Icons.star : Icons.star_border,
              label: host.isFavorite ? 'Remove from Favorites' : 'Add to Favorites',
              onTap: onToggleFavorite,
            ),
            const Divider(height: 1, color: AppColors.border),
            _MenuAction(
              icon: Icons.delete_outline,
              label: 'Delete',
              color: const Color(0xFFF87171),
              onTap: onDelete,
            ),
            const SizedBox(height: AppSpacing.s8),
          ],
        ),
      ),
    );
  }
}

class _MenuAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  const _MenuAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = AppColors.text,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s24,
          vertical: AppSpacing.s16,
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: AppSpacing.s16),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
