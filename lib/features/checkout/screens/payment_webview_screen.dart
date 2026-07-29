import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:blukios_marketplace/config/api_config.dart';
import 'package:blukios_marketplace/config/routes.dart';
import 'package:blukios_marketplace/features/transaction/viewmodels/transaction_viewmodel.dart';

/// Midtrans has no Flutter Snap SDK; we load the same Snap web payment page
/// used by fe-blue's snap.js popup inside an in-app webview instead, and
/// detect completion from Midtrans's finish/unfinish/error redirect URLs.
class PaymentWebviewScreen extends ConsumerStatefulWidget {
  final String transactionId;
  final String snapToken;

  const PaymentWebviewScreen({
    super.key,
    required this.transactionId,
    required this.snapToken,
  });

  @override
  ConsumerState<PaymentWebviewScreen> createState() => _PaymentWebviewScreenState();
}

class _PaymentWebviewScreenState extends ConsumerState<PaymentWebviewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _isLoading = true),
          onPageFinished: (_) => setState(() => _isLoading = false),
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            final path = uri?.path ?? '';
            if (path.contains('/finish') || path.contains('/success')) {
              _handleResult('Pembayaran berhasil!', const Color(0xFF10B981));
              return NavigationDecision.prevent;
            }
            if (path.contains('/unfinish')) {
              _handleResult('Pesanan dibuat. Selesaikan pembayaran sebelum batas waktu.', const Color(0xFFCA8A04));
              return NavigationDecision.prevent;
            }
            if (path.contains('/error')) {
              _handleResult('Pembayaran gagal. Cek status di menu Transaksi untuk mencoba lagi.', const Color(0xFFEF4444));
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(ApiConfig.midtransSnapUrl(widget.snapToken)));
  }

  Future<void> _handleResult(String message, Color color) async {
    if (_finished) return;
    _finished = true;

    if (!mounted) return;
    await ref.read(transactionProvider.notifier).refreshStatus(widget.transactionId);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
    context.go(AppRoutes.transactions);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleResult('Popup ditutup. Pesanan tetap aktif — selesaikan pembayaran di menu Transaksi.', const Color(0xFFCA8A04));
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Pembayaran'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => _handleResult(
              'Popup ditutup. Pesanan tetap aktif — selesaikan pembayaran di menu Transaksi.',
              const Color(0xFFCA8A04),
            ),
          ),
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_isLoading) const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }
}
