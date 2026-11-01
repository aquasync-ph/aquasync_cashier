import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import '../models/gcash_models.dart';

class GCashOcrService {
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  Future<GCashReceiptData> processImage(XFile imageFile) async {
    try {
      final inputImage = InputImage.fromFilePath(imageFile.path);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
      
      final String rawText = recognizedText.text;
      debugPrint('--- OCR RECOGNIZED TEXT ---');
      debugPrint(rawText);
      debugPrint('---------------------------');

      final parsedData = extractGCashDetails(rawText);
      return GCashReceiptData(
        refNo: parsedData.refNo,
        amount: parsedData.amount,
        rawText: rawText,
        isOcrExtracted: true,
        imagePath: imageFile.path,
      );
    } catch (e) {
      debugPrint('Error processing GCash receipt OCR image: $e');
      return GCashReceiptData(
        rawText: 'Error reading image: $e',
        isOcrExtracted: false,
        imagePath: imageFile.path,
      );
    }
  }

  /// Parses raw text extracted from a GCash receipt screenshot or camera picture
  static GCashReceiptData extractGCashDetails(String rawText) {
    if (rawText.trim().isEmpty) {
      return GCashReceiptData(rawText: rawText);
    }

    final lines = rawText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    String? extractedRefNo;
    double? extractedAmount;

    // --- 1. EXTRACT REFERENCE NUMBER ---
    extractedRefNo = _extractRefNo(rawText, lines);

    // --- 2. EXTRACT AMOUNT ---
    extractedAmount = _extractAmount(rawText, lines);

    return GCashReceiptData(
      refNo: extractedRefNo,
      amount: extractedAmount,
      rawText: rawText,
      isOcrExtracted: extractedRefNo != null || extractedAmount != null,
    );
  }

  static String? _extractRefNo(String rawText, List<String> lines) {
    // Pattern A: Keyword explicit search (Ref No., Reference No., Ref No, Trans No, etc.)
    final refKeywordRegexes = [
      RegExp(r'Ref(?:\.|erence)?\s*(?:No|ID|#)?[\.\:]?\s*([0-9\s]{9,20})', caseSensitive: false),
      RegExp(r'Ref\s*([0-9\s]{9,20})', caseSensitive: false),
      RegExp(r'Transaction\s*(?:No|ID|#)?[\.\:]?\s*([0-9\s]{9,20})', caseSensitive: false),
      RegExp(r'Trans\s*(?:No|ID|#)?[\.\:]?\s*([0-9\s]{9,20})', caseSensitive: false),
    ];

    for (final regex in refKeywordRegexes) {
      final match = regex.firstMatch(rawText);
      if (match != null && match.groupCount >= 1) {
        final rawDigits = match.group(1)!.replaceAll(RegExp(r'\s+'), '');
        if (rawDigits.length >= 9 && rawDigits.length <= 18) {
          return rawDigits;
        }
      }
    }

    // Line by line search for "Ref No" line or line following "Ref No"
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lineLower = line.toLowerCase();

      if (lineLower.contains('ref') || lineLower.contains('reference') || lineLower.contains('trans')) {
        // Digits inside the same line
        final digitsInLine = RegExp(r'[0-9]{9,18}').firstMatch(line.replaceAll(' ', ''));
        if (digitsInLine != null) {
          return digitsInLine.group(0);
        }

        // Or in next line
        if (i + 1 < lines.length) {
          final nextLineDigits = RegExp(r'^[0-9\s]{9,20}$').firstMatch(lines[i + 1]);
          if (nextLineDigits != null) {
            final clean = nextLineDigits.group(0)!.replaceAll(' ', '');
            if (clean.length >= 9 && clean.length <= 18) {
              return clean;
            }
          }
        }
      }
    }

    // Pattern B: Fallback regex for standard 13-digit or 10-16 digit sequence in text
    final standaloneRefRegex = RegExp(r'\b(100[0-9]{10,13}|200[0-9]{10,13}|500[0-9]{10,13}|900[0-9]{10,13}|[0-9]{13})\b');
    final matchB = standaloneRefRegex.firstMatch(rawText.replaceAll(' ', ''));
    if (matchB != null) {
      return matchB.group(0);
    }

    // Pattern C: Any group of 10 to 16 continuous digits
    final genericDigitGroup = RegExp(r'\b([0-9]{10,16})\b');
    final matchC = genericDigitGroup.firstMatch(rawText);
    if (matchC != null) {
      return matchC.group(1);
    }

    return null;
  }

  static double? _extractAmount(String rawText, List<String> lines) {
    // Keywords for amount
    final amountKeywords = [
      RegExp(r'(?:Amount|Total|Paid|Send|Amount Paid|Total Amount)\s*[\:\=]?\s*(?:PHP|Php|₱)?\s*([0-9\,]+\.[0-9]{2})', caseSensitive: false),
      RegExp(r'(?:PHP|Php|₱)\s*([0-9\,]+\.[0-9]{2})', caseSensitive: false),
      RegExp(r'(?:PHP|Php|₱)\s*([0-9\,]+)', caseSensitive: false),
    ];

    for (final regex in amountKeywords) {
      final match = regex.firstMatch(rawText);
      if (match != null && match.groupCount >= 1) {
        final amountStr = match.group(1)!.replaceAll(',', '');
        final val = double.tryParse(amountStr);
        if (val != null && val > 0) {
          return val;
        }
      }
    }

    // Search line by line for lines containing PHP / ₱ / Amount
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lineLower = line.toLowerCase();

      if (lineLower.contains('amount') || lineLower.contains('php') || lineLower.contains('₱') || lineLower.contains('paid')) {
        final numberMatch = RegExp(r'([0-9]{1,6}(?:\.[0-9]{2})?)').firstMatch(line.replaceAll('PHP', '').replaceAll('Php', '').replaceAll('₱', '').replaceAll(',', ''));
        if (numberMatch != null) {
          final val = double.tryParse(numberMatch.group(1)!);
          if (val != null && val > 0 && val < 100000) {
            return val;
          }
        }
      }
    }

    // Fallback search for any decimal pattern e.g. 35.00, 150.00
    final decimalRegex = RegExp(r'\b([0-9]{1,5}\.[0-9]{2})\b');
    final matches = decimalRegex.allMatches(rawText);
    for (final m in matches) {
      final val = double.tryParse(m.group(1)!);
      if (val != null && val > 0 && val < 50000) {
        return val;
      }
    }

    return null;
  }

  void dispose() {
    _textRecognizer.close();
  }
}
