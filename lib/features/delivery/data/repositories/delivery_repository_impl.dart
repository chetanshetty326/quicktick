import 'dart:io';
import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/delivery_api_entities.dart';
import '../../domain/entities/delivery_notification_entity.dart';
import '../../domain/entities/delivery_models.dart';
import '../../domain/entities/rider_wallet_entities.dart';
import '../../domain/entities/doorstep_qr_entity.dart';
import '../../../customer/domain/entities/hero_banner_entity.dart';
import '../../domain/repositories/delivery_repository.dart';
import '../datasources/delivery_remote_data_source.dart';
import '../models/delivery_api_models.dart';

class DeliveryRepositoryImpl implements IDeliveryRepository {
  final IDeliveryRemoteDataSource _remoteDataSource;

  // In-memory cache for fast UI updates & offline fallback
  DeliveryPartnerProfileEntity? _cachedProfile;
  DeliveryEarningsEntity? _cachedEarnings;
  final Map<String, List<DeliveryJobEntity>> _jobsCache = {};

  DeliveryRepositoryImpl(this._remoteDataSource);

  @override
  Future<Either<Failure, DeliveryPartnerProfileEntity>> getProfile() async {
    try {
      final profile = await _remoteDataSource.getProfile();
      _cachedProfile = profile;
      return Right(profile);
    } catch (e) {
      if (e is Failure) {
        if (e.statusCode == 404 || e.message.toLowerCase().contains('not found')) {
          _cachedProfile = null;
        }
        return Left(e);
      }
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, String>> uploadDocument(File file) async {
    try {
      final url = await _remoteDataSource.uploadDocument(file);
      return Right(url);
    } catch (e) {
      if (e is Failure) return Left(e);
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
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
  }) async {
    try {
      final docModels = documents
          .map((d) => DeliveryDocumentModel(
                type: d.type,
                url: d.url,
                number: d.number,
              ))
          .toList();

      final profile = await _remoteDataSource.registerPartner(
        vehicleType: vehicleType,
        vehicleNumber: vehicleNumber,
        vehicleModel: vehicleModel,
        licenseNumber: licenseNumber,
        name: name,
        mobile: mobile,
        email: email,
        houseAddress: houseAddress,
        selfieUrl: selfieUrl,
        latitude: latitude,
        longitude: longitude,
        zoneId: zoneId,
        documents: docModels,
      );
      _cachedProfile = profile;
      return Right(profile);
    } catch (e) {
      if (e is Failure) return Left(e);
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> registerDeviceToken({
    required String deviceToken,
    String platform = 'android',
  }) async {
    try {
      final success = await _remoteDataSource.registerDeviceToken(
        deviceToken: deviceToken,
        platform: platform,
      );
      return Right(success);
    } catch (e) {
      if (e is Failure) return Left(e);
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, DeliveryPartnerProfileEntity>> updateProfile(Map<String, dynamic> data) async {
    try {
      final profile = await _remoteDataSource.updateProfile(data);
      _cachedProfile = profile;
      return Right(profile);
    } catch (e) {
      if (e is Failure) return Left(e);
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, String>> setAvailability(String availability) async {
    try {
      final result = await _remoteDataSource.setAvailability(availability);
      if (_cachedProfile != null) {
        _cachedProfile = _cachedProfile!.copyWith(availability: result);
      }
      return Right(result);
    } catch (e) {
      // Optimistic fallback: assume desired availability if network transient
      if (_cachedProfile != null) {
        _cachedProfile = _cachedProfile!.copyWith(availability: availability);
      }
      if (e is Failure) return Left(e);
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, ({double lat, double lng})>> updateLocation({
    required double lat,
    required double lng,
  }) async {
    try {
      final loc = await _remoteDataSource.updateLocation(lat, lng);
      return Right(loc);
    } catch (e) {
      // Return local coordinate on transient failure
      return Right((lat: lat, lng: lng));
    }
  }

  @override
  Future<Either<Failure, List<DeliveryJobEntity>>> getJobs({String filter = 'all'}) async {
    try {
      final jobs = await _remoteDataSource.getJobs(filter: filter);
      _jobsCache[filter] = jobs;
      return Right(jobs);
    } catch (e) {
      if (_jobsCache.containsKey(filter)) {
        return Right(_jobsCache[filter]!);
      }
      if (e is Failure) return Left(e);
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, DeliveryJobEntity>> getJobDetails(String jobId) async {
    try {
      final job = await _remoteDataSource.getJobDetails(jobId);
      return Right(job);
    } catch (e) {
      if (e is Failure) return Left(e);
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> updateJobStatus({
    required String jobId,
    required String status,
    String? deliveryOtp,
  }) async {
    try {
      final res = await _remoteDataSource.updateJobStatus(
        jobId: jobId,
        status: status,
        deliveryOtp: deliveryOtp,
      );
      return Right(res);
    } catch (e) {
      if (e is Failure) return Left(e);
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, DoorstepQrEntity>> requestDoorstepQr(String orderId, {int? validitySeconds}) async {
    try {
      final res = await _remoteDataSource.requestDoorstepQr(
        orderId: orderId,
        validitySeconds: validitySeconds,
      );
      return Right(res);
    } catch (e) {
      if (e is Failure) return Left(e);
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, QrPaymentStatusEntity>> getQrPaymentStatus(String orderId) async {
    try {
      final res = await _remoteDataSource.getQrPaymentStatus(orderId);
      return Right(res);
    } catch (e) {
      if (e is Failure) return Left(e);
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> reportCodDelivered({
    required String assignmentId,
    required String otpCode,
    required double collectedAmount,
    bool paymentCollected = true,
  }) async {
    try {
      final res = await _remoteDataSource.reportCodDelivered(
        assignmentId: assignmentId,
        otpCode: otpCode,
        collectedAmount: collectedAmount,
        paymentCollected: paymentCollected,
      );
      return Right(res);
    } catch (e) {
      if (e is Failure) return Left(e);
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> rejectJob({
    required String jobId,
    required String reason,
  }) async {
    try {
      final res = await _remoteDataSource.rejectJob(
        jobId: jobId,
        reason: reason,
      );
      return Right(res);
    } catch (e) {
      if (e is Failure) return Left(e);
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, DeliveryEarningsEntity>> getEarnings() async {
    try {
      final earnings = await _remoteDataSource.getEarnings();
      _cachedEarnings = earnings;
      return Right(earnings);
    } catch (e) {
      if (_cachedEarnings != null) {
        return Right(_cachedEarnings!);
      }
      if (e is Failure) return Left(e);
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<EarningsBreakdownRowEntity>>> getEarningsBreakdown({int limit = 50}) async {
    try {
      final breakdown = await _remoteDataSource.getEarningsBreakdown(limit: limit);
      return Right(breakdown);
    } catch (e) {
      if (e is Failure) {
        if (e.statusCode == 404 || e.message.toLowerCase().contains('not found')) {
          return const Right([]);
        }
        return Left(e);
      }
      return const Left(ServerFailure(message: 'Unable to load earnings breakdown. Please try again.'));
    }
  }

  @override
  Future<Either<Failure, CashCollectedSummaryEntity>> getCashCollected() async {
    try {
      final summary = await _remoteDataSource.getCashCollected();
      return Right(summary);
    } catch (e) {
      if (e is Failure) {
        if (e.statusCode == 404 || e.message.toLowerCase().contains('not found')) {
          return const Right(CashCollectedSummaryEntity(
            totalCashCollected: 0.0,
            totalEarnings: 0.0,
            netOwedToCompany: 0.0,
            netOwedByCompany: 0.0,
            cashInHand: 0.0,
            orders: [],
          ));
        }
        return Left(e);
      }
      return const Left(ServerFailure(message: 'Unable to load cash summary. Please try again.'));
    }
  }

  @override
  Future<Either<Failure, List<DeliveryNotificationEntity>>> getNotifications({int page = 1, int limit = 20}) async {
    try {
      final list = await _remoteDataSource.getNotifications(page: page, limit: limit);
      return Right(list);
    } catch (e) {
      if (e is Failure) {
        if (e.statusCode == 404 || e.message.toLowerCase().contains('not found')) {
          return const Right([]);
        }
        return Left(e);
      }
      return const Left(ServerFailure(message: 'Unable to load notifications. Please try again.'));
    }
  }

  @override
  Future<Either<Failure, int>> getUnreadNotificationCount() async {
    try {
      final count = await _remoteDataSource.getUnreadNotificationCount();
      return Right(count);
    } catch (e) {
      if (e is Failure) {
        if (e.statusCode == 404 || e.message.toLowerCase().contains('not found')) {
          return const Right(0);
        }
        return Left(e);
      }
      return const Left(ServerFailure(message: 'Unable to load notification count.'));
    }
  }

  @override
  Future<Either<Failure, bool>> markNotificationAsRead(String id) async {
    try {
      final ok = await _remoteDataSource.markNotificationAsRead(id);
      return Right(ok);
    } catch (e) {
      if (e is Failure) return Left(e);
      return const Left(ServerFailure(message: 'Unable to update notification.'));
    }
  }

  @override
  Future<Either<Failure, bool>> markAllNotificationsAsRead() async {
    try {
      final ok = await _remoteDataSource.markAllNotificationsAsRead();
      return Right(ok);
    } catch (e) {
      if (e is Failure) return Left(e);
      return const Left(ServerFailure(message: 'Unable to update notifications.'));
    }
  }

  @override
  Future<Either<Failure, double>> getWalletBalance() async {
    try {
      final balance = await _remoteDataSource.getWalletBalance();
      return Right(balance);
    } catch (e) {
      if (e is Failure) return Left(e);
      return const Left(ServerFailure(message: 'Unable to retrieve wallet balance.'));
    }
  }

  @override
  Future<Either<Failure, List<DeliveryTransactionEntity>>> getWalletTransactions() async {
    try {
      final txs = await _remoteDataSource.getWalletTransactions();
      return Right(txs);
    } catch (e) {
      if (e is Failure) {
        if (e.statusCode == 404 || e.message.toLowerCase().contains('not found')) {
          return const Right([]);
        }
        return Left(e);
      }
      return const Left(ServerFailure(message: 'Unable to load wallet transactions.'));
    }
  }

  @override
  Future<Either<Failure, List<RiderBankAccountEntity>>> getBankAccounts() async {
    try {
      final accounts = await _remoteDataSource.getBankAccounts();
      return Right(accounts);
    } catch (e) {
      if (e is Failure) {
        if (e.statusCode == 404 || e.message.toLowerCase().contains('not found')) {
          return const Right([]);
        }
        return Left(e);
      }
      return const Left(ServerFailure(message: 'Unable to load bank accounts. Please try again.'));
    }
  }

  @override
  Future<Either<Failure, RiderBankAccountEntity>> addBankAccount(Map<String, dynamic> data) async {
    try {
      final created = await _remoteDataSource.addBankAccount(data);
      return Right(created);
    } catch (e) {
      if (e is Failure) return Left(e);
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> deleteBankAccount(String id) async {
    try {
      final ok = await _remoteDataSource.deleteBankAccount(id);
      return Right(ok);
    } catch (e) {
      if (e is Failure) return Left(e);
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, RiderWithdrawalEntity>> requestWithdrawal({
    required double amount,
    required String bankAccountId,
    String? notes,
  }) async {
    try {
      final withdrawal = await _remoteDataSource.requestWithdrawal(
        amount: amount,
        bankAccountId: bankAccountId,
        notes: notes,
      );
      return Right(withdrawal);
    } catch (e) {
      if (e is Failure) return Left(e);
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<RiderWithdrawalEntity>>> getWithdrawals() async {
    try {
      final withdrawals = await _remoteDataSource.getWithdrawals();
      return Right(withdrawals);
    } catch (e) {
      if (e is Failure) {
        if (e.statusCode == 404 || e.message.toLowerCase().contains('not found')) {
          return const Right([]);
        }
        return Left(e);
      }
      return const Left(ServerFailure(message: 'Unable to load withdrawal history. Please try again.'));
    }
  }

  @override
  Future<Either<Failure, bool>> cancelWithdrawal(String withdrawalId) async {
    try {
      final ok = await _remoteDataSource.cancelWithdrawal(withdrawalId);
      return Right(ok);
    } catch (e) {
      if (e is Failure) return Left(e);
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<HeroBannerEntity>>> getHeroBanners({String app = 'DELIVERY'}) async {
    try {
      final banners = await _remoteDataSource.getHeroBanners(app: app);
      return Right(banners);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to fetch delivery banners: $e'));
    }
  }

  @override
  void clearCache() {
    _cachedProfile = null;
    _cachedEarnings = null;
    _jobsCache.clear();
  }
}
