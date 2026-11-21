import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quicklink/core/errors/failures.dart';
import 'package:quicklink/core/network/api_client.dart';
import 'package:quicklink/core/security/secure_storage_service.dart';
import 'package:quicklink/core/storage/local_cache_service.dart';
import 'package:quicklink/features/order/data/datasources/order_remote_data_source.dart';
import 'package:quicklink/features/order/data/repositories/order_repository_impl.dart';

class _FakeSecureStorage implements ISecureStorageService {
  @override
  Future<String?> getAccessToken() async => 'test-token';
  @override
  Future<String?> getRefreshToken() async => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeLocalCache implements ILocalCacheService {
  @override
  List<Map<String, dynamic>> getCachedActiveOrders() => [];
  @override
  Future<void> cacheActiveOrders(List<Map<String, dynamic>> orders) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubApiClient extends ApiClient {
  Response<dynamic>? nextResponse;
  Failure? nextFailure;
  Options? lastOptions;
  String? lastPath;

  _StubApiClient() : super(secureStorage: _FakeSecureStorage());

  @override
  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    lastPath = path;
    lastOptions = options;
    if (nextFailure != null) throw nextFailure!;
    return nextResponse!;
  }
}

void main() {
  group('Order Invoice Download Pipeline', () {
    late _StubApiClient apiClient;
    late OrderRemoteDataSourceImpl dataSource;
    late OrderRepositoryImpl repository;

    setUp(() {
      apiClient = _StubApiClient();
      dataSource = OrderRemoteDataSourceImpl(apiClient);
      repository = OrderRepositoryImpl(_FakeLocalCache(), dataSource);
    });

    test('returns valid PDF bytes and requests ResponseType.bytes with Accept PDF header', () async {
      final pdfBytes = Uint8List.fromList(utf8.encode('%PDF-1.4\n1 0 obj\n<<>>\nendobj\n%%EOF'));
      apiClient.nextResponse = Response(
        requestOptions: RequestOptions(path: '/orders/ord_1/invoice'),
        statusCode: 200,
        data: pdfBytes,
      );

      final result = await repository.downloadOrderInvoice('ord_1');
      expect(result.isRight(), true);
      result.fold(
        (l) => fail('Expected Right, got $l'),
        (r) => expect(r, pdfBytes),
      );
      expect(apiClient.lastPath, '/orders/ord_1/invoice');
      expect(apiClient.lastOptions?.responseType, ResponseType.bytes);
      expect(apiClient.lastOptions?.headers?['Accept'], contains('application/pdf'));
    });

    test('decodes base64 PDF wrapped in JSON response', () async {
      final pdfBytes = utf8.encode('%PDF-1.4\n%%EOF');
      final b64 = base64Encode(pdfBytes);
      final jsonBytes = Uint8List.fromList(utf8.encode(jsonEncode({
        'success': true,
        'data': {'pdf': b64},
      })));
      apiClient.nextResponse = Response(
        requestOptions: RequestOptions(path: '/orders/ord_2/invoice'),
        statusCode: 200,
        data: jsonBytes,
      );

      final result = await repository.downloadOrderInvoice('ord_2');
      expect(result.isRight(), true);
      result.fold(
        (l) => fail('Expected Right, got $l'),
        (r) => expect(r, pdfBytes),
      );
    });

    test('rejects JSON error payload returned with 200 bytes instead of saving corrupt PDF', () async {
      final errBytes = Uint8List.fromList(utf8.encode(jsonEncode({
        'success': false,
        'error': {'message': 'Invoice not generated yet'},
      })));
      apiClient.nextResponse = Response(
        requestOptions: RequestOptions(path: '/orders/ord_3/invoice'),
        statusCode: 200,
        data: errBytes,
      );

      final result = await repository.downloadOrderInvoice('ord_3');
      expect(result.isLeft(), true);
      result.fold(
        (l) => expect(l.message, 'Invoice not generated yet'),
        (r) => fail('Expected Left, got bytes'),
      );
    });

    test('rejects empty byte array', () async {
      apiClient.nextResponse = Response(
        requestOptions: RequestOptions(path: '/orders/ord_4/invoice'),
        statusCode: 200,
        data: Uint8List(0),
      );

      final result = await repository.downloadOrderInvoice('ord_4');
      expect(result.isLeft(), true);
      result.fold(
        (l) => expect(l.message, contains('empty')),
        (r) => fail('Expected Left'),
      );
    });

    test('preserves ServerFailure message without double wrapping', () async {
      apiClient.nextFailure = const ServerFailure(message: 'Order not found', statusCode: 404);

      final result = await repository.downloadOrderInvoice('missing');
      expect(result.isLeft(), true);
      result.fold(
        (l) => expect(l.message, 'Order not found'),
        (r) => fail('Expected Left'),
      );
    });

    test('parses order tax, taxBreakdown, discount, tip, and GSTIN snapshots from backend order JSON', () async {
      apiClient.nextResponse = Response(
        requestOptions: RequestOptions(path: '/orders'),
        statusCode: 200,
        data: {
          'success': true,
          'data': [
            {
              '_id': 'ord_tax_1',
              'orderNumber': 'QL-1001',
              'subtotal': 200.0,
              'deliveryFee': 20.0,
              'platformFee': 5.0,
              'couponDiscount': 15.0,
              'tip': 10.0,
              'taxBreakdown': {'cgst': 9.0, 'sgst': 9.0, 'igst': 0.0},
              'total': 238.0,
              'retailerGstinSnapshot': '29ABCDE1234F1Z5',
              'retailerStateSnapshot': 'Karnataka',
              'items': [],
            }
          ],
        },
      );

      final orders = await dataSource.getActiveOrders();
      expect(orders.length, 1);
      final order = orders.first;
      expect(order.tax, 18.0);
      expect(order.taxBreakdown.cgst, 9.0);
      expect(order.taxBreakdown.sgst, 9.0);
      expect(order.taxBreakdown.hasBreakdown, true);
      expect(order.discount, 15.0);
      expect(order.tip, 10.0);
      expect(order.retailerGstinSnapshot, '29ABCDE1234F1Z5');
      expect(order.retailerStateSnapshot, 'Karnataka');
      expect(order.grandTotal, 238.0);
    });
  });
}
