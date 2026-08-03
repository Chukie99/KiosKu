import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api.dart';
import '../components.dart';
import '../main.dart';
import '../models.dart';
import '../providers.dart';
import '../theme.dart';

class PinLockScreen extends ConsumerStatefulWidget {
  const PinLockScreen({super.key});

  @override
  ConsumerState<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends ConsumerState<PinLockScreen> {
  static const int _pinLength = 4;

  String _pin = '';
  String? _error;
  bool _submitting = false;
  bool _setPinMode = false;
  String? _firstPin;
  bool _showSetPin = false;

  @override
  void initState() {
    super.initState();
    _checkPinExists();
  }

  Future<void> _checkPinExists() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _showSetPin = !(prefs.getBool('pin_set') ?? false);
    });
  }

  void _onKey(String key) {
    if (_submitting) return;
    if (key == 'backspace') {
      if (_pin.isNotEmpty) {
        setState(() {
          _pin = _pin.substring(0, _pin.length - 1);
          _error = null;
        });
      }
      return;
    }
    if (key == '.') return;
    if (_pin.length >= _pinLength) return;
    setState(() {
      _pin += key;
      _error = null;
    });
    if (_pin.length == _pinLength) {
      if (_setPinMode) {
        _handlePinEntry();
      } else {
        _verify();
      }
    }
  }

  Future<void> _handlePinEntry() async {
    if (_firstPin == null) {
      setState(() {
        _firstPin = _pin;
        _pin = '';
      });
      return;
    }
    if (_pin == _firstPin) {
      await _submitSetPin(_pin);
    } else {
      HapticFeedback.vibrate();
      setState(() {
        _error = 'PIN tidak cocok, coba lagi';
        _firstPin = null;
        _pin = '';
      });
    }
  }

  Future<void> _submitSetPin(String newPin) async {
    setState(() => _submitting = true);
    final prefs = await SharedPreferences.getInstance();
    try {
      await ref.read(apiProvider).setPin(newPin: newPin);
      await prefs.setBool('pin_set', true);
      await prefs.setString('pin_hash', hashPin(newPin));
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainShell()),
      );
    } on ApiException catch (e) {
      if (e.offline) {
        await prefs.setBool('pin_set', true);
        await prefs.setString('pin_hash', hashPin(newPin));
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainShell()),
        );
      } else {
        setState(() {
          _error = 'Gagal menyimpan PIN';
          _pin = '';
          _firstPin = null;
        });
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _verify() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final res = await ref.read(apiProvider).verifyPin(pin: _pin);
      if (!mounted) return;
      if (res.ok) {
        await _unlock();
      } else {
        HapticFeedback.vibrate();
        setState(() {
          _error = 'PIN salah';
          _pin = '';
        });
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.offline) {
        final prefs = await SharedPreferences.getInstance();
        final stored = prefs.getString('pin_hash');
        if (stored != null && stored == hashPin(_pin)) {
          await _unlock();
        } else {
          HapticFeedback.vibrate();
          setState(() {
            _error = 'PIN salah';
            _pin = '';
          });
        }
      } else {
        setState(() {
          _error = 'Gagal verifikasi PIN';
          _pin = '';
        });
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _unlock() async {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _setPinMode
        ? (_firstPin == null ? 'Buat PIN Baru' : 'Konfirmasi PIN')
        : 'Masukkan PIN';
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  LucideIcons.store,
                  size: 42,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'KiosKu',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < _pinLength; i++)
                    Container(
                      width: 16,
                      height: 16,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i < _pin.length
                            ? AppColors.primary
                            : AppColors.border,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 20,
                child: _error != null
                    ? Text(
                        _error!,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.danger,
                        ),
                      )
                    : null,
              ),
              const Spacer(flex: 1),
              SizedBox(
                width: 320,
                child: NumericKeypad(onKey: _onKey),
              ),
              const Spacer(flex: 2),
              if (_showSetPin && !_setPinMode)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: OutlinedButton(
                    onPressed: _submitting
                        ? null
                        : () => setState(() {
                              _setPinMode = true;
                              _firstPin = null;
                              _pin = '';
                              _error = null;
                            }),
                    child: const Text('Set PIN'),
                  ),
                )
              else if (_setPinMode)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: TextButton(
                    onPressed: () => setState(() {
                      _setPinMode = false;
                      _firstPin = null;
                      _pin = '';
                      _error = null;
                    }),
                    child: const Text('Batal'),
                  ),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
