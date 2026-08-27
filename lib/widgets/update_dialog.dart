import 'package:flutter/material.dart';
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
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: UpdateDialog(releaseInfo: releaseInfo),
      ),
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
  String _statusText = 'มีเวอร์ชันใหม่พร้อมให้อัปเดต';

  void _startUpdate() async {
    setState(() {
      _isDownloading = true;
      _statusText = 'กำลังดาวน์โหลดไฟล์อัปเดต...';
    });

    final success = await UpdateService.downloadAndInstall(
      downloadUrl: widget.releaseInfo.downloadUrl,
      onProgress: (progress, downloadedMb, totalMb) {
        if (mounted) {
          setState(() {
            _progress = progress;
            _downloadedMb = downloadedMb;
            _totalMb = totalMb;
            _statusText = 'กำลังดาวน์โหลด... (${(progress * 100).toInt()}%)';
          });
        }
      },
    );

    if (mounted) {
      if (success) {
        setState(() {
          _statusText = 'เปิดตัวติดตั้งแพ็กเกจเรียบร้อย กรุณากดยืนยันการติดตั้ง';
        });
      } else {
        setState(() {
          _isDownloading = false;
          _statusText = 'ดาวน์โหลดหรือติดตั้งไม่สำเร็จ กรุณาลองใหม่อีกครั้ง';
        });
        Fluttertoast.showToast(
          msg: 'ไม่สามารถติดตั้งอัตโนมัติได้ กรุณาลองใหม่',
          backgroundColor: AppColors.pinkDeep,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header with Rocket Icon
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.purplePastel, AppColors.bluePastel],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.purpleDeep.withValues(alpha: 0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.rocket_launch_rounded,
                  color: AppColors.purpleDeep,
                  size: 36,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            const Text(
              'พบการอัปเดตเวอร์ชันใหม่!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),

            // Version Tag
            Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.purplePastel.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'v${UpdateService.currentVersion}  ➔  v${widget.releaseInfo.latestVersion}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.purpleDeep,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Changelog Box
            Container(
              padding: const EdgeInsets.all(14),
              constraints: const BoxConstraints(maxHeight: 140),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: AppColors.purplePastel.withValues(alpha: 0.4),
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '📝 รายละเอียดการอัปเดต:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.releaseInfo.changelog,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Download Progress Bar (when downloading)
            if (_isDownloading) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: _progress > 0 ? _progress : null,
                  minHeight: 8,
                  backgroundColor: AppColors.background,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppColors.purpleDeep),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _statusText,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.purpleDeep,
                    ),
                  ),
                  if (_totalMb > 0)
                    Text(
                      '${_downloadedMb.toStringAsFixed(1)} / ${_totalMb.toStringAsFixed(1)} MB',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
            ] else ...[
              Text(
                _statusText,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
            ],

            // Action Button
            ElevatedButton(
              onPressed: _isDownloading ? null : _startUpdate,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.purpleDeep,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isDownloading)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  else ...[
                    const Icon(Icons.download_rounded, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'อัปเดตและติดตั้งทันที',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
