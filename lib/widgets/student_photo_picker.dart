import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';

import '../core/constants/app_colors.dart';
import '../core/utils/app_utils.dart';
import '../core/utils/image_compress_util.dart';

/// Student / Institute photo picker.
///
/// Flow:
/// Tap photo
///   ↓
/// View / Take Photo / Gallery / Remove
///   ↓
/// Camera or Gallery
///   ↓
/// Crop 1:1
///   ↓
/// Preview
///   ↓
/// Use This Photo
///   ↓
/// onChanged(path)
///
/// Nothing is changed until the user confirms the preview.
class StudentPhotoPicker extends StatelessWidget {
  final String? photoPath;
  final ValueChanged<String?> onChanged;
  final double size;

  /// null = circular student avatar
  /// non-null = rounded-square image, useful for institute logo
  final BorderRadius? borderRadius;

  final IconData placeholderIcon;

  /// Aspect ratio for cropper (defaults to 3:4 for student ID, or 1:1 if square/logo)
  final CropAspectRatio? cropAspectRatio;

  const StudentPhotoPicker({
    super.key,
    required this.photoPath,
    required this.onChanged,
    this.size = 100,
    this.borderRadius,
    this.placeholderIcon = Icons.add_a_photo_outlined,
    this.cropAspectRatio,
  });

  bool get _hasPhoto =>
      photoPath != null && photoPath!.trim().isNotEmpty;

  bool get _isCircle => borderRadius == null;

  Future<void> _openMenu(BuildContext context) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return _PhotoActionSheet(
          hasPhoto: _hasPhoto,
        );
      },
    );

    if (action == null || !context.mounted) {
      return;
    }

    switch (action) {
      case 'view':
        if (!_hasPhoto) return;

        Navigator.of(context).push(
          PageRouteBuilder(
            opaque: false,
            barrierColor: Colors.black87,
            pageBuilder: (_, __, ___) {
              return FullPhotoViewer(
                path: photoPath!,
              );
            },
          ),
        );
        break;

      case 'camera':
        await _pickAndCrop(
          context,
          ImageSource.camera,
        );
        break;

      case 'gallery':
        await _pickAndCrop(
          context,
          ImageSource.gallery,
        );
        break;

      case 'remove':
        onChanged(null);
        break;
    }
  }

  Future<void> _pickAndCrop(
      BuildContext context,
      ImageSource source,
      ) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        imageQuality: 90,
      );

      if (picked == null) {
        return;
      }

      final defaultRatio = cropAspectRatio ??
          (_isCircle
              ? const CropAspectRatio(ratioX: 3, ratioY: 4)
              : const CropAspectRatio(ratioX: 1, ratioY: 1));

      final cropped = await ImageCropper().cropImage(
        sourcePath: picked.path,
        aspectRatio: defaultRatio,
        maxWidth: 600,
        maxHeight: 800,
        compressQuality: 78,
        compressFormat: ImageCompressFormat.jpg,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Photo',
            toolbarColor: AppColors.primary,
            toolbarWidgetColor: Colors.white,
            activeControlsWidgetColor: AppColors.primary,
            lockAspectRatio: false,
          ),
          IOSUiSettings(
            title: 'Crop Photo',
            aspectRatioLockEnabled: false,
            resetAspectRatioEnabled: true,
          ),
        ],
      );

      if (cropped == null) {
        return;
      }

      // ─── COMPRESS DP TO 20 - 30 KB ───
      final compressedFile = await ImageCompressUtil.compressStudentPhotoFile(
        File(cropped.path),
        minKb: 20,
        maxKb: 30,
      );

      if (!context.mounted) {
        return;
      }

      final confirmed = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => _PhotoPreviewScreen(
            path: compressedFile.path,
          ),
        ),
      );

      if (confirmed == true) {
        // Convert to standard Base64 Data URL for universal two-way sync with Web
        try {
          if (await compressedFile.exists()) {
            final bytes = await compressedFile.readAsBytes();
            final base64String = 'data:image/jpeg;base64,${base64Encode(bytes)}';
            onChanged(base64String);
            return;
          }
        } catch (_) {}
        onChanged(compressedFile.path);
      }
    } catch (e) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            source == ImageSource.camera
                ? 'Camera permission is required. You can choose a photo from your device instead.'
                : 'Could not load photo: $e',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  ImageProvider? _resolveImageProvider(String path) {
    final trimmed = path.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return NetworkImage(trimmed);
    }
    if (trimmed.startsWith('data:image')) {
      try {
        final base64Str = trimmed.split(',').last;
        return MemoryImage(base64Decode(base64Str));
      } catch (_) {
        return null;
      }
    }
    try {
      final file = File(trimmed);
      if (file.existsSync()) {
        return FileImage(file);
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final imgProvider = _hasPhoto ? _resolveImageProvider(photoPath!) : null;

    return GestureDetector(
      onTap: () => _openMenu(context),
      child: Stack(
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: _isCircle
                  ? BoxShape.circle
                  : BoxShape.rectangle,
              borderRadius: _isCircle
                  ? null
                  : borderRadius,
              color: AppColors.primary.withValues(
                alpha: 0.08,
              ),
              image: imgProvider != null
                  ? DecorationImage(
                image: imgProvider,
                fit: BoxFit.cover,
              )
                  : null,
              border: Border.all(
                color: AppColors.primary.withValues(
                  alpha: 0.25,
                ),
                width: 1.5,
              ),
            ),
            child: imgProvider == null
                ? Icon(
              placeholderIcon,
              color: AppColors.primary,
              size: size * 0.32,
            )
                : null,
          ),

          // Camera badge
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context)
                      .scaffoldBackgroundColor,
                  width: 2,
                ),
                boxShadow: const [
                  BoxShadow(
                    blurRadius: 5,
                    offset: Offset(0, 2),
                    color: Colors.black26,
                  ),
                ],
              ),
              child: const Icon(
                Icons.camera_alt_outlined,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Photo action bottom sheet.
class _PhotoActionSheet extends StatelessWidget {
  final bool hasPhoto;

  const _PhotoActionSheet({
    required this.hasPhoto,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final isDark =
        theme.brightness == Brightness.dark;

    final backgroundColor = isDark
        ? AppColors.darkCard
        : AppColors.surface;

    final titleColor = isDark
        ? Colors.white
        : AppColors.textPrimary;

    final secondaryColor = isDark
        ? Colors.white70
        : AppColors.textSecondary;

    final dividerColor = isDark
        ? Colors.white12
        : AppColors.divider;

    final handleColor = isDark
        ? Colors.white30
        : Colors.black12;

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 500,
          ),
          child: Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark
                    ? Colors.white10
                    : AppColors.border,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: isDark ? 0.35 : 0.12,
                  ),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(
              8,
              10,
              8,
              10,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(
                    bottom: 12,
                  ),
                  decoration: BoxDecoration(
                    color: handleColor,
                    borderRadius:
                    BorderRadius.circular(10),
                  ),
                ),

                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    12,
                    2,
                    12,
                    10,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: colorScheme.primary
                              .withValues(alpha: 0.10),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.account_circle_outlined,
                          color: colorScheme.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Student Photo',
                              style: TextStyle(
                                color: titleColor,
                                fontSize: 17,
                                fontWeight:
                                FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              hasPhoto
                                  ? 'View or change the current photo'
                                  : 'Add a photo to the student profile',
                              style: TextStyle(
                                color: secondaryColor,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                Divider(
                  height: 1,
                  color: dividerColor,
                ),

                const SizedBox(height: 6),

                // View Photo
                if (hasPhoto)
                  _PhotoActionTile(
                    icon: Icons.visibility_outlined,
                    title: 'View Photo',
                    subtitle: 'View the current profile photo',
                    iconColor: colorScheme.primary,
                    textColor: titleColor,
                    subtitleColor: secondaryColor,
                    onTap: () {
                      Navigator.pop(
                        context,
                        'view',
                      );
                    },
                  ),

                // Take Photo
                _PhotoActionTile(
                  icon: Icons.photo_camera_outlined,
                  title: 'Take Photo',
                  subtitle: 'Use your device camera',
                  iconColor: colorScheme.primary,
                  textColor: titleColor,
                  subtitleColor: secondaryColor,
                  onTap: () {
                    Navigator.pop(
                      context,
                      'camera',
                    );
                  },
                ),

                // Gallery
                _PhotoActionTile(
                  icon: Icons.photo_library_outlined,
                  title: 'Choose from Gallery',
                  subtitle: 'Select an existing photo',
                  iconColor: colorScheme.primary,
                  textColor: titleColor,
                  subtitleColor: secondaryColor,
                  onTap: () {
                    Navigator.pop(
                      context,
                      'gallery',
                    );
                  },
                ),

                // Remove
                if (hasPhoto)
                  _PhotoActionTile(
                    icon: Icons.delete_outline,
                    title: 'Remove Photo',
                    subtitle: 'Remove the current profile photo',
                    iconColor: AppColors.error,
                    textColor: AppColors.error,
                    subtitleColor:
                    AppColors.error.withValues(
                      alpha: 0.70,
                    ),
                    onTap: () {
                      Navigator.pop(
                        context,
                        'remove',
                      );
                    },
                  ),

                const SizedBox(height: 4),

                // Cancel
                _PhotoActionTile(
                  icon: Icons.close,
                  title: 'Cancel',
                  subtitle: 'Close this menu',
                  iconColor: secondaryColor,
                  textColor: titleColor,
                  subtitleColor: secondaryColor,
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Individual action row.
class _PhotoActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconColor;
  final Color textColor;
  final Color subtitleColor;
  final VoidCallback onTap;

  const _PhotoActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.iconColor,
    required this.textColor,
    required this.subtitleColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 5,
          ),
          child: SizedBox(
            height: 58,
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(
                      alpha: 0.10,
                    ),
                    borderRadius:
                    BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    mainAxisAlignment:
                    MainAxisAlignment.center,
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow:
                        TextOverflow.ellipsis,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 14.5,
                          fontWeight:
                          FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow:
                        TextOverflow.ellipsis,
                        style: TextStyle(
                          color: subtitleColor,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: subtitleColor.withValues(
                    alpha: 0.65,
                  ),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Photo preview screen.
class _PhotoPreviewScreen extends StatelessWidget {
  final String path;

  const _PhotoPreviewScreen({
    required this.path,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark =
        theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
      isDark ? AppColors.darkBackground : Colors.black,
      appBar: AppBar(
        backgroundColor:
        isDark ? AppColors.darkSurface : Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Photo Preview',
          style: TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.file(
                        File(path),
                        fit: BoxFit.contain,
                        height: 300,
                      ),
                    ),
                    const SizedBox(height: 14),
                    FutureBuilder<int>(
                      future: File(path).length(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const SizedBox.shrink();
                        final kb = (snapshot.data! / 1024).toStringAsFixed(1);
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_circle_rounded, color: Colors.green, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                'Compressed: $kb KB (Optimized 20-30 KB)',
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                16,
                8,
                16,
                16,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style:
                      OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(
                          color: Colors.white54,
                        ),
                        padding:
                        const EdgeInsets.symmetric(
                          vertical: 14,
                        ),
                        shape:
                        RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () =>
                          Navigator.pop(
                            context,
                            false,
                          ),
                      icon: const Icon(
                        Icons.refresh,
                      ),
                      label: const Text(
                        'Choose Another',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style:
                      ElevatedButton.styleFrom(
                        backgroundColor:
                        AppColors.primary,
                        foregroundColor:
                        Colors.white,
                        padding:
                        const EdgeInsets.symmetric(
                          vertical: 14,
                        ),
                        shape:
                        RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () =>
                          Navigator.pop(
                            context,
                            true,
                          ),
                      icon: const Icon(
                        Icons.check_circle_outline,
                      ),
                      label: const Text(
                        'Use This Photo',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-screen photo viewer with zoom and pan.
class FullPhotoViewer extends StatelessWidget {
  final String path;

  const FullPhotoViewer({
    super.key,
    required this.path,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Scaffold(
        backgroundColor: Colors.black87,
        body: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4,
                child: AppUtils.buildAppImageWidget(
                  path,
                  fit: BoxFit.contain,
                  placeholder: const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),
              ),
            ),

            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Container(
                  margin: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white24,
                    ),
                  ),
                  child: IconButton(
                    tooltip: 'Close',
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 26,
                    ),
                    onPressed: () =>
                        Navigator.pop(context),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}