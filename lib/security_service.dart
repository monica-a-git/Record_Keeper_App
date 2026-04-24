import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';

class SecurityService {
  static const _storage = FlutterSecureStorage();
  static const _keyName = 'enter_key';

  // Returns an encryption key. It creates one if it doesn't exist.
  static Future<Uint8List> getEncryptionKey() async {
    final containsKey = await _storage.containsKey(key: _keyName);
    if (!containsKey) {
      // Generate a new 32-byte (256-bit) key
      final key = Hive.generateSecureKey();
      await _storage.write(key: _keyName, value: base64UrlEncode(key));
    }

    final keyString = await _storage.read(key: _keyName);
    return base64Url.decode(keyString!);
  }
}