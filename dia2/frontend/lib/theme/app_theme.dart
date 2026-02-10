import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const Color background = Color(0xFFFDF5E6); // Cream
  static const Color surface = Color(0xFF121212); // Metallic Black
  static const Color surfaceLight = Color(0xFF1E1E1E); // Lighter Metallic
  static const Color border = Color(0xFF2C2C2C); // Metallic Border
  
  static const Color accent = Color(0xFF121212); 
  static const Color textOnBackground = Color(0xFF121212);
  static const Color textOnSurface = Color(0xFFFDF5E6);
  static const Color textOnCreamBackground = Color(0xFF121212);
  static const Color darkMetallicText = Color(0xFF2C2C2C);
  static const Color black = Color(0xFF121212);

  // Purple accent for CTA buttons and highlights inside dark containers
  static const Color purple = Color(0xFFC084FC);       // Main purple accent
  static const Color purpleLight = Color(0xFFD8B4FE);   // Lighter purple
  static const Color purpleDark = Color(0xFFA855F7);     // Deeper purple
  static const Color purpleBg = Color(0x1AC084FC);       // Subtle purple bg (10% opacity)

  static const LinearGradient purpleGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFA855F7),
      Color(0xFFC084FC),
      Color(0xFFD8B4FE),
    ],
  );

  static const LinearGradient metallicGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF1A1A1A),
      Color(0xFF000000),
      Color(0xFF2C2C2C),
    ],
    stops: [0.0, 0.5, 1.0],
  );

  static const Color silver100 = Color(0xFFF1F5F9);
  static const Color silver200 = Color(0xFFE2E8F0);
  static const Color silver300 = Color(0xFFCBD5E1);
  static const Color silver400 = Color(0xFF94A3B8);
  static const Color silver500 = Color(0xFF64748B);
  static const Color silver600 = Color(0xFF475569);
  
  // Legacy aliases for compatibility
  static const Color cardBackground = surface;
  static const Color cardBackgroundBright = surfaceLight;
  static const Color cardBorder = border;
  static const Color cardBorderBright = Color(0x26FFFFFF);

  static const LinearGradient silverGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF121212),
      Color(0xFF454545),
    ],
  );
}

class AppTheme {
  static ThemeData get theme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.light(
        primary: AppColors.surface,
        secondary: AppColors.surfaceLight,
        surface: AppColors.surface,
        onSurface: AppColors.textOnSurface,
      ),
      textTheme: GoogleFonts.plusJakartaSansTextTheme().copyWith(
        displayLarge: GoogleFonts.plusJakartaSans(
          color: AppColors.textOnBackground,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: GoogleFonts.plusJakartaSans(
          color: AppColors.textOnBackground,
          fontWeight: FontWeight.bold,
        ),
        bodyLarge: GoogleFonts.plusJakartaSans(
          color: AppColors.textOnBackground,
        ),
        bodyMedium: GoogleFonts.plusJakartaSans(
          color: AppColors.textOnBackground,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
        elevation: 8,
      ),
      useMaterial3: true,
    );
  }
}

class AppToast {
  static void show(BuildContext context, String message, {bool isError = true}) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 20,
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutBack,
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, -20 * (1 - value)),
                child: Opacity(
                  opacity: value.clamp(0.0, 1.0),
                  child: child,
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isError ? const Color(0xFF1E1E1E) : AppColors.background,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isError ? Colors.redAccent.withOpacity(0.5) : AppColors.border.withOpacity(0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isError ? Colors.redAccent.withOpacity(0.1) : AppColors.purple.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isError ? Icons.error_outline : Icons.check_circle_outline,
                      color: isError ? Colors.redAccent : AppColors.purple,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      message,
                      style: TextStyle(
                        color: isError ? AppColors.textOnSurface : AppColors.textOnBackground,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 3), () {
      entry.remove();
    });
  }
}
