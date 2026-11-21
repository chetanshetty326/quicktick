import 'package:equatable/equatable.dart';

enum AiSender { user, assistant, system }

enum AiActionType {
  none,
  searchProduct,
  addItemsToCart,
  trackOrder,
  viewCoupons,
  incomingDeliveryAlert,
  customerSupport,
  checkStock,
  paymentStatus,
  recipeGuide,
}

class RecipeIngredient extends Equatable {
  final String name;
  final String quantity;
  final String? matchedQuery;

  const RecipeIngredient({
    required this.name,
    required this.quantity,
    this.matchedQuery,
  });

  @override
  List<Object?> get props => [name, quantity, matchedQuery];
}

class RecipeDetails extends Equatable {
  final String title;
  final String prepTime;
  final String cookTime;
  final String servings;
  final String difficulty;
  final List<RecipeIngredient> ingredients;
  final List<String> steps;
  final String? chefTip;
  final String? cuisine;

  const RecipeDetails({
    required this.title,
    required this.prepTime,
    required this.cookTime,
    required this.servings,
    this.difficulty = 'Easy',
    required this.ingredients,
    required this.steps,
    this.chefTip,
    this.cuisine,
  });

  @override
  List<Object?> get props => [
        title,
        prepTime,
        cookTime,
        servings,
        difficulty,
        ingredients,
        steps,
        chefTip,
        cuisine,
      ];
}

class AiActionIntent extends Equatable {
  final AiActionType type;
  final String? query;
  final List<String> itemNames;
  final String? payload;
  final RecipeDetails? recipeDetails;
  final String? stockItemQuery;
  final String? paymentOrderId;

  const AiActionIntent({
    this.type = AiActionType.none,
    this.query,
    this.itemNames = const [],
    this.payload,
    this.recipeDetails,
    this.stockItemQuery,
    this.paymentOrderId,
  });

  @override
  List<Object?> get props => [
        type,
        query,
        itemNames,
        payload,
        recipeDetails,
        stockItemQuery,
        paymentOrderId,
      ];
}

class AiMessageEntity extends Equatable {
  final String id;
  final String text;
  final AiSender sender;
  final DateTime timestamp;
  final AiActionIntent? actionIntent;
  final List<String> suggestions;
  final String? languageCode;
  final RecipeDetails? recipeDetails;

  const AiMessageEntity({
    required this.id,
    required this.text,
    required this.sender,
    required this.timestamp,
    this.actionIntent,
    this.suggestions = const [],
    this.languageCode,
    this.recipeDetails,
  });

  @override
  List<Object?> get props => [
        id,
        text,
        sender,
        timestamp,
        actionIntent,
        suggestions,
        languageCode,
        recipeDetails,
      ];
}

