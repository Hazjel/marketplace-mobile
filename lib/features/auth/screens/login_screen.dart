import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:blukios_marketplace/config/api_config.dart';
import 'package:blukios_marketplace/config/app_theme.dart';
import 'package:blukios_marketplace/config/routes.dart';
import 'package:blukios_marketplace/core/storage/secure_storage.dart';
import 'package:blukios_marketplace/features/auth/viewmodels/auth_viewmodel.dart';
import 'package:blukios_marketplace/shared/widgets/app_icon.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isGoogleLoading = false;
  String? _googleErrorMessage;

  late final AppLinks _appLinks;
  StreamSubscription? _linkSub;

  @override
  void initState() {
    super.initState();
    _appLinks = AppLinks();
    _listenForDeepLinks();
  }

  void _listenForDeepLinks() {
    _linkSub = _appLinks.uriLinkStream.listen((Uri uri) {
      if (uri.scheme == 'mobileblue' && uri.host == 'callback') {
        _handleOAuthCallback(uri);
      }
    });
  }

  Future<void> _handleOAuthCallback(Uri uri) async {
    final token = uri.queryParameters['token'];
    if (token == null || token.isEmpty) {
      setState(() {
        _googleErrorMessage = 'Login Google gagal: token tidak ditemukan';
        _isGoogleLoading = false;
      });
      return;
    }

    setState(() {
      _isGoogleLoading = true;
      _googleErrorMessage = null;
    });

    try {
      await SecureStorage.saveToken(token);
      if (mounted) {
        await ref.read(authProvider.notifier).refreshAfterExternalLogin();
      }
    } catch (e) {
      setState(() => _googleErrorMessage = 'Gagal menyimpan sesi login');
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(authProvider.notifier).login(
          _emailController.text.trim(),
          _passwordController.text,
        );
  }

  Future<void> _handleGoogleLogin() async {
    setState(() {
      _isGoogleLoading = true;
      _googleErrorMessage = null;
    });

    try {
      final baseUrl = ApiConfig.baseUrl.replaceAll('/api', '');
      final googleUrl = Uri.parse(
        '$baseUrl/api/auth/google/redirect?platform=mobile',
      );

      await launchUrl(googleUrl, mode: LaunchMode.externalApplication);
    } catch (e) {
      setState(() {
        _googleErrorMessage = 'Gagal membuka Google Login';
        _isGoogleLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = ref.watch(authProvider);
    final errorMessage = _googleErrorMessage ?? auth.errorMessage;
    final isLoading = auth.isLoading;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo / Brand
                  const AppIcon(
                    AppIcons.store,
                    size: 56,
                    color: AppTheme.primary,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Blukios',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Masuk ke akun Anda',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Error message
                  if (errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const AppIcon(AppIcons.alert, color: AppTheme.error, size: AppIconSize.md),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              errorMessage,
                              style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Google Sign-In button
                  SizedBox(
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: (_isGoogleLoading || isLoading) ? null : _handleGoogleLogin,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: theme.dividerColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: _isGoogleLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const BrandIcon(BrandAssets.google, size: 20),
                      label: const Text(
                        'Masuk dengan Google',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Divider
                  Row(
                    children: [
                      Expanded(child: Divider(color: theme.dividerColor)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'atau',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: theme.dividerColor)),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Email field
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      hintText: 'Email',
                      prefixIcon: FieldIcon(AppIcons.mail),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Email wajib diisi';
                      if (!value.contains('@')) return 'Format email tidak valid';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Password field
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      hintText: 'Password',
                      prefixIcon: const FieldIcon(AppIcons.lock),
                      suffixIcon: IconButton(
                        icon: AppIcon(_obscurePassword ? AppIcons.eyeOff : AppIcons.eye, size: AppIconSize.md),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Password wajib diisi';
                      if (value.length < 6) return 'Password minimal 6 karakter';
                      return null;
                    },
                    onFieldSubmitted: (_) => _handleLogin(),
                  ),
                  const SizedBox(height: 24),

                  // Login button
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: (isLoading || _isGoogleLoading) ? null : _handleLogin,
                      child: isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Masuk'),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Register link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Belum punya akun? ',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => context.push(AppRoutes.register),
                        child: const Text(
                          'Daftar',
                          style: TextStyle(
                            color: Color(0xFF2563EB),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
