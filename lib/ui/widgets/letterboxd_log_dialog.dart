import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../providers/app_provider.dart';
import '../../utils/title_formatter.dart';
import '../../data/models/letterboxd_item.dart';
import '../../data/services/letterboxd_service.dart';

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

  static String _cleanFilmTitle(String rawTitle) {
    var clean = rawTitle.replaceAll(RegExp(r'\s*\(\d{4}\)\s*'), ' ').trim();
    if (clean.endsWith('*')) {
      clean = clean.substring(0, clean.length - 1).trim();
    }
    return clean;
  }

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

    final provider = Provider.of<AppProvider>(context, listen: false);
    final username = provider.letterboxdUsername.trim().toLowerCase();
    final userDiaryUrl = username.isNotEmpty
        ? 'https://letterboxd.com/$username/diary/'
        : 'https://letterboxd.com/';

    final rawTitle = widget.filmTitle;
    final yearMatch = RegExp(r'\((\d{4})\)').firstMatch(rawTitle);
    final yearStr = widget.filmYear ?? yearMatch?.group(1);
    final cleanedTitle = _cleanFilmTitle(rawTitle);
    final baseSlug = cleanedTitle
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');

    final computedSlug = (widget.existingItem == null && yearStr != null && yearStr.isNotEmpty)
        ? '$baseSlug-$yearStr'
        : baseSlug;

    final slug = _extractSlugFromLink(widget.existingItem?.link) ?? computedSlug;

    final initialUrl = (widget.existingItem?.link != null && widget.existingItem!.link.isNotEmpty)
        ? widget.existingItem!.link
        : (slug.isNotEmpty ? 'https://letterboxd.com/film/$slug/' : userDiaryUrl);

    debugPrint('[LetterboxdLogDialog] rawTitle: "$rawTitle", yearStr: "$yearStr", computedSlug: "$slug"');
    debugPrint('[LetterboxdLogDialog] Initial URL: $initialUrl');

    _webController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
          'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Mobile Safari/537.36')
      ..addJavaScriptChannel(
        'LetterboxdSaveChannel',
        onMessageReceived: (JavaScriptMessage message) {
          debugPrint('[LetterboxdLogDialog] SaveChannel Message: ${message.message}');
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
          onPageStarted: (url) {
            debugPrint('[LetterboxdLogDialog] Page Started: $url');
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (url) async {
            debugPrint('[LetterboxdLogDialog] Page Finished: $url');
            if (_hasFinishedSaveOrCancel) return;
            if (mounted) setState(() => _isLoading = false);
            await _injectRefinements();
          },
          onWebResourceError: (error) {
            debugPrint('[LetterboxdLogDialog] WebResourceError: ${error.description} (code: ${error.errorCode}, url: ${error.url})');
          },
        ),
      )
      ..loadRequest(Uri.parse(initialUrl));

    if (widget.filmTitle.isNotEmpty && (widget.existingItem?.link == null || widget.existingItem!.link.isEmpty)) {
      _resolveAndNavigateExactUrl();
    }
  }

  Future<void> _resolveAndNavigateExactUrl() async {
    try {
      final exactUrl = await LetterboxdService.resolveFilmUrl(
        widget.filmTitle,
        year: widget.filmYear,
      );
      debugPrint('[LetterboxdLogDialog] Resolved Exact URL: $exactUrl');
      if (mounted && !_hasFinishedSaveOrCancel) {
        _webController.loadRequest(Uri.parse(exactUrl));
      }
    } catch (e) {
      debugPrint('[LetterboxdLogDialog] Resolve error: $e');
    }
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

        // Intercept XHR / Fetch POST saves, button clicks & Form Submits to notify Flutter and pop dialog
        if (!window.__lbxdClickIntercepted) {
          window.__lbxdClickIntercepted = true;

          const notifySaved = function() {
            if (window.__lbxdSavedSent) return;
            window.__lbxdSavedSent = true;
            window.__lbxdSaved = true;
            if (window.LetterboxdSaveChannel) {
              window.LetterboxdSaveChannel.postMessage('saved');
            }
          };

          document.addEventListener('click', function(e) {
            let el = e.target;
            while (el && el !== document.body) {
              const text = (el.textContent || el.value || '').trim().toLowerCase();
              const inModal = el.closest('#diary-entry-form-modal, .diary-entry-form-modal, form.diary-entry-form, form[action*="save"]');

              const isSaveButton = (inModal && (
                el.type === 'submit' ||
                text === 'save' ||
                text.startsWith('save ') ||
                el.classList.contains('js-save-diary-entry')
              ));

              if (isSaveButton) {
                window.__userClickedSave = true;
                setTimeout(notifySaved, 650);
                break;
              }
              el = el.parentElement;
            }
          }, true);

          const origOpen = XMLHttpRequest.prototype.open;
          XMLHttpRequest.prototype.open = function(method, url) {
            this.addEventListener('load', function() {
              if (window.__userClickedSave) {
                if (this.status === 200 || this.status === 201 || this.status === 302) {
                  notifySaved();
                }
              }
            });
            origOpen.apply(this, arguments);
          };

          const origFetch = window.fetch;
          window.fetch = async function() {
            const res = await origFetch.apply(this, arguments);
            if (window.__userClickedSave) {
              if (res.status === 200 || res.status === 201 || res.status === 302) {
                notifySaved();
              }
            }
            return res;
          };

          document.addEventListener('submit', function(e) {
            const form = e.target;
            if (form && (form.id.includes('diary') || form.action.includes('save') || form.closest('#diary-entry-form-modal'))) {
              window.__userClickedSave = true;
              setTimeout(notifySaved, 400);
            }
          }, true);
        }

        // Trigger EditLogEntry or AddLogEntry after React component hydration finishes
        let hasClickedEdit = false;
        const triggerEdit = () => {
          if (window.__lbxdSaved) return;

          const modal = document.querySelector('#diary-entry-form-modal, .diary-entry-form-modal');
          if (modal) {
            // Check if review area or compose wizard step is visible
            const composeSection = modal.querySelector('section[data-js-wizard-step="compose"], .diary-entry-form-wizard-step.-compose');
            const textarea = modal.querySelector('textarea');
            const isReviewFieldVisible = (composeSection && !composeSection.hasAttribute('hidden') && composeSection.offsetHeight > 40) ||
                                         (textarea && textarea.offsetHeight > 30);

            if (isReviewFieldVisible) {
              hasClickedEdit = true;
              return;
            }

            // If modal is open but on Step 1 ("Add to your films"), trigger "Specify date or add review..." or Next
            const nextOrReviewBtn = modal.querySelector('[data-js-trigger="next"], [data-js-trigger="review"], .js-wizard-next, .js-show-review, a[href*="#review"], a.option-review');
            if (nextOrReviewBtn) {
              nextOrReviewBtn.click();
              hasClickedEdit = true;
              return;
            }

            const allModalLinks = Array.from(modal.querySelectorAll('a, button, span'));
            const reviewToggle = allModalLinks.find(el => {
              const txt = (el.textContent || '').trim().toLowerCase();
              return txt.includes('specify date') || txt.includes('add review') || txt.includes('add a review') || txt.includes('write a review');
            });
            if (reviewToggle) {
              const btn = reviewToggle.closest('button') || reviewToggle.closest('a') || reviewToggle;
              btn.click();
              hasClickedEdit = true;
              return;
            }
          }

          if (hasClickedEdit) return;

          const logClassWrappers = document.querySelectorAll('[data-component-class="EditLogEntry"], [data-component-class="AddLogEntry"], [data-component-class="LogFilm"]');
          for (let wrapper of logClassWrappers) {
            const btn = wrapper.querySelector('button') || wrapper.querySelector('a');
            if (btn) {
              hasClickedEdit = true;
              btn.click();
              return;
            }
          }

          const actionLinks = document.querySelectorAll('a.add-film-link, a.log-entry-button, a[href*="/log/"], .js-open-diary-entry-modal, .js-add-film-button');
          if (actionLinks.length > 0) {
            hasClickedEdit = true;
            actionLinks[0].click();
            return;
          }

          const allLabels = Array.from(document.querySelectorAll('span.label, button, a, div'));
          const target = allLabels.find(el => {
            const txt = (el.textContent || '').trim().toLowerCase();
            return txt.includes('edit entry or add review') ||
                   txt.includes('log, rate, or add') ||
                   txt.includes('log or review') ||
                   txt.includes('log film') ||
                   txt.includes('log this film') ||
                   txt.includes('add to your films') ||
                   txt === 'log' || txt === 'review';
          });

          if (target) {
            hasClickedEdit = true;
            const btn = target.closest('button') || target.closest('a') || target;
            btn.click();
          }
        };

        if (!window.__lbxdSaved) {
          setTimeout(triggerEdit, 300);
          setTimeout(triggerEdit, 700);
          setTimeout(triggerEdit, 1200);
          setTimeout(triggerEdit, 2000);
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
