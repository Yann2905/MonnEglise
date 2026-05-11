/*
 * FICHIER : lib/models/sermon_model.dart
 *
 * Modèle pour une prédication.
 * Table Supabase : `sermons`
 */

class SermonModel {
  final String id;
  final String churchId;
  final String theme;
  final String? verses;
  final String? audioUrl;
  final int? durationSec;
  final DateTime sermonDate;
  final DateTime createdAt;

  SermonModel({
    required this.id,
    required this.churchId,
    required this.theme,
    this.verses,
    this.audioUrl,
    this.durationSec,
    required this.sermonDate,
    required this.createdAt,
  });

  factory SermonModel.fromJson(Map<String, dynamic> data) {
    return SermonModel(
      id:          data['id']?.toString() ?? '',
      churchId:    data['church_id']?.toString() ?? '',
      theme:       data['theme']?.toString() ?? '',
      verses:      data['verses']?.toString(),
      audioUrl:    data['audio_url']?.toString(),
      durationSec: data['duration_sec'] as int?,
      sermonDate:  data['sermon_date'] != null
          ? DateTime.parse(data['sermon_date'] as String)
          : DateTime.now(),
      createdAt:   data['created_at'] != null
          ? DateTime.parse(data['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id':           id,
        'church_id':    churchId,
        'theme':        theme,
        'verses':       verses,
        'audio_url':    audioUrl,
        'duration_sec': durationSec,
        'sermon_date':  sermonDate.toIso8601String(),
        'created_at':   createdAt.toIso8601String(),
      };

  bool get hasAudio => audioUrl != null && audioUrl!.isNotEmpty;

  /// Format durée "MM:SS" (ou "HH:MM:SS" si > 1h)
  String? get formattedDuration {
    if (durationSec == null) return null;
    final h = durationSec! ~/ 3600;
    final m = (durationSec! % 3600) ~/ 60;
    final s = durationSec! % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
