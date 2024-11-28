import 'package:flutter/material.dart';
import 'package:eatseasy/common/back_ground_container.dart';
import 'package:eatseasy/controllers/order_controller.dart';
import 'package:eatseasy/views/orders/payments/failed.dart';
import 'package:eatseasy/views/orders/payments/successful.dart';
import 'package:get/get.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:html' as html;
import 'dart:async'; 

import '../../controllers/wallet_controller.dart';

class PaymentWebView extends StatefulWidget {
  final String amount;
  final String currentAction;

  const PaymentWebView({super.key, required this.amount, required this.currentAction});

  @override
  State<PaymentWebView> createState() => _PaymentWebViewState();
}

class _PaymentWebViewState extends State<PaymentWebView> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    final WalletController walletController = Get.put(WalletController());

    if (kIsWeb) {
      // Web
      _loadWebView(walletController);
    } else {
      // Mobile
      _initializeMobileWebView(walletController);
    }
  }

  void _initializeMobileWebView(WalletController walletController) {
    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    final WebViewController controller = WebViewController.fromPlatformCreationParams(params);

    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            // debugPrint('Page started loading: ${paymentNotifier.paymentUrl}');
          },
          onPageFinished: (String url) {
            // debugPrint('Page finished loading: $url');
          },
          
          onNavigationRequest: (NavigationRequest request) {
            return NavigationDecision.navigate;
          },
          onUrlChange: (UrlChange change) async {
            if (change.url!.contains("checkout-success")) {
              walletController.paymentUrl = '';
              if (widget.currentAction == 'load') {
                await walletController.initiateTopUp(double.parse(widget.amount), 'Top-up');
              } else if (widget.currentAction == 'pay') {
                await walletController.initiatePay(double.parse(widget.amount), 'Pay');
              } else {
                await walletController.initiateWithdraw(double.parse(widget.amount), 'Withdraw');
              }

            }else if(change.url!.contains("cancel")){
              walletController.paymentUrl = '';
              walletController.handlePaymentFailure();
            }
          },
        ),
      )
      ..addJavaScriptChannel(
        'Toaster',
        onMessageReceived: (JavaScriptMessage message) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message.message)),
          );
        },
      )
      ..loadRequest(Uri.parse(walletController.paymentUrl));

    // #docregion platform_features
    if (controller.platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(true);
     (controller.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }
     // #enddocregion platform_features

    _controller = controller;
  }

StreamSubscription? _messageSubscription; // Track the subscription

void _loadWebView(WalletController walletController) async {
  final String url = walletController.paymentUrl;

  html.window.open(url, "_blank");

  // Cancel any existing listener before attaching a new one
  _messageSubscription?.cancel();

  Future<void> messageListener(html.MessageEvent event) async {
    // we listen from the backend
    if (event.origin == "http://localhost:5040") {
      print("Received message: ${event.data}");
      if (event.data == "payment_success") {
        await walletController.initiateTopUp(double.parse(widget.amount), 'Top-up');
      } else if (event.data == "payment_cancel") {
        walletController.paymentUrl = '';
        walletController.handlePaymentFailure();
      }
      // Cancel listener after processing the message
      _messageSubscription?.cancel();
    }
  }

  // Attach the listener and store the subscription
  _messageSubscription = html.window.onMessage.listen(messageListener);
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 5,
        leading: Container()
      ),
      body: Center(
        child: kIsWeb
            ? BackGroundContainer(child: Container()) // Empty container for web; iframe added directly
            : BackGroundContainer(child: WebViewWidget(controller: _controller)), // Android/iOS
      ),
    );
  }
}
