import 'package:material_ui/material_ui.dart';
import '../../../../app/app_theme.dart';
import '../controllers/snippet_controller.dart';
import '../models/snippet.dart';

class SnippetFormDialog extends StatefulWidget {
  final SnippetController controller;
  final Snippet? existing;

  const SnippetFormDialog({super.key, required this.controller, this.existing});

  @override
  State<SnippetFormDialog> createState() => _SnippetFormDialogState();
}

class _SnippetFormDialogState extends State<SnippetFormDialog> {
  late final _titleCtrl =
      TextEditingController(text: widget.existing?.title ?? '');
  late final _commandCtrl =
      TextEditingController(text: widget.existing?.command ?? '');
  late final _descCtrl =
      TextEditingController(text: widget.existing?.description ?? '');
  late final _tagsCtrl =
      TextEditingController(text: widget.existing?.tags.join(', ') ?? '');

  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _commandCtrl.dispose();
    _descCtrl.dispose();
    _tagsCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    final command = _commandCtrl.text.trim();
    if (title.isEmpty || command.isEmpty) return;

    final tags = _tagsCtrl.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    setState(() => _saving = true);
    final snippet = Snippet(
      id: widget.existing?.id ?? Snippet.generateId(),
      title: title,
      command: command,
      description:
          _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      tags: tags,
    );

    if (widget.existing != null) {
      await widget.controller.update(snippet);
    } else {
      await widget.controller.add(snippet);
    }

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.border),
      ),
      child: SizedBox(
        width: 480,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.existing != null ? 'Edit Snippet' : 'New Snippet',
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              _Field(label: 'Title', controller: _titleCtrl),
              const SizedBox(height: 12),
              _Field(
                label: 'Command',
                controller: _commandCtrl,
                monospace: true,
                minLines: 3,
                maxLines: 8,
              ),
              const SizedBox(height: 12),
              _Field(
                label: 'Description (optional)',
                controller: _descCtrl,
              ),
              const SizedBox(height: 12),
              _Field(
                label: 'Tags (comma-separated)',
                controller: _tagsCtrl,
                hint: 'docker, k8s, git',
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _SaveButton(saving: _saving, onTap: _save),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool monospace;
  final int minLines;
  final int? maxLines;
  final String? hint;

  const _Field({
    required this.label,
    required this.controller,
    this.monospace = false,
    this.minLines = 1,
    this.maxLines = 1,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          minLines: minLines,
          maxLines: maxLines,
          style: TextStyle(
            color: AppColors.text,
            fontSize: 13,
            fontFamily: monospace ? 'monospace' : null,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            filled: true,
            fillColor: AppColors.background,
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
              borderSide:
                  const BorderSide(color: AppColors.accent, width: 1.5),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      ],
    );
  }
}

class _SaveButton extends StatefulWidget {
  final bool saving;
  final VoidCallback onTap;
  const _SaveButton({required this.saving, required this.onTap});

  @override
  State<_SaveButton> createState() => _SaveButtonState();
}

class _SaveButtonState extends State<_SaveButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.saving ? null : widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: _hovered
                ? AppColors.accent.withValues(alpha: 0.9)
                : AppColors.accent,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text(
            widget.saving ? 'Saving...' : 'Save',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
