import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_state.dart';
import '../theme.dart';
import 'receipt_dialog.dart';

class TransactionHistoryDialog extends StatelessWidget {
  const TransactionHistoryDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final currencyFormat = NumberFormat.currency(symbol: '₱');
    final dateFormat = DateFormat('MMM d, h:mm a');

    final totalSales = appState.transactions.fold(0.0, (sum, tx) => sum + tx.total);
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: screenWidth * 0.92 > 600 ? 600 : screenWidth * 0.92, 
          maxHeight: screenHeight * 0.85 > 700 ? 700 : screenHeight * 0.85
        ),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.skyBlue.withValues(alpha: 0.4), width: 1.5),
          boxShadow: AppDesign.glassShadow,
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.lightAqua,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.receipt_long_rounded, color: AppColors.electricCyan, size: 22),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Daily Sales & History',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryDarkNavy,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.grayText),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Today's Sales Summary Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: AppColors.premiumGradient,
                borderRadius: BorderRadius.circular(18),
                boxShadow: AppDesign.glowingShadow,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      const Text(
                        'Total Transactions',
                        style: TextStyle(fontSize: 11, color: AppColors.lightGrayText, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${appState.transactions.length}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.white,
                        ),
                      ),
                    ],
                  ),
                  Container(height: 32, width: 1, color: AppColors.borderDark),
                  Column(
                    children: [
                      const Text(
                        'Total Sales Today',
                        style: TextStyle(fontSize: 11, color: AppColors.lightGrayText, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        currencyFormat.format(totalSales),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.skyBlue,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Expanded(
              child: appState.transactions.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long_outlined, size: 48, color: AppColors.lightGrayText),
                          SizedBox(height: 12),
                          Text(
                            'No sales recorded today',
                            style: TextStyle(color: AppColors.grayText, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: appState.transactions.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final tx = appState.transactions[index];
                        final isGCash = tx.paymentMethod.toUpperCase() == 'GCASH';

                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: isGCash ? const Color(0xFF005CE6).withValues(alpha: 0.1) : AppColors.lightAqua,
                                child: Icon(
                                  isGCash ? Icons.qr_code_rounded : Icons.receipt_rounded,
                                  color: isGCash ? const Color(0xFF005CE6) : AppColors.electricCyan,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          tx.id,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: isGCash ? const Color(0xFF005CE6).withValues(alpha: 0.15) : AppColors.lightAqua,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            tx.paymentMethod.toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: isGCash ? const Color(0xFF005CE6) : AppColors.electricCyan,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      '${dateFormat.format(tx.timestamp)} • ${tx.items.length} item(s)',
                                      style: const TextStyle(fontSize: 11, color: AppColors.grayText),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    currencyFormat.format(tx.total),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: AppColors.electricCyan,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    icon: const Icon(Icons.visibility_outlined, color: AppColors.grayText, size: 20),
                                    tooltip: 'View Receipt',
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (_) => ReceiptDialog(transaction: tx),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
