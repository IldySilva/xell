import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../app/app_theme.dart';
import '../../hosts/models/ssh_host.dart';

class _PaletteItem {
  final String label;
  final String? subtitle;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  const _PaletteItem({
    required this.label,
    this.subtitle,
    required this.icon,
    this.iconColor = AppColors.textMuted,
    required this.onTap,
  });
}

class CommandPalette extends StatefulWidget {
  final List<SshHost> hosts;
  final ValueChanged<SshHost> onConnect;
  final VoidCallback onOpenSettings;
  final VoidCallback onCreateHost;
  final VoidCallback? onImportSshConfig;
  final VoidCallback? onSplitHorizontal;
  final VoidCallback? onSplitVertical;
  final VoidCallback? onCloseSplit;

  const CommandPalette({
    super.key,
    required this.hosts,
    required this.onConnect,
    required this.onOpenSettings,
    required this.onCreateHost,
    this.onImportSshConfig,
    this.onSplitHorizontal,
    this.onSplitVertical,
    this.onCloseSplit,
  });

  @override
  State<CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends State<CommandPalette> {
  late final FocusNode _focusNode;
  final _controller = TextEditingController();
  String _query = '';
  int _focusedIndex = 0;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(onKeyEvent: _handleKeyEvent);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final items = _buildItems();
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowDown:
        if (items.isNotEmpty) {
          setState(
            () =>
                _focusedIndex = (_focusedIndex + 1).clamp(0, items.length - 1),
          );
        }
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
        if (items.isNotEmpty) {
          setState(
            () =>
                _focusedIndex = (_focusedIndex - 1).clamp(0, items.length - 1),
          );
        }
        return KeyEventResult.handled;
      case LogicalKeyboardKey.enter:
        if (items.isNotEmpty && _focusedIndex < items.length) {
          items[_focusedIndex].onTap();
        }
        return KeyEventResult.handled;
      case LogicalKeyboardKey.escape:
        Navigator.of(context).pop();
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
  }

  void _close() => Navigator.of(context).pop();

  void _execute(VoidCallback fn) {
    _close();
    fn();
  }

  List<SshHost> get _recentHosts {
    final withDate =
        widget.hosts.where((h) => h.lastConnectedAt != null).toList()
          ..sort((a, b) => b.lastConnectedAt!.compareTo(a.lastConnectedAt!));
    return withDate.take(5).toList();
  }

  List<_PaletteItem> _buildItems() {
    final q = _query.trim().toLowerCase();
    final items = <_PaletteItem>[];

    // Hosts: recent when query empty, fuzzy-filtered when typing
    final matchingHosts = q.isEmpty
        ? _recentHosts
        : widget.hosts.where((h) => h.matchesQuery(_query)).toList();

    for (final host in matchingHosts) {
      items.add(
        _PaletteItem(
          label: host.name,
          subtitle: '${host.username}@${host.hostname}:${host.port}',
          icon: Icons.terminal_outlined,
          iconColor: AppColors.accent,
          onTap: () => _execute(() => widget.onConnect(host)),
        ),
      );
    }

    // Static actions — shown always, or only when query matches
    final statics = [
      (
        label: 'Open Settings',
        icon: Icons.settings_outlined,
        keys: ['settings', 'open settings', 'preferences'],
        fn: widget.onOpenSettings,
      ),
      (
        label: 'Create New Host',
        icon: Icons.add_circle_outline,
        keys: ['create host', 'new host', 'add host', 'add server'],
        fn: widget.onCreateHost,
      ),
      if (widget.onImportSshConfig != null)
        (
          label: 'Import SSH Config',
          icon: Icons.download_outlined,
          keys: ['import', 'ssh config', 'import hosts', '~/.ssh/config'],
          fn: widget.onImportSshConfig!,
        ),
      if (widget.onSplitHorizontal != null)
        (
          label: 'Split Pane Right',
          icon: Icons.vertical_split_outlined,
          keys: ['split', 'split right', 'split horizontal', 'pane'],
          fn: widget.onSplitHorizontal!,
        ),
      if (widget.onSplitVertical != null)
        (
          label: 'Split Pane Down',
          icon: Icons.horizontal_split_outlined,
          keys: ['split', 'split down', 'split vertical', 'pane'],
          fn: widget.onSplitVertical!,
        ),
      if (widget.onCloseSplit != null)
        (
          label: 'Close Split',
          icon: Icons.close_fullscreen_outlined,
          keys: ['close split', 'unsplit', 'single pane'],
          fn: widget.onCloseSplit!,
        ),
    ];

    for (final s in statics) {
      final visible = q.isEmpty || s.keys.any((k) => k.contains(q));
      if (visible) {
        items.add(
          _PaletteItem(
            label: s.label,
            icon: s.icon,
            onTap: () => _execute(s.fn),
          ),
        );
      }
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    final items = _buildItems();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: Align(
        alignment: const Alignment(0, -0.25),
        child: Container(
          width: (MediaQuery.of(context).size.width - 32).clamp(0.0, 560.0),
          constraints: const BoxConstraints(maxHeight: 420),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 32,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SearchField(
                controller: _controller,
                focusNode: _focusNode,
                onChanged: (v) => setState(() {
                  _query = v;
                  _focusedIndex = 0;
                }),
              ),
              if (items.isNotEmpty)
                const Divider(height: 1, color: AppColors.border),
              if (items.isNotEmpty)
                Flexible(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.s4,
                    ),
                    shrinkWrap: true,
                    itemCount: items.length,
                    itemBuilder: (context, i) => _ItemRow(
                      item: items[i],
                      focused: i == _focusedIndex,
                      onHover: () => setState(() => _focusedIndex = i),
                    ),
                  ),
                ),
              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.s24),
                  child: Text(
                    'No results.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                ),
              _Footer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s16,
        vertical: AppSpacing.s12,
      ),
      child: Row(
        children: [
          const Icon(Icons.search, size: 16, color: AppColors.textMuted),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              autofocus: true,
              onChanged: onChanged,
              style: const TextStyle(color: AppColors.text, fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'Search hosts or jump to...',
                hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 14),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final _PaletteItem item;
  final bool focused;
  final VoidCallback onHover;

  const _ItemRow({
    required this.item,
    required this.focused,
    required this.onHover,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => onHover(),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: item.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          color: focused
              ? AppColors.accent.withValues(alpha: 0.12)
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s16,
            vertical: 10,
          ),
          child: Row(
            children: [
              Icon(item.icon, size: 15, color: item.iconColor),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.label,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 13.5,
                      ),
                    ),
                    if (item.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.subtitle!,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (focused)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '↵',
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isMac = Platform.isMacOS;
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s16,
        vertical: AppSpacing.s8,
      ),
      child: Row(
        children: [
          _hint('↑↓', 'navigate'),
          const SizedBox(width: AppSpacing.s16),
          _hint('↵', 'select'),
          const SizedBox(width: AppSpacing.s16),
          _hint('esc', 'close'),
          const Spacer(),
          _hint(isMac ? '⌘K' : 'Ctrl+K', 'palette'),
        ],
      ),
    );
  }

  Widget _hint(String key, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.border,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            key,
            style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
      ],
    );
  }
}
