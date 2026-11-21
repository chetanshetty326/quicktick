import 'dart:io';
import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/delivery_api_entities.dart';
import '../entities/delivery_notification_entity.dart';
import '../entities/delivery_models.dart';
import '../entities/rider_wallet_entities.dart';
import '../entities/doorstep_qr_entity.dart';
import '../../../customer/domain/entities/hero_banner_entity.dart';

abstract class IDeliveryRepository {
  Future<Either<Failure, DeliveryPartnerProfileEntity>> getProfile();
  Future<Either<Failure, String>> uploadDocument(File file);
  Future<Either<Failure, DeliveryPartnerProfileEntity>> registerPartner({
    required String vehicleType,
    required String vehicleNumber,
    required String vehicleModel,
    required String licenseNumber,
    String? name,
    String? mobile,
    String? email,
    String houseAddress = '',
    String selfieUrl = '',
    double? latitude,
    double? longitude,
    String? zoneId,
    required List<DeliveryDocumentEntity> documents,
  });
  Future<Either<Failure, bool>> registerDeviceToken({
    required String deviceToken,
    String platform = 'android',
  });
  Future<Either<Failure, DeliveryPartnerProfileEntity>> updateProfile(Map<String, dynamic> data);
  Future<Either<Failure, String>> setAvailability(String availability);
  Future<Either<Failure, ({double lat, double lng})>> updateLocation({
    required double lat,
    required double lng,
  });
  Future<Either<Failure, List<DeliveryJobEntity>>> getJobs({String filter = 'all'});
  Future<Either<Failure, DeliveryJobEntity>> getJobDetails(String jobId);
  Future<Either<Failure, Map<String, dynamic>>> updateJobStatus({
    required String jobId,
    required String status,
    String? deliveryOtp,
  });
  Future<Either<Failure, DoorstepQrEntity>> requestDoorstepQr(String orderId, {int? validitySeconds}) async =>
      const Left(ServerFailure(message: 'Unimplemented'));
  Future<Either<Failure, QrPaymentStatusEntity>> getQrPaymentStatus(String orderId) async =>
      const Left(ServerFailure(message: 'Unimplemented'));
  Future<Either<Failure, Map<String, dynamic>>> reportCodDelivered({
    required String assignmentId,
    required String otpCode,
    required double collectedAmount,
    bool paymentCollected = true,
  });
  Future<Either<Failure, bool>> rejectJob({
    required String jobId,
    required String reason,
  });
  Future<Either<Failure, DeliveryEarningsEntity>> getEarnings();
  Future<Either<Failure, List<EarningsBreakdownRowEntity>>> getEarningsBreakdown({int limit = 50});
  Future<Either<Failure, CashCollectedSummaryEntity>> getCashCollected();
  Future<Either<Failure, List<DeliveryNotificationEntity>>> getNotifications({int page = 1, int limit = 20});
  Future<Either<Failure, int>> getUnreadNotificationCount();
  Future<Either<Failure, bool>> markNotificationAsRead(String id);
  Future<Either<Failure, bool>> markAllNotificationsAsRead();
  Future<Either<Failure, double>> getWalletBalance();
  Future<Either<Failure, List<DeliveryTransactionEntity>>> getWalletTransactions();
  Future<Either<Failure, List<RiderBankAccountEntity>>> getBankAccounts();
  Future<Either<Failure, RiderBankAccountEntity>> addBankAccount(Map<String, dynamic> data);
  Future<Either<Failure, bool>> deleteBankAccount(String id);
  Future<Either<Failure, RiderWithdrawalEntity>> requestWithdrawal({
    required double amount,
    required String bankAccountId,
    String? notes,
  });
  Future<Either<Failure, List<RiderWithdrawalEntity>>> getWithdrawals();
  Future<Either<Failure, bool>> cancelWithdrawal(String withdrawalId);
  Future<Either<Failure, List<HeroBannerEntity>>> getHeroBanners({String app = 'DELIVERY'});
  void clearCache();
}
