import 'package:flutter/material.dart';
import '../errors/failures.dart';

/// Swiggy/Zepto-grade error state view for handling both:
/// 1. Offline (No Internet / Airplane mode)
/// 2. Server Down (HTTP 500, 502 Bad Gateway, 503 Maintenance, 504 Timeout)
class NetworkAndServerErrorView extends StatefulWidget {
  final FailureType failureType;
  final String? customMessage;
  final VoidCallback onRetry;
  final bool isRetrying;
  final String? cachedDataHint;
  final VoidCallback? onUseCachedData;

  const NetworkAndServerErrorView({
    super.key,
    required this.failureType,
    required this.onRetry,
    this.customMessage,
    this.isRetrying = false,
    this.cachedDataHint,
    this.onUseCachedData,
  });

  @override
  State<NetworkAndServerErrorView> createState() => _NetworkAndServerErrorViewState();
}

class _NetworkAndServerErrorViewState extends State<NetworkAndServerErrorView>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isOffline = widget.failureType == FailureType.noInternet;

    // Palette tokens
    final primaryColor = isOffline ? const Color(0xFFD97706) : const Color(0xFFDC2626); // Amber vs Crimson
    final iconBgColor = isOffline ? const Color(0xFFFEF3C7) : const Color(0xFFFEE2E2);
    final buttonColor = const Color(0xFF0F766E); // QuickLink Teal Brand

    final title = isOffline
        ? 'Connection Lost'
        : 'Something went wrong on our end';

    final defaultSubtitle = isOffline
        ? 'Please check your Wi-Fi or mobile data connection and try again.'
        : 'We are experiencing high traffic on our servers. Our team is already on it!';

    final subtitle = (widget.customMessage != null && widget.customMessage!.isNotEmpty)
        ? widget.customMessage!
        : defaultSubtitle;

    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Scaled Animated Icon Badge
            ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                width: 108,
                height: 108,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.18),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    isOffline ? Icons.wifi_off_rounded : Icons.cloud_off_rounded,
                    size: 54,
                    color: primaryColor,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Badge chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                isOffline ? 'OFFLINE MODE' : 'SERVER TEMPORARILY BUSY',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: primaryColor,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Heading
            Text(
              title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
                letterSpacing: -0.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),

            // Subtitle
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF64748B),
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 32),

            // Primary Action: Try Again
            SizedBox(
              width: 220,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: buttonColor,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shadowColor: buttonColor.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: widget.isRetrying ? null : widget.onRetry,
                icon: widget.isRetrying
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.refresh_rounded, size: 20),
                label: Text(
                  widget.isRetrying ? 'Checking...' : 'Try Again',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),

            // Secondary Action: Cached Data (if available)
            if (widget.cachedDataHint != null && widget.onUseCachedData != null) ...[
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: widget.onUseCachedData,
                icon: const Icon(Icons.history_rounded, size: 16, color: Color(0xFF0F766E)),
                label: Text(
                  widget.cachedDataHint!,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F766E),
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
