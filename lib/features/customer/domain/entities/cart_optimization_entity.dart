import 'package:equatable/equatable.dart';
import 'catalog_entities.dart';

enum CartOptimizationType {
  budget,
  healthy,
}

class CartSwapSuggestion extends Equatable {
  final ProductEntity originalProduct;
  final ProductEntity suggestedProduct;
  final double savings;
  final String reason;
  final int quantity;
  final String? healthTag;

  const CartSwapSuggestion({
    required this.originalProduct,
    required this.suggestedProduct,
    required this.savings,
    required this.reason,
    this.quantity = 1,
    this.healthTag,
  });

  double get totalSavings => savings * quantity;

  @override
  List<Object?> get props => [
        originalProduct,
        suggestedProduct,
        savings,
        reason,
        quantity,
        healthTag,
      ];
}

class CartOptimizationEntity extends Equatable {
  final CartOptimizationType type;
  final List<CartSwapSuggestion> suggestions;
  final double totalPotentialSavings;

  const CartOptimizationEntity({
    required this.type,
    required this.suggestions,
    required this.totalPotentialSavings,
  });

  bool get hasSuggestions => suggestions.isNotEmpty;

  @override
  List<Object?> get props => [type, suggestions, totalPotentialSavings];
}

