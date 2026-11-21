import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import 'ai_concierge_sheet.dart';

class AiFloatingConciergeButton extends StatefulWidget {
  final VoidCallback? onSearchRequested;
  final Function(String query)? onSearchQuery;
  final VoidCallback? onTrackOrderRequested;
  final VoidCallback? onViewCouponsRequested;
  final Function(List<String> items)? onAddItemsRequested;
  final VoidCallback? onContactSupportRequested;
  final bool isDraggable;

  const AiFloatingConciergeButton({
    super.key,
    this.onSearchRequested,
    this.onSearchQuery,
    this.onTrackOrderRequested,
    this.onViewCouponsRequested,
    this.onAddItemsRequested,
    this.onContactSupportRequested,
    this.isDraggable = true,
  });

  @override
  State<AiFloatingConciergeButton> createState() => _AiFloatingConciergeButtonState();
}

class _AiFloatingConciergeButtonState extends State<AiFloatingConciergeButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  double? _right;
  double? _bottom;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _snapToNearestEdge(Size screenSize) {
    final curRight = _right ?? 16.0;
    // Snap to right edge (16.0) or left edge (screenSize.width - buttonWidth - 16.0)
    final buttonWidth = 115.0;
    final isCloserToLeft = curRight > (screenSize.width - buttonWidth) / 2;
    setState(() {
      _right = isCloserToLeft ? (screenSize.width - buttonWidth - 16.0) : 16.0;
      _bottom = (_bottom ?? 20.0).clamp(16.0, screenSize.height - 180.0);
      _isDragging = false;
    });
  }

  Widget _buildButton(double glowAlpha) {
    return GestureDetector(
      onTap: () {
        AiConciergeSheet.show(
          context,
          onSearchRequested: widget.onSearchRequested,
          onSearchQuery: widget.onSearchQuery,
          onTrackOrderRequested: widget.onTrackOrderRequested,
          onViewCouponsRequested: widget.onViewCouponsRequested,
          onAddItemsRequested: widget.onAddItemsRequested,
          onContactSupportRequested: widget.onContactSupportRequested,
        );
      },
      child: AnimatedScale(
        scale: _isDragging ? 1.08 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6366F1).withValues(alpha: _isDragging ? 0.6 : glowAlpha),
                blurRadius: _isDragging ? 22 : 16,
                spreadRadius: _isDragging ? 3 : 2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Ask AI',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: -0.1,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'VOICE',
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isDraggable) {
      return AnimatedBuilder(
        animation: _animController,
        builder: (context, child) {
          final glowAlpha = 0.25 + (_animController.value * 0.25);
          return _buildButton(glowAlpha);
        },
      );
    }

    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;

    // Default starting position: bottom 20 (just above bottom nav bar), right 16
    final curRight = _right ?? 16.0;
    final curBottom = _bottom ?? 20.0;

    return Positioned(
      right: curRight,
      bottom: curBottom,
      child: GestureDetector(
        onPanStart: (_) {
          setState(() => _isDragging = true);
        },
        onPanUpdate: (details) {
          setState(() {
            // details.delta.dx > 0 means moving right (so right offset decreases)
            final nextRight = (curRight - details.delta.dx)
                .clamp(12.0, screenSize.width - 120.0);
            // details.delta.dy > 0 means moving down (so bottom offset decreases)
            final nextBottom = (curBottom - details.delta.dy)
                .clamp(16.0, screenSize.height - 180.0);
            _right = nextRight;
            _bottom = nextBottom;
          });
        },
        onPanEnd: (_) => _snapToNearestEdge(screenSize),
        onPanCancel: () => _snapToNearestEdge(screenSize),
        child: AnimatedBuilder(
          animation: _animController,
          builder: (context, child) {
            final glowAlpha = 0.25 + (_animController.value * 0.25);
            return _buildButton(glowAlpha);
          },
        ),
      ),
    );
  }
}


