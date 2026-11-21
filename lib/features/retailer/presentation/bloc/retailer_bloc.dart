import 'dart:async';
import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/errors/failures.dart';
import 'package:dartz/dartz.dart';
import '../../../../core/utils/bloc_event_transformers.dart';
import '../../../customer/domain/entities/catalog_entities.dart';
import '../../../customer/domain/entities/hero_banner_entity.dart';
import '../../../customer/domain/repositories/catalog_repository.dart';
import '../../../order/domain/entities/order_entity.dart';
import '../../../order/domain/repositories/order_repository.dart';
import '../../domain/entities/retailer_entities.dart';
import '../../domain/entities/retailer_finance_entities.dart';
import '../../domain/repositories/retailer_repository.dart';
import '../../data/models/retailer_notification_model.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../../core/services/order_alert_service.dart';
import '../../../../core/services/push_notification_service.dart';
import '../../../../core/services/websocket_service.dart';
import '../../../../core/services/network_connectivity_service.dart';
import '../../../../core/services/in_app_messaging_service.dart';
import 'retailer_event.dart';
import 'retailer_state.dart';

export 'retailer_event.dart';
export 'retailer_state.dart';

class RetailerBloc extends Bloc<RetailerEvent, RetailerState> {
  final IOrderRepository _orderRepo;
  final ICatalogRepository _catalogRepo;
  final IRetailerRepository? _retailerRepo;
  final IWebSocketService? _webSocketService;
  final IPushNotificationService? _pushNotificationService;
  final IInAppMessagingService? _inAppMessagingService;
  StreamSubscription? _orderSub;
  StreamSubscription? _productSub;
  StreamSubscription? _retailerOrderSub;
  StreamSubscription? _retailerProductSub;
  StreamSubscription? _socketOrderSub;
  StreamSubscription? _socketNotifSub;
  StreamSubscription<PushNotificationPayload>? _pushNotifSub;
  StreamSubscription? _connectivitySub;
  Timer? _pollTimer;
  final Map<String, DateTime> _recentNotifSignatures = {};

  RetailerBloc({
    required IOrderRepository orderRepo,
    required ICatalogRepository catalogRepo,
    IRetailerRepository? retailerRepo,
    IWebSocketService? webSocketService,
    IPushNotificationService? pushNotificationService,
    IInAppMessagingService? inAppMessagingService,
    bool enablePeriodicPolling = true,
  })  : _orderRepo = orderRepo,
        _catalogRepo = catalogRepo,
        _retailerRepo = retailerRepo,
        _webSocketService = webSocketService,
        _pushNotificationService = pushNotificationService,
        _inAppMessagingService = inAppMessagingService ?? (sl.isRegistered<IInAppMessagingService>() ? sl<IInAppMessagingService>() : null),
        super(const RetailerState()) {
    on<LoadRetailerDataEvent>(_onLoadData);
    on<PollRetailerOrdersEvent>(_onPollOrders);
    on<AcceptOrderEvent>(_onAcceptOrder, transformer: BlocEventTransformers.droppable());
    on<RejectOrderEvent>(_onRejectOrder, transformer: BlocEventTransformers.droppable());
    on<MarkPreparingEvent>(_onMarkPreparing, transformer: BlocEventTransformers.droppable());
    on<MarkReadyForPickupEvent>(_onMarkReadyForPickup, transformer: BlocEventTransformers.droppable());
    on<ToggleProductStockEvent>(_onToggleProductStock, transformer: BlocEventTransformers.sequential());
    on<ToggleStoreStatusEvent>(_onToggleStoreStatus, transformer: BlocEventTransformers.droppable());
    on<RetailerOrdersStreamUpdated>(_onOrdersStreamUpdated);
    on<RetailerProductsStreamUpdated>(_onProductsStreamUpdated);
    on<AddProductToInventoryEvent>(_onAddProductToInventory, transformer: BlocEventTransformers.sequential());
    on<UpdateProductInInventoryEvent>(_onUpdateProductInInventory, transformer: BlocEventTransformers.sequential());
    on<DeleteProductFromInventoryEvent>(_onDeleteProductFromInventory, transformer: BlocEventTransformers.sequential());
    on<RegisterRetailerStoreEvent>(_onRegisterStore, transformer: BlocEventTransformers.droppable());
    on<UpdateRetailerStoreProfileEvent>(_onUpdateStoreProfile, transformer: BlocEventTransformers.droppable());
    on<RegisterRetailerPushTokenEvent>(_onRegisterPushToken);
    on<RetailerPushNotificationReceivedEvent>(_onPushNotificationReceived);
    on<RetailerSocketOrderStatusChangedEvent>(_onSocketOrderStatusChanged);
    on<RetailerSocketNotificationEvent>(_onSocketNotification);
    on<LoadRetailerProfileEvent>(_onLoadProfile);
    on<LoadRetailerDashboardStatsEvent>(_onLoadDashboardStats);
    on<CheckRetailerStatusEvent>(_onCheckRetailerStatus);
    on<FetchRetailerRejectionEvent>(_onFetchRetailerRejection);
    on<UploadRetailerDocumentEvent>(_onUploadRetailerDocument);
    on<ResetRetailerErrorsEvent>(_onResetErrors);
    on<CheckStoreNameEvent>(_onCheckStoreName, transformer: BlocEventTransformers.restartable());
    on<ClearStoreNameCheckEvent>(_onClearStoreNameCheck);
    on<LoadRetailerNotificationsEvent>(_onLoadNotifications);
    on<MarkRetailerNotificationReadEvent>(_onMarkNotificationRead);
    on<MarkAllRetailerNotificationsReadEvent>(_onMarkAllNotificationsRead);
    on<FetchRetailerSubscriptionEvent>(_onFetchSubscription);
    on<FetchRetailerFinanceSummaryEvent>(_onFetchFinanceSummary);
    on<FetchRetailerEarningsListEvent>(_onFetchEarningsList);
    on<FetchRetailerSettlementsEvent>(_onFetchSettlements);
    on<UpdateRetailerBankAccountEvent>(_onUpdateBankAccount);
    on<FetchRetailerBannersEvent>(_onFetchBanners);
    on<RetailerConnectivityChangedEvent>(_onConnectivityChanged);
    on<DismissSubscriptionRequiredSheetEvent>((event, emit) {
      emit(state.copyWith(showSubscriptionRequiredSheet: false));
    });

    // FIX #4: Only subscribe to ONE stream source to prevent double-firing.
    if (_retailerRepo != null) {
      _retailerOrderSub = _retailerRepo.ordersStream.listen((orders) {
        add(RetailerOrdersStreamUpdated(orders));
      });
      _retailerProductSub = _retailerRepo.productsStream.listen((products) {
        add(RetailerProductsStreamUpdated(products));
      });
    } else {
      _orderSub = _orderRepo.ordersStream.listen((orders) {
        add(RetailerOrdersStreamUpdated(orders));
      });
      _productSub = _catalogRepo.productsStream.listen((products) {
        add(RetailerProductsStreamUpdated(products));
      });
    }

    // Connect WebSocket for instant incoming orders & delivery updates
    final ws = _webSocketService;
    if (ws != null) {
      ws.connect();
      _socketOrderSub = ws.orderStatusStream.listen((data) {
        add(RetailerSocketOrderStatusChangedEvent(data));
      });
      _socketNotifSub = ws.notificationStream.listen((data) {
        add(RetailerSocketNotificationEvent(data));
      });
    }

    // Auto-reconnect & offline listener
    if (sl.isRegistered<INetworkConnectivityService>()) {
      final conn = sl<INetworkConnectivityService>();
      _connectivitySub = conn.onConnectivityChanged.listen((online) {
        add(RetailerConnectivityChangedEvent(online));
      });
    }

    // Live order sync polling every 25 seconds as backup
    if (enablePeriodicPolling) {
      _pollTimer = Timer.periodic(const Duration(seconds: 25), (_) {
        add(const PollRetailerOrdersEvent());
      });
    }

    // Hook Firebase Cloud Messaging (foreground, background tap, and cold-start initial message)
    final push = _pushNotificationService ??
        (sl.isRegistered<IPushNotificationService>() ? sl<IPushNotificationService>() : null);
    if (push != null) {
      _pushNotifSub = push.onNotificationReceived.listen((payload) {
        add(RetailerPushNotificationReceivedEvent(payload.toMap()));
      });
      final pending = push.consumePendingNotification();
      if (pending != null) {
        add(RetailerPushNotificationReceivedEvent(pending.toMap()));
      }
    }
  }

  void _onConnectivityChanged(RetailerConnectivityChangedEvent event, Emitter<RetailerState> emit) {
    final newFailure = event.isOnline ? FailureType.none : FailureType.noInternet;
    emit(state.copyWith(failureType: newFailure));
    if (event.isOnline && (state.isOffline || state.isServerDown)) {
      final storeId = state.profile?.id ?? '';
      add(LoadRetailerDataEvent(storeId: storeId));
    }
  }

  @override
  Future<void> close() {
    OrderAlertService.instance.stopOrderChime();
    _pollTimer?.cancel();
    _connectivitySub?.cancel();
    _orderSub?.cancel();
    _productSub?.cancel();
    _retailerOrderSub?.cancel();
    _retailerProductSub?.cancel();
    _socketOrderSub?.cancel();
    _socketNotifSub?.cancel();
    _pushNotifSub?.cancel();
    return super.close();
  }

  Future<void> _onSocketOrderStatusChanged(RetailerSocketOrderStatusChangedEvent event, Emitter<RetailerState> emit) async {
    final payload = event.payload;
    final orderId = payload['orderId']?.toString() ??
        payload['id']?.toString() ??
        payload['_id']?.toString() ??
        '';
    final newStatusStr = payload['status']?.toString() ?? '';

    if (orderId.isEmpty) {
      // No order ID in payload — fall back to a full poll (rare)
      add(const PollRetailerOrdersEvent());
      return;
    }

    // R-3 Fix: Optimistic update — instantly reflect the status in state without
    // an HTTP call. This eliminates 5+ redundant getLiveOrders() calls during a
    // normal order lifecycle (placed→accepted→preparing→readyForPickup→delivered).
    final newStatus = OrderEntity.parseStatus(newStatusStr);
    final orderExists = state.orders.any((o) => o.id == orderId);
    final updatedOrders = state.orders.map((order) {
      if (order.id == orderId) return order.copyWith(status: newStatus);
      return order;
    }).toList();
    emit(state.copyWith(orders: updatedOrders));
    _checkAndTriggerOrderAlert(updatedOrders);

    // Full HTTP sync only when:
    //  (a) Order not found locally (e.g. first push after app restart), OR
    //  (b) Terminal status — get final enriched snapshot from server.
    final isTerminal = newStatus == OrderStatus.delivered ||
        newStatus == OrderStatus.cancelled ||
        newStatus == OrderStatus.rejected;
    if (!orderExists || isTerminal) {
      add(const PollRetailerOrdersEvent());
    }
  }

  Future<void> _onSocketNotification(RetailerSocketNotificationEvent event, Emitter<RetailerState> emit) async {
    add(RetailerPushNotificationReceivedEvent(event.payload));
  }

  void _checkAndTriggerOrderAlert(List<OrderEntity> orders) {
    final hasPending = orders.any((o) => o.status == OrderStatus.placed);
    if (hasPending) {
      OrderAlertService.instance.startOrderChime();
    } else {
      OrderAlertService.instance.stopOrderChime();
    }
  }

  Future<void> _onPollOrders(PollRetailerOrdersEvent event, Emitter<RetailerState> emit) async {
    if (_webSocketService?.isConnected == false) {
      _webSocketService?.connect();
    }
    if (_retailerRepo != null) {
      final ordersRes = await _retailerRepo.getLiveOrders();
      ordersRes.fold(
        (_) => null,
        (orders) {
          // Always emit — an empty list means all orders are done, which is valid.
          _checkAndTriggerOrderAlert(orders);
          emit(state.copyWith(orders: orders));
        },
      );
    } else {
      // FIX #3: Don't use hardcoded 'store_01' — use the profile ID from state if available
      final storeId = state.profile?.id ?? '';
      if (storeId.isEmpty) return; // No store ID known yet, skip poll
      final ordersRes = await _orderRepo.getRetailerOrders(storeId);
      ordersRes.fold(
        (_) => null,
        (orders) {
          _checkAndTriggerOrderAlert(orders);
          emit(state.copyWith(orders: orders));
        },
      );
    }
  }

  Future<void> _onLoadData(LoadRetailerDataEvent event, Emitter<RetailerState> emit) async {
    _inAppMessagingService?.initialize(role: UserRole.retailer);
    emit(state.copyWith(isLoading: true, clearMessages: true));

    if (_webSocketService?.isConnected == false) {
      _webSocketService?.connect();
    }

    if (_retailerRepo != null) {
      // Auto-register live FCM device token if available
      try {
        final push = _pushNotificationService ??
            (sl.isRegistered<IPushNotificationService>() ? sl<IPushNotificationService>() : null);
        if (push != null) {
          unawaited(() async {
            final token = await push.getDeviceToken();
            if (token != null && token.isNotEmpty && !token.startsWith('fcm_token_')) {
              await push.registerDeviceWithBackend(fcmToken: token, role: UserRole.retailer);
            }
          }());
        } else if (sl.isRegistered<SharedPreferences>()) {
          final prefs = sl<SharedPreferences>();
          final cachedToken = prefs.getString('fcm_device_token');
          if (cachedToken != null && cachedToken.isNotEmpty && !cachedToken.startsWith('fcm_token_')) {
            _retailerRepo.registerDeviceToken(
              fcmToken: cachedToken,
              platform: Platform.isIOS ? 'ios' : 'android',
              deviceId: 'retailer_device_default',
            );
          }
        }
      } catch (_) {}

      // R-1 Fix: True concurrent startup — all 7 calls fire simultaneously.
      // Note: We must type each future individually because Dart erases generics
      // at runtime, making `as Either<A,B>` casts illegal on dynamic results.
      final Future<Either<Failure, List<OrderEntity>>> f0 = _retailerRepo.getLiveOrders();
      final Future<Either<Failure, List<ProductEntity>>> f1 = _retailerRepo.getCatalogItems();
      final Future<Either<Failure, RetailerStoreProfileEntity>> f2 = _retailerRepo.getStoreProfile();
      final Future<Either<Failure, RetailerDashboardStatsEntity>> f3 = _retailerRepo.getDashboardStats();
      final Future<Either<Failure, List<Map<String, dynamic>>>> f4 = _retailerRepo.getNotifications();
      final Future<Either<Failure, int>> f5 = _retailerRepo.getUnreadNotificationCount();
      final Future<Either<Failure, RetailerSubscriptionEntity?>> f6 = _retailerRepo.getSubscription();
      final Future<Either<Failure, RetailerEarningsSummaryEntity>> f7 = _retailerRepo.getEarningsSummary();
      final Future<Either<Failure, List<RetailerSettlementEntity>>> f8 = _retailerRepo.getSettlements();
      final Future<Either<Failure, List<HeroBannerEntity>>> fBanners = _retailerRepo.getHeroBanners(app: 'RETAILER');

      // Await all 10 truly concurrently — no sequential blocking.
      final r0 = await f0;
      final r1 = await f1;
      final r2 = await f2;
      final r3 = await f3;
      final rNotifs = await f4;
      final rUnread = await f5;
      final rSub = await f6;
      final rEarnings = await f7;
      final rSettlements = await f8;
      final rBanners = await fBanners;

      List<OrderEntity> orders = state.orders;
      List<ProductEntity> products = state.storeProducts;
      RetailerStoreProfileEntity? profile = state.profile;
      RetailerDashboardStatsEntity? stats = state.dashboardStats;
      RetailerSubscriptionEntity? sub = state.subscription;
      RetailerEarningsSummaryEntity? earningsSummary = state.earningsSummary;
      List<RetailerSettlementEntity> settlements = state.settlements;
      bool isOpen = state.isStoreOpen;

      if (r0.isRight()) {
        orders = r0.getOrElse(() => []);
      } else {
        final fallback = await _orderRepo.getRetailerOrders(event.storeId);
        fallback.fold((_) => null, (r) => orders = r);
      }

      if (r1.isRight()) {
        products = r1.getOrElse(() => []);
      } else {
        final fallback = await _catalogRepo.getStoreProducts(event.storeId);
        fallback.fold((_) => null, (r) => products = r);
      }

      r2.fold((_) => null, (r) {
        profile = r;
        isOpen = r.isOpen;
      });

      r3.fold((_) => null, (r) => stats = r);
      rSub.fold((_) => sub = RetailerSubscriptionEntity.freeTier, (s) => sub = s ?? RetailerSubscriptionEntity.freeTier);
      rEarnings.fold((_) => null, (s) => earningsSummary = s);
      rSettlements.fold((_) => null, (list) => settlements = list);

      List<Map<String, dynamic>> notifs = state.notifications;
      int unread = state.unreadNotificationsCount;
      rNotifs.fold((_) => null, (list) => notifs = list);
      rUnread.fold((_) => null, (cnt) => unread = cnt);

      List<HeroBannerEntity> heroBanners = state.heroBanners;
      rBanners.fold((_) => null, (list) => heroBanners = list);

      RetailerRegistrationStatus regStatus = state.registrationStatus;
      if (profile != null) {
        if (profile!.isApproved) {
          regStatus = RetailerRegistrationStatus.approved;
        } else if (profile!.isPending) {
          regStatus = RetailerRegistrationStatus.pendingApproval;
        } else if (profile!.isRejected) {
          regStatus = RetailerRegistrationStatus.rejected;
        } else if (profile!.isSuspended) {
          regStatus = RetailerRegistrationStatus.suspended;
        }
      }

      FailureType failureType = FailureType.none;
      if (r0.isLeft()) failureType = r0.fold((l) => l.failureType, (_) => FailureType.none);
      if (failureType == FailureType.none && r1.isLeft()) failureType = r1.fold((l) => l.failureType, (_) => FailureType.none);
      if (failureType == FailureType.none && r2.isLeft()) failureType = r2.fold((l) => l.failureType, (_) => FailureType.none);

      if (sl.isRegistered<INetworkConnectivityService>() &&
          !sl<INetworkConnectivityService>().isConnected) {
        failureType = FailureType.noInternet;
      }

      _checkAndTriggerOrderAlert(orders);
      emit(state.copyWith(
        isLoading: false,
        failureType: failureType,
        orders: orders,
        storeProducts: products,
        profile: profile,
        dashboardStats: stats,
        subscription: sub,
        earningsSummary: earningsSummary,
        settlements: settlements,
        isStoreOpen: isOpen,
        notifications: notifs,
        unreadNotificationsCount: unread,
        registrationStatus: regStatus,
        heroBanners: heroBanners,
      ));
    } else {
      final ordersRes = await _orderRepo.getRetailerOrders(event.storeId);
      final productsRes = await _catalogRepo.getStoreProducts(event.storeId);

      ordersRes.fold(
        (l) => emit(state.copyWith(isLoading: false, errorMessage: l.message)),
        (orders) {
          _checkAndTriggerOrderAlert(orders);
          productsRes.fold(
            (l) => emit(state.copyWith(isLoading: false, orders: orders)),
            (products) => emit(state.copyWith(
              isLoading: false,
              orders: orders,
              storeProducts: products,
            )),
          );
        },
      );
    }
  }

  Future<void> _onRegisterStore(RegisterRetailerStoreEvent event, Emitter<RetailerState> emit) async {
    emit(state.copyWith(
      isLoading: true,
      clearMessages: true,
      clearDuplicateShopNameError: true,
    ));
    if (_retailerRepo != null) {
      final res = await _retailerRepo.registerStore(event.storeData);
      res.fold(
        (l) {
          final isDuplicateName = l is DuplicateResourceFailure ||
              l.message.toLowerCase().contains('shop name');
          final isAlreadyRegistered = l.message.toLowerCase().contains('already registered') ||
              (l is DuplicateResourceFailure && l.code == 'RETAILER_ALREADY_REGISTERED');
          if (isDuplicateName && !isAlreadyRegistered) {
            emit(state.copyWith(
              isLoading: false,
              duplicateShopNameError: 'Shop name already taken. Please choose another shop name.',
              errorMessage: 'Shop name already taken. Please choose another shop name.',
            ));
          } else if (isAlreadyRegistered) {
            emit(state.copyWith(
              isLoading: false,
              errorMessage: null,
            ));
            add(const CheckRetailerStatusEvent());
          } else {
            emit(state.copyWith(
              isLoading: false,
              errorMessage: l.message,
            ));
          }
        },
        (profile) => emit(state.copyWith(
          isLoading: false,
          profile: profile,
          registrationStatus: RetailerRegistrationStatus.pendingApproval,
          registeredShopName: profile.storeName,
          successMessage: 'Store registered successfully! Awaiting approval.',
        )),
      );
    } else {
      emit(state.copyWith(
        isLoading: false,
        registrationStatus: RetailerRegistrationStatus.pendingApproval,
        successMessage: 'Store registered successfully! Awaiting approval.',
      ));
    }
  }

  Future<void> _onCheckRetailerStatus(CheckRetailerStatusEvent event, Emitter<RetailerState> emit) async {
    emit(state.copyWith(
      registrationStatus: RetailerRegistrationStatus.checking,
      clearMessages: true,
    ));
    if (_retailerRepo != null) {
      final res = await _retailerRepo.checkRetailerRegistration();
      await res.fold(
        (l) async {
          final fallbackStatus = (state.profile != null || state.registrationStatus == RetailerRegistrationStatus.approved)
              ? RetailerRegistrationStatus.approved
              : (l.statusCode == 404 ? RetailerRegistrationStatus.notRegistered : RetailerRegistrationStatus.approved);
          emit(state.copyWith(
            registrationStatus: fallbackStatus,
            failureType: l.failureType,
            errorMessage: l.message,
          ));
        },
        (check) async {
          if (!check.registered) {
            emit(state.copyWith(
              registrationStatus: RetailerRegistrationStatus.notRegistered,
              registeredShopName: null,
            ));
          } else {
            final statusStr = (check.status ?? 'PENDING').toUpperCase();
            if (statusStr == 'APPROVED') {
              emit(state.copyWith(
                registrationStatus: RetailerRegistrationStatus.approved,
                registeredShopName: check.shopName,
              ));
            } else if (statusStr == 'PENDING') {
              emit(state.copyWith(
                registrationStatus: RetailerRegistrationStatus.pendingApproval,
                registeredShopName: check.shopName,
              ));
            } else if (statusStr == 'SUSPENDED') {
              emit(state.copyWith(
                registrationStatus: RetailerRegistrationStatus.suspended,
                registeredShopName: check.shopName,
              ));
            } else if (statusStr == 'REJECTED') {
              emit(state.copyWith(
                registrationStatus: RetailerRegistrationStatus.rejected,
                registeredShopName: check.shopName,
                rejectionRemarks: check.remarks,
              ));
              // Fetch rejected documents itemization
              add(const FetchRetailerRejectionEvent());
            } else {
              emit(state.copyWith(
                registrationStatus: RetailerRegistrationStatus.pendingApproval,
                registeredShopName: check.shopName,
              ));
            }
          }
        },
      );
    } else {
      emit(state.copyWith(registrationStatus: RetailerRegistrationStatus.approved));
    }
  }

  Future<void> _onFetchRetailerRejection(FetchRetailerRejectionEvent event, Emitter<RetailerState> emit) async {
    if (_retailerRepo != null) {
      final res = await _retailerRepo.getRejectionReason();
      res.fold(
        (_) => null,
        (rejection) {
          emit(state.copyWith(
            rejectionRemarks: rejection.remarks ?? state.rejectionRemarks,
            rejectedDocuments: rejection.rejectedDocuments,
          ));
        },
      );
    }
  }

  Future<void> _onUploadRetailerDocument(UploadRetailerDocumentEvent event, Emitter<RetailerState> emit) async {
    emit(state.copyWith(isUploadingDoc: true, clearUploadDocError: true));
    if (_retailerRepo != null) {
      final res = await _retailerRepo.uploadDocument(
        event.filePath,
        folder: event.folder ?? 'quickclick/documents',
      );
      res.fold(
        (l) => emit(state.copyWith(
          isUploadingDoc: false,
          uploadDocError: l.message,
        )),
        (upload) {
          final updated = Map<String, String>.from(state.uploadedDocUrls);
          updated[event.docType] = upload.url;
          emit(state.copyWith(
            isUploadingDoc: false,
            uploadedDocUrls: updated,
            successMessage: '${event.docType} uploaded successfully!',
          ));
        },
      );
    } else {
      emit(state.copyWith(isUploadingDoc: false));
    }
  }

  void _onResetErrors(ResetRetailerErrorsEvent event, Emitter<RetailerState> emit) {
    emit(state.copyWith(
      clearMessages: true,
      clearDuplicateShopNameError: true,
      clearUploadDocError: true,
    ));
  }

  Future<void> _onUpdateStoreProfile(UpdateRetailerStoreProfileEvent event, Emitter<RetailerState> emit) async {
    emit(state.copyWith(isLoading: true, clearMessages: true));
    if (_retailerRepo != null) {
      final res = await _retailerRepo.updateStoreProfile(event.storeData);
      res.fold(
        (l) => emit(state.copyWith(isLoading: false, errorMessage: l.message)),
        (profile) => emit(state.copyWith(
          isLoading: false,
          profile: profile,
          successMessage: 'Store details updated successfully!',
        )),
      );
    } else {
      emit(state.copyWith(isLoading: false, successMessage: 'Store details updated successfully!'));
    }
  }

  Future<void> _onLoadProfile(LoadRetailerProfileEvent event, Emitter<RetailerState> emit) async {
    if (_retailerRepo != null) {
      final res = await _retailerRepo.getStoreProfile();
      res.fold(
        (l) => emit(state.copyWith(errorMessage: l.message)),
        (profile) => emit(state.copyWith(profile: profile, isStoreOpen: profile.isOpen)),
      );
    }
  }

  Future<void> _onLoadDashboardStats(LoadRetailerDashboardStatsEvent event, Emitter<RetailerState> emit) async {
    if (_retailerRepo != null) {
      final res = await _retailerRepo.getDashboardStats();
      res.fold(
        (l) => emit(state.copyWith(errorMessage: l.message)),
        (stats) => emit(state.copyWith(dashboardStats: stats)),
      );
    }
  }

  Future<void> _onAddProductToInventory(AddProductToInventoryEvent event, Emitter<RetailerState> emit) async {
    emit(state.copyWith(isLoading: true, clearMessages: true));
    if (_retailerRepo != null) {
      final res = await _retailerRepo.addProduct(event.product);
      res.fold(
        (l) => emit(state.copyWith(isLoading: false, errorMessage: l.message)),
        (product) {
          final updated = List<ProductEntity>.from(state.storeProducts);
          final existingIdx = updated.indexWhere((p) => p.id == product.id);
          if (existingIdx >= 0) {
            updated[existingIdx] = product;
          } else {
            updated.insert(0, product);
          }
          emit(state.copyWith(
            isLoading: false,
            storeProducts: updated,
            successMessage: '${product.name} added to inventory!',
          ));
        },
      );
    } else {
      final res = await _catalogRepo.addProduct(event.product);
      res.fold(
        (l) => emit(state.copyWith(isLoading: false, errorMessage: l.message)),
        (product) {
          final updated = List<ProductEntity>.from(state.storeProducts);
          final existingIdx = updated.indexWhere((p) => p.id == product.id);
          if (existingIdx >= 0) {
            updated[existingIdx] = product;
          } else {
            updated.insert(0, product);
          }
          emit(state.copyWith(
            isLoading: false,
            storeProducts: updated,
            successMessage: '${product.name} added to inventory!',
          ));
        },
      );
    }
  }

  Future<void> _onUpdateProductInInventory(UpdateProductInInventoryEvent event, Emitter<RetailerState> emit) async {
    emit(state.copyWith(isLoading: true, clearMessages: true));
    if (_retailerRepo != null) {
      final res = await _retailerRepo.updateProduct(event.product);
      res.fold(
        (l) => emit(state.copyWith(isLoading: false, errorMessage: l.message)),
        (product) {
          final updated = List<ProductEntity>.from(state.storeProducts);
          final finalProduct = product.copyWith(
            id: product.id.isNotEmpty ? product.id : event.product.id,
            imageUrl: product.imageUrl.isNotEmpty && !product.imageUrl.contains('photo-1550583724-b2692b85b150')
                ? product.imageUrl
                : event.product.imageUrl,
          );
          final idx = updated.indexWhere((p) => p.id == product.id || p.id == event.product.id);
          if (idx != -1) {
            updated[idx] = finalProduct;
          } else {
            updated.add(finalProduct);
          }
          emit(state.copyWith(
            isLoading: false,
            storeProducts: updated,
            successMessage: '${finalProduct.name} updated successfully!',
          ));
        },
      );
    } else {
      final res = await _catalogRepo.updateProduct(event.product);
      res.fold(
        (l) => emit(state.copyWith(isLoading: false, errorMessage: l.message)),
        (product) {
          final updated = List<ProductEntity>.from(state.storeProducts);
          final finalProduct = product.copyWith(
            id: product.id.isNotEmpty ? product.id : event.product.id,
            imageUrl: product.imageUrl.isNotEmpty && !product.imageUrl.contains('photo-1550583724-b2692b85b150')
                ? product.imageUrl
                : event.product.imageUrl,
          );
          final idx = updated.indexWhere((p) => p.id == product.id || p.id == event.product.id);
          if (idx != -1) {
            updated[idx] = finalProduct;
          } else {
            updated.add(finalProduct);
          }
          emit(state.copyWith(
            isLoading: false,
            storeProducts: updated,
            successMessage: '${finalProduct.name} updated successfully!',
          ));
        },
      );
    }
  }

  Future<void> _onDeleteProductFromInventory(DeleteProductFromInventoryEvent event, Emitter<RetailerState> emit) async {
    emit(state.copyWith(isLoading: true, clearMessages: true));
    if (_retailerRepo != null) {
      final res = await _retailerRepo.deleteProduct(event.productId);
      res.fold(
        (l) => emit(state.copyWith(isLoading: false, errorMessage: l.message)),
        (_) {
          final updated = List<ProductEntity>.from(state.storeProducts)
            ..removeWhere((p) => p.id == event.productId);
          emit(state.copyWith(
            isLoading: false,
            storeProducts: updated,
            successMessage: '${event.productName} removed from inventory',
          ));
        },
      );
    } else {
      final res = await _catalogRepo.deleteProduct(event.productId);
      res.fold(
        (l) => emit(state.copyWith(isLoading: false, errorMessage: l.message)),
        (_) {
          final updated = List<ProductEntity>.from(state.storeProducts)
            ..removeWhere((p) => p.id == event.productId);
          emit(state.copyWith(
            isLoading: false,
            storeProducts: updated,
            successMessage: '${event.productName} removed from inventory',
          ));
        },
      );
    }
  }

  Future<void> _onAcceptOrder(AcceptOrderEvent event, Emitter<RetailerState> emit) async {
    OrderAlertService.instance.stopOrderChime();
    if (state.subscription?.isExpired == true) {
      emit(state.copyWith(
        showSubscriptionRequiredSheet: true,
        errorMessage: 'Active subscription required to accept orders. Please renew your plan.',
      ));
      return;
    }
    if (_retailerRepo != null) {
      final res = await _retailerRepo.acceptOrder(event.orderId);
      res.fold(
        (l) {
          final isSubReq = l.message.toUpperCase().contains('SUBSCRIPTION_REQUIRED') ||
              l.message.toUpperCase().contains('SUBSCRIPTION') ||
              (l is ServerFailure && l.statusCode == 403);
          emit(state.copyWith(
            errorMessage: l.message,
            showSubscriptionRequiredSheet: isSubReq,
          ));
        },
        (r) {
          _webSocketService?.emitOrderStatus(orderId: event.orderId, status: 'ACCEPTED');
          final updated = state.orders.map((o) {
            if (o.id == event.orderId || o.id == r.id) {
              return o.copyWith(status: OrderStatus.accepted);
            }
            return o;
          }).toList();
          _checkAndTriggerOrderAlert(updated);
          _inAppMessagingService?.triggerEvent(IInAppMessagingService.retailerOrderAccepted);
          emit(state.copyWith(
            orders: updated,
            successMessage: 'Order #${r.orderNumber.isNotEmpty ? r.orderNumber : ''} Accepted',
          ));
        },
      );
    } else {
      final res = await _orderRepo.updateOrderStatus(
        orderId: event.orderId,
        nextStatus: OrderStatus.accepted,
      );
      res.fold(
        (l) {
          final isSubReq = l.message.toUpperCase().contains('SUBSCRIPTION_REQUIRED') ||
              l.message.toUpperCase().contains('SUBSCRIPTION') ||
              (l is ServerFailure && l.statusCode == 403);
          emit(state.copyWith(
            errorMessage: l.message,
            showSubscriptionRequiredSheet: isSubReq,
          ));
        },
        (r) {
          final updated = state.orders.map((o) {
            if (o.id == event.orderId || o.id == r.id) {
              return o.copyWith(status: OrderStatus.accepted);
            }
            return o;
          }).toList();
          _checkAndTriggerOrderAlert(updated);
          _inAppMessagingService?.triggerEvent(IInAppMessagingService.retailerOrderAccepted);
          emit(state.copyWith(
            orders: updated,
            successMessage: 'Order #${r.orderNumber.isNotEmpty ? r.orderNumber : ''} Accepted',
          ));
        },
      );
    }
  }

  Future<void> _onRejectOrder(RejectOrderEvent event, Emitter<RetailerState> emit) async {
    OrderAlertService.instance.stopOrderChime();
    if (_retailerRepo != null) {
      final res = await _retailerRepo.rejectOrder(event.orderId, event.reason);
      res.fold(
        (l) => emit(state.copyWith(errorMessage: l.message)),
        (r) {
          _webSocketService?.emitOrderStatus(orderId: event.orderId, status: 'REJECTED');
          final updated = state.orders.where((o) => o.id != event.orderId && o.id != r.id).toList();
          _checkAndTriggerOrderAlert(updated);
          emit(state.copyWith(
            orders: updated,
            successMessage: 'Order #${r.orderNumber.isNotEmpty ? r.orderNumber : ''} Rejected',
          ));
        },
      );
    } else {
      final res = await _orderRepo.updateOrderStatus(
        orderId: event.orderId,
        nextStatus: OrderStatus.rejected,
        reason: event.reason,
      );
      res.fold(
        (l) => emit(state.copyWith(errorMessage: l.message)),
        (r) {
          final updated = state.orders.where((o) => o.id != event.orderId && o.id != r.id).toList();
          _checkAndTriggerOrderAlert(updated);
          emit(state.copyWith(
            orders: updated,
            successMessage: 'Order #${r.orderNumber.isNotEmpty ? r.orderNumber : ''} Rejected',
          ));
        },
      );
    }
  }

  Future<void> _onMarkPreparing(MarkPreparingEvent event, Emitter<RetailerState> emit) async {
    if (state.subscription?.isExpired == true) {
      emit(state.copyWith(
        showSubscriptionRequiredSheet: true,
        errorMessage: 'Active subscription required to prepare orders. Please renew your plan.',
      ));
      return;
    }
    if (_retailerRepo != null) {
      final res = await _retailerRepo.markPreparing(event.orderId);
      res.fold(
        (l) {
          final isSubReq = l.message.toUpperCase().contains('SUBSCRIPTION_REQUIRED') ||
              l.message.toUpperCase().contains('SUBSCRIPTION') ||
              (l is ServerFailure && l.statusCode == 403);
          emit(state.copyWith(
            errorMessage: l.message,
            showSubscriptionRequiredSheet: isSubReq,
          ));
        },
        (r) {
          _webSocketService?.emitOrderStatus(orderId: event.orderId, status: 'PREPARING');
          final updated = state.orders.map((o) {
            if (o.id == event.orderId || o.id == r.id) {
              return o.copyWith(status: OrderStatus.preparing);
            }
            return o;
          }).toList();
          emit(state.copyWith(
            orders: updated,
            successMessage: 'Order #${r.orderNumber.isNotEmpty ? r.orderNumber : ''} is Preparing',
          ));
        },
      );
    } else {
      final res = await _orderRepo.updateOrderStatus(
        orderId: event.orderId,
        nextStatus: OrderStatus.preparing,
      );
      res.fold(
        (l) {
          final isSubReq = l.message.toUpperCase().contains('SUBSCRIPTION_REQUIRED') ||
              l.message.toUpperCase().contains('SUBSCRIPTION') ||
              (l is ServerFailure && l.statusCode == 403);
          emit(state.copyWith(
            errorMessage: l.message,
            showSubscriptionRequiredSheet: isSubReq,
          ));
        },
        (r) {
          final updated = state.orders.map((o) {
            if (o.id == event.orderId || o.id == r.id) {
              return o.copyWith(status: OrderStatus.preparing);
            }
            return o;
          }).toList();
          emit(state.copyWith(
            orders: updated,
            successMessage: 'Order #${r.orderNumber.isNotEmpty ? r.orderNumber : ''} is Preparing',
          ));
        },
      );
    }
  }

  Future<void> _onMarkReadyForPickup(MarkReadyForPickupEvent event, Emitter<RetailerState> emit) async {
    if (state.subscription?.isExpired == true) {
      emit(state.copyWith(
        showSubscriptionRequiredSheet: true,
        errorMessage: 'Active subscription required to dispatch orders. Please renew your plan.',
      ));
      return;
    }
    if (_retailerRepo != null) {
      final res = await _retailerRepo.markReady(event.orderId);
      res.fold(
        (l) {
          final isSubReq = l.message.toUpperCase().contains('SUBSCRIPTION_REQUIRED') ||
              l.message.toUpperCase().contains('SUBSCRIPTION') ||
              (l is ServerFailure && l.statusCode == 403);
          emit(state.copyWith(
            errorMessage: l.message,
            showSubscriptionRequiredSheet: isSubReq,
          ));
        },
        (r) {
          _webSocketService?.emitOrderStatus(orderId: event.orderId, status: 'READY_FOR_PICKUP');
          final updated = state.orders.map((o) {
            if (o.id == event.orderId || o.id == r.id) {
              return o.copyWith(status: OrderStatus.readyForPickup);
            }
            return o;
          }).toList();
          _inAppMessagingService?.triggerEvent(IInAppMessagingService.retailerOrderReady);
          emit(state.copyWith(
            orders: updated,
            successMessage: 'Order #${r.orderNumber.isNotEmpty ? r.orderNumber : ''} Ready for Rider!',
          ));
        },
      );
    } else {
      final res = await _orderRepo.updateOrderStatus(
        orderId: event.orderId,
        nextStatus: OrderStatus.readyForPickup,
      );
      res.fold(
        (l) {
          final isSubReq = l.message.toUpperCase().contains('SUBSCRIPTION_REQUIRED') ||
              l.message.toUpperCase().contains('SUBSCRIPTION') ||
              (l is ServerFailure && l.statusCode == 403);
          emit(state.copyWith(
            errorMessage: l.message,
            showSubscriptionRequiredSheet: isSubReq,
          ));
        },
        (r) {
          final updated = state.orders.map((o) {
            if (o.id == event.orderId || o.id == r.id) {
              return o.copyWith(status: OrderStatus.readyForPickup);
            }
            return o;
          }).toList();
          _inAppMessagingService?.triggerEvent(IInAppMessagingService.retailerOrderReady);
          emit(state.copyWith(
            orders: updated,
            successMessage: 'Order #${r.orderNumber.isNotEmpty ? r.orderNumber : ''} Ready for Rider!',
          ));
        },
      );
    }
  }

  Future<void> _onToggleProductStock(ToggleProductStockEvent event, Emitter<RetailerState> emit) async {
    if (_retailerRepo != null) {
      final res = await _retailerRepo.toggleProductStock(
        event.productId,
        event.isAvailable,
        currentStock: event.currentStock,
      );
      res.fold(
        (l) => emit(state.copyWith(errorMessage: l.message)),
        (r) {
          final updated = state.storeProducts.map((p) {
            if (p.id == event.productId) {
              final newStock = event.isAvailable
                  ? ((event.currentStock != null && event.currentStock! > 0)
                      ? event.currentStock!
                      : (p.stock > 0 ? p.stock : 10))
                  : 0;
              return p.copyWith(
                stock: newStock,
                isAvailable: event.isAvailable,
              );
            }
            return p;
          }).toList();
          _inAppMessagingService?.triggerEvent(IInAppMessagingService.retailerStockToggled);
          emit(state.copyWith(
            storeProducts: updated,
            successMessage: 'Product stock status updated to ${event.isAvailable ? "In Stock" : "Out of Stock"}',
          ));
        },
      );
    } else {
      final res = await _catalogRepo.toggleProductStock(event.productId, event.isAvailable);
      res.fold(
        (l) => emit(state.copyWith(errorMessage: l.message)),
        (r) {
          final updated = state.storeProducts.map((p) {
            if (p.id == event.productId) {
              final newStock = event.isAvailable
                  ? ((event.currentStock != null && event.currentStock! > 0)
                      ? event.currentStock!
                      : (p.stock > 0 ? p.stock : 10))
                  : 0;
              return p.copyWith(
                stock: newStock,
                isAvailable: event.isAvailable,
              );
            }
            return p;
          }).toList();
          _inAppMessagingService?.triggerEvent(IInAppMessagingService.retailerStockToggled);
          emit(state.copyWith(
            storeProducts: updated,
            successMessage: 'Product stock status updated to ${event.isAvailable ? "In Stock" : "Out of Stock"}',
          ));
        },
      );
    }
  }

  Future<void> _onToggleStoreStatus(ToggleStoreStatusEvent event, Emitter<RetailerState> emit) async {
    if (_retailerRepo != null) {
      final res = await _retailerRepo.toggleStoreStatus(event.isOpen);
      // R-4 Fix: Only sync catalog AFTER the primary retailer toggle succeeds.
      // Previously the catalog sync fired regardless of whether the API returned
      // a Left (failure), causing the catalog to show the wrong open/closed state.
      await res.fold(
        (l) async => emit(state.copyWith(errorMessage: l.message)),
        (r) async {
          // Catalog sync is best-effort; use try/catch so errors don't
          // bubble up (avoids return-type mismatch from catchError).
          try {
            await _catalogRepo.toggleStoreOpenStatus(event.storeId, event.isOpen);
          } catch (_) {}
          if (event.isOpen && _webSocketService?.isConnected == false) {
            _webSocketService?.connect();
          }
          emit(state.copyWith(
            isStoreOpen: event.isOpen,
            successMessage: event.isOpen ? 'Store is now OPEN for orders' : 'Store is now CLOSED',
          ));
        },
      );
    } else {
      final res = await _catalogRepo.toggleStoreOpenStatus(event.storeId, event.isOpen);
      res.fold(
        (l) => emit(state.copyWith(errorMessage: l.message)),
        (r) => emit(state.copyWith(
          isStoreOpen: event.isOpen,
          successMessage: event.isOpen ? 'Store is now OPEN for orders' : 'Store is now CLOSED',
        )),
      );
    }
  }

  void _onOrdersStreamUpdated(RetailerOrdersStreamUpdated event, Emitter<RetailerState> emit) {
    _checkAndTriggerOrderAlert(event.orders);
    emit(state.copyWith(orders: event.orders));
  }

  void _onProductsStreamUpdated(RetailerProductsStreamUpdated event, Emitter<RetailerState> emit) {
    emit(state.copyWith(storeProducts: event.products));
  }

  Future<void> _onRegisterPushToken(RegisterRetailerPushTokenEvent event, Emitter<RetailerState> emit) async {
    if (_retailerRepo != null) {
      await _retailerRepo.registerDeviceToken(
        fcmToken: event.fcmToken,
        platform: event.platform,
        deviceId: event.deviceId ?? 'device_${DateTime.now().millisecondsSinceEpoch % 100000}',
      );
    }
  }

  Future<void> _onPushNotificationReceived(RetailerPushNotificationReceivedEvent event, Emitter<RetailerState> emit) async {
    final rawPayload = Map<String, dynamic>.from(event.notificationPayload);
    final fromTap = rawPayload['fromTap'] == true;
    final model = RetailerNotificationModel.fromJson(rawPayload);
    final notifMap = model.toMap();
    final rawId = notifMap['id']?.toString() ?? notifMap['_id']?.toString();
    final title = notifMap['title']?.toString() ?? '';
    final body = notifMap['body']?.toString() ?? notifMap['message']?.toString() ?? '';
    final signature = '$title|$body|${rawPayload['orderId'] ?? ''}';
    final now = DateTime.now();
    final lastSeen = _recentNotifSignatures[signature];
    final isRecentDuplicate = lastSeen != null && now.difference(lastSeen) < const Duration(seconds: 10);

    if (!fromTap && isRecentDuplicate) {
      return;
    }
    _recentNotifSignatures[signature] = now;

    final updatedNotifs = List<Map<String, dynamic>>.from(state.notifications);
    final alreadyStoredById = rawId != null &&
        rawId.isNotEmpty &&
        updatedNotifs.any((n) => (n['id']?.toString() ?? n['_id']?.toString()) == rawId);
    if (!alreadyStoredById && !isRecentDuplicate) {
      if (fromTap) {
        notifMap['read'] = true;
        notifMap['isRead'] = true;
      }
      updatedNotifs.insert(0, notifMap);
    }
    final newUnread = updatedNotifs.where((n) => n['read'] != true && n['isRead'] != true).length;
    emit(state.copyWith(
      latestPushNotification: <String, dynamic>{...notifMap, ...rawPayload},
      notifications: updatedNotifs,
      unreadNotificationsCount: newUnread,
      successMessage: fromTap ? null : '🔔 New Notification: ${notifMap['title'] ?? 'Alert'}',
    ));

    // When an incoming order or status update push is received, fetch fresh live orders immediately
    final type = (notifMap['type']?.toString() ?? rawPayload['type']?.toString() ?? '').toUpperCase();
    final hasOrder = type.contains('ORDER') ||
        type.contains('NEW_ORDER') ||
        (rawPayload['orderId']?.toString().isNotEmpty ?? false);
    if (hasOrder) {
      if (_retailerRepo != null) {
        final res = await _retailerRepo.getLiveOrders();
        res.fold((_) => null, (orders) {
          _checkAndTriggerOrderAlert(orders);
          emit(state.copyWith(orders: orders));
        });
      } else {
        add(const PollRetailerOrdersEvent());
      }
    }
  }

  Future<void> _onLoadNotifications(LoadRetailerNotificationsEvent event, Emitter<RetailerState> emit) async {
    if (_retailerRepo != null) {
      // R-2 Fix: run both calls in parallel \u2014 independent endpoints, no sequential blocking.
      // Typed futures used directly (Dart erases generics at runtime so Future.wait<dynamic>
      // cannot be cast back to Either<A,B> safely).
      final Future<Either<Failure, List<Map<String, dynamic>>>> fNotifs = _retailerRepo.getNotifications();
      final Future<Either<Failure, int>> fUnread = _retailerRepo.getUnreadNotificationCount();
      final notifsRes = await fNotifs;
      final unreadRes = await fUnread;
      List<Map<String, dynamic>> notifs = state.notifications;
      int unread = state.unreadNotificationsCount;
      notifsRes.fold((_) => null, (list) => notifs = list);
      unreadRes.fold((_) => null, (cnt) => unread = cnt);
      final actualUnread = notifs.where((n) => n['read'] != true && n['isRead'] != true).length;
      if (actualUnread > 0 || unread == 0) {
        unread = actualUnread;
      }
      emit(state.copyWith(notifications: notifs, unreadNotificationsCount: unread));
    }
  }

  Future<void> _onMarkNotificationRead(MarkRetailerNotificationReadEvent event, Emitter<RetailerState> emit) async {
    if (_retailerRepo != null) {
      await _retailerRepo.markNotificationRead(event.notificationId);
      final updatedNotifs = state.notifications.map((n) {
        if (n['id'] == event.notificationId || n['_id'] == event.notificationId) {
          return {...n, 'read': true, 'isRead': true};
        }
        return n;
      }).toList();
      final newUnread = updatedNotifs.where((n) => n['read'] != true && n['isRead'] != true).length;
      emit(state.copyWith(notifications: updatedNotifs, unreadNotificationsCount: newUnread));
    }
  }

  Future<void> _onMarkAllNotificationsRead(MarkAllRetailerNotificationsReadEvent event, Emitter<RetailerState> emit) async {
    if (_retailerRepo != null) {
      await _retailerRepo.markAllNotificationsRead();
      final updatedNotifs = state.notifications.map((n) {
        return {...n, 'read': true, 'isRead': true};
      }).toList();
      emit(state.copyWith(notifications: updatedNotifs, unreadNotificationsCount: 0));
    }
  }

  Future<void> _onCheckStoreName(CheckStoreNameEvent event, Emitter<RetailerState> emit) async {
    final name = event.name.trim();
    if (name.isEmpty) {
      emit(state.copyWith(
        isCheckingStoreName: false,
        clearStoreNameAvailable: true,
        clearStoreNameCheckMessage: true,
      ));
      return;
    }

    emit(state.copyWith(
      isCheckingStoreName: true,
      clearStoreNameAvailable: true,
      clearStoreNameCheckMessage: true,
    ));

    if (_retailerRepo != null) {
      final res = await _retailerRepo.checkStoreName(name);
      res.fold(
        (failure) {
          emit(state.copyWith(
            isCheckingStoreName: false,
            isStoreNameAvailable: null,
            storeNameCheckMessage: failure.message,
          ));
        },
        (result) {
          emit(state.copyWith(
            isCheckingStoreName: false,
            isStoreNameAvailable: result.available,
            storeNameCheckMessage: result.message,
          ));
        },
      );
    } else {
      emit(state.copyWith(
        isCheckingStoreName: false,
        isStoreNameAvailable: true,
        storeNameCheckMessage: 'Store name is available',
      ));
    }
  }

  void _onClearStoreNameCheck(ClearStoreNameCheckEvent event, Emitter<RetailerState> emit) {
    emit(state.copyWith(
      isCheckingStoreName: false,
      clearStoreNameAvailable: true,
      clearStoreNameCheckMessage: true,
    ));
  }

  Future<void> _onFetchSubscription(FetchRetailerSubscriptionEvent event, Emitter<RetailerState> emit) async {
    if (_retailerRepo == null) return;
    emit(state.copyWith(isLoadingSubscription: true));
    final res = await _retailerRepo.getSubscription();
    res.fold(
      (_) => emit(state.copyWith(
        isLoadingSubscription: false,
        subscription: RetailerSubscriptionEntity.freeTier,
      )),
      (sub) => emit(state.copyWith(
        isLoadingSubscription: false,
        subscription: sub ?? RetailerSubscriptionEntity.freeTier,
      )),
    );
  }

  Future<void> _onFetchFinanceSummary(FetchRetailerFinanceSummaryEvent event, Emitter<RetailerState> emit) async {
    if (_retailerRepo == null) return;
    emit(state.copyWith(isLoadingFinance: true));
    final res = await _retailerRepo.getEarningsSummary();
    res.fold(
      (failure) => emit(state.copyWith(
        isLoadingFinance: false,
        financeErrorMessage: failure.message,
      )),
      (summary) => emit(state.copyWith(
        isLoadingFinance: false,
        earningsSummary: summary,
      )),
    );
  }

  Future<void> _onFetchEarningsList(FetchRetailerEarningsListEvent event, Emitter<RetailerState> emit) async {
    if (_retailerRepo == null) return;
    emit(state.copyWith(isLoadingFinance: true));
    final res = await _retailerRepo.getEarnings(
      status: event.status,
      limit: event.limit,
      skip: event.skip,
    );
    res.fold(
      (failure) => emit(state.copyWith(
        isLoadingFinance: false,
        financeErrorMessage: failure.message,
      )),
      (list) => emit(state.copyWith(
        isLoadingFinance: false,
        earningsList: list,
      )),
    );
  }

  Future<void> _onFetchSettlements(FetchRetailerSettlementsEvent event, Emitter<RetailerState> emit) async {
    if (_retailerRepo == null) return;
    _inAppMessagingService?.triggerEvent(IInAppMessagingService.retailerSettlementViewed);
    emit(state.copyWith(isLoadingFinance: true));
    final res = await _retailerRepo.getSettlements(
      limit: event.limit,
      skip: event.skip,
    );
    res.fold(
      (failure) => emit(state.copyWith(
        isLoadingFinance: false,
        financeErrorMessage: failure.message,
      )),
      (list) => emit(state.copyWith(
        isLoadingFinance: false,
        settlements: list,
      )),
    );
  }

  Future<void> _onUpdateBankAccount(UpdateRetailerBankAccountEvent event, Emitter<RetailerState> emit) async {
    if (_retailerRepo == null) return;
    emit(state.copyWith(isLoadingFinance: true, clearFinanceMessages: true));
    final res = await _retailerRepo.updateBankAccount(event.bankData);
    res.fold(
      (failure) => emit(state.copyWith(
        isLoadingFinance: false,
        financeErrorMessage: failure.message,
      )),
      (bank) => emit(state.copyWith(
        isLoadingFinance: false,
        bankAccount: bank,
        financeSuccessMessage: 'Bank account updated successfully',
      )),
    );
  }

  Future<void> _onFetchBanners(FetchRetailerBannersEvent event, Emitter<RetailerState> emit) async {
    if (_retailerRepo == null) return;
    final res = await _retailerRepo.getHeroBanners(app: 'RETAILER');
    res.fold(
      (_) => null,
      (banners) => emit(state.copyWith(heroBanners: banners)),
    );
  }
}
