import 'package:image_picker/image_picker.dart';

enum GCashVerificationResult {
  verified,
  amountMismatch,
  alreadyUsed,
  notFound,
  unverified,
}

class GCashPaymentResult {
  final String refNo;
  final XFile? imageFile;
  final double? amount;

  GCashPaymentResult({
    required this.refNo,
    this.imageFile,
    this.amount,
  });
}

class GCashReceiptData {
  final String? refNo;
  final double? amount;
  final String rawText;
  final bool isOcrExtracted;
  final String? imagePath;

  GCashReceiptData({
    this.refNo,
    this.amount,
    required this.rawText,
    this.isOcrExtracted = false,
    this.imagePath,
  });
}

class GCashVerificationStatus {
  final GCashVerificationResult result;
  final String message;
  final String? adminRecordId;
  final String? usedInReceipt;
  final double? adminRecordAmount;

  GCashVerificationStatus({
    required this.result,
    required this.message,
    this.adminRecordId,
    this.usedInReceipt,
    this.adminRecordAmount,
  });

  bool get isVerified => result == GCashVerificationResult.verified;
}

class AdminGCashRecord {
  final String id;
  final String referenceNumber;
  final double amount;
  final bool isUsed;
  final String? usedInReceipt;
  final DateTime createdAt;

  AdminGCashRecord({
    required this.id,
    required this.referenceNumber,
    required this.amount,
    required this.isUsed,
    this.usedInReceipt,
    required this.createdAt,
  });

  factory AdminGCashRecord.fromJson(Map<String, dynamic> json) {
    return AdminGCashRecord(
      id: json['id']?.toString() ?? '',
      referenceNumber: json['reference_number']?.toString() ?? '',
      amount: (json['amount'] as num? ?? 0.0).toDouble(),
      isUsed: json['is_used'] == true,
      usedInReceipt: json['used_in_receipt']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'reference_number': referenceNumber,
    'amount': amount,
    'is_used': isUsed,
    'used_in_receipt': usedInReceipt,
    'created_at': createdAt.toIso8601String(),
  };
}
