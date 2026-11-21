import 'package:flutter_test/flutter_test.dart';
import 'package:quicklink/core/services/in_app_messaging_service.dart';
import 'package:quicklink/features/auth/domain/entities/user_entity.dart';

class FakeInAppMessagingService implements IInAppMessagingService {
  final List<String> triggeredEvents = [];
  bool _isSuppressed = false;
  UserRole? initializedRole;
  String? initializedUserId;

  @override
  bool get isSuppressed => _isSuppressed;

  @override
  Future<void> initialize({required UserRole role, String? userId}) async {
    initializedRole = role;
    initializedUserId = userId;
    _isSuppressed = false;
    final roleEvent = _getRoleAppOpenEvent(role);
    await triggerEvent(roleEvent);
  }

  @override
  Future<void> triggerEvent(String eventName) async {
    if (_isSuppressed) return;
    triggeredEvents.add(eventName);
  }

  @override
  Future<void> setMessagesSuppressed(bool suppressed) async {
    _isSuppressed = suppressed;
  }

  String _getRoleAppOpenEvent(UserRole role) {
    switch (role) {
      case UserRole.customer:
        return IInAppMessagingService.customerAppOpened;
      case UserRole.retailer:
        return IInAppMessagingService.retailerAppOpened;
      case UserRole.deliveryPartner:
        return IInAppMessagingService.deliveryAppOpened;
      case UserRole.admin:
        return 'admin_app_opened';
    }
  }
}

void main() {
  group('IInAppMessagingService - Clean Architecture & Role Tests', () {
    late FakeInAppMessagingService fakeService;

    setUp(() {
      fakeService = FakeInAppMessagingService();
    });

    test('Customer role initialization triggers customer_app_opened and unsuppresses messages', () async {
      await fakeService.initialize(role: UserRole.customer, userId: 'cust_123');

      expect(fakeService.initializedRole, UserRole.customer);
      expect(fakeService.initializedUserId, 'cust_123');
      expect(fakeService.isSuppressed, false);
      expect(fakeService.triggeredEvents, contains(IInAppMessagingService.customerAppOpened));
    });

    test('Retailer role initialization triggers retailer_app_opened', () async {
      await fakeService.initialize(role: UserRole.retailer, userId: 'ret_456');

      expect(fakeService.initializedRole, UserRole.retailer);
      expect(fakeService.triggeredEvents, contains(IInAppMessagingService.retailerAppOpened));
    });

    test('Delivery role initialization triggers delivery_app_opened', () async {
      await fakeService.initialize(role: UserRole.deliveryPartner, userId: 'del_789');

      expect(fakeService.initializedRole, UserRole.deliveryPartner);
      expect(fakeService.triggeredEvents, contains(IInAppMessagingService.deliveryAppOpened));
    });

    test('Event triggering registers events when not suppressed', () async {
      await fakeService.triggerEvent(IInAppMessagingService.customerCartViewed);
      await fakeService.triggerEvent(IInAppMessagingService.customerOrderPlaced);

      expect(fakeService.triggeredEvents, [
        IInAppMessagingService.customerCartViewed,
        IInAppMessagingService.customerOrderPlaced,
      ]);
    });

    test('Sensitive flow suppression blocks popup events', () async {
      await fakeService.setMessagesSuppressed(true);
      expect(fakeService.isSuppressed, true);

      // Attempt to trigger event while payment/scanning modal is active
      await fakeService.triggerEvent(IInAppMessagingService.customerOrderPlaced);
      expect(fakeService.triggeredEvents, isEmpty);

      // Unsuppress when checkout/payment finishes
      await fakeService.setMessagesSuppressed(false);
      expect(fakeService.isSuppressed, false);

      await fakeService.triggerEvent(IInAppMessagingService.customerOrderPlaced);
      expect(fakeService.triggeredEvents, [IInAppMessagingService.customerOrderPlaced]);
    });

    test('All defined event constants match Clean Architecture naming conventions', () {
      expect(IInAppMessagingService.customerAppOpened, 'customer_app_opened');
      expect(IInAppMessagingService.customerCartViewed, 'customer_cart_viewed');
      expect(IInAppMessagingService.customerOrderPlaced, 'customer_order_placed');
      expect(IInAppMessagingService.customerRecipeUsed, 'customer_recipe_used');
      expect(IInAppMessagingService.customerCategoryBrowsed, 'customer_category_browsed');

      expect(IInAppMessagingService.retailerAppOpened, 'retailer_app_opened');
      expect(IInAppMessagingService.retailerOrderAccepted, 'retailer_order_accepted');
      expect(IInAppMessagingService.retailerOrderReady, 'retailer_order_ready');
      expect(IInAppMessagingService.retailerStockToggled, 'retailer_stock_toggled');
      expect(IInAppMessagingService.retailerSettlementViewed, 'retailer_settlement_viewed');

      expect(IInAppMessagingService.deliveryAppOpened, 'delivery_app_opened');
      expect(IInAppMessagingService.deliveryDutyOn, 'delivery_duty_on');
      expect(IInAppMessagingService.deliveryDutyOff, 'delivery_duty_off');
      expect(IInAppMessagingService.deliveryOrderAccepted, 'delivery_order_accepted');
      expect(IInAppMessagingService.deliveryOrderPickedUp, 'delivery_order_picked_up');
      expect(IInAppMessagingService.deliveryOrderDelivered, 'delivery_order_delivered');
      expect(IInAppMessagingService.deliveryEarningsViewed, 'delivery_earnings_viewed');
    });
  });
}

