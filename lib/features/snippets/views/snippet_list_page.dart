import 'dart:io';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import '../../../../app/app_theme.dart';
import '../controllers/snippet_controller.dart';
import '../models/snippet.dart';
import 'snippet_form_dialog.dart';

class SnippetListPage extends StatefulWidget {
  final SnippetController controller;
  final void Function(String command)? onRun;

  const SnippetListPage({
    super.key,
    required this.controller,
    this.onRun,
  });

  @override
  State<SnippetListPage> createState() => _SnippetListPageState();
}

class _SnippetListPageState extends State<SnippetListPage> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Snippet> _filtered(List<Snippet> all) {
    if (_query.isEmpty) return all;
    final q = _query.toLowerCase();
    return all.where((s) {
      return s.title.toLowerCase().contains(q) ||
          s.command.toLowerCase().contains(q) ||
          s.tags.any((t) => t.toLowerCase().contains(q));
    }).toList();
  }

  void _openForm([Snippet? existing]) {
    if (Platform.isIOS || Platform.isAndroid) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => SnippetFormDialog(
          controller: widget.controller,
          existing: existing,
        ),
      ));
    } else {
      showDialog<void>(
        context: context,
        builder: (_) => SnippetFormDialog(
          controller: widget.controller,
          existing: existing,
        ),
      );
    }
  }

  Future<void> _confirmDelete(Snippet snippet) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppColors.border),
        ),
        title: const Text(
          'Delete snippet?',
          style: TextStyle(color: AppColors.text, fontSize: 15),
        ),
        content: Text(
          '"${snippet.title}" will be permanently removed.',
          style:
              const TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete',
                style: TextStyle(color: Color(0xFFF87171))),
          ),
        ],
      ),
    );
    if (confirmed == true) await widget.controller.delete(snippet.id);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Header ──────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              const Text(
                'Snippets',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              _AddButton(onTap: () => _openForm()),
            ],
          ),
        ),
        // ── Search ──────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _search,
            onChanged: (v) => setState(() => _query = v),
            style:
                const TextStyle(color: AppColors.text, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search snippets...',
              hintStyle: const TextStyle(
                  color: AppColors.textMuted, fontSize: 13),
              prefixIcon: const Icon(Icons.search,
                  size: 16, color: AppColors.textMuted),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(7),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(7),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(7),
                borderSide: const BorderSide(
                    color: AppColors.accent, width: 1.5),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ),
        // ── List ────────────────────────────────────────────────────────
        Expanded(
          child: ValueListenableBuilder<List<Snippet>>(
            valueListenable: widget.controller.snippetsNotifier,
            builder: (context, all, _) {
              final snippets = _filtered(all);
              if (snippets.isEmpty) {
                return Center(
                  child: Text(
                    all.isEmpty
                        ? 'No snippets yet.\nTap + to create one.'
                        : 'No results for "$_query".',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                    ),
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                itemCount: snippets.length,
                separatorBuilder: (_, _) => const SizedBox(height: 6),
                itemBuilder: (_, i) => _SnippetCard(
                  snippet: snippets[i],
                  onRun: widget.onRun != null
                      ? () => widget.onRun!(snippets[i].command)
                      : null,
                  onEdit: () => _openForm(snippets[i]),
                  onDelete: () => _confirmDelete(snippets[i]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Snippet card ──────────────────────────────────────────────────────────────

class _SnippetCard extends StatefulWidget {
  final Snippet snippet;
  final VoidCallback? onRun;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SnippetCard({
    required this.snippet,
    this.onRun,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_SnippetCard> createState() => _SnippetCardState();
}

class _SnippetCardState extends State<_SnippetCard> {
  bool _hovered = false;
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.snippet.command));
    setState(() => _copied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: _hovered ? AppColors.surfaceElevated : AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.snippet.title,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (_hovered) ...[
                  if (widget.onRun != null)
                    _IconBtn(
                      icon: Icons.play_arrow_rounded,
                      tooltip: 'Run in terminal',
                      color: AppColors.accent,
                      onTap: widget.onRun!,
                    ),
                  _IconBtn(
                    icon: _copied ? Icons.check : Icons.copy_outlined,
                    tooltip: _copied ? 'Copied!' : 'Copy command',
                    onTap: _copy,
                  ),
                  _IconBtn(
                    icon: Icons.edit_outlined,
                    tooltip: 'Edit',
                    onTap: widget.onEdit,
                  ),
                  _IconBtn(
                    icon: Icons.delete_outline,
                    tooltip: 'Delete',
                    color: const Color(0xFFF87171),
                    onTap: widget.onDelete,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                widget.snippet.command,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (widget.snippet.description != null) ...[
              const SizedBox(height: 6),
              Text(
                widget.snippet.description!,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11.5,
                ),
              ),
            ],
            if (widget.snippet.tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: widget.snippet.tags
                    .map((t) => _Tag(label: t))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color color;

  const _IconBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color = AppColors.textMuted,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  const _Tag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.accent,
          fontSize: 10.5,
          fontWeight: FontWeight.w500,
        ),
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
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _hovered
                ? AppColors.accent.withValues(alpha: 0.15)
                : AppColors.accent.withValues(alpha: 0.08),
            border: Border.all(
                color: AppColors.accent.withValues(alpha: 0.4)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, size: 14, color: AppColors.accent),
              SizedBox(width: 4),
              Text(
                'New snippet',
                style: TextStyle(
                  color: AppColors.accent,
                  fontSize: 12,
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
