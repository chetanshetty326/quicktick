import 'package:flutter/material.dart';
import 'about_quicktick_sheet.dart';

/// A classic, fully responsive brand footer for QuickTick.
/// Displays:
/// - QUICKTICK
/// - "A product from Prajnan Softwares"
/// - "Crafted with pride in Karnataka • v1.0.0"
/// Tapping opens the interactive [AboutQuickTickSheet].
class QuickTickBrandFooter extends StatelessWidget {
  final bool compact;
  final VoidCallback? onTap;

  const QuickTickBrandFooter({
    super.key,
    this.compact = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;
        final contentWidth = availableWidth.clamp(0.0, 480.0);
        final sideLineWidth = ((contentWidth - 60) / 2).clamp(16.0, 100.0);

        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: contentWidth),
            child: InkWell(
              onTap: onTap ?? () => AboutQuickTickSheet.show(context),
              borderRadius: BorderRadius.circular(16),
              splashColor: const Color(0xFF0F766E).withValues(alpha: 0.08),
              highlightColor: Colors.transparent,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: contentWidth < 340 ? 8 : 16,
                  vertical: compact ? 12 : 22,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Classic Ornamental Divider Line
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: sideLineWidth,
                          height: 0.8,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                const Color(0xFFCBD5E1).withValues(alpha: 0.8),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 3.5,
                                height: 3.5,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF0F766E),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.bolt_rounded,
                                size: 14,
                                color: Color(0xFF0F766E),
                              ),
                              const SizedBox(width: 4),
                              Container(
                                width: 3.5,
                                height: 3.5,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF0F766E),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: sideLineWidth,
                          height: 0.8,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFFCBD5E1).withValues(alpha: 0.8),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Brand Title in Classic Letter-spaced Typography
                    const Text(
                      'QUICKTICK',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.2,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Main Attribution: "A product from Prajnan Softwares"
                    const Text(
                      'A product from Prajnan Softwares',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                        color: Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Heritage & Version Line (Responsive Wrap to prevent any 320px overflow)
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 2,
                      children: [
                        const Text(
                          'Crafted with pride in Karnataka',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF94A3B8),
                            letterSpacing: 0.2,
                          ),
                        ),
                        Container(
                          width: 3,
                          height: 3,
                          decoration: const BoxDecoration(
                            color: Color(0xFFCBD5E1),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const Text(
                          'v1.0.0',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                    if (!compact) ...[
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'About & Heritage',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF0F766E).withValues(alpha: 0.9),
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 13,
                            color: const Color(0xFF0F766E).withValues(alpha: 0.9),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
