class MemberPresence {
  final String deviceId;
  final String nickname;
  final bool isOnline;
  final int lastSeen;

  MemberPresence({
    required this.deviceId,
    required this.nickname,
    required this.isOnline,
    required this.lastSeen,
  });

  factory MemberPresence.fromMap(String deviceId, Map<dynamic, dynamic>? map) {
    if (map == null) {
      return MemberPresence(
        deviceId: deviceId,
        nickname: 'เพื่อน',
        isOnline: false,
        lastSeen: 0,
      );
    }
    return MemberPresence(
      deviceId: deviceId,
      nickname: map['nickname'] as String? ?? 'เพื่อน',
      isOnline: map['online'] as bool? ?? false,
      lastSeen: (map['lastSeen'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nickname': nickname,
      'online': isOnline,
      'lastSeen': lastSeen,
    };
  }
}
