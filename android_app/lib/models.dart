import 'dart:convert';

import 'package:crypto/crypto.dart';

String hashPin(String pin) {
  return sha256.convert(utf8.encode(pin)).toString();
}

class ProductUnit {
  final int id;
  final String unitName;
  final double conversionQty;
  final double priceSell;

  const ProductUnit({
    required this.id,
    required this.unitName,
    required this.conversionQty,
    required this.priceSell,
  });

  factory ProductUnit.fromJson(Map<String, dynamic> json) {
    return ProductUnit(
      id: (json['id'] as num?)?.toInt() ?? 0,
      unitName: json['unit_name'] as String? ?? '',
      conversionQty: (json['conversion_qty'] as num?)?.toDouble() ?? 1,
      priceSell: (json['price_sell'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'unit_name': unitName,
      'conversion_qty': conversionQty,
      'price_sell': priceSell,
    };
  }
}

class Product {
  final int id;
  final String sku;
  final String barcode;
  final String name;
  final int? categoryId;
  final String? categoryName;
  final String? photoPath;
  final String unitBase;
  final double priceBuy;
  final double priceSell;
  final double stock;
  final double stockAlertThreshold;
  final bool isFavorite;
  final bool isActive;
  final List<ProductUnit> units;
  final String? createdAt;

  const Product({
    required this.id,
    required this.sku,
    required this.barcode,
    required this.name,
    this.categoryId,
    this.categoryName,
    this.photoPath,
    required this.unitBase,
    required this.priceBuy,
    required this.priceSell,
    required this.stock,
    required this.stockAlertThreshold,
    required this.isFavorite,
    required this.isActive,
    required this.units,
    this.createdAt,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    final rawUnits = json['units'];
    List<ProductUnit> units = [];
    if (rawUnits is List) {
      units = rawUnits
          .whereType<Map>()
          .map((e) => ProductUnit.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return Product(
      id: (json['id'] as num?)?.toInt() ?? 0,
      sku: json['sku'] as String? ?? '',
      barcode: json['barcode'] as String? ?? '',
      name: json['name'] as String? ?? '',
      categoryId: (json['category_id'] as num?)?.toInt(),
      categoryName: json['category_name'] as String?,
      photoPath: json['photo_path'] as String?,
      unitBase: json['unit_base'] as String? ?? 'pcs',
      priceBuy: (json['price_buy'] as num?)?.toDouble() ?? 0,
      priceSell: (json['price_sell'] as num?)?.toDouble() ?? 0,
      stock: (json['stock'] as num?)?.toDouble() ?? 0,
      stockAlertThreshold:
          (json['stock_alert_threshold'] as num?)?.toDouble() ?? 5,
      isFavorite: json['is_favorite'] == true || json['is_favorite'] == 1,
      isActive: json['is_active'] == true || json['is_active'] == null,
      units: units,
      createdAt: json['created_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sku': sku,
      'barcode': barcode,
      'name': name,
      'category_id': categoryId,
      'category_name': categoryName,
      'photo_path': photoPath,
      'unit_base': unitBase,
      'price_buy': priceBuy,
      'price_sell': priceSell,
      'stock': stock,
      'stock_alert_threshold': stockAlertThreshold,
      'is_favorite': isFavorite,
      'is_active': isActive,
      'units': units.map((u) => u.toJson()).toList(),
      'created_at': createdAt,
    };
  }

  Product copyWith({
    bool? isFavorite,
    double? stock,
  }) {
    return Product(
      id: id,
      sku: sku,
      barcode: barcode,
      name: name,
      categoryId: categoryId,
      categoryName: categoryName,
      photoPath: photoPath,
      unitBase: unitBase,
      priceBuy: priceBuy,
      priceSell: priceSell,
      stock: stock ?? this.stock,
      stockAlertThreshold: stockAlertThreshold,
      isFavorite: isFavorite ?? this.isFavorite,
      isActive: isActive,
      units: units,
      createdAt: createdAt,
    );
  }
}

class Category {
  final int id;
  final String name;

  const Category({required this.id, required this.name});

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name};
  }
}

class CartItem {
  final Product product;
  final double qty;
  final String unitName;
  final double pricePerUnit;

  const CartItem({
    required this.product,
    required this.qty,
    required this.unitName,
    required this.pricePerUnit,
  });

  double get subtotal => qty * pricePerUnit;

  CartItem copyWith({double? qty}) {
    return CartItem(
      product: product,
      qty: qty ?? this.qty,
      unitName: unitName,
      pricePerUnit: pricePerUnit,
    );
  }

  Map<String, dynamic> toPayload() {
    return {
      'product_id': product.id,
      'qty': qty,
      'unit_name': unitName,
      'price_per_unit': pricePerUnit,
    };
  }
}

class TxItem {
  final int productId;
  final String productNameSnapshot;
  final String unitName;
  final double qty;
  final double pricePerUnit;
  final double subtotal;

  const TxItem({
    required this.productId,
    required this.productNameSnapshot,
    required this.unitName,
    required this.qty,
    required this.pricePerUnit,
    required this.subtotal,
  });

  factory TxItem.fromJson(Map<String, dynamic> json) {
    return TxItem(
      productId: (json['product_id'] as num?)?.toInt() ?? 0,
      productNameSnapshot: json['product_name_snapshot'] as String? ?? '',
      unitName: json['unit_name'] as String? ?? 'pcs',
      qty: (json['qty'] as num?)?.toDouble() ?? 0,
      pricePerUnit: (json['price_per_unit'] as num?)?.toDouble() ?? 0,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
    );
  }
}

class Transaction {
  final int id;
  final String invoiceNo;
  final double totalAmount;
  final double changeAmount;
  final String paymentMethod;
  final double cashReceived;
  final double discountAmount;
  final String status;
  final String createdAt;
  final int? customerId;
  final String? customerName;
  final List<TxItem> items;

  const Transaction({
    required this.id,
    required this.invoiceNo,
    required this.totalAmount,
    required this.changeAmount,
    required this.paymentMethod,
    required this.cashReceived,
    required this.discountAmount,
    required this.status,
    required this.createdAt,
    this.customerId,
    this.customerName,
    this.items = const [],
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    List<TxItem> items = [];
    if (rawItems is List) {
      items = rawItems
          .whereType<Map>()
          .map((e) => TxItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return Transaction(
      id: (json['id'] as num?)?.toInt() ?? 0,
      invoiceNo: json['invoice_no'] as String? ?? '',
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0,
      changeAmount: (json['change_amount'] as num?)?.toDouble() ?? 0,
      paymentMethod: json['payment_method'] as String? ?? 'tunai',
      cashReceived: (json['cash_received'] as num?)?.toDouble() ?? 0,
      discountAmount: (json['discount_amount'] as num?)?.toDouble() ?? 0,
      status: json['status'] as String? ?? 'completed',
      createdAt: json['created_at'] as String? ?? '',
      customerId: (json['customer_id'] as num?)?.toInt(),
      customerName: json['customer_name'] as String?,
      items: items,
    );
  }
}

class Customer {
  final int id;
  final String name;
  final String phone;

  const Customer({required this.id, required this.name, required this.phone});

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'phone': phone};
  }
}

class DebtEntry {
  final int id;
  final int transactionId;
  final double amount;
  final double amountPaid;
  final double remaining;
  final String status;
  final String? dueDate;
  final String? createdAt;

  const DebtEntry({
    required this.id,
    required this.transactionId,
    required this.amount,
    required this.amountPaid,
    required this.remaining,
    required this.status,
    this.dueDate,
    this.createdAt,
  });

  factory DebtEntry.fromJson(Map<String, dynamic> json) {
    return DebtEntry(
      id: (json['id'] as num?)?.toInt() ?? 0,
      transactionId: (json['transaction_id'] as num?)?.toInt() ?? 0,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      amountPaid: (json['amount_paid'] as num?)?.toDouble() ?? 0,
      remaining: (json['remaining'] as num?)?.toDouble() ?? 0,
      status: json['status'] as String? ?? 'unpaid',
      dueDate: json['due_date'] as String?,
      createdAt: json['created_at'] as String?,
    );
  }
}

class DebtGroup {
  final int customerId;
  final String customerName;
  final String phone;
  final double totalDebt;
  final double totalPaid;
  final String? dueDateMin;
  final List<DebtEntry> debts;

  const DebtGroup({
    required this.customerId,
    required this.customerName,
    required this.phone,
    required this.totalDebt,
    required this.totalPaid,
    this.dueDateMin,
    this.debts = const [],
  });

  double get totalRemaining => totalDebt - totalPaid;

  factory DebtGroup.fromJson(Map<String, dynamic> json) {
    final rawDebts = json['debts'];
    List<DebtEntry> debts = [];
    if (rawDebts is List) {
      debts = rawDebts
          .whereType<Map>()
          .map((e) => DebtEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return DebtGroup(
      customerId: (json['customer_id'] as num?)?.toInt() ?? 0,
      customerName: json['customer_name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      totalDebt: (json['total_debt'] as num?)?.toDouble() ?? 0,
      totalPaid: (json['total_paid'] as num?)?.toDouble() ?? 0,
      dueDateMin: json['due_date_min'] as String?,
      debts: debts,
    );
  }
}

class PaymentSplit {
  final String method;
  final double amount;

  const PaymentSplit({required this.method, required this.amount});

  Map<String, dynamic> toJson() {
    return {'method': method, 'amount': amount};
  }
}

class AppSettings {
  final String storeName;
  final bool pinSet;
  final bool backupEnabled;
  final String backupHour;

  const AppSettings({
    required this.storeName,
    required this.pinSet,
    required this.backupEnabled,
    required this.backupHour,
  });

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      storeName: json['store_name'] as String? ?? 'Toko KiosKu',
      pinSet: json['pin_set'] == true,
      backupEnabled: json['backup_enabled'] == true,
      backupHour: json['backup_hour'] as String? ?? '00:00',
    );
  }

  AppSettings copyWith({String? storeName, bool? pinSet}) {
    return AppSettings(
      storeName: storeName ?? this.storeName,
      pinSet: pinSet ?? this.pinSet,
      backupEnabled: backupEnabled,
      backupHour: backupHour,
    );
  }
}

class StockAlert {
  final int id;
  final String name;
  final String sku;
  final double stock;
  final double stockAlertThreshold;
  final String status;

  const StockAlert({
    required this.id,
    required this.name,
    required this.sku,
    required this.stock,
    required this.stockAlertThreshold,
    required this.status,
  });

  factory StockAlert.fromJson(Map<String, dynamic> json) {
    return StockAlert(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      sku: json['sku'] as String? ?? '',
      stock: (json['stock'] as num?)?.toDouble() ?? 0,
      stockAlertThreshold:
          (json['stock_alert_threshold'] as num?)?.toDouble() ?? 0,
      status: json['status'] as String? ?? 'menipis',
    );
  }
}

class StockLog {
  final int id;
  final int productId;
  final String productName;
  final double changeQty;
  final String reason;
  final String? referenceId;
  final String? createdAt;

  const StockLog({
    required this.id,
    required this.productId,
    required this.productName,
    required this.changeQty,
    required this.reason,
    this.referenceId,
    this.createdAt,
  });

  factory StockLog.fromJson(Map<String, dynamic> json) {
    return StockLog(
      id: (json['id'] as num?)?.toInt() ?? 0,
      productId: (json['product_id'] as num?)?.toInt() ?? 0,
      productName: json['product_name'] as String? ?? '',
      changeQty: (json['change_qty'] as num?)?.toDouble() ?? 0,
      reason: json['reason'] as String? ?? '',
      referenceId: json['reference_id']?.toString(),
      createdAt: json['created_at'] as String?,
    );
  }
}

class ReportSummary {
  final int totalTransactions;
  final double omzet;
  final double avgBelanja;
  final double itemsSold;

  const ReportSummary({
    required this.totalTransactions,
    required this.omzet,
    required this.avgBelanja,
    required this.itemsSold,
  });

  factory ReportSummary.fromJson(Map<String, dynamic> json) {
    return ReportSummary(
      totalTransactions: (json['total_transactions'] as num?)?.toInt() ?? 0,
      omzet: (json['omzet'] as num?)?.toDouble() ?? 0,
      avgBelanja: (json['avg_belanja'] as num?)?.toDouble() ?? 0,
      itemsSold: (json['items_sold'] as num?)?.toDouble() ?? 0,
    );
  }
}

class DailyReport {
  final String date;
  final ReportSummary summary;
  final int transactions;

  const DailyReport({
    required this.date,
    required this.summary,
    required this.transactions,
  });

  factory DailyReport.fromJson(Map<String, dynamic> json) {
    final raw = json['summary'];
    return DailyReport(
      date: json['date'] as String? ?? '',
      summary: raw is Map
          ? ReportSummary.fromJson(Map<String, dynamic>.from(raw))
          : const ReportSummary(
              totalTransactions: 0,
              omzet: 0,
              avgBelanja: 0,
              itemsSold: 0,
            ),
      transactions: (json['transactions'] as num?)?.toInt() ?? 0,
    );
  }
}

class MonthlyReport {
  final int month;
  final int year;
  final ReportSummary summary;
  final Map<String, double> daily;

  const MonthlyReport({
    required this.month,
    required this.year,
    required this.summary,
    required this.daily,
  });

  factory MonthlyReport.fromJson(Map<String, dynamic> json) {
    final raw = json['summary'];
    final rawDaily = json['daily'];
    final daily = <String, double>{};
    if (rawDaily is Map) {
      rawDaily.forEach((key, value) {
        daily[key.toString()] = (value as num?)?.toDouble() ?? 0;
      });
    }
    return MonthlyReport(
      month: (json['month'] as num?)?.toInt() ?? DateTime.now().month,
      year: (json['year'] as num?)?.toInt() ?? DateTime.now().year,
      summary: raw is Map
          ? ReportSummary.fromJson(Map<String, dynamic>.from(raw))
          : const ReportSummary(
              totalTransactions: 0,
              omzet: 0,
              avgBelanja: 0,
              itemsSold: 0,
            ),
      daily: daily,
    );
  }
}

class TopProduct {
  final int productId;
  final String productName;
  final double qtySold;
  final double revenue;

  const TopProduct({
    required this.productId,
    required this.productName,
    required this.qtySold,
    required this.revenue,
  });

  factory TopProduct.fromJson(Map<String, dynamic> json) {
    return TopProduct(
      productId: (json['product_id'] as num?)?.toInt() ?? 0,
      productName: json['product_name'] as String? ?? '',
      qtySold: (json['qty_sold'] as num?)?.toDouble() ?? 0,
      revenue: (json['revenue'] as num?)?.toDouble() ?? 0,
    );
  }
}

class BackupFile {
  final String filename;
  final int size;
  final String? createdAt;

  const BackupFile({
    required this.filename,
    required this.size,
    this.createdAt,
  });

  factory BackupFile.fromJson(Map<String, dynamic> json) {
    return BackupFile(
      filename: json['filename'] as String? ?? '',
      size: (json['size'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] as String?,
    );
  }

  String get sizeLabel {
    if (size >= 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(size / 1024).toStringAsFixed(1)} KB';
  }
}

class HealthInfo {
  final String status;
  final String app;
  final String? time;

  const HealthInfo({
    required this.status,
    required this.app,
    this.time,
  });

  bool get isOk => status == 'ok';

  factory HealthInfo.fromJson(Map<String, dynamic> json) {
    return HealthInfo(
      status: json['status'] as String? ?? '',
      app: json['app'] as String? ?? '',
      time: json['time'] as String?,
    );
  }
}
