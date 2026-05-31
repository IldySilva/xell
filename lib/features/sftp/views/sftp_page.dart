import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../app/app_theme.dart';
import '../../remote_editor/controllers/remote_editor_controller.dart';
import '../../remote_editor/views/remote_file_editor_page.dart';
import '../../terminal/controllers/terminal_controller.dart';
import '../../terminal/models/terminal_session.dart';
import '../controllers/sftp_controller.dart';
import '../models/sftp_entry.dart';
import '../widgets/sftp_entry_row.dart';

class SftpPage extends StatefulWidget {
  final TerminalController terminalController;

  const SftpPage({super.key, required this.terminalController});

  @override
  State<SftpPage> createState() => _SftpPageState();
}

class _SftpPageState extends State<SftpPage> {
  final _controller = SftpController();
  String? _connectedSessionId;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  TerminalSession? get _activeSession =>
      widget.terminalController.activeSession;

  Future<void> _ensureConnected() async {
    final session = _activeSession;
    if (session == null ||
        session.status != SessionStatus.connected ||
        session.client == null) {
      return;
    }
    if (_connectedSessionId == session.id) return;
    _connectedSessionId = session.id;
    await _controller.connect(session.client!);
  }

  Future<void> _handleUpload() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Select file to upload',
      allowMultiple: false,
    );
    if (result == null || result.files.single.path == null) return;
    final path = result.files.single.path!;
    final name = result.files.single.name;
    final data = await File(path).readAsBytes();
    try {
      await _controller.upload(name, data);
    } catch (_) {
      if (mounted) _showError('Upload failed. Check permissions and try again.');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Color(0xFFE6EAF2), fontSize: 13),
        ),
        backgroundColor: const Color(0xFF151922),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xFF232734)),
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _handleDownload(SftpEntry entry) async {
    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save ${entry.name}',
      fileName: entry.name,
    );
    if (savePath == null) return;
    final data = await _controller.download(entry);
    if (data == null) return;
    await File(savePath).writeAsBytes(data);
  }

  Future<void> _handleRename(SftpEntry entry) async {
    final controller = TextEditingController(text: entry.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => _RenameDialog(controller: controller),
    );
    controller.dispose();
    if (newName == null || newName.trim().isEmpty || newName == entry.name) {
      return;
    }
    await _controller.rename(entry, newName.trim());
  }

  void _handleEdit(SftpEntry entry) {
    final sftp = _controller.sftp;
    if (sftp == null) return;
    final editorController =
        RemoteEditorController(sftp: sftp, path: entry.path);
    if (Platform.isIOS || Platform.isAndroid) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) =>
            RemoteFileEditorPage(controller: editorController),
      ));
    } else {
      showDialog<void>(
        context: context,
        builder: (_) =>
            RemoteFileEditorPage(controller: editorController),
      );
    }
  }

  Future<void> _handleDelete(SftpEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _DeleteDialog(entry: entry),
    );
    if (confirmed != true) return;
    await _controller.delete(entry);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: widget.terminalController.activeSessionIdNotifier,
      builder: (context, activeId, child) {
        final session = _activeSession;
        final isReady = session != null &&
            session.status == SessionStatus.connected &&
            session.client != null;

        if (!isReady) {
          return const _NoSessionState();
        }

        // Trigger connection lazily when a valid session is available.
        _ensureConnected();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SftpToolbar(
              controller: _controller,
              onUpload: _handleUpload,
            ),
            const Divider(height: 1),
            Expanded(child: _SftpBrowser(
              controller: _controller,
              onDownload: _handleDownload,
              onEdit: _handleEdit,
              onRename: _handleRename,
              onDelete: _handleDelete,
            )),
          ],
        );
      },
    );
  }
}

// ── Toolbar ───────────────────────────────────────────────────────────────────

class _SftpToolbar extends StatelessWidget {
  final SftpController controller;
  final VoidCallback onUpload;

  const _SftpToolbar({required this.controller, required this.onUpload});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12),
      child: Row(
        children: [
          ValueListenableBuilder<bool>(
            valueListenable: controller.loadingNotifier,
            builder: (context, loading, child) => IconButton(
              icon: const Icon(Icons.arrow_upward, size: 15),
              tooltip: 'Go up',
              color: AppColors.textMuted,
              onPressed: loading ? null : controller.navigateUp,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
          const SizedBox(width: AppSpacing.s8),
          Expanded(
            child: ValueListenableBuilder<String>(
              valueListenable: controller.currentPathNotifier,
              builder: (context, path, child) => _Breadcrumb(
                path: path,
                onNavigate: controller.navigate,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s8),
          ValueListenableBuilder<bool>(
            valueListenable: controller.loadingNotifier,
            builder: (context, loading, child) => loading
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.accent,
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.refresh, size: 15),
                    tooltip: 'Refresh',
                    color: AppColors.textMuted,
                    onPressed: controller.refresh,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
          ),
          const SizedBox(width: AppSpacing.s8),
          ValueListenableBuilder<bool>(
            valueListenable: controller.loadingNotifier,
            builder: (context, loading, child) => _UploadButton(
              onTap: loading ? null : onUpload,
            ),
          ),
        ],
      ),
    );
  }
}

class _Breadcrumb extends StatelessWidget {
  final String path;
  final ValueChanged<String> onNavigate;

  const _Breadcrumb({required this.path, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final parts = path.split('/').where((p) => p.isNotEmpty).toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      reverse: true,
      child: Row(
        children: [
          _crumb('/', () => onNavigate('/')),
          for (var i = 0; i < parts.length; i++) ...[
            const Icon(Icons.chevron_right, size: 14, color: AppColors.textMuted),
            _crumb(parts[i], () {
              final p = '/${parts.sublist(0, i + 1).join('/')}';
              onNavigate(p);
            }),
          ],
        ],
      ),
    );
  }

  Widget _crumb(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Text(
          label,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _UploadButton extends StatelessWidget {
  final VoidCallback? onTap;
  const _UploadButton({this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s12,
          vertical: AppSpacing.s4,
        ),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.12),
          border: Border.all(
            color: AppColors.accent.withValues(alpha: 0.3),
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.upload_outlined,
              size: 13,
              color: onTap == null
                  ? AppColors.textMuted
                  : AppColors.accent,
            ),
            const SizedBox(width: AppSpacing.s4),
            Text(
              'Upload',
              style: TextStyle(
                color: onTap == null
                    ? AppColors.textMuted
                    : AppColors.accent,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Browser ───────────────────────────────────────────────────────────────────

class _SftpBrowser extends StatelessWidget {
  final SftpController controller;
  final Future<void> Function(SftpEntry) onDownload;
  final void Function(SftpEntry) onEdit;
  final Future<void> Function(SftpEntry) onRename;
  final Future<void> Function(SftpEntry) onDelete;

  const _SftpBrowser({
    required this.controller,
    required this.onDownload,
    required this.onEdit,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: controller.loadingNotifier,
      builder: (context, loading, child) {
        return ValueListenableBuilder<String?>(
          valueListenable: controller.errorNotifier,
          builder: (context, error, child) {
            if (error != null) {
              return _ErrorState(message: error, onRetry: controller.refresh);
            }
            return ValueListenableBuilder<List<SftpEntry>>(
              valueListenable: controller.entriesNotifier,
              builder: (context, entries, child) {
                if (loading && entries.isEmpty) {
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
                if (entries.isEmpty) {
                  return const Center(
                    child: Text(
                      'Empty directory',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: entries.length,
                  itemBuilder: (context, i) {
                    final entry = entries[i];
                    return SftpEntryRow(
                      entry: entry,
                      onTap: () => controller.navigate(entry.path),
                      onDownload: () => onDownload(entry),
                      onEdit: entry.isDirectory ? null : () => onEdit(entry),
                      onRename: () => onRename(entry),
                      onDelete: () => onDelete(entry),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

// ── Empty / Error states ──────────────────────────────────────────────────────

class _NoSessionState extends StatelessWidget {
  const _NoSessionState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.folder_open_outlined,
            size: 40,
            color: AppColors.textMuted.withValues(alpha: 0.25),
          ),
          const SizedBox(height: AppSpacing.s16),
          const Text(
            'No active session',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppSpacing.s8),
          const Text(
            'Connect to a host from the Hosts tab.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 32, color: Color(0xFFF87171)),
          const SizedBox(height: AppSpacing.s16),
          Text(
            message,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.s16),
          GestureDetector(
            onTap: onRetry,
            child: const Text(
              'Retry',
              style: TextStyle(
                color: AppColors.accent,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Dialogs ───────────────────────────────────────────────────────────────────

class _RenameDialog extends StatelessWidget {
  final TextEditingController controller;
  const _RenameDialog({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.border),
      ),
      title: const Text(
        'Rename',
        style: TextStyle(color: AppColors.text, fontSize: 15),
      ),
      content: TextField(
        controller: controller,
        autofocus: true,
        style: const TextStyle(color: AppColors.text, fontSize: 13),
        onSubmitted: (v) => Navigator.of(context).pop(v),
        decoration: InputDecoration(
          filled: true,
          fillColor: AppColors.background,
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
              color: AppColors.accent.withValues(alpha: 0.6),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Cancel',
            style: TextStyle(color: AppColors.textMuted),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(controller.text),
          child: const Text(
            'Rename',
            style: TextStyle(color: AppColors.accent),
          ),
        ),
      ],
    );
  }
}

class _DeleteDialog extends StatelessWidget {
  final SftpEntry entry;
  const _DeleteDialog({required this.entry});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.border),
      ),
      title: const Text(
        'Delete',
        style: TextStyle(color: AppColors.text, fontSize: 15),
      ),
      content: Text(
        'Delete "${entry.name}"? This cannot be undone.',
        style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text(
            'Cancel',
            style: TextStyle(color: AppColors.textMuted),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text(
            'Delete',
            style: TextStyle(color: Color(0xFFF87171)),
          ),
        ),
      ],
    );
  }
}
