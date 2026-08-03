import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'models.dart';

class OfflineDatabase {
  OfflineDatabase._();

  static final OfflineDatabase instance = OfflineDatabase._();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    final path = p.join(dir, 'kiosku.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE products (
            id INTEGER PRIMARY KEY,
            sku TEXT,
            barcode TEXT,
            name TEXT NOT NULL,
            category_id INTEGER,
            category_name TEXT,
            unit_base TEXT,
            price_buy REAL,
            price_sell REAL,
            stock REAL,
            stock_alert_threshold REAL,
            is_favorite INTEGER DEFAULT 0,
            photo_path TEXT,
            units_json TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE pending_transactions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            payload_json TEXT NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE customers (
            id INTEGER PRIMARY KEY,
            name TEXT NOT NULL,
            phone TEXT
          )
        ''');
      },
    );
  }

  Future<void> init() async {
    await database;
  }

  Map<String, dynamic> _productToRow(Product product) {
    return {
      'id': product.id,
      'sku': product.sku,
      'barcode': product.barcode,
      'name': product.name,
      'category_id': product.categoryId,
      'category_name': product.categoryName,
      'unit_base': product.unitBase,
      'price_buy': product.priceBuy,
      'price_sell': product.priceSell,
      'stock': product.stock,
      'stock_alert_threshold': product.stockAlertThreshold,
      'is_favorite': product.isFavorite ? 1 : 0,
      'photo_path': product.photoPath,
      'units_json': jsonEncode(product.units.map((u) => u.toJson()).toList()),
    };
  }

  Product _rowToProduct(Map<String, dynamic> row) {
    List<ProductUnit> units = [];
    final raw = row['units_json'];
    if (raw is String && raw.isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        units = decoded
            .whereType<Map>()
            .map((e) => ProductUnit.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    }
    return Product(
      id: (row['id'] as num).toInt(),
      sku: row['sku'] as String? ?? '',
      barcode: row['barcode'] as String? ?? '',
      name: row['name'] as String? ?? '',
      categoryId: (row['category_id'] as num?)?.toInt(),
      categoryName: row['category_name'] as String?,
      unitBase: row['unit_base'] as String? ?? 'pcs',
      priceBuy: (row['price_buy'] as num?)?.toDouble() ?? 0,
      priceSell: (row['price_sell'] as num?)?.toDouble() ?? 0,
      stock: (row['stock'] as num?)?.toDouble() ?? 0,
      stockAlertThreshold: (row['stock_alert_threshold'] as num?)?.toDouble() ?? 5,
      isFavorite: (row['is_favorite'] as num?) == 1,
      photoPath: row['photo_path'] as String?,
      isActive: true,
      units: units,
    );
  }

  Future<void> upsertProducts(List<Product> products) async {
    if (products.isEmpty) return;
    final db = await database;
    final batch = db.batch();
    for (final product in products) {
      batch.insert(
        'products',
        _productToRow(product),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> upsertProduct(Product product) async {
    final db = await database;
    await db.insert(
      'products',
      _productToRow(product),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Product>> getProducts({
    int? categoryId,
    bool? favorite,
    String? search,
  }) async {
    final db = await database;
    final where = <String>[];
    final args = <Object?>[];
    if (categoryId != null) {
      where.add('category_id = ?');
      args.add(categoryId);
    }
    if (favorite == true) {
      where.add('is_favorite = 1');
    }
    if (search != null && search.trim().isNotEmpty) {
      where.add('name LIKE ? OR barcode LIKE ? OR sku LIKE ?');
      final like = '%${search.trim()}%';
      args.addAll([like, like, like]);
    }
    final rows = await db.query(
      'products',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args,
      orderBy: 'name COLLATE NOCASE',
    );
    return rows.map(_rowToProduct).toList();
  }

  Future<Product?> getProductById(int id) async {
    final db = await database;
    final rows = await db.query('products', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return _rowToProduct(rows.first);
  }

  Future<Product?> getProductByBarcode(String code) async {
    final db = await database;
    final rows = await db.query(
      'products',
      where: 'barcode = ? OR sku = ?',
      whereArgs: [code, code],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _rowToProduct(rows.first);
  }

  Future<void> setFavorite(int productId, bool favorite) async {
    final db = await database;
    await db.update(
      'products',
      {'is_favorite': favorite ? 1 : 0},
      where: 'id = ?',
      whereArgs: [productId],
    );
  }

  Future<int> insertPendingTransaction(Map<String, dynamic> payload) async {
    final db = await database;
    return db.insert('pending_transactions', {
      'payload_json': jsonEncode(payload),
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getPendingTransactions() async {
    final db = await database;
    final rows = await db.query(
      'pending_transactions',
      orderBy: 'created_at ASC',
    );
    return rows.map((row) {
      return {
        'id': row['id'],
        'created_at': row['created_at'],
        'payload': jsonDecode(row['payload_json'] as String),
      };
    }).toList();
  }

  Future<void> deletePendingTransaction(int id) async {
    final db = await database;
    await db.delete('pending_transactions', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> upsertCustomers(List<Customer> customers) async {
    if (customers.isEmpty) return;
    final db = await database;
    final batch = db.batch();
    for (final customer in customers) {
      batch.insert(
        'customers',
        {'id': customer.id, 'name': customer.name, 'phone': customer.phone},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<Customer>> getCustomers({String? q}) async {
    final db = await database;
    final rows = (q == null || q.trim().isEmpty)
        ? await db.query('customers', orderBy: 'name COLLATE NOCASE')
        : await db.query(
            'customers',
            where: 'name LIKE ? OR phone LIKE ?',
            whereArgs: ['%${q.trim()}%', '%${q.trim()}%'],
            orderBy: 'name COLLATE NOCASE',
          );
    return rows
        .map((row) => Customer(
              id: (row['id'] as num).toInt(),
              name: row['name'] as String? ?? '',
              phone: row['phone'] as String? ?? '',
            ))
        .toList();
  }
}
