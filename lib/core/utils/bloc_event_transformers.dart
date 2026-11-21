import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Reusable, lightweight, zero-dependency BLoC Event Transformers
class BlocEventTransformers {
  /// Debounces incoming events by [duration].
  /// Ignores rapid sequential events and only forwards the last event after [duration] of inactivity.
  /// Ideal for: Search queries, live text input, typing filters.
  static EventTransformer<E> debounce<E>([Duration duration = const Duration(milliseconds: 300)]) {
    return (events, mapper) {
      Timer? timer;
      final controller = StreamController<E>.broadcast();
      StreamSubscription? eventsSub;

      void onData(E event) {
        timer?.cancel();
        timer = Timer(duration, () {
          if (!controller.isClosed) {
            controller.add(event);
          }
        });
      }

      void listen() {
        eventsSub = events.listen(
          onData,
          onError: controller.addError,
          onDone: () {
            timer?.cancel();
            controller.close();
          },
        );
      }

      controller.onListen = listen;
      controller.onCancel = () {
        timer?.cancel();
        eventsSub?.cancel();
      };

      return controller.stream.asyncExpand(mapper);
    };
  }

  /// Drops any new event while the previous event is still executing.
  /// Prevents accidental double-clicks, duplicate orders, and multiple OTP submissions.
  /// Ideal for: PlaceOrderEvent, VerifyPaymentEvent, LoginEvent, SendOtpEvent.
  static EventTransformer<E> droppable<E>() {
    return (events, mapper) {
      final controller = StreamController<E>.broadcast();
      bool isProcessing = false;
      StreamSubscription? eventsSub;

      void onData(E event) {
        if (!isProcessing) {
          isProcessing = true;
          controller.add(event);
        }
      }

      void listen() {
        eventsSub = events.listen(
          onData,
          onError: controller.addError,
          onDone: controller.close,
        );
      }

      controller.onListen = listen;
      controller.onCancel = () => eventsSub?.cancel();

      return controller.stream.asyncExpand((event) async* {
        try {
          yield* mapper(event);
        } finally {
          isProcessing = false;
        }
      });
    };
  }

  /// Processes events strictly sequentially in FIFO order without interleaving.
  /// Ideal for: Cart quantity increments/decrements (+/-), queue items.
  static EventTransformer<E> sequential<E>() {
    return (events, mapper) {
      return events.asyncExpand(mapper);
    };
  }

  /// Cancels the currently running event execution as soon as a new event arrives.
  /// Ideal for: Category filters, tab switching, live data refresh.
  static EventTransformer<E> restartable<E>() {
    return (events, mapper) {
      final controller = StreamController<E>.broadcast();
      StreamSubscription? mapperSub;
      StreamSubscription? eventsSub;

      controller.onListen = () {
        eventsSub = events.listen((event) {
          mapperSub?.cancel();
          mapperSub = mapper(event).listen(
            (state) => controller.add(state as dynamic),
            onError: controller.addError,
          );
        });
      };

      controller.onCancel = () {
        eventsSub?.cancel();
        mapperSub?.cancel();
      };

      return controller.stream;
    };
  }
}
