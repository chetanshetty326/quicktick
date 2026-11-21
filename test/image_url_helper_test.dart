import 'package:flutter_test/flutter_test.dart';
import 'package:quicklink/core/utils/image_url_helper.dart';

void main() {
  group('ImageUrlHelper Tests', () {
    test('Injects auto-format and auto-quality into standard Cloudinary URL', () {
      const original = 'https://res.cloudinary.com/quickclick/image/upload/v12345/apple.jpg';
      final optimized = ImageUrlHelper.optimize(original, width: 300);

      expect(optimized, 'https://res.cloudinary.com/quickclick/image/upload/w_300,q_auto,f_auto/v12345/apple.jpg');
    });

    test('Injects width and height when height is provided', () {
      const original = 'https://res.cloudinary.com/quickclick/image/upload/v12345/banana.jpg';
      final optimized = ImageUrlHelper.optimize(original, width: 200, height: 200);

      expect(optimized, 'https://res.cloudinary.com/quickclick/image/upload/c_fill,w_200,h_200,q_auto,f_auto/v12345/banana.jpg');
    });

    test('Does not duplicate parameters if already optimized', () {
      const alreadyOptimized = 'https://res.cloudinary.com/quickclick/image/upload/w_300,q_auto,f_auto/v12345/milk.jpg';
      final result = ImageUrlHelper.optimize(alreadyOptimized, width: 300);

      expect(result, alreadyOptimized);
    });

    test('Leaves non-Cloudinary URLs unmodified', () {
      const s3Url = 'https://s3.amazonaws.com/quickclick-bucket/images/bread.png';
      expect(ImageUrlHelper.optimize(s3Url), s3Url);
    });

    test('Safely handles null and empty URLs', () {
      expect(ImageUrlHelper.optimize(null), '');
      expect(ImageUrlHelper.optimize('   '), '');
    });
  });
}
