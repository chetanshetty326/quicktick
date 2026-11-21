import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/widgets/network_and_server_error_view.dart';
import '../../../order/domain/entities/order_entity.dart';
import '../../domain/entities/delivery_models.dart';
import '../../domain/entities/delivery_api_entities.dart';
import '../../domain/entities/rider_wallet_entities.dart';
import '../bloc/delivery_bloc.dart';
import 'delivery_main_screen.dart';

class DeliveryPaymentHistoryScreen extends StatefulWidget {
  final bool isEmbedded;
  const DeliveryPaymentHistoryScreen({super.key, this.isEmbedded = false});

  @override
  State<DeliveryPaymentHistoryScreen> createState() => _DeliveryPaymentHistoryScreenState();
}

class _DeliveryPaymentHistoryScreenState extends State<DeliveryPaymentHistoryScreen> {
  int _selectedView = 0; // 0: Earnings & Breakdown, 1: Cash In Hand (COD), 2: Trips & Wallet

  @override
  void initState() {
    super.initState();
    final bloc = context.read<DeliveryBloc>();
    bloc.add(const FetchDeliveryEarningsEvent());
    bloc.add(const FetchEarningsBreakdownEvent());
    bloc.add(const FetchCashCollectedEvent());
    bloc.add(const FetchWalletDataEvent());
  }

  void _showWithdrawalSheet(BuildContext context, DeliveryState state) {
    if (state.bankAccounts.isEmpty) {
      _showAddBankAccountSheet(context);
      return;
    }

    final amountCtrl = TextEditingController(
      text: state.walletBalance >= 100 ? state.walletBalance.toStringAsFixed(0) : '100',
    );
    final notesCtrl = TextEditingController();
    String selectedBankAccountId = state.bankAccounts.firstWhere(
      (a) => a.isDefault,
      orElse: () => state.bankAccounts.first,
    ).id;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 540,
              maxHeight: MediaQuery.of(ctx).size.height * 0.9,
            ),
            child: Container(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Request Wallet Withdrawal',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Available Balance: ₹${state.walletBalance.toStringAsFixed(0)}',
                    style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const Text(
                    'Min: ₹100',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  prefixText: '₹ ',
                  prefixStyle: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  labelText: 'Withdrawal Amount',
                  labelStyle: const TextStyle(color: Colors.white60),
                  helperText: 'Minimum ₹100 required per policy',
                  helperStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white24)),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Payout Account',
                style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              ...state.bankAccounts.map((acc) {
                final isSelected = acc.id == selectedBankAccountId;
                return InkWell(
                  onTap: () => setSheetState(() => selectedBankAccountId = acc.id),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF047857).withValues(alpha: 0.3) : const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF10B981) : Colors.white12,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          acc.type == BankAccountType.upi ? Icons.qr_code : Icons.account_balance,
                          color: isSelected ? const Color(0xFF10B981) : Colors.white60,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(acc.displayTitle, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                              Text(acc.displaySubtitle, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                            ],
                          ),
                        ),
                        if (acc.verified)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('VERIFIED', style: TextStyle(color: Color(0xFF10B981), fontSize: 9, fontWeight: FontWeight.bold)),
                          ),
                        const SizedBox(width: 8),
                        Icon(
                          isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                          color: isSelected ? const Color(0xFF10B981) : Colors.white38,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                );
              }),
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _showAddBankAccountSheet(context);
                },
                icon: const Icon(Icons.add, size: 16, color: Color(0xFF38BDF8)),
                label: const Text('Add Another Bank / UPI Account', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 12)),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: notesCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Notes (optional)',
                  labelStyle: const TextStyle(color: Colors.white60),
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white24)),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    final amt = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                    if (amt < 100) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Minimum withdrawal is ₹100.')),
                      );
                      return;
                    }
                    if (amt > state.walletBalance) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Insufficient wallet balance. Available: ₹${state.walletBalance.toStringAsFixed(0)}')),
                      );
                      return;
                    }
                    context.read<DeliveryBloc>().add(RequestWalletWithdrawalEvent(
                          amount: amt,
                          bankAccountId: selectedBankAccountId,
                          notes: notesCtrl.text.trim(),
                        ));
                    Navigator.of(ctx).pop();
                  },
                  child: const Text('Submit Withdrawal Request', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  ),
),
);
  }

  void _showAddBankAccountSheet(BuildContext context) {
    bool isUpi = true;
    final upiCtrl = TextEditingController();
    final holderCtrl = TextEditingController();
    final accNumCtrl = TextEditingController();
    final confirmAccNumCtrl = TextEditingController();
    final ifscCtrl = TextEditingController();
    final bankNameCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 540,
              maxHeight: MediaQuery.of(ctx).size.height * 0.9,
            ),
            child: Container(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Add Payout Account',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('UPI ID')),
                      selected: isUpi,
                      selectedColor: const Color(0xFF10B981),
                      labelStyle: TextStyle(color: isUpi ? Colors.white : Colors.white60, fontWeight: FontWeight.bold),
                      onSelected: (_) => setSheetState(() => isUpi = true),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('Bank Account')),
                      selected: !isUpi,
                      selectedColor: const Color(0xFF10B981),
                      labelStyle: TextStyle(color: !isUpi ? Colors.white : Colors.white60, fontWeight: FontWeight.bold),
                      onSelected: (_) => setSheetState(() => isUpi = false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (isUpi) ...[
                TextField(
                  controller: upiCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.qr_code, color: Color(0xFF10B981)),
                    labelText: 'UPI ID / VPA (e.g. name@okhdfcbank)',
                    labelStyle: const TextStyle(color: Colors.white60),
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white24)),
                  ),
                ),
              ] else ...[
                TextField(
                  controller: holderCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Account Holder Name',
                    labelStyle: const TextStyle(color: Colors.white60),
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white24)),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: accNumCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Account Number',
                    labelStyle: const TextStyle(color: Colors.white60),
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white24)),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: confirmAccNumCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Confirm Account Number',
                    labelStyle: const TextStyle(color: Colors.white60),
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white24)),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: ifscCtrl,
                        textCapitalization: TextCapitalization.characters,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          labelText: 'IFSC Code',
                          labelStyle: const TextStyle(color: Colors.white60),
                          filled: true,
                          fillColor: const Color(0xFF1E293B),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white24)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: bankNameCtrl,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          labelText: 'Bank Name',
                          labelStyle: const TextStyle(color: Colors.white60),
                          filled: true,
                          fillColor: const Color(0xFF1E293B),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white24)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Map<String, dynamic> payload;
                    if (isUpi) {
                      final upi = upiCtrl.text.trim();
                      if (!RegExp(r'^[\w.\-_]{2,256}@[a-zA-Z]{2,64}$').hasMatch(upi)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter a valid UPI ID (e.g. name@okhdfcbank).')),
                        );
                        return;
                      }
                      payload = {'type': 'UPI', 'upiVpa': upi, 'isDefault': true};
                    } else {
                      final holder = holderCtrl.text.trim();
                      final accNum = accNumCtrl.text.trim();
                      final confirmAccNum = confirmAccNumCtrl.text.trim();
                      final ifsc = ifscCtrl.text.trim().toUpperCase();

                      if (holder.isEmpty || accNum.isEmpty || confirmAccNum.isEmpty || ifsc.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please fill all bank details including account confirmation.')),
                        );
                        return;
                      }
                      if (accNum != confirmAccNum) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Bank account numbers do not match. Please re-enter.')),
                        );
                        return;
                      }
                      if (!RegExp(r'^\d{9,18}$').hasMatch(accNum)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Bank account number must be between 9 and 18 digits.')),
                        );
                        return;
                      }
                      if (!RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$').hasMatch(ifsc)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Invalid IFSC format. Must be 11 characters (e.g. HDFC0001234).')),
                        );
                        return;
                      }
                      payload = {
                        'type': 'BANK',
                        'accountHolderName': holder,
                        'accountNumber': accNum,
                        'ifscCode': ifsc,
                        'bankName': bankNameCtrl.text.trim().isNotEmpty ? bankNameCtrl.text.trim() : 'Bank',
                        'isDefault': true,
                      };
                    }

                    showDialog(
                      context: context,
                      builder: (dialogCtx) => AlertDialog(
                        backgroundColor: const Color(0xFF1E293B),
                        title: const Text('Confirm Account Details', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        content: Text(
                          isUpi
                              ? 'Set ${payload['upiVpa']} as your default payout UPI ID?'
                              : 'Add account ••••${payload['accountNumber'].toString().substring(payload['accountNumber'].toString().length - 4)} (${payload['bankName']}) for delivery earnings payouts?',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogCtx),
                            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                            onPressed: () {
                              Navigator.pop(dialogCtx);
                              context.read<DeliveryBloc>().add(AddBankAccountEvent(payload));
                              Navigator.of(ctx).pop();
                            },
                            child: const Text('Confirm & Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Text('Save Account', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  ),
),
);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DeliveryBloc, DeliveryState>(
      builder: (context, state) {
        final hasFinancialData = state.apiEarnings != null ||
            state.earningsBreakdown.isNotEmpty ||
            state.transactions.isNotEmpty ||
            state.cashCollectedSummary != null;

        final content = Column(
          children: [
            // Responsive 3-Tab Segmented Control
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                height: 44,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  children: [
                    _buildTabButton(0, 'Earnings', Icons.insights_rounded),
                    _buildTabButton(1, 'Cash In Hand', Icons.payments_rounded),
                    _buildTabButton(2, 'Trips & Wallet', Icons.account_balance_wallet_rounded),
                  ],
                ),
              ),
            ),

            Expanded(
              child: RefreshIndicator(
                color: const Color(0xFF10B981),
                onRefresh: () async {
                  final bloc = context.read<DeliveryBloc>();
                  bloc.add(const FetchDeliveryEarningsEvent());
                  bloc.add(const FetchEarningsBreakdownEvent());
                  bloc.add(const FetchCashCollectedEvent());
                  bloc.add(const FetchWalletDataEvent());
                },
                child: (!hasFinancialData && state.failureType != FailureType.none)
                    ? NetworkAndServerErrorView(
                        failureType: state.failureType,
                        customMessage: state.errorMessage,
                        isRetrying: state.isLoadingEarnings || state.isWalletLoading,
                        onRetry: () {
                          final bloc = context.read<DeliveryBloc>();
                          bloc.add(const FetchDeliveryEarningsEvent());
                          bloc.add(const FetchEarningsBreakdownEvent());
                          bloc.add(const FetchCashCollectedEvent());
                          bloc.add(const FetchWalletDataEvent());
                        },
                      )
                    : (_selectedView == 0
                        ? _buildEarningsSummaryTab(state)
                        : _selectedView == 1
                            ? _buildCashInHandTab(state)
                            : _buildTripsAndWalletTab(state, context)),
              ),
            ),
          ],
        );

        if (widget.isEmbedded) {
          return content;
        }

        void handleBack() {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          } else {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const DeliveryMainScreen()),
            );
          }
        }

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) handleBack();
          },
          child: Scaffold(
            backgroundColor: const Color(0xFF0F172A),
            appBar: AppBar(
              backgroundColor: const Color(0xFF0F172A),
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: handleBack,
              ),
              title: const Text('Trips & Financials', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            body: content,
          ),
        );
      },
    );
  }

  Widget _buildTabButton(int index, String label, IconData icon) {
    final isSelected = _selectedView == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedView = index),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF10B981) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: isSelected ? Colors.white : Colors.white60),
              const SizedBox(width: 4),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEarningsSummaryTab(DeliveryState state) {
    final earnings = state.apiEarnings;
    final today = earnings?.today ?? PeriodEarningsEntity(amount: state.todayEarnings, deliveries: state.todayCompletedCount);
    final week = earnings?.thisWeek ?? const PeriodEarningsEntity(amount: 0, deliveries: 0);
    final month = earnings?.thisMonth ?? const PeriodEarningsEntity(amount: 0, deliveries: 0);
    final life = earnings?.lifetime ?? const PeriodEarningsEntity(amount: 0, deliveries: 0);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Earnings Performance 📊',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        // Grid of 4 Periods
        Row(
          children: [
            Expanded(child: _PeriodEarningsCard(title: 'Today', period: today, color: const Color(0xFF10B981))),
            const SizedBox(width: 12),
            Expanded(child: _PeriodEarningsCard(title: 'This Week', period: week, color: const Color(0xFF38BDF8))),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _PeriodEarningsCard(title: 'This Month', period: month, color: const Color(0xFFF59E0B))),
            const SizedBox(width: 12),
            Expanded(child: _PeriodEarningsCard(title: 'Lifetime', period: life, color: const Color(0xFFA855F7))),
          ],
        ),

        const SizedBox(height: 24),

        // Breakdown List Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text(
                'Per-Order Earnings Breakdown',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            if (state.earningsBreakdown.isNotEmpty)
              Text(
                '${state.earningsBreakdown.length} orders',
                style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 12, fontWeight: FontWeight.bold),
              ),
          ],
        ),
        const SizedBox(height: 12),

        if (state.isLoadingEarnings)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator(color: Color(0xFF10B981))),
          )
        else if (state.earningsBreakdown.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              children: [
                Icon(Icons.receipt_long_outlined, size: 40, color: Colors.white24),
                SizedBox(height: 10),
                Text(
                  'No order breakdown records available yet.',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          ...state.earningsBreakdown.map((row) => _EarningsBreakdownTile(row: row)),
      ],
    );
  }

  Widget _buildCashInHandTab(DeliveryState state) {
    final summary = state.cashCollectedSummary;
    final totalCash = summary?.totalCashCollected ?? 0.0;
    final totalEarn = summary?.totalEarnings ?? state.todayEarnings;
    final owedToCompany = summary?.netOwedToCompany ?? ((totalCash > totalEarn) ? totalCash - totalEarn : 0.0);
    final owedByCompany = summary?.netOwedByCompany ?? ((totalEarn > totalCash) ? totalEarn - totalCash : 0.0);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Main Company Settlement Status Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: owedToCompany > 0
                  ? [const Color(0xFFDC2626), const Color(0xFF991B1B)]
                  : [const Color(0xFF059669), const Color(0xFF047857)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: (owedToCompany > 0 ? const Color(0xFFDC2626) : const Color(0xFF059669)).withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      owedToCompany > 0 ? 'COD Cash Deposit Required' : 'Net Settlement Status',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      owedToCompany > 0 ? 'Action Needed' : 'In Balance',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (owedToCompany > 0) ...[
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'You owe ₹${owedToCompany.toStringAsFixed(0)} to company',
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Please deposit the collected Cash on Delivery amounts before midnight to avoid duty suspension.',
                  style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.3),
                ),
              ] else if (owedByCompany > 0) ...[
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Company owes ₹${owedByCompany.toStringAsFixed(0)} to you',
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Your delivery payouts exceed COD collected. Net balance will be auto-credited to your registered bank account.',
                  style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.3),
                ),
              ] else ...[
                const FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'All Accounts Settled (₹0 Balance)',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'No outstanding cash deposits required. You are fully settled.',
                  style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.3),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Cash Metrics
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                title: 'COD Cash Collected',
                value: '₹${totalCash.toStringAsFixed(0)}',
                subtitle: 'From customers',
                icon: Icons.payments_outlined,
                color: const Color(0xFFF59E0B),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                title: 'Total Rider Earnings',
                value: '₹${totalEarn.toStringAsFixed(0)}',
                subtitle: 'Deliveries & tips',
                icon: Icons.account_balance_wallet_outlined,
                color: const Color(0xFF10B981),
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Deposit Guidelines Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cash Deposit Guidelines ℹ️',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Text(
                '1. Cash collected from Cash on Delivery (COD) orders belongs to QuickTick.\n'
                '2. Net Payout is calculated as: Gross Delivery Earnings - COD Cash Collected.\n'
                '3. If you collect more cash than your earnings, you owe the difference to the company.\n'
                '4. Deposit via company UPI or visit the nearest hub office before the end of each day.',
                style: TextStyle(color: Colors.white70, fontSize: 11, height: 1.5),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTripsAndWalletTab(DeliveryState state, BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Wallet Balance Glassmorphism Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF059669), Color(0xFF047857)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF059669).withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'Available Wallet Balance',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('Daily Auto-Settlement', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  '₹${state.walletBalance.toStringAsFixed(0)}',
                  style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF047857),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF047857), size: 18),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Request Withdrawal (Min ₹100)', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      onPressed: () => _showWithdrawalSheet(context, state),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Saved Payout Accounts Section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text(
                'Payout Accounts',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: () => _showAddBankAccountSheet(context),
              icon: const Icon(Icons.add, size: 16, color: Color(0xFF10B981)),
              label: const Text('Add Account', style: TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (state.bankAccounts.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.white54, size: 20),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('No saved bank or UPI account. Add one to receive payouts.',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                ),
                TextButton(
                  onPressed: () => _showAddBankAccountSheet(context),
                  child: const Text('Add Now', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          )
        else
          ...state.bankAccounts.map((acc) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: acc.isDefault ? const Color(0xFF10B981).withValues(alpha: 0.5) : Colors.white12),
                ),
                child: Row(
                  children: [
                    Icon(
                      acc.type == BankAccountType.upi ? Icons.qr_code : Icons.account_balance,
                      color: const Color(0xFF10B981),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(acc.displayTitle, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                          Text(acc.displaySubtitle, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (acc.verified ? const Color(0xFF10B981) : const Color(0xFFF59E0B)).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        acc.verified ? 'VERIFIED' : 'PENDING',
                        style: TextStyle(
                          color: acc.verified ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.white38, size: 18),
                      onPressed: () {
                        context.read<DeliveryBloc>().add(DeleteBankAccountEvent(acc.id));
                      },
                    ),
                  ],
                ),
              )),

        const SizedBox(height: 16),

        // Withdrawal Requests Section (if any)
        if (state.withdrawals.isNotEmpty) ...[
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Withdrawal Requests', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              Text('Recent', style: TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          ...state.withdrawals.map((w) {
            Color statusColor;
            switch (w.status) {
              case WithdrawalStatus.paid:
                statusColor = const Color(0xFF10B981);
                break;
              case WithdrawalStatus.approved:
                statusColor = const Color(0xFF38BDF8);
                break;
              case WithdrawalStatus.rejected:
              case WithdrawalStatus.failed:
                statusColor = const Color(0xFFEF4444);
                break;
              case WithdrawalStatus.cancelled:
                statusColor = Colors.white38;
                break;
              default:
                statusColor = const Color(0xFFF59E0B);
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.currency_rupee, color: statusColor, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('₹${w.amount.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
                        Text(
                          '${w.createdAt.day}/${w.createdAt.month}/${w.createdAt.year} • Status: ${w.status.label}',
                          style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (w.paymentReference.isNotEmpty)
                          Text(
                            'Ref: ${w.paymentReference}',
                            style: const TextStyle(color: Colors.white38, fontSize: 10),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  if (w.status == WithdrawalStatus.pending)
                    TextButton(
                      onPressed: () {
                        context.read<DeliveryBloc>().add(CancelWithdrawalEvent(w.id));
                      },
                      child: const Text('Cancel', style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            );
          }),
          const SizedBox(height: 16),
        ],

        // Completed Trips Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text(
                'Completed Trips Log',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text('${state.completedTrips.length} trips', style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 12),

        if (state.completedTrips.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text('No completed delivery trips yet today.', style: TextStyle(color: Colors.white54, fontSize: 13)),
          )
        else
          ...state.completedTrips.map((order) => _DeliveredTripCard(order: order)),

        const SizedBox(height: 24),

        // Transaction History Header
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Settlement Ledger',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: 8),
            Text('All Transfers', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 12),

        if (state.transactions.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text('No transactions yet today.', style: TextStyle(color: Colors.white54)),
          )
        else
          ...state.transactions.map((tx) => _TransactionTile(tx: tx)),
      ],
    );
  }
}

class _DeliveredTripCard extends StatelessWidget {
  final OrderEntity order;
  const _DeliveredTripCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final isCod = order.paymentMethod.toUpperCase() == 'COD' || order.paymentMethod.toLowerCase().contains('cash');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Trip #${order.orderNumber}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            order.storeName,
                            style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 12, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF10B981)),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '+₹${(order.deliveryFee > 0 ? order.deliveryFee : 35.0).toStringAsFixed(0)} Earned',
                    style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white10, height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.pin_drop, color: Color(0xFFF59E0B), size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Delivered to: ${order.customerName} • ${order.deliveryAddress}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${order.items.length} items (${order.items.map((i) => i.nameSnapshot).take(2).join(", ")}${order.items.length > 2 ? '...' : ''})',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: (isCod ? const Color(0xFFF59E0B) : const Color(0xFF38BDF8)).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isCod ? 'Cash Collected: ₹${order.grandTotal.toStringAsFixed(0)}' : 'Prepaid Order',
                  style: TextStyle(
                    color: isCod ? const Color(0xFFF59E0B) : const Color(0xFF38BDF8),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Icon(icon, color: color, size: 18),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              subtitle,
              style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final DeliveryTransactionEntity tx;
  const _TransactionTile({required this.tx});

  @override
  Widget build(BuildContext context) {
    final isWithdrawal = tx.type == TransactionType.upiWithdrawal;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isWithdrawal ? const Color(0xFFEF4444).withValues(alpha: 0.15) : const Color(0xFF10B981).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isWithdrawal ? Icons.arrow_outward : Icons.arrow_downward,
              color: isWithdrawal ? const Color(0xFFEF4444) : const Color(0xFF10B981),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.description,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  isWithdrawal ? 'Instant UPI Cashout' : 'Order #${tx.orderNumber} Delivery Earnings',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              isWithdrawal ? '-₹${tx.amount.abs().toStringAsFixed(0)}' : '+₹${tx.amount.toStringAsFixed(0)}',
              style: TextStyle(
                color: isWithdrawal ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodEarningsCard extends StatelessWidget {
  final String title;
  final PeriodEarningsEntity period;
  final Color color;

  const _PeriodEarningsCard({
    required this.title,
    required this.period,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${period.deliveries} orders',
                    style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '₹${period.amount.toStringAsFixed(0)}',
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Cash Col:', style: TextStyle(color: Colors.white38, fontSize: 10)),
              const SizedBox(width: 4),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    '₹${period.cashCollected.toStringAsFixed(0)}',
                    style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 10, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Net Payout:', style: TextStyle(color: Colors.white38, fontSize: 10)),
              const SizedBox(width: 4),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    '₹${period.netPayout.toStringAsFixed(0)}',
                    style: TextStyle(
                      color: period.netPayout >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EarningsBreakdownTile extends StatelessWidget {
  final EarningsBreakdownRowEntity row;
  const _EarningsBreakdownTile({required this.row});

  @override
  Widget build(BuildContext context) {
    final isCod = row.paymentMethod.toUpperCase() == 'COD';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.receipt, color: Color(0xFF38BDF8), size: 16),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Order #${row.orderNumber}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (isCod ? const Color(0xFFF59E0B) : const Color(0xFF38BDF8)).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: (isCod ? const Color(0xFFF59E0B) : const Color(0xFF38BDF8)).withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  isCod ? 'COD 💵' : 'ONLINE 💳',
                  style: TextStyle(
                    color: isCod ? const Color(0xFFF59E0B) : const Color(0xFF38BDF8),
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Breakdown components
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              Text('Base: ₹${row.basePay.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white60, fontSize: 11)),
              if (row.distancePay > 0)
                Text('Distance: ₹${row.distancePay.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white60, fontSize: 11)),
              if (row.surgeBonus > 0)
                Text('Surge: +₹${row.surgeBonus.toStringAsFixed(0)}', style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 11, fontWeight: FontWeight.w600)),
              if (row.tipFromCustomer > 0)
                Text('Tip: +₹${row.tipFromCustomer.toStringAsFixed(0)}', style: const TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.w600)),
              if (row.penalty > 0)
                Text('Penalty: -₹${row.penalty.toStringAsFixed(0)}', style: const TextStyle(color: Color(0xFFEF4444), fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
          const Divider(color: Colors.white10, height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Total Earned: ₹${row.totalEarning.toStringAsFixed(0)}',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (row.cashCollected > 0) ...[
                    Text(
                      'Cash: ₹${row.cashCollected.toStringAsFixed(0)}  ',
                      style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                  Text(
                    'Net: ${row.netPayout >= 0 ? "+" : ""}₹${row.netPayout.toStringAsFixed(0)}',
                    style: TextStyle(
                      color: row.netPayout >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

