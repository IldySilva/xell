import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import '../../../app/app_theme.dart';
import '../controllers/host_controller.dart';
import '../models/ssh_host.dart';
import '../widgets/host_row.dart';
import 'host_form_dialog.dart';
import 'host_form_page.dart';

class HostListPage extends StatefulWidget {
  final HostController controller;
  final Future<void> Function(SshHost)? onConnect;

  const HostListPage({super.key, required this.controller, this.onConnect});

  @override
  State<HostListPage> createState() => _HostListPageState();
}

class _HostListPageState extends State<HostListPage> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  String _query = '';
  int _focusedIndex = -1;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  List<SshHost> _filtered(List<SshHost> hosts) =>
      hosts.where((h) => h.matchesQuery(_query)).toList();

  // Flat ordered list used for keyboard navigation (favorites first).
  List<SshHost> _orderedFiltered(List<SshHost> hosts) {
    final filtered = _filtered(hosts);
    return [
      ...filtered.where((h) => h.isFavorite),
      ...filtered.where((h) => !h.isFavorite),
    ];
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final hosts = widget.controller.hostsNotifier.value;
    final ordered = _orderedFiltered(hosts);
    if (ordered.isEmpty) return KeyEventResult.ignored;

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown) {
      setState(() => _focusedIndex = (_focusedIndex + 1).clamp(0, ordered.length - 1));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      setState(() => _focusedIndex = (_focusedIndex - 1).clamp(0, ordered.length - 1));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter && _focusedIndex >= 0) {
      _onConnect(ordered[_focusedIndex]);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      setState(() => _focusedIndex = -1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _openForm([SshHost? host]) {
    if (Platform.isIOS || Platform.isAndroid) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => HostFormPage(controller: widget.controller, host: host),
      ));
    } else {
      showDialog(
        context: context,
        builder: (_) =>
            HostFormDialog(controller: widget.controller, host: host),
      );
    }
  }

  Future<void> _confirmDelete(SshHost host) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _DeleteConfirmDialog(hostName: host.name),
    );
    if (confirmed == true) {
      await widget.controller.delete(host.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: _handleKey,
      child: ValueListenableBuilder<bool>(
        valueListenable: widget.controller.loadingNotifier,
        builder: (context, loading, _) {
          if (loading) return const _LoadingState();
          return ValueListenableBuilder<List<SshHost>>(
            valueListenable: widget.controller.hostsNotifier,
            builder: (context, hosts, _) {
              final filtered = _filtered(hosts);
              final ordered = _orderedFiltered(hosts);
              final favorites = filtered.where((h) => h.isFavorite).toList();
              final others = filtered.where((h) => !h.isFavorite).toList();
              final noFavorites = hosts.isNotEmpty &&
                  hosts.every((h) => !h.isFavorite) &&
                  _query.isEmpty;
              final focusedId =
                  (_focusedIndex >= 0 && _focusedIndex < ordered.length)
                      ? ordered[_focusedIndex].id
                      : null;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Header(count: hosts.length, onNewHost: () => _openForm()),
                  _SearchBar(
                    controller: _searchController,
                    focusNode: _searchFocus,
                    onChanged: (q) => setState(() {
                      _query = q;
                      _focusedIndex = -1;
                    }),
                  ),
                  Expanded(
                    child: hosts.isEmpty
                        ? _EmptyState(onAdd: () => _openForm())
                        : filtered.isEmpty
                        ? const _NoResults()
                        : _HostList(
                            favorites: favorites,
                            others: others,
                            noFavoritesHint: noFavorites,
                            focusedId: focusedId,
                            onConnect: _onConnect,
                            onEdit: _openForm,
                            onDelete: _confirmDelete,
                            onToggleFavorite: (h) =>
                                widget.controller.toggleFavorite(h.id),
                          ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _onConnect(SshHost host) async {
    if (widget.onConnect != null) {
      await widget.onConnect!(host);
    }
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final int count;
  final VoidCallback onNewHost;

  const _Header({required this.count, required this.onNewHost});

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
            'Hosts',
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
          _NewHostButton(onTap: onNewHost),
        ],
      ),
    );
  }
}

class _NewHostButton extends StatefulWidget {
  final VoidCallback onTap;
  const _NewHostButton({required this.onTap});

  @override
  State<_NewHostButton> createState() => _NewHostButtonState();
}

class _NewHostButtonState extends State<_NewHostButton> {
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
                'New Host',
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

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final ValueChanged<String> onChanged;

  const _SearchBar({
    required this.controller,
    required this.onChanged,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s24,
        vertical: AppSpacing.s8,
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        style: const TextStyle(color: AppColors.text, fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Search hosts...',
          hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          prefixIcon: const Padding(
            padding: EdgeInsets.only(left: 12, right: 8),
            child: Icon(Icons.search, size: 15, color: AppColors.textMuted),
          ),
          prefixIconConstraints: const BoxConstraints(),
          filled: true,
          fillColor: AppColors.surface,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s12,
            vertical: AppSpacing.s8,
          ),
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
            borderSide: BorderSide(
              color: AppColors.accent.withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.accent,
        ),
      ),
    );
  }
}

class _HostList extends StatelessWidget {
  final List<SshHost> favorites;
  final List<SshHost> others;
  final bool noFavoritesHint;
  final String? focusedId;
  final void Function(SshHost) onConnect;
  final void Function(SshHost) onEdit;
  final void Function(SshHost) onDelete;
  final void Function(SshHost) onToggleFavorite;

  const _HostList({
    required this.favorites,
    required this.others,
    required this.focusedId,
    required this.onConnect,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleFavorite,
    this.noFavoritesHint = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s16,
        AppSpacing.s8,
        AppSpacing.s16,
        AppSpacing.s24,
      ),
      children: [
        if (noFavoritesHint)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s24,
              AppSpacing.s8,
              AppSpacing.s24,
              AppSpacing.s4,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.star_border,
                  size: 12,
                  color: AppColors.textMuted.withValues(alpha: 0.5),
                ),
                const SizedBox(width: AppSpacing.s4),
                Text(
                  'Star a host to pin it to Favorites.',
                  style: TextStyle(
                    color: AppColors.textMuted.withValues(alpha: 0.6),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
        if (favorites.isNotEmpty) ...[
          _SectionHeader(label: 'Favorites', count: favorites.length),
          ...favorites.map(
            (h) => HostRow(
              key: ValueKey(h.id),
              host: h,
              isKeyboardFocused: h.id == focusedId,
              onConnect: () => onConnect(h),
              onEdit: () => onEdit(h),
              onDelete: () => onDelete(h),
              onToggleFavorite: () => onToggleFavorite(h),
            ),
          ),
          const SizedBox(height: AppSpacing.s8),
        ],
        if (others.isNotEmpty) ...[
          _SectionHeader(
            label: favorites.isEmpty ? 'All Hosts' : 'Others',
            count: others.length,
          ),
          ...others.map(
            (h) => HostRow(
              key: ValueKey(h.id),
              host: h,
              isKeyboardFocused: h.id == focusedId,
              onConnect: () => onConnect(h),
              onEdit: () => onEdit(h),
              onDelete: () => onDelete(h),
              onToggleFavorite: () => onToggleFavorite(h),
            ),
          ),
        ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final int count;

  const _SectionHeader({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s12,
        AppSpacing.s8,
        AppSpacing.s12,
        AppSpacing.s4,
      ),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(width: AppSpacing.s8),
          Text(
            '$count',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 10.5),
          ),
        ],
      ),
    );
  }
}

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
            Icons.dns_outlined,
            size: 40,
            color: AppColors.textMuted.withValues(alpha: 0.3),
          ),
          const SizedBox(height: AppSpacing.s16),
          const Text(
            'No hosts yet',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppSpacing.s8),
          const Text(
            'Add your first SSH host to get started.',
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
                'Add Host',
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

class _NoResults extends StatelessWidget {
  const _NoResults();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'No hosts match your search.',
        style: TextStyle(color: AppColors.textMuted, fontSize: 13),
      ),
    );
  }
}

class _DeleteConfirmDialog extends StatelessWidget {
  final String hostName;
  const _DeleteConfirmDialog({required this.hostName});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 380,
        padding: const EdgeInsets.all(AppSpacing.s24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Delete host?',
              style: TextStyle(
                color: AppColors.text,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.s8),
            Text(
              '"$hostName" will be removed permanently.',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            const SizedBox(height: AppSpacing.s24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s12,
                      vertical: AppSpacing.s8,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.s12),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s12,
                      vertical: AppSpacing.s8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF87171),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: const Text(
                      'Delete',
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
          ],
        ),
      ),
    );
  }
}
