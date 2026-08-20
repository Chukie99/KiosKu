import 'dart:io';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

class ApiException implements Exception {
  final String message;
  final bool offline;
  final bool notFound;
  final bool unauthorized;

  const ApiException(
    this.message, {
    this.offline = false,
    this.notFound = false,
    this.unauthorized = false,
  });

  @override
  String toString() => message;
}

class ProductPage {
  final List<Product> items;
  final int page;
  final int pageSize;
  final int total;

  const ProductPage({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
  });
}

class TxPage {
  final List<Transaction> items;
  final int total;

  const TxPage({required this.items, required this.total});
}

class VerifyPinResult {
  final bool ok;
  final bool pinSet;
  final String? token;

  const VerifyPinResult({required this.ok, required this.pinSet, this.token});
}

class ApiClient {
  static const String defaultBaseUrl = 'http://192.168.1.100:8000';
  static const String _tokenKey = 'auth_token';

  final Dio _dio;
  String? _baseUrl;
  String? _token;
  void Function()? _onUnauthorized;

  ApiClient({String? baseUrl})
      : _dio = Dio(BaseOptions(
          baseUrl: baseUrl ?? defaultBaseUrl,
          connectTimeout: const Duration(seconds: 3),
          receiveTimeout: const Duration(seconds: 3),
          sendTimeout: const Duration(seconds: 3),
          headers: {'Content-Type': 'application/json'},
        )) {
    _baseUrl = baseUrl;
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_token != null) {
          options.headers['Authorization'] = 'Bearer $_token';
        }
        handler.next(options);
      },
      onError: (error, handler) {
        if (error.response?.statusCode == 401) {
          _token = null;
          _onUnauthorized?.call();
        }
        handler.next(error);
      },
    ));
  }

  String get baseUrl => _baseUrl ?? defaultBaseUrl;
  String? get token => _token;

  set onUnauthorized(void Function()? callback) {
    _onUnauthorized = callback;
  }

  Future<void> _ensureBaseUrl() async {
    if (_baseUrl != null) return;
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString('server_url') ?? defaultBaseUrl;
    _dio.options.baseUrl = _baseUrl!;
  }

  Future<void> setBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_url', url);
    _baseUrl = url;
    _dio.options.baseUrl = url;
  }

  Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
  }

  Future<void> saveToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  ApiException _mapError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.connectionError) {
      return const ApiException('Tidak terhubung ke server', offline: true);
    }
    if (e.response != null) {
      final code = e.response!.statusCode ?? 0;
      if (code == 404) {
        return const ApiException('Data tidak ditemukan', notFound: true);
      }
      if (code == 401) {
        return const ApiException('Sesi berakhir, silakan login ulang', unauthorized: true);
      }
      return ApiException('Kesalahan server ($code)');
    }
    return const ApiException('Terjadi kesalahan jaringan', offline: true);
  }

  Future<dynamic> _wrap(Future<Response<dynamic>> Function() request) async {
    try {
      final res = await request();
      return res.data;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<bool> healthCheck() async {
    try {
      final data = await _wrap(() => _dio.get<dynamic>('/health'));
      if (data is Map && data['status'] == 'ok') return true;
      return false;
    } on ApiException {
      return false;
    }
  }

  Future<VerifyPinResult> verifyPin({required String pin}) async {
    if (pin.isEmpty || pin.length > 6) {
      throw const ApiException('PIN tidak valid');
    }
    await _ensureBaseUrl();
    final data = await _wrap(
      () => _dio.post<dynamic>('/auth/verify-pin', data: {'pin': pin}),
    );
    final map = (data is Map) ? Map<String, dynamic>.from(data) : <String, dynamic>{};
    final result = VerifyPinResult(
      ok: map['ok'] == true,
      pinSet: map['pin_set'] == true,
      token: map['token'] as String?,
    );
    if (result.ok && result.token != null) {
      await saveToken(result.token!);
    }
    return result;
  }

  Future<bool> logout() async {
    await _ensureBaseUrl();
    try {
      final data = await _wrap(() => _dio.post<dynamic>('/auth/logout'));
      await clearToken();
      if (data is Map) return data['ok'] == true;
      return false;
    } on ApiException {
      await clearToken();
      return false;
    }
  }

  Future<bool> setPin({String? oldPin, required String newPin}) async {
    await _ensureBaseUrl();
    final data = await _wrap(
      () => _dio.post<dynamic>(
        '/auth/set-pin',
        data: {'old_pin': oldPin, 'new_pin': newPin},
      ),
    );
    if (data is Map) return data['ok'] == true;
    return false;
  }

  Future<AppSettings> getSettings() async {
    await _ensureBaseUrl();
    final data = await _wrap(() => _dio.get<dynamic>('/settings'));
    return AppSettings.fromJson(
      (data is Map) ? Map<String, dynamic>.from(data) : <String, dynamic>{},
    );
  }

  Future<AppSettings> updateSettings({required String storeName}) async {
    await _ensureBaseUrl();
    final data = await _wrap(
      () => _dio.put<dynamic>('/settings', data: {'store_name': storeName}),
    );
    return AppSettings.fromJson(
      (data is Map) ? Map<String, dynamic>.from(data) : <String, dynamic>{},
    );
  }

  Future<ProductPage> getProducts({
    int page = 1,
    int pageSize = 50,
    int? categoryId,
    bool? favorite,
    bool includeInactive = false,
  }) async {
    await _ensureBaseUrl();
    final data = await _wrap(
      () => _dio.get<dynamic>('/products', queryParameters: {
        'page': page,
        'page_size': pageSize,
        if (categoryId != null) 'category_id': categoryId,
        if (favorite != null) 'favorite': favorite,
        if (includeInactive) 'include_inactive': true,
      }),
    );
    final map = (data is Map) ? Map<String, dynamic>.from(data) : <String, dynamic>{};
    final rawItems = map['items'];
    final items = (rawItems is List)
        ? rawItems
            .whereType<Map>()
            .map((e) => Product.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <Product>[];
    return ProductPage(
      items: items,
      page: (map['page'] as num?)?.toInt() ?? page,
      pageSize: (map['page_size'] as num?)?.toInt() ?? pageSize,
      total: (map['total'] as num?)?.toInt() ?? items.length,
    );
  }

  Future<List<Product>> searchProducts(String q) async {
    await _ensureBaseUrl();
    final data = await _wrap(
      () => _dio.get<dynamic>('/products/search', queryParameters: {'q': q}),
    );
    if (data is! List) return [];
    return data
        .whereType<Map>()
        .map((e) => Product.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<Product?> getProductByBarcode(String code) async {
    await _ensureBaseUrl();
    try {
      final data = await _wrap(
        () => _dio.get<dynamic>('/products/barcode/$code'),
      );
      return Product.fromJson(
        (data is Map) ? Map<String, dynamic>.from(data) : <String, dynamic>{},
      );
    } on ApiException catch (e) {
      if (e.notFound) return null;
      rethrow;
    }
  }

  Future<List<Category>> getCategories() async {
    await _ensureBaseUrl();
    final data = await _wrap(() => _dio.get<dynamic>('/categories'));
    if (data is! List) return [];
    return data
        .whereType<Map>()
        .map((e) => Category.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<Category> addCategory(String name) async {
    if (name.trim().isEmpty) {
      throw const ApiException('Nama kategori tidak boleh kosong');
    }
    await _ensureBaseUrl();
    final data = await _wrap(
      () => _dio.post<dynamic>('/categories', data: {'name': name}),
    );
    return Category.fromJson(
      (data is Map) ? Map<String, dynamic>.from(data) : {'id': 0, 'name': name},
    );
  }

  Future<Product> addProduct({
    required String name,
    required double priceSell,
    int? categoryId,
    String? barcode,
    String unitBase = 'pcs',
  }) async {
    if (name.trim().isEmpty) {
      throw const ApiException('Nama produk tidak boleh kosong');
    }
    if (priceSell <= 0) {
      throw const ApiException('Harga jual harus lebih dari 0');
    }
    await _ensureBaseUrl();
    final data = await _wrap(
      () => _dio.post<dynamic>('/products', data: {
        'name': name,
        'price_sell': priceSell,
        'category_id': categoryId,
        'barcode': barcode,
        'unit_base': unitBase,
      }),
    );
    return Product.fromJson(
      (data is Map) ? Map<String, dynamic>.from(data) : <String, dynamic>{},
    );
  }

  Future<Product> updateProduct(int id, Map<String, dynamic> payload) async {
    await _ensureBaseUrl();
    final data = await _wrap(
      () => _dio.put<dynamic>('/products/$id', data: payload),
    );
    return Product.fromJson(
      (data is Map) ? Map<String, dynamic>.from(data) : <String, dynamic>{},
    );
  }

  Future<bool> deleteProduct(int id) async {
    await _ensureBaseUrl();
    final data = await _wrap(() => _dio.delete<dynamic>('/products/$id'));
    if (data is Map) return data['ok'] == true;
    return false;
  }

  Future<List<StockAlert>> getStockAlerts() async {
    await _ensureBaseUrl();
    final data = await _wrap(() => _dio.get<dynamic>('/stock/alerts'));
    if (data is! List) return [];
    return data
        .whereType<Map>()
        .map((e) => StockAlert.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<StockLog>> getStockLogs({int limit = 100}) async {
    await _ensureBaseUrl();
    final data = await _wrap(
      () => _dio.get<dynamic>('/stock/logs', queryParameters: {'limit': limit}),
    );
    if (data is! List) return [];
    return data
        .whereType<Map>()
        .map((e) => StockLog.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<ReportSummary> getReportSummary() async {
    await _ensureBaseUrl();
    final data = await _wrap(() => _dio.get<dynamic>('/reports/summary'));
    final map = (data is Map) ? Map<String, dynamic>.from(data) : <String, dynamic>{};
    final today = map['today'];
    return today is Map
        ? ReportSummary.fromJson(Map<String, dynamic>.from(today))
        : const ReportSummary(
            totalTransactions: 0,
            omzet: 0,
            avgBelanja: 0,
            itemsSold: 0,
          );
  }

  Future<MonthlyReport> getReportMonthly({int? month, int? year}) async {
    await _ensureBaseUrl();
    final data = await _wrap(
      () => _dio.get<dynamic>('/reports/monthly', queryParameters: {
        if (month != null) 'month': month,
        if (year != null) 'year': year,
      }),
    );
    return MonthlyReport.fromJson(
      (data is Map) ? Map<String, dynamic>.from(data) : <String, dynamic>{},
    );
  }

  Future<DailyReport> getReportDaily(String date) async {
    await _ensureBaseUrl();
    final data = await _wrap(
      () => _dio.get<dynamic>('/reports/daily', queryParameters: {'dt': date}),
    );
    return DailyReport.fromJson(
      (data is Map) ? Map<String, dynamic>.from(data) : <String, dynamic>{},
    );
  }

  Future<List<TopProduct>> getTopProducts({int limit = 10}) async {
    await _ensureBaseUrl();
    final data = await _wrap(
      () => _dio.get<dynamic>(
        '/reports/top-products',
        queryParameters: {'limit': limit},
      ),
    );
    if (data is! List) return [];
    return data
        .whereType<Map>()
        .map((e) => TopProduct.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<BackupFile>> getBackupList() async {
    await _ensureBaseUrl();
    final data = await _wrap(() => _dio.get<dynamic>('/backup/list'));
    if (data is! List) return [];
    return data
        .whereType<Map>()
        .map((e) => BackupFile.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<bool> restoreBackup(String filename) async {
    await _ensureBaseUrl();
    final data = await _wrap(
      () => _dio.post<dynamic>('/backup/restore', queryParameters: {
        'filename': filename,
      }),
    );
    if (data is Map) return data['ok'] == true;
    return false;
  }

  Future<HealthInfo> getHealth() async {
    await _ensureBaseUrl();
    final data = await _wrap(() => _dio.get<dynamic>('/health'));
    return HealthInfo.fromJson(
      (data is Map) ? Map<String, dynamic>.from(data) : <String, dynamic>{},
    );
  }

  Future<String> exportReport({
    required String format,
    required String dateFrom,
    required String dateTo,
    required String savePath,
  }) async {
    await _ensureBaseUrl();
    try {
      await _dio.download(
        '/reports/export',
        savePath,
        queryParameters: {
          'format': format,
          'date_from': dateFrom,
          'date_to': dateTo,
        },
      );
      return savePath;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<Transaction> createTransaction({
    required List<CartItem> items,
    required String paymentMethod,
    double? cashReceived,
    double discountAmount = 0,
    int? customerId,
    List<PaymentSplit>? paymentSplit,
    String? dueDate,
    String? deviceId,
  }) async {
    await _ensureBaseUrl();
    final data = await _wrap(
      () => _dio.post<dynamic>('/transactions', data: {
        'items': items.map((e) => e.toPayload()).toList(),
        'payment_method': paymentMethod,
        'cash_received': cashReceived,
        'discount_amount': discountAmount,
        'customer_id': customerId,
        'payment_split': paymentSplit?.map((e) => e.toJson()).toList(),
        'device_id': deviceId,
        'due_date': dueDate,
      }),
    );
    return Transaction.fromJson(
      (data is Map) ? Map<String, dynamic>.from(data) : <String, dynamic>{},
    );
  }

  Future<TxPage> getTransactions({
    String? dateFrom,
    String? dateTo,
    int page = 1,
  }) async {
    await _ensureBaseUrl();
    final data = await _wrap(
      () => _dio.get<dynamic>('/transactions', queryParameters: {
        if (dateFrom != null) 'date_from': dateFrom,
        if (dateTo != null) 'date_to': dateTo,
        'page': page,
      }),
    );
    final map = (data is Map) ? Map<String, dynamic>.from(data) : <String, dynamic>{};
    final rawItems = map['items'];
    final items = (rawItems is List)
        ? rawItems
            .whereType<Map>()
            .map((e) => Transaction.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <Transaction>[];
    return TxPage(
      items: items,
      total: (map['total'] as num?)?.toInt() ?? items.length,
    );
  }

  Future<Transaction> getTransaction(int id) async {
    await _ensureBaseUrl();
    final data = await _wrap(() => _dio.get<dynamic>('/transactions/$id'));
    return Transaction.fromJson(
      (data is Map) ? Map<String, dynamic>.from(data) : <String, dynamic>{},
    );
  }

  Future<bool> voidTransaction(int id, {String reason = ''}) async {
    await _ensureBaseUrl();
    final data = await _wrap(
      () => _dio.post<dynamic>('/transactions/$id/void', data: {'reason': reason}),
    );
    if (data is Map) return data['ok'] == true;
    return false;
  }

  Future<List<Customer>> getCustomers({String? q}) async {
    await _ensureBaseUrl();
    final data = await _wrap(
      () => _dio.get<dynamic>('/customers', queryParameters: {if (q != null) 'q': q}),
    );
    if (data is! List) return [];
    return data
        .whereType<Map>()
        .map((e) => Customer.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<Customer> addCustomer({required String name, String? phone}) async {
    await _ensureBaseUrl();
    final data = await _wrap(
      () => _dio.post<dynamic>('/customers', data: {'name': name, 'phone': phone}),
    );
    return Customer.fromJson(
      (data is Map) ? Map<String, dynamic>.from(data) : <String, dynamic>{},
    );
  }

  Future<List<DebtGroup>> getDebts() async {
    await _ensureBaseUrl();
    final data = await _wrap(() => _dio.get<dynamic>('/debts'));
    if (data is! List) return [];
    return data
        .whereType<Map>()
        .map((e) => DebtGroup.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<bool> payDebt(int debtId, {required double amountPaid}) async {
    await _ensureBaseUrl();
    final data = await _wrap(
      () => _dio.post<dynamic>('/debts/$debtId/pay', data: {'amount_paid': amountPaid}),
    );
    if (data is Map) return data['ok'] == true;
    return false;
  }

  Future<bool> adjustStock({
    required int productId,
    required double changeQty,
    String reason = '',
  }) async {
    await _ensureBaseUrl();
    final data = await _wrap(
      () => _dio.post<dynamic>('/stock/adjust', data: {
        'product_id': productId,
        'change_qty': changeQty,
        'reason': reason,
      }),
    );
    if (data is Map) return data['ok'] == true;
    return false;
  }

  Future<List<Map<String, dynamic>>> syncPush(
    List<Map<String, dynamic>> transactions,
  ) async {
    await _ensureBaseUrl();
    final data = await _wrap(
      () => _dio.post<dynamic>('/sync/push', data: {'transactions': transactions}),
    );
    if (data is Map) {
      final raw = data['results'];
      if (raw is List) {
        return raw
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    }
    return [];
  }

  Future<Map<String, dynamic>> syncPull({String? since}) async {
    await _ensureBaseUrl();
    final data = await _wrap(
      () => _dio.get<dynamic>('/sync/pull', queryParameters: {if (since != null) 'since': since}),
    );
    return (data is Map) ? Map<String, dynamic>.from(data) : <String, dynamic>{};
  }

  Future<bool> triggerBackup() async {
    await _ensureBaseUrl();
    final data = await _wrap(() => _dio.post<dynamic>('/backup/trigger'));
    if (data is Map) return data['ok'] == true;
    return false;
  }

  Future<String?> uploadProductPhoto(int productId, String filePath) async {
    await _ensureBaseUrl();
    final fileName = filePath.split(Platform.pathSeparator).last.split('/').last;
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: fileName),
    });
    final data = await _wrap(
      () => _dio.post<dynamic>('/products/$productId/photo', data: formData),
    );
    if (data is Map && data['ok'] == true) {
      return data['photo_path'] as String?;
    }
    return null;
  }
}
