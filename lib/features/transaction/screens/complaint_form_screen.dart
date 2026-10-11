import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:blukios_marketplace/config/app_theme.dart';
import 'package:blukios_marketplace/features/transaction/models/transaction_model.dart';
import 'package:blukios_marketplace/features/transaction/viewmodels/transaction_viewmodel.dart';
import 'package:blukios_marketplace/shared/widgets/app_scaffold.dart';

// Limits mirror api-blue ComplaintController::store.
const maxComplaintPhotos = 3;
const _maxPhotoBytes = 2 * 1024 * 1024;
const _photoExtensions = {'jpg', 'jpeg', 'png', 'webp'};

String? complaintReasonError(String? reason) =>
    TransactionComplaint.reasons.containsKey(reason) ? null : 'Pilih alasan komplain';

String? complaintDescriptionError(String text) {
  final length = text.trim().length;
  if (length < 10) return 'Keterangan minimal 10 karakter';
  if (length > 1000) return 'Keterangan maksimal 1000 karakter';
  return null;
}

/// Checks [picked] before it joins the [existing] photos already chosen.
Future<String?> complaintPhotosError(int existing, List<XFile> picked) async {
  if (existing + picked.length > maxComplaintPhotos) {
    return 'Maksimal $maxComplaintPhotos foto';
  }
  for (final photo in picked) {
    final name = photo.name.isNotEmpty ? photo.name : photo.path;
    if (!_photoExtensions.contains(name.split('.').last.toLowerCase())) {
      return 'Foto harus berformat JPG, PNG, atau WEBP';
    }
    if (await photo.length() > _maxPhotoBytes) return 'Ukuran tiap foto maksimal 2 MB';
  }
  return null;
}

/// Buyer files a complaint on a paid, delivering order. Pops `true` once the
/// order has a complaint (filed now, or by an earlier attempt whose response
/// was lost).
class ComplaintFormScreen extends ConsumerStatefulWidget {
  final String transactionId;

  /// Tests pass a fake; the app uses the real gallery picker.
  final ImagePicker? picker;

  const ComplaintFormScreen({super.key, required this.transactionId, this.picker});

  @override
  ConsumerState<ComplaintFormScreen> createState() => _ComplaintFormScreenState();
}

class _ComplaintFormScreenState extends ConsumerState<ComplaintFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _description = TextEditingController();
  final List<XFile> _photos = [];
  String? _reason;
  String? _reasonError;
  String? _photoError;
  bool _sending = false;

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _addPhotos() async {
    final remaining = maxComplaintPhotos - _photos.length;
    if (remaining <= 0) return;
    final picker = widget.picker ?? ImagePicker();
    // image_picker before 1.2 throws on pickMultiImage(limit: 1).
    final picked = remaining == 1
        ? [
            if (await picker.pickImage(source: ImageSource.gallery, imageQuality: 85)
                case final photo?)
              photo,
          ]
        : await picker.pickMultiImage(imageQuality: 85, limit: remaining);
    if (picked.isEmpty || !mounted) return;
    final error = await complaintPhotosError(_photos.length, picked);
    if (!mounted) return;
    setState(() {
      _photoError = error;
      if (error == null) _photos.addAll(picked);
    });
  }

  Future<void> _submit() async {
    if (_sending) return;
    setState(() => _reasonError = complaintReasonError(_reason));
    final valid = _formKey.currentState!.validate();
    if (_reasonError != null || !valid) return;

    setState(() => _sending = true);
    final notifier = ref.read(transactionProvider.notifier);
    final error = await notifier.createComplaint(
      widget.transactionId,
      reason: _reason!,
      description: _description.text.trim(),
      photoPaths: [for (final photo in _photos) photo.path],
    );
    if (!mounted) return;
    setState(() => _sending = false);

    final messenger = ScaffoldMessenger.of(context);
    if (error == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Komplain terkirim, penjual punya 2 hari untuk menanggapi')),
      );
      context.pop(true);
      return;
    }
    messenger.showSnackBar(SnackBar(content: Text(error), backgroundColor: AppTheme.error));
    // The order was re-read: a complaint there means an earlier try landed.
    final filed = ref
        .read(transactionProvider)
        .transactions
        .any((t) => t.id == widget.transactionId && t.complaint != null);
    if (filed) context.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary;

    return AppScaffold(
      title: 'Ajukan Komplain',
      body: Form(
        key: _formKey,
        // Not a ListView: its index-matched children would drop the
        // description field's state (and its error) when an error line
        // appears above it.
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.spacingLG),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Ada masalah dengan pesanan ini? Ajukan komplain sebelum menandai pesanan diterima. '
                'Penjual punya 2 hari untuk menanggapi.',
                style: AppTheme.bodySm.copyWith(color: muted),
              ),
              const SizedBox(height: AppTheme.spacingLG),
              Text('Alasan', style: AppTheme.labelMd),
              const SizedBox(height: AppTheme.spacingSM),
              Wrap(
                spacing: AppTheme.spacingSM,
                runSpacing: AppTheme.spacingSM,
                children: [
                  for (final MapEntry(key: value, value: label)
                      in TransactionComplaint.reasons.entries)
                    ChoiceChip(
                      label: Text(label),
                      selected: _reason == value,
                      onSelected: _sending
                          ? null
                          : (_) => setState(() {
                                _reason = value;
                                _reasonError = null;
                              }),
                    ),
                ],
              ),
              if (_reasonError != null) ...[
                const SizedBox(height: AppTheme.spacingXS),
                Text(_reasonError!, style: AppTheme.bodySm.copyWith(color: AppTheme.error)),
              ],
              const SizedBox(height: AppTheme.spacingLG),
              TextFormField(
                controller: _description,
                enabled: !_sending,
                maxLength: 1000,
                minLines: 4,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: 'Keterangan',
                  hintText: 'Jelaskan masalahnya, minimal 10 karakter',
                  alignLabelWithHint: true,
                ),
                validator: (value) => complaintDescriptionError(value ?? ''),
              ),
              const SizedBox(height: AppTheme.spacingMD),
              Text('Foto bukti (opsional)', style: AppTheme.labelMd),
              const SizedBox(height: AppTheme.spacingXS),
              Text(
                _photos.length >= maxComplaintPhotos
                    ? 'Maksimal $maxComplaintPhotos foto. Hapus salah satu untuk menggantinya.'
                    : 'Maksimal $maxComplaintPhotos foto JPG, PNG, atau WEBP, masing-masing 2 MB.',
                style: AppTheme.bodySm.copyWith(color: muted),
              ),
              const SizedBox(height: AppTheme.spacingSM),
              Wrap(
                spacing: AppTheme.spacingSM,
                runSpacing: AppTheme.spacingSM,
                children: [
                  for (final (i, photo) in _photos.indexed)
                    SizedBox(
                      width: 88,
                      height: 88,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                            child: Image.file(
                              File(photo.path),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const Center(child: Icon(Icons.broken_image_outlined)),
                            ),
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: IconButton(
                              tooltip: 'Hapus foto ${i + 1}',
                              visualDensity: VisualDensity.compact,
                              style: IconButton.styleFrom(backgroundColor: Colors.black54),
                              onPressed: _sending
                                  ? null
                                  : () => setState(() {
                                        _photos.removeAt(i);
                                        _photoError = null;
                                      }),
                              icon: const Icon(Icons.close, size: 16, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_photos.length < maxComplaintPhotos)
                    SizedBox(
                      width: 88,
                      height: 88,
                      child: OutlinedButton(
                        onPressed: _sending ? null : _addPhotos,
                        style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined),
                            Text('Tambah', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              if (_photoError != null) ...[
                const SizedBox(height: AppTheme.spacingXS),
                Text(_photoError!, style: AppTheme.bodySm.copyWith(color: AppTheme.error)),
              ],
              const SizedBox(height: AppTheme.spacingXL),
              ElevatedButton(
                onPressed: _sending ? null : _submit,
                child: Text(_sending ? 'Mengirim...' : 'Kirim Komplain'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
