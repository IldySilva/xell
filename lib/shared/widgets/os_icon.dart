import 'package:material_ui/material_ui.dart';
import '../../features/hosts/models/os_type.dart';

class OsIcon extends StatelessWidget {
  final OsType os;
  final double size;

  const OsIcon({super.key, required this.os, this.size = 18});

  @override
  Widget build(BuildContext context) {
    final path = os.assetPath;
    if (path == null) return const SizedBox.shrink();

    return Tooltip(
      message: os.label,
      child: Image.asset(
        path,
        width: size,
        height: size,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      ),
    );
  }
}
