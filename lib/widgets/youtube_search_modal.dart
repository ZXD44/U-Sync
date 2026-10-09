import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../theme/app_theme.dart';
import '../services/youtube_search_service.dart';

class YouTubeSearchModal extends StatefulWidget {
  final Function(String videoId, String title) onSelectPlay;
  final Function(String videoId, String title) onSelectQueue;
  final bool initialAddToQueue;

  const YouTubeSearchModal({
    super.key,
    required this.onSelectPlay,
    required this.onSelectQueue,
    this.initialAddToQueue = false,
  });

  @override
  State<YouTubeSearchModal> createState() => _YouTubeSearchModalState();
}

class _YouTubeSearchModalState extends State<YouTubeSearchModal> {
  final TextEditingController _searchController = TextEditingController();
  List<YouTubeSearchResult> _results = [];
  bool _isLoading = false;
  bool _hasSearched = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      Fluttertoast.showToast(msg: 'กรุณากรอกชื่อคลิป หรือวางลิงก์ YouTube');
      return;
    }

    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    try {
      final results = await YouTubeSearchService.search(query);
      if (mounted) {
        setState(() {
          _results = results;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        Fluttertoast.showToast(msg: 'เกิดข้อผิดพลาดในการค้นหา ลองอีกครั้ง');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark;

    return Dialog(
      backgroundColor: AppColors.cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 650),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.smart_display_rounded,
                    color: AppColors.purpleDeep, size: 24),
                const SizedBox(width: 8),
                Text(
                  'ค้นหาคลิป YouTube',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close_rounded,
                      color: AppColors.textMuted, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Search Bar Input
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF13121E) : AppColors.background,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isDark ? const Color(0xFF2B273D) : Colors.transparent,
                  width: 1.0,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.search_rounded,
                      color: AppColors.purpleDeep, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: 'พิมพ์ชื่อคลิป หรือวางลิงก์ YouTube...',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: AppColors.textMuted,
                        ),
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => _performSearch(),
                    ),
                  ),
                  if (_searchController.text.isNotEmpty)
                    IconButton(
                      icon: Icon(Icons.clear_rounded,
                          size: 16, color: AppColors.textMuted),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                    ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? AppColors.purpleDeep : AppColors.darkNav,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _performSearch,
                    child: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'ค้นหา',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Search Results Body
            Expanded(
              child: _isLoading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: AppColors.purpleDeep),
                          const SizedBox(height: 12),
                          Text(
                            'กำลังค้นหาวิดีโอบน YouTube...',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    )
                  : !_hasSearched
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: AppColors.purplePastel,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.youtube_searched_for_rounded,
                                    size: 32, color: AppColors.purpleDeep),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'ค้นหาหรือวางลิงก์เพื่อเริ่มดู',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'พิมพ์ชื่อเพลง ศิลปิน หรือวาง URL ใดๆ ของ YouTube',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : _results.isEmpty
                          ? Center(
                              child: Text(
                                'ไม่พบวิดีโอที่ค้นหา ลองเปลี่ยนคำค้นหาใหม่',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _results.length,
                              itemBuilder: (context, index) {
                                final item = _results[index];
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF151322) : AppColors.background,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: isDark ? const Color(0xFF28243A) : Colors.transparent,
                                      width: 1.0,
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Video Thumbnail with Duration Badge
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Stack(
                                          children: [
                                            Image.network(
                                              item.thumbnailUrl,
                                              width: 100,
                                              height: 62,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) =>
                                                  Container(
                                                width: 100,
                                                height: 62,
                                                color: Colors.black12,
                                                child: Icon(
                                                    Icons.movie_rounded,
                                                    color: AppColors.purpleDeep),
                                              ),
                                            ),
                                            if (item.duration.isNotEmpty)
                                              Positioned(
                                                right: 4,
                                                bottom: 4,
                                                child: Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 4,
                                                      vertical: 1),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black87,
                                                    borderRadius:
                                                        BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    item.duration,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 9,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      // Video Info & Buttons
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.title,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.textPrimary,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            if (item.channelTitle.isNotEmpty) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                item.channelTitle,
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: AppColors.textSecondary,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                            const SizedBox(height: 6),
                                            // Action Buttons
                                            Row(
                                              children: [
                                                ElevatedButton(
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        isDark ? AppColors.purpleDeep : AppColors.darkNav,
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 10,
                                                        vertical: 4),
                                                    shape:
                                                        RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              10),
                                                    ),
                                                    minimumSize: Size.zero,
                                                    tapTargetSize:
                                                        MaterialTapTargetSize
                                                            .shrinkWrap,
                                                  ),
                                                  onPressed: () {
                                                    Navigator.pop(context);
                                                    widget.onSelectPlay(
                                                        item.videoId, item.title);
                                                  },
                                                  child: const Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                          Icons
                                                              .play_arrow_rounded,
                                                          size: 14,
                                                          color: Colors.white),
                                                      SizedBox(width: 2),
                                                      Text(
                                                        'เล่นเลย',
                                                        style: TextStyle(
                                                            fontSize: 11,
                                                            color:
                                                                Colors.white),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                OutlinedButton(
                                                  style: OutlinedButton.styleFrom(
                                                    foregroundColor:
                                                        AppColors.purpleDeep,
                                                    backgroundColor:
                                                        isDark ? const Color(0xFF1F1A30) : Colors.white,
                                                    side: BorderSide(
                                                        color: isDark
                                                            ? AppColors.purpleDeep.withValues(alpha: 0.5)
                                                            : AppColors.purplePastel),
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 8,
                                                        vertical: 4),
                                                    shape:
                                                        RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              10),
                                                    ),
                                                    minimumSize: Size.zero,
                                                    tapTargetSize:
                                                        MaterialTapTargetSize
                                                            .shrinkWrap,
                                                  ),
                                                  onPressed: () {
                                                    Navigator.pop(context);
                                                    widget.onSelectQueue(
                                                        item.videoId, item.title);
                                                  },
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Icon(Icons.add_rounded,
                                                          size: 14,
                                                          color: AppColors
                                                              .purpleDeep),
                                                      const SizedBox(width: 2),
                                                      const Text(
                                                        '+คิว',
                                                        style: TextStyle(
                                                            fontSize: 11,
                                                            fontWeight:
                                                                FontWeight.bold),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
