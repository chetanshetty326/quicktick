import '../../domain/entities/catalog_entities.dart';

class CategoryModel extends CategoryEntity {
  const CategoryModel({
    required super.id,
    required super.name,
    super.icon = '🏪',
    super.colorHex = '#0F766E',
    super.slug = '',
    super.imageUrl = '',
    super.description = '',
    super.isActive = true,
    super.isFeatured = false,
    super.sortOrder = 0,
    super.foodType,
    super.dietaryBadge = false,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    final nameStr = json['name']?.toString() ?? '';
    final slugStr = json['slug']?.toString() ?? '';
    final key = slugStr.isNotEmpty ? slugStr : nameStr;
    return CategoryModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      name: nameStr,
      slug: slugStr,
      description: json['description']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString() ?? '',
      isActive: json['isActive'] != false,
      isFeatured: json['isFeatured'] == true,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      icon: resolveEmoji(key),
      colorHex: _resolveColor(key),
      foodType: json['foodType']?.toString(),
      dietaryBadge: json['dietaryBadge'] == true,
    );
  }

  static String resolveEmoji(String nameOrSlug) {
    final lower = nameOrSlug.toLowerCase();
    if (lower.contains('all')) return '🏪';
    if (lower.contains('milk') || lower.contains('dairy') || lower.contains('egg') || lower.contains('cheese') || lower.contains('butter') || lower.contains('paneer')) return '🥛';
    if (lower.contains('fruit') || lower.contains('apple') || lower.contains('banana') || lower.contains('mango')) return '🍎';
    if (lower.contains('veg') || lower.contains('vegetable') || lower.contains('onion') || lower.contains('potato') || lower.contains('tomato')) return '🥦';
    if (lower.contains('snack') || lower.contains('biscuit') || lower.contains('crisp') || lower.contains('chips') || lower.contains('munch') || lower.contains('namkeen')) return '🍿';
    if (lower.contains('bakery') || lower.contains('bread') || lower.contains('cake') || lower.contains('toast') || lower.contains('cookie') || lower.contains('pastry')) return '🥐';
    if (lower.contains('beverage') || lower.contains('drink') || lower.contains('juice') || lower.contains('soda') || lower.contains('cold drink') || lower.contains('water')) return '🧃';
    if (lower.contains('tea') || lower.contains('chai') || lower.contains('coffee')) return '☕';
    if (lower.contains('meat') || lower.contains('fish') || lower.contains('chicken') || lower.contains('mutton') || lower.contains('seafood') || lower.contains('prawn')) return '🍗';
    if (lower.contains('clean') || lower.contains('detergent') || lower.contains('wash') || lower.contains('dish') || lower.contains('mop')) return '🧼';
    if (lower.contains('personal') || lower.contains('care') || lower.contains('beauty') || lower.contains('shampoo') || lower.contains('soap') || lower.contains('skin')) return '🧴';
    if (lower.contains('baby') || lower.contains('diaper') || lower.contains('infant')) return '🍼';
    if (lower.contains('pet') || lower.contains('dog') || lower.contains('cat')) return '🐾';
    if (lower.contains('pharma') || lower.contains('medicine') || lower.contains('health') || lower.contains('wellness')) return '💊';
    if (lower.contains('frozen') || lower.contains('ice cream') || lower.contains('popsicle')) return '🍦';
    if (lower.contains('sweet') || lower.contains('mithai') || lower.contains('chocolate') || lower.contains('candy')) return '🍫';
    if (lower.contains('noodle') || lower.contains('pasta') || lower.contains('instant') || lower.contains('maggi') || lower.contains('soup')) return '🍜';
    if (lower.contains('home') || lower.contains('kitchen') || lower.contains('cookware')) return '🍳';
    if (lower.contains('stationery') || lower.contains('book') || lower.contains('pen') || lower.contains('office')) return '📚';
    if (lower.contains('electronic') || lower.contains('cable') || lower.contains('battery') || lower.contains('charger') || lower.contains('gadget')) return '🔌';
    if (lower.contains('grocer') || lower.contains('staple') || lower.contains('dal') || lower.contains('rice') || lower.contains('oil') || lower.contains('atta') || lower.contains('flour') || lower.contains('spice') || lower.contains('masala')) return '🛒';
    return '🛍️';
  }

  static String _resolveColor(String nameOrSlug) {
    final lower = nameOrSlug.toLowerCase();
    if (lower.contains('milk') || lower.contains('dairy')) return '#0284C7';
    if (lower.contains('fruit') || lower.contains('veg')) return '#16A34A';
    if (lower.contains('snack')) return '#D97706';
    if (lower.contains('bakery')) return '#EA580C';
    if (lower.contains('beverage') || lower.contains('coffee')) return '#9333EA';
    if (lower.contains('meat') || lower.contains('fish')) return '#DC2626';
    if (lower.contains('clean')) return '#0D9488';
    return '#0F766E';
  }
}
