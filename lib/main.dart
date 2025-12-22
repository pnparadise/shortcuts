import 'package:flutter/material.dart';
import 'ui/screens/dashboard_screen.dart';
import 'ui/theme/theme.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shortcuts',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: AppColors.primary,
        scaffoldBackgroundColor: AppColors.scaffoldBg,
        fontFamily: 'Inter',
        useMaterial3: false,
      ),
      home: const DashboardScreen(),
    );
  }
}
