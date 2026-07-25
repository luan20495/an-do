import 'dart:convert';
import 'dart:io';

import 'package:an_do/features/report/domain/road_report.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RoadReportRepository {
  static const _pendingKey = 'pending_road_reports';

  Future<void> submit(RoadReport report, File? image) async {
    if (Firebase.apps.isEmpty) {
      await _enqueue(report, image?.path);
      return;
    }

    try {
      String? photoUrl;
      if (image != null) {
        final directory = await getTemporaryDirectory();
        final target = '${directory.path}/${report.id}.jpg';
        final compressed = await FlutterImageCompress.compressAndGetFile(
          image.path,
          target,
          minWidth: 1440,
          minHeight: 960,
          quality: 80,
          keepExif: false,
        );
        if (compressed != null) {
          final reference = FirebaseStorage.instance.ref(
            'road_reports/${report.ownerId}/${report.id}.jpg',
          );
          await reference.putFile(
            File(compressed.path),
            SettableMetadata(contentType: 'image/jpeg'),
          );
          photoUrl = await reference.getDownloadURL();
        }
      }
      final json = report.toJson()..['photoUrl'] = photoUrl;
      await FirebaseFirestore.instance
          .collection('road_reports')
          .doc(report.id)
          .set(json);
    } catch (_) {
      await _enqueue(report, image?.path);
      rethrow;
    }
  }

  Future<void> _enqueue(RoadReport report, String? localImagePath) async {
    final preferences = await SharedPreferences.getInstance();
    final current = preferences.getStringList(_pendingKey) ?? <String>[];
    current.add(jsonEncode({
      ...report.toJson(),
      'localImagePath': localImagePath,
      'queuedAt': DateTime.now().millisecondsSinceEpoch,
    }));
    await preferences.setStringList(_pendingKey, current);
  }
}
