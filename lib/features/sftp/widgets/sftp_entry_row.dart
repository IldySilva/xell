import 'package:material_ui/material_ui.dart';
import '../../../app/app_theme.dart';
import '../models/sftp_entry.dart';

class SftpEntryRow extends StatefulWidget {
  final SftpEntry entry;
  final VoidCallback onTap;
  final VoidCallback onDownload;
  final VoidCallback? onEdit;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const SftpEntryRow({
    super.key,
    required this.entry,
    required this.onTap,
    required this.onDownload,
    this.onEdit,
    required this.onRename,
    required this.onDelete,
  });

  @override
  State<SftpEntryRow> createState() => _SftpEntryRowState();
}

class _SftpEntryRowState extends State<SftpEntryRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: entry.isDirectory
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: entry.isDirectory ? widget.onTap : null,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s16,
            vertical: AppSpacing.s8,
          ),
          color: _hovered
              ? AppColors.border.withValues(alpha: 0.3)
              : Colors.transparent,
          child: Row(
            children: [
              Icon(
                entry.isDirectory
                    ? Icons.folder_outlined
                    : Icons.insert_drive_file_outlined,
                size: 15,
                color: entry.isDirectory
                    ? AppColors.accent.withValues(alpha: 0.8)
                    : AppColors.textMuted,
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Text(
                  entry.name,
                  style: TextStyle(
                    color: entry.isDirectory
                        ? AppColors.text
                        : AppColors.text.withValues(alpha: 0.85),
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_hovered) ...[
                if (!entry.isDirectory) ...[
                  _ActionButton(
                    icon: Icons.download_outlined,
                    tooltip: 'Download',
                    onTap: widget.onDownload,
                  ),
                  if (widget.onEdit != null)
                    _ActionButton(
                      icon: Icons.edit_outlined,
                      tooltip: 'Edit',
                      onTap: widget.onEdit!,
                    ),
                ],
                _ActionButton(
                  icon: Icons.drive_file_rename_outline,
                  tooltip: 'Rename',
                  onTap: widget.onRename,
                ),
                _ActionButton(
                  icon: Icons.delete_outline,
                  tooltip: 'Delete',
                  onTap: widget.onDelete,
                  danger: true,
                ),
              ] else ...[
                if (!entry.isDirectory && entry.displaySize.isNotEmpty)
                  Text(
                    entry.displaySize,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11.5,
                    ),
                  ),
                if (entry.modifiedAt != null) ...[
                  const SizedBox(width: AppSpacing.s16),
                  Text(
                    _formatDate(entry.modifiedAt!),
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool danger;

  const _ActionButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 600),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s8,
            vertical: AppSpacing.s4,
          ),
          child: Icon(
            icon,
            size: 14,
            color: danger ? const Color(0xFFF87171) : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}
