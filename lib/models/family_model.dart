/*
 * ============================================================
 * FICHIER : lib/models/family_model.dart (VERSION CORRIGÉE)
 *
 * DESCRIPTION : Modèle de données pour une Famille/Département
 * Base de données : Supabase (PostgreSQL)
 * ============================================================
 */

class FamilyModel {
  // ========== PROPRIÉTÉS ==========

  // ID unique de la famille (UUID généré par Supabase)
  final String id;

  // ID de l'église à laquelle appartient la famille
  final String churchId;

  // Nom de la famille ou département
  final String name;

  // ID du responsable de la famille
  final String responsibleId;

  // Nombre de membres dans la famille
  final int memberCount;

  // Liste des IDs des membres
  final List<String> memberIds;

  // Date de création
  final DateTime createdAt;

  // Date de dernière mise à jour (optionnelle)
  final DateTime? updatedAt;

  // ========== CONSTRUCTEUR ==========
  FamilyModel({
    required this.id,
    required this.churchId,
    required this.name,
    required this.responsibleId,
    this.memberCount = 0,
    this.memberIds = const [],
    required this.createdAt,
    this.updatedAt,
  });

  // =========================================================
  // ========== CONVERSION DEPUIS SUPABASE ==================
  // =========================================================

  // Factory principal pour Supabase (snake_case)
  factory FamilyModel.fromJson(Map<String, dynamic> json) {
    return FamilyModel(
      id: json['id'] as String,
      churchId: json['church_id'] as String,
      name: json['name'] as String,
      responsibleId: json['responsible_id'] as String,
      memberCount: json['member_count'] as int? ?? 0,
      memberIds: (json['member_ids'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ??
          [],
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  // Alias pour compatibilité (utilise fromJson)
  factory FamilyModel.fromSupabase(Map<String, dynamic> data) {
    return FamilyModel.fromJson(data);
  }

  // =========================================================
  // ========== CONVERSION VERS SUPABASE ====================
  // =========================================================

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'church_id': churchId,
      'name': name,
      'responsible_id': responsibleId,
      'member_count': memberCount,
      'member_ids': memberIds,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  // Alias pour compatibilité (utilise toJson)
  Map<String, dynamic> toSupabase() {
    return toJson();
  }

  // =========================================================
  // ========== MÉTHODE COPYWITH ============================
  // =========================================================

  FamilyModel copyWith({
    String? id,
    String? churchId,
    String? name,
    String? responsibleId,
    int? memberCount,
    List<String>? memberIds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FamilyModel(
      id: id ?? this.id,
      churchId: churchId ?? this.churchId,
      name: name ?? this.name,
      responsibleId: responsibleId ?? this.responsibleId,
      memberCount: memberCount ?? this.memberCount,
      memberIds: memberIds ?? this.memberIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // =========================================================
  // ========== MÉTHODES UTILES =============================
  // =========================================================

  // Vérifie si un utilisateur est responsable
  bool isUserResponsible(String userId) {
    return responsibleId == userId;
  }

  // Vérifie si un utilisateur est membre
  bool isUserMember(String userId) {
    return memberIds.contains(userId);
  }

  @override
  String toString() {
    return 'FamilyModel(id: $id, name: $name, memberCount: $memberCount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FamilyModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/*
 * ============================================================
 * STRUCTURE DE LA TABLE SUPABASE
 * ============================================================
 *
 * CREATE TABLE families (
 *   id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
 *   church_id UUID NOT NULL REFERENCES churches(id) ON DELETE CASCADE,
 *   name TEXT NOT NULL,
 *   responsible_id UUID NOT NULL REFERENCES users(id),
 *   member_count INTEGER DEFAULT 0,
 *   member_ids TEXT[] DEFAULT '{}',
 *   created_at TIMESTAMPTZ DEFAULT NOW(),
 *   updated_at TIMESTAMPTZ DEFAULT NOW()
 * );
 *
 * -- Index pour les performances
 * CREATE INDEX idx_families_church_id ON families(church_id);
 * CREATE INDEX idx_families_responsible_id ON families(responsible_id);
 *
 * -- Trigger pour mettre à jour updated_at automatiquement
 * CREATE OR REPLACE FUNCTION update_updated_at_column()
 * RETURNS TRIGGER AS $$
 * BEGIN
 *   NEW.updated_at = NOW();
 *   RETURN NEW;
 * END;
 * $$ language 'plpgsql';
 *
 * CREATE TRIGGER update_families_updated_at
 *   BEFORE UPDATE ON families
 *   FOR EACH ROW
 *   EXECUTE FUNCTION update_updated_at_column();
 *
 * ============================================================
 * POLITIQUES RLS (Row Level Security)
 * ============================================================
 *
 * -- Lecture : Les membres de l'église peuvent voir les familles
 * CREATE POLICY "Users can view families in their church"
 * ON families FOR SELECT
 * USING (
 *   church_id IN (
 *     SELECT church_id FROM users WHERE id = auth.uid()
 *   )
 * );
 *
 * -- Création : Seuls les admins peuvent créer des familles
 * CREATE POLICY "Admins can create families"
 * ON families FOR INSERT
 * WITH CHECK (
 *   EXISTS (
 *     SELECT 1 FROM users
 *     WHERE id = auth.uid()
 *       AND church_id = families.church_id
 *       AND role_global = 'admin'
 *   )
 * );
 *
 * -- Mise à jour : Admins et responsables peuvent modifier
 * CREATE POLICY "Admins and responsible can update families"
 * ON families FOR UPDATE
 * USING (
 *   auth.uid() = responsible_id OR
 *   EXISTS (
 *     SELECT 1 FROM users
 *     WHERE id = auth.uid()
 *       AND church_id = families.church_id
 *       AND role_global = 'admin'
 *   )
 * );
 *
 * -- Suppression : Seuls les admins
 * CREATE POLICY "Only admins can delete families"
 * ON families FOR DELETE
 * USING (
 *   EXISTS (
 *     SELECT 1 FROM users
 *     WHERE id = auth.uid()
 *       AND church_id = families.church_id
 *       AND role_global = 'admin'
 *   )
 * );
 *
 * ============================================================
 * EXEMPLES D'UTILISATION
 * ============================================================
 *
 * // 1. CRÉER UNE NOUVELLE FAMILLE
 * final newFamily = FamilyModel(
 *   id: 'uuid-generated',
 *   churchId: 'church-uuid',
 *   name: 'Famille Martin',
 *   responsibleId: 'user-uuid',
 *   createdAt: DateTime.now(),
 * );
 *
 * await supabase
 *   .from('families')
 *   .insert(newFamily.toJson());
 *
 * // 2. RÉCUPÉRER UNE FAMILLE
 * final response = await supabase
 *   .from('families')
 *   .select()
 *   .eq('id', familyId)
 *   .single();
 *
 * final family = FamilyModel.fromJson(response);
 *
 * // 3. METTRE À JOUR UNE FAMILLE
 * final updatedFamily = family.copyWith(
 *   name: 'Nouveau nom',
 *   memberCount: 5,
 * );
 *
 * await supabase
 *   .from('families')
 *   .update(updatedFamily.toJson())
 *   .eq('id', familyId);
 *
 * // 4. RÉCUPÉRER TOUTES LES FAMILLES D'UNE ÉGLISE
 * final response = await supabase
 *   .from('families')
 *   .select()
 *   .eq('church_id', churchId)
 *   .order('name');
 *
 * final families = (response as List)
 *   .map((json) => FamilyModel.fromJson(json))
 *   .toList();
 *
 * // 5. STREAM EN TEMPS RÉEL
 * supabase
 *   .from('families')
 *   .stream(primaryKey: ['id'])
 *   .eq('church_id', churchId)
 *   .listen((data) {
 *     final families = data
 *       .map((json) => FamilyModel.fromJson(json))
 *       .toList();
 *     print('Familles mises à jour: ${families.length}');
 *   });
 */