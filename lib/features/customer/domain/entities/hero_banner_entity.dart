import 'package:equatable/equatable.dart';

/// Clean Architecture Entity representing a Hero Banner in QuickTick.
/// Conforms to QuickTick Android Integration Guide - Hero Banners API.
class HeroBannerEntity extends Equatable {
  final String id;
  final String? app;
  final String? badge;
  final String title;
  final String? titleAccent;
  final String? subtitle;
  final String? ctaLabel;
  final String? ctaLink;
  final String? imageUrl;
  final String? bgColor;
  final int order;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const HeroBannerEntity({
    required this.id,
    this.app,
    this.badge,
    required this.title,
    this.titleAccent,
    this.subtitle,
    this.ctaLabel,
    this.ctaLink,
    this.imageUrl,
    this.bgColor,
    this.order = 0,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  @override
  List<Object?> get props => [
        id,
        app,
        badge,
        title,
        titleAccent,
        subtitle,
        ctaLabel,
        ctaLink,
        imageUrl,
        bgColor,
        order,
        isActive,
        createdAt,
        updatedAt,
      ];
}
