import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class AppUpdateInfo {
  final String currentVersion;
  final String latestVersion;
  final String releaseTitle;
  final String releaseNotes;
  final String releaseUrl;
  final String? apkDownloadUrl;
  final bool isUpdateAvailable;

  AppUpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.releaseTitle,
    required this.releaseNotes,
    required this.releaseUrl,
    this.apkDownloadUrl,
    required this.isUpdateAvailable,
  });
}

class UpdateService {
  static const String currentVersion = '1.1.0';
  static const String githubRepo = 'mattsigal/AfterTheCredits';
  static const String latestReleaseUrl =
      'https://api.github.com/repos/$githubRepo/releases/latest';

  /// Checks GitHub API for the latest release
  static Future<AppUpdateInfo?> checkForUpdate() async {
    try {
      final response = await http.get(
        Uri.parse(latestReleaseUrl),
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'AfterTheCreditsApp',
        },
      );

      if (response.statusCode != 200) return null;

      final data = json.decode(response.body) as Map<String, dynamic>;
      final tagName = (data['tag_name'] as String? ?? '1.0.0').replaceAll('v', '').trim();
      final name = data['name'] as String? ?? 'Release $tagName';
      final body = data['body'] as String? ?? 'No release notes available.';
      final htmlUrl = data['html_url'] as String? ?? 'https://github.com/$githubRepo';

      String? apkUrl;
      final assets = data['assets'] as List<dynamic>?;
      if (assets != null) {
        for (final asset in assets) {
          final assetName = (asset['name'] as String? ?? '').toLowerCase();
          final downloadUrl = asset['browser_download_url'] as String?;
          if (assetName.endsWith('.apk') && downloadUrl != null) {
            apkUrl = downloadUrl;
            break;
          }
        }
      }

      final updateAvailable = _isVersionHigher(tagName, currentVersion);

      return AppUpdateInfo(
        currentVersion: currentVersion,
        latestVersion: tagName,
        releaseTitle: name,
        releaseNotes: body,
        releaseUrl: htmlUrl,
        apkDownloadUrl: apkUrl,
        isUpdateAvailable: updateAvailable,
      );
    } catch (_) {
      return null;
    }
  }

  static bool _isVersionHigher(String latest, String current) {
    try {
      final lParts = latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final cParts = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      for (int i = 0; i < lParts.length && i < cParts.length; i++) {
        if (lParts[i] > cParts[i]) return true;
        if (lParts[i] < cParts[i]) return false;
      }
      return lParts.length > cParts.length;
    } catch (_) {
      return latest != current;
    }
  }

  /// Opens specified URL in OS browser
  static Future<void> openReleasePage(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
