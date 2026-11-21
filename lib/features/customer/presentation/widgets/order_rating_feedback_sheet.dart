import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../order/domain/entities/order_entity.dart';
import '../bloc/customer_bloc.dart';

/// Interactive, responsive Post-Delivery Rating & Feedback Bottom Sheet
/// Inspired by Swiggy & Zepto:
/// - 5-star rating for Store & Items with quick tags
/// - 5-star rating for Delivery Partner with quick tags
/// - Optional feedback note and seamless BLoC submission
class OrderRatingFeedbackSheet extends StatefulWidget {
  final OrderEntity order;

  const OrderRatingFeedbackSheet({
    super.key,
    required this.order,
  });

  /// Displays the rating sheet only if the order hasn't been reviewed yet.
  static Future<void> show(
    BuildContext context, {
    required OrderEntity order,
  }) async {
    final bloc = context.read<CustomerBloc>();
    if (bloc.state.reviewedOrderIds.contains(order.id)) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: OrderRatingFeedbackSheet(order: order),
      ),
    );
  }

  @override
  State<OrderRatingFeedbackSheet> createState() => _OrderRatingFeedbackSheetState();
}

class _OrderRatingFeedbackSheetState extends State<OrderRatingFeedbackSheet> {
  int _storeRating = 5;
  int _riderRating = 5;

  final Set<String> _selectedStoreTags = {};
  final Set<String> _selectedRiderTags = {};

  final TextEditingController _commentController = TextEditingController();

  static const List<String> _storeTagOptions = [
    '📦 Neatly Packed',
    '🍎 Fresh Quality',
    '🏷️ Correct Items',
    '⚡ Rapid Dispatch',
    '❄️ Cold Items Fresh',
    '💯 Great Value',
  ];

  static const List<String> _riderTagOptions = [
    '🚀 Super Fast',
    '😊 Polite & Courteous',
    '🚪 Followed Instructions',
    '🛡️ Contactless & Safe',
    '📍 Found Address Easily',
    '🌧️ Braved the Weather',
  ];

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  String _getRatingLabel(int rating) {
    switch (rating) {
      case 1:
        return 'Needs Improvement 🙁';
      case 2:
        return 'Below Expectations 😐';
      case 3:
        return 'Satisfactory 🙂';
      case 4:
        return 'Very Good! 😊';
      case 5:
        return 'Outstanding! 🌟';
      default:
        return 'Rate Experience';
    }
  }

  void _handleSubmit() {
    if (_storeRating == 0 && _riderRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a star rating to submit feedback.')),
      );
      return;
    }

    context.read<CustomerBloc>().add(
          SubmitOrderReviewEvent(
            orderId: widget.order.id,
            storeRating: _storeRating > 0 ? _storeRating : 5,
            deliveryRating: _riderRating > 0 ? _riderRating : 5,
            comment: _commentController.text.trim(),
            storeTags: _selectedStoreTags.toList(),
            riderTags: _selectedRiderTags.toList(),
          ),
        );

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final bottomInset = media.viewInsets.bottom;
    final partnerName = widget.order.deliveryPartnerName?.isNotEmpty == true
        ? widget.order.deliveryPartnerName!
        : 'Delivery Partner';

    return BlocConsumer<CustomerBloc, CustomerState>(
      listenWhen: (prev, curr) =>
          prev.isSubmittingReview && !curr.isSubmittingReview && curr.errorMessage != null,
      listener: (context, state) {
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
      },
      builder: (context, state) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 580),
            child: Container(
              constraints: BoxConstraints(
                maxHeight: media.size.height * 0.90,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x330F172A),
                    blurRadius: 28,
                    offset: Offset(0, -6),
                  ),
                ],
              ),
              padding: EdgeInsets.only(bottom: bottomInset),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Grab Handle
                  const SizedBox(height: 12),
                  Container(
                    width: 44,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Header with Delivered Celebration Badge
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.14),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check_circle_rounded,
                                  color: Color(0xFF059669),
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Order Delivered!',
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    Text(
                                      'Order #${widget.order.orderNumber} • ${widget.order.storeName}',
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        color: Color(0xFF64748B),
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8), size: 22),
                          onPressed: () => Navigator.of(context).pop(),
                          tooltip: 'Maybe Later',
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 20, color: Color(0xFFF1F5F9)),

                  // Scrollable Rating Sections
                  Flexible(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // SECTION 1: Store & Item Quality Rating
                          _buildSectionCard(
                            icon: Icons.storefront_rounded,
                            iconColor: AppColors.primary,
                            title: widget.order.storeName.isNotEmpty
                                ? widget.order.storeName
                                : 'Store & Products Quality',
                            subtitle: 'How was the packing and product condition?',
                            currentRating: _storeRating,
                            onRatingSelected: (stars) => setState(() => _storeRating = stars),
                            tagOptions: _storeTagOptions,
                            selectedTags: _selectedStoreTags,
                            onTagToggled: (tag) {
                              setState(() {
                                if (_selectedStoreTags.contains(tag)) {
                                  _selectedStoreTags.remove(tag);
                                } else {
                                  _selectedStoreTags.add(tag);
                                }
                              });
                            },
                          ),
                          const SizedBox(height: 18),

                          // SECTION 2: Delivery Partner Experience Rating
                          _buildSectionCard(
                            icon: Icons.delivery_dining_rounded,
                            iconColor: const Color(0xFFF59E0B),
                            title: partnerName,
                            subtitle: 'How was the delivery speed and service?',
                            currentRating: _riderRating,
                            onRatingSelected: (stars) => setState(() => _riderRating = stars),
                            tagOptions: _riderTagOptions,
                            selectedTags: _selectedRiderTags,
                            onTagToggled: (tag) {
                              setState(() {
                                if (_selectedRiderTags.contains(tag)) {
                                  _selectedRiderTags.remove(tag);
                                } else {
                                  _selectedRiderTags.add(tag);
                                }
                              });
                            },
                          ),
                          const SizedBox(height: 18),

                          // SECTION 3: Additional Comment (Optional)
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.edit_note_rounded, size: 18, color: Color(0xFF475569)),
                                    SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Add a quick note (Optional)',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF1E293B),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _commentController,
                                  maxLines: 2,
                                  maxLength: 250,
                                  style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                                  decoration: const InputDecoration(
                                    hintText: 'Share what you loved or how we can improve...',
                                    hintStyle: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                                    border: InputBorder.none,
                                    counterText: '',
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),

                  // Bottom Action Bar
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'Maybe Later',
                                style: TextStyle(
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: SizedBox(
                            height: 50,
                            child: ElevatedButton(
                              onPressed: state.isSubmittingReview ? null : _handleSubmit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0F766E),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: state.isSubmittingReview
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.2,
                                      ),
                                    )
                                  : const FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.star_rounded, size: 20, color: Color(0xFFFDE68A)),
                                          SizedBox(width: 6),
                                          Text(
                                            'SUBMIT FEEDBACK',
                                            style: TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 0.5,
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
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required int currentRating,
    required ValueChanged<int> onRatingSelected,
    required List<String> tagOptions,
    required Set<String> selectedTags,
    required ValueChanged<String> onTagToggled,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title & Icon
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 5-Star Interactive Rating Bar
          Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final starIndex = index + 1;
                  final isSelected = starIndex <= currentRating;
                  return GestureDetector(
                    onTap: () => onRatingSelected(starIndex),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: AnimatedScale(
                        scale: isSelected ? 1.08 : 0.95,
                        duration: const Duration(milliseconds: 150),
                        curve: Curves.easeOutBack,
                        child: Icon(
                          isSelected ? Icons.star_rounded : Icons.star_outline_rounded,
                          size: 34,
                          color: isSelected ? const Color(0xFFF59E0B) : const Color(0xFFCBD5E1),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 6),

          // Rating Label
          Center(
            child: Text(
              _getRatingLabel(currentRating),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: currentRating >= 4 ? const Color(0xFF059669) : const Color(0xFFD97706),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Quick Tags Section
          const Text(
            'Quick feedback tags:',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tagOptions.map((tag) {
              final isChosen = selectedTags.contains(tag);
              return InkWell(
                onTap: () => onTagToggled(tag),
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                  decoration: BoxDecoration(
                    color: isChosen
                        ? const Color(0xFF0F766E).withValues(alpha: 0.12)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isChosen ? const Color(0xFF0F766E) : const Color(0xFFCBD5E1),
                      width: isChosen ? 1.4 : 1.0,
                    ),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: isChosen ? FontWeight.w800 : FontWeight.w600,
                      color: isChosen ? const Color(0xFF0F766E) : const Color(0xFF334155),
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
}
