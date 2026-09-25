import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:blukios_marketplace/config/app_theme.dart';
import 'package:blukios_marketplace/config/routes.dart';
import 'package:blukios_marketplace/features/auth/viewmodels/auth_viewmodel.dart';
import 'package:blukios_marketplace/shared/widgets/app_icon.dart';
import 'package:blukios_marketplace/shared/widgets/app_scaffold.dart';

const _confirmPhrase = 'HAPUS AKUN';

/// Padanan `DeleteAccount.vue`: mengetik ulang [_confirmPhrase] sebagai
/// pengaman, alih-alih dialog konfirmasi biasa yang gampang terpencet.
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final _confirmController = TextEditingController();
  bool _canDelete = false;
  bool _isDeleting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _confirmController.dispose();
    super.dispose();
  }

  void _onConfirmChanged(String value) {
    final matches = value == _confirmPhrase;
    if (matches != _canDelete) setState(() => _canDelete = matches);
  }

  Future<void> _handleDelete() async {
    if (!_canDelete) return;

    setState(() {
      _isDeleting = true;
      _errorMessage = null;
    });

    final error = await ref.read(authProvider.notifier).deleteAccount();

    if (!mounted) return;
    if (error != null) {
      setState(() {
        _isDeleting = false;
        _errorMessage = error;
      });
      return;
    }

    context.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppScaffold(
      title: 'Hapus Akun',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacingLG),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingMD),
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppTheme.radiusXLCard),
                border:
                    Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppIcon(
                    AppIcons.alert,
                    color: AppTheme.error,
                    size: AppIconSize.lg,
                  ),
                  const SizedBox(width: AppTheme.spacingSM),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Perhatian!',
                          style: TextStyle(
                            color: AppTheme.error,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacingXS),
                        Text(
                          'Tindakan ini bersifat permanen. Riwayat transaksi, '
                          'alamat, dan chat akan hilang dan tidak dapat '
                          'dipulihkan. Kalau kamu seorang penjual, tokomu '
                          'akan dinonaktifkan.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: isDark
                                ? AppTheme.darkTextSecondary
                                : AppTheme.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacingLG),
            const Text(
              'Ketik "$_confirmPhrase" untuk melanjutkan',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppTheme.spacingSM),
            TextField(
              controller: _confirmController,
              onChanged: _onConfirmChanged,
              decoration: const InputDecoration(hintText: _confirmPhrase),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: AppTheme.spacingMD),
              Text(
                _errorMessage!,
                style: const TextStyle(color: AppTheme.error, fontSize: 12.5),
              ),
            ],
            const SizedBox(height: AppTheme.spacingLG),
            SizedBox(
              height: 50,
              child: FilledButton(
                onPressed: (_canDelete && !_isDeleting) ? _handleDelete : null,
                style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
                child: _isDeleting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Hapus Akun Saya'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
