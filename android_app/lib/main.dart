import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'api.dart';
import 'models.dart';
import 'offline_db.dart';
import 'pages/debts_page.dart';
import 'pages/history_page.dart';
import 'pages/kasir.dart';
import 'pages/owner/dashboard_page.dart';
import 'pages/owner/products_page.dart';
import 'pages/owner/reports_page.dart';
import 'pages/owner/stock_page.dart';
import 'pages/pin_lock.dart';
import 'pages/settings_page.dart';
import 'providers.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  const windowOptions = WindowOptions(
    size: Size(1380, 860),
    minimumSize: Size(1100, 700),
    center: true,
    title: 'KiosKu — Kasir Warung',
    titleBarStyle: TitleBarStyle.normal,
  );
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });
  await OfflineDatabase.instance.init();
  runApp(const ProviderScope(child: KioskuApp()));
}

class KioskuApp extends StatelessWidget {
  const KioskuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KiosKu',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const HomeGate(),
    );
  }
}

class HomeGate extends ConsumerStatefulWidget {
  const HomeGate({super.key});

  @override
  ConsumerState<HomeGate> createState() => _HomeGateState();
}

class _HomeGateState extends ConsumerState<HomeGate> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await ref.read(apiProvider).loadToken();
    await ref.read(settingsProvider.future);
    if (!mounted) return;
    ref.read(apiProvider).onUnauthorized = () {
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const PinLockScreen()),
        (route) => false,
      );
    };
    setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(connectionProvider, (previous, next) {
      if (next.valueOrNull == true && previous?.valueOrNull != true) {
        ref.read(syncProvider.notifier).syncNow();
      }
    });
    if (!_ready) return const _SplashScreen();
    final settings = ref.watch(settingsProvider).valueOrNull;
    final pinSet = settings?.pinSet ?? false;
    if (pinSet) {
      return const PinLockScreen();
    }
    return const MainShell();
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                LucideIcons.store,
                size: 44,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'KiosKu',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                fontFamily: 'Fraunces',
              ),
            ),
            const SizedBox(height: 24),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum AppMode { kasir, pemilik }

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  AppMode _mode = AppMode.kasir;
  int _index = 0;
  bool _unlockedPemilik = false;

  void _switchMode(AppMode mode) {
    if (mode == _mode) return;
    if (mode == AppMode.pemilik && !_unlockedPemilik) {
      _verifyOwnerPin();
      return;
    }
    setState(() {
      _mode = mode;
      _index = 0;
    });
  }

  Future<void> _verifyOwnerPin() async {
    final controller = TextEditingController();
    final isLoading = ValueNotifier<bool>(false);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Mode Pemilik'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Masukkan PIN untuk mengakses menu pemilik toko.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              ValueListenableBuilder<bool>(
                valueListenable: isLoading,
                builder: (_, loading, __) {
                  return TextField(
                    controller: controller,
                    autofocus: true,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    enabled: !loading,
                    decoration: InputDecoration(
                      labelText: 'PIN',
                      counterText: '',
                      suffixIcon: loading
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : null,
                    ),
                  );
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Batal'),
            ),
            ValueListenableBuilder<bool>(
              valueListenable: isLoading,
              builder: (_, loading, __) {
                return FilledButton(
                  onPressed: loading ? null : () => Navigator.pop(dialogContext, true),
                  child: loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Masuk'),
                );
              },
            ),
          ],
        );
      },
    );
    try {
      if (ok != true || !mounted) return;
      final pin = controller.text.trim();
      if (pin.length != 4) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN harus 4 digit')),
        );
        return;
      }
      var valid = false;
      isLoading.value = true;
      try {
        final result = await ref.read(apiProvider).verifyPin(pin: pin);
        valid = result.ok;
      } on ApiException catch (e) {
        if (e.offline) {
          final prefs = await SharedPreferences.getInstance();
          final stored = prefs.getString('pin_hash');
          valid = stored != null && stored == hashPin(pin);
        }
      }
      if (!mounted) return;
      if (valid) {
        setState(() {
          _unlockedPemilik = true;
          _mode = AppMode.pemilik;
          _index = 0;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN salah')),
        );
      }
    } finally {
      controller.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider).valueOrNull;
    final online = ref.watch(connectionProvider).valueOrNull;

    final kasirDestinations = <NavigationRailDestination>[
      const NavigationRailDestination(
        icon: Icon(LucideIcons.store),
        label: Text('Kasir'),
      ),
      const NavigationRailDestination(
        icon: Icon(LucideIcons.history),
        label: Text('Riwayat'),
      ),
      const NavigationRailDestination(
        icon: Icon(LucideIcons.receipt),
        label: Text('Utang'),
      ),
      const NavigationRailDestination(
        icon: Icon(LucideIcons.settings),
        label: Text('Pengaturan'),
      ),
    ];

    final pemilikDestinations = <NavigationRailDestination>[
      const NavigationRailDestination(
        icon: Icon(LucideIcons.layoutDashboard),
        label: Text('Dashboard'),
      ),
      const NavigationRailDestination(
        icon: Icon(LucideIcons.package),
        label: Text('Produk'),
      ),
      const NavigationRailDestination(
        icon: Icon(LucideIcons.packageMinus),
        label: Text('Stok'),
      ),
      const NavigationRailDestination(
        icon: Icon(LucideIcons.barChart3),
        label: Text('Laporan'),
      ),
      const NavigationRailDestination(
        icon: Icon(LucideIcons.receipt),
        label: Text('Utang'),
      ),
      const NavigationRailDestination(
        icon: Icon(LucideIcons.settings),
        label: Text('Pengaturan'),
      ),
    ];

    final kasirPages = <Widget>[
      const KasirPage(),
      const HistoryPage(),
      const DebtPage(),
      const SettingsPage(),
    ];

    final pemilikPages = <Widget>[
      const OwnerDashboardPage(),
      const OwnerProductsPage(),
      const OwnerStockPage(),
      const OwnerReportsPage(),
      const DebtPage(),
      const SettingsPage(),
    ];

    final isKasir = _mode == AppMode.kasir;
    final destinations = isKasir ? kasirDestinations : pemilikDestinations;
    final pages = isKasir ? kasirPages : pemilikPages;
    if (_index >= pages.length) _index = 0;

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            backgroundColor: AppColors.surface,
            selectedIndex: _index,
            groupAlignment: -0.9,
            onDestinationSelected: (index) =>
                setState(() => _index = index),
            labelType: NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      LucideIcons.store,
                      size: 24,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _ModeSwitchButton(
                    current: _mode,
                    onChanged: _switchMode,
                  ),
                ],
              ),
            ),
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: (online == true
                                  ? AppColors.success
                                  : AppColors.danger)
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              online == true
                                  ? LucideIcons.wifi
                                  : LucideIcons.wifiOff,
                              size: 12,
                              color: online == true
                                  ? AppColors.success
                                  : AppColors.danger,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              online == true ? 'Online' : 'Offline',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: online == true
                                    ? AppColors.success
                                    : AppColors.danger,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        settings?.storeName ?? 'KiosKu',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            destinations: destinations,
          ),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(
            child: IndexedStack(
              index: _index,
              children: pages,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeSwitchButton extends StatelessWidget {
  final AppMode current;
  final ValueChanged<AppMode> onChanged;

  const _ModeSwitchButton({
    required this.current,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isKasir = current == AppMode.kasir;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () => onChanged(AppMode.kasir),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 64,
            height: 40,
            decoration: BoxDecoration(
              color: isKasir ? AppColors.primary : AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isKasir ? AppColors.primary : AppColors.border,
              ),
            ),
            child: const Icon(
              LucideIcons.shoppingCart,
              size: 20,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Kasir',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: isKasir ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () => onChanged(AppMode.pemilik),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 64,
            height: 40,
            decoration: BoxDecoration(
                color: !isKasir ? AppColors.accentGreen : AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: !isKasir ? AppColors.accentGreen : AppColors.border,
              ),
            ),
            child: const Icon(
              LucideIcons.settings2,
              size: 20,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Pemilik',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: !isKasir
                ? AppColors.accentGreen
                : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
