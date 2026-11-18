import 'package:material_ui/material_ui.dart';
import '../../../app/app_theme.dart';
import '../controllers/host_controller.dart';
import '../services/ssh_config_importer.dart';

class SshConfigImportDialog extends StatefulWidget {
  final HostController controller;

  const SshConfigImportDialog({super.key, required this.controller});

  @override
  State<SshConfigImportDialog> createState() => _SshConfigImportDialogState();
}

class _SshConfigImportDialogState extends State<SshConfigImportDialog> {
  List<SshConfigEntry> _entries = [];
  Set<int> _selected = {};
  bool _loading = true;
  String? _error;
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final entries = await SshConfigImporter.parse();
      final existingKeys = widget.controller.hostsNotifier.value
          .map((h) => '${h.hostname}:${h.port}')
          .toSet();
      final preSelected = <int>{};
      for (var i = 0; i < entries.length; i++) {
        if (!existingKeys.contains('${entries[i].hostname}:${entries[i].port}')) {
          preSelected.add(i);
        }
      }
      setState(() {
        _entries = entries;
        _selected = preSelected;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Could not read ~/.ssh/config';
        _loading = false;
      });
    }
  }

  Future<void> _import() async {
    setState(() => _importing = true);
    for (final i in _selected) {
      await widget.controller.add(_entries[i].toSshHost());
    }
    if (mounted) Navigator.of(context).pop(_selected.length);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 520,
        constraints: const BoxConstraints(maxHeight: 520),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            const Divider(height: 1, color: AppColors.border),
            Flexible(child: _buildBody()),
            const Divider(height: 1, color: AppColors.border),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s24,
        vertical: AppSpacing.s16,
      ),
      child: Row(
        children: [
          const Icon(
            Icons.download_outlined,
            size: 15,
            color: AppColors.accent,
          ),
          const SizedBox(width: AppSpacing.s8),
          const Text(
            'Import from SSH Config',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: const Icon(
              Icons.close,
              size: 16,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.s32),
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.accent,
            ),
          ),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s32),
          child: Text(
            _error!,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ),
      );
    }

    if (_entries.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.s32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.search_off,
                size: 28,
                color: AppColors.textMuted,
              ),
              SizedBox(height: AppSpacing.s12),
              Text(
                'No hosts found in ~/.ssh/config',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
      itemCount: _entries.length,
      itemBuilder: (context, i) {
        final e = _entries[i];
        final selected = _selected.contains(i);
        return GestureDetector(
          onTap: () => setState(() {
            if (selected) {
              _selected.remove(i);
            } else {
              _selected.add(i);
            }
          }),
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            color: selected
                ? AppColors.accent.withValues(alpha: 0.06)
                : Colors.transparent,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s16,
              vertical: AppSpacing.s12,
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: selected ? AppColors.accent : Colors.transparent,
                    border: Border.all(
                      color: selected ? AppColors.accent : AppColors.border,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: selected
                      ? const Icon(Icons.check, size: 10, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.alias,
                        style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${e.username}@${e.hostname}:${e.port}',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                if (e.identityFile != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.vpn_key_outlined,
                          size: 10,
                          color: AppColors.textMuted,
                        ),
                        SizedBox(width: 3),
                        Text(
                          'Key',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s24,
        vertical: AppSpacing.s16,
      ),
      child: Row(
        children: [
          if (_entries.isNotEmpty) ...[
            GestureDetector(
              onTap: () => setState(() {
                _selected = _selected.length == _entries.length
                    ? {}
                    : Set.from(Iterable.generate(_entries.length));
              }),
              child: Text(
                _selected.length == _entries.length
                    ? 'Deselect All'
                    : 'Select All',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.s12),
            Text(
              '${_selected.length} of ${_entries.length}',
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
              ),
            ),
          ],
          const Spacer(),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
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
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s8),
          GestureDetector(
            onTap: _selected.isEmpty || _importing ? null : _import,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s16,
                vertical: AppSpacing.s8,
              ),
              decoration: BoxDecoration(
                color: _selected.isEmpty
                    ? AppColors.border
                    : AppColors.accent,
                borderRadius: BorderRadius.circular(7),
              ),
              child: _importing
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      _selected.isEmpty
                          ? 'Import'
                          : 'Import ${_selected.length}',
                      style: const TextStyle(
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
