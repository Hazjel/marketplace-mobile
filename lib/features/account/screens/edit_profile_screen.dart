import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:blukios_marketplace/config/app_theme.dart';
import 'package:blukios_marketplace/features/account/viewmodels/account_viewmodel.dart';
import 'package:blukios_marketplace/shared/widgets/app_scaffold.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();

  bool _changePassword = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(accountProvider).user;
    _nameController.text = user?.name ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final error = await ref.read(accountProvider.notifier).updateProfile(
          name: _nameController.text.trim(),
          phoneNumber: _phoneController.text.trim(),
          currentPassword:
              _changePassword ? _currentPasswordController.text : null,
          newPassword: _changePassword ? _newPasswordController.text : null,
        );

    if (!mounted) return;

    if (error == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profil berhasil diperbarui'),
          backgroundColor: AppTheme.success,
        ),
      );
      context.pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppTheme.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSaving = ref.watch(accountProvider).isSaving;

    return AppScaffold(
      title: 'Ubah Profil',
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppTheme.spacingLG),
          children: [
            const _Label('Nama Lengkap'),
            TextFormField(
              controller: _nameController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(hintText: 'Nama lengkap'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Nama wajib diisi' : null,
            ),
            const SizedBox(height: AppTheme.spacingLG),

            const _Label('Nomor Telepon'),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(hintText: '08xxxxxxxxxx'),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                // Matches the API rule: ^08[0-9]{8,13}$
                if (!RegExp(r'^08[0-9]{8,13}$').hasMatch(v.trim())) {
                  return 'Format: 08 diikuti 8-13 angka';
                }
                return null;
              },
            ),
            const SizedBox(height: AppTheme.spacingLG),

            SwitchListTile.adaptive(
              value: _changePassword,
              onChanged: (v) => setState(() => _changePassword = v),
              title: Text('Ubah Password', style: AppTheme.titleMd),
              contentPadding: EdgeInsets.zero,
            ),

            if (_changePassword) ...[
              const SizedBox(height: AppTheme.spacingSM),
              const _Label('Password Saat Ini'),
              TextFormField(
                controller: _currentPasswordController,
                obscureText: true,
                decoration:
                    const InputDecoration(hintText: 'Password saat ini'),
                validator: (v) => (_changePassword && (v == null || v.isEmpty))
                    ? 'Wajib diisi untuk mengubah password'
                    : null,
              ),
              const SizedBox(height: AppTheme.spacingLG),
              const _Label('Password Baru'),
              TextFormField(
                controller: _newPasswordController,
                obscureText: true,
                decoration: const InputDecoration(hintText: 'Password baru'),
                validator: (v) {
                  if (!_changePassword) return null;
                  if (v == null || v.length < 8) return 'Minimal 8 karakter';
                  // Matches the API rule: >=1 uppercase and >=1 digit.
                  if (!RegExp(r'[A-Z]').hasMatch(v)) {
                    return 'Harus ada 1 huruf kapital';
                  }
                  if (!RegExp(r'[0-9]').hasMatch(v)) {
                    return 'Harus ada 1 angka';
                  }
                  return null;
                },
              ),
            ],

            const SizedBox(height: AppTheme.spacingXL),
            FilledButton(
              onPressed: isSaving ? null : _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Simpan Perubahan'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;

  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingSM),
      child: Text(text, style: AppTheme.labelMd),
    );
  }
}
