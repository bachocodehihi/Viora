import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  static const String fontFamily = 'Inter';
  static const List<String> fontFallback = ['Inter', 'Roboto', 'sans-serif'];

  static TextTheme _buildTextTheme(Brightness brightness) {
    final base = brightness == Brightness.light
        ? ThemeData.light().textTheme
        : ThemeData.dark().textTheme;

    return base.copyWith(
      headlineMedium: TextStyle(
        color: brightness == Brightness.light ? AppColors.black : AppColors.white,
        fontWeight: FontWeight.bold,
      ),
      bodyLarge: TextStyle(
        color: brightness == Brightness.light ? const Color(0xFF2D3142) : const Color(0xFFE4E6EB),
      ),
      bodyMedium: TextStyle(
        color: brightness == Brightness.light ? const Color(0xFF4F5D75) : const Color(0xB3E4E6EB),
      ),
    ).apply(
      fontFamily: fontFamily,
      fontFamilyFallback: fontFallback,
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      fontFamilyFallback: fontFallback,
      brightness: Brightness.light,
      primaryColor: AppColors.blue,
      colorScheme: const ColorScheme.light(
        primary: AppColors.blue,
        secondary: AppColors.teal,
        surface: AppColors.white,
        onSurface: AppColors.black,
        error: AppColors.red,
      ),
      scaffoldBackgroundColor: const Color(0xFFF5F7FB),
      tooltipTheme: const TooltipThemeData(
        triggerMode: TooltipTriggerMode.manual,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.black),
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: AppColors.black,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      textTheme: _buildTextTheme(Brightness.light),
      primaryTextTheme: ThemeData.light().primaryTextTheme.apply(
        fontFamily: fontFamily,
        fontFamilyFallback: fontFallback,
      ),
      listTileTheme: const ListTileThemeData(
        titleTextStyle: TextStyle(fontFamily: fontFamily),
        subtitleTextStyle: TextStyle(fontFamily: fontFamily),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08), width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.blue, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.red, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.red, width: 1.5),
        ),
        prefixIconColor: AppColors.gray,
        suffixIconColor: AppColors.gray,
        labelStyle: const TextStyle(color: AppColors.gray),
        hintStyle: const TextStyle(
          color: AppColors.gray,
          fontSize: 14,
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      fontFamilyFallback: fontFallback,
      brightness: Brightness.dark,
      primaryColor: AppColors.blue,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.blue,
        secondary: AppColors.teal,
        surface: Color(0xFF1E1E2C),
        onSurface: AppColors.white,
        error: AppColors.red,
      ),
      scaffoldBackgroundColor: const Color(0xFF0F0E17),
      tooltipTheme: const TooltipThemeData(
        triggerMode: TooltipTriggerMode.manual,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.white),
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: AppColors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      textTheme: _buildTextTheme(Brightness.dark),
      primaryTextTheme: ThemeData.dark().primaryTextTheme.apply(
        fontFamily: fontFamily,
        fontFamilyFallback: fontFallback,
      ),
      listTileTheme: const ListTileThemeData(
        titleTextStyle: TextStyle(fontFamily: fontFamily),
        subtitleTextStyle: TextStyle(fontFamily: fontFamily),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1E1E2C),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.12),
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.12),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.blue, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.red, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.red, width: 1.5),
        ),
        prefixIconColor: Colors.white.withValues(alpha: 0.5),
        suffixIconColor: Colors.white.withValues(alpha: 0.5),
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
        hintStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.4),
          fontSize: 14,
        ),
      ),
    );
  }
}
