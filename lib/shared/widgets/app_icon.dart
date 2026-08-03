import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Icon asset paths. Every icon in the app comes from here — no raw
/// asset strings at call sites, and no `Icons.*` (Material font glyphs
/// can't be brand-styled and don't share Lucide's 2px stroke).
class AppIcons {
  const AppIcons._();

  static const String _base = 'assets/icons';

  // Navigation — each tab has an outline (inactive) and filled (active) pair
  static const String home = '$_base/house.svg';
  static const String homeFilled = '$_base/house_filled.svg';
  static const String category = '$_base/grid.svg';
  static const String categoryFilled = '$_base/grid_filled.svg';
  static const String transaction = '$_base/receipt.svg';
  static const String transactionFilled = '$_base/receipt_filled.svg';
  static const String heart = '$_base/heart.svg';
  static const String heartFilled = '$_base/heart_filled.svg';
  static const String user = '$_base/user.svg';
  static const String userFilled = '$_base/user_filled.svg';

  // Commerce
  static const String cart = '$_base/shopping_cart.svg';
  static const String store = '$_base/store.svg';
  static const String package = '$_base/package.svg';
  static const String tag = '$_base/tag.svg';
  static const String wallet = '$_base/wallet.svg';
  static const String truck = '$_base/truck.svg';

  // Search & filter
  static const String search = '$_base/search.svg';
  static const String searchEmpty = '$_base/search_x.svg';
  static const String filter = '$_base/sliders.svg';
  static const String filterOff = '$_base/filter_x.svg';

  // Form & auth
  static const String mail = '$_base/mail.svg';
  static const String lock = '$_base/lock.svg';
  static const String phone = '$_base/phone.svg';
  static const String eye = '$_base/eye.svg';
  static const String eyeOff = '$_base/eye_off.svg';

  // Status & feedback
  static const String alert = '$_base/alert_circle.svg';
  static const String check = '$_base/check_circle.svg';
  static const String refresh = '$_base/refresh.svg';
  static const String inbox = '$_base/inbox.svg';

  // Media
  static const String image = '$_base/image.svg';
  static const String imageOff = '$_base/image_off.svg';

  // Actions
  static const String plus = '$_base/plus.svg';
  static const String close = '$_base/x.svg';
  static const String trash = '$_base/trash.svg';
  static const String chevronRight = '$_base/chevron_right.svg';
  static const String chevronLeft = '$_base/chevron_left.svg';
  static const String logout = '$_base/log_out.svg';
  static const String settings = '$_base/settings.svg';

  // Location & misc
  static const String mapPin = '$_base/map_pin.svg';
  static const String mapPinOff = '$_base/map_pin_off.svg';
  static const String star = '$_base/star.svg';
  static const String starFilled = '$_base/star_filled.svg';
  static const String layers = '$_base/layers.svg';
  static const String bell = '$_base/bell.svg';
  static const String shield = '$_base/shield.svg';
}

/// Brand assets — full-color, never tinted.
class BrandAssets {
  const BrandAssets._();

  static const String google = 'assets/brand/google.svg';
}

/// Standard icon sizes. Keeping these tokenized stops the codebase
/// drifting into arbitrary 18/22/26px values.
abstract final class AppIconSize {
  static const double sm = 16;
  static const double md = 20;
  static const double lg = 24;
  static const double xl = 32;
}

/// Renders an SVG icon tinted to [color].
///
/// Pass [semanticsLabel] whenever the icon is the only content of a
/// button — otherwise screen readers announce nothing.
class AppIcon extends StatelessWidget {
  final String asset;
  final double size;
  final Color? color;
  final String? semanticsLabel;

  const AppIcon(
    this.asset, {
    super.key,
    this.size = AppIconSize.lg,
    this.color,
    this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) {
    final resolved = color ?? IconTheme.of(context).color;

    return SvgPicture.asset(
      asset,
      width: size,
      height: size,
      semanticsLabel: semanticsLabel,
      colorFilter:
          resolved == null ? null : ColorFilter.mode(resolved, BlendMode.srcIn),
    );
  }
}

/// Icon sized and padded to sit correctly as a `TextField.prefixIcon`.
///
/// `prefixIcon` gives its child the full field height, so a bare
/// [AppIcon] would stretch; the padding pins it to icon size instead.
class FieldIcon extends StatelessWidget {
  final String asset;

  const FieldIcon(this.asset, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: AppIcon(asset, size: AppIconSize.md),
    );
  }
}

/// Full-color brand mark — deliberately has no [ColorFilter], so the
/// Google "G" keeps its four official colors.
class BrandIcon extends StatelessWidget {
  final String asset;
  final double size;
  final String? semanticsLabel;

  const BrandIcon(
    this.asset, {
    super.key,
    this.size = AppIconSize.md,
    this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      asset,
      width: size,
      height: size,
      semanticsLabel: semanticsLabel,
    );
  }
}
