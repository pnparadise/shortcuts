import 'package:flutter/material.dart';

class AppColors {
  // Primary
  static const Color primary = Color(0xFF007BFF); // Vultr Blue

  // Backgrounds
  static const Color scaffoldBg = Color(0xFFF8FAFC); // Very light slate
  static const Color cardBg = Color(0xFFFFFFFF);     // Pure white
  
  // Borders
  static const Color border = Color(0xFFE2E8F0);     // Light grey border

  // Text
  static const Color textHeader = Color(0xFF1E293B); // Dark Slate
  static const Color textBody = Color(0xFF64748B);   // Cool Grey
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
