class TripChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String body;
  final DateTime createdAt;

  const TripChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.body,
    required this.createdAt,
  });

  factory TripChatMessage.fromJson(Map<String, dynamic> json) {
    return TripChatMessage(
      id: (json['id'] ?? '').toString(),
      senderId: (json['sender'] ?? json['sender_id'] ?? '').toString(),
      senderName: (json['sender_name'] ?? 'Unknown').toString(),
      body: (json['body'] ?? '').toString(),
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
              DateTime.now(),
    );
  }
}
