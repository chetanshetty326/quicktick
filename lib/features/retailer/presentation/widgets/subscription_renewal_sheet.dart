import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../bloc/retailer_bloc.dart';

class SubscriptionRenewalSheet extends StatefulWidget {
  const SubscriptionRenewalSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: context.read<RetailerBloc>(),
        child: const SubscriptionRenewalSheet(),
      ),
    ).then((_) {
      if (context.mounted) {
        context.read<RetailerBloc>().add(const DismissSubscriptionRequiredSheetEvent());
      }
    });
  }

  @override
  State<SubscriptionRenewalSheet> createState() => _SubscriptionRenewalSheetState();
}

class _SubscriptionRenewalSheetState extends State<SubscriptionRenewalSheet> {
  int _selectedPlanIndex = 1; // Default to Pro

  final List<Map<String, dynamic>> _plans = [
    {
      'name': 'STARTER',
      'title': 'Starter Merchant',
      'price': '₹999',
      'period': '/month',
      'orders': 'Up to 300 orders/mo',
      'commission': '3% platform fee',
      'highlight': false,
    },
    {
      'name': 'PRO',
      'title': 'Growth Pro',
      'price': '₹2,499',
      'period': '/month',
      'orders': 'Unlimited orders',
      'commission': '0% platform fee',
      'highlight': true,
      'badge': 'MOST POPULAR',
    },
    {
      'name': 'ENTERPRISE',
      'title': 'Enterprise Fleet',
      'price': '₹5,999',
      'period': '/month',
      'orders': 'Unlimited multi-store',
      'commission': '0% fee + dedicated manager',
      'highlight': false,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final state = context.watch<RetailerBloc>().state;
    final sub = state.subscription;
    final bool isTrial = sub?.isTrial == true;
    final int daysLeft = sub?.daysRemaining ?? 0;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
        maxWidth: 580,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A), // Premium Dark
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 44,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Crown Icon + Title
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.workspace_premium_rounded,
                    color: Color(0xFFF59E0B),
                    size: 36,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              Text(
                isTrial
                    ? (daysLeft <= 0 ? 'Trial Period Ended' : 'Trial Ending Soon ($daysLeft Days Left)')
                    : 'Merchant Subscription Required',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Active subscription is required to accept new orders and dispatch deliveries to riders.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),

              // Plans
              ...List.generate(_plans.length, (idx) {
                final plan = _plans[idx];
                final isSelected = _selectedPlanIndex == idx;
                return GestureDetector(
                  onTap: () => setState(() => _selectedPlanIndex = idx),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary.withValues(alpha: 0.15)
                          : const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : Colors.white.withValues(alpha: 0.1),
                        width: isSelected ? 2.0 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? AppColors.primary : const Color(0xFF64748B),
                              width: 2,
                            ),
                          ),
                          child: isSelected
                              ? Center(
                                  child: Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  Text(
                                    plan['title'] as String,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14.5,
                                    ),
                                  ),
                                  if (plan['badge'] != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF59E0B),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        plan['badge'] as String,
                                        style: const TextStyle(
                                          color: Color(0xFF0F172A),
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${plan['orders']} • ${plan['commission']}',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              plan['price'] as String,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                              ),
                            ),
                            Text(
                              plan['period'] as String,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 14),

              // Features Checklist
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B).withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    _buildFeatureItem(Icons.check_circle_rounded, 'Real-time order acceptance & delivery tracking'),
                    const SizedBox(height: 8),
                    _buildFeatureItem(Icons.check_circle_rounded, 'Priority dispatch to nearest delivery partners'),
                    const SizedBox(height: 8),
                    _buildFeatureItem(Icons.check_circle_rounded, 'Zero hidden charges with daily automated settlement'),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Action Buttons
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 2,
                ),
                onPressed: () {
                  final chosen = _plans[_selectedPlanIndex];
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Subscription request for ${chosen['title']} submitted!'),
                      backgroundColor: const Color(0xFF10B981),
                    ),
                  );
                  Navigator.pop(context);
                },
                child: Text(
                  'Upgrade / Renew Plan (${_plans[_selectedPlanIndex]['price']})',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Dismiss for now',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF10B981), size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
