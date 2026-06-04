import 'package:flutter/widgets.dart';

class BananRadii {
  const BananRadii._();

  // Softer, pillowy corners for a calm kissaten feel.
  static const double xs = 6;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 22;
  static const double xl = 30;
  static const double pill = 999;

  static const BorderRadius rxs = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius rsm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius rmd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius rlg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius rxl = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius rPill = BorderRadius.all(Radius.circular(pill));
}
