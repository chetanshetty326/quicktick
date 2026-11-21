import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Audio and haptic alert buzzer service for the Retailer App.
/// Plays a continuous loud merchant buzzer sound (like Zomato/Swiggy merchant devices)
/// and vibrations whenever a new pending order arrives, ensuring shopkeepers never miss
/// orders even in loud or busy environments.
class OrderAlertService {
  OrderAlertService._() {
    _initPlayer();
  }

  static final OrderAlertService instance = OrderAlertService._();

  AudioPlayer? _audioPlayer;
  Timer? _hapticTimer;
  bool _isRinging = false;
  bool _isInitialized = false;

  bool get isRinging => _isRinging;

  Future<void> _initPlayer() async {
    if (_isInitialized) return;
    try {
      _audioPlayer = AudioPlayer();
      await _audioPlayer?.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer?.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            isSpeakerphoneOn: true,
            stayAwake: true,
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.alarm,
            audioFocus: AndroidAudioFocus.gainTransientExclusive,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: {
              AVAudioSessionOptions.duckOthers,
              AVAudioSessionOptions.defaultToSpeaker,
            },
          ),
        ),
      );
      await _audioPlayer?.setVolume(1.0);
      _isInitialized = true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ [ORDER ALERT INIT ERROR]: $e');
      }
    }
  }

  /// Starts repeating buzzer sound and vibration for incoming pending order.
  Future<void> startOrderChime() async {
    if (_isRinging) return;
    _isRinging = true;

    if (kDebugMode) {
      debugPrint('🚨 [ORDER ALERT] Starting loud merchant order buzzer...');
    }

    // Ensure player is ready
    if (!_isInitialized) {
      await _initPlayer();
    }

    try {
      // Play buzzer sound on loop
      await _audioPlayer?.stop();
      await _audioPlayer?.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer?.setVolume(1.0);
      await _audioPlayer?.play(AssetSource('sounds/order_buzzer.wav'));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ [ORDER ALERT AUDIO PLAY ERROR]: $e');
      }
      // Fallback to system chime if audio asset playback fails
      SystemSound.play(SystemSoundType.alert);
    }

    // Heavy pulsing vibration to accompany buzzer
    _triggerHapticPulse();
    _hapticTimer?.cancel();
    _hapticTimer = Timer.periodic(const Duration(milliseconds: 1000), (_) {
      _triggerHapticPulse();
    });
  }

  /// Stops the repeating buzzer sound and vibration immediately.
  Future<void> stopOrderChime() async {
    if (!_isRinging) return;
    _isRinging = false;

    _hapticTimer?.cancel();
    _hapticTimer = null;

    try {
      await _audioPlayer?.stop();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ [ORDER ALERT STOP ERROR]: $e');
      }
    }

    if (kDebugMode) {
      debugPrint('🔕 [ORDER ALERT] Stopped merchant order buzzer.');
    }
  }

  void _triggerHapticPulse() {
    try {
      HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  /// Clean up resources when app shuts down
  void dispose() {
    stopOrderChime();
    _audioPlayer?.dispose();
    _audioPlayer = null;
    _isInitialized = false;
  }
}
