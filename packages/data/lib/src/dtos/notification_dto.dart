import 'package:banan_domain/banan_domain.dart';

class NotificationDto {
  const NotificationDto({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.data,
    this.readAt,
  });

  factory NotificationDto.fromJson(Map<String, dynamic> json) {
    return NotificationDto(
      id: json['id'] as String,
      type: json['type'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      data: json['data'] is Map
          ? Map<String, dynamic>.from(json['data'] as Map)
          : null,
      readAt: json['readAt'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  final String id;
  final String type;
  final String title;
  final String body;
  final Map<String, dynamic>? data;
  final String? readAt;
  final DateTime createdAt;

  NotificationEntry toDomain() => NotificationEntry(
        id: id,
        type: type,
        title: title,
        body: body,
        data: data,
        readAt: readAt == null ? null : DateTime.tryParse(readAt!),
        createdAt: createdAt,
      );
}
