import 'package:flutter/material.dart';

class AppColors {
  static const navy = Color(0xFF0B3A5E);
  static const green = Color(0xFF0E7A5F);
  static const background = Color(0xFFF1F5FB);
  static const chipBackground = Color(0xFFEAF0FA);
  static const textMuted = Color(0xFF5B6B7C);

  static const gradient = LinearGradient(
    colors: [navy, green],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
}
