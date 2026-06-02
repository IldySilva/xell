import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../../app/app_theme.dart';

const double sidebarCollapsedWidth = 80.0;
const double sidebarDefaultWidth = 220.0;

// Height reserved for macOS traffic light buttons (~76px wide, ~52px tall)
const double _trafficLightsClearance = 52.0;

class Sidebar extends StatelessWidget {
  final int selectedIndex;
  final bool isCollapsed;
  final ValueChanged<int> onItemSelected;
  final VoidCallback onSettingsTap;
  final VoidCallback onToggleCollapse;

  const Sidebar({
    super.key,
    required this.selectedIndex,
    required this.isCollapsed,
    required this.onItemSelected,
    required this.onSettingsTap,
    required this.onToggleCollapse,
  });

  static const _navItems = [
    (icon: Icons.dns_outlined, label: 'Hosts'),
    (icon: Icons.terminal_outlined, label: 'Terminal'),
    (icon: Icons.folder_open_outlined, label: 'SFTP'),
    (icon: Icons.alt_route_outlined, label: 'Tunnels'),
    (icon: Icons.code_outlined, label: 'Snippets'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        // On macOS the window has native vibrancy; use a semi-transparent
        // tint so content is still readable while the blur shows through.
        color: Platform.isMacOS
            ? AppColors.surface.withValues(alpha: 0.72)
            : AppColors.surface,
        border: const Border(right: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (Platform.isMacOS || Platform.isLinux || Platform.isWindows)
            DragToMoveArea(child: SizedBox(height: _trafficLightsClearance))
          else
            const SizedBox(height: _trafficLightsClearance),
          ..._navItems.indexed.map(
            (e) => _NavItem(
              icon: e.$2.icon,
              label: e.$2.label,
              isSelected: selectedIndex == e.$1,
              isCollapsed: isCollapsed,
              onTap: () => onItemSelected(e.$1),
            ),
          ),
          const Spacer(),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.s4),
          _NavItem(
            icon: Icons.settings_outlined,
            label: 'Settings',
            isSelected: selectedIndex == 5,
            isCollapsed: isCollapsed,
            onTap: onSettingsTap,
          ),
          _CollapseToggle(
            isCollapsed: isCollapsed,
            onTap: onToggleCollapse,
          ),
          const SizedBox(height: AppSpacing.s8),
        ],
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final bool isCollapsed;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.isCollapsed,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.isCollapsed ? widget.label : '',
      preferBelow: false,
      waitDuration: const Duration(milliseconds: 500),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            margin: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s8,
              vertical: 2,
            ),
            padding: EdgeInsets.symmetric(
              horizontal: widget.isCollapsed ? AppSpacing.s8 : AppSpacing.s12,
              vertical: AppSpacing.s8,
            ),
            decoration: BoxDecoration(
              color: widget.isSelected
                  ? AppColors.accent.withValues(alpha: 0.12)
                  : _hovered
                  ? AppColors.border.withValues(alpha: 0.5)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(7),
            ),
            child: widget.isCollapsed
                ? Center(
                    child: Icon(
                      widget.icon,
                      size: 18,
                      color: widget.isSelected
                          ? AppColors.accent
                          : AppColors.textMuted,
                    ),
                  )
                : Row(
                    children: [
                      Icon(
                        widget.icon,
                        size: 16,
                        color: widget.isSelected
                            ? AppColors.accent
                            : AppColors.textMuted,
                      ),
                      const SizedBox(width: AppSpacing.s12),
                      Text(
                        widget.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: widget.isSelected
                              ? FontWeight.w500
                              : FontWeight.w400,
                          color: widget.isSelected
                              ? AppColors.text
                              : AppColors.textMuted,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _CollapseToggle extends StatefulWidget {
  final bool isCollapsed;
  final VoidCallback onTap;

  const _CollapseToggle({required this.isCollapsed, required this.onTap});

  @override
  State<_CollapseToggle> createState() => _CollapseToggleState();
}

class _CollapseToggleState extends State<_CollapseToggle> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.isCollapsed ? 'Expand sidebar' : 'Collapse sidebar',
      preferBelow: false,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            margin: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s8,
              vertical: 2,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s12,
              vertical: AppSpacing.s8,
            ),
            decoration: BoxDecoration(
              color: _hovered
                  ? AppColors.border.withValues(alpha: 0.5)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Center(
              child: Icon(
                widget.isCollapsed ? Icons.chevron_right : Icons.chevron_left,
                size: 16,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
