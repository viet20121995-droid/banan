import 'package:flutter/material.dart';

/// Brand palette — Banan Fukuoka Saigon. Refreshed to mirror the
/// banana-leaf logo: forest-green primary (logo background), gold trim,
/// crimson accent (logo segments) and a warm cream surface. The vibe is
/// Vietnamese Tết-festive on a kissaten quietness — bold red+green
/// accents over a cream canvas.
///
/// All foreground tones target AA contrast (≥ 4.5:1) on the cream
/// surface for body text and on the green primary for inverse text.
class BananColors {
  const BananColors._();

  // ── Primary — deep forest green from the logo backdrop ────────────────
  static const Color primary = Color(0xFF1E6A35);     // forest green
  static const Color primaryDark = Color(0xFF15522A); // for hover / pressed
  static const Color primaryLight = Color(0xFFB6D27A); // lime accent (leaf)

  // ── Accent — crimson red lifted from the logo's leaf segments.
  // Used for hero CTAs, sale badges, festive highlights. Keep small-area —
  // body text on red drops below 4.5:1 fast.
  static const Color accent = Color(0xFFC12B36);
  static const Color accentDark = Color(0xFF971F28);
  static const Color accentLight = Color(0xFFE8C0C4);

  // ── Gold — logo trim. Replaces the previous hojicha gold.
  static const Color gold = Color(0xFFD4B14B);
  static const Color goldLight = Color(0xFFEAD589);

  // ── Neutrals — soft PEACH backdrop (reverted from the tan/golden tone,
  // which read a bit dark). Warmer + lighter so the page feels airy under
  // the green+red brand accents.
  static const Color cream = Color(0xFFFCEBDF);       // peach-cream page backdrop
  static const Color surface = Color(0xFFFFF7F0);     // card surface (lighter peach)
  static const Color surfaceDim = Color(0xFFEEDFAE);  // kraft / dim surface
  static const Color cocoa = Color(0xFF2B2A22);       // sumi ink — body text
  static const Color cocoaSoft = Color(0xFF5E5848);   // secondary text
  static const Color outline = Color(0xFFD8C794);     // tracks cream

  // ── Neutrals — dark theme
  static const Color darkBg = Color(0xFF101810);
  static const Color darkSurface = Color(0xFF182018);
  static const Color darkSurfaceDim = Color(0xFF223024);
  static const Color darkInk = Color(0xFFF1F2E9);
  static const Color darkInkSoft = Color(0xFFAEB4A0);
  static const Color darkOutline = Color(0xFF2E3A2E);

  // ── Semantic — success stays in green family (slightly distinct from
  // brand primary so badges read as state, not brand). Danger pulls from
  // the same red lineage as `accent` for cohesion.
  static const Color success = Color(0xFF2E8B57);
  static const Color warning = Color(0xFFD08A1F);
  static const Color danger = Color(0xFFB3261E);
  static const Color info = Color(0xFF3F6FB0);
}
