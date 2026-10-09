import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../theme/app_theme.dart';
import '../services/update_service.dart';

class UpdateDialog extends StatefulWidget {
  final AppReleaseInfo releaseInfo;

  const UpdateDialog({
    super.key,
    required this.releaseInfo,
  });

  static void show(BuildContext context, AppReleaseInfo releaseInfo) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => UpdateDialog(releaseInfo: releaseInfo),
    );
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _isDownloading = false;
  double _progress = 0.0;
  double _downloadedMb = 0.0;
  double _totalMb = 0.0;
  String _statusText = 'กดปุ่มด้านล่างเพื่ออัปเดต';

  void _startUpdate() async {
    HapticFeedback.selectionClick();
    setState(() {
      _isDownloading = true;
      _statusText = 'กำลังดาวน์โหลดไฟล์...';
    });

    final success = await UpdateService.downloadAndInstall(
      downloadUrl: widget.releaseInfo.downloadUrl,
      onProgress: (progress, downloadedMb, totalMb) {
        if (mounted) {
          setState(() {
            _progress = progress;
            _downloadedMb = downloadedMb;
            _totalMb = totalMb;
            _statusText = 'กำลังโหลด ${(progress * 100).toInt()}%';
          });
        }
      },
    );

    if (mounted) {
      if (success) {
        setState(() {
          _statusText = 'กรุณากดยืนยันการติดตั้งในหน้าจอ';
        });
      } else {
        setState(() {
          _isDownloading = false;
          _statusText = 'ดาวน์โหลดไม่สำเร็จ ลองใหม่อีกครั้ง';
        });
        Fluttertoast.showToast(
          msg: 'ดาวน์โหลดไม่สำเร็จ กรุณาลองใหม่',
          backgroundColor: AppColors.pinkDeep,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: isDark
                ? const Color(0xFF2E2B40)
                : AppColors.purplePastel.withValues(alpha: 0.6),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                  alpha: isDark ? 0.4 : 0.12),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Badge & Close button
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.purplePastel.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    color: AppColors.purpleDeep,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'อัปเดตเวอร์ชันใหม่',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'v${UpdateService.currentVersion} ➔ v${widget.releaseInfo.latestVersion}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.purpleDeep,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!_isDownloading)
                  IconButton(
                    icon: Icon(Icons.close_rounded,
                        size: 18, color: AppColors.textMuted),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),

            const SizedBox(height: 14),

            // Short Changelog Box
            Container(
              padding: const EdgeInsets.all(12),
              constraints: const BoxConstraints(maxHeight: 90),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF13121E) : AppColors.background,
                borderRadius: BorderRadius.circular(16),
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Text(
                  widget.releaseInfo.changelog.isNotEmpty
                      ? widget.releaseInfo.changelog
                      : 'อัปเดตประสิทธิภาพและฟีเจอร์ใหม่',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Download Progress Bar (during download)
            if (_isDownloading) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: _progress > 0 ? _progress : null,
                  minHeight: 6,
                  backgroundColor: isDark ? const Color(0xFF13121E) : AppColors.background,
                  valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.purpleDeep),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _statusText,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.purpleDeep,
                    ),
                  ),
                  if (_totalMb > 0)
                    Text(
                      '${_downloadedMb.toStringAsFixed(1)}/${_totalMb.toStringAsFixed(1)} MB',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
            ] else ...[
              Text(
                _statusText,
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
            ],

            // Action Button: Short, clean & clear
            SizedBox(
              height: 44,
              child: ElevatedButton(
                onPressed: _isDownloading ? null : _startUpdate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.purpleDeep,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isDownloading)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    else ...[
                      const Icon(Icons.download_rounded, size: 18),
                      const SizedBox(width: 6),
                      const Text(
                        'อัปเดตทันที',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
