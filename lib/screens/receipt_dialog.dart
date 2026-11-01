import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../theme.dart';
import 'components/top_alert.dart';

class ReceiptDialog extends StatelessWidget {
  final TransactionRecord transaction;

  const ReceiptDialog({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '₱');
    final dateFormat = DateFormat('MMMM d, yyyy h:mm a');
    final isGCash = transaction.paymentMethod.toUpperCase() == 'GCASH';
    final screenWidth = MediaQuery.of(context).size.width;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: BoxConstraints(maxWidth: screenWidth * 0.9 > 400 ? 400 : screenWidth * 0.9),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.skyBlue.withValues(alpha: 0.4), width: 1.5),
          boxShadow: AppDesign.glassShadow,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Brand Banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.lightAqua,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        gradient: AppColors.cyanGradient,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.water_drop, color: AppColors.white, size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AQUASYNC WATER STATION',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            color: AppColors.primaryDarkNavy,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          'OFFICIAL SALES RECEIPT',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                            color: AppColors.electricCyan,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Transaction Meta Info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    _buildMetaRow('Date:', dateFormat.format(transaction.timestamp)),
                    const SizedBox(height: 4),
                    _buildMetaRow('Receipt #:', transaction.id, bold: true),
                    const SizedBox(height: 4),
                    _buildMetaRow('Cashier:', transaction.cashierName),
                    const SizedBox(height: 4),
                    _buildMetaRow('Payment Method:', transaction.paymentMethod, highlight: true),
                    if (isGCash && transaction.gcashRefNo != null && transaction.gcashRefNo!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      _buildMetaRow('GCash Ref:', transaction.gcashRefNo!, highlight: true),
                    ],
                    const SizedBox(height: 4),
                    _buildMetaRow('Fulfillment:', transaction.fulfillmentType.toLowerCase().contains('delivery') ? 'For Delivery' : 'Pick-up at Store', highlight: true),
                    if (transaction.customer != null) ...[
                      const SizedBox(height: 4),
                      _buildMetaRow('Customer:', transaction.customer!.fullName, success: true),
                      if (transaction.customer!.phone.isNotEmpty && transaction.customer!.phone != 'N/A') ...[
                        const SizedBox(height: 4),
                        _buildMetaRow('Phone:', transaction.customer!.phone),
                      ],
                      if (transaction.customer!.address != null && transaction.customer!.address!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        _buildMetaRow('Address:', transaction.customer!.address!),
                      ],
                    ],
                    if (transaction.notes != null && transaction.notes!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      _buildMetaRow('Notes:', transaction.notes!),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              const Divider(color: AppColors.border, thickness: 1.2),
              const SizedBox(height: 8),

              // Items Breakdown
              ...transaction.items.map((item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.product.name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.darkText),
                              ),
                              Text(
                                '${item.quantity} × ${currencyFormat.format(item.product.price)}',
                                style: const TextStyle(fontSize: 11, color: AppColors.grayText),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          currencyFormat.format(item.subtotal),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryDarkNavy),
                        ),
                      ],
                    ),
                  )),

              const SizedBox(height: 8),
              const Divider(color: AppColors.border, thickness: 1.2),
              const SizedBox(height: 12),

              // Summary Totals
              if (transaction.deliveryFee > 0 || transaction.discount > 0) ...[
                _buildReceiptRow('SUBTOTAL', currencyFormat.format(transaction.subtotal)),
                if (transaction.deliveryFee > 0) ...[
                  const SizedBox(height: 4),
                  _buildReceiptRow('DELIVERY FEE', currencyFormat.format(transaction.deliveryFee)),
                ],
                if (transaction.discount > 0) ...[
                  const SizedBox(height: 4),
                  _buildReceiptRow('DISCOUNT', '-${currencyFormat.format(transaction.discount)}'),
                ],
                const SizedBox(height: 6),
              ],

              _buildReceiptRow('TOTAL', currencyFormat.format(transaction.total), bold: true),
              const SizedBox(height: 6),
              if (isGCash) ...[
                _buildReceiptRow('Payment Status', 'PAID VIA GCASH', highlight: true),
              ] else ...[
                _buildReceiptRow('Cash Received', currencyFormat.format(transaction.cashReceived)),
                const SizedBox(height: 4),
                _buildReceiptRow('Change Given', currencyFormat.format(transaction.change), highlight: true),
              ],

              const SizedBox(height: 20),
              const Center(
                child: Text(
                  'Thank you for trusting AquaSync!',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: AppColors.electricCyan,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        TopAlert.show(
                          context,
                          'Receipt sent to thermal printer successfully!',
                          type: AlertType.success,
                          title: 'Printing Receipt',
                        );
                      },
                      icon: const Icon(Icons.print_rounded, size: 18),
                      label: const Text('PRINT'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: const BorderSide(color: AppColors.electricCyan),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.electricCyan,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('DONE'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetaRow(String label, String value, {bool bold = false, bool highlight = false, bool success = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.grayText)),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 11,
              fontWeight: bold || highlight || success ? FontWeight.bold : FontWeight.normal,
              color: success
                  ? AppColors.success
                  : highlight
                      ? AppColors.electricCyan
                      : AppColors.darkText,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReceiptRow(String label, String value, {bool bold = false, bool highlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontWeight: bold ? FontWeight.w900 : FontWeight.bold,
            fontSize: bold ? 15 : 12,
            color: bold ? AppColors.primaryDarkNavy : AppColors.grayText,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: bold ? FontWeight.w900 : FontWeight.bold,
            fontSize: bold ? 18 : 13,
            color: bold
                ? AppColors.electricCyan
                : highlight
                    ? AppColors.success
                    : AppColors.darkText,
          ),
        ),
      ],
    );
  }
}
