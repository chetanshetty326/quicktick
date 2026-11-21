import 'package:flutter_test/flutter_test.dart';
import 'package:dartz/dartz.dart';
import 'package:quicklink/core/errors/failures.dart';
import 'package:quicklink/core/network/api_endpoints.dart';
import 'package:quicklink/features/customer/domain/entities/hero_banner_entity.dart';
import 'package:quicklink/features/customer/data/models/hero_banner_model.dart';
import 'package:quicklink/features/customer/domain/entities/coupon_entity.dart';
import 'package:quicklink/features/customer/data/models/coupon_model.dart';
import 'package:quicklink/features/support/domain/entities/support_ticket_entity.dart';
import 'package:quicklink/features/support/data/models/support_ticket_model.dart';
import 'package:quicklink/features/support/domain/repositories/support_repository.dart';
import 'package:quicklink/features/support/presentation/bloc/support_bloc.dart';

class MockSupportRepository implements ISupportRepository {
  List<SupportTicketEntity> mockTickets = [];
  List<SupportMessageEntity> mockMessages = [];

  @override
  Future<Either<Failure, ({List<SupportTicketEntity> tickets, int total, int page, int pages})>>
      getTickets({
    String? status,
    int page = 1,
    int limit = 20,
  }) async {
    final filtered = (status != null && status.isNotEmpty)
        ? mockTickets.where((t) => t.status == status).toList()
        : mockTickets;
    return Right((tickets: filtered, total: filtered.length, page: page, pages: 1));
  }

  @override
  Future<Either<Failure, ({SupportTicketEntity ticket, List<SupportMessageEntity> messages})>>
      getTicketDetails(String ticketId) async {
    final ticket = mockTickets.firstWhere(
      (t) => t.id == ticketId,
      orElse: () => SupportTicketEntity(
        id: ticketId,
        ticketNumber: 'TKT-001',
        userId: 'u1',
        app: 'customer',
        category: 'other',
        subject: 'Test',
        description: 'Test',
      ),
    );
    return Right((ticket: ticket, messages: mockMessages));
  }

  @override
  Future<Either<Failure, SupportTicketEntity>> createTicket({
    required String app,
    required String category,
    required String subject,
    required String description,
    String? relatedOrderId,
    List<String>? attachments,
  }) async {
    final newTicket = SupportTicketEntity(
      id: 'ticket-new',
      ticketNumber: 'TKT-2026-0099',
      userId: 'user-1',
      app: app,
      category: category,
      subject: subject,
      description: description,
      status: 'open',
      priority: 'medium',
      relatedOrderId: relatedOrderId,
      createdAt: DateTime.now(),
    );
    mockTickets.add(newTicket);
    return Right(newTicket);
  }

  @override
  Future<Either<Failure, SupportMessageEntity>> replyTicket({
    required String ticketId,
    required String body,
    List<String>? attachments,
  }) async {
    final newMsg = SupportMessageEntity(
      id: 'msg-new',
      body: body,
      senderRole: 'user',
      createdAt: DateTime.now(),
    );
    mockMessages.add(newMsg);
    return Right(newMsg);
  }
}

void main() {
  group('Phase 1: Hero Banners Parameterization & Clean Architecture', () {
    test('ApiEndpoints.heroBannersForApp generates correct endpoints per app', () {
      expect(ApiEndpoints.heroBannersForApp('CUSTOMER'), equals('/hero-banners?app=CUSTOMER'));
      expect(ApiEndpoints.heroBannersForApp('RETAILER'), equals('/hero-banners?app=RETAILER'));
      expect(ApiEndpoints.heroBannersForApp('DELIVERY'), equals('/hero-banners?app=DELIVERY'));
    });

    test('HeroBannerModel deserializes app and timestamps accurately', () {
      final json = {
        '_id': 'banner_1',
        'title': 'Grand Monsoon Sale',
        'subtitle': 'Flat 50% Off Everything',
        'imageUrl': 'https://cdn.example.com/banner.png',
        'deepLink': '/category/monsoon',
        'displayOrder': 1,
        'isActive': true,
        'app': 'RETAILER',
        'createdAt': '2026-10-15T00:00:00.000Z',
        'updatedAt': '2026-10-15T01:00:00.000Z',
      };

      final model = HeroBannerModel.fromJson(json);
      expect(model.id, 'banner_1');
      expect(model.app, 'RETAILER');
      expect(model.createdAt, isNotNull);
      expect(model.updatedAt, isNotNull);
      expect(model.isActive, true);
    });
  });

  group('Phase 2: Coupons Domain & Data Models', () {
    test('CouponModel deserializes backend payload correctly', () {
      final json = {
        'code': 'QUICK100',
        'label': 'Save ₹100 on orders above ₹499',
        'description': 'Flat discount',
        'type': 'FIXED',
        'value': 100.0,
        'minOrder': 499.0,
        'maxDiscount': 100.0,
      };

      final model = CouponModel.fromJson(json);
      expect(model.code, 'QUICK100');
      expect(model.label, 'Save ₹100 on orders above ₹499');
      expect(model.type, 'FIXED');
      expect(model.value, 100.0);
      expect(model.minOrder, 499.0);
    });

    test('CouponValidationModel correctly deserializes valid and invalid responses', () {
      final validJson = {
        'code': 'SAVE20',
        'label': '20% OFF',
        'discount': 80.0,
        'freeDelivery': false,
        'minOrder': 200.0,
        'maxDiscount': 150.0,
      };

      final validModel = CouponValidationModel.fromJson(validJson);
      expect(validModel.isValid, true);
      expect(validModel.discount, 80.0);
      expect(validModel.code, 'SAVE20');
      expect(validModel.minOrder, 200.0);

      final invalidModel = CouponValidationModel.fromError(
        code: 'EXPIRED10',
        errorMessage: 'Minimum order amount of ₹499 required',
        errorCode: 'MIN_ORDER_NOT_MET',
      );

      expect(invalidModel.isValid, false);
      expect(invalidModel.discount, 0.0);
      expect(invalidModel.errorMessage, contains('Minimum order amount'));
      expect(invalidModel.errorCode, 'MIN_ORDER_NOT_MET');
    });
  });

  group('Phase 3: Customer Support Clean Architecture & BLoC', () {
    test('SupportTicketModel and SupportMessageModel parse backend json', () {
      final ticketJson = {
        '_id': 'tkt_abc',
        'ticketNumber': 'TKT-10023',
        'userId': 'usr_99',
        'app': 'customer',
        'category': 'order_issue',
        'subject': 'Order Delayed',
        'description': 'My order is 30 mins late',
        'status': 'open',
        'priority': 'high',
        'relatedOrderId': 'ord_555',
        'createdAt': '2026-10-15T05:00:00.000Z',
      };

      final ticketModel = SupportTicketModel.fromJson(ticketJson);
      expect(ticketModel.ticketNumber, 'TKT-10023');
      expect(ticketModel.isOpen, true);
      expect(ticketModel.priority, 'high');
      expect(ticketModel.relatedOrderId, 'ord_555');

      final msgJson = {
        '_id': 'msg_001',
        'body': 'We have alerted the courier rider.',
        'senderRole': 'agent',
        'isInternalNote': false,
        'createdAt': '2026-10-15T05:05:00.000Z',
      };

      final msgModel = SupportMessageModel.fromJson(msgJson);
      expect(msgModel.id, 'msg_001');
      expect(msgModel.isFromUser, false);
      expect(msgModel.senderRole, 'agent');
    });

    test('SupportBloc handles full ticket lifecycle: fetch, create, and send reply', () async {
      final mockRepo = MockSupportRepository();
      final bloc = SupportBloc(supportRepo: mockRepo);

      expect(bloc.state.isLoading, false);
      expect(bloc.state.tickets, isEmpty);

      // 1. Create Ticket
      bloc.add(const CreateSupportTicketEvent(
        app: 'customer',
        category: 'order_issue',
        subject: 'Missing item in basket',
        description: 'Milk 1L was missing',
      ));

      await expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<SupportState>((s) => s.isCreatingTicket == true),
          predicate<SupportState>((s) => s.isCreatingTicket == false && s.newlyCreatedTicket != null),
        ]),
      );

      expect(mockRepo.mockTickets.length, 1);
      final created = mockRepo.mockTickets.first;

      // 2. Fetch Tickets
      bloc.add(const FetchSupportTicketsEvent());
      await expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<SupportState>((s) => s.isLoading == true),
          predicate<SupportState>((s) => s.isLoading == false && s.tickets.length == 1),
        ]),
      );

      // 3. Select Ticket
      bloc.add(SelectTicketDetailsEvent(created.id));
      await expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<SupportState>((s) => s.isLoading == true),
          predicate<SupportState>((s) => s.isLoading == false && s.selectedTicket?.id == created.id),
        ]),
      );

      // 4. Send Reply (Re-opens if resolved per doc)
      bloc.add(ReplySupportTicketEvent(
        ticketId: created.id,
        body: 'Any update on this?',
      ));
      await expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<SupportState>((s) => s.isSendingReply == true),
          predicate<SupportState>((s) =>
              s.isSendingReply == false &&
              s.messages.isNotEmpty &&
              s.messages.last.body == 'Any update on this?'),
        ]),
      );

      await bloc.close();
    });
  });
}
