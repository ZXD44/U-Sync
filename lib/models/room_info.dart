class RoomInfo {
  final String roomId;
  final String roomName;
  final String hostId;
  final bool isLocked;
  final String password;
  final String videoId;
  final String status;
  final int memberCount;
  final int updatedAt;
  final int deleteAt; // 0 = no countdown, >0 = timestamp when room will be deleted

  RoomInfo({
    required this.roomId,
    required this.roomName,
    required this.hostId,
    required this.isLocked,
    this.password = '',
    this.videoId = '',
    this.status = 'PAUSED',
    this.memberCount = 1,
    this.updatedAt = 0,
    this.deleteAt = 0,
  });

  factory RoomInfo.fromFirebase(String roomId, Map<dynamic, dynamic>? map) {
    if (map == null) {
      return RoomInfo(
        roomId: roomId,
        roomName: roomId,
        hostId: '',
        isLocked: false,
      );
    }

    final state = map['state'] as Map?;
    final members = map['members'] as Map?;

    int onlineMembers = 0;
    if (members != null) {
      members.forEach((k, v) {
        if (v is Map && v['online'] == true) {
          onlineMembers++;
        }
      });
    }

    final String name = (state?['roomName'] as String?)?.isNotEmpty == true
        ? state!['roomName'] as String
        : roomId;

    return RoomInfo(
      roomId: roomId,
      roomName: name,
      hostId: state?['hostId'] as String? ?? '',
      isLocked: state?['isLocked'] as bool? ?? false,
      password: state?['password'] as String? ?? '',
      videoId: state?['videoId'] as String? ?? '',
      status: state?['status'] as String? ?? 'PAUSED',
      memberCount: onlineMembers,
      updatedAt: (state?['timestamp'] as num?)?.toInt() ?? 0,
      deleteAt: (state?['deleteAt'] as num?)?.toInt() ?? 0,
    );
  }
}
