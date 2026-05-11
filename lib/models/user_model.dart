// ============================================================
// FICHIER 1 : lib/models/user_model.dart (CORRIGÉ)
// ============================================================

/*
 * ============================================================
 * FICHIER : lib/models/user_model.dart
 *
 * DESCRIPTION : Modèle de données pour un utilisateur (Admin ou Membre)
 * Base de données : Supabase (PostgreSQL)
 * ============================================================
 */

class UserModel {
  // ========== PROPRIÉTÉS ==========

  // ID unique de l'utilisateur (UUID généré par Supabase)
  final String id;

  // ID de l'utilisateur auth Supabase (référence vers auth.users)
  final String authId;

  // ID de l'église à laquelle appartient l'utilisateur
  final String churchId;

  // Rôle global : 'admin' ou 'membre'
  final String roleGlobal;

  // Numéro de téléphone
  final String phone;

  // Prénom
  final String firstName;

  // Nom de famille
  final String lastName;

  // Quartier
  final String quartier;

  // URL de l'avatar (optionnel)
  final String? avatarUrl;

  // L'utilisateur est-il responsable d'une famille ? (true/false)
  final bool isResponsible;

  // Code membre unique (optionnel)
  final String? memberCode;

  // Code admin (pour les membres, référence au code de l'admin)
  final String? adminCode;

  // Rôle spécifique (optionnel : 'Fidèle', 'Diacre', 'Pasteur', etc.)
  final String? role;

  // Liste des IDs des familles dont l'utilisateur fait partie
  final List<String> familyIds;

  // Date de naissance (optionnel)
  final DateTime? birthDate;

  // Date de création
  final DateTime createdAt;

  // Date de dernière mise à jour
  final DateTime updatedAt;

  // ========== CONSTRUCTEUR ==========
  UserModel({
    required this.id,
    required this.authId,
    required this.churchId,
    required this.roleGlobal,
    required this.phone,
    required this.firstName,
    required this.lastName,
    required this.quartier,
    this.avatarUrl,
    this.isResponsible = false,
    this.memberCode,
    this.adminCode,
    this.role,
    this.familyIds = const [],
    this.birthDate,
    required this.createdAt,
    required this.updatedAt,
  });

  // ========== GETTERS ==========

  // Nom complet (prénom + nom)
  String get fullName => '$firstName $lastName';

  // Vérifie si l'utilisateur est admin
  bool get isAdmin => roleGlobal.toLowerCase() == 'admin';

  // Vérifie si l'utilisateur est membre
  bool get isMember => roleGlobal.toLowerCase() == 'membre';

  // =========================================================
  // ========== CONVERSION DEPUIS SUPABASE ==================
  // =========================================================

  // Méthode principale pour Supabase (snake_case)
  factory UserModel.fromJson(Map<String, dynamic> data) {
    return UserModel(
      id: data['id']?.toString() ?? '',
      authId: data['auth_id']?.toString() ?? '',  // ✅ Ajouté
      churchId: data['church_id']?.toString() ?? '',
      roleGlobal: data['role_global']?.toString() ?? 'membre',
      phone: data['phone']?.toString() ?? '',
      firstName: data['first_name']?.toString() ?? '',
      lastName: data['last_name']?.toString() ?? '',
      quartier: data['quartier']?.toString() ?? '',
      avatarUrl: data['avatar_url']?.toString(),
      isResponsible: data['is_responsible'] ?? false,
      memberCode: data['member_code']?.toString(),
      adminCode: data['admin_code']?.toString(),  // ✅ Ajouté
      role: data['role']?.toString(),
      familyIds: data['family_ids'] != null
          ? List<String>.from(data['family_ids'] as List<dynamic>)
          : [],
      birthDate: data['birth_date'] != null
          ? DateTime.tryParse(data['birth_date'] as String)
          : null,
      createdAt: data['created_at'] != null
          ? DateTime.parse(data['created_at'] as String)
          : DateTime.now(),
      updatedAt: data['updated_at'] != null
          ? DateTime.parse(data['updated_at'] as String)
          : DateTime.now(),
    );
  }

  // Alias pour compatibilité (utilise fromJson)
  factory UserModel.fromSupabase(Map<String, dynamic> data) {
    return UserModel.fromJson(data);
  }

  // =========================================================
  // ========== CONVERSION VERS SUPABASE ====================
  // =========================================================

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'auth_id': authId,  // ✅ Ajouté
      'church_id': churchId,
      'role_global': roleGlobal,
      'phone': phone,
      'first_name': firstName,
      'last_name': lastName,
      'quartier': quartier,
      'avatar_url': avatarUrl,
      'is_responsible': isResponsible,
      'member_code': memberCode,
      'role': role,
      'family_ids': familyIds,
      'birth_date':
          birthDate?.toIso8601String().substring(0, 10), // YYYY-MM-DD
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // Alias pour compatibilité (utilise toJson)
  Map<String, dynamic> toSupabase() {
    return toJson();
  }

  // =========================================================
  // ========== COPIE / MODIFICATION ========================
  // =========================================================

  UserModel copyWith({
    String? churchId,
    String? roleGlobal,
    String? phone,
    String? firstName,
    String? lastName,
    String? quartier,
    String? avatarUrl,
    bool? isResponsible,
    String? memberCode,
    String? adminCode,
    String? role,
    List<String>? familyIds,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id, // ID ne change jamais
      authId: authId,
      churchId: churchId ?? this.churchId,
      roleGlobal: roleGlobal ?? this.roleGlobal,
      phone: phone ?? this.phone,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      quartier: quartier ?? this.quartier,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isResponsible: isResponsible ?? this.isResponsible,
      memberCode: memberCode ?? this.memberCode,
      adminCode: adminCode ?? this.adminCode,
      role: role ?? this.role,
      familyIds: familyIds ?? this.familyIds,
      createdAt: createdAt, // createdAt ne change jamais
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  // =========================================================
  // ========== MÉTHODES UTILES =============================
  // =========================================================

  // Vérifie si l'utilisateur appartient à une famille
  bool belongsToFamily(String familyId) {
    return familyIds.contains(familyId);
  }

  // Ajoute une famille
  UserModel addFamily(String familyId) {
    if (familyIds.contains(familyId)) return this;
    return copyWith(
      familyIds: [...familyIds, familyId],
      updatedAt: DateTime.now(),
    );
  }

  // Retire une famille
  UserModel removeFamily(String familyId) {
    return copyWith(
      familyIds: familyIds.where((id) => id != familyId).toList(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'UserModel(id: $id, authId: $authId, name: $fullName, role: $roleGlobal)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;


}
