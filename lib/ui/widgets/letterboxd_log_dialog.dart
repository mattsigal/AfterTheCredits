import 'dart:async';
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
    final userHomeUrl = username.isNotEmpty
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
        : (slug.isNotEmpty ? 'https://letterboxd.com/film/$slug/' : userHomeUrl);

    debugPrint('[LetterboxdLogDialog] rawTitle: "$rawTitle", yearStr: "$yearStr", computedSlug: "$slug"');
    debugPrint('[LetterboxdLogDialog] Initial URL: $initialUrl');

    _webController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
          'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Mobile Safari/537.36')
      ..setOnConsoleMessage((JavaScriptConsoleMessage message) {
        debugPrint('[LetterboxdJS] ${message.message}');
      })
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
          onProgress: (progress) {
            if (progress > 40) {
              _injectRefinements();
            }
          },
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

    Timer.periodic(const Duration(milliseconds: 600), (timer) {
      if (!mounted || _hasFinishedSaveOrCancel) {
        timer.cancel();
        return;
      }
      _injectRefinements();
    });

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
    const jsCode = r'''
      (function() {
        if (window.__lbxdSaved) return;

        if (sessionStorage.getItem('__lbxdSubmitted') === 'true') {
          sessionStorage.removeItem('__lbxdSubmitted');
          console.log('[LetterboxdJS] Save successful, closing dialog');
          if (window.LetterboxdSaveChannel) {
            window.LetterboxdSaveChannel.postMessage('saved');
          }
          return;
        }

        console.log('[LetterboxdJS] Injected refinements loaded');

        document.cookie = "useMobileSite=no; path=/; domain=.letterboxd.com";
        document.cookie = "useMobileSite=no; path=/; domain=letterboxd.com";

        let style = document.getElementById('letterboxd-custom-cleaner');
        if (!style) {
          style = document.createElement('style');
          style.id = 'letterboxd-custom-cleaner';
          document.head.appendChild(style);
        }
        style.innerHTML = `
          #header, .site-header {
            height: 0 !important;
            min-height: 0 !important;
            max-height: 0 !important;
            overflow: hidden !important;
            opacity: 0 !important;
            pointer-events: none !important;
            padding: 0 !important;
            margin: 0 !important;
          }

          iframe, #footer, footer, .site-footer, .banner-ad, .ad, .google-ad, 
          [class*="ad-container"], [id*="ad-container"], [class*="banner-ad"],
          .anchor-ad, #anchor-ad, .intergient-ad, [id*="intergient"], [class*="intergient"],
          [id*="google_ads_iframe"], div[id*="google_ads_iframe"], .adbox, .ad-space,
          .ad-banner, .site-footer-ad, .widget-ad, .ad-unit, [id*="ad-wrapper"],
          .advertisement, .commercial, .playwire-ad {
            display: none !important;
            visibility: hidden !important;
            opacity: 0 !important;
            height: 0 !important;
            width: 0 !important;
            pointer-events: none !important;
          }

          .rateit-reset, .remove-rating {
            display: none !important;
            visibility: hidden !important;
            opacity: 0 !important;
            width: 0 !important;
            height: 0 !important;
            pointer-events: none !important;
          }

          .rateit {
            transform: scale(1.35) !important;
            transform-origin: left center !important;
            margin-right: 20px !important;
          }

          html, body {
            background-color: #283038 !important;
            color: #ffffff !important;
            padding: 0 !important;
            margin: 0 !important;
          }
        `;

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

        if (!window.__lbxdSubmitIntercepted) {
          window.__lbxdSubmitIntercepted = true;
          document.addEventListener('submit', function(e) {
            const form = e.target;
            if (form && (form.id === 'diary-entry-form' || form.classList.contains('diary-entry-form') || form.action.includes('save') || form.closest('#diary-entry-form-modal'))) {
              console.log('[LetterboxdJS] Diary/Review form submit intercepted, setting sessionStorage');
              sessionStorage.setItem('__lbxdSubmitted', 'true');
            }
          }, true);
        }

        if (!window.__lbxdClickIntercepted) {
          window.__lbxdClickIntercepted = true;

          const notifySaved = function() {
            if (window.__lbxdSavedSent) return;
            window.__lbxdSavedSent = true;
            window.__lbxdSaved = true;
            console.log('[LetterboxdJS] Sending saved message to Flutter');
            if (window.LetterboxdSaveChannel) {
              window.LetterboxdSaveChannel.postMessage('saved');
            }
          };

          const origOpen = XMLHttpRequest.prototype.open;
          XMLHttpRequest.prototype.open = function(method, url) {
            const isSaveEndpoint = url && (
              url.includes('save-diary-entry') || 
              url.includes('save-film-entry') || 
              url.includes('production-log-entries') ||
              url.includes('save')
            );
            this.addEventListener('load', function() {
              console.log('[LetterboxdJS] XHR Load: ' + url + ' Status: ' + this.status);
              if (isSaveEndpoint) {
                if (this.status === 200 || this.status === 201 || this.status === 302) {
                  notifySaved();
                }
              }
            });
            origOpen.apply(this, arguments);
          };

          const origFetch = window.fetch;
          window.fetch = async function() {
            const url = arguments[0] ? (typeof arguments[0] === 'string' ? arguments[0] : arguments[0].url) : '';
            const isSaveEndpoint = url && (
              url.includes('save-diary-entry') || 
              url.includes('save-film-entry') || 
              url.includes('production-log-entries') ||
              url.includes('save')
            );
            const res = await origFetch.apply(this, arguments);
            console.log('[LetterboxdJS] Fetch Res: ' + url + ' Status: ' + res.status);
            if (isSaveEndpoint) {
              if (res.status === 200 || res.status === 201 || res.status === 302) {
                notifySaved();
              }
            }
            return res;
          };
        }

        let hasClickedEdit = false;
        const triggerEdit = () => {
          if (window.__lbxdSaved || hasClickedEdit) return;

          const modal = document.querySelector('#diary-entry-form-modal, .diary-entry-form-modal');
          const isModalVisible = modal && (
            modal.classList.contains('in') ||
            modal.classList.contains('show') ||
            modal.classList.contains('visible') ||
            modal.classList.contains('active')
          );

          if (isModalVisible) {
            hasClickedEdit = true;
            console.log('[LetterboxdJS] Modal is open and visible, stopping poller');
            const nextOrReviewBtn = modal.querySelector('[data-js-trigger="next"], [data-js-trigger="review"], .js-wizard-next, .js-show-review, a[href*="#review"], a.option-review');
            if (nextOrReviewBtn) {
              console.log('[LetterboxdJS] Clicking next/review wizard step');
              nextOrReviewBtn.click();
            }
            return;
          }

          if (window.__lbxdIsNew) {
            if (window.jQuery) {
              const $btn = window.jQuery('#add-new-button, .button-add, a.add-film-link, .js-open-diary-entry-modal, .js-add-film-button, a.nav-account-log');
              if ($btn.length > 0) {
                console.log('[LetterboxdJS] Triggering jQuery click on Add Film header button');
                hasClickedEdit = true;
                $btn.first().trigger('click');
                return;
              }
            }
            const btn = document.querySelector('#add-new-button, .button-add, a.add-film-link, .js-open-diary-entry-modal, .js-add-film-button, a.nav-account-log');
            if (btn) {
              console.log('[LetterboxdJS] Triggering native DOM click on Add Film header button');
              hasClickedEdit = true;
              btn.click();
            }
          } else {
            const selectors = [
              'a[href*="/edit/"]',
              'a[href*="edit-review"]',
              '.js-edit-review',
              '[data-component-class="EditLogEntry"] a',
              '[data-component-class="AddLogEntry"] a',
              '[data-component-class="LogFilm"] a',
              'section.film-header-wrapper a[href*="/log/"]',
              'a.log-entry-button',
              '.js-open-diary-entry-modal:not(.button-add):not(#add-new-button)',
              '#content a[href*="/log/"]',
              '#content a[href*="#log"]'
            ];
            for (let sel of selectors) {
              const el = document.querySelector(sel);
              if (el && el.offsetHeight > 0) {
                console.log('[LetterboxdJS] Triggering film page action selector: ' + sel);
                hasClickedEdit = true;
                el.click();
                return;
              }
            }

            const candidates = Array.from(document.querySelectorAll('#content a, #content button, #content span.label'));
            const logTarget = candidates.find(el => {
              const txt = (el.textContent || '').trim().toLowerCase();
              return txt.includes('edit entry') ||
                     txt.includes('edit or delete review') ||
                     txt.includes('edit review') ||
                     txt.includes('edit or delete') ||
                     txt.includes('rate or add') ||
                     txt.includes('log or review') ||
                     txt.includes('log this film') ||
                     txt.includes('add to your films');
            });
            if (logTarget) {
              console.log('[LetterboxdJS] Triggering film page text match: ' + (logTarget.textContent || '').trim());
              hasClickedEdit = true;
              const btn = logTarget.closest('button') || logTarget.closest('a') || logTarget;
              btn.click();
            }
          }
        };

        if (!window.__lbxdSaved) {
          triggerEdit();
          if (!window.__lbxdPoller) {
            window.__lbxdPoller = setInterval(triggerEdit, 300);
          }
        }
      })();
    ''';

    try {
      await _webController.runJavaScript('window.__lbxdIsNew = ${widget.filmTitle.isEmpty};');
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
