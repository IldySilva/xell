import 'dart:convert';
import 'dart:io';

// Keep in sync with pubspec.yaml version and git tags.
const String kAppVersion = '0.1.1';
const String _releasesUrl = 'https://github.com/IldySilva/xell/releases';
const String _apiUrl =
    'https://api.github.com/repos/IldySilva/xell/releases/latest';

String get releasesUrl => _releasesUrl;

class UpdateService {
  /// Returns the latest version string if a newer release exists, otherwise null.
  static Future<String?> checkForUpdate() async {
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 5);
      final request = await client.getUrl(Uri.parse(_apiUrl));
      request.headers
          .set('Accept', 'application/vnd.github.v3+json');
      final response = await request.close();
      if (response.statusCode != 200) return null;
      final body = await response.transform(utf8.decoder).join();
      client.close();
      final json = jsonDecode(body) as Map<String, dynamic>;
      if (json['prerelease'] == true) return null;
      final tag =
          ((json['tag_name'] as String?) ?? '').replaceFirst('v', '');
      return _isNewer(tag, kAppVersion) ? tag : null;
    } catch (_) {
      return null;
    }
  }

  static bool _isNewer(String latest, String current) {
    final l = _parse(latest);
    final c = _parse(current);
    for (var i = 0; i < 3; i++) {
      if (l[i] > c[i]) return true;
      if (l[i] < c[i]) return false;
    }
    return false;
  }

  static List<int> _parse(String v) {
    final parts = v.split('.');
    return List.generate(
        3, (i) => i < parts.length ? (int.tryParse(parts[i]) ?? 0) : 0);
  }
}
