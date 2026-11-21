import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:quicklink/core/network/api_endpoints.dart';
import 'package:quicklink/features/customer/data/models/product_model.dart';
import 'package:quicklink/features/auth/data/datasources/auth_remote_data_source.dart';

void main() {
  group('Live Backend API Verification (QuickClick v1.0 Spec)', () {
    late Dio dio;

    setUp(() {
      dio = Dio(BaseOptions(
        baseUrl: ApiEndpoints.baseUrl,
        connectTimeout: const Duration(seconds: 35),
        receiveTimeout: const Duration(seconds: 35),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ));
    });

    test('1. GET /products hits live server and returns 200 OK', () async {
      final response = await dio.get(ApiEndpoints.products);
      expect(response.statusCode, 200);
      expect(response.data, isA<Map>());
      print('GET /products response: ${response.data}');
    });

    test('2. GET /products/featured returns 200 OK and deserializes into ProductModel', () async {
      final response = await dio.get(ApiEndpoints.productsFeatured);
      expect(response.statusCode, 200);
      expect(response.data, isA<Map>());
      final data = response.data['data'];
      if (data is Map) {
        final product = ProductModel.fromJson(Map<String, dynamic>.from(data));
        expect(product.name, isNotEmpty);
        print('Featured Product parsed successfully: ${product.name} (id: ${product.id})');
      }
    });

    test('3. GET /products/search?q=milk returns 200 OK and deserializes into ProductModel', () async {
      final response = await dio.get(ApiEndpoints.productsSearch, queryParameters: {'q': 'milk'});
      expect(response.statusCode, 200);
      expect(response.data, isA<Map>());
      final data = response.data['data'];
      if (data is Map) {
        final product = ProductModel.fromJson(Map<String, dynamic>.from(data));
        expect(product.name, isNotEmpty);
        print('Search Product parsed successfully: ${product.name}');
      }
    });

    test('4. POST /auth/send-otp sends mobile in E.164 and receives challengeId', () async {
      final response = await dio.post(ApiEndpoints.sendOtp, data: {
        'mobile': '+919999999999',
        'purpose': 'LOGIN',
      });
      expect(response.statusCode, 200);
      final model = SendOtpResponseModel.fromJson(response.data);
      expect(model.success, isTrue);
      expect(model.challengeId, isNotNull);
      print('Send-OTP response parsed: challengeId=${model.challengeId}');
    });

    test('5. GET /zones/serviceability returns 200 OK', () async {
      final response = await dio.get(ApiEndpoints.zonesServiceability, queryParameters: {
        'pincode': '560038',
        'lat': 12.9716,
        'lng': 77.5946,
      });
      expect(response.statusCode, 200);
      expect(response.data['success'], isTrue);
      print('Zones Serviceability response: ${response.data}');
    });

    test('6. Unauthenticated protected endpoints correctly return 401', () async {
      try {
        await dio.get(ApiEndpoints.userMe);
        fail('Should have thrown DioException with 401');
      } on DioException catch (e) {
        expect(e.response?.statusCode, 401);
        print('Expected 401 verified for unauthenticated /users/me: ${e.response?.data}');
      }
    });
  });
}
