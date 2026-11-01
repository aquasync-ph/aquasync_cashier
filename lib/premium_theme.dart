import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppColors {
  // Brand Colors
  static const Color navy = Color(0xFF075985);      // Deep Sea Navy
  static const Color primary = Color(0xFF0284C7);   // Electric Blue
  static const Color secondary = Color(0xFF0EA5E9); // Sky Cyan
  static const Color tertiary = Color(0xFF38BDF8);  // Light Water Blue

  // Background & Surface
  static const Color scaffold = Color(0xFFF4F9FC);  // Frost White
  static const Color surface = Colors.white;
  static const Color card = Colors.white;

  // Glassmorphism
  static Color glassBackground = Colors.white.withValues(alpha: 0.7);
  static Color glassBorder = Colors.white.withValues(alpha: 0.3);

  // Functional
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
  static const Color slate = Color(0xFF64748B);
  static const Color darkText = Color(0xFF0F172A);

  // Legacy compatibility (keeping names that might be used elsewhere)
  static const Color primaryNavy = navy;
  static const Color primaryBlue = primary;
  static const Color skyBlue = tertiary;
  static const Color electricCyan = primary;
  static const Color background = scaffold;
  static const Color border = Color(0xFFE2E8F0);

  static const LinearGradient cyanGradient = LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient premiumGradient = LinearGradient(
    colors: [navy, primary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient gcashGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF005CE6), Color(0xFF0088FF)],
  );
}

class AppGradients {
  static const LinearGradient ocean = AppColors.premiumGradient;
  static const LinearGradient electric = AppColors.cyanGradient;

  static const LinearGradient glass = LinearGradient(
    colors: [Colors.white54, Colors.white12],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppDesign {
  static const double cardRadius = 24.0;
  static const double buttonRadius = 16.0;
  static const double inputRadius = 16.0;

  static List<BoxShadow> premiumShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 20,
      offset: const Offset(0, 8),
      spreadRadius: 0,
    ),
    BoxShadow(
      color: AppColors.primary.withValues(alpha: 0.05),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> softShadow = premiumShadow;
  static List<BoxShadow> glowingShadow = [
    BoxShadow(
      color: AppColors.primary.withValues(alpha: 0.25),
      blurRadius: 20,
      spreadRadius: -2,
      offset: const Offset(0, 6),
    ),
  ];
  static List<BoxShadow> glassShadow = premiumShadow;

  static BoxDecoration glassDecoration({
    Color backgroundColor = Colors.white,
    Color borderColor = AppColors.border,
    double borderRadius = cardRadius,
  }) {
    return BoxDecoration(
      color: backgroundColor.withValues(alpha: 0.8),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.5),
      boxShadow: premiumShadow,
    );
  }
}

class GlassCard extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final double blur;
  final double opacity;
  final double borderRadius;

  const GlassCard({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding,
    this.blur = 12.0,
    this.opacity = 0.7,
    this.borderRadius = AppDesign.cardRadius,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          width: width,
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: opacity),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.4),
              width: 1.5,
            ),
            boxShadow: AppDesign.premiumShadow,
          ),
          child: child,
        ),
      ),
    );
  }
}

class LiquidButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool isLoading;
  final IconData? icon;
  final Color? color;

  const LiquidButton({
    super.key,
    required this.label,
    this.onTap,
    this.isLoading = false,
    this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap != null ? () {
            HapticFeedback.lightImpact();
            onTap!();
          } : null,
          borderRadius: BorderRadius.circular(AppDesign.buttonRadius),
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              gradient: onTap != null ? AppGradients.electric : null,
              color: onTap == null ? Colors.grey[300] : color,
              borderRadius: BorderRadius.circular(AppDesign.buttonRadius),
              boxShadow: onTap != null ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                )
              ] : null,
            ),
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          label.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class AquaTheme {
  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    fontFamily: 'Poppins',
    scaffoldBackgroundColor: AppColors.scaffold,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      secondary: AppColors.navy,
      tertiary: AppColors.secondary,
      surface: AppColors.surface,
      outline: const Color(0xFFE2E8F0),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: AppColors.navy,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontFamily: 'Poppins',
        fontWeight: FontWeight.w900,
        fontSize: 18,
        color: AppColors.navy,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDesign.cardRadius),
        side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
      ),
      color: Colors.white,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDesign.inputRadius),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDesign.inputRadius),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDesign.inputRadius),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      labelStyle: const TextStyle(color: AppColors.slate, fontSize: 14, fontWeight: FontWeight.w500),
      hintStyle: const TextStyle(color: AppColors.slate, fontSize: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDesign.buttonRadius),
        ),
        textStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 15,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.8,
        ),
        elevation: 4,
        shadowColor: AppColors.primary.withValues(alpha: 0.3),
      ),
    ),
  );
}
