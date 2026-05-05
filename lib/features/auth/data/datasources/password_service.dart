import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:railway_secretariat/core/platform/foundation_shims.dart'
    if (dart.library.ui) 'package:flutter/foundation.dart'
    show kIsWeb;
import 'package:crypto/crypto.dart';

class PasswordHashResult {
  final String saltBase64;
  final String hashBase64;
  final String algorithm;
  final int iterations;

  const PasswordHashResult({
    required this.saltBase64,
    required this.hashBase64,
    required this.algorithm,
    required this.iterations,
  });
}

class PasswordService {
  static const String algorithm = 'pbkdf2_sha256';
  static const int _defaultIterationsNative = 120000;
  // Web-mode iteration count. Bumped from a legacy value of 1,000 (which
  // is well below the 2024 OWASP guidance of ≥100k for PBKDF2-SHA256) up
  // to 100,000. On modern browsers this completes in well under 200 ms
  // for a 32-byte derivation, so the user-perceived login latency stays
  // imperceptible while the hash now sits squarely in the secure bucket.
  // Hashes that were stored at the lower count remain valid because the
  // iteration count is persisted per-user and verification reads it from
  // the row; on the next successful Web login we transparently re-hash
  // the row at the new count via the upgrade path in
  // `DatabaseService.authenticateUser` (see the
  // `needsWebIterationUpgrade` branch).
  static const int _defaultIterationsWeb = 100000;
  static const int _saltLength = 16;
  static const int _keyLength = 32;

  int get recommendedIterations =>
      kIsWeb ? _defaultIterationsWeb : _defaultIterationsNative;

  PasswordHashResult hashPassword(
    String password, {
    String? saltBase64,
    int? iterations,
  }) {
    final effectiveIterations =
        (iterations ?? recommendedIterations).clamp(1, 1000000);
    final saltBytes = saltBase64 != null
        ? base64Decode(saltBase64)
        : _randomBytes(_saltLength);
    final passwordBytes = Uint8List.fromList(utf8.encode(password));
    final derived = _pbkdf2(
      passwordBytes: passwordBytes,
      saltBytes: saltBytes,
      iterations: effectiveIterations,
      keyLength: _keyLength,
    );

    return PasswordHashResult(
      saltBase64: base64Encode(saltBytes),
      hashBase64: base64Encode(derived),
      algorithm: algorithm,
      iterations: effectiveIterations,
    );
  }

  bool verifyPassword({
    required String plainPassword,
    required String saltBase64,
    required String storedHashBase64,
    required String storedAlgorithm,
    required int iterations,
  }) {
    if (storedAlgorithm != algorithm ||
        saltBase64.isEmpty ||
        storedHashBase64.isEmpty) {
      return false;
    }

    final result = hashPassword(
      plainPassword,
      saltBase64: saltBase64,
      iterations: iterations > 0 ? iterations : recommendedIterations,
    );
    return _constantTimeEquals(result.hashBase64, storedHashBase64);
  }

  Uint8List _pbkdf2({
    required Uint8List passwordBytes,
    required Uint8List saltBytes,
    required int iterations,
    required int keyLength,
  }) {
    final hmac = Hmac(sha256, passwordBytes);
    const hashLength = 32; // sha256 output bytes
    final blockCount = (keyLength / hashLength).ceil();

    final output = BytesBuilder(copy: false);
    for (var blockIndex = 1; blockIndex <= blockCount; blockIndex++) {
      final block = _int32BigEndian(blockIndex);
      var u = hmac.convert(Uint8List.fromList([...saltBytes, ...block])).bytes;
      final t = List<int>.from(u);

      for (var i = 1; i < iterations; i++) {
        u = hmac.convert(u).bytes;
        for (var j = 0; j < hashLength; j++) {
          t[j] ^= u[j];
        }
      }
      output.add(t);
    }

    final allBytes = output.toBytes();
    return Uint8List.fromList(allBytes.sublist(0, keyLength));
  }

  Uint8List _int32BigEndian(int value) {
    final b = ByteData(4);
    b.setUint32(0, value);
    return b.buffer.asUint8List();
  }

  Uint8List _randomBytes(int length) {
    final random = Random.secure();
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = random.nextInt(256);
    }
    return bytes;
  }

  bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) {
      return false;
    }
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }
}
