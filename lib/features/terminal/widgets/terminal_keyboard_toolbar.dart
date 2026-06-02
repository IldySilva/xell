import 'package:flutter/material.dart';
import '../../../app/app_theme.dart';

// Sequences to send for each key.
const _kKeys = [
  ('Esc', '\x1b'),
  ('Tab', '\t'),
  ('↑', '\x1b[A'),
  ('↓', '\x1b[B'),
  ('←', '\x1b[D'),
  ('→', '\x1b[C'),
  ('^C', '\x03'),
  ('^D', '\x04'),
  ('^Z', '\x1a'),
  ('^L', '\x0c'),
  ('|', '|'),
  ('~', '~'),
  ('`', '`'),
  ('-', '-'),
  ('/', '/'),
  ('\\', '\\'),
];

class TerminalKeyboardToolbar extends StatelessWidget {
  final void Function(String sequence) onSendKey;

  const TerminalKeyboardToolbar({super.key, required this.onSendKey});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: _kKeys.length,
        itemBuilder: (context, i) {
          final (label, seq) = _kKeys[i];
          final isCtrl = label.startsWith('^');
          return _KeyButton(label: label, sequence: seq, isCtrl: isCtrl, onTap: onSendKey);
        },
      ),
    );
  }
}

class _KeyButton extends StatefulWidget {
  final String label;
  final String sequence;
  final bool isCtrl;
  final void Function(String) onTap;

  const _KeyButton({
    required this.label,
    required this.sequence,
    required this.isCtrl,
    required this.onTap,
  });

  @override
  State<_KeyButton> createState() => _KeyButtonState();
}

class _KeyButtonState extends State<_KeyButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.isCtrl ? AppColors.accent : AppColors.textMuted;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap(widget.sequence);
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
        constraints: const BoxConstraints(minWidth: 44),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: _pressed
              ? (widget.isCtrl
                    ? AppColors.accent.withValues(alpha: 0.25)
                    : AppColors.border.withValues(alpha: 0.9))
              : AppColors.background.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: widget.isCtrl
                ? AppColors.accent.withValues(alpha: _pressed ? 0.6 : 0.3)
                : AppColors.border,
          ),
        ),
        child: Center(
          child: Text(
            widget.label,
            style: TextStyle(
              color: _pressed ? color : color.withValues(alpha: 0.85),
              fontSize: 12.5,
              fontWeight: widget.isCtrl ? FontWeight.w600 : FontWeight.w400,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ),
    );
  }
}
