import 'dart:async';
import 'package:flutter/material.dart';
import '../di/service_locator.dart';
import '../services/network_connectivity_service.dart';

/// Swiggy/Zepto-style animated floating connectivity banner.
/// Slides down from the top when offline with amber/charcoal theme.
/// Transitions to emerald green upon reconnection, displays for 2.5s, then smoothly slides up and disappears.
class ConnectivityBanner extends StatefulWidget {
  final Widget child;

  const ConnectivityBanner({
    super.key,
    required this.child,
  });

  @override
  State<ConnectivityBanner> createState() => _ConnectivityBannerState();
}

class _ConnectivityBannerState extends State<ConnectivityBanner> with SingleTickerProviderStateMixin {
  INetworkConnectivityService? _connectivityService;
  StreamSubscription<bool>? _subscription;

  bool _isOnline = true;
  bool _showBackOnline = false;
  bool _hasEverBeenOffline = false;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _setupConnectivity();
  }

  void _setupConnectivity() {
    if (_subscription != null) return;
    if (sl.isRegistered<INetworkConnectivityService>()) {
      _connectivityService = sl<INetworkConnectivityService>();
      _isOnline = _connectivityService!.isConnected;
      _hasEverBeenOffline = !_isOnline;

      _subscription = _connectivityService!.onConnectivityChanged.listen((online) {
        if (!mounted) return;
        if (online) {
          if (!_isOnline) {
            setState(() {
              _isOnline = true;
              if (_hasEverBeenOffline) {
                _showBackOnline = true;
              }
            });
            _hideTimer?.cancel();
            _hideTimer = Timer(const Duration(milliseconds: 2500), () {
              if (mounted) {
                setState(() {
                  _showBackOnline = false;
                });
              }
            });
          }
        } else {
          _hasEverBeenOffline = true;
          _hideTimer?.cancel();
          setState(() {
            _isOnline = false;
            _showBackOnline = false;
          });
        }
      });
    }
  }

  @override
  void didUpdateWidget(ConnectivityBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_subscription == null) {
      _setupConnectivity();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _hideTimer?.cancel();
    super.dispose();
  }

  void _dismissBackOnline() {
    if (_showBackOnline) {
      _hideTimer?.cancel();
      setState(() {
        _showBackOnline = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final showBanner = !_isOnline || _showBackOnline;

    return Stack(
      children: [
        widget.child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 380),
            curve: Curves.fastOutSlowIn,
            offset: showBanner ? Offset.zero : const Offset(0, -2.0),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeInOut,
              opacity: showBanner ? 1.0 : 0.0,
              child: IgnorePointer(
                ignoring: !showBanner,
                child: SafeArea(
                  bottom: false,
                  child: GestureDetector(
                    onTap: _dismissBackOnline,
                    onVerticalDragEnd: (details) {
                      if (details.primaryVelocity != null && details.primaryVelocity! < 0) {
                        _dismissBackOnline();
                      }
                    },
                    child: Material(
                      color: Colors.transparent,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 280),
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: _isOnline
                              ? const Color(0xFF0F766E) // Emerald Green - Online
                              : const Color(0xFF1E293B), // Dark Slate / Charcoal - Offline
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: _isOnline ? const Color(0xFF34D399) : const Color(0xFFF59E0B),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _isOnline
                                    ? 'Back online! Syncing fresh data...'
                                    : 'No Internet Connection • You are offline',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (!_isOnline) ...[
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () {
                                  _connectivityService?.checkConnection();
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Text(
                                    'RETRY',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ),
                            ] else ...[
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: _dismissBackOnline,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
