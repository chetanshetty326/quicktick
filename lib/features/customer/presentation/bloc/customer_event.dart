import 'dart:typed_data';
import 'package:equatable/equatable.dart';
import '../../../order/domain/entities/order_entity.dart';
import '../../domain/entities/cart_optimization_entity.dart';
import '../../domain/entities/catalog_entities.dart';
import '../../domain/entities/customer_address_entity.dart';
import 'customer_state.dart';

abstract class CustomerEvent extends Equatable {
  const CustomerEvent();
  @override
  List<Object?> get props => [];
}

class LoadCustomerDataEvent extends CustomerEvent {
  final double? lat;
  final double? lng;
  const LoadCustomerDataEvent({this.lat, this.lng});

  @override
  List<Object?> get props => [lat, lng];
}

class SearchProductsEvent extends CustomerEvent {
  final String query;
  const SearchProductsEvent(this.query);

  @override
  List<Object?> get props => [query];
}

class FilterByCategoryEvent extends CustomerEvent {
  final String categoryId;
  const FilterByCategoryEvent(this.categoryId);

  @override
  List<Object?> get props => [categoryId];
}

class FilterByStoreEvent extends CustomerEvent {
  final StoreEntity? store;
  const FilterByStoreEvent(this.store);

  @override
  List<Object?> get props => [store];
}

class AddToCartEvent extends CustomerEvent {
  final ProductEntity product;
  final bool clearPreviousStoreCart;

  const AddToCartEvent(this.product, {this.clearPreviousStoreCart = false});

  @override
  List<Object?> get props => [product, clearPreviousStoreCart];
}

class DismissMultiRetailerConflictEvent extends CustomerEvent {}

class UpdateCartQuantityEvent extends CustomerEvent {
  final String productId;
  final int newQuantity;
  const UpdateCartQuantityEvent(this.productId, this.newQuantity);

  @override
  List<Object?> get props => [productId, newQuantity];
}

class RemoveFromCartEvent extends CustomerEvent {
  final String productId;
  const RemoveFromCartEvent(this.productId);

  @override
  List<Object?> get props => [productId];
}

class ClearCartEvent extends CustomerEvent {}

class ReorderEvent extends CustomerEvent {
  final OrderEntity order;
  const ReorderEvent(this.order);

  @override
  List<Object?> get props => [order];
}

class SelectAddressEvent extends CustomerEvent {
  final String address;
  final double? lat;
  final double? lng;
  const SelectAddressEvent(this.address, {this.lat, this.lng});

  @override
  List<Object?> get props => [address, lat, lng];
}

class PlaceOrderEvent extends CustomerEvent {
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String storeId;
  final String storeName;
  final String storeAddress;
  final String? deliveryAddress;
  final String paymentMethod;
  final String? zoneId;
  final String? deliveryAddressId;
  final String? couponCode;
  final double? couponDiscount;
  final double? latitude;
  final double? longitude;

  const PlaceOrderEvent({
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.storeId,
    required this.storeName,
    required this.storeAddress,
    this.deliveryAddress,
    this.paymentMethod = 'COD',
    this.zoneId,
    this.deliveryAddressId,
    this.couponCode,
    this.couponDiscount,
    this.latitude,
    this.longitude,
  });

  @override
  List<Object?> get props => [
        customerId,
        customerName,
        customerPhone,
        storeId,
        storeName,
        storeAddress,
        deliveryAddress,
        paymentMethod,
        zoneId,
        deliveryAddressId,
        couponCode,
        couponDiscount,
        latitude,
        longitude,
      ];
}

class FetchAvailableCouponsEvent extends CustomerEvent {
  final String? retailerId;
  const FetchAvailableCouponsEvent({this.retailerId});

  @override
  List<Object?> get props => [retailerId];
}

class ApplyCouponEvent extends CustomerEvent {
  final String code;
  final String? cartId;
  final String? retailerId;

  const ApplyCouponEvent({
    required this.code,
    this.cartId,
    this.retailerId,
  });

  @override
  List<Object?> get props => [code, cartId, retailerId];
}

class RemoveCouponEvent extends CustomerEvent {
  const RemoveCouponEvent();
}

class ValidateCartEvent extends CustomerEvent {}

class LoadAddressesEvent extends CustomerEvent {}

class AddAddressEvent extends CustomerEvent {
  final CustomerAddressEntity address;
  const AddAddressEvent(this.address);

  @override
  List<Object?> get props => [address];
}

class UpdateAddressEvent extends CustomerEvent {
  final String addressId;
  final CustomerAddressEntity address;
  const UpdateAddressEvent({required this.addressId, required this.address});

  @override
  List<Object?> get props => [addressId, address];
}

class DeleteAddressEvent extends CustomerEvent {
  final String addressId;
  const DeleteAddressEvent(this.addressId);

  @override
  List<Object?> get props => [addressId];
}

class SetDefaultAddressEvent extends CustomerEvent {
  final String addressId;
  const SetDefaultAddressEvent(this.addressId);

  @override
  List<Object?> get props => [addressId];
}

class LoadRecommendationsEvent extends CustomerEvent {}

class LoadWishlistEvent extends CustomerEvent {}

class ToggleWishlistEvent extends CustomerEvent {
  final String productId;
  const ToggleWishlistEvent(this.productId);

  @override
  List<Object?> get props => [productId];
}

class LoadNotificationsEvent extends CustomerEvent {}

class MarkNotificationReadEvent extends CustomerEvent {
  final String notificationId;
  const MarkNotificationReadEvent(this.notificationId);

  @override
  List<Object?> get props => [notificationId];
}

class MarkAllNotificationsReadEvent extends CustomerEvent {}

class CancelOrderEvent extends CustomerEvent {
  final String orderId;
  final String reason;
  const CancelOrderEvent({required this.orderId, required this.reason});

  @override
  List<Object?> get props => [orderId, reason];
}

class ReviewOrderEvent extends CustomerEvent {
  final String orderId;
  final int storeRating;
  final int deliveryRating;
  final String storeReview;
  final String deliveryReview;

  const ReviewOrderEvent({
    required this.orderId,
    required this.storeRating,
    required this.deliveryRating,
    this.storeReview = '',
    this.deliveryReview = '',
  });

  @override
  List<Object?> get props => [orderId, storeRating, deliveryRating, storeReview, deliveryReview];
}

class TrackOrderEvent extends CustomerEvent {
  final String orderId;
  const TrackOrderEvent(this.orderId);

  @override
  List<Object?> get props => [orderId];
}

// Internal stream updates
class CustomerOrdersStreamUpdated extends CustomerEvent {
  final List<OrderEntity> orders;
  const CustomerOrdersStreamUpdated(this.orders);

  @override
  List<Object?> get props => [orders];
}

class CustomerProductsStreamUpdated extends CustomerEvent {
  final List<ProductEntity> products;
  const CustomerProductsStreamUpdated(this.products);

  @override
  List<Object?> get props => [products];
}

class CustomerStoresStreamUpdated extends CustomerEvent {
  final List<StoreEntity> stores;
  const CustomerStoresStreamUpdated(this.stores);

  @override
  List<Object?> get props => [stores];
}

class PollCustomerOrdersEvent extends CustomerEvent {
  const PollCustomerOrdersEvent();
}

class RefreshCustomerOrdersEvent extends CustomerEvent {
  const RefreshCustomerOrdersEvent();
}

class InitiateRazorpayPaymentEvent extends CustomerEvent {
  final String orderId;
  const InitiateRazorpayPaymentEvent(this.orderId);

  @override
  List<Object?> get props => [orderId];
}

class VerifyRazorpayPaymentEvent extends CustomerEvent {
  final String razorpayOrderId;
  final String razorpayPaymentId;
  final String razorpaySignature;
  final String orderId;

  const VerifyRazorpayPaymentEvent({
    required this.razorpayOrderId,
    required this.razorpayPaymentId,
    required this.razorpaySignature,
    required this.orderId,
  });

  @override
  List<Object?> get props => [razorpayOrderId, razorpayPaymentId, razorpaySignature, orderId];
}

class RazorpayPaymentFailedEvent extends CustomerEvent {
  final String errorMessage;
  const RazorpayPaymentFailedEvent(this.errorMessage);

  @override
  List<Object?> get props => [errorMessage];
}

class RegisterCustomerPushTokenEvent extends CustomerEvent {
  final String fcmToken;
  final String platform;
  final String? deviceId;

  const RegisterCustomerPushTokenEvent({
    required this.fcmToken,
    this.platform = 'android',
    this.deviceId,
  });

  @override
  List<Object?> get props => [fcmToken, platform, deviceId];
}

class CustomerPushNotificationReceivedEvent extends CustomerEvent {
  final Map<String, dynamic> notificationPayload;

  const CustomerPushNotificationReceivedEvent(this.notificationPayload);

  @override
  List<Object?> get props => [notificationPayload];
}

class SocketOrderStatusChangedEvent extends CustomerEvent {
  final Map<String, dynamic> payload;
  const SocketOrderStatusChangedEvent(this.payload);

  @override
  List<Object?> get props => [payload];
}

class SocketNotificationEvent extends CustomerEvent {
  final Map<String, dynamic> payload;
  const SocketNotificationEvent(this.payload);

  @override
  List<Object?> get props => [payload];
}

class ApplyProductFiltersEvent extends CustomerEvent {
  final ProductSortOption sortOption;
  final bool inStockOnly;
  final bool fastDeliveryOnly;
  final bool dealsOnly;
  final String? foodType;

  const ApplyProductFiltersEvent({
    this.sortOption = ProductSortOption.relevance,
    this.inStockOnly = false,
    this.fastDeliveryOnly = false,
    this.dealsOnly = false,
    this.foodType,
  });

  @override
  List<Object?> get props => [sortOption, inStockOnly, fastDeliveryOnly, dealsOnly, foodType];
}

class ResetProductFiltersEvent extends CustomerEvent {}

class ClearCustomerSessionEvent extends CustomerEvent {
  const ClearCustomerSessionEvent();
}

class LoadMoreProductsEvent extends CustomerEvent {
  const LoadMoreProductsEvent();
}

class ClearActiveRazorpayOrderEvent extends CustomerEvent {
  const ClearActiveRazorpayOrderEvent();
}

class CheckCustomerLocationEvent extends CustomerEvent {
  final double lat;
  final double lng;

  const CheckCustomerLocationEvent({required this.lat, required this.lng});

  @override
  List<Object?> get props => [lat, lng];
}

class LoadCustomerNotificationsEvent extends CustomerEvent {
  const LoadCustomerNotificationsEvent();
}

class GetPaymentStatusEvent extends CustomerEvent {
  final String orderId;

  const GetPaymentStatusEvent(this.orderId);

  @override
  List<Object?> get props => [orderId];
}

class FetchHeroBannersEvent extends CustomerEvent {
  final bool forceRefresh;
  const FetchHeroBannersEvent({this.forceRefresh = false});

  @override
  List<Object?> get props => [forceRefresh];
}

class FilterStoresEvent extends CustomerEvent {
  final StoreFilterType filterType;
  const FilterStoresEvent(this.filterType);

  @override
  List<Object?> get props => [filterType];
}

class CustomerConnectivityChangedEvent extends CustomerEvent {
  final bool isOnline;
  const CustomerConnectivityChangedEvent(this.isOnline);

  @override
  List<Object?> get props => [isOnline];
}

class SubmitOrderReviewEvent extends CustomerEvent {
  final String orderId;
  final int storeRating;
  final int deliveryRating;
  final String comment;
  final List<String> storeTags;
  final List<String> riderTags;

  const SubmitOrderReviewEvent({
    required this.orderId,
    required this.storeRating,
    required this.deliveryRating,
    this.comment = '',
    this.storeTags = const [],
    this.riderTags = const [],
  });

  @override
  List<Object?> get props => [
        orderId,
        storeRating,
        deliveryRating,
        comment,
        storeTags,
        riderTags,
      ];
}

class FetchCartPricingEvent extends CustomerEvent {
  final String? couponCode;
  final double? tip;

  const FetchCartPricingEvent({this.couponCode, this.tip});

  @override
  List<Object?> get props => [couponCode, tip];
}

class SelectTipEvent extends CustomerEvent {
  final double tip;

  const SelectTipEvent(this.tip);

  @override
  List<Object?> get props => [tip];
}

class DownloadOrderInvoiceEvent extends CustomerEvent {
  final String orderId;

  const DownloadOrderInvoiceEvent(this.orderId);

  @override
  List<Object?> get props => [orderId];
}

class ChangeCustomerLanguageEvent extends CustomerEvent {
  final String languageCode;

  const ChangeCustomerLanguageEvent(this.languageCode);

  @override
  List<Object?> get props => [languageCode];
}

class AddSearchHistoryEvent extends CustomerEvent {
  final String query;

  const AddSearchHistoryEvent(this.query);

  @override
  List<Object?> get props => [query];
}

class RemoveSearchHistoryItemEvent extends CustomerEvent {
  final String query;

  const RemoveSearchHistoryItemEvent(this.query);

  @override
  List<Object?> get props => [query];
}

class ClearSearchHistoryEvent extends CustomerEvent {
  const ClearSearchHistoryEvent();
}

class AnalyzeCartOptimizationEvent extends CustomerEvent {
  final CartOptimizationType type;

  const AnalyzeCartOptimizationEvent({this.type = CartOptimizationType.budget});

  @override
  List<Object?> get props => [type];
}

class ApplyCartSwapEvent extends CustomerEvent {
  final CartSwapSuggestion swap;

  const ApplyCartSwapEvent(this.swap);

  @override
  List<Object?> get props => [swap];
}

class ApplyAllCartSwapsEvent extends CustomerEvent {
  final List<CartSwapSuggestion> swaps;

  const ApplyAllCartSwapsEvent(this.swaps);

  @override
  List<Object?> get props => [swaps];
}

class DismissCartOptimizationEvent extends CustomerEvent {
  const DismissCartOptimizationEvent();
}

class ScanHandwrittenListEvent extends CustomerEvent {
  final Uint8List imageBytes;
  final String? imagePath;

  const ScanHandwrittenListEvent({
    required this.imageBytes,
    this.imagePath,
  });

  @override
  List<Object?> get props => [imageBytes, imagePath];
}

class ToggleHandwrittenItemSelectionEvent extends CustomerEvent {
  final int index;

  const ToggleHandwrittenItemSelectionEvent(this.index);

  @override
  List<Object?> get props => [index];
}

class UpdateHandwrittenItemQuantityEvent extends CustomerEvent {
  final int index;
  final int delta;

  const UpdateHandwrittenItemQuantityEvent({required this.index, required this.delta});

  @override
  List<Object?> get props => [index, delta];
}

class AddHandwrittenMatchesToCartEvent extends CustomerEvent {
  const AddHandwrittenMatchesToCartEvent();
}

class ClearHandwrittenScanEvent extends CustomerEvent {
  const ClearHandwrittenScanEvent();
}





