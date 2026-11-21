import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/order_entity.dart';

abstract class IOrderRepository {
  Stream<List<OrderEntity>> get ordersStream;
  Future<Either<Failure, OrderEntity>> createOrder({
    required String customerId,
    required String customerName,
    required String customerPhone,
    required String deliveryAddress,
    required String storeId,
    required String storeName,
    required String storeAddress,
    required List<OrderItemEntity> items,
    required double deliveryFee,
    required double platformFee,
    String paymentMethod = 'COD',
    String? zoneId,
    String? deliveryAddressId,
    String? couponCode,
    double? couponDiscount,
    double? lat,
    double? lng,
    String? city,
    String? postalCode,
    double tip = 0.0,
  });

  Future<Either<Failure, List<OrderEntity>>> getCustomerOrders(String customerId);
  Future<Either<Failure, List<OrderEntity>>> getRetailerOrders(String storeId);
  Future<Either<Failure, List<OrderEntity>>> getDeliveryJobs(String deliveryPartnerId);
  Future<Either<Failure, List<OrderEntity>>> getAvailableDeliveryRequests();

  Future<Either<Failure, OrderEntity>> updateOrderStatus({
    required String orderId,
    required OrderStatus nextStatus,
    String? reason,
  });

  Future<Either<Failure, OrderEntity>> updatePaymentStatus({
    required String orderId,
    required String paymentStatus,
  }) async =>
      const Left(ServerFailure(message: 'Not implemented'));

  Future<Either<Failure, Map<String, dynamic>>> getPaymentStatus(String orderId) async =>
      const Right({});

  Future<Either<Failure, OrderEntity>> assignDeliveryPartner({
    required String orderId,
    required String deliveryPartnerId,
    required String deliveryPartnerName,
    required String deliveryPartnerPhone,
  });

  Future<Either<Failure, OrderEntity>> verifyDeliveryOtp({
    required String orderId,
    required String enteredOtp,
  });

  void clearOrders() {}

  Future<Either<Failure, bool>> cancelOrder(String orderId, String reason);
  Future<Either<Failure, bool>> reviewOrder(String orderId, int storeRating, int deliveryRating, String comment);
  Future<Either<Failure, Map<String, dynamic>>> trackOrder(String orderId);
  Future<Either<Failure, List<OrderEntity>>> getOrdersByStatus(String status) async =>
      const Right([]);
  Future<Either<Failure, List<int>>> downloadOrderInvoice(String orderId) async =>
      const Left(ServerFailure(message: 'Not implemented'));
}
