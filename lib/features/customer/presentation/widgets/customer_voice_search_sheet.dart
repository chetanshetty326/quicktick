import 'dart:async';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../../../core/theme/app_colors.dart';

class CustomerVoiceSearchSheet extends StatefulWidget {
  const CustomerVoiceSearchSheet({super.key});

  /// Opens the voice search sheet and returns the recognized query string, or null if cancelled.
  static Future<String?> show(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const CustomerVoiceSearchSheet(),
    );
  }

  @override
  State<CustomerVoiceSearchSheet> createState() => _CustomerVoiceSearchSheetState();
}

class _CustomerVoiceSearchSheetState extends State<CustomerVoiceSearchSheet>
    with SingleTickerProviderStateMixin {
  final stt.SpeechToText _speechToText = stt.SpeechToText();

  bool _isInitialized = false;
  bool _isListening = false;
  bool _hasError = false;
  String _errorMessage = '';
  String _recognizedWords = '';
  double _soundLevel = 0.0;
  Timer? _silenceTimer;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initAndStartListening();
    });
  }

  @override
  void dispose() {
    _silenceTimer?.cancel();
    _pulseController.dispose();
    _speechToText.stop();
    super.dispose();
  }

  Future<void> _initAndStartListening() async {
    setState(() {
      _hasError = false;
      _errorMessage = '';
      _recognizedWords = '';
    });

    try {
      if (!_isInitialized) {
        final available = await _speechToText.initialize(
          onStatus: _onSpeechStatus,
          onError: (val) {
            if (!mounted) return;
            setState(() {
              _hasError = true;
              _errorMessage = val.errorMsg.isNotEmpty
                  ? val.errorMsg
                  : 'Could not recognize speech. Please try again.';
              _isListening = false;
            });
          },
        );
        _isInitialized = available;
      }

      if (_isInitialized) {
        _startListening();
      } else {
        if (mounted) {
          setState(() {
            _hasError = true;
            _errorMessage = 'Microphone permission or speech recognition is not available.';
            _isListening = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Error initializing voice search: $e';
          _isListening = false;
        });
      }
    }
  }

  void _startListening() async {
    setState(() {
      _isListening = true;
      _hasError = false;
      _errorMessage = '';
    });

    try {
      await _speechToText.listen(
        onResult: (result) {
          if (!mounted) return;
          setState(() {
            _recognizedWords = result.recognizedWords;
          });

          // Reset silence timer on every recognized phrase
          _silenceTimer?.cancel();
          _silenceTimer = Timer(const Duration(milliseconds: 1600), () {
            if (mounted && _recognizedWords.trim().isNotEmpty) {
              _confirmAndReturn(_recognizedWords.trim());
            }
          });

          if (result.finalResult && _recognizedWords.trim().isNotEmpty) {
            _confirmAndReturn(_recognizedWords.trim());
          }
        },
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.search,
          cancelOnError: true,
          partialResults: true,
          autoPunctuation: true,
        ),
        onSoundLevelChange: (level) {
          if (!mounted) return;
          setState(() {
            _soundLevel = level;
          });
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Could not start listening: $e';
          _isListening = false;
        });
      }
    }
  }

  void _onSpeechStatus(String status) {
    if (!mounted) return;
    if (status == 'notListening' || status == 'done') {
      setState(() {
        _isListening = false;
      });
      // If words were recognized, return them
      if (_recognizedWords.trim().isNotEmpty) {
        _confirmAndReturn(_recognizedWords.trim());
      }
    } else if (status == 'listening') {
      setState(() {
        _isListening = true;
      });
    }
  }

  void _confirmAndReturn(String query) {
    _silenceTimer?.cancel();
    _speechToText.stop();
    if (mounted && Navigator.canPop(context)) {
      Navigator.pop(context, query);
    }
  }

  void _toggleListening() {
    if (_isListening) {
      _speechToText.stop();
      setState(() {
        _isListening = false;
      });
    } else {
      _initAndStartListening();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom +
        MediaQuery.of(context).padding.bottom +
        16;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottomPadding),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.mic_rounded, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Voice Search',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Pulsing / Sound-reactive Microphone Button
          GestureDetector(
            onTap: _toggleListening,
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                final scale = _isListening
                    ? (_pulseAnimation.value + (_soundLevel.clamp(-2, 10) / 30.0).clamp(0.0, 0.2))
                    : 1.0;

                return Transform.scale(
                  scale: scale,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Outer animated glow rings
                      if (_isListening) ...[
                        Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary.withValues(alpha: 0.12),
                          ),
                        ),
                        Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary.withValues(alpha: 0.22),
                          ),
                        ),
                      ],
                      // Main mic circle
                      Container(
                        width: 74,
                        height: 74,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: _isListening
                                ? [AppColors.primary, const Color(0xFF4338CA)]
                                : (_hasError
                                    ? [const Color(0xFFEF4444), const Color(0xFFDC2626)]
                                    : [const Color(0xFF64748B), const Color(0xFF475569)]),
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (_isListening ? AppColors.primary : Colors.black26)
                                  .withValues(alpha: 0.35),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Icon(
                          _isListening
                              ? Icons.mic_rounded
                              : (_hasError ? Icons.mic_off_rounded : Icons.mic_none_rounded),
                          color: Colors.white,
                          size: 34,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 20),

          // Recognized Text Display
          if (_recognizedWords.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: Text(
                '"$_recognizedWords"',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
          ] else if (_hasError) ...[
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFFEF4444),
              ),
            ),
          ] else ...[
            Text(
              _isListening ? 'Listening... Speak now' : 'Tap the microphone to speak',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: _isListening ? AppColors.primary : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Try saying: "Fresh Milk", "Eggs", "Atta", or store names',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF94A3B8),
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Action Buttons
          Row(
            children: [
              if (_hasError || (!_isListening && _recognizedWords.isEmpty)) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _initAndStartListening,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Try Again'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ] else if (_recognizedWords.isNotEmpty) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _recognizedWords = '';
                      });
                      _startListening();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF64748B),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Clear'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: () => _confirmAndReturn(_recognizedWords.trim()),
                    icon: const Icon(Icons.search_rounded, size: 18),
                    label: const Text('Search Now', style: TextStyle(fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 2,
                    ),
                  ),
                ),
              ] else ...[
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
