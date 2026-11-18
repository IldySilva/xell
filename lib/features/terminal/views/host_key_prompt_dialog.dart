import 'package:material_ui/material_ui.dart';
import '../../../app/app_theme.dart';
import '../../hosts/models/ssh_host.dart';
import '../../hosts/services/host_key_verifier.dart';

const _kDanger = Color(0xFFF87171);

/// Asks the user to trust an unknown server key, or warns that a known
/// server's key changed. Resolves to true only on an explicit "trust" click.
Future<bool> showHostKeyPromptDialog(
  BuildContext context,
  SshHost host,
  HostKeyCheck check,
) async {
  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => HostKeyPromptDialog(host: host, check: check),
  );
  return ok ?? false;
}

class HostKeyPromptDialog extends StatelessWidget {
  final SshHost host;
  final HostKeyCheck check;

  const HostKeyPromptDialog({
    super.key,
    required this.host,
    required this.check,
  });

  bool get _changed => check.status == HostKeyStatus.changed;

  @override
  Widget build(BuildContext context) {
    final target = '${host.username}@${host.hostname}'
        '${host.port == 22 ? '' : ':${host.port}'}';

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 460),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(
            color: _changed ? _kDanger.withValues(alpha: 0.6) : AppColors.border,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(AppSpacing.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  _changed ? Icons.gpp_bad_outlined : Icons.verified_user_outlined,
                  size: 18,
                  color: _changed ? _kDanger : AppColors.accent,
                ),
                const SizedBox(width: AppSpacing.s8),
                Flexible(
                  child: Text(
                    _changed ? 'Host key changed' : 'Trust this server?',
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s8),
            Text(
              _changed
                  ? 'The key presented by $target is different from the one you '
                      'trusted before. Someone may be intercepting the connection, '
                      'or the server was reinstalled. Only continue if you know why '
                      'the key changed.'
                  : 'This is the first connection to $target. Check that the '
                      'fingerprint below matches the server before trusting it.',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5, height: 1.4),
            ),
            const SizedBox(height: AppSpacing.s16),
            if (_changed && check.previous != null) ...[
              _FingerprintBox(label: 'Previously trusted', value: check.previous!),
              const SizedBox(height: AppSpacing.s8),
            ],
            _FingerprintBox(
              label: _changed ? 'Presented now' : 'Fingerprint',
              value: check.fingerprint,
              highlight: _changed,
            ),
            const SizedBox(height: AppSpacing.s12),
            const Text(
              'On the server: ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 11.5,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: AppSpacing.s24),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: AppSpacing.s12,
              runSpacing: AppSpacing.s8,
              children: [
                _Button(
                  label: 'Cancel',
                  onTap: () => Navigator.of(context).pop(false),
                ),
                _Button(
                  label: _changed ? 'Replace key and connect' : 'Trust and connect',
                  filled: _changed ? _kDanger : AppColors.accent,
                  onTap: () => Navigator.of(context).pop(true),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FingerprintBox extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _FingerprintBox({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(
          color: highlight ? _kDanger.withValues(alpha: 0.5) : AppColors.border,
        ),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
          const SizedBox(height: AppSpacing.s4),
          SelectableText(
            value,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 12.5,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

class _Button extends StatelessWidget {
  final String label;
  final Color? filled;
  final VoidCallback onTap;

  const _Button({required this.label, required this.onTap, this.filled});

  @override
  Widget build(BuildContext context) {
    final isFilled = filled != null;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isFilled ? AppSpacing.s16 : AppSpacing.s12,
            vertical: AppSpacing.s8,
          ),
          decoration: BoxDecoration(
            color: filled,
            border: isFilled ? null : Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isFilled ? Colors.white : AppColors.textMuted,
              fontSize: 13,
              fontWeight: isFilled ? FontWeight.w500 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}
