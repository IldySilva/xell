import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../app/app_theme.dart';
import '../controllers/host_controller.dart';
import '../models/ssh_host.dart';

class HostFormDialog extends StatefulWidget {
  final HostController controller;

  /// Null = create mode, non-null = edit mode.
  final SshHost? host;

  const HostFormDialog({super.key, required this.controller, this.host});

  @override
  State<HostFormDialog> createState() => _HostFormDialogState();
}

class _HostFormDialogState extends State<HostFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _hostname;
  late final TextEditingController _port;
  late final TextEditingController _username;
  late final TextEditingController _keyPath;
  late final TextEditingController _tags;
  late final TextEditingController _notes;

  late AuthType _authType;
  bool _saving = false;
  bool _keyDropActive = false;

  bool get _isEdit => widget.host != null;

  @override
  void initState() {
    super.initState();
    final h = widget.host;
    _name = TextEditingController(text: h?.name ?? '');
    _hostname = TextEditingController(text: h?.hostname ?? '');
    _port = TextEditingController(text: (h?.port ?? 22).toString());
    _username = TextEditingController(text: h?.username ?? '');
    _keyPath = TextEditingController(text: h?.privateKeyPath ?? '');
    _tags = TextEditingController(text: h?.tags.join(', ') ?? '');
    _notes = TextEditingController(text: h?.notes ?? '');
    _authType = h?.authType ?? AuthType.password;
  }

  @override
  void dispose() {
    _name.dispose();
    _hostname.dispose();
    _port.dispose();
    _username.dispose();
    _keyPath.dispose();
    _tags.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final tags = _tags.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    final host = SshHost(
      id: widget.host?.id ?? SshHost.generateId(),
      name: _name.text.trim(),
      hostname: _hostname.text.trim(),
      port: int.parse(_port.text.trim()),
      username: _username.text.trim(),
      authType: _authType,
      privateKeyPath:
          _authType == AuthType.privateKey ? _keyPath.text.trim() : null,
      tags: tags,
      isFavorite: widget.host?.isFavorite ?? false,
      lastConnectedAt: widget.host?.lastConnectedAt,
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    );

    if (_isEdit) {
      await widget.controller.update(host);
    } else {
      await widget.controller.add(host);
    }

    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _pickKeyFile() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Select Private Key',
      allowMultiple: false,
    );
    if (result != null && result.files.single.path != null) {
      _keyPath.text = result.files.single.path!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 520,
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.s24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _field(
                        label: 'Name',
                        controller: _name,
                        hint: 'Production VPS',
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: AppSpacing.s16),
                      Row(
                        children: [
                          Expanded(
                            child: _field(
                              label: 'Hostname / IP',
                              controller: _hostname,
                              hint: '192.168.1.10',
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Required';
                                }
                                if (v.trim().contains(' ')) {
                                  return 'Invalid hostname';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: AppSpacing.s12),
                          SizedBox(
                            width: 90,
                            child: _field(
                              label: 'Port',
                              controller: _port,
                              hint: '22',
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              validator: (v) {
                                final n = int.tryParse(v ?? '');
                                if (n == null || n < 1 || n > 65535) {
                                  return 'Invalid';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.s16),
                      _field(
                        label: 'Username',
                        controller: _username,
                        hint: 'root',
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: AppSpacing.s24),
                      _label('Authentication'),
                      const SizedBox(height: AppSpacing.s8),
                      _AuthTypeSelector(
                        value: _authType,
                        onChanged: (v) => setState(() => _authType = v),
                      ),
                      const SizedBox(height: AppSpacing.s16),
                      _buildAuthSection(),
                      const SizedBox(height: AppSpacing.s24),
                      _field(
                        label: 'Tags',
                        controller: _tags,
                        hint: 'production, aws, staging',
                      ),
                      const SizedBox(height: AppSpacing.s16),
                      _field(
                        label: 'Notes',
                        controller: _notes,
                        hint: 'Optional notes about this host',
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
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
          Text(
            _isEdit ? 'Edit Host' : 'New Host',
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 15,
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

  Widget _buildAuthSection() {
    return switch (_authType) {
      AuthType.password => _infoBox(
          icon: Icons.lock_outline,
          text:
              'Password will be stored securely when you first connect to this host.',
        ),
      AuthType.privateKey => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _label('Private Key Path'),
            const SizedBox(height: AppSpacing.s8),
            DropTarget(
              onDragEntered: (_) => setState(() => _keyDropActive = true),
              onDragExited: (_) => setState(() => _keyDropActive = false),
              onDragDone: (details) {
                setState(() => _keyDropActive = false);
                final path = details.files.firstOrNull?.path;
                if (path != null) _keyPath.text = path;
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(7),
                  border: _keyDropActive
                      ? Border.all(
                          color: AppColors.accent.withValues(alpha: 0.6),
                          width: 1.5,
                        )
                      : null,
                  color: _keyDropActive
                      ? AppColors.accent.withValues(alpha: 0.06)
                      : null,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _rawField(
                        controller: _keyPath,
                        hint: _keyDropActive
                            ? 'Drop key file here…'
                            : '/Users/you/.ssh/id_rsa',
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Key path required'
                            : null,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    _SecondaryButton(
                      label: 'Browse',
                      onTap: _pickKeyFile,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s12),
            _infoBox(
              icon: Icons.info_outline,
              text: _keyDropActive
                  ? 'Drop the private key file to set its path.'
                  : 'Passphrase will be stored securely when connecting.',
            ),
          ],
        ),
      AuthType.sshAgent => _infoBox(
          icon: Icons.vpn_key_outlined,
          text:
              'SSH Agent will be used for authentication. No credentials needed.',
        ),
    };
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s24,
        vertical: AppSpacing.s16,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _SecondaryButton(
            label: 'Cancel',
            onTap: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: AppSpacing.s12),
          _PrimaryButton(
            label: _isEdit ? 'Save Changes' : 'Add Host',
            loading: _saving,
            onTap: _save,
          ),
        ],
      ),
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    String? hint,
    String? Function(String?)? validator,
    int maxLines = 1,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        const SizedBox(height: AppSpacing.s8),
        _rawField(
          controller: controller,
          hint: hint,
          validator: validator,
          maxLines: maxLines,
          inputFormatters: inputFormatters,
        ),
      ],
    );
  }

  Widget _rawField({
    required TextEditingController controller,
    String? hint,
    String? Function(String?)? validator,
    int maxLines = 1,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      maxLines: maxLines,
      inputFormatters: inputFormatters,
      style: const TextStyle(color: AppColors.text, fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
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
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: const BorderSide(color: Color(0xFFF87171)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: const BorderSide(color: Color(0xFFF87171)),
        ),
        errorStyle: const TextStyle(fontSize: 11, color: Color(0xFFF87171)),
      ),
    );
  }

  Widget _label(String text) => Text(
    text,
    style: const TextStyle(
      color: AppColors.textMuted,
      fontSize: 11.5,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.3,
    ),
  );

  Widget _infoBox({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.textMuted),
          const SizedBox(width: AppSpacing.s8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthTypeSelector extends StatelessWidget {
  final AuthType value;
  final ValueChanged<AuthType> onChanged;

  const _AuthTypeSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: AuthType.values.map((type) {
        final selected = value == type;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(type),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
              margin: EdgeInsets.only(
                right: type != AuthType.values.last ? AppSpacing.s8 : 0,
              ),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.accent.withValues(alpha: 0.12)
                    : AppColors.background,
                border: Border.all(
                  color: selected ? AppColors.accent : AppColors.border,
                ),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(
                _label(type),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                  color: selected ? AppColors.accent : AppColors.textMuted,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  String _label(AuthType type) => switch (type) {
    AuthType.password => 'Password',
    AuthType.privateKey => 'Private Key',
    AuthType.sshAgent => 'SSH Agent',
  };
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onTap;

  const _PrimaryButton({
    required this.label,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s16,
          vertical: AppSpacing.s8,
        ),
        decoration: BoxDecoration(
          color: AppColors.accent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: loading
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
      ),
    );
  }
}

class _SecondaryButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;

  const _SecondaryButton({required this.label, required this.onTap});

  @override
  State<_SecondaryButton> createState() => _SecondaryButtonState();
}

class _SecondaryButtonState extends State<_SecondaryButton> {
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
            vertical: AppSpacing.s8,
          ),
          decoration: BoxDecoration(
            color: _hovered ? AppColors.border : Colors.transparent,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text(
            widget.label,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
