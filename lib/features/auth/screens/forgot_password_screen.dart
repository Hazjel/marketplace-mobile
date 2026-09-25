import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blukios_marketplace/config/app_theme.dart';
import 'package:blukios_marketplace/features/auth/viewmodels/auth_viewmodel.dart';
import 'package:blukios_marketplace/shared/widgets/app_icon.dart';

/// Meminta link reset password. Web punya padanan penuh (kirim link lalu
/// user reset password lewat halaman web); di sini hanya langkah pertama
/// -- link dari email tetap membuka web, karena app ini belum punya
/// Universal Links/App Links terverifikasi untuk menangkapnya sebagai
/// deep link. Sama dengan bagaimana verifikasi email ditangani.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isSubmitting = false;
  bool _sent = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final error = await ref
        .read(authProvider.notifier)
        .forgotPassword(_emailController.text.trim());

    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
      if (error == null) {
        _sent = true;
      } else {
        _errorMessage = error;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Lupa Password')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child:
                _sent ? _SentState(email: _emailController.text.trim()) : _form(theme),
          ),
        ),
      ),
    );
  }

  Widget _form(ThemeData theme) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppIcon(AppIcons.lock, size: 48, color: AppTheme.primary),
          const SizedBox(height: 16),
          const Text(
            'Reset Password',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Masukkan email akunmu. Kami kirim link untuk membuat password baru.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 32),
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13),
              ),
            ),
            const SizedBox(height: 16),
          ],
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              hintText: 'Email',
              prefixIcon: FieldIcon(AppIcons.mail),
            ),
            onFieldSubmitted: (_) => _submit(),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Email wajib diisi';
              if (!value.contains('@')) return 'Format email tidak valid';
              return null;
            },
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Kirim Link Reset'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SentState extends StatelessWidget {
  final String email;

  const _SentState({required this.email});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const AppIcon(AppIcons.mail, size: 48, color: AppTheme.success),
        const SizedBox(height: 16),
        const Text(
          'Link Terkirim',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          'Cek inbox $email (atau folder spam) untuk link reset password.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 50,
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Kembali ke Login'),
          ),
        ),
      ],
    );
  }
}
