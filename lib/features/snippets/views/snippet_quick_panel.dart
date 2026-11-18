import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import '../../../../app/app_theme.dart';
import '../controllers/snippet_controller.dart';
import '../models/snippet.dart';
import 'snippet_form_dialog.dart';

/// Right-side sheet panel shown in the terminal tab bar.
/// Shows all snippets with search, paste, paste+run, and create actions.
void showSnippetPanel(
  BuildContext context, {
  required SnippetController snippetController,
  required void Function(String command) onPaste,
  required void Function(String command) onRun,
}) {
  showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close snippets',
    barrierColor: Colors.black.withValues(alpha: 0.35),
    transitionDuration: const Duration(milliseconds: 200),
    transitionBuilder: (ctx, anim, _, child) {
      final slide = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(slide),
        child: child,
      );
    },
    pageBuilder: (ctx, _, _) => Align(
      alignment: Alignment.centerRight,
      child: _SnippetPanel(
        controller: snippetController,
        onPaste: onPaste,
        onRun: onRun,
        onClose: () => Navigator.of(ctx).pop(),
      ),
    ),
  );
}

class _SnippetPanel extends StatefulWidget {
  final SnippetController controller;
  final void Function(String) onPaste;
  final void Function(String) onRun;
  final VoidCallback onClose;

  const _SnippetPanel({
    required this.controller,
    required this.onPaste,
    required this.onRun,
    required this.onClose,
  });

  @override
  State<_SnippetPanel> createState() => _SnippetPanelState();
}

class _SnippetPanelState extends State<_SnippetPanel> {
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

  void _openCreateForm() {
    showDialog<void>(
      context: context,
      builder: (_) => SnippetFormDialog(controller: widget.controller),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 380,
        height: double.infinity,
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(left: BorderSide(color: AppColors.border)),
        ),
        child: Column(
          children: [
            _PanelHeader(
              onClose: widget.onClose,
              onNewSnippet: _openCreateForm,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: TextField(
                controller: _search,
                autofocus: true,
                onChanged: (v) => setState(() => _query = v),
                style:
                    const TextStyle(color: AppColors.text, fontSize: 12.5),
                decoration: InputDecoration(
                  hintText: 'Search snippets…',
                  hintStyle: const TextStyle(
                      color: AppColors.textMuted, fontSize: 12.5),
                  prefixIcon: const Icon(Icons.search,
                      size: 14, color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(7),
                    borderSide:
                        const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(7),
                    borderSide:
                        const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(7),
                    borderSide: const BorderSide(
                        color: AppColors.accent, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 9),
                ),
              ),
            ),
            Expanded(
              child: ValueListenableBuilder<List<Snippet>>(
                valueListenable: widget.controller.snippetsNotifier,
                builder: (_, all, _) {
                  final snippets = _filtered(all);
                  if (snippets.isEmpty) {
                    return _PanelEmptyState(
                      hasSnippets: all.isNotEmpty,
                      query: _query,
                      onCreateTap: _openCreateForm,
                    );
                  }
                  return ListView.separated(
                    padding:
                        const EdgeInsets.fromLTRB(12, 0, 12, 24),
                    itemCount: snippets.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: 6),
                    itemBuilder: (_, i) => _PanelSnippetCard(
                      snippet: snippets[i],
                      onPaste: () {
                        widget.onPaste(snippets[i].command);
                        widget.onClose();
                      },
                      onRun: () {
                        widget.onRun(snippets[i].command);
                        widget.onClose();
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header ─────────────────────────────────────────────────────────────────────

class _PanelHeader extends StatelessWidget {
  final VoidCallback onClose;
  final VoidCallback onNewSnippet;

  const _PanelHeader({required this.onClose, required this.onNewSnippet});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          const Icon(Icons.code_outlined,
              size: 14, color: AppColors.textMuted),
          const SizedBox(width: 8),
          const Text(
            'Snippets',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          _HeaderButton(
            icon: Icons.add,
            tooltip: 'New snippet',
            onTap: onNewSnippet,
          ),
          const SizedBox(width: 4),
          _HeaderButton(
            icon: Icons.close,
            tooltip: 'Close',
            onTap: onClose,
          ),
        ],
      ),
    );
  }
}

class _HeaderButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _HeaderButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  State<_HeaderButton> createState() => _HeaderButtonState();
}

class _HeaderButtonState extends State<_HeaderButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: _hovered
                  ? AppColors.border.withValues(alpha: 0.8)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Icon(widget.icon,
                size: 15, color: AppColors.textMuted),
          ),
        ),
      ),
    );
  }
}

// ── Snippet card ───────────────────────────────────────────────────────────────

class _PanelSnippetCard extends StatefulWidget {
  final Snippet snippet;
  final VoidCallback onPaste;
  final VoidCallback onRun;

  const _PanelSnippetCard({
    required this.snippet,
    required this.onPaste,
    required this.onRun,
  });

  @override
  State<_PanelSnippetCard> createState() => _PanelSnippetCardState();
}

class _PanelSnippetCardState extends State<_PanelSnippetCard> {
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
        duration: const Duration(milliseconds: 100),
        decoration: BoxDecoration(
          color: _hovered ? AppColors.surfaceElevated : AppColors.background,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.all(11),
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
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_hovered) ...[
                  _CardAction(
                    icon: _copied ? Icons.check : Icons.copy_outlined,
                    tooltip: _copied ? 'Copied!' : 'Copy',
                    onTap: _copy,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                widget.snippet.command,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11.5,
                  fontFamily: 'monospace',
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (widget.snippet.description != null) ...[
              const SizedBox(height: 5),
              Text(
                widget.snippet.description!,
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                if (widget.snippet.tags.isNotEmpty)
                  Expanded(
                    child: Wrap(
                      spacing: 3,
                      runSpacing: 3,
                      children: widget.snippet.tags
                          .take(3)
                          .map((t) => _MiniTag(label: t))
                          .toList(),
                    ),
                  )
                else
                  const Spacer(),
                const SizedBox(width: 8),
                _ActionButton(
                  label: 'Paste',
                  tooltip: 'Paste into terminal',
                  onTap: widget.onPaste,
                  primary: false,
                ),
                const SizedBox(width: 6),
                _ActionButton(
                  label: 'Run',
                  tooltip: 'Paste and run',
                  onTap: widget.onRun,
                  primary: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CardAction extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _CardAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  State<_CardAction> createState() => _CardActionState();
}

class _CardActionState extends State<_CardAction> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Icon(
              widget.icon,
              size: 14,
              color:
                  _hovered ? AppColors.text : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatefulWidget {
  final String label;
  final String tooltip;
  final VoidCallback onTap;
  final bool primary;

  const _ActionButton({
    required this.label,
    required this.tooltip,
    required this.onTap,
    required this.primary,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: widget.primary
                  ? (_hovered
                      ? AppColors.accent.withValues(alpha: 0.85)
                      : AppColors.accent)
                  : (_hovered
                      ? AppColors.border
                      : AppColors.border.withValues(alpha: 0.5)),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              widget.label,
              style: TextStyle(
                color:
                    widget.primary ? Colors.white : AppColors.textMuted,
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  final String label;
  const _MiniTag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.accent,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────────────

class _PanelEmptyState extends StatelessWidget {
  final bool hasSnippets;
  final String query;
  final VoidCallback onCreateTap;

  const _PanelEmptyState({
    required this.hasSnippets,
    required this.query,
    required this.onCreateTap,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.code_outlined,
              size: 32,
              color: Color.fromRGBO(154, 164, 178, 0.25)),
          const SizedBox(height: 12),
          Text(
            hasSnippets
                ? 'No results for "$query".'
                : 'No snippets yet.',
            style: const TextStyle(
                color: AppColors.textMuted, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          if (!hasSnippets) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: onCreateTap,
              child: const Text(
                'Create your first snippet',
                style: TextStyle(
                  color: AppColors.accent,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
