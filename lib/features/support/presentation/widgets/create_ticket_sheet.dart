import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../bloc/support_bloc.dart';

class CreateTicketSheet extends StatefulWidget {
  final String app; // 'customer', 'retailer', 'rider'
  final String? prefilledOrderId;
  final String? prefilledCategory;

  const CreateTicketSheet({
    super.key,
    required this.app,
    this.prefilledOrderId,
    this.prefilledCategory,
  });

  static Future<void> show(
    BuildContext context, {
    required String app,
    String? prefilledOrderId,
    String? prefilledCategory,
  }) {
    final supportBloc = context.read<SupportBloc>();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: supportBloc,
        child: CreateTicketSheet(
          app: app,
          prefilledOrderId: prefilledOrderId,
          prefilledCategory: prefilledCategory,
        ),
      ),
    );
  }

  @override
  State<CreateTicketSheet> createState() => _CreateTicketSheetState();
}

class _CreateTicketSheetState extends State<CreateTicketSheet> {
  final _formKey = GlobalKey<FormState>();
  late String _selectedCategory;
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _orderIdController = TextEditingController();

  final List<({String key, String label, IconData icon})> _categories = const [
    (key: 'order_issue', label: 'Order Issue', icon: Icons.shopping_bag_outlined),
    (key: 'refund', label: 'Refund', icon: Icons.currency_rupee),
    (key: 'payment', label: 'Payment', icon: Icons.payment_outlined),
    (key: 'delivery', label: 'Delivery', icon: Icons.delivery_dining_outlined),
    (key: 'account', label: 'Account', icon: Icons.person_outline),
    (key: 'technical', label: 'Technical Issue', icon: Icons.build_outlined),
    (key: 'other', label: 'Other', icon: Icons.help_outline),
  ];

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.prefilledCategory ?? 'order_issue';
    if (widget.prefilledOrderId != null) {
      _orderIdController.text = widget.prefilledOrderId!;
    }
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _descriptionController.dispose();
    _orderIdController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final rawOrderId = _orderIdController.text.trim();
    final isMongoObjectId = RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(rawOrderId);

    String description = _descriptionController.text.trim();
    String? validOrderId;

    if (rawOrderId.isNotEmpty) {
      if (isMongoObjectId) {
        validOrderId = rawOrderId;
      } else {
        description = '$description\n\n[Related Order: $rawOrderId]';
      }
    }

    context.read<SupportBloc>().add(
          CreateSupportTicketEvent(
            app: widget.app,
            category: _selectedCategory,
            subject: _subjectController.text.trim(),
            description: description,
            relatedOrderId: validOrderId,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SupportBloc, SupportState>(
      listener: (context, state) {
        if (state.newlyCreatedTicket != null) {
          context.read<SupportBloc>().add(const ResetTicketCreatedEvent());
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Ticket ${state.newlyCreatedTicket!.ticketNumber} created successfully!',
              ),
              backgroundColor: const Color(0xFF0F766E),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      child: Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          left: 20,
          right: 20,
          top: 16,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.support_agent_rounded,
                          color: AppColors.primary, size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Raise Support Ticket',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'Our support team will respond shortly',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(height: 24),

                // Category Chips
                const Text(
                  'Select Category',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _categories.map((cat) {
                    final isSelected = _selectedCategory == cat.key;
                    return ChoiceChip(
                      selected: isSelected,
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            cat.icon,
                            size: 14,
                            color: isSelected ? Colors.white : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(cat.label),
                        ],
                      ),
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? Colors.white : AppColors.textPrimary,
                      ),
                      selectedColor: const Color(0xFF0F766E),
                      backgroundColor: Colors.grey.shade100,
                      onSelected: (val) {
                        if (val) setState(() => _selectedCategory = cat.key);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Subject
                const Text(
                  'Subject',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _subjectController,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Please enter a subject' : null,
                  decoration: InputDecoration(
                    hintText: 'e.g. Order #123 items missing',
                    hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Related Order ID
                const Text(
                  'Order ID (Optional)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _orderIdController,
                  decoration: InputDecoration(
                    hintText: 'e.g. Order # or Reference (Optional)',
                    hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Description
                const Text(
                  'Detailed Description',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 4,
                  validator: (v) =>
                      (v == null || v.trim().length < 5) ? 'Please provide more details' : null,
                  decoration: InputDecoration(
                    hintText: 'Describe what went wrong or how we can help you...',
                    hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    contentPadding: const EdgeInsets.all(14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Submit Button
                BlocBuilder<SupportBloc, SupportState>(
                  builder: (context, state) {
                    return SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: state.isCreatingTicket ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F766E),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: state.isCreatingTicket
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text(
                                'Submit Ticket',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
