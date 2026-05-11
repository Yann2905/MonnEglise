/*
 * ============================================================
 * FICHIER : lib/models/church_model.dart
 *
 * DESCRIPTION : Modèle pour les informations de l'église
 * Table Supabase : 'churches'
 * ============================================================
 */


class ChurchModel {
  final String id;
  final String name;
  final String? logoUrl;
  final String adminId;
  final String? inviteCode;
  final DateTime createdAt;

  ChurchModel({
    required this.id,
    required this.name,
    this.logoUrl,
    required this.adminId,
    this.inviteCode,
    required this.createdAt,
  });

  factory ChurchModel.fromMap(Map<String, dynamic> data) {
    return ChurchModel(
      id: data['id'] ?? '',
      name: data['name'] ?? '',
      logoUrl: data['logo_url'],
      adminId: data['admin_id'] ?? '',
      inviteCode: data['invite_code']?.toString(),
      createdAt: data['created_at'] != null
          ? DateTime.parse(data['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'logo_url': logoUrl,
      'admin_id': adminId,
      'invite_code': inviteCode,
      'created_at': createdAt.toIso8601String(),
    };
  }

  static ChurchModel? fromJson(Map<String, dynamic> response) {
    return ChurchModel.fromMap(response);
  }
}

/*
 * UTILISATION DES MODÈLES :
 *
 * 1. Créer une église :
 *    ChurchModel church = ChurchModel(
 *      id: 'uuid-auto-generated',
 *      name: 'Église Baptiste de Cocody',
 *      adminId: 'admin-user-id',
 *      createdAt: DateTime.now(),
 *    );
 *
 * 2. Sauvegarder dans Supabase :
 *    await SupabaseConfig.client
 *      .from('churches')
 *      .insert(church.toMap());
 *
 * 3. Lire depuis Supabase :
 *    final data = await SupabaseConfig.client
 *      .from('churches')
 *      .select()
 *      .eq('id', churchId)
 *      .single();
 *    ChurchModel church = ChurchModel.fromMap(data);
 */