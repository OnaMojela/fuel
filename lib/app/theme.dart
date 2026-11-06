import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens lifted from intl.nothing.tech: light-grey canvas with a dot
/// grid, frosted white panels, solid black CTAs, dot-matrix + mono type.
@immutable
class NothingTokens extends ThemeExtension<NothingTokens> {
  const NothingTokens({
    required this.canvas,
    required this.ink,
    required this.inkMuted,
    required this.glass,
    required this.tint,
    required this.track,
    required this.dot,
    required this.cta,
    required this.onCta,
    required this.accent,
    this.accentOn = false,
    this.glyphRings = false,
  });

  final Color canvas; // page background
  final Color ink; // primary text
  final Color inkMuted; // secondary text
  final Color glass; // frosted panel fill
  final Color tint; // subtle tiles / selectors
  final Color track; // empty ring / bar track
  final Color dot; // background dot grid
  final Color cta; // black button
  final Color onCta;
  final Color accent; // Nothing red: "over goal", plus subtle details when [accentOn]
  final bool accentOn; // user opted into Nothing-red details
  final bool glyphRings; // rings drawn as dotted circles

  /// Colour for an accent-able detail: red when the user turned accents on, else [fallback].
  Color detail(Color fallback) => accentOn ? accent : fallback;

  static const light = NothingTokens(
    canvas: Color(0xFFF4F4F4),
    ink: Color(0xFF000000),
    inkMuted: Color(0xFF595A5A),
    glass: Color(0xCCFFFFFF),
    tint: Color(0x0D595A5A),
    track: Color(0xFFE2E2E2),
    dot: Color(0xFFD4D4D4),
    cta: Color(0xFF040404),
    onCta: Color(0xFFFFFFFF),
    accent: Color(0xFFD71921),
  );

  static const dark = NothingTokens(
    canvas: Color(0xFF000000),
    ink: Color(0xFFFFFFFF),
    inkMuted: Color(0xFF9A9A9A),
    glass: Color(0xCC1A1A1A),
    tint: Color(0x0DFFFFFF),
    track: Color(0xFF2A2A2A),
    dot: Color(0xFF262626),
    cta: Color(0xFFFFFFFF),
    onCta: Color(0xFF000000),
    accent: Color(0xFFD71921),
  );

  @override
  NothingTokens copyWith({bool? accentOn, bool? glyphRings}) => NothingTokens(
        canvas: canvas,
        ink: ink,
        inkMuted: inkMuted,
        glass: glass,
        tint: tint,
        track: track,
        dot: dot,
        cta: cta,
        onCta: onCta,
        accent: accent,
        accentOn: accentOn ?? this.accentOn,
        glyphRings: glyphRings ?? this.glyphRings,
      );

  @override
  NothingTokens lerp(NothingTokens? other, double t) =>
      t < 0.5 ? this : (other ?? this);
}

extension TokensX on BuildContext {
  NothingTokens get tk => Theme.of(this).extension<NothingTokens>()!;
}

/// Type roles: dot-matrix display, uppercase mono labels, serif captions.
class NType {
  // Resolved once: GoogleFonts.x() does a font lookup per call, and screens
  // build hundreds of styles. Bold mono is its own font file, so it gets its
  // own base (copyWith(fontWeight) would only fake-bold the regular file).
  static final _dot = GoogleFonts.doto(fontWeight: FontWeight.w800, height: 1);
  static final _mono = GoogleFonts.spaceMono(letterSpacing: 1.1);
  static final _monoBold = GoogleFonts.spaceMono(fontWeight: FontWeight.w700, letterSpacing: 1.1);
  static final _serif = GoogleFonts.instrumentSerif(height: 1.2);

  static TextStyle dot(double size, Color color) => _dot.copyWith(fontSize: size, color: color);

  static TextStyle mono(double size, Color color, {FontWeight weight = FontWeight.w400}) =>
      (weight.value >= 600 ? _monoBold : _mono).copyWith(fontSize: size, color: color);

  static TextStyle serif(double size, Color color) => _serif.copyWith(fontSize: size, color: color);
}

ThemeData buildTheme(Brightness b, {bool accentOn = false, bool glyphRings = false}) {
  final t = (b == Brightness.light ? NothingTokens.light : NothingTokens.dark)
      .copyWith(accentOn: accentOn, glyphRings: glyphRings);
  final base = ThemeData(brightness: b, useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: t.canvas,
    colorScheme: ColorScheme.fromSeed(
      seedColor: t.ink,
      brightness: b,
      surface: t.canvas,
      primary: t.cta,
      onPrimary: t.onCta,
    ),
    textTheme: GoogleFonts.spaceMonoTextTheme(base.textTheme).apply(bodyColor: t.ink, displayColor: t.ink),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      foregroundColor: t.ink,
      centerTitle: true,
      titleTextStyle: NType.mono(13, t.ink, weight: FontWeight.w700),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: t.glass,
      hintStyle: NType.mono(12, t.inkMuted),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: t.cta,
      contentTextStyle: NType.mono(12, t.onCta),
      behavior: SnackBarBehavior.floating,
    ),
    dividerColor: t.track,
    extensions: [t],
  );
}
