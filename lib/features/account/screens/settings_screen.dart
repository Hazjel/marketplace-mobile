import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blukios_marketplace/config/app_theme.dart';
import 'package:blukios_marketplace/features/account/viewmodels/account_viewmodel.dart';
import 'package:blukios_marketplace/shared/widgets/app_scaffold.dart';

/// Which prefs group a [SettingsScreen] edits.
enum SettingsGroup { notification, privacy }

/// Renders the toggle list for one prefs group.
///
/// Both groups behave identically — optimistic flip, revert + snackbar on
/// failure — so they share one screen rather than two near-copies.
class SettingsScreen extends ConsumerWidget {
  final SettingsGroup group;

  const SettingsScreen({super.key, required this.group});

  static const _notificationLabels = <String, (String, String)>{
    'order_updates': ('Update Pesanan', 'Status pembayaran dan pengiriman'),
    'review_reminders': ('Pengingat Ulasan', 'Ingatkan menilai produk'),
    'promotions': ('Promo', 'Diskon dan penawaran khusus'),
    'price_drops': ('Turun Harga', 'Produk di wishlist yang turun harga'),
    'newsletter': ('Newsletter', 'Berita dan tips belanja'),
    'new_messages': ('Pesan Baru', 'Chat dari penjual'),
  };

  static const _privacyLabels = <String, (String, String)>{
    'profile_visible': ('Profil Publik', 'Penjual bisa melihat profilmu'),
    'show_online_status': ('Status Online', 'Tampilkan saat kamu aktif'),
    'show_purchase_history': (
      'Riwayat Belanja',
      'Tampilkan produk yang pernah dibeli'
    ),
  };

  bool get _isNotification => group == SettingsGroup.notification;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(accountProvider);
    final notifier = ref.read(accountProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted =
        isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary;

    final labels = _isNotification ? _notificationLabels : _privacyLabels;
    final values = _isNotification ? state.notificationPrefs : state.privacyPrefs;

    return AppScaffold(
      title: _isNotification ? 'Notifikasi' : 'Privasi',
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.spacingLG),
        children: labels.entries.map((entry) {
          final (title, subtitle) = entry.value;
          return SwitchListTile.adaptive(
            value: values[entry.key] ?? false,
            title: Text(title, style: AppTheme.titleMd),
            subtitle: Text(
              subtitle,
              style: AppTheme.bodySm.copyWith(color: muted),
            ),
            contentPadding: EdgeInsets.zero,
            onChanged: (value) async {
              final error = _isNotification
                  ? await notifier.toggleNotification(entry.key, value)
                  : await notifier.togglePrivacy(entry.key, value);

              if (error != null && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Gagal menyimpan: $error'),
                    backgroundColor: AppTheme.error,
                  ),
                );
              }
            },
          );
        }).toList(),
      ),
    );
  }
}
