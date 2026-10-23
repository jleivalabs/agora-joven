import 'package:flutter/material.dart';

/// Identidad visual de Ágora Joven: colores, tipografía y espaciado comunes.
class AppColors {
  AppColors._();

  static const Color primario = Color(0xFF1F4E79); // azul ágora
  static const Color acento = Color(0xFFE07A2F); // naranja participación
  static const Color fondo = Color(0xFFF6F7FB);
}

class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double s = 8;
  static const double m = 16;
  static const double l = 24;
  static const double xl = 32;
}

class AppTheme {
  AppTheme._();

  static ThemeData get claro {
    final esquema = ColorScheme.fromSeed(
      seedColor: AppColors.primario,
      primary: AppColors.primario,
      secondary: AppColors.acento,
      surface: Colors.white,
    );

    return ThemeData(
      colorScheme: esquema,
      scaffoldBackgroundColor: AppColors.fondo,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primario,
        foregroundColor: Colors.white,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: esquema.outlineVariant),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.acento,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.l,
            vertical: AppSpacing.m,
          ),
        ),
      ),
    );
  }
}
