import 'dart:convert';
import 'dart:typed_data';
import '../../features/order/domain/entities/order_entity.dart';

/// Pure Dart zero-dependency compliant PDF 1.4 Tax Invoice generator.
/// Generates authentic, valid vector PDF documents viewable in any PDF reader.
class InvoicePdfGenerator {
  InvoicePdfGenerator._();

  static Uint8List generate(OrderEntity order) {
    final buffer = StringBuffer();

    // Collect drawing operations into content stream
    final stream = StringBuffer();

    void rect(double x, double y, double w, double h, double r, double g, double b) {
      stream.writeln('${r.toStringAsFixed(3)} ${g.toStringAsFixed(3)} ${b.toStringAsFixed(3)} rg');
      stream.writeln('${x.toStringAsFixed(2)} ${y.toStringAsFixed(2)} ${w.toStringAsFixed(2)} ${h.toStringAsFixed(2)} re f');
    }

    void line(double x1, double y1, double x2, double y2, double r, double g, double b, [double width = 1.0]) {
      stream.writeln('${r.toStringAsFixed(3)} ${g.toStringAsFixed(3)} ${b.toStringAsFixed(3)} RG');
      stream.writeln('$width w');
      stream.writeln('${x1.toStringAsFixed(2)} ${y1.toStringAsFixed(2)} m ${x2.toStringAsFixed(2)} ${y2.toStringAsFixed(2)} l S');
    }

    void text(String raw, double x, double y, {bool isBold = false, double size = 10, double r = 0.1, double g = 0.1, double b = 0.1}) {
      final safeText = _sanitize(raw);
      final font = isBold ? '/F2' : '/F1';
      stream.writeln('BT');
      stream.writeln('$font ${size.toStringAsFixed(1)} Tf');
      stream.writeln('${r.toStringAsFixed(3)} ${g.toStringAsFixed(3)} ${b.toStringAsFixed(3)} rg');
      stream.writeln('${x.toStringAsFixed(2)} ${y.toStringAsFixed(2)} Td');
      stream.writeln('($safeText) Tj');
      stream.writeln('ET');
    }

    // A4 Dimensions: 595.28 x 841.89 pt
    const pageWidth = 595.28;
    const pageHeight = 841.89;
    const margin = 40.0;
    final contentWidth = pageWidth - (margin * 2);

    // 1. Header Banner (Deep Emerald Teal: #0F766E -> 0.059, 0.463, 0.431)
    rect(margin, pageHeight - 110, contentWidth, 70, 0.059, 0.463, 0.431);
    text('QUICK TICK', margin + 16, pageHeight - 72, isBold: true, size: 22, r: 1, g: 1, b: 1);
    text('15-Minute Grocery & Essentials Delivery', margin + 16, pageHeight - 92, isBold: false, size: 10, r: 0.85, g: 0.95, b: 0.93);
    text('TAX INVOICE', pageWidth - margin - 110, pageHeight - 68, isBold: true, size: 14, r: 1, g: 1, b: 1);
    text('Original for Recipient', pageWidth - margin - 110, pageHeight - 86, isBold: false, size: 9, r: 0.85, g: 0.95, b: 0.93);

    // 2. Order & Customer Info Grid
    double curY = pageHeight - 135;
    rect(margin, curY - 70, contentWidth, 75, 0.97, 0.98, 0.99);
    line(margin, curY - 70, pageWidth - margin, curY - 70, 0.88, 0.91, 0.94);
    line(margin, curY + 5, pageWidth - margin, curY + 5, 0.88, 0.91, 0.94);

    final displayOrderNum = order.orderNumber.isNotEmpty ? order.orderNumber : order.id;
    final dateStr = '${order.createdAt.year}-${_twoDigits(order.createdAt.month)}-${_twoDigits(order.createdAt.day)} ${_twoDigits(order.createdAt.hour)}:${_twoDigits(order.createdAt.minute)}';

    text('Order Details', margin + 12, curY - 12, isBold: true, size: 10, r: 0.06, g: 0.46, b: 0.43);
    text('Invoice / Order No: #$displayOrderNum', margin + 12, curY - 28, isBold: false, size: 9);
    text('Date & Time: $dateStr', margin + 12, curY - 42, isBold: false, size: 9);
    text('Payment Mode: ${_cleanText(order.paymentMethod.toUpperCase())} (${order.paymentStatus.toUpperCase()})', margin + 12, curY - 56, isBold: false, size: 9);

    final midX = margin + (contentWidth / 2) + 10;
    text('Store & Delivery Details', midX, curY - 12, isBold: true, size: 10, r: 0.06, g: 0.46, b: 0.43);
    text('Sold By: ${_cleanText(order.storeName.isNotEmpty ? order.storeName : "QuickTick Partner Store")}', midX, curY - 28, isBold: false, size: 9);
    final safeAddr = _truncate(_cleanText(order.deliveryAddress), 45);
    text('Delivery Address: $safeAddr', midX, curY - 42, isBold: false, size: 9);
    text('Order Status: ${order.status.label}', midX, curY - 56, isBold: false, size: 9);

    // 3. Items Table Header
    curY -= 95;
    rect(margin, curY - 20, contentWidth, 24, 0.059, 0.463, 0.431);
    text('SL', margin + 8, curY - 13, isBold: true, size: 9, r: 1, g: 1, b: 1);
    text('ITEM DESCRIPTION', margin + 35, curY - 13, isBold: true, size: 9, r: 1, g: 1, b: 1);
    text('QTY', margin + 290, curY - 13, isBold: true, size: 9, r: 1, g: 1, b: 1);
    text('PRICE (INR)', margin + 350, curY - 13, isBold: true, size: 9, r: 1, g: 1, b: 1);
    text('TOTAL (INR)', pageWidth - margin - 85, curY - 13, isBold: true, size: 9, r: 1, g: 1, b: 1);

    // 4. Items Table Rows
    curY -= 20;
    int idx = 1;
    for (final item in order.items) {
      if (curY < 180) break; // Keep space for totals & footer
      final isEven = (idx % 2 == 0);
      if (isEven) {
        rect(margin, curY - 18, contentWidth, 20, 0.98, 0.98, 0.99);
      }
      line(margin, curY - 18, pageWidth - margin, curY - 18, 0.92, 0.93, 0.95, 0.5);

      final itemName = _truncate(_cleanText(item.nameSnapshot), 38);
      final itemPrice = item.priceSnapshot.toStringAsFixed(2);
      final itemTotal = (item.serverTotal ?? (item.priceSnapshot * item.quantity)).toStringAsFixed(2);

      text('$idx', margin + 8, curY - 12, size: 8.5, r: 0.4, g: 0.4, b: 0.4);
      text(itemName, margin + 35, curY - 12, size: 8.5, isBold: true);
      text('${item.quantity} ${item.unit}', margin + 290, curY - 12, size: 8.5);
      text(itemPrice, margin + 350, curY - 12, size: 8.5);
      text(itemTotal, pageWidth - margin - 85, curY - 12, size: 8.5, isBold: true);

      curY -= 20;
      idx++;
    }

    // 5. Bill Summary Breakdown (Right Aligned)
    curY -= 15;
    line(margin, curY + 5, pageWidth - margin, curY + 5, 0.8, 0.85, 0.9, 1.0);

    final summaryXLabel = pageWidth - margin - 220;
    final summaryXVal = pageWidth - margin - 75;

    void summaryRow(String label, double amount, {bool isGrandTotal = false, bool isDiscount = false}) {
      if (curY < 120) return;
      if (isGrandTotal) {
        rect(summaryXLabel - 10, curY - 18, 230, 22, 0.059, 0.463, 0.431);
        text(label, summaryXLabel, curY - 12, isBold: true, size: 10, r: 1, g: 1, b: 1);
        text('INR ${amount.toStringAsFixed(2)}', summaryXVal - 25, curY - 12, isBold: true, size: 10, r: 1, g: 1, b: 1);
      } else {
        text(label, summaryXLabel, curY - 12, isBold: false, size: 9, r: 0.35, g: 0.35, b: 0.35);
        final prefix = isDiscount ? '- INR ' : 'INR ';
        text('$prefix${amount.toStringAsFixed(2)}', summaryXVal - 25, curY - 12, isBold: isDiscount, size: 9, r: isDiscount ? 0.06 : 0.2, g: isDiscount ? 0.55 : 0.2, b: isDiscount ? 0.35 : 0.2);
      }
      curY -= 18;
    }

    summaryRow('Items Subtotal:', order.subtotal);
    if (order.deliveryFee > 0) summaryRow('Delivery Partner Fee:', order.deliveryFee);
    if (order.tax > 0) summaryRow('Taxes & Packaging Charges:', order.tax);
    if (order.discount > 0) summaryRow('Promotional Discount:', order.discount, isDiscount: true);
    if (order.tip > 0) summaryRow('Delivery Tip:', order.tip);
    curY -= 4;
    summaryRow('GRAND TOTAL:', order.grandTotal, isGrandTotal: true);

    // 6. Footer Notes & Support Info
    rect(margin, 40, contentWidth, 48, 0.96, 0.97, 0.98);
    line(margin, 88, pageWidth - margin, 88, 0.88, 0.9, 0.92);
    text('Thank you for ordering with QuickTick!', margin + 14, 72, isBold: true, size: 9, r: 0.06, g: 0.46, b: 0.43);
    text('This is a computer-generated tax invoice. No signature required.', margin + 14, 58, size: 8, r: 0.5, g: 0.5, b: 0.5);
    text('Customer Support: support@quicktick.shop | Helpline: 1800-QUICK-TICK', margin + 14, 46, size: 8, r: 0.5, g: 0.5, b: 0.5);

    final streamBytes = utf8.encode(stream.toString());

    // Construct valid PDF 1.4 objects
    final offsets = <int>[];
    buffer.write('%PDF-1.4\n');

    void writeObj(int id, String content) {
      offsets.add(buffer.length);
      buffer.write('$id 0 obj\n$content\nendobj\n');
    }

    writeObj(1, '<< /Type /Catalog /Pages 2 0 R >>');
    writeObj(2, '<< /Type /Pages /Kids [3 0 R] /Count 1 >>');
    writeObj(3, '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595.28 841.89] /Resources << /Font << /F1 4 0 R /F2 5 0 R >> >> /Contents 6 0 R >>');
    writeObj(4, '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>');
    writeObj(5, '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold >>');

    offsets.add(buffer.length);
    buffer.write('6 0 obj\n<< /Length ${streamBytes.length} >>\nstream\n');
    buffer.write(stream.toString());
    buffer.write('\nendstream\nendobj\n');

    final startXref = buffer.length;
    buffer.write('xref\n0 7\n0000000000 65535 f \n');
    for (final off in offsets) {
      buffer.write('${off.toString().padLeft(10, '0')} 00000 n \n');
    }
    buffer.write('trailer\n<< /Size 7 /Root 1 0 R >>\nstartxref\n$startXref\n%%EOF');

    return Uint8List.fromList(utf8.encode(buffer.toString()));
  }

  static String _twoDigits(int n) => n.toString().padLeft(2, '0');

  static String _cleanText(String input) {
    return input.replaceAll(RegExp(r'[^\x20-\x7E]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String _truncate(String input, int maxLen) {
    if (input.length <= maxLen) return input;
    return '${input.substring(0, maxLen - 3)}...';
  }

  static String _sanitize(String s) {
    return s.replaceAll('\\', '\\\\').replaceAll('(', '\\(').replaceAll(')', '\\)');
  }
}

