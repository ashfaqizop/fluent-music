import 'package:app/design_system/density/density_tokens.dart';
import 'package:app/design_system/motion/motion_tokens.dart';
import 'package:app/design_system/settings/appearance_settings.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DensityTokens', () {
    test('forMode resolves the matching preset for each mode', () {
      expect(DensityTokens.forMode(DensityMode.hybrid), DensityTokens.hybrid);
      expect(
        DensityTokens.forMode(DensityMode.spacious),
        DensityTokens.spacious,
      );
      expect(DensityTokens.forMode(DensityMode.compact), DensityTokens.compact);
    });

    test('compact is denser than spacious on every metric (§11.6)', () {
      expect(
        DensityTokens.compact.itemSpacing,
        lessThan(DensityTokens.spacious.itemSpacing),
      );
      expect(
        DensityTokens.compact.listTileHeight,
        lessThan(DensityTokens.spacious.listTileHeight),
      );
      expect(
        DensityTokens.compact.coverArtSize,
        lessThan(DensityTokens.spacious.coverArtSize),
      );
    });
  });

  group('MotionTokens', () {
    testWidgets('collapses every duration to zero when the OS requests reduced '
        'motion, even if the user setting is full (§11.7)', (tester) async {
      late MotionTokens tokens;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Builder(
            builder: (context) {
              tokens = MotionTokens.resolve(
                context,
                const AppearanceSettings(motionLevel: MotionLevel.full),
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(tokens.reduced, isTrue);
      expect(tokens.fast, Duration.zero);
      expect(tokens.standard, Duration.zero);
      expect(tokens.slow, Duration.zero);
    });

    testWidgets(
      'collapses to zero when the user setting requests reduced motion, '
      'even if the OS does not (§11.7)',
      (tester) async {
        late MotionTokens tokens;
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(),
            child: Builder(
              builder: (context) {
                tokens = MotionTokens.resolve(
                  context,
                  const AppearanceSettings(motionLevel: MotionLevel.reduced),
                );
                return const SizedBox.shrink();
              },
            ),
          ),
        );

        expect(tokens.reduced, isTrue);
        expect(tokens.standard, Duration.zero);
      },
    );

    testWidgets('uses real durations when nothing requests reduced motion', (
      tester,
    ) async {
      late MotionTokens tokens;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(),
          child: Builder(
            builder: (context) {
              tokens = MotionTokens.resolve(
                context,
                const AppearanceSettings(motionLevel: MotionLevel.full),
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(tokens.reduced, isFalse);
      expect(tokens.standard, greaterThan(Duration.zero));
    });
  });
}
