import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/ai_assistant_bloc.dart';
import '../bloc/ai_assistant_event.dart';
import '../bloc/ai_assistant_state.dart';

class IncomingDeliveryCallDialog extends StatefulWidget {
  final String riderName;
  final String storeName;
  final String orderNumber;
  final VoidCallback? onAccepted;

  const IncomingDeliveryCallDialog({
    super.key,
    required this.riderName,
    required this.storeName,
    required this.orderNumber,
    this.onAccepted,
  });

  static Future<void> show(
    BuildContext context, {
    required String riderName,
    required String storeName,
    required String orderNumber,
    VoidCallback? onAccepted,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      useSafeArea: false,
      builder: (_) => BlocProvider.value(
        value: context.read<AiAssistantBloc>(),
        child: IncomingDeliveryCallDialog(
          riderName: riderName,
          storeName: storeName,
          orderNumber: orderNumber,
          onAccepted: onAccepted,
        ),
      ),
    );
  }

  @override
  State<IncomingDeliveryCallDialog> createState() => _IncomingDeliveryCallDialogState();
}

class _IncomingDeliveryCallDialogState extends State<IncomingDeliveryCallDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _ringController;
  bool _isAnswered = false;

  @override
  void initState() {
    super.initState();
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ringController.dispose();
    super.dispose();
  }

  void _handleAccept() {
    setState(() => _isAnswered = true);
    context.read<AiAssistantBloc>().add(TriggerDeliveryArrivalCallEvent(
          riderName: widget.riderName,
          storeName: widget.storeName,
          orderNumber: widget.orderNumber,
        ));
    widget.onAccepted?.call();
  }

  void _handleDecline() {
    context.read<AiAssistantBloc>().add(const DismissDeliveryArrivalCallEvent());
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AiAssistantBloc, AiAssistantState>(
      listenWhen: (prev, curr) => prev.showIncomingCall && !curr.showIncomingCall,
      listener: (context, state) {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      },
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _handleDecline();
        },
        child: Scaffold(
          backgroundColor: const Color(0xFF0F172A),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Top Status
                  Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.greenAccent,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'QUICKTICK LIVE ARRIVAL',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        widget.riderName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Delivery Partner • ${widget.storeName}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Order #${widget.orderNumber}',
                        style: const TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),

                  // Center Pulsing Avatar
                  AnimatedBuilder(
                    animation: _ringController,
                    builder: (context, child) {
                      final scale = 1.0 + (_ringController.value * 0.12);
                      final glow = 0.2 + (_ringController.value * 0.3);
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 170 * scale,
                            height: 170 * scale,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: (_isAnswered ? Colors.green : const Color(0xFF6366F1))
                                  .withValues(alpha: glow * 0.4),
                            ),
                          ),
                          Container(
                            width: 130,
                            height: 130,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: _isAnswered
                                    ? [const Color(0xFF10B981), const Color(0xFF059669)]
                                    : [const Color(0xFF4F46E5), const Color(0xFF7C3AED)],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.4),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Icon(
                              _isAnswered ? Icons.record_voice_over_rounded : Icons.delivery_dining_rounded,
                              color: Colors.white,
                              size: 56,
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                  // Bottom Action Buttons
                  if (!_isAnswered)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Decline
                        Column(
                          children: [
                            IconButton.filled(
                              icon: const Icon(Icons.call_end_rounded, color: Colors.white, size: 28),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.red.shade600,
                                fixedSize: const Size(64, 64),
                              ),
                              onPressed: _handleDecline,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Dismiss',
                              style: TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),

                        // Accept
                        Column(
                          children: [
                            IconButton.filled(
                              icon: const Icon(Icons.call_rounded, color: Colors.white, size: 28),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.green.shade600,
                                fixedSize: const Size(64, 64),
                              ),
                              onPressed: _handleAccept,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Answer',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    )
                  else
                    Column(
                      children: [
                        const Text(
                          'Delivery Partner Arrival Announcement Active...',
                          style: TextStyle(
                            color: Colors.greenAccent,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _handleDecline,
                          icon: const Icon(Icons.check_rounded),
                          label: const Text('I will collect the order'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white.withValues(alpha: 0.15),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

