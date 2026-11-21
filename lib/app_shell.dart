import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/theme/app_colors.dart';
import 'features/auth/domain/entities/user_entity.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/customer/presentation/bloc/customer_bloc.dart';
import 'features/customer/presentation/screens/customer_main_screen.dart';
import 'features/retailer/presentation/bloc/retailer_bloc.dart';
import 'features/retailer/presentation/screens/retailer_main_screen.dart';
import 'features/delivery/presentation/bloc/delivery_bloc.dart';
import 'features/delivery/presentation/screens/delivery_main_screen.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        UserRole currentRole = UserRole.customer;
        if (state is AuthenticatedState) {
          currentRole = state.user.role;
        }

        return Scaffold(
          body: Column(
            children: [
              // Dev Mode Top Role Switcher Bar
              _DevRoleSwitcherBar(currentRole: currentRole),

              // Active Portal Screen
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _getPortalForRole(currentRole),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _getPortalForRole(UserRole role) {
    switch (role) {
      case UserRole.customer:
        return const CustomerMainScreen(key: ValueKey('customer_portal'));
      case UserRole.retailer:
        return const RetailerMainScreen(key: ValueKey('retailer_portal'));
      case UserRole.deliveryPartner:
        return const DeliveryMainScreen(key: ValueKey('delivery_portal'));
      case UserRole.admin:
        return const CustomerMainScreen(key: ValueKey('admin_view'));
    }
  }
}

class _DevRoleSwitcherBar extends StatelessWidget {
  final UserRole currentRole;
  const _DevRoleSwitcherBar({required this.currentRole});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A), // Dark slate header
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            const Icon(Icons.tune, color: Colors.tealAccent, size: 16),
            const SizedBox(width: 6),
            const Text(
              'ROLE:',
              style: TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w900,
                fontSize: 10,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _RoleButton(
                      label: '🛒 Customer',
                      isSelected: currentRole == UserRole.customer,
                      color: AppColors.primaryLight,
                      onTap: () {
                        context.read<AuthBloc>().add(const SwitchRoleEvent(UserRole.customer));
                        context.read<CustomerBloc>().add(LoadCustomerDataEvent());
                      },
                    ),
                    const SizedBox(width: 6),
                    _RoleButton(
                      label: '🏪 Retailer',
                      isSelected: currentRole == UserRole.retailer,
                      color: AppColors.retailerAccent,
                      onTap: () {
                        context.read<AuthBloc>().add(const SwitchRoleEvent(UserRole.retailer));
                        context.read<RetailerBloc>().add(const LoadRetailerDataEvent());
                      },
                    ),
                    const SizedBox(width: 6),
                    _RoleButton(
                      label: '🛵 Delivery',
                      isSelected: currentRole == UserRole.deliveryPartner,
                      color: AppColors.deliveryAccent,
                      onTap: () {
                        context.read<AuthBloc>().add(const SwitchRoleEvent(UserRole.deliveryPartner));
                        context.read<DeliveryBloc>().add(const LoadDeliveryDataEvent());
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _RoleButton({
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : Colors.white.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? (color == AppColors.deliveryAccent ? Colors.black : Colors.white) : Colors.white70,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
