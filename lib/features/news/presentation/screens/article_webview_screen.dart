import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../app/app_colors.dart';

class ArticleWebViewScreen extends StatefulWidget {
  const ArticleWebViewScreen({
    super.key,
    required this.title,
    required this.url,
  });

  final String title;
  final String url;

  @override
  State<ArticleWebViewScreen> createState() => _ArticleWebViewScreenState();
}

class _ArticleWebViewScreenState extends State<ArticleWebViewScreen> {
  late final WebViewController _controller;
  int _progress = 0;
  String? _error;
  bool _allowPop = false;
  bool _handlingBack = false;

  @override
  void initState() {
    super.initState();
    final uri = Uri.tryParse(widget.url);
    if (uri == null || uri.scheme != 'https' || !uri.hasAuthority || uri.host.isEmpty) {
      _error = 'This article link is not a valid secure URL.';
      return;
    }
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (mounted) setState(() => _progress = progress);
          },
          onWebResourceError: (error) {
            if (mounted && error.isForMainFrame == true) {
              setState(() => _error = 'Could not load this article.');
            }
          },
          onNavigationRequest: (request) {
            final target = Uri.tryParse(request.url);
            if (target == null || target.scheme != 'https' || !target.hasAuthority || target.host.isEmpty) {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(uri);
  }

  Future<void> _handleBack() async {
    if (_handlingBack || _allowPop) return;
    _handlingBack = true;

    try {
      if (_error == null && await _controller.canGoBack()) {
        await _controller.goBack();
        return;
      }

      if (!mounted) return;

      setState(() => _allowPop = true);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pop();
      });
    } finally {
      _handlingBack = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
      appBar: AppBar(
        title: Text(widget.title, maxLines: 1),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _handleBack,
        ),
      ),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
              ),
            )
          : Column(
              children: [
                if (_progress < 100)
                  LinearProgressIndicator(value: _progress / 100),
                Expanded(child: WebViewWidget(controller: _controller)),
              ],
            ),
      ),
    );
  }
}
