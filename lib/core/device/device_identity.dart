import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class DeviceIdentity {
  static const _key = 'installation_id';
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static String? _cached;

  static Future<String> getOrCreate() async {
    final cached = _cached;
    if (cached != null && cached.isNotEmpty) return cached;
    try {
      final existing = await _storage
          .read(key: _key)
          .timeout(const Duration(seconds: 2));
      if (existing != null && existing.isNotEmpty) {
        return _cached = existing;
      }
      final value = const Uuid().v4();
      await _storage
          .write(key: _key, value: value)
          .timeout(const Duration(seconds: 2));
      return _cached = value;
    } catch (error) {
      debugPrint('Secure identity fallback: $error');
      final prefs = await SharedPreferences.getInstance()
          .timeout(const Duration(seconds: 2));
      final existing = prefs.getString(_key);
      if (existing != null && existing.isNotEmpty) {
        return _cached = existing;
      }
      final value = const Uuid().v4();
      await prefs.setString(_key, value);
      return _cached = value;
    }
  }
}
