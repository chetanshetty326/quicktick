import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/location_service.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../../../order/domain/entities/order_entity.dart';
import '../bloc/customer_bloc.dart';
import '../../domain/entities/hero_banner_entity.dart';
import '../../domain/entities/catalog_entities.dart';
import '../../domain/entities/cart_item_entity.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:open_filex/open_filex.dart';
import '../../../../core/di/service_locator.dart';
import '../../domain/repositories/catalog_repository.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../../../core/services/razorpay_payment_service.dart';
import 'order_success_screen.dart';
import 'payment_failure_screen.dart';
import 'customer_live_tracking_screen.dart';
import '../../../../core/widgets/skeleton_loading.dart';
import '../widgets/customer_address_sheet.dart';
import '../widgets/customer_notifications_sheet.dart';
import '../widgets/customer_profile_edit_sheet.dart';
import '../widgets/customer_filter_sort_sheet.dart';
import '../widgets/product_details_sheet.dart';
import '../widgets/initial_location_prompt_sheet.dart';
import '../widgets/customer_voice_search_sheet.dart';
import '../../../../core/utils/image_url_helper.dart';
import '../../../../core/utils/product_matcher.dart';
import '../../../../core/widgets/legal_policy_screen.dart';
import '../../../../core/widgets/delete_account_dialog.dart';
import '../../../../core/widgets/network_and_server_error_view.dart';
import '../widgets/cart_optimizer_card.dart';
import '../../../../core/widgets/system_status_banner.dart';
import '../../../../core/services/network_connectivity_service.dart';
import '../../../../core/errors/failures.dart';
import '../../../support/presentation/screens/support_tickets_screen.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/handwritten_list_sheet.dart';
import '../widgets/about_quicktick_sheet.dart';
import '../widgets/quicktick_brand_footer.dart';
import '../widgets/order_rating_feedback_sheet.dart';
import '../widgets/customer_language_selector_sheet.dart';
import '../../../../core/localization/app_strings.dart';
import '../../../ai_assistant/presentation/bloc/ai_assistant_bloc.dart';
import '../../../ai_assistant/presentation/bloc/ai_assistant_event.dart';
import '../../../ai_assistant/presentation/bloc/ai_assistant_state.dart';
import '../../../ai_assistant/presentation/widgets/ai_floating_concierge_button.dart';
import '../../../ai_assistant/presentation/widgets/incoming_delivery_call_dialog.dart';

class CustomerMainScreen extends StatefulWidget {
  const CustomerMainScreen({super.key});

  @override
  State<CustomerMainScreen> createState() => _CustomerMainScreenState();
}

class _CustomerMainScreenState extends State<CustomerMainScreen> with WidgetsBindingObserver {
  int _currentTab = 0;
  bool _hasCheckedInitialLocation = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        final authState = context.read<AuthBloc>().state;
        final userName = authState is AuthenticatedState ? authState.user.name : null;
        context.read<AiAssistantBloc>().add(InitAiAssistantEvent(
              customerName: userName,
            ));
        try {
          final pos = await LocationService.getCurrentPosition(requestIfNeeded: false);
          if (pos != null && mounted) {
            context.read<CustomerBloc>().add(LoadCustomerDataEvent(lat: pos.latitude, lng: pos.longitude));
            return;
          }
        } catch (_) {}
        if (mounted) {
          context.read<CustomerBloc>().add(LoadCustomerDataEvent());
        }
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    if (lifecycleState == AppLifecycleState.resumed) {
      if (sl.isRegistered<INetworkConnectivityService>()) {
        sl<INetworkConnectivityService>().checkConnection().then((connected) {
          if (connected && mounted) {
            final bloc = context.read<CustomerBloc>();
            if (bloc.state.isOffline || bloc.state.isServerDown || bloc.state.allProducts.isEmpty) {
              bloc.add(const LoadCustomerDataEvent());
              bloc.add(const RefreshCustomerOrdersEvent());
            }
          }
        });
      }
    }
  }

  void _checkInitialLocation(CustomerState state) {
    if (_hasCheckedInitialLocation) return;
    if (state.isLoading) return;

    _hasCheckedInitialLocation = true;
    if (state.savedAddresses.isEmpty &&
        (state.selectedAddress == 'Select Delivery Address' || state.selectedAddress.isEmpty)) {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              InitialLocationPromptSheet.show(context);
            }
          });
        }
      });
    }
  }

  DateTime? _lastBackPressTime;

  void _handleBackPress() {
    final customerBloc = context.read<CustomerBloc>();
    final state = customerBloc.state;

    // Level 1: If store filter or search is active on home tab, clear them first
    if (_currentTab == 0 && (state.selectedStore != null || state.searchQuery.isNotEmpty)) {
      if (state.selectedStore != null) {
        customerBloc.add(const FilterByStoreEvent(null));
      }
      if (state.searchQuery.isNotEmpty) {
        customerBloc.add(const SearchProductsEvent(''));
      }
      return;
    }

    // Level 2: If on non-home tab (Orders or Profile), return to Shop (Tab 0)
    if (_currentTab != 0) {
      setState(() => _currentTab = 0);
      return;
    }

    // Level 3: Root screen (Shop tab with no active search/filter) -> Double tap back to exit
    final now = DateTime.now();
    if (_lastBackPressTime == null || now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
      _lastBackPressTime = now;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF1E293B),
          elevation: 6,
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
          content: const Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.info_outline, color: Color(0xFF38BDF8), size: 18),
              SizedBox(width: 10),
              Text(
                'Press back again to exit',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      // Second back press within 2 seconds -> close the app
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackPress();
      },
      child: MultiBlocListener(
        listeners: [
          BlocListener<AuthBloc, AuthState>(
            listener: (context, state) {
              if (state is UnauthenticatedState) {
                context.read<CustomerBloc>().add(const ClearCustomerSessionEvent());
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                }
              }
            },
          ),
          BlocListener<CustomerBloc, CustomerState>(
            listenWhen: (prev, curr) => prev.failureType != curr.failureType && curr.failureType == FailureType.auth,
            listener: (context, state) {
              context.read<AuthBloc>().add(LogoutEvent());
            },
          ),
          BlocListener<CustomerBloc, CustomerState>(
            listenWhen: (prev, curr) => !curr.isLoading && !_hasCheckedInitialLocation,
            listener: (context, state) => _checkInitialLocation(state),
          ),
          BlocListener<CustomerBloc, CustomerState>(
            listenWhen: (prev, curr) =>
                prev.latestPushNotification != curr.latestPushNotification &&
                curr.latestPushNotification != null,
            listener: (context, state) {
              final notif = state.latestPushNotification;
              if (notif == null) return;
              final title = notif['title']?.toString() ?? 'Quick Tick Alert ⚡';
              final body = notif['body']?.toString() ?? notif['message']?.toString() ?? '';
              final fromTap = notif['fromTap'] == true;
              final type = (notif['type']?.toString() ?? '').toUpperCase();
              final hasOrder = (notif['orderId']?.toString().isNotEmpty ?? false) || type.contains('ORDER');

              // If push notification announces delivery arrival, trigger full-screen VoIP call screen
              final combinedText = '$title $body'.toLowerCase();
              if (combinedText.contains('arrived') ||
                  combinedText.contains('outside') ||
                  combinedText.contains('doorstep')) {
                context.read<AiAssistantBloc>().add(TriggerDeliveryArrivalCallEvent(
                      riderName: notif['riderName']?.toString() ?? 'Delivery Partner',
                      storeName: notif['storeName']?.toString() ?? 'QuickTick Store',
                      orderNumber: notif['orderId']?.toString() ?? notif['orderNumber']?.toString() ?? '101',
                    ));
              }

              // If user tapped an OS/background push notification, navigate straight to the relevant view
              if (fromTap) {
                if (hasOrder) {
                  setState(() => _currentTab = 1);
                  context.read<CustomerBloc>().add(const RefreshCustomerOrdersEvent());
                } else {
                  setState(() => _currentTab = 0);
                  context.read<CustomerBloc>().add(const FetchHeroBannersEvent(forceRefresh: true));
                }
                return;
              }

              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: const Color(0xFF0F172A),
                  elevation: 8,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  duration: const Duration(seconds: 4),
                  content: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Color(0xFF0F766E),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Colors.white),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (body.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                body,
                                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).hideCurrentSnackBar();
                          setState(() => _currentTab = 1);
                          context.read<CustomerBloc>().add(const RefreshCustomerOrdersEvent());
                        },
                        child: const Text('VIEW', style: TextStyle(color: Color(0xFF14B8A6), fontWeight: FontWeight.w900, fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          BlocListener<AiAssistantBloc, AiAssistantState>(
            listenWhen: (prev, curr) => !prev.showIncomingCall && curr.showIncomingCall,
            listener: (context, state) {
              if (state.showIncomingCall) {
                IncomingDeliveryCallDialog.show(
                  context,
                  riderName: state.callRiderName ?? 'Delivery Partner',
                  storeName: state.callStoreName ?? 'QuickTick Store',
                  orderNumber: state.callOrderNumber ?? '101',
                );
              }
            },
          ),
        ],
        child: Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          body: SafeArea(
            child: Stack(
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: Column(
                      children: [
                        BlocBuilder<CustomerBloc, CustomerState>(
                          buildWhen: (prev, curr) => prev.failureType != curr.failureType,
                          builder: (context, state) {
                            if (state.isOffline) {
                              return const SystemStatusBar(
                                severity: SystemStatusSeverity.offline,
                                message: 'You are offline • Showing cached items',
                              );
                            }
                            if (state.isServerDown) {
                              return SystemStatusBar(
                                severity: SystemStatusSeverity.serverDown,
                                message: 'QuickTick Server Busy • Reconnecting...',
                                actionLabel: 'Retry',
                                onAction: () => context.read<CustomerBloc>().add(LoadCustomerDataEvent()),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                        Expanded(
                          child: IndexedStack(
                            index: _currentTab,
                            children: [
                              _CustomerHomeView(
                                onNavigateToOrders: () => setState(() => _currentTab = 1),
                              ),
                              const _CustomerOrdersView(),
                              const _CustomerProfileView(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                AiFloatingConciergeButton(
                  isDraggable: true,
                  onSearchQuery: (query) {
                    setState(() => _currentTab = 0);
                    context.read<CustomerBloc>().add(SearchProductsEvent(query));
                  },
                  onTrackOrderRequested: () {
                    setState(() => _currentTab = 1);
                    context.read<CustomerBloc>().add(const RefreshCustomerOrdersEvent());
                  },
                  onViewCouponsRequested: () {
                    setState(() => _currentTab = 0);
                    _showCartModal(context, onNavigateToOrders: () => setState(() => _currentTab = 1));
                  },
                  onAddItemsRequested: (items) {
                    setState(() => _currentTab = 0);
                    final customerBloc = context.read<CustomerBloc>();
                    () async {
                      final catalogPool = <ProductEntity>[
                        ...customerBloc.state.allProducts,
                        ...customerBloc.state.filteredProducts,
                      ];
                      final addedProducts = <ProductEntity>[];

                      for (final itemName in items) {
                        final query = ProductMatcher.normalizeQuery(itemName);
                        if (query.isEmpty) continue;

                        var match = ProductMatcher.findBestMatch(catalogPool, query);
                        if (match == null && sl.isRegistered<ICatalogRepository>()) {
                          try {
                            final res = await sl<ICatalogRepository>().searchProducts(
                              query,
                              lat: customerBloc.state.activeLat,
                              lng: customerBloc.state.activeLng,
                            );
                            res.fold((_) {}, (products) {
                              match = ProductMatcher.findBestMatch(products, query);
                            });
                          } catch (_) {}
                        }

                        if (match != null &&
                            match!.stock > 0 &&
                            match!.isAvailable &&
                            !addedProducts.any((p) => p.id == match!.id)) {
                          customerBloc.add(AddToCartEvent(match!));
                          addedProducts.add(match!);
                        }
                      }

                      if (!context.mounted) return;
                      if (addedProducts.isNotEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Added ${addedProducts.length} item${addedProducts.length > 1 ? "s" : ""} to cart: ${addedProducts.map((p) => p.name).join(", ")}',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                            backgroundColor: const Color(0xFF10B981),
                            duration: const Duration(seconds: 4),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            action: SnackBarAction(
                              label: 'VIEW CART',
                              textColor: Colors.white,
                              onPressed: () => _showCartModal(context, onNavigateToOrders: () => setState(() => _currentTab = 1)),
                            ),
                          ),
                        );
                      } else if (items.isNotEmpty) {
                        customerBloc.add(SearchProductsEvent(items.first));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Searching catalog for "${items.first}"...'),
                            duration: const Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    }();
                  },
                  onContactSupportRequested: () {
                    Navigator.push(context, SupportTicketsScreen.route(app: 'customer'));
                  },
                ),
              ],
            ),
          ),
          bottomNavigationBar: Container(
            color: Colors.white,
            child: SafeArea(
              top: false,
              child: Center(
                heightFactor: 1.0,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: BlocBuilder<CustomerBloc, CustomerState>(
                    buildWhen: (prev, curr) => prev.language != curr.language,
                    builder: (context, custState) {
                      final strings = custState.strings;
                      return NavigationBar(
                        selectedIndex: _currentTab,
                        onDestinationSelected: (idx) {
                          setState(() => _currentTab = idx);
                          if (idx == 0) {
                            context.read<CustomerBloc>().add(const FetchHeroBannersEvent(forceRefresh: true));
                          } else if (idx == 1) {
                            context.read<CustomerBloc>().add(const RefreshCustomerOrdersEvent());
                          }
                        },
                        backgroundColor: Colors.white,
                        elevation: 10,
                        indicatorColor: AppColors.primaryContainer,
                        height: 65,
                        destinations: [
                          NavigationDestination(
                            icon: const Icon(Icons.storefront_outlined),
                            selectedIcon: const Icon(Icons.storefront, color: AppColors.primary),
                            label: strings.tabShop,
                          ),
                          NavigationDestination(
                            icon: const Icon(Icons.receipt_long_outlined),
                            selectedIcon: const Icon(Icons.receipt_long, color: AppColors.primary),
                            label: strings.tabOrders,
                          ),
                          NavigationDestination(
                            icon: const Icon(Icons.person_outline),
                            selectedIcon: const Icon(Icons.person, color: AppColors.primary),
                            label: strings.tabProfile,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------
// ADVANCED HOME VIEW (ListView.builder based)
// ----------------------------------------------------
class _CustomerHomeView extends StatefulWidget {
  final VoidCallback? onNavigateToOrders;
  const _CustomerHomeView({this.onNavigateToOrders});

  @override
  State<_CustomerHomeView> createState() => _CustomerHomeViewState();
}

class _CustomerHomeViewState extends State<_CustomerHomeView> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openVoiceSearch() async {
    final query = await CustomerVoiceSearchSheet.show(context);
    if (query != null && query.trim().isNotEmpty && mounted) {
      _searchController.text = query.trim();
      _searchController.selection = TextSelection.fromPosition(
        TextPosition(offset: _searchController.text.length),
      );
      context.read<CustomerBloc>().add(AddSearchHistoryEvent(query.trim()));
      context.read<CustomerBloc>().add(SearchProductsEvent(query.trim()));
    }
  }

  Future<void> _openHandwrittenListScanner() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.edit_note_rounded, color: Color(0xFF0F766E), size: 24),
                  SizedBox(width: 8),
                  Text(
                    'AI Handwritten Grocery List',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Snap or upload a photo of your paper list and AI will match and add the items to your cart automatically.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F766E).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.camera_alt_rounded, color: Color(0xFF0F766E)),
                ),
                title: const Text('Take Photo with Camera', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: const Text('Snap a picture of your paper list', style: TextStyle(fontSize: 11, color: Colors.grey)),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.photo_library_rounded, color: Colors.blueAccent),
                ),
                title: const Text('Upload from Gallery', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: const Text('Choose a saved image from gallery', style: TextStyle(fontSize: 11, color: Colors.grey)),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null || !mounted) return;

    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, imageQuality: 85);
      if (picked == null || !mounted) return;

      final bytes = await picked.readAsBytes();
      if (!mounted) return;

      context.read<CustomerBloc>().add(ScanHandwrittenListEvent(
            imageBytes: bytes,
            imagePath: picked.path,
          ));

      HandwrittenListSheet.show(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open image: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CustomerBloc, CustomerState>(
      // FIX #3: Only listen for side-effects (dialogs/snackbars) — not on every poll tick
      listenWhen: (prev, curr) =>
          prev.multiRetailerConflictProduct != curr.multiRetailerConflictProduct ||
          prev.errorMessage != curr.errorMessage ||
          prev.successMessage != curr.successMessage,
      // FIX #3: Only rebuild home view when display-relevant state changes.
      // Previously rebuilt on EVERY emit (poll, push notification, payment state, etc.)
      buildWhen: (prev, curr) =>
          prev.failureType != curr.failureType ||
          prev.isLoading != curr.isLoading ||
          prev.productListVersion != curr.productListVersion ||
          prev.storeListVersion != curr.storeListVersion ||
          prev.storeFilter != curr.storeFilter ||
          prev.zoneId != curr.zoneId ||
          prev.categories != curr.categories ||
          prev.selectedCategoryId != curr.selectedCategoryId ||
          prev.selectedFoodType != curr.selectedFoodType ||
          prev.searchQuery != curr.searchQuery ||
          prev.searchHistory != curr.searchHistory ||
          prev.cartItems != curr.cartItems ||
          prev.sortOption != curr.sortOption ||
          prev.inStockOnly != curr.inStockOnly ||
          prev.fastDeliveryOnly != curr.fastDeliveryOnly ||
          prev.dealsOnly != curr.dealsOnly ||
          prev.selectedStore != curr.selectedStore ||
          prev.isLoadingMoreProducts != curr.isLoadingMoreProducts ||
          prev.hasReachedMaxProducts != curr.hasReachedMaxProducts,
      listener: (context, state) {
        if (state.multiRetailerConflictProduct != null) {
          final conflictProduct = state.multiRetailerConflictProduct!;
          context.read<CustomerBloc>().add(DismissMultiRetailerConflictEvent());
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              title: const Row(
                children: [
                  Icon(Icons.storefront_rounded, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text('Replace Cart Items?', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                ],
              ),
              content: const Text(
                'Your cart contains items from a different store. You can only order from one store at a time.\n\nWould you like to clear your cart and start an order from this store?',
                style: TextStyle(fontSize: 13, height: 1.4, color: Color(0xFF334155)),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    context.read<CustomerBloc>().add(AddToCartEvent(conflictProduct, clearPreviousStoreCart: true));
                  },
                  child: const Text('Clear & Add', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        }
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.errorMessage!), backgroundColor: AppColors.statusCancelled),
          );
        }
        if (state.successMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.successMessage!),
              backgroundColor: AppColors.primary,
              duration: const Duration(seconds: 1),
            ),
          );
        }
      },
      builder: (context, state) {
        if (state.isLoading && state.allProducts.isEmpty) {
          return const CustomerHomeScreenSkeleton();
        }

        if (state.failureType != FailureType.none && state.allProducts.isEmpty && state.stores.isEmpty) {
          return Scaffold(
            backgroundColor: Colors.white,
            body: SafeArea(
              child: RefreshIndicator(
                onRefresh: () async {
                  context.read<CustomerBloc>().add(LoadCustomerDataEvent());
                },
                color: const Color(0xFF0F766E),
                child: NetworkAndServerErrorView(
                  failureType: state.failureType,
                  customMessage: state.errorMessage,
                  isRetrying: state.isLoading,
                  onRetry: () => context.read<CustomerBloc>().add(LoadCustomerDataEvent()),
                ),
              ),
            ),
          );
        }

        return Stack(
          children: [
            NotificationListener<ScrollNotification>(
              onNotification: (scrollInfo) {
                if (scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent * 0.8 &&
                    !state.isLoadingMoreProducts &&
                    !state.hasReachedMaxProducts &&
                    state.searchQuery.isEmpty) {
                  context.read<CustomerBloc>().add(const LoadMoreProductsEvent());
                }
                return false;
              },
              child: RefreshIndicator(
                onRefresh: () async {
                  context.read<CustomerBloc>().add(LoadCustomerDataEvent());
                },
                color: AppColors.primary,
                child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. Header Location & Search
                        _buildHeader(context, state),

                        // 1.1 Live Active Order Mini-Card (Swiggy/Zepto style)
                        _buildLiveActiveOrderBanner(context, state),

                        // 2. Promo Banner (only when not searching)
                        if (state.searchQuery.isEmpty) _buildPromoBanner(context),

                        // 3. Category Horizontal List
                        _buildCategoriesSection(context, state),

                        // 3.1 Featured Restaurants & Local Shops (only when not searching)
                        if (state.searchQuery.isEmpty) ...[
                          const SizedBox(height: 20),
                          _buildStoresSection(context, state),
                        ],

                        const SizedBox(height: 16),

                        // 3.2 Quick Filter Chips (Enhancement 3)
                        _buildQuickFilterChips(context, state),

                        const SizedBox(height: 16),

                        // 4. Products List Header
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  state.selectedStore != null
                                      ? 'Products from ${state.selectedStore!.name}'
                                      : (state.searchQuery.isNotEmpty
                                          ? 'Search Results for "${state.searchQuery}"'
                                          : (state.selectedCategoryId == 'cat_all'
                                              ? 'All Daily Essentials'
                                              : '${state.categories.firstWhere((c) => c.id == state.selectedCategoryId, orElse: () => const CategoryEntity(id: '', name: 'Filtered')).name} Products')),
                                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '${state.filteredProducts.length} Items',
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Store filter active banner chip
                        if (state.selectedStore != null) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.storefront_rounded, size: 18, color: AppColors.primary),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Viewing products from ${state.selectedStore!.name}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => context.read<CustomerBloc>().add(const FilterByStoreEvent(null)),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 0.2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.close_rounded, size: 16, color: AppColors.primary),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ],
                    ),
                  ),

                  // 4b. Matching Stores (from Unified Catalog Search)
                  if (state.searchQuery.isNotEmpty && state.searchStores.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.store_mall_directory_rounded, size: 18, color: AppColors.primary),
                                const SizedBox(width: 8),
                                Text(
                                  'Matching Stores (${state.searchStores.length})',
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF0F172A)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 86,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: state.searchStores.length,
                                separatorBuilder: (context, index) => const SizedBox(width: 10),
                                itemBuilder: (context, index) {
                                  final store = state.searchStores[index];
                                  final isSelected = state.selectedStore?.id == store.id;
                                  return InkWell(
                                    onTap: () {
                                      context.read<CustomerBloc>().add(FilterByStoreEvent(isSelected ? null : store));
                                    },
                                    borderRadius: BorderRadius.circular(14),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      width: 230,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: isSelected ? const Color(0xFFF0FDF4) : Colors.white,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
                                          width: isSelected ? 1.5 : 1,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.03),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 42,
                                            height: 42,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF1F5F9),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: const Icon(Icons.storefront_rounded, color: AppColors.primary, size: 22),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  store.name,
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  store.isOpen ? '🟢 Open Now' : '🔴 Closed',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: store.isOpen ? const Color(0xFF059669) : const Color(0xFFDC2626),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 14),
                            const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // 4c. Search Products Header
                  if (state.searchQuery.isNotEmpty && state.filteredProducts.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                        child: Text(
                          'Products (${state.filteredProducts.length})',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF0F172A)),
                        ),
                      ),
                    ),

                  // 5. Products List
                  if (state.isLoading && state.filteredProducts.isEmpty)
                    SliverToBoxAdapter(
                      child: SkeletonShimmer(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            children: List.generate(
                              4,
                              (index) => Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFF1F5F9)),
                                ),
                                child: const Row(
                                  children: [
                                    SkeletonBox(width: 72, height: 72, borderRadius: 12),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          SkeletonBox(height: 14, width: 140, borderRadius: 4),
                                          SizedBox(height: 6),
                                          SkeletonBox(height: 11, width: 90, borderRadius: 4),
                                          SizedBox(height: 10),
                                          SkeletonBox(height: 16, width: 60, borderRadius: 4),
                                        ],
                                      ),
                                    ),
                                    SkeletonBox(height: 36, width: 72, borderRadius: 10),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                  else if (state.filteredProducts.isEmpty)
                    SliverToBoxAdapter(
                      child: Container(
                        padding: const EdgeInsets.all(40),
                        alignment: Alignment.center,
                        child: Column(
                          children: [
                            const Icon(Icons.inventory_2_outlined, size: 48, color: AppColors.textMuted),
                            const SizedBox(height: 10),
                            Text(
                              state.selectedStore != null
                                  ? 'No products available right now from ${state.selectedStore!.name}'
                                  : (state.searchQuery.isNotEmpty
                                      ? (state.searchStores.isNotEmpty
                                          ? 'No direct products found, but ${state.searchStores.length} store(s) matched above!'
                                          : 'No products or stores found matching "${state.searchQuery}"')
                                      : 'No products found in this category'),
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                              textAlign: TextAlign.center,
                            ),
                            if (state.selectedStore != null) ...[
                              const SizedBox(height: 14),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: () => context.read<CustomerBloc>().add(const FilterByStoreEvent(null)),
                                icon: const Icon(Icons.storefront_rounded, size: 16),
                                label: const Text('Browse All Stores & Products', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ] else if (state.searchQuery.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              TextButton.icon(
                                onPressed: () => context.read<CustomerBloc>().add(const SearchProductsEvent('')),
                                icon: const Icon(Icons.clear, size: 16, color: AppColors.primary),
                                label: const Text('Clear Search', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ],
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                      sliver: SliverList.builder(
                        itemCount: state.filteredProducts.length,
                        itemBuilder: (context, index) {
                          final product = state.filteredProducts[index];
                          return _ProductListTile(product: product);
                        },
                      ),
                    ),
                  if (state.isLoadingMoreProducts)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary),
                          ),
                        ),
                      ),
                    ),
                  if (state.hasReachedMaxProducts && state.filteredProducts.length >= 20)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            "🎉 You've reached the end of the catalog",
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade500),
                          ),
                        ),
                      ),
                    ),
                  const SliverToBoxAdapter(
                    child: QuickTickBrandFooter(),
                  ),
                  SliverToBoxAdapter(child: SizedBox(height: state.cartItems.isNotEmpty ? 115 : 80)),
                ],
              ),
            ),
          ),

            // Floating Bottom Cart Bar
            if (state.cartItems.isNotEmpty)
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: _FloatingCartBar(
                  totalItems: state.cartTotalItems,
                  grandTotal: state.cartGrandTotal,
                  onViewCart: () => _showCartModal(context, onNavigateToOrders: widget.onNavigateToOrders),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, CustomerState state) {
    final unreadNotifs = state.unreadNotificationsCount > 0
        ? state.unreadNotificationsCount
        : state.notifications.where((n) => n['read'] != true && n['isRead'] != true).length;
    final isFilterActive = state.sortOption != ProductSortOption.relevance ||
        state.inStockOnly ||
        state.fastDeliveryOnly ||
        state.dealsOnly;
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompactScreen = screenWidth < 360;

    return Container(
      padding: EdgeInsets.fromLTRB(16, isCompactScreen ? 10 : 14, 16, 14),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.location_on, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: () => CustomerAddressSheet.show(context),
                  borderRadius: BorderRadius.circular(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              'Deliver to Address',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                        ],
                      ),
                      Text(
                        state.selectedAddress,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Serviceability Status Badge (Responsive)
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isCompactScreen ? 6 : 9,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: state.inZone
                        ? [Colors.green.shade600, Colors.teal.shade700]
                        : [Colors.red.shade600, Colors.red.shade800],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: (state.inZone ? Colors.green : Colors.red).withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(state.inZone ? Icons.bolt : Icons.location_off_rounded, color: state.inZone ? Colors.amber : Colors.white, size: 14),
                    if (!isCompactScreen) ...[
                      const SizedBox(width: 2),
                      Text(state.inZone ? '15 MINS' : 'OUT OF ZONE', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10)),
                    ] else ...[
                      const SizedBox(width: 2),
                      Text(state.inZone ? '15m' : 'NO SERVICE', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 9.5)),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Notification Bell Icon with Live Badge
              InkWell(
                onTap: () {
                  CustomerNotificationsSheet.show(
                    context,
                    onTrackOrder: (orderId) {
                      if (widget.onNavigateToOrders != null) widget.onNavigateToOrders!();
                    },
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Icon(Icons.notifications_outlined, size: 20, color: Color(0xFF0F172A)),
                    ),
                    if (unreadNotifs > 0)
                      Positioned(
                        top: -2,
                        right: -2,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                          child: Text(
                            '$unreadNotifs',
                            style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Top Shopping Cart Icon with Live Badge
              InkWell(
                onTap: () => _showCartModal(context, onNavigateToOrders: widget.onNavigateToOrders),
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: state.cartItems.isNotEmpty ? AppColors.primaryContainer : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: state.cartItems.isNotEmpty ? AppColors.primary.withValues(alpha: 0.3) : const Color(0xFFE2E8F0)),
                      ),
                      child: Icon(
                        Icons.shopping_bag_outlined,
                        size: 20,
                        color: state.cartItems.isNotEmpty ? AppColors.primary : const Color(0xFF0F172A),
                      ),
                    ),
                    if (state.cartTotalItems > 0)
                      Positioned(
                        top: -2,
                        right: -2,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                          child: Text(
                            '${state.cartTotalItems}',
                            style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Search Field with Filter/Sort Icon
          TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            onChanged: (val) {
              context.read<CustomerBloc>().add(SearchProductsEvent(val));
            },
            onSubmitted: (val) {
              final trimmed = val.trim();
              if (trimmed.isNotEmpty) {
                context.read<CustomerBloc>().add(AddSearchHistoryEvent(trimmed));
              }
              context.read<CustomerBloc>().add(SearchProductsEvent(trimmed));
            },
            decoration: InputDecoration(
              hintText: state.language == AppLanguage.kannada
                  ? (isCompactScreen ? 'ಉತ್ಪನ್ನಗಳು, ಅಂಗಡಿಗಳನ್ನು ಹುಡುಕಿ...' : 'ದಿನಸಿ, ತರಕಾರಿ, ಹಣ್ಣುಗಳನ್ನು ಹುಡುಕಿ...')
                  : (isCompactScreen ? 'Search products, stores...' : 'Search products, stores, essentials...'),
              hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
              prefixIcon: const Icon(Icons.search, color: AppColors.primary, size: 20),
              prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_searchController.text.isNotEmpty || state.searchQuery.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        _searchController.clear();
                        context.read<CustomerBloc>().add(const SearchProductsEvent(''));
                      },
                    ),
                  IconButton(
                    tooltip: 'Voice Search',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(
                      Icons.mic_rounded,
                      size: 20,
                      color: AppColors.primary,
                    ),
                    onPressed: _openVoiceSearch,
                  ),
                  IconButton(
                    tooltip: 'Scan Handwritten List',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(
                      Icons.document_scanner_rounded,
                      size: 20,
                      color: AppColors.primary,
                    ),
                    onPressed: _openHandwrittenListScanner,
                  ),
                  IconButton(
                    tooltip: 'Sort & Filters',
                    visualDensity: VisualDensity.compact,
                    icon: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(
                          Icons.tune_rounded,
                          size: 20,
                          color: isFilterActive ? AppColors.primary : const Color(0xFF64748B),
                        ),
                        if (isFilterActive)
                          Positioned(
                            top: -1,
                            right: -1,
                            child: Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                    onPressed: () => CustomerFilterSortSheet.show(context),
                  ),
                ],
              ),
              filled: true,
              fillColor: AppColors.surfaceVariant,
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),

          // Recent Search History Chips
          if (state.searchQuery.isEmpty && state.searchHistory.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 30,
              child: ListView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.history_rounded, size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          state.language == AppLanguage.kannada ? 'ಇತ್ತೀಚಿನ:' : 'Recent:',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...state.searchHistory.map(
                    (query) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)),
                              onTap: () {
                                HapticFeedback.lightImpact();
                                _searchController.text = query;
                                _searchController.selection = TextSelection.fromPosition(
                                  TextPosition(offset: query.length),
                                );
                                context.read<CustomerBloc>().add(AddSearchHistoryEvent(query));
                                context.read<CustomerBloc>().add(SearchProductsEvent(query));
                              },
                              child: Padding(
                                padding: const EdgeInsets.only(left: 10, right: 4, top: 4, bottom: 4),
                                child: Text(
                                  query,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF334155),
                                  ),
                                ),
                              ),
                            ),
                            InkWell(
                              borderRadius: const BorderRadius.horizontal(right: Radius.circular(14)),
                              onTap: () {
                                context.read<CustomerBloc>().add(RemoveSearchHistoryItemEvent(query));
                              },
                              child: const Padding(
                                padding: EdgeInsets.only(left: 2, right: 8, top: 4, bottom: 4),
                                child: Icon(Icons.close_rounded, size: 13, color: Color(0xFF94A3B8)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        context.read<CustomerBloc>().add(const ClearSearchHistoryEvent());
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Text(
                          state.language == AppLanguage.kannada ? 'ತೆರವುಗೊಳಿಸಿ' : 'Clear',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // 5. Trending / Popular Search Chips (Enhancement 5)
          if (state.searchQuery.isEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 28,
              child: ListView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                children: [
                  const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.trending_up_rounded, size: 14, color: AppColors.primary),
                        SizedBox(width: 4),
                        Text(
                          'Trending:',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...['Fresh Milk', 'Bread & Eggs', 'Veggies', 'Snacks', 'Beverages'].map(
                    (query) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () {
                            HapticFeedback.lightImpact();
                            _searchController.text = query;
                            _searchController.selection = TextSelection.fromPosition(
                              TextPosition(offset: query.length),
                            );
                            context.read<CustomerBloc>().add(AddSearchHistoryEvent(query));
                            context.read<CustomerBloc>().add(SearchProductsEvent(query));
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Text(
                              query,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF334155),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ----------------------------------------------------
  // ENHANCEMENT 2: LIVE ACTIVE ORDER MINI-CARD (Swiggy/Zepto style)
  // ----------------------------------------------------
  Widget _buildLiveActiveOrderBanner(BuildContext context, CustomerState state) {
    final activeOrders = state.myOrders.where((o) => !o.status.isTerminal).toList();
    if (activeOrders.isEmpty) return const SizedBox.shrink();

    final activeOrder = activeOrders.first;
    final itemCount = activeOrder.items.length;
    final displayOrderNum = activeOrder.orderNumber.isNotEmpty
        ? activeOrder.orderNumber
        : (activeOrder.id.length > 8 ? activeOrder.id.substring(0, 8) : activeOrder.id);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CustomerLiveTrackingScreen(order: activeOrder),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF064E3B), Color(0xFF047857)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF047857).withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.delivery_dining_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: Color(0xFF34D399),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            activeOrder.status.label.toUpperCase(),
                            style: const TextStyle(
                              color: Color(0xFF34D399),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Order #$displayOrderNum • $itemCount ${itemCount == 1 ? "item" : "items"}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Track',
                        style: TextStyle(
                          color: Color(0xFF064E3B),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(width: 2),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 13,
                        color: Color(0xFF064E3B),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ----------------------------------------------------
  // ENHANCEMENT 3: QUICK FILTER CHIPS
  // ----------------------------------------------------
  Widget _buildQuickFilterChips(BuildContext context, CustomerState state) {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          // 1. Deals
          _buildFilterChip(
            label: '⚡ Deals',
            isSelected: state.dealsOnly,
            onTap: () {
              HapticFeedback.selectionClick();
              context.read<CustomerBloc>().add(
                    ApplyProductFiltersEvent(
                      dealsOnly: !state.dealsOnly,
                      inStockOnly: state.inStockOnly,
                      fastDeliveryOnly: state.fastDeliveryOnly,
                      sortOption: state.sortOption,
                    ),
                  );
            },
          ),
          const SizedBox(width: 8),

          // 2. In Stock
          _buildFilterChip(
            label: '🟢 In Stock',
            isSelected: state.inStockOnly,
            onTap: () {
              HapticFeedback.selectionClick();
              context.read<CustomerBloc>().add(
                    ApplyProductFiltersEvent(
                      inStockOnly: !state.inStockOnly,
                      dealsOnly: state.dealsOnly,
                      fastDeliveryOnly: state.fastDeliveryOnly,
                      sortOption: state.sortOption,
                    ),
                  );
            },
          ),
          const SizedBox(width: 8),

          // 3. Fast 15m Delivery
          _buildFilterChip(
            label: '🚀 15m Fast',
            isSelected: state.fastDeliveryOnly,
            onTap: () {
              HapticFeedback.selectionClick();
              context.read<CustomerBloc>().add(
                    ApplyProductFiltersEvent(
                      fastDeliveryOnly: !state.fastDeliveryOnly,
                      inStockOnly: state.inStockOnly,
                      dealsOnly: state.dealsOnly,
                      sortOption: state.sortOption,
                    ),
                  );
            },
          ),
          const SizedBox(width: 8),

          // 4. Rating 4.0+
          _buildFilterChip(
            label: '⭐ Rating 4.0+',
            isSelected: state.sortOption == ProductSortOption.ratingHighToLow,
            onTap: () {
              HapticFeedback.selectionClick();
              final newSort = state.sortOption == ProductSortOption.ratingHighToLow
                  ? ProductSortOption.relevance
                  : ProductSortOption.ratingHighToLow;
              context.read<CustomerBloc>().add(
                    ApplyProductFiltersEvent(
                      sortOption: newSort,
                      inStockOnly: state.inStockOnly,
                      fastDeliveryOnly: state.fastDeliveryOnly,
                      dealsOnly: state.dealsOnly,
                    ),
                  );
            },
          ),
          const SizedBox(width: 8),

          // 5. Price: Low to High
          _buildFilterChip(
            label: '💰 Price: Low to High',
            isSelected: state.sortOption == ProductSortOption.priceLowToHigh,
            onTap: () {
              HapticFeedback.selectionClick();
              final newSort = state.sortOption == ProductSortOption.priceLowToHigh
                  ? ProductSortOption.relevance
                  : ProductSortOption.priceLowToHigh;
              context.read<CustomerBloc>().add(
                    ApplyProductFiltersEvent(
                      sortOption: newSort,
                      inStockOnly: state.inStockOnly,
                      fastDeliveryOnly: state.fastDeliveryOnly,
                      dealsOnly: state.dealsOnly,
                    ),
                  );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? AppColors.primary : const Color(0xFFCBD5E1),
              width: isSelected ? 1.5 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    )
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? Colors.white : const Color(0xFF334155),
                ),
              ),
              if (isSelected) ...[
                const SizedBox(width: 5),
                const Icon(Icons.check_rounded, size: 14, color: Colors.white),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPromoBanner(BuildContext context) {
    return const _HeroBannerCarousel();
  }

  Widget _buildCategoriesSection(BuildContext context, CustomerState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Text(
                    'Explore Categories',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, letterSpacing: -0.3),
                  ),
                  SizedBox(width: 6),
                  Text('⚡', style: TextStyle(fontSize: 14)),
                ],
              ),
              if (state.selectedCategoryId != 'cat_all')
                GestureDetector(
                  onTap: () => context.read<CustomerBloc>().add(const FilterByCategoryEvent('cat_all')),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.refresh, size: 12, color: AppColors.primary),
                        SizedBox(width: 4),
                        Text(
                          'Show All',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (state.categories.isEmpty && state.isLoading)
          SizedBox(
            height: 52,
            child: SkeletonShimmer(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 5,
                separatorBuilder: (context, index) => const SizedBox(width: 10),
                itemBuilder: (context, idx) => const Center(
                  child: SkeletonBox(width: 88, height: 38, borderRadius: 20),
                ),
              ),
            ),
          )
        else
          SizedBox(
            height: 52,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: state.categories.length,
              separatorBuilder: (context, index) => const SizedBox(width: 10),
              itemBuilder: (context, idx) {
                final cat = state.categories[idx];
                final isSelected = cat.id == state.selectedCategoryId;
                return Center(
                  child: _AnimatedCategoryChip(
                    category: cat,
                    isSelected: isSelected,
                    onTap: () {
                      context.read<CustomerBloc>().add(FilterByCategoryEvent(cat.id));
                    },
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildStoresSection(BuildContext context, CustomerState state) {
    // Out of Serviceable Zone: Do NOT display retailer shops to customers
    // Only display warning banner if confirmed out of zone and NOT in an initial loading transition
    if (!state.inZone && !state.isLoading && !state.isCheckingLocation) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFCA5A5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFEE2E2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.location_off_rounded, color: Color(0xFFDC2626), size: 20),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Out of Serviceable Zone',
                    style: TextStyle(
                      color: Color(0xFF991B1B),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              state.outOfDeliveryZoneMessage ??
                  'QuickTick is not currently delivering to your location. Retailer stores and products are unavailable in this area.',
              style: const TextStyle(
                color: Color(0xFF7F1D1D),
                fontSize: 12.5,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => CustomerAddressSheet.show(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFDC2626),
                side: const BorderSide(color: Color(0xFFDC2626)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              icon: const Icon(Icons.edit_location_alt_outlined, size: 16),
              label: const Text('Change Delivery Location', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }

    // Zone-scoped & filtered stores derived in BLoC state (Clean Architecture)
    final displayStores = state.zoneStores;
    if (displayStores.isEmpty) {
      if (state.isLoading || state.isCheckingLocation) {
        return SkeletonShimmer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    SkeletonBox(width: 170, height: 16, borderRadius: 4),
                    Spacer(),
                    SkeletonBox(width: 60, height: 16, borderRadius: 8),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 170,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 3,
                  separatorBuilder: (context, index) => const SizedBox(width: 12),
                  itemBuilder: (context, index) => const SkeletonStoreCard(),
                ),
              ),
            ],
          ),
        );
      }
      return const SizedBox.shrink();
    }

    final openCount = state.openStoreCount;
    final expressCount = state.expressStoreCount;
    final currentFilter = state.storeFilter;
    final storesToShow = state.filteredZoneStores;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Restaurants & Local Shops',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, letterSpacing: -0.3),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: 6),
                    Text('🍽️', style: TextStyle(fontSize: 14)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: openCount > 0 ? Colors.green.shade50 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: openCount > 0 ? Colors.green.shade200 : Colors.grey.shade300),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: openCount > 0 ? Colors.green : Colors.grey,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$openCount Open',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: openCount > 0 ? Colors.green.shade800 : Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildStoreTabChip(
                  label: 'All Shops (${displayStores.length})',
                  icon: Icons.storefront_rounded,
                  isSelected: currentFilter == StoreFilterType.all,
                  onTap: () {
                    context.read<CustomerBloc>().add(const FilterStoresEvent(StoreFilterType.all));
                  },
                ),
                const SizedBox(width: 8),
                _buildStoreTabChip(
                  label: '⚡ Express < 10km ($expressCount)',
                  icon: null,
                  isSelected: currentFilter == StoreFilterType.express,
                  activeColor: const Color(0xFF0F766E),
                  onTap: () {
                    context.read<CustomerBloc>().add(const FilterStoresEvent(StoreFilterType.express));
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (storesToShow.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 18, color: Colors.amber.shade800),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No express shops within 10 km. Showing all ${displayStores.length} zone shops with standard delivery.',
                      style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          SizedBox(
            height: 170,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: storesToShow.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, idx) {
                final store = storesToShow[idx];
                return _StoreCard(store: store);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildStoreTabChip({
    required String label,
    IconData? icon,
    required bool isSelected,
    Color? activeColor,
    required VoidCallback onTap,
  }) {
    final themeColor = activeColor ?? AppColors.primary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? themeColor : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? themeColor : Colors.grey.shade300,
              width: 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: themeColor.withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: isSelected ? Colors.white : Colors.grey.shade700),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? Colors.white : Colors.grey.shade800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void _showAddressSelectorModal(BuildContext context, String current) {
  final savedAddrs = context.read<CustomerBloc>().state.savedAddresses;

  showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select Delivery Address', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),

                // GPS Location Trigger
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: AppColors.primary,
                      radius: 16,
                      child: Icon(Icons.my_location, color: Colors.white, size: 18),
                    ),
                    title: const Text(
                      'Detect Current GPS Location',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.primary),
                    ),
                    subtitle: const Text(
                      'Using Device GPS & Location Permission',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                    onTap: () async {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Row(
                            children: [
                              SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                              SizedBox(width: 12),
                              Text('Fetching precise GPS location...'),
                            ],
                          ),
                          duration: Duration(seconds: 2),
                        ),
                      );

                      final pos = await LocationService.getCurrentPosition();
                      final locString = LocationService.formatLocation(pos);
                      if (context.mounted) {
                        context.read<CustomerBloc>().add(SelectAddressEvent(locString, lat: pos?.latitude, lng: pos?.longitude));
                        if (pos != null) {
                          context.read<CustomerBloc>().add(LoadCustomerDataEvent(lat: pos.latitude, lng: pos.longitude));
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('📍 Location updated: $locString'), backgroundColor: AppColors.primary),
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(height: 12),
                const Text('SAVED ADDRESSES', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted, letterSpacing: 1)),
                const SizedBox(height: 4),

                if (savedAddrs.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'No saved addresses yet on your account.',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  )
                else
                  ...savedAddrs.map((entity) {
                    final addr = entity.formattedFullAddress;
                    final isSelected = addr == current;
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.location_on, color: isSelected ? AppColors.primary : AppColors.textSecondary),
                      title: Text('${entity.label.toUpperCase()}: $addr', style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
                      trailing: isSelected ? const Icon(Icons.check_circle, color: AppColors.primary, size: 20) : null,
                      onTap: () {
                        context.read<CustomerBloc>().add(SelectAddressEvent(addr));
                        Navigator.pop(ctx);
                      },
                    );
                  }),
              ],
            ),
          ),
        );
      },
    );
}

void _showCartModal(BuildContext context, {VoidCallback? onNavigateToOrders}) {
  final customerState = context.read<CustomerBloc>().state;
  final cartRetailerId = customerState.cartItems.isNotEmpty
      ? customerState.cartItems.first.product.storeId
      : (customerState.stores.isNotEmpty ? customerState.stores.first.id : null);
  context.read<CustomerBloc>().add(FetchAvailableCouponsEvent(retailerId: cartRetailerId));

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _CartBottomSheet(onNavigateToOrders: onNavigateToOrders),
  );
}

// ----------------------------------------------------
// PRODUCT LIST TILE (Advanced ListView item)
// ----------------------------------------------------
class _ProductListTile extends StatelessWidget {
  final ProductEntity product;
  const _ProductListTile({required this.product});

  static String getStoreName(String storeId, {bool isKannada = false}) {
    String name;
    switch (storeId) {
      case '6aa3febe8b2afec202cc65cc':
        name = 'BigBasket Express';
        break;
      case '6aa4d2968e786cd9f0772009':
        name = 'Daily Needs Supermarket';
        break;
      case '6aa57f6a191b0ba5d25863af':
        name = 'Spice Garden Restaurant';
        break;
      case '6aa4d51e8e786cd9f07720bb':
        name = 'malnad spicies';
        break;
      case '6aa3febe8b2afec202cc65cb':
        name = 'Daily Needs Store';
        break;
      case '6aa3febe8b2afec202cc65c9':
        name = 'QuickStore S391';
        break;
      case '6aa3febe8b2afec202cc65ca':
        name = 'FreshMart Grocery';
        break;
      case '6aa3febe8b2afec202cc65ce':
        name = 'Organic Hub';
        break;
      case '6aa3febe8b2afec202cc65cd':
        name = 'Corner Shop';
        break;
      case '6aecd15dc123b83f572f4dfe':
        name = 'namma angadi';
        break;
      case 'store_04':
        name = 'Spice Route';
        break;
      case 'store_05':
        name = 'The Rustic Oven';
        break;
      case 'store_06':
        name = 'Urban Brew Cafe';
        break;
      case 'store_02':
        name = 'Green Leaf Organic';
        break;
      case 'store_03':
        name = 'Sunrise Bakery';
        break;
      default:
        name = 'Fresh Mart';
    }
    return AppStrings.resolveStoreName(storeId, name, isKannada: isKannada);
  }

  String _getStoreName(String storeId) => getStoreName(storeId);

  Widget _buildDietaryBadge(String name, String categoryId) {
    final foodType = product.resolvedFoodType;
    final Color color;
    if (foodType == 'NON_VEG') {
      color = const Color(0xFFDC2626); // Red
    } else if (foodType == 'EGG') {
      color = const Color(0xFFF59E0B); // Amber / Yellow
    } else {
      color = const Color(0xFF16A34A); // Green
    }

    return Container(
      width: 14,
      height: 14,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 1.2),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Center(
        child: Container(
          width: 5.5,
          height: 5.5,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isKn = context.isKannada;
    final storeName = (product.storeName != null && product.storeName!.trim().isNotEmpty)
        ? AppStrings.resolveStoreName(product.storeId, product.storeName!.trim(), isKannada: isKn)
        : _getStoreName(product.storeId);
    final hasDiscount = product.originalPrice != null && product.originalPrice! > product.price;
    final discountPercent = hasDiscount
        ? (((product.originalPrice! - product.price) / product.originalPrice!) * 100).round()
        : 0;

    return GestureDetector(
      onTap: () {
        final stores = context.read<CustomerBloc>().state.stores;
        final matchingStore = stores.where((s) => s.id == product.storeId).firstOrNull;
        ProductDetailsSheet.show(context, product: product, store: matchingStore);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Product Image with rounded container
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: ImageUrlHelper.optimize(product.imageUrl, width: 240, height: 240),
                    width: 82,
                    height: 82,
                    fit: BoxFit.cover,
                    memCacheWidth: 240,
                    memCacheHeight: 240,
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey.shade100,
                      width: 82,
                      height: 82,
                      child: const Icon(Icons.shopping_bag_outlined, color: Colors.grey),
                    ),
                  ),
                ),
                if (hasDiscount && discountPercent > 0)
                  Positioned(
                    top: 4,
                    left: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F766E),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '$discountPercent% OFF',
                        style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),

            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Veg Badge + Store Attribution
                  Row(
                    children: [
                      _buildDietaryBadge(product.name, product.categoryId),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          storeName,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMuted,
                            letterSpacing: 0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),

                  // Title
                  Text(
                    product.name,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: AppColors.textPrimary, height: 1.2),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),

                  // Description
                  Text(
                    product.description,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),

                  // Unit Tag + Price Row
                  Row(
                    children: [
                      Flexible(
                        fit: FlexFit.loose,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            product.unit,
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 9.5, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '₹${product.price.toStringAsFixed(0)}',
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: AppColors.textPrimary),
                              ),
                              if (product.originalPrice != null) ...[
                                const SizedBox(width: 4),
                                Text(
                                  '₹${product.originalPrice!.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    decoration: TextDecoration.lineThrough,
                                    color: AppColors.textMuted,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Add to Cart Button
            _AddToCartButton(product: product),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------
// STORE CARD (Restaurants & Shops Carousel Card)
// ----------------------------------------------------
typedef _StoreCard = CustomerStoreCard;

class CustomerStoreCard extends StatelessWidget {
  final StoreEntity store;
  const CustomerStoreCard({super.key, required this.store});

  // Standard luminance grayscale matrix for authentic black-and-white rendering
  static const ColorFilter _grayscaleFilter = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0,      0,      0,      1, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = (screenWidth * 0.65).clamp(220.0, 270.0);
    final isClosed = !store.isOpen;

    Widget cardContent = Container(
      width: cardWidth,
      decoration: BoxDecoration(
        color: isClosed ? const Color(0xFFF1F5F9) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isClosed ? Colors.grey.shade400 : AppColors.border,
          width: isClosed ? 1.2 : 1.0,
        ),
        boxShadow: isClosed
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Banner Image with Overlays
          Stack(
            children: [
              CachedNetworkImage(
                imageUrl: store.bannerUrl,
                height: 92,
                width: double.infinity,
                fit: BoxFit.cover,
                memCacheWidth: 600,
                errorWidget: (context, url, error) => Container(
                  height: 92,
                  color: isClosed
                      ? Colors.grey.shade300
                      : AppColors.primaryLight.withValues(alpha: 0.2),
                  child: Icon(
                    Icons.storefront_rounded,
                    color: isClosed ? Colors.grey.shade600 : AppColors.primary,
                  ),
                ),
              ),
              Container(
                height: 92,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: isClosed ? 0.6 : 0.4),
                      Colors.transparent,
                      Colors.black.withValues(alpha: isClosed ? 0.8 : 0.6),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),

              // If closed: Centered "CLOSED" Badge Overlay
              if (isClosed)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.45),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white70, width: 1.2),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock_rounded, color: Colors.white, size: 12),
                            SizedBox(width: 5),
                            Text(
                              'CLOSED',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // Top-left: Delivery Time (when open) or "Opens Soon" (when closed)
              Positioned(
                top: 6,
                left: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: isClosed
                        ? Colors.black.withValues(alpha: 0.65)
                        : (store.isExpress ? const Color(0xFF0F766E) : const Color(0xFFD97706)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isClosed
                            ? Icons.schedule_rounded
                            : (store.isExpress ? Icons.bolt_rounded : Icons.two_wheeler_rounded),
                        color: Colors.white,
                        size: 11,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        isClosed
                            ? 'Opens Soon'
                            : (store.isExpress ? '⚡ ${store.deliveryTime}' : '${store.deliveryTime} (${store.distanceKm.toStringAsFixed(1)}km)'),
                        style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),

              // Top-right: Rating Badge (when open) or "CLOSED" Badge (when closed)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: isClosed ? Colors.grey.shade800 : Colors.green.shade700,
                    borderRadius: BorderRadius.circular(6),
                    border: isClosed ? Border.all(color: Colors.white38, width: 0.8) : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isClosed ? Icons.block_rounded : Icons.star_rounded,
                        color: Colors.white,
                        size: 11,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        isClosed ? 'CLOSED' : store.rating.toStringAsFixed(1),
                        style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Store Info
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        store.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                          color: isClosed ? Colors.grey.shade700 : AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isClosed) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Closed',
                          style: TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        isClosed ? 'Currently not accepting orders' : store.category,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: isClosed ? Colors.grey.shade600 : AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!isClosed) ...[
                      const SizedBox(width: 4),
                      Text(
                        '• ${store.distanceKm < 1.0 ? '${(store.distanceKm * 1000).round()}m' : '${store.distanceKm.toStringAsFixed(1)}km'}',
                        style: const TextStyle(fontSize: 9.5, color: AppColors.textMuted, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );

    // Apply Black & White (Grayscale) filter when store is closed
    if (isClosed) {
      cardContent = ColorFiltered(
        colorFilter: _grayscaleFilter,
        child: cardContent,
      );
    }

    // Card is NOT tappable when closed
    return GestureDetector(
      onTap: store.isOpen ? () => _showStoreDetailsModal(context, store) : null,
      behavior: HitTestBehavior.opaque,
      child: cardContent,
    );
  }
}

void _showStoreDetailsModal(BuildContext context, StoreEntity store) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _StoreDetailsBottomSheet(store: store),
  );
}

class _StoreDetailsBottomSheet extends StatefulWidget {
  final StoreEntity store;
  const _StoreDetailsBottomSheet({required this.store});

  @override
  State<_StoreDetailsBottomSheet> createState() => _StoreDetailsBottomSheetState();
}

class _StoreDetailsBottomSheetState extends State<_StoreDetailsBottomSheet> {
  late StoreEntity _currentStore;
  bool _isLoadingLive = true;

  @override
  void initState() {
    super.initState();
    _currentStore = widget.store;
    _fetchLiveDetails();
  }

  Future<void> _fetchLiveDetails() async {
    try {
      final repo = sl<ICatalogRepository>();
      final res = await repo.getStoreDetails(widget.store.id);
      if (mounted) {
        res.fold(
          (_) {
            setState(() => _isLoadingLive = false);
          },
          (liveStore) {
            setState(() {
              _currentStore = liveStore;
              _isLoadingLive = false;
            });
          },
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingLive = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = _currentStore;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      constraints: BoxConstraints(
        maxHeight: screenHeight * 0.90,
        maxWidth: 640,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Scrollable Store Info Section
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Banner Image & Close
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                          child: CachedNetworkImage(
                            imageUrl: store.bannerUrl,
                            height: 140,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            memCacheWidth: 800,
                            errorWidget: (context, url, error) => Container(
                              height: 140,
                              color: AppColors.primaryLight.withValues(alpha: 0.2),
                              child: const Icon(Icons.storefront_rounded, size: 48, color: AppColors.primary),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 10,
                          right: 10,
                          child: CircleAvatar(
                            backgroundColor: Colors.black54,
                            radius: 16,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              icon: const Icon(Icons.close, color: Colors.white, size: 18),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 10,
                          left: 14,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: store.isOpen ? const Color(0xFF10B981) : Colors.red.shade600,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 7,
                                      height: 7,
                                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      store.isOpen ? 'OPEN NOW' : 'CURRENTLY CLOSED',
                                      style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w900),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_isLoadingLive)
                          const Positioned(
                            top: 10,
                            left: 14,
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            ),
                          ),
                      ],
                    ),

                    Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Store Title & Rating
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  store.name,
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade700,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.star_rounded, color: Colors.white, size: 14),
                                    const SizedBox(width: 3),
                                    Text(
                                      store.rating.toStringAsFixed(1),
                                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            store.category,
                            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 14),

                          const Divider(height: 1, color: AppColors.border),
                          const SizedBox(height: 14),

                          // Location & Address Row
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.location_on_rounded, size: 18, color: AppColors.primary),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Store Address', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                                    const SizedBox(height: 2),
                                    Text(
                                      store.address.isNotEmpty ? store.address : 'Indiranagar 100ft Road, Bangalore, Karnataka',
                                      style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Delivery ETA & Radius (Responsive)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.two_wheeler_rounded, size: 18, color: Color(0xFF0F766E)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Delivery Info', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${store.deliveryTime} • ${store.distanceKm} km away (5 km delivery radius)',
                                      style: const TextStyle(fontSize: 12.5, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Operating Hours & Compliance (Responsive)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.schedule_rounded, size: 18, color: Color(0xFF6366F1)),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Operating Hours', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                                    SizedBox(height: 2),
                                    Text(
                                      '07:00 AM - 11:00 PM • Monday to Sunday',
                                      style: TextStyle(fontSize: 12.5, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // FSSAI License Tag (Responsive with Expanded)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFBBF7D0)),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.verified_user_rounded, color: Color(0xFF16A34A), size: 16),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'FSSAI Lic: 11223344556678 • Verified Merchant Partner',
                                    style: TextStyle(fontSize: 11, color: Color(0xFF166534), fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Primary Action Button: Browse Products
            Padding(
              padding: EdgeInsets.fromLTRB(
                18,
                8,
                18,
                16 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: store.isOpen ? AppColors.primary : Colors.grey.shade400,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: store.isOpen ? 2 : 0,
                  ),
                  icon: Icon(store.isOpen ? Icons.storefront_rounded : Icons.lock_clock_rounded, size: 18),
                  label: Text(
                    store.isOpen ? 'Browse Products from ${store.name}' : '${store.name} is Currently Closed',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                  onPressed: store.isOpen
                      ? () {
                          Navigator.pop(context);
                          context.read<CustomerBloc>().add(FilterByStoreEvent(store));
                        }
                      : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddToCartButton extends StatelessWidget {
  final ProductEntity product;
  const _AddToCartButton({required this.product});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CustomerBloc, CustomerState>(
      // FIX #1: Only rebuild this button when cart items or store open/close status changes.
      // Without this, ALL visible cart buttons rebuilt on EVERY state emit (poll, search, etc.)
      // With 20 products visible: was 20x firstWhere + 20x store.where per emit → now 0 until cart/store changes.
      buildWhen: (prev, curr) =>
          prev.cartItems != curr.cartItems ||
          prev.storeListVersion != curr.storeListVersion,
      builder: (context, state) {
        final cartItem = state.cartItems.firstWhere(
          (c) => c.product.id == product.id,
          orElse: () => CartItemEntity(product: product, quantity: 0),
        );

        final store = state.stores.where((s) => s.id == product.storeId).firstOrNull;
        final isStoreClosed = store != null && !store.isOpen;

        if (isStoreClosed) {
          return Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline_rounded, size: 12, color: Color(0xFF94A3B8)),
                SizedBox(width: 4),
                Text(
                  'Store Closed',
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          );
        }

        if (!product.isAvailable || product.stock <= 0) {
          return Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Text(
              'Out of Stock',
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          );
        }

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutBack,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            return ScaleTransition(
              scale: animation,
              child: FadeTransition(opacity: animation, child: child),
            );
          },
          child: cartItem.quantity == 0
              ? _buildAddButton(context)
              : _buildStepper(context, cartItem.quantity),
        );
      },
    );
  }

  Widget _buildAddButton(BuildContext context) {
    return Material(
      key: ValueKey('add_btn_${product.id}'),
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (product.stock <= 0) {
            HapticFeedback.heavyImpact();
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${product.name} is currently out of stock'),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
            return;
          }
          HapticFeedback.lightImpact();
          context.read<CustomerBloc>().add(AddToCartEvent(product));
        },
        borderRadius: BorderRadius.circular(10),
        splashColor: AppColors.primary.withValues(alpha: 0.15),
        highlightColor: AppColors.primary.withValues(alpha: 0.08),
        child: Ink(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: AppColors.primaryContainer,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.primary, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.08),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.add_rounded, color: AppColors.primary, size: 15),
              const SizedBox(width: 3),
              Text(
                context.isKannada ? 'ಸೇರಿಸಿ' : 'ADD',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepper(BuildContext context, int quantity) {
    return Container(
      key: ValueKey('stepper_${product.id}'),
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Minus Button with tactile feedback
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                if (quantity <= 1) {
                  HapticFeedback.mediumImpact();
                  context.read<CustomerBloc>().add(UpdateCartQuantityEvent(product.id, 0));
                } else {
                  HapticFeedback.selectionClick();
                  context.read<CustomerBloc>().add(UpdateCartQuantityEvent(product.id, quantity - 1));
                }
              },
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(10)),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Icon(Icons.remove_rounded, color: Colors.white, size: 16),
              ),
            ),
          ),

          // Animated Quantity Display
          SizedBox(
            width: 22,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
              child: Text(
                '$quantity',
                key: ValueKey('qty_${product.id}_$quantity'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),

          // Plus Button with tactile feedback & stock limit guard
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                if (quantity >= product.stock) {
                  HapticFeedback.heavyImpact();
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Maximum available stock for ${product.name} is ${product.stock} units'),
                      duration: const Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }
                HapticFeedback.lightImpact();
                context.read<CustomerBloc>().add(UpdateCartQuantityEvent(product.id, quantity + 1));
              },
              borderRadius: const BorderRadius.horizontal(right: Radius.circular(10)),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Icon(Icons.add_rounded, color: Colors.white, size: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------
// FLOATING CART BAR
// ----------------------------------------------------
class _FloatingCartBar extends StatelessWidget {
  final int totalItems;
  final double grandTotal;
  final VoidCallback onViewCart;

  const _FloatingCartBar({
    required this.totalItems,
    required this.grandTotal,
    required this.onViewCart,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F766E), Color(0xFF0D9488)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: const Color(0xFF0F766E).withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: BlocBuilder<CustomerBloc, CustomerState>(
              buildWhen: (prev, curr) =>
                  prev.cartTotalItems != curr.cartTotalItems ||
                  prev.cartGrandTotal != curr.cartGrandTotal ||
                  prev.language != curr.language,
              builder: (context, custState) {
                final strings = custState.strings;
                final itemsCount = custState.cartTotalItems;
                final currentTotal = custState.cartGrandTotal;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${strings.itemsInCartCount(itemsCount)}  •  ₹${currentTotal.toStringAsFixed(0)}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      custState.language == AppLanguage.kannada ? 'ವಿತರಣೆ ಮತ್ತು ಶುಲ್ಕಗಳನ್ನು ಒಳಗೊಂಡಿದೆ' : 'Includes delivery & fees',
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: onViewCart,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: BlocBuilder<CustomerBloc, CustomerState>(
                buildWhen: (prev, curr) => prev.language != curr.language,
                builder: (context, custState) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        custState.strings.viewCart,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 12),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------
// ADVANCED RESPONSIVE CART BOTTOM SHEET & MODAL
// ----------------------------------------------------
class _CartBottomSheet extends StatefulWidget {
  final VoidCallback? onNavigateToOrders;
  const _CartBottomSheet({this.onNavigateToOrders});

  @override
  State<_CartBottomSheet> createState() => _CartBottomSheetState();
}

class _CartBottomSheetState extends State<_CartBottomSheet> {
  double _selectedTip = 0.0;
  final Set<String> _selectedInstructions = {};
  String _selectedPaymentMethod = 'COD';
  final TextEditingController _couponController = TextEditingController();
  bool _isPlacingOrder = false;
  // These flags track navigation for the CURRENT checkout attempt only.
  // They MUST be reset at the start of every new PlaceOrderEvent.
  bool _hasNavigatedToSuccess = false;
  bool _hasNavigatedToFailure = false;
  late RazorpayPaymentService _razorpayService;
  String? _lastCreatedOrderId;

  @override
  void initState() {
    super.initState();
    final cState = context.read<CustomerBloc>().state;
    _selectedTip = cState.selectedTip;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<CustomerBloc>().add(FetchCartPricingEvent(tip: _selectedTip));
      }
    });
    _razorpayService = RazorpayPaymentService(
      onSuccess: _handlePaymentSuccess,
      onFailure: _handlePaymentFailure,
    );
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    if (!mounted) return;
    context.read<CustomerBloc>().add(VerifyRazorpayPaymentEvent(
          razorpayOrderId: response.orderId ?? '',
          razorpayPaymentId: response.paymentId ?? '',
          razorpaySignature: response.signature ?? '',
          orderId: _lastCreatedOrderId ?? '',
        ));
  }

  void _handlePaymentFailure(PaymentFailureResponse response) {
    if (!mounted) return;
    final failMsg = response.message ?? 'Payment was cancelled or could not be completed';
    context.read<CustomerBloc>().add(RazorpayPaymentFailedEvent(failMsg));
    setState(() => _isPlacingOrder = false);

    // If customer intentionally cancelled Razorpay checkout (e.g. tapped back),
    // keep them in the checkout sheet with a snackbar rather than forcing them to a failure screen.
    if (response.code == Razorpay.PAYMENT_CANCELLED) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment cancelled. You can retry anytime or choose Cash on Delivery.'),
          backgroundColor: Color(0xFF1F2937),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    if (!_hasNavigatedToSuccess && !_hasNavigatedToFailure) {
      _hasNavigatedToFailure = true;
      final bloc = context.read<CustomerBloc>();
      final cartTotal = bloc.state.cartGrandTotal;
      final latestOrder = bloc.state.latestPlacedOrder;

      final rootNav = Navigator.of(context, rootNavigator: true);
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (rootNav.mounted) {
          rootNav.push(
            MaterialPageRoute(
              builder: (_) => BlocProvider.value(
                value: bloc,
                child: PaymentFailureScreen(
                  order: latestOrder,
                  errorMessage: failMsg,
                  amount: cartTotal,
                  paymentMethod: _selectedPaymentMethod,
                  onRetryPayment: () {
                    if (_lastCreatedOrderId != null && _lastCreatedOrderId!.isNotEmpty) {
                      setState(() => _isPlacingOrder = true);
                      bloc.add(InitiateRazorpayPaymentEvent(_lastCreatedOrderId!));
                    }
                  },
                  onSwitchToCod: () {
                    setState(() => _selectedPaymentMethod = 'COD');
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Payment mode switched to Cash on Delivery. Tap "Place Order" to confirm.'),
                        backgroundColor: Color(0xFF0F766E),
                      ),
                    );
                  },
                  onBackToCart: () {},
                ),
              ),
            ),
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _razorpayService.dispose();
    _couponController.dispose();
    super.dispose();
  }

  void _applyCoupon(String code, String? retailerId) {
    if (code.trim().isEmpty) return;
    FocusScope.of(context).unfocus();
    final clean = code.trim().toUpperCase();
    final normalized = (clean == 'WELCOME' || clean == 'WELCOME10' || clean == 'WELCOME100') ? 'WELLCOME' : clean;
    context.read<CustomerBloc>().add(
          ApplyCouponEvent(
            code: normalized,
            retailerId: retailerId,
          ),
        );
  }

  void _removeCoupon() {
    _couponController.clear();
    context.read<CustomerBloc>().add(const RemoveCouponEvent());
  }

  StoreEntity _resolveStoreFromCart(CustomerState state) {
    if (state.cartItems.isEmpty) {
      if (state.stores.isNotEmpty) return state.stores.first;
      return const StoreEntity(
        id: 'default_store',
        name: 'QuickTick Store',
        category: 'Grocery',
        address: 'Local Area',
        rating: 4.8,
        deliveryTime: '15-20 min',
        distanceKm: 1.0,
        isOpen: true,
        bannerUrl: '',
      );
    }

    final cartStoreId = state.cartItems.first.product.storeId;

    // 1. Try finding exact matching store from state.stores
    final matching = state.stores.where((s) => s.id == cartStoreId);
    if (matching.isNotEmpty) {
      return matching.first;
    }

    // 2. Resolve known store name from store ID or product details
    final resolvedName = _ProductListTile.getStoreName(cartStoreId);
    final storeName = (resolvedName != 'Fresh Mart' || cartStoreId.isEmpty)
        ? resolvedName
        : 'QuickTick Store';

    return StoreEntity(
      id: cartStoreId,
      name: storeName,
      category: 'Grocery',
      address: 'Local Area',
      rating: 4.8,
      deliveryTime: '15-20 min',
      distanceKm: 1.0,
      isOpen: true,
      bannerUrl: '',
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Container(
          height: screenHeight * 0.90,
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, -4)),
            ],
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: ScaffoldMessenger(
              child: BlocConsumer<CustomerBloc, CustomerState>(
            listenWhen: (previous, current) =>
                previous.isLoading != current.isLoading ||
                previous.activeRazorpayOrder != current.activeRazorpayOrder ||
                previous.paymentVerification != current.paymentVerification ||
                previous.latestPlacedOrder != current.latestPlacedOrder ||
                previous.successMessage != current.successMessage ||
                previous.errorMessage != current.errorMessage ||
                previous.paymentErrorMessage != current.paymentErrorMessage,
            listener: (context, state) {
              // 1. Online Razorpay intent received from backend with real Order ID
              if (state.activeRazorpayOrder != null && _isPlacingOrder) {
                final rzpOrder = state.activeRazorpayOrder!;
                _lastCreatedOrderId = rzpOrder.orderId;
                setState(() => _isPlacingOrder = false);
                context.read<CustomerBloc>().add(const ClearActiveRazorpayOrderEvent());

                final matchedStore = _resolveStoreFromCart(state);

                final authState = context.read<AuthBloc>().state;
                String customerPhone = '+91 98765 43210';
                String customerEmail = 'customer@quicktick.com';
                String customerName = 'Customer';
                if (authState is AuthenticatedState) {
                  customerPhone = authState.user.phone;
                  final email = authState.user.email;
                  if (email != null && email.isNotEmpty) {
                    customerEmail = email;
                  }
                  if (authState.user.name.isNotEmpty) {
                    customerName = authState.user.name;
                  }
                }

                _razorpayService.openCheckout(
                  context: context,
                  keyId: rzpOrder.keyId,
                  amountInPaise: rzpOrder.amount,
                  orderId: rzpOrder.razorpayOrderId,
                  customerPhone: customerPhone,
                  customerEmail: customerEmail,
                  customerName: customerName,
                  storeName: matchedStore.name,
                  description: 'Quick Tick • Order #${rzpOrder.orderId.length > 6 ? rzpOrder.orderId.substring(rzpOrder.orderId.length - 6) : rzpOrder.orderId}',
                );
              }

              // 2. Online Payment Verified (COMPLETED or PENDING) successfully
              if (!_hasNavigatedToSuccess && state.paymentVerification != null && state.paymentVerification!.success) {
                _hasNavigatedToSuccess = true;
                setState(() => _isPlacingOrder = false);
                final fallbackStore = _resolveStoreFromCart(state);
                final effectiveStatus = state.paymentVerification!.isPending ? 'PENDING' : 'COMPLETED';
                final order = state.latestPlacedOrder ?? OrderEntity(
                  id: _lastCreatedOrderId ?? 'ord_${DateTime.now().millisecondsSinceEpoch}',
                  orderNumber: 'QT-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
                  customerId: 'cust_01',
                  customerName: 'Customer',
                  customerPhone: '+91 98765 43210',
                  storeId: fallbackStore.id,
                  storeName: fallbackStore.name,
                  storeAddress: fallbackStore.address,
                  deliveryAddress: state.selectedAddress,
                  items: const [],
                  subtotal: state.cartSubtotal,
                  deliveryFee: state.deliveryFee,
                  platformFee: state.platformFee,
                  grandTotal: state.cartGrandTotal,
                  status: OrderStatus.placed,
                  deliveryOtp: '1234',
                  paymentStatus: effectiveStatus,
                  paymentMethod: _selectedPaymentMethod,
                  createdAt: DateTime.now(),
                );

                final bloc = context.read<CustomerBloc>();
                final rootNav = Navigator.of(context, rootNavigator: true);
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }

                final resolvedOrder = (order.deliveryAddress.isEmpty ||
                        RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(order.deliveryAddress) ||
                        order.deliveryAddress == 'Default Address' ||
                        order.deliveryAddress == 'Customer Default Address')
                    ? order.copyWith(
                        deliveryAddress: state.selectedAddress.isNotEmpty && state.selectedAddress != 'Select Delivery Address'
                            ? state.selectedAddress
                            : order.deliveryAddress,
                      )
                    : order;

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (rootNav.mounted) {
                    rootNav.push(
                      MaterialPageRoute(
                        builder: (_) => BlocProvider.value(
                          value: bloc,
                          child: OrderSuccessScreen(
                            order: resolvedOrder,
                            paymentId: state.paymentVerification?.paymentId,
                            paymentMethod: _selectedPaymentMethod,
                            onTrackOrder: widget.onNavigateToOrders,
                          ),
                        ),
                      ),
                    );
                  }
                });
              }

              // 3. Cash on Delivery (COD) order placed
              if (!_hasNavigatedToSuccess && _isPlacingOrder && _selectedPaymentMethod == 'COD' && state.latestPlacedOrder != null && !state.isLoading) {
                _hasNavigatedToSuccess = true;
                setState(() => _isPlacingOrder = false);
                final order = state.latestPlacedOrder!;
                final bloc = context.read<CustomerBloc>();
                final rootNav = Navigator.of(context, rootNavigator: true);
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }

                final resolvedOrder = (order.deliveryAddress.isEmpty ||
                        RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(order.deliveryAddress) ||
                        order.deliveryAddress == 'Default Address' ||
                        order.deliveryAddress == 'Customer Default Address')
                    ? order.copyWith(
                        deliveryAddress: state.selectedAddress.isNotEmpty && state.selectedAddress != 'Select Delivery Address'
                            ? state.selectedAddress
                            : order.deliveryAddress,
                      )
                    : order;

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (rootNav.mounted) {
                    rootNav.push(
                      MaterialPageRoute(
                        builder: (_) => BlocProvider.value(
                          value: bloc,
                          child: OrderSuccessScreen(
                            order: resolvedOrder,
                            paymentMethod: 'COD',
                            onTrackOrder: widget.onNavigateToOrders,
                          ),
                        ),
                      ),
                    );
                  }
                });
              }

              // 4. Online Payment Verification Failed
              if (!_hasNavigatedToSuccess && !_hasNavigatedToFailure && state.paymentErrorMessage != null) {
                _hasNavigatedToFailure = true;
                setState(() => _isPlacingOrder = false);
                final bloc = context.read<CustomerBloc>();
                final cartTotal = bloc.state.cartGrandTotal;
                final latestOrder = bloc.state.latestPlacedOrder;
                final failMsg = state.paymentErrorMessage ?? 'Payment could not be verified by your bank.';
                final rootNav = Navigator.of(context, rootNavigator: true);
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (rootNav.mounted) {
                    rootNav.push(
                      MaterialPageRoute(
                        builder: (_) => BlocProvider.value(
                          value: bloc,
                          child: PaymentFailureScreen(
                            order: latestOrder,
                            errorMessage: failMsg,
                            amount: cartTotal,
                            paymentMethod: _selectedPaymentMethod,
                        onRetryPayment: () {
                          if (_lastCreatedOrderId != null && _lastCreatedOrderId!.isNotEmpty) {
                            setState(() => _isPlacingOrder = true);
                            bloc.add(InitiateRazorpayPaymentEvent(_lastCreatedOrderId!));
                          }
                        },
                        onSwitchToCod: () {
                          setState(() => _selectedPaymentMethod = 'COD');
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Payment mode switched to Cash on Delivery. Tap "Place Order" to confirm.'),
                              backgroundColor: Color(0xFF0F766E),
                            ),
                          );
                        },
                        onBackToCart: () {},
                      ),
                    ),
                  ),
                );
              }
            });
          }

              // 5. Handle general errors or ended loading state
              if (_isPlacingOrder && !state.isLoading) {
                if (state.errorMessage != null && state.paymentErrorMessage == null) {
                  setState(() => _isPlacingOrder = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(state.errorMessage ?? 'Unable to place order. Please try again.'),
                      backgroundColor: Colors.redAccent,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                } else if (state.latestPlacedOrder == null && state.activeRazorpayOrder == null) {
                  // No order created and no Razorpay intent — clear loading
                  setState(() => _isPlacingOrder = false);
                } else if (_hasNavigatedToSuccess || _hasNavigatedToFailure) {
                  // Navigation already happened — ensure spinner is always cleared
                  setState(() => _isPlacingOrder = false);
                }
              }
            },
            builder: (context, state) {
              if (state.cartItems.isEmpty) {
                return Scaffold(
                  backgroundColor: Colors.transparent,
                  body: _buildEmptyCartView(context),
                );
              }

              final authState = context.read<AuthBloc>().state;
              String customerName = 'Customer';
              String customerPhone = '';
              String customerId = 'cust_01';

              if (authState is AuthenticatedState) {
                customerName = authState.user.name.isNotEmpty ? authState.user.name : 'Customer';
                customerPhone = authState.user.phone;
                customerId = authState.user.id;
              }

              // Centralized state-driven calculations matching backend order & invoice rules
              final double effectiveDeliveryFee = state.deliveryFee;
              final bool isFreeDelivery = effectiveDeliveryFee == 0;
              final double effectiveGrandTotal = state.cartGrandTotal;

              final double totalSavings = (isFreeDelivery && state.effectiveZoneDeliveryFee > 0 ? state.effectiveZoneDeliveryFee : 0.0) +
                  state.couponDiscount +
                  state.cartItems.fold(0.0, (sum, item) {
                    final orig = item.product.originalPrice ?? item.product.price;
                    return sum + ((orig - item.product.price) * item.quantity);
                  });

              return Scaffold(
                backgroundColor: Colors.transparent,
                resizeToAvoidBottomInset: false,
                body: Column(
                  children: [
                    // Top Drag Handle & Store Header
                    _buildCartHeader(context, state),

                    // Scrollable Body
                    Expanded(
                      child: ListView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                        children: [
                          // 0. Minimum Order Progress Banner (shown when below min order)
                          if (state.isBelowMinOrder) ...[
                            _buildMinOrderBanner(context, state),
                            const SizedBox(height: 14),
                          ],

                          // 1. Free Delivery Progress Tracker
                          _buildFreeDeliveryTracker(
                            state.cartSubtotal,
                            isFreeDelivery,
                            threshold: state.effectiveFreeDeliveryThreshold,
                          ),
                          const SizedBox(height: 14),

                          // Smart Cart Optimizer (RAG Engine)
                          CartOptimizerCard(state: state),

                          // 2. Review Cart Items Card
                          _buildCartItemsCard(context, state),
                          const SizedBox(height: 14),

                          // 3. Frequently Bought Together / Quick Add
                          _buildRecommendationsSection(context, state),
                          const SizedBox(height: 14),

                          // 4. Coupons & Offers
                          _buildCouponsCard(context, state),
                          const SizedBox(height: 14),

                          // 5. Delivery Instructions
                          _buildDeliveryInstructionsCard(),
                          const SizedBox(height: 14),

                          // 6. Delivery Partner Tip
                          _buildTipCard(),
                          const SizedBox(height: 14),

                          // 7. Delivery Address & Contact
                          _buildAddressCard(context, state, customerName, customerPhone),
                          const SizedBox(height: 14),

                          // 8. Payment Method Selector
                          _buildPaymentMethodCard(),
                          const SizedBox(height: 14),

                          // 9. Bill Summary & Transparent Breakdown
                          _buildBillDetailsCard(
                            state: state,
                            isFreeDelivery: isFreeDelivery,
                            effectiveDeliveryFee: effectiveDeliveryFee,
                            effectiveGrandTotal: effectiveGrandTotal,
                            totalSavings: totalSavings,
                          ),
                          const SizedBox(height: 16),

                          // 10. Safety & Cancellation Policy Note
                          _buildSafetyNotice(),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ],
                ),
                bottomNavigationBar: _buildStickyCheckoutBar(
                  context: context,
                  state: state,
                  customerId: customerId,
                  customerName: customerName,
                  customerPhone: customerPhone,
                  effectiveGrandTotal: effectiveGrandTotal,
                  totalSavings: totalSavings,
                ),
              );
            },
          ),
        ),
      ),
    ),
  ),
);
}

  // --- EMPTY CART VIEW ---
  Widget _buildEmptyCartView(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.primaryContainer.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.shopping_basket_outlined, size: 52, color: AppColors.primary),
            ),
            const SizedBox(height: 20),
            const Text(
              'Your Basket is Empty',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              'Explore fresh groceries, daily milk, fruits and bakery essentials delivered in 15 minutes.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.storefront_rounded, size: 18),
              label: const Text('Start Shopping', style: TextStyle(fontWeight: FontWeight.w800)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- TOP HEADER ---
  Widget _buildCartHeader(BuildContext context, CustomerState state) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Column(
        children: [
          // Drag Handle
          Container(
            width: 42,
            height: 4.5,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _resolveStoreFromCart(state).name,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.bolt, color: Colors.green, size: 12),
                              SizedBox(width: 2),
                              Text(
                                '15 MINS',
                                style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.w900),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            '•  ${state.cartTotalItems} ${state.cartTotalItems == 1 ? "item" : "items"} in cart',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Clear Cart Button
              TextButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (dCtx) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      title: const Text('Clear Cart?', style: TextStyle(fontWeight: FontWeight.bold)),
                      content: const Text('Are you sure you want to remove all items from your basket?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dCtx),
                          child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            context.read<CustomerBloc>().add(ClearCartEvent());
                            Navigator.pop(dCtx);
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade600,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Clear All'),
                        ),
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.redAccent),
                label: const Text('Clear', style: TextStyle(fontSize: 12, color: Colors.redAccent, fontWeight: FontWeight.w700)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 4),

              IconButton(
                icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                onPressed: () => Navigator.pop(context),
                tooltip: 'Close',
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.surfaceVariant,
                  padding: const EdgeInsets.all(6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- MINIMUM ORDER REQUIREMENT BANNER ---
  Widget _buildMinOrderBanner(BuildContext context, CustomerState state) {
    final double minOrder = state.effectiveMinOrderAmount;
    final double needed = (minOrder - state.cartSubtotal).clamp(1.0, minOrder);
    final double progress = (state.cartSubtotal / (minOrder > 0 ? minOrder : 1.0)).clamp(0.0, 1.0);
    final bool isKn = state.language == AppLanguage.kannada;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFEDD5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFEDD5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.shopping_bag_outlined,
                  color: Color(0xFFEA580C),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isKn
                          ? 'ಕನಿಷ್ಠ ಆರ್ಡರ್ ಮೊತ್ತ: ₹${minOrder.toStringAsFixed(0)}'
                          : 'Minimum Order: ₹${minOrder.toStringAsFixed(0)} (${state.zoneName ?? "your zone"})',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: Color(0xFF9A3412),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isKn
                          ? 'ಆರ್ಡರ್ ಮಾಡಲು ಇನ್ನೂ ₹${needed.toStringAsFixed(0)} ಮೌಲ್ಯದ ವಸ್ತುಗಳನ್ನು ಸೇರಿಸಿ'
                          : 'Add items worth ₹${needed.toStringAsFixed(0)} more to place order',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: Color(0xFFC2410C),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: const Color(0xFFFFEDD5),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFEA580C)),
            ),
          ),
        ],
      ),
    );
  }

  // --- FREE DELIVERY MILESTONE TRACKER ---
  Widget _buildFreeDeliveryTracker(double subtotal, bool isFree, {double threshold = 199.0}) {
    final double freeThreshold = threshold > 0 ? threshold : (isFree ? 1.0 : 199.0);
    final double progress = isFree ? 1.0 : (subtotal / freeThreshold).clamp(0.0, 1.0);
    final double remaining = isFree ? 0.0 : (freeThreshold - subtotal).clamp(0.0, freeThreshold);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isFree
              ? [const Color(0xFFECFDF5), const Color(0xFFD1FAE5)]
              : [const Color(0xFFF0FDFA), const Color(0xFFCCFBF1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isFree ? const Color(0xFFA7F3D0) : const Color(0xFF99F6E4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isFree ? Icons.celebration_rounded : Icons.delivery_dining_rounded,
                color: isFree ? const Color(0xFF059669) : const Color(0xFF0D9488),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isFree
                      ? '🎉 FREE Hyperlocal Delivery Unlocked!'
                      : 'Add ₹${remaining.toStringAsFixed(0)} more for FREE Delivery 🛵',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: isFree ? const Color(0xFF065F46) : const Color(0xFF115E59),
                  ),
                ),
              ),
              if (isFree)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF059669),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'SAVED ₹15',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10),
                  ),
                ),
            ],
          ),
          if (!isFree) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: Colors.teal.shade100,
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0D9488)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- REVIEW CART ITEMS CARD ---
  Widget _buildCartItemsCard(BuildContext context, CustomerState state) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Review Items',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textPrimary),
                ),
                Text(
                  '${state.cartTotalItems} items',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            itemCount: state.cartItems.length,
            separatorBuilder: (ctx, i) => const Divider(height: 16, color: Color(0xFFF1F5F9)),
            itemBuilder: (context, index) {
              final item = state.cartItems[index];
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Item Image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: CachedNetworkImage(
                      imageUrl: ImageUrlHelper.optimize(item.product.imageUrl, width: 160, height: 160),
                      width: 54,
                      height: 54,
                      fit: BoxFit.cover,
                      memCacheWidth: 160,
                      memCacheHeight: 160,
                      errorWidget: (context, url, error) => Container(
                        width: 54,
                        height: 54,
                        color: Colors.grey.shade100,
                        child: const Icon(Icons.shopping_bag_outlined, color: Colors.grey, size: 22),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Item Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.product.name,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Wrap(
                          spacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              item.product.unit,
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w500),
                            ),
                            Text(
                              '• ₹${item.product.price.toStringAsFixed(0)} each',
                              style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Modern Stepper
                  _buildItemQuantityStepper(context, item),
                  const SizedBox(width: 8),

                  // Total Item Price
                  ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 44),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        '₹${item.total.toStringAsFixed(0)}',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppColors.textPrimary),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // --- ITEM QUANTITY STEPPER ---
  Widget _buildItemQuantityStepper(BuildContext context, CartItemEntity item) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F766E),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(color: const Color(0xFF0F766E).withValues(alpha: 0.25), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () {
              context.read<CustomerBloc>().add(UpdateCartQuantityEvent(item.product.id, item.quantity - 1));
            },
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
              child: Icon(
                item.quantity == 1 ? Icons.delete_outline_rounded : Icons.remove,
                color: item.quantity == 1 ? Colors.amberAccent : Colors.white,
                size: 15,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '${item.quantity}',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12),
            ),
          ),
          InkWell(
            onTap: () {
              if (item.quantity >= item.product.stock) {
                HapticFeedback.heavyImpact();
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Maximum available stock for ${item.product.name} is ${item.product.stock} units'),
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }
              context.read<CustomerBloc>().add(UpdateCartQuantityEvent(item.product.id, item.quantity + 1));
            },
            borderRadius: const BorderRadius.horizontal(right: Radius.circular(10)),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 7, vertical: 6),
              child: Icon(Icons.add, color: Colors.white, size: 15),
            ),
          ),
        ],
      ),
    );
  }

  // --- FREQUENTLY BOUGHT TOGETHER / QUICK ADD ---
  Widget _buildRecommendationsSection(BuildContext context, CustomerState state) {
    final cartProductIds = state.cartItems.map((c) => c.product.id).toSet();
    final recommendations = state.allProducts.where((p) => !cartProductIds.contains(p.id)).take(4).toList();

    if (recommendations.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              Icon(Icons.auto_awesome, color: Colors.amber, size: 16),
              SizedBox(width: 6),
              Text(
                'Missed Anything? Frequently Added',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.textPrimary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: recommendations.length,
            separatorBuilder: (ctx, i) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final prod = recommendations[index];
              return Container(
                width: 220,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: ImageUrlHelper.optimize(prod.imageUrl, width: 150, height: 150),
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        memCacheWidth: 150,
                        memCacheHeight: 150,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            prod.name,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            prod.unit,
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
                          ),
                          Text(
                            '₹${prod.price.toStringAsFixed(0)}',
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: AppColors.primary),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        context.read<CustomerBloc>().add(AddToCartEvent(prod));
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryContainer,
                        foregroundColor: AppColors.primary,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('+ ADD', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // --- COUPONS & OFFERS CARD ---
  Widget _buildCouponsCard(BuildContext context, CustomerState state) {
    final applied = state.appliedCoupon;
    final retailerId = state.cartItems.isNotEmpty ? state.cartItems.first.product.storeId : null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: applied != null ? Colors.teal.shade200 : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_offer_rounded, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              const Text(
                'Coupons & Offers',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.textPrimary),
              ),
              const Spacer(),
              if (applied != null)
                TextButton(
                  onPressed: _removeCoupon,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Remove', style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 10),

          if (applied != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.teal.shade300),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_rounded, color: Colors.teal, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Code "${applied.code}" Applied! ${applied.label.isNotEmpty ? applied.label : "You saved ₹${applied.discount.toStringAsFixed(0)}"}',
                      style: TextStyle(color: Colors.teal.shade900, fontWeight: FontWeight.w800, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _couponController,
                    textCapitalization: TextCapitalization.characters,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Enter coupon code (e.g. SAVE20)',
                      hintStyle: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: state.isApplyingCoupon
                      ? null
                      : () {
                          if (_couponController.text.trim().isNotEmpty) {
                            _applyCoupon(_couponController.text.trim(), retailerId);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: state.isApplyingCoupon
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Apply', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                ),
              ],
            ),
            if (state.couponErrorMessage != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.red.shade700, size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        state.couponErrorMessage!,
                        style: TextStyle(color: Colors.red.shade800, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: state.availableCoupons.isNotEmpty
                  ? state.availableCoupons.map((c) {
                      final minText = c.minOrder > 0 ? 'Min ₹${c.minOrder.toInt()}' : null;
                      final label = minText != null ? '${c.label} • $minText' : c.label;
                      return _buildQuickCouponChip(c.code, label, retailerId);
                    }).toList()
                  : [
                      _buildQuickCouponChip('WELLCOME', '10% OFF • Min ₹102', retailerId),
                    ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickCouponChip(String code, String desc, String? retailerId) {
    return InkWell(
      onTap: () => _applyCoupon(code, retailerId),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFCBD5E1), style: BorderStyle.solid),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.confirmation_number_outlined, size: 12, color: AppColors.primary),
            const SizedBox(width: 4),
            Text(
              '$code ($desc)',
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }

  // --- DELIVERY INSTRUCTIONS CARD ---
  Widget _buildDeliveryInstructionsCard() {
    final instructions = [
      {'icon': Icons.notifications_off_outlined, 'label': 'Don\'t ring bell'},
      {'icon': Icons.door_front_door_outlined, 'label': 'Leave at door'},
      {'icon': Icons.phone_disabled_outlined, 'label': 'Avoid calling'},
      {'icon': Icons.shield_outlined, 'label': 'Leave with guard'},
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.directions_bike_rounded, color: AppColors.primary, size: 18),
              SizedBox(width: 8),
              Text(
                'Delivery Instructions',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: instructions.map((item) {
              final label = item['label'] as String;
              final icon = item['icon'] as IconData;
              final isSelected = _selectedInstructions.contains(label);

              return FilterChip(
                label: Text(label, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500)),
                avatar: Icon(icon, size: 14, color: isSelected ? Colors.white : AppColors.textSecondary),
                selected: isSelected,
                selectedColor: AppColors.primary,
                labelStyle: TextStyle(color: isSelected ? Colors.white : AppColors.textPrimary),
                backgroundColor: AppColors.surfaceVariant,
                checkmarkColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                onSelected: (val) {
                  setState(() {
                    if (val) {
                      _selectedInstructions.add(label);
                    } else {
                      _selectedInstructions.remove(label);
                    }
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // --- TIP CARD ---
  Widget _buildTipCard() {
    final tips = [0.0, 10.0, 20.0, 30.0, 50.0];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.favorite_rounded, color: Colors.pinkAccent, size: 18),
              SizedBox(width: 8),
              Text(
                'Tip Your Delivery Partner',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 2),
          const Text(
            '100% of the tip goes directly to your rider.',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
          Row(
            children: tips.map((tip) {
              final isSelected = _selectedTip == tip;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: InkWell(
                    onTap: () {
                      setState(() => _selectedTip = tip);
                      context.read<CustomerBloc>().add(SelectTipEvent(tip));
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF0F766E) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF0F766E) : const Color(0xFFCBD5E1),
                        ),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          tip == 0 ? 'No tip' : '₹${tip.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                            color: isSelected ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // --- ADDRESS & CONTACT CARD ---
  Widget _buildAddressCard(BuildContext context, CustomerState state, String name, String phone) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.location_on_rounded, color: AppColors.primary, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    state.language == AppLanguage.kannada ? 'ವಿತರಣಾ ವಿಳಾಸ' : 'Delivery Address',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.textPrimary),
                  ),
                ],
              ),
              InkWell(
                onTap: () => _showAddressSelectorModal(context, state.selectedAddress),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    state.strings.change,
                    style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            state.selectedAddress,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            'Recipient: $name • $phone',
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  // --- PAYMENT METHOD SELECTOR ---
  Widget _buildPaymentMethodCard() {
    final paymentModes = [
      {'id': 'COD', 'title': 'Cash on Delivery (COD)', 'subtitle': 'Pay cash or scan driver QR upon arrival', 'icon': Icons.payments_rounded},
      {'id': 'UPI', 'title': 'Instant UPI (Google Pay, PhonePe, Paytm)', 'subtitle': 'Fast & zero contact checkout', 'icon': Icons.account_balance_wallet_rounded},
      {'id': 'CARD', 'title': 'Credit / Debit Card / NetBanking', 'subtitle': 'Secure 256-bit encrypted gateway', 'icon': Icons.credit_card_rounded},
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.payment_rounded, color: AppColors.primary, size: 18),
              SizedBox(width: 8),
              Text(
                'Payment Mode',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...paymentModes.map((pm) {
            final isCod = pm['id'] == 'COD';
            final isSelected = _selectedPaymentMethod == pm['id'];
            return InkWell(
              onTap: () => setState(() => _selectedPaymentMethod = pm['id'] as String),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFF0FDFA) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF14B8A6) : Colors.transparent,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: isSelected ? AppColors.primary : AppColors.textMuted,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Icon(pm['icon'] as IconData, color: isSelected ? AppColors.primary : AppColors.textSecondary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  pm['title'] as String,
                                  style: TextStyle(
                                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                    fontSize: 12,
                                    color: AppColors.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (!isCod) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                                  ),
                                  child: const Text(
                                    'RAZORPAY',
                                    style: TextStyle(
                                      color: Color(0xFF10B981),
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Text(
                            pm['subtitle'] as String,
                            style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // --- BILL SUMMARY CARD ---
  Widget _buildBillDetailsCard({
    required CustomerState state,
    required bool isFreeDelivery,
    required double effectiveDeliveryFee,
    required double effectiveGrandTotal,
    required double totalSavings,
  }) {
    final subtotalVal = state.cartSubtotal;
    final delFeeVal = state.deliveryFee;
    final platFeeVal = state.platformFee;
    final taxVal = state.taxAmount;
    final tipVal = state.tipAmount;
    final discountVal = state.couponDiscount;
    final totalVal = state.cartGrandTotal;

    final strings = state.strings;
    final isKn = state.language == AppLanguage.kannada;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            strings.billDetails,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 12),

          _BillRow(label: strings.itemTotal, amount: '₹${subtotalVal.toStringAsFixed(2)}'),
          _BillRow(
            label: isKn ? 'ವಿತರಣಾ ಶುಲ್ಕ (15-ನಿಮಿಷಗಳ ಡೆಲಿವರಿ)' : 'Delivery Fee (Hyperlocal 15-Min)',
            amount: delFeeVal == 0 ? strings.freeDelivery : '₹${delFeeVal.toStringAsFixed(2)}',
            isDiscount: delFeeVal == 0,
          ),
          _BillRow(
            label: isKn ? 'ಪ್ಲಾಟ್‌ಫಾರ್ಮ್ ಮತ್ತು ಪ್ಯಾಕೇಜಿಂಗ್ ಶುಲ್ಕ' : 'Platform & Packaging Fee',
            amount: '₹${platFeeVal.toStringAsFixed(2)}',
          ),

          if (taxVal > 0) ...[
            _BillRow(label: strings.taxesAndCharges, amount: '₹${taxVal.toStringAsFixed(2)}'),
            if (state.cartPricing?.taxBreakdown != null && state.cartPricing!.taxBreakdown.hasBreakdown)
              Padding(
                padding: const EdgeInsets.only(left: 14, bottom: 4),
                child: Column(
                  children: [
                    if (state.cartPricing!.taxBreakdown.cgst > 0)
                      _BillSubRow(label: '• CGST', amount: '₹${state.cartPricing!.taxBreakdown.cgst.toStringAsFixed(2)}'),
                    if (state.cartPricing!.taxBreakdown.sgst > 0)
                      _BillSubRow(label: '• SGST', amount: '₹${state.cartPricing!.taxBreakdown.sgst.toStringAsFixed(2)}'),
                    if (state.cartPricing!.taxBreakdown.igst > 0)
                      _BillSubRow(label: '• IGST', amount: '₹${state.cartPricing!.taxBreakdown.igst.toStringAsFixed(2)}'),
                  ],
                ),
              ),
          ],

          if (tipVal > 0)
            _BillRow(label: strings.tipAmount, amount: '+ ₹${tipVal.toStringAsFixed(2)}'),

          if (discountVal > 0)
            _BillRow(
              label: '${strings.couponDiscount} (${state.appliedCoupon?.code ?? (isKn ? "ಆಫರ್" : "Offer")})',
              amount: '- ₹${discountVal.toStringAsFixed(2)}',
              isDiscount: true,
            ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(color: AppColors.border, height: 1),
          ),

          _BillRow(
            label: strings.toPay,
            amount: '₹${totalVal.toStringAsFixed(2)}',
            isTotal: true,
          ),

          if (totalSavings > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.savings_outlined, color: Colors.green, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    isKn
                        ? '🎉 ನೀವು ಈ ಆರ್ಡರ್‌ನಲ್ಲಿ ₹${totalSavings.toStringAsFixed(0)} ಉಳಿಸಿದ್ದೀರಿ!'
                        : '🎉 You saved ₹${totalSavings.toStringAsFixed(0)} on this order!',
                    style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.w800, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- SAFETY NOTICE ---
  Widget _buildSafetyNotice() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.verified_user_outlined, color: Color(0xFF0F766E), size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              '100% Hygienic & Temperature Controlled packaging. Orders cannot be cancelled once packed by the store.',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  // --- STICKY BOTTOM CHECKOUT ACTION BAR ---
  Widget _buildStickyCheckoutBar({
    required BuildContext context,
    required CustomerState state,
    required String customerId,
    required String customerName,
    required String customerPhone,
    required double effectiveGrandTotal,
    required double totalSavings,
  }) {
    final double minOrder = state.effectiveMinOrderAmount;
    final bool isBelowMin = state.isBelowMinOrder;
    final double needed = (minOrder - state.cartSubtotal).clamp(1.0, minOrder);
    final bool isKn = state.language == AppLanguage.kannada;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, -4)),
        ],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isBelowMin) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFFEDD5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: Color(0xFFC2410C), size: 15),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isKn
                            ? 'ಕನಿಷ್ಠ ಆರ್ಡರ್ ಮೊತ್ತ ₹${minOrder.toStringAsFixed(0)}. ಇನ್ನೂ ₹${needed.toStringAsFixed(0)} ಸೇರಿಸಿ.'
                            : 'Min order for ${state.zoneName ?? "your zone"} is ₹${minOrder.toStringAsFixed(0)}. Add ₹${needed.toStringAsFixed(0)} more.',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFC2410C)),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            Row(
              children: [
                // Left Total Info
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '₹${effectiveGrandTotal.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: AppColors.textPrimary,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.keyboard_arrow_up_rounded, size: 16, color: AppColors.textSecondary),
                          ],
                        ),
                      ),
                      Text(
                        _selectedPaymentMethod == 'COD'
                            ? (isKn ? 'ನಗದು / UPI ಪಾವತಿ' : 'Pay via Cash/UPI')
                            : (isKn ? 'ಆನ್‌ಲೈನ್ ಪಾವತಿ' : 'Pay Online Now'),
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Right Place Order CTA
                Expanded(
                  flex: 6,
                  child: ElevatedButton(
                    onPressed: _isPlacingOrder
                        ? null
                        : () {
                            if (state.selectedAddress == 'Select Delivery Address' || state.selectedAddress.isEmpty) {
                              ScaffoldMessenger.of(context).hideCurrentSnackBar();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please select or add a delivery address first.'),
                                  backgroundColor: Colors.orange,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                              InitialLocationPromptSheet.show(context);
                              return;
                            }

                            if (!state.inZone) {
                              ScaffoldMessenger.of(context).hideCurrentSnackBar();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(state.outOfDeliveryZoneMessage ?? 'Order cannot be placed outside the delivery zone.'),
                                  backgroundColor: Colors.redAccent,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                              return;
                            }

                            if (state.isBelowMinOrder) {
                              ScaffoldMessenger.of(context).hideCurrentSnackBar();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      const Icon(Icons.info_outline_rounded, color: Colors.white, size: 20),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          isKn
                                              ? 'ಕನಿಷ್ಠ ಆರ್ಡರ್ ಮೊತ್ತ ₹${minOrder.toStringAsFixed(0)}. ಇನ್ನೂ ₹${needed.toStringAsFixed(0)} ಸೇರಿಸಿ.'
                                              : 'Minimum order for ${state.zoneName ?? "your zone"} is ₹${minOrder.toStringAsFixed(0)}. Add ₹${needed.toStringAsFixed(0)} more to checkout.',
                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                        ),
                                      ),
                                    ],
                                  ),
                                  backgroundColor: Colors.orange.shade800,
                                  behavior: SnackBarBehavior.floating,
                                  duration: const Duration(seconds: 3),
                                  action: SnackBarAction(
                                    label: isKn ? 'ಖರೀದಿಸಿ' : 'Shop More',
                                    textColor: Colors.white,
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                    },
                                  ),
                                ),
                              );
                              return;
                            }

                            if (sl.isRegistered<INetworkConnectivityService>() &&
                                !sl<INetworkConnectivityService>().isConnected) {
                              ScaffoldMessenger.of(context).hideCurrentSnackBar();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Row(
                                    children: [
                                      Icon(Icons.wifi_off_rounded, color: Colors.white, size: 18),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'You are offline. Please check your internet connection to place order.',
                                          style: TextStyle(fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ],
                                  ),
                                  backgroundColor: Color(0xFF1E293B),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                              return;
                            }

                            // Reset navigation flags for this NEW checkout attempt.
                            // Without this, a second order placed in the same session
                            // would see _hasNavigatedToSuccess==true and never navigate.
                            _hasNavigatedToSuccess = false;
                            _hasNavigatedToFailure = false;
                            setState(() => _isPlacingOrder = true);

                            final matchedStore = _resolveStoreFromCart(state);
                            String? selectedAddressId;
                            if (state.savedAddresses.isNotEmpty) {
                              try {
                                final match = state.savedAddresses.firstWhere(
                                  (a) => a.formattedFullAddress == state.selectedAddress,
                                  orElse: () => state.savedAddresses.firstWhere(
                                    (a) => a.isDefault,
                                    orElse: () => state.savedAddresses.first,
                                  ),
                                );
                                selectedAddressId = match.id;
                              } catch (_) {}
                            }

                            // Place order into CustomerBloc with the selected payment method, delivery address, and coupon
                            context.read<CustomerBloc>().add(PlaceOrderEvent(
                                  customerId: customerId,
                                  customerName: customerName,
                                  customerPhone: customerPhone,
                                  storeId: matchedStore.id,
                                  storeName: matchedStore.name,
                                  storeAddress: matchedStore.address,
                                  deliveryAddress: state.selectedAddress,
                                  paymentMethod: _selectedPaymentMethod,
                                  zoneId: state.zoneId,
                                  deliveryAddressId: selectedAddressId,
                                  couponCode: state.appliedCoupon?.code,
                                  couponDiscount: state.couponDiscount,
                                ));
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isBelowMin ? Colors.orange.shade800 : const Color(0xFF0F766E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 4,
                      shadowColor: (isBelowMin ? Colors.orange : const Color(0xFF0F766E)).withValues(alpha: 0.4),
                    ),
                    child: _isPlacingOrder
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  isBelowMin
                                      ? (isKn ? 'ಇನ್ನೂ ₹${needed.toStringAsFixed(0)} ಸೇರಿಸಿ' : 'Add ₹${needed.toStringAsFixed(0)} More')
                                      : (_selectedPaymentMethod == 'COD'
                                          ? (isKn ? 'ಆರ್ಡರ್ ದೃಢೀಕರಿಸಿ' : 'Place Order')
                                          : (isKn ? 'ಪಾವತಿಗೆ ಮುಂದುವರಿಯಿರಿ' : 'Proceed to Pay')),
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                                ),
                                const SizedBox(width: 6),
                                Icon(isBelowMin ? Icons.add_shopping_cart_rounded : Icons.arrow_forward_rounded, size: 18),
                              ],
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------
// BILL ROW COMPONENT
// ----------------------------------------------------
class _BillRow extends StatelessWidget {
  final String label;
  final String amount;
  final bool isTotal;
  final bool isDiscount;

  const _BillRow({
    required this.label,
    required this.amount,
    this.isTotal = false,
    this.isDiscount = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: isTotal ? 16 : 13,
                fontWeight: isTotal ? FontWeight.w900 : FontWeight.w500,
                color: isDiscount ? Colors.teal.shade800 : (isTotal ? AppColors.textPrimary : AppColors.textSecondary),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            amount,
            style: TextStyle(
              fontSize: isTotal ? 18 : 13,
              fontWeight: isTotal ? FontWeight.w900 : FontWeight.w700,
              color: isDiscount ? Colors.teal.shade800 : (isTotal ? AppColors.textPrimary : AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _BillSubRow extends StatelessWidget {
  final String label;
  final String amount;

  const _BillSubRow({required this.label, required this.amount});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            amount,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------
// MY ORDERS VIEW (Advanced UI with Live Timeline & Filter Tabs)
// ----------------------------------------------------
class _CustomerOrdersView extends StatefulWidget {
  const _CustomerOrdersView();

  @override
  State<_CustomerOrdersView> createState() => _CustomerOrdersViewState();
}

class _CustomerOrdersViewState extends State<_CustomerOrdersView> {
  int _selectedFilterIndex = 0; // 0 = Active, 1 = Completed

  @override
  void initState() {
    super.initState();
    // Refresh orders once on opening tab
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<CustomerBloc>().add(const RefreshCustomerOrdersEvent());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CustomerBloc, CustomerState>(
      listenWhen: (prev, curr) =>
          prev.errorMessage != curr.errorMessage ||
          prev.successMessage != curr.successMessage ||
          prev.lastDownloadedInvoicePath != curr.lastDownloadedInvoicePath,
      listener: (context, state) {
        if (state.errorMessage != null && state.errorMessage!.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else if (state.successMessage != null && state.successMessage!.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.successMessage!),
              backgroundColor: const Color(0xFF0F766E),
              behavior: SnackBarBehavior.floating,
              action: (state.lastDownloadedInvoicePath != null && state.lastDownloadedInvoicePath!.isNotEmpty)
                  ? SnackBarAction(
                      label: 'OPEN',
                      textColor: Colors.amberAccent,
                      onPressed: () {
                        OpenFilex.open(state.lastDownloadedInvoicePath!, type: 'application/pdf');
                      },
                    )
                  : null,
            ),
          );
        }
      },
      buildWhen: (prev, curr) => prev.myOrders != curr.myOrders || prev.language != curr.language,
      builder: (context, state) {
        final isKn = state.language == AppLanguage.kannada;

        final activeOrders = state.myOrders.where((o) =>
            o.status != OrderStatus.delivered &&
            o.status != OrderStatus.cancelled &&
            o.status != OrderStatus.rejected).toList();

        final pastOrders = state.myOrders.where((o) =>
            o.status == OrderStatus.delivered ||
            o.status == OrderStatus.cancelled ||
            o.status == OrderStatus.rejected).toList();

        final displayOrders = _selectedFilterIndex == 0 ? activeOrders : pastOrders;

        return Column(
          children: [
            // Top Filter Tabs Bar
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: _OrderFilterTab(
                      label: isKn
                          ? 'ಪ್ರಸ್ತುತ ಆರ್ಡರ್‌ಗಳು (${activeOrders.length})'
                          : 'Active Orders (${activeOrders.length})',
                      isSelected: _selectedFilterIndex == 0,
                      onTap: () => setState(() => _selectedFilterIndex = 0),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _OrderFilterTab(
                      label: isKn
                          ? 'ಹಿಂದಿನ ಆರ್ಡರ್‌ಗಳು (${pastOrders.length})'
                          : 'Past Orders (${pastOrders.length})',
                      isSelected: _selectedFilterIndex == 1,
                      onTap: () => setState(() => _selectedFilterIndex = 1),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Orders List / Skeleton / Empty View
            Expanded(
              child: (state.isLoading && state.myOrders.isEmpty)
                  ? const CustomerOrdersSkeleton()
                  : RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: () async {
                        context.read<CustomerBloc>().add(LoadCustomerDataEvent());
                        await Future.delayed(const Duration(milliseconds: 600));
                      },
                      child: displayOrders.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          const SizedBox(height: 60),
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: const BoxDecoration(
                                      color: AppColors.primaryContainer,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.receipt_long_rounded,
                                      size: 48,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _selectedFilterIndex == 0
                                        ? (isKn ? 'ಯಾವುದೇ ಸಕ್ರಿಯ ಆರ್ಡರ್‌ಗಳಿಲ್ಲ' : 'No Active Deliveries')
                                        : (isKn ? 'ಹಿಂದಿನ ಆರ್ಡರ್‌ಗಳು ಕಂಡುಬಂದಿಲ್ಲ' : 'No Past Orders Found'),
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _selectedFilterIndex == 0
                                        ? (isKn ? 'ಲೈವ್ ವಿತರಣೆಯನ್ನು ಟ್ರ್ಯಾಕ್ ಮಾಡಲು ದಿನಸಿ & ವಸ್ತುಗಳನ್ನು ಆರ್ಡರ್ ಮಾಡಿ.' : 'Place an order for fresh groceries & essentials to track live delivery.')
                                        : (isKn ? 'ನಿಮ್ಮ ಹಿಂದಿನ ಎಲ್ಲಾ ರಶೀದಿಗಳು ಇಲ್ಲಿ ಕಾಣಿಸುತ್ತವೆ.' : 'Your previous completed order receipts will appear here.'),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                  ),
                                  if (_selectedFilterIndex == 0 && pastOrders.isNotEmpty) ...[
                                    const SizedBox(height: 16),
                                    OutlinedButton.icon(
                                      onPressed: () => setState(() => _selectedFilterIndex = 1),
                                      icon: const Icon(Icons.history_rounded, size: 18),
                                      label: Text(isKn ? 'ಹಿಂದಿನ ಆರ್ಡರ್‌ಗಳನ್ನು ನೋಡಿ (${pastOrders.length})' : 'View Past Orders (${pastOrders.length})'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppColors.primary,
                                        side: const BorderSide(color: AppColors.primary),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        itemCount: displayOrders.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 16),
                        itemBuilder: (context, idx) {
                          final order = displayOrders[idx];
                          return _AdvancedOrderCard(order: order);
                        },
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _OrderFilterTab extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _OrderFilterTab({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : AppColors.textSecondary,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _AdvancedOrderCard extends StatelessWidget {
  final OrderEntity order;
  const _AdvancedOrderCard({required this.order});

  String _resolveDisplayStoreName(OrderEntity order, {bool isKannada = false}) {
    String name;
    if (order.storeName.isNotEmpty &&
        order.storeName != 'QuickMart Supermarket' &&
        order.storeName != 'Store' &&
        order.storeName != 'QuickTick Store' &&
        order.storeName != 'Quick Tick Mart') {
      name = order.storeName;
    } else {
      final mappedName = _ProductListTile.getStoreName(order.storeId, isKannada: isKannada);
      if (mappedName != 'Fresh Mart' && mappedName != 'ಫ್ರೆಶ್ ಮಾರ್ಟ್') {
        return mappedName;
      }
      if (order.storeName.isNotEmpty && order.storeName != 'Store') {
        name = order.storeName;
      } else {
        name = 'QuickTick Supermarket';
      }
    }
    return AppStrings.resolveStoreName(order.storeId, name, isKannada: isKannada);
  }

  @override
  Widget build(BuildContext context) {
    final isActive = order.status != OrderStatus.paymentPending &&
        order.status != OrderStatus.delivered &&
        order.status != OrderStatus.cancelled &&
        order.status != OrderStatus.rejected;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Store Name, Status Badge & Order Number
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant.withValues(alpha: 0.5),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      BlocBuilder<CustomerBloc, CustomerState>(
                        buildWhen: (prev, curr) => prev.language != curr.language,
                        builder: (context, custState) {
                          final isKn = custState.language == AppLanguage.kannada;
                          return Text(
                            _resolveDisplayStoreName(order, isKannada: isKn),
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textPrimary),
                          );
                        },
                      ),
                      const SizedBox(height: 2),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        children: [
                          Text(
                            'Order #${order.orderNumber}',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                          BlocBuilder<CustomerBloc, CustomerState>(
                            buildWhen: (prev, curr) => prev.isDownloadingInvoice != curr.isDownloadingInvoice,
                            builder: (context, custState) {
                              final isDownloading = custState.isDownloadingInvoice;
                              return InkWell(
                                onTap: isDownloading
                                    ? null
                                    : () {
                                        context.read<CustomerBloc>().add(DownloadOrderInvoiceEvent(order.id));
                                      },
                                borderRadius: BorderRadius.circular(6),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (isDownloading)
                                        const SizedBox(
                                          width: 12,
                                          height: 12,
                                          child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.primary),
                                        )
                                      else
                                        const Icon(Icons.picture_as_pdf_rounded, size: 13, color: AppColors.primary),
                                      const SizedBox(width: 4),
                                      Text(
                                        isDownloading ? 'Downloading...' : 'Invoice',
                                        style: const TextStyle(
                                          color: AppColors.primary,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: order.status.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: order.status.color.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    order.status.label,
                    style: TextStyle(color: order.status.color, fontWeight: FontWeight.w800, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Live Step Timeline for Active Orders
                if (isActive) ...[
                  _buildLiveTimeline(order.status),
                  const SizedBox(height: 16),
                ],

                // 2. High-Contrast Delivery OTP Box (for active deliveries)
                if (isActive) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1E40AF), Color(0xFF2563EB)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(color: Colors.blue.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3)),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.pin, color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('DELIVERY OTP', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
                              Text('Share with driver upon arrival', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            order.deliveryOtp,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 3,
                              color: Color(0xFF1E40AF),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // 3. Ordered Items List
                const Text('Items Ordered', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                const SizedBox(height: 6),
                ...order.items.map((item) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceVariant,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${item.quantity}x',
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: AppColors.primary),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  item.nameSnapshot,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '₹${(item.priceSnapshot * item.quantity).toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                  );
                }),

                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 6),

                // 4. Payment Status Badge & Grand Total
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: (order.paymentStatus == 'COMPLETED' || order.paymentStatus == 'PAID')
                            ? const Color(0xFFDCFCE7)
                            : const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: (order.paymentStatus == 'COMPLETED' || order.paymentStatus == 'PAID')
                              ? const Color(0xFF86EFAC)
                              : const Color(0xFFFDE68A),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            (order.paymentStatus == 'COMPLETED' || order.paymentStatus == 'PAID')
                                ? Icons.check_circle_rounded
                                : Icons.schedule_rounded,
                            size: 12,
                            color: (order.paymentStatus == 'COMPLETED' || order.paymentStatus == 'PAID')
                                ? const Color(0xFF15803D)
                                : const Color(0xFFB45309),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            (order.paymentStatus == 'COMPLETED' || order.paymentStatus == 'PAID')
                                ? 'PAID (${order.paymentMethod})'
                                : (order.paymentMethod == 'COD' ? 'PAY ON DELIVERY' : 'PAYMENT PENDING'),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: (order.paymentStatus == 'COMPLETED' || order.paymentStatus == 'PAID')
                                  ? const Color(0xFF15803D)
                                  : const Color(0xFFB45309),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'Total: ₹${order.grandTotal.toStringAsFixed(0)}',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.primary),
                    ),
                  ],
                ),

                // 5. Rejection Reason Banner (if rejected)
                if (order.status == OrderStatus.rejected) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.cancel_rounded, size: 16, color: Color(0xFFDC2626)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            order.rejectionReason != null && order.rejectionReason!.isNotEmpty
                                ? 'Store Note: ${order.rejectionReason}'
                                : 'Order was rejected by the store. Any online payment will be refunded.',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF991B1B)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // 5.2 Payment Pending Notice & Retry CTA (15-min auto-cancel window per backend spec)
                if (order.status == OrderStatus.paymentPending) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.timer_outlined, size: 18, color: Color(0xFFB45309)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Stock reserved for 15 minutes. Complete payment before auto-cancellation.',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF92400E)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF59E0B),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.payment_rounded, size: 18),
                      label: const Text(
                        'Complete Payment Now ⚡',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () {
                        context.read<CustomerBloc>().add(
                          InitiateRazorpayPaymentEvent(order.id),
                        );
                      },
                    ),
                  ),
                ],

                // 5.3 Assigned Delivery Partner Badge (if assigned and active)
                if (isActive && (order.deliveryPartner != null || (order.deliveryPartnerName != null && order.deliveryPartnerName!.isNotEmpty))) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.two_wheeler_rounded, size: 16, color: Color(0xFF059669)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Rider: ${order.deliveryPartner?.name ?? order.deliveryPartnerName!}${order.deliveryPartner != null && order.deliveryPartner!.vehicleNumber.isNotEmpty ? ' (${order.deliveryPartner!.vehicleNumber})' : ''}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF065F46)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (order.deliveryPartner != null && order.deliveryPartner!.rating > 0) ...[
                          const Icon(Icons.star_rounded, size: 13, color: Color(0xFFEAB308)),
                          const SizedBox(width: 2),
                          Text(
                            order.deliveryPartner!.rating.toStringAsFixed(1),
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF854D0E)),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],

                // 5.5 Live Tracking Navigation (for active orders)
                if (isActive) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.navigation_rounded, size: 18),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Track Live Delivery (Map & Rider)',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CustomerLiveTrackingScreen(order: order),
                          ),
                        );
                      },
                    ),
                  ),
                ],

                // 6. Action Buttons: Cancel (if placed, paymentPending, or accepted)
                if (order.status == OrderStatus.placed ||
                    order.status == OrderStatus.paymentPending ||
                    order.status == OrderStatus.accepted) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Expanded(
                        child: Row(
                          children: [
                            Icon(Icons.info_outline_rounded, size: 14, color: AppColors.textMuted),
                            SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Cancel allowed before prep starts',
                                style: TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w500),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          side: const BorderSide(color: Colors.redAccent, width: 1.2),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          minimumSize: Size.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.cancel_outlined, size: 14),
                        label: const Text('Cancel Order', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        onPressed: () => _showCancelOrderDialog(context, order.id),
                      ),
                    ],
                  ),
                ],

                // 7. Action Buttons: Rate & Review & Order Again ⚡
                if (order.status == OrderStatus.delivered) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  BlocBuilder<CustomerBloc, CustomerState>(
                    buildWhen: (prev, curr) => prev.reviewedOrderIds != curr.reviewedOrderIds,
                    builder: (context, state) {
                      final isReviewed = state.reviewedOrderIds.contains(order.id);
                      return Row(
                        children: [
                          Expanded(
                            child: isReviewed
                                ? Container(
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                                    ),
                                    alignment: Alignment.center,
                                    child: const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.check_circle_rounded, size: 15, color: Color(0xFF059669)),
                                        SizedBox(width: 4),
                                        Text(
                                          'Reviewed',
                                          style: TextStyle(
                                            color: Color(0xFF059669),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : OutlinedButton.icon(
                                    onPressed: () => OrderRatingFeedbackSheet.show(context, order: order),
                                    icon: const Icon(Icons.star_rounded, size: 17, color: Color(0xFFF59E0B)),
                                    label: const Text(
                                      'Rate Order',
                                      style: TextStyle(
                                        color: Color(0xFF0F766E),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: Color(0xFF0F766E), width: 1.2),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      padding: const EdgeInsets.symmetric(vertical: 9),
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: _OrderAgainButton(order: order, compact: true)),
                        ],
                      );
                    },
                  ),
                ] else if (order.status == OrderStatus.cancelled) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  _OrderAgainButton(order: order),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCancelOrderDialog(BuildContext context, String orderId) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.cancel_outlined, color: Colors.redAccent, size: 22),
            SizedBox(width: 8),
            Text('Cancel Order', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to cancel this order? Orders can only be cancelled before the store starts preparing.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'Reason for cancellation (optional)',
                hintStyle: const TextStyle(fontSize: 12),
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Keep Order'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<CustomerBloc>().add(CancelOrderEvent(
                    orderId: orderId,
                    reason: controller.text.trim().isNotEmpty ? controller.text.trim() : 'Cancelled by customer',
                  ));
            },
            child: const Text('Confirm Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveTimeline(OrderStatus current) {
    final steps = [
      {'title': 'Placed', 'status': OrderStatus.placed},
      {'title': 'Preparing', 'status': OrderStatus.preparing},
      {'title': 'On the Way', 'status': OrderStatus.outForDelivery},
      {'title': 'Delivered', 'status': OrderStatus.delivered},
    ];

    int currentStepIndex = 0;
    if (current == OrderStatus.accepted || current == OrderStatus.preparing || current == OrderStatus.readyForPickup) {
      currentStepIndex = 1;
    } else if (current == OrderStatus.assigned || current == OrderStatus.pickedUp || current == OrderStatus.outForDelivery) {
      currentStepIndex = 2;
    } else if (current == OrderStatus.delivered) {
      currentStepIndex = 3;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(steps.length, (index) {
          final isDone = index <= currentStepIndex;
          final isCurrent = index == currentStepIndex;

          return Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    if (index > 0)
                      Expanded(
                        child: Container(
                          height: 2.5,
                          color: index <= currentStepIndex ? AppColors.primary : Colors.grey.shade300,
                        ),
                      ),
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDone ? AppColors.primary : Colors.grey.shade300,
                        border: isCurrent ? Border.all(color: AppColors.primaryLight, width: 3) : null,
                      ),
                      child: Center(
                        child: isDone
                            ? const Icon(Icons.check, size: 12, color: Colors.white)
                            : Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                      ),
                    ),
                    if (index < steps.length - 1)
                      Expanded(
                        child: Container(
                          height: 2.5,
                          color: index < currentStepIndex ? AppColors.primary : Colors.grey.shade300,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  steps[index]['title'] as String,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isCurrent ? FontWeight.w900 : FontWeight.w500,
                    color: isDone ? AppColors.textPrimary : AppColors.textMuted,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

// ----------------------------------------------------
// ADVANCED PROFILE VIEW (Ultra-Modern Aesthetic)
// ----------------------------------------------------
class _CustomerProfileView extends StatelessWidget {
  const _CustomerProfileView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        String name = 'Customer';
        String phone = '';
        if (authState is AuthenticatedState) {
          name = authState.user.name.isNotEmpty ? authState.user.name : 'Customer';
          phone = authState.user.phone;
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final isSmallScreen = constraints.maxWidth < 360;
            final horizontalPadding = constraints.maxWidth > 680
                ? 24.0
                : (isSmallScreen ? 12.0 : 16.0);

            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: ListView(
                  padding: EdgeInsets.fromLTRB(horizontalPadding, 12, horizontalPadding, 40),
                  children: [
                    // 1. Premium User Card
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0F766E), Color(0xFF115E59)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(color: const Color(0xFF0F766E).withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 6)),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: const Color(0xFF5EEAD4), width: 2),
                                ),
                                child: CircleAvatar(
                                  radius: 28,
                                  backgroundColor: const Color(0xFF134E4A),
                                  child: Text(
                                    name.isNotEmpty ? name[0].toUpperCase() : 'C',
                                    style: const TextStyle(color: Color(0xFF5EEAD4), fontSize: 24, fontWeight: FontWeight.w900),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            name,
                                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        const Icon(Icons.verified_rounded, color: Color(0xFF5EEAD4), size: 16),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.phone_android_rounded, size: 13, color: Color(0xFF5EEAD4)),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            phone.isNotEmpty ? phone : (authState is AuthenticatedState && authState.user.phone.isNotEmpty ? authState.user.phone : 'No phone linked'),
                                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.3),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (authState is AuthenticatedState && authState.user.email != null && authState.user.email!.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          const Icon(Icons.email_outlined, size: 12, color: Colors.white70),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              authState.user.email!,
                                              style: const TextStyle(color: Colors.white70, fontSize: 11),
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.amber,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'MEMBER',
                                      style: TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.8),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  if (authState is AuthenticatedState)
                                    InkWell(
                                      onTap: () => CustomerProfileEditSheet.show(context, authState.user),
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.white38, width: 0.8),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.edit_rounded, color: Colors.white, size: 12),
                                            SizedBox(width: 4),
                                            Text('Edit', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Divider(color: Colors.white24, height: 1),
                          const SizedBox(height: 12),

                          // Quick Metrics in Card
                          BlocBuilder<CustomerBloc, CustomerState>(
                            // FIX #5: Profile stats only change when orders or addresses change
                            buildWhen: (prev, curr) =>
                                prev.myOrders.length != curr.myOrders.length ||
                                prev.savedAddresses.length != curr.savedAddresses.length ||
                                prev.language != curr.language,
                            builder: (context, custState) {
                              final isKn = custState.language == AppLanguage.kannada;
                              return Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  _ProfileStatItem(title: isKn ? 'ಆರ್ಡರ್‌ಗಳು' : 'Orders', value: '${custState.myOrders.length}'),
                                  Container(width: 1, height: 24, color: Colors.white24),
                                  _ProfileStatItem(title: isKn ? 'ವಿಳಾಸಗಳು' : 'Addresses', value: '${custState.savedAddresses.length}'),
                                  Container(width: 1, height: 24, color: Colors.white24),
                                  _ProfileStatItem(title: isKn ? 'ಸ್ಥಿತಿ' : 'Status', value: isKn ? 'ಸಕ್ರಿಯ' : 'Active'),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),

                    // SECTION 1: Delivery & Orders
                    BlocBuilder<CustomerBloc, CustomerState>(
                      buildWhen: (prev, curr) => prev.language != curr.language,
                      builder: (context, custState) {
                        return Text(
                          custState.language == AppLanguage.kannada ? 'ವಿತರಣೆ ಮತ್ತು ಸೆಟ್ಟಿಂಗ್‌ಗಳು' : 'DELIVERY & SETTINGS',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 1.2),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    BlocBuilder<CustomerBloc, CustomerState>(
                      // FIX #5: Address tile only rebuilds when savedAddresses or language change
                      buildWhen: (prev, curr) =>
                          prev.savedAddresses.length != curr.savedAddresses.length ||
                          prev.notifications.length != curr.notifications.length ||
                          prev.language != curr.language,
                      builder: (context, custState) {
                        final strings = custState.strings;
                        final addrSubtitle = custState.savedAddresses.isNotEmpty
                            ? (custState.language == AppLanguage.kannada
                                ? '${custState.savedAddresses.length} ವಿಳಾಸಗಳು ಉಳಿಸಲಾಗಿದೆ'
                                : '${custState.savedAddresses.length} addresses saved')
                            : (custState.language == AppLanguage.kannada
                                ? 'ಯಾವುದೇ ವಿಳಾಸ ಉಳಿಸಿಲ್ಲ'
                                : 'No saved addresses yet');
                        return _AdvancedSettingCard(
                          children: [
                            _AdvancedTile(
                              icon: Icons.translate_rounded,
                              iconColor: const Color(0xFF6366F1),
                              title: strings.appLanguage,
                              subtitle: custState.language == AppLanguage.kannada ? 'ಕನ್ನಡ (Kannada)' : 'English',
                              badge: 'NEW',
                              badgeColor: const Color(0xFF6366F1),
                              onTap: () => CustomerLanguageSelectorSheet.show(context),
                            ),
                            const Divider(height: 1),
                            _AdvancedTile(
                              icon: Icons.location_on_outlined,
                              iconColor: AppColors.primary,
                              title: strings.savedAddresses,
                              subtitle: addrSubtitle,
                              onTap: () => CustomerAddressSheet.show(context),
                            ),
                            const Divider(height: 1),
                            _AdvancedTile(
                              icon: Icons.notifications_active_outlined,
                              iconColor: Colors.amber.shade800,
                              title: strings.notificationCenter,
                              subtitle: '${custState.notifications.length} updates recorded',
                              badge: custState.notifications.any((n) => n['read'] != true) ? 'NEW' : null,
                              badgeColor: AppColors.primary,
                              onTap: () => CustomerNotificationsSheet.show(context),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 18),

                    // SECTION 2: Support & Legal
                    BlocBuilder<CustomerBloc, CustomerState>(
                      buildWhen: (prev, curr) => prev.language != curr.language,
                      builder: (context, custState) {
                        final isKn = custState.language == AppLanguage.kannada;
                        final strings = custState.strings;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              strings.supportAndLegal,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 1.2),
                            ),
                            const SizedBox(height: 8),
                            _AdvancedSettingCard(
                              children: [
                                _AdvancedTile(
                                  icon: Icons.privacy_tip_outlined,
                                  iconColor: const Color(0xFF10B981),
                                  title: strings.privacyPolicy,
                                  subtitle: isKn ? 'ಡೇಟಾ ಸುರಕ್ಷತೆ, ಧಾರಣೆ ಮತ್ತು ಬಹಿರಂಗಪಡಿಸುವಿಕೆ' : 'Data safety, retention & disclosures',
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => const LegalPolicyScreen(initialTabIndex: 0),
                                      ),
                                    );
                                  },
                                ),
                                const Divider(height: 1),
                                _AdvancedTile(
                                  icon: Icons.description_outlined,
                                  iconColor: const Color(0xFF38BDF8),
                                  title: strings.termsOfService,
                                  subtitle: isKn ? 'ಬಳಕೆಯ ನಿಯಮಗಳು ಮತ್ತು ಆರ್ಡರ್ ನೀತಿಗಳು' : 'Usage conditions & order rules',
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => const LegalPolicyScreen(initialTabIndex: 1),
                                      ),
                                    );
                                  },
                                ),
                                const Divider(height: 1),
                                _AdvancedTile(
                                  icon: Icons.verified_user_outlined,
                                  iconColor: const Color(0xFFA855F7),
                                  title: strings.dataSafety,
                                  subtitle: isKn ? 'ಸ್ಥಳ ಮತ್ತು ಸಾಧನದ ಅನುಮತಿಗಳನ್ನು ಪರಿಶೀಲಿಸಿ' : 'Review location & device telemetry',
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => const LegalPolicyScreen(initialTabIndex: 2),
                                      ),
                                    );
                                  },
                                ),
                                const Divider(height: 1),
                                _AdvancedTile(
                                  icon: Icons.headset_mic_outlined,
                                  iconColor: Colors.teal,
                                  title: isKn ? '೨೪x೭ ಗ್ರಾಹಕ ಸಹಾಯ' : '24x7 Customer Support',
                                  subtitle: isKn ? 'ಸಹಾಯಕರೊಂದಿಗೆ ನೇರವಾಗಿ ಚಾಟ್ ಮಾಡಿ' : 'Chat directly with support agents',
                                  onTap: () {
                                    Navigator.of(context).push(
                                      SupportTicketsScreen.route(app: 'customer'),
                                    );
                                  },
                                ),
                                const Divider(height: 1),
                                _AdvancedTile(
                                  icon: Icons.verified_outlined,
                                  iconColor: const Color(0xFF0F766E),
                                  title: isKn ? 'ಕ್ವಿಕ್‌ಟಿಕ್ ಬಗ್ಗೆ' : 'About QuickTick',
                                  subtitle: isKn ? 'ಕರ್ನಾಟಕದ ಉತ್ಪನ್ನ, ಪ್ರಜ್ಞಾನ್ ಸಾಫ್ಟ್‌ವೇರ್ಸ್' : 'A product from Karnataka, from Prajnan Softwares',
                                  badge: 'v1.0.0',
                                  badgeColor: const Color(0xFF0F766E),
                                  onTap: () => AboutQuickTickSheet.show(context),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            // Logout Button
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.logout_rounded, color: Colors.red, size: 20),
                                label: Text(
                                  isKn ? 'ಖಾತೆಯಿಂದ ಲಾಗ್ ಔಟ್ ಮಾಡಿ' : 'Log Out of Account',
                                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                onPressed: () {
                                  _showLogoutDialog(context);
                                },
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.red, width: 1.5),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  backgroundColor: Colors.red.withValues(alpha: 0.04),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Google Play Mandatory Account Deletion Button
                            Center(
                              child: TextButton.icon(
                                icon: const Icon(Icons.delete_forever_outlined, color: Colors.redAccent, size: 18),
                                label: Text(
                                  isKn ? 'ಖಾತೆ ಮತ್ತು ಡೇಟಾವನ್ನು ಅಳಿಸಿ' : 'Delete Account & Data',
                                  style: const TextStyle(
                                    color: Colors.redAccent,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                                onPressed: () => DeleteAccountDialog.show(context, isDeliveryPartner: false),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    // Classic QuickTick Provenance & Heritage Footer
                    const QuickTickBrandFooter(compact: true),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Confirm Logout', style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text('Are you sure you want to log out of your session? All cached authentication data will be cleared securely.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                context.read<CustomerBloc>().add(const ClearCustomerSessionEvent());
                context.read<AuthBloc>().add(LogoutEvent());
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (context.mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  }
                });
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Log Out', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }
}

class _ProfileStatItem extends StatelessWidget {
  final String title;
  final String value;

  const _ProfileStatItem({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _AdvancedSettingCard extends StatelessWidget {
  final List<Widget> children;
  const _AdvancedSettingCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: children),
    );
  }
}

class _AdvancedTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String? badge;
  final Color? badgeColor;
  final VoidCallback onTap;

  const _AdvancedTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.badge,
    this.badgeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (badge != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: (badgeColor ?? Colors.green).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(badge!, style: TextStyle(color: badgeColor ?? Colors.green, fontSize: 9, fontWeight: FontWeight.w900)),
            ),
          ],
        ],
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textMuted),
      onTap: onTap,
    );
  }
}

class _AnimatedCategoryChip extends StatelessWidget {
  final CategoryEntity category;
  final bool isSelected;
  final VoidCallback onTap;

  const _AnimatedCategoryChip({
    required this.category,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : LinearGradient(
                  colors: [Colors.white, Colors.grey.shade50],
                ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.transparent : Colors.grey.shade200,
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF0D9488).withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                    spreadRadius: 1,
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: isSelected ? 1.15 : 1.0,
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutBack,
              child: _buildCategoryIcon(category, isSelected),
            ),
            const SizedBox(width: 8),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textPrimary,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                fontSize: 13,
                letterSpacing: -0.2,
              ),
              child: Text(category.name),
            ),
            if (category.dietaryBadge || category.foodType != null) ...[
              const SizedBox(width: 5),
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: (category.foodType?.toUpperCase() == 'NON_VEG')
                      ? const Color(0xFFEF4444)
                      : const Color(0xFF22C55E),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? Colors.white : Colors.transparent,
                    width: 1,
                  ),
                ),
              ),
            ],
            if (isSelected) ...[
              const SizedBox(width: 6),
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryIcon(CategoryEntity cat, bool isSelected) {
    if (cat.imageUrl.isNotEmpty &&
        cat.imageUrl.startsWith('http') &&
        !cat.imageUrl.toLowerCase().contains('placeholder')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.network(
          cat.imageUrl,
          width: 20,
          height: 20,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildFallbackIcon(cat.icon, isSelected),
        ),
      );
    }
    return _buildFallbackIcon(cat.icon, isSelected);
  }

  Widget _buildFallbackIcon(String iconStr, bool isSelected) {
    final isNamed = RegExp(r'^[a-zA-Z_]+$').hasMatch(iconStr.trim());
    if (isNamed) {
      final iconData = _getMaterialIcon(iconStr.trim());
      return Icon(
        iconData,
        size: 18,
        color: isSelected ? Colors.white : AppColors.primary,
      );
    }
    return Text(
      iconStr.isNotEmpty ? iconStr : '🛍️',
      style: const TextStyle(fontSize: 18),
    );
  }

  IconData _getMaterialIcon(String name) {
    switch (name.toLowerCase()) {
      case 'local_drink':
        return Icons.local_drink_outlined;
      case 'eco':
        return Icons.eco_outlined;
      case 'bakery_dining':
        return Icons.bakery_dining_outlined;
      case 'coffee':
        return Icons.coffee_outlined;
      case 'set_meal':
        return Icons.set_meal_outlined;
      case 'cleaning_services':
        return Icons.cleaning_services_outlined;
      case 'spa':
        return Icons.spa_outlined;
      case 'shopping_cart':
        return Icons.shopping_cart_outlined;
      default:
        return Icons.category_outlined;
    }
  }
}

class _HeroBannerCarousel extends StatefulWidget {
  const _HeroBannerCarousel();

  @override
  State<_HeroBannerCarousel> createState() => _HeroBannerCarouselState();
}

class _HeroBannerCarouselState extends State<_HeroBannerCarousel> with WidgetsBindingObserver {
  final PageController _pageController = PageController(viewportFraction: 0.92);
  int _currentPage = 0;
  Timer? _autoScrollTimer;
  Timer? _liveSyncTimer;
  int _lastBannerCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startLiveSyncTimer();
  }

  void _startLiveSyncTimer() {
    _liveSyncTimer?.cancel();
    // Keep foreground customers synced with admin banner edits/deletions even if a socket event is missed
    _liveSyncTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted) return;
      context.read<CustomerBloc>().add(const FetchHeroBannersEvent(forceRefresh: true));
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<CustomerBloc>().add(const FetchHeroBannersEvent(forceRefresh: true));
      _startLiveSyncTimer();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _liveSyncTimer?.cancel();
      _liveSyncTimer = null;
    }
  }

  void _syncAutoScroll(int count) {
    if (_currentPage >= count && count > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_currentPage >= count) {
          setState(() => _currentPage = 0);
        }
        if (_pageController.hasClients) {
          _pageController.jumpToPage(0);
        }
      });
    }
    if (count == _lastBannerCount) return;
    _lastBannerCount = count;
    _autoScrollTimer?.cancel();
    if (count <= 1) return;
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (_pageController.hasClients) {
        final nextPage = (_currentPage + 1) % count;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _liveSyncTimer?.cancel();
    _autoScrollTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Gradient _parseBgGradient(String? bgColor) {
    if (bgColor == null || bgColor.trim().isEmpty) {
      return const LinearGradient(
        colors: [Color(0xFF6366F1), Color(0xFFA855F7)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
    final hexMatches = RegExp(r'#([A-Fa-f0-9]{6})').allMatches(bgColor);
    if (hexMatches.length >= 2) {
      final colors = hexMatches.map((m) {
        final hex = m.group(1)!;
        return Color(int.parse('FF$hex', radix: 16));
      }).toList();
      return LinearGradient(
        colors: colors,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (hexMatches.length == 1) {
      final hex = hexMatches.first.group(1)!;
      final c = Color(int.parse('FF$hex', radix: 16));
      return LinearGradient(
        colors: [c, c.withValues(alpha: 0.85)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
    return const LinearGradient(
      colors: [Color(0xFF6366F1), Color(0xFFA855F7)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  void _showBannerDetailModal(BuildContext context, HeroBannerEntity banner) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final hasImage = banner.imageUrl != null && banner.imageUrl!.trim().isNotEmpty;
        final hasBadge = banner.badge != null && banner.badge!.trim().isNotEmpty;
        final hasSubtitle = banner.subtitle != null && banner.subtitle!.trim().isNotEmpty;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (hasImage) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: CachedNetworkImage(
                      imageUrl: banner.imageUrl!,
                      height: 140,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                if (hasBadge) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      banner.badge!.toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  banner.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
                if (hasSubtitle) ...[
                  const SizedBox(height: 6),
                  Text(
                    banner.subtitle!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                      height: 1.35,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      context.read<CustomerBloc>().add(const SearchProductsEvent(''));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      banner.ctaLabel ?? 'Explore Products',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleBannerTap(BuildContext context, HeroBannerEntity banner) async {
    final link = (banner.ctaLink ?? '').trim();
    if (link.isEmpty) {
      _showBannerDetailModal(context, banner);
      return;
    }

    try {
      if (link.startsWith('http://') || link.startsWith('https://')) {
        final uri = Uri.parse(link);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
        return;
      }

      if (link == '/search' || link == 'search' || link.startsWith('/search') || link.startsWith('search')) {
        String query = '';
        if (link.contains('q=')) {
          final uri = Uri.tryParse(link.startsWith('http') ? link : 'app://$link');
          query = uri?.queryParameters['q'] ?? '';
        } else if (link.contains(':') && !link.contains('://')) {
          query = link.split(':').last.trim();
        }
        context.read<CustomerBloc>().add(SearchProductsEvent(query));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(query.isNotEmpty ? 'Searching for "$query"' : 'Showing all products'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      if (link.startsWith('/category/') ||
          link.startsWith('category:') ||
          link.startsWith('/categories/') ||
          link.startsWith('category/')) {
        final rawCat = link
            .replaceFirst('/category/', '')
            .replaceFirst('category:', '')
            .replaceFirst('/categories/', '')
            .replaceFirst('category/', '')
            .trim();
        if (rawCat.isNotEmpty) {
          final categories = context.read<CustomerBloc>().state.categories;
          CategoryEntity? matched;
          for (final c in categories) {
            if (c.id.toLowerCase() == rawCat.toLowerCase() ||
                c.name.toLowerCase() == rawCat.toLowerCase() ||
                c.slug.toLowerCase() == rawCat.toLowerCase()) {
              matched = c;
              break;
            }
          }
          final effectiveId = matched?.id ?? rawCat;
          context.read<CustomerBloc>().add(FilterByCategoryEvent(effectiveId));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Category: ${matched?.name ?? rawCat}'),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      if (link.startsWith('/product/') || link.startsWith('product:') || link.startsWith('/products/')) {
        final prodId = link
            .replaceFirst('/product/', '')
            .replaceFirst('product:', '')
            .replaceFirst('/products/', '')
            .trim();
        if (prodId.isNotEmpty) {
          context.read<CustomerBloc>().add(SearchProductsEvent(prodId));
        }
        return;
      }

      if (link.startsWith('/retailer/') ||
          link.startsWith('/store/') ||
          link.startsWith('store:') ||
          link.startsWith('retailer:')) {
        final retId = link
            .replaceFirst('/retailer/', '')
            .replaceFirst('/store/', '')
            .replaceFirst('store:', '')
            .replaceFirst('retailer:', '')
            .trim();
        if (retId.isNotEmpty) {
          final stores = context.read<CustomerBloc>().state.stores;
          StoreEntity? matched;
          for (final s in stores) {
            if (s.id == retId || s.name.toLowerCase() == retId.toLowerCase()) {
              matched = s;
              break;
            }
          }
          if (matched != null) {
            context.read<CustomerBloc>().add(FilterByStoreEvent(matched));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Selected Store: ${matched.name}'),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
        return;
      }

      // Generic deep link fallback
      final uri = Uri.tryParse(link);
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (!context.mounted) return;
        context.read<CustomerBloc>().add(SearchProductsEvent(link));
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CustomerBloc, CustomerState>(
      buildWhen: (prev, curr) =>
          prev.heroBanners != curr.heroBanners ||
          prev.heroBannersFetchedAt != curr.heroBannersFetchedAt,
      builder: (context, state) {
        // Strictly filter active banners per spec & admin configuration
        final banners = state.heroBanners.where((b) => b.isActive).toList();

        // Per spec Section 5: If data is an empty array, hide the carousel entirely; do not render an empty container
        if (banners.isEmpty) {
          _lastBannerCount = 0;
          _currentPage = 0;
          _autoScrollTimer?.cancel();
          return const SizedBox.shrink();
        }

        _syncAutoScroll(banners.length);

        final screenWidth = MediaQuery.of(context).size.width;
        final double bannerHeight = screenWidth > 600 ? 175.0 : (screenWidth * 0.44).clamp(150.0, 172.0);

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              SizedBox(
                height: bannerHeight,
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() => _currentPage = index);
                  },
                  itemCount: banners.length,
                  itemBuilder: (context, index) {
                    final banner = banners[index];
                    final hasImage = banner.imageUrl != null && banner.imageUrl!.trim().isNotEmpty;
                    final hasBadge = banner.badge != null && banner.badge!.trim().isNotEmpty;
                    final hasSubtitle = banner.subtitle != null && banner.subtitle!.trim().isNotEmpty;
                    final hasCta = banner.ctaLabel != null && banner.ctaLabel!.trim().isNotEmpty;
                    final updatedMillis = banner.updatedAt?.millisecondsSinceEpoch ?? 0;
                    final bannerVersion =
                        '${banner.id}_${updatedMillis}_${banner.title.hashCode}_${banner.imageUrl.hashCode}_${banner.ctaLink.hashCode}';

                    return AnimatedScale(
                      key: ValueKey(bannerVersion),
                      scale: _currentPage == index ? 1.0 : 0.96,
                      duration: const Duration(milliseconds: 300),
                      child: GestureDetector(
                        onTap: () => _handleBannerTap(context, banner),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: hasImage ? null : _parseBgGradient(banner.bgColor),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 14,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              // 1. Background image (priority over bgColor per spec)
                              if (hasImage)
                                CachedNetworkImage(
                                  imageUrl: banner.imageUrl!,
                                  cacheKey: '${banner.id}_${updatedMillis}_${banner.imageUrl.hashCode}',
                                  fit: BoxFit.cover,
                                  memCacheWidth: 800,
                                  placeholder: (context, url) => Container(
                                    decoration: BoxDecoration(
                                      gradient: _parseBgGradient(banner.bgColor),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) => Container(
                                    decoration: BoxDecoration(
                                      gradient: _parseBgGradient(banner.bgColor),
                                    ),
                                  ),
                                ),

                              // 2. Dark overlay for text legibility per spec:
                              // linear-gradient(180deg, transparent 0%, rgba(0,0,0,0.6) 100%)
                              if (hasImage)
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        Colors.black.withValues(alpha: 0.65),
                                      ],
                                    ),
                                  ),
                                ),

                              // 3. Banner text and interactive CTA
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // Badge pill above title
                                    if (hasBadge) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.25),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: Colors.white.withValues(alpha: 0.35),
                                            width: 0.8,
                                          ),
                                        ),
                                        child: Text(
                                          banner.badge!,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 9.5,
                                            letterSpacing: 0.4,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                    ],

                                    // Title + titleAccent on same line (#fbbf24 accent)
                                    RichText(
                                      text: TextSpan(
                                        text: banner.title,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 16,
                                          height: 1.15,
                                        ),
                                        children: [
                                          if (banner.titleAccent != null && banner.titleAccent!.trim().isNotEmpty)
                                            TextSpan(
                                              text: ' ${banner.titleAccent!}',
                                              style: const TextStyle(
                                                color: Color(0xFFFBBF24), // #fbbf24 amber accent per spec
                                                fontWeight: FontWeight.w900,
                                                fontSize: 16,
                                                height: 1.15,
                                              ),
                                            ),
                                        ],
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),

                                    // Subtitle below title
                                    if (hasSubtitle) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        banner.subtitle!,
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 11,
                                          height: 1.2,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],

                                    // White pill CTA button
                                    if (hasCta) ...[
                                      const SizedBox(height: 10),
                                      InkWell(
                                        onTap: () => _handleBannerTap(context, banner),
                                        borderRadius: BorderRadius.circular(20),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(20),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: 0.2),
                                                blurRadius: 6,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Text(
                                            banner.ctaLabel!,
                                            style: const TextStyle(
                                              color: Color(0xFF0F172A),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              if (banners.length > 1) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(banners.length, (index) {
                    final isSelected = _currentPage == index;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: isSelected ? 20 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Responsive, animated Order Again button with tactile micro-interactions and adaptive layout.
class _OrderAgainButton extends StatefulWidget {
  final OrderEntity order;
  final bool compact;

  const _OrderAgainButton({
    required this.order,
    this.compact = false,
  });

  @override
  State<_OrderAgainButton> createState() => _OrderAgainButtonState();
}

class _OrderAgainButtonState extends State<_OrderAgainButton> {
  bool _isSuccess = false;
  bool _isPressed = false;
  Timer? _resetTimer;

  @override
  void dispose() {
    _resetTimer?.cancel();
    super.dispose();
  }

  void _handleTap() {
    if (_isSuccess) {
      HapticFeedback.lightImpact();
      _showCartModal(context);
      return;
    }

    HapticFeedback.mediumImpact();
    context.read<CustomerBloc>().add(ReorderEvent(widget.order));

    setState(() {
      _isSuccess = true;
    });

    _resetTimer?.cancel();
    _resetTimer = Timer(const Duration(milliseconds: 3200), () {
      if (mounted) {
        setState(() {
          _isSuccess = false;
        });
      }
    });

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF0F766E),
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Color(0xFF5EEAD4), size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${widget.order.items.length} ${widget.order.items.length == 1 ? "item" : "items"} added to your cart!',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'VIEW CART',
          textColor: const Color(0xFF5EEAD4),
          onPressed: () => _showCartModal(context),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final itemCount = widget.order.items.length;
    final itemLabel = itemCount == 1 ? 'item' : 'items';

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: _handleTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeInOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          width: double.infinity,
          constraints: BoxConstraints(minHeight: widget.compact ? 40 : 46),
          padding: EdgeInsets.symmetric(
            horizontal: widget.compact ? 10 : 14,
            vertical: widget.compact ? 8 : 10,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _isSuccess
                  ? const [Color(0xFF059669), Color(0xFF10B981)]
                  : const [Color(0xFF0F766E), Color(0xFF14B8A6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: (_isSuccess ? const Color(0xFF10B981) : const Color(0xFF0F766E))
                    .withValues(alpha: _isPressed ? 0.15 : 0.28),
                blurRadius: _isPressed ? 4 : 10,
                offset: Offset(0, _isPressed ? 2 : 4),
              ),
            ],
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: ScaleTransition(scale: anim, child: child),
            ),
            child: _isSuccess
                ? Row(
                    key: const ValueKey('success'),
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            widget.compact ? 'Added • View' : 'Added $itemCount $itemLabel • View Cart',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward_rounded, color: Colors.white70, size: 14),
                    ],
                  )
                : Row(
                    key: const ValueKey('idle'),
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.replay_rounded, color: Colors.white, size: widget.compact ? 16 : 18),
                      const SizedBox(width: 6),
                      const Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Order Again ⚡',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ),
                      if (!widget.compact) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$itemCount $itemLabel',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}




