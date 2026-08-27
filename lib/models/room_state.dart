class RoomState {
  final String videoId;
  final String status; // 'PLAYING', 'PAUSED', 'BUFFERING'
  final double currentTime;
  final double playbackRate;
  final String updatedBy;
  final int timestamp;
  final String roomName;
  final String hostId;
  final String ownerId; // Original room creator (never changes)
  final bool isLocked;
  final String password;

  RoomState({
    required this.videoId,
    required this.status,
    required this.currentTime,
    this.playbackRate = 1.0,
    required this.updatedBy,
    required this.timestamp,
    this.roomName = '',
    this.hostId = '',
    this.ownerId = '',
    this.isLocked = false,
    this.password = '',
  });

  bool get isPlaying => status == 'PLAYING';
  bool get isPaused => status == 'PAUSED';
  bool get isBuffering => status == 'BUFFERING';

  factory RoomState.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) {
      return RoomState.initial();
    }

    return RoomState(
      videoId: map['videoId'] as String? ?? '',
      status: map['status'] as String? ?? 'PAUSED',
      currentTime: (map['currentTime'] as num?)?.toDouble() ?? 0.0,
      playbackRate: (map['playbackRate'] as num?)?.toDouble() ?? 1.0,
      updatedBy: map['updatedBy'] as String? ?? '',
      timestamp: (map['timestamp'] as num?)?.toInt() ?? 0,
      roomName: map['roomName'] as String? ?? '',
      hostId: map['hostId'] as String? ?? '',
      ownerId: map['ownerId'] as String? ?? map['hostId'] as String? ?? '',
      isLocked: map['isLocked'] as bool? ?? false,
      password: map['password'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'videoId': videoId,
      'status': status,
      'currentTime': currentTime,
      'playbackRate': playbackRate,
      'updatedBy': updatedBy,
      'timestamp': timestamp,
      'roomName': roomName,
      'hostId': hostId,
      'ownerId': ownerId,
      'isLocked': isLocked,
      'password': password,
    };
  }

  factory RoomState.initial() {
    return RoomState(
      videoId: '',
      status: 'PAUSED',
      currentTime: 0.0,
      playbackRate: 1.0,
      updatedBy: '',
      timestamp: 0,
      roomName: '',
      hostId: '',
      ownerId: '',
      isLocked: false,
      password: '',
    );
  }

  RoomState copyWith({
    String? videoId,
    String? status,
    double? currentTime,
    double? playbackRate,
    String? updatedBy,
    int? timestamp,
    String? roomName,
    String? hostId,
    String? ownerId,
    bool? isLocked,
    String? password,
  }) {
    return RoomState(
      videoId: videoId ?? this.videoId,
      status: status ?? this.status,
      currentTime: currentTime ?? this.currentTime,
      playbackRate: playbackRate ?? this.playbackRate,
      updatedBy: updatedBy ?? this.updatedBy,
      timestamp: timestamp ?? this.timestamp,
      roomName: roomName ?? this.roomName,
      hostId: hostId ?? this.hostId,
      ownerId: ownerId ?? this.ownerId,
      isLocked: isLocked ?? this.isLocked,
      password: password ?? this.password,
    );
  }
}
