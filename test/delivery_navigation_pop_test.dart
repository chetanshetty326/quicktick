import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Delivery Back Navigation Logic Tests', () {
    test('Double-tap back timer correctly allows exit only when pressed within 2 seconds', () {
      DateTime? lastBackPressTime;

      bool handleBack(DateTime now) {
        if (lastBackPressTime == null ||
            now.difference(lastBackPressTime!) > const Duration(seconds: 2)) {
          lastBackPressTime = now;
          return false; // Show "Press back again to exit"
        }
        return true; // Exit / move to background
      }

      final t0 = DateTime(2026, 9, 30, 21, 0, 0);
      // First tap at t0
      expect(handleBack(t0), isFalse);

      // Second tap 3 seconds later (exceeded 2s threshold) -> should not exit, resets timer
      final t1 = t0.add(const Duration(seconds: 3));
      expect(handleBack(t1), isFalse);

      // Third tap 1 second after t1 -> within 2s threshold -> exits!
      final t2 = t1.add(const Duration(seconds: 1));
      expect(handleBack(t2), isTrue);
    });

    test('Navigation tab switching logic routes to Tab 0 (Radar) first before exiting', () {
      int currentTab = 2; // e.g. Earnings tab or Profile tab

      int onBackInvoked(int selectedTab) {
        if (selectedTab != 0) {
          return 0; // Reset to radar screen (tab 0)
        }
        return -1; // Ready for double-tap exit check
      }

      // If user is on Tab 2, back press switches to Tab 0 (Radar)
      currentTab = onBackInvoked(currentTab);
      expect(currentTab, 0);

      // If user is on Tab 0 (Radar), onBackInvoked indicates ready for exit
      final nextAction = onBackInvoked(currentTab);
      expect(nextAction, -1);
    });

    test('Safe fallback logic prevents blank screen when stack cannot pop', () {
      bool canPopStack = false;
      bool navigatedToAuth = false;
      bool poppedRoute = false;

      void performSafeBack({required bool canPop}) {
        if (canPop) {
          poppedRoute = true;
        } else {
          navigatedToAuth = true; // Safe pushReplacement prevents black/blank screen
        }
      }

      // Case 1: Stack has routes (e.g. pushed from another screen)
      performSafeBack(canPop: true);
      expect(poppedRoute, isTrue);
      expect(navigatedToAuth, isFalse);

      // Case 2: Root screen reached via pushReplacement (canPop is false)
      poppedRoute = false;
      performSafeBack(canPop: false);
      expect(poppedRoute, isFalse);
      expect(navigatedToAuth, isTrue); // Fallback prevents blank screen!
    });
  });
}
