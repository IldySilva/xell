import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import '../../../app/app_theme.dart';
import '../controllers/host_controller.dart';
import '../models/ssh_host.dart';

class HostFormPage extends StatefulWidget {
  final HostController controller;
  final SshHost? host;

  const HostFormPage({super.key, required this.controller, this.host});

  @override
  State<HostFormPage> createState() => _HostFormPageState();
}

class _HostFormPageState extends State<HostFormPage> {
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
      setState(() => _keyPath.text = result.files.single.path!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textMuted),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _isEdit ? 'Edit Host' : 'New Host',
          style: const TextStyle(
            color: AppColors.text,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.accent,
                      ),
                    )
                  : Text(
                      _isEdit ? 'Save' : 'Add',
                      style: TextStyle(
                        color: _saving ? AppColors.textMuted : AppColors.accent,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.s24,
            AppSpacing.s24,
            AppSpacing.s24,
            MediaQuery.of(context).padding.bottom + AppSpacing.s32,
          ),
          children: [
            _field(
              label: 'Name',
              controller: _name,
              hint: 'Production VPS',
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: AppSpacing.s16),
            _field(
              label: 'Hostname / IP',
              controller: _hostname,
              hint: '192.168.1.10',
              keyboardType: TextInputType.url,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                if (v.trim().contains(' ')) return 'Invalid hostname';
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.s16),
            _field(
              label: 'Port',
              controller: _port,
              hint: '22',
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) {
                final n = int.tryParse(v ?? '');
                if (n == null || n < 1 || n > 65535) return 'Invalid port';
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.s16),
            _field(
              label: 'Username',
              controller: _username,
              hint: 'root',
              keyboardType: TextInputType.text,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: AppSpacing.s32),
            _label('Authentication'),
            const SizedBox(height: AppSpacing.s12),
            _AuthTypeSelector(
              value: _authType,
              onChanged: (v) => setState(() => _authType = v),
            ),
            const SizedBox(height: AppSpacing.s16),
            _buildAuthSection(),
            const SizedBox(height: AppSpacing.s32),
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
            const SizedBox(height: AppSpacing.s12),
            _rawField(
              controller: _keyPath,
              hint: Platform.isIOS || Platform.isAndroid
                  ? 'Paste key path...'
                  : '/Users/you/.ssh/id_rsa',
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Key path required' : null,
            ),
            if (!(Platform.isIOS || Platform.isAndroid)) ...[
              const SizedBox(height: AppSpacing.s8),
              Align(
                alignment: Alignment.centerLeft,
                child: _BrowseButton(onTap: _pickKeyFile),
              ),
            ],
            const SizedBox(height: AppSpacing.s12),
            _infoBox(
              icon: Icons.info_outline,
              text: 'Passphrase will be stored securely when connecting.',
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

  Widget _field({
    required String label,
    required TextEditingController controller,
    String? hint,
    String? Function(String?)? validator,
    int maxLines = 1,
    TextInputType? keyboardType,
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
          keyboardType: keyboardType,
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
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textInputAction:
          maxLines > 1 ? TextInputAction.newline : TextInputAction.next,
      style: const TextStyle(color: AppColors.text, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 15),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s16,
          vertical: AppSpacing.s12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: AppColors.accent.withValues(alpha: 0.6),
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFF87171)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFF87171)),
        ),
        errorStyle: const TextStyle(fontSize: 12, color: Color(0xFFF87171)),
      ),
    );
  }

  Widget _label(String text) => Text(
    text,
    style: const TextStyle(
      color: AppColors.textMuted,
      fontSize: 12,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.3,
    ),
  );

  Widget _infoBox({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textMuted),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
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
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.s12),
              margin: EdgeInsets.only(
                right: type != AuthType.values.last ? AppSpacing.s8 : 0,
              ),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.accent.withValues(alpha: 0.12)
                    : AppColors.surface,
                border: Border.all(
                  color: selected ? AppColors.accent : AppColors.border,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _label(type),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
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

class _BrowseButton extends StatelessWidget {
  final VoidCallback onTap;
  const _BrowseButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
          'Browse',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
      ),
    );
  }
}
