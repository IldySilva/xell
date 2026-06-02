import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import '../../app/app_theme.dart';
import '../../core/window_preferences.dart';
import '../../features/hosts/controllers/host_controller.dart';
import '../../features/hosts/data/credential_storage.dart';
import '../../features/hosts/models/ssh_host.dart';
import '../../features/hosts/views/host_list_page.dart';
import '../../features/terminal/controllers/terminal_controller.dart';
import '../../features/port_forwarding/controllers/tunnel_controller.dart';
import '../../features/port_forwarding/views/tunnel_page.dart';
import '../../features/settings/controllers/settings_controller.dart';
import '../../features/settings/views/settings_page.dart';
import '../../features/sftp/views/sftp_page.dart';
import '../../features/command_palette/views/command_palette.dart';
import '../../features/hosts/views/host_form_dialog.dart';
import '../../features/hosts/views/host_form_page.dart';
import '../../features/hosts/views/ssh_config_import_dialog.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/dock_service.dart';
import '../../core/update_service.dart';
import '../../features/snippets/controllers/snippet_controller.dart';
import '../../features/snippets/views/snippet_list_page.dart';
import '../../features/terminal/controllers/command_history_controller.dart';
import '../../features/terminal/models/terminal_theme_presets.dart';
import '../../features/terminal/views/credential_prompt_dialog.dart';
import '../../features/terminal/views/terminal_page.dart';
import '../widgets/xell_about_dialog.dart';
import 'sidebar.dart';
import 'top_bar.dart';

const double _minSidebarWidth = 180.0;
const double _maxSidebarWidth = 360.0;

bool get _isDesktop =>
    Platform.isMacOS || Platform.isLinux || Platform.isWindows;

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WindowListener {
  int _selectedIndex = 0;
  bool _sidebarCollapsed = false;
  double _sidebarWidth = sidebarDefaultWidth;
  bool _isFullScreen = false;

  late final HostController _hostController;
  late final TerminalController _terminalController;
  late final SettingsController _settingsController;
  late final TunnelController _tunnelController;
  late final SnippetController _snippetController;
  late final CommandHistoryController _historyController;
  final _credentials = CredentialStorage();
  final _updateNotifier = ValueNotifier<String?>(null);
  StreamSubscription<String>? _commandStreamSub;

  @override
  void initState() {
    super.initState();
    if (_isDesktop) windowManager.addListener(this);
    _hostController = HostController()..load();
    _terminalController = TerminalController()
      ..onOsDetected = (hostId, os) {
        final hosts = _hostController.hostsNotifier.value;
        final host = hosts.where((h) => h.id == hostId).firstOrNull;
        if (host != null) _hostController.update(host.copyWith(detectedOs: os));
      };
    _settingsController = SettingsController()..load();
    _tunnelController = TunnelController();
    _snippetController = SnippetController();
    _historyController = CommandHistoryController();
    _terminalController.activeSessionIdNotifier.addListener(_updateWindowTitle);
    _terminalController.sessionsNotifier.addListener(_updateDockState);
    _commandStreamSub = _terminalController.commandTypedStream
        .listen((cmd) => _historyController.add(cmd));
    // Defer non-critical loads until after first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _snippetController.load();
      _historyController.load();
    });
    UpdateService.checkForUpdate().then((v) => _updateNotifier.value = v);
  }

  @override
  void dispose() {
    _commandStreamSub?.cancel();
    _terminalController.activeSessionIdNotifier.removeListener(_updateWindowTitle);
    _terminalController.sessionsNotifier.removeListener(_updateDockState);
    if (_isDesktop) windowManager.removeListener(this);
    _hostController.dispose();
    _terminalController.dispose();
    _settingsController.dispose();
    _tunnelController.dispose();
    _snippetController.dispose();
    _historyController.dispose();
    _updateNotifier.dispose();
    super.dispose();
  }

  void _updateDockState() {
    final count = _terminalController.sessionsNotifier.value.length;
    DockService.setSessionCount(count);
    final recent = _hostController.hostsNotifier.value
        .where((h) => h.lastConnectedAt != null)
        .toList()
      ..sort((a, b) => b.lastConnectedAt!.compareTo(a.lastConnectedAt!));
    DockService.setRecentHosts(recent.take(5).map((h) => h.name).toList());
  }

  void _updateWindowTitle() {
    if (!_isDesktop) return;
    final session = _terminalController.activeSession;
    final title = session != null
        ? 'Xell — ${session.host.hostname}'
        : 'Xell';
    windowManager.setTitle(title);
  }

  Future<void> _handleReconnect(String sessionId) async {
    final session = _terminalController.sessions.firstWhere((s) => s.id == sessionId);
    final host = session.host;
    await _terminalController.closeSession(sessionId);
    await _tunnelController.closeForSession(sessionId);
    await _handleConnect(host);
  }

  @override
  void onWindowResized() => WindowPreferences.save();

  @override
  void onWindowMoved() => WindowPreferences.save();

  @override
  void onWindowEnterFullScreen() => setState(() => _isFullScreen = true);

  @override
  void onWindowLeaveFullScreen() => setState(() => _isFullScreen = false);

  void _toggleFullscreen() {
    if (_isDesktop) windowManager.setFullScreen(!_isFullScreen);
  }

  void _closeActiveTab() {
    final id = _terminalController.activeSessionIdNotifier.value;
    if (id != null) _terminalController.closeSession(id);
  }

  void _selectTab(int index) => setState(() => _selectedIndex = index);

  Map<ShortcutActivator, VoidCallback> get _shortcuts {
    if (!_isDesktop) return {};
    final mac = Platform.isMacOS;
    return {
      SingleActivator(LogicalKeyboardKey.keyK, meta: mac, control: !mac):
          _showCommandPalette,
      SingleActivator(LogicalKeyboardKey.keyN, meta: mac, control: !mac):
          _showCommandPalette,
      SingleActivator(LogicalKeyboardKey.comma, meta: mac, control: !mac):
          () => setState(() => _selectedIndex = 5),
      if (mac)
        const SingleActivator(
          LogicalKeyboardKey.keyF,
          control: true,
          meta: true,
        ): _toggleFullscreen
      else
        const SingleActivator(LogicalKeyboardKey.f11): _toggleFullscreen,
      SingleActivator(LogicalKeyboardKey.keyW, meta: mac, control: !mac):
          _closeActiveTab,
      SingleActivator(LogicalKeyboardKey.digit1, meta: mac, control: !mac):
          () => _selectTab(0),
      SingleActivator(LogicalKeyboardKey.digit2, meta: mac, control: !mac):
          () => _selectTab(1),
      SingleActivator(LogicalKeyboardKey.digit3, meta: mac, control: !mac):
          () => _selectTab(2),
      SingleActivator(LogicalKeyboardKey.digit4, meta: mac, control: !mac):
          () => _selectTab(3),
      // Split pane shortcuts
      SingleActivator(LogicalKeyboardKey.keyD, meta: mac, control: !mac):
          _terminalController.splitHorizontal,
      SingleActivator(
        LogicalKeyboardKey.keyD,
        meta: mac,
        control: !mac,
        shift: true,
      ): _terminalController.splitVertical,
    };
  }

  void _showCommandPalette() {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 180),
      transitionBuilder: (ctx, anim, _, child) => FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1.0).animate(
            CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
          ),
          child: child,
        ),
      ),
      pageBuilder: (ctx, _, _) => CommandPalette(
        hosts: _hostController.hostsNotifier.value,
        onConnect: _handleConnect,
        onOpenSettings: () => setState(() => _selectedIndex = 5),
        onCreateHost: () {
          setState(() => _selectedIndex = 0);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (Platform.isIOS || Platform.isAndroid) {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => HostFormPage(controller: _hostController),
              ));
            } else {
              showDialog<void>(
                context: context,
                builder: (_) => HostFormDialog(controller: _hostController),
              );
            }
          });
        },
        onImportSshConfig: _isDesktop ? _showSshConfigImport : null,
        onSplitHorizontal: _isDesktop ? _terminalController.splitHorizontal : null,
        onSplitVertical: _isDesktop ? _terminalController.splitVertical : null,
        onCloseSplit: _isDesktop ? _terminalController.closeSplit : null,
      ),
    );
  }

  void _onSidebarResize(double delta) {
    setState(() {
      _sidebarWidth = (_sidebarWidth + delta).clamp(
        _minSidebarWidth,
        _maxSidebarWidth,
      );
    });
  }

  double get _effectiveSidebarWidth =>
      _sidebarCollapsed ? sidebarCollapsedWidth : _sidebarWidth;

  // ── Connect flow ─────────────────────────────────────────────────────────

  Future<void> _handleConnect(SshHost host) async {
    if (host.authType == AuthType.sshAgent) {
      _showSnackbar('SSH Agent auth is not yet supported.');
      return;
    }

    final stored = host.authType == AuthType.password
        ? await _credentials.loadPassword(host.id)
        : await _credentials.loadPassphrase(host.id);

    String? credential = stored;
    if (credential == null) {
      if (!mounted) return;
      credential = await showDialog<String>(
        context: context,
        builder: (_) => CredentialPromptDialog(
          host: host,
          isPassphrase: host.authType == AuthType.privateKey,
        ),
      );
      if (credential == null) return;
    }

    if (mounted) setState(() => _selectedIndex = 1);

    try {
      await _terminalController.createSession(
        host: host,
        password: host.authType == AuthType.password ? credential : null,
        passphrase: host.authType == AuthType.privateKey ? credential : null,
      );
    } catch (_) {
      return;
    }

    await _hostController.markConnected(host.id);

    try {
      if (host.authType == AuthType.password) {
        await _credentials.savePassword(host.id, credential);
      } else if (host.authType == AuthType.privateKey) {
        await _credentials.savePassphrase(host.id, credential);
      }
    } catch (_) {}
  }

  void _showSshConfigImport() {
    showDialog<int>(
      context: context,
      builder: (_) => SshConfigImportDialog(controller: _hostController),
    ).then((count) {
      if (count != null && count > 0 && mounted) {
        _showSnackbar('Imported $count host${count == 1 ? '' : 's'} from ~/.ssh/config');
      }
    });
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: AppColors.text, fontSize: 13),
        ),
        backgroundColor: AppColors.surface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppColors.border),
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  Widget _pageContent(int index) => switch (index) {
    0 => HostListPage(controller: _hostController, onConnect: _handleConnect),
    1 => ValueListenableBuilder<double>(
      valueListenable: _settingsController.fontSizeNotifier,
      builder: (context, fontSize, _) =>
          ValueListenableBuilder<TerminalThemeName>(
            valueListenable: _settingsController.terminalThemeNotifier,
            builder: (context, themeName, _) => TerminalPage(
              controller: _terminalController,
              fontSize: fontSize,
              terminalTheme: getTerminalThemePreset(themeName).theme,
              onCloseSession: (id) async {
                await _terminalController.closeSession(id);
                await _tunnelController.closeForSession(id);
              },
              onReconnect: _handleReconnect,
              onNewTab: _showCommandPalette,
              snippetController: _snippetController,
              historyController: _historyController,
              themeNotifier: _settingsController.terminalThemeNotifier,
              onThemeChanged: _settingsController.setTerminalTheme,
              onPaste: (cmd) =>
                  _terminalController.activeSession?.xterm?.paste(cmd),
              onRun: (cmd) {
                _historyController.add(cmd);
                _terminalController.activeSession?.xterm
                    ?.paste(cmd.endsWith('\n') ? cmd : '$cmd\n');
              },
            ),
          ),
    ),
    2 => SftpPage(terminalController: _terminalController),
    3 => TunnelPage(
      controller: _tunnelController,
      terminalController: _terminalController,
    ),
    4 => SnippetListPage(
      controller: _snippetController,
      onRun: (cmd) {
        final session = _terminalController.activeSession;
        session?.xterm?.paste(cmd.endsWith('\n') ? cmd : '$cmd\n');
      },
    ),
    5 => SettingsPage(controller: _settingsController),
    _ => const _PlaceholderPage(),
  };

  Widget _animatedPage(int index) => AnimatedSwitcher(
    duration: const Duration(milliseconds: 180),
    switchInCurve: Curves.easeOut,
    switchOutCurve: Curves.easeIn,
    transitionBuilder: (child, animation) =>
        FadeTransition(opacity: animation, child: child),
    child: KeyedSubtree(
      key: ValueKey(index),
      child: _pageContent(index),
    ),
  );

  static final _issuesUri =
      Uri.parse('https://github.com/IldySilva/xell/issues/new');
  static final _githubUri =
      Uri.parse('https://github.com/IldySilva/xell');
  static final _releasesUri =
      Uri.parse('https://github.com/IldySilva/xell/releases');

  void _checkForUpdates() {
    UpdateService.checkForUpdate().then((v) {
      if (!mounted) return;
      if (v != null) {
        _updateNotifier.value = v;
      } else {
        _showSnackbar('You\'re on the latest version.');
      }
    });
  }

  void _showAboutDialog() {
    showDialog<void>(
      context: context,
      builder: (_) => const XellAboutDialog(),
    );
  }

  void _quit() => windowManager.close();

  void _dispatchEditAction(Intent intent) {
    if (!mounted) return;
    final focusContext =
        FocusManager.instance.primaryFocus?.context ?? context;
    Actions.maybeInvoke(focusContext, intent);
  }

  @override
  Widget build(BuildContext context) {
    final content = CallbackShortcuts(
      bindings: _shortcuts,
      child: Focus(
        autofocus: true,
        child: _isDesktop ? _buildDesktop() : _buildMobile(),
      ),
    );

    if (!Platform.isMacOS && !Platform.isLinux) return content;

    return PlatformMenuBar(
      menus: [
        // ── App menu (macOS: appears as the app-name menu) ────────────────
        PlatformMenu(
          label: 'Xell',
          menus: [
            PlatformMenuItemGroup(
              members: [
                PlatformMenuItem(
                  label: 'About Xell',
                  onSelected: _showAboutDialog,
                ),
              ],
            ),
            const PlatformMenuItemGroup(
              members: [
                PlatformProvidedMenuItem(
                    type: PlatformProvidedMenuItemType.servicesSubmenu),
              ],
            ),
            const PlatformMenuItemGroup(
              members: [
                PlatformProvidedMenuItem(
                    type: PlatformProvidedMenuItemType.hide),
                PlatformProvidedMenuItem(
                    type:
                        PlatformProvidedMenuItemType.hideOtherApplications),
                PlatformProvidedMenuItem(
                    type:
                        PlatformProvidedMenuItemType.showAllApplications),
              ],
            ),
            PlatformMenuItemGroup(
              members: [
                PlatformMenuItem(
                  label: 'Quit Xell',
                  shortcut: const SingleActivator(
                      LogicalKeyboardKey.keyQ, meta: true),
                  onSelected: _quit,
                ),
              ],
            ),
          ],
        ),

        // ── File menu ────────────────────────────────────────────────────
        PlatformMenu(
          label: 'File',
          menus: [
            PlatformMenuItemGroup(
              members: [
                PlatformMenuItem(
                  label: 'New Connection',
                  shortcut: const SingleActivator(
                      LogicalKeyboardKey.keyN, meta: true),
                  onSelected: _showCommandPalette,
                ),
              ],
            ),
            PlatformMenuItemGroup(
              members: [
                PlatformMenuItem(
                  label: 'Close Tab',
                  shortcut: const SingleActivator(
                      LogicalKeyboardKey.keyW, meta: true),
                  onSelected: _closeActiveTab,
                ),
              ],
            ),
            PlatformMenuItemGroup(
              members: [
                PlatformMenuItem(
                  label: 'Settings',
                  shortcut: const SingleActivator(
                      LogicalKeyboardKey.comma, meta: true),
                  onSelected: () => setState(() => _selectedIndex = 5),
                ),
              ],
            ),
          ],
        ),

        // ── Edit menu ────────────────────────────────────────────────────
        PlatformMenu(
          label: 'Edit',
          menus: [
            PlatformMenuItemGroup(
              members: [
                PlatformMenuItem(
                  label: 'Undo',
                  shortcut: const SingleActivator(
                      LogicalKeyboardKey.keyZ, meta: true),
                  onSelected: () => _dispatchEditAction(
                      const UndoTextIntent(
                          SelectionChangedCause.keyboard)),
                ),
                PlatformMenuItem(
                  label: 'Redo',
                  shortcut: const SingleActivator(
                      LogicalKeyboardKey.keyZ,
                      meta: true,
                      shift: true),
                  onSelected: () => _dispatchEditAction(
                      const RedoTextIntent(
                          SelectionChangedCause.keyboard)),
                ),
              ],
            ),
            PlatformMenuItemGroup(
              members: [
                PlatformMenuItem(
                  label: 'Cut',
                  shortcut: const SingleActivator(
                      LogicalKeyboardKey.keyX, meta: true),
                  onSelected: () => _dispatchEditAction(
                      CopySelectionTextIntent.cut(
                          SelectionChangedCause.keyboard)),
                ),
                PlatformMenuItem(
                  label: 'Copy',
                  shortcut: const SingleActivator(
                      LogicalKeyboardKey.keyC, meta: true),
                  onSelected: () =>
                      _dispatchEditAction(CopySelectionTextIntent.copy),
                ),
                PlatformMenuItem(
                  label: 'Paste',
                  shortcut: const SingleActivator(
                      LogicalKeyboardKey.keyV, meta: true),
                  onSelected: () => _dispatchEditAction(
                      const PasteTextIntent(
                          SelectionChangedCause.keyboard)),
                ),
              ],
            ),
            PlatformMenuItemGroup(
              members: [
                PlatformMenuItem(
                  label: 'Select All',
                  shortcut: const SingleActivator(
                      LogicalKeyboardKey.keyA, meta: true),
                  onSelected: () => _dispatchEditAction(
                      const SelectAllTextIntent(
                          SelectionChangedCause.keyboard)),
                ),
              ],
            ),
          ],
        ),

        // ── Window menu ───────────────────────────────────────────────────
        PlatformMenu(
          label: 'Window',
          menus: [
            const PlatformMenuItemGroup(
              members: [
                PlatformProvidedMenuItem(
                    type: PlatformProvidedMenuItemType.minimizeWindow),
                PlatformProvidedMenuItem(
                    type: PlatformProvidedMenuItemType.zoomWindow),
              ],
            ),
            PlatformMenuItemGroup(
              members: [
                PlatformMenuItem(
                  label: 'Toggle Full Screen',
                  shortcut: const SingleActivator(
                      LogicalKeyboardKey.keyF,
                      meta: true,
                      control: true),
                  onSelected: _toggleFullscreen,
                ),
              ],
            ),
          ],
        ),

        // ── Help menu ────────────────────────────────────────────────────
        PlatformMenu(
          label: 'Help',
          menus: [
            PlatformMenuItemGroup(
              members: [
                PlatformMenuItem(
                  label: 'Check for Updates',
                  onSelected: _checkForUpdates,
                ),
              ],
            ),
            PlatformMenuItemGroup(
              members: [
                PlatformMenuItem(
                  label: 'View on GitHub',
                  onSelected: () => launchUrl(_githubUri,
                      mode: LaunchMode.externalApplication),
                ),
                PlatformMenuItem(
                  label: "What's New",
                  onSelected: () => launchUrl(_releasesUri,
                      mode: LaunchMode.externalApplication),
                ),
              ],
            ),
            PlatformMenuItemGroup(
              members: [
                PlatformMenuItem(
                  label: 'Report a Bug',
                  onSelected: () => launchUrl(_issuesUri,
                      mode: LaunchMode.externalApplication),
                ),
              ],
            ),
          ],
        ),
      ],
      child: content,
    );
  }

  Widget _buildDesktop() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeInOut,
            width: _effectiveSidebarWidth,
            child: Sidebar(
              selectedIndex: _selectedIndex,
              isCollapsed: _sidebarCollapsed,
              onItemSelected: (i) => setState(() => _selectedIndex = i),
              onSettingsTap: () => setState(() => _selectedIndex = 5),
              onToggleCollapse: () =>
                  setState(() => _sidebarCollapsed = !_sidebarCollapsed),
            ),
          ),
          if (!_sidebarCollapsed) _ResizeHandle(onDrag: _onSidebarResize),
          Expanded(
            child: Column(
              children: [
                ValueListenableBuilder<String?>(
                  valueListenable: _terminalController.activeSessionIdNotifier,
                  builder: (context, sessionId, child) => TopBar(
                    onCommandPaletteTap: _showCommandPalette,
                    onSettingsTap: () => setState(() => _selectedIndex = 5),
                    isFullScreen: _isFullScreen,
                    onToggleFullscreen: _toggleFullscreen,
                    activeSession:
                        _terminalController.activeSession?.host.hostname,
                  ),
                ),
                ValueListenableBuilder<String?>(
                  valueListenable: _updateNotifier,
                  builder: (_, version, child) => _UpdateBanner(
                    version: version,
                    onDismiss: () => _updateNotifier.value = null,
                  ),
                ),
                Expanded(child: _animatedPage(_selectedIndex)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobile() {
    // Settings lives at index 4 but the bottom nav only has 4 items (0-3).
    // We handle tapping the settings icon via a dedicated nav item at index 4.
    final navIndex = _selectedIndex.clamp(0, 5);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            ValueListenableBuilder<String?>(
              valueListenable: _updateNotifier,
              builder: (_, version, child) => _UpdateBanner(
                version: version,
                onDismiss: () => _updateNotifier.value = null,
              ),
            ),
            Expanded(child: _animatedPage(_selectedIndex)),
          ],
        ),
      ),
      bottomNavigationBar: _MobileNavBar(
        selectedIndex: navIndex,
        onItemSelected: (i) => setState(() => _selectedIndex = i),
        onCommandPaletteTap: _showCommandPalette,
      ),
    );
  }
}

// ── Mobile bottom nav bar ─────────────────────────────────────────────────────

class _MobileNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;
  final VoidCallback onCommandPaletteTap;

  const _MobileNavBar({
    required this.selectedIndex,
    required this.onItemSelected,
    required this.onCommandPaletteTap,
  });

  static const _items = [
    (icon: Icons.dns_outlined, label: 'Hosts'),
    (icon: Icons.terminal_outlined, label: 'Terminal'),
    (icon: Icons.folder_open_outlined, label: 'SFTP'),
    (icon: Icons.alt_route_outlined, label: 'Tunnels'),
    (icon: Icons.code_outlined, label: 'Snippets'),
    (icon: Icons.settings_outlined, label: 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            ..._items.indexed.map((e) {
              final idx = e.$1;
              final item = e.$2;
              final selected = selectedIndex == idx;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onItemSelected(idx),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          item.icon,
                          size: 22,
                          color: selected
                              ? AppColors.accent
                              : AppColors.textMuted,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 10,
                            color: selected
                                ? AppColors.accent
                                : AppColors.textMuted,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ── Desktop-only widgets ──────────────────────────────────────────────────────

class _ResizeHandle extends StatefulWidget {
  final ValueChanged<double> onDrag;
  const _ResizeHandle({required this.onDrag});

  @override
  State<_ResizeHandle> createState() => _ResizeHandleState();
}

class _ResizeHandleState extends State<_ResizeHandle> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onHorizontalDragUpdate: (d) => widget.onDrag(d.delta.dx),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 4,
          color: _hovered
              ? AppColors.accent.withValues(alpha: 0.4)
              : AppColors.border,
        ),
      ),
    );
  }
}

class _PlaceholderPage extends StatelessWidget {
  const _PlaceholderPage();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Coming soon.',
        style: TextStyle(color: AppColors.textMuted, fontSize: 13),
      ),
    );
  }
}

// ── Update banner ─────────────────────────────────────────────────────────────

class _UpdateBanner extends StatelessWidget {
  final String? version;
  final VoidCallback onDismiss;

  const _UpdateBanner({required this.version, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    if (version == null) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'xell $version is available',
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => launchUrl(
              Uri.parse(releasesUrl),
              mode: LaunchMode.externalApplication,
            ),
            child: const Text(
              'Download',
              style: TextStyle(
                color: AppColors.accent,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 16),
          GestureDetector(
            onTap: onDismiss,
            child: const Icon(Icons.close, size: 14, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
