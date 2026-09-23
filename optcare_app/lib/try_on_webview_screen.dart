import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

class TryOnWebViewScreen extends StatefulWidget {
  final int frameId;

  const TryOnWebViewScreen({
    super.key,
    required this.frameId,
  });

  @override
  State<TryOnWebViewScreen> createState() =>
      _TryOnWebViewScreenState();
}

class _TryOnWebViewScreenState
    extends State<TryOnWebViewScreen> {

  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();

    final url = Uri.parse(
      'https://gonzalesvisionclinic.vercel.app/',
    ).replace(
      queryParameters: {
        'frameId': widget.frameId.toString(),
        'mobileTryOn': 'true',
      },
    );

    debugPrint('TRY-ON URL: $url');

    _controller = WebViewController()
      ..setJavaScriptMode(
        JavaScriptMode.unrestricted,
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            debugPrint(
              'TRY-ON PAGE STARTED: $url',
            );
          },
          onPageFinished: (url) {
            debugPrint(
              'TRY-ON PAGE FINISHED: $url',
            );
          },
          onWebResourceError: (error) {
            debugPrint(
              'TRY-ON WEBVIEW ERROR: ${error.description}',
            );
          },
        ),
      );

    // Allow the web page to request camera access.
    if (_controller.platform is AndroidWebViewController) {
      final androidController =
          _controller.platform as AndroidWebViewController;

      androidController.setOnPlatformPermissionRequest(
        (request) {
          debugPrint(
            '🌐 WebView permission request: ${request.types}',
          );

          request.grant();
        },
      );
    }

    _controller.loadRequest(url);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Virtual Try-On'),
      ),
      body: WebViewWidget(
        controller: _controller,
      ),
    );
  }
}