class RoomReaction {
  final String emoji;
  final String sender;
  final String senderName;
  final int timestamp;

  RoomReaction({
    required this.emoji,
    required this.sender,
    this.senderName = '',
    required this.timestamp,
  });

  factory RoomReaction.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) {
      return RoomReaction(emoji: '', sender: '', senderName: '', timestamp: 0);
    }
    return RoomReaction(
      emoji: map['emoji'] as String? ?? '',
      sender: map['sender'] as String? ?? '',
      senderName: map['senderName'] as String? ?? '',
      timestamp: (map['timestamp'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'emoji': emoji,
      'sender': sender,
      'senderName': senderName,
      'timestamp': timestamp,
    };
  }
}
