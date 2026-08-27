import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../theme/app_theme.dart';
import '../models/room_state.dart';
import '../models/member_presence.dart';
import '../models/chat_message.dart';
import '../models/queue_item.dart';
import '../services/firebase_sync_service.dart';
import '../services/url_helper.dart';
import '../services/device_service.dart';
import '../services/stats_service.dart';
import '../services/favorites_service.dart';
import '../services/pip_service.dart';
import '../widgets/floating_reactions.dart';
import '../widgets/youtube_search_modal.dart';
import '../widgets/room_invite_modal.dart';

class WatchPartyScreen extends StatefulWidget {
  final String roomId;
  final String roomName;
  final bool initialLocked;
  final String password;

  const WatchPartyScreen({
    super.key,
    required this.roomId,
    this.roomName = '',
    this.initialLocked = false,
    this.password = '',
  });

  @override
  State<WatchPartyScreen> createState() => _WatchPartyScreenState();
}

class _WatchPartyScreenState extends State<WatchPartyScreen> {
  late FirebaseSyncService _syncService;

  YoutubePlayerController? _playerController;
  String _currentVideoId = '';
  bool _isPlayerReady = false;

  // Synchronization flags
  bool _isApplyingRemoteUpdate = false;
  Timer? _debounceTimer;
  Timer? _watchStatsTimer; // Real watch time ticker
  Timer? _viewerSyncGuardTimer; // Periodic auto-sync guard for non-host viewers

  // UI state
  Map<String, MemberPresence> _members = {};
  List<ChatMessage> _chatMessages = [];
  List<QueueItem> _videoQueue = [];
  double _currentPlaybackRate = 1.0;
  RoomState? _latestRoomState;
  bool _isHost = false;
  bool _isFavorite = false;
  bool _isCaptionsEnabled = true;
  bool _hasPlayerError = false;

  final StreamController<String> _localReactionStreamController =
      StreamController<String>.broadcast();

  final TextEditingController _chatInputController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();

  int _selectedBottomTab = 0; // 0 = แชทสด, 1 = คิวคลิป, 2 = สมาชิก

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    PipService.setPartyActive(true);

    _isFavorite = FavoritesService.isFavorite(widget.roomId);
    _syncService = FirebaseSyncService();
    _initSync();
    _startWatchStatsTracker();
    _startViewerSyncGuard();

    // Record room joined in real stats
    StatsService.incrementRooms();
  }

  void _startWatchStatsTracker() {
    _watchStatsTimer?.cancel();
    _watchStatsTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_playerController != null &&
          _isPlayerReady &&
          _playerController!.value.isPlaying &&
          _currentVideoId.isNotEmpty) {
        StatsService.addWatchTime(1);
      }
    });
  }

  /// Auto-sync guard for non-hosts: keep viewers strictly aligned to host's time and status
  void _startViewerSyncGuard() {
    _viewerSyncGuardTimer?.cancel();
    _viewerSyncGuardTimer =
        Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!_isHost &&
          _playerController != null &&
          _isPlayerReady &&
          _latestRoomState != null &&
          _latestRoomState!.videoId.isNotEmpty &&
          !_isApplyingRemoteUpdate) {
        final playerVal = _playerController!.value;
        // Strict guard: Do NOT seek if player is buffering or in error state
        if (playerVal.playerState == PlayerState.buffering ||
            playerVal.hasError) {
          return;
        }

        final targetTime =
            _syncService.calculateCompensatedTime(_latestRoomState!);
        final localTime =
            playerVal.position.inMilliseconds / 1000.0;
        final drift = (targetTime - localTime).abs();

        // If drifted more than 1.5s, smoothly seek to host time
        if (drift > 1.5) {
          _isApplyingRemoteUpdate = true;
          _playerController!.seekTo(
            Duration(milliseconds: (targetTime * 1000).toInt()),
          );
          Future.delayed(const Duration(milliseconds: 500), () {
            _isApplyingRemoteUpdate = false;
          });
        }

        // Force match host playback status (only when ready and not buffering)
        if (_latestRoomState!.status == 'PLAYING' &&
            !playerVal.isPlaying &&
            playerVal.playerState != PlayerState.buffering) {
          _playerController!.play();
        } else if (_latestRoomState!.status == 'PAUSED' &&
            playerVal.isPlaying) {
          _playerController!.pause();
        }
      }
    });
  }

  void _initSync() async {
    await _syncService.joinRoom(
      widget.roomId,
      roomName: widget.roomName.isNotEmpty ? widget.roomName : widget.roomId,
      isLocked: widget.initialLocked,
      password: widget.password,
    );

    // 1. Listen to Room State from Firebase
    _syncService.stateStream.listen((remoteState) {
      if (mounted) {
        setState(() {
          _latestRoomState = remoteState;
          _isHost = remoteState.hostId == _syncService.myDeviceId;
        });
      }
      _handleRemoteState(remoteState);
    });

    // Immediate initial sync for new members joining an active room
    final initialState = await _syncService.fetchLatestState();
    if (initialState != null && initialState.videoId.isNotEmpty) {
      if (mounted) {
        setState(() {
          _latestRoomState = initialState;
          _isHost = initialState.hostId == _syncService.myDeviceId;
        });
      }
      _handleRemoteState(initialState);
    }

    // 2. Listen to Member Presence
    _syncService.membersStream.listen((members) {
      if (mounted) {
        setState(() {
          _members = members;
        });
      }
    });

    // 3. Listen to Reactions
    _syncService.reactionStream.listen((reaction) {
      if (reaction.emoji.isNotEmpty) {
        _localReactionStreamController.add(reaction.emoji);
        if (FavoritesService.soundEnabled) {
          SystemSound.play(SystemSoundType.click);
        }
      }
    });

    // 4. Listen to Realtime Chat Messages
    _syncService.messagesStream.listen((messages) {
      if (mounted) {
        setState(() {
          _chatMessages = messages;
        });
        _scrollChatToBottom();
        if (FavoritesService.soundEnabled && messages.isNotEmpty) {
          SystemSound.play(SystemSoundType.click);
        }
      }
    });

    // 5. Listen to Video Playlist Queue
    _syncService.queueStream.listen((queue) {
      if (mounted) {
        setState(() {
          _videoQueue = queue;
        });
      }
    });
  }

  void _scrollChatToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _setupPlayer(String videoId, {double initialTime = 0.0, bool autoPlay = true}) {
    if (_playerController != null) {
      _playerController!.dispose();
    }

    _currentVideoId = videoId;
    _isPlayerReady = false;
    _hasPlayerError = false;

    // Track in real stats
    StatsService.incrementVideos();
    StatsService.addHistory(videoId, 'วิดีโอ YouTube ($videoId)');

    _playerController = YoutubePlayerController(
      initialVideoId: videoId,
      flags: YoutubePlayerFlags(
        autoPlay: autoPlay,
        mute: false,
        disableDragSeek: !_isHost,
        loop: false,
        isLive: false,
        forceHD: false,
        enableCaption: _isCaptionsEnabled,
        captionLanguage: 'th',
        hideControls: !_isHost,
      ),
    )..addListener(_onPlayerStateChanged);

    if (mounted) {
      setState(() {});
    }
  }

  /// Toggle Thai subtitles / captions on or off
  void _toggleCaptions() {
    HapticFeedback.lightImpact();
    setState(() {
      _isCaptionsEnabled = !_isCaptionsEnabled;
    });
    if (_playerController != null && _currentVideoId.isNotEmpty) {
      final pos = _playerController!.value.position.inMilliseconds / 1000.0;
      final isPlaying = _playerController!.value.isPlaying;
      _setupPlayer(
        _currentVideoId,
        initialTime: pos,
        autoPlay: isPlaying,
      );
    }
    Fluttertoast.showToast(
      msg: _isCaptionsEnabled ? 'เปิดคำบรรยายไทย (ซับไทย)' : 'ปิดคำบรรยาย',
    );
  }

  /// Local YouTube Player Listener
  void _onPlayerStateChanged() {
    if (_playerController == null || !_isPlayerReady) return;

    if (_isApplyingRemoteUpdate) return;

    final playerValue = _playerController!.value;

    // Handle Auto-Play Next in Queue when current video ends (Host only triggers queue progression)
    if (playerValue.playerState == PlayerState.ended) {
      if (_isHost) {
        _playNextInQueue();
      }
      return;
    }

    // Handle Player Error (Age-restricted or embed blocked)
    if (playerValue.hasError) {
      if (!_hasPlayerError && mounted) {
        setState(() {
          _hasPlayerError = true;
        });
      }
      return;
    } else if (_hasPlayerError && mounted) {
      setState(() {
        _hasPlayerError = false;
      });
    }

    // NON-HOST VIEWERS: Do NOT broadcast state to Firebase! Strictly match host view.
    if (!_isHost) {
      if (_latestRoomState != null && _latestRoomState!.videoId.isNotEmpty) {
        if (_latestRoomState!.status == 'PLAYING' &&
            !playerValue.isPlaying &&
            playerValue.playerState != PlayerState.buffering) {
          _playerController!.play();
        } else if (_latestRoomState!.status == 'PAUSED' &&
            playerValue.isPlaying) {
          _playerController!.pause();
        }
      }
      return;
    }

    // HOST ONLY: Broadcast local playback state changes to Firebase
    String status = 'PAUSED';
    if (playerValue.isPlaying) {
      status = 'PLAYING';
    } else if (playerValue.playerState == PlayerState.buffering) {
      status = 'BUFFERING';
    }

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      final double currentTime = playerValue.position.inMilliseconds / 1000.0;
      _syncService.updateState(
        videoId: _currentVideoId,
        status: status,
        currentTime: currentTime,
        playbackRate: _currentPlaybackRate,
      );
    });
  }

  /// Auto-play Next Video from Queue
  void _playNextInQueue() {
    if (_videoQueue.isNotEmpty) {
      final nextItem = _videoQueue.first;
      _syncService.removeFromQueue(nextItem.id);
      _playVideoById(nextItem.videoId);
      Fluttertoast.showToast(msg: 'เล่นคลิปถัดไปในคิว: ${nextItem.title}');
    }
  }

  /// Process incoming remote state
  void _handleRemoteState(RoomState remoteState) async {
    if (remoteState.videoId.isEmpty) return;

    if (remoteState.videoId != _currentVideoId) {
      final double targetTime =
          _syncService.calculateCompensatedTime(remoteState);
      if (_playerController == null) {
        _setupPlayer(
          remoteState.videoId,
          initialTime: targetTime,
          autoPlay: remoteState.status == 'PLAYING',
        );
      } else {
        _isApplyingRemoteUpdate = true;
        _currentVideoId = remoteState.videoId;
        _playerController!.load(
          remoteState.videoId,
          startAt: targetTime.toInt(),
        );
        StatsService.incrementVideos();
        StatsService.addHistory(
          remoteState.videoId,
          'วิดีโอ YouTube (${remoteState.videoId})',
        );
        Future.delayed(const Duration(milliseconds: 600), () {
          _isApplyingRemoteUpdate = false;
        });
      }
      return;
    }

    if (remoteState.updatedBy == _syncService.myDeviceId) {
      return;
    }

    if (_playerController == null || !_isPlayerReady) return;

    _isApplyingRemoteUpdate = true;

    try {
      if ((remoteState.playbackRate - _currentPlaybackRate).abs() > 0.01) {
        _currentPlaybackRate = remoteState.playbackRate;
        _playerController!.setPlaybackRate(_currentPlaybackRate);
      }

      final double targetTime =
          _syncService.calculateCompensatedTime(remoteState);
      final double localTime =
          _playerController!.value.position.inMilliseconds / 1000.0;
      final double drift = (targetTime - localTime).abs();

      if (drift > 1.0) {
        _playerController!.seekTo(
          Duration(milliseconds: (targetTime * 1000).toInt()),
        );
      }

      if (remoteState.status == 'PLAYING' &&
          !_playerController!.value.isPlaying) {
        _playerController!.play();
      } else if (remoteState.status == 'PAUSED' &&
          _playerController!.value.isPlaying) {
        _playerController!.pause();
      }
    } finally {
      Future.delayed(const Duration(milliseconds: 500), () {
        _isApplyingRemoteUpdate = false;
      });
    }
  }

  /// Force Resync
  Future<void> _forceResync() async {
    HapticFeedback.lightImpact();
    Fluttertoast.showToast(msg: 'กำลังปรับเวลาให้ตรงกัน...');
    final latestState = await _syncService.fetchLatestState();

    if (latestState == null || latestState.videoId.isEmpty) {
      Fluttertoast.showToast(msg: 'ยังไม่มีวิดีโอที่กำลังเล่น');
      return;
    }

    if (_playerController == null) {
      _setupPlayer(latestState.videoId);
      return;
    }

    _isApplyingRemoteUpdate = true;

    if (latestState.videoId != _currentVideoId) {
      _currentVideoId = latestState.videoId;
      _playerController!.load(latestState.videoId);
    }

    final targetTime = _syncService.calculateCompensatedTime(latestState);
    _playerController!.seekTo(
      Duration(milliseconds: (targetTime * 1000).toInt()),
    );

    if (latestState.status == 'PLAYING') {
      _playerController!.play();
    } else {
      _playerController!.pause();
    }

    Future.delayed(const Duration(milliseconds: 600), () {
      _isApplyingRemoteUpdate = false;
    });

    Fluttertoast.showToast(
      msg: 'ปรับเวลาตรงกันแล้ว (${UrlHelper.formatDuration(targetTime)})',
      backgroundColor: AppColors.darkNav,
    );
  }

  /// Host Room Lock Settings (Strictly accessible to the host only)
  void _showRoomLockSettings() {
    if (!_isHost) {
      Fluttertoast.showToast(
        msg: 'เฉพาะหัวห้องเท่านั้นที่สามารถตั้งค่าล็อคห้องได้',
        backgroundColor: const Color(0xFFE63946),
      );
      return;
    }

    HapticFeedback.lightImpact();
    bool currentLock = _latestRoomState?.isLocked ?? false;
    final pwdController =
        TextEditingController(text: _latestRoomState?.password ?? '');

    showDialog(
      context: context,
      builder: (ctx) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: StatefulBuilder(
              builder: (context, setModalState) {
                return AlertDialog(
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24)),
                  title: const Row(
                    children: [
                      Icon(Icons.lock_outline_rounded,
                          color: AppColors.orangeDeep),
                      SizedBox(width: 8),
                      Text('ตั้งค่าล็อคห้องส่วนตัว',
                          style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('ล็อคห้อง (ต้องใช้รหัสผ่าน)',
                            style: TextStyle(
                                color: AppColors.textPrimary, fontSize: 14)),
                        value: currentLock,
                        activeThumbColor: AppColors.darkNav,
                        onChanged: (val) {
                          setModalState(() {
                            currentLock = val;
                          });
                        },
                      ),
                      if (currentLock) ...[
                        const SizedBox(height: 10),
                        TextField(
                          controller: pwdController,
                          style: const TextStyle(
                              color: AppColors.textPrimary, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'ตั้งรหัสผ่านห้อง (เช่น 1234)',
                            filled: true,
                            fillColor: AppColors.background,
                            prefixIcon: const Icon(Icons.key_rounded,
                                color: AppColors.orangeDeep),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('ยกเลิก',
                          style: TextStyle(color: AppColors.textSecondary)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.darkNav,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        final success = await _syncService.toggleRoomLock(
                          isLocked: currentLock,
                          password:
                              currentLock ? pwdController.text.trim() : '',
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (success) {
                          Fluttertoast.showToast(
                              msg: currentLock
                                  ? 'ล็อคห้องเรียบร้อย'
                                  : 'ปลดล็อคห้องแล้ว');
                        } else {
                          Fluttertoast.showToast(
                              msg: 'ไม่สามารถบันทึกได้ (เฉพาะหัวห้องเท่านั้น)',
                              backgroundColor: const Color(0xFFE63946));
                        }
                      },
                      child: const Text('บันทึก',
                          style: TextStyle(color: Colors.white)),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  /// Open YouTube Search & URL Picker Modal
  void _showChangeVideoDialog({bool isAddToQueue = false}) {
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      builder: (context) {
        return YouTubeSearchModal(
          initialAddToQueue: isAddToQueue,
          onSelectPlay: (videoId, title) {
            _playVideoById(videoId, title: title);
            Fluttertoast.showToast(msg: 'กำลังเล่น: $title');
          },
          onSelectQueue: (videoId, title) {
            _syncService.addToQueue(
              videoId: videoId,
              title: title,
            );
            Fluttertoast.showToast(msg: 'เพิ่ม "$title" ลงในคิวแล้ว');
          },
        );
      },
    );
  }

  void _playVideoById(String videoId, {String? title}) {
    _syncService.updateState(
      videoId: videoId,
      status: 'PLAYING',
      currentTime: 0.0,
      playbackRate: _currentPlaybackRate,
    );
    if (_playerController == null) {
      _setupPlayer(videoId);
    } else {
      _playerController!.load(videoId);
      StatsService.incrementVideos();
      StatsService.addHistory(
          videoId, title ?? 'วิดีโอ YouTube ($videoId)');
    }
  }

  void _sendReaction(String emoji) {
    HapticFeedback.lightImpact();
    _localReactionStreamController.add(emoji);
    _syncService.sendReaction(emoji);
    StatsService.incrementReactions();
  }

  void _sendChatMessage() {
    final text = _chatInputController.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.lightImpact();
    _syncService.sendMessage(text);
    _chatInputController.clear();
    StatsService.incrementMessages();
  }

  void _changePlaybackSpeed(double speed) {
    HapticFeedback.selectionClick();
    setState(() {
      _currentPlaybackRate = speed;
    });
    _playerController?.setPlaybackRate(speed);

    if (_playerController != null && _isPlayerReady) {
      final pos = _playerController!.value.position.inMilliseconds / 1000.0;
      final isPlaying = _playerController!.value.isPlaying;
      _syncService.updateState(
        videoId: _currentVideoId,
        status: isPlaying ? 'PLAYING' : 'PAUSED',
        currentTime: pos,
        playbackRate: speed,
      );
    }
  }

  void _shareRoomInvite() {
    HapticFeedback.mediumImpact();
    RoomInviteModal.show(
      context,
      roomId: widget.roomId,
      roomName: widget.roomName.isNotEmpty ? widget.roomName : widget.roomId,
      isLocked: _latestRoomState?.isLocked ?? widget.initialLocked,
      password: _latestRoomState?.password ?? widget.password,
    );
  }

  void _toggleFavoriteRoom() async {
    final isFav = await FavoritesService.toggleFavorite(
      widget.roomId,
      widget.roomName.isNotEmpty ? widget.roomName : widget.roomId,
    );
    if (mounted) {
      setState(() {
        _isFavorite = isFav;
      });
    }
    Fluttertoast.showToast(
      msg: isFav ? 'บันทึกเป็นห้องโปรดแล้ว' : 'ลบออกจากห้องโปรดแล้ว',
    );
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    PipService.setPartyActive(false);
    _watchStatsTimer?.cancel();
    _viewerSyncGuardTimer?.cancel();
    _debounceTimer?.cancel();
    _playerController?.removeListener(_onPlayerStateChanged);
    _playerController?.dispose();
    _syncService.dispose();
    _localReactionStreamController.close();
    _chatInputController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_playerController != null) {
      return YoutubePlayerBuilder(
        player: YoutubePlayer(
          controller: _playerController!,
          showVideoProgressIndicator: true,
          progressIndicatorColor: AppColors.purpleDeep,
          progressColors: const ProgressBarColors(
            playedColor: AppColors.purpleDeep,
            handleColor: AppColors.orangeDeep,
          ),
          onReady: () {
            _isPlayerReady = true;
            // Immediate sync upon player ready
            if (_latestRoomState != null &&
                _latestRoomState!.videoId.isNotEmpty) {
              final double targetTime =
                  _syncService.calculateCompensatedTime(_latestRoomState!);
              if (targetTime > 0.5) {
                _playerController!.seekTo(
                  Duration(milliseconds: (targetTime * 1000).toInt()),
                );
              }
              if (_latestRoomState!.status == 'PLAYING') {
                _playerController!.play();
              } else if (_latestRoomState!.status == 'PAUSED') {
                _playerController!.pause();
              }
              if ((_latestRoomState!.playbackRate - _currentPlaybackRate)
                      .abs() >
                  0.01) {
                _currentPlaybackRate = _latestRoomState!.playbackRate;
                _playerController!.setPlaybackRate(_currentPlaybackRate);
              }
            }
          },
        ),
        builder: (context, player) {
          return _buildScaffold(player);
        },
      );
    }

    return _buildScaffold(null);
  }

  Widget _buildScaffold(Widget? player) {
    final int onlineCount = _members.values.where((m) => m.isOnline).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                color: AppColors.textPrimary, size: 14),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.roomName.isNotEmpty ? widget.roomName : widget.roomId,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFF2EC4B6),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'ID: ${widget.roomId} • $onlineCount คน',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // ⚙️ Unified Clean 3-Dots Menu (No Duplications)
          PopupMenuButton<String>(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.more_vert_rounded,
                  color: AppColors.textPrimary, size: 20),
            ),
            tooltip: 'เมนูห้อง',
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            color: Colors.white,
            elevation: 8,
            onSelected: (val) async {
              if (val == 'share') {
                _shareRoomInvite();
              } else if (val == 'pip') {
                HapticFeedback.lightImpact();
                final ok = await PipService.enterPip();
                if (!ok) {
                  Fluttertoast.showToast(
                      msg: 'อุปกรณ์ไม่รองรับโหมด PiP หรือหน้าต่างลอย');
                }
              } else if (val == 'favorite') {
                _toggleFavoriteRoom();
              } else if (val == 'lock') {
                _showRoomLockSettings();
              }
            },
            itemBuilder: (context) => [
              // 1. QR Code & Share Link
              const PopupMenuItem(
                value: 'share',
                child: Row(
                  children: [
                    Icon(Icons.qr_code_2_rounded,
                        color: AppColors.purpleDeep, size: 20),
                    SizedBox(width: 12),
                    Text(
                      'QR Code & ชวนเพื่อน',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              // 2. Picture-in-Picture Mini Player
              const PopupMenuItem(
                value: 'pip',
                child: Row(
                  children: [
                    Icon(Icons.picture_in_picture_alt_rounded,
                        color: AppColors.blueDeep, size: 20),
                    SizedBox(width: 12),
                    Text(
                      'เล่นแบบหน้าต่างลอย (PiP)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              // 3. Toggle Favorite Room
              PopupMenuItem(
                value: 'favorite',
                child: Row(
                  children: [
                    Icon(
                      _isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                      color: _isFavorite ? Colors.amber : AppColors.textSecondary,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _isFavorite ? 'อยู่ในห้องโปรดแล้ว ⭐' : 'บันทึกเป็นห้องโปรด',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              // 4. Host Only: Private Room Lock
              if (_isHost)
                PopupMenuItem(
                  value: 'lock',
                  child: Row(
                    children: [
                      Icon(
                        _latestRoomState?.isLocked == true
                            ? Icons.lock_rounded
                            : Icons.lock_open_rounded,
                        color: AppColors.orangeDeep,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _latestRoomState?.isLocked == true
                            ? 'ตั้งค่ารหัสผ่าน (ล็อคอยู่)'
                            : 'ล็อคห้องส่วนตัว',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Stack(
        children: [
          SafeArea(
            top: false,
            bottom: true,
            child: Column(
              children: [
                // 1. YouTube Player Hero Card
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Container(
                        color: Colors.black,
                        child: player != null
                            ? Stack(
                                children: [
                                  // Player
                                  AbsorbPointer(
                                    absorbing: !_isHost,
                                    child: player,
                                  ),
                                  // YouTube Embed / Restriction Error Overlay
                                  if (_hasPlayerError)
                                    Positioned.fill(
                                      child: Container(
                                        color: Colors.black.withValues(alpha: 0.88),
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const Icon(
                                              Icons.warning_amber_rounded,
                                              color: AppColors.orangeDeep,
                                              size: 38,
                                            ),
                                            const SizedBox(height: 6),
                                            const Text(
                                              'คลิปนี้ติดข้อจำกัดการเล่นจาก YouTube',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                            const SizedBox(height: 2),
                                            const Text(
                                              'อาจติดลิขสิทธิ์ / ปิดการเล่นภายนอก หรือจำกัดอายุ',
                                              style: TextStyle(
                                                color: Colors.white70,
                                                fontSize: 11,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                            const SizedBox(height: 10),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                if (_isHost && _videoQueue.isNotEmpty) ...[
                                                  ElevatedButton.icon(
                                                    onPressed: _playNextInQueue,
                                                    icon: const Icon(Icons.skip_next_rounded, size: 16),
                                                    label: const Text('เล่นคลิปถัดไปในคิว',
                                                        style: TextStyle(fontSize: 12)),
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: AppColors.purpleDeep,
                                                      foregroundColor: Colors.white,
                                                      padding: const EdgeInsets.symmetric(
                                                          horizontal: 12, vertical: 8),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                ],
                                                if (_isHost)
                                                  OutlinedButton.icon(
                                                    onPressed: () => _showChangeVideoDialog(),
                                                    icon: const Icon(Icons.search_rounded, size: 16),
                                                    label: const Text('ค้นหาคลิปใหม่',
                                                        style: TextStyle(fontSize: 12)),
                                                    style: OutlinedButton.styleFrom(
                                                      foregroundColor: Colors.white,
                                                      side: const BorderSide(color: Colors.white60),
                                                      padding: const EdgeInsets.symmetric(
                                                          horizontal: 12, vertical: 8),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  // Non-host gesture interceptor & lock badge
                                  if (!_isHost) ...[
                                    Positioned.fill(
                                      child: GestureDetector(
                                        behavior: HitTestBehavior.translucent,
                                        onTap: () {
                                          Fluttertoast.showToast(
                                            msg:
                                                'โหมดรับชม: หัวห้องเป็นผู้ควบคุมการเล่น',
                                            toastLength: Toast.LENGTH_SHORT,
                                            backgroundColor: AppColors.darkNav,
                                          );
                                        },
                                      ),
                                    ),
                                    Positioned(
                                      top: 10,
                                      left: 10,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.black
                                              .withValues(alpha: 0.75),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                            color: const Color(0xFF2EC4B6),
                                            width: 1,
                                          ),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.visibility_rounded,
                                                size: 13,
                                                color: Color(0xFF2EC4B6)),
                                            SizedBox(width: 5),
                                            Text(
                                              'โหมดรับชม (ซิงค์ตามหัวห้อง)',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              )
                            : Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.smart_display_rounded,
                                      size: 44,
                                      color: AppColors.purplePastel,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _isHost
                                          ? 'พร้อมเริ่มเล่นวิดีโอ'
                                          : 'รอหัวห้องเลือกวิดีโอ',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    if (_isHost)
                                      ElevatedButton.icon(
                                        onPressed: () =>
                                            _showChangeVideoDialog(),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.white,
                                          foregroundColor: AppColors.darkNav,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(16),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 14, vertical: 8),
                                        ),
                                        icon: const Icon(Icons.search_rounded,
                                            size: 15),
                                        label: const Text('ค้นหาคลิป YouTube',
                                            style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold)),
                                      )
                                    else
                                      ElevatedButton.icon(
                                        onPressed: () => _showChangeVideoDialog(
                                            isAddToQueue: true),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.white,
                                          foregroundColor: AppColors.darkNav,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(16),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 14, vertical: 8),
                                        ),
                                        icon: const Icon(
                                            Icons.playlist_add_rounded,
                                            size: 16),
                                        label: const Text('แนะนำคลิปเข้าคิว',
                                            style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold)),
                                      ),
                                  ],
                                ),
                              ),
                      ),
                    ),
                  ),
                ),

                // 2. Modern Unified Action Bar
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  child: Row(
                    children: [
                      // Main Action Button (Change Video or Add to Queue)
                      if (_isHost) ...[
                        Expanded(
                          flex: 3,
                          child: ElevatedButton.icon(
                            onPressed: () => _showChangeVideoDialog(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppColors.textPrimary,
                              elevation: 0,
                              overlayColor: AppColors.purplePastel.withValues(alpha: 0.3),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 9),
                            ),
                            icon: const Icon(Icons.smart_display_rounded,
                                size: 16, color: AppColors.purpleDeep),
                            label: const Text(
                              'เปลี่ยนคลิป',
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: () =>
                                _showChangeVideoDialog(isAddToQueue: true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppColors.textPrimary,
                              elevation: 0,
                              overlayColor: AppColors.purplePastel.withValues(alpha: 0.3),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 9),
                            ),
                            icon: const Icon(Icons.playlist_add_rounded,
                                size: 16, color: AppColors.purpleDeep),
                            label: const Text(
                              '+คิว',
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ] else ...[
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () =>
                                _showChangeVideoDialog(isAddToQueue: true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppColors.textPrimary,
                              elevation: 0,
                              overlayColor: AppColors.purplePastel.withValues(alpha: 0.3),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 9),
                            ),
                            icon: const Icon(Icons.playlist_add_rounded,
                                size: 16, color: AppColors.purpleDeep),
                            label: const Text(
                              '+เพิ่มคลิปเข้าคิว',
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(width: 6),
                      // Force Resync Button
                      InkWell(
                        onTap: _forceResync,
                        borderRadius: BorderRadius.circular(14),
                        splashColor: AppColors.orangePastel.withValues(alpha: 0.4),
                        highlightColor: AppColors.orangePastel.withValues(alpha: 0.2),
                        child: Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.sync_rounded,
                              size: 18, color: AppColors.orangeDeep),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Subtitles (CC) Toggle Button
                      InkWell(
                        onTap: _toggleCaptions,
                        borderRadius: BorderRadius.circular(14),
                        splashColor: AppColors.purplePastel.withValues(alpha: 0.4),
                        highlightColor: AppColors.purplePastel.withValues(alpha: 0.2),
                        child: Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            _isCaptionsEnabled
                                ? Icons.subtitles_rounded
                                : Icons.subtitles_off_rounded,
                            size: 18,
                            color: _isCaptionsEnabled
                                ? AppColors.purpleDeep
                                : AppColors.textMuted,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Speed Indicator / Selector
                      if (_isHost)
                        PopupMenuButton<double>(
                          initialValue: _currentPlaybackRate,
                          tooltip: 'ความเร็วในการเล่น (หัวห้อง)',
                          onSelected: _changePlaybackSpeed,
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.speed_rounded,
                                    size: 14, color: AppColors.purpleDeep),
                                const SizedBox(width: 4),
                                Text(
                                  '${_currentPlaybackRate}x',
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          itemBuilder: (context) =>
                              [0.75, 1.0, 1.25, 1.5, 2.0].map((rate) {
                            return PopupMenuItem<double>(
                              value: rate,
                              child: Text(
                                '${rate}x',
                                style: TextStyle(
                                  color: _currentPlaybackRate == rate
                                      ? AppColors.purpleDeep
                                      : AppColors.textPrimary,
                                  fontWeight: _currentPlaybackRate == rate
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            );
                          }).toList(),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.lock_clock_rounded,
                                  size: 14, color: AppColors.textMuted),
                              const SizedBox(width: 4),
                              Text(
                                '${_currentPlaybackRate}x',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 4),

                // 3. Modern Segmented Tab Body Container
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(24),
                        topRight: Radius.circular(24),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x08000000),
                          blurRadius: 16,
                          offset: Offset(0, -4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Segmented Tab Bar (Minimal iOS Pill Style)
                        Container(
                          margin: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3EDF7),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              _buildSegmentTab(0, Icons.chat_bubble_rounded,
                                  'แชท', _chatMessages.length),
                              _buildSegmentTab(1, Icons.queue_music_rounded,
                                  'คิวคลิป', _videoQueue.length),
                              _buildSegmentTab(2, Icons.people_alt_rounded,
                                  'สมาชิก', _members.length),
                            ],
                          ),
                        ),

                        // Active Tab Body Content
                        Expanded(
                          child: _selectedBottomTab == 0
                              ? _buildChatSection()
                              : _selectedBottomTab == 1
                                  ? _buildQueueSection()
                                  : _buildMembersSection(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Floating Reaction Overlay Animation
          FloatingReactionsOverlay(
            reactionStream: _localReactionStreamController.stream,
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentTab(int index, IconData icon, String label, int count) {
    final isSelected = _selectedBottomTab == index;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (_selectedBottomTab != index) {
            HapticFeedback.selectionClick();
            setState(() => _selectedBottomTab = index);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(13),
            boxShadow: isSelected
                ? const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected
                    ? AppColors.purpleDeep
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: 5),
              Text(
                '$label ($count)',
                style: TextStyle(
                  color: isSelected
                      ? AppColors.purpleDeep
                      : AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight:
                      isSelected ? FontWeight.bold : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// REAL-TIME CHAT SECTION (Clean & Simple)
  Widget _buildChatSection() {
    return Column(
      children: [
        // Message List
        Expanded(
          child: _chatMessages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          color: AppColors.purplePastel,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.chat_bubble_outline_rounded,
                            size: 22, color: AppColors.purpleDeep),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'ยังไม่มีข้อความแชท',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'พิมพ์ทักทายเพื่อพูดคุยในห้อง',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  controller: _chatScrollController,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  itemCount: _chatMessages.length,
                  itemBuilder: (context, index) {
                    final msg = _chatMessages[index];
                    final isMe = msg.senderId == _syncService.myDeviceId;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        mainAxisAlignment: isMe
                            ? MainAxisAlignment.end
                            : MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (!isMe) ...[
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: AppColors.purplePastel,
                              child: Text(
                                msg.senderName.isNotEmpty
                                    ? msg.senderName[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                    color: AppColors.purpleDeep,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Flexible(
                            child: Column(
                              crossAxisAlignment: isMe
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                              children: [
                                if (!isMe)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                        left: 3, bottom: 2),
                                    child: Text(
                                      msg.senderName,
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isMe
                                        ? AppColors.purplePastel
                                        : AppColors.background,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    msg.text,
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isMe) ...[
                            const SizedBox(width: 4),
                            Text(
                              msg.formattedTime,
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
        ),

        // Quick Reaction Bar Strip (Directly above input box)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0xFFF4F0FA))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['❤️', '🍿', '😂', '🔥', '👏', '😭', '🎬', '✨']
                .map((emoji) {
              return InkWell(
                onTap: () => _sendReaction(emoji),
                borderRadius: BorderRadius.circular(16),
                splashColor: AppColors.purplePastel.withValues(alpha: 0.35),
                highlightColor: AppColors.purplePastel.withValues(alpha: 0.15),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 4, vertical: 2),
                  child: Text(
                    emoji,
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        // Chat Input Box
        Container(
          padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chatInputController,
                  style: const TextStyle(
                      color: AppColors.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'พิมพ์ข้อความคุยกัน...',
                    hintStyle: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                    filled: true,
                    fillColor: AppColors.background,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (_) => _sendChatMessage(),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                decoration: const BoxDecoration(
                  color: AppColors.darkNav,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.send_rounded,
                      color: Colors.white, size: 16),
                  tooltip: 'ส่งข้อความ',
                  onPressed: _sendChatMessage,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// VIDEO PLAYLIST QUEUE SECTION
  Widget _buildQueueSection() {
    final myNickname = DeviceService.getNickname();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Row(
            children: [
              Text(
                'คิวที่จะเล่นถัดไป (${_videoQueue.length} รายการ)',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _showChangeVideoDialog(isAddToQueue: true),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('เพิ่มคลิป', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ),
        Expanded(
          child: _videoQueue.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.playlist_play_rounded,
                          size: 40, color: AppColors.textMuted),
                      SizedBox(height: 6),
                      Text(
                        'ยังไม่มีคลิปในคิว',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'กดปุ่ม "เพิ่มคิว" เพื่อเล่นวิดีโอต่อเนื่องอัตโนมัติ',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  itemCount: _videoQueue.length,
                  itemBuilder: (context, index) {
                    final item = _videoQueue[index];
                    final bool canDelete = _isHost || item.addedBy == myNickname;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.bluePastel,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.blueDeep,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'เพิ่มโดย ${item.addedBy}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_isHost)
                            IconButton(
                              icon: const Icon(Icons.play_arrow_rounded,
                                  color: AppColors.purpleDeep, size: 20),
                              tooltip: 'เล่นตอนนี้',
                              onPressed: () {
                                _syncService.removeFromQueue(item.id);
                                _playVideoById(item.videoId);
                              },
                            ),
                          if (canDelete)
                            IconButton(
                              icon: const Icon(Icons.close_rounded,
                                  color: AppColors.textMuted, size: 18),
                              tooltip: 'ลบออกจากคิว',
                              onPressed: () {
                                _syncService.removeFromQueue(item.id);
                              },
                            ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  /// 👥 PARTY MEMBERS SECTION
  Widget _buildMembersSection() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      children: _members.entries.map((entry) {
        final isMe = entry.key == _syncService.myDeviceId;
        final isOnline = entry.value.isOnline;
        final isHost = entry.key == _latestRoomState?.hostId;
        final isOwner = entry.key == _latestRoomState?.ownerId;
        final displayName = isMe
            ? '${DeviceService.getNickname()} (คุณ)'
            : entry.value.nickname;

        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: isHost
                    ? const Color(0xFFFFF3CD)
                    : (isMe
                        ? AppColors.purplePastel
                        : AppColors.orangePastel),
                child: Icon(
                  isHost
                      ? Icons.star_rounded
                      : (isMe
                          ? Icons.person_rounded
                          : Icons.face_rounded),
                  size: 14,
                  color: isHost
                      ? const Color(0xFF856404)
                      : AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        displayName,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isHost) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3CD),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'หัวห้อง',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF856404),
                          ),
                        ),
                      ),
                    ] else if (isOwner) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'เจ้าของห้อง',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2E7D32),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: isOnline
                      ? AppColors.greenPastel
                      : const Color(0xFFFFCCD5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  isOnline ? 'ออนไลน์' : 'ออฟไลน์',
                  style: TextStyle(
                    color: isOnline
                        ? const Color(0xFF1B4332)
                        : const Color(0xFFA4133C),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
