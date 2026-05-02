import 'package:flutter/material.dart';

class AppRadius {
  AppRadius._();

  static const double large = 32.0;
  static const double medium = 24.0;
  static const double small = 16.0;
  static const double extraSmall = 8.0;
  static const double pill = 9999.0;

  static const BorderRadius circularLarge = BorderRadius.all(Radius.circular(large));
  static const BorderRadius circularMedium = BorderRadius.all(Radius.circular(medium));
  static const BorderRadius circularSmall = BorderRadius.all(Radius.circular(small));
  static const BorderRadius circularExtraSmall = BorderRadius.all(Radius.circular(extraSmall));
  static const BorderRadius circularPill = BorderRadius.all(Radius.circular(pill));
}
