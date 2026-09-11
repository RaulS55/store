import 'package:flutter/material.dart';

class AppColors {
  static const terracotta = Color(0xFFC45C3E);
  static const terracottaPressed = Color(0xFFB04E32);
  static const terracottaSoft = Color(0xFFF3E4DE);
  static const terracottaChip = Color(0xFFF8EDE8);

  static const lightBg = Color(0xFFF8F9FA);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightMuted = Color(0xFFF1F3F4);
  static const lightBorder = Color(0xFFE6E8EA);
  static const charcoal = Color(0xFF1E1E1E);
  static const slate = Color(0xFF6B7280);
  static const mutedText = Color(0xFF8A8F98);

  static const darkBg = Color(0xFF121212);
  static const darkSurface = Color(0xFF1E1E1E);
  static const darkElevated = Color(0xFF262626);
  static const darkBorder = Color(0xFF2C2C2C);
  static const darkMuted = Color(0xFF2A2A2A);

  static const stockOk = Color(0xFF2F9E44);
  static const stockLow = Color(0xFFE03131);
  static const warning = Color(0xFFE67700);
  static const whatsapp = Color(0xFF25D366);
}

class AppRadii {
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const pill = 999.0;
}

class AppBreakpoints {
  static const wide = 900.0;

  static bool isWide(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= wide;
  }
}

class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
}
