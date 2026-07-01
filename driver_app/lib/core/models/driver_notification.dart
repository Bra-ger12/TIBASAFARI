import 'package:flutter/material.dart';

enum DriverNotificationType {
  tripAssigned,
  tripCompleted,
  earnings,
  tripCancelled,
}

class DriverNotification {
  final String id;
  final String title;
  final String message;
  final String relativeTime;
  final bool isRead;
  final DriverNotificationType type;

  const DriverNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.relativeTime,
    required this.isRead,
    required this.type,
  });

  DriverNotification copyWith({bool? isRead}) {
    return DriverNotification(
      id: id,
      title: title,
      message: message,
      relativeTime: relativeTime,
      isRead: isRead ?? this.isRead,
      type: type,
    );
  }

  factory DriverNotification.fromJson(Map<String, dynamic> json) {
    return DriverNotification(
      id: json['id'] as String,
      title: json['title'] as String,
      message: json['message'] as String,
      relativeTime: json['relative_time'] as String,
      isRead: json['is_read'] as bool? ?? false,
      type: DriverNotificationType.values.firstWhere(
        (type) => type.name == json['type'],
        orElse: () => DriverNotificationType.tripAssigned,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'message': message,
    'relative_time': relativeTime,
    'is_read': isRead,
    'type': type.name,
  };
}

extension DriverNotificationTypeX on DriverNotificationType {
  IconData get icon {
    switch (this) {
      case DriverNotificationType.tripAssigned:
        return Icons.directions_car_rounded;
      case DriverNotificationType.tripCompleted:
        return Icons.check_circle_rounded;
      case DriverNotificationType.earnings:
        return Icons.account_balance_wallet_rounded;
      case DriverNotificationType.tripCancelled:
        return Icons.cancel_rounded;
    }
  }
}
