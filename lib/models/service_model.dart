/*
 * FICHIER : lib/models/service_model.dart
 *
 * Modèle pour un culte / événement.
 * Table Supabase : `services`
 */

class ServiceModel {
  final String id;
  final String churchId;
  final String type; // 'dimanche' | 'midweek' | 'special'
  final String? title;
  final DateTime date;
  final String? createdBy;
  final DateTime createdAt;

  ServiceModel({
    required this.id,
    required this.churchId,
    required this.type,
    this.title,
    required this.date,
    this.createdBy,
    required this.createdAt,
  });

  factory ServiceModel.fromJson(Map<String, dynamic> data) {
    return ServiceModel(
      id:        data['id']?.toString() ?? '',
      churchId:  data['church_id']?.toString() ?? '',
      type:      data['type']?.toString() ?? 'dimanche',
      title:     data['title']?.toString(),
      date:      data['date'] != null
          ? DateTime.parse(data['date'] as String)
          : DateTime.now(),
      createdBy: data['created_by']?.toString(),
      createdAt: data['created_at'] != null
          ? DateTime.parse(data['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id':         id,
        'church_id':  churchId,
        'type':       type,
        'title':      title,
        'date':       date.toIso8601String(),
        'created_by': createdBy,
        'created_at': createdAt.toIso8601String(),
      };

  String get typeLabel {
    switch (type) {
      case 'dimanche': return 'Culte de dimanche';
      case 'midweek':  return 'Réunion de semaine';
      case 'special':  return 'Événement spécial';
      default:         return 'Culte';
    }
  }

  String get displayTitle => title?.isNotEmpty == true ? title! : typeLabel;
}
