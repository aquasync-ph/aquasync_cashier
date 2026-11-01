import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../models/gcash_models.dart';
import '../../providers/app_state.dart';
import '../../theme.dart';

class AdminGCashManagerDialog extends StatefulWidget {
  const AdminGCashManagerDialog({super.key});

  @override
  State<AdminGCashManagerDialog> createState() => _AdminGCashManagerDialogState();
}

class _AdminGCashManagerDialogState extends State<AdminGCashManagerDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Settings tab controllers
  final TextEditingController _qrUrlController = TextEditingController();
  final TextEditingController _numberController = TextEditingController();
  final TextEditingController _accountNameController = TextEditingController();

  // Batch import controller
  final TextEditingController _singleRefController = TextEditingController();
  final TextEditingController _singleAmountController = TextEditingController();
  final TextEditingController _batchInputController = TextEditingController();

  bool _isSaving = false;
  List<AdminGCashRecord> _adminRecords = [];

  static const Color gcashBlue = Color(0xFF005CE6);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    final appState = context.read<AppState>();
    _qrUrlController.text = appState.gcashQrUrl ?? '';
    _numberController.text = appState.gcashNumber ?? '';
    _accountNameController.text = appState.gcashAccountName ?? '';

    _loadRecords();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _qrUrlController.dispose();
    _numberController.dispose();
    _accountNameController.dispose();
    _singleRefController.dispose();
    _singleAmountController.dispose();
    _batchInputController.dispose();
    super.dispose();
  }

  Future<void> _loadRecords() async {
    final appState = context.read<AppState>();
    final records = await appState.fetchAdminGCashRecords();
    if (mounted) {
      setState(() {
        _adminRecords = records;
      });
    }
  }

  Future<void> _pickQrImageFile() async {
    try {
      final picker = ImagePicker();
      final XFile? file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (file == null) return;

      final bytes = await file.readAsBytes();
      final base64Str = base64Encode(bytes);
      final dataUrl = 'data:image/png;base64,$base64Str';

      setState(() {
        _qrUrlController.text = dataUrl;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('QR code image selected! Click SAVE GCASH STORE SETTINGS below.'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking QR image: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    final appState = context.read<AppState>();

    try {
      await appState.updateGCashSettings(
        qrUrl: _qrUrlController.text.trim(),
        number: _numberController.text.trim(),
        accountName: _accountNameController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('GCash store settings saved successfully!'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving settings: $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _addSingleRecord() async {
    final ref = _singleRefController.text.trim();
    final amount = double.tryParse(_singleAmountController.text.trim()) ?? 0.0;

    if (ref.isEmpty || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid Reference Number and Amount'), backgroundColor: AppColors.warning),
      );
      return;
    }

    setState(() => _isSaving = true);
    final appState = context.read<AppState>();

    try {
      await appState.addAdminGCashRecord(ref, amount);
      _singleRefController.clear();
      _singleAmountController.clear();
      await _loadRecords();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added GCash Ref: $ref (₱${amount.toStringAsFixed(2)})'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding record: $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _processBatchImport() async {
    final rawText = _batchInputController.text.trim();
    if (rawText.isEmpty) return;

    final lines = rawText.split('\n');
    final List<Map<String, dynamic>> batch = [];

    for (var line in lines) {
      final parts = line.split(RegExp(r'[\,\t\:]+'));
      if (parts.length >= 2) {
        final ref = parts[0].replaceAll(' ', '').trim();
        final amtStr = parts[1].replaceAll('₱', '').replaceAll('PHP', '').replaceAll(',', '').trim();
        final amt = double.tryParse(amtStr);
        if (ref.isNotEmpty && amt != null && amt > 0) {
          batch.add({'reference_number': ref, 'amount': amt});
        }
      }
    }

    if (batch.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No valid records found in batch text. Format: RefNo, Amount'), backgroundColor: AppColors.warning),
      );
      return;
    }

    setState(() => _isSaving = true);
    final appState = context.read<AppState>();

    try {
      await appState.uploadBatchGCashRecords(batch);
      _batchInputController.clear();
      await _loadRecords();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Successfully imported ${batch.length} GCash records!'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error importing batch: $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildPreviewQrImage(String text) {
    final trimmed = text.trim();
    if (trimmed.startsWith('data:image')) {
      try {
        final parts = trimmed.split(',');
        if (parts.length > 1) {
          final bytes = base64Decode(parts.last);
          return Image.memory(bytes, fit: BoxFit.contain);
        }
      } catch (_) {}
      return const Text('Invalid image data', style: TextStyle(color: AppColors.danger));
    } else {
      return Image.network(
        trimmed,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => const Text('Invalid image URL', style: TextStyle(color: AppColors.danger)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 600,
        height: 680,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: gcashBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.admin_panel_settings_rounded, color: gcashBlue, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Admin GCash & Verification Manager',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.darkText),
                      ),
                      Text(
                        'Manage QR Code & Pre-upload expected payments',
                        style: TextStyle(fontSize: 12, color: AppColors.slate),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Tab Bar
            TabBar(
              controller: _tabController,
              labelColor: gcashBlue,
              unselectedLabelColor: AppColors.slate,
              indicatorColor: gcashBlue,
              tabs: const [
                Tab(icon: Icon(Icons.qr_code_2_rounded), text: 'Store QR & Details'),
                Tab(icon: Icon(Icons.list_alt_rounded), text: 'Uploaded GCash Ref Records'),
              ],
            ),

            const SizedBox(height: 16),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: QR & Account Settings
                  SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _accountNameController,
                          decoration: InputDecoration(
                            labelText: 'GCash Account / Store Name',
                            hintText: 'e.g. AquaSync Water Station',
                            prefixIcon: const Icon(Icons.storefront_rounded, color: gcashBlue),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _numberController,
                          decoration: InputDecoration(
                            labelText: 'GCash Mobile Number',
                            hintText: 'e.g. 0917 123 4567',
                            prefixIcon: const Icon(Icons.phone_iphone_rounded, color: gcashBlue),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _qrUrlController,
                          decoration: InputDecoration(
                            labelText: 'GCash QR Image Public URL or Data',
                            hintText: 'https://... or data:image/...',
                            prefixIcon: const Icon(Icons.link_rounded, color: gcashBlue),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _pickQrImageFile,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: const BorderSide(color: gcashBlue),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.photo_library_rounded, color: gcashBlue),
                          label: const Text('📷 Choose QR Code Image File from Device', style: TextStyle(color: gcashBlue, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(height: 16),
                        if (_qrUrlController.text.isNotEmpty) ...[
                          Container(
                            height: 160,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: _buildPreviewQrImage(_qrUrlController.text),
                          ),
                          const SizedBox(height: 16),
                        ],
                        ElevatedButton.icon(
                          onPressed: _isSaving ? null : _saveSettings,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: gcashBlue,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.save_rounded, color: Colors.white),
                          label: const Text('SAVE GCASH STORE SETTINGS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),

                  // Tab 2: GCash Reference Records Management
                  Column(
                    children: [
                      // Single & Batch Input Form
                      ExpansionTile(
                        title: const Text('Upload / Add Reference Numbers', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: const Text('Add reference numbers to auto counter-check cashier payments', style: TextStyle(fontSize: 11)),
                        initiallyExpanded: true,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: TextField(
                                        controller: _singleRefController,
                                        decoration: const InputDecoration(
                                          labelText: 'Ref No.',
                                          hintText: '1001234567890',
                                          isDense: true,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextField(
                                        controller: _singleAmountController,
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                          labelText: 'Amount (₱)',
                                          hintText: '35.00',
                                          isDense: true,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      onPressed: _isSaving ? null : _addSingleRecord,
                                      style: ElevatedButton.styleFrom(backgroundColor: gcashBlue),
                                      child: const Text('ADD', style: TextStyle(color: Colors.white)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                TextField(
                                  controller: _batchInputController,
                                  maxLines: 2,
                                  decoration: InputDecoration(
                                    labelText: 'Or Paste Batch (Format: RefNo, Amount per line)',
                                    hintText: '1001234567890, 35.00\n1001234567891, 70.00',
                                    isDense: true,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    onPressed: _isSaving ? null : _processBatchImport,
                                    icon: const Icon(Icons.file_upload_outlined, size: 18),
                                    label: const Text('IMPORT BATCH LIST'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const Divider(height: 1),

                      // Records Table
                      Expanded(
                        child: _adminRecords.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.inbox_rounded, size: 48, color: Colors.grey.shade400),
                                    const SizedBox(height: 8),
                                    const Text('No uploaded GCash records yet.', style: TextStyle(color: AppColors.slate)),
                                  ],
                                ),
                              )
                            : ListView.separated(
                                itemCount: _adminRecords.length,
                                separatorBuilder: (_, _) => const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final r = _adminRecords[index];
                                  return ListTile(
                                    dense: true,
                                    leading: Icon(
                                      r.isUsed ? Icons.check_circle_rounded : Icons.pending_rounded,
                                      color: r.isUsed ? AppColors.danger : AppColors.success,
                                    ),
                                    title: Text(
                                      r.referenceNumber,
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    subtitle: Text('Amount: ₱${r.amount.toStringAsFixed(2)}'),
                                    trailing: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: r.isUsed ? const Color(0xFFFEE2E2) : AppColors.successLight,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        r.isUsed ? 'USED (${r.usedInReceipt ?? 'N/A'})' : 'AVAILABLE',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: r.isUsed ? AppColors.danger : AppColors.success,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
