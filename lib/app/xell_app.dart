import 'package:material_ui/material_ui.dart';
import 'app_theme.dart';
import '../features/settings/controllers/settings_controller.dart';
import '../shared/layouts/app_shell.dart';

class XellApp extends StatelessWidget {
  const XellApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, mode, _) => MaterialApp(
        title: 'Xell',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: mode,
        home: const AppShell(),
      ),
    );
  }
}
