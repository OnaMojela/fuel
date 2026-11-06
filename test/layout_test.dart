import 'package:calorie_tracker/app/theme.dart';
import 'package:calorie_tracker/features/more/more_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// Renders screens at real phone sizes and font scales; any RenderFlex
/// overflow (the yellow/black stripes) fails the test.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  // Guard that this harness really detects the bug: the previous More-grid
  // cell (fixed 0.82 aspect ratio, square tile + 2-line caption) must overflow.
  testWidgets('harness catches the old More-grid overflow', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: GridView.count(
          crossAxisCount: 3,
          crossAxisSpacing: 12,
          childAspectRatio: 0.82,
          padding: const EdgeInsets.all(16),
          children: [
            for (var i = 0; i < 3; i++)
              Column(children: [
                const AspectRatio(aspectRatio: 1, child: Placeholder()),
                const SizedBox(height: 6),
                Text('Workout routines', style: NType.serif(15, Colors.black), maxLines: 2),
              ]),
          ],
        ),
      ),
    ));
    // One "RenderFlex overflowed" per cell; Flutter reports several as a summary.
    expect(tester.takeException(), isNotNull);
  });

  for (final width in [320.0, 360.0, 390.0, 430.0]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('More grid has no overflow at ${width}dp, text ×$scale', (tester) async {
        tester.view.physicalSize = Size(width * 3, 2400);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(MaterialApp(
          theme: buildTheme(Brightness.dark),
          home: MediaQuery(
            data: MediaQueryData(size: Size(width, 800), textScaler: TextScaler.linear(scale)),
            child: const MoreScreen(),
          ),
        ));
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.text('Weekly report'), findsOneWidget);
        expect(find.text('Friends'), findsNothing); // placeholders removed
      });
    }
  }
}
