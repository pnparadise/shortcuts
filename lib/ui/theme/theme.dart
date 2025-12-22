import 'package:flutter/material.dart';

class AppColors {
  // Primary
  static const Color primary = Color(0xFF007BFF); // Vultr Blue

  // Backgrounds
  static const Color scaffoldBg = Color(0xFFF8FAFC); // Very light slate
  static const Color cardBg = Color(0xFFFFFFFF);     // Pure white
  static const Color inputBg = Color(0xFFF1F5F9);    // Subtle field fill
  static const Color codeBg = Color(0xFF0F172A);     // Deep slate for code blocks
  
  // Borders
  static const Color border = Color(0xFFE2E8F0);     // Light grey border

  // Text
  static const Color textHeader = Color(0xFF1E293B); // Dark Slate
  static const Color textBody = Color(0xFF64748B);   // Cool Grey
  static const Color textMuted = Color(0xFF94A3B8);  // Hint grey
  static const Color codeText = Color(0xFF86EFAC);   // Mint for code output

  // Status
  static const Color success = Color(0xFF16A34A);
  static const Color danger = Color(0xFFDC2626);
  static const Color warning = Color(0xFFF59E0B);
}

class AppStyles {
  static const double borderRadius = 4.0;
  
  static BoxDecoration cardDecoration = BoxDecoration(
    color: AppColors.cardBg,
    border: Border.all(color: AppColors.border, width: 1),
    borderRadius: BorderRadius.circular(borderRadius),
  );
  
  static const TextStyle headerStyle = TextStyle(
    color: AppColors.textHeader,
    fontWeight: FontWeight.bold,
    fontSize: 16,
  );
  
  static const TextStyle labelStyle = TextStyle(
    color: AppColors.textBody,
    fontSize: 14,
  );
}
