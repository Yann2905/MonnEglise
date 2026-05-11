/*
 * ============================================================
 * FICHIER : lib/models/absence_model.dart
 *
 * DESCRIPTION : Modèle pour enregistrer les absences d'une famille
 * Table Supabase : 'absences'
 * ============================================================
 */

class AbsenceModel {
  // ========== PROPRIÉTÉS ==========

  // ID unique de l'enregistrement d'absence
  final String id;

  // ID de la famille concernée
  final String familyId;

  // Nom de la famille (dupliqué pour faciliter l'affichage)
  final String familyName;

  // Date de l'événement (ex: dimanche 22 mars 2024)
  final DateTime date;

  // ID du responsable qui a fait l'appel
  final String createdBy;

  // Nombre total d'absents
  final int absentCount;

  // Liste détaillée des membres absents (avec raisons)
  final List<AbsentMember> absentMembers;

  // Date de création de l'enregistrement
  final DateTime createdAt;

  // ========== CONSTRUCTEUR ==========
  AbsenceModel({
    required this.id,
    required this.familyId,
    required this.familyName,
    required this.date,
    required this.createdBy,
    required this.absentCount,
    required this.absentMembers,
    required this.createdAt,
  });

  // ========== CONVERSION DEPUIS SUPABASE ==========
  factory AbsenceModel.fromMap(Map<String, dynamic> data) {
    return AbsenceModel(
      id: data['id'] ?? '',
      familyId: data['family_id'] ?? '',
      familyName: data['family_name'] ?? '',
      date: DateTime.parse(data['date']),
      createdBy: data['created_by'] ?? '',
      absentCount: data['absent_count'] ?? 0,
      absentMembers: (data['absent_members'] as List? ?? [])
          .map((m) => AbsentMember.fromMap(m as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(data['created_at']),
    );
  }

  // ========== CONVERSION VERS SUPABASE ==========
  Map<String, dynamic> toMap() {
    return {
      'family_id': familyId,
      'family_name': familyName,
      'date': date.toIso8601String(),
      'created_by': createdBy,
      'absent_count': absentCount,
      'absent_members': absentMembers.map((m) => m.toMap()).toList(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}

/*
 * ============================================================
 * CLASSE : AbsentMember (sous-modèle)
 *
 * DESCRIPTION : Représente un membre absent dans un enregistrement
 * ============================================================
 */

class AbsentMember {
  // ID de l'utilisateur absent
  final String userId;

  // Nom complet du membre
  final String name;

  // Numéro de téléphone (pour contacter)
  final String phone;

  // Raison de l'absence (optionnel)
  final String? reason;

  AbsentMember({
    required this.userId,
    required this.name,
    required this.phone,
    this.reason,
  });

  // Conversion depuis Map (utilisé dans AbsenceModel)
  factory AbsentMember.fromMap(Map<String, dynamic> map) {
    return AbsentMember(
      userId: map['user_id'] ?? '',
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      reason: map['reason'],
    );
  }

  // Conversion vers Map
  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'name': name,
      'phone': phone,
      'reason': reason,
    };
  }
}