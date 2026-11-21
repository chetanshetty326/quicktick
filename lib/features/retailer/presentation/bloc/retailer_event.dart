import 'package:equatable/equatable.dart';
import '../../../customer/domain/entities/catalog_entities.dart';
import '../../../order/domain/entities/order_entity.dart';

abstract class RetailerEvent extends Equatable {
  const RetailerEvent();
  @override
  List<Object?> get props => [];
}

class LoadRetailerDataEvent extends RetailerEvent {
  final String storeId;
  // FIX #3: Removed hardcoded 'store_01' fallback — caller must pass real storeId
  const LoadRetailerDataEvent({this.storeId = ''});

  @override
  List<Object?> get props => [storeId];
}

class RetailerConnectivityChangedEvent extends RetailerEvent {
  final bool isOnline;
  const RetailerConnectivityChangedEvent(this.isOnline);

  @override
  List<Object?> get props => [isOnline];
}

class AcceptOrderEvent extends RetailerEvent {
  final String orderId;
  const AcceptOrderEvent(this.orderId);

  @override
  List<Object?> get props => [orderId];
}

class RejectOrderEvent extends RetailerEvent {
  final String orderId;
  final String reason;
  const RejectOrderEvent(this.orderId, {this.reason = 'Item out of stock'});

  @override
  List<Object?> get props => [orderId, reason];
}

class MarkPreparingEvent extends RetailerEvent {
  final String orderId;
  const MarkPreparingEvent(this.orderId);

  @override
  List<Object?> get props => [orderId];
}

class MarkReadyForPickupEvent extends RetailerEvent {
  final String orderId;
  const MarkReadyForPickupEvent(this.orderId);

  @override
  List<Object?> get props => [orderId];
}

class ToggleProductStockEvent extends RetailerEvent {
  final String productId;
  final bool isAvailable;
  final int? currentStock;
  const ToggleProductStockEvent(this.productId, this.isAvailable, {this.currentStock});

  @override
  List<Object?> get props => [productId, isAvailable, currentStock];
}

class ToggleStoreStatusEvent extends RetailerEvent {
  final String storeId;
  final bool isOpen;
  const ToggleStoreStatusEvent(this.storeId, this.isOpen);

  @override
  List<Object?> get props => [storeId, isOpen];
}

class RetailerOrdersStreamUpdated extends RetailerEvent {
  final List<OrderEntity> orders;
  const RetailerOrdersStreamUpdated(this.orders);

  @override
  List<Object?> get props => [orders];
}

class RetailerProductsStreamUpdated extends RetailerEvent {
  final List<ProductEntity> products;
  const RetailerProductsStreamUpdated(this.products);

  @override
  List<Object?> get props => [products];
}

class AddProductToInventoryEvent extends RetailerEvent {
  final ProductEntity product;
  const AddProductToInventoryEvent(this.product);

  @override
  List<Object?> get props => [product];
}

class UpdateProductInInventoryEvent extends RetailerEvent {
  final ProductEntity product;
  const UpdateProductInInventoryEvent(this.product);

  @override
  List<Object?> get props => [product];
}

class DeleteProductFromInventoryEvent extends RetailerEvent {
  final String productId;
  final String productName;
  const DeleteProductFromInventoryEvent(this.productId, {this.productName = 'Item'});

  @override
  List<Object?> get props => [productId, productName];
}

class RegisterRetailerStoreEvent extends RetailerEvent {
  final Map<String, dynamic> storeData;
  const RegisterRetailerStoreEvent(this.storeData);

  @override
  List<Object?> get props => [storeData];
}

class UpdateRetailerStoreProfileEvent extends RetailerEvent {
  final Map<String, dynamic> storeData;
  const UpdateRetailerStoreProfileEvent(this.storeData);

  @override
  List<Object?> get props => [storeData];
}

class LoadRetailerProfileEvent extends RetailerEvent {
  const LoadRetailerProfileEvent();
}

class LoadRetailerDashboardStatsEvent extends RetailerEvent {
  const LoadRetailerDashboardStatsEvent();
}

class PollRetailerOrdersEvent extends RetailerEvent {
  const PollRetailerOrdersEvent();
}

class RegisterRetailerPushTokenEvent extends RetailerEvent {
  final String fcmToken;
  final String platform;
  final String? deviceId;

  const RegisterRetailerPushTokenEvent({
    required this.fcmToken,
    this.platform = 'android',
    this.deviceId,
  });

  @override
  List<Object?> get props => [fcmToken, platform, deviceId];
}

class RetailerPushNotificationReceivedEvent extends RetailerEvent {
  final Map<String, dynamic> notificationPayload;

  const RetailerPushNotificationReceivedEvent(this.notificationPayload);

  @override
  List<Object?> get props => [notificationPayload];
}

class RetailerSocketOrderStatusChangedEvent extends RetailerEvent {
  final Map<String, dynamic> payload;
  const RetailerSocketOrderStatusChangedEvent(this.payload);

  @override
  List<Object?> get props => [payload];
}

class RetailerSocketNotificationEvent extends RetailerEvent {
  final Map<String, dynamic> payload;
  const RetailerSocketNotificationEvent(this.payload);

  @override
  List<Object?> get props => [payload];
}

class CheckRetailerStatusEvent extends RetailerEvent {
  const CheckRetailerStatusEvent();
}

class FetchRetailerRejectionEvent extends RetailerEvent {
  const FetchRetailerRejectionEvent();
}

class UploadRetailerDocumentEvent extends RetailerEvent {
  final String docType;
  final String filePath;
  final String? folder;

  const UploadRetailerDocumentEvent({
    required this.docType,
    required this.filePath,
    this.folder,
  });

  @override
  List<Object?> get props => [docType, filePath, folder];
}

class ResetRetailerErrorsEvent extends RetailerEvent {
  const ResetRetailerErrorsEvent();
}

class CheckStoreNameEvent extends RetailerEvent {
  final String name;
  const CheckStoreNameEvent(this.name);

  @override
  List<Object?> get props => [name];
}

class ClearStoreNameCheckEvent extends RetailerEvent {
  const ClearStoreNameCheckEvent();
}

class LoadRetailerNotificationsEvent extends RetailerEvent {
  const LoadRetailerNotificationsEvent();
}

class MarkRetailerNotificationReadEvent extends RetailerEvent {
  final String notificationId;
  const MarkRetailerNotificationReadEvent(this.notificationId);

  @override
  List<Object?> get props => [notificationId];
}

class MarkAllRetailerNotificationsReadEvent extends RetailerEvent {
  const MarkAllRetailerNotificationsReadEvent();
}

class FetchRetailerSubscriptionEvent extends RetailerEvent {
  const FetchRetailerSubscriptionEvent();
}

class FetchRetailerFinanceSummaryEvent extends RetailerEvent {
  const FetchRetailerFinanceSummaryEvent();
}

class FetchRetailerEarningsListEvent extends RetailerEvent {
  final String? status;
  final int limit;
  final int skip;

  const FetchRetailerEarningsListEvent({
    this.status,
    this.limit = 50,
    this.skip = 0,
  });

  @override
  List<Object?> get props => [status, limit, skip];
}

class FetchRetailerSettlementsEvent extends RetailerEvent {
  final int limit;
  final int skip;

  const FetchRetailerSettlementsEvent({
    this.limit = 50,
    this.skip = 0,
  });

  @override
  List<Object?> get props => [limit, skip];
}

class UpdateRetailerBankAccountEvent extends RetailerEvent {
  final Map<String, dynamic> bankData;

  const UpdateRetailerBankAccountEvent(this.bankData);

  @override
  List<Object?> get props => [bankData];
}

class DismissSubscriptionRequiredSheetEvent extends RetailerEvent {
  const DismissSubscriptionRequiredSheetEvent();
}

class FetchRetailerBannersEvent extends RetailerEvent {
  final bool forceRefresh;
  const FetchRetailerBannersEvent({this.forceRefresh = false});

  @override
  List<Object?> get props => [forceRefresh];
}



