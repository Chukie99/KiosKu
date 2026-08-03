import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'models.dart';
import 'offline_db.dart';

final serverUrlProvider = StateProvider<String>((ref) => ApiClient.defaultBaseUrl);

final apiProvider = Provider<ApiClient>((ref) => ApiClient());

final dbProvider = Provider<OfflineDatabase>((ref) => OfflineDatabase.instance);

final cartProvider =
    StateNotifierProvider<CartNotifier, List<CartItem>>((ref) => CartNotifier());

class CartNotifier extends StateNotifier<List<CartItem>> {
  CartNotifier() : super([]);

  double get total => state.fold(0, (sum, item) => sum + item.subtotal);

  void add(CartItem item) {
    final index = state.indexWhere(
      (e) => e.product.id == item.product.id && e.unitName == item.unitName,
    );
    if (index >= 0) {
      final merged = state[index].copyWith(qty: state[index].qty + item.qty);
      final copy = List<CartItem>.of(state);
      copy[index] = merged;
      state = copy;
    } else {
      state = [...state, item];
    }
  }

  void remove(int index) {
    final copy = List<CartItem>.of(state)..removeAt(index);
    state = copy;
  }

  void changeQty(int index, double qty) {
    if (qty <= 0) {
      remove(index);
      return;
    }
    final copy = List<CartItem>.of(state);
    copy[index] = copy[index].copyWith(qty: qty);
    state = copy;
  }

  void clear() => state = [];
}

final productsProvider =
    AsyncNotifierProvider<ProductsNotifier, List<Product>>(ProductsNotifier.new);

class ProductsNotifier extends AsyncNotifier<List<Product>> {
  int _nextPage = 2;
  bool _hasMore = false;

  bool get hasMore => _hasMore;

  @override
  Future<List<Product>> build() async {
    final db = ref.watch(dbProvider);
    final local = await db.getProducts();
    _refreshFromServer();
    return local;
  }

  Future<void> _refreshFromServer() async {
    try {
      final page = await ref.read(apiProvider).getProducts(page: 1, pageSize: 50);
      final db = ref.read(dbProvider);
      await db.upsertProducts(page.items);
      _nextPage = 2;
      _hasMore = page.total > page.items.length;
      final local = await db.getProducts();
      state = AsyncValue.data(local);
    } catch (_) {}
  }

  Future<void> refresh() => _refreshFromServer();

  Future<void> loadMore() async {
    if (!_hasMore) return;
    try {
      final page = await ref
          .read(apiProvider)
          .getProducts(page: _nextPage, pageSize: 50);
      final db = ref.read(dbProvider);
      await db.upsertProducts(page.items);
      _nextPage++;
      _hasMore = _nextPage * page.pageSize < page.total;
      final local = await db.getProducts();
      state = AsyncValue.data(local);
    } catch (_) {}
  }

  Future<void> toggleFavorite(Product product) async {
    final db = ref.read(dbProvider);
    await db.setFavorite(product.id, !product.isFavorite);
    final local = await db.getProducts();
    state = AsyncValue.data(local);
  }
}

final categoriesProvider =
    AsyncNotifierProvider<CategoriesNotifier, List<Category>>(CategoriesNotifier.new);

class CategoriesNotifier extends AsyncNotifier<List<Category>> {
  @override
  Future<List<Category>> build() async {
    try {
      return await ref.read(apiProvider).getCategories();
    } catch (_) {
      return [];
    }
  }

  Future<void> refresh() async {
    try {
      final cats = await ref.read(apiProvider).getCategories();
      state = AsyncValue.data(cats);
    } catch (_) {}
  }
}

final settingsProvider =
    AsyncNotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

class SettingsNotifier extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() async {
    final prefs = await SharedPreferences.getInstance();
    final fallback = AppSettings(
      storeName: prefs.getString('store_name') ?? 'Toko KiosKu',
      pinSet: prefs.getBool('pin_set') ?? false,
      backupEnabled: false,
      backupHour: '00:00',
    );
    try {
      final settings = await ref.read(apiProvider).getSettings();
      await prefs.setString('store_name', settings.storeName);
      await prefs.setBool('pin_set', settings.pinSet);
      return settings;
    } catch (_) {
      return fallback;
    }
  }

  Future<void> saveStoreName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('store_name', name);
    try {
      final settings = await ref.read(apiProvider).updateSettings(storeName: name);
      state = AsyncValue.data(settings);
    } catch (_) {
      final current = state.value ?? const AppSettings(
        storeName: 'Toko KiosKu',
        pinSet: false,
        backupEnabled: false,
        backupHour: '00:00',
      );
      state = AsyncValue.data(current.copyWith(storeName: name));
    }
  }
}

final connectionProvider = StreamProvider<bool>((ref) async* {
  final api = ref.read(apiProvider);
  while (true) {
    final ok = await api.healthCheck();
    yield ok;
    await Future<void>.delayed(const Duration(seconds: 5));
  }
});

final syncProvider =
    AsyncNotifierProvider<SyncNotifier, int>(SyncNotifier.new);

class SyncNotifier extends AsyncNotifier<int> {
  @override
  Future<int> build() async => 0;

  Future<int> _pushPending() async {
    final db = ref.read(dbProvider);
    final api = ref.read(apiProvider);
    final pending = await db.getPendingTransactions();
    int synced = 0;
    for (final entry in pending) {
      try {
        final payload = entry['payload'];
        if (payload is! Map) continue;
        final results = await api.syncPush(
          [Map<String, dynamic>.from(payload)],
        );
        if (results.isNotEmpty) {
          final status = results.first['status'] as String?;
          if (status != null && status.toLowerCase() != 'error') {
            await db.deletePendingTransaction((entry['id'] as num).toInt());
            synced++;
          }
        }
      } catch (_) {}
    }
    return synced;
  }

  Future<int> syncNow() async {
    state = const AsyncValue.loading();
    final synced = await _pushPending();
    state = AsyncValue.data(synced);
    return synced;
  }
}

String buildDeviceId() {
  final seed = DateTime.now().millisecondsSinceEpoch;
  final rand = (seed * 2654435761) % 0x7FFFFFFF;
  return 'kiosku-${rand.toRadixString(16).padLeft(8, '0')}';
}

Future<String> getDeviceId() async {
  final prefs = await SharedPreferences.getInstance();
  var id = prefs.getString('device_id');
  if (id == null || id.isEmpty) {
    id = buildDeviceId();
    await prefs.setString('device_id', id);
  }
  return id;
}

Map<String, dynamic> buildTransactionPayload({
  required List<CartItem> items,
  required String paymentMethod,
  double? cashReceived,
  double discountAmount = 0,
  int? customerId,
  List<PaymentSplit>? paymentSplit,
  String? dueDate,
  String? deviceId,
}) {
  return {
    'items': items.map((e) => e.toPayload()).toList(),
    'payment_method': paymentMethod,
    'cash_received': cashReceived,
    'discount_amount': discountAmount,
    'customer_id': customerId,
    'payment_split': paymentSplit?.map((e) => e.toJson()).toList(),
    'device_id': deviceId,
    'due_date': dueDate,
  };
}

Transaction localTransactionFromPayload(Map<String, dynamic> payload) {
  final rawItems = payload['items'];
  final items = (rawItems is List)
      ? rawItems
          .whereType<Map>()
          .map((e) => TxItem(
                productId: (e['product_id'] as num?)?.toInt() ?? 0,
                productNameSnapshot:
                    (e['product_name_snapshot'] as String?) ?? '',
                unitName: (e['unit_name'] as String?) ?? 'pcs',
                qty: (e['qty'] as num?)?.toDouble() ?? 0,
                pricePerUnit: (e['price_per_unit'] as num?)?.toDouble() ?? 0,
                subtotal: ((e['qty'] as num?)?.toDouble() ?? 0) *
                    ((e['price_per_unit'] as num?)?.toDouble() ?? 0),
              ))
          .toList()
      : <TxItem>[];
  final total = items.fold(0.0, (sum, i) => sum + i.subtotal);
  final cash = (payload['cash_received'] as num?)?.toDouble() ?? total;
  final method = payload['payment_method'] as String? ?? 'tunai';
  final now = DateTime.now();
  return Transaction(
    id: 0,
    invoiceNo: 'L-${now.millisecondsSinceEpoch}',
    totalAmount: total,
    changeAmount: cash - total,
    paymentMethod: method,
    cashReceived: cash,
    discountAmount: (payload['discount_amount'] as num?)?.toDouble() ?? 0,
    status: 'pending',
    createdAt: now.toIso8601String(),
    customerId: (payload['customer_id'] as num?)?.toInt(),
    items: items,
  );
}

String? pendingInvoiceFromPayload(Map<String, dynamic> payload) {
  final raw = payload['invoice_no'];
  if (raw is String && raw.isNotEmpty) return raw;
  final createdAt = payload['local_created_at'] as String?;
  if (createdAt != null) return 'L-${DateTime.tryParse(createdAt)?.millisecondsSinceEpoch ?? 0}';
  return null;
}
