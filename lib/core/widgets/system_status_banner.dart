import 'package:flutter/material.dart';

enum SystemStatusSeverity {
  offline, // Red/Charcoal - No internet
  serverDown, // Amber/Red - Server 5xx / Maintenance
  syncing, // Blue - Syncing
  online, // Emerald - Back online
}

/// Swiggy-style top persistent banner for informing users of system/network states
/// without blocking the entire screen.
class SystemStatusBar extends StatelessWidget {
  final SystemStatusSeverity severity;
  final String message;
  final VoidCallback? onAction;
  final String? actionLabel;

  const SystemStatusBar({
    super.key,
    required this.severity,
    required this.message,
    this.onAction,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    IconData icon;

    switch (severity) {
      case SystemStatusSeverity.offline:
        bgColor = const Color(0xFF1E293B); // Dark slate
        textColor = const Color(0xFFF8FAFC);
        icon = Icons.wifi_off_rounded;
        break;
      case SystemStatusSeverity.serverDown:
        bgColor = const Color(0xFF991B1B); // Crimson dark
        textColor = const Color(0xFFFEF2F2);
        icon = Icons.cloud_off_rounded;
        break;
      case SystemStatusSeverity.syncing:
        bgColor = const Color(0xFF0369A1); // Blue
        textColor = const Color(0xFFF0F9FF);
        icon = Icons.sync_rounded;
        break;
      case SystemStatusSeverity.online:
        bgColor = const Color(0xFF065F46); // Emerald
        textColor = const Color(0xFFECFDF5);
        icon = Icons.check_circle_outline_rounded;
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Row(
          children: [
            Icon(icon, size: 16, color: textColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (onAction != null && actionLabel != null) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onAction,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    actionLabel!,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
