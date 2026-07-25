import 'dart:convert';

import 'package:an_do/features/sos/domain/sos_models.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ProfileStore {
  static const _key = 'sos_profile';
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<SosProfile> read() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return const SosProfile();
    return SosProfile.fromJson(
      Map<String, Object?>.from(jsonDecode(raw) as Map),
    );
  }

  Future<void> save(SosProfile value) {
    return _storage.write(key: _key, value: jsonEncode(value.toJson()));
  }
}
