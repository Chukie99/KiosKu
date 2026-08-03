import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'offline_db.dart';
import 'pages/debts_page.dart';
import 'pages/history_page.dart';
import 'pages/kasir.dart';
import 'pages/pin_lock.dart';
import 'pages/settings_page.dart';
import 'providers.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
    await ref.read(settingsProvider.future);
    if (!mounted) return;
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

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          KasirPage(),
          HistoryPage(),
          DebtPage(),
          SettingsPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(LucideIcons.store),
            label: 'Kasir',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.history),
            label: 'Riwayat',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.receipt),
            label: 'Utang',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.settings),
            label: 'Pengaturan',
          ),
        ],
      ),
    );
  }
}
