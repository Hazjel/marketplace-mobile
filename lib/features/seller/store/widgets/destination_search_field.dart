import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blukios_marketplace/config/app_theme.dart';
import 'package:blukios_marketplace/core/providers.dart';
import 'package:blukios_marketplace/features/shipment/models/shipment_destination_model.dart';
import 'package:blukios_marketplace/shared/widgets/app_icon.dart';

/// Searches `/shipment/destination` and lets the user pick a Komerce
/// destination (id + city name + postal code).
///
/// Mirrors `features/address/screens/address_form_screen.dart`'s
/// destination-search UX exactly, since the store's `address_id` field
/// feeds the same shipping-cost calculation as a buyer address does — see
/// `SellerStoreModel.addressId` for why a free-text field would break
/// shipping for this store's buyers.
class DestinationSearchField extends ConsumerStatefulWidget {
  final TextEditingController controller;
  final String label;
  final ValueChanged<ShipmentDestinationModel> onSelected;

  const DestinationSearchField({
    super.key,
    required this.controller,
    required this.onSelected,
    this.label = 'Cari Kecamatan / Kota',
  });

  @override
  ConsumerState<DestinationSearchField> createState() => _DestinationSearchFieldState();
}

class _DestinationSearchFieldState extends ConsumerState<DestinationSearchField> {
  List<ShipmentDestinationModel> _options = [];
  bool _showOptions = false;
  bool _searching = false;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < 2) {
      setState(() {
        _options = [];
        _showOptions = false;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      setState(() => _searching = true);
      try {
        final results =
            await ref.read(shipmentRepositoryProvider).searchDestination(value.trim());
        if (!mounted) return;
        setState(() {
          _options = results;
          _showOptions = true;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() => _options = []);
      } finally {
        if (mounted) setState(() => _searching = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: widget.controller,
          decoration: InputDecoration(
            labelText: widget.label,
            suffixIcon: _searching
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : const AppIcon(AppIcons.search, size: AppIconSize.md),
          ),
          onChanged: _onChanged,
        ),
        if (_showOptions && _options.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.border),
              borderRadius: BorderRadius.circular(8),
            ),
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _options.length,
              itemBuilder: (context, index) {
                final option = _options[index];
                return ListTile(
                  dense: true,
                  title: Text(option.label, style: AppTheme.bodySm),
                  onTap: () {
                    widget.controller.text = option.label;
                    setState(() => _showOptions = false);
                    widget.onSelected(option);
                  },
                );
              },
            ),
          ),
      ],
    );
  }
}
