import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/storage/local_cache_service.dart';
import '../../../../core/utils/bloc_event_transformers.dart';
import '../../../order/data/datasources/payment_remote_data_source.dart';
import '../../../order/data/datasources/order_remote_data_source.dart';
import '../../../order/domain/entities/order_entity.dart';
import '../../../order/domain/repositories/order_repository.dart';
import '../../domain/entities/cart_item_entity.dart';
import '../../domain/entities/catalog_entities.dart';
import '../../domain/entities/customer_address_entity.dart';
import '../../domain/entities/hero_banner_entity.dart';
import '../../domain/repositories/catalog_repository.dart';
import '../../data/models/category_model.dart';
import '../../../../core/services/websocket_service.dart';
import '../../../../core/services/push_notification_service.dart';
import '../../../../core/services/network_connectivity_service.dart';
import '../../../../core/security/secure_storage_service.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/localization/app_strings.dart';
import '../../../../core/services/in_app_messaging_service.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../../core/ai/cart_rag_service.dart';
import '../../domain/entities/cart_optimization_entity.dart';
import '../../../../core/utils/invoice_pdf_generator.dart';
import '../../../../core/ai/handwritten_list_rag_service.dart';
import '../../domain/entities/handwritten_item_match_entity.dart';
import 'customer_event.dart';
import 'customer_state.dart';

export 'customer_event.dart';
export 'customer_state.dart';

class CustomerBloc extends Bloc<CustomerEvent, CustomerState> {
  final ICatalogRepository _catalogRepo;
  final IOrderRepository _orderRepo;
  final ILocalCacheService _localCache;
  final IPaymentRemoteDataSource? _paymentDataSource;
  final IWebSocketService? _webSocketService;
  final ISecureStorageService? _secureStorage;
  final IPushNotificationService? _pushNotificationService;
  final IInAppMessagingService? _inAppMessagingService;
  final CartRagService _cartRagService;
  final HandwrittenListRagService _handwrittenListRagService;
  StreamSubscription? _orderSub;
  StreamSubscription? _productSub;
  StreamSubscription? _storeSub;
  StreamSubscription? _socketOrderSub;
  StreamSubscription? _socketNotifSub;
  StreamSubscription? _socketBannerSub;
  StreamSubscription<PushNotificationPayload>? _pushNotifSub;
  StreamSubscription? _connectivitySub;
  Timer? _pollTimer;
  int _pollTicks = 0;
  final Map<String, DateTime> _recentNotifSignatures = {};

  CustomerBloc({
    required ICatalogRepository catalogRepo,
    required IOrderRepository orderRepo,
    required ILocalCacheService localCache,
    IPaymentRemoteDataSource? paymentDataSource,
    IWebSocketService? webSocketService,
    ISecureStorageService? secureStorage,
    IPushNotificationService? pushNotificationService,
    IInAppMessagingService? inAppMessagingService,
    CartRagService? cartRagService,
    HandwrittenListRagService? handwrittenListRagService,
  })  : _catalogRepo = catalogRepo,
        _orderRepo = orderRepo,
        _localCache = localCache,
        _paymentDataSource = paymentDataSource,
        _webSocketService = webSocketService,
        _secureStorage = secureStorage,
        _pushNotificationService = pushNotificationService,
        _inAppMessagingService = inAppMessagingService ?? (sl.isRegistered<IInAppMessagingService>() ? sl<IInAppMessagingService>() : null),
        _cartRagService = cartRagService ?? CartRagService(),
        _handwrittenListRagService = handwrittenListRagService ?? HandwrittenListRagService(secureStorage: secureStorage),
        super(CustomerState(
          language: AppLanguage.fromCode(localCache.getAppLanguage()),
          searchHistory: _safeInitialSearchHistory(catalogRepo),
        )) {
    on<LoadCustomerDataEvent>(_onLoadData);
    on<PollCustomerOrdersEvent>(_onPollOrders, transformer: BlocEventTransformers.droppable());
    on<RefreshCustomerOrdersEvent>(_onRefreshCustomerOrders, transformer: BlocEventTransformers.droppable());
    on<SearchProductsEvent>(_onSearchProducts, transformer: BlocEventTransformers.debounce(const Duration(milliseconds: 300)));
    on<FilterByCategoryEvent>(_onFilterByCategory, transformer: BlocEventTransformers.restartable());
    on<FilterByStoreEvent>(_onFilterByStore);
    on<AddToCartEvent>(_onAddToCart, transformer: BlocEventTransformers.sequential());
    on<DismissMultiRetailerConflictEvent>((event, emit) => emit(state.copyWith(clearMultiRetailerConflict: true)));
    on<UpdateCartQuantityEvent>(_onUpdateCartQuantity, transformer: BlocEventTransformers.sequential());
    on<RemoveFromCartEvent>(_onRemoveFromCart);
    on<ClearCartEvent>(_onClearCart);
    on<ReorderEvent>(_onReorder);
    on<SelectAddressEvent>(_onSelectAddress);
    on<PlaceOrderEvent>(_onPlaceOrder, transformer: BlocEventTransformers.droppable());
    on<ValidateCartEvent>(_onValidateCart);
    on<LoadAddressesEvent>(_onLoadAddresses);
    on<AddAddressEvent>(_onAddAddress);
    on<UpdateAddressEvent>(_onUpdateAddress);
    on<DeleteAddressEvent>(_onDeleteAddress);
    on<SetDefaultAddressEvent>(_onSetDefaultAddress);
    on<LoadRecommendationsEvent>(_onLoadRecommendations);
    on<LoadWishlistEvent>(_onLoadWishlist);
    on<ToggleWishlistEvent>(_onToggleWishlist);
    on<LoadNotificationsEvent>(_onLoadNotifications);
    on<MarkNotificationReadEvent>(_onMarkNotificationRead);
    on<MarkAllNotificationsReadEvent>(_onMarkAllNotificationsRead);
    on<CancelOrderEvent>(_onCancelOrder);
    on<ReviewOrderEvent>(_onReviewOrder);
    on<TrackOrderEvent>(_onTrackOrder);
    on<InitiateRazorpayPaymentEvent>(_onInitiateRazorpayPayment, transformer: BlocEventTransformers.droppable());
    on<VerifyRazorpayPaymentEvent>(_onVerifyRazorpayPayment, transformer: BlocEventTransformers.droppable());
    on<RazorpayPaymentFailedEvent>(_onRazorpayPaymentFailed);
    on<RegisterCustomerPushTokenEvent>(_onRegisterPushToken);
    on<CustomerPushNotificationReceivedEvent>(_onPushNotificationReceived);
    on<SocketOrderStatusChangedEvent>(_onSocketOrderStatusChanged);
    on<SocketNotificationEvent>(_onSocketNotification);
    on<ApplyProductFiltersEvent>(_onApplyProductFilters);
    on<ResetProductFiltersEvent>(_onResetProductFilters);
    on<CustomerOrdersStreamUpdated>(_onOrdersStreamUpdated);
    on<CustomerProductsStreamUpdated>(_onProductsStreamUpdated);
    on<CustomerStoresStreamUpdated>(_onStoresStreamUpdated);
    on<ClearCustomerSessionEvent>(_onClearCustomerSession);
    on<LoadMoreProductsEvent>(_onLoadMoreProducts, transformer: BlocEventTransformers.droppable());
    on<ClearActiveRazorpayOrderEvent>((event, emit) => emit(state.copyWith(clearActiveRazorpayOrder: true)));
    on<CheckCustomerLocationEvent>(_onCheckCustomerLocation, transformer: BlocEventTransformers.restartable());
    on<LoadCustomerNotificationsEvent>((event, emit) => add(LoadNotificationsEvent()));
    on<GetPaymentStatusEvent>(_onGetPaymentStatus);
    on<FetchHeroBannersEvent>(_onFetchHeroBanners, transformer: BlocEventTransformers.restartable());
    on<FetchAvailableCouponsEvent>(_onFetchAvailableCoupons);
    on<ApplyCouponEvent>(_onApplyCoupon);
    on<RemoveCouponEvent>(_onRemoveCoupon);
    on<FetchCartPricingEvent>(_onFetchCartPricing);
    on<SelectTipEvent>(_onSelectTip);
    on<DownloadOrderInvoiceEvent>(_onDownloadOrderInvoice);
    on<ChangeCustomerLanguageEvent>(_onChangeLanguage);
    on<FilterStoresEvent>(_onFilterStores);
    on<CustomerConnectivityChangedEvent>(_onConnectivityChanged);
    on<SubmitOrderReviewEvent>(_onSubmitOrderReview);
    on<AddSearchHistoryEvent>(_onAddSearchHistory);
    on<RemoveSearchHistoryItemEvent>(_onRemoveSearchHistoryItem);
    on<ClearSearchHistoryEvent>(_onClearSearchHistory);
    on<AnalyzeCartOptimizationEvent>(_onAnalyzeCartOptimization);
    on<ApplyCartSwapEvent>(_onApplyCartSwap);
    on<ApplyAllCartSwapsEvent>(_onApplyAllCartSwaps);
    on<DismissCartOptimizationEvent>((event, emit) => emit(state.copyWith(clearCartOptimization: true)));
    on<ScanHandwrittenListEvent>(_onScanHandwrittenList);
    on<ToggleHandwrittenItemSelectionEvent>(_onToggleHandwrittenItemSelection);
    on<UpdateHandwrittenItemQuantityEvent>(_onUpdateHandwrittenItemQuantity);
    on<AddHandwrittenMatchesToCartEvent>(_onAddHandwrittenMatchesToCart);
    on<ClearHandwrittenScanEvent>(_onClearHandwrittenScan);

    // Subscribe to repository reactive streams
    _orderSub = _orderRepo.ordersStream.listen((orders) {
      add(CustomerOrdersStreamUpdated(orders));
    });

    _productSub = _catalogRepo.productsStream.listen((products) {
      add(CustomerProductsStreamUpdated(products));
    });

    _storeSub = _catalogRepo.storesStream.listen((stores) {
      add(CustomerStoresStreamUpdated(stores));
    });

    // Hook WebSockets for real-time order updates & alerts
    final ws = _webSocketService;
    if (ws != null) {
      _hasValidToken().then((isValid) {
        if (isValid) {
          ws.connect();
        }
      });
      _socketOrderSub = ws.orderStatusStream.listen((data) {
        add(SocketOrderStatusChangedEvent(data));
      });
      _socketNotifSub = ws.notificationStream.listen((data) {
        add(SocketNotificationEvent(data));
      });
      _socketBannerSub = ws.bannerUpdateStream.listen((_) {
        add(const FetchHeroBannersEvent(forceRefresh: true));
      });
    }

    // Secondary fallback polling (every 30s) when idle or reconnecting
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      add(const PollCustomerOrdersEvent());
    });

    // Auto-reconnect & offline listener
    if (sl.isRegistered<INetworkConnectivityService>()) {
      final conn = sl<INetworkConnectivityService>();
      _connectivitySub = conn.onConnectivityChanged.listen((online) {
        add(CustomerConnectivityChangedEvent(online));
      });
    }

    // Hook Firebase Cloud Messaging (foreground, background tap, and cold-start initial message)
    final push = _pushNotificationService;
    if (push != null) {
      _pushNotifSub = push.onNotificationReceived.listen((payload) {
        add(CustomerPushNotificationReceivedEvent(payload.toMap()));
      });
      final pending = push.consumePendingNotification();
      if (pending != null) {
        add(CustomerPushNotificationReceivedEvent(pending.toMap()));
      }
    }

  }

  @override
  Future<void> close() {
    _pollTimer?.cancel();
    _connectivitySub?.cancel();
    _orderSub?.cancel();
    _productSub?.cancel();
    _storeSub?.cancel();
    _socketOrderSub?.cancel();
    _socketNotifSub?.cancel();
    _socketBannerSub?.cancel();
    _pushNotifSub?.cancel();
    return super.close();
  }

  Future<void> _onSocketOrderStatusChanged(SocketOrderStatusChangedEvent event, Emitter<CustomerState> emit) async {
    final payload = event.payload;
    final orderId = payload['orderId']?.toString() ?? payload['id']?.toString() ?? '';
    final newStatusStr = payload['status']?.toString() ?? '';

    if (orderId.isEmpty) return;

    // Optimistic update: instantly reflect status change in state (no HTTP call).
    final newStatus = OrderEntity.parseStatus(newStatusStr);
    final orderExists = state.myOrders.any((o) => o.id == orderId);
    final updatedOrders = state.myOrders.map((order) {
      if (order.id == orderId) {
        return order.copyWith(status: newStatus);
      }
      return order;
    }).toList();
    emit(state.copyWith(myOrders: updatedOrders));

    // Only do a full HTTP re-sync when:
    //  (a) The order was not found in local state (e.g. first push after app restart), OR
    //  (b) The status is terminal — delivered/cancelled get final data from server
    //      so the enriched snapshot (rating prompt, OTP, etc.) is up to date.
    // Avoids 5+ redundant full-list fetches during a normal order lifecycle.
    final isTerminal = newStatus == OrderStatus.delivered ||
        newStatus == OrderStatus.cancelled ||
        newStatus == OrderStatus.rejected;
    if (!orderExists || isTerminal) {
      final res = await _orderRepo.getCustomerOrders('');
      res.fold((_) => null, (orders) {
        if (orders.isNotEmpty) {
          emit(state.copyWith(myOrders: _mergeOrdersPreservingTerminal(orders)));
        }
      });
    }
  }

  List<OrderEntity> _mergeOrdersPreservingTerminal(List<OrderEntity> incomingOrders) {
    final now = DateTime.now();
    if (incomingOrders.isEmpty) {
      // If server returned empty, keep only very recent local pending orders (< 3 min)
      return state.myOrders.where((o) {
        final isLocal = !RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(o.id);
        final isRecent = now.difference(o.createdAt).inMinutes < 3;
        final isPending = o.status == OrderStatus.placed || o.status == OrderStatus.paymentPending;
        return isLocal && isRecent && isPending;
      }).toList();
    }
    final mergedMap = <String, OrderEntity>{};
    // Seed with remote authoritative incoming orders
    for (final incoming in incomingOrders) {
      final existing = state.myOrders.where((o) => o.id == incoming.id).firstOrNull;
      if (existing != null) {
        if (existing.status == OrderStatus.delivered && incoming.status != OrderStatus.delivered) {
          mergedMap[incoming.id] = incoming.copyWith(
            status: OrderStatus.delivered,
            paymentStatus: 'COMPLETED',
          );
          continue;
        }
        if (existing.status == OrderStatus.cancelled && incoming.status != OrderStatus.cancelled) {
          mergedMap[incoming.id] = incoming.copyWith(status: OrderStatus.cancelled);
          continue;
        }
      }
      mergedMap[incoming.id] = incoming;
    }
    // Also keep fresh local pending orders (< 3 min) not yet indexed by the server
    for (final local in state.myOrders) {
      final isLocal = !RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(local.id);
      final isRecent = now.difference(local.createdAt).inMinutes < 3;
      final isPending = local.status == OrderStatus.placed || local.status == OrderStatus.paymentPending;
      if (isLocal && isRecent && isPending && !mergedMap.containsKey(local.id)) {
        mergedMap[local.id] = local;
      }
    }
    final result = mergedMap.values.toList();
    result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }

  Future<void> _onSocketNotification(SocketNotificationEvent event, Emitter<CustomerState> emit) async {
    final type = (event.payload['type'] ?? event.payload['event'] ?? '').toString().toUpperCase();
    if (type.contains('BANNER')) {
      add(const FetchHeroBannersEvent(forceRefresh: true));
      return;
    }
    add(CustomerPushNotificationReceivedEvent(event.payload));
  }

  void _onConnectivityChanged(CustomerConnectivityChangedEvent event, Emitter<CustomerState> emit) {
    final wasOfflineOrDown = state.isOffline || state.isServerDown || state.failureType != FailureType.none;
    final newFailure = event.isOnline ? FailureType.none : FailureType.noInternet;

    emit(state.copyWith(failureType: newFailure));

    if (event.isOnline) {
      _webSocketService?.connect();
      if (wasOfflineOrDown || state.allProducts.isEmpty || state.stores.isEmpty) {
        // Network restored: auto-refresh catalog and orders
        final cachedLoc = _localCache.getCachedActiveLocation();
        final lat = state.activeLat != 0.0 ? state.activeLat : (cachedLoc?['lat'] as num?)?.toDouble();
        final lng = state.activeLng != 0.0 ? state.activeLng : (cachedLoc?['lng'] as num?)?.toDouble();

        add(LoadCustomerDataEvent(lat: lat, lng: lng));
        add(const RefreshCustomerOrdersEvent());
      }
    }

  }

  Future<void> _onPollOrders(PollCustomerOrdersEvent event, Emitter<CustomerState> emit) async {
    _pollTicks++;

    // FIX #1: Only check active order status — determines whether we need any polling at all
    final hasActiveOrder = state.myOrders.any((o) =>
        o.status != OrderStatus.delivered &&
        o.status != OrderStatus.cancelled &&
        o.status != OrderStatus.rejected);

    // FIX #1: Only sync store open/closed status when customer has an active order.
    // Previously ran every 12s regardless — now skipped for idle users (saves network + battery).
    if (_pollTicks % 2 == 0 && hasActiveOrder) {
      final lat = state.activeLat != 0.0 ? state.activeLat : null;
      final lng = state.activeLng != 0.0 ? state.activeLng : null;
      final storesRes = await _catalogRepo.getNearbyStores(lat: lat, lng: lng);
      storesRes.fold((_) => null, (stores) {
        if (stores.isNotEmpty) {
          add(CustomerStoresStreamUpdated(stores));
        }
      });
    }

    // Only poll orders if there is an active pending/in-flight order
    if (!hasActiveOrder) {
      return;
    }

    final isAuthenticated = await _hasValidToken();
    if (!isAuthenticated) return;

    final res = await _orderRepo.getCustomerOrders('');
    res.fold(
      (_) => null,
      (orders) {
        emit(state.copyWith(myOrders: _mergeOrdersPreservingTerminal(orders)));
      },
    );
  }

  Future<void> _onRefreshCustomerOrders(RefreshCustomerOrdersEvent event, Emitter<CustomerState> emit) async {
    final isAuthenticated = await _hasValidToken();
    if (!isAuthenticated) return;

    final res = await _orderRepo.getCustomerOrders('');
    res.fold(
      (_) => null,
      (orders) {
        emit(state.copyWith(myOrders: _mergeOrdersPreservingTerminal(orders)));
      },
    );
  }

  Future<bool> _hasValidToken() async {
    try {
      final storage = _secureStorage ??
          (sl.isRegistered<ISecureStorageService>() ? sl<ISecureStorageService>() : null);
      if (storage == null) return false;
      final token = await storage.getAccessToken();
      final isSessionValid = await storage.isSessionValid();
      return (token != null && token.isNotEmpty) || isSessionValid;
    } catch (_) {
      return false;
    }
  }

  Future<void> _onLoadData(LoadCustomerDataEvent event, Emitter<CustomerState> emit) async {
    _inAppMessagingService?.initialize(role: UserRole.customer);
    final cachedLoc = _localCache.getCachedActiveLocation();
    double? activeLat = event.lat ?? (cachedLoc?['lat'] as num?)?.toDouble();
    double? activeLng = event.lng ?? (cachedLoc?['lng'] as num?)?.toDouble();
    String? activeAddr = cachedLoc?['address']?.toString();
    String? activeZoneId = cachedLoc?['zoneId']?.toString();
    String? activeZoneName = cachedLoc?['zoneName']?.toString();
    bool activeInZone = (cachedLoc?['inZone'] as bool?) ?? true;

    // Pre-flight check: If active coordinates are missing, resolve from cached saved addresses
    if (activeLat == null || activeLng == null || activeLat == 0.0) {
      final cachedAddresses = _localCache.getCachedAddresses();
      if (cachedAddresses.isNotEmpty) {
        final defaultAddr = cachedAddresses.firstWhere(
          (a) => a['isDefault'] == true,
          orElse: () => cachedAddresses.first,
        );
        final dLat = (defaultAddr['lat'] as num?)?.toDouble();
        final dLng = (defaultAddr['lng'] as num?)?.toDouble();
        final dAddr = defaultAddr['formattedAddress']?.toString() ??
            defaultAddr['address']?.toString() ??
            defaultAddr['line1']?.toString();
        if (dLat != null && dLat != 0.0 && dLng != null && dLng != 0.0) {
          activeLat = dLat;
          activeLng = dLng;
          if (dAddr != null && dAddr.isNotEmpty) {
            activeAddr = dAddr;
          }
        }
      }
    }


    Set<String> reviewedOrderIds = state.reviewedOrderIds;
    try {
      final cached = _localCache.getReviewedOrderIds();
      if (cached.isNotEmpty) {
        reviewedOrderIds = cached;
      }
    }
 catch (_) {}

    List<String> searchHistory = state.searchHistory;
    try {
      final cachedHistory = _catalogRepo.getSearchHistory();
      if (cachedHistory.isNotEmpty) {
        searchHistory = cachedHistory;
      }
    }
 catch (_) {}

    emit(state.copyWith(
      isLoading: true,
      failureType: FailureType.none,
      activeLat: activeLat,
      activeLng: activeLng,
      selectedAddress: (activeAddr != null && activeAddr.isNotEmpty) ? activeAddr : state.selectedAddress,
      zoneId: activeZoneId ?? state.zoneId,
      zoneName: activeZoneName ?? state.zoneName,
      inZone: activeInZone,
      reviewedOrderIds: reviewedOrderIds,
      searchHistory: searchHistory,
    ));

    // Trigger fresh hero banners and available coupons fetch
    add(const FetchHeroBannersEvent(forceRefresh: true));
    add(const FetchAvailableCouponsEvent());

    // STAGE 1 (Immediate UI Render): Load Catalog & Zone-specific Stores concurrently
    final stage1Futures = <Future>[
      _catalogRepo.getCategories(),
      _catalogRepo.searchProducts('', lat: activeLat, lng: activeLng),
    ];
    final bool hasLocation = activeLat != null && activeLng != null && activeLat != 0.0;
    if (hasLocation) {
      stage1Futures.add(_catalogRepo.getNearbyStores(lat: activeLat, lng: activeLng));
      stage1Futures.add(_catalogRepo.checkLocation(lat: activeLat, lng: activeLng));
    }

    List<dynamic> stage1Results;
    try {
      stage1Results = await Future.wait(stage1Futures).timeout(const Duration(seconds: 4));
    } catch (_) {
      final cats = await _catalogRepo.getCategories();
      final prods = await _catalogRepo.searchProducts('');
      stage1Results = [
        cats,
        prods,
        if (hasLocation) ...[
          const Right<Failure, List<StoreEntity>>([]),
          const Left<Failure, CustomerZoneEntity>(ServerFailure(message: 'Location verification timed out')),
        ],
      ];
    }

    final categoriesRes = stage1Results[0] as Either<Failure, List<CategoryEntity>>;
    final productsRes = stage1Results[1] as Either<Failure, List<ProductEntity>>;
    final cachedCart = _localCache.getCartItems();

    List<CategoryEntity> categories = [];
    List<ProductEntity> products = [];
    String? loadError;
    FailureType failureType = FailureType.none;

    categoriesRes.fold((l) {
      loadError = l.message;
      failureType = l.failureType;
    }, (r) => categories = r);

    productsRes.fold((l) {
      loadError = l.message;
      if (failureType == FailureType.none) failureType = l.failureType;
    }, (r) => products = r);

    if (sl.isRegistered<INetworkConnectivityService>() &&
        !sl<INetworkConnectivityService>().isConnected) {
      failureType = FailureType.noInternet;
    }

    final cartItems = cachedCart.map((map) {
      final pid = map['productId'] as String;
      final qty = map['quantity'] as int;
      final prod = products.firstWhere(
        (p) => p.id == pid,
        orElse: () => ProductEntity(
          id: pid,
          // FIX #4: Use cached values from local storage instead of hardcoded placeholders
          storeId: map['storeId']?.toString() ?? '',
          name: map['name']?.toString() ?? 'Product',
          description: map['description']?.toString() ?? '',
          price: (map['price'] as num?)?.toDouble() ?? 0.0,
          unit: map['unit']?.toString() ?? '1 unit',
          imageUrl: map['imageUrl']?.toString() ?? '', // was hardcoded Unsplash milk photo
          categoryId: map['categoryId']?.toString() ?? 'cat_all', // was 'cat_dairy'
          isAvailable: true,
          stock: (map['stock'] as num?)?.toInt() ?? (map['stockQty'] as num?)?.toInt() ?? 0,
        ),
      );
      return CartItemEntity(product: prod, quantity: qty);
    }).toList();

    // UNBLOCK DASHBOARD IMMEDIATELY: Screen renders categories and product feed in ~300ms
    // Re-check if any new categories were auto-discovered from products:
    final Set<String> catIds = categories.map((c) => c.id).toSet();
    final Set<String> catNames = categories.map((c) => c.name.toLowerCase().trim()).toSet();
    final List<CategoryEntity> enrichedCategories = List.from(categories);
    for (final prod in products) {
      final pCatName = prod.categoryName?.trim() ?? '';
      final pCatId = prod.categoryId.trim();
      final displayName = pCatName.isNotEmpty ? pCatName : pCatId;
      if (displayName.isEmpty ||
          displayName == 'cat_all' ||
          displayName.toLowerCase().contains('test') ||
          displayName.toLowerCase().contains('flow') ||
          RegExp(r'^[a-f0-9]{24}$').hasMatch(displayName)) {
        continue;
      }
      if (catNames.contains(displayName.toLowerCase()) || (pCatId.isNotEmpty && catIds.contains(pCatId))) continue;

      final cleanId = pCatId.isNotEmpty && !pCatId.startsWith('cat_')
          ? pCatId
          : (displayName.toLowerCase().startsWith('cat_')
              ? displayName.toLowerCase()
              : 'cat_${displayName.toLowerCase().replaceAll(' ', '_')}');

      if (!catIds.contains(cleanId)) {
        catIds.add(cleanId);
        catNames.add(displayName.toLowerCase());
        String cleanName = displayName;
        if (cleanName.toLowerCase().startsWith('cat_')) cleanName = cleanName.substring(4).replaceAll('_', ' ');
        cleanName = cleanName.split(' ').where((w) => w.isNotEmpty).map((w) => '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
        enrichedCategories.add(CategoryEntity(
          id: cleanId,
          name: cleanName,
          icon: CategoryModel.resolveEmoji(cleanName),
          colorHex: '#0F766E',
        ));
      }
    }

    if (!enrichedCategories.any((c) => c.id == 'cat_all')) {
      enrichedCategories.insert(
        0,
        const CategoryEntity(id: 'cat_all', name: 'All Essentials', icon: '🏪', colorHex: '0xFF0F766E'),
      );
    }


    List<StoreEntity> stores = List.from(state.stores);
    bool inZone = activeInZone;
    String? zoneId = activeZoneId ?? state.zoneId;
    String? zoneName = activeZoneName ?? state.zoneName;
    double? zoneDeliveryFee = state.zoneDeliveryFee;
    double? zonePlatformFee = state.zonePlatformFee;
    double? zoneFreeDeliveryThreshold = state.zoneFreeDeliveryThreshold;
    double? zoneMinOrderAmount = state.zoneMinOrderAmount;
    String? outOfZoneMsg;

    if (hasLocation && stage1Results.length >= 4) {
      final storesRes = stage1Results[2] as Either<Failure, List<StoreEntity>>;
      final zoneRes = stage1Results[3] as Either<Failure, CustomerZoneEntity>;

      zoneRes.fold(
        (l) {
          inZone = activeInZone;
          zoneId = activeZoneId ?? state.zoneId;
          zoneName = activeZoneName ?? state.zoneName;
          outOfZoneMsg = inZone ? null : l.message;
        },
        (r) {
          inZone = r.inZone;
          zoneId = r.zoneId ?? (r.inZone ? activeZoneId : null);
          zoneName = r.zoneName ?? (r.inZone ? activeZoneName : null);
          zoneDeliveryFee = r.inZone ? (r.deliveryFee ?? zoneDeliveryFee) : null;
          zonePlatformFee = r.inZone ? (r.platformFee ?? zonePlatformFee) : null;
          zoneFreeDeliveryThreshold = r.inZone ? (r.freeDeliveryThreshold ?? zoneFreeDeliveryThreshold) : null;
          zoneMinOrderAmount = r.inZone ? (r.minOrderAmount ?? zoneMinOrderAmount) : null;
          outOfZoneMsg = r.inZone ? null : (r.message ?? 'Location is outside the delivery zone');
        },
      );

      if (inZone) {
        storesRes.fold((_) => null, (r) {
          if (zoneId != null && zoneId!.isNotEmpty) {
            final zoneStores = r.where((s) => s.zoneId == null || s.zoneId!.isEmpty || s.zoneId == zoneId).toList();
            if (zoneStores.isNotEmpty) {
              stores = zoneStores;
            } else if (r.isNotEmpty) {
              stores = r;
            }
          } else if (r.isNotEmpty) {
            stores = r;
          }
        });
      } else {
        stores = <StoreEntity>[];
      }
    }


    final effectiveProducts = products.isNotEmpty
        ? products
        : (state.allProducts.isNotEmpty ? state.allProducts : products);

    List<ProductEntity> initialFiltered = (!inZone && outOfZoneMsg != null)
        ? const <ProductEntity>[]
        : _applyFilters(
            products: effectiveProducts,
            categoryId: state.selectedCategoryId,
            query: state.searchQuery,
            extraStores: stores.isNotEmpty ? stores : null,
          );

    // Guard against sudden catalog disappearance on fresh launch:
    // If extraStores filtered out all items but we have valid products in catalog,
    // fall back cleanly to catalog filtering so All Essentials products never vanish.
    if (initialFiltered.isEmpty && effectiveProducts.isNotEmpty && (inZone || outOfZoneMsg == null)) {
      initialFiltered = _applyFilters(
        products: effectiveProducts,
        categoryId: state.selectedCategoryId,
        query: state.searchQuery,
      );
    }

    // Preserve existing filteredProducts if initialFiltered is unexpectedly empty
    if (initialFiltered.isEmpty && state.filteredProducts.isNotEmpty && (inZone || outOfZoneMsg == null)) {
      initialFiltered = state.filteredProducts;
    }

    final hasData = effectiveProducts.isNotEmpty || categories.isNotEmpty;
    final effectiveFailureType = hasData ? FailureType.none : failureType;

    emit(state.copyWith(
      isLoading: false,
      failureType: effectiveFailureType,
      categories: enrichedCategories,
      allProducts: effectiveProducts,
      filteredProducts: initialFiltered,
      cartItems: cartItems,
      errorMessage: effectiveProducts.isEmpty && loadError != null ? loadError : null,
      stores: stores,
      zoneId: zoneId,
      zoneName: zoneName,
      inZone: inZone,
      zoneDeliveryFee: zoneDeliveryFee,
      zonePlatformFee: zonePlatformFee,
      zoneFreeDeliveryThreshold: zoneFreeDeliveryThreshold,
      zoneMinOrderAmount: zoneMinOrderAmount,
      clearZonePricing: !inZone,
      outOfDeliveryZoneMessage: outOfZoneMsg,
    ));

    final initialRetailerId = cartItems.isNotEmpty
        ? cartItems.first.product.storeId
        : (stores.isNotEmpty ? stores.first.id : null);
    if (initialRetailerId != null && initialRetailerId.isNotEmpty) {
      add(FetchAvailableCouponsEvent(retailerId: initialRetailerId));
    }

    // STAGE 2 (Background Enrichment): Silently fetch Saved Addresses & Notifications, sync location cache
    final isAuthenticated = await _hasValidToken();

    if (isAuthenticated) {
      // Connect WebSocket if user is logged in
      _webSocketService?.connect();

      // Auto-register FCM device token if cached in local storage
      try {
        final cachedToken = _localCache.getCachedFcmToken();
        if (cachedToken != null && cachedToken.isNotEmpty) {
          _catalogRepo.registerDeviceToken(
            fcmToken: cachedToken,
            platform: Platform.isIOS ? 'ios' : 'android',
          );
        }
      } catch (_) {}
    }

    List<CustomerAddressEntity> addresses = [];
    List<Map<String, dynamic>> notifs = state.notifications;
    int unreadCount = state.unreadNotificationsCount;

    if (isAuthenticated) {
      final stage2Init = await Future.wait([
        _catalogRepo.getAddresses(),
        _catalogRepo.getNotifications(),
        _catalogRepo.getUnreadNotificationCount(),
      ]);

      final addressesRes = stage2Init[0] as Either<Failure, List<CustomerAddressEntity>>;
      final notifsRes = stage2Init[1] as Either<Failure, List<Map<String, dynamic>>>;
      final unreadRes = stage2Init[2] as Either<Failure, int>;

      addressesRes.fold((l) => null, (r) => addresses = CustomerAddressEntity.deduplicate(r));
      notifsRes.fold((l) => null, (r) => notifs = r);
      unreadRes.fold((l) => null, (r) => unreadCount = r);
    }

    if (addresses.isNotEmpty) {
      await _localCache.cacheAddresses(addresses.map((a) => {
        'id': a.id,
        'label': a.label,
        'line1': a.line1,
        'address': a.line1,
        'formattedFullAddress': a.formattedFullAddress,
        'lat': a.lat,
        'lng': a.lng,
        'isDefault': a.isDefault,
        'city': a.city,
        'state': a.state,
        'pincode': a.pincode,
      }).toList());
      final defaultAddr = addresses.firstWhere(
        (a) => a.isDefault,
        orElse: () => addresses.first,
      );
      OrderRemoteDataSourceImpl.setCachedAddressId(defaultAddr.id);

      // If app started with NO resolved location, trigger location check with default address coordinates:
      if (!hasLocation && defaultAddr.lat != 0.0 && defaultAddr.lng != 0.0) {
        add(CheckCustomerLocationEvent(lat: defaultAddr.lat, lng: defaultAddr.lng));
      }
    }


    if (hasLocation && inZone) {
      await _localCache.cacheActiveLocation(
        lat: activeLat,
        lng: activeLng,
        address: (activeAddr != null && activeAddr.isNotEmpty) ? activeAddr : state.selectedAddress,
        zoneId: zoneId,
        zoneName: zoneName,
        inZone: inZone,
      );
    } else if (hasLocation && !inZone) {
      await _localCache.cacheActiveLocation(
        lat: activeLat,
        lng: activeLng,
        address: (activeAddr != null && activeAddr.isNotEmpty) ? activeAddr : state.selectedAddress,
        zoneId: null,
        zoneName: null,
        inZone: false,
      );
    }

    emit(state.copyWith(
      savedAddresses: addresses.isNotEmpty ? addresses : state.savedAddresses,
      notifications: notifs,
      unreadNotificationsCount: unreadCount,
    ));

    // STAGE 3 (Asynchronous Order Sync): Sync customer orders for Orders tab & Profile badge in background
    if (isAuthenticated) {
      final ordersRes = await _orderRepo.getCustomerOrders('');
      ordersRes.fold((l) => null, (orders) {
        emit(state.copyWith(myOrders: _mergeOrdersPreservingTerminal(orders)));
      });
    }
  }

  Future<void> _onSearchProducts(SearchProductsEvent event, Emitter<CustomerState> emit) async {
    final query = event.query.toLowerCase().trim();
    if (query.length > 1) {
      final res = await _catalogRepo.searchCatalog(
        query: query,
        lat: state.activeLat,
        lng: state.activeLng,
      );
      res.fold(
        (failure) {
          final matchedStores = state.stores
              .where((s) =>
                  s.name.toLowerCase().contains(query) ||
                  s.category.toLowerCase().contains(query) ||
                  s.address.toLowerCase().contains(query))
              .toList();
          final filtered = _applyFilters(
            products: state.allProducts,
            categoryId: state.selectedCategoryId,
            query: query,
            sortOption: state.sortOption,
            inStockOnly: state.inStockOnly,
            fastDeliveryOnly: state.fastDeliveryOnly,
            dealsOnly: state.dealsOnly,
            extraStores: matchedStores,
          );
          emit(state.copyWith(
            searchQuery: event.query,
            filteredProducts: filtered,
            searchStores: matchedStores,
          ));
        },
        (catalogData) {
          // Merge remote matched stores and any matching local stores
          final storeMap = <String, StoreEntity>{};
          for (final s in catalogData.stores) {
            storeMap[s.id] = s;
          }
          for (final s in state.stores) {
            if (s.name.toLowerCase().contains(query) ||
                s.category.toLowerCase().contains(query) ||
                s.address.toLowerCase().contains(query)) {
              storeMap[s.id] = s;
            }
          }
          final combinedStores = storeMap.values.where((s) {
            if (state.zoneId == null || state.zoneId!.isEmpty) return true;
            return s.zoneId == null || s.zoneId!.isEmpty || s.zoneId == state.zoneId;
          }).toList();

          // Merge products
          final prodMap = <String, ProductEntity>{};
          for (final p in state.allProducts) {
            prodMap[p.id] = p;
          }
          for (final p in catalogData.products) {
            prodMap[p.id] = p;
          }
          final combinedProducts = prodMap.values.toList();

          final filtered = _applyFilters(
            products: combinedProducts,
            categoryId: state.selectedCategoryId,
            query: query,
            sortOption: state.sortOption,
            inStockOnly: state.inStockOnly,
            fastDeliveryOnly: state.fastDeliveryOnly,
            dealsOnly: state.dealsOnly,
            extraStores: combinedStores,
          );
          emit(state.copyWith(
            searchQuery: event.query,
            filteredProducts: filtered,
            searchStores: combinedStores,
          ));
        },
      );
    } else {
      final filtered = _applyFilters(
        products: state.allProducts,
        categoryId: state.selectedCategoryId,
        query: query,
        sortOption: state.sortOption,
        inStockOnly: state.inStockOnly,
        fastDeliveryOnly: state.fastDeliveryOnly,
        dealsOnly: state.dealsOnly,
      );
      emit(state.copyWith(
        searchQuery: event.query,
        filteredProducts: filtered,
        searchStores: const [],
      ));
    }
  }

  Future<void> _onFilterByCategory(FilterByCategoryEvent event, Emitter<CustomerState> emit) async {
    _inAppMessagingService?.triggerEvent(IInAppMessagingService.customerCategoryBrowsed);
    final bool isAllEssentials = event.categoryId == 'cat_all';
    final String? effectiveStoreId = isAllEssentials ? null : state.selectedStore?.id;

    // Show immediately from memory while backend loads
    final filtered = _applyFilters(
      products: state.allProducts,
      categoryId: event.categoryId,
      query: state.searchQuery,
      sortOption: state.sortOption,
      inStockOnly: state.inStockOnly,
      fastDeliveryOnly: state.fastDeliveryOnly,
      dealsOnly: state.dealsOnly,
      storeId: effectiveStoreId,
    );
    emit(state.copyWith(
      selectedCategoryId: event.categoryId,
      filteredProducts: filtered,
      currentPage: 1,
      hasReachedMaxProducts: false,
      clearSelectedStore: isAllEssentials,
    ));

    // Always fetch fresh from backend for any category selection (including cat_all)
    // This ensures products appear even when in-memory state is empty or stale
    try {
      final res = await _catalogRepo.searchProducts(
        state.searchQuery,
        category: isAllEssentials ? null : event.categoryId,
      );
      res.fold((_) {}, (remoteProducts) {
        if (state.selectedCategoryId == event.categoryId && remoteProducts.isNotEmpty) {
          final updatedAll = List<ProductEntity>.from(state.allProducts);
          for (final p in remoteProducts) {
            final idx = updatedAll.indexWhere((existing) => existing.id == p.id);
            if (idx == -1) {
              updatedAll.add(p);
            } else {
              updatedAll[idx] = p;
            }
          }
          final newFiltered = _applyFilters(
            products: updatedAll,
            categoryId: event.categoryId,
            query: state.searchQuery,
            sortOption: state.sortOption,
            inStockOnly: state.inStockOnly,
            fastDeliveryOnly: state.fastDeliveryOnly,
            dealsOnly: state.dealsOnly,
            storeId: effectiveStoreId,
          );
          emit(state.copyWith(
            allProducts: updatedAll,
            filteredProducts: newFiltered,
          ));
        }
      });
    } catch (_) {}
  }

  Future<void> _onFilterByStore(FilterByStoreEvent event, Emitter<CustomerState> emit) async {
    final store = event.store;
    if (store == null) {
      final filtered = _applyFilters(
        products: state.allProducts,
        categoryId: state.selectedCategoryId,
        query: state.searchQuery,
        sortOption: state.sortOption,
        inStockOnly: state.inStockOnly,
        fastDeliveryOnly: state.fastDeliveryOnly,
        dealsOnly: state.dealsOnly,
        storeId: null,
      );
      emit(state.copyWith(
        clearSelectedStore: true,
        filteredProducts: filtered,
      ));
      return;
    }

    emit(state.copyWith(
      isLoading: true,
      selectedStore: store,
      searchQuery: '',
      selectedCategoryId: 'cat_all',
    ));

    // First check in-memory products for this store
    var storeProducts = state.allProducts.where((p) => p.storeId == store.id).toList();
    List<ProductEntity> currentAll = state.allProducts;

    // Always fetch fresh store products from backend to ensure real-time stock and pricing
    final res = await _catalogRepo.getStoreProducts(store.id);
    res.fold(
      (_) {},
      (remoteProds) {
        if (remoteProds.isNotEmpty) {
          storeProducts = remoteProds;
          final updatedAll = List<ProductEntity>.from(state.allProducts);
          for (final p in remoteProds) {
            final idx = updatedAll.indexWhere((existing) => existing.id == p.id);
            if (idx == -1) {
              updatedAll.add(p);
            } else {
              updatedAll[idx] = p;
            }
          }
          currentAll = updatedAll;
        }
      },
    );

    final filtered = _applyFilters(
      products: storeProducts,
      categoryId: 'cat_all',
      query: '',
      sortOption: state.sortOption,
      inStockOnly: state.inStockOnly,
      fastDeliveryOnly: state.fastDeliveryOnly,
      dealsOnly: state.dealsOnly,
      storeId: store.id,
    );

    emit(state.copyWith(
      isLoading: false,
      allProducts: currentAll,
      selectedStore: store,
      searchQuery: '',
      selectedCategoryId: 'cat_all',
      filteredProducts: filtered,
    ));
  }

  void _onAddToCart(AddToCartEvent event, Emitter<CustomerState> emit) {
    // Closed Store Protection: Reject products belonging to a closed store
    final store = state.stores.where((s) => s.id == event.product.storeId).firstOrNull;
    if (store != null && !store.isOpen) {
      emit(state.copyWith(
        errorMessage: '${store.name} is currently closed and not accepting orders.',
      ));
      return;
    }

    // Out of Stock Limitation Protection
    if (!event.product.isAvailable || event.product.stock <= 0) {
      emit(state.copyWith(
        errorMessage: '${event.product.name} is currently out of stock.',
      ));
      return;
    }

    var updatedCart = List<CartItemEntity>.from(state.cartItems);

    // Single-Retailer Cart Protection (Backend Guide Gotcha #6)
    if (updatedCart.isNotEmpty && !event.clearPreviousStoreCart) {
      final existingStoreId = updatedCart.first.product.storeId;
      if (existingStoreId.isNotEmpty &&
          event.product.storeId.isNotEmpty &&
          existingStoreId != event.product.storeId) {
        emit(state.copyWith(
          multiRetailerConflictProduct: event.product,
          errorMessage: 'Cart contains items from another store. Clear cart to switch stores.',
        ));
        return;
      }
    }
 else if (event.clearPreviousStoreCart) {
      updatedCart = [];
      _localCache.clearCart();
    }

    final idx = updatedCart.indexWhere((c) => c.product.id == event.product.id);

    if (idx >= 0) {
      final currentQty = updatedCart[idx].quantity;
      if (currentQty >= event.product.stock) {
        emit(state.copyWith(
          errorMessage: 'Cannot add more. Only ${event.product.stock} units available in stock.',
        ));
        return;
      }
      updatedCart[idx] = updatedCart[idx].copyWith(quantity: currentQty + 1);
    } else {
      updatedCart.add(CartItemEntity(product: event.product, quantity: 1));
    }

    _persistCart(updatedCart);
    _inAppMessagingService?.triggerEvent(IInAppMessagingService.customerCartViewed);
    emit(state.copyWith(
      cartItems: updatedCart,
      clearCartPricing: true,
      successMessage: '${event.product.name} added to cart',
      clearMultiRetailerConflict: true,
    ));

    // Sync to backend server cart if valid Mongo ID
    if (RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(event.product.id)) {
      final targetQty = updatedCart.firstWhere((c) => c.product.id == event.product.id).quantity;
      _catalogRepo.addCartItem(productId: event.product.id, quantity: targetQty).then((res) {
        res.fold((_) {
          if (!isClosed) add(const FetchCartPricingEvent());
        }, (pricing) {
          if (pricing != null && pricing.subtotal > 0 && pricing.total > 0 && !isClosed) {
            final currentSub = state.cartItems.fold(0.0, (acc, item) => acc + item.total);
            if ((pricing.subtotal - currentSub).abs() < 0.05) {
              emit(state.copyWith(cartPricing: pricing));
            } else {
              add(const FetchCartPricingEvent());
            }
          } else if (!isClosed) {
            add(const FetchCartPricingEvent());
          }
        });
      });
    } else {
      add(const FetchCartPricingEvent());
    }
    if (event.product.storeId.isNotEmpty) {
      add(FetchAvailableCouponsEvent(retailerId: event.product.storeId));
    }
  }

  void _onUpdateCartQuantity(UpdateCartQuantityEvent event, Emitter<CustomerState> emit) {
    final updatedCart = List<CartItemEntity>.from(state.cartItems);
    final idx = updatedCart.indexWhere((c) => c.product.id == event.productId);

    if (idx >= 0) {
      if (event.newQuantity <= 0) {
        updatedCart.removeAt(idx);
      } else {
        final availableStock = updatedCart[idx].product.stock;
        if (availableStock > 0 && event.newQuantity > availableStock) {
          emit(state.copyWith(
            errorMessage: 'Stock limit reached: Only $availableStock units available.',
          ));
          return;
        }
        updatedCart[idx] = updatedCart[idx].copyWith(quantity: event.newQuantity);
      }

      final newSubtotal = updatedCart.fold(0.0, (acc, item) => acc + item.total);
      final applied = state.appliedCoupon;
      final bool couponInvalidated = applied != null && applied.minOrder > 0 && newSubtotal < applied.minOrder;

      _persistCart(updatedCart);
      if (couponInvalidated) {
        emit(state.copyWith(
          cartItems: updatedCart,
          clearCartPricing: true,
          clearAppliedCoupon: true,
          errorMessage: 'Coupon "${applied.code}" removed: Minimum order of ₹${applied.minOrder.toStringAsFixed(0)} required.',
        ));
      } else {
        emit(state.copyWith(
          cartItems: updatedCart,
          clearCartPricing: true,
        ));
      }

      // Sync updated quantity to backend
      if (RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(event.productId)) {
        if (event.newQuantity <= 0) {
          _catalogRepo.removeCartItem(event.productId).then((_) {
            if (!isClosed) add(FetchCartPricingEvent(couponCode: couponInvalidated ? '' : null));
          });
        } else {
          _catalogRepo.addCartItem(productId: event.productId, quantity: event.newQuantity).then((res) {
            res.fold((_) {
              if (!isClosed) add(FetchCartPricingEvent(couponCode: couponInvalidated ? '' : null));
            }, (pricing) {
              if (pricing != null && pricing.subtotal > 0 && pricing.total > 0 && !isClosed) {
                final currentSub = state.cartItems.fold(0.0, (acc, item) => acc + item.total);
                if ((pricing.subtotal - currentSub).abs() < 0.05) {
                  emit(state.copyWith(cartPricing: pricing));
                } else {
                  add(FetchCartPricingEvent(couponCode: couponInvalidated ? '' : null));
                }
              } else if (!isClosed) {
                add(FetchCartPricingEvent(couponCode: couponInvalidated ? '' : null));
              }
            });
          });
        }
      } else {
        add(FetchCartPricingEvent(couponCode: couponInvalidated ? '' : null));
      }
    }

  }

  void _onRemoveFromCart(RemoveFromCartEvent event, Emitter<CustomerState> emit) {
    final updatedCart = state.cartItems.where((c) => c.product.id != event.productId).toList();
    final newSubtotal = updatedCart.fold(0.0, (acc, item) => acc + item.total);
    final applied = state.appliedCoupon;
    final bool couponInvalidated = applied != null && applied.minOrder > 0 && newSubtotal < applied.minOrder;

    _persistCart(updatedCart);
    if (couponInvalidated) {
      emit(state.copyWith(
        cartItems: updatedCart,
        clearCartPricing: true,
        clearAppliedCoupon: true,
        errorMessage: 'Coupon "${applied.code}" removed: Minimum order of ₹${applied.minOrder.toStringAsFixed(0)} required.',
      ));
    } else {
      emit(state.copyWith(
        cartItems: updatedCart,
        clearCartPricing: true,
      ));
    }

    if (RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(event.productId)) {
      _catalogRepo.removeCartItem(event.productId).then((_) {
        if (!isClosed) add(FetchCartPricingEvent(couponCode: couponInvalidated ? '' : null));
      });
    } else {
      add(FetchCartPricingEvent(couponCode: couponInvalidated ? '' : null));
    }
  }

  void _onClearCart(ClearCartEvent event, Emitter<CustomerState> emit) {
    _localCache.clearCart();
    _catalogRepo.clearBackendCart();
    emit(state.copyWith(
      cartItems: [],
      clearCartPricing: true,
      selectedTip: 0.0,
      clearAppliedCoupon: true,
    ));
  }

  void _onReorder(ReorderEvent event, Emitter<CustomerState> emit) {
    final order = event.order;
    if (order.items.isEmpty) return;

    final newCartItems = <CartItemEntity>[];
    for (final item in order.items) {
      final existingProd = state.allProducts.where((p) => p.id == item.productId).firstOrNull;
      final product = existingProd ?? ProductEntity(
        id: item.productId,
        name: item.nameSnapshot,
        price: item.priceSnapshot,
        unit: item.unit,
        storeId: order.storeId,
        storeName: order.storeName,
        imageUrl: item.imageUrl ?? '',
        categoryId: 'cat_all',
        description: item.nameSnapshot,
        stock: item.quantity > 0 ? item.quantity : 1,
        isAvailable: true,
        rating: 4.5,
      );
      newCartItems.add(CartItemEntity(product: product, quantity: item.quantity));
    }

    _persistCart(newCartItems);
    emit(state.copyWith(
      cartItems: newCartItems,
      successMessage: 'Items added to basket! Ready to checkout ⚡',
      clearMultiRetailerConflict: true,
    ));
  }

  void _onClearCustomerSession(ClearCustomerSessionEvent event, Emitter<CustomerState> emit) {
    try {
      _orderRepo.clearOrders();
    } catch (_) {}
    unawaited(_localCache.clearUserData());
    emit(state.copyWith(
      myOrders: [],
      cartItems: [],
      savedAddresses: [],
      selectedAddress: '',
      reviewedOrderIds: const {},
      clearCartPricing: true,
      clearAppliedCoupon: true,
      clearPaymentVerification: true,
      clearActiveRazorpayOrder: true,
    ));
  }

  void _onSelectAddress(SelectAddressEvent event, Emitter<CustomerState> emit) {
    CustomerAddressEntity? matched;
    if (state.savedAddresses.isNotEmpty) {
      for (final a in state.savedAddresses) {
        if (a.formattedFullAddress == event.address ||
            a.line1 == event.address ||
            event.address.contains(a.line1)) {
          OrderRemoteDataSourceImpl.setCachedAddressId(a.id);
          matched = a;
          break;
        }
      }
    }

    final targetLat = event.lat ?? matched?.lat;
    final targetLng = event.lng ?? matched?.lng;

    emit(state.copyWith(
      selectedAddress: event.address,
      activeLat: targetLat ?? state.activeLat,
      activeLng: targetLng ?? state.activeLng,
    ));
    if (targetLat != null && targetLng != null && targetLat != 0.0 && targetLng != 0.0) {
      add(CheckCustomerLocationEvent(lat: targetLat, lng: targetLng));
    }
  }

  Future<void> _onValidateCart(ValidateCartEvent event, Emitter<CustomerState> emit) async {
    if (state.cartItems.isEmpty) return;
    emit(state.copyWith(isCartValidating: true));

    final items = state.cartItems
        .map((i) => {
              'productId': i.product.id,
              'quantity': i.quantity,
            })
        .toList();

    final result = await _catalogRepo.validateCart(items);
    result.fold(
      (failure) => emit(state.copyWith(
        isCartValidating: false,
        errorMessage: failure.message,
      )),
      (data) => emit(state.copyWith(
        isCartValidating: false,
        cartValidation: data,
      )),
    );
  }

  Future<void> _onPlaceOrder(PlaceOrderEvent event, Emitter<CustomerState> emit) async {
    if (state.cartItems.isEmpty) {
      emit(state.copyWith(errorMessage: 'Cart is empty. Please add items.'));
      return;
    }

    emit(state.copyWith(
      isLoading: true,
      clearPaymentVerification: true,
      clearActiveRazorpayOrder: true,
      clearPlacedOrder: true,
      errorMessage: null,
      paymentErrorMessage: null,
    ));

    final orderItems = state.cartItems.map((cartItem) {
      return OrderItemEntity(
        productId: cartItem.product.id,
        nameSnapshot: cartItem.product.name,
        priceSnapshot: cartItem.product.price,
        unit: cartItem.product.unit,
        quantity: cartItem.quantity,
      );
    }).toList();

    final displayAddress = (event.deliveryAddress != null && event.deliveryAddress!.trim().isNotEmpty)
        ? event.deliveryAddress!.trim()
        : (state.selectedAddress.isNotEmpty && state.selectedAddress != 'Select Delivery Address'
            ? state.selectedAddress
            : (state.savedAddresses.isNotEmpty
                ? state.savedAddresses.firstWhere((a) => a.isDefault, orElse: () => state.savedAddresses.first).formattedFullAddress
                : 'Customer Delivery Address'));

    final effectiveAddressId = (event.deliveryAddressId != null && event.deliveryAddressId!.trim().isNotEmpty)
        ? event.deliveryAddressId!.trim()
        : (state.savedAddresses.isNotEmpty
            ? state.savedAddresses.firstWhere(
                (a) => a.formattedFullAddress == displayAddress || a.isDefault,
                orElse: () => state.savedAddresses.first,
              ).id
            : null);

    if (effectiveAddressId != null && effectiveAddressId.isNotEmpty) {
      OrderRemoteDataSourceImpl.setCachedAddressId(effectiveAddressId);
    }

    final effectiveCouponCode = event.couponCode ?? state.appliedCoupon?.code;
    final effectiveCouponDiscount = event.couponDiscount ?? state.couponDiscount;

    final selectedAddrEntity = state.savedAddresses.where(
      (a) => a.formattedFullAddress == displayAddress || (effectiveAddressId != null && a.id == effectiveAddressId) || a.isDefault,
    ).firstOrNull ?? state.savedAddresses.firstOrNull;

    final effectiveLat = event.latitude ?? state.activeLat ?? selectedAddrEntity?.lat;
    final effectiveLng = event.longitude ?? state.activeLng ?? selectedAddrEntity?.lng;
    final effectiveCity = selectedAddrEntity?.city;
    final effectivePostalCode = selectedAddrEntity?.pincode;

    final result = await _orderRepo.createOrder(
      customerId: event.customerId,
      customerName: event.customerName,
      customerPhone: event.customerPhone,
      storeId: event.storeId,
      storeName: event.storeName,
      storeAddress: event.storeAddress,
      deliveryAddress: displayAddress,
      items: orderItems,
      deliveryFee: state.deliveryFee,
      platformFee: state.platformFee,
      paymentMethod: event.paymentMethod,
      zoneId: event.zoneId ?? state.zoneId,
      deliveryAddressId: effectiveAddressId,
      couponCode: effectiveCouponCode,
      couponDiscount: effectiveCouponDiscount,
      lat: effectiveLat,
      lng: effectiveLng,
      city: effectiveCity,
      postalCode: effectivePostalCode,
      tip: state.selectedTip,
    );

    await result.fold(
      (failure) async {
        emit(state.copyWith(isLoading: false, errorMessage: failure.message));
      },
      (order) async {
        final orderWithAddress = (order.deliveryAddress.isEmpty ||
                RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(order.deliveryAddress) ||
                order.deliveryAddress == 'Default Address' ||
                order.deliveryAddress == 'Customer Default Address')
            ? order.copyWith(deliveryAddress: displayAddress)
            : order;

        final updatedOrders = List<OrderEntity>.from(state.myOrders);
        _inAppMessagingService?.triggerEvent(IInAppMessagingService.customerOrderPlaced);
        final existingIdx = updatedOrders.indexWhere((o) => o.id == orderWithAddress.id);
        if (existingIdx == -1) {
          updatedOrders.insert(0, orderWithAddress);
        } else {
          updatedOrders[existingIdx] = orderWithAddress;
        }

        if (event.paymentMethod == 'COD') {
          // Instantly clear cart and emit success state for instantaneous checkout
          _localCache.clearCart();
          emit(state.copyWith(
            isLoading: false,
            cartItems: [],
            clearCartPricing: true,
            selectedTip: 0.0,
            clearAppliedCoupon: true,
            latestPlacedOrder: orderWithAddress,
            myOrders: updatedOrders,
            successMessage: 'Order #${orderWithAddress.orderNumber} placed successfully! ⚡',
          ));

          // Background fire-and-forget confirmation (non-blocking for UI)
          final paymentDs = _paymentDataSource;
          if (paymentDs != null && RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(orderWithAddress.id)) {
            unawaited(paymentDs.confirmCodPayment(orderWithAddress.id).catchError((_) => false));
          }
        } else {
          // Online Payment (UPI / CARD) - Create Razorpay Order token for real backend order
          emit(state.copyWith(
            isLoading: false,
            isPaymentProcessing: true,
            latestPlacedOrder: orderWithAddress,
            myOrders: updatedOrders,
          ));

          final isMongoId = RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(orderWithAddress.id);
          final paymentDs = _paymentDataSource;
          if (paymentDs != null && isMongoId) {
            try {
              final rzpOrder = await paymentDs.createRazorpayOrder(
                orderWithAddress.id,
                amount: state.cartGrandTotal > 0 ? state.cartGrandTotal : orderWithAddress.grandTotal,
              );
              emit(state.copyWith(
                isPaymentProcessing: false,
                activeRazorpayOrder: rzpOrder,
              ));
            } catch (e) {
              emit(state.copyWith(
                isPaymentProcessing: false,
                activeRazorpayOrder: RazorpayOrderModel(
                  orderId: orderWithAddress.id,
                  razorpayOrderId: '',
                  amount: (state.cartGrandTotal * 100).toInt(),
                  currency: 'INR',
                  keyId: ApiEndpoints.defaultRazorpayKeyId,
                ),
              ));
            }
          } else {
            emit(state.copyWith(
              isPaymentProcessing: false,
              activeRazorpayOrder: RazorpayOrderModel(
                orderId: orderWithAddress.id,
                razorpayOrderId: '',
                amount: (state.cartGrandTotal * 100).toInt(),
                currency: 'INR',
                keyId: ApiEndpoints.defaultRazorpayKeyId,
              ),
            ));
          }
        }
      },
    );
  }

  Future<void> _onLoadAddresses(LoadAddressesEvent event, Emitter<CustomerState> emit) async {
    final isAuthenticated = await _hasValidToken();
    if (!isAuthenticated) return;
    final res = await _catalogRepo.getAddresses();
    res.fold(
      (f) => emit(state.copyWith(errorMessage: f.message)),
      (addresses) {
        final deduped = CustomerAddressEntity.deduplicate(addresses);
        emit(state.copyWith(savedAddresses: deduped));
      },
    );
  }

  Future<void> _onAddAddress(AddAddressEvent event, Emitter<CustomerState> emit) async {
    // Check if an address matching this location/label already exists in state.savedAddresses
    final existingIndex = state.savedAddresses.indexWhere((a) => a.isSameLocationAs(event.address));
    if (existingIndex != -1) {
      final existing = state.savedAddresses[existingIndex];
      final isMongoId = RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(existing.id);
      if (isMongoId) {
        OrderRemoteDataSourceImpl.setCachedAddressId(existing.id);
        final updateRes = await _catalogRepo.updateAddress(existing.id, event.address);
        updateRes.fold(
          (f) {
            emit(state.copyWith(
              selectedAddress: existing.formattedFullAddress,
              successMessage: 'Delivery address selected',
            ));
          },
          (updated) {
            final list = List<CustomerAddressEntity>.from(state.savedAddresses);
            list[existingIndex] = updated;
            final deduped = CustomerAddressEntity.deduplicate(list);
            OrderRemoteDataSourceImpl.setCachedAddressId(updated.id);
            emit(state.copyWith(
              savedAddresses: deduped,
              selectedAddress: updated.formattedFullAddress,
              successMessage: 'Delivery address updated successfully',
            ));
          },
        );
        return;
      }
    }


    final res = await _catalogRepo.addAddress(event.address);
    res.fold(
      (f) => emit(state.copyWith(errorMessage: f.message)),
      (added) {
        final list = List<CustomerAddressEntity>.from(state.savedAddresses)..add(added);
        final deduped = CustomerAddressEntity.deduplicate(list);
        OrderRemoteDataSourceImpl.setCachedAddressId(added.id);
        emit(state.copyWith(
          savedAddresses: deduped,
          selectedAddress: added.formattedFullAddress,
          successMessage: 'Delivery address added successfully',
        ));
      },
    );
  }

  Future<void> _onDeleteAddress(DeleteAddressEvent event, Emitter<CustomerState> emit) async {
    final res = await _catalogRepo.deleteAddress(event.addressId);
    res.fold(
      (f) => emit(state.copyWith(errorMessage: f.message)),
      (_) {
        final list = state.savedAddresses.where((a) => a.id != event.addressId).toList();
        emit(state.copyWith(savedAddresses: list));
      },
    );
  }

  Future<void> _onSetDefaultAddress(SetDefaultAddressEvent event, Emitter<CustomerState> emit) async {
    final res = await _catalogRepo.setDefaultAddress(event.addressId);
    res.fold(
      (f) => emit(state.copyWith(errorMessage: f.message)),
      (_) {
        final list = state.savedAddresses.map((a) {
          return CustomerAddressEntity(
            id: a.id,
            label: a.label,
            line1: a.line1,
            line2: a.line2,
            landmark: a.landmark,
            city: a.city,
            state: a.state,
            pincode: a.pincode,
            lat: a.lat,
            lng: a.lng,
            isDefault: a.id == event.addressId,
            contactName: a.contactName,
            contactPhone: a.contactPhone,
            deliveryInstructions: a.deliveryInstructions,
          );
        }).toList();

        final def = list.firstWhere((a) => a.id == event.addressId);
        OrderRemoteDataSourceImpl.setCachedAddressId(def.id);
        emit(state.copyWith(
          savedAddresses: list,
          selectedAddress: def.formattedFullAddress,
        ));
      },
    );
  }

  Future<void> _onUpdateAddress(UpdateAddressEvent event, Emitter<CustomerState> emit) async {
    final res = await _catalogRepo.updateAddress(event.addressId, event.address);
    res.fold(
      (f) => emit(state.copyWith(errorMessage: f.message)),
      (updated) {
        final oldAddr = state.savedAddresses.firstWhere(
          (a) => a.id == event.addressId,
          orElse: () => updated,
        );
        final list = state.savedAddresses.map((a) => a.id == event.addressId ? updated : a).toList();
        if (!list.any((a) => a.id == event.addressId)) {
          list.add(updated);
        }
        final deduped = CustomerAddressEntity.deduplicate(list);
        String selected = state.selectedAddress;
        final wasSelected = selected == oldAddr.formattedFullAddress ||
            selected == oldAddr.line1 ||
            selected.contains(oldAddr.line1) ||
            selected == 'Select Delivery Address' ||
            state.savedAddresses.length <= 1;

        if (updated.isDefault || wasSelected) {
          selected = updated.formattedFullAddress;
          OrderRemoteDataSourceImpl.setCachedAddressId(updated.id);
        }
        emit(state.copyWith(
          savedAddresses: deduped,
          selectedAddress: selected,
          successMessage: 'Address updated successfully',
        ));
      },
    );
  }

  Future<void> _onLoadRecommendations(LoadRecommendationsEvent event, Emitter<CustomerState> emit) async {
    final res = await _catalogRepo.getRecommendations();
    res.fold(
      (f) => null,
      (recs) => emit(state.copyWith(recommendations: recs)),
    );
  }

  Future<void> _onLoadWishlist(LoadWishlistEvent event, Emitter<CustomerState> emit) async {
    final isAuthenticated = await _hasValidToken();
    if (!isAuthenticated) return;
    final res = await _catalogRepo.getWishlist();
    res.fold(
      (f) => null,
      (products) {
        final ids = products.map((p) => p.id).toSet();
        emit(state.copyWith(wishlistProductIds: ids));
      },
    );
  }

  Future<void> _onToggleWishlist(ToggleWishlistEvent event, Emitter<CustomerState> emit) async {
    final isWishlisted = state.wishlistProductIds.contains(event.productId);
    final updated = Set<String>.from(state.wishlistProductIds);

    if (isWishlisted) {
      updated.remove(event.productId);
      emit(state.copyWith(wishlistProductIds: updated));
      await _catalogRepo.removeFromWishlist(event.productId);
    } else {
      updated.add(event.productId);
      emit(state.copyWith(wishlistProductIds: updated));
      await _catalogRepo.addToWishlist(event.productId);
    }
  }

  Future<void> _onLoadNotifications(LoadNotificationsEvent event, Emitter<CustomerState> emit) async {
    final isAuthenticated = await _hasValidToken();
    if (!isAuthenticated) return;

    // C-1 Fix: run both calls in parallel — they are independent API endpoints.
    final notifsFuture = _catalogRepo.getNotifications();
    final countFuture = _catalogRepo.getUnreadNotificationCount();

    final notifsRes = await notifsFuture;
    final countRes = await countFuture;

    List<Map<String, dynamic>> notifs = state.notifications;
    int unread = state.unreadNotificationsCount;
    notifsRes.fold((f) => null, (list) => notifs = list);
    countRes.fold((f) => null, (cnt) => unread = cnt);

    if (notifs.isNotEmpty) {
      final actualUnread = notifs.where((n) => n['read'] != true && n['isRead'] != true).length;
      if (actualUnread > 0) {
        unread = actualUnread;
      }
    }


    emit(state.copyWith(notifications: notifs, unreadNotificationsCount: unread));
  }

  Future<void> _onMarkNotificationRead(MarkNotificationReadEvent event, Emitter<CustomerState> emit) async {
    final updated = state.notifications.map((n) {
      if (n['id'] == event.notificationId || n['_id'] == event.notificationId) {
        return Map<String, dynamic>.from(n)
          ..['read'] = true
          ..['isRead'] = true;
      }
      return n;
    }).toList();
    final actualUnread = updated.where((n) => n['read'] != true && n['isRead'] != true).length;
    emit(state.copyWith(notifications: updated, unreadNotificationsCount: actualUnread));
    await _catalogRepo.markNotificationRead(event.notificationId);
  }

  Future<void> _onMarkAllNotificationsRead(MarkAllNotificationsReadEvent event, Emitter<CustomerState> emit) async {
    final updated = state.notifications.map((n) {
      return Map<String, dynamic>.from(n)
        ..['read'] = true
        ..['isRead'] = true;
    }).toList();
    emit(state.copyWith(notifications: updated, unreadNotificationsCount: 0));
    await _catalogRepo.markAllNotificationsRead();
  }

  Future<void> _onCheckCustomerLocation(CheckCustomerLocationEvent event, Emitter<CustomerState> emit) async {
    emit(state.copyWith(isCheckingLocation: true, clearOutOfDeliveryZoneMessage: true));
    final res = await _catalogRepo.checkLocation(lat: event.lat, lng: event.lng);
    await res.fold(
      (failure) async {
        await _localCache.cacheActiveLocation(
          lat: event.lat,
          lng: event.lng,
          address: state.selectedAddress,
          zoneId: null,
          zoneName: null,
          inZone: false,
        );
        emit(state.copyWith(
          isCheckingLocation: false,
          inZone: false,
          zoneId: null,
          zoneName: null,
          stores: const <StoreEntity>[],
          filteredProducts: const <ProductEntity>[],
          outOfDeliveryZoneMessage: failure.message,
        ));
      },
      (zone) async {
        List<StoreEntity> filteredStores = state.stores;
        if (zone.inZone) {
          final fetchRes = await _catalogRepo.getNearbyStores(lat: event.lat, lng: event.lng);
          fetchRes.fold((_) {}, (sList) {
            if (zone.zoneId != null && zone.zoneId!.isNotEmpty) {
              final matching = sList
                  .where((s) => s.zoneId == null || s.zoneId!.isEmpty || s.zoneId == zone.zoneId)
                  .toList();
              filteredStores = matching.isNotEmpty ? matching : sList;
            } else if (sList.isNotEmpty) {
              filteredStores = sList;
            }
          });

          await _localCache.cacheActiveLocation(
            lat: event.lat,
            lng: event.lng,
            address: state.selectedAddress,
            zoneId: zone.zoneId,
            zoneName: zone.zoneName,
            inZone: zone.inZone,
          );
        } else {
          filteredStores = const <StoreEntity>[];
          await _localCache.cacheActiveLocation(
            lat: event.lat,
            lng: event.lng,
            address: state.selectedAddress,
            zoneId: null,
            zoneName: null,
            inZone: false,
          );
        }

        var updatedFiltered = zone.inZone
            ? _applyFilters(
                products: state.allProducts,
                categoryId: state.selectedCategoryId,
                query: state.searchQuery,
                extraStores: filteredStores.isNotEmpty ? filteredStores : null,
              )
            : const <ProductEntity>[];

        if (zone.inZone && updatedFiltered.isEmpty && state.allProducts.isNotEmpty) {
          updatedFiltered = _applyFilters(
            products: state.allProducts,
            categoryId: state.selectedCategoryId,
            query: state.searchQuery,
          );
        }

        emit(state.copyWith(
          isCheckingLocation: false,
          inZone: zone.inZone,
          zoneId: zone.inZone ? zone.zoneId : null,
          zoneName: zone.inZone ? zone.zoneName : null,
          zoneDeliveryFee: zone.inZone ? zone.deliveryFee : null,
          zonePlatformFee: zone.inZone ? zone.platformFee : null,
          zoneFreeDeliveryThreshold: zone.inZone ? zone.freeDeliveryThreshold : null,
          zoneMinOrderAmount: zone.inZone ? zone.minOrderAmount : null,
          clearZonePricing: !zone.inZone,
          clearCartPricing: !zone.inZone,
          activeLat: event.lat,
          activeLng: event.lng,
          stores: filteredStores,
          filteredProducts: updatedFiltered,
          outOfDeliveryZoneMessage: zone.inZone ? null : (zone.message ?? 'Location is outside the delivery zone'),
        ));
        if (zone.inZone && state.cartItems.isNotEmpty) {
          add(const FetchCartPricingEvent());
        }
      },
    );
  }

  Future<void> _onGetPaymentStatus(GetPaymentStatusEvent event, Emitter<CustomerState> emit) async {
    final res = await _orderRepo.getPaymentStatus(event.orderId);
    res.fold(
      (_) => null,
      (statusMap) => emit(state.copyWith(paymentStatus: statusMap)),
    );
  }

  Future<void> _onCancelOrder(CancelOrderEvent event, Emitter<CustomerState> emit) async {
    final res = await _orderRepo.cancelOrder(event.orderId, event.reason);
    res.fold(
      (f) => emit(state.copyWith(errorMessage: f.message)),
      (success) {
        if (success) {
          final updatedOrders = state.myOrders.map((o) {
            if (o.id == event.orderId || o.orderNumber == event.orderId) {
              return o.copyWith(status: OrderStatus.cancelled);
            }
            return o;
          }).toList();
          emit(state.copyWith(
            myOrders: updatedOrders,
            successMessage: 'Order cancelled successfully',
          ));
          add(const RefreshCustomerOrdersEvent());
        } else {
          emit(state.copyWith(errorMessage: 'Unable to cancel order'));
        }
      },
    );
  }

  Future<void> _onReviewOrder(ReviewOrderEvent event, Emitter<CustomerState> emit) async {
    final res = await _orderRepo.reviewOrder(
      event.orderId,
      event.storeRating,
      event.deliveryRating,
      event.storeReview.isNotEmpty ? event.storeReview : event.deliveryReview,
    );
    res.fold(
      (f) => emit(state.copyWith(errorMessage: f.message)),
      (_) => emit(state.copyWith(successMessage: 'Review submitted successfully! Thank you.')),
    );
  }

  Future<void> _onTrackOrder(TrackOrderEvent event, Emitter<CustomerState> emit) async {
    final res = await _orderRepo.trackOrder(event.orderId);
    res.fold(
      (f) => emit(state.copyWith(errorMessage: f.message)),
      (data) {
        // Track payload received live from backend
      },
    );
  }

  void _onOrdersStreamUpdated(CustomerOrdersStreamUpdated event, Emitter<CustomerState> emit) {
    emit(state.copyWith(myOrders: _mergeOrdersPreservingTerminal(event.orders)));
  }

  void _onProductsStreamUpdated(CustomerProductsStreamUpdated event, Emitter<CustomerState> emit) {
    // Preserve any dynamically loaded store products that may not be in event.products
    final allProductsMap = <String, ProductEntity>{};
    for (final p in state.allProducts) {
      allProductsMap[p.id] = p;
    }
    for (final p in event.products) {
      allProductsMap[p.id] = p;
    }
    final mergedAll = allProductsMap.values.toList();

    // If user is actively filtering by a store, never wipe out their store products view!
    if (state.selectedStore != null) {
      final storeId = state.selectedStore!.id;
      final storeProds = mergedAll.where((p) => p.storeId == storeId).toList();
      if (storeProds.isNotEmpty) {
        final filtered = _applyFilters(
          products: storeProds,
          categoryId: state.selectedCategoryId,
          query: state.searchQuery,
          sortOption: state.sortOption,
          inStockOnly: state.inStockOnly,
          fastDeliveryOnly: state.fastDeliveryOnly,
          dealsOnly: state.dealsOnly,
          storeId: storeId,
        );
        emit(state.copyWith(allProducts: mergedAll, filteredProducts: filtered));
        return;
      } else if (state.filteredProducts.isNotEmpty) {
        // Do not wipe out existing store products with an empty list!
        emit(state.copyWith(allProducts: mergedAll));
        return;
      }
    }


    final filtered = _applyFilters(
      products: mergedAll,
      categoryId: state.selectedCategoryId,
      query: state.searchQuery,
      sortOption: state.sortOption,
      inStockOnly: state.inStockOnly,
      fastDeliveryOnly: state.fastDeliveryOnly,
      dealsOnly: state.dealsOnly,
      storeId: state.selectedStore?.id,
    );
    emit(state.copyWith(allProducts: mergedAll, filteredProducts: filtered));
  }

  void _onStoresStreamUpdated(CustomerStoresStreamUpdated event, Emitter<CustomerState> emit) {
    if (!state.inZone) {
      emit(state.copyWith(
        stores: const [],
        selectedStore: null,
        clearSelectedStore: true,
      ));
      return;
    }

    final targetZoneId = state.zoneId;
    List<StoreEntity> filteredStores = event.stores;
    if (targetZoneId != null && targetZoneId.isNotEmpty) {
      final matching = event.stores
          .where((s) => s.zoneId == null || s.zoneId!.isEmpty || s.zoneId == targetZoneId)
          .toList();
      filteredStores = matching.isNotEmpty ? matching : event.stores;
    }

    StoreEntity? updatedSelected = state.selectedStore;
    bool shouldClear = false;
    if (updatedSelected != null) {
      final matching = filteredStores.where((s) => s.id == updatedSelected!.id).firstOrNull;
      if (matching != null) {
        updatedSelected = matching;
        if (!matching.isOpen) {
          // Deselect store if closed so user is not stuck on a closed store view
          updatedSelected = null;
          shouldClear = true;
        }
      } else {
        updatedSelected = null;
        shouldClear = true;
      }
    }

    emit(state.copyWith(
      stores: filteredStores.isNotEmpty ? filteredStores : (state.stores.isNotEmpty ? state.stores : filteredStores),
      selectedStore: updatedSelected,
      clearSelectedStore: shouldClear,
    ));
  }

  void _onApplyProductFilters(ApplyProductFiltersEvent event, Emitter<CustomerState> emit) {
    final filtered = _applyFilters(
      products: state.allProducts,
      categoryId: state.selectedCategoryId,
      query: state.searchQuery,
      sortOption: event.sortOption,
      inStockOnly: event.inStockOnly,
      fastDeliveryOnly: event.fastDeliveryOnly,
      dealsOnly: event.dealsOnly,
      foodType: event.foodType,
      storeId: state.selectedStore?.id,
    );
    emit(state.copyWith(
      sortOption: event.sortOption,
      inStockOnly: event.inStockOnly,
      fastDeliveryOnly: event.fastDeliveryOnly,
      dealsOnly: event.dealsOnly,
      selectedFoodType: event.foodType,
      clearFoodType: event.foodType == null,
      filteredProducts: filtered,
    ));
  }

  void _onResetProductFilters(ResetProductFiltersEvent event, Emitter<CustomerState> emit) {
    final filtered = _applyFilters(
      products: state.allProducts,
      categoryId: state.selectedCategoryId,
      query: state.searchQuery,
      sortOption: ProductSortOption.relevance,
      inStockOnly: false,
      fastDeliveryOnly: false,
      dealsOnly: false,
      foodType: null,
      storeId: state.selectedStore?.id,
    );
    emit(state.copyWith(
      sortOption: ProductSortOption.relevance,
      inStockOnly: false,
      fastDeliveryOnly: false,
      dealsOnly: false,
      clearFoodType: true,
      filteredProducts: filtered,
    ));
  }

  Future<void> _onLoadMoreProducts(LoadMoreProductsEvent event, Emitter<CustomerState> emit) async {
    if (state.isLoadingMoreProducts || state.hasReachedMaxProducts || state.searchQuery.isNotEmpty) {
      return;
    }

    emit(state.copyWith(isLoadingMoreProducts: true));

    final nextPage = state.currentPage + 1;
    final categoryId = state.selectedCategoryId == 'cat_all' ? null : state.selectedCategoryId;

    final result = await _catalogRepo.searchProducts(
      '',
      category: categoryId,
      page: nextPage,
      limit: 20,
    );

    result.fold(
      (failure) {
        emit(state.copyWith(isLoadingMoreProducts: false));
      },
      (newProducts) {
        if (newProducts.isEmpty) {
          emit(state.copyWith(
            isLoadingMoreProducts: false,
            hasReachedMaxProducts: true,
          ));
        } else {
          final existingIds = state.allProducts.map((p) => p.id).toSet();
          final uniqueNewProducts = newProducts.where((p) => !existingIds.contains(p.id)).toList();

          final updatedAll = [...state.allProducts, ...uniqueNewProducts];
          final updatedFiltered = _applyFilters(
            products: updatedAll,
            categoryId: state.selectedCategoryId,
            query: state.searchQuery,
            sortOption: state.sortOption,
            inStockOnly: state.inStockOnly,
            fastDeliveryOnly: state.fastDeliveryOnly,
            dealsOnly: state.dealsOnly,
            storeId: state.selectedStore?.id,
          );

          emit(state.copyWith(
            allProducts: updatedAll,
            filteredProducts: updatedFiltered,
            currentPage: nextPage,
            isLoadingMoreProducts: false,
            hasReachedMaxProducts: newProducts.length < 20,
          ));
        }
      },
    );
  }

  List<ProductEntity> _applyFilters({
    required List<ProductEntity> products,
    required String categoryId,
    required String query,
    ProductSortOption sortOption = ProductSortOption.relevance,
    bool inStockOnly = false,
    bool fastDeliveryOnly = false,
    bool dealsOnly = false,
    String? storeId,
    List<StoreEntity>? extraStores,
    String? foodType,
  }) {
    // If user is outside serviceable zone or location is out-of-zone, return empty
    if (!state.inZone && state.outOfDeliveryZoneMessage != null) {
      return const <ProductEntity>[];
    }

    final effectiveFoodType = foodType ?? state.selectedFoodType;

    final allKnownStores = <String, StoreEntity>{};
    for (final s in state.stores) {
      if (s.zoneId == null || s.zoneId!.isEmpty || state.zoneId == null || state.zoneId!.isEmpty || s.zoneId == state.zoneId) {
        allKnownStores[s.id] = s;
      }
    }

    if (extraStores != null) {
      for (final s in extraStores) {
        if (s.zoneId == null || s.zoneId!.isEmpty || state.zoneId == null || state.zoneId!.isEmpty || s.zoneId == state.zoneId) {
          allKnownStores[s.id] = s;
        }
      }
    }


    final validStoreIds = allKnownStores.keys.toSet();

    var result = products.where((p) {
      // Exclude developer/test dummy products
      final nameLower = p.name.toLowerCase().trim();
      final descLower = p.description.toLowerCase().trim();
      if (nameLower.contains('test product') ||
          nameLower.contains('customer test') ||
          nameLower.contains('retailer test') ||
          nameLower.contains('fallback product') ||
          nameLower.contains('flow product') ||
          nameLower == 'aa product' ||
          descLower.contains('flow test product')) {
        return false;
      }

      // Zone-based Product Filtering:
      // 1. If user explicitly filtered by a specific store, enforce storeId match strictly
      if (storeId != null && storeId.isNotEmpty) {
        if (p.storeId != storeId) return false;
      } else if (validStoreIds.isNotEmpty && categoryId != 'cat_all') {
        // 2. When filtering by a specific sub-category in an active zone, products must belong to a verified store
        if (p.storeId.isEmpty || !validStoreIds.contains(p.storeId)) {
          return false;
        }
      }

      // 3. If product has an explicit zoneId, ensure it matches current active zone
      if (state.zoneId != null && state.zoneId!.isNotEmpty) {
        if (p.zoneId != null && p.zoneId!.isNotEmpty && p.zoneId != state.zoneId) {
          return false;
        }
      }
      final matchesCat = p.matchesCategory(categoryId, state.categories);
      final matchesQuery = query.isEmpty ||
          p.name.toLowerCase().contains(query) ||
          p.description.toLowerCase().contains(query) ||
          (p.storeName != null && p.storeName!.toLowerCase().contains(query)) ||
          p.storeId.toLowerCase().contains(query) ||
          allKnownStores.values.any((s) => s.id == p.storeId && (
              s.name.toLowerCase().contains(query) ||
              s.category.toLowerCase().contains(query) ||
              s.address.toLowerCase().contains(query)
          ));
      final matchesStock = !inStockOnly || p.stock > 0;
      final matchesDeals = !dealsOnly || (p.originalPrice != null && p.originalPrice! > p.price);
      final matchesFoodType = p.matchesDietaryPreference(effectiveFoodType);
      return matchesCat && matchesQuery && matchesStock && matchesDeals && matchesFoodType;
    }).toList();

    switch (sortOption) {
      case ProductSortOption.priceLowToHigh:
        result.sort((a, b) => a.price.compareTo(b.price));
        break;
      case ProductSortOption.priceHighToLow:
        result.sort((a, b) => b.price.compareTo(a.price));
        break;
      case ProductSortOption.ratingHighToLow:
        result.sort((a, b) => (b.rating ?? 4.0).compareTo(a.rating ?? 4.0));
        break;
      case ProductSortOption.relevance:
        break;
    }

    return result;
  }

  void _persistCart(List<CartItemEntity> items) {
    final mapList = items.map<Map<String, dynamic>>((i) => <String, dynamic>{
          'productId': i.product.id,
          'name': i.product.name,
          'price': i.product.price,
          'unit': i.product.unit,
          'quantity': i.quantity,
          // Persist store + image so cart survives restart with correct storeId
          'storeId': i.product.storeId,
          'imageUrl': i.product.imageUrl,
          'categoryId': i.product.categoryId,
          'description': i.product.description,
          if (i.product.stock > 0) 'stock': i.product.stock,
        }).toList();
    _localCache.saveCartItems(mapList);
  }

  Future<void> _onInitiateRazorpayPayment(InitiateRazorpayPaymentEvent event, Emitter<CustomerState> emit) async {
    _inAppMessagingService?.setMessagesSuppressed(true);
    emit(state.copyWith(
      isPaymentProcessing: true,
      clearPlacedOrder: false,
      clearPaymentVerification: true,
      errorMessage: null,
      paymentErrorMessage: null,
    ));
    final paymentDs = _paymentDataSource;
    if (paymentDs != null) {
      try {
        final rzpOrder = await paymentDs.createRazorpayOrder(
          event.orderId,
          amount: state.cartGrandTotal,
          currency: 'INR',
        );
        emit(state.copyWith(
          isPaymentProcessing: false,
          activeRazorpayOrder: rzpOrder,
        ));
      } catch (e) {
        emit(state.copyWith(
          isPaymentProcessing: false,
          activeRazorpayOrder: RazorpayOrderModel(
            orderId: event.orderId,
            razorpayOrderId: '',
            amount: (state.cartGrandTotal * 100).toInt(),
            currency: 'INR',
            keyId: ApiEndpoints.defaultRazorpayKeyId,
          ),
        ));
      }
    }
 else {
      emit(state.copyWith(
        isPaymentProcessing: false,
        activeRazorpayOrder: RazorpayOrderModel(
          orderId: event.orderId,
          razorpayOrderId: '',
          amount: (state.cartGrandTotal * 100).toInt(),
          currency: 'INR',
          keyId: ApiEndpoints.defaultRazorpayKeyId,
        ),
      ));
    }
  }

  Future<void> _onVerifyRazorpayPayment(VerifyRazorpayPaymentEvent event, Emitter<CustomerState> emit) async {
    _inAppMessagingService?.setMessagesSuppressed(false);
    emit(state.copyWith(isPaymentProcessing: true));
    final paymentDs = _paymentDataSource;
    PaymentVerificationModel verification;

    if (paymentDs != null) {
      try {
        verification = await paymentDs.verifyPaymentSignature(
          razorpayOrderId: event.razorpayOrderId,
          razorpayPaymentId: event.razorpayPaymentId,
          razorpaySignature: event.razorpaySignature,
          orderId: event.orderId,
        );
      } catch (e) {
        final msg = e.toString().replaceFirst('Exception: ', '');
        final isVerifyTxFailed = msg.contains('VERIFY_TX_FAILED');
        verification = PaymentVerificationModel(
          success: false,
          paymentId: event.razorpayPaymentId,
          status: 'FAILED',
          orderId: event.orderId,
          idempotent: isVerifyTxFailed,
          errorCode: isVerifyTxFailed ? 'VERIFY_TX_FAILED' : 'VERIFICATION_ERROR',
          errorMessage: msg.isNotEmpty ? msg : 'Payment verification network error. Please retry.',
        );
      }
    }
 else {
      verification = PaymentVerificationModel(
        success: true,
        paymentId: event.razorpayPaymentId,
        status: 'CAPTURED',
        orderId: event.orderId,
      );
    }

    // Section 2.7: Handle VERIFY_TX_FAILED with clear message and retry path; retries are safe/idempotent.
    // Do not show order success until the backend confirms the order/payment state.
    if (verification.isRetryable || verification.errorCode == 'VERIFY_TX_FAILED') {
      emit(state.copyWith(
        isPaymentProcessing: false,
        paymentVerification: verification,
        paymentErrorMessage: verification.errorMessage ??
            'Payment recorded but order update failed. Contact support — retry is safe.',
      ));
      return;
    }

    // Clean Architecture & Resilient Verification:
    // If verification explicitly failed (e.g. SIGNATURE_INVALID), do not show order success.
    if (!verification.success && verification.errorCode == 'SIGNATURE_INVALID') {
      emit(state.copyWith(
        isPaymentProcessing: false,
        paymentVerification: verification,
        paymentErrorMessage: verification.errorMessage ?? 'Payment signature invalid. Verification rejected.',
      ));
      return;
    }

    // If verification returned non-success, do not falsely show order success.
    if (!verification.success || verification.isFailed) {
      emit(state.copyWith(
        isPaymentProcessing: false,
        paymentVerification: verification,
        paymentErrorMessage: verification.errorMessage ?? 'Payment verification failed. Please check payment status.',
      ));
      return;
    }

    final isPending = verification.isPending || verification.status == 'PENDING' || verification.status == 'AUTHORIZED';
    final isConfirmed = verification.success && !isPending && !verification.isFailed;

    if (isConfirmed || isPending) {
      _localCache.clearCart();
      final effectivePaymentStatus = isPending ? 'PENDING' : 'COMPLETED';
      OrderEntity? updatedOrder = state.latestPlacedOrder;
      if (updatedOrder == null && event.orderId.isNotEmpty) {
        final found = state.myOrders.where((o) => o.id == event.orderId || o.orderNumber == event.orderId);
        if (found.isNotEmpty) {
          updatedOrder = found.first;
        }
      }
      if (updatedOrder != null) {
        updatedOrder = updatedOrder.copyWith(
          paymentStatus: effectivePaymentStatus,
          status: OrderStatus.placed,
        );
      }

      final List<OrderEntity> updatedOrders = List.from(state.myOrders);
      final targetId = event.orderId.isNotEmpty ? event.orderId : (updatedOrder?.id ?? '');
      if (targetId.isNotEmpty) {
        await _orderRepo.updatePaymentStatus(
          orderId: targetId,
          paymentStatus: effectivePaymentStatus,
        );
      }

      final existingIdx = updatedOrders.indexWhere((o) =>
          (targetId.isNotEmpty && o.id == targetId) ||
          (updatedOrder != null && o.id == updatedOrder.id));

      if (existingIdx != -1) {
        updatedOrders[existingIdx] = updatedOrders[existingIdx].copyWith(paymentStatus: effectivePaymentStatus);
      } else if (updatedOrder != null) {
        updatedOrders.insert(0, updatedOrder);
      }

      final successMsg = isPending
          ? 'Order registered • Payment is awaiting bank clearance ⏳'
          : 'Payment verified successfully! Order is confirmed ⚡';

      emit(state.copyWith(
        isPaymentProcessing: false,
        cartItems: [],
        clearCartPricing: true,
        selectedTip: 0.0,
        clearAppliedCoupon: true,
        clearActiveRazorpayOrder: true,
        latestPlacedOrder: updatedOrder,
        myOrders: updatedOrders,
        paymentVerification: verification,
        successMessage: successMsg,
      ));
    } else {
      emit(state.copyWith(
        isPaymentProcessing: false,
        paymentErrorMessage: 'Payment verification failed. Please check transaction with bank.',
        errorMessage: 'Payment verification failed. Please try again.',
      ));
    }
  }

  void _onRazorpayPaymentFailed(RazorpayPaymentFailedEvent event, Emitter<CustomerState> emit) {
    _inAppMessagingService?.setMessagesSuppressed(false);
    emit(state.copyWith(
      isPaymentProcessing: false,
      clearActiveRazorpayOrder: true,
      clearPaymentVerification: true,
      paymentErrorMessage: event.errorMessage,
      errorMessage: 'Payment cancelled or failed: ${event.errorMessage}',
    ));
  }

  Future<void> _onRegisterPushToken(RegisterCustomerPushTokenEvent event, Emitter<CustomerState> emit) async {
    try {
      await _localCache.saveFcmToken(event.fcmToken);
    } catch (_) {}
    await _catalogRepo.registerDeviceToken(
      fcmToken: event.fcmToken,
      platform: event.platform,
      deviceId: event.deviceId ?? 'device_${DateTime.now().millisecondsSinceEpoch % 100000}',
    );
  }

  Future<void> _onPushNotificationReceived(CustomerPushNotificationReceivedEvent event, Emitter<CustomerState> emit) async {
    final payload = event.notificationPayload;
    final fromTap = payload['fromTap'] == true;
    final updatedNotifs = List<Map<String, dynamic>>.from(state.notifications);
    final rawId = payload['id']?.toString() ?? payload['_id']?.toString();
    final notifId = (rawId != null && rawId.isNotEmpty) ? rawId : 'notif_${DateTime.now().millisecondsSinceEpoch}';
    final notifTitle = payload['title']?.toString() ?? 'Quick Tick Notification';
    final notifBody = payload['body']?.toString() ?? payload['message']?.toString() ?? '';
    String? orderId = payload['orderId']?.toString();
    if (orderId == null || orderId.isEmpty) {
      final regMatch = RegExp(r'QC-\d{6}-\d{4}').firstMatch('$notifTitle $notifBody');
      if (regMatch != null) orderId = regMatch.group(0);
    }

    // Prevent duplicating alerts when both Socket.IO and FCM deliver the same notification,
    // or when the user taps an OS notification that was already added in the foreground.
    final now = DateTime.now();
    final signature = '$notifTitle|$notifBody|${orderId ?? ''}';
    final lastSeen = _recentNotifSignatures[signature];
    final isRecentDuplicate = lastSeen != null && now.difference(lastSeen) < const Duration(seconds: 10);
    final alreadyStoredById = rawId != null &&
        rawId.isNotEmpty &&
        updatedNotifs.any((n) => (n['id']?.toString() ?? n['_id']?.toString()) == rawId);

    if (!fromTap && isRecentDuplicate) {
      return;
    }
    _recentNotifSignatures[signature] = now;

    var nextUnreadCount = state.unreadNotificationsCount;
    if (!alreadyStoredById && !isRecentDuplicate) {
      updatedNotifs.insert(0, {
        'id': notifId,
        '_id': notifId,
        'title': notifTitle,
        'body': notifBody,
        'message': notifBody,
        'time': 'Just now',
        'read': fromTap,
        'isRead': fromTap,
        'type': payload['type']?.toString() ?? 'ORDER_UPDATE',
        'orderId': ?orderId,
      });
      if (!fromTap) {
        nextUnreadCount += 1;
      }
    }


    emit(state.copyWith(
      notifications: updatedNotifs,
      unreadNotificationsCount: nextUnreadCount,
      latestPushNotification: payload,
    ));

    // Auto-refresh orders or banners when matching notification payload arrives
    final type = payload['type']?.toString() ?? '';
    if (type.toUpperCase().contains('BANNER')) {
      add(const FetchHeroBannersEvent(forceRefresh: true));
    }
    if (type.toUpperCase().contains('ORDER') || (orderId != null && orderId.isNotEmpty)) {
      final res = await _orderRepo.getCustomerOrders('');
      res.fold((_) => null, (orders) {
        if (orders.isNotEmpty) {
          emit(state.copyWith(myOrders: orders));
        }
      });
    }
  }

  Future<void> _onFetchHeroBanners(FetchHeroBannersEvent event, Emitter<CustomerState> emit) async {
    // Only debounce rapid unforced requests (< 15 seconds) if we already have banners; always honor forceRefresh
    if (!event.forceRefresh && state.heroBannersFetchedAt != null && state.heroBanners.isNotEmpty) {
      final diff = DateTime.now().difference(state.heroBannersFetchedAt!);
      if (diff < const Duration(seconds: 15)) {
        return; // Respect short debounce
      }
    }


    final res = await _catalogRepo.getHeroBanners(app: 'CUSTOMER');
    res.fold(
      (failure) {
        // Silent error fallback: keep cached banners during offline/network failure
      },
      (banners) {
        // Filter strictly for active customer banners
        final activeBanners = banners.where((b) => b.isActive).toList();
        // Sort banners by order ascending per spec
        final sorted = List<HeroBannerEntity>.from(activeBanners)
          ..sort((a, b) => a.order.compareTo(b.order));
        emit(state.copyWith(
          heroBanners: sorted,
          heroBannersFetchedAt: DateTime.now(),
        ));
      },
    );
  }

  Future<void> _onFetchAvailableCoupons(
    FetchAvailableCouponsEvent event,
    Emitter<CustomerState> emit,
  ) async {
    final effectiveRetailerId = event.retailerId ??
        (state.cartItems.isNotEmpty ? state.cartItems.first.product.storeId : null) ??
        (state.stores.isNotEmpty ? state.stores.first.id : null);

    final res = await _catalogRepo.getAvailableCoupons(retailerId: effectiveRetailerId);
    res.fold(
      (_) => null,
      (coupons) => emit(state.copyWith(availableCoupons: coupons)),
    );
  }

  Future<void> _onApplyCoupon(
    ApplyCouponEvent event,
    Emitter<CustomerState> emit,
  ) async {
    emit(state.copyWith(isApplyingCoupon: true, clearCouponError: true));
    final res = await _catalogRepo.validateCoupon(
      code: event.code,
      cartId: event.cartId,
      retailerId: event.retailerId,
    );

    res.fold(
      (failure) => emit(state.copyWith(
        isApplyingCoupon: false,
        couponErrorMessage: failure.message,
      )),
      (validation) {
        if (!validation.isValid) {
          emit(state.copyWith(
            isApplyingCoupon: false,
            couponErrorMessage: validation.errorMessage ?? 'Invalid coupon code',
          ));
        } else {
          emit(state.copyWith(
            isApplyingCoupon: false,
            appliedCoupon: validation,
            clearCouponError: true,
            successMessage: 'Coupon "${validation.code}" applied! Saved ₹${validation.discount.toStringAsFixed(0)}',
          ));
          add(FetchCartPricingEvent(couponCode: validation.code));
        }
      },
    );
  }

  void _onRemoveCoupon(
    RemoveCouponEvent event,
    Emitter<CustomerState> emit,
  ) {
    emit(state.copyWith(
      clearAppliedCoupon: true,
      clearCouponError: true,
      successMessage: 'Coupon removed',
    ));
    add(const FetchCartPricingEvent(couponCode: ''));
  }

  Future<void> _onFetchCartPricing(
    FetchCartPricingEvent event,
    Emitter<CustomerState> emit,
  ) async {
    if (state.cartItems.isEmpty) {
      emit(state.copyWith(clearCartPricing: true));
      return;
    }
    final coupon = event.couponCode ?? state.appliedCoupon?.code;
    final tip = event.tip ?? state.selectedTip;
    final res = await _catalogRepo.getCartPricing(
      couponCode: coupon,
      tip: tip,
      zoneId: state.zoneId,
      lat: state.activeLat,
      lng: state.activeLng,
    );
    res.fold(
      (failure) {
        // Retain fallback local calculations
      },
      (pricing) {
        final currentSub = state.cartItems.fold(0.0, (acc, item) => acc + item.total);
        if (pricing.subtotal > 0 && pricing.total > 0 && (pricing.subtotal - currentSub).abs() < 0.05) {
          emit(state.copyWith(cartPricing: pricing));
        } else {
          // If server pricing is 0 or obsolete (does not match local items), clear cartPricing so local calculation remains 100% accurate
          emit(state.copyWith(clearCartPricing: true));
        }
      },
    );
  }

  void _onSelectTip(
    SelectTipEvent event,
    Emitter<CustomerState> emit,
  ) {
    emit(state.copyWith(selectedTip: event.tip));
    add(FetchCartPricingEvent(tip: event.tip));
  }

  Future<void> _onDownloadOrderInvoice(
    DownloadOrderInvoiceEvent event,
    Emitter<CustomerState> emit,
  ) async {
    emit(state.copyWith(isDownloadingInvoice: true, clearLastDownloadedInvoicePath: true));

    List<int>? bytes;
    final res = await _orderRepo.downloadOrderInvoice(event.orderId);
    res.fold(
      (_) => null,
      (remoteBytes) {
        if (remoteBytes.isNotEmpty) {
          bytes = remoteBytes;
        }
      },
    );

    // If remote endpoint did not return valid bytes or failed (e.g. 404 / worker pending)
    if (bytes == null || bytes!.isEmpty) {
      emit(state.copyWith(
        isDownloadingInvoice: false,
        errorMessage: 'Something went wrong, will be downloaded in some time.',
      ));
      return;
    }

    try {
      // Use app documents directory so the file is accessible to the user
      final docsDir = await getApplicationDocumentsDirectory();
      final safeOrderId = event.orderId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final file = File('${docsDir.path}/invoice_$safeOrderId.pdf');
      await file.writeAsBytes(bytes!, flush: true);

      emit(state.copyWith(
        isDownloadingInvoice: false,
        lastDownloadedInvoicePath: file.path,
        successMessage: 'Invoice ready',
      ));

      // Automatically open the downloaded PDF in the system viewer
      try {
        final openResult = await OpenFilex.open(file.path, type: 'application/pdf');
        if (openResult.type != ResultType.done) {
          // If system PDF viewer isn't available or fails, trigger system share sheet as seamless fallback
          await SharePlus.instance.share(
            ShareParams(
              files: [XFile(file.path, mimeType: 'application/pdf', name: 'invoice_$safeOrderId.pdf')],
              subject: 'Invoice for Order #${event.orderId}',
            ),
          );
        }
      } catch (_) {
        try {
          await SharePlus.instance.share(
            ShareParams(
              files: [XFile(file.path, mimeType: 'application/pdf', name: 'invoice_$safeOrderId.pdf')],
              subject: 'Invoice for Order #${event.orderId}',
            ),
          );
        } catch (_) {}
      }
    } catch (e) {
      emit(state.copyWith(
        isDownloadingInvoice: false,
        errorMessage: 'Could not save invoice file: $e',
      ));
    }
  }

  Future<void> _onChangeLanguage(
    ChangeCustomerLanguageEvent event,
    Emitter<CustomerState> emit,
  ) async {
    final newLang = AppLanguage.fromCode(event.languageCode);
    await _localCache.setAppLanguage(newLang.code);
    final msg = newLang == AppLanguage.kannada
        ? 'ಆ್ಯಪ್ ಭಾಷೆಯನ್ನು ಕನ್ನಡಕ್ಕೆ ಬದಲಾಯಿಸಲಾಗಿದೆ'
        : 'App language set to English';
    emit(state.copyWith(
      language: newLang,
      successMessage: msg,
    ));
  }

  Future<void> _onSubmitOrderReview(
    SubmitOrderReviewEvent event,
    Emitter<CustomerState> emit,
  ) async {
    emit(state.copyWith(isSubmittingReview: true));

    final combinedComment = StringBuffer();
    if (event.storeTags.isNotEmpty) {
      combinedComment.write('Store: ${event.storeTags.join(", ")}. ');
    }
    if (event.riderTags.isNotEmpty) {
      combinedComment.write('Rider: ${event.riderTags.join(", ")}. ');
    }
    if (event.comment.trim().isNotEmpty) {
      combinedComment.write(event.comment.trim());
    }

    final res = await _orderRepo.reviewOrder(
      event.orderId,
      event.storeRating,
      event.deliveryRating,
      combinedComment.toString().trim(),
    );

    final updatedReviewed = Set<String>.from(state.reviewedOrderIds)..add(event.orderId);

    // Persist via the cache service layer — no direct SharedPreferences in BLoC
    await _localCache.saveReviewedOrderIds(updatedReviewed);

    res.fold(
      (failure) {
        emit(state.copyWith(
          isSubmittingReview: false,
          errorMessage: 'Could not submit rating: ${failure.message}',
        ));
      },
      (success) {
        emit(state.copyWith(
          isSubmittingReview: false,
          reviewedOrderIds: updatedReviewed,
          successMessage: 'Thank you for your rating & feedback! ⭐',
        ));
      },
    );
  }

  void _onFilterStores(FilterStoresEvent event, Emitter<CustomerState> emit) {
    if (state.storeFilter == event.filterType) return;
    emit(state.copyWith(storeFilter: event.filterType));
  }

  static List<String> _safeInitialSearchHistory(ICatalogRepository repo) {
    try {
      return repo.getSearchHistory();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _onAddSearchHistory(
    AddSearchHistoryEvent event,
    Emitter<CustomerState> emit,
  ) async {
    final trimmed = event.query.trim();
    if (trimmed.length < 2) return;

    final updated = [
      trimmed,
      ...state.searchHistory.where(
        (q) => q.toLowerCase() != trimmed.toLowerCase(),
      ),
    ].take(10).toList();

    try {
      await _catalogRepo.saveSearchHistory(updated);
    } catch (_) {}
    emit(state.copyWith(searchHistory: updated));
  }

  Future<void> _onRemoveSearchHistoryItem(
    RemoveSearchHistoryItemEvent event,
    Emitter<CustomerState> emit,
  ) async {
    final target = event.query.trim().toLowerCase();
    final updated = state.searchHistory
        .where((q) => q.toLowerCase() != target)
        .toList();

    try {
      await _catalogRepo.saveSearchHistory(updated);
    } catch (_) {}
    emit(state.copyWith(searchHistory: updated));
  }

  Future<void> _onClearSearchHistory(
    ClearSearchHistoryEvent event,
    Emitter<CustomerState> emit,
  ) async {
    try {
      await _catalogRepo.saveSearchHistory(const []);
    } catch (_) {}
    emit(state.copyWith(searchHistory: const []));
  }

  Future<void> _onAnalyzeCartOptimization(
    AnalyzeCartOptimizationEvent event,
    Emitter<CustomerState> emit,
  ) async {
    if (state.cartItems.isEmpty) {
      emit(state.copyWith(clearCartOptimization: true, isOptimizingCart: false));
      return;
    }

    emit(state.copyWith(isOptimizingCart: true));

    try {
      final activeStoreId = state.cartItems.first.product.storeId;
      final storeProducts = state.allProducts.where((p) => p.storeId == activeStoreId).toList();
      final effectiveCatalog = storeProducts.isNotEmpty ? storeProducts : state.allProducts;

      final optimization = await _cartRagService.optimizeCart(
        cartItems: state.cartItems,
        storeCatalog: effectiveCatalog,
        type: event.type,
      );

      emit(state.copyWith(
        cartOptimization: optimization,
        isOptimizingCart: false,
      ));
    } catch (e) {
      debugPrint('[CustomerBloc] Error optimizing cart: $e');
      emit(state.copyWith(isOptimizingCart: false));
    }
  }

  void _onApplyCartSwap(
    ApplyCartSwapEvent event,
    Emitter<CustomerState> emit,
  ) {
    final updatedCart = List<CartItemEntity>.from(state.cartItems);
    final idx = updatedCart.indexWhere((c) => c.product.id == event.swap.originalProduct.id);

    if (idx >= 0) {
      final qty = updatedCart[idx].quantity;
      updatedCart[idx] = CartItemEntity(
        product: event.swap.suggestedProduct,
        quantity: qty,
      );

      _persistCart(updatedCart);
      _inAppMessagingService?.triggerEvent(IInAppMessagingService.customerRecipeUsed);

      final currentOpt = state.cartOptimization;
      CartOptimizationEntity? newOpt;
      if (currentOpt != null) {
        final remaining = currentOpt.suggestions
            .where((s) => s.originalProduct.id != event.swap.originalProduct.id)
            .toList();
        final remainingSavings = remaining.fold(0.0, (acc, s) => acc + s.totalSavings);
        newOpt = CartOptimizationEntity(
          type: currentOpt.type,
          suggestions: remaining,
          totalPotentialSavings: remainingSavings,
        );
      }

      emit(state.copyWith(
        cartItems: updatedCart,
        cartOptimization: newOpt,
        clearCartPricing: true,
        successMessage: 'Swapped ${event.swap.originalProduct.name} for ${event.swap.suggestedProduct.name}!',
      ));

      add(const FetchCartPricingEvent());
    }
  }

  void _onApplyAllCartSwaps(
    ApplyAllCartSwapsEvent event,
    Emitter<CustomerState> emit,
  ) {
    if (event.swaps.isEmpty) return;

    final updatedCart = List<CartItemEntity>.from(state.cartItems);
    double totalSaved = 0.0;

    for (final swap in event.swaps) {
      final idx = updatedCart.indexWhere((c) => c.product.id == swap.originalProduct.id);
      if (idx >= 0) {
        final qty = updatedCart[idx].quantity;
        updatedCart[idx] = CartItemEntity(
          product: swap.suggestedProduct,
          quantity: qty,
        );
        totalSaved += swap.totalSavings;
      }
    }

    _persistCart(updatedCart);
    _inAppMessagingService?.triggerEvent(IInAppMessagingService.customerRecipeUsed);

    emit(state.copyWith(
      cartItems: updatedCart,
      clearCartOptimization: true,
      clearCartPricing: true,
      successMessage: '🎉 All swaps applied! Saved ₹${totalSaved.toStringAsFixed(0)} on your order.',
    ));

    add(const FetchCartPricingEvent());
  }

  Future<void> _onScanHandwrittenList(
    ScanHandwrittenListEvent event,
    Emitter<CustomerState> emit,
  ) async {
    emit(state.copyWith(
      isScanningHandwrittenList: true,
      clearHandwrittenScanError: true,
      clearHandwrittenScanResult: true,
    ));

    try {
      final catalog = state.allProducts.isNotEmpty ? state.allProducts : state.filteredProducts;
      final result = await _handwrittenListRagService.processHandwrittenList(
        imageBytes: event.imageBytes,
        imagePath: event.imagePath,
        storeCatalog: catalog,
      );

      emit(state.copyWith(
        isScanningHandwrittenList: false,
        handwrittenScanResult: result,
      ));
    } catch (e) {
      emit(state.copyWith(
        isScanningHandwrittenList: false,
        handwrittenScanError: 'Unable to analyze handwritten list: $e',
      ));
    }
  }

  void _onToggleHandwrittenItemSelection(
    ToggleHandwrittenItemSelectionEvent event,
    Emitter<CustomerState> emit,
  ) {
    final currentResult = state.handwrittenScanResult;
    if (currentResult == null || event.index < 0 || event.index >= currentResult.matches.length) return;

    final updatedMatches = List<HandwrittenItemMatchEntity>.from(currentResult.matches);
    final target = updatedMatches[event.index];
    updatedMatches[event.index] = target.copyWith(isSelected: !target.isSelected);

    emit(state.copyWith(
      handwrittenScanResult: currentResult.copyWith(matches: updatedMatches),
    ));
  }

  void _onUpdateHandwrittenItemQuantity(
    UpdateHandwrittenItemQuantityEvent event,
    Emitter<CustomerState> emit,
  ) {
    final currentResult = state.handwrittenScanResult;
    if (currentResult == null || event.index < 0 || event.index >= currentResult.matches.length) return;

    final updatedMatches = List<HandwrittenItemMatchEntity>.from(currentResult.matches);
    final target = updatedMatches[event.index];
    final newQty = target.quantity + event.delta;
    if (newQty < 1) return;

    final maxStock = target.matchedProduct?.stock ?? 20;
    if (newQty > maxStock && maxStock > 0) return;

    updatedMatches[event.index] = target.copyWith(quantity: newQty);

    emit(state.copyWith(
      handwrittenScanResult: currentResult.copyWith(matches: updatedMatches),
    ));
  }

  Future<void> _onAddHandwrittenMatchesToCart(
    AddHandwrittenMatchesToCartEvent event,
    Emitter<CustomerState> emit,
  ) async {
    final currentResult = state.handwrittenScanResult;
    if (currentResult == null) return;

    final itemsToAdd = currentResult.matches.where((m) => m.isSelected && m.isFound).toList();
    if (itemsToAdd.isEmpty) {
      emit(state.copyWith(errorMessage: 'No available items selected to add.'));
      return;
    }

    final currentCart = List<CartItemEntity>.from(state.cartItems);
    int addedCount = 0;

    for (final match in itemsToAdd) {
      final product = match.matchedProduct!;
      final existingIndex = currentCart.indexWhere((c) => c.product.id == product.id);

      if (existingIndex >= 0) {
        final existingItem = currentCart[existingIndex];
        final newQuantity = existingItem.quantity + match.quantity;
        currentCart[existingIndex] = existingItem.copyWith(quantity: newQuantity);
      } else {
        currentCart.add(CartItemEntity(product: product, quantity: match.quantity));
      }
      addedCount++;
    }

    _persistCart(currentCart);
    _inAppMessagingService?.triggerEvent(IInAppMessagingService.customerCartViewed);

    emit(state.copyWith(
      cartItems: currentCart,
      clearHandwrittenScanResult: true,
      clearCartPricing: true,
      successMessage: '🎉 Added $addedCount item${addedCount > 1 ? "s" : ""} to your cart!',
    ));

    add(const FetchCartPricingEvent());
  }

  void _onClearHandwrittenScan(
    ClearHandwrittenScanEvent event,
    Emitter<CustomerState> emit,
  ) {
    emit(state.copyWith(
      clearHandwrittenScanResult: true,
      clearHandwrittenScanError: true,
      isScanningHandwrittenList: false,
    ));
  }
}


