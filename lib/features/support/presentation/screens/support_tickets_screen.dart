import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/support_ticket_entity.dart';
import '../bloc/support_bloc.dart';
import '../widgets/create_ticket_sheet.dart';
import 'ticket_chat_screen.dart';

class SupportTicketsScreen extends StatefulWidget {
  final String app; // 'customer', 'retailer', 'rider'
  final String? prefilledOrderId;

  const SupportTicketsScreen({
    super.key,
    required this.app,
    this.prefilledOrderId,
  });

  static Route route({required String app, String? prefilledOrderId}) {
    return MaterialPageRoute(
      builder: (_) => BlocProvider<SupportBloc>(
        create: (_) => sl<SupportBloc>(),
        child: SupportTicketsScreen(app: app, prefilledOrderId: prefilledOrderId),
      ),
    );
  }

  @override
  State<SupportTicketsScreen> createState() => _SupportTicketsScreenState();
}

class _SupportTicketsScreenState extends State<SupportTicketsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String?> _filterStatuses = [null, 'open', 'in_progress', 'resolved', 'closed'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadTickets();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    _loadTickets();
  }

  void _loadTickets() {
    final status = _filterStatuses[_tabController.index];
    context.read<SupportBloc>().add(FetchSupportTicketsEvent(status: status));
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  String get _appTitle {
    switch (widget.app.toLowerCase()) {
      case 'retailer':
        return 'Partner Support Desk';
      case 'rider':
        return 'Rider Support Helpdesk';
      case 'customer':
      default:
        return '24x7 Customer Support';
    }
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    String label = status.toUpperCase();

    switch (status.toLowerCase()) {
      case 'open':
        bg = Colors.blue.shade50;
        fg = Colors.blue.shade800;
        break;
      case 'in_progress':
        bg = Colors.amber.shade50;
        fg = Colors.amber.shade900;
        label = 'IN PROGRESS';
        break;
      case 'resolved':
        bg = Colors.green.shade50;
        fg = Colors.green.shade800;
        break;
      case 'closed':
        bg = Colors.grey.shade100;
        fg = Colors.grey.shade700;
        break;
      default:
        bg = Colors.grey.shade100;
        fg = Colors.grey.shade700;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.w800),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          _appTitle,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: const Color(0xFF0F766E),
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: const Color(0xFF0F766E),
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Open'),
            Tab(text: 'In Progress'),
            Tab(text: 'Resolved'),
            Tab(text: 'Closed'),
          ],
        ),
      ),
      body: BlocConsumer<SupportBloc, SupportState>(
        listener: (context, state) {
          if (state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage!),
                backgroundColor: Colors.redAccent,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state.isLoading && state.tickets.isEmpty) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF0F766E)));
          }

          if (state.errorMessage != null && state.tickets.isEmpty) {
            final isAuthError = state.errorMessage!.toLowerCase().contains('token') ||
                state.errorMessage!.toLowerCase().contains('unauthorized');
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isAuthError ? Icons.lock_clock_rounded : Icons.cloud_off_rounded,
                        size: 40,
                        color: Colors.red.shade700,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      isAuthError ? 'Session Expired' : 'Unable to Load Tickets',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isAuthError
                          ? 'Your login session has expired. Please log in again to access support tickets.'
                          : state.errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _loadTickets,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Retry', style: TextStyle(fontWeight: FontWeight.w800)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F766E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          if (state.tickets.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F766E).withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.support_agent_rounded,
                          size: 48, color: Color(0xFF0F766E)),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'No Support Tickets',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Have an issue with an order, delivery or payment? Raise a ticket and our agents will assist you.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => CreateTicketSheet.show(
                        context,
                        app: widget.app,
                        prefilledOrderId: widget.prefilledOrderId,
                      ),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Raise a Ticket',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F766E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            color: const Color(0xFF0F766E),
            onRefresh: () async => _loadTickets(),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
              itemCount: state.tickets.length,
              separatorBuilder: (_, index) => const SizedBox(height: 12),
              itemBuilder: (context, idx) {
                final ticket = state.tickets[idx];
                return _buildTicketCard(context, ticket, dateFormat);
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0F766E),
        icon: const Icon(Icons.add_comment_rounded, color: Colors.white),
        label: const Text(
          'New Ticket',
          style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white),
        ),
        onPressed: () => CreateTicketSheet.show(
          context,
          app: widget.app,
          prefilledOrderId: widget.prefilledOrderId,
        ),
      ),
    );
  }

  Widget _buildTicketCard(
    BuildContext context,
    SupportTicketEntity ticket,
    DateFormat dateFormat,
  ) {
    return InkWell(
      onTap: () {
        final bloc = context.read<SupportBloc>();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => BlocProvider.value(
              value: bloc,
              child: TicketChatScreen(ticketId: ticket.id),
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  ticket.ticketNumber,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F766E),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    ticket.category.replaceAll('_', ' ').toUpperCase(),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
                const Spacer(),
                _buildStatusBadge(ticket.status),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              ticket.subject,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              ticket.description,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (ticket.relatedOrderId != null) ...[
                  Icon(Icons.receipt_long_outlined, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(
                    'Order ${ticket.relatedOrderId}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                  const Spacer(),
                ],
                if (ticket.createdAt != null) ...[
                  Icon(Icons.schedule, size: 13, color: Colors.grey.shade400),
                  const SizedBox(width: 4),
                  Text(
                    dateFormat.format(ticket.createdAt!),
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                ],
                const SizedBox(width: 4),
                const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppColors.textSecondary),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
