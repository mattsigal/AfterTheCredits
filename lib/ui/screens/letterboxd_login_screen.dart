import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

class LetterboxdLoginResult {
  final String username;
  final String rawCookies;
  final String userAgent;

  LetterboxdLoginResult({
    required this.username,
    required this.rawCookies,
    required this.userAgent,
  });
}

class LetterboxdLoginScreen extends StatefulWidget {
  const LetterboxdLoginScreen({super.key});

  @override
  State<LetterboxdLoginScreen> createState() => _LetterboxdLoginScreenState();
}

class _LetterboxdLoginScreenState extends State<LetterboxdLoginScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _isCaptured = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
          'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Mobile Safari/537.36')
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (url) async {
            if (mounted) setState(() => _isLoading = false);
            await _checkSession();
          },
          onUrlChange: (change) async {
            await _checkSession();
          },
        ),
      )
      ..loadRequest(Uri.parse('https://letterboxd.com/sign-in/'));
  }

  Future<void> _checkSession() async {
    if (_isCaptured) return;
    try {
      String rawCookies = '';
      try {
        const channel = MethodChannel('com.afterthecredits/cookies');
        final String? nativeCookies =
            await channel.invokeMethod('getCookies', {'url': 'https://letterboxd.com/'});
        if (nativeCookies != null && nativeCookies.isNotEmpty) {
          rawCookies = nativeCookies;
        }
      } catch (_) {}

      if (rawCookies.isEmpty) {
        final rawCookiesResult =
            await _controller.runJavaScriptReturningResult('document.cookie');
        rawCookies = rawCookiesResult.toString();
        if (rawCookies.startsWith('"') && rawCookies.endsWith('"')) {
          rawCookies = rawCookies.substring(1, rawCookies.length - 1);
        }
        rawCookies = rawCookies.replaceAll(r'\"', '"').replaceAll(r'\\', r'\');
      }

      if (rawCookies.contains('letterboxd.user') ||
          rawCookies.contains('letterboxd.signed.in.as') ||
          rawCookies.contains('letterboxd.session')) {
        _isCaptured = true;

        var username = '';
        final userMatch =
            RegExp(r'letterboxd\.signed\.in\.as=([^;]+)').firstMatch(rawCookies) ??
                RegExp(r'letterboxd\.user=([^;]+)').firstMatch(rawCookies);
        if (userMatch != null) {
          username = Uri.decodeComponent(userMatch.group(1)!.trim());
        }

        final uaResult =
            await _controller.runJavaScriptReturningResult('navigator.userAgent');
        var userAgent = uaResult.toString();
        if (userAgent.startsWith('"') && userAgent.endsWith('"')) {
          userAgent = userAgent.substring(1, userAgent.length - 1);
        }

        if (mounted) {
          Navigator.of(context).pop(
            LetterboxdLoginResult(
              username: username,
              rawCookies: rawCookies,
              userAgent: userAgent,
            ),
          );
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Log in to Letterboxd'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _controller.reload(),
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const LinearProgressIndicator(
              backgroundColor: Colors.transparent,
              color: Color(0xFF00E676),
            ),
        ],
      ),
    );
  }
}
