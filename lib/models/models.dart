import 'package:flutter/material.dart';

class Product {
  final String id;
  final String name;
  final double price;
  final String category;
  final IconData icon;
  final int? stock;
  final String? description;
  final String? imageUrl;

  Product({
    required this.id,
    required this.name,
    required this.price,
    this.category = 'General',
    this.icon = Icons.local_mall,
    this.stock,
    this.description,
    this.imageUrl,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'price': price,
    'category': category,
    'stock': stock,
    'description': description,
    'imageUrl': imageUrl,
  };

  factory Product.fromJson(Map<String, dynamic> json) => Product(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? 'Product',
    price: (json['price'] as num? ?? 0.0).toDouble(),
    category: json['category']?.toString() ?? 'General',
    stock: json['stock'] as int?,
    description: json['description']?.toString(),
    imageUrl: json['imageUrl']?.toString(),
  );
}

class CartItem {
  final Product product;
  int quantity;

  CartItem({required this.product, this.quantity = 1});

  double get subtotal => product.price * quantity;

  Map<String, dynamic> toJson() => {
    'product': product.toJson(),
    'quantity': quantity,
  };

  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
    product: Product.fromJson(json['product'] as Map<String, dynamic>),
    quantity: json['quantity'] as int? ?? 1,
  );
}

class CustomerInfo {
  final String id;
  final String fullName;
  final String phone;
  final String rfidUid;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String? notes;
  final String? gallonId;
  final String? gallonCode;
  final bool isLoyal;

  CustomerInfo({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.rfidUid,
    this.address,
    this.latitude,
    this.longitude,
    this.notes,
    this.gallonId,
    this.gallonCode,
    this.isLoyal = true,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'fullName': fullName,
    'phone': phone,
    'rfidUid': rfidUid,
    'address': address,
    'latitude': latitude,
    'longitude': longitude,
    'notes': notes,
    'gallonId': gallonId,
    'gallonCode': gallonCode,
    'isLoyal': isLoyal,
  };

  factory CustomerInfo.fromJson(Map<String, dynamic> json) => CustomerInfo(
    id: json['id']?.toString() ?? '',
    fullName: json['fullName']?.toString() ?? json['full_name']?.toString() ?? 'Customer',
    phone: json['phone']?.toString() ?? 'N/A',
    rfidUid: json['rfidUid']?.toString() ?? 'N/A',
    address: json['address']?.toString() ?? json['delivery_address']?.toString(),
    latitude: (json['latitude'] as num? ?? json['lat'] as num? ?? json['delivery_lat'] as num?)?.toDouble(),
    longitude: (json['longitude'] as num? ?? json['lng'] as num? ?? json['delivery_lng'] as num?)?.toDouble(),
    notes: json['notes']?.toString(),
    gallonId: json['gallonId']?.toString(),
    gallonCode: json['gallonCode']?.toString(),
    isLoyal: json['isLoyal'] == true,
  );
}

class TransactionRecord {
  final String id;
  final String cashierName;
  final CustomerInfo? customer;
  final List<CartItem> items;
  final double subtotal;
  final double deliveryFee;
  final double discount;
  final double total;
  final double cashReceived;
  final String paymentMethod;
  final String fulfillmentType;
  final String? notes;
  final String? gcashRefNo;
  final DateTime timestamp;

  TransactionRecord({
    required this.id,
    required this.cashierName,
    this.customer,
    required this.items,
    double? subtotal,
    this.deliveryFee = 0.0,
    this.discount = 0.0,
    required this.total,
    required this.cashReceived,
    this.paymentMethod = 'Cash',
    this.fulfillmentType = 'Pick-up at Store',
    this.notes,
    this.gcashRefNo,
    required this.timestamp,
  }) : subtotal = subtotal ?? items.fold(0.0, (sum, i) => sum + i.subtotal);

  double get change => cashReceived > total ? cashReceived - total : 0.0;

  Map<String, dynamic> toJson() => {
    'id': id,
    'cashierName': cashierName,
    'customer': customer?.toJson(),
    'items': items.map((i) => i.toJson()).toList(),
    'subtotal': subtotal,
    'deliveryFee': deliveryFee,
    'discount': discount,
    'total': total,
    'cashReceived': cashReceived,
    'paymentMethod': paymentMethod,
    'fulfillmentType': fulfillmentType,
    'notes': notes,
    'gcashRefNo': gcashRefNo,
    'timestamp': timestamp.toIso8601String(),
  };

  factory TransactionRecord.fromJson(Map<String, dynamic> json) => TransactionRecord(
    id: json['id']?.toString() ?? '',
    cashierName: json['cashierName']?.toString() ?? 'Cashier',
    customer: json['customer'] != null ? CustomerInfo.fromJson(json['customer'] as Map<String, dynamic>) : null,
    items: ((json['items'] as List?) ?? []).map((i) => CartItem.fromJson(i as Map<String, dynamic>)).toList(),
    subtotal: (json['subtotal'] as num?)?.toDouble(),
    deliveryFee: (json['deliveryFee'] as num? ?? json['delivery_fee'] as num? ?? 0.0).toDouble(),
    discount: (json['discount'] as num? ?? 0.0).toDouble(),
    total: (json['total'] as num? ?? json['total_amount'] as num? ?? 0.0).toDouble(),
    cashReceived: (json['cashReceived'] as num? ?? json['cash_received'] as num? ?? 0.0).toDouble(),
    paymentMethod: json['paymentMethod']?.toString() ?? json['payment_method']?.toString() ?? 'Cash',
    fulfillmentType: json['fulfillmentType']?.toString() ?? json['fulfillment_type']?.toString() ?? 'Pick-up at Store',
    notes: json['notes']?.toString(),
    gcashRefNo: json['gcashRefNo']?.toString() ?? json['gcash_ref_no']?.toString(),
    timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ?? DateTime.now(),
  );
}

class DriverInfo {
  final String id;
  final String fullName;
  final String role;

  DriverInfo({required this.id, required this.fullName, required this.role});

  factory DriverInfo.fromJson(Map<String, dynamic> json) => DriverInfo(
    id: json['id']?.toString() ?? '',
    fullName: json['full_name']?.toString() ?? 'Driver',
    role: json['role']?.toString() ?? 'driver',
  );
}

class PendingApprovalRecord {
  final String id;
  final String code;
  final String codeType; // 'RFID', 'QR', or 'ORDER'
  final String? customerId;
  final String? customerName;
  final String? address;
  final double? totalAmount;
  final String? paymentMethod;
  final int? itemCount;
  final bool isActive;
  final DateTime? createdAt;

  PendingApprovalRecord({
    required this.id,
    required this.code,
    required this.codeType,
    this.customerId,
    this.customerName,
    this.address,
    this.totalAmount,
    this.paymentMethod,
    this.itemCount,
    required this.isActive,
    this.createdAt,
  });
}

class ApprovalHistoryRecord {
  final String id;
  final String code;
  final String customerName;
  final String action; // 'APPROVED' or 'REJECTED'
  final String? assignedDriver;
  final DateTime timestamp;

  ApprovalHistoryRecord({
    required this.id,
    required this.code,
    required this.customerName,
    required this.action,
    this.assignedDriver,
    required this.timestamp,
  });
}
