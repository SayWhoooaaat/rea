import 'package:flutter/material.dart';

class MaterialTheme {
  static ColorScheme darkScheme() {
    return const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(4293910742), //Color.fromARGB(255, 91, 69, 50),
      surfaceTint: Color(4294948730),
      onPrimary: Color(4283180800),
      primaryContainer: Color(4285217285),
      onPrimaryContainer: Color(4294958274),
      secondary: Color(4293116069),
      onSecondary: Color(4282461209),
      secondaryContainer: Color(4284105262),
      onSecondaryContainer: Color(4294958274),
      tertiary: Color(4294948005),
      onTertiary: Color(4283833876),
      tertiaryContainer: Color(4285740072),
      onTertiaryContainer: Color(4294957779),
      error: Color(4294948011),
      onError: Color(4285071365),
      errorContainer: Color(4287823882),
      onErrorContainer: Color(4294957782),
      surface: Color.fromARGB(255, 25, 23, 22),
      onSurface: Color(4293910742),
      onSurfaceVariant: Color(4292264886),
      outline: Color(4288581250),
      outlineVariant: Color(4283515963),
      shadow: Color(4278190080),
      scrim: Color(4278190080),
      inverseSurface: Color(4293910742),
      inversePrimary: Color.fromARGB(255, 49, 44, 40),
      primaryFixed: Color(4294958274),
      onPrimaryFixed: Color(4281210112),
      primaryFixedDim: Color(4294948730),
      onPrimaryFixedVariant: Color(4285217285),
      secondaryFixed: Color(4294958274),
      onSecondaryFixed: Color(4280948487),
      secondaryFixedDim: Color(4293116069),
      onSecondaryFixedVariant: Color(4284105262),
      tertiaryFixed: Color(4294957779),
      onTertiaryFixed: Color(4281993731),
      tertiaryFixedDim: Color(4294948005),
      onTertiaryFixedVariant: Color(4285740072),
      surfaceDim: Color.fromARGB(255, 51, 39, 28),
      surfaceBright: Color.fromARGB(255, 40, 36, 33),
      surfaceContainerLowest: Color(4279504136),
      surfaceContainerLow: Color(4280424980),
      surfaceContainer: Color(4280688152),
      surfaceContainerHigh: Color(4281411618),
      surfaceContainerHighest: Color(4282135340),
    );
  }

  static ThemeData dark() {
    return ThemeData(
      colorScheme: darkScheme(),
      useMaterial3: true,
    );
  }
}
