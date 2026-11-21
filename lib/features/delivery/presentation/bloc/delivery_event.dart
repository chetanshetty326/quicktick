import 'package:equatable/equatable.dart';
import '../../../order/domain/entities/order_entity.dart';
import '../../domain/entities/delivery_models.dart';

abstract class DeliveryEvent extends Equatable {
  const DeliveryEvent();
  @override
  List<Object?> get props => [];
}

class LoadDeliveryDataEvent extends DeliveryEvent {
  final String driverId;
  const LoadDeliveryDataEvent({this.driverId = ''});

  @override
  List<Object?> get props => [driverId];
}

class DeliveryConnectivityChangedEvent extends DeliveryEvent {
  final bool isOnline;
  const DeliveryConnectivityChangedEvent(this.isOnline);

  @override
  List<Object?> get props => [isOnline];
}

class ResetDeliveryStateEvent extends DeliveryEvent {
  const ResetDeliveryStateEvent();
}

class ToggleDutyEvent extends DeliveryEvent {
  final bool isOnline;
  final String reason;
  const ToggleDutyEvent(this.isOnline, {this.reason = 'None'});

  @override
  List<Object?> get props => [isOnline, reason];
}

class SubmitRiderKYCEvent extends DeliveryEvent {
  final RiderKYCEntity kycData;
  const SubmitRiderKYCEvent(this.kycData);

  @override
  List<Object?> get props => [kycData];
}

class VerifyFaceSelfieEvent extends DeliveryEvent {
  final String capturedPhotoPath;
  final bool isMatchConfirmed;
  const VerifyFaceSelfieEvent({
    required this.capturedPhotoPath,
    this.isMatchConfirmed = true,
  });

  @override
  List<Object?> get props => [capturedPhotoPath, isMatchConfirmed];
}

class AcceptDeliveryJobEvent extends DeliveryEvent {
  final String orderId;
  final String driverId;
  final String driverName;
  final String driverPhone;

  const AcceptDeliveryJobEvent({
    required this.orderId,
    this.driverId = '',
    this.driverName = '',
    this.driverPhone = '',
  });

  @override
  List<Object?> get props => [orderId, driverId, driverName, driverPhone];
}

class ApproveRiderKYCEvent extends DeliveryEvent {
  const ApproveRiderKYCEvent();
}

class RejectRiderKYCEvent extends DeliveryEvent {
  final String reason;
  const RejectRiderKYCEvent({this.reason = 'Documents incomplete'});

  @override
  List<Object?> get props => [reason];
}

class DeclineDeliveryJobEvent extends DeliveryEvent {
  final String orderId;
  final String reason;
  const DeclineDeliveryJobEvent(this.orderId, {this.reason = 'Driver Declined'});

  @override
  List<Object?> get props => [orderId, reason];
}

class DismissIncomingJobAlertEvent extends DeliveryEvent {}

class ArrivedAtStoreEvent extends DeliveryEvent {
  final String orderId;
  const ArrivedAtStoreEvent(this.orderId);

  @override
  List<Object?> get props => [orderId];
}

class ToggleItemChecklistEvent extends DeliveryEvent {
  final String itemId;
  const ToggleItemChecklistEvent(this.itemId);

  @override
  List<Object?> get props => [itemId];
}

class MarkPickedUpEvent extends DeliveryEvent {
  final String orderId;
  const MarkPickedUpEvent(this.orderId);

  @override
  List<Object?> get props => [orderId];
}

class MarkOutForDeliveryEvent extends DeliveryEvent {
  final String orderId;
  const MarkOutForDeliveryEvent(this.orderId);

  @override
  List<Object?> get props => [orderId];
}

class ArrivedAtCustomerEvent extends DeliveryEvent {
  final String orderId;
  const ArrivedAtCustomerEvent(this.orderId);

  @override
  List<Object?> get props => [orderId];
}

class VerifyDeliveryOtpEvent extends DeliveryEvent {
  final String orderId;
  final String otp;
  final double collectedAmount;
  final bool paymentCollected;

  const VerifyDeliveryOtpEvent({
    required this.orderId,
    required this.otp,
    this.collectedAmount = 0.0,
    this.paymentCollected = false,
  });

  @override
  List<Object?> get props => [orderId, otp, collectedAmount, paymentCollected];
}

class RequestDoorstepQrEvent extends DeliveryEvent {
  final String orderId;
  final int? validitySeconds;
  const RequestDoorstepQrEvent({required this.orderId, this.validitySeconds});

  @override
  List<Object?> get props => [orderId, validitySeconds];
}

class PollQrPaymentStatusEvent extends DeliveryEvent {
  final String orderId;
  const PollQrPaymentStatusEvent(this.orderId);

  @override
  List<Object?> get props => [orderId];
}

class StopQrPollingEvent extends DeliveryEvent {
  const StopQrPollingEvent();

  @override
  List<Object?> get props => [];
}

class ResetDoorstepQrEvent extends DeliveryEvent {
  const ResetDoorstepQrEvent();

  @override
  List<Object?> get props => [];
}

class RequestInstantUPIPayoutEvent extends DeliveryEvent {
  final double amount;
  final String upiId;
  const RequestInstantUPIPayoutEvent({required this.amount, required this.upiId});

  @override
  List<Object?> get props => [amount, upiId];
}

class DeliveryOrdersStreamUpdated extends DeliveryEvent {
  final List<OrderEntity> orders;
  const DeliveryOrdersStreamUpdated(this.orders);

  @override
  List<Object?> get props => [orders];
}

class DeliverySocketOrderEvent extends DeliveryEvent {
  final Map<String, dynamic> payload;
  const DeliverySocketOrderEvent(this.payload);

  @override
  List<Object?> get props => [payload];
}

class DeliverySocketNotificationEvent extends DeliveryEvent {
  final Map<String, dynamic> payload;
  const DeliverySocketNotificationEvent(this.payload);

  @override
  List<Object?> get props => [payload];
}

class DeliveryPushNotificationReceivedEvent extends DeliveryEvent {
  final Map<String, dynamic> payload;
  const DeliveryPushNotificationReceivedEvent(this.payload);

  @override
  List<Object?> get props => [payload];
}

class FetchDeliveryProfileEvent extends DeliveryEvent {
  const FetchDeliveryProfileEvent();
}

class UpdateLocationPingEvent extends DeliveryEvent {
  final double lat;
  final double lng;
  final int? etaMins;
  const UpdateLocationPingEvent({required this.lat, required this.lng, this.etaMins});

  @override
  List<Object?> get props => [lat, lng, etaMins];
}

class FetchDeliveryJobsEvent extends DeliveryEvent {
  final String filter;
  final bool isBackground;
  const FetchDeliveryJobsEvent({this.filter = 'all', this.isBackground = false});

  @override
  List<Object?> get props => [filter, isBackground];
}

class ClearDeliveryErrorMessageEvent extends DeliveryEvent {
  const ClearDeliveryErrorMessageEvent();

  @override
  List<Object?> get props => [];
}

class FetchDeliveryEarningsEvent extends DeliveryEvent {
  const FetchDeliveryEarningsEvent();
}

class RegisterDeliveryDeviceTokenEvent extends DeliveryEvent {
  final String deviceToken;
  final String platform;
  const RegisterDeliveryDeviceTokenEvent({
    required this.deviceToken,
    this.platform = 'android',
  });

  @override
  List<Object?> get props => [deviceToken, platform];
}

class LoadDeliveryNotificationsEvent extends DeliveryEvent {
  final bool refresh;
  const LoadDeliveryNotificationsEvent({this.refresh = false});

  @override
  List<Object?> get props => [refresh];
}

class MarkDeliveryNotificationReadEvent extends DeliveryEvent {
  final String notificationId;
  const MarkDeliveryNotificationReadEvent(this.notificationId);

  @override
  List<Object?> get props => [notificationId];
}

class MarkAllDeliveryNotificationsReadEvent extends DeliveryEvent {
  const MarkAllDeliveryNotificationsReadEvent();
}

class ToggleCrossZoneScanningEvent extends DeliveryEvent {
  const ToggleCrossZoneScanningEvent();
}

class FetchEarningsBreakdownEvent extends DeliveryEvent {
  final int limit;
  const FetchEarningsBreakdownEvent({this.limit = 50});

  @override
  List<Object?> get props => [limit];
}

class FetchCashCollectedEvent extends DeliveryEvent {
  const FetchCashCollectedEvent();
}

class RemoveExpiredJobEvent extends DeliveryEvent {
  final String jobId;
  const RemoveExpiredJobEvent(this.jobId);

  @override
  List<Object?> get props => [jobId];
}

class FetchWalletDataEvent extends DeliveryEvent {
  const FetchWalletDataEvent();
}

class FetchBankAccountsEvent extends DeliveryEvent {
  const FetchBankAccountsEvent();
}

class AddBankAccountEvent extends DeliveryEvent {
  final Map<String, dynamic> data;
  const AddBankAccountEvent(this.data);

  @override
  List<Object?> get props => [data];
}

class DeleteBankAccountEvent extends DeliveryEvent {
  final String id;
  const DeleteBankAccountEvent(this.id);

  @override
  List<Object?> get props => [id];
}

class RequestWalletWithdrawalEvent extends DeliveryEvent {
  final double amount;
  final String bankAccountId;
  final String? notes;

  const RequestWalletWithdrawalEvent({
    required this.amount,
    required this.bankAccountId,
    this.notes,
  });

  @override
  List<Object?> get props => [amount, bankAccountId, notes];
}

class FetchWithdrawalsEvent extends DeliveryEvent {
  const FetchWithdrawalsEvent();
}

class CancelWithdrawalEvent extends DeliveryEvent {
  final String withdrawalId;
  const CancelWithdrawalEvent(this.withdrawalId);

  @override
  List<Object?> get props => [withdrawalId];
}

class TriggerEmergencySosEvent extends DeliveryEvent {
  final double latitude;
  final double longitude;
  final String? address;
  final String? note;

  const TriggerEmergencySosEvent({
    required this.latitude,
    required this.longitude,
    this.address,
    this.note,
  });

  @override
  List<Object?> get props => [latitude, longitude, address, note];
}

class FetchDeliveryBannersEvent extends DeliveryEvent {
  final bool forceRefresh;
  const FetchDeliveryBannersEvent({this.forceRefresh = false});

  @override
  List<Object?> get props => [forceRefresh];
}

