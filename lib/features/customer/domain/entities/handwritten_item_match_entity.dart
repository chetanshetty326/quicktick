import 'package:equatable/equatable.dart';
import 'catalog_entities.dart';

/// Represents a single item detected on a handwritten grocery list
/// and its corresponding match against the store catalog.
class HandwrittenItemMatchEntity extends Equatable {
  final String rawText;
  final String itemName;
  final int quantity;
  final String? detectedUnit;
  final ProductEntity? matchedProduct;
  final double matchScore;
  final bool isSelected;
  final String? statusNote;

  const HandwrittenItemMatchEntity({
    required this.rawText,
    required this.itemName,
    this.quantity = 1,
    this.detectedUnit,
    this.matchedProduct,
    this.matchScore = 0.0,
    this.isSelected = true,
    this.statusNote,
  });

  bool get isFound => matchedProduct != null && matchedProduct!.isAvailable && matchedProduct!.stock > 0;

  HandwrittenItemMatchEntity copyWith({
    String? rawText,
    String? itemName,
    int? quantity,
    String? detectedUnit,
    ProductEntity? matchedProduct,
    double? matchScore,
    bool? isSelected,
    String? statusNote,
  }) {
    return HandwrittenItemMatchEntity(
      rawText: rawText ?? this.rawText,
      itemName: itemName ?? this.itemName,
      quantity: quantity ?? this.quantity,
      detectedUnit: detectedUnit ?? this.detectedUnit,
      matchedProduct: matchedProduct ?? this.matchedProduct,
      matchScore: matchScore ?? this.matchScore,
      isSelected: isSelected ?? this.isSelected,
      statusNote: statusNote ?? this.statusNote,
    );
  }

  @override
  List<Object?> get props => [
        rawText,
        itemName,
        quantity,
        detectedUnit,
        matchedProduct,
        matchScore,
        isSelected,
        statusNote,
      ];
}

/// Represents the overall result of analyzing a handwritten grocery list.
class HandwrittenListScanResultEntity extends Equatable {
  final List<HandwrittenItemMatchEntity> matches;
  final String? imagePath;
  final DateTime scannedAt;

  const HandwrittenListScanResultEntity({
    required this.matches,
    this.imagePath,
    required this.scannedAt,
  });

  int get totalDetected => matches.length;
  int get matchedCount => matches.where((m) => m.isFound).length;
  int get selectedCount => matches.where((m) => m.isSelected && m.isFound).length;

  double get estimatedTotal => matches
      .where((m) => m.isSelected && m.isFound)
      .fold(0.0, (sum, m) => sum + ((m.matchedProduct?.price ?? 0.0) * m.quantity));

  HandwrittenListScanResultEntity copyWith({
    List<HandwrittenItemMatchEntity>? matches,
    String? imagePath,
    DateTime? scannedAt,
  }) {
    return HandwrittenListScanResultEntity(
      matches: matches ?? this.matches,
      imagePath: imagePath ?? this.imagePath,
      scannedAt: scannedAt ?? this.scannedAt,
    );
  }

  @override
  List<Object?> get props => [matches, imagePath, scannedAt];
}

