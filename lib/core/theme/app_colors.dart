import 'package:flutter/material.dart';

class AppColors {
  // Brand Primary & Accents
  static const Color primary = Color(0xFF0F766E); // Vibrant Deep Teal
  static const Color primaryDark = Color(0xFF115E59);
  static const Color primaryLight = Color(0xFF14B8A6);
  static const Color primaryContainer = Color(0xFFCCFBF1);

  // Role Color Accents
  static const Color customerAccent = Color(0xFF0D9488); // Teal
  static const Color retailerAccent = Color(0xFF6366F1); // Indigo
  static const Color deliveryAccent = Color(0xFFF59E0B); // Amber/Orange
  static const Color adminAccent = Color(0xFF8B5CF6);    // Purple

  // Status Colors (Matching SRS Order State Machine)
  static const Color statusPlaced = Color(0xFF3B82F6);    // Blue
  static const Color statusAccepted = Color(0xFF06B6D4);  // Cyan
  static const Color statusPreparing = Color(0xFF8B5CF6); // Violet
  static const Color statusReady = Color(0xFFF59E0B);     // Amber
  static const Color statusAssigned = Color(0xFFEC4899);  // Pink
  static const Color statusPickedUp = Color(0xFFF97316);  // Orange
  static const Color statusOutForDelivery = Color(0xFF10B981); // Emerald
  static const Color statusDelivered = Color(0xFF059669); // Forest Green
  static const Color statusCancelled = Color(0xFFEF4444); // Red
  static const Color statusRejected = Color(0xFFDC2626);  // Crimson
  static const Color error = Color(0xFFEF4444);           // Standard Error Red

  // Neutrals & Surface Colors (Light Mode)
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF1F5F9);
  static const Color border = Color(0xFFE2E8F0);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);

  // Dark Mode Neutrals
  static const Color darkBackground = Color(0xFF0B0F19);
  static const Color darkSurface = Color(0xFF131B2E);
  static const Color darkSurfaceVariant = Color(0xFF1E293B);
  static const Color darkBorder = Color(0xFF334155);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
}
