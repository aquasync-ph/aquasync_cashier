import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../models/gcash_models.dart';
import '../../providers/app_state.dart';
import '../../services/gcash_ocr_service.dart';
import '../../theme.dart';

class GCashPaymentDialog extends StatefulWidget {
  final double totalAmount;
  final String customerName;

  const GCashPaymentDialog({
    super.key,
    required this.totalAmount,
    required this.customerName,
  });

  @override
  State<GCashPaymentDialog> createState() => _GCashPaymentDialogState();
}

class _GCashPaymentDialogState extends State<GCashPaymentDialog> {
  final TextEditingController _refNoController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final GCashOcrService _ocrService = GCashOcrService();

  XFile? _selectedImage;
  bool _isProcessingOcr = false;
  bool _isOcrExtracted = false;
  bool _isVerifying = false;
  GCashVerificationStatus? _verificationStatus;

  bool _isLoadingSettings = true;

  static const Color gcashBlue = Color(0xFF005CE6);
  static const Color gcashDarkBlue = Color(0xFF003B99);
  static const Color gcashLightBlue = Color(0xFFF0F6FF);

  @override
  void initState() {
    super.initState();
    _amountController.text = widget.totalAmount.toStringAsFixed(2);
    _refNoController.addListener(_onRefNoChanged);
    _fetchLatestGCashSettings();
  }

  Future<void> _fetchLatestGCashSettings() async {
    setState(() => _isLoadingSettings = true);
    await context.read<AppState>().loadGCashSettings();
    if (mounted) {
      setState(() => _isLoadingSettings = false);
    }
  }

  @override
  void dispose() {
    _refNoController.removeListener(_onRefNoChanged);
    _refNoController.dispose();
    _amountController.dispose();
    _ocrService.dispose();
    super.dispose();
  }

  void _onRefNoChanged() {
    if (_refNoController.text.trim().length >= 8) {
      _verifyReference();
    } else {
      if (_verificationStatus != null) {
        setState(() {
          _verificationStatus = null;
        });
      }
    }
  }

  Future<void> _verifyReference() async {
    final refNo = _refNoController.text.trim();
    if (refNo.isEmpty) return;

    setState(() {
      _isVerifying = true;
    });

    final appState = context.read<AppState>();
    final amountPaid = double.tryParse(_amountController.text.trim()) ?? widget.totalAmount;
    final status = await appState.verifyGCashReference(refNo, amountPaid);

    if (mounted) {
      setState(() {
        _verificationStatus = status;
        _isVerifying = false;
      });
    }
  }

  Future<void> _pickAndProcessImage(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        imageQuality: 90,
      );

      if (file == null) return;

      setState(() {
        _selectedImage = file;
        _isProcessingOcr = true;
      });

      final GCashReceiptData ocrResult = await _ocrService.processImage(file);

      if (!mounted) return;

      setState(() {
        _isProcessingOcr = false;
        _isOcrExtracted = ocrResult.isOcrExtracted;

        if (ocrResult.refNo != null && ocrResult.refNo!.isNotEmpty) {
          _refNoController.text = ocrResult.refNo!;
        } else {
          _refNoController.clear();
        }

        if (ocrResult.amount != null && ocrResult.amount! > 0) {
          _amountController.text = ocrResult.amount!.toStringAsFixed(2);
        }
      });

      if (ocrResult.refNo != null && ocrResult.refNo!.isNotEmpty) {
        _verifyReference();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid image: Could not detect any GCash Reference Number from the photo.'),
            backgroundColor: AppColors.danger,
            duration: Duration(seconds: 4),
          ),
        );
        setState(() {
          _isOcrExtracted = false;
          _verificationStatus = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessingOcr = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to read receipt: ${e.toString()}'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final qrUrl = appState.gcashQrUrl;
    final gcashNumber = appState.gcashNumber;
    final accountName = appState.gcashAccountName;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 540),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: gcashBlue.withValues(alpha: 0.2),
              blurRadius: 32,
              offset: const Offset(0, 12),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // High-Tech Header Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [gcashBlue, gcashDarkBlue, Color(0xFF012273)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
                      ),
                      child: const Icon(Icons.qr_code_2_rounded, color: Colors.white, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'PAY VIA GCASH',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF34D399),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Customer: ${widget.customerName}',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Material(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: const CircleBorder(),
                      child: IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                        onPressed: () => Navigator.of(context).pop(null),
                        tooltip: 'Close',
                      ),
                    ),
                  ],
                ),
              ),

              // Scrollable Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Amount Display Banner (Guaranteed Responsive, Zero RenderFlex Overflow)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [gcashLightBlue, const Color(0xFFE2EDFF)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: gcashBlue.withValues(alpha: 0.25), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: gcashBlue.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'TOTAL AMOUNT TO PAY',
                                    style: TextStyle(
                                      color: gcashBlue,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      '₱${widget.totalAmount.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        color: gcashBlue,
                                        fontSize: 28,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF005CE6), Color(0xFF0040B0)],
                                ),
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: gcashBlue.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  )
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.verified_rounded, color: Colors.white, size: 16),
                                  SizedBox(width: 5),
                                  Text(
                                    'GCash Official',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),

                      // Admin GCash QR Display Card
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.border, width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            )
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: gcashLightBlue,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.storefront_rounded, color: gcashBlue, size: 18),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    accountName ?? 'Aqua Pure Water Station',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                      color: AppColors.darkText,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                            if (gcashNumber != null && gcashNumber.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: gcashLightBlue,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: gcashBlue.withValues(alpha: 0.2)),
                                ),
                                child: Text(
                                  'GCash No: $gcashNumber',
                                  style: const TextStyle(
                                    color: gcashBlue,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),

                            // QR Image Container with Glow & Border
                            Container(
                              width: 195,
                              height: 195,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: gcashBlue.withValues(alpha: 0.25), width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: gcashBlue.withValues(alpha: 0.1),
                                    blurRadius: 16,
                                    spreadRadius: 2,
                                  )
                                ],
                              ),
                              child: _isLoadingSettings
                                  ? const Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          SizedBox(
                                            width: 28,
                                            height: 28,
                                            child: CircularProgressIndicator(strokeWidth: 2.8, color: gcashBlue),
                                          ),
                                          SizedBox(height: 10),
                                          Text(
                                            'Loading Admin QR...',
                                            style: TextStyle(fontSize: 12, color: gcashBlue, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    )
                                  : ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: _buildQrImageWidget(qrUrl),
                                    ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.qr_code_scanner_rounded, color: AppColors.slate, size: 14),
                                const SizedBox(width: 5),
                                Text(
                                  'Scan this QR code using your GCash App',
                                  style: TextStyle(
                                    color: AppColors.slate,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // OCR Section Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: gcashLightBlue,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.document_scanner_rounded, color: gcashBlue, size: 20),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Scan GCash Receipt (OCR Auto-Extract)',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: AppColors.darkText,
                              ),
                            ),
                          ),
                          if (_isOcrExtracted)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.successLight,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.auto_awesome, color: AppColors.success, size: 14),
                                  SizedBox(width: 4),
                                  Text(
                                    'Auto-Filled',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.success,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Image Capture & Pick Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _isProcessingOcr ? null : () => _pickAndProcessImage(ImageSource.camera),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                side: const BorderSide(color: gcashBlue, width: 1.5),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                backgroundColor: gcashLightBlue.withValues(alpha: 0.5),
                              ),
                              icon: const Icon(Icons.camera_alt_rounded, color: gcashBlue, size: 18),
                              label: const Text(
                                'Take Photo',
                                style: TextStyle(color: gcashBlue, fontWeight: FontWeight.w800, fontSize: 13),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _isProcessingOcr ? null : () => _pickAndProcessImage(ImageSource.gallery),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                side: const BorderSide(color: gcashBlue, width: 1.5),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                backgroundColor: gcashLightBlue.withValues(alpha: 0.5),
                              ),
                              icon: const Icon(Icons.photo_library_rounded, color: gcashBlue, size: 18),
                              label: const Text(
                                'Pick Screenshot',
                                style: TextStyle(color: gcashBlue, fontWeight: FontWeight.w800, fontSize: 13),
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Image Preview & Loading Indicator
                      if (_isProcessingOcr) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: gcashLightBlue,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: gcashBlue.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2.5, color: gcashBlue),
                              ),
                              SizedBox(width: 12),
                              Flexible(
                                child: Text(
                                  'Extracting GCash receipt details via AI OCR...',
                                  style: TextStyle(
                                    color: gcashBlue,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else if (_selectedImage != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.file(
                                  File(_selectedImage!.path),
                                  width: 50,
                                  height: 50,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'Receipt photo attached. Ref No. and Amount successfully extracted.',
                                  style: TextStyle(fontSize: 12, color: AppColors.slate, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 18),

                      // Inputs Section
                      // Reference Number Input
                      TextField(
                        controller: _refNoController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                        decoration: InputDecoration(
                          labelText: 'GCash Reference Number (Ref No.)',
                          hintText: 'e.g. 1001 234 567 890',
                          prefixIcon: const Icon(Icons.numbers_rounded, color: gcashBlue),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: AppColors.border, width: 1.2),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: gcashBlue, width: 2),
                          ),
                          suffixIcon: _refNoController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 18),
                                  onPressed: () {
                                    _refNoController.clear();
                                    setState(() => _verificationStatus = null);
                                  },
                                )
                              : null,
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Amount Input
                      TextField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                        onChanged: (_) => _verifyReference(),
                        decoration: InputDecoration(
                          labelText: 'Amount Paid (₱)',
                          prefixIcon: const Icon(Icons.payments_rounded, color: gcashBlue),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: AppColors.border, width: 1.2),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: gcashBlue, width: 2),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Live Verification Result Box
                      if (_isVerifying) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: gcashLightBlue,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: gcashBlue.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: const [
                              SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: gcashBlue)),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Counter-checking reference with Admin list...',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: gcashBlue),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else if (_verificationStatus != null) ...[
                        _buildVerificationBadge(_verificationStatus!),
                      ],
                    ],
                  ),
                ),
              ),

              // Footer Action Buttons
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  border: const Border(top: BorderSide(color: AppColors.border, width: 1)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(null),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          side: const BorderSide(color: AppColors.border, width: 1.2),
                        ),
                        child: const Text('CANCEL', style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.slate, letterSpacing: 0.8)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: _canConfirmPayment() ? _submitPayment : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _canConfirmPayment() ? gcashBlue : Colors.grey.shade300,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: _canConfirmPayment() ? 4 : 0,
                          shadowColor: gcashBlue.withValues(alpha: 0.4),
                        ),
                        icon: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                        label: const FittedBox(
                          child: Text(
                            'CONFIRM PAYMENT',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _canConfirmPayment() {
    if (_refNoController.text.trim().isEmpty) return false;
    
    if (_verificationStatus != null) {
      if (_verificationStatus!.result == GCashVerificationResult.alreadyUsed) {
        return false;
      }
      return true;
    }
    
    return true;
  }

  Widget _buildQrImageWidget(String? qrUrl) {
    final gcashQrUrl = qrUrl ?? '';

    if (gcashQrUrl.isNotEmpty) {
      if (gcashQrUrl.startsWith('data:image')) {
        try {
          final parts = gcashQrUrl.split(',');
          if (parts.length > 1) {
            final bytes = base64Decode(parts.last);
            return Image.memory(
              bytes,
              width: 195,
              height: 195,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Text(
                'No QR Image set in Admin Database',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: AppColors.slate, fontWeight: FontWeight.bold),
              ),
            );
          }
        } catch (_) {}
      }
      return Image.network(
        gcashQrUrl,
        width: 195,
        height: 195,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => const Text(
          'No QR Image set in Admin Database',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: AppColors.slate, fontWeight: FontWeight.bold),
        ),
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          return const Center(child: CircularProgressIndicator(strokeWidth: 2, color: gcashBlue));
        },
      );
    } else {
      return const Text(
        'No QR Image set in Admin Database',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 11, color: AppColors.slate, fontWeight: FontWeight.bold),
      );
    }
  }

  Widget _buildVerificationBadge(GCashVerificationStatus status) {
    Color bgColor;
    Color borderColor;
    Color textColor;
    IconData icon;
    String title;

    switch (status.result) {
      case GCashVerificationResult.verified:
        bgColor = AppColors.successLight;
        borderColor = AppColors.success;
        textColor = AppColors.success;
        icon = Icons.verified_rounded;
        title = 'ADMIN MATCH VERIFIED';
        break;
      case GCashVerificationResult.amountMismatch:
        bgColor = AppColors.warningLight;
        borderColor = AppColors.warning;
        textColor = const Color(0xFFB45309);
        icon = Icons.warning_amber_rounded;
        title = 'AMOUNT MISMATCH';
        break;
      case GCashVerificationResult.alreadyUsed:
        bgColor = const Color(0xFFFEE2E2);
        borderColor = AppColors.danger;
        textColor = AppColors.danger;
        icon = Icons.error_outline_rounded;
        title = 'REFERENCE ALREADY USED';
        break;
      case GCashVerificationResult.notFound:
      case GCashVerificationResult.unverified:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: borderColor.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: textColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 12.5,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  status.message,
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _submitPayment() {
    final refNo = _refNoController.text.trim();
    if (refNo.isEmpty) return;

    if (_verificationStatus?.result == GCashVerificationResult.alreadyUsed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot proceed: This GCash Reference Number has already been used.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final double? parsedAmount = double.tryParse(_amountController.text.trim());

    Navigator.of(context).pop(
      GCashPaymentResult(
        refNo: refNo,
        imageFile: _selectedImage,
        amount: parsedAmount,
      ),
    );
  }
}
