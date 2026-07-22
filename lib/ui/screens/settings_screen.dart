import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../data/database/database_helper.dart';
import '../../providers/app_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _userController;

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<AppProvider>(context, listen: false);
    _userController = TextEditingController(text: provider.letterboxdUsername);
  }

  @override
  void dispose() {
    _userController.dispose();
    super.dispose();
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
          // Letterboxd RSS Feed Configuration
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
                  const Text(
                    'Letterboxd Username',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Enter your username to pull your Recently Watched RSS feed onto the home screen.',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _userController,
                    decoration: InputDecoration(
                      hintText: 'e.g. dave',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.check),
                        onPressed: () {
                          provider.setLetterboxdUsername(_userController.text);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Letterboxd username updated!')),
                          );
                        },
                      ),
                    ),
                    onSubmitted: (val) {
                      provider.setLetterboxdUsername(val);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Letterboxd username updated!')),
                      );
                    },
                  ),
                  if (provider.letterboxdUsername.isNotEmpty) ...[
                    const SizedBox(height: 8),
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

          // Theme Settings
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
