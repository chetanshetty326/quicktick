import '../../domain/entities/hero_banner_entity.dart';

/// Clean Architecture Data Model for Hero Banner API.
/// Safely maps JSON fields from GET /hero-banners.
class HeroBannerModel extends HeroBannerEntity {
  const HeroBannerModel({
    required super.id,
    super.app,
    super.badge,
    required super.title,
    super.titleAccent,
    super.subtitle,
    super.ctaLabel,
    super.ctaLink,
    super.imageUrl,
    super.bgColor,
    super.order = 0,
    super.isActive = true,
    super.createdAt,
    super.updatedAt,
  });

  factory HeroBannerModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      return DateTime.tryParse(v.toString());
    }

    bool parseBool(dynamic val, {bool defaultValue = true}) {
      if (val == null) return defaultValue;
      if (val is bool) return val;
      if (val is num) return val != 0;
      final s = val.toString().trim().toLowerCase();
      if (s == 'true' || s == '1' || s == 'active' || s == 'enabled' || s == 'yes') return true;
      if (s == 'false' || s == '0' || s == 'inactive' || s == 'disabled' || s == 'no') return false;
      return defaultValue;
    }

    final rawActive = json['isActive'] ?? json['active'] ?? json['is_active'] ?? json['status'] ?? json['state'];
    final bool isActive = parseBool(rawActive, defaultValue: true);

    final rawOrder = json['order'] ?? json['displayOrder'] ?? json['priority'] ?? json['sortOrder'];
    final int order = (rawOrder is num)
        ? rawOrder.toInt()
        : int.tryParse(rawOrder?.toString() ?? '') ?? 0;

    return HeroBannerModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      app: json['app']?.toString(),
      badge: json['badge']?.toString() ?? json['tag']?.toString() ?? json['badgeText']?.toString(),
      title: json['title']?.toString() ?? json['name']?.toString() ?? json['header']?.toString() ?? '',
      titleAccent: json['titleAccent']?.toString() ?? json['accentTitle']?.toString() ?? json['accent']?.toString(),
      subtitle: json['subtitle']?.toString() ?? json['subTitle']?.toString() ?? json['description']?.toString() ?? json['subHeader']?.toString(),
      ctaLabel: json['ctaLabel']?.toString() ?? json['ctaText']?.toString() ?? json['buttonText']?.toString() ?? json['cta']?.toString() ?? json['actionLabel']?.toString(),
      ctaLink: json['ctaLink']?.toString() ?? json['deepLink']?.toString() ?? json['link']?.toString() ?? json['actionUrl']?.toString() ?? json['url']?.toString() ?? json['target']?.toString(),
      imageUrl: json['imageUrl']?.toString() ?? json['image']?.toString() ?? json['bannerUrl']?.toString() ?? json['bannerImage']?.toString() ?? json['img']?.toString(),
      bgColor: json['bgColor']?.toString() ?? json['backgroundColor']?.toString() ?? json['color']?.toString(),
      order: order,
      isActive: isActive,
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      if (app != null) 'app': app,
      if (badge != null) 'badge': badge,
      'title': title,
      if (titleAccent != null) 'titleAccent': titleAccent,
      if (subtitle != null) 'subtitle': subtitle,
      if (ctaLabel != null) 'ctaLabel': ctaLabel,
      if (ctaLink != null) 'ctaLink': ctaLink,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (bgColor != null) 'bgColor': bgColor,
      'order': order,
      'isActive': isActive,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    };
  }
}
