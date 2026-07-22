import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../providers/app_provider.dart';
import '../../utils/title_formatter.dart';
import '../../data/models/letterboxd_item.dart';

class LetterboxdLogDialog extends StatefulWidget {
  final String filmTitle;
  final String? filmYear;
  final String? posterUrl;
  final LetterboxdItem? existingItem;

  const LetterboxdLogDialog({
    super.key,
    required this.filmTitle,
    this.filmYear,
    this.posterUrl,
    this.existingItem,
  });

  @override
  State<LetterboxdLogDialog> createState() => _LetterboxdLogDialogState();
}

class _LetterboxdLogDialogState extends State<LetterboxdLogDialog> {
  late final WebViewController _webController;
  bool _isLoading = true;
  bool _hasFinishedSaveOrCancel = false;

  static String? _extractSlugFromLink(String? urlStr) {
    if (urlStr == null || urlStr.isEmpty) return null;
    try {
      final uri = Uri.parse(urlStr);
      final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      final filmIdx = segments.indexOf('film');
      if (filmIdx != -1 && filmIdx + 1 < segments.length) {
        return segments[filmIdx + 1];
      }
    } catch (_) {}
    return null;
  }

  @override
  void initState() {
    super.initState();

    final slug = _extractSlugFromLink(widget.existingItem?.link) ??
        widget.filmTitle
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
            .replaceAll(RegExp(r'^-+|-+$'), '');

    final initialUrl = (widget.existingItem?.link != null && widget.existingItem!.link.isNotEmpty)
        ? widget.existingItem!.link
        : (slug.isNotEmpty ? 'https://letterboxd.com/film/$slug/' : 'https://letterboxd.com/');

    _webController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
          'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Mobile Safari/537.36')
      ..addJavaScriptChannel(
        'LetterboxdSaveChannel',
        onMessageReceived: (JavaScriptMessage message) {
          if (_hasFinishedSaveOrCancel) return;

          if (message.message == 'saved') {
            _hasFinishedSaveOrCancel = true;
            if (mounted) {
              final provider = Provider.of<AppProvider>(context, listen: false);
              provider.refreshRecentlyWatched();
              Navigator.of(context).pop(true);
            }
          } else if (message.message == 'cancel') {
            _hasFinishedSaveOrCancel = true;
            if (mounted) {
              Navigator.of(context).pop(false);
            }
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (_) async {
            if (_hasFinishedSaveOrCancel) return;
            if (mounted) setState(() => _isLoading = false);
            await _injectRefinements();
          },
        ),
      )
      ..loadRequest(Uri.parse(initialUrl));
  }

  Future<void> _injectRefinements() async {
    const jsCode = '''
      (function() {
        if (window.__lbxdSaved) return;

        document.cookie = "useMobileSite=no; path=/; domain=.letterboxd.com";
        document.cookie = "useMobileSite=no; path=/; domain=letterboxd.com";

        // Clean CSS hiding site chrome while preserving React DOM flow
        let style = document.getElementById('letterboxd-custom-cleaner');
        if (!style) {
          style = document.createElement('style');
          style.id = 'letterboxd-custom-cleaner';
          document.head.appendChild(style);
        }
        style.innerHTML = `
          #header, footer, #footer, .site-header, .site-header-bg, .site-footer, 
          .banner-ad, .ad, .sidebar, .col-sidebar, .sub-nav, .navigation,
          .js-hide-in-app, #signin, .header-signin-form, .cols-2, .col-main,
          .viewing-poster-container, .section, .film-header, .film-poster,
          #content > :not(#diary-entry-form-modal):not(.diary-entry-form-modal) {
            display: none !important;
          }

          html, body, #content, .content-wrap, main.site-body {
            background-color: #283038 !important;
            color: #ffffff !important;
            padding: 0 !important;
            margin: 0 !important;
            overflow: hidden !important;
          }

          .modal-backdrop {
            display: none !important;
          }

          #diary-entry-form-modal, .modal.in, .modal.show, .diary-entry-form-modal {
            display: block !important;
            opacity: 1 !important;
            position: absolute !important;
            top: 0 !important;
            left: 0 !important;
            width: 100% !important;
            min-height: 100% !important;
            margin: 0 !important;
            z-index: 999999 !important;
            background: #283038 !important;
            box-shadow: none !important;
          }

          .modal-dialog {
            margin: 0 !important;
            max-width: 100% !important;
            width: 100% !important;
            padding: 0 !important;
          }

          .modal-content {
            background: #283038 !important;
            border: none !important;
            box-shadow: none !important;
            border-radius: 0 !important;
            padding: 4px !important;
          }

          .modal-header {
            border-bottom: 1px solid #37434f !important;
            padding: 12px 16px !important;
          }

          .modal-title {
            color: #00E676 !important;
            font-size: 18px !important;
            font-weight: bold !important;
          }

          .modal-body {
            padding: 12px 16px !important;
          }

          .modal-footer {
            display: block !important;
            border-top: 1px solid #37434f !important;
            padding: 12px 16px !important;
            margin-bottom: 28px !important;
          }

          .button-green, .button-neue.-primary, button[data-js-trigger="submit"] {
            background-color: #00E676 !important;
            color: #000000 !important;
            font-weight: bold !important;
            border: none !important;
          }
        `;

        // Intercept close button / dismiss clicks inside the web modal to close Flutter dialog
        if (!window.__lbxdCloseIntercepted) {
          window.__lbxdCloseIntercepted = true;
          document.addEventListener('click', function(e) {
            let el = e.target;
            while (el && el !== document.body) {
              if (el.classList && (el.classList.contains('close') || el.classList.contains('js-close')) ||
                  el.getAttribute('data-bs-dismiss') === 'modal' || 
                  el.getAttribute('data-dismiss') === 'modal') {
                if (window.LetterboxdSaveChannel) {
                  window.LetterboxdSaveChannel.postMessage('cancel');
                }
                break;
              }
              el = el.parentElement;
            }
          }, true);
        }

        // Intercept Save button clicks directly to dismiss outer Flutter container dialog
        if (!window.__lbxdSaveClickIntercepted) {
          window.__lbxdSaveClickIntercepted = true;
          document.addEventListener('click', function(e) {
            let el = e.target;
            while (el && el !== document.body) {
              const text = (el.textContent || '').trim().toLowerCase();
              const isSave = el.type === 'submit' ||
                (el.classList && (el.classList.contains('button-green') || el.classList.contains('js-extend-button'))) ||
                (text === 'save' || text.startsWith('save '));

              if (isSave) {
                window.__lbxdSaved = true;
                setTimeout(function() {
                  if (window.LetterboxdSaveChannel) {
                    window.LetterboxdSaveChannel.postMessage('saved');
                  }
                }, 400);
                break;
              }
              el = el.parentElement;
            }
          }, true);
        }

        // Intercept XHR / Fetch POST saves & Form Submits to notify Flutter and pop dialog
        if (!window.__lbxdIntercepted) {
          window.__lbxdIntercepted = true;

          const origOpen = XMLHttpRequest.prototype.open;
          XMLHttpRequest.prototype.open = function(method, url) {
            this.addEventListener('load', function() {
              if (url && (url.includes('save-diary-entry') || url.includes('production-log-entries'))) {
                if (this.status === 200 || this.status === 201 || this.status === 302) {
                  window.__lbxdSaved = true;
                  if (window.LetterboxdSaveChannel) {
                    window.LetterboxdSaveChannel.postMessage('saved');
                  }
                }
              }
            });
            origOpen.apply(this, arguments);
          };

          const origFetch = window.fetch;
          window.fetch = async function() {
            const res = await origFetch.apply(this, arguments);
            const url = arguments[0] ? (typeof arguments[0] === 'string' ? arguments[0] : arguments[0].url) : '';
            if (url && (url.includes('save-diary-entry') || url.includes('production-log-entries'))) {
              if (res.status === 200 || res.status === 201 || res.status === 302) {
                window.__lbxdSaved = true;
                if (window.LetterboxdSaveChannel) {
                  window.LetterboxdSaveChannel.postMessage('saved');
                }
              }
            }
            return res;
          };

          document.addEventListener('submit', function(e) {
            const form = e.target;
            if (form && (form.action.includes('save-diary-entry') || form.id.includes('diary-entry-form'))) {
              setTimeout(function() {
                window.__lbxdSaved = true;
                if (window.LetterboxdSaveChannel) {
                  window.LetterboxdSaveChannel.postMessage('saved');
                }
              }, 450);
            }
          }, true);
        }

        // Trigger EditLogEntry after React component hydration finishes
        let hasClickedEdit = false;
        const triggerEdit = () => {
          if (hasClickedEdit || window.__lbxdSaved) return;

          const composeSection = document.querySelector('section[data-js-wizard-step="compose"], .diary-entry-form-wizard-step.-compose');
          const isComposeVisible = composeSection && (!composeSection.hasAttribute('hidden') && composeSection.offsetHeight > 50);

          if (isComposeVisible) {
            hasClickedEdit = true;
            return;
          }

          const editWrapper = document.querySelector('[data-component-class="EditLogEntry"]');
          if (editWrapper) {
            const btn = editWrapper.querySelector('button') || editWrapper.querySelector('a');
            if (btn) {
              hasClickedEdit = true;
              btn.click();
              return;
            }
          }

          const allLabels = Array.from(document.querySelectorAll('span.label, button, a'));
          const target = allLabels.find(el => {
            const txt = (el.textContent || '').trim();
            return txt.includes('Edit entry or add review');
          });

          if (target) {
            hasClickedEdit = true;
            const btn = target.closest('button') || target.closest('a') || target;
            btn.click();
          }
        };

        if (!window.__lbxdSaved) {
          setTimeout(triggerEdit, 400);
          setTimeout(triggerEdit, 900);
        }
      })();
    ''';

    try {
      await _webController.runJavaScript(jsCode);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final displayTitle = TitleFormatter.formatDisplayTitle(widget.filmTitle);
    const darkBg = Color(0xFF283038);
    const accentGreen = Color(0xFF00E676);
    final mediaQuery = MediaQuery.of(context);

    return Dialog(
      backgroundColor: darkBg,
      insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: mediaQuery.size.height * 0.90,
        ),
        child: Column(
          children: [
            // Clean Top Bar
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
              decoration: const BoxDecoration(
                color: Color(0xFF1E252C),
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.existingItem != null ? 'Update Letterboxd Entry' : 'Log on Letterboxd',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: accentGreen,
                          ),
                        ),
                        Text(
                          displayTitle,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.grey, size: 20),
                    onPressed: () => _webController.reload(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey, size: 20),
                    onPressed: () {
                      if (_hasFinishedSaveOrCancel) return;
                      _hasFinishedSaveOrCancel = true;
                      Navigator.of(context).pop(false);
                    },
                  ),
                ],
              ),
            ),

            if (_isLoading)
              const LinearProgressIndicator(
                backgroundColor: Colors.transparent,
                color: accentGreen,
              ),

            // Embedded Native Letterboxd Edit Modal
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                child: WebViewWidget(controller: _webController),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
