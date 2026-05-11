/*
 * FICHIER : lib/services/database_service.dart
 *
 * DESCRIPTION : Service pour gérer toutes les interactions avec Supabase
 *              (familles, membres, notifications, absences)
 */

import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase_config.dart';

class DatabaseService {
  final SupabaseClient _client = SupabaseConfig.client;

  // ========================= FAMILLES =========================

  Future<List<Map<String, dynamic>>> getFamilies(String adminId) async {
    try {
      final response = await _client
          .from('families')
          .select()
          .eq('church_id', adminId)
          .order('created_at', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Erreur getFamilies: $e');
      return [];
    }
  }

  /// Crée une famille.
  /// [churchId] : ID de l'église (FK vers churches.id)
  /// [responsibleId] : ID de l'utilisateur responsable (FK vers users.id)
  ///
  /// L'API legacy à 2 args (name + adminId) est conservée pour rétro-compat,
  /// auquel cas adminId sert de fallback à la fois pour churchId et responsibleId.
  Future<String?> createFamily(
    String name,
    String churchId, {
    String? responsibleId,
  }) async {
    try {
      final response = await _client
          .from('families')
          .insert({
            'name': name,
            'church_id': churchId,
            'responsible_id': responsibleId ?? churchId,
            'member_ids': <String>[],
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      return response['id'] as String?;
    } catch (e) {
      print('Erreur createFamily: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getFamily(String familyId) async {
    try {
      final response = await _client
          .from('families')
          .select()
          .eq('id', familyId)
          .single();

      return Map<String, dynamic>.from(response);
    } catch (e) {
      print('Erreur getFamily: $e');
      return null;
    }
  }

  Future<void> updateFamily(String familyId, Map<String, dynamic> updates) async {
    try {
      updates['updated_at'] = DateTime.now().toIso8601String();
      await _client.from('families').update(updates).eq('id', familyId);
    } catch (e) {
      print('Erreur updateFamily: $e');
    }
  }

  Future<void> deleteFamily(String familyId) async {
    try {
      await _client.from('families').delete().eq('id', familyId);
    } catch (e) {
      print('Erreur deleteFamily: $e');
    }
  }

  // ========================= MEMBRES =========================

  Future<Map<String, dynamic>?> getMember(String userId) async {
    try {
      final response =
      await _client.from('users').select().eq('id', userId).single();
      return Map<String, dynamic>.from(response);
    } catch (e) {
      print('Erreur getMember: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getMembers(String adminId) async {
    try {
      final response = await _client
          .from('users')
          .select()
          .eq('admin_code', adminId);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Erreur getMembers: $e');
      return [];
    }
  }

  Future<void> updateMember(String userId, Map<String, dynamic> updates) async {
    try {
      updates['updated_at'] = DateTime.now().toIso8601String();
      await _client.from('users').update(updates).eq('id', userId);
    } catch (e) {
      print('Erreur updateMember: $e');
    }
  }

  // ── Table de jointure family_members (source de vérité unique) ──

  Future<void> addMemberToFamily(String familyId, String userId) async {
    try {
      await _client.from('family_members').upsert({
        'family_id': familyId,
        'user_id':   userId,
      }, onConflict: 'family_id,user_id');
    } catch (e) {
      print('Erreur addMemberToFamily: $e');
    }
  }

  Future<void> removeMemberFromFamily(String familyId, String userId) async {
    try {
      await _client
          .from('family_members')
          .delete()
          .eq('family_id', familyId)
          .eq('user_id', userId);
    } catch (e) {
      print('Erreur removeMemberFromFamily: $e');
    }
  }

  /// Liste des IDs des familles auxquelles appartient un user.
  Future<List<String>> getFamilyIdsForUser(String userId) async {
    try {
      final res = await _client
          .from('family_members')
          .select('family_id')
          .eq('user_id', userId);
      return (res as List)
          .map((e) => (e as Map)['family_id'] as String)
          .toList();
    } catch (e) {
      print('Erreur getFamilyIdsForUser: $e');
      return [];
    }
  }

  /// Liste des IDs des membres d'une famille.
  Future<List<String>> getMemberIdsForFamily(String familyId) async {
    try {
      final res = await _client
          .from('family_members')
          .select('user_id')
          .eq('family_id', familyId);
      return (res as List)
          .map((e) => (e as Map)['user_id'] as String)
          .toList();
    } catch (e) {
      print('Erreur getMemberIdsForFamily: $e');
      return [];
    }
  }

  // ========================= STATISTIQUES =========================

  Future<int> countMembers(String adminId) async {
    try {
      final res = await _client
          .from('users')
          .select()
          .eq('admin_code', adminId)
          .count(); // ← méthode count() 🙌
      return res.count ?? 0;
    } catch (e) {
      print('Erreur countMembers: $e');
      return 0;
    }
  }

  Future<int> countFamilies(String adminId) async {
    try {
      final res = await _client
          .from('families')
          .select()
          .eq('church_id', adminId)
          .count(); // ← méthode count()
      return res.count ?? 0;
    } catch (e) {
      print('Erreur countFamilies: $e');
      return 0;
    }
  }

  Future<int> countUnreadNotifications(String adminId) async {
    try {
      final res = await _client
          .from('notifications')
          .select()
          .eq('receiver_id', adminId)
          .eq('is_read', false)
          .count();
      return res.count ?? 0;
    } catch (e) {
      print('Erreur countUnreadNotifications: $e');
      return 0;
    }
  }

  // ========================= ABSENCES =========================

  Future<List<Map<String, dynamic>>> getAbsences({DateTime? startDate}) async {
    try {
      var query = _client.from('absences').select();
      if (startDate != null) {
        query = query.gte('date', startDate.toIso8601String());
      }
      final response = await query;
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Erreur getAbsences: $e');
      return [];
    }
  }
}
