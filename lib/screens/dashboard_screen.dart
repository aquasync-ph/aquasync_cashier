import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_state.dart';
import '../models/models.dart';
import '../theme.dart';
import 'receipt_dialog.dart';
import 'components/modern_nav_rail.dart';
import 'components/modern_bottom_nav.dart';
import 'components/top_alert.dart';
import 'components/gcash_payment_dialog.dart';
import 'components/walk_in_customer_dialog.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _cashController = TextEditingController();
  final currencyFormat = NumberFormat.currency(symbol: '₱');
  double _cashReceived = 0.0;
  int _selectedNavIndex = 0; // 0: POS Terminal, 1: Sales History, 2: RFID Lookup
  bool _showNumpad = false;
  String _paymentMethod = 'Cash';

  @override
  void initState() {
    super.initState();
    _cashController.addListener(() {
      setState(() {
        _cashReceived = double.tryParse(_cashController.text) ?? 0.0;
      });
    });

    // Route protection: ensure user is authenticated, otherwise redirect to login
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    });
  }

  @override
  void dispose() {
    _cashController.dispose();
    super.dispose();
  }

  Future<void> _completeTransaction(AppState appState) async {
    if (appState.cart.isEmpty) return;

    if (appState.selectedCustomer == null) {
      TopAlert.show(context, 'Please select or enter customer details first', type: AlertType.warning, title: 'Customer Required');
      _showCustomerSelectionDialog(context);
      return;
    }

    String? gcashRefNo;

    if (_paymentMethod == 'GCash') {
      final result = await showDialog<String?>(
        context: context,
        barrierDismissible: false,
        builder: (context) => GCashPaymentDialog(
          totalAmount: appState.totalAmount,
          customerName: appState.selectedCustomer?.fullName ?? 'Customer',
        ),
      );

      if (result == null) {
        // User cancelled GCash payment dialog
        return;
      }
      gcashRefNo = result;
    }

    final cashToUse = _paymentMethod == 'GCash' ? appState.totalAmount : _cashReceived;

    try {
      final transaction = await appState.completeTransaction(
        cashToUse,
        paymentMethod: _paymentMethod,
        gcashRefNo: gcashRefNo,
      );

      if (transaction != null) {
        _cashController.clear();
        setState(() {
          _cashReceived = 0.0;
          _showNumpad = false;
        });

        if (!mounted) return;
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => ReceiptDialog(transaction: transaction),
        );

        if (!mounted) return;
        setState(() {
          _selectedNavIndex = 1; // Switch to Daily Sales & History tab
        });
      }
    } catch (e) {
      if (!mounted) return;
      TopAlert.show(context, 'Failed to complete transaction: ${e.toString().replaceAll('Exception: ', '')}', type: AlertType.error, title: 'Transaction Failed');
    }
  }

  void _applyQuickCash(double amount) {
    setState(() {
      _cashReceived = amount;
      _cashController.text = amount.toStringAsFixed(2);
    });
  }

  void _onNumpadPress(String key) {
    String current = _cashController.text;
    if (key == 'C') {
      _cashController.clear();
    } else if (key == '⌫') {
      if (current.isNotEmpty) {
        _cashController.text = current.substring(0, current.length - 1);
      }
    } else {
      if (key == '.' && current.contains('.')) return;
      _cashController.text = current + key;
    }
  }

  void _showWalkInCustomerDialog(BuildContext context) {
    debugPrint('SHOWING WALK IN CUSTOMER DIALOG TRIGGERED');
    showDialog(
      context: context,
      builder: (dialogContext) => const WalkInCustomerDialog(),
    );
  }

  Widget _buildCustomerList({
    required bool isSearching,
    required List<CustomerInfo> searchResults,
    required AppState appState,
    required BuildContext dialogContext,
  }) {
    if (isSearching) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (searchResults.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text('No customers found', style: TextStyle(color: AppColors.grayText)),
        ),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: searchResults.length,
      separatorBuilder: (context, index) => const Divider(),
      itemBuilder: (context, index) {
        final customer = searchResults[index];
        return ListTile(
          leading: const CircleAvatar(
            backgroundColor: AppColors.lightAqua,
            child: Icon(Icons.person, color: AppColors.electricCyan),
          ),
          title: Text(customer.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(customer.phone),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () {
            FocusScope.of(dialogContext).unfocus();
            appState.selectRegisteredCustomer(customer);
            Navigator.of(dialogContext).pop();
          },
        );
      },
    );
  }

  void _showRegisteredCustomerSearchDialog(BuildContext context) {
    final appState = context.read<AppState>();
    final searchController = TextEditingController();
    List<CustomerInfo> searchResults = [];
    bool isSearching = true;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Fetch initial list once when dialog opens
            if (searchResults.isEmpty && isSearching && searchController.text.isEmpty) {
              Future.microtask(() async {
                final results = await appState.searchRegisteredCustomers('');
                if (dialogContext.mounted) {
                  setDialogState(() {
                    searchResults = results;
                    isSearching = false;
                  });
                }
              });
            }

            return AlertDialog(
              backgroundColor: AppColors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.lightAqua,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.group_rounded, color: AppColors.electricCyan, size: 22),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Registered Customers',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryDarkNavy),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: searchController,
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: 'Search by name or phone...',
                          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.electricCyan),
                          suffixIcon: isSearching 
                            ? const Padding(
                                padding: EdgeInsets.all(12.0),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            : IconButton(
                                icon: const Icon(Icons.search_rounded),
                                onPressed: () async {
                                  setDialogState(() => isSearching = true);
                                  final results = await appState.searchRegisteredCustomers(searchController.text);
                                  setDialogState(() {
                                    searchResults = results;
                                    isSearching = false;
                                  });
                                },
                              ),
                        ),
                        onSubmitted: (val) async {
                          setDialogState(() => isSearching = true);
                          final results = await appState.searchRegisteredCustomers(val);
                          setDialogState(() {
                            searchResults = results;
                            isSearching = false;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 300),
                        child: _buildCustomerList(
                          isSearching: isSearching,
                          searchResults: searchResults,
                          appState: appState,
                          dialogContext: dialogContext,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    FocusScope.of(dialogContext).unfocus();
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showCustomerSelectionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Select Customer Type', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.lightAqua, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.directions_walk_rounded, color: AppColors.electricCyan),
                ),
                title: const Text('Walk-In Customer', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Enter name, contact, and location'),
                onTap: () {
                  Navigator.of(dialogContext).pop();
                  _showWalkInCustomerDialog(context);
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.lightAqua, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.group_rounded, color: AppColors.electricCyan),
                ),
                title: const Text('Registered User', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Search from existing database'),
                onTap: () {
                  Navigator.of(dialogContext).pop();
                  _showRegisteredCustomerSearchDialog(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showRfidLookupDialog(BuildContext context) {
    final uidController = TextEditingController();
    final appState = context.read<AppState>();

    showDialog(
      context: context,
      builder: (dialogContext) {
        bool isSearching = false;

        return StatefulBuilder(
          builder: (dialogContext, setState) {
            return AlertDialog(
              backgroundColor: AppColors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.lightAqua,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.nfc_rounded, color: AppColors.electricCyan, size: 22),
                  ),
                  const SizedBox(width: 10),
                  const Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Customer Loyalty RFID', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryDarkNavy)),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Scan or enter Customer Loyalty RFID Card UID:',
                    style: TextStyle(fontSize: 12, color: AppColors.grayText),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: uidController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'RFID Card UID',
                      hintText: 'e.g., 04:A2:8F:91:XX',
                      prefixIcon: Icon(Icons.credit_card_rounded, color: AppColors.electricCyan),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    FocusScope.of(dialogContext).unfocus();
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Cancel', style: TextStyle(color: AppColors.grayText, fontWeight: FontWeight.w600)),
                ),
                ElevatedButton(
                  onPressed: isSearching
                      ? null
                      : () async {
                          final uid = uidController.text.trim();
                          if (uid.isEmpty) return;

                          setState(() => isSearching = true);

                          try {
                            final customer = await appState.findCustomerByRfidUid(uid);
                            if (!dialogContext.mounted) return;
                            FocusScope.of(dialogContext).unfocus();
                            Navigator.of(dialogContext).pop();

                            if (customer != null) {
                              TopAlert.show(context, 'Loyal Customer Verified: ${customer.fullName}', type: AlertType.success, title: 'RFID Verified');
                            }
                          } catch (e) {
                            if (!dialogContext.mounted) return;
                            setState(() => isSearching = false);
                            TopAlert.show(context, 'RFID Error: ${e.toString().replaceAll('Exception: ', '')}', type: AlertType.error, title: 'Lookup Failed');
                          }
                        },
                  child: isSearching
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white),
                        )
                      : const Text('SEARCH CUSTOMER'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(28),
              constraints: const BoxConstraints(maxWidth: 380),
              decoration: BoxDecoration(
                color: AppColors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 1.8),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.danger.withValues(alpha: 0.15),
                    blurRadius: 40,
                    offset: const Offset(0, 15),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.danger.withValues(alpha: 0.2),
                          AppColors.danger.withValues(alpha: 0.08),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.danger.withValues(alpha: 0.2),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.logout_rounded, color: AppColors.danger, size: 36),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Sign Out',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primaryDarkNavy,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Are you sure you want to end your session on this Cashier Terminal?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.grayText,
                      fontSize: 13.5,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primaryDarkNavy,
                              side: const BorderSide(color: AppColors.border, width: 1.5),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  AppColors.danger,
                                  Color(0xFFD32F2F),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.danger.withValues(alpha: 0.4),
                                  blurRadius: 14,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                foregroundColor: AppColors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              onPressed: () {
                                HapticFeedback.heavyImpact();
                                Navigator.of(dialogContext).pop();
                                context.read<AppState>().logout();
                                Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                              },
                              child: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5, letterSpacing: 0.5)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppGradients.mainBackground,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWideScreen = constraints.maxWidth >= 850;

            if (isWideScreen) {
              return Row(
                children: [
                  // Modern Left Navigation Sidebar
                  ModernNavRail(
                    selectedIndex: _selectedNavIndex,
                    onDestinationSelected: (index) {
                      if (index == 2) {
                        _showRfidLookupDialog(context);
                      } else {
                        setState(() => _selectedNavIndex = index);
                      }
                    },
                    onLogout: _handleLogout,
                  ),

                  // Main Content Body Area
                  Expanded(
                    child: IndexedStack(
                      index: _selectedNavIndex,
                      children: [
                        // View 0: POS Terminal Split View
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            children: [
                              Expanded(
                                flex: constraints.maxWidth > 1024 ? 3 : 2,
                                child: const GlassCard(
                                  opacity: 0.65,
                                  child: ProductGrid(),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: GlassCard(
                                  opacity: 0.85,
                                  child: _CartAndPaymentSection(
                                    currencyFormat: currencyFormat,
                                    cashController: _cashController,
                                    cashReceived: _cashReceived,
                                    paymentMethod: _paymentMethod,
                                    onSelectPaymentMethod: (method) {
                                      setState(() {
                                        _paymentMethod = method;
                                        if (method == 'GCash') {
                                          _cashReceived = appState.totalAmount;
                                          _cashController.text = appState.totalAmount.toStringAsFixed(2);
                                        }
                                      });
                                    },
                                    showNumpad: _showNumpad,
                                    onToggleNumpad: () => setState(() => _showNumpad = !_showNumpad),
                                    onNumpadPress: _onNumpadPress,
                                    onQuickCash: _applyQuickCash,
                                    onRfidLookup: () => _showRfidLookupDialog(context),
                                    onWalkInLookup: () => _showWalkInCustomerDialog(context),
                                    onRegisteredLookup: () => _showRegisteredCustomerSearchDialog(context),
                                    onComplete: () => _completeTransaction(appState),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // View 1: Transaction / Daily Sales History Page
                        _SalesHistoryView(currencyFormat: currencyFormat),

                        // View 2: Placeholder (handled by dialog)
                        const SizedBox.shrink(),

                        // View 3: Pending Approvals & History Tab View
                        _PendingApprovalsTabView(),
                      ],
                    ),
                  ),
                ],
              );
            } else {
            // Mobile / Narrow Screen Layout
            return SafeArea(
              child: Column(
                children: [
                  // Mobile Glass Header Bar
                  ClipRRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.primaryDarkNavy.withValues(alpha: 0.88),
                          border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.12))),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                gradient: AppColors.cyanGradient,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: AppDesign.glowingShadow,
                              ),
                              child: const Icon(Icons.water_drop, color: AppColors.white, size: 20),
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'AQUASYNC POS',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: AppColors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  Text(
                                    'Cashier Terminal',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: AppColors.skyBlue,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _HeaderActionButton(
                              icon: Icons.verified_user_rounded,
                              tooltip: 'Pending Approvals',
                              color: AppColors.warning,
                              badgeCount: appState.pendingApprovals.length,
                              onPressed: () => setState(() => _selectedNavIndex = 3),
                            ),
                            const SizedBox(width: 8),
                            _HeaderActionButton(
                              icon: Icons.logout_rounded,
                              tooltip: 'Logout',
                              color: AppColors.danger,
                              onPressed: _handleLogout,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Active Mobile Tab View
                  Expanded(
                    child: IndexedStack(
                      index: _selectedNavIndex,
                      children: [
                        const ProductGrid(),
                        _CartAndPaymentSection(
                          currencyFormat: currencyFormat,
                          cashController: _cashController,
                          cashReceived: _cashReceived,
                          paymentMethod: _paymentMethod,
                          onSelectPaymentMethod: (method) {
                            setState(() {
                              _paymentMethod = method;
                              if (method == 'GCash') {
                                _cashReceived = appState.totalAmount;
                                _cashController.text = appState.totalAmount.toStringAsFixed(2);
                              }
                            });
                          },
                          showNumpad: _showNumpad,
                          onToggleNumpad: () => setState(() => _showNumpad = !_showNumpad),
                          onNumpadPress: _onNumpadPress,
                          onQuickCash: _applyQuickCash,
                          onRfidLookup: () => _showRfidLookupDialog(context),
                          onWalkInLookup: () => _showWalkInCustomerDialog(context),
                          onRegisteredLookup: () => _showRegisteredCustomerSearchDialog(context),
                          onComplete: () => _completeTransaction(appState),
                        ),
                        _SalesHistoryView(currencyFormat: currencyFormat),
                        _PendingApprovalsTabView(),
                      ],
                    ),
                  ),

                  // Floating Glass Bottom Navigation Bar
                  ModernBottomNav(
                    selectedIndex: _selectedNavIndex,
                    onTap: (index) => setState(() => _selectedNavIndex = index),
                  ),
                ],
              ),
            );
          }
        },
      ),
    ));
  }
}

class ProductGrid extends StatelessWidget {
  const ProductGrid({super.key});
  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final products = appState.filteredProducts;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category Selector & Search Bar
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          color: Colors.transparent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search Input
              SizedBox(
                height: 48,
                child: TextField(
                  onChanged: (val) => appState.setSearchQuery(val),
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.primaryDarkNavy),
                  decoration: InputDecoration(
                    hintText: 'Search products by name...',
                    hintStyle: const TextStyle(color: AppColors.slate, fontSize: 13),
                    prefixIcon: const Icon(Icons.search_rounded, size: 22, color: AppColors.electricCyan),
                    suffixIcon: appState.searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 20, color: AppColors.slate),
                            onPressed: () => appState.setSearchQuery(''),
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.8),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: AppColors.electricCyan, width: 2),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Category Pills
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: appState.categories.map((category) {
                    final isSelected = appState.selectedCategory == category;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          appState.setCategory(category);
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: isSelected ? AppColors.cyanGradient : null,
                            color: isSelected ? null : Colors.white.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected ? AppColors.electricCyan : Colors.white.withValues(alpha: 0.5),
                              width: 1.5,
                            ),
                            boxShadow: isSelected ? AppDesign.glowingShadow : AppDesign.softShadow,
                          ),
                          child: Text(
                            category.toUpperCase(),
                            style: TextStyle(
                              color: isSelected ? AppColors.white : AppColors.primaryDarkNavy,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.border),

        // Product Cards Grid
        Expanded(
          child: products.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.search_off_rounded, size: 44, color: AppColors.lightGrayText),
                      const SizedBox(height: 10),
                      Text(
                        appState.searchQuery.isNotEmpty
                            ? 'No products found matching "${appState.searchQuery}"'
                            : 'No active products available.',
                        style: const TextStyle(color: AppColors.grayText, fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ],
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 600;
                    return GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: isWide ? 220 : 180,
                        childAspectRatio: isWide ? 0.68 : 0.62,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: products.length,
                      itemBuilder: (context, index) {
                        final product = products[index];
                        final qtyInCart = appState.getItemQuantityInCart(product.id);
                        final isSelected = qtyInCart > 0;

                        return _AnimatedProductCard(
                          product: product,
                          qtyInCart: qtyInCart,
                          isSelected: isSelected,
                          onTap: () => appState.addToCart(product),
                          onAdd: () => appState.addToCart(product),
                          onRemove: () => appState.removeFromCart(product),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _AnimatedProductCard extends StatefulWidget {
  final Product product;
  final int qtyInCart;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  const _AnimatedProductCard({
    required this.product,
    required this.qtyInCart,
    required this.isSelected,
    required this.onTap,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  State<_AnimatedProductCard> createState() => _AnimatedProductCardState();
}

class _AnimatedProductCardState extends State<_AnimatedProductCard> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    final hasImage = widget.product.imageUrl != null && widget.product.imageUrl!.trim().isNotEmpty;
    final hasDescription = widget.product.description != null && widget.product.description!.trim().isNotEmpty;

    return AnimatedScale(
      scale: _scale,
      duration: const Duration(milliseconds: 120),
      child: GlassCard(
        opacity: widget.isSelected ? 0.9 : 0.7,
        borderRadius: 20,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTapDown: (_) => setState(() => _scale = 0.96),
          onTapUp: (_) => setState(() => _scale = 1.0),
          onTapCancel: () => setState(() => _scale = 1.0),
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Product Image Container (BoxFit.contain so picture is not cropped)
                  Stack(
                    children: [
                      Container(
                        height: 115,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: widget.isSelected
                              ? AppColors.primary.withValues(alpha: 0.15)
                              : AppColors.white.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: hasImage
                              ? Image.network(
                                  widget.product.imageUrl!,
                                  fit: BoxFit.contain,
                                  width: double.infinity,
                                  height: double.infinity,
                                  loadingBuilder: (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Center(
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                                        ),
                                      ),
                                    );
                                  },
                                  errorBuilder: (context, error, stackTrace) {
                                    return Center(
                                      child: Icon(
                                        widget.product.icon,
                                        color: AppColors.primary,
                                        size: 32,
                                      ),
                                    );
                                  },
                                )
                              : Center(
                                  child: Icon(
                                    widget.product.icon,
                                    color: AppColors.primary,
                                    size: 40,
                                  ),
                                ),
                        ),
                      ),
                      if (widget.qtyInCart > 0)
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              gradient: AppGradients.electric,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              '${widget.qtyInCart}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Product Name
                  Text(
                    widget.product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      color: AppColors.darkText,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),

                  // Category Tag
                  Text(
                    widget.product.category.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.slate,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                  if (hasDescription) ...[
                    const SizedBox(height: 2),
                    Text(
                      widget.product.description!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.grayText,
                        fontSize: 9,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),

                  // Price & Quantity / Add / Remove Action Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '₱${widget.product.price.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      widget.qtyInCart > 0
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                InkWell(
                                  onTap: widget.onRemove,
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    width: 26,
                                    height: 26,
                                    decoration: BoxDecoration(
                                      color: AppColors.danger.withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.remove_rounded, size: 14, color: AppColors.danger),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${widget.qtyInCart}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primaryDarkNavy),
                                ),
                                const SizedBox(width: 4),
                                InkWell(
                                  onTap: widget.onAdd,
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    width: 26,
                                    height: 26,
                                    decoration: BoxDecoration(
                                      gradient: AppGradients.electric,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.add_rounded, size: 14, color: Colors.white),
                                  ),
                                ),
                              ],
                            )
                          : InkWell(
                              onTap: widget.onAdd,
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  gradient: AppGradients.electric,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: AppDesign.glowingShadow,
                                ),
                                child: const Center(
                                  child: Icon(Icons.add_rounded, size: 18, color: Colors.white),
                                ),
                              ),
                            ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CartAndPaymentSection extends StatelessWidget {
  final NumberFormat currencyFormat;
  final TextEditingController cashController;
  final double cashReceived;
  final String paymentMethod;
  final ValueChanged<String> onSelectPaymentMethod;
  final bool showNumpad;
  final VoidCallback onToggleNumpad;
  final Function(String) onNumpadPress;
  final Function(double) onQuickCash;
  final VoidCallback onRfidLookup;
  final VoidCallback onWalkInLookup;
  final VoidCallback onRegisteredLookup;
  final VoidCallback onComplete;

  const _CartAndPaymentSection({
    required this.currencyFormat,
    required this.cashController,
    required this.cashReceived,
    required this.paymentMethod,
    required this.onSelectPaymentMethod,
    required this.showNumpad,
    required this.onToggleNumpad,
    required this.onNumpadPress,
    required this.onQuickCash,
    required this.onRfidLookup,
    required this.onWalkInLookup,
    required this.onRegisteredLookup,
    required this.onComplete,
  });

  Widget _buildOrderHeader(AppState appState) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border(bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.5))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                const Icon(Icons.shopping_cart_rounded, color: AppColors.primaryDarkNavy, size: 18),
                const SizedBox(width: 6),
                const Flexible(
                  child: Text(
                    'CURRENT ORDER',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryDarkNavy,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.lightAqua,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${appState.totalCartItemsCount}',
                    style: const TextStyle(
                      color: AppColors.electricCyan,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (appState.cart.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 18),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              tooltip: 'Clear Cart',
              onPressed: () => appState.clearCart(),
            ),
        ],
      ),
    );
  }

  Widget _buildCustomerBanner(AppState appState, CustomerInfo? customer) {
    if (customer == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.5),
          border: Border(bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.5))),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ASSIGN CUSTOMER',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: AppColors.grayText,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _CustomerActionBtn(
                    icon: Icons.directions_walk_rounded,
                    label: 'Walk-In',
                    color: AppColors.electricCyan,
                    onTap: onWalkInLookup,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _CustomerActionBtn(
                    icon: Icons.group_rounded,
                    label: 'Registered',
                    color: AppColors.primaryDarkNavy,
                    onTap: onRegisteredLookup,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _CustomerActionBtn(
                    icon: Icons.nfc_rounded,
                    label: 'Loyalty RFID',
                    color: AppColors.secondary,
                    onTap: onRfidLookup,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    final isLoyal = customer.isLoyal;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isLoyal ? AppColors.lightAqua.withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.9),
        border: Border(bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.5))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isLoyal ? AppColors.electricCyan : AppColors.primaryDarkNavy,
              shape: BoxShape.circle,
              boxShadow: AppDesign.softShadow,
            ),
            child: Icon(
              isLoyal ? Icons.stars_rounded : Icons.person_rounded,
              size: 26,
              color: AppColors.white,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        customer.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: AppColors.primaryDarkNavy,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isLoyal ? AppColors.successLight : AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isLoyal ? AppColors.success : AppColors.border),
                      ),
                      child: Text(
                        isLoyal ? 'Loyal RFID ✓' : 'Walk-In 🚶',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: isLoyal ? AppColors.success : AppColors.grayText,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${customer.phone} ${customer.address != null ? ' • ${customer.address}' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.grayText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.edit_rounded, size: 22, color: AppColors.electricCyan),
                tooltip: 'Change Customer',
                onPressed: isLoyal ? onRegisteredLookup : onWalkInLookup,
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 22, color: AppColors.danger),
                tooltip: 'Remove Customer',
                onPressed: () => appState.clearCustomer(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCartList(AppState appState, {required bool shrinkWrap}) {
    if (appState.cart.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shopping_bag_outlined, size: 44, color: AppColors.lightGrayText),
              SizedBox(height: 8),
              Text(
                'Cart is empty.\nTap items to add.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.grayText, fontWeight: FontWeight.w500, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: appState.cart.length,
      separatorBuilder: (_, index) => const Divider(height: 1, color: AppColors.border),
      itemBuilder: (context, index) {
        final item = appState.cart[index];
        final hasImage = item.product.imageUrl != null && item.product.imageUrl!.trim().isNotEmpty;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10.0),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: hasImage
                      ? Image.network(
                          item.product.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Icon(item.product.icon, size: 18, color: AppColors.primary),
                        )
                      : Icon(item.product.icon, size: 18, color: AppColors.primary),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppColors.darkText,
                      ),
                    ),
                    Text(
                      '₱${item.product.price.toStringAsFixed(2)} × ${item.quantity}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.grayText,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  _QtyTouchBtn(
                    icon: Icons.remove,
                    onTap: () => appState.removeFromCart(item.product),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(
                      '${item.quantity}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  _QtyTouchBtn(
                    icon: Icons.add,
                    onTap: () => appState.addToCart(item.product),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 65,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    currencyFormat.format(item.subtotal),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AppColors.electricCyan,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCheckoutControls(AppState appState, double total, bool isGCash, bool isEnough) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        border: Border(top: BorderSide(color: AppColors.border.withValues(alpha: 0.5))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Total Summary
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'TOTAL AMOUNT',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: AppColors.grayText,
                  letterSpacing: 1.0,
                ),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  currencyFormat.format(total),
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primaryDarkNavy,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Payment Method Selectors
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => onSelectPaymentMethod('Cash'),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: paymentMethod == 'Cash' ? AppColors.electricCyan : AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: paymentMethod == 'Cash' ? AppColors.electricCyan : AppColors.border, width: 1.5),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.payments_rounded,
                          size: 18,
                          color: paymentMethod == 'Cash' ? AppColors.white : AppColors.grayText,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'CASH',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                            color: paymentMethod == 'Cash' ? AppColors.white : AppColors.grayText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () => onSelectPaymentMethod('GCash'),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      gradient: paymentMethod == 'GCash' ? AppColors.gcashGradient : null,
                      color: paymentMethod == 'GCash' ? null : AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: paymentMethod == 'GCash' ? const Color(0xFF005CE6) : AppColors.border, width: 1.5),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.qr_code_rounded,
                          size: 18,
                          color: paymentMethod == 'GCash' ? AppColors.white : AppColors.grayText,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'GCASH',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                            color: paymentMethod == 'GCash' ? AppColors.white : AppColors.grayText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (!isGCash) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'QUICK CASH',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.grayText, letterSpacing: 0.5),
                ),
                GestureDetector(
                  onTap: onToggleNumpad,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.lightAqua,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      showNumpad ? 'Hide Numpad' : 'Numpad 🔢',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.electricCyan),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _FastCashChip(label: 'EXACT', isHighlight: true, onTap: () => onQuickCash(total)),
                _FastCashChip(label: '₱50', onTap: () => onQuickCash(50.0)),
                _FastCashChip(label: '₱100', onTap: () => onQuickCash(100.0)),
                _FastCashChip(label: '₱500', onTap: () => onQuickCash(500.0)),
                _FastCashChip(label: '₱1,000', onTap: () => onQuickCash(1000.0)),
              ],
            ),
            const SizedBox(height: 16),

            if (showNumpad) ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    Row(children: ['1', '2', '3'].map((k) => Expanded(child: _NumpadBtn(label: k, onTap: () => onNumpadPress(k)))).toList()),
                    Row(children: ['4', '5', '6'].map((k) => Expanded(child: _NumpadBtn(label: k, onTap: () => onNumpadPress(k)))).toList()),
                    Row(children: ['7', '8', '9'].map((k) => Expanded(child: _NumpadBtn(label: k, onTap: () => onNumpadPress(k)))).toList()),
                    Row(children: ['C', '0', '⌫'].map((k) => Expanded(child: _NumpadBtn(label: k, onTap: () => onNumpadPress(k)))).toList()),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            TextField(
              controller: cashController,
              readOnly: showNumpad,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.primaryDarkNavy),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Cash Received',
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.slate),
                prefixText: '₱ ',
                prefixStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.electricCyan),
                prefixIcon: const Icon(Icons.attach_money_rounded, color: AppColors.electricCyan),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Complete Checkout Button
          SizedBox(
            height: 60,
            child: ElevatedButton(
              onPressed: isEnough ? onComplete : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: isEnough ? AppColors.electricCyan : AppColors.lightGrayText,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: isEnough ? 4 : 0,
                shadowColor: AppColors.electricCyan.withValues(alpha: 0.4),
              ),
              child: appState.isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.white),
                    )
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        isGCash ? 'PAY VIA GCASH' : 'COMPLETE SALE',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final total = appState.totalAmount;
    final isGCash = paymentMethod == 'GCash';
    final isEnough = isGCash ? total > 0 : (cashReceived >= total && total > 0);
    final customer = appState.selectedCustomer;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildOrderHeader(appState),
          _buildCustomerBanner(appState, customer),
          _buildFulfillmentSelector(appState),
          _buildCartList(appState, shrinkWrap: true),
          _buildCheckoutControls(appState, total, isGCash, isEnough),
        ],
      ),
    );
  }

  Widget _buildFulfillmentSelector(AppState appState) {
    final isDelivery = appState.fulfillmentType == 'Delivery';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                appState.setFulfillmentType('Pick-up');
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: !isDelivery ? AppColors.electricCyan : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.storefront_rounded,
                      size: 18,
                      color: !isDelivery ? AppColors.white : AppColors.grayText,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Pick-up at Store',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: !isDelivery ? AppColors.white : AppColors.grayText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                appState.setFulfillmentType('Delivery');
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isDelivery ? AppColors.electricCyan : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.delivery_dining_rounded,
                      size: 18,
                      color: isDelivery ? AppColors.white : AppColors.grayText,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'For Delivery',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isDelivery ? AppColors.white : AppColors.grayText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SalesHistoryView extends StatefulWidget {
  final NumberFormat currencyFormat;

  const _SalesHistoryView({required this.currencyFormat});

  @override
  State<_SalesHistoryView> createState() => _SalesHistoryViewState();
}

class _SalesHistoryViewState extends State<_SalesHistoryView> {
  String _filterOption = 'all'; // 'all', 'today', 'cash', 'gcash'
  String _sortOption = 'newest'; // 'newest', 'oldest', 'highest', 'lowest'

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final dateFormat = DateFormat('MMM d, h:mm a');

    // Filter Logic
    List<TransactionRecord> filteredList = List.from(appState.transactions);
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);

    if (_filterOption == 'today') {
      filteredList = filteredList.where((tx) => tx.timestamp.isAfter(startOfToday)).toList();
    } else if (_filterOption == 'cash') {
      filteredList = filteredList.where((tx) => tx.paymentMethod.toUpperCase() == 'CASH').toList();
    } else if (_filterOption == 'gcash') {
      filteredList = filteredList.where((tx) => tx.paymentMethod.toUpperCase() == 'GCASH').toList();
    }

    // Sort Logic
    if (_sortOption == 'oldest') {
      filteredList.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    } else if (_sortOption == 'highest') {
      filteredList.sort((a, b) => b.total.compareTo(a.total));
    } else if (_sortOption == 'lowest') {
      filteredList.sort((a, b) => a.total.compareTo(b.total));
    } else {
      // newest
      filteredList.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    }

    final totalSales = filteredList.fold(0.0, (sum, tx) => sum + tx.total);

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: GlassCard(
        opacity: 0.65,
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: AppColors.cyanGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.receipt_long_rounded, color: AppColors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sales & History',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryDarkNavy,
                          ),
                        ),
                        Text(
                          'Filter & sort completed transactions',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: AppColors.grayText),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Filter & Sort Dropdowns Controls Row
              Row(
                children: [
                  // Filter Dropdown
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _filterOption,
                          isExpanded: true,
                          icon: const Icon(Icons.filter_alt_rounded, color: AppColors.electricCyan, size: 18),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primaryDarkNavy),
                          onChanged: (val) {
                            if (val != null) {
                              HapticFeedback.lightImpact();
                              setState(() => _filterOption = val);
                            }
                          },
                          items: const [
                            DropdownMenuItem(value: 'all', child: Text('All Transactions')),
                            DropdownMenuItem(value: 'today', child: Text('Today Only')),
                            DropdownMenuItem(value: 'cash', child: Text('Cash Sales')),
                            DropdownMenuItem(value: 'gcash', child: Text('GCash Sales')),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Sort Dropdown
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _sortOption,
                          isExpanded: true,
                          icon: const Icon(Icons.swap_vert_rounded, color: AppColors.electricCyan, size: 18),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primaryDarkNavy),
                          onChanged: (val) {
                            if (val != null) {
                              HapticFeedback.lightImpact();
                              setState(() => _sortOption = val);
                            }
                          },
                          items: const [
                            DropdownMenuItem(value: 'newest', child: Text('Newest First')),
                            DropdownMenuItem(value: 'oldest', child: Text('Oldest First')),
                            DropdownMenuItem(value: 'highest', child: Text('Highest ₱')),
                            DropdownMenuItem(value: 'lowest', child: Text('Lowest ₱')),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Total Sales Summary Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AppGradients.ocean,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    )
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          const Text(
                            'FILTERED TRANSACTIONS',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                          ),
                          const SizedBox(height: 6),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '${filteredList.length}',
                              style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(height: 40, width: 1.5, color: Colors.white24),
                    Expanded(
                      child: Column(
                        children: [
                          const Text(
                            'TOTAL REVENUE',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                          ),
                          const SizedBox(height: 6),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              widget.currencyFormat.format(totalSales),
                              style: const TextStyle(color: AppColors.tertiary, fontSize: 28, fontWeight: FontWeight.w900),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Transaction List
              Expanded(
                child: filteredList.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.receipt_outlined, size: 44, color: AppColors.lightGrayText),
                            const SizedBox(height: 10),
                            const Text('No sales match the selected filter/sort', style: TextStyle(color: AppColors.grayText, fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: filteredList.length,
                        separatorBuilder: (_, index) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final tx = filteredList[index];
                          final isGCash = tx.paymentMethod.toUpperCase() == 'GCASH';

                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: AppDesign.glassDecoration(),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: isGCash ? const Color(0xFF005CE6).withValues(alpha: 0.1) : AppColors.lightAqua,
                                  child: Icon(
                                    isGCash ? Icons.qr_code_rounded : Icons.receipt_rounded,
                                    color: isGCash ? const Color(0xFF005CE6) : AppColors.electricCyan,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              tx.id,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: isGCash ? const Color(0xFF005CE6).withValues(alpha: 0.15) : AppColors.lightAqua,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              tx.paymentMethod.toUpperCase(),
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                                color: isGCash ? const Color(0xFF005CE6) : AppColors.electricCyan,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        '${dateFormat.format(tx.timestamp)} • ${tx.items.length} item(s)',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 10, color: AppColors.grayText),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        widget.currencyFormat.format(tx.total),
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.electricCyan),
                                      ),
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.visibility_outlined, size: 18, color: AppColors.grayText),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                          tooltip: 'View Receipt',
                                          onPressed: () {
                                            showDialog(
                                              context: context,
                                              builder: (_) => ReceiptDialog(transaction: tx),
                                            );
                                          },
                                        ),
                                        const SizedBox(width: 4),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.danger),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                          tooltip: 'Delete Transaction',
                                          onPressed: () {
                                            showDialog(
                                              context: context,
                                              builder: (dialogContext) => Dialog(
                                                backgroundColor: Colors.transparent,
                                                child: ClipRRect(
                                                  borderRadius: BorderRadius.circular(24),
                                                  child: BackdropFilter(
                                                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                                                    child: Container(
                                                      padding: const EdgeInsets.all(24),
                                                      constraints: const BoxConstraints(maxWidth: 380),
                                                      decoration: BoxDecoration(
                                                        color: AppColors.white.withValues(alpha: 0.95),
                                                        borderRadius: BorderRadius.circular(24),
                                                        border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 1.5),
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: Colors.black.withValues(alpha: 0.15),
                                                            blurRadius: 30,
                                                            offset: const Offset(0, 10),
                                                          ),
                                                        ],
                                                      ),
                                                      child: Column(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Container(
                                                            padding: const EdgeInsets.all(16),
                                                            decoration: BoxDecoration(
                                                              color: AppColors.danger.withValues(alpha: 0.12),
                                                              shape: BoxShape.circle,
                                                            ),
                                                            child: const Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 32),
                                                          ),
                                                          const SizedBox(height: 16),
                                                          const Text(
                                                            'Delete Transaction',
                                                            style: TextStyle(
                                                              fontSize: 18,
                                                              fontWeight: FontWeight.w900,
                                                              color: AppColors.primaryDarkNavy,
                                                              letterSpacing: 0.5,
                                                            ),
                                                          ),
                                                          const SizedBox(height: 8),
                                                          Text(
                                                            'Are you sure you want to delete transaction ${tx.id}? This will also remove it from the database.',
                                                            textAlign: TextAlign.center,
                                                            style: const TextStyle(
                                                              color: AppColors.grayText,
                                                              fontSize: 13,
                                                              height: 1.4,
                                                            ),
                                                          ),
                                                          const SizedBox(height: 24),
                                                          Row(
                                                            children: [
                                                              Expanded(
                                                                child: SizedBox(
                                                                  height: 44,
                                                                  child: OutlinedButton(
                                                                    style: OutlinedButton.styleFrom(
                                                                      foregroundColor: AppColors.primaryDarkNavy,
                                                                      side: const BorderSide(color: AppColors.border, width: 1.2),
                                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                                                    ),
                                                                    onPressed: () => Navigator.of(dialogContext).pop(),
                                                                    child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                                                  ),
                                                                ),
                                                              ),
                                                              const SizedBox(width: 12),
                                                              Expanded(
                                                                child: SizedBox(
                                                                  height: 44,
                                                                  child: ElevatedButton(
                                                                    style: ElevatedButton.styleFrom(
                                                                      backgroundColor: AppColors.danger,
                                                                      foregroundColor: AppColors.white,
                                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                                                      elevation: 2,
                                                                    ),
                                                                    onPressed: () async {
                                                                      Navigator.of(dialogContext).pop();
                                                                      try {
                                                                        await appState.deleteTransaction(tx.id);
                                                                        if (context.mounted) {
                                                                          TopAlert.show(context, 'Transaction ${tx.id} deleted successfully', type: AlertType.success, title: 'Deleted');
                                                                        }
                                                                      } catch (e) {
                                                                        if (context.mounted) {
                                                                          TopAlert.show(context, 'Error deleting transaction: ${e.toString().replaceAll('Exception: ', '')}', type: AlertType.error, title: 'Delete Failed');
                                                                        }
                                                                      }
                                                                    },
                                                                    child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ],
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
      ),
    );
  }
}

class _CustomerActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _CustomerActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1.2),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FastCashChip extends StatelessWidget {
  final String label;
  final bool isHighlight;
  final VoidCallback onTap;

  const _FastCashChip({
    required this.label,
    this.isHighlight = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          gradient: isHighlight ? AppColors.cyanGradient : null,
          color: isHighlight ? null : AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isHighlight ? Colors.transparent : AppColors.electricCyan.withValues(alpha: 0.5),
            width: 1.2,
          ),
          boxShadow: isHighlight
              ? [
                  BoxShadow(
                    color: AppColors.electricCyan.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
            color: isHighlight ? AppColors.white : AppColors.primaryDarkNavy,
          ),
        ),
      ),
    );
  }
}

class _QtyTouchBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _QtyTouchBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppColors.lightAqua,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: AppColors.electricCyan),
      ),
    );
  }
}

class _HeaderActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? color;
  final int badgeCount;

  const _HeaderActionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              onPressed();
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: (color ?? AppColors.skyBlue).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: (color ?? AppColors.skyBlue).withValues(alpha: 0.3), width: 1.2),
              ),
              child: Icon(icon, color: color ?? AppColors.skyBlue, size: 20),
            ),
          ),
          if (badgeCount > 0)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: AppColors.danger,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Center(
                  child: Text(
                    '$badgeCount',
                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NumpadBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _NumpadBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.primaryDarkNavy),
          ),
        ),
      ),
    );
  }
}

class _PendingApprovalsTabView extends StatefulWidget {
  @override
  State<_PendingApprovalsTabView> createState() => _PendingApprovalsTabViewState();
}

class _PendingApprovalsTabViewState extends State<_PendingApprovalsTabView> {
  final Map<String, String> selectedDriverIds = {};

  @override
  void initState() {
    super.initState();
    final appState = context.read<AppState>();
    Future.microtask(() {
      if (!mounted) return;
      appState.checkAdminAuthorization();
      appState.fetchPendingApprovals();
      appState.fetchDeliveryDrivers();
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final pendingList = appState.pendingApprovals;
    final historyList = appState.approvalHistory;
    final driversList = appState.deliveryDrivers;

    return DefaultTabController(
      length: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: GlassCard(
          opacity: 0.75,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header & TabBar
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.lightAqua,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.verified_user_rounded, color: AppColors.electricCyan, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Pending Approvals & Dispatch Hub',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryDarkNavy),
                          ),
                          const Text(
                            'Manage pending orders, assign drivers from database, and review cashier approval audit logs.',
                            style: TextStyle(fontSize: 12, color: AppColors.grayText),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded),
                      onPressed: () async {
                        await appState.checkAdminAuthorization();
                        await appState.fetchPendingApprovals();
                        await appState.fetchDeliveryDrivers();
                      },
                      tooltip: 'Refresh',
                    ),
                  ],
                ),
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.lightAqua.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  indicator: BoxDecoration(
                    color: AppColors.primaryNavy,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  labelColor: AppColors.white,
                  unselectedLabelColor: AppColors.primaryDarkNavy,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.pending_actions_rounded, size: 16),
                          const SizedBox(width: 6),
                          Text('Pending (${pendingList.length})'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.history_rounded, size: 16),
                          const SizedBox(width: 6),
                          Text('History (${historyList.length})'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TabBarView(
                  children: [
                    // Tab 1: Pending List
                    pendingList.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle_outline_rounded, size: 64, color: AppColors.success),
                                SizedBox(height: 12),
                                Text(
                                  'No pending approvals found!',
                                  style: TextStyle(color: AppColors.grayText, fontWeight: FontWeight.w600, fontSize: 15),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            itemCount: pendingList.length,
                            itemBuilder: (context, index) {
                              final item = pendingList[index];
                              final isOrder = item.codeType.toUpperCase() == 'ORDER';

                              if (isOrder && !selectedDriverIds.containsKey(item.id) && driversList.isNotEmpty) {
                                selectedDriverIds[item.id] = driversList.first.id;
                              }

                              final currentDriverId = selectedDriverIds[item.id] ?? (driversList.isNotEmpty ? driversList.first.id : null);

                              return Card(
                                margin: const EdgeInsets.only(bottom: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                elevation: 2,
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: AppColors.lightAqua,
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    isOrder ? Icons.shopping_bag_rounded : Icons.nfc_rounded,
                                                    color: AppColors.electricCyan,
                                                    size: 16,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Flexible(
                                                    child: Text(
                                                      isOrder ? 'Order: ${item.code}' : 'RFID/QR: ${item.code}',
                                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryDarkNavy),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          if (item.createdAt != null)
                                            Text(
                                              DateFormat('MMM d, h:mm a').format(item.createdAt!),
                                              style: const TextStyle(fontSize: 11, color: AppColors.grayText, fontWeight: FontWeight.w500),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Customer: ${item.customerName ?? 'N/A'}',
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
                                      ),
                                      if (isOrder && item.address != null && item.address!.isNotEmpty) ...[
                                        const SizedBox(height: 3),
                                        Text(
                                          'Address: ${item.address}',
                                          style: const TextStyle(fontSize: 12, color: AppColors.grayText),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                      const SizedBox(height: 8),
                                      if (isOrder) ...[
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                          decoration: BoxDecoration(
                                            color: AppColors.electricCyan.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            '₱${item.totalAmount?.toStringAsFixed(2) ?? '0.00'} • ${item.paymentMethod ?? 'COD'} (${item.itemCount ?? 1} Items)',
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.electricCyan),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        const Text(
                                          'ASSIGN DELIVERY DRIVER (DATABASE):',
                                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.grayText, letterSpacing: 0.5),
                                        ),
                                        const SizedBox(height: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF8FAFC),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: AppColors.skyBlue.withValues(alpha: 0.5)),
                                          ),
                                          child: DropdownButtonHideUnderline(
                                            child: DropdownButton<String>(
                                              value: driversList.any((d) => d.id == currentDriverId) ? currentDriverId : (driversList.isNotEmpty ? driversList.first.id : null),
                                              isExpanded: true,
                                              icon: const Icon(Icons.arrow_drop_down_rounded, color: AppColors.electricCyan),
                                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primaryDarkNavy),
                                              items: driversList.map((driver) {
                                                return DropdownMenuItem<String>(
                                                  value: driver.id,
                                                  child: Row(
                                                    children: [
                                                      const Icon(Icons.two_wheeler_rounded, size: 16, color: AppColors.electricCyan),
                                                      const SizedBox(width: 8),
                                                      Expanded(child: Text(driver.fullName, style: const TextStyle(fontSize: 13))),
                                                    ],
                                                  ),
                                                );
                                              }).toList(),
                                              onChanged: (val) {
                                                if (val != null) {
                                                  setState(() {
                                                    selectedDriverIds[item.id] = val;
                                                  });
                                                }
                                              },
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 14),
                                        appState.canAcceptOrders
                                            ? Row(
                                                children: [
                                                  Expanded(
                                                    child: SizedBox(
                                                      height: 40,
                                                      child: ElevatedButton.icon(
                                                        style: ElevatedButton.styleFrom(
                                                          backgroundColor: AppColors.success,
                                                          foregroundColor: AppColors.white,
                                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                          elevation: 2,
                                                        ),
                                                        icon: const Icon(Icons.check_rounded, size: 18),
                                                        label: const Text('APPROVE & DISPATCH', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                                                        onPressed: () async {
                                                          final chosenId = selectedDriverIds[item.id] ?? (driversList.isNotEmpty ? driversList.first.id : null);
                                                          final assignedDriver = driversList.firstWhere((d) => d.id == chosenId, orElse: () => driversList.first);
                                                          try {
                                                            await appState.confirmPendingRecord(
                                                              item.id,
                                                              appState.cashierName ?? 'Cashier',
                                                              codeType: 'ORDER',
                                                              driverId: assignedDriver.id,
                                                              driverName: assignedDriver.fullName,
                                                            );
                                                            if (context.mounted) {
                                                              TopAlert.show(
                                                                context,
                                                                'Order ${item.code} assigned to ${assignedDriver.fullName} & Admin notified!',
                                                                type: AlertType.success,
                                                                title: 'Order Approved & Assigned',
                                                              );
                                                            }
                                                          } catch (e) {
                                                            if (context.mounted) {
                                                              TopAlert.show(
                                                                context,
                                                                'Error approving: ${e.toString().replaceAll('Exception: ', '')}',
                                                                type: AlertType.error,
                                                                title: 'Approval Failed',
                                                              );
                                                            }
                                                          }
                                                        },
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  SizedBox(
                                                    height: 40,
                                                    child: OutlinedButton.icon(
                                                      style: OutlinedButton.styleFrom(
                                                        foregroundColor: AppColors.danger,
                                                        side: const BorderSide(color: AppColors.danger, width: 1.2),
                                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                      ),
                                                      icon: const Icon(Icons.close_rounded, size: 18),
                                                      label: const Text('REJECT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                                      onPressed: () async {
                                                        try {
                                                          await appState.rejectPendingRecord(
                                                            item.id,
                                                            appState.cashierName ?? 'Cashier',
                                                            codeType: 'ORDER',
                                                          );
                                                          if (context.mounted) {
                                                            TopAlert.show(context, 'Rejected order: ${item.code}', type: AlertType.warning, title: 'Order Rejected');
                                                          }
                                                        } catch (e) {
                                                          if (context.mounted) {
                                                            TopAlert.show(context, 'Error rejecting: ${e.toString().replaceAll('Exception: ', '')}', type: AlertType.error, title: 'Action Failed');
                                                          }
                                                        }
                                                      },
                                                    ),
                                                  ),
                                                ],
                                              )
                                            : Container(
                                                height: 44,
                                                width: double.infinity,
                                                decoration: BoxDecoration(
                                                  color: AppColors.danger.withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(10),
                                                  border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
                                                ),
                                                child: ClipRRect(
                                                  borderRadius: BorderRadius.circular(10),
                                                  child: Stack(
                                                    alignment: Alignment.center,
                                                    children: [
                                                      ImageFiltered(
                                                        imageFilter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                                                        child: const Row(
                                                          mainAxisAlignment: MainAxisAlignment.center,
                                                          children: [
                                                            Text('APPROVE & DISPATCH', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.success)),
                                                            SizedBox(width: 20),
                                                            Text('REJECT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.danger)),
                                                          ],
                                                        ),
                                                      ),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                        decoration: BoxDecoration(
                                                          color: AppColors.danger.withValues(alpha: 0.9),
                                                          borderRadius: BorderRadius.circular(6),
                                                        ),
                                                        child: const Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            Icon(Icons.lock_rounded, size: 13, color: AppColors.white),
                                                            SizedBox(width: 5),
                                                            Text(
                                                              'Approval Disabled by Admin (Toggle OFF)',
                                                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.white),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                      ] else ...[
                                        const SizedBox(height: 10),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            ElevatedButton.icon(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: AppColors.primaryNavy,
                                                foregroundColor: AppColors.white,
                                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                              ),
                                              icon: const Icon(Icons.check_rounded, size: 18),
                                              label: const Text('Confirm RFID', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                              onPressed: () async {
                                                try {
                                                  await appState.confirmPendingRecord(item.id, appState.cashierName ?? 'Cashier', codeType: 'RFID');
                                                  if (context.mounted) {
                                                    TopAlert.show(context, 'Successfully confirmed RFID: ${item.code}', type: AlertType.success, title: 'RFID Confirmed');
                                                  }
                                                } catch (e) {
                                                  if (context.mounted) {
                                                    TopAlert.show(context, 'Error confirming: ${e.toString().replaceAll('Exception: ', '')}', type: AlertType.error, title: 'Confirmation Failed');
                                                  }
                                                }
                                              },
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),

                    // Tab 2: Approval History Log
                    historyList.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.history_rounded, size: 64, color: AppColors.grayText),
                                SizedBox(height: 12),
                                Text(
                                  'No approval history yet.',
                                  style: TextStyle(color: AppColors.grayText, fontWeight: FontWeight.w600, fontSize: 15),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            itemCount: historyList.length,
                            itemBuilder: (context, index) {
                              final record = historyList[index];
                              final isApproved = record.action == 'APPROVED';

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                elevation: 1,
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  leading: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: isApproved ? AppColors.success.withValues(alpha: 0.15) : AppColors.danger.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      isApproved ? Icons.check_circle_rounded : Icons.cancel_rounded,
                                      color: isApproved ? AppColors.success : AppColors.danger,
                                      size: 24,
                                    ),
                                  ),
                                  title: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          record.code,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primaryDarkNavy),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isApproved ? AppColors.success : AppColors.danger,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          record.action,
                                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.white),
                                        ),
                                      ),
                                    ],
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      Text('Customer: ${record.customerName}', style: const TextStyle(fontSize: 12, color: AppColors.grayText)),
                                      if (record.assignedDriver != null) ...[
                                        const SizedBox(height: 2),
                                        Text('Assigned Driver: ${record.assignedDriver}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.electricCyan)),
                                      ],
                                      const SizedBox(height: 2),
                                      Text(DateFormat('MMM d, yyyy h:mm a').format(record.timestamp), style: const TextStyle(fontSize: 10, color: AppColors.grayText)),
                                    ],
                                  ),
                                ),
                              );
                            },
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
}
