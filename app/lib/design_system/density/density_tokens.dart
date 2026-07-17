import 'package:app/design_system/settings/appearance_settings.dart';
import 'package:app/design_system/settings/appearance_settings_controller.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Spacing/sizing constants for one [DensityMode] (Masterdoc §11.6).
final class DensityTokens {
  const DensityTokens._({
    required this.pagePadding,
    required this.itemSpacing,
    required this.listTileHeight,
    required this.cardRadius,
    required this.coverArtSize,
  });

  /// Padding around a screen's main content.
  final EdgeInsets pagePadding;

  /// Vertical spacing between stacked items (list rows, cards).
  final double itemSpacing;

  /// Height of a single-line list row (queue, search results).
  final double listTileHeight;

  /// Corner radius for cards/surfaces.
  final double cardRadius;

  /// Now-playing-bar cover art size.
  final double coverArtSize;

  /// Balanced spacing — Masterdoc §11.6's default.
  static const hybrid = DensityTokens._(
    pagePadding: EdgeInsets.all(20),
    itemSpacing: 12,
    listTileHeight: 56,
    cardRadius: 12,
    coverArtSize: 48,
  );

  /// Apple-Music-style spacious layout.
  static const spacious = DensityTokens._(
    pagePadding: EdgeInsets.all(28),
    itemSpacing: 18,
    listTileHeight: 68,
    cardRadius: 16,
    coverArtSize: 56,
  );

  /// Power-user compact/dense layout.
  static const compact = DensityTokens._(
    pagePadding: EdgeInsets.all(12),
    itemSpacing: 6,
    listTileHeight: 40,
    cardRadius: 8,
    coverArtSize: 40,
  );

  /// Resolves the tokens for [mode].
  static DensityTokens forMode(DensityMode mode) => switch (mode) {
    DensityMode.hybrid => hybrid,
    DensityMode.spacious => spacious,
    DensityMode.compact => compact,
  };
}

/// The [DensityTokens] for the live [AppearanceSettings.densityMode].
final densityTokensProvider = Provider<DensityTokens>(
  (ref) => DensityTokens.forMode(
    ref.watch(appearanceSettingsProvider.select((s) => s.densityMode)),
  ),
);
