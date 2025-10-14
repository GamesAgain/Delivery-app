import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io' show File; // ถ้าใช้บน Web ให้เรียกเมธอด uploadBytes()/uploadXFile()

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

/// ผลลัพธ์จาก Cloudinary
class CloudinaryUploadResult {
  final bool success;
  final String? url;        // อาจเป็น http
  final String? secureUrl;  // https (ควรใช้ตัวนี้)
  final String? publicId;
  final int? width;
  final int? height;
  final String? format;
  final int? bytes;

  CloudinaryUploadResult({
    required this.success,
    this.url,
    this.secureUrl,
    this.publicId,
    this.width,
    this.height,
    this.format,
    this.bytes,
  });

  factory CloudinaryUploadResult.fromJson(Map<String, dynamic> json) {
    return CloudinaryUploadResult(
      success: true,
      url: json['url'] as String?,
      secureUrl: json['secure_url'] as String?,
      publicId: json['public_id'] as String?,
      width: (json['width'] as num?)?.toInt(),
      height: (json['height'] as num?)?.toInt(),
      format: json['format'] as String?,
      bytes: (json['bytes'] as num?)?.toInt(),
    );
  }
}

/// Service สำหรับอัปโหลดรูปไป Cloudinary (unsigned upload)
class UploadImgService {
  /// ตั้งค่าของคุณที่นี่
  static const String cloudName = 'didjrcgs2';
  static const String uploadPreset = 'delivery_app';

  /// endpoint หลักของ Cloudinary
  static Uri _endpoint() =>
      Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');

  /// อัปโหลดจากไฟล์ (Mobile/Desktop)
  static Future<CloudinaryUploadResult> uploadFile({
    required File file,
    String? folder,                          // เช่น 'users/avatars'
    Map<String, String>? extraFields,        // ใส่ tag/metadata เพิ่มเติมได้
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final req = http.MultipartRequest('POST', _endpoint())
      ..fields['upload_preset'] = uploadPreset;

    if (folder != null && folder.isNotEmpty) req.fields['folder'] = folder;
    if (extraFields != null) req.fields.addAll(extraFields);

    req.files.add(await http.MultipartFile.fromPath('file', file.path));

    final res = await req.send().timeout(timeout);
    final body = await res.stream.bytesToString();

    if (res.statusCode != 200) {
      throw Exception('Cloudinary upload failed (${res.statusCode}): $body');
    }

    final jsonMap = jsonDecode(body) as Map<String, dynamic>;
    return CloudinaryUploadResult.fromJson(jsonMap);
  }

  /// อัปโหลดจาก bytes (ใช้ได้ทั้ง Mobile และ Web)
  static Future<CloudinaryUploadResult> uploadBytes({
    required Uint8List bytes,
    String filename = 'upload.jpg',
    String? folder,
    Map<String, String>? extraFields,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final req = http.MultipartRequest('POST', _endpoint())
      ..fields['upload_preset'] = uploadPreset;

    if (folder != null && folder.isNotEmpty) req.fields['folder'] = folder;
    if (extraFields != null) req.fields.addAll(extraFields);

    req.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));

    final res = await req.send().timeout(timeout);
    final body = await res.stream.bytesToString();

    if (res.statusCode != 200) {
      throw Exception('Cloudinary upload failed (${res.statusCode}): $body');
    }

    final jsonMap = jsonDecode(body) as Map<String, dynamic>;
    return CloudinaryUploadResult.fromJson(jsonMap);
  }

  /// อัปโหลดจาก XFile (สะดวกกับ image_picker)
  static Future<CloudinaryUploadResult> uploadXFile({
    required XFile xfile,
    String? folder,
    Map<String, String>? extraFields,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    if (kIsWeb) {
      final bytes = await xfile.readAsBytes();
      return uploadBytes(
        bytes: bytes,
        filename: xfile.name,
        folder: folder,
        extraFields: extraFields,
        timeout: timeout,
      );
    } else {
      return uploadFile(
        file: File(xfile.path),
        folder: folder,
        extraFields: extraFields,
        timeout: timeout,
      );
    }
  }
}
