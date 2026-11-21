import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/localization/app_strings.dart';
import '../../domain/entities/cart_optimization_entity.dart';
import '../bloc/customer_bloc.dart';

class CartOptimizerCard extends StatefulWidget {
  final CustomerState state;

  const CartOptimizerCard({
    super.key,
    required this.state,
  });

  @override
  State<CartOptimizerCard> createState() => _CartOptimizerCardState();
}

class _CartOptimizerCardState extends State<CartOptimizerCard> {
  CartOptimizationType _selectedType = CartOptimizationType.budget;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    // Auto-analyze cart in budget mode if cart is non-empty and no optimization exists yet
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.state.cartItems.isNotEmpty && widget.state.cartOptimization == null) {
        context.read<CustomerBloc>().add(
              const AnalyzeCartOptimizationEvent(type: CartOptimizationType.budget),
            );
      }
    });
  }

  void _onSwitchType(CartOptimizationType type) {
    if (_selectedType == type && widget.state.cartOptimization != null) return;
    setState(() {
      _selectedType = type;
      _isExpanded = true;
    });
    context.read<CustomerBloc>().add(AnalyzeCartOptimizationEvent(type: type));
  }

  @override
  Widget build(BuildContext context) {
    final opt = widget.state.cartOptimization;
    final isOptimizing = widget.state.isOptimizingCart;
    final isKannada = context.isKannada;

    if (widget.state.cartItems.isEmpty) {
      return const SizedBox.shrink();
    }

    final hasSuggestions = opt != null && opt.hasSuggestions;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasSuggestions ? AppColors.primary.withValues(alpha: 0.35) : AppColors.border,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: AppColors.primary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            isKannada ? 'ಸ್ಮಾರ್ಟ್ ಕಾರ್ಟ್ ಆಪ್ಟಿಮೈಜರ್' : 'Smart Cart Optimizer',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'AI RAG',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primaryDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasSuggestions
                            ? (isKannada
                                ? '₹${opt.totalPotentialSavings.toStringAsFixed(0)} ಉಳಿತಾಯ ಲಭ್ಯವಿದೆ!'
                                : 'Save up to ₹${opt.totalPotentialSavings.toStringAsFixed(0)} on this order')
                            : (isKannada
                                ? 'ಕಡಿಮೆ ಬೆಲೆ ಅಥವಾ ಆರೋಗ್ಯಕರ ಆಯ್ಕೆಗಳನ್ನು ನೋಡಿ'
                                : 'Compare best prices & healthier choices'),
                        style: TextStyle(
                          fontSize: 12,
                          color: hasSuggestions ? const Color(0xFF047857) : AppColors.textSecondary,
                          fontWeight: hasSuggestions ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                // Toggle Accordion Button
                IconButton(
                  onPressed: () => setState(() => _isExpanded = !_isExpanded),
                  icon: Icon(
                    _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: AppColors.textSecondary,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // Tab Pills: [ 💰 Budget Saver ] & [ 🥗 Healthier Choice ]
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Expanded(
                  child: _buildTypePill(
                    title: isKannada ? '💰 ಹಣ ಉಳಿಸಿ' : '💰 Budget Saver',
                    type: CartOptimizationType.budget,
                    isSelected: _selectedType == CartOptimizationType.budget,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildTypePill(
                    title: isKannada ? '🥗 ಆರೋಗ್ಯಕರ ಆಯ್ಕೆ' : '🥗 Healthier Choice',
                    type: CartOptimizationType.healthy,
                    isSelected: _selectedType == CartOptimizationType.healthy,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Expandable Body
          if (_isExpanded || hasSuggestions) ...[
            const Divider(height: 1, color: AppColors.border),
            if (isOptimizing)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Scanning store for smart alternatives...',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              )
            else if (!hasSuggestions)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, color: Color(0xFF059669), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _selectedType == CartOptimizationType.budget
                            ? (isKannada
                                ? 'ನಿಮ್ಮ ಕಾರ್ಟ್ ಈಗಾಗಲೇ ಈ ಅಂಗಡಿಯಲ್ಲಿ ಉತ್ತಮ ಬೆಲೆಯಲ್ಲಿದೆ!'
                                : 'Your cart already has the best available prices!')
                            : (isKannada
                                ? 'ಈ ಕಾರ್ಟ್‌ನಲ್ಲಿ ಯಾವುದೇ ಅನ್‌ಹೆಲ್ತಿ ಪದಾರ್ಥಗಳಿಲ್ಲ!'
                                : 'All current items match healthy diet standards!'),
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              // Suggestion List
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                itemCount: opt.suggestions.length,
                separatorBuilder: (_, index) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final suggestion = opt.suggestions[index];
                  return _buildSuggestionRow(context, suggestion, isKannada);
                },
              ),

              // Swap All Button (if more than 0 suggestions)
              if (opt.suggestions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
                  child: ElevatedButton(
                    onPressed: () {
                      context.read<CustomerBloc>().add(ApplyAllCartSwapsEvent(opt.suggestions));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.bolt, size: 18, color: Colors.amberAccent),
                        const SizedBox(width: 6),
                        Text(
                          isKannada
                              ? 'ಎಲ್ಲವನ್ನೂ ಬದಲಾಯಿಸಿ ₹${opt.totalPotentialSavings.toStringAsFixed(0)} ಉಳಿಸಿ'
                              : 'Swap All & Save ₹${opt.totalPotentialSavings.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildTypePill({
    required String title,
    required CartOptimizationType type,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () => _onSwitchType(type),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestionRow(
    BuildContext context,
    CartSwapSuggestion s,
    bool isKannada,
  ) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Original Item
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.originalProduct.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '₹${s.originalProduct.price.toStringAsFixed(0)} • ${s.originalProduct.unit}',
                      style: const TextStyle(
                        fontSize: 11,
                        decoration: TextDecoration.lineThrough,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),

              // Swap Arrow
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Icon(Icons.arrow_forward, size: 14, color: AppColors.primary),
              ),

              // Suggested Item
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.suggestedProduct.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          '₹${s.suggestedProduct.price.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF047857),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '• ${s.suggestedProduct.unit}',
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Swap Button
              ElevatedButton(
                onPressed: () {
                  context.read<CustomerBloc>().add(ApplyCartSwapEvent(s));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  isKannada ? 'ಬದಲಾಯಿಸಿ' : 'Swap',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),

          // Subtitle / Reason Tag
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lightbulb_outline, size: 12, color: Color(0xFF059669)),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    s.reason,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF047857),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
