/*
 * FICHIER : lib/services/push_notifications_service.dart
 *
 * Service centralisé pour les notifications push (FCM) + affichage local.
 *
 *  • init()                         → à appeler dans main() après Firebase.initializeApp
 *  • registerTokenForUser(userId)   → à appeler après login : enregistre le token FCM
 *                                     du device dans la table Supabase `device_tokens`
 *  • unregisterTokenForUser(userId) → à appeler au logout (best-effort)
 *
 * Architecture push :
 *   Admin envoie notif → notifications_screen insère dans `notifications` (DB)
 *                     → puis appelle l'Edge Function `send-push`
 *                     → Edge Function récupère tokens FCM des destinataires
 *                     → appelle l'API FCM HTTP v1
 *                     → device reçoit, on affiche via flutter_local_notifications
 */

import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Handler appelé quand un message arrive et que l'app est en background OU killed.
/// DOIT être une fonction TOP-LEVEL (pas une méthode).
@pragma('vm:entry-point')
Future<void> _backgroundHandler(RemoteMessage message) async {
  // Pas grand-chose à faire — Android affiche automatiquement la notif
  // depuis le payload `notification:{...}` envoyé par notre Edge Function.
  // ignore: avoid_print
  print('🔔 [BG] message reçu: ${message.messageId}');
}

class PushNotificationsService {
  PushNotificationsService._();

  static final FirebaseMessaging _fm = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'moneglise_default',
    'Notifications MonÉglise',
    description: 'Notifications de l\'application MonÉglise',
    importance: Importance.high,
  );

  static bool _initialized = false;

  /// Init unique — à appeler dans main() APRÈS Firebase.initializeApp.
  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // Permissions (iOS + Android 13+)
    if (!kIsWeb) {
      await _fm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    // Foreground display (iOS)
    if (!kIsWeb && Platform.isIOS) {
      await _fm.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    // Canal Android + plugin local
    if (!kIsWeb) {
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings();
      await _local.initialize(const InitializationSettings(
        android: androidInit,
        iOS: iosInit,
      ));
      await _local
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);
    }

    // Handler background
    FirebaseMessaging.onBackgroundMessage(_backgroundHandler);

    // Handler foreground → on affiche nous-mêmes via flutter_local_notifications
    FirebaseMessaging.onMessage.listen((msg) {
      final notif = msg.notification;
      if (notif == null || kIsWeb) return;
      _local.show(
        notif.hashCode,
        notif.title,
        notif.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            icon: '@mipmap/ic_launcher',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
      );
    });

    // Refresh token (peut changer au cours du temps)
    _fm.onTokenRefresh.listen((token) async {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId != null) {
        await _upsertToken(userId, token);
      }
    });
  }

  /// Enregistre le token FCM du device pour ce user.
  /// À appeler après chaque login (ou au reload de l'app si user déjà connecté).
  static Future<void> registerTokenForUser(String userId) async {
    if (userId.isEmpty) return;
    try {
      // Sur iOS, attendre que l'APNs soit dispo (sinon getToken renvoie null)
      if (!kIsWeb && Platform.isIOS) {
        await _fm.getAPNSToken();
      }
      final token = await _fm.getToken(
        // Pour Web, fournir la vapidKey de Firebase Console > Cloud Messaging > Web Push certificates
        vapidKey: null,
      );
      if (token == null) return;
      await _upsertToken(userId, token);
    } catch (e) {
      // ignore: avoid_print
      print('❌ registerTokenForUser: $e');
    }
  }

  /// Supprime le token courant lors d'un logout (best-effort).
  static Future<void> unregisterTokenForUser(String userId) async {
    if (userId.isEmpty) return;
    try {
      final token = await _fm.getToken();
      if (token == null) return;
      await Supabase.instance.client
          .from('device_tokens')
          .delete()
          .eq('user_id', userId)
          .eq('token', token);
    } catch (_) {}
  }

  static Future<void> _upsertToken(String userId, String token) async {
    final supabase = Supabase.instance.client;
    final platform = kIsWeb
        ? 'web'
        : Platform.isIOS
            ? 'ios'
            : Platform.isAndroid
                ? 'android'
                : 'other';
    await supabase.from('device_tokens').upsert(
      {
        'user_id': userId,
        'token': token,
        'platform': platform,
        'updated_at': DateTime.now().toIso8601String(),
      },
      onConflict: 'token',
    );
  }
}
