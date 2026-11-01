import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';
import '../models/gcash_models.dart';
import '../supabase_config.dart';

class AppState extends ChangeNotifier {
  String? _cashierName;
  String? _cashierId;
  CustomerInfo? _selectedCustomer;
  final List<CartItem> _cart = [];
  final List<TransactionRecord> _transactions = [];
  String _selectedCategory = 'All';
  String _searchQuery = '';
  bool _isLoading = false;

  String? _gcashQrUrl;
  String? _gcashNumber;
  String? _gcashAccountName;

  List<Product> _availableProducts = [];
  List<PendingApprovalRecord> _pendingApprovals = [];
  List<DriverInfo> _deliveryDrivers = [];
  List<ApprovalHistoryRecord> _approvalHistory = [];
  bool _isAuthorizedByAdmin = true;
  bool _canAcceptOrders = true;
  bool _canAssignDrivers = true;
  StreamSubscription<List<Map<String, dynamic>>>? _productsStreamSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _rfidStreamSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _salesStreamSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _ordersStreamSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _profileStreamSubscription;

  Future<SupabaseClient> _getSupabaseClient() async {
    try {
      return Supabase.instance.client;
    } catch (_) {
      try {
        await Supabase.initialize(
          url: SupabaseConfig.url,
          publishableKey: SupabaseConfig.anonKey,
        );
        return Supabase.instance.client;
      } catch (e) {
        throw Exception('Failed to initialize Supabase: $e');
      }
    }
  }

  SupabaseClient get _supabase {
    try {
      return Supabase.instance.client;
    } catch (e) {
      throw Exception('Supabase connection is not initialized ($e). Please refresh the page or check network settings.');
    }
  }

  String _normalizePaymentMethod(String? raw) {
    if (raw == null) return 'Cash';
    final lower = raw.toLowerCase();
    if (lower == 'gcash') return 'GCash';
    if (lower == 'cash') return 'Cash';
    if (lower == 'cod') return 'COD';
    return raw;
  }

  bool get isLoading => _isLoading;
  bool get isAuthorizedByAdmin => _isAuthorizedByAdmin;
  bool get canAcceptOrders => _canAcceptOrders;
  bool get canAssignDrivers => _canAssignDrivers;
  String? get cashierName => _cashierName;
  String? get cashierId => _cashierId;
  CustomerInfo? get selectedCustomer => _selectedCustomer;
  List<CartItem> get cart => _cart;
  List<Product> get availableProducts => _availableProducts;
  List<PendingApprovalRecord> get pendingApprovals => List.unmodifiable(_pendingApprovals);
  List<DriverInfo> get deliveryDrivers => List.unmodifiable(_deliveryDrivers);
  List<ApprovalHistoryRecord> get approvalHistory => List.unmodifiable(_approvalHistory);
  List<TransactionRecord> get transactions => List.unmodifiable(_transactions);
  String get selectedCategory => _selectedCategory;
  String get searchQuery => _searchQuery;

  String? get gcashQrUrl => _gcashQrUrl;
  String? get gcashNumber => _gcashNumber;
  String? get gcashAccountName => _gcashAccountName;
  String _fulfillmentType = 'Pick-up';

  String get fulfillmentType => _fulfillmentType;

  void setFulfillmentType(String type) {
    _fulfillmentType = type;
    notifyListeners();
  }

  List<String> get categories {
    final cats = _availableProducts.map((p) => p.category).toSet().toList();
    cats.sort();
    return ['All', ...cats];
  }

  List<Product> get filteredProducts {
    return _availableProducts.where((product) {
      final matchesCategory =
          _selectedCategory == 'All' || product.category == _selectedCategory;
      final matchesSearch =
          product.name.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();
  }

  int get totalCartItemsCount {
    return _cart.fold(0, (sum, item) => sum + item.quantity);
  }

  double get totalAmount {
    return _cart.fold(0, (sum, item) => sum + item.subtotal);
  }

  int getItemQuantityInCart(String productId) {
    final index = _cart.indexWhere((item) => item.product.id == productId);
    return index >= 0 ? _cart[index].quantity : 0;
  }

  void setCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  Future<CustomerInfo> setWalkInCustomer(
    String name,
    String phone,
    String address, {
    double? latitude,
    double? longitude,
  }) async {
    final cleanName = name.trim().isEmpty ? 'Walk-in Customer' : name.trim();
    final cleanPhone = phone.trim().isEmpty ? 'N/A' : phone.trim();
    final cleanAddress = address.trim().isEmpty ? 'Walk-in' : address.trim();

    _isLoading = true;
    notifyListeners();

    String profileId = '';

    // Save walk-in customer profile in Supabase profiles table with a unique phone/identifier so it never conflicts with or steals registered customer profiles
    try {
      final uniquePhone = cleanPhone == 'N/A' || cleanPhone.isEmpty
          ? 'WALKIN-${DateTime.now().millisecondsSinceEpoch}'
          : '${cleanPhone}-${DateTime.now().millisecondsSinceEpoch}';

      final profilePayload = <String, dynamic>{
        'full_name': cleanName,
        'phone': uniquePhone,
        'address': cleanAddress,
        'role': 'customer',
      };

      if (latitude != null && longitude != null) {
        profilePayload['latitude'] = latitude;
        profilePayload['longitude'] = longitude;
        profilePayload['lat'] = latitude;
        profilePayload['lng'] = longitude;
      }

      try {
        final inserted = await _supabase.from('profiles').insert(profilePayload).select('id').single();
        profileId = inserted['id'].toString();
      } catch (_) {
        // Fallback without extra lat/lng columns if schema lacks them
        final inserted = await _supabase.from('profiles').insert({
          'full_name': cleanName,
          'phone': uniquePhone,
          'address': cleanAddress,
          'role': 'customer',
        }).select('id').single();
        profileId = inserted['id'].toString();
      }
    } catch (insertErr) {
      debugPrint('Walk-in profile insert note: $insertErr');
    }

    final customer = CustomerInfo(
      id: profileId.isNotEmpty ? profileId : 'walk-in-${DateTime.now().millisecondsSinceEpoch}',
      fullName: cleanName,
      phone: cleanPhone,
      address: cleanAddress,
      latitude: latitude,
      longitude: longitude,
      rfidUid: 'WALK-IN',
      isLoyal: false,
    );

    _selectedCustomer = customer;
    _isLoading = false;
    notifyListeners();
    return customer;
  }

  void selectRegisteredCustomer(CustomerInfo customer) {
    _selectedCustomer = customer;
    notifyListeners();
  }

  Future<List<CustomerInfo>> searchRegisteredCustomers(String query) async {
    try {
      var request = _supabase
          .from('profiles')
          .select('id, full_name, phone, address')
          .eq('role', 'customer');

      if (query.trim().isNotEmpty) {
        request = request.or('full_name.ilike.%$query%,phone.ilike.%$query%');
      }

      final response = await request.order('full_name').limit(20);

      return (response as List).map((data) {
        return CustomerInfo(
          id: data['id'].toString(),
          fullName: data['full_name'] ?? 'Unknown',
          phone: data['phone']?.toString() ?? 'N/A',
          address: data['address']?.toString(),
          rfidUid: 'REGISTERED',
          isLoyal: true,
        );
      }).toList();
    } catch (e) {
      debugPrint('Error searching customers: $e');
      return [];
    }
  }

  void clearCustomer() {
    _selectedCustomer = null;
    notifyListeners();
  }

  Future<CustomerInfo?> findCustomerByRfidUid(String rawRfidUid) async {
    final cleanUid = rawRfidUid.trim();
    if (cleanUid.isEmpty) return null;

    try {
      // 1. Query rfid_qr_records using exact schema columns: code, code_type, is_active, customer_id, gallon_id
      final rfidRows = await _supabase
          .from('rfid_qr_records')
          .select('customer_id, gallon_id')
          .eq('code_type', 'RFID')
          .eq('is_active', true)
          .eq('code', cleanUid);

      if (rfidRows.isEmpty) {
        throw Exception('No active RFID record found matching card code: $cleanUid');
      }

      final rfidRecord = rfidRows.first;
      final customerId = rfidRecord['customer_id']?.toString();
      final gallonId = rfidRecord['gallon_id']?.toString();

      if (customerId == null || customerId.isEmpty) {
        throw Exception('RFID card $cleanUid is not linked to a customer account.');
      }

      String? gallonCode;
      // 2. Query gallons table if gallon_id exists using exact column: gallon_code
      if (gallonId != null && gallonId.isNotEmpty) {
        try {
          final gallonRow = await _supabase
              .from('gallons')
              .select('gallon_code')
              .eq('id', gallonId)
              .maybeSingle();
          if (gallonRow != null) {
            gallonCode = gallonRow['gallon_code']?.toString();
          }
        } catch (gallonErr) {
          debugPrint('Gallon lookup error: $gallonErr');
        }
      }

      // 3. Query profiles table by customer_id (resolving real profiles.id)
      final profileData = await _supabase
          .from('profiles')
          .select('id, full_name, phone')
          .eq('id', customerId)
          .maybeSingle();

      if (profileData != null) {
        final customer = CustomerInfo(
          id: profileData['id'].toString(),
          fullName: profileData['full_name'] ?? 'Loyal Customer',
          phone: profileData['phone']?.toString() ?? 'N/A',
          rfidUid: cleanUid,
          gallonId: gallonId,
          gallonCode: gallonCode,
          isLoyal: true,
        );

        _selectedCustomer = customer;
        notifyListeners();
        return customer;
      } else {
        throw Exception('No customer profile found for ID: $customerId');
      }
    } catch (e) {
      debugPrint('Customer RFID lookup failed: $e');
      rethrow;
    }
  }

  static const String _kSalesCacheKey = 'cached_sales_history_v2';

  Future<void> saveTransactionsToLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _transactions.map((tx) => jsonEncode(tx.toJson())).toList();
      await prefs.setStringList(_kSalesCacheKey, jsonList);
    } catch (e) {
      debugPrint('Error saving transactions to local storage: $e');
    }
  }

  Future<void> loadTransactionsFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = prefs.getStringList(_kSalesCacheKey);
      if (jsonList != null && jsonList.isNotEmpty) {
        final Map<String, TransactionRecord> map = {};
        for (var tx in _transactions) {
          if (tx.id.isNotEmpty) map[tx.id] = tx;
        }
        for (var str in jsonList) {
          try {
            final jsonMap = jsonDecode(str) as Map<String, dynamic>;
            final tx = TransactionRecord.fromJson(jsonMap);
            if (tx.id.isNotEmpty) {
              map[tx.id] = tx;
            }
          } catch (_) {}
        }
        _transactions.clear();
        _transactions.addAll(map.values);
        _transactions.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading transactions from local storage: $e');
    }
  }

  Future<bool> restoreSession() async {
    try {
      await loadTransactionsFromLocal();
      final session = _supabase.auth.currentSession;
      final user = session?.user;
      if (user != null) {
        final profile = await _supabase
            .from('profiles')
            .select('*')
            .eq('id', user.id)
            .single();

        final role = profile['role']?.toString().toLowerCase();
        if (role == 'cashier') {
          _cashierName = profile['full_name'] ?? 'Cashier';
          _cashierId = user.id;
          if (profile.containsKey('can_accept_orders') && profile['can_accept_orders'] != null) {
            _canAcceptOrders = profile['can_accept_orders'] == true;
          }
          if (profile.containsKey('can_assign_drivers') && profile['can_assign_drivers'] != null) {
            _canAssignDrivers = profile['can_assign_drivers'] == true;
          }
          await loadProducts();
          await loadGCashSettings();
          await fetchPendingApprovals();
          subscribeToProductsRealtime();
          subscribeToRfidRegistryRealtime();
          subscribeToSalesRealtime();
          subscribeToCashierProfileRealtime();
          await checkAdminAuthorization();
          await loadDailySales();
          notifyListeners();
          return true;
        } else {
          debugPrint('Session restore rejected: Account role "$role" is not cashier.');
          await _supabase.auth.signOut();
          return false;
        }
      }
    } catch (e) {
      debugPrint('Error restoring session: $e');
    }
    return false;
  }

  Future<void> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final client = await _getSupabaseClient();

      final response = await client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final user = response.user;
      if (user == null) {
        throw Exception('Login failed: Invalid credentials');
      }

      final profile = await client
          .from('profiles')
          .select('*')
          .eq('id', user.id)
          .single();

      final role = profile['role']?.toString().toLowerCase();
      if (role != 'cashier') {
        await client.auth.signOut();
        throw Exception('Access denied: role = cashier required. Your account role is "$role".');
      }

      _cashierName = profile['full_name'] ?? 'Cashier';
      _cashierId = user.id;
      if (profile.containsKey('can_accept_orders') && profile['can_accept_orders'] != null) {
        _canAcceptOrders = profile['can_accept_orders'] == true;
      }
      if (profile.containsKey('can_assign_drivers') && profile['can_assign_drivers'] != null) {
        _canAssignDrivers = profile['can_assign_drivers'] == true;
      }

      await loadTransactionsFromLocal();
      await loadProducts();
      await loadGCashSettings();
      await fetchPendingApprovals();
      subscribeToProductsRealtime();
      subscribeToRfidRegistryRealtime();
      subscribeToSalesRealtime();
      subscribeToCashierProfileRealtime();
      await checkAdminAuthorization();
      await loadDailySales();

    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }

    _isLoading = false;
    notifyListeners();
  }

  static const String _kGCashQrUrlKey = 'cached_gcash_qr_url';
  static const String _kGCashNumberKey = 'cached_gcash_number';
  static const String _kGCashAccountNameKey = 'cached_gcash_account_name';

  Future<void> saveGCashSettingsToLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_gcashQrUrl != null) await prefs.setString(_kGCashQrUrlKey, _gcashQrUrl!);
      if (_gcashNumber != null) await prefs.setString(_kGCashNumberKey, _gcashNumber!);
      if (_gcashAccountName != null) await prefs.setString(_kGCashAccountNameKey, _gcashAccountName!);
    } catch (e) {
      debugPrint('Error saving GCash settings to local storage: $e');
    }
  }

  Future<void> loadGCashSettingsFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final qr = prefs.getString(_kGCashQrUrlKey);
      final num = prefs.getString(_kGCashNumberKey);
      final name = prefs.getString(_kGCashAccountNameKey);

      if (qr != null && qr.isNotEmpty) _gcashQrUrl = qr;
      if (num != null && num.isNotEmpty) _gcashNumber = num;
      if (name != null && name.isNotEmpty) _gcashAccountName = name;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading GCash settings from local storage: $e');
    }
  }

  Future<void> loadGCashSettings() async {
    await loadGCashSettingsFromLocal();

    String? foundQrUrl;
    String? foundNumber;
    String? foundAccountName;

    String? sanitizeName(String? raw) {
      if (raw == null) return null;
      final str = raw.trim();
      final lower = str.toLowerCase();
      if (str.isEmpty || lower == 'new user' || lower == 'customer' || lower == 'walk-in' || lower == 'null') {
        return null;
      }
      return str;
    }

    String? sanitizePhone(String? raw) {
      if (raw == null) return null;
      final str = raw.trim();
      final digits = str.replaceAll(RegExp(r'[^\d+]'), '');
      if (digits.length >= 10 && (digits.startsWith('09') || digits.startsWith('639') || digits.startsWith('+639'))) {
        return str;
      }
      return null;
    }

    final stationCandidateTables = [
      'station_settings',
      'system_settings',
      'store_settings',
      'settings',
      'gcash_settings',
      'payment_methods',
      'payment_settings',
      'store_info',
      'app_settings',
      'rfid_qr_records',
      'profiles',
    ];

    for (final table in stationCandidateTables) {
      try {
        final List<dynamic> rows = await _supabase.from(table).select();
        for (var rawRow in rows) {
          if (rawRow is! Map) continue;
          final Map<String, dynamic> settings = Map<String, dynamic>.from(rawRow);

          final gcashQrUrl = settings['gcash_qr_image_url']?.toString() ??
                             settings['gcash_qr_url']?.toString() ??
                             settings['gcash_qr_code']?.toString() ??
                             settings['qr_code_url']?.toString() ??
                             settings['qr_image_url']?.toString() ??
                             settings['value']?.toString() ?? '';

          if (gcashQrUrl.isNotEmpty && (gcashQrUrl.startsWith('http') || gcashQrUrl.startsWith('data:image'))) {
            foundQrUrl ??= gcashQrUrl;
          }

          final gcashNum = settings['gcash_number']?.toString() ??
                           settings['gcash_phone']?.toString() ??
                           settings['phone_number']?.toString() ??
                           settings['phone']?.toString() ??
                           settings['mobile']?.toString() ?? '';
          if (gcashNum.isNotEmpty) {
            foundNumber ??= gcashNum;
          }

          final gcashName = settings['gcash_account_name']?.toString() ??
                            settings['account_name']?.toString() ??
                            settings['store_name']?.toString() ??
                            settings['name']?.toString() ?? '';
          if (gcashName.isNotEmpty) {
            final cleaned = sanitizeName(gcashName);
            if (cleaned != null) foundAccountName ??= cleaned;
          }

          // Also check generic key-value rows
          final k = (settings['key'] ?? settings['setting_key'] ?? settings['name'])?.toString().toLowerCase();
          final v = (settings['value'] ?? settings['setting_value'] ?? settings['val'])?.toString();
          if (k != null && v != null && v.isNotEmpty) {
            if ((k.contains('qr') || k.contains('image')) && (v.startsWith('http') || v.startsWith('data:image'))) {
              foundQrUrl ??= v;
            } else if (k.contains('number') || k.contains('phone') || k.contains('gcash')) {
              foundNumber ??= v;
            } else if (k.contains('account') || k.contains('store') || k.contains('name')) {
              final cleaned = sanitizeName(v);
              if (cleaned != null) foundAccountName ??= cleaned;
            }
          }
        }
      } catch (_) {}
    }

    if (foundQrUrl == null || foundQrUrl.isEmpty) {
      for (final bucket in ['qr-codes', 'qr_codes', 'gcash', 'gcash_qr', 'gcash-qr', 'public', 'images', 'uploads', 'store', 'avatars', 'photos', 'payments', 'qr']) {
        try {
          final List<FileObject> files = await _supabase.storage.from(bucket).list();
          for (final f in files) {
            final publicUrl = _supabase.storage.from(bucket).getPublicUrl(f.name);
            if (publicUrl.isNotEmpty) {
              foundQrUrl = publicUrl;
              break;
            }
          }
          if (foundQrUrl != null) break;
        } catch (_) {}
      }
    }

    if (foundQrUrl != null && foundQrUrl.isNotEmpty) {
      _gcashQrUrl = foundQrUrl;
    }
    if (foundNumber != null && foundNumber.isNotEmpty) {
      _gcashNumber = foundNumber;
    }
    if (foundAccountName != null && foundAccountName.isNotEmpty) {
      _gcashAccountName = foundAccountName;
    }

    await saveGCashSettingsToLocal();
    notifyListeners();
  }

  Future<void> updateGCashSettings({
    String? qrUrl,
    String? number,
    String? accountName,
  }) async {
    if (qrUrl != null && qrUrl.isNotEmpty) _gcashQrUrl = qrUrl;
    if (number != null && number.isNotEmpty) _gcashNumber = number;
    if (accountName != null && accountName.isNotEmpty) _gcashAccountName = accountName;

    await saveGCashSettingsToLocal();
    notifyListeners();

    try {
      final updates = <Map<String, dynamic>>[];
      if (qrUrl != null) updates.add({'key': 'gcash_qr_url', 'value': qrUrl});
      if (number != null) updates.add({'key': 'gcash_number', 'value': number});
      if (accountName != null) updates.add({'key': 'gcash_account_name', 'value': accountName});

      for (var item in updates) {
        await _supabase.from('store_settings').upsert(item);
      }
    } catch (e) {
      debugPrint('Note on upsert store_settings key-value: $e');
    }

    try {
      await _supabase.from('store_settings').upsert({
        'id': 1,
        'gcash_qr_url': qrUrl ?? _gcashQrUrl,
        'gcash_number': number ?? _gcashNumber,
        'gcash_account_name': accountName ?? _gcashAccountName,
      });
    } catch (e) {
      debugPrint('Note on upsert store_settings column row: $e');
    }

    if (qrUrl != null && qrUrl.isNotEmpty) {
      try {
        await _supabase.from('rfid_qr_records').upsert({
          'code': qrUrl,
          'code_type': 'GCASH_QR',
          'is_active': true,
        });
      } catch (e) {
        debugPrint('Note on upsert rfid_qr_records: $e');
      }
    }
  }

  Future<GCashVerificationStatus> verifyGCashReference(
    String rawRefNo,
    double expectedAmount,
  ) async {
    final cleanRef = rawRefNo.replaceAll(' ', '').trim();
    if (cleanRef.isEmpty) {
      return GCashVerificationStatus(
        result: GCashVerificationResult.unverified,
        message: 'Please enter or scan a GCash Reference Number.',
      );
    }

    // 1. Check if reference number has already been used in sales table
    try {
      final existingSale = await _supabase
          .from('sales')
          .select('receipt_number')
          .eq('gcash_ref_no', cleanRef)
          .maybeSingle();

      if (existingSale != null) {
        return GCashVerificationStatus(
          result: GCashVerificationResult.alreadyUsed,
          message: 'This Reference No. ($cleanRef) was already used in Receipt #${existingSale['receipt_number']}.',
          usedInReceipt: existingSale['receipt_number']?.toString(),
        );
      }
    } catch (_) {}

    // 2. Check admin_gcash_records / gcash_records / gcash_payments / gcash_verifications tables
    for (final tableName in ['admin_gcash_records', 'gcash_records', 'gcash_payments', 'gcash_verifications']) {
      try {
        final adminRecord = await _supabase
            .from(tableName)
            .select()
            .or('reference_number.eq.$cleanRef,ref_no.eq.$cleanRef,reference_no.eq.$cleanRef,transaction_id.eq.$cleanRef')
            .maybeSingle();

        if (adminRecord != null) {
          final bool isUsed = adminRecord['is_used'] == true || adminRecord['status']?.toString().toLowerCase() == 'used';
          final double recordAmount = (adminRecord['amount'] as num? ?? adminRecord['total'] as num? ?? 0.0).toDouble();
          final String? usedReceipt = (adminRecord['used_in_receipt'] ?? adminRecord['receipt_number'] ?? adminRecord['used_by'])?.toString();

          if (isUsed) {
            return GCashVerificationStatus(
              result: GCashVerificationResult.alreadyUsed,
              message: 'This Reference No. ($cleanRef) was already marked as used in Receipt #${usedReceipt ?? 'N/A'}.',
              usedInReceipt: usedReceipt,
              adminRecordId: adminRecord['id']?.toString(),
              adminRecordAmount: recordAmount,
            );
          }

          if ((recordAmount - expectedAmount).abs() > 0.01 && expectedAmount > 0) {
            return GCashVerificationStatus(
              result: GCashVerificationResult.amountMismatch,
              message: 'Reference found, but Admin uploaded amount is ₱${recordAmount.toStringAsFixed(2)} (Expected: ₱${expectedAmount.toStringAsFixed(2)}).',
              adminRecordId: adminRecord['id']?.toString(),
              adminRecordAmount: recordAmount,
            );
          }

          return GCashVerificationStatus(
            result: GCashVerificationResult.verified,
            message: 'Verified! Reference No. $cleanRef matched Admin record (₱${recordAmount.toStringAsFixed(2)}).',
            adminRecordId: adminRecord['id']?.toString(),
            adminRecordAmount: recordAmount,
          );
        }
      } catch (e) {
        debugPrint('Note on $tableName lookup: $e');
      }
    }

    return GCashVerificationStatus(
      result: GCashVerificationResult.notFound,
      message: 'Reference No. $cleanRef is NOT found in the Admin uploaded list. Cashier must manually verify receipt.',
    );
  }

  Future<void> addAdminGCashRecord(String refNo, double amount) async {
    final cleanRef = refNo.replaceAll(' ', '').trim();
    if (cleanRef.isEmpty) return;

    try {
      await _supabase.from('admin_gcash_records').upsert({
        'reference_number': cleanRef,
        'amount': amount,
        'is_used': false,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Note on adding admin_gcash_record: $e');
      rethrow;
    }
  }

  Future<void> uploadBatchGCashRecords(List<Map<String, dynamic>> records) async {
    try {
      await _supabase.from('admin_gcash_records').upsert(records);
    } catch (e) {
      debugPrint('Note on batch upsert admin_gcash_records: $e');
      rethrow;
    }
  }

  Future<List<AdminGCashRecord>> fetchAdminGCashRecords() async {
    for (final tableName in ['admin_gcash_records', 'gcash_records', 'gcash_payments', 'gcash_verifications']) {
      try {
        final rows = await _supabase
            .from(tableName)
            .select()
            .order('created_at', ascending: false)
            .limit(100);

        if ((rows as List).isNotEmpty) {
          return rows.map((r) {
            final ref = r['reference_number'] ?? r['ref_no'] ?? r['reference_no'] ?? r['transaction_id'] ?? '';
            final amt = (r['amount'] as num? ?? r['total'] as num? ?? 0.0).toDouble();
            final isUsed = r['is_used'] == true || r['status']?.toString().toLowerCase() == 'used';
            final usedReceipt = (r['used_in_receipt'] ?? r['receipt_number'])?.toString();
            final id = r['id']?.toString() ?? '';
            final createdAt = DateTime.tryParse(r['created_at']?.toString() ?? '') ?? DateTime.now();

            return AdminGCashRecord(
              id: id,
              referenceNumber: ref.toString(),
              amount: amt,
              isUsed: isUsed,
              usedInReceipt: usedReceipt,
              createdAt: createdAt,
            );
          }).toList();
        }
      } catch (e) {
        debugPrint('Note on fetchAdminGCashRecords from $tableName: $e');
      }
    }
    return [];
  }

  Future<void> logout() async {
    _productsStreamSubscription?.cancel();
    _productsStreamSubscription = null;
    _rfidStreamSubscription?.cancel();
    _rfidStreamSubscription = null;
    _salesStreamSubscription?.cancel();
    _salesStreamSubscription = null;

    try {
      await _supabase.auth.signOut();
    } catch (e) {
      debugPrint('Logout note: $e');
    }

    _cashierName = null;
    _cashierId = null;
    _selectedCustomer = null;
    _cart.clear();
    // Keep transactions loaded locally so sales history is never lost
    _availableProducts.clear();
    notifyListeners();
  }

  Future<void> loadProducts() async {
    try {
      final data = await _supabase
          .from('products')
          .select()
          .eq('is_active', true);

      _availableProducts = (data as List).map((json) {
        final category = json['category']?.toString() ?? 'General';
        IconData icon = Icons.local_mall;
        final nameLower = (json['name'] ?? '').toString().toLowerCase();
        if (nameLower.contains('refill') || nameLower.contains('water') || nameLower.contains('gallon')) {
          icon = Icons.water_drop;
        } else if (nameLower.contains('container') || nameLower.contains('bottle')) {
          icon = Icons.shopping_bag;
        } else if (nameLower.contains('cap') || nameLower.contains('pump') || nameLower.contains('tap')) {
          icon = Icons.plumbing;
        }

        final stockVal = json['stock'];
        final imageUrlStr = (json['image_url'] ??
                json['image'] ??
                json['imageUrl'] ??
                json['photo_url'] ??
                json['img_url'])
            ?.toString();

        return Product(
          id: json['id'].toString(),
          name: json['name'] ?? 'Product',
          price: (json['price'] as num? ?? 0.0).toDouble(),
          category: category,
          icon: icon,
          stock: stockVal != null ? (stockVal as num).toInt() : null,
          description: json['description']?.toString(),
          imageUrl: imageUrlStr,
        );
      }).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading products: $e');
    }
  }

  Future<void> fetchPendingApprovals() async {
    try {
      await checkAdminAuthorization();
      final List<PendingApprovalRecord> records = [];

      // 1. Fetch pending RFID/QR records
      try {
        final rfidRows = await _supabase
            .from('rfid_qr_records')
            .select('id, code, code_type, customer_id, is_active, created_at')
            .eq('is_active', false)
            .order('created_at', ascending: false);

        for (var row in rfidRows) {
          String? customerName;
          final customerId = row['customer_id']?.toString();
          if (customerId != null && customerId.isNotEmpty) {
            try {
              final profile = await _supabase
                  .from('profiles')
                  .select('full_name')
                  .eq('id', customerId)
                  .maybeSingle();
              if (profile != null) {
                customerName = profile['full_name']?.toString();
              }
            } catch (_) {}
          }

          DateTime? createdAt;
          if (row['created_at'] != null) {
            createdAt = DateTime.tryParse(row['created_at'].toString());
          }

          records.add(PendingApprovalRecord(
            id: row['id'].toString(),
            code: row['code']?.toString() ?? '',
            codeType: row['code_type']?.toString() ?? 'RFID',
            customerId: customerId,
            customerName: customerName ?? 'Unassigned Customer',
            isActive: false,
            createdAt: createdAt,
          ));
        }
      } catch (e) {
        debugPrint('Note on RFID pending fetch: $e');
      }

      // 2. Fetch Pending Orders from 'orders' table
      try {
        List<dynamic> orderRows = [];
        try {
          orderRows = await _supabase
              .from('orders')
              .select('''
                *,
                profiles:customer_id (full_name, phone, address)
              ''')
              .order('created_at', ascending: false)
              .limit(100);
        } catch (e) {
          debugPrint('Note on orders join query: $e');
          // Fallback if profiles FK relationship does not exist in schema
          orderRows = await _supabase
              .from('orders')
              .select('*')
              .order('created_at', ascending: false)
              .limit(100);
        }

        for (var row in orderRows) {
          final statusStr = (row['status'] ?? '').toString().toLowerCase().trim();
          final orderStatusStr = (row['order_status'] ?? '').toString().toLowerCase().trim();

          // ONLY include if it clearly indicates it needs approval
          final bool isPending = statusStr.contains('pending') ||
              statusStr.contains('approval') ||
              statusStr.contains('unpaid') ||
              statusStr == 'placed' ||
              orderStatusStr.contains('pending');

          if (!isPending) continue;

          String customerName = 'Customer';
          String? address = row['address']?.toString() ??
              row['delivery_address']?.toString() ??
              row['shipping_address']?.toString();

          if (row['profiles'] != null && row['profiles'] is Map) {
            final prof = row['profiles'] as Map<String, dynamic>;
            customerName = prof['full_name']?.toString() ?? customerName;
            address ??= prof['address']?.toString();
          } else if (row['customer_name'] != null && row['customer_name'].toString().isNotEmpty) {
            customerName = row['customer_name'].toString();
          } else if (row['full_name'] != null && row['full_name'].toString().isNotEmpty) {
            customerName = row['full_name'].toString();
          } else if (row['client_name'] != null && row['client_name'].toString().isNotEmpty) {
            customerName = row['client_name'].toString();
          }

          // Fallback profile lookup if customerName is generic and customer_id is available
          if (customerName == 'Customer' && row['customer_id'] != null) {
            final custId = row['customer_id'].toString();
            if (custId.isNotEmpty) {
              try {
                final prof = await _supabase
                    .from('profiles')
                    .select('full_name, address')
                    .eq('id', custId)
                    .maybeSingle();
                if (prof != null) {
                  if (prof['full_name'] != null) customerName = prof['full_name'].toString();
                  address ??= prof['address']?.toString();
                }
              } catch (_) {}
            }
          }

          DateTime? createdAt;
          if (row['created_at'] != null) {
            createdAt = DateTime.tryParse(row['created_at'].toString());
          }

          final orderCode = row['order_number']?.toString() ??
              row['receipt_number']?.toString() ??
              row['code']?.toString() ??
              row['id'].toString();

          records.add(PendingApprovalRecord(
            id: row['id'].toString(),
            code: orderCode,
            codeType: 'ORDER',
            customerId: row['customer_id']?.toString(),
            customerName: customerName,
            address: address,
            totalAmount: (row['total_amount'] as num? ?? row['total'] as num? ?? row['amount'] as num? ?? 0.0).toDouble(),
            paymentMethod: _normalizePaymentMethod(row['payment_method']?.toString() ?? row['payment_type']?.toString()),
            itemCount: row['item_count'] as int? ?? row['total_items'] as int? ?? row['quantity'] as int? ?? 1,
            isActive: false,
            createdAt: createdAt,
          ));
        }
      } catch (e) {
        debugPrint('Note on Orders pending fetch: $e');
      }

      // 3. Supplement with pending records from 'sales' table if not already added
      try {
        List<dynamic> salesRows = [];
        try {
          salesRows = await _supabase
              .from('sales')
              .select('''
                *,
                profiles:customer_id (full_name, phone, address)
              ''')
              .order('created_at', ascending: false)
              .limit(50);
        } catch (_) {
          salesRows = await _supabase
              .from('sales')
              .select('*')
              .order('created_at', ascending: false)
              .limit(50);
        }

        for (var row in salesRows) {
          final statusStr = (row['status'] ?? '').toString().toLowerCase().trim();
          final orderStatusStr = (row['order_status'] ?? '').toString().toLowerCase().trim();

          final bool isPending = statusStr.contains('pending') ||
              statusStr.contains('approval') ||
              statusStr.contains('unpaid') ||
              statusStr == 'placed' ||
              orderStatusStr.contains('pending');

          if (!isPending) continue;

          final rowId = row['id'].toString();
          final code = row['receipt_number']?.toString() ?? rowId;

          // Skip if already added from orders table
          if (records.any((r) => r.id == rowId || r.code == code)) continue;

          String customerName = 'Customer';
          String? address = row['address']?.toString();
          if (row['profiles'] != null && row['profiles'] is Map) {
            final prof = row['profiles'] as Map<String, dynamic>;
            customerName = prof['full_name']?.toString() ?? customerName;
            address ??= prof['address']?.toString();
          }

          DateTime? createdAt;
          if (row['created_at'] != null) {
            createdAt = DateTime.tryParse(row['created_at'].toString());
          }

          records.add(PendingApprovalRecord(
            id: rowId,
            code: code,
            codeType: 'ORDER',
            customerId: row['customer_id']?.toString(),
            customerName: customerName,
            address: address,
            totalAmount: (row['total_amount'] as num? ?? row['total'] as num? ?? 0.0).toDouble(),
            paymentMethod: _normalizePaymentMethod(row['payment_method']?.toString()),
            itemCount: 1,
            isActive: false,
            createdAt: createdAt,
          ));
        }
      } catch (e2) {
        debugPrint('Note on Sales pending fetch: $e2');
      }

      _pendingApprovals = records;
      _isAuthorizedByAdmin = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching pending approvals: $e');
    }
  }

  void toggleAdminAuthorization() {
    _isAuthorizedByAdmin = !_isAuthorizedByAdmin;
    notifyListeners();
  }

  Future<void> checkAdminAuthorization() async {
    try {
      if (_cashierId != null && _cashierId!.isNotEmpty) {
        final profile = await _supabase
            .from('profiles')
            .select('*')
            .eq('id', _cashierId!)
            .maybeSingle();

        if (profile != null) {
          debugPrint('Profile auth check raw: $profile');

          if (profile.containsKey('can_accept_orders')) {
            final val = profile['can_accept_orders'];
            if (val is bool) {
              _canAcceptOrders = val;
            } else if (val != null) {
              final s = val.toString().toLowerCase().trim();
              _canAcceptOrders = s == 'true' || s == '1' || s == 'yes';
            } else {
              _canAcceptOrders = true;
            }
          }

          if (profile.containsKey('can_assign_drivers')) {
            final val = profile['can_assign_drivers'];
            if (val is bool) {
              _canAssignDrivers = val;
            } else if (val != null) {
              final s = val.toString().toLowerCase().trim();
              _canAssignDrivers = s == 'true' || s == '1' || s == 'yes';
            } else {
              _canAssignDrivers = true;
            }
          }

          debugPrint('Checked admin authorization: canAcceptOrders=$_canAcceptOrders, canAssignDrivers=$_canAssignDrivers');
          notifyListeners();
          return;
        }
      }
    } catch (e) {
      debugPrint('Note on admin authorization check from profiles: $e');
    }

    try {
      final orders = await _supabase
          .from('orders')
          .select('id, is_authorized, authorized_cashier_id')
          .limit(10);

      for (var order in orders) {
        if (order['is_authorized'] == true ||
            (order['authorized_cashier_id']?.toString() == _cashierId)) {
          _isAuthorizedByAdmin = true;
          notifyListeners();
          return;
        }
      }
    } catch (e) {
      debugPrint('Note on admin authorization check from orders: $e');
    }

    notifyListeners();
  }

  Future<void> fetchDeliveryDrivers() async {
    try {
      final rows = await _supabase
          .from('profiles')
          .select('id, full_name, role')
          .or('role.ilike.driver,role.ilike.delivery');

      _deliveryDrivers = rows.map((r) => DriverInfo.fromJson(r)).toList();

      if (_deliveryDrivers.isEmpty) {
        final allRows = await _supabase
            .from('profiles')
            .select('id, full_name, role')
            .neq('role', 'customer');
        _deliveryDrivers = allRows.map((r) => DriverInfo.fromJson(r)).toList();
      }

      if (_deliveryDrivers.isEmpty) {
        _deliveryDrivers = [
          DriverInfo(id: 'drv-1', fullName: 'Juan Dela Cruz (Driver)', role: 'driver'),
        ];
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching delivery drivers from database: $e');
      if (_deliveryDrivers.isEmpty) {
        _deliveryDrivers = [
          DriverInfo(id: 'drv-1', fullName: 'Juan Dela Cruz (Driver)', role: 'driver'),
        ];
      }
    }
  }

  Future<void> confirmPendingRecord(
    String recordId,
    String cashierName, {
    String codeType = 'RFID',
    String? driverId,
    String? driverName,
  }) async {
    if (codeType == 'ORDER') {
      await checkAdminAuthorization();
      if (!_canAcceptOrders) {
        _isLoading = false;
        notifyListeners();
        throw Exception('Order acceptance is currently disabled by Admin (Toggle OFF).');
      }
    }
    _isLoading = true;
    notifyListeners();
    try {
      final itemIndex = _pendingApprovals.indexWhere((item) => item.id == recordId);
      final item = itemIndex != -1 ? _pendingApprovals[itemIndex] : null;

      if (codeType == 'ORDER') {
        debugPrint('Order $recordId confirmed with driver $driverName');
        try {
          // Update orders table with generic status that the admin side expects.
          // Usually 'Approved', 'For Dispatch', or 'Processing'
          await _supabase.from('orders').update({
            'status': 'For Dispatch', 
            'order_status': 'approved',
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', recordId);
        } catch (e) {
          debugPrint('Note updating order status in orders table: $e');
        }

        try {
          await _supabase.from('sales').update({
            'status': 'For Dispatch',
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', recordId);
        } catch (_) {}

        // Try to update the driver assignment. If columns don't exist, this will quietly fail.
        if (driverId != null) {
          for (final driverCol in ['delivery_driver_id', 'driver_id', 'assigned_driver_id']) {
            try {
              await _supabase.from('orders').update({
                driverCol: driverId,
                'driver_name': driverName, // May fail if driver_name doesn't exist
              }).eq('id', recordId);
              break; // Stop if successful
            } catch (_) {}
          }
          for (final driverCol in ['delivery_driver_id', 'driver_id', 'assigned_driver_id']) {
            try {
              await _supabase.from('sales').update({
                driverCol: driverId,
                'driver_name': driverName,
              }).eq('id', recordId);
              break;
            } catch (_) {}
          }
        }

        // If it was paid via GCash, create the admin GCash record too
        if (item != null && (item.paymentMethod?.toUpperCase() == 'GCASH' || item.code.length >= 8)) {
          final cleanRef = item.code.replaceAll(' ', '').trim();
          final recordData = {
            'reference_number': cleanRef,
            'amount': item.totalAmount ?? 0.0,
            'is_used': true,
            'status': 'used',
            'used_in_receipt': cleanRef,
            'customer_name': item.customerName ?? 'Customer',
            'cashier_name': cashierName,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          };
          for (final tableName in ['admin_gcash_records', 'gcash_records', 'gcash_payments', 'gcash_verifications']) {
            try {
              await _supabase.from(tableName).upsert(recordData, onConflict: 'reference_number');
            } catch (_) {}
          }
        }
      } else {
        await _supabase
            .from('rfid_qr_records')
            .update({
              'is_active': true,
            })
            .eq('id', recordId);
      }

      if (item != null) {
        _approvalHistory.insert(0, ApprovalHistoryRecord(
          id: item.id,
          code: item.code,
          customerName: item.customerName ?? 'Customer',
          action: 'APPROVED',
          assignedDriver: driverName,
          timestamp: DateTime.now(),
        ));
      }

      try {
        await _supabase.from('notifications').insert({
          'title': codeType == 'ORDER' ? 'Order Approved & Dispatched' : 'RFID Confirmed',
          'message': 'Code ${item?.code ?? recordId} approved by cashier $cashierName${driverName != null ? ' and assigned to $driverName' : ''}',
          'type': codeType == 'ORDER' ? 'order_approval' : 'rfid_approval',
          'reference_id': recordId,
          'cashier_name': cashierName,
          'created_at': DateTime.now().toIso8601String(),
        });
      } catch (notifErr) {
        debugPrint('Note on admin notification insert: $notifErr');
      }

      _pendingApprovals.removeWhere((item) => item.id == recordId);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _pendingApprovals.removeWhere((item) => item.id == recordId);
      _isLoading = false;
      notifyListeners();
      debugPrint('Confirm pending record completed with note: $e');
    }
  }

  Future<void> rejectPendingRecord(
    String recordId,
    String cashierName, {
    String codeType = 'RFID',
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final itemIndex = _pendingApprovals.indexWhere((item) => item.id == recordId);
      final item = itemIndex != -1 ? _pendingApprovals[itemIndex] : null;

      if (codeType == 'ORDER') {
        debugPrint('Order $recordId rejected');
        try {
          await _supabase.from('orders').update({
            'status': 'Cancelled', 
            'order_status': 'cancelled',
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', recordId);
        } catch (e) {
          debugPrint('Note updating order status in orders table to rejected: $e');
        }

        try {
          await _supabase.from('sales').update({
            'status': 'Cancelled',
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', recordId);
        } catch (_) {}
      } else {
        await _supabase
            .from('rfid_qr_records')
            .delete()
            .eq('id', recordId);
      }

      if (item != null) {
        _approvalHistory.insert(0, ApprovalHistoryRecord(
          id: item.id,
          code: item.code,
          customerName: item.customerName ?? 'Customer',
          action: 'REJECTED',
          timestamp: DateTime.now(),
        ));
      }

      try {
        await _supabase.from('notifications').insert({
          'title': 'Record Rejected',
          'message': 'Code ${item?.code ?? recordId} rejected by cashier $cashierName',
          'type': 'rejection',
          'reference_id': recordId,
          'cashier_name': cashierName,
          'created_at': DateTime.now().toIso8601String(),
        });
      } catch (notifErr) {
        debugPrint('Note on admin notification insert: $notifErr');
      }

      _pendingApprovals.removeWhere((item) => item.id == recordId);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _pendingApprovals.removeWhere((item) => item.id == recordId);
      _isLoading = false;
      notifyListeners();
      debugPrint('Reject pending record completed with note: $e');
    }
  }

  void subscribeToCashierProfileRealtime() {
    _profileStreamSubscription?.cancel();
    if (_cashierId == null) return;
    try {
      _profileStreamSubscription = _supabase
          .from('profiles')
          .stream(primaryKey: ['id'])
          .eq('id', _cashierId!)
          .listen((data) {
            if (data.isNotEmpty) {
              final profile = data.first;
              if (profile.containsKey('can_accept_orders') && profile['can_accept_orders'] != null) {
                _canAcceptOrders = profile['can_accept_orders'] == true;
              }
              if (profile.containsKey('can_assign_drivers') && profile['can_assign_drivers'] != null) {
                _canAssignDrivers = profile['can_assign_drivers'] == true;
              }
              notifyListeners();
            }
          }, onError: (e) {
            debugPrint('Realtime cashier profile stream error: $e');
          });
    } catch (e) {
      debugPrint('Error initializing cashier profile stream: $e');
    }
  }

  void subscribeToProductsRealtime() {
    _productsStreamSubscription?.cancel();
    try {
      _productsStreamSubscription = _supabase
          .from('products')
          .stream(primaryKey: ['id'])
          .eq('is_active', true)
          .listen((data) {
            _availableProducts = data.map((json) {
              final category = json['category']?.toString() ?? 'General';
              IconData icon = Icons.local_mall;
              final nameLower = (json['name'] ?? '').toString().toLowerCase();
              if (nameLower.contains('refill') || nameLower.contains('water') || nameLower.contains('gallon')) {
                icon = Icons.water_drop;
              } else if (nameLower.contains('container') || nameLower.contains('bottle')) {
                icon = Icons.shopping_bag;
              } else if (nameLower.contains('cap') || nameLower.contains('pump') || nameLower.contains('tap')) {
                icon = Icons.plumbing;
              }

              final stockVal = json['stock'];
              final imageUrlStr = (json['image_url'] ??
                      json['image'] ??
                      json['imageUrl'] ??
                      json['photo_url'] ??
                      json['img_url'])
                  ?.toString();

              return Product(
                id: json['id'].toString(),
                name: json['name'] ?? 'Product',
                price: (json['price'] as num).toDouble(),
                category: category,
                icon: icon,
                stock: stockVal != null ? (stockVal as num).toInt() : null,
                description: json['description']?.toString(),
                imageUrl: imageUrlStr,
              );
            }).toList();

            _cart.removeWhere((item) => !_availableProducts.any((p) => p.id == item.product.id));
            notifyListeners();
          }, onError: (e) {
            debugPrint('Realtime products stream error: $e');
          });
    } catch (e) {
      debugPrint('Error initializing realtime products: $e');
    }
  }

  void subscribeToRfidRegistryRealtime() {
    _rfidStreamSubscription?.cancel();
    try {
      _rfidStreamSubscription = _supabase
          .from('rfid_qr_records')
          .stream(primaryKey: ['id'])
          .eq('code_type', 'RFID')
          .listen((data) {
            if (_selectedCustomer != null && _selectedCustomer!.isLoyal) {
              findCustomerByRfidUid(_selectedCustomer!.rfidUid).catchError((err) {
                debugPrint('Realtime RFID lookup refresh note: $err');
                return null;
              });
            }
          }, onError: (e) {
            debugPrint('Realtime RFID stream error: $e');
          });
    } catch (e) {
      debugPrint('Error initializing realtime RFID stream: $e');
    }
  }

  void subscribeToSalesRealtime() {
    _salesStreamSubscription?.cancel();
    try {
      _salesStreamSubscription = _supabase
          .from('sales')
          .stream(primaryKey: ['id'])
          .listen((data) {
            loadDailySales().catchError((err) {
              debugPrint('Sales stream reload error: $err');
            });
          }, onError: (e) {
            debugPrint('Sales realtime stream error: $e');
          });
    } catch (e) {
      debugPrint('Error initializing sales stream: $e');
    }
  }

  Future<void> loadDailySales() async {
    try {
      await loadTransactionsFromLocal();

      List<dynamic> data;
      try {
        data = await _supabase
            .from('sales')
            .select('''
              *,
              profiles:customer_id (id, full_name, phone, address),
              sale_items (*)
            ''')
            .order('created_at', ascending: false)
            .limit(200);
      } catch (e) {
        debugPrint('Sales query with profiles join failed, falling back to basic query: $e');
        data = await _supabase
            .from('sales')
            .select('''
              *,
              sale_items (*)
            ''')
            .order('created_at', ascending: false)
            .limit(200);
      }

      final List<TransactionRecord> fetchedTransactions = [];

      for (var row in data) {
        final receiptNo = row['receipt_number']?.toString() ?? '';
        if (receiptNo.isEmpty) continue;

        final items = ((row['sale_items'] as List?) ?? []).map((item) {
          return CartItem(
            product: Product(
              id: item['product_id']?.toString() ?? '',
              name: item['product_name'] ?? 'Item',
              price: (item['unit_price'] as num? ?? 0.0).toDouble(),
            ),
            quantity: item['quantity'] as int? ?? 1,
          );
        }).toList();

        CustomerInfo? customer;
        if (row['profiles'] != null && row['profiles'] is Map) {
          final profileData = row['profiles'] as Map<String, dynamic>;
          customer = CustomerInfo(
            id: profileData['id']?.toString() ?? '',
            fullName: profileData['full_name'] ?? 'Customer',
            phone: profileData['phone']?.toString() ?? 'N/A',
            address: profileData['address']?.toString(),
            rfidUid: 'N/A',
            isLoyal: false,
          );
        }

        final tx = TransactionRecord(
          id: receiptNo,
          cashierName: _cashierName ?? 'Cashier',
          customer: customer,
          items: items,
          total: (row['total_amount'] as num? ?? 0.0).toDouble(),
          cashReceived: (row['cash_received'] as num? ?? 0.0).toDouble(),
          paymentMethod: _normalizePaymentMethod(row['payment_method']?.toString()),
          fulfillmentType: row['fulfillment_type']?.toString() ?? 'Pick-up',
          timestamp: DateTime.tryParse(row['created_at']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
        );

        fetchedTransactions.add(tx);
      }

      _transactions.clear();
      _transactions.addAll(fetchedTransactions);
      _transactions.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      await saveTransactionsToLocal();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading sales (using local fallback): $e');
      await loadTransactionsFromLocal();
    }
  }

  void addToCart(Product product) {
    final index = _cart.indexWhere((item) => item.product.id == product.id);
    if (index >= 0) {
      _cart[index].quantity++;
    } else {
      _cart.add(CartItem(product: product));
    }
    notifyListeners();
  }

  void removeFromCart(Product product) {
    final index = _cart.indexWhere((item) => item.product.id == product.id);
    if (index >= 0) {
      if (_cart[index].quantity > 1) {
        _cart[index].quantity--;
      } else {
        _cart.removeAt(index);
      }
      notifyListeners();
    }
  }

  void removeItemCompletely(Product product) {
    _cart.removeWhere((item) => item.product.id == product.id);
    notifyListeners();
  }

  void clearCart() {
    _cart.clear();
    notifyListeners();
  }

  Future<TransactionRecord?> completeTransaction(
    double cashReceived, {
    String paymentMethod = 'Cash',
    String? gcashRefNo,
  }) async {
    if (_cart.isEmpty || _cashierId == null || _isLoading) return null;

    _isLoading = true;
    notifyListeners();

    try {
      final total = totalAmount;

      // 1. Validate Payment Method (strict: Cash, GCash)
      if (paymentMethod != 'Cash' && paymentMethod != 'GCash') {
        throw Exception('Invalid payment method: $paymentMethod. Allowed: Cash, GCash');
      }

      // 2. Validate Cash Amount for Cash
      if (paymentMethod == 'Cash' && cashReceived < total) {
        throw Exception(
          'Insufficient cash. Required: ₱${total.toStringAsFixed(2)}, Received: ₱${cashReceived.toStringAsFixed(2)}',
        );
      }

      final receiptNumber = "POS-${DateTime.now().millisecondsSinceEpoch}-${(100 + (DateTime.now().microsecondsSinceEpoch % 900))}";

      final bool isPickUp = _fulfillmentType.toLowerCase().contains('pick');
      final String targetStatus = isPickUp ? 'Completed' : 'Pending';
      final String targetDeliveryStatus = isPickUp ? 'Completed' : 'Pending';

      String? customerId;
      if (_selectedCustomer != null) {
        final idStr = _selectedCustomer!.id.trim();
        if (idStr.isNotEmpty && !idStr.toLowerCase().startsWith('walk-in')) {
          customerId = idStr;
        } else {
          try {
            final uniquePhone = (_selectedCustomer!.phone == null || _selectedCustomer!.phone == 'N/A' || _selectedCustomer!.phone!.isEmpty)
                ? 'WALKIN-${DateTime.now().millisecondsSinceEpoch}'
                : '${_selectedCustomer!.phone}-${DateTime.now().millisecondsSinceEpoch}';

            final inserted = await _supabase.from('profiles').insert({
              'full_name': _selectedCustomer!.fullName,
              'phone': uniquePhone,
              'address': _selectedCustomer!.address ?? 'Walk-in',
              'role': 'customer',
            }).select('id').single();
            customerId = inserted['id'].toString();
          } catch (_) {
            customerId = null;
          }
        }
      }

      String deliveryNotes = _selectedCustomer?.address ?? (_fulfillmentType == 'Delivery' ? 'Delivery Order' : 'Counter Walk-in / Station Pickup');
      if (_selectedCustomer?.latitude != null && _selectedCustomer?.longitude != null) {
        final latStr = _selectedCustomer!.latitude!.toStringAsFixed(6);
        final lngStr = _selectedCustomer!.longitude!.toStringAsFixed(6);
        if (!deliveryNotes.contains('Pin:')) {
          deliveryNotes = '$deliveryNotes [Pin: $latStr, $lngStr]';
        }
      }

      // p_items contains only product_id and quantity
      final itemsPayload = _cart.map((item) => {
        'product_id': item.product.id,
        'quantity': item.quantity,
      }).toList();

      bool success = false;
      String? lastError;

      // 3. Complete transaction via RPC first
      try {
        await _supabase.rpc('cashier_complete_sale', params: {
          'p_receipt_number': receiptNumber,
          'p_customer_id': customerId,
          'p_customer_name': _selectedCustomer?.fullName ?? 'Walk-in Customer',
          'p_customer_phone': _selectedCustomer?.phone ?? 'N/A',
          'p_notes': deliveryNotes,
          'p_payment_method': paymentMethod,
          'p_cash_received': paymentMethod == 'gcash' ? null : cashReceived,
          'p_items': itemsPayload,
          'p_fulfillment_type': _fulfillmentType,
          'p_cashier_id': _cashierId,
          'p_cashier_name': _cashierName ?? 'Cashier',
          'p_gcash_ref_no': gcashRefNo?.replaceAll(' ', '').trim(),
        });

        // Ensure status respects fulfillment type (Pick-up = Completed, Delivery = Pending for approval)
        try {
          final Map<String, dynamic> updateData = {'status': targetStatus, 'order_status': targetStatus};
          if (_selectedCustomer?.latitude != null && _selectedCustomer?.longitude != null) {
            updateData['latitude'] = _selectedCustomer!.latitude;
            updateData['longitude'] = _selectedCustomer!.longitude;
            updateData['lat'] = _selectedCustomer!.latitude;
            updateData['lng'] = _selectedCustomer!.longitude;
          }
          await _supabase
              .from('sales')
              .update(updateData)
              .eq('receipt_number', receiptNumber);
        } catch (_) {}

        try {
          final Map<String, dynamic> updateData = {
            'status': targetStatus,
            'order_status': targetStatus,
            'delivery_status': targetDeliveryStatus,
            'delivery_address': deliveryNotes,
          };
          if (_selectedCustomer?.latitude != null && _selectedCustomer?.longitude != null) {
            updateData['latitude'] = _selectedCustomer!.latitude;
            updateData['longitude'] = _selectedCustomer!.longitude;
            updateData['delivery_lat'] = _selectedCustomer!.latitude;
            updateData['delivery_lng'] = _selectedCustomer!.longitude;
            updateData['lat'] = _selectedCustomer!.latitude;
            updateData['lng'] = _selectedCustomer!.longitude;
          }
          await _supabase
              .from('orders')
              .update(updateData)
              .eq('order_number', receiptNumber);
        } catch (_) {}

        success = true;
      } catch (rpcErr) {
        debugPrint('RPC cashier_complete_sale failed: $rpcErr. Trying direct inserts.');
        lastError = rpcErr.toString();
      }

      // 4. Fallback to direct inserts if RPC failed
      if (!success) {
        try {
          final bool isWalkIn = _selectedCustomer?.rfidUid == 'WALK-IN' || _selectedCustomer?.id == 'walk-in';

          final Map<String, dynamic> salePayload = {
            'receipt_number': receiptNumber,
            'customer_id': customerId,
            'customer_name': _selectedCustomer?.fullName ?? 'Walk-in Customer',
            'customer_phone': _selectedCustomer?.phone ?? 'N/A',
            'notes': deliveryNotes,
            'cashier_id': _cashierId,
            'total_amount': total,
            'cash_received': paymentMethod == 'gcash' ? total : cashReceived,
            'payment_method': paymentMethod,
            'fulfillment_type': _fulfillmentType,
            'status': 'Completed',
            'is_walk_in': isWalkIn,
            'order_type': isWalkIn ? 'walk_in' : 'pos',
            'gcash_ref_no': gcashRefNo?.replaceAll(' ', '').trim(),
          };
          if (_selectedCustomer?.latitude != null && _selectedCustomer?.longitude != null) {
            salePayload['latitude'] = _selectedCustomer!.latitude;
            salePayload['longitude'] = _selectedCustomer!.longitude;
            salePayload['lat'] = _selectedCustomer!.latitude;
            salePayload['lng'] = _selectedCustomer!.longitude;
          }

          dynamic saleInsert;
          try {
            saleInsert = await _supabase.from('sales').insert(salePayload).select('id').single();
          } catch (_) {
            salePayload.remove('latitude');
            salePayload.remove('longitude');
            salePayload.remove('lat');
            salePayload.remove('lng');
            saleInsert = await _supabase.from('sales').insert(salePayload).select('id').single();
          }

          final saleUuid = saleInsert['id'].toString();
          for (var item in _cart) {
            await _supabase.from('sale_items').insert({
              'sale_id': saleUuid,
              'product_id': item.product.id,
              'product_name': item.product.name,
              'unit_price': item.product.price,
              'quantity': item.quantity,
              'subtotal': item.subtotal,
            });
          }

          try {
            final Map<String, dynamic> orderPayload = {
              'order_number': receiptNumber,
              'customer_id': customerId,
              'total_amount': total,
              'payment_method': paymentMethod,
              'fulfillment_type': _fulfillmentType,
              'status': targetStatus,
              'order_status': targetStatus,
              'delivery_status': targetDeliveryStatus,
              'delivery_address': deliveryNotes,
              'is_walk_in': isWalkIn,
              'order_type': isWalkIn ? 'walk_in' : 'pos',
              'created_at': DateTime.now().toIso8601String(),
            };
            if (_selectedCustomer?.latitude != null && _selectedCustomer?.longitude != null) {
              orderPayload['latitude'] = _selectedCustomer!.latitude;
              orderPayload['longitude'] = _selectedCustomer!.longitude;
              orderPayload['delivery_lat'] = _selectedCustomer!.latitude;
              orderPayload['delivery_lng'] = _selectedCustomer!.longitude;
              orderPayload['lat'] = _selectedCustomer!.latitude;
              orderPayload['lng'] = _selectedCustomer!.longitude;
            }

            try {
              await _supabase.from('orders').insert(orderPayload);
            } catch (_) {
              orderPayload.remove('latitude');
              orderPayload.remove('longitude');
              orderPayload.remove('delivery_lat');
              orderPayload.remove('delivery_lng');
              orderPayload.remove('lat');
              orderPayload.remove('lng');
              await _supabase.from('orders').insert(orderPayload);
            }
          } catch (ordersErr) {
            debugPrint('Note on orders table insert: $ordersErr');
          }

          success = true;
        } catch (directErr) {
          debugPrint('Direct sales insert failed: $directErr');
          lastError = directErr.toString();
        }
      }

      if (!success) {
        throw Exception('Failed to record transaction in database: ${lastError ?? 'Unknown error'}');
      }

      if (paymentMethod == 'GCash') {
        final cleanRef = gcashRefNo?.replaceAll(' ', '').trim();
        if (cleanRef != null && cleanRef.isNotEmpty) {
          try {
            await _supabase
                .from('admin_gcash_records')
                .update({
                  'is_used': true,
                  'used_in_receipt': receiptNumber,
                })
                .eq('reference_number', cleanRef);
          } catch (e) {
            debugPrint('Note on marking admin_gcash_records as used: $e');
          }
        }

        try {
          await _supabase.from('notifications').insert({
            'title': 'New GCash Payment Received',
            'message': 'Cashier ${_cashierName ?? 'Cashier'} processed GCash payment for Receipt #$receiptNumber (Ref: ${gcashRefNo ?? 'N/A'}, Amount: ₱${total.toStringAsFixed(2)})',
            'type': 'gcash_payment',
            'reference_id': receiptNumber,
            'cashier_name': _cashierName ?? 'Cashier',
            'created_at': DateTime.now().toIso8601String(),
          });
        } catch (notifErr) {
          debugPrint('Note on sending GCash notification to admin: $notifErr');
        }
      }

      final effectiveCashReceived = paymentMethod == 'GCash' ? 0.0 : cashReceived;

      final transaction = TransactionRecord(
        id: receiptNumber,
        cashierName: _cashierName ?? 'Cashier',
        customer: _selectedCustomer,
        items: List.from(_cart),
        total: total,
        cashReceived: effectiveCashReceived,
        paymentMethod: paymentMethod,
        fulfillmentType: _fulfillmentType,
        timestamp: DateTime.now(),
      );

      _transactions.insert(0, transaction);
      try {
        await saveTransactionsToLocal();
      } catch (e) {
        debugPrint('Note on local save: $e');
      }

      _cart.clear();
      _selectedCustomer = null;

      // Refresh inventory and sales history safely
      try {
        await loadProducts();
      } catch (e) {
        debugPrint('Note refreshing products: $e');
      }

      try {
        await loadDailySales();
      } catch (e) {
        debugPrint('Note refreshing daily sales: $e');
      }

      _isLoading = false;
      notifyListeners();
      return transaction;

    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow; // Rethrow to UI, preserve cart
    }
  }

  Future<void> deleteTransaction(String transactionId) async {
    _isLoading = true;
    notifyListeners();
    try {
      try {
        final saleRow = await _supabase
            .from('sales')
            .select('id')
            .eq('receipt_number', transactionId)
            .maybeSingle();

        if (saleRow != null && saleRow['id'] != null) {
          final actualUuid = saleRow['id'].toString();
          await _supabase
              .from('sale_items')
              .delete()
              .eq('sale_id', actualUuid);
        }
      } catch (e) {
        debugPrint('Note on sale_id items delete: $e');
      }

      try {
        await _supabase
            .from('sales')
            .delete()
            .eq('receipt_number', transactionId);
      } catch (_) {
        await _supabase
            .from('sales')
            .delete()
            .eq('id', transactionId);
      }

      _transactions.removeWhere((tx) => tx.id == transactionId);
      await saveTransactionsToLocal();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      debugPrint('Error deleting transaction from database: $e');
      throw Exception('Failed to delete from database: ${e.toString().replaceAll('Exception: ', '')}');
    }
  }

  @override
  void dispose() {
    _productsStreamSubscription?.cancel();
    _rfidStreamSubscription?.cancel();
    _salesStreamSubscription?.cancel();
    _ordersStreamSubscription?.cancel();
    _profileStreamSubscription?.cancel();
    super.dispose();
  }
}
