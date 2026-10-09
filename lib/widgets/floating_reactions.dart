import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class FloatingReactionItem {
  final Key key;
  final String emoji;
  final double startX; // Normalized 0.0 - 1.0

  FloatingReactionItem({
    required this.key,
    required this.emoji,
    required this.startX,
  });
}

class FloatingReactionsOverlay extends StatefulWidget {
  final Stream<String>? reactionStream;

  const FloatingReactionsOverlay({
    super.key,
    this.reactionStream,
  });

  @override
  State<FloatingReactionsOverlay> createState() =>
      _FloatingReactionsOverlayState();
}

class _FloatingReactionsOverlayState extends State<FloatingReactionsOverlay> {
  final List<FloatingReactionItem> _reactions = [];
  final Random _random = Random();

  // Combo system
  int _comboCount = 0;
  Timer? _comboResetTimer;
  String _comboEmoji = '❤️';
  bool _showComboBadge = false;

  @override
  void initState() {
    super.initState();
    widget.reactionStream?.listen((emoji) {
      if (mounted && emoji.isNotEmpty) {
        _handleIncomingReaction(emoji);
      }
    });
  }

  @override
  void dispose() {
    _comboResetTimer?.cancel();
    super.dispose();
  }

  void _handleIncomingReaction(String emoji) {
    _comboEmoji = emoji;
    _comboCount++;
    _showComboBadge = _comboCount >= 3;

    _comboResetTimer?.cancel();
    _comboResetTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) {
        setState(() {
          _comboCount = 0;
          _showComboBadge = false;
        });
      }
    });

    // If milestone reached (e.g. 5, 10, 20), trigger multi-burst
    if (_comboCount == 5 || _comboCount == 10 || _comboCount % 15 == 0) {
      _triggerBurst(emoji);
    } else {
      _addReaction(emoji);
    }
  }

  void _triggerBurst(String emoji) {
    for (int i = 0; i < 6; i++) {
      Future.delayed(Duration(milliseconds: i * 60), () {
        if (mounted) {
          _addReaction(emoji, customX: 0.2 + (_random.nextDouble() * 0.6));
        }
      });
    }
  }

  void _addReaction(String emoji, {double? customX}) {
    final item = FloatingReactionItem(
      key: UniqueKey(),
      emoji: emoji,
      startX: customX ?? (0.65 + (_random.nextDouble() * 0.25)),
    );

    setState(() {
      _reactions.add(item);
    });

    // Auto remove after 2.4 seconds
    Future.delayed(const Duration(milliseconds: 2400), () {
      if (mounted) {
        setState(() {
          _reactions.removeWhere((r) => r.key == item.key);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          // Floating Emojis
          ..._reactions.map((item) {
            return _FloatingSingleEmoji(
              key: item.key,
              emoji: item.emoji,
              startX: item.startX,
            );
          }),

          // Combo Celebration Banner
          if (_showComboBadge && _comboCount >= 3)
            Positioned(
              top: 100,
              right: 20,
              child: AnimatedScale(
                scale: 1.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.orangeDeep, AppColors.pinkDeep],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.pinkDeep.withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _comboEmoji,
                        style: const TextStyle(fontSize: 18),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'x$_comboCount COMBO!',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FloatingSingleEmoji extends StatefulWidget {
  final String emoji;
  final double startX;

  const _FloatingSingleEmoji({
    super.key,
    required this.emoji,
    required this.startX,
  });

  @override
  State<_FloatingSingleEmoji> createState() => _FloatingSingleEmojiState();
}

class _FloatingSingleEmojiState extends State<_FloatingSingleEmoji>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _yAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<double> _scaleAnimation;
  late double _xWobbleOffset;

  @override
  void initState() {
    super.initState();
    _xWobbleOffset = (Random().nextDouble() - 0.5) * 45;

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    _yAnimation = Tween<double>(begin: 0.95, end: 0.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 55),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30),
    ]).animate(_controller);

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.3, end: 1.4), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.4, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.15), weight: 60),
    ]).animate(_controller);

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final double top = _yAnimation.value * size.height;
        final double left =
            (widget.startX * size.width) + (_xWobbleOffset * sin(_controller.value * pi * 2));

        return Positioned(
          top: top,
          left: left.clamp(10.0, size.width - 50.0),
          child: Opacity(
            opacity: _opacityAnimation.value.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: Text(
                widget.emoji,
                style: const TextStyle(fontSize: 34),
              ),
            ),
          ),
        );
      },
    );
  }
}
