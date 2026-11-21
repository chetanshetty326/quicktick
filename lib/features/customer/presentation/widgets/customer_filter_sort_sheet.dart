import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../bloc/customer_bloc.dart';

class CustomerFilterSortSheet extends StatefulWidget {
  const CustomerFilterSortSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: context.read<CustomerBloc>(),
        child: const CustomerFilterSortSheet(),
      ),
    );
  }

  @override
  State<CustomerFilterSortSheet> createState() => _CustomerFilterSortSheetState();
}

class _CustomerFilterSortSheetState extends State<CustomerFilterSortSheet> {
  late ProductSortOption _selectedSort;
  late bool _inStockOnly;
  late bool _fastDeliveryOnly;
  late bool _dealsOnly;
  String? _selectedFoodType;

  @override
  void initState() {
    super.initState();
    final state = context.read<CustomerBloc>().state;
    _selectedSort = state.sortOption;
    _inStockOnly = state.inStockOnly;
    _fastDeliveryOnly = state.fastDeliveryOnly;
    _dealsOnly = state.dealsOnly;
    _selectedFoodType = state.selectedFoodType;
  }

  void _applyFilters() {
    context.read<CustomerBloc>().add(
          ApplyProductFiltersEvent(
            sortOption: _selectedSort,
            inStockOnly: _inStockOnly,
            fastDeliveryOnly: _fastDeliveryOnly,
            dealsOnly: _dealsOnly,
            foodType: _selectedFoodType,
          ),
        );
    Navigator.pop(context);
  }

  void _resetFilters() {
    context.read<CustomerBloc>().add(ResetProductFiltersEvent());
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
        maxWidth: 640,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 44,
                height: 4.5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.tune_rounded, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sort & Filters',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF0F172A)),
                        ),
                        Text(
                          'Refine product search results',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _resetFilters,
                    child: const Text('Reset', style: TextStyle(color: Color(0xFFEF4444), fontSize: 13, fontWeight: FontWeight.w800)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF334155)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),

            // Body
            Flexible(
              child: ListView(
                padding: const EdgeInsets.all(20),
                shrinkWrap: true,
                children: [
                  // Sort By Section
                  const Text(
                    'SORT BY',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF94A3B8), letterSpacing: 0.8),
                  ),
                  const SizedBox(height: 10),

                  RadioGroup<ProductSortOption>(
                    groupValue: _selectedSort,
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedSort = val);
                    },
                    child: Column(
                      children: [
                        _buildSortOption(
                          option: ProductSortOption.relevance,
                          title: 'Relevance / Popularity',
                          subtitle: 'Recommended default ranking',
                          icon: Icons.auto_awesome_rounded,
                        ),
                        _buildSortOption(
                          option: ProductSortOption.priceLowToHigh,
                          title: 'Price: Low to High',
                          subtitle: 'Cheapest products first',
                          icon: Icons.arrow_downward_rounded,
                        ),
                        _buildSortOption(
                          option: ProductSortOption.priceHighToLow,
                          title: 'Price: High to Low',
                          subtitle: 'Premium products first',
                          icon: Icons.arrow_upward_rounded,
                        ),
                        _buildSortOption(
                          option: ProductSortOption.ratingHighToLow,
                          title: 'Highest Customer Rating',
                          subtitle: '4.5+ star verified essentials',
                          icon: Icons.star_rounded,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  const Text(
                    'DIETARY PREFERENCE',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF94A3B8), letterSpacing: 0.8),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _buildDietaryChip('All', null),
                      const SizedBox(width: 8),
                      _buildDietaryChip('Veg', 'VEG', dotColor: const Color(0xFF22C55E)),
                      const SizedBox(width: 8),
                      _buildDietaryChip('Non-Veg', 'NON_VEG', dotColor: const Color(0xFFEF4444)),
                      const SizedBox(width: 8),
                      _buildDietaryChip('Egg', 'EGG', dotColor: const Color(0xFFF59E0B)),
                    ],
                  ),

                  const SizedBox(height: 20),
                  const Text(
                    'FILTER PRODUCTS',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF94A3B8), letterSpacing: 0.8),
                  ),
                  const SizedBox(height: 10),

                  // Filter Toggles
                  _buildFilterTile(
                    title: 'In-Stock Only',
                    subtitle: 'Hide temporarily unavailable items',
                    icon: Icons.inventory_2_rounded,
                    value: _inStockOnly,
                    onChanged: (v) => setState(() => _inStockOnly = v),
                  ),
                  _buildFilterTile(
                    title: 'Express Delivery (< 15 mins)',
                    subtitle: 'From fastest nearby hyper-local stores',
                    icon: Icons.electric_bolt_rounded,
                    value: _fastDeliveryOnly,
                    onChanged: (v) => setState(() => _fastDeliveryOnly = v),
                  ),
                  _buildFilterTile(
                    title: 'Special Deals & Offers',
                    subtitle: 'Items with active promotional discounts',
                    icon: Icons.discount_rounded,
                    value: _dealsOnly,
                    onChanged: (v) => setState(() => _dealsOnly = v),
                  ),

                  const SizedBox(height: 24),

                  // Apply Button
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 2,
                    ),
                    onPressed: _applyFilters,
                    child: const Text('Apply Filters', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSortOption({
    required ProductSortOption option,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = _selectedSort == option;

    return InkWell(
      onTap: () => setState(() => _selectedSort = option),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF0FDF4) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
            width: isSelected ? 1.6 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primaryContainer : const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: isSelected ? AppColors.primary : const Color(0xFF64748B)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                      fontSize: 13,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            Radio<ProductSortOption>(
              value: option,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: value ? const Color(0xFFF0FDF4) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: value ? AppColors.primary : const Color(0xFFE2E8F0),
          width: value ? 1.6 : 1.0,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: value ? AppColors.primaryContainer : const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: value ? AppColors.primary : const Color(0xFF64748B)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: value ? FontWeight.w800 : FontWeight.w700,
                    fontSize: 13,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            activeTrackColor: AppColors.primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildDietaryChip(String label, String? type, {Color? dotColor}) {
    final isSelected = _selectedFoodType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedFoodType = type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryContainer.withValues(alpha: 0.4) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.grey.shade300,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (dotColor != null) ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? AppColors.primary : const Color(0xFF334155),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
