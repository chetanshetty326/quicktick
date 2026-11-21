import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/product_matcher.dart';
import '../../../customer/domain/entities/catalog_entities.dart';
import '../../../customer/domain/repositories/catalog_repository.dart';
import '../../../customer/presentation/bloc/customer_bloc.dart';
import '../../../order/domain/entities/order_entity.dart';
import '../../domain/entities/ai_message_entity.dart';
import '../bloc/ai_assistant_bloc.dart';
import '../bloc/ai_assistant_event.dart';
import '../bloc/ai_assistant_state.dart';

class AiConciergeSheet extends StatefulWidget {
  final VoidCallback? onSearchRequested;
  final Function(String query)? onSearchQuery;
  final VoidCallback? onTrackOrderRequested;
  final VoidCallback? onViewCouponsRequested;
  final Function(List<String> items)? onAddItemsRequested;
  final VoidCallback? onContactSupportRequested;

  const AiConciergeSheet({
    super.key,
    this.onSearchRequested,
    this.onSearchQuery,
    this.onTrackOrderRequested,
    this.onViewCouponsRequested,
    this.onAddItemsRequested,
    this.onContactSupportRequested,
  });

  static Future<void> show(
    BuildContext context, {
    VoidCallback? onSearchRequested,
    Function(String query)? onSearchQuery,
    VoidCallback? onTrackOrderRequested,
    VoidCallback? onViewCouponsRequested,
    Function(List<String> items)? onAddItemsRequested,
    VoidCallback? onContactSupportRequested,
  }) {
    final aiBloc = context.read<AiAssistantBloc>();
    CustomerBloc? customerBloc;
    try {
      customerBloc = context.read<CustomerBloc>();
    } catch (_) {}

    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        final sheet = AiConciergeSheet(
          onSearchRequested: onSearchRequested,
          onSearchQuery: onSearchQuery,
          onTrackOrderRequested: onTrackOrderRequested,
          onViewCouponsRequested: onViewCouponsRequested,
          onAddItemsRequested: onAddItemsRequested,
          onContactSupportRequested: onContactSupportRequested,
        );

        if (customerBloc != null) {
          return MultiBlocProvider(
            providers: [
              BlocProvider.value(value: aiBloc),
              BlocProvider.value(value: customerBloc),
            ],
            child: sheet,
          );
        }

        return BlocProvider.value(
          value: aiBloc,
          child: sheet,
        );
      },
    );
  }

  @override
  State<AiConciergeSheet> createState() => _AiConciergeSheetState();
}

class _AiConciergeSheetState extends State<AiConciergeSheet> with SingleTickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late AnimationController _pulseController;

  final List<Map<String, String>> _languages = [
    {'code': 'en', 'label': 'English'},
    {'code': 'kn', 'label': 'ಕನ್ನಡ'},
    {'code': 'hi', 'label': 'हिंदी'},
    {'code': 'ta', 'label': 'தமிழ்'},
    {'code': 'te', 'label': 'తెలుగు'},
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _getTitle(String langCode) {
    switch (langCode.toLowerCase()) {
      case 'kn':
      case 'kn_in':
        return 'ಕ್ವಿಕ್‌ಟಿಕ್ ಎಐ ಸಹಾಯಕ';
      case 'hi':
      case 'hi_in':
        return 'क्विकटिक एआई सहायक';
      case 'ta':
      case 'ta_in':
        return 'குயிக்டிக் ஏஐ உதவியாளர்';
      case 'te':
      case 'te_in':
        return 'క్విక్టిక్ ఏఐ సహాయకుడు';
      default:
        return 'QuickTick AI Assistant';
    }
  }

  String _getSubtitle(String langCode) {
    switch (langCode.toLowerCase()) {
      case 'kn':
      case 'kn_in':
        return 'ಧ್ವನಿ ಶಾಪಿಂಗ್ ಮತ್ತು ತ್ವರಿತ ಬೆಂಬಲ';
      case 'hi':
      case 'hi_in':
        return 'वॉयस शॉपिंग और त्वरित सपोर्ट';
      case 'ta':
      case 'ta_in':
        return 'குரல் ஷாப்பிங் மற்றும் உடனடி ஆதரவு';
      case 'te':
      case 'te_in':
        return 'వాయిస్ షాపింగ్ మరియు తక్షణ సపోర్ట్';
      default:
        return 'Voice shopping & instant smart support';
    }
  }

  String _getListeningText(String langCode) {
    switch (langCode.toLowerCase()) {
      case 'kn':
      case 'kn_in':
        return 'ಕೇಳುತ್ತಿದ್ದೇವೆ... ನಿಮ್ಮ ಭಾಷೆಯಲ್ಲಿ ಮಾತನಾಡಿ';
      case 'hi':
      case 'hi_in':
        return 'सुन रहे हैं... अपनी भाषा में बोलिए';
      case 'ta':
      case 'ta_in':
        return 'கேட்கிறது... உங்கள் மொழியில் பேசுங்கள்';
      case 'te':
      case 'te_in':
        return 'వింటున్నాము... మీ భాషలో మాట్లాడండి';
      default:
        return 'Listening... speak naturally in your language';
    }
  }

  String _getThinkingText(String langCode) {
    switch (langCode.toLowerCase()) {
      case 'kn':
      case 'kn_in':
        return 'ಕ್ವಿಕ್‌ಟಿಕ್ ಎಐ ಯೋಚಿಸುತ್ತಿದೆ...';
      case 'hi':
      case 'hi_in':
        return 'क्विकटिक एआई सोच रहा है...';
      case 'ta':
      case 'ta_in':
        return 'குயிக்டிக் ஏஐ யோசிக்கிறது...';
      case 'te':
      case 'te_in':
        return 'క్విక్టిక్ ఏఐ ఆలోచిస్తోంది...';
      default:
        return 'QuickTick AI is thinking...';
    }
  }

  String _getHintText(String langCode) {
    switch (langCode.toLowerCase()) {
      case 'kn':
      case 'kn_in':
        return 'ಕನ್ನಡ, ಹಿಂದಿ ಅಥವಾ ಇಂಗ್ಲಿಷ್‌ನಲ್ಲಿ ಕೇಳಿ...';
      case 'hi':
      case 'hi_in':
        return 'हिंदी, कन्नड़ या अंग्रेजी में पूछें...';
      case 'ta':
      case 'ta_in':
        return 'தமிழில் கேளுங்கள்...';
      case 'te':
      case 'te_in':
        return 'తెలుగులో అడగండి...';
      default:
        return 'Ask in Kannada, Hindi, or English...';
    }
  }

  void _handleIntent(AiActionIntent intent) {
    switch (intent.type) {
      case AiActionType.searchProduct:
        Navigator.of(context).pop();
        if (intent.query != null && widget.onSearchQuery != null) {
          widget.onSearchQuery!(intent.query!);
        } else if (widget.onSearchRequested != null) {
          widget.onSearchRequested!();
        }
        break;
      case AiActionType.trackOrder:
        Navigator.of(context).pop();
        widget.onTrackOrderRequested?.call();
        break;
      case AiActionType.viewCoupons:
        Navigator.of(context).pop();
        widget.onViewCouponsRequested?.call();
        break;
      case AiActionType.addItemsToCart:
      case AiActionType.recipeGuide:
        Navigator.of(context).pop();
        if (intent.itemNames.isNotEmpty && widget.onAddItemsRequested != null) {
          widget.onAddItemsRequested!(intent.itemNames);
        }
        break;
      case AiActionType.customerSupport:
        Navigator.of(context).pop();
        widget.onContactSupportRequested?.call();
        break;
      case AiActionType.checkStock:
      case AiActionType.paymentStatus:
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;

    return BlocConsumer<AiAssistantBloc, AiAssistantState>(
      listenWhen: (prev, curr) =>
          prev.messages.length != curr.messages.length ||
          prev.lastTriggeredIntent != curr.lastTriggeredIntent,
      listener: (context, state) {
        _scrollToBottom();
      },
      builder: (context, state) {
        return Container(
          height: screenHeight * 0.85,
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              // 1. Top Drag Handle & Premium Header
              _buildHeader(context, state),

              // 2. Language Selector Bar
              _buildLanguageSelector(context, state),

              const Divider(height: 1, thickness: 0.5),

              // 3. Conversation Message List
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: state.messages.length + (state.isLoading ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == state.messages.length && state.isLoading) {
                      return _buildLoadingBubble(state.selectedLanguageCode);
                    }
                    final msg = state.messages[index];
                    return _buildMessageItem(context, msg);
                  },
                ),
              ),

              // 4. Quick Suggestions Chips
              if (state.messages.isNotEmpty && state.messages.last.suggestions.isNotEmpty)
                _buildSuggestionsBar(context, state.messages.last.suggestions),

              // 5. Voice Waveform Indicator (if actively listening)
              if (state.isListening) _buildVoiceWaveform(state.selectedLanguageCode),

              // 6. Disclaimer Banner: Contact Support if response is incorrect
              _buildDisclaimerBanner(context, state.selectedLanguageCode),

              // 7. Modern Input Bottom Bar
              _buildInputBar(context, state),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, AiAssistantState state) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag pill
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Glowing Icon
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            _getTitle(state.selectedLanguageCode),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.amber.shade400, width: 0.6),
                          ),
                          child: Text(
                            'UNDER DEVELOPMENT',
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.amber.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _getSubtitle(state.selectedLanguageCode),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Speaker Toggle
              IconButton(
                icon: Icon(
                  state.speechOutputEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                  color: state.speechOutputEnabled ? AppColors.primary : Colors.grey,
                  size: 22,
                ),
                tooltip: state.speechOutputEnabled ? 'Mute AI Voice' : 'Unmute AI Voice',
                onPressed: () {
                  context.read<AiAssistantBloc>().add(const ToggleSpeechOutputEvent());
                },
              ),
              // Close Sheet Button
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 22),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageSelector(BuildContext context, AiAssistantState state) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _languages.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final lang = _languages[index];
          final isSelected = state.selectedLanguageCode == lang['code'];
          return ChoiceChip(
            label: Text(
              lang['label']!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : Colors.black87,
              ),
            ),
            selected: isSelected,
            selectedColor: AppColors.primary,
            backgroundColor: Colors.grey.shade100,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            labelPadding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            side: BorderSide.none,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onSelected: (selected) {
              if (selected) {
                context.read<AiAssistantBloc>().add(ChangeLanguageEvent(lang['code']!));
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildMessageItem(BuildContext context, AiMessageEntity msg) {
    final isUser = msg.sender == AiSender.user;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              margin: const EdgeInsets.only(top: 2, right: 8),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primaryLight.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 14),
            ),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? AppColors.primary : Colors.grey.shade100,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    msg.text,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.35,
                      color: isUser ? Colors.white : Colors.black87,
                    ),
                  ),
                  if (msg.actionIntent?.type == AiActionType.recipeGuide || msg.recipeDetails != null) ...[
                    const SizedBox(height: 10),
                    _AnimatedRecipeCard(
                      recipe: msg.recipeDetails ?? msg.actionIntent!.recipeDetails!,
                      itemNames: msg.actionIntent?.itemNames ?? [],
                      onAddItemsRequested: widget.onAddItemsRequested,
                    ),
                  ] else if (msg.actionIntent?.type == AiActionType.addItemsToCart) ...[
                    const SizedBox(height: 10),
                    _AiAddToCartCard(
                      key: ValueKey('add_cart_${msg.id}'),
                      messageId: msg.id,
                      itemNames: msg.actionIntent?.itemNames ?? const [],
                      onViewCartRequested: () {
                        Navigator.of(context).pop();
                        widget.onViewCouponsRequested?.call();
                      },
                      onSearchCatalogRequested: (query) {
                        Navigator.of(context).pop();
                        if (query.isNotEmpty && widget.onSearchQuery != null) {
                          widget.onSearchQuery!(query);
                        } else {
                          widget.onSearchRequested?.call();
                        }
                      },
                    ),
                  ] else if (msg.actionIntent?.type == AiActionType.checkStock) ...[
                    const SizedBox(height: 10),
                    _StockDetailsCard(
                      itemQuery: msg.actionIntent?.stockItemQuery ?? msg.actionIntent?.query ?? '',
                    ),
                  ] else if (msg.actionIntent?.type == AiActionType.paymentStatus) ...[
                    const SizedBox(height: 10),
                    _PaymentStatusCard(
                      onTrackOrderRequested: () {
                        Navigator.of(context).pop();
                        widget.onTrackOrderRequested?.call();
                      },
                    ),
                  ] else if (msg.actionIntent != null && msg.actionIntent!.type != AiActionType.none) ...[
                    const SizedBox(height: 8),
                    _buildActionButton(context, msg.actionIntent!),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, AiActionIntent intent) {
    String label = 'Open';
    IconData icon = Icons.arrow_forward_rounded;

    switch (intent.type) {
      case AiActionType.searchProduct:
        label = 'Search "${intent.query ?? "Products"}"';
        icon = Icons.search_rounded;
        break;
      case AiActionType.trackOrder:
        label = 'Track Live Order';
        icon = Icons.location_on_outlined;
        break;
      case AiActionType.viewCoupons:
        label = 'View Coupons';
        icon = Icons.local_offer_outlined;
        break;
      case AiActionType.addItemsToCart:
        label = 'Add to Cart (${intent.itemNames.length} items)';
        icon = Icons.add_shopping_cart_rounded;
        break;
      case AiActionType.recipeGuide:
        label = 'Add Recipe Ingredients (${intent.itemNames.length} items)';
        icon = Icons.soup_kitchen_rounded;
        break;
      case AiActionType.checkStock:
        label = 'View Stock & Inventory';
        icon = Icons.inventory_2_outlined;
        break;
      case AiActionType.paymentStatus:
        label = 'View Payment Status';
        icon = Icons.account_balance_wallet_outlined;
        break;
      case AiActionType.customerSupport:
        label = 'Contact Customer Support';
        icon = Icons.support_agent_rounded;
        break;
      default:
        break;
    }

    return InkWell(
      onTap: () => _handleIntent(intent),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionsBar(BuildContext context, List<String> suggestions) {
    return Container(
      height: 38,
      margin: const EdgeInsets.only(bottom: 6),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: suggestions.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final sug = suggestions[index];
          return ActionChip(
            label: Text(
              sug,
              style: TextStyle(fontSize: 11.5, color: Colors.grey.shade800),
            ),
            backgroundColor: Colors.white,
            side: BorderSide(color: Colors.grey.shade300, width: 0.8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            padding: const EdgeInsets.symmetric(horizontal: 6),
            onPressed: () {
              context.read<AiAssistantBloc>().add(SendTextMessageEvent(sug));
            },
          );
        },
      ),
    );
  }

  Widget _buildVoiceWaveform(String langCode) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Icon(
                Icons.mic_rounded,
                color: AppColors.primary.withValues(alpha: 0.6 + (_pulseController.value * 0.4)),
                size: 20,
              );
            },
          ),
          const SizedBox(width: 10),
          Text(
            _getListeningText(langCode),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingBubble(String langCode) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.grey.shade600),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _getThinkingText(langCode),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimerBanner(BuildContext context, String langCode) {
    String text = 'AI Assistant is under development. Responses may vary — contact Customer Support for help.';
    if (langCode.startsWith('kn')) {
      text = 'ಎಐ ಸಹಾಯಕ ಅಭಿವೃದ್ಧಿ ಹಂತದಲ್ಲಿದೆ. ಯಾವುದೇ ಮಾಹಿತಿ ತಪ್ಪಾಗಿದ್ದರೆ, ದಯವಿಟ್ಟು ಗ್ರಾಹಕ ಬೆಂಬಲವನ್ನು ಸಂಪರ್ಕಿಸಿ.';
    } else if (langCode.startsWith('hi')) {
      text = 'एआई सहायक अभी विकास के चरण में है। यदि कोई जानकारी गलत हो, तो कृपया कस्टमर सपोर्ट से संपर्क करें।';
    } else if (langCode.startsWith('ta')) {
      text = 'ஏஐ உதவியாளர் தற்போது மேம்பாட்டின் கீழ் உள்ளது. தகவல் தவறாக இருந்தால், வாடிக்கையாளர் ஆதரவைத் தொடர்பு கொள்ளவும்.';
    } else if (langCode.startsWith('te')) {
      text = 'ఏఐ సహాయకుడు ప్రస్తుతం అభివృద్ధి దశలో ఉంది. సమాచారం తప్పుగా ఉంటే, కస్టమర్ సపోర్ట్‌ను సంప్రదించండి.';
    }

    return InkWell(
      onTap: widget.onContactSupportRequested,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        color: Colors.amber.shade50.withValues(alpha: 0.75),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.construction_rounded, size: 13, color: Colors.amber.shade800),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.amber.shade900,
                  decoration: widget.onContactSupportRequested != null ? TextDecoration.underline : null,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar(BuildContext context, AiAssistantState state) {
    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, 12, MediaQuery.of(context).viewInsets.bottom + 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Voice Mic Button
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final isLit = state.isListening;
              return Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: isLit
                      ? [
                          BoxShadow(
                            color: Colors.red.withValues(alpha: 0.5 * _pulseController.value),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
                child: IconButton.filled(
                  icon: Icon(
                    isLit ? Icons.mic_rounded : Icons.mic_none_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: isLit ? Colors.red : AppColors.primary,
                  ),
                  tooltip: isLit ? 'Stop listening' : 'Speak to AI',
                  onPressed: () {
                    if (isLit) {
                      context.read<AiAssistantBloc>().add(const StopVoiceListeningEvent());
                    } else {
                      context.read<AiAssistantBloc>().add(const StartVoiceListeningEvent());
                    }
                  },
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          // Text Input Field
          Expanded(
            child: TextField(
              controller: _textController,
              textInputAction: TextInputAction.send,
              onSubmitted: (val) {
                if (val.trim().isNotEmpty) {
                  context.read<AiAssistantBloc>().add(SendTextMessageEvent(val));
                  _textController.clear();
                }
              },
              decoration: InputDecoration(
                hintText: _getHintText(state.selectedLanguageCode),
                hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Send Button
          IconButton(
            icon: const Icon(Icons.send_rounded, color: AppColors.primary, size: 22),
            onPressed: () {
              final text = _textController.text;
              if (text.trim().isNotEmpty) {
                context.read<AiAssistantBloc>().add(SendTextMessageEvent(text));
                _textController.clear();
              }
            },
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// ANIMATED RECIPE CARD WITH MASTER INGREDIENT & COOKING GUIDE
// ============================================================================
class _AnimatedRecipeCard extends StatefulWidget {
  final RecipeDetails recipe;
  final List<String> itemNames;
  final Function(List<String> items)? onAddItemsRequested;

  const _AnimatedRecipeCard({
    required this.recipe,
    required this.itemNames,
    this.onAddItemsRequested,
  });

  @override
  State<_AnimatedRecipeCard> createState() => _AnimatedRecipeCardState();
}

class _AnimatedRecipeCardState extends State<_AnimatedRecipeCard>
    with SingleTickerProviderStateMixin {
  int _selectedTab = 0; // 0: Ingredients, 1: Steps, 2: Chef Tip
  bool _isAdded = false;
  final Set<String> _singleAdded = {};
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _handleAddAllToCart(BuildContext context) {
    _animController.forward().then((_) => _animController.reverse());
    setState(() {
      _isAdded = true;
    });

    CustomerBloc? customerBloc;
    try {
      customerBloc = context.read<CustomerBloc>();
    } catch (_) {}

    final itemsToAdd = widget.itemNames.isNotEmpty
        ? widget.itemNames
        : widget.recipe.ingredients.map((e) => e.matchedQuery ?? e.name).toList();

    if (widget.onAddItemsRequested != null) {
      widget.onAddItemsRequested!.call(itemsToAdd);
      return;
    }

    if (customerBloc != null) {
      final allProducts = customerBloc.state.allProducts;
      for (final itemName in itemsToAdd) {
        final matched = ProductMatcher.findBestMatch(allProducts, itemName);
        if (matched != null && matched.stock > 0 && matched.isAvailable) {
          customerBloc.add(AddToCartEvent(matched));
        }
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Added all ingredients for ${widget.recipe.title} to cart!',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF10B981),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _handleSingleItemAdd(BuildContext context, RecipeIngredient ing) {
    final query = ing.matchedQuery ?? ing.name;
    setState(() {
      _singleAdded.add(ing.name);
    });

    if (widget.onAddItemsRequested != null) {
      widget.onAddItemsRequested!.call([query]);
      return;
    }

    CustomerBloc? customerBloc;
    try {
      customerBloc = context.read<CustomerBloc>();
    } catch (_) {}

    if (customerBloc != null) {
      final matched = ProductMatcher.findBestMatch(customerBloc.state.allProducts, query);
      if (matched != null && matched.stock > 0 && matched.isAvailable) {
        customerBloc.add(AddToCartEvent(matched));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFE11D48), Color(0xFFFB923C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.soup_kitchen_rounded, color: Colors.white, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          widget.recipe.cuisine ?? 'Master Recipe',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        widget.recipe.difficulty,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  widget.recipe.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildPill(Icons.timer_outlined, 'Prep: ${widget.recipe.prepTime}'),
                    const SizedBox(width: 6),
                    _buildPill(Icons.local_fire_department_outlined, 'Cook: ${widget.recipe.cookTime}'),
                    const SizedBox(width: 6),
                    _buildPill(Icons.people_outline_rounded, widget.recipe.servings),
                  ],
                ),
              ],
            ),
          ),

          // Tabs row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            color: Colors.grey.shade50,
            child: Row(
              children: [
                _buildTabButton(0, 'Ingredients (${widget.recipe.ingredients.length})'),
                const SizedBox(width: 6),
                _buildTabButton(1, 'Steps (${widget.recipe.steps.length})'),
                if (widget.recipe.chefTip != null) ...[
                  const SizedBox(width: 6),
                  _buildTabButton(2, 'Chef Tip 💡'),
                ],
              ],
            ),
          ),

          // Body Content Based on Tab
          Padding(
            padding: const EdgeInsets.all(12),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _selectedTab == 0
                  ? _buildIngredientsList(context)
                  : _selectedTab == 1
                      ? _buildStepsList()
                      : _buildChefTip(),
            ),
          ),

          // Bottom Action: Add All to Cart with Animation
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: InkWell(
                onTap: () => _handleAddAllToCart(context),
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _isAdded
                          ? [const Color(0xFF059669), const Color(0xFF10B981)]
                          : [const Color(0xFF4F46E5), const Color(0xFF7C3AED)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: (_isAdded ? const Color(0xFF10B981) : const Color(0xFF6366F1))
                            .withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isAdded ? Icons.check_circle_rounded : Icons.add_shopping_cart_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isAdded
                            ? 'All Ingredients Added to Cart! 🛒'
                            : 'Add All Ingredients (${widget.recipe.ingredients.length}) to Cart',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(int index, String title) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedTab = index),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    )
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppColors.primary : Colors.black54,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIngredientsList(BuildContext context) {
    return Column(
      key: const ValueKey('ingredients'),
      children: widget.recipe.ingredients.map((ing) {
        final isAdded = _singleAdded.contains(ing.name) || _isAdded;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Color(0xFF10B981),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  ing.name,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  ing.quantity,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: () => _handleSingleItemAdd(context, ing),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isAdded
                        ? const Color(0xFF10B981).withValues(alpha: 0.15)
                        : AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isAdded ? Icons.check : Icons.add,
                        size: 11,
                        color: isAdded ? const Color(0xFF059669) : AppColors.primary,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        isAdded ? 'Added' : 'Add',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: isAdded ? const Color(0xFF059669) : AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStepsList() {
    return Column(
      key: const ValueKey('steps'),
      children: widget.recipe.steps.asMap().entries.map((entry) {
        final index = entry.key + 1;
        final step = entry.value;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 18,
                height: 18,
                margin: const EdgeInsets.only(top: 2),
                decoration: const BoxDecoration(
                  color: Color(0xFFE11D48),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$index',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  step,
                  style: const TextStyle(
                    fontSize: 11.5,
                    height: 1.35,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildChefTip() {
    return Container(
      key: const ValueKey('cheftip'),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_rounded, size: 16, color: Color(0xFFD97706)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.recipe.chefTip ?? '',
              style: const TextStyle(
                fontSize: 11.5,
                height: 1.35,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w500,
                color: Color(0xFF92400E),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// LIVE STOCK & INVENTORY DETAILS CARD
// ============================================================================
class _StockDetailsCard extends StatelessWidget {
  final String itemQuery;

  const _StockDetailsCard({required this.itemQuery});

  @override
  Widget build(BuildContext context) {
    CustomerBloc? customerBloc;
    try {
      customerBloc = context.read<CustomerBloc>();
    } catch (_) {}

    final q = itemQuery.trim().toLowerCase();
    final allProducts = customerBloc?.state.allProducts ?? [];

    List<ProductEntity> matches = [];
    if (q.isNotEmpty && q != 'items') {
      matches = ProductMatcher.findMatches(allProducts, q, limit: 3);
    }

    if (matches.isEmpty && allProducts.isNotEmpty) {
      matches = allProducts.take(2).toList();
    }

    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.inventory_2_rounded, size: 14, color: Color(0xFF10B981)),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Live Stock & Inventory Status',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  '● LIVE',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF059669),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (matches.isNotEmpty) ...[
            ...matches.map((product) {
              final inStock = product.stock > 0 && product.isAvailable;
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200, width: 0.8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.name,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                '₹${product.price.toStringAsFixed(0)} • ${product.unit}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: inStock
                                      ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                      : Colors.red.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  inStock ? '${product.stock} in stock' : 'Out of stock',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    color: inStock ? const Color(0xFF059669) : Colors.red.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (inStock && customerBloc != null)
                      InkWell(
                        onTap: () {
                          customerBloc?.add(AddToCartEvent(product));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Added ${product.name} to cart!'),
                              duration: const Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add, size: 12, color: Colors.white),
                              SizedBox(width: 3),
                              Text(
                                'Add',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }),
          ] else ...[
            Text(
              'Item is available at your nearest QuickTick local store! You can add it directly to cart.',
              style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================================
// LIVE PAYMENT & TRANSACTION STATUS CARD
// ============================================================================
class _PaymentStatusCard extends StatelessWidget {
  final VoidCallback? onTrackOrderRequested;

  const _PaymentStatusCard({this.onTrackOrderRequested});

  @override
  Widget build(BuildContext context) {
    CustomerBloc? customerBloc;
    try {
      customerBloc = context.read<CustomerBloc>();
    } catch (_) {}

    final orders = customerBloc?.state.myOrders ?? [];
    final latestOrder =
        customerBloc?.state.latestPlacedOrder ?? (orders.isNotEmpty ? orders.first : null);

    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child:
                    const Icon(Icons.account_balance_wallet_rounded, size: 14, color: Color(0xFF6366F1)),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Live Payment & Order Status',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'SECURE',
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.black54,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (latestOrder != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200, width: 0.8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Order #${latestOrder.orderNumber.isNotEmpty ? latestOrder.orderNumber : latestOrder.id.substring(0, 8)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        '₹${latestOrder.grandTotal.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _buildPaymentBadge(latestOrder),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Status: ${latestOrder.status.label}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      if (onTrackOrderRequested != null)
                        InkWell(
                          onTap: onTrackOrderRequested,
                          child: const Text(
                            'Track Order →',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ] else ...[
            Text(
              'No active payments or orders found. When you place an order, live transaction and payment status appear here automatically.',
              style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentBadge(OrderEntity order) {
    final status = order.paymentStatus.toUpperCase();
    final isCod = order.paymentMethod.toUpperCase() == 'COD' ||
        order.paymentMethod.toUpperCase() == 'CASH ON DELIVERY';

    Color bg;
    Color fg;
    String label;
    IconData icon;

    if (status == 'PAID' || status == 'COMPLETED') {
      bg = const Color(0xFF10B981).withValues(alpha: 0.15);
      fg = const Color(0xFF059669);
      label = 'Payment Verified & Confirmed';
      icon = Icons.check_circle_rounded;
    } else if (isCod) {
      bg = const Color(0xFF3B82F6).withValues(alpha: 0.15);
      fg = const Color(0xFF2563EB);
      label = 'Pay on Delivery (COD) - ₹${order.grandTotal.toStringAsFixed(0)}';
      icon = Icons.local_shipping_rounded;
    } else if (status == 'PENDING') {
      bg = const Color(0xFFF59E0B).withValues(alpha: 0.15);
      fg = const Color(0xFFD97706);
      label = 'Payment Processing / Pending';
      icon = Icons.hourglass_top_rounded;
    } else {
      bg = Colors.red.withValues(alpha: 0.12);
      fg = Colors.red.shade700;
      label = 'Payment Status: ${order.paymentStatus}';
      icon = Icons.info_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

/// Interactive AI Concierge Card for instant Add-to-Cart commands.
/// Resolves requested item names locally and via live catalog search,
/// auto-adds matched in-stock items once per message, and lets users adjust or view cart.
class _AiAddToCartCard extends StatefulWidget {
  final String messageId;
  final List<String> itemNames;
  final VoidCallback? onViewCartRequested;
  final Function(String query)? onSearchCatalogRequested;

  const _AiAddToCartCard({
    super.key,
    required this.messageId,
    required this.itemNames,
    this.onViewCartRequested,
    this.onSearchCatalogRequested,
  });

  @override
  State<_AiAddToCartCard> createState() => _AiAddToCartCardState();
}

class _AiAddToCartCardState extends State<_AiAddToCartCard> {
  static final Set<String> _processedMessageIds = {};

  bool _isResolving = true;
  List<ProductEntity> _resolvedProducts = [];
  final Set<String> _autoAddedProductIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolveAndAutoAdd());
  }

  CustomerBloc? _tryCustomerBloc() {
    try {
      return context.read<CustomerBloc>();
    } catch (_) {
      return null;
    }
  }

  Future<void> _resolveAndAutoAdd() async {
    final customerBloc = _tryCustomerBloc();
    if (customerBloc == null) {
      if (mounted) setState(() => _isResolving = false);
      return;
    }

    final state = customerBloc.state;
    final catalogPool = <ProductEntity>[
      ...state.allProducts,
      ...state.filteredProducts,
    ];

    final matched = <ProductEntity>[];
    final seenIds = <String>{};

    for (final rawName in widget.itemNames) {
      final clean = ProductMatcher.normalizeQuery(rawName);
      if (clean.isEmpty) continue;

      var best = ProductMatcher.findBestMatch(catalogPool, clean);
      // Fallback: search remote catalog if product is not on currently loaded pages
      if (best == null && sl.isRegistered<ICatalogRepository>()) {
        try {
          final remoteRes = await sl<ICatalogRepository>().searchProducts(
            clean,
            lat: state.activeLat,
            lng: state.activeLng,
          );
          remoteRes.fold((_) {}, (products) {
            best = ProductMatcher.findBestMatch(products, clean);
          });
        } catch (_) {}
      }

      if (best != null && seenIds.add(best!.id)) {
        matched.add(best!);
      }
    }

    // If user literally said "add to cart" with no item name, suggest top available items without auto-adding
    final hasExplicitItems = widget.itemNames.isNotEmpty;
    if (!hasExplicitItems && matched.isEmpty && catalogPool.isNotEmpty) {
      for (final p in catalogPool.where((p) => p.stock > 0 && p.isAvailable).take(3)) {
        if (seenIds.add(p.id)) matched.add(p);
      }
    }

    final shouldAutoAdd = hasExplicitItems && !_processedMessageIds.contains(widget.messageId);
    if (shouldAutoAdd) {
      _processedMessageIds.add(widget.messageId);
      for (final p in matched) {
        if (p.stock > 0 && p.isAvailable) {
          customerBloc.add(AddToCartEvent(p));
          _autoAddedProductIds.add(p.id);
        }
      }
    }

    if (mounted) {
      setState(() {
        _resolvedProducts = matched;
        _isResolving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final customerBloc = _tryCustomerBloc();

    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.shopping_bag_rounded, size: 14, color: AppColors.primary),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _isResolving
                      ? 'Finding items in store...'
                      : (_autoAddedProductIds.isNotEmpty
                          ? 'Added to Your Cart'
                          : (widget.itemNames.isEmpty ? 'Quick Add Suggestions' : 'Cart Match Results')),
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              if (_autoAddedProductIds.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    '✓ ADDED',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF059669),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (_isResolving)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(minHeight: 3),
            )
          else if (_resolvedProducts.isNotEmpty && customerBloc != null)
            BlocBuilder<CustomerBloc, CustomerState>(
              bloc: customerBloc,
              builder: (context, custState) {
                return Column(
                  children: _resolvedProducts.map((product) {
                    final inStock = product.stock > 0 && product.isAvailable;
                    final cartQty = custState.cartItems
                        .where((c) => c.product.id == product.id)
                        .fold<int>(0, (sum, c) => sum + c.quantity);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: cartQty > 0
                              ? const Color(0xFF10B981).withValues(alpha: 0.4)
                              : Colors.grey.shade200,
                          width: 0.9,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  product.name,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '₹${product.price.toStringAsFixed(0)} • ${product.unit}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (inStock)
                            InkWell(
                              onTap: () => customerBloc.add(AddToCartEvent(product)),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: cartQty > 0 ? const Color(0xFF10B981) : AppColors.primary,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  cartQty > 0 ? 'In Cart ($cartQty) +1' : '+ Add',
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            )
                          else
                            Text(
                              'Out of stock',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.red.shade700,
                              ),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            )
          else
            Text(
              widget.itemNames.isEmpty
                  ? 'Tell me what to add (for example: "Add milk and bread to cart").'
                  : 'No matching in-stock items found for "${widget.itemNames.join(', ')}". Try searching the catalog.',
              style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
            ),
          if (!_isResolving) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                if (_resolvedProducts.isNotEmpty)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: widget.onViewCartRequested,
                      icon: const Icon(Icons.shopping_cart_checkout_rounded, size: 15),
                      label: const Text('View Cart', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                    ),
                  ),
                if (_resolvedProducts.isEmpty && widget.itemNames.isNotEmpty)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => widget.onSearchCatalogRequested?.call(widget.itemNames.first),
                      icon: const Icon(Icons.search_rounded, size: 15),
                      label: Text(
                        'Search "${widget.itemNames.first}"',
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

