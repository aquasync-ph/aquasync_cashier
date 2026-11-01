import 'package:flutter_test/flutter_test.dart';
import 'package:aquasync_cashier_app/services/gcash_ocr_service.dart';

void main() {
  group('GCash OCR Receipt Text Extraction Tests', () {
    test('Extracts Reference Number and Amount from standard GCash Send Money receipt text', () {
      const sampleText = '''
GCash
Express Send
Successfully Sent to
JUAN DELA CRUZ
0917 *** 4567

Amount
PHP 35.00

Ref No. 1001 234 567 890
Jul 25, 2024 03:15 PM
''';

      final result = GCashOcrService.extractGCashDetails(sampleText);

      expect(result.refNo, equals('1001234567890'));
      expect(result.amount, equals(35.0));
      expect(result.isOcrExtracted, isTrue);
    });

    test('Extracts Reference Number starting with 200/500 and symbol amount', () {
      const sampleText = '''
Payment Received
Merchant: AquaSync Station
Ref No: 2009876543210
Total Paid: ₱150.00
''';

      final result = GCashOcrService.extractGCashDetails(sampleText);

      expect(result.refNo, equals('2009876543210'));
      expect(result.amount, equals(150.0));
      expect(result.isOcrExtracted, isTrue);
    });

    test('Handles receipt with formatted commas in amount', () {
      const sampleText = '''
Transaction Successful
Reference No. 5001234567891
Amount: Php 1,250.00
''';

      final result = GCashOcrService.extractGCashDetails(sampleText);

      expect(result.refNo, equals('5001234567891'));
      expect(result.amount, equals(1250.0));
      expect(result.isOcrExtracted, isTrue);
    });
  });
}
