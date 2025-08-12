import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/* ----------------------------------------------------------
   HTML PREVIEW DIALOG - Shows HTML content in a WebView
---------------------------------------------------------- */
class HtmlPreviewDialog extends StatefulWidget {
  final String htmlContent;
  
  const HtmlPreviewDialog({super.key, required this.htmlContent});
  
  @override
  State<HtmlPreviewDialog> createState() => _HtmlPreviewDialogState();
}

class _HtmlPreviewDialogState extends State<HtmlPreviewDialog> {
  late final WebViewController _webViewController;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
          },
        ),
      );

    // Create a complete HTML document with the provided HTML content
    final String completeHtml = '''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>HTML Preview</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            margin: 16px;
            line-height: 1.6;
            color: #333;
        }
        * {
            max-width: 100%;
        }
        img {
            height: auto;
        }
    </style>
</head>
<body>
${widget.htmlContent}
</body>
</html>
    ''';

    _webViewController.loadHtmlString(completeHtml);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFF4F3F0),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.preview_rounded,
                    color: Color(0xFF000000),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'HTML Preview',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF000000),
                    ),
                  ),
                  if (_isLoading) ...[
                    const SizedBox(width: 8),
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF000000)),
                      ),
                    ),
                  ],
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close,
                      color: Color(0xFF000000),
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
            // WebView Content
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: WebViewWidget(controller: _webViewController),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}