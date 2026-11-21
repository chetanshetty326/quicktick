import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../network/api_client.dart';
import '../security/secure_storage_service.dart';
import '../services/google_auth_service.dart';
import '../services/network_connectivity_service.dart';
import '../services/push_notification_service.dart';
import '../services/in_app_messaging_service.dart';
import '../services/routing_service.dart';
import '../services/websocket_service.dart';
import '../storage/local_cache_service.dart';
import '../../features/auth/data/datasources/auth_remote_data_source.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/customer/data/datasources/customer_remote_data_source.dart';
import '../../features/customer/domain/repositories/catalog_repository.dart';
import '../../features/customer/data/repositories/catalog_repository_impl.dart';
import '../../features/customer/presentation/bloc/customer_bloc.dart';
import '../../features/retailer/presentation/bloc/retailer_bloc.dart';
import '../../features/delivery/presentation/bloc/delivery_bloc.dart';
import '../../features/order/data/datasources/order_remote_data_source.dart';
import '../../features/order/data/datasources/payment_remote_data_source.dart';
import '../../features/order/domain/repositories/order_repository.dart';
import '../../features/order/data/repositories/order_repository_impl.dart';
import '../../features/retailer/data/datasources/retailer_remote_data_source.dart';
import '../../features/retailer/domain/repositories/retailer_repository.dart';
import '../../features/retailer/data/repositories/retailer_repository_impl.dart';
import '../../features/delivery/data/datasources/delivery_remote_data_source.dart';
import '../../features/delivery/domain/repositories/delivery_repository.dart';
import '../../features/delivery/data/repositories/delivery_repository_impl.dart';
import '../../features/support/data/datasources/support_remote_data_source.dart';
import '../../features/support/domain/repositories/support_repository.dart';
import '../../features/support/data/repositories/support_repository_impl.dart';
import '../../features/support/presentation/bloc/support_bloc.dart';
import '../../features/ai_assistant/data/datasources/speech_service.dart';
import '../../features/ai_assistant/data/datasources/ai_assistant_remote_data_source.dart';
import '../../features/ai_assistant/domain/repositories/ai_assistant_repository.dart';
import '../../features/ai_assistant/data/repositories/ai_assistant_repository_impl.dart';
import '../../features/ai_assistant/presentation/bloc/ai_assistant_bloc.dart';

final sl = GetIt.instance;

Future<void> initServiceLocator() async {
  // Core: Preferences & Storage
  final sharedPreferences = await SharedPreferences.getInstance();
  sl.registerLazySingleton<SharedPreferences>(() => sharedPreferences);

  sl.registerLazySingleton<ISecureStorageService>(
    () => SecureStorageService(prefs: sl<SharedPreferences>()),
  );

  final localCache = LocalCacheService(sl<SharedPreferences>());
  await localCache.init();
  sl.registerLazySingleton<ILocalCacheService>(() => localCache);

  // Core: Network & Real-Time WebSockets
  sl.registerLazySingleton<ApiClient>(
    () => ApiClient(secureStorage: sl<ISecureStorageService>()),
  );

  sl.registerLazySingleton<IWebSocketService>(
    () => WebSocketService(sl<ISecureStorageService>()),
  );

  sl.registerLazySingleton<INetworkConnectivityService>(
    () => NetworkConnectivityService(),
  );

  sl.registerLazySingleton<IRoutingService>(
    () => RoutingServiceImpl(),
  );

  sl.registerLazySingleton<IGoogleAuthService>(
    () => GoogleAuthService(),
  );

  sl.registerLazySingleton<IPushNotificationService>(
    () => PushNotificationService(
      apiClient: sl<ApiClient>(),
      prefs: sl<SharedPreferences>(),
      secureStorage: sl<ISecureStorageService>(),
    ),
  );

  sl.registerLazySingleton<IInAppMessagingService>(
    () => FirebaseInAppMessagingService(),
  );

  // Data Sources
  sl.registerLazySingleton<IAuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(sl<ApiClient>()),
  );

  sl.registerLazySingleton<ICustomerRemoteDataSource>(
    () => CustomerRemoteDataSourceImpl(sl<ApiClient>()),
  );

  sl.registerLazySingleton<IOrderRemoteDataSource>(
    () => OrderRemoteDataSourceImpl(sl<ApiClient>()),
  );

  sl.registerLazySingleton<IPaymentRemoteDataSource>(
    () => PaymentRemoteDataSourceImpl(sl<ApiClient>()),
  );

  sl.registerLazySingleton<IRetailerRemoteDataSource>(
    () => RetailerRemoteDataSourceImpl(sl<ApiClient>(), sl<ISecureStorageService>()),
  );

  sl.registerLazySingleton<IDeliveryRemoteDataSource>(
    () => DeliveryRemoteDataSourceImpl(sl<ApiClient>(), sl<ISecureStorageService>()),
  );

  // Repositories
  sl.registerLazySingleton<ICatalogRepository>(
    () => CatalogRepositoryImpl(
      sl<ILocalCacheService>(),
      sl<ICustomerRemoteDataSource>(),
    ),
  );

  sl.registerLazySingleton<IOrderRepository>(
    () => OrderRepositoryImpl(
      sl<ILocalCacheService>(),
      sl<IOrderRemoteDataSource>(),
      sl<IPaymentRemoteDataSource>(),
    ),
  );

  sl.registerLazySingleton<IRetailerRepository>(
    () => RetailerRepositoryImpl(
      sl<IRetailerRemoteDataSource>(),
      sl<ILocalCacheService>(),
    ),
  );

  sl.registerLazySingleton<IDeliveryRepository>(
    () => DeliveryRepositoryImpl(sl<IDeliveryRemoteDataSource>()),
  );

  sl.registerLazySingleton<ISupportRemoteDataSource>(
    () => SupportRemoteDataSourceImpl(sl<ApiClient>()),
  );

  sl.registerLazySingleton<ISupportRepository>(
    () => SupportRepositoryImpl(sl<ISupportRemoteDataSource>()),
  );

  // BLoCs (LazySingletons so authentication and application state is preserved across screens)
  sl.registerLazySingleton<AuthBloc>(
    () => AuthBloc(
      sl<ISecureStorageService>(),
      sl<IAuthRemoteDataSource>(),
      sl<IPushNotificationService>(),
      sl<ILocalCacheService>(),
      sl<IGoogleAuthService>(),
    ),
  );

  sl.registerLazySingleton<CustomerBloc>(
    () => CustomerBloc(
      catalogRepo: sl<ICatalogRepository>(),
      orderRepo: sl<IOrderRepository>(),
      localCache: sl<ILocalCacheService>(),
      paymentDataSource: sl<IPaymentRemoteDataSource>(),
      webSocketService: sl<IWebSocketService>(),
      secureStorage: sl<ISecureStorageService>(),
      pushNotificationService: sl<IPushNotificationService>(),
      inAppMessagingService: sl<IInAppMessagingService>(),
    ),
  );

  sl.registerLazySingleton<RetailerBloc>(
    () => RetailerBloc(
      orderRepo: sl<IOrderRepository>(),
      catalogRepo: sl<ICatalogRepository>(),
      retailerRepo: sl<IRetailerRepository>(),
      webSocketService: sl<IWebSocketService>(),
      pushNotificationService: sl<IPushNotificationService>(),
      inAppMessagingService: sl<IInAppMessagingService>(),
    ),
  );

  sl.registerLazySingleton<DeliveryBloc>(
    () => DeliveryBloc(
      orderRepo: sl<IOrderRepository>(),
      deliveryRepo: sl<IDeliveryRepository>(),
      webSocketService: sl<IWebSocketService>(),
      secureStorage: sl<ISecureStorageService>(),
      localCache: sl<ILocalCacheService>(),
      pushNotificationService: sl<IPushNotificationService>(),
      inAppMessagingService: sl<IInAppMessagingService>(),
    ),
  );

  sl.registerFactory<SupportBloc>(
    () => SupportBloc(supportRepo: sl<ISupportRepository>()),
  );

  // AI Assistant Services & BLoC
  sl.registerLazySingleton<ISpeechService>(
    () => SpeechServiceImpl(),
  );

  sl.registerLazySingleton<IAiAssistantRemoteDataSource>(
    () => GroqAiRemoteDataSourceImpl(secureStorage: sl<ISecureStorageService>()),
  );

  sl.registerLazySingleton<IAiAssistantRepository>(
    () => AiAssistantRepositoryImpl(
      remoteDataSource: sl<IAiAssistantRemoteDataSource>(),
      speechService: sl<ISpeechService>(),
    ),
  );

  sl.registerLazySingleton<AiAssistantBloc>(
    () => AiAssistantBloc(repository: sl<IAiAssistantRepository>()),
  );
}
