import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import '../../../app/app_theme.dart';
import '../../../features/snippets/controllers/snippet_controller.dart';
import '../../../features/snippets/models/snippet.dart';
import '../../../features/snippets/views/snippet_form_dialog.dart';
import '../controllers/command_history_controller.dart';
import '../models/command_history_entry.dart';
import '../models/terminal_theme_presets.dart';

const double kSidebarWidth = 300.0;

enum _SidebarSection { snippets, history, themes }

class TerminalRightSidebar extends StatefulWidget {
  final SnippetController snippetController;
  final CommandHistoryController historyController;
  final ValueNotifier<TerminalThemeName> themeNotifier;
  final ValueChanged<TerminalThemeName> onThemeChanged;
  final void Function(String command) onPaste;
  final void Function(String command) onRun;

  const TerminalRightSidebar({
    super.key,
    required this.snippetController,
    required this.historyController,
    required this.themeNotifier,
    required this.onThemeChanged,
    required this.onPaste,
    required this.onRun,
  });

  @override
  State<TerminalRightSidebar> createState() => _TerminalRightSidebarState();
}

class _TerminalRightSidebarState extends State<TerminalRightSidebar> {
  _SidebarSection _section = _SidebarSection.snippets;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: kSidebarWidth,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(left: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          _SectionTabs(
            current: _section,
            onChanged: (s) => setState(() => _section = s),
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() => switch (_section) {
        _SidebarSection.snippets => _SnippetsSection(
            controller: widget.snippetController,
            onPaste: widget.onPaste,
            onRun: widget.onRun,
          ),
        _SidebarSection.history => _HistorySection(
            controller: widget.historyController,
            onPaste: widget.onPaste,
            onRun: widget.onRun,
          ),
        _SidebarSection.themes => _ThemesSection(
            themeNotifier: widget.themeNotifier,
            onThemeChanged: widget.onThemeChanged,
          ),
      };
}

// ── Section tab bar ────────────────────────────────────────────────────────────

class _SectionTabs extends StatelessWidget {
  final _SidebarSection current;
  final ValueChanged<_SidebarSection> onChanged;

  const _SectionTabs({required this.current, required this.onChanged});

  static const _tabs = [
    (section: _SidebarSection.snippets, icon: Icons.code_outlined,    label: 'Snippets'),
    (section: _SidebarSection.history,  icon: Icons.history,           label: 'History'),
    (section: _SidebarSection.themes,   icon: Icons.palette_outlined,  label: 'Themes'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: _tabs.map((t) {
          final active = t.section == current;
          return Expanded(
            child: _SectionTab(
              icon: t.icon,
              label: t.label,
              active: active,
              onTap: () => onChanged(t.section),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _SectionTab extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _SectionTab({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  State<_SectionTab> createState() => _SectionTabState();
}

class _SectionTabState extends State<_SectionTab> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.label,
      waitDuration: const Duration(milliseconds: 500),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              color: widget.active
                  ? AppColors.background
                  : _hovered
                      ? AppColors.border.withValues(alpha: 0.3)
                      : Colors.transparent,
              border: Border(
                bottom: BorderSide(
                  color: widget.active
                      ? AppColors.accent
                      : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  widget.icon,
                  size: 13,
                  color: widget.active
                      ? AppColors.accent
                      : AppColors.textMuted,
                ),
                const SizedBox(width: 5),
                Text(
                  widget.label,
                  style: TextStyle(
                    color: widget.active
                        ? AppColors.accent
                        : AppColors.textMuted,
                    fontSize: 11.5,
                    fontWeight: widget.active
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Snippets section ───────────────────────────────────────────────────────────

class _SnippetsSection extends StatefulWidget {
  final SnippetController controller;
  final void Function(String) onPaste;
  final void Function(String) onRun;

  const _SnippetsSection({
    required this.controller,
    required this.onPaste,
    required this.onRun,
  });

  @override
  State<_SnippetsSection> createState() => _SnippetsSectionState();
}

class _SnippetsSectionState extends State<_SnippetsSection> {
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
    return all
        .where((s) =>
            s.title.toLowerCase().contains(q) ||
            s.command.toLowerCase().contains(q) ||
            s.tags.any((t) => t.toLowerCase().contains(q)))
        .toList();
  }

  void _openCreateForm() {
    showDialog<void>(
      context: context,
      builder: (_) =>
          SnippetFormDialog(controller: widget.controller),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
          child: Row(
            children: [
              Expanded(
                child: _SearchField(
                  controller: _search,
                  hint: 'Search snippets…',
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              const SizedBox(width: 6),
              _AddButton(onTap: _openCreateForm),
            ],
          ),
        ),
        Expanded(
          child: ValueListenableBuilder<List<Snippet>>(
            valueListenable: widget.controller.snippetsNotifier,
            builder: (_, all, _) {
              final list = _filtered(all);
              if (list.isEmpty) {
                return _EmptyState(
                  icon: Icons.code_outlined,
                  text: all.isEmpty
                      ? 'No snippets yet.'
                      : 'No results for "$_query".',
                  action: all.isEmpty ? 'Create one' : null,
                  onAction: all.isEmpty ? _openCreateForm : null,
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 24),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 5),
                itemBuilder: (_, i) => _SnippetCard(
                  snippet: list[i],
                  onPaste: () => widget.onPaste(list[i].command),
                  onRun: () => widget.onRun(list[i].command),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SnippetCard extends StatefulWidget {
  final Snippet snippet;
  final VoidCallback onPaste;
  final VoidCallback onRun;

  const _SnippetCard({
    required this.snippet,
    required this.onPaste,
    required this.onRun,
  });

  @override
  State<_SnippetCard> createState() => _SnippetCardState();
}

class _SnippetCardState extends State<_SnippetCard> {
  bool _hovered = false;
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(
        ClipboardData(text: widget.snippet.command));
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
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _hovered
              ? AppColors.surfaceElevated
              : AppColors.background,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(7),
        ),
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
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_hovered)
                  _IconAction(
                    icon: _copied ? Icons.check : Icons.copy_outlined,
                    tooltip: _copied ? 'Copied!' : 'Copy',
                    onTap: _copy,
                  ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              widget.snippet.command,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
                fontFamily: 'monospace',
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (widget.snippet.tags.isNotEmpty) ...[
              const SizedBox(height: 5),
              Wrap(
                spacing: 3,
                runSpacing: 3,
                children: widget.snippet.tags
                    .take(3)
                    .map((t) => _MiniTag(label: t))
                    .toList(),
              ),
            ],
            const SizedBox(height: 7),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _InlineButton(
                    label: 'Paste', onTap: widget.onPaste, primary: false),
                const SizedBox(width: 5),
                _InlineButton(
                    label: 'Run ▶', onTap: widget.onRun, primary: true),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── History section ────────────────────────────────────────────────────────────

class _HistorySection extends StatefulWidget {
  final CommandHistoryController controller;
  final void Function(String) onPaste;
  final void Function(String) onRun;

  const _HistorySection({
    required this.controller,
    required this.onPaste,
    required this.onRun,
  });

  @override
  State<_HistorySection> createState() => _HistorySectionState();
}

class _HistorySectionState extends State<_HistorySection> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<CommandHistoryEntry> _filtered(List<CommandHistoryEntry> all) {
    if (_query.isEmpty) return all;
    final q = _query.toLowerCase();
    return all
        .where((e) => e.command.toLowerCase().contains(q))
        .toList();
  }

  Future<void> _confirmClear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppColors.border),
        ),
        title: const Text('Clear history?',
            style: TextStyle(color: AppColors.text, fontSize: 15)),
        content: const Text(
          'All command history will be permanently removed.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Clear',
                style: TextStyle(color: Color(0xFFF87171))),
          ),
        ],
      ),
    );
    if (ok == true) await widget.controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
          child: Row(
            children: [
              Expanded(
                child: _SearchField(
                  controller: _search,
                  hint: 'Filter history…',
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              const SizedBox(width: 6),
              ValueListenableBuilder<List<CommandHistoryEntry>>(
                valueListenable: widget.controller.entriesNotifier,
                builder: (_, entries, _) => entries.isEmpty
                    ? const SizedBox.shrink()
                    : Tooltip(
                        message: 'Clear history',
                        child: _IconAction(
                          icon: Icons.delete_sweep_outlined,
                          tooltip: 'Clear history',
                          onTap: _confirmClear,
                        ),
                      ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ValueListenableBuilder<List<CommandHistoryEntry>>(
            valueListenable: widget.controller.entriesNotifier,
            builder: (_, all, _) {
              final list = _filtered(all);
              if (list.isEmpty) {
                return _EmptyState(
                  icon: Icons.history,
                  text: all.isEmpty
                      ? 'No history yet.\nRun a snippet to get started.'
                      : 'No results for "$_query".',
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 24),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 4),
                itemBuilder: (_, i) => _HistoryRow(
                  entry: list[i],
                  onPaste: () => widget.onPaste(list[i].command),
                  onRun: () => widget.onRun(list[i].command),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _HistoryRow extends StatefulWidget {
  final CommandHistoryEntry entry;
  final VoidCallback onPaste;
  final VoidCallback onRun;

  const _HistoryRow({
    required this.entry,
    required this.onPaste,
    required this.onRun,
  });

  @override
  State<_HistoryRow> createState() => _HistoryRowState();
}

class _HistoryRowState extends State<_HistoryRow> {
  bool _hovered = false;

  String get _timeLabel {
    final diff = DateTime.now().difference(widget.entry.ranAt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: _hovered
              ? AppColors.surfaceElevated
              : AppColors.background,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.entry.command,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 11.5,
                      fontFamily: 'monospace',
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _timeLabel,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),
            if (_hovered) ...[
              const SizedBox(width: 6),
              _IconAction(
                icon: Icons.content_paste_outlined,
                tooltip: 'Paste',
                onTap: widget.onPaste,
              ),
              const SizedBox(width: 2),
              _IconAction(
                icon: Icons.play_arrow_rounded,
                tooltip: 'Run',
                color: AppColors.accent,
                onTap: widget.onRun,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Themes section ─────────────────────────────────────────────────────────────

class _ThemesSection extends StatelessWidget {
  final ValueNotifier<TerminalThemeName> themeNotifier;
  final ValueChanged<TerminalThemeName> onThemeChanged;

  const _ThemesSection({
    required this.themeNotifier,
    required this.onThemeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TerminalThemeName>(
      valueListenable: themeNotifier,
      builder: (_, current, _) {
        return ListView.separated(
          padding: const EdgeInsets.all(10),
          itemCount: terminalThemePresets.length,
          separatorBuilder: (_, _) => const SizedBox(height: 6),
          itemBuilder: (_, i) {
            final preset = terminalThemePresets[i];
            final selected = preset.name == current;
            return _ThemeCard(
              preset: preset,
              selected: selected,
              onTap: () => onThemeChanged(preset.name),
            );
          },
        );
      },
    );
  }
}

class _ThemeCard extends StatefulWidget {
  final TerminalThemePreset preset;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeCard({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_ThemeCard> createState() => _ThemeCardState();
}

class _ThemeCardState extends State<_ThemeCard> {
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
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: widget.selected
                ? AppColors.accent.withValues(alpha: 0.08)
                : _hovered
                    ? AppColors.surfaceElevated
                    : AppColors.background,
            border: Border.all(
              color: widget.selected
                  ? AppColors.accent.withValues(alpha: 0.5)
                  : AppColors.border,
              width: widget.selected ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Row(
            children: [
              // Mini terminal preview swatch
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  width: 44,
                  height: 32,
                  color: widget.preset.background,
                  padding: const EdgeInsets.all(5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        height: 3,
                        width: 24,
                        decoration: BoxDecoration(
                          color: widget.preset.foreground
                              .withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Container(
                        height: 3,
                        width: 14,
                        decoration: BoxDecoration(
                          color: widget.preset.accent
                              .withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.preset.name.label,
                  style: TextStyle(
                    color: widget.selected
                        ? AppColors.text
                        : AppColors.textMuted,
                    fontSize: 12.5,
                    fontWeight: widget.selected
                        ? FontWeight.w500
                        : FontWeight.w400,
                  ),
                ),
              ),
              if (widget.selected)
                const Icon(Icons.check,
                    size: 14, color: AppColors.accent),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Shared widgets ─────────────────────────────────────────────────────────────

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  const _SearchField({
    required this.controller,
    required this.hint,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: const TextStyle(color: AppColors.text, fontSize: 12),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
            const TextStyle(color: AppColors.textMuted, fontSize: 12),
        prefixIcon: const Icon(Icons.search,
            size: 13, color: AppColors.textMuted),
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide:
              const BorderSide(color: AppColors.accent, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
    return Tooltip(
      message: 'New snippet',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _hovered
                  ? AppColors.accent.withValues(alpha: 0.15)
                  : AppColors.accent.withValues(alpha: 0.08),
              border: Border.all(
                  color: AppColors.accent.withValues(alpha: 0.35)),
              borderRadius: BorderRadius.circular(6),
            ),
            child:
                const Icon(Icons.add, size: 14, color: AppColors.accent),
          ),
        ),
      ),
    );
  }
}

class _IconAction extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color color;

  const _IconAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color = AppColors.textMuted,
  });

  @override
  State<_IconAction> createState() => _IconActionState();
}

class _IconActionState extends State<_IconAction> {
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
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: _hovered
                  ? AppColors.border.withValues(alpha: 0.8)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(widget.icon, size: 14, color: widget.color),
          ),
        ),
      ),
    );
  }
}

class _InlineButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final bool primary;

  const _InlineButton({
    required this.label,
    required this.onTap,
    required this.primary,
  });

  @override
  State<_InlineButton> createState() => _InlineButtonState();
}

class _InlineButtonState extends State<_InlineButton> {
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
          duration: const Duration(milliseconds: 100),
          padding:
              const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: widget.primary
                ? (_hovered
                    ? AppColors.accent.withValues(alpha: 0.85)
                    : AppColors.accent)
                : (_hovered ? AppColors.border : AppColors.border.withValues(alpha: 0.5)),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              color: widget.primary ? Colors.white : AppColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w500,
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
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
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

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;
  final String? action;
  final VoidCallback? onAction;

  const _EmptyState({
    required this.icon,
    required this.text,
    this.action,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 28,
                color: AppColors.textMuted.withValues(alpha: 0.3)),
            const SizedBox(height: 10),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.textMuted, fontSize: 12.5),
            ),
            if (action != null && onAction != null) ...[
              const SizedBox(height: 10),
              GestureDetector(
                onTap: onAction,
                child: Text(
                  action!,
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
