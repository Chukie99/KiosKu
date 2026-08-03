import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api.dart';
import '../components.dart';
import '../models.dart';
import '../providers.dart';
import '../theme.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final TextEditingController _serverController = TextEditingController();
  final TextEditingController _storeController = TextEditingController();
  bool _savingServer = false;
  bool _savingStore = false;
  bool _syncing = false;
  bool _backingUp = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final serverUrl = prefs.getString('server_url') ?? ApiClient.defaultBaseUrl;
    final storeName = prefs.getString('store_name') ?? 'Toko KiosKu';
    if (!mounted) return;
    setState(() {
      _serverController.text = serverUrl;
      _storeController.text = storeName;
    });
  }

  Future<void> _saveServerUrl() async {
    final url = _serverController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('URL server tidak boleh kosong')),
      );
      return;
    }
    setState(() => _savingServer = true);
    try {
      await ref.read(apiProvider).setBaseUrl(url);
      ref.read(serverUrlProvider.notifier).state = url;
      final ok = await ref.read(apiProvider).healthCheck();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok
              ? 'Tersimpan — server terhubung'
              : 'URL tersimpan, tetapi server tidak merespons'),
        ),
      );
      ref.invalidate(connectionProvider);
      ref.invalidate(settingsProvider);
    } finally {
      if (mounted) setState(() => _savingServer = false);
    }
  }

  Future<void> _saveStoreName() async {
    final name = _storeController.text.trim();
    if (name.isEmpty) return;
    setState(() => _savingStore = true);
    await ref.read(settingsProvider.notifier).saveStoreName(name);
    if (!mounted) return;
    setState(() => _savingStore = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Nama toko disimpan')),
    );
  }

  Future<void> _changePin() async {
    final oldController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Ubah PIN'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: oldController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                decoration: const InputDecoration(labelText: 'PIN lama'),
              ),
              TextField(
                controller: newController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                decoration: const InputDecoration(labelText: 'PIN baru'),
              ),
              TextField(
                controller: confirmController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                decoration: const InputDecoration(
                  labelText: 'Konfirmasi PIN baru',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
    if (submitted != true) return;
    if (!mounted) return;
    final oldPin = oldController.text.trim();
    final newPin = newController.text.trim();
    if (oldPin.length != 4 || newPin.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN harus 4 digit')),
      );
      return;
    }
    if (newPin != confirmController.text.trim()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Konfirmasi PIN tidak cocok')),
      );
      return;
    }
    try {
      final ok = await ref
          .read(apiProvider)
          .setPin(oldPin: oldPin, newPin: newPin);
      if (ok) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('pin_hash', hashPin(newPin));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN berhasil diubah')),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal mengubah PIN')),
        );
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  Future<void> _triggerBackup() async {
    setState(() => _backingUp = true);
    try {
      final ok = await ref.read(apiProvider).triggerBackup();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok
              ? 'Backup berhasil dijalankan'
              : 'Backup gagal dijalankan'),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.offline ? 'Offline — backup tidak dapat dijalankan' : e.message)),
      );
    } finally {
      if (mounted) setState(() => _backingUp = false);
    }
  }

  Future<void> _syncNow() async {
    setState(() => _syncing = true);
    final synced = await ref.read(syncProvider.notifier).syncNow();
    if (!mounted) return;
    setState(() => _syncing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(synced > 0
            ? '$synced transaksi tersimpan berhasil disinkronkan'
            : 'Tidak ada transaksi menunggu sinkron'),
      ),
    );
  }

  @override
  void dispose() {
    _serverController.dispose();
    _storeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider).valueOrNull;
    final online = ref.watch(connectionProvider).valueOrNull;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan'),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          const ConnectionBanner(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _SectionCard(
                  title: 'Server',
                  icon: LucideIcons.cloud,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _serverController,
                        keyboardType: TextInputType.url,
                        decoration: const InputDecoration(
                          labelText: 'URL Server',
                          hintText: 'http://192.168.1.100:8000',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: (online == true
                                        ? AppColors.success
                                        : AppColors.danger)
                                    .withOpacity(0.1),
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusBadge,
                                ),
                              ),
                              child: Text(
                                online == true
                                    ? 'Terhubung'
                                    : 'Tidak terhubung',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: online == true
                                      ? AppColors.success
                                      : AppColors.danger,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _savingServer
                                  ? null
                                  : _saveServerUrl,
                              child: _savingServer
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Simpan'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _SectionCard(
                  title: 'Toko',
                  icon: LucideIcons.store,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _storeController,
                        decoration: const InputDecoration(
                          labelText: 'Nama Toko',
                        ),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _savingStore ? null : _saveStoreName,
                        child: _savingStore
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Simpan Nama Toko'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _SectionCard(
                  title: 'Keamanan',
                  icon: LucideIcons.lock,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        settings != null
                            ? settings.pinSet
                                ? 'PIN kasir aktif'
                                : 'PIN kasir belum diatur'
                            : 'PIN kasir',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _changePin,
                        icon: const Icon(LucideIcons.keyRound, size: 18),
                        label: const Text('Ubah PIN'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _SectionCard(
                  title: 'Sinkronisasi & Backup',
                  icon: LucideIcons.refreshCcw,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _syncing ? null : _syncNow,
                        icon: _syncing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(LucideIcons.uploadCloud, size: 18),
                        label: const Text('Sinkronkan Sekarang'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _backingUp ? null : _triggerBackup,
                        icon: _backingUp
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                LucideIcons.databaseBackup,
                                size: 18,
                              ),
                        label: const Text('Backup Database'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Center(
                  child: Text(
                    'KiosKu v1.0.0',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
