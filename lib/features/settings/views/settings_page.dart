import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../app/app_theme.dart';
import '../../../core/update_service.dart';
import '../../terminal/models/terminal_theme_presets.dart';
import '../controllers/settings_controller.dart';

class SettingsPage extends StatelessWidget {
  final SettingsController controller;

  const SettingsPage({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s24,
        AppSpacing.s24,
        AppSpacing.s24,
        AppSpacing.s48,
      ),
      children: [
        const Text(
          'Settings',
          style: TextStyle(
            color: AppColors.text,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.s32),
        _Section(
          title: 'Terminal',
          children: [
            _FontSizeSetting(controller: controller),
            _TerminalThemeSetting(controller: controller),
          ],
        ),
        const SizedBox(height: AppSpacing.s32),
        _Section(
          title: 'Appearance',
          children: [
            _ThemeModeSetting(controller: controller),
            _AccentColorSetting(controller: controller),
          ],
        ),
        const SizedBox(height: AppSpacing.s32),
        _Section(
          title: 'Data',
          children: [
            _ClearDataSetting(controller: controller),
          ],
        ),
        const SizedBox(height: AppSpacing.s32),
        _Section(
          title: 'Support',
          children: [
            _ReportBugSetting(),
          ],
        ),
        const SizedBox(height: AppSpacing.s48),
        const _AppInfo(),
      ],
    );
  }
}

// ── Sections ──────────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: AppSpacing.s12),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: children
                .expand((w) => [w, const Divider(height: 1)])
                .toList()
              ..removeLast(),
          ),
        ),
      ],
    );
  }
}

class _SettingRow extends StatelessWidget {
  final String label;
  final String? description;
  final Widget trailing;

  const _SettingRow({
    required this.label,
    this.description,
    required this.trailing,
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: AppColors.text, fontSize: 13),
                ),
                if (description != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    description!,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.s16),
          trailing,
        ],
      ),
    );
  }
}

// ── Font size ─────────────────────────────────────────────────────────────────

class _FontSizeSetting extends StatelessWidget {
  final SettingsController controller;
  const _FontSizeSetting({required this.controller});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: controller.fontSizeNotifier,
      builder: (context, size, child) {
        return _SettingRow(
          label: 'Font Size',
          description: 'Terminal font size in points.',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: terminalFontSizes.map((s) {
              final selected = s == size;
              return GestureDetector(
                onTap: () => controller.setFontSize(s),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  margin: const EdgeInsets.only(left: AppSpacing.s4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s8,
                    vertical: AppSpacing.s4,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.accent.withValues(alpha: 0.15)
                        : Colors.transparent,
                    border: Border.all(
                      color: selected ? AppColors.accent : AppColors.border,
                    ),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    s == s.truncateToDouble() ? s.toInt().toString() : s.toString(),
                    style: TextStyle(
                      color: selected ? AppColors.accent : AppColors.textMuted,
                      fontSize: 11.5,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

// ── Terminal theme ────────────────────────────────────────────────────────────

class _TerminalThemeSetting extends StatelessWidget {
  final SettingsController controller;
  const _TerminalThemeSetting({required this.controller});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TerminalThemeName>(
      valueListenable: controller.terminalThemeNotifier,
      builder: (context, current, _) {
        return _SettingRow(
          label: 'Terminal Theme',
          description: 'Color scheme for the terminal.',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: terminalThemePresets.map((preset) {
              final selected = preset.name == current;
              return Tooltip(
                message: preset.name.label,
                child: GestureDetector(
                  onTap: () => controller.setTerminalTheme(preset.name),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    margin: const EdgeInsets.only(left: AppSpacing.s8),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: preset.background,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: selected ? AppColors.text : AppColors.border,
                        width: selected ? 2 : 1,
                      ),
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                color: preset.accent.withValues(alpha: 0.4),
                                blurRadius: 4,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    child: selected
                        ? Center(
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: preset.accent,
                                shape: BoxShape.circle,
                              ),
                            ),
                          )
                        : null,
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

// ── Theme mode ────────────────────────────────────────────────────────────────

class _ThemeModeSetting extends StatelessWidget {
  final SettingsController controller;
  const _ThemeModeSetting({required this.controller});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, mode, _) {
        final isDark = mode == ThemeMode.dark;
        return _SettingRow(
          label: 'Appearance',
          description: 'Choose between dark and light mode.',
          trailing: GestureDetector(
            onTap: () => controller.setThemeMode(
              isDark ? ThemeMode.light : ThemeMode.dark,
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 48,
              height: 26,
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.accent.withValues(alpha: 0.9)
                    : AppColors.border,
                borderRadius: BorderRadius.circular(13),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeInOut,
                alignment: isDark ? Alignment.centerRight : Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isDark ? Icons.dark_mode : Icons.light_mode,
                      size: 12,
                      color: isDark ? AppColors.accent : AppColors.textMuted,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Accent color ──────────────────────────────────────────────────────────────

class _AccentColorSetting extends StatelessWidget {
  final SettingsController controller;
  const _AccentColorSetting({required this.controller});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Color>(
      valueListenable: controller.accentColorNotifier,
      builder: (context, accent, child) {
        return _SettingRow(
          label: 'Accent Color',
          description: 'Color used for active states and highlights.',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: accentColorPresets.map((color) {
              final selected = color.toARGB32() == accent.toARGB32();
              return GestureDetector(
                onTap: () => controller.setAccentColor(color),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  margin: const EdgeInsets.only(left: AppSpacing.s8),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? AppColors.text : Colors.transparent,
                      width: 2,
                    ),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: color.withValues(alpha: 0.5),
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

// ── Clear data ────────────────────────────────────────────────────────────────

class _ClearDataSetting extends StatelessWidget {
  final SettingsController controller;
  const _ClearDataSetting({required this.controller});

  @override
  Widget build(BuildContext context) {
    return _SettingRow(
      label: 'Clear Local Data',
      description: 'Removes all hosts and settings. Cannot be undone.',
      trailing: _DangerButton(
        label: 'Clear All',
        onTap: () => _confirm(context),
      ),
    );
  }

  Future<void> _confirm(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppColors.border),
        ),
        title: const Text(
          'Clear all data?',
          style: TextStyle(color: AppColors.text, fontSize: 15),
        ),
        content: const Text(
          'All hosts and settings will be permanently deleted. '
          'Stored credentials will remain in the system keychain.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Clear',
              style: TextStyle(color: Color(0xFFF87171)),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) await controller.clearAllData();
  }
}

class _DangerButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;

  const _DangerButton({required this.label, required this.onTap});

  @override
  State<_DangerButton> createState() => _DangerButtonState();
}

class _DangerButtonState extends State<_DangerButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    const danger = Color(0xFFF87171);
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
            vertical: AppSpacing.s4,
          ),
          decoration: BoxDecoration(
            color: _hovered
                ? danger.withValues(alpha: 0.12)
                : Colors.transparent,
            border: Border.all(color: danger.withValues(alpha: 0.5)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text(
            'Clear All',
            style: TextStyle(
              color: danger,
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Report bug ────────────────────────────────────────────────────────────────

class _ReportBugSetting extends StatelessWidget {
  static final _issuesUri = Uri.parse('https://github.com/IldySilva/xell/issues/new');

  @override
  Widget build(BuildContext context) {
    return _SettingRow(
      label: 'Report a Bug',
      description: 'Open a new issue on GitHub.',
      trailing: GestureDetector(
        onTap: () => launchUrl(_issuesUri, mode: LaunchMode.externalApplication),
        child: const Icon(Icons.open_in_new, size: 15, color: AppColors.textMuted),
      ),
    );
  }
}

// ── App info ──────────────────────────────────────────────────────────────────

class _AppInfo extends StatelessWidget {
  const _AppInfo();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Text(
          'Xell',
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 2),
        Text(
          'Version $kAppVersion — Open Source SSH Workspace',
          style: TextStyle(color: AppColors.textMuted, fontSize: 11),
        ),
      ],
    );
  }
}
