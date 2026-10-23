import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_colors.dart';
import '../../core/localization/app_translations.dart';
import '../../data/services/providers.dart';
import '../../data/services/session_service.dart';
import '../../data/services/teacher_permissions_service.dart';
import '../../data/services/voice_assistant_service.dart';

class NoticeItem {
  final String id;
  final String title;
  final String content;
  final String category; // 'Urgent' | 'Meeting' | 'Holiday' | 'Academic' | 'Event' | 'General'
  final String targetAudience; // 'all' | 'teachers' | 'students' | 'parents'
  final String authorName;
  final String authorRole;
  final DateTime createdAt;
  bool isPinned;
  final String? imageUrl;
  final String? fileType; // 'image' | 'pdf'
  final String? fileName;
  final String? fileSize;
  final String? originalSize;

  NoticeItem({
    required this.id,
    required this.title,
    required this.content,
    required this.category,
    required this.targetAudience,
    required this.authorName,
    this.authorRole = 'principal',
    required this.createdAt,
    this.isPinned = false,
    this.imageUrl,
    this.fileType = 'image',
    this.fileName,
    this.fileSize,
    this.originalSize,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'content': content,
    'category': category,
    'targetAudience': targetAudience,
    'authorName': authorName,
    'authorRole': authorRole,
    'createdAt': createdAt.toIso8601String(),
    'isPinned': isPinned,
    'imageUrl': imageUrl ?? '',
    'fileType': fileType ?? 'image',
    'fileName': fileName ?? '',
    'fileSize': fileSize ?? '',
    'originalSize': originalSize ?? '',
  };

  factory NoticeItem.fromJson(Map<String, dynamic> m) => NoticeItem(
    id: m['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
    title: m['title']?.toString() ?? '',
    content: m['content']?.toString() ?? '',
    category: m['category']?.toString() ?? 'General',
    targetAudience: m['targetAudience']?.toString() ?? 'all',
    authorName: m['authorName']?.toString() ?? 'Principal Office',
    authorRole: m['authorRole']?.toString() ?? 'principal',
    createdAt: m['createdAt'] != null
        ? DateTime.tryParse(m['createdAt'].toString()) ?? DateTime.now()
        : DateTime.now(),
    isPinned: m['isPinned'] == true,
    imageUrl: m['imageUrl']?.toString(),
    fileType: m['fileType']?.toString() ??
        ((m['imageUrl']?.toString().startsWith('data:application/pdf') ?? false) ? 'pdf' : 'image'),
    fileName: m['fileName']?.toString(),
    fileSize: m['fileSize']?.toString(),
    originalSize: m['originalSize']?.toString(),
  );
}

class NoticeScreen extends ConsumerStatefulWidget {
  const NoticeScreen({super.key});

  @override
  ConsumerState<NoticeScreen> createState() => _NoticeScreenState();
}

class _NoticeScreenState extends ConsumerState<NoticeScreen> {
  final List<String> _categories = ['All', 'Urgent', 'Meeting', 'Holiday', 'Academic', 'Event', 'General'];
  final List<String> _audiences = ['all', 'teachers', 'students', 'parents'];

  String _selectedCategory = 'All';
  String _selectedAudience = 'all';
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  List<NoticeItem> _notices = [];
  bool _loading = true;
  StreamSubscription? _noticesSub;

  @override
  void initState() {
    super.initState();
    _loadNotices();
    _subscribeToFirestoreNotices();
  }

  @override
  void dispose() {
    _noticesSub?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadNotices() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('school_notices_list');
      if (raw != null && raw.isNotEmpty) {
        final List decoded = jsonDecode(raw);
        if (mounted) {
          setState(() {
            _notices = decoded.map((e) => NoticeItem.fromJson(Map<String, dynamic>.from(e))).toList();
            _loading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _notices = _getDefaultNotices();
            _loading = false;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _notices = _getDefaultNotices();
          _loading = false;
        });
      }
    }
  }

  void _subscribeToFirestoreNotices() {
    final schoolId = SessionService.instance.activeSchoolId;
    if (schoolId.isEmpty) return;

    _noticesSub?.cancel();
    _noticesSub = FirebaseFirestore.instance
        .collection('schools')
        .doc(schoolId)
        .collection('notices')
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      if (snapshot.docs.isNotEmpty) {
        final List<NoticeItem> items = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return NoticeItem.fromJson(data);
        }).toList();

        setState(() {
          _notices = items;
          _loading = false;
        });
        _cacheNoticesLocally(items);
      }
    }, onError: (e) {
      debugPrint('[NoticeScreen] Firestore subscription note: $e');
    });
  }

  Future<void> _cacheNoticesLocally(List<NoticeItem> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('school_notices_list', jsonEncode(items.map((n) => n.toJson()).toList()));
    } catch (_) {}
  }

  List<NoticeItem> _getDefaultNotices() {
    return [
      NoticeItem(
        id: '1',
        title: 'Parent-Teacher Meeting (PTM) Scheduled',
        content: 'All parents are requested to attend the PTM this Saturday at 10:00 AM to discuss term assessment and academic progress.',
        category: 'Meeting',
        targetAudience: 'parents',
        authorName: 'Principal Office',
        createdAt: DateTime.now().subtract(const Duration(hours: 4)),
        isPinned: true,
      ),
      NoticeItem(
        id: '2',
        title: 'Diwali & Chhath Puja Holidays Notice',
        content: 'The school campus will remain closed from 20th October to 28th October for Diwali & Chhath Puja festivities.',
        category: 'Holiday',
        targetAudience: 'all',
        authorName: 'Principal Office',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        isPinned: true,
      ),
      NoticeItem(
        id: '3',
        title: 'Admit Card Distribution for Annual Exam 2026',
        content: 'Students can collect their verified Admit Cards with document ID from the examination desk starting tomorrow.',
        category: 'Academic',
        targetAudience: 'students',
        authorName: 'Exam Controller',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
      NoticeItem(
        id: '4',
        title: 'URGENT: Fee Submission Reminder for Quarter 3',
        content: 'Kindly clear pending tuition and bus fees before the 15th to avoid late penalty charges.',
        category: 'Urgent',
        targetAudience: 'parents',
        authorName: 'Accounts Office',
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
      ),
    ];
  }

  Future<void> _togglePin(NoticeItem notice) async {
    final nextPinned = !notice.isPinned;
    setState(() {
      notice.isPinned = nextPinned;
    });

    final schoolId = SessionService.instance.activeSchoolId;
    if (schoolId.isNotEmpty) {
      try {
        await FirebaseFirestore.instance
            .collection('schools')
            .doc(schoolId)
            .collection('notices')
            .doc(notice.id)
            .set({'isPinned': nextPinned}, SetOptions(merge: true));
      } catch (_) {}
    }
    _cacheNoticesLocally(_notices);
  }

  Future<void> _deleteNotice(NoticeItem notice) async {
    final lang = ref.read(appLanguageProvider);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(AppTranslations.tr('delete', lang), style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          lang == 'hi'
              ? 'क्या आप इस सूचना को हटाना चाहते हैं?'
              : 'Are you sure you want to delete this notice permanently?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppTranslations.tr('cancel', lang))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: Text(AppTranslations.tr('delete', lang)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _notices.removeWhere((n) => n.id == notice.id);
    });

    final schoolId = SessionService.instance.activeSchoolId;
    if (schoolId.isNotEmpty) {
      try {
        await FirebaseFirestore.instance
            .collection('schools')
            .doc(schoolId)
            .collection('notices')
            .doc(notice.id)
            .delete();
      } catch (_) {}
    }
    _cacheNoticesLocally(_notices);
  }

  // ── Smart Multi-Pass Photo & PDF Compressor (Strictly <= 50-70 KB) ──
  Future<Map<String, dynamic>?> _compressAndPrepareAttachment(
    Uint8List rawBytes,
    String originalFileName,
    bool isPdf,
  ) async {
    final origSizeKB = (rawBytes.lengthInBytes / 1024).round();

    // 1. Handle PDF
    if (isPdf) {
      final b64 = base64Encode(rawBytes);
      return {
        'imageUrl': 'data:application/pdf;base64,$b64',
        'fileType': 'pdf',
        'fileName': originalFileName,
        'fileSize': '$origSizeKB KB',
        'originalSize': '$origSizeKB KB',
      };
    }

    // 2. Handle Image Compression (Targeting <= 50 KB)
    try {
      final decoded = img.decodeImage(rawBytes);
      if (decoded == null) return null;

      // Resize if dimension exceeds 1000px
      img.Image processed = decoded;
      if (decoded.width > 1000 || decoded.height > 1000) {
        if (decoded.width > decoded.height) {
          processed = img.copyResize(decoded, width: 1000);
        } else {
          processed = img.copyResize(decoded, height: 1000);
        }
      }

      // Adaptive quality compression loop targeting <= 55 KB
      int quality = 80;
      Uint8List jpgBytes = Uint8List.fromList(img.encodeJpg(processed, quality: quality));
      while (jpgBytes.lengthInBytes > 55 * 1024 && quality > 25) {
        quality -= 15;
        jpgBytes = Uint8List.fromList(img.encodeJpg(processed, quality: quality));
      }

      final compressedKB = (jpgBytes.lengthInBytes / 1024).round();
      final b64 = base64Encode(jpgBytes);

      return {
        'imageUrl': 'data:image/jpeg;base64,$b64',
        'fileType': 'image',
        'fileName': originalFileName,
        'fileSize': '$compressedKB KB',
        'originalSize': '$origSizeKB KB',
      };
    } catch (e) {
      debugPrint('[NoticeScreen] Compression error: $e');
      return null;
    }
  }

  void _showPublishNoticeSheet() {
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    String cat = 'General';
    String aud = 'all';
    bool pin = false;

    // Attachment State
    Map<String, dynamic>? attachmentData;
    bool isCompressing = false;

    final lang = ref.read(appLanguageProvider);
    final isPrincipal = SessionService.instance.isPrincipal;
    final authorName = isPrincipal
        ? 'Principal Office'
        : (SessionService.instance.teacherName ?? 'Teacher Office');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(3)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      AppTranslations.tr('publish_new_circular', lang),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFF0F172A)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20, color: Colors.grey),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Title
                TextField(
                  controller: titleCtrl,
                  decoration: InputDecoration(
                    labelText: AppTranslations.tr('notice_title', lang),
                    prefixIcon: const Icon(Icons.title_rounded, color: AppColors.primary, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 12),

                // Category & Audience
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: cat,
                        decoration: InputDecoration(
                          labelText: AppTranslations.tr('category', lang),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        items: _categories
                            .where((c) => c != 'All')
                            .map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13))))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setSheetState(() => cat = v);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: aud,
                        decoration: InputDecoration(
                          labelText: AppTranslations.tr('audience', lang),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        items: _audiences
                            .map((a) => DropdownMenuItem(value: a, child: Text(a.toUpperCase(), style: const TextStyle(fontSize: 13))))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setSheetState(() => aud = v);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Content
                TextField(
                  controller: contentCtrl,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: AppTranslations.tr('notice_details', lang),
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 12),

                // ── Attachment Document / Photo Section ──
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.attach_file_rounded, size: 16, color: AppColors.primary),
                              const SizedBox(width: 6),
                              Text(
                                AppTranslations.tr('attach_file', lang),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
                              ),
                            ],
                          ),
                          if (isCompressing)
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      if (attachmentData == null) ...[
                        Row(
                          children: [
                            // Gallery Image Button
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: isCompressing
                                    ? null
                                    : () async {
                                        try {
                                          final picker = ImagePicker();
                                          final picked = await picker.pickImage(source: ImageSource.gallery);
                                          if (picked == null) return;

                                          setSheetState(() => isCompressing = true);
                                          final bytes = await picked.readAsBytes();
                                          final result = await _compressAndPrepareAttachment(bytes, picked.name, false);
                                          setSheetState(() {
                                            attachmentData = result;
                                            isCompressing = false;
                                          });
                                        } catch (_) {
                                          setSheetState(() => isCompressing = false);
                                        }
                                      },
                                icon: const Icon(Icons.image_outlined, size: 16),
                                label: const Text('Image (JPG/PNG)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // PDF Document Button
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: isCompressing
                                    ? null
                                    : () async {
                                        try {
                                          final res = await FilePicker.platform.pickFiles(
                                            type: FileType.custom,
                                            allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
                                            withData: true,
                                          );
                                          if (res == null || res.files.isEmpty) return;

                                          final file = res.files.first;
                                          final bytes = file.bytes ?? (file.path != null ? await File(file.path!).readAsBytes() : null);
                                          if (bytes == null) return;

                                          setSheetState(() => isCompressing = true);
                                          final isPdf = file.name.toLowerCase().endsWith('.pdf');
                                          final result = await _compressAndPrepareAttachment(bytes, file.name, isPdf);
                                          setSheetState(() {
                                            attachmentData = result;
                                            isCompressing = false;
                                          });
                                        } catch (_) {
                                          setSheetState(() => isCompressing = false);
                                        }
                                      },
                                icon: const Icon(Icons.picture_as_pdf_outlined, size: 16, color: Colors.redAccent),
                                label: const Text('PDF Document', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Files are automatically compressed to ≤ 50 KB for instant mobile sync.',
                          style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                        ),
                      ] else ...[
                        // Attachment Preview Card
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: attachmentData!['fileType'] == 'pdf' ? Colors.red.shade50 : Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  attachmentData!['fileType'] == 'pdf' ? Icons.picture_as_pdf : Icons.image,
                                  color: attachmentData!['fileType'] == 'pdf' ? Colors.red : AppColors.primary,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      attachmentData!['fileName'] ?? 'attachment',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${attachmentData!['fileSize']} (Orig: ${attachmentData!['originalSize']})',
                                      style: const TextStyle(fontSize: 10, color: Color(0xFF10B981), fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.cancel, color: Colors.grey, size: 20),
                                onPressed: () {
                                  setSheetState(() => attachmentData = null);
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Pin switch
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(AppTranslations.tr('pin_notice_top', lang), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  value: pin,
                  onChanged: (v) => setSheetState(() => pin = v),
                ),
                const SizedBox(height: 14),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isCompressing
                        ? null
                        : () async {
                            final title = titleCtrl.text.trim();
                            if (title.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please enter a notice title')),
                              );
                              return;
                            }

                            final newNotice = NoticeItem(
                              id: 'notice_${DateTime.now().millisecondsSinceEpoch}_${(DateTime.now().microsecond % 1000)}',
                              title: title,
                              content: contentCtrl.text.trim(),
                              category: cat,
                              targetAudience: aud,
                              authorName: authorName,
                              authorRole: isPrincipal ? 'principal' : 'teacher',
                              createdAt: DateTime.now(),
                              isPinned: pin,
                              imageUrl: attachmentData?['imageUrl'],
                              fileType: attachmentData?['fileType'],
                              fileName: attachmentData?['fileName'],
                              fileSize: attachmentData?['fileSize'],
                              originalSize: attachmentData?['originalSize'],
                            );

                            setState(() {
                              _notices.insert(0, newNotice);
                            });
                            _cacheNoticesLocally(_notices);

                            // Sync to Firestore
                            final schoolId = SessionService.instance.activeSchoolId;
                            if (schoolId.isNotEmpty) {
                              try {
                                await FirebaseFirestore.instance
                                    .collection('schools')
                                    .doc(schoolId)
                                    .collection('notices')
                                    .doc(newNotice.id)
                                    .set(newNotice.toJson(), SetOptions(merge: true));
                              } catch (_) {}
                            }

                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Notice published successfully!'), backgroundColor: AppColors.success),
                            );
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A8A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(AppTranslations.tr('publish_notice', lang), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openImageZoomDialog(String base64OrUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                color: Colors.black,
                child: InteractiveViewer(
                  maxScale: 4.0,
                  child: _buildNoticeImageWidget(base64OrUrl, fit: BoxFit.contain),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareOrOpenPdf(NoticeItem notice) async {
    try {
      if (notice.imageUrl == null || !notice.imageUrl!.startsWith('data:application/pdf;base64,')) {
        return;
      }
      final rawBase64 = notice.imageUrl!.replaceFirst('data:application/pdf;base64,', '');
      final bytes = base64Decode(rawBase64);
      final dir = await getTemporaryDirectory();
      final sanitizedName = (notice.fileName?.isNotEmpty == true ? notice.fileName! : 'notice_${notice.id}.pdf')
          .replaceAll(RegExp(r'[^\w\.-]'), '_');
      final file = File('${dir.path}/$sanitizedName');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles([XFile(file.path)], text: notice.title);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening PDF: $e')),
      );
    }
  }

  Widget _buildNoticeImageWidget(String dataUri, {BoxFit fit = BoxFit.cover, double? height}) {
    try {
      if (dataUri.startsWith('data:image')) {
        final commaIdx = dataUri.indexOf(',');
        final base64Str = commaIdx != -1 ? dataUri.substring(commaIdx + 1) : dataUri;
        final bytes = base64Decode(base64Str);
        return Image.memory(bytes, fit: fit, height: height, width: double.infinity);
      } else if (dataUri.startsWith('http')) {
        return Image.network(dataUri, fit: fit, height: height, width: double.infinity);
      }
    } catch (_) {}
    return const SizedBox.shrink();
  }

  Color _getCategoryColor(String cat) {
    switch (cat.toLowerCase()) {
      case 'urgent':
        return const Color(0xFFE11D48);
      case 'holiday':
        return const Color(0xFF059669);
      case 'academic':
        return const Color(0xFF7C3AED);
      case 'meeting':
        return const Color(0xFF2563EB);
      case 'event':
        return const Color(0xFFD97706);
      default:
        return const Color(0xFF475569);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appLanguageProvider);
    final perms = ref.watch(teacherPermissionsProvider);
    final isPrincipal = SessionService.instance.isPrincipal;
    final canPostNotices = isPrincipal || perms.canPostNotices;

    final filtered = _notices.where((n) {
      if (_selectedCategory != 'All' && n.category != _selectedCategory) return false;
      if (_selectedAudience != 'all' && n.targetAudience != _selectedAudience && n.targetAudience != 'all') return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        return n.title.toLowerCase().contains(q) || n.content.toLowerCase().contains(q);
      }
      return true;
    }).toList();

    // Sort: pinned first, then by date descending
    filtered.sort((a, b) {
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;
      return b.createdAt.compareTo(a.createdAt);
    });

    final totalCount = _notices.length;
    final pinnedCount = _notices.where((n) => n.isPinned).length;
    final urgentCount = _notices.where((n) => n.category == 'Urgent').length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          AppTranslations.tr('notice_board', lang),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        elevation: 0,
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        actions: [
          if (canPostNotices)
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.white),
              tooltip: AppTranslations.tr('publish_notice', lang),
              onPressed: _showPublishNoticeSheet,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Banner like website
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1F108E), Color(0xFF0F0069)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1F108E).withValues(alpha: 0.25),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.campaign_outlined, color: Colors.white, size: 16),
                                  const SizedBox(width: 6),
                                  Text(
                                    lang == 'hi' ? 'आधिकारिक सूचना पट्ट एवं परिपत्र' : 'Official Circulars & Notice Board',
                                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatItem(AppTranslations.tr('total_notices', lang), '$totalCount'),
                            _buildStatItem(AppTranslations.tr('pinned', lang), '$pinnedCount'),
                            _buildStatItem(AppTranslations.tr('urgent', lang), '$urgentCount'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Search Bar
                  TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: lang == 'hi' ? 'सूचनाएं खोजें...' : 'Search notices by keyword...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val.trim()),
                  ),
                  const SizedBox(height: 12),

                  // Categories Horizontal Bar
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _categories.map((c) {
                        final isSel = _selectedCategory == c;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(c),
                            selected: isSel,
                            selectedColor: const Color(0xFF1E3A8A),
                            labelStyle: TextStyle(
                              color: isSel ? Colors.white : const Color(0xFF334155),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            onSelected: (val) => setState(() => _selectedCategory = c),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Notices List
                  if (filtered.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(40),
                      alignment: Alignment.center,
                      child: Column(
                        children: [
                          Icon(Icons.mark_email_read_outlined, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 10),
                          Text(
                            AppTranslations.tr('no_notices_category', lang),
                            style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filtered.length,
                      itemBuilder: (ctx, idx) {
                        final n = filtered[idx];
                        final catColor = _getCategoryColor(n.category);
                        final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(n.createdAt);
                        final hasImage = n.imageUrl != null && n.imageUrl!.isNotEmpty && (n.fileType == 'image' || n.imageUrl!.startsWith('data:image'));
                        final hasPdf = n.imageUrl != null && n.imageUrl!.isNotEmpty && (n.fileType == 'pdf' || n.imageUrl!.startsWith('data:application/pdf'));

                        return Card(
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          color: Colors.white,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: catColor.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            n.category.toUpperCase(),
                                            style: TextStyle(color: catColor, fontSize: 10, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            'FOR: ${n.targetAudience.toUpperCase()}',
                                            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.volume_up_rounded, size: 20, color: Color(0xFFD97706)),
                                          onPressed: () {
                                            VoiceAssistantService.instance.speak('स्कूल सूचना: ${n.title}। ${n.content}');
                                          },
                                          tooltip: 'बोलकर सुनें / Listen Notice',
                                        ),
                                        IconButton(
                                          icon: Icon(
                                            n.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                                            size: 18,
                                            color: n.isPinned ? const Color(0xFF1E3A8A) : Colors.grey,
                                          ),
                                          onPressed: () => _togglePin(n),
                                          tooltip: n.isPinned ? 'Unpin' : 'Pin to top',
                                        ),
                                        if (isPrincipal || canPostNotices)
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                            onPressed: () => _deleteNotice(n),
                                            tooltip: 'Delete',
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  n.title,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                                ),
                                if (n.content.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    n.content,
                                    style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.4),
                                  ),
                                ],

                                // ── Image Attachment View ──
                                if (hasImage) ...[
                                  const SizedBox(height: 10),
                                  GestureDetector(
                                    onTap: () => _openImageZoomDialog(n.imageUrl!),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Stack(
                                        alignment: Alignment.bottomRight,
                                        children: [
                                          _buildNoticeImageWidget(n.imageUrl!, height: 150),
                                          Container(
                                            margin: const EdgeInsets.all(8),
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withValues(alpha: 0.65),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.zoom_in, color: Colors.white, size: 14),
                                                SizedBox(width: 4),
                                                Text('Tap to expand', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],

                                // ── PDF Attachment View ──
                                if (hasPdf) ...[
                                  const SizedBox(height: 10),
                                  InkWell(
                                    onTap: () => _shareOrOpenPdf(n),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEF2F2),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: const Color(0xFFFECACA)),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.picture_as_pdf, color: Colors.red, size: 28),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  n.fileName?.isNotEmpty == true ? n.fileName! : 'Official Document PDF',
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF991B1B)),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  n.fileSize?.isNotEmpty == true ? '${n.fileSize} • Tap to view/share' : 'Tap to view/share PDF',
                                                  style: const TextStyle(fontSize: 10, color: Color(0xFFB91C1C)),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const Icon(Icons.share_outlined, color: Colors.red, size: 18),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],

                                const SizedBox(height: 12),
                                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.person_outline, size: 13, color: Color(0xFF64748B)),
                                        const SizedBox(width: 4),
                                        Text(n.authorName, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        const Icon(Icons.access_time_rounded, size: 13, color: Color(0xFF94A3B8)),
                                        const SizedBox(width: 4),
                                        Text(dateStr, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }
}
