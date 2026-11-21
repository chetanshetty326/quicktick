import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

abstract class INetworkConnectivityService {
  Stream<bool> get onConnectivityChanged;
  bool get isConnected;
  Future<bool> checkConnection();
  void dispose();
}

class NetworkConnectivityService implements INetworkConnectivityService {
  final StreamController<bool> _controller = StreamController<bool>.broadcast();
  bool _isConnected = true;
  Timer? _timer;

  NetworkConnectivityService() {
    _init();
  }

  void _init() {
    // Initial check
    checkConnection();
    // Periodic check every 2.5 seconds for instant network restoration detection
    _timer = Timer.periodic(const Duration(milliseconds: 2500), (_) {
      checkConnection();
    });
  }

  @override
  Stream<bool> get onConnectivityChanged => _controller.stream;

  @override
  bool get isConnected => _isConnected;

  @override
  Future<bool> checkConnection() async {
    try {
      final result = await InternetAddress.lookup('dns.google')
          .timeout(const Duration(milliseconds: 2000));
      final connected = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      _updateStatus(connected);
      return connected;
    } on SocketException catch (_) {
      _updateStatus(false);
      return false;
    } on TimeoutException catch (_) {
      _updateStatus(false);
      return false;
    } catch (_) {
      _updateStatus(false);
      return false;
    }
  }

  void _updateStatus(bool connected) {
    if (_isConnected != connected) {
      _isConnected = connected;
      if (!_controller.isClosed) {
        _controller.add(connected);
      }
      debugPrint('[NetworkConnectivity] Status changed: ${connected ? "ONLINE 🟢" : "OFFLINE 🔴"}');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.close();
  }
}
