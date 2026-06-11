/*
 * FICHIER : lib/services/cloudinary_service.dart
 *
 * Service d'upload audio sur Cloudinary AVEC progression et annulation.
 *  • Utilise dio directement (cloudinary_public n'expose pas CancelToken)
 *  • Upload preset "unsigned" → pas de secret API en client
 *  • Callback de progression (sent, total) en bytes
 *  • CancelToken pour interrompre l'upload à mi-chemin
 *
 * Endpoint Cloudinary unsigned :
 *   POST https://api.cloudinary.com/v1_1/{cloud_name}/{resource_type}/upload
 *   - file        : multipart
 *   - upload_preset : nom du preset (Settings > Upload > Upload presets)
 *   - folder      : (optionnel) sous-dossier
 */

import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class CloudinaryConfig {
  static const String cloudName = 'dobxpqyru';
  static const String audioUploadPreset = 'moneglise_audios';

  /// Preset utilisé pour les images (avatars + logos d'église).
  /// Configuré en mode "unsigned" sur Cloudinary, séparé de l'audio pour
  /// permettre des règles différentes (compression auto, max dimensions, etc.).
  static const String imageUploadPreset = 'moneglise_images';
}

class CloudinaryUploadResult {
  final String secureUrl;
  final String publicId;
  final String? format;
  final int? bytes;

  const CloudinaryUploadResult({
    required this.secureUrl,
    required this.publicId,
    this.format,
    this.bytes,
  });
}

/// Callback de progression : `(sent, total)` en bytes.
typedef CloudinaryProgressCallback = void Function(int sent, int total);

class CloudinaryService {
  CloudinaryService._();

  static final Dio _dio = Dio();

  /// Upload audio avec progression + cancel.
  /// `cancelToken` permet d'interrompre l'upload (call `cancelToken.cancel()`).
  /// `onProgress` reçoit (sentBytes, totalBytes) — utilise pour MAJ barre UI.
  /// `publicId` (optionnel mais recommandé) : permet de connaître à l'avance
  ///   le public_id du fichier, pour pouvoir le supprimer même si l'upload
  ///   est annulé en cours de route.
  ///
  /// IMPORTANT : si `folder` est fourni, le public_id final sera préfixé du
  /// folder. Exemple : folder=`moneglise/X/sermons` + publicId=`abc123`
  /// → public_id réel = `moneglise/X/sermons/abc123`.
  static Future<CloudinaryUploadResult> uploadAudio({
    String? path,
    Uint8List? bytes,
    required String fileName,
    String? folder,
    String? publicId,
    CloudinaryProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) async {
    final url =
        'https://api.cloudinary.com/v1_1/${CloudinaryConfig.cloudName}/video/upload';

    final MultipartFile multipart;
    if (!kIsWeb && path != null) {
      multipart = await MultipartFile.fromFile(path, filename: fileName);
    } else if (bytes != null) {
      multipart = MultipartFile.fromBytes(bytes, filename: fileName);
    } else {
      throw ArgumentError('CloudinaryService.uploadAudio: path OU bytes requis');
    }

    final formData = FormData.fromMap({
      'file': multipart,
      'upload_preset': CloudinaryConfig.audioUploadPreset,
      if (folder != null) 'folder': folder,
      if (publicId != null) 'public_id': publicId,
    });

    final response = await _dio.post(
      url,
      data: formData,
      cancelToken: cancelToken,
      onSendProgress: (sent, total) {
        if (total > 0 && onProgress != null) onProgress(sent, total);
      },
      options: Options(
        responseType: ResponseType.json,
        // Timeout généreux pour les gros MP3
        sendTimeout: const Duration(minutes: 10),
        receiveTimeout: const Duration(minutes: 2),
      ),
    );

    final data = response.data as Map<String, dynamic>;
    return CloudinaryUploadResult(
      secureUrl: data['secure_url'] as String,
      publicId: data['public_id'] as String,
      format: data['format'] as String?,
      bytes: data['bytes'] as int?,
    );
  }

  /// Upload image (avatar / logo).
  /// Hit l'endpoint `/image/upload`. Compression auto par Cloudinary.
  static Future<CloudinaryUploadResult> uploadImage({
    String? path,
    Uint8List? bytes,
    required String fileName,
    String? folder,
    String? publicId,
    CloudinaryProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) async {
    final url =
        'https://api.cloudinary.com/v1_1/${CloudinaryConfig.cloudName}/image/upload';

    final MultipartFile multipart;
    if (!kIsWeb && path != null) {
      multipart = await MultipartFile.fromFile(path, filename: fileName);
    } else if (bytes != null) {
      multipart = MultipartFile.fromBytes(bytes, filename: fileName);
    } else {
      throw ArgumentError(
          'CloudinaryService.uploadImage: path OU bytes requis');
    }

    final formData = FormData.fromMap({
      'file': multipart,
      'upload_preset': CloudinaryConfig.imageUploadPreset,
      if (folder != null) 'folder': folder,
      if (publicId != null) 'public_id': publicId,
    });

    final response = await _dio.post(
      url,
      data: formData,
      cancelToken: cancelToken,
      onSendProgress: (sent, total) {
        if (total > 0 && onProgress != null) onProgress(sent, total);
      },
      options: Options(
        responseType: ResponseType.json,
        sendTimeout: const Duration(minutes: 3),
        receiveTimeout: const Duration(minutes: 1),
      ),
    );

    final data = response.data as Map<String, dynamic>;
    return CloudinaryUploadResult(
      secureUrl: data['secure_url'] as String,
      publicId: data['public_id'] as String,
      format: data['format'] as String?,
      bytes: data['bytes'] as int?,
    );
  }
}
