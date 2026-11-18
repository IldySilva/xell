import 'dart:io';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import '../../../../app/app_theme.dart';
import '../controllers/remote_editor_controller.dart';

class RemoteFileEditorPage extends StatefulWidget {
  final RemoteEditorController controller;

  const RemoteFileEditorPage({super.key, required this.controller});

  @override
  State<RemoteFileEditorPage> createState() => _RemoteFileEditorPageState();
}

class _RemoteFileEditorPageState extends State<RemoteFileEditorPage> {
  late final TextEditingController _text;
  bool _initialised = false;

  @override
  void initState() {
    super.initState();
    _text = TextEditingController();
    widget.controller.load().then((_) {
      if (!mounted) return;
      _text.text = widget.controller.contentNotifier.value;
      setState(() => _initialised = true);
    });
    _text.addListener(() => widget.controller.markDirty());
  }

  @override
  void dispose() {
    _text.dispose();
    widget.controller.dispose();
    super.dispose();
  }

  String get _filename {
    final parts = widget.controller.path.split('/');
    return parts.lastWhere((p) => p.isNotEmpty, orElse: () => widget.controller.path);
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await widget.controller.save(_text.text);
    if (ok && mounted) {
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Saved', style: TextStyle(color: AppColors.text, fontSize: 13)),
          backgroundColor: AppColors.surface,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: AppColors.border),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<bool> _confirmDiscard() async {
    if (!widget.controller.dirtyNotifier.value) return true;
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: AppColors.border),
            ),
            title: const Text(
              'Unsaved changes',
              style: TextStyle(color: AppColors.text, fontSize: 15),
            ),
            content: const Text(
              'You have unsaved changes. Discard them?',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel',
                    style: TextStyle(color: AppColors.textMuted)),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Discard',
                    style: TextStyle(color: Color(0xFFF87171))),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop =
        Platform.isMacOS || Platform.isLinux || Platform.isWindows;

    final content = CallbackShortcuts(
      bindings: {
        SingleActivator(LogicalKeyboardKey.keyS,
            meta: Platform.isMacOS, control: !Platform.isMacOS): _save,
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            _EditorToolbar(
              filename: _filename,
              path: widget.controller.path,
              controller: widget.controller,
              onSave: _save,
              onClose: () async {
                final navigator = Navigator.of(context);
                if (await _confirmDiscard()) {
                  if (mounted) navigator.pop();
                }
              },
            ),
            ValueListenableBuilder<String?>(
              valueListenable: widget.controller.errorNotifier,
              builder: (_, err, _) {
                if (err == null) return const SizedBox.shrink();
                return Container(
                  width: double.infinity,
                  color: const Color(0xFFF87171).withValues(alpha: 0.1),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    err,
                    style: const TextStyle(
                        color: Color(0xFFF87171), fontSize: 12),
                  ),
                );
              },
            ),
            Expanded(
              child: ValueListenableBuilder<bool>(
                valueListenable: widget.controller.loadingNotifier,
                builder: (_, loading, _) {
                  if (loading) {
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
                  if (!_initialised) return const SizedBox.shrink();
                  return TextField(
                    controller: _text,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 13,
                      fontFamily: 'monospace',
                      height: 1.6,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(16),
                      hintText: 'Empty file',
                      hintStyle: TextStyle(
                          color: AppColors.textMuted, fontSize: 13),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );

    if (!isDesktop) return content;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(40),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 760,
          height: MediaQuery.of(context).size.height * 0.75,
          child: content,
        ),
      ),
    );
  }
}

// ── Toolbar ────────────────────────────────────────────────────────────────────

class _EditorToolbar extends StatelessWidget {
  final String filename;
  final String path;
  final RemoteEditorController controller;
  final VoidCallback onSave;
  final VoidCallback onClose;

  const _EditorToolbar({
    required this.filename,
    required this.path,
    required this.controller,
    required this.onSave,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final mac = Platform.isMacOS;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          const Icon(Icons.insert_drive_file_outlined,
              size: 14, color: AppColors.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ValueListenableBuilder<bool>(
                  valueListenable: controller.dirtyNotifier,
                  builder: (_, dirty, _) => Row(
                    children: [
                      Text(
                        filename,
                        style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (dirty) ...[
                        const SizedBox(width: 6),
                        const Text(
                          '●',
                          style: TextStyle(
                            color: AppColors.accent,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Text(
                  path,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: controller.savingNotifier,
            builder: (_, saving, _) => _ToolbarButton(
              label: saving ? 'Saving…' : 'Save',
              shortcut: mac ? '⌘S' : 'Ctrl+S',
              onTap: saving ? null : onSave,
              primary: true,
            ),
          ),
          const SizedBox(width: 8),
          _CloseButton(onTap: onClose),
        ],
      ),
    );
  }
}

class _ToolbarButton extends StatefulWidget {
  final String label;
  final String shortcut;
  final VoidCallback? onTap;
  final bool primary;

  const _ToolbarButton({
    required this.label,
    required this.shortcut,
    this.onTap,
    this.primary = false,
  });

  @override
  State<_ToolbarButton> createState() => _ToolbarButtonState();
}

class _ToolbarButtonState extends State<_ToolbarButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.shortcut,
      child: MouseRegion(
        cursor: widget.onTap != null
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: widget.primary
                  ? (_hovered
                      ? AppColors.accent.withValues(alpha: 0.9)
                      : AppColors.accent)
                  : (_hovered
                      ? AppColors.border.withValues(alpha: 0.8)
                      : AppColors.border.withValues(alpha: 0.4)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              widget.label,
              style: TextStyle(
                color: widget.primary ? Colors.white : AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CloseButton extends StatefulWidget {
  final VoidCallback onTap;
  const _CloseButton({required this.onTap});

  @override
  State<_CloseButton> createState() => _CloseButtonState();
}

class _CloseButtonState extends State<_CloseButton> {
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
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _hovered
                ? AppColors.border.withValues(alpha: 0.8)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Icon(Icons.close, size: 15, color: AppColors.textMuted),
        ),
      ),
    );
  }
}
