import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../data/database/database_helper.dart';
import '../../data/services/update_service.dart';
import '../../providers/app_provider.dart';
import 'letterboxd_login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _cookiesController;
  late TextEditingController _uaController;

  bool _isVerifyingCredentials = false;
  bool _isCheckingUpdate = false;
  AppUpdateInfo? _updateInfo;

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<AppProvider>(context, listen: false);
    _cookiesController = TextEditingController(text: provider.letterboxdRawCookies);
    _uaController = TextEditingController(text: provider.letterboxdUserAgent);
  }

  @override
  void dispose() {
    _cookiesController.dispose();
    _uaController.dispose();
    super.dispose();
  }

  Future<void> _checkAppUpdates() async {
    setState(() => _isCheckingUpdate = true);
    final info = await UpdateService.checkForUpdate();
    if (mounted) {
      setState(() {
        _isCheckingUpdate = false;
        _updateInfo = info;
      });
      if (info != null) _showUpdateDialog(info);
    }
  }

  void _showUpdateDialog(AppUpdateInfo info) {
    final isAndroid = Theme.of(context).platform == TargetPlatform.android;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              info.isUpdateAvailable ? Icons.system_update : Icons.check_circle_outline,
              color: info.isUpdateAvailable ? const Color(0xFF00E676) : Colors.grey,
            ),
            const SizedBox(width: 8),
            Text(info.isUpdateAvailable ? 'Update Available!' : 'Up to Date'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Current Version: ${UpdateService.currentVersion}'),
            Text('Latest Version: ${info.latestVersion}'),
            const SizedBox(height: 12),
            if (!info.isUpdateAvailable)
              const Text('You are using the latest version of AfterTheCredits.')
            else
              const Text('A new update is available on GitHub Releases!'),
            const SizedBox(height: 12),
            if (!isAndroid && info.isUpdateAvailable)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.shade900.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Note for Apple iOS: System requirements dictate manual installation / sideloading or TestFlight updates.',
                  style: TextStyle(fontSize: 12, color: Colors.amber),
                ),
              ),
            if (isAndroid && info.apkDownloadUrl != null)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E676).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Android APK found! Tap below to download and update.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF00E676), fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Dismiss'),
          ),
          if (isAndroid && info.apkDownloadUrl != null)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E676),
                foregroundColor: Colors.black,
              ),
              icon: const Icon(Icons.download),
              label: const Text('Download APK'),
              onPressed: () {
                Navigator.of(ctx).pop();
                UpdateService.openReleasePage(info.apkDownloadUrl!);
              },
            ),
          ElevatedButton.icon(
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('GitHub Release'),
            onPressed: () {
              Navigator.of(ctx).pop();
              UpdateService.openReleasePage(info.releaseUrl);
            },
          ),
        ],
      ),
    );
  }

  void _showAccountDetailsSheet(BuildContext context, AppProvider provider) {
    _cookiesController.text = provider.letterboxdRawCookies;
    _uaController.text = provider.letterboxdUserAgent;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E2630),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: const Color(0xFF00E676).withValues(alpha: 0.2),
                    child: const Icon(Icons.person, color: Color(0xFF00E676)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Logged in as ${provider.letterboxdUsername}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Active Letterboxd Session',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: Colors.white10),
              const SizedBox(height: 10),

              // Manual Cookie / User Agent Expansion
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                shape: const Border(),
                collapsedShape: const Border(),
                title: const Text(
                  'Manual Cookie / User Agent Settings',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey),
                ),
                children: [
                  const SizedBox(height: 8),
                  TextField(
                    controller: _cookiesController,
                    maxLines: 3,
                    style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                    decoration: const InputDecoration(
                      labelText: 'Active Raw Cookies',
                      alignLabelWithHint: true,
                      prefixIcon: Icon(Icons.cookie_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _uaController,
                    maxLines: 2,
                    style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                    decoration: const InputDecoration(
                      labelText: 'Active User Agent',
                      alignLabelWithHint: true,
                      prefixIcon: Icon(Icons.important_devices),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.save, size: 16),
                      label: const Text('Update Manual Cookies'),
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final success = await provider.verifyAndSaveLetterboxdCredentials(
                          username: provider.letterboxdUsername,
                          rawCookies: _cookiesController.text,
                          userAgent: _uaController.text,
                        );
                        if (ctx.mounted) {
                          Navigator.of(ctx).pop();
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                success
                                    ? 'Updated manual Letterboxd cookies!'
                                    : 'Failed to update cookies.',
                              ),
                              backgroundColor: success ? const Color(0xFF00E676) : Colors.redAccent,
                            ),
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
              ),
              const SizedBox(height: 16),

              // Sign Out Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent.withValues(alpha: 0.2),
                    foregroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.logout),
                  label: const Text(
                    'Sign Out',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    Navigator.of(ctx).pop();
                    await provider.clearLetterboxdCredentials();
                    _cookiesController.clear();
                    _uaController.clear();
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Signed out of Letterboxd.'),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Letterboxd Integration & Auth Section
          Text(
            'LETTERBOXD INTEGRATION',
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Letterboxd Authentication',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: provider.isLetterboxdAuthenticated
                              ? const Color(0xFF00E676).withValues(alpha: 0.2)
                              : Colors.grey.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          provider.isLetterboxdAuthenticated ? 'Authenticated' : 'Not Connected',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: provider.isLetterboxdAuthenticated
                                ? const Color(0xFF00E676)
                                : Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Configure for RSS sync and Review logging.',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 16),

                  if (provider.isLetterboxdAuthenticated)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF00E676),
                          side: const BorderSide(color: Color(0xFF00E676), width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.check_circle, size: 20),
                        label: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Logged in as ${provider.letterboxdUsername}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(Icons.settings, size: 18),
                          ],
                        ),
                        onPressed: () => _showAccountDetailsSheet(context, provider),
                      ),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00E676),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: _isVerifyingCredentials
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                              )
                            : const Icon(Icons.language, size: 20),
                        label: Text(
                          _isVerifyingCredentials
                              ? 'Connecting...'
                              : 'Log in to Letterboxd (In-App Browser)',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        onPressed: _isVerifyingCredentials
                            ? null
                            : () async {
                                final messenger = ScaffoldMessenger.of(context);
                                final result = await Navigator.push<LetterboxdLoginResult>(
                                  context,
                                  MaterialPageRoute(builder: (_) => const LetterboxdLoginScreen()),
                                );
                                if (result != null) {
                                  _cookiesController.text = result.rawCookies;
                                  _uaController.text = result.userAgent;
                                  setState(() => _isVerifyingCredentials = true);
                                  final success = await provider.verifyAndSaveLetterboxdCredentials(
                                    username: result.username,
                                    rawCookies: result.rawCookies,
                                    userAgent: result.userAgent,
                                  );
                                  if (mounted) {
                                    setState(() => _isVerifyingCredentials = false);
                                    if (success) {
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            result.username.isNotEmpty
                                                ? 'Connected to Letterboxd as "${result.username}"!'
                                                : 'Letterboxd session authenticated and saved!',
                                          ),
                                          backgroundColor: const Color(0xFF00E676),
                                        ),
                                      );
                                    } else {
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Authentication failed: ${provider.letterboxdAuthError}',
                                          ),
                                          backgroundColor: Colors.redAccent,
                                        ),
                                      );
                                    }
                                  }
                                }
                              },
                      ),
                    ),

                  if (provider.letterboxdUsername.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      'RSS Feed URL: https://letterboxd.com/${provider.letterboxdUsername}/rss/',
                      style: TextStyle(fontSize: 12, color: Colors.amber.shade700),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // App Updates Section (Android APK download / iOS notification)
          Text(
            'APPLICATION UPDATES',
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.system_update_outlined, color: Color(0xFFFF3B5C)),
              title: const Text('Check for Updates', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                _updateInfo != null && _updateInfo!.isUpdateAvailable
                    ? 'New version ${_updateInfo!.latestVersion} available!'
                    : 'Current Version: ${UpdateService.currentVersion}',
              ),
              trailing: _isCheckingUpdate
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _checkAppUpdates,
                    ),
              onTap: _isCheckingUpdate ? null : _checkAppUpdates,
            ),
          ),
          const SizedBox(height: 24),

          // Appearance Settings
          Text(
            'APPEARANCE',
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: SwitchListTile(
              title: const Text('Dark Mode', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Toggle between Dark (default) and Light mode'),
              value: provider.isDarkMode,
              onChanged: (val) => provider.setDarkMode(val),
              secondary: Icon(
                provider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Cache & Database Management
          Text(
            'CACHE & STORAGE',
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent),
              title: const Text('Clear Movie Cache'),
              subtitle: const Text('Deletes cached aftercredits.com movie data from local database'),
              onTap: () async {
                await DatabaseHelper.instance.clearAllCache();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Local movie cache cleared!')),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
