import 'dart:io' show Platform;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';

class ScannedDocument {
  final String path;
  final String name;

  const ScannedDocument({
    required this.path,
    required this.name,
  });
}

class DocumentScanService {
  final ImagePicker _imagePicker = ImagePicker();

  /// Returns true when the camera API is available on the current platform.
  static bool get isCameraSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  Future<ScannedDocument?> pickFile({
    required List<String> allowedExtensions,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
    );

    if (result == null || result.files.isEmpty) {
      return null;
    }

    final picked = result.files.single;
    final path = picked.path?.trim() ?? '';
    if (path.isEmpty) {
      return null;
    }

    return ScannedDocument(path: path, name: picked.name);
  }

  Future<ScannedDocument?> scanFromCamera({
    String fileNamePrefix = 'scan',
  }) async {
    if (!isCameraSupported) {
      return null;
    }

    final captured = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 92,
    );

    if (captured == null) {
      return null;
    }

    final path = captured.path.trim();
    if (path.isEmpty) {
      return null;
    }

    final rawName = captured.name.trim();
    final name = rawName.isEmpty
        ? '${fileNamePrefix}_${DateTime.now().millisecondsSinceEpoch}.jpg'
        : rawName;

    return ScannedDocument(path: path, name: name);
  }
}
