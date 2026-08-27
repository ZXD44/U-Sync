import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/room_state.dart';
import '../models/member_presence.dart';
import '../models/room_reaction.dart';
import '../models/chat_message.dart';
import '../models/room_info.dart';
import '../models/queue_item.dart';
import 'device_service.dart';

class FirebaseSyncService {
  static const String _dbUrl =
      'https://usync-e85a4-default-rtdb.firebaseio.com';

  /// Countdown duration before an empty room gets deleted (seconds)
  static const int roomDeletionCountdownSeconds = 30;

  final FirebaseDatabase _db = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: _dbUrl,
  );

  String? _currentRoomId;
  int _serverTimeOffset = 0;
  StreamSubscription? _offsetSubscription;
  StreamSubscription? _connectedSubscription;
  StreamSubscription? _stateSubscription;
  StreamSubscription? _membersSubscription;
  StreamSubscription? _reactionSubscription;
  StreamSubscription? _messagesSubscription;
  StreamSubscription? _queueSubscription;

  /// Local countdown timers for rooms pending deletion (roomId -> Timer)
  static final Map<String, Timer> _pendingDeletionTimers = {};

  final StreamController<RoomState> _stateController =
      StreamController<RoomState>.broadcast();
  final StreamController<Map<String, MemberPresence>> _membersController =
      StreamController<Map<String, MemberPresence>>.broadcast();
  final StreamController<RoomReaction> _reactionController =
      StreamController<RoomReaction>.broadcast();
  final StreamController<List<ChatMessage>> _messagesController =
      StreamController<List<ChatMessage>>.broadcast();
  final StreamController<List<QueueItem>> _queueController =
      StreamController<List<QueueItem>>.broadcast();

  Stream<RoomState> get stateStream => _stateController.stream;
  Stream<Map<String, MemberPresence>> get membersStream =>
      _membersController.stream;
  Stream<RoomReaction> get reactionStream => _reactionController.stream;
  Stream<List<ChatMessage>> get messagesStream => _messagesController.stream;
  Stream<List<QueueItem>> get queueStream => _queueController.stream;

  String? get currentRoomId => _currentRoomId;
  String get myDeviceId => DeviceService.getDeviceId();
  String get myNickname => DeviceService.getNickname();

  /// Track the user's last active room for rejoin prevention
  static String? _lastActiveRoomId;
  static String? get lastActiveRoomId => _lastActiveRoomId;
  static void clearLastActiveRoom() {
    _lastActiveRoomId = null;
  }

  FirebaseSyncService() {
    _initServerClockSync();
  }

  /// Listen to Firebase server time offset
  void _initServerClockSync() {
    final offsetRef = _db.ref('.info/serverTimeOffset');
    _offsetSubscription = offsetRef.onValue.listen((event) {
      final offset = event.snapshot.value as num?;
      _serverTimeOffset = offset?.toInt() ?? 0;
    });
  }

  /// Estimated current timestamp of Firebase server in milliseconds
  int get currentServerTimestamp {
    return DateTime.now().millisecondsSinceEpoch + _serverTimeOffset;
  }

  /// Check if a room still exists and has the deletion countdown field
  Future<bool> isRoomAlive(String roomId) async {
    try {
      final snap = await _db.ref('rooms/$roomId/state').get();
      return snap.exists;
    } catch (_) {
      return false;
    }
  }

  /// Real-time stream to observe whether a specific room exists
  Stream<DatabaseEvent> watchRoomExistence(String roomId) {
    return _db.ref('rooms/$roomId').onValue;
  }

  /// Delete a room immediately and clean all timers/caches
  Future<void> deleteRoomImmediately(String roomId) async {
    try {
      _cancelDeletionCountdown(roomId);
      if (_lastActiveRoomId == roomId) {
        _lastActiveRoomId = null;
      }
      await _db.ref('rooms/$roomId').remove();
    } catch (_) {}
  }

  /// Get remaining seconds before a room is deleted (0 = safe / no countdown)
  Future<int> getRoomCountdownRemaining(String roomId) async {
    try {
      final snap = await _db.ref('rooms/$roomId/state/deleteAt').get();
      if (!snap.exists || snap.value == null) return 0;
      final deleteAt = (snap.value as num).toInt();
      final now = currentServerTimestamp;
      final remaining = ((deleteAt - now) / 1000).ceil();
      return remaining > 0 ? remaining : 0;
    } catch (_) {
      return 0;
    }
  }

  /// Stream of all active public rooms (Filters out empty/ghost rooms with auto-purge)
  Stream<List<RoomInfo>> getPublicRooms() {
    return _db.ref('rooms').onValue.map((event) {
      final List<RoomInfo> rooms = [];
      final now = currentServerTimestamp;
      if (event.snapshot.exists && event.snapshot.value is Map) {
        final data = event.snapshot.value as Map;
        data.forEach((roomId, roomData) {
          if (roomData is Map) {
            final info = RoomInfo.fromFirebase(roomId.toString(), roomData);
            if (info.memberCount > 0) {
              rooms.add(info);
              // Cancel deletion countdown if someone rejoined
              _cancelDeletionCountdown(roomId.toString());
            } else {
              // If countdown has already expired on server, purge immediately
              if (info.deleteAt > 0 && info.deleteAt <= now) {
                _executeRoomDeletion(roomId.toString());
              } else {
                // Start countdown if not already started
                _startDeletionCountdown(roomId.toString());
                if (_pendingDeletionTimers.containsKey(roomId.toString())) {
                  rooms.add(info);
                }
              }
            }
          }
        });
      }
      rooms.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return rooms;
    });
  }

  /// Start a 50-second countdown before deleting an empty room
  void _startDeletionCountdown(String roomId) {
    // Don't start if already pending
    if (_pendingDeletionTimers.containsKey(roomId)) return;

    // Write the deleteAt timestamp to Firebase so all clients know
    final deleteAt = currentServerTimestamp +
        (roomDeletionCountdownSeconds * 1000);
    _db.ref('rooms/$roomId/state/deleteAt').set(deleteAt).catchError((_) {});

    _pendingDeletionTimers[roomId] = Timer(
      const Duration(seconds: roomDeletionCountdownSeconds),
      () async {
        // Re-check if room is still empty before deleting
        await _executeRoomDeletion(roomId);
        _pendingDeletionTimers.remove(roomId);
      },
    );
  }

  /// Cancel the deletion countdown (someone rejoined)
  void _cancelDeletionCountdown(String roomId) {
    final timer = _pendingDeletionTimers.remove(roomId);
    if (timer != null) {
      timer.cancel();
      // Remove the deleteAt field from Firebase
      _db.ref('rooms/$roomId/state/deleteAt').remove().catchError((_) {});
    }
  }

  /// Execute room deletion after verifying it's still empty
  Future<void> _executeRoomDeletion(String roomId) async {
    try {
      final roomRef = _db.ref('rooms/$roomId');
      final membersSnap = await roomRef.child('members').get();
      if (membersSnap.exists && membersSnap.value is Map) {
        final membersMap = membersSnap.value as Map;
        bool anyOnline = false;
        membersMap.forEach((k, v) {
          if (v is Map && v['online'] == true) {
            anyOnline = true;
          }
        });
        if (!anyOnline) {
          await roomRef.remove();
          if (_lastActiveRoomId == roomId) {
            _lastActiveRoomId = null;
          }
        }
      } else {
        await roomRef.remove();
        if (_lastActiveRoomId == roomId) {
          _lastActiveRoomId = null;
        }
      }
    } catch (_) {}
  }

  /// Join a room & setup presence + streams
  Future<void> joinRoom(
    String roomId, {
    String roomName = '',
    bool isLocked = false,
    String password = '',
  }) async {
    _currentRoomId = roomId;
    _lastActiveRoomId = roomId;

    // Cancel any pending deletion for this room (user rejoined)
    _cancelDeletionCountdown(roomId);

    final roomRef = _db.ref('rooms/$roomId');
    final memberRef = roomRef.child('members/$myDeviceId');
    final stateRef = roomRef.child('state');

    // 1. Initial State Check / Room Creation
    final stateSnapshot = await stateRef.get();
    if (!stateSnapshot.exists) {
      // Brand new room: this device is both owner and host
      await stateRef.set({
        'videoId': '',
        'status': 'PAUSED',
        'currentTime': 0.0,
        'playbackRate': 1.0,
        'updatedBy': myDeviceId,
        'timestamp': ServerValue.timestamp,
        'roomName': roomName.isNotEmpty ? roomName : roomId,
        'hostId': myDeviceId,
        'ownerId': myDeviceId,
        'isLocked': isLocked,
        'password': password,
      });
    } else {
      // Room exists — remove deleteAt if pending deletion
      await stateRef.child('deleteAt').remove();

      // If I am the original owner, reclaim host immediately
      final stateMap = stateSnapshot.value as Map?;
      final ownerId = stateMap?['ownerId']?.toString() ?? '';
      if (ownerId == myDeviceId) {
        await stateRef.update({'hostId': myDeviceId});
      }
    }

    // 2. Set Up Member Presence with onDisconnect
    await memberRef.set({
      'nickname': DeviceService.getNickname(),
      'online': true,
      'lastSeen': ServerValue.timestamp,
    });
    await memberRef.onDisconnect().update({
      'online': false,
      'lastSeen': ServerValue.timestamp,
    });

    // 3. Listen to Connection State
    final connectedRef = _db.ref('.info/connected');
    _connectedSubscription = connectedRef.onValue.listen((event) {
      final connected = event.snapshot.value == true;
      if (connected) {
        memberRef.update({
          'nickname': DeviceService.getNickname(),
          'online': true,
          'lastSeen': ServerValue.timestamp,
        });
      }
    });

    // 4. Listen to Room State & Auto Host Transfer
    _stateSubscription = stateRef.onValue.listen((event) {
      if (event.snapshot.exists && event.snapshot.value is Map) {
        final stateMap = event.snapshot.value as Map;
        final roomState = RoomState.fromMap(stateMap);
        _stateController.add(roomState);
      }
    });

    // 5. Listen to Member Presence & Elect New Host if Needed
    _membersSubscription = roomRef.child('members').onValue.listen((event) {
      final Map<String, MemberPresence> members = {};
      String? firstOnlineMemberId;

      if (event.snapshot.exists && event.snapshot.value is Map) {
        final data = event.snapshot.value as Map;
        data.forEach((key, value) {
          if (value is Map) {
            final presence = MemberPresence.fromMap(key.toString(), value);
            members[key.toString()] = presence;
            if (presence.isOnline && firstOnlineMemberId == null) {
              firstOnlineMemberId = key.toString();
            }
          }
        });
      }
      _membersController.add(members);

      // Auto-migrate host if current host is offline
      _checkAndTransferHost(roomRef, members, firstOnlineMemberId);
    });

    // 6. Listen to Reactions
    _reactionSubscription =
        roomRef.child('reaction').onValue.listen((event) {
      if (event.snapshot.exists && event.snapshot.value is Map) {
        _reactionController
            .add(RoomReaction.fromMap(event.snapshot.value as Map));
      }
    });

    // 7. Listen to Realtime Chat Messages
    _messagesSubscription = roomRef
        .child('messages')
        .limitToLast(50)
        .onValue
        .listen((event) {
      final List<ChatMessage> messages = [];
      if (event.snapshot.exists && event.snapshot.value is Map) {
        final data = event.snapshot.value as Map;
        data.forEach((msgId, msgData) {
          if (msgData is Map) {
            messages.add(ChatMessage.fromMap(msgId.toString(), msgData));
          }
        });
        messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      }
      _messagesController.add(messages);
    });

    // 8. Listen to Video Playlist Queue
    _queueSubscription = roomRef.child('queue').onValue.listen((event) {
      final List<QueueItem> queue = [];
      if (event.snapshot.exists && event.snapshot.value is Map) {
        final data = event.snapshot.value as Map;
        data.forEach((qId, qData) {
          if (qData is Map) {
            queue.add(QueueItem.fromMap(qId.toString(), qData));
          }
        });
        queue.sort((a, b) => a.addedAt.compareTo(b.addedAt));
      }
      _queueController.add(queue);
    });
  }

  /// Auto transfer host: prioritize owner, then first online member
  Future<void> _checkAndTransferHost(
    DatabaseReference roomRef,
    Map<String, MemberPresence> members,
    String? firstOnlineMemberId,
  ) async {
    try {
      final stateSnap = await roomRef.child('state').get();
      if (stateSnap.exists && stateSnap.value is Map) {
        final stateMap = stateSnap.value as Map;
        final currentHostId = stateMap['hostId']?.toString() ?? '';
        final ownerId = stateMap['ownerId']?.toString() ?? '';
        final hostPresence = members[currentHostId];

        // Priority 1: If owner is online, always give host back to owner
        if (ownerId.isNotEmpty && currentHostId != ownerId) {
          final ownerPresence = members[ownerId];
          if (ownerPresence != null && ownerPresence.isOnline) {
            await roomRef.child('state').update({'hostId': ownerId});
            return;
          }
        }

        // Priority 2: If current host is offline, elect first online member
        if ((hostPresence == null || !hostPresence.isOnline) &&
            firstOnlineMemberId != null &&
            firstOnlineMemberId != currentHostId) {
          await roomRef.child('state').update({
            'hostId': firstOnlineMemberId,
          });
        }
      }
    } catch (_) {}
  }

  /// Update the room playback state
  Future<void> updateState({
    required String videoId,
    required String status,
    required double currentTime,
    double playbackRate = 1.0,
  }) async {
    if (_currentRoomId == null) return;

    final stateRef = _db.ref('rooms/$_currentRoomId/state');
    await stateRef.update({
      'videoId': videoId,
      'status': status,
      'currentTime': currentTime,
      'playbackRate': playbackRate,
      'updatedBy': myDeviceId,
      'timestamp': ServerValue.timestamp,
    });
  }

  /// Toggle room lock & password (Strictly Host only)
  Future<bool> toggleRoomLock({
    required bool isLocked,
    String password = '',
  }) async {
    if (_currentRoomId == null) return false;

    final stateRef = _db.ref('rooms/$_currentRoomId/state');
    try {
      final snap = await stateRef.get();
      if (snap.exists && snap.value is Map) {
        final currentHostId = (snap.value as Map)['hostId']?.toString() ?? '';
        // Strict guard: only the current host is allowed to change lock settings
        if (currentHostId != myDeviceId) {
          return false;
        }
      }

      await stateRef.update({
        'isLocked': isLocked,
        'password': isLocked ? password.trim() : '',
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Send a real-time chat message
  Future<void> sendMessage(String text) async {
    final cleanText = text.trim();
    if (_currentRoomId == null || cleanText.isEmpty) return;

    final messagesRef = _db.ref('rooms/$_currentRoomId/messages');
    final newMsgRef = messagesRef.push();
    await newMsgRef.set({
      'senderId': myDeviceId,
      'senderName': DeviceService.getNickname(),
      'text': cleanText,
      'timestamp': ServerValue.timestamp,
    });
  }

  /// Broadcast a floating reaction emoji to the room
  Future<void> sendReaction(String emoji) async {
    if (_currentRoomId == null) return;

    final reactionRef = _db.ref('rooms/$_currentRoomId/reaction');
    await reactionRef.set({
      'emoji': emoji,
      'sender': myDeviceId,
      'senderName': DeviceService.getNickname(),
      'timestamp': ServerValue.timestamp,
    });
  }

  /// 📑 Add Video to Playlist Queue
  Future<void> addToQueue({
    required String videoId,
    required String title,
  }) async {
    if (_currentRoomId == null) return;
    final queueRef = _db.ref('rooms/$_currentRoomId/queue');
    final newQ = queueRef.push();
    final item = QueueItem(
      id: newQ.key ?? DateTime.now().millisecondsSinceEpoch.toString(),
      videoId: videoId,
      title: title.isNotEmpty ? title : 'วิดีโอ YouTube ($videoId)',
      addedBy: DeviceService.getNickname(),
      addedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await newQ.set(item.toMap());
  }

  /// 📑 Remove Video from Playlist Queue
  Future<void> removeFromQueue(String queueItemId) async {
    if (_currentRoomId == null) return;
    await _db.ref('rooms/$_currentRoomId/queue/$queueItemId').remove();
  }

  /// Fetch the latest snapshot of the room state for instant resync
  Future<RoomState?> fetchLatestState() async {
    if (_currentRoomId == null) return null;
    final snapshot = await _db.ref('rooms/$_currentRoomId/state').get();
    if (snapshot.exists && snapshot.value is Map) {
      return RoomState.fromMap(snapshot.value as Map);
    }
    return null;
  }

  /// Calculate latency-compensated target playback time
  double calculateCompensatedTime(RoomState state) {
    if (state.status != 'PLAYING') {
      return state.currentTime;
    }

    if (state.timestamp <= 0) {
      return state.currentTime;
    }

    final int now = currentServerTimestamp;
    final double elapsedSeconds = (now - state.timestamp) / 1000.0;

    if (elapsedSeconds > 0 && elapsedSeconds < 3600) {
      return state.currentTime + (elapsedSeconds * state.playbackRate);
    }

    return state.currentTime;
  }

  /// Leave the current room, mark offline and start deletion countdown
  Future<void> leaveRoom() async {
    final roomId = _currentRoomId;
    if (roomId != null) {
      try {
        final memberRef = _db.ref('rooms/$roomId/members/$myDeviceId');
        await memberRef.update({
          'online': false,
          'lastSeen': ServerValue.timestamp,
        });

        // Start 50-second countdown instead of immediate deletion
        _startDeletionCountdown(roomId);
      } catch (_) {}
    }

    await _connectedSubscription?.cancel();
    await _stateSubscription?.cancel();
    await _membersSubscription?.cancel();
    await _reactionSubscription?.cancel();
    await _messagesSubscription?.cancel();
    await _queueSubscription?.cancel();

    _connectedSubscription = null;
    _stateSubscription = null;
    _membersSubscription = null;
    _reactionSubscription = null;
    _messagesSubscription = null;
    _queueSubscription = null;
    _currentRoomId = null;
  }

  void dispose() {
    leaveRoom();
    _offsetSubscription?.cancel();
    _stateController.close();
    _membersController.close();
    _reactionController.close();
    _messagesController.close();
    _queueController.close();
  }
}
