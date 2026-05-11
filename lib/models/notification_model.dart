/*
 * FICHIER : lib/models/notification_model.dart
 *
 * Extrait du fichier member_dashboard.dart original
 * où il était défini en bas du fichier.
 */

class NotificationModel {
  final String   id;
  final String   title;
  final String   message;
  final NotificationType type;
  final String   senderId;
  final String?  receiverId;
  final String?  actorName;
  final bool     isRead;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;

  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    this.type = NotificationType.system,
    required this.senderId,
    this.receiverId,
    this.actorName,
    this.isRead = false,
    required this.createdAt,
    this.metadata,
  });

  bool get isSystemNotification  => type == NotificationType.system;
  bool get isAbsenceNotification => type == NotificationType.absence;
  bool get isCustomNotification  => type == NotificationType.custom;
  bool get isBroadcast           => receiverId == null;

  factory NotificationModel.fromJson(Map<String, dynamic> data) {
    return NotificationModel(
      id:         data['id']?.toString()         ?? '',
      title:      data['title']?.toString()      ?? '',
      message:    data['message']?.toString()    ?? '',
      type:       _parseType(data['type']?.toString()),
      senderId:   data['sender_id']?.toString()  ?? '',
      receiverId: data['receiver_id']?.toString(),
      actorName:  data['actor_name']?.toString(),
      isRead:     data['is_read']                ?? false,
      createdAt:  data['created_at'] != null
          ? DateTime.parse(data['created_at'] as String)
          : DateTime.now(),
      metadata: data['metadata'] != null
          ? Map<String, dynamic>.from(data['metadata'])
          : null,
    );
  }

  // Alias pour compatibilité avec l'ancien code
  factory NotificationModel.fromSupabase(Map<String, dynamic> data) =>
      NotificationModel.fromJson(data);

  Map<String, dynamic> toJson() => {
    'id':          id,
    'title':       title,
    'message':     message,
    'type':        type.name,
    'sender_id':   senderId,
    'receiver_id': receiverId,
    'actor_name':  actorName,
    'is_read':     isRead,
    'created_at':  createdAt.toIso8601String(),
    'metadata':    metadata,
  };

  NotificationModel copyWith({
    String?        title,
    String?        message,
    NotificationType? type,
    String?        actorName,
    bool?          isRead,
    Map<String, dynamic>? metadata,
  }) => NotificationModel(
    id:         id,
    title:      title    ?? this.title,
    message:    message  ?? this.message,
    type:       type     ?? this.type,
    senderId:   senderId,
    receiverId: receiverId,
    actorName:  actorName ?? this.actorName,
    isRead:     isRead   ?? this.isRead,
    createdAt:  createdAt,
    metadata:   metadata ?? this.metadata,
  );

  NotificationModel markAsRead()   => copyWith(isRead: true);
  NotificationModel markAsUnread() => copyWith(isRead: false);

  static NotificationType _parseType(String? s) {
    switch (s?.toLowerCase()) {
      case 'absence': return NotificationType.absence;
      case 'custom':  return NotificationType.custom;
      default:        return NotificationType.system;
    }
  }

  @override
  String toString() =>
      'NotificationModel(id: $id, title: $title, type: ${type.name}, isRead: $isRead)';

  @override
  bool operator ==(Object other) =>
      other is NotificationModel && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

enum NotificationType {
  /// Notification générée par le serveur ou un automatisme (ex: code membre).
  system,

  /// Rapport d'appel : envoyée à l'admin après que le responsable a fait l'appel.
  absence,

  /// Message libre envoyé manuellement par l'admin à un membre / une famille.
  custom,
}