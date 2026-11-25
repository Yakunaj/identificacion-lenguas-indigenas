import 'package:flutter/material.dart';

///  blanco Color.fromARGB(255, 245, 245, 245);
/// dorado Color.fromARGB(255, 199, 147, 22);
///  azul Color.fromARGB(255, 0, 46, 95);
///
class TemaColorEstructura {
  static const Color _seedColor = Color.fromARGB(255, 245, 245, 245);
  static const Color _secondaryColor = Color.fromARGB(255, 199, 147, 22);
  static const Color _tertiaryColor = Color.fromARGB(255, 0, 46, 95);
  static ThemeData _buildTheme(ColorScheme colorScheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.secondary.withAlpha(150),
        indicatorColor: colorScheme.secondary,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              color: colorScheme.tertiary,
              fontWeight: FontWeight.bold,
            );
          }
          return TextStyle(color: colorScheme.tertiary);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: colorScheme.tertiary);
          }
          return IconThemeData(color: colorScheme.tertiary.withAlpha(150));
        }),
      ),

      dividerTheme: DividerThemeData(color: colorScheme.secondary),

      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.tertiary,
        foregroundColor: colorScheme.secondary,
        iconTheme: IconThemeData(color: colorScheme.onSecondary),
      ),

      scaffoldBackgroundColor: colorScheme.primary,

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.tertiary,
        circularTrackColor: colorScheme.secondary,
      ),

      listTileTheme: ListTileThemeData(
        tileColor: colorScheme.primary,
        selectedColor: colorScheme.tertiary,
        selectedTileColor: colorScheme.secondary.withAlpha(150),
        titleTextStyle: TextStyle(color: colorScheme.tertiary),
        subtitleTextStyle: TextStyle(
          color: colorScheme.tertiary.withAlpha(150),
        ),
      ),

      textTheme: TextTheme(
        displayLarge: TextStyle(color: colorScheme.tertiary),
        displayMedium: TextStyle(color: colorScheme.tertiary),
        displaySmall: TextStyle(color: colorScheme.tertiary),
        headlineLarge: TextStyle(color: colorScheme.tertiary),
        headlineMedium: TextStyle(color: colorScheme.tertiary),
        headlineSmall: TextStyle(color: colorScheme.tertiary),
        bodyLarge: TextStyle(color: colorScheme.tertiary),
        bodyMedium: TextStyle(color: colorScheme.tertiary),
        bodySmall: TextStyle(color: colorScheme.tertiary),
        titleLarge: TextStyle(color: colorScheme.tertiary),
        titleMedium: TextStyle(color: colorScheme.tertiary),
        titleSmall: TextStyle(color: colorScheme.tertiary),
        labelLarge: TextStyle(color: colorScheme.tertiary),
      ),
    );
  }

  static ThemeData get lightTheme {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: _seedColor,
          brightness: Brightness.light,
        ).copyWith(
          primary: _seedColor,
          secondary: _secondaryColor,
          tertiary: _tertiaryColor,
        );
    return _buildTheme(colorScheme);
  }

  static ThemeData get darkTheme {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: _seedColor,
          brightness: Brightness.dark,
        ).copyWith(
          primary: _seedColor,
          secondary: _secondaryColor,
          tertiary: _tertiaryColor,
        );
    return _buildTheme(colorScheme);
  }
}
