import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../../data/services/session_service.dart';

class AdminTheme {
  static const Color primary = Color(0xFF6366F1); // Indigo
  static const Color primaryDark = Color(0xFF4F46E5);
  static const Color secondary = Color(0xFF0EA5E9); // Sky
  static const Color bgDark = Color(0xFF0B0F19);
  static const Color cardDark = Color(0xFF1E293B);
  static const Color surface = Color(0xFF0F172A);
  static const Color border = Color(0xFF334155);
  static const Color textMain = Color(0xFFF8FAFC);
  static const Color textMuted = Color(0xFF94A3B8);

  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
  static const Color error = Color(0xFFEF4444);
}

/// Helper to convert standard Google Drive sharing links to direct CDN image URLs
String resolveDriveImageUrl(String url) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return '';
  if (trimmed.startsWith('data:image')) return trimmed;

  // If it's a relative path like '/campus_building.jpg' or 'campus_building.jpg'
  if (trimmed.startsWith('https://mnpschool.in/')) {
    return trimmed.replaceFirst('https://mnpschool.in/', 'https://www.mnpschool.in/');
  }
  if (trimmed.startsWith('http://mnpschool.in/')) {
    return trimmed.replaceFirst('http://mnpschool.in/', 'https://www.mnpschool.in/');
  }
  if (trimmed.startsWith('/') || (!trimmed.startsWith('http://') && !trimmed.startsWith('https://'))) {
    final cleanPath = trimmed.startsWith('/') ? trimmed : '/$trimmed';
    return 'https://www.mnpschool.in$cleanPath';
  }

  if (trimmed.contains('lh3.googleusercontent.com/d/')) return trimmed;

  // Pattern 1: drive.google.com/file/d/FILE_ID
  final match1 = RegExp(r'drive\.google\.com/file/d/([a-zA-Z0-9_-]+)').firstMatch(trimmed);
  if (match1 != null && match1.group(1) != null) {
    return 'https://lh3.googleusercontent.com/d/${match1.group(1)}';
  }

  // Pattern 2: drive.google.com/open?id=FILE_ID or ?id=FILE_ID
  final match2 = RegExp(r'[?&]id=([a-zA-Z0-9_-]+)').firstMatch(trimmed);
  if (match2 != null && match2.group(1) != null && trimmed.contains('drive.google.com')) {
    return 'https://lh3.googleusercontent.com/d/${match2.group(1)}';
  }

  return trimmed;
}

/// Instant Auto-Translator between English and Hindi
Future<String> autoTranslateOnline(String text, String targetLang) async {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return '';

  final lower = trimmed.toLowerCase();
  final Map<String, String> dictEnToHi = {
    'computer project': 'कंप्यूटर प्रोजेक्ट',
    'science project': 'विज्ञान प्रोजेक्ट',
    'science exhibition': 'विज्ञान प्रदर्शनी',
    'drawing competition': 'चित्रकला प्रतियोगिता',
    'annual sports meet': 'वार्षिक खेलकूद महोत्सव',
    'campus': 'कैंपस',
    'sports': 'खेलकूद',
    'events': 'कार्यक्रम',
    'class': 'कक्षाएं',
    'projects': 'प्रोजेक्ट्स',
    'project': 'प्रोजेक्ट',
    'academics': 'शैक्षणिक',
  };

  if (targetLang == 'hi' && dictEnToHi.containsKey(lower)) {
    return dictEnToHi[lower]!;
  }

  try {
    final client = HttpClient();
    final uri = Uri.parse(
        'https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=$targetLang&dt=t&q=${Uri.encodeComponent(trimmed)}');
    final req = await client.getUrl(uri).timeout(const Duration(seconds: 4));
    final res = await req.close();
    if (res.statusCode == 200) {
      final body = await res.transform(utf8.decoder).join();
      final data = jsonDecode(body);
      if (data is List && data.isNotEmpty && data[0] is List) {
        final buf = StringBuffer();
        for (final p in (data[0] as List)) {
          if (p is List && p.isNotEmpty) buf.write(p[0].toString());
        }
        final result = buf.toString().trim();
        if (result.isNotEmpty) return result;
      }
    }
  } catch (_) {}
  return trimmed;
}

/// Universal Image renderer supporting Base64 uploads, Google Drive streams & Web URLs
Widget buildCmsImage(
  String rawUrl, {
  double? height,
  double? width,
  BoxFit fit = BoxFit.cover,
  BorderRadius? borderRadius,
  Widget? errorWidget,
}) {
  final trimmed = rawUrl.trim();
  if (trimmed.isEmpty) {
    return errorWidget ??
        Container(
          height: height,
          width: width,
          color: Colors.black26,
          child: const Center(
            child: Icon(Icons.image_outlined, color: Colors.white24, size: 28),
          ),
        );
  }

  Widget imgWidget;
  if (trimmed.startsWith('data:image')) {
    try {
      final commaIndex = trimmed.indexOf(',');
      final b64 = commaIndex != -1 ? trimmed.substring(commaIndex + 1) : trimmed;
      final bytes = base64Decode(b64);
      imgWidget = Image.memory(
        bytes,
        height: height,
        width: width,
        fit: fit,
        errorBuilder: (_, __, ___) =>
            errorWidget ??
            Container(
              height: height,
              width: width,
              color: Colors.black26,
              child: const Icon(Icons.broken_image_rounded, color: Colors.white38),
            ),
      );
    } catch (_) {
      imgWidget = errorWidget ??
          Container(
            height: height,
            width: width,
            color: Colors.black26,
            child: const Icon(Icons.broken_image_rounded, color: Colors.white38),
          );
    }
  } else {
    final directUrl = resolveDriveImageUrl(trimmed);
    imgWidget = Image.network(
      directUrl,
      height: height,
      width: width,
      fit: fit,
      errorBuilder: (_, __, ___) =>
          errorWidget ??
          Container(
            height: height,
            width: width,
            color: Colors.black26,
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.broken_image_rounded, color: Colors.white38, size: 22),
                  SizedBox(height: 4),
                  Text('Image not accessible',
                      style: TextStyle(color: Colors.white38, fontSize: 10)),
                ],
              ),
            ),
          ),
    );
  }

  if (borderRadius != null) {
    return ClipRRect(borderRadius: borderRadius, child: imgWidget);
  }
  return imgWidget;
}

class WebsiteManagerScreen extends StatefulWidget {
  final String? initialSchoolId;
  final int initialTabIndex;

  const WebsiteManagerScreen({
    super.key,
    this.initialSchoolId,
    this.initialTabIndex = 0,
  });

  @override
  State<WebsiteManagerScreen> createState() => _WebsiteManagerScreenState();
}

class _WebsiteManagerScreenState extends State<WebsiteManagerScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  late String _currentSchoolId;

  // Selected Category filter for Photo Gallery
  String _selectedGalleryCategory = 'all';

  // Default initial school photos in case Firestore has none
  static const List<Map<String, String>> defaultSchoolPhotos = [
    {
      'id': 'gal_default_1',
      'title': 'Main Campus Entrance',
      'titleHi': 'मुख्य कैंपस प्रवेश द्वार',
      'description': 'Secure entrance with official school identification',
      'descriptionHi': 'स्कूल की आधिकारिक पहचान के साथ सुरक्षित प्रवेश',
      'category': 'campus',
      'imageUrl': 'https://mnpschool.in/school_gate_banner.jpg',
      'date': 'Campus Photo',
    },
    {
      'id': 'gal_default_2',
      'title': 'Sports & Football Arena',
      'titleHi': 'खेलकूद एवं फुटबॉल मैदान',
      'description': 'Expansive open playground for athletics and football',
      'descriptionHi': 'एथलेटिक्स और फुटबॉल के लिए विशाल खुला खेल का मैदान',
      'category': 'sports',
      'imageUrl': 'https://mnpschool.in/campus_playground.jpg',
      'date': 'Sports Field',
    },
    {
      'id': 'gal_default_3',
      'title': 'Academic Building Block',
      'titleHi': 'शैक्षणिक भवन ब्लॉक',
      'description': 'Spacious, ventilated classrooms and digital study points',
      'descriptionHi': 'हवादार व बड़े क्लासरूम और डिजिटल लर्निंग पॉइंट्स',
      'category': 'campus',
      'imageUrl': 'https://mnpschool.in/campus_building.jpg',
      'date': 'Academic Wing',
    },
    {
      'id': 'gal_default_4',
      'title': 'Student Arrival & Campus Life',
      'titleHi': 'विद्यार्थी आगमन एवं कैंपस जीवन',
      'description': 'Disciplined campus gates, bicycle parking and arrival',
      'descriptionHi': 'अनुशासित कैंपस गेट, साइकिल पार्किंग और आगमन',
      'category': 'campus',
      'imageUrl': 'https://mnpschool.in/school_entrance.jpg',
      'date': 'Campus Life',
    },
  ];

  Future<void> _ensureAuth() async {
    try {
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }
    } catch (e) {
      debugPrint('[WebsiteManagerScreen] Auth note: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _ensureAuth();
    final activeId = SessionService.instance.activeSchoolId;
    _currentSchoolId = (widget.initialSchoolId != null && widget.initialSchoolId != 'all')
        ? widget.initialSchoolId!
        : (activeId.isNotEmpty ? activeId : 'SCHOOL_007');
    _tabController = TabController(
      length: 5,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 4),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<String?> _pickImageFromDevice({ImageSource source = ImageSource.gallery}) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 960,
        maxHeight: 960,
      );
      if (picked == null) return null;
      final bytes = await picked.readAsBytes();
      final base64String = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      return base64String;
    } catch (e) {
      _showSnack('Could not pick photo: $e', isError: true);
      return null;
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isError ? Icons.error_outline_rounded : Icons.check_circle_rounded,
                color: isError ? Colors.redAccent : Colors.tealAccent, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
          ],
        ),
        backgroundColor: AdminTheme.surface,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: isError ? Colors.redAccent.withValues(alpha: 0.5) : AdminTheme.border),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Website CMS & Live Control', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            Text('Campus Scope: $_currentSchoolId • Live Sync',
                style: const TextStyle(fontSize: 11, color: AdminTheme.textMuted)),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AdminTheme.success.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AdminTheme.success.withValues(alpha: 0.3)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(radius: 3.5, backgroundColor: AdminTheme.success),
                SizedBox(width: 6),
                Text('LIVE WEB', style: TextStyle(color: AdminTheme.success, fontSize: 10, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: AdminTheme.primary,
          labelColor: Colors.white,
          unselectedLabelColor: AdminTheme.textMuted,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.campaign_rounded, size: 18), text: 'Notices'),
            Tab(icon: Icon(Icons.view_carousel_rounded, size: 18), text: 'Banners & Alerts'),
            Tab(icon: Icon(Icons.photo_library_rounded, size: 18), text: 'Gallery'),
            Tab(icon: Icon(Icons.people_alt_rounded, size: 18), text: 'Leadership'),
            Tab(icon: Icon(Icons.rate_review_rounded, size: 18), text: 'Reviews'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildNoticesTab(),
          _buildBannersAndAlertsTab(),
          _buildGalleryTab(),
          _buildLeadershipTab(),
          _buildReviewsTab(),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 1: NOTICES & CIRCULARS
  // ===========================================================================
  Widget _buildNoticesTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _db
          .collection('schools')
          .doc(_currentSchoolId)
          .collection('notices')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];

        return Scaffold(
          backgroundColor: Colors.transparent,
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: AdminTheme.primary,
            icon: const Icon(Icons.add_rounded, color: Colors.white),
            label: const Text('Add Notice', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            onPressed: () => _openNoticeDialog(null),
          ),
          body: docs.isEmpty
              ? _buildEmptyState(
                  icon: Icons.campaign_rounded,
                  title: 'No Notices Published Yet',
                  subtitle: 'Create official school circulars, holiday announcements, or exam notices here.',
                  buttonLabel: 'Publish First Notice',
                  onTap: () => _openNoticeDialog(null),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (ctx, index) {
                    final doc = docs[index];
                    final data = doc.data();
                    final title = data['title'] ?? 'Untitled Notice';
                    final content = data['content'] ?? '';
                    final category = data['category'] ?? 'General';
                    final isPinned = data['isPinned'] == true;
                    final target = data['targetAudience'] ?? 'all';
                    final imageUrl = data['imageUrl'] ?? '';
                    final dateStr = data['date'] ??
                        (data['createdAt'] is Timestamp
                            ? DateFormat('dd MMM yyyy').format((data['createdAt'] as Timestamp).toDate())
                            : (data['createdAt'] ?? ''));

                    Color badgeColor;
                    switch (category.toString().toLowerCase()) {
                      case 'urgent':
                        badgeColor = Colors.redAccent;
                        break;
                      case 'holiday':
                        badgeColor = Colors.tealAccent;
                        break;
                      case 'meeting':
                        badgeColor = Colors.lightBlueAccent;
                        break;
                      case 'academic':
                        badgeColor = Colors.purpleAccent;
                        break;
                      case 'event':
                        badgeColor = Colors.amberAccent;
                        break;
                      default:
                        badgeColor = Colors.blueGrey;
                    }

                    return Container(
                      decoration: BoxDecoration(
                        color: AdminTheme.cardDark,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isPinned ? AdminTheme.warning.withValues(alpha: 0.6) : AdminTheme.border,
                          width: isPinned ? 1.5 : 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (isPinned)
                                  Container(
                                    margin: const EdgeInsets.only(right: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AdminTheme.warning.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: AdminTheme.warning.withValues(alpha: 0.4)),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.push_pin_rounded, color: AdminTheme.warning, size: 12),
                                        SizedBox(width: 4),
                                        Text('PINNED',
                                            style: TextStyle(
                                                color: AdminTheme.warning, fontSize: 10, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: badgeColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    category.toString().toUpperCase(),
                                    style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  dateStr.toString().substring(0, dateStr.toString().length > 15 ? 15 : dateStr.toString().length),
                                  style: const TextStyle(color: AdminTheme.textMuted, fontSize: 11),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(title,
                                style: const TextStyle(
                                    color: AdminTheme.textMain, fontWeight: FontWeight.bold, fontSize: 15)),
                            if (content.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(content,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: AdminTheme.textMuted, fontSize: 13, height: 1.35)),
                            ],
                            if (imageUrl.toString().isNotEmpty) ...[
                              const SizedBox(height: 10),
                              GestureDetector(
                                onTap: () => _openFullImageViewer(
                                  imageUrl: imageUrl.toString(),
                                  title: title,
                                  category: category,
                                  description: content,
                                  date: dateStr.toString(),
                                ),
                                child: buildCmsImage(
                                  imageUrl.toString(),
                                  height: 130,
                                  width: double.infinity,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(Icons.people_outline_rounded, color: AdminTheme.textMuted, size: 14),
                                const SizedBox(width: 4),
                                Text('Audience: ${target.toString().toUpperCase()}',
                                    style: const TextStyle(color: AdminTheme.textMuted, fontSize: 11)),
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(Icons.edit_rounded, color: AdminTheme.secondary, size: 18),
                                  tooltip: 'Edit Notice',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () => _openNoticeDialog(doc),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                                  tooltip: 'Delete Notice',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () => _confirmDeleteNotice(doc.id, title),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }

  void _openNoticeDialog(DocumentSnapshot<Map<String, dynamic>>? existingDoc) {
    final data = existingDoc?.data() ?? {};
    final titleCtrl = TextEditingController(text: data['title'] ?? '');
    final contentCtrl = TextEditingController(text: data['content'] ?? '');
    final imageCtrl = TextEditingController(text: data['imageUrl'] ?? '');
    String selectedCat = data['category'] ?? 'General';
    String selectedAudience = data['targetAudience'] ?? 'all';
    bool isPinned = data['isPinned'] == true;

    final categories = ['General', 'Urgent', 'Meeting', 'Holiday', 'Academic', 'Event'];
    final audiences = ['all', 'parents', 'teachers', 'students'];

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final currentImg = imageCtrl.text.trim();

          return AlertDialog(
            backgroundColor: AdminTheme.cardDark,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: AdminTheme.border),
            ),
            title: Row(
              children: [
                Icon(existingDoc != null ? Icons.edit_note_rounded : Icons.post_add_rounded,
                    color: AdminTheme.primary),
                const SizedBox(width: 8),
                Text(existingDoc != null ? 'Edit Notice' : 'Publish New Notice',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Notice Title *',
                        hintText: 'e.g. Summer Vacation Circular / Admission Notice',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: selectedCat,
                            dropdownColor: AdminTheme.cardDark,
                            decoration: const InputDecoration(labelText: 'Category'),
                            items: categories
                                .map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13))))
                                .toList(),
                            onChanged: (v) {
                              if (v != null) setDialogState(() => selectedCat = v);
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: selectedAudience,
                            dropdownColor: AdminTheme.cardDark,
                            decoration: const InputDecoration(labelText: 'Target Audience'),
                            items: audiences
                                .map((a) => DropdownMenuItem(
                                    value: a,
                                    child: Text(a.toUpperCase(), style: const TextStyle(fontSize: 13))))
                                .toList(),
                            onChanged: (v) {
                              if (v != null) setDialogState(() => selectedAudience = v);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: contentCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Detailed Notice Description',
                        hintText: 'Write announcement text, instructions, and dates here...',
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Photo Selection Section
                    const Text('Notice Attachment / Photo:',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AdminTheme.textMuted)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AdminTheme.primary.withValues(alpha: 0.25),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: const BorderSide(color: AdminTheme.primary),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.add_photo_alternate_rounded, size: 18, color: Colors.tealAccent),
                            label: const Text('Phone Gallery Se Photo Chunein',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            onPressed: () async {
                              final b64 = await _pickImageFromDevice(source: ImageSource.gallery);
                              if (b64 != null) {
                                imageCtrl.text = b64;
                                setDialogState(() {});
                                _showSnack('Photo selected from phone successfully!');
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          icon: const Icon(Icons.camera_alt_rounded, color: Colors.amberAccent, size: 20),
                          tooltip: 'Camera se click karein',
                          onPressed: () async {
                            final b64 = await _pickImageFromDevice(source: ImageSource.camera);
                            if (b64 != null) {
                              imageCtrl.text = b64;
                              setDialogState(() {});
                              _showSnack('Photo captured from camera!');
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Or Paste Drive / Web Link
                    TextField(
                      controller: imageCtrl,
                      decoration: InputDecoration(
                        labelText: 'Ya Google Drive / Web Link Paste Karein',
                        hintText: 'Paste Google Drive share link here',
                        suffixIcon: imageCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 16),
                                onPressed: () {
                                  imageCtrl.clear();
                                  setDialogState(() {});
                                },
                              )
                            : null,
                      ),
                      onChanged: (val) {
                        final converted = resolveDriveImageUrl(val);
                        if (converted != val) {
                          imageCtrl.text = converted;
                          imageCtrl.selection = TextSelection.fromPosition(TextPosition(offset: converted.length));
                          _showSnack('Drive link converted to direct image!');
                        }
                        setDialogState(() {});
                      },
                    ),

                    if (currentImg.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Stack(
                        children: [
                          buildCmsImage(
                            currentImg,
                            height: 120,
                            width: double.infinity,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          Positioned(
                            top: 6,
                            right: 6,
                            child: CircleAvatar(
                              radius: 14,
                              backgroundColor: Colors.black.withValues(alpha: 0.7),
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                icon: const Icon(Icons.close_rounded, size: 16, color: Colors.white),
                                onPressed: () {
                                  imageCtrl.clear();
                                  setDialogState(() {});
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Pin this Notice to Top',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      subtitle: const Text('Keeps this notice prominently visible at the top of the board',
                          style: TextStyle(fontSize: 11, color: AdminTheme.textMuted)),
                      value: isPinned,
                      activeThumbColor: AdminTheme.warning,
                      onChanged: (val) => setDialogState(() => isPinned = val),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Cancel', style: TextStyle(color: AdminTheme.textMuted)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () async {
                  final title = titleCtrl.text.trim();
                  if (title.isEmpty) {
                    _showSnack('Please enter notice title', isError: true);
                    return;
                  }
                  final finalImg = resolveDriveImageUrl(imageCtrl.text);

                  final docId = existingDoc?.id ?? 'notice_${DateTime.now().millisecondsSinceEpoch}';
                  final payload = {
                    'id': docId,
                    'title': title,
                    'content': contentCtrl.text.trim(),
                    'category': selectedCat,
                    'targetAudience': selectedAudience,
                    'imageUrl': finalImg,
                    'fileType': finalImg.isNotEmpty ? 'image' : '',
                    'isPinned': isPinned,
                    'authorName': 'School Administration',
                    'authorRole': 'admin',
                    'updatedAt': FieldValue.serverTimestamp(),
                  };

                  if (existingDoc == null) {
                    payload['createdAt'] = FieldValue.serverTimestamp();
                    payload['date'] = DateFormat('dd MMM yyyy').format(DateTime.now());
                  }

                  try {
                    // 1. Save in primary school subcollection
                    await _db
                        .collection('schools')
                        .doc(_currentSchoolId)
                        .collection('notices')
                        .doc(docId)
                        .set(payload, SetOptions(merge: true));

                    // 2. Also sync to SCHOOL_001 if current school is different for cross-compatibility
                    if (_currentSchoolId != 'SCHOOL_001') {
                      await _db
                          .collection('schools')
                          .doc('SCHOOL_001')
                          .collection('notices')
                          .doc(docId)
                          .set(payload, SetOptions(merge: true))
                          .catchError((_) {});
                    }

                    if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                    _showSnack(existingDoc != null ? 'Notice updated successfully!' : 'Notice published to Live Board!');
                  } catch (e) {
                    _showSnack('Error saving notice: $e', isError: true);
                  }
                },
                child: Text(existingDoc != null ? 'Save Changes' : 'Publish Notice'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDeleteNotice(String docId, String title) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AdminTheme.cardDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AdminTheme.border),
        ),
        title: const Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Delete Notice', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text('Are you sure you want to permanently delete "$title"? This will remove it from the live notice board.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AdminTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _db.collection('schools').doc(_currentSchoolId).collection('notices').doc(docId).delete();
                if (_currentSchoolId != 'SCHOOL_001') {
                  await _db.collection('schools').doc('SCHOOL_001').collection('notices').doc(docId).delete().catchError((_) {});
                }
                await _db.collection('schools').doc('SCHOOL_007').collection('notices').doc(docId).delete().catchError((_) {});
                await _db.collection('notices').doc(docId).delete().catchError((_) {});
                _showSnack('Notice deleted successfully.');
              } catch (e) {
                _showSnack('Failed to delete: $e', isError: true);
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 2: BANNERS & ALERTS (website_config)
  // ===========================================================================
  Widget _buildBannersAndAlertsTab() {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _db.collection('schoolDirectory').doc('website_config').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final config = snapshot.data?.data() ?? {};
        final banner = (config['admissionBanner'] as Map<String, dynamic>?) ?? {};
        final marquee = (config['flashNotice'] as Map<String, dynamic>?) ?? {};
        final popup = (config['popupAlert'] as Map<String, dynamic>?) ?? {};

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AdminTheme.primary.withValues(alpha: 0.25), AdminTheme.cardDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AdminTheme.primary.withValues(alpha: 0.4)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.live_tv_rounded, color: AdminTheme.primary, size: 28),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Live Website Banners & Alerts',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                          SizedBox(height: 4),
                          Text('Any changes saved here immediately update on the school website without redeployment.',
                              style: TextStyle(fontSize: 12, color: AdminTheme.textMuted)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // SECTION A: ADMISSION BANNER STUDIO
              _buildSectionCard(
                title: 'Admission Banner Studio',
                subtitle: 'Controls the prominent Admission Box on the website hero section',
                icon: Icons.school_rounded,
                color: AdminTheme.secondary,
                action: ElevatedButton.icon(
                  icon: const Icon(Icons.edit_rounded, size: 16),
                  label: const Text('Edit Banner'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AdminTheme.secondary.withValues(alpha: 0.2),
                    foregroundColor: AdminTheme.secondary,
                  ),
                  onPressed: () => _openAdmissionBannerDialog(banner),
                ),
                children: [
                  _buildConfigRow('Admissions Status',
                      banner['isAdmissionOpen'] == false ? 'CLOSED' : 'OPEN (Active)',
                      statusColor: banner['isAdmissionOpen'] == false ? Colors.redAccent : Colors.tealAccent),
                  _buildConfigRow('Headline (EN)', banner['headline'] ?? 'ADMISSIONS OPEN FOR SESSION 2026-27'),
                  _buildConfigRow('Headline (HI)', banner['headlineHi'] ?? 'सत्र 2026-27 हेतु नवीन नामांकन प्रारंभ'),
                  _buildConfigRow('Subheadline (EN)', banner['subheadline'] ?? 'Nursery to 8th • Leading English Medium School in Siwan & Mora Bazar'),
                  _buildConfigRow('Academic Session', banner['session'] ?? '2026-27'),
                  _buildConfigRow('Classes', banner['classes'] ?? 'Nursery to 8th'),
                  _buildConfigRow('Theme Style', (banner['style'] ?? 'royal_navy').toString().toUpperCase()),
                  _buildConfigRow('Helpline Phone', banner['phone'] ?? '8603481865'),
                ],
              ),
              const SizedBox(height: 16),

              // SECTION B: FLASH TICKER / BREAKING NEWS MARQUEE
              _buildSectionCard(
                title: 'Flash News Ticker / Marquee',
                subtitle: 'Top red/gold breaking news ticker scrolling at the top of the website',
                icon: Icons.campaign_rounded,
                color: Colors.amberAccent,
                action: ElevatedButton.icon(
                  icon: const Icon(Icons.edit_rounded, size: 16),
                  label: const Text('Edit Ticker'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amberAccent.withValues(alpha: 0.2),
                    foregroundColor: Colors.amberAccent,
                  ),
                  onPressed: () => _openFlashMarqueeDialog(marquee),
                ),
                children: [
                  _buildConfigRow('Status', marquee['enabled'] == true ? 'ENABLED (Visible)' : 'DISABLED (Hidden)',
                      statusColor: marquee['enabled'] == true ? Colors.tealAccent : Colors.redAccent),
                  _buildConfigRow('Badge Text', marquee['badge'] ?? 'FLASH NOTICE'),
                  _buildConfigRow('Scrolling Announcement (EN)', marquee['text'] ?? 'Admissions Open for Session 2026-27. Limited seats available.'),
                  _buildConfigRow('Scrolling Announcement (HI)', marquee['textHi'] ?? 'सत्र 2026-27 के लिए नवीन नामांकन प्रारंभ है।'),
                ],
              ),
              const SizedBox(height: 16),

              // SECTION C: EMERGENCY POPUP ALERT
              _buildSectionCard(
                title: 'Emergency Popup Alert',
                subtitle: 'Modal popup dialog that opens when visitors land on the school website',
                icon: Icons.notification_important_rounded,
                color: Colors.redAccent,
                action: ElevatedButton.icon(
                  icon: const Icon(Icons.edit_rounded, size: 16),
                  label: const Text('Edit Popup'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent.withValues(alpha: 0.2),
                    foregroundColor: Colors.redAccent,
                  ),
                  onPressed: () => _openPopupAlertDialog(popup),
                ),
                children: [
                  _buildConfigRow('Status', popup['enabled'] == true ? 'ENABLED (Showing to visitors)' : 'DISABLED (Hidden)',
                      statusColor: popup['enabled'] == true ? Colors.tealAccent : Colors.redAccent),
                  _buildConfigRow('Badge', popup['badge'] ?? 'SCHOOL ANNOUNCEMENT'),
                  _buildConfigRow('Alert Title', popup['title'] ?? 'Official Notice'),
                  _buildConfigRow('Message (EN)', popup['message'] ?? 'Admissions are now open for 2026-27.'),
                  _buildConfigRow('Action Button', popup['actionText'] ?? 'Apply Online →'),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Widget action,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AdminTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminTheme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
                      Text(subtitle, style: const TextStyle(fontSize: 11, color: AdminTheme.textMuted)),
                    ],
                  ),
                ),
                action,
              ],
            ),
            const Divider(color: AdminTheme.border, height: 24),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildConfigRow(String label, String value, {Color? statusColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: const TextStyle(color: AdminTheme.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: statusColor ?? AdminTheme.textMain,
                fontWeight: statusColor != null ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openAdmissionBannerDialog(Map<String, dynamic> current) {
    final headCtrl = TextEditingController(text: current['headline'] ?? 'ADMISSIONS OPEN FOR SESSION 2026-27');
    final headHiCtrl = TextEditingController(text: current['headlineHi'] ?? 'सत्र 2026-27 हेतु नवीन नामांकन प्रारंभ');
    final subCtrl = TextEditingController(text: current['subheadline'] ?? 'Nursery to 8th • Leading English Medium School in Siwan & Mora');
    final subHiCtrl = TextEditingController(text: current['subheadlineHi'] ?? 'सीवान एवं मोरा का अग्रणी अंग्रेजी माध्यम विद्यालय');
    final sessionCtrl = TextEditingController(text: current['session'] ?? '2026-27');
    final classesCtrl = TextEditingController(text: current['classes'] ?? 'Nursery to 8th');
    final tagCtrl = TextEditingController(text: current['tagText'] ?? 'Special Scholarship & Early Admission Offer Available');
    final phoneCtrl = TextEditingController(text: current['phone'] ?? '8603481865');
    final whatsappCtrl = TextEditingController(text: current['whatsapp'] ?? '8603481865');
    bool isOpen = current['isAdmissionOpen'] != false;
    String selectedStyle = current['style'] ?? 'royal_navy';

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AdminTheme.cardDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: AdminTheme.border)),
          title: const Text('Edit Admission Banner Studio', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Admissions Open Switch', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Enable or disable admission calls on website'),
                    value: isOpen,
                    activeThumbColor: AdminTheme.success,
                    onChanged: (v) => setDialogState(() => isOpen = v),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: selectedStyle,
                    dropdownColor: AdminTheme.cardDark,
                    decoration: const InputDecoration(labelText: 'Banner Visual Theme Style'),
                    items: const [
                      DropdownMenuItem(value: 'royal_navy', child: Text('Royal Navy & Gold (Default)')),
                      DropdownMenuItem(value: 'crimson_gold', child: Text('Crimson & Gold (Festive)')),
                      DropdownMenuItem(value: 'emerald_elite', child: Text('Emerald Elite (Nature Green)')),
                      DropdownMenuItem(value: 'modern_dark', child: Text('Modern Dark Cyber (Tech)')),
                    ],
                    onChanged: (v) {
                      if (v != null) setDialogState(() => selectedStyle = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: headCtrl, decoration: const InputDecoration(labelText: 'Headline (English)')),
                  const SizedBox(height: 10),
                  TextField(controller: headHiCtrl, decoration: const InputDecoration(labelText: 'Headline (Hindi)')),
                  const SizedBox(height: 10),
                  TextField(controller: subCtrl, decoration: const InputDecoration(labelText: 'Subheadline (English)')),
                  const SizedBox(height: 10),
                  TextField(controller: subHiCtrl, decoration: const InputDecoration(labelText: 'Subheadline (Hindi)')),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: sessionCtrl, decoration: const InputDecoration(labelText: 'Session'))),
                      const SizedBox(width: 10),
                      Expanded(child: TextField(controller: classesCtrl, decoration: const InputDecoration(labelText: 'Classes'))),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(controller: tagCtrl, decoration: const InputDecoration(labelText: 'Tagline / Offer Note')),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Helpline Phone'))),
                      const SizedBox(width: 10),
                      Expanded(child: TextField(controller: whatsappCtrl, decoration: const InputDecoration(labelText: 'WhatsApp Phone'))),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel', style: TextStyle(color: AdminTheme.textMuted))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AdminTheme.primary, foregroundColor: Colors.white),
              onPressed: () async {
                try {
                  await _db.collection('schoolDirectory').doc('website_config').set({
                    'admissionBanner': {
                      'isAdmissionOpen': isOpen,
                      'style': selectedStyle,
                      'headline': headCtrl.text.trim(),
                      'headlineHi': headHiCtrl.text.trim(),
                      'subheadline': subCtrl.text.trim(),
                      'subheadlineHi': subHiCtrl.text.trim(),
                      'session': sessionCtrl.text.trim(),
                      'classes': classesCtrl.text.trim(),
                      'tagText': tagCtrl.text.trim(),
                      'phone': phoneCtrl.text.trim(),
                      'whatsapp': whatsappCtrl.text.trim(),
                      'updatedAt': FieldValue.serverTimestamp(),
                    }
                  }, SetOptions(merge: true));
                  if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                  _showSnack('Admission banner settings updated live!');
                } catch (e) {
                  _showSnack('Error saving banner: $e', isError: true);
                }
              },
              child: const Text('Save Banner'),
            ),
          ],
        ),
      ),
    );
  }

  void _openFlashMarqueeDialog(Map<String, dynamic> current) {
    final badgeCtrl = TextEditingController(text: current['badge'] ?? 'FLASH NOTICE');
    final badgeHiCtrl = TextEditingController(text: current['badgeHi'] ?? 'नवीन सूचना');
    final textCtrl = TextEditingController(text: current['text'] ?? '📢 Admissions Open for Session 2026-27. Limited seats available.');
    final textHiCtrl = TextEditingController(text: current['textHi'] ?? '📢 सत्र 2026-27 के लिए नवीन नामांकन प्रारंभ है।');
    bool enabled = current['enabled'] == true;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AdminTheme.cardDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: AdminTheme.border)),
          title: const Text('Edit Flash News Ticker / Marquee', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Enable Flash Ticker Bar', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Shows animated scrolling bar at top of site'),
                    value: enabled,
                    activeThumbColor: Colors.amberAccent,
                    onChanged: (v) => setDialogState(() => enabled = v),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: badgeCtrl, decoration: const InputDecoration(labelText: 'Badge (English)'))),
                      const SizedBox(width: 10),
                      Expanded(child: TextField(controller: badgeHiCtrl, decoration: const InputDecoration(labelText: 'Badge (Hindi)'))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: textCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Announcement Text (English)')),
                  const SizedBox(height: 10),
                  TextField(controller: textHiCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Announcement Text (Hindi)')),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel', style: TextStyle(color: AdminTheme.textMuted))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amberAccent, foregroundColor: Colors.black),
              onPressed: () async {
                try {
                  await _db.collection('schoolDirectory').doc('website_config').set({
                    'flashNotice': {
                      'enabled': enabled,
                      'badge': badgeCtrl.text.trim(),
                      'badgeHi': badgeHiCtrl.text.trim(),
                      'text': textCtrl.text.trim(),
                      'textHi': textHiCtrl.text.trim(),
                      'updatedAt': FieldValue.serverTimestamp(),
                    }
                  }, SetOptions(merge: true));
                  if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                  _showSnack('Flash news ticker updated live!');
                } catch (e) {
                  _showSnack('Error saving ticker: $e', isError: true);
                }
              },
              child: const Text('Save Ticker', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _openPopupAlertDialog(Map<String, dynamic> current) {
    final badgeCtrl = TextEditingController(text: current['badge'] ?? 'SCHOOL ANNOUNCEMENT');
    final titleCtrl = TextEditingController(text: current['title'] ?? 'Official Notice');
    final msgCtrl = TextEditingController(text: current['message'] ?? 'Admissions are open for 2026-27.');
    final msgHiCtrl = TextEditingController(text: current['messageHi'] ?? 'सत्र 2026-27 हेतु नामांकन स्वीकार किए जा रहे हैं।');
    final actionCtrl = TextEditingController(text: current['actionText'] ?? 'Apply Online →');
    bool enabled = current['enabled'] == true;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AdminTheme.cardDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: AdminTheme.border)),
          title: const Text('Edit Emergency Popup Alert', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Enable Popup on Website', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Shows an overlay modal when visitors enter website'),
                    value: enabled,
                    activeThumbColor: Colors.redAccent,
                    onChanged: (v) => setDialogState(() => enabled = v),
                  ),
                  const SizedBox(height: 10),
                  TextField(controller: badgeCtrl, decoration: const InputDecoration(labelText: 'Popup Badge')),
                  const SizedBox(height: 10),
                  TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Popup Title')),
                  const SizedBox(height: 10),
                  TextField(controller: msgCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Message (English)')),
                  const SizedBox(height: 10),
                  TextField(controller: msgHiCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Message (Hindi)')),
                  const SizedBox(height: 10),
                  TextField(controller: actionCtrl, decoration: const InputDecoration(labelText: 'Action Button Label')),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel', style: TextStyle(color: AdminTheme.textMuted))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
              onPressed: () async {
                try {
                  await _db.collection('schoolDirectory').doc('website_config').set({
                    'popupAlert': {
                      'enabled': enabled,
                      'badge': badgeCtrl.text.trim(),
                      'title': titleCtrl.text.trim(),
                      'message': msgCtrl.text.trim(),
                      'messageHi': msgHiCtrl.text.trim(),
                      'actionText': actionCtrl.text.trim(),
                      'updatedAt': FieldValue.serverTimestamp(),
                    }
                  }, SetOptions(merge: true));
                  if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                  _showSnack('Emergency popup alert updated live!');
                } catch (e) {
                  _showSnack('Error saving popup: $e', isError: true);
                }
              },
              child: const Text('Save Popup'),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // TAB 3: PHOTO GALLERY (website_gallery)
  // ===========================================================================
  Widget _buildGalleryTab() {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _db.collection('schoolDirectory').doc('website_gallery').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final rawItems = (snapshot.data?.data()?['items'] as List<dynamic>?) ?? [];
        List<Map<String, dynamic>> items;
        if (rawItems.isNotEmpty) {
          items = List<Map<String, dynamic>>.from(rawItems.map((e) => Map<String, dynamic>.from(e as Map)));
        } else {
          // Fallback to default campus photos so photos always show!
          items = List<Map<String, dynamic>>.from(defaultSchoolPhotos);
        }

        // Dynamically collect all unique categories
        final Set<String> categoriesSet = {'all', 'campus', 'sports', 'events', 'class', 'projects'};
        for (final item in items) {
          final cat = (item['category'] ?? '').toString().trim().toLowerCase();
          if (cat.isNotEmpty) {
            categoriesSet.add(cat);
          }
        }
        final categoriesList = categoriesSet.toList();

        // Filter items according to _selectedGalleryCategory
        final filteredItems = _selectedGalleryCategory == 'all'
            ? items
            : items.where((p) => (p['category'] ?? '').toString().toLowerCase() == _selectedGalleryCategory).toList();

        return Scaffold(
          backgroundColor: Colors.transparent,
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: AdminTheme.primary,
            icon: const Icon(Icons.add_photo_alternate_rounded, color: Colors.white),
            label: const Text('Add Photo', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            onPressed: () => _openGalleryItemDialog(items, null, categoriesList),
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category Filter Bar (Like Phone Gallery / Albums)
              Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: const BoxDecoration(
                  color: AdminTheme.surface,
                  border: Border(bottom: BorderSide(color: AdminTheme.border, width: 0.8)),
                ),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: categoriesList.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (ctx, cIdx) {
                    final cat = categoriesList[cIdx];
                    final isSelected = _selectedGalleryCategory == cat;
                    final count = cat == 'all'
                        ? items.length
                        : items.where((p) => (p['category'] ?? '').toString().toLowerCase() == cat).length;

                    return FilterChip(
                      selected: isSelected,
                      showCheckmark: false,
                      label: Text(
                        '${cat.toUpperCase()} ($count)',
                        style: TextStyle(
                          color: isSelected ? Colors.white : AdminTheme.textMuted,
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        ),
                      ),
                      backgroundColor: AdminTheme.cardDark,
                      selectedColor: AdminTheme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected ? AdminTheme.primary : AdminTheme.border,
                        ),
                      ),
                      onSelected: (_) {
                        setState(() => _selectedGalleryCategory = cat);
                      },
                    );
                  },
                ),
              ),

              // Photos Grid
              Expanded(
                child: filteredItems.isEmpty
                    ? _buildEmptyState(
                        icon: Icons.photo_library_rounded,
                        title: 'No Photos in "${_selectedGalleryCategory.toUpperCase()}"',
                        subtitle: 'Tap the button below to upload photos for this category.',
                        buttonLabel: 'Add Photo',
                        onTap: () => _openGalleryItemDialog(items, null, categoriesList),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 80),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.84,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                        ),
                        itemCount: filteredItems.length,
                        itemBuilder: (ctx, idx) {
                          final photo = filteredItems[idx];
                          final title = photo['title'] ?? 'Photo';
                          final category = photo['category'] ?? 'campus';
                          final imageUrl = photo['imageUrl'] ?? photo['src'] ?? '';

                          // Find index in master list for editing
                          final photoId = (photo['id'] ?? '').toString();
                          final photoUrl = (photo['imageUrl'] ?? photo['src'] ?? '').toString();
                          final masterIndex = items.indexWhere((p) {
                            if (photoId.isNotEmpty && (p['id'] ?? '').toString() == photoId) return true;
                            if (photoUrl.isNotEmpty && (p['imageUrl'] ?? p['src'] ?? '').toString() == photoUrl) return true;
                            return false;
                          });

                          return Container(
                            decoration: BoxDecoration(
                              color: AdminTheme.cardDark,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AdminTheme.border),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Top Image - taps open full viewer
                                Expanded(
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () => _openFullImageViewer(
                                      imageUrl: imageUrl.toString(),
                                      title: title,
                                      category: category,
                                      description: photo['description'] ?? '',
                                      date: photo['date'] ?? '',
                                      onEdit: () => _openGalleryItemDialog(items, masterIndex >= 0 ? masterIndex : null, categoriesList),
                                      onDelete: () => _deleteGalleryItem(items, photo),
                                    ),
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        buildCmsImage(
                                          imageUrl.toString(),
                                          fit: BoxFit.cover,
                                        ),
                                        Positioned(
                                          top: 8,
                                          left: 8,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withValues(alpha: 0.75),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              category.toString().toUpperCase(),
                                              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          bottom: 6,
                                          right: 6,
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withValues(alpha: 0.65),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(Icons.fullscreen_rounded, color: Colors.white, size: 16),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                // Bottom Actions Row - completely independent taps!
                                Container(
                                  color: AdminTheme.cardDark,
                                  padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.edit_rounded, color: AdminTheme.secondary, size: 18),
                                        tooltip: 'Edit Photo',
                                        visualDensity: VisualDensity.compact,
                                        constraints: const BoxConstraints(),
                                        padding: const EdgeInsets.all(4),
                                        onPressed: () => _openGalleryItemDialog(items, masterIndex >= 0 ? masterIndex : null, categoriesList),
                                      ),
                                      const SizedBox(width: 4),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                                        tooltip: 'Delete Photo',
                                        visualDensity: VisualDensity.compact,
                                        constraints: const BoxConstraints(),
                                        padding: const EdgeInsets.all(4),
                                        onPressed: () => _deleteGalleryItem(items, photo),
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
        );
      },
    );
  }

  // Fullscreen Photo Viewer Dialog with Zoom & Fit Options
  void _openFullImageViewer({
    required String imageUrl,
    required String title,
    required String category,
    required String description,
    required String date,
    VoidCallback? onEdit,
    VoidCallback? onDelete,
  }) {
    bool isFitCover = false;

    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setViewerState) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(12),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            decoration: BoxDecoration(
              color: AdminTheme.cardDark,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AdminTheme.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AdminTheme.primary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AdminTheme.primary.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          category.toUpperCase(),
                          style: const TextStyle(color: AdminTheme.primary, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                      IconButton(
                        tooltip: isFitCover ? 'Fit to Screen (Full View)' : 'Fill Screen (Cover)',
                        icon: Icon(isFitCover ? Icons.fit_screen_rounded : Icons.crop_free_rounded, color: Colors.white70),
                        onPressed: () => setViewerState(() => isFitCover = !isFitCover),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white70),
                        onPressed: () => Navigator.pop(dialogCtx),
                      ),
                    ],
                  ),
                ),
                const Divider(color: AdminTheme.border, height: 1),

                // Main Image Container
                Container(
                  height: 340,
                  width: double.infinity,
                  color: Colors.black,
                  child: InteractiveViewer(
                    panEnabled: true,
                    minScale: 0.8,
                    maxScale: 3.5,
                    child: Center(
                      child: buildCmsImage(
                        imageUrl,
                        fit: isFitCover ? BoxFit.cover : BoxFit.contain,
                      ),
                    ),
                  ),
                ),

                // Details & Actions
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (description.isNotEmpty)
                        Text(description, style: const TextStyle(color: AdminTheme.textMuted, fontSize: 13, height: 1.4)),
                      if (date.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded, size: 12, color: AdminTheme.textMuted),
                            const SizedBox(width: 4),
                            Text(date, style: const TextStyle(color: AdminTheme.textMuted, fontSize: 11)),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (onEdit != null)
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AdminTheme.secondary.withValues(alpha: 0.2),
                                foregroundColor: AdminTheme.secondary,
                              ),
                              icon: const Icon(Icons.edit_rounded, size: 16),
                              label: const Text('Edit'),
                              onPressed: () {
                                Navigator.pop(dialogCtx);
                                onEdit();
                              },
                            ),
                          if (onDelete != null) ...[
                            const SizedBox(width: 10),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent.withValues(alpha: 0.2),
                                foregroundColor: Colors.redAccent,
                              ),
                              icon: const Icon(Icons.delete_outline_rounded, size: 16),
                              label: const Text('Delete'),
                              onPressed: () {
                                Navigator.pop(dialogCtx);
                                onDelete();
                              },
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openGalleryItemDialog(List<Map<String, dynamic>> allItems, int? editIndex, List<String> existingCategories) {
    final current = editIndex != null ? allItems[editIndex] : <String, dynamic>{};
    final titleCtrl = TextEditingController(text: current['title'] ?? '');
    final titleHiCtrl = TextEditingController(text: current['titleHi'] ?? '');
    final descCtrl = TextEditingController(text: current['description'] ?? '');
    final descHiCtrl = TextEditingController(text: current['descriptionHi'] ?? '');
    final imgCtrl = TextEditingController(text: current['imageUrl'] ?? current['src'] ?? '');
    final customCatCtrl = TextEditingController();

    // Default presets + existing custom categories
    final Set<String> presetCats = {
      'campus',
      'sports',
      'events',
      'class',
      'projects',
      'academics',
      'annual day',
      'competitions',
      'tours & trips',
      'exhibitions',
      ...existingCategories.where((c) => c != 'all')
    };

    String currentCategory = (current['category'] ?? 'campus').toString().toLowerCase();
    bool isCustomCat = !presetCats.contains(currentCategory);
    String selectedCat = isCustomCat ? '__custom__' : currentCategory;
    if (isCustomCat) {
      customCatCtrl.text = currentCategory;
    }

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final currentImg = imgCtrl.text.trim();

          return AlertDialog(
            backgroundColor: AdminTheme.cardDark,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: AdminTheme.border)),
            title: Text(editIndex != null ? 'Edit Gallery Photo' : 'Add Photo to Gallery',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Photo Upload from Phone Button
                    const Text('Select Photo Source:',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AdminTheme.textMuted)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AdminTheme.primary.withValues(alpha: 0.25),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: const BorderSide(color: AdminTheme.primary),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.photo_library_rounded, size: 18, color: Colors.tealAccent),
                            label: const Text('Phone Gallery Se Photo Chunein',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            onPressed: () async {
                              final b64 = await _pickImageFromDevice(source: ImageSource.gallery);
                              if (b64 != null) {
                                imgCtrl.text = b64;
                                setDialogState(() {});
                                _showSnack('Photo selected from phone successfully!');
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          icon: const Icon(Icons.camera_alt_rounded, color: Colors.amberAccent, size: 20),
                          tooltip: 'Camera se click karein',
                          onPressed: () async {
                            final b64 = await _pickImageFromDevice(source: ImageSource.camera);
                            if (b64 != null) {
                              imgCtrl.text = b64;
                              setDialogState(() {});
                              _showSnack('Photo captured from camera!');
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Or Paste Drive / Web Link
                    TextField(
                      controller: imgCtrl,
                      decoration: InputDecoration(
                        labelText: 'Ya Google Drive / Web Link Paste Karein *',
                        hintText: 'Paste Google Drive share link here',
                        suffixIcon: imgCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 16),
                                onPressed: () {
                                  imgCtrl.clear();
                                  setDialogState(() {});
                                },
                              )
                            : null,
                      ),
                      onChanged: (val) {
                        final converted = resolveDriveImageUrl(val);
                        if (converted != val) {
                          imgCtrl.text = converted;
                          imgCtrl.selection = TextSelection.fromPosition(TextPosition(offset: converted.length));
                          _showSnack('Drive link converted to direct image!');
                        }
                        setDialogState(() {});
                      },
                    ),

                    if (currentImg.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Stack(
                        children: [
                          buildCmsImage(
                            currentImg,
                            height: 130,
                            width: double.infinity,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          Positioned(
                            top: 6,
                            right: 6,
                            child: CircleAvatar(
                              radius: 14,
                              backgroundColor: Colors.black.withValues(alpha: 0.7),
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                icon: const Icon(Icons.close_rounded, size: 16, color: Colors.white),
                                onPressed: () {
                                  imgCtrl.clear();
                                  setDialogState(() {});
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 14),

                    // Category Selector + Custom Category Creator
                    DropdownButtonFormField<String>(
                      initialValue: selectedCat,
                      dropdownColor: AdminTheme.cardDark,
                      decoration: const InputDecoration(labelText: 'Photo Category'),
                      items: [
                        ...presetCats.map((c) => DropdownMenuItem(
                              value: c,
                              child: Text(c.toUpperCase(), style: const TextStyle(fontSize: 13)),
                            )),
                        const DropdownMenuItem(
                          value: '__custom__',
                          child: Row(
                            children: [
                              Icon(Icons.add_circle_outline_rounded, color: Colors.amberAccent, size: 16),
                              SizedBox(width: 8),
                              Text('+ Nayi Custom Category Banayein',
                                  style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          setDialogState(() => selectedCat = v);
                        }
                      },
                    ),

                    // Custom category input if user wants a custom category (e.g. Science Project)
                    if (selectedCat == '__custom__') ...[
                      const SizedBox(height: 10),
                      TextField(
                        controller: customCatCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Nayi Category Ka Naam Likhein *',
                          hintText: 'e.g. Science Project, Republic Day, Drawing Exhibition',
                          prefixIcon: Icon(Icons.category_rounded, color: Colors.amberAccent, size: 18),
                        ),
                      ),
                    ],

                    const SizedBox(height: 10),
                    TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Photo Title (English)')),
                    const SizedBox(height: 10),
                    TextField(controller: titleHiCtrl, decoration: const InputDecoration(labelText: 'Photo Title (Hindi)')),
                    const SizedBox(height: 10),
                    TextField(controller: descCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Description (English)')),
                    const SizedBox(height: 10),
                    TextField(controller: descHiCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Description (Hindi)')),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel', style: TextStyle(color: AdminTheme.textMuted))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AdminTheme.primary, foregroundColor: Colors.white),
                onPressed: () async {
                  final finalImg = resolveDriveImageUrl(imgCtrl.text);
                  if (finalImg.isEmpty) {
                    _showSnack('Please provide a photo or link', isError: true);
                    return;
                  }

                  String categoryToSave;
                  if (selectedCat == '__custom__') {
                    final typed = customCatCtrl.text.trim().toLowerCase();
                    if (typed.isEmpty) {
                      _showSnack('Please enter custom category name', isError: true);
                      return;
                    }
                    categoryToSave = typed;
                  } else {
                    categoryToSave = selectedCat;
                  }

                  String finalTitle = titleCtrl.text.trim();
                  String finalTitleHi = titleHiCtrl.text.trim();
                  if (finalTitle.isNotEmpty && finalTitleHi.isEmpty) {
                    finalTitleHi = await autoTranslateOnline(finalTitle, 'hi');
                  } else if (finalTitle.isEmpty && finalTitleHi.isNotEmpty) {
                    finalTitle = await autoTranslateOnline(finalTitleHi, 'en');
                  }

                  String finalDesc = descCtrl.text.trim();
                  String finalDescHi = descHiCtrl.text.trim();
                  if (finalDesc.isNotEmpty && finalDescHi.isEmpty) {
                    finalDescHi = await autoTranslateOnline(finalDesc, 'hi');
                  } else if (finalDesc.isEmpty && finalDescHi.isNotEmpty) {
                    finalDesc = await autoTranslateOnline(finalDescHi, 'en');
                  }

                  final newPhoto = {
                    'id': current['id'] ?? 'gal_${DateTime.now().millisecondsSinceEpoch}',
                    'title': finalTitle.isNotEmpty ? finalTitle : (finalTitleHi.isNotEmpty ? finalTitleHi : 'MNP School Photo'),
                    'titleEn': finalTitle,
                    'titleHi': finalTitleHi,
                    'description': finalDesc,
                    'descriptionEn': finalDesc,
                    'descriptionHi': finalDescHi,
                    'category': categoryToSave,
                    'imageUrl': finalImg,
                    'date': current['date'] ?? DateFormat('dd MMM yyyy').format(DateTime.now()),
                  };

                  final updatedList = List<Map<String, dynamic>>.from(allItems);
                  if (editIndex != null) {
                    updatedList[editIndex] = newPhoto;
                  } else {
                    updatedList.insert(0, newPhoto);
                  }

                  try {
                    await Future.wait([
  _db.collection('schoolDirectory').doc('website_gallery').set({'items': updatedList}, SetOptions(merge: true)),
  _db.collection('schools').doc('SCHOOL_007').collection('website_content').doc('gallery').set({'items': updatedList}, SetOptions(merge: true)).catchError((_) {}),
  _db.collection('schools').doc('SCHOOL_001').collection('website_content').doc('gallery').set({'items': updatedList}, SetOptions(merge: true)).catchError((_) {}),
]);
                    if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                    _showSnack(editIndex != null ? 'Gallery photo updated!' : 'New photo added to website gallery!');
                  } catch (e) {
                    _showSnack('Error saving photo: $e', isError: true);
                  }
                },
                child: Text(editIndex != null ? 'Save Changes' : 'Add to Gallery'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _deleteGalleryItem(List<Map<String, dynamic>> allItems, Map<String, dynamic> photo) {
    final photoId = (photo['id'] ?? '').toString();
    final photoTitle = (photo['title'] ?? photo['titleHi'] ?? 'Photo').toString();
    final photoUrl = (photo['imageUrl'] ?? photo['src'] ?? '').toString();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AdminTheme.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AdminTheme.border)),
        title: const Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Delete Photo', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text('Are you sure you want to remove "$photoTitle" from the website gallery?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: AdminTheme.textMuted))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(ctx);
              final updated = allItems.where((p) {
                if (photoId.isNotEmpty && (p['id'] ?? '').toString() == photoId) {
                  return false;
                }
                if (photoUrl.isNotEmpty && (p['imageUrl'] ?? p['src'] ?? '').toString() == photoUrl) {
                  return false;
                }
                if (photoId.isEmpty && photoUrl.isEmpty && (p['title'] ?? '').toString() == photoTitle) {
                  return false;
                }
                return true;
              }).toList();
              try {
                await Future.wait([
  _db.collection('schoolDirectory').doc('website_gallery').set({'items': updated}, SetOptions(merge: true)),
  _db.collection('schools').doc('SCHOOL_007').collection('website_content').doc('gallery').set({'items': updated}, SetOptions(merge: true)).catchError((_) {}),
  _db.collection('schools').doc('SCHOOL_001').collection('website_content').doc('gallery').set({'items': updated}, SetOptions(merge: true)).catchError((_) {}),
]);
                _showSnack('Photo removed from gallery.');
              } catch (e) {
                _showSnack('Error deleting photo: $e', isError: true);
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 4: LEADERSHIP & FACULTY (website_leadership)
  // ===========================================================================
  Widget _buildLeadershipTab() {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _db.collection('schoolDirectory').doc('website_leadership').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final items = List<Map<String, dynamic>>.from(
          ((snapshot.data?.data()?['items'] as List<dynamic>?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)),
        );

        return Scaffold(
          backgroundColor: Colors.transparent,
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: AdminTheme.primary,
            icon: const Icon(Icons.person_add_rounded, color: Colors.white),
            label: const Text('Add Member', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            onPressed: () => _openLeadershipDialog(items, null),
          ),
          body: items.isEmpty
              ? _buildEmptyState(
                  icon: Icons.people_alt_rounded,
                  title: 'No Leadership Profiles Added',
                  subtitle: 'Add profiles for Principal, Director, Vice-Principal, and Key Faculty.',
                  buttonLabel: 'Add First Member',
                  onTap: () => _openLeadershipDialog(items, null),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (ctx, idx) {
                    final leader = items[idx];
                    final name = leader['name'] ?? 'Faculty Member';
                    final role = leader['role'] ?? 'Role';
                    final subtitle = leader['subtitle'] ?? '';
                    final bio = leader['bio'] ?? '';
                    final photoUrl = (leader['photoUrl'] ?? leader['avatarUrl'] ?? '').toString();

                    return Container(
                      decoration: BoxDecoration(
                        color: AdminTheme.cardDark,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AdminTheme.border),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: AdminTheme.primary.withValues(alpha: 0.2),
                            child: photoUrl.isNotEmpty
                                ? ClipOval(
                                    child: buildCmsImage(
                                      photoUrl,
                                      height: 60,
                                      width: 60,
                                      fit: BoxFit.cover,
                                      errorWidget: Text(
                                        name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'M',
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: AdminTheme.primary, fontSize: 20),
                                      ),
                                    ),
                                  )
                                : Text(
                                    name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'M',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: AdminTheme.primary, fontSize: 20),
                                  ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(name,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit_rounded, color: AdminTheme.secondary, size: 18),
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () => _openLeadershipDialog(items, idx),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () => _deleteLeadershipItem(items, leader),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  margin: const EdgeInsets.only(top: 2, bottom: 6),
                                  decoration: BoxDecoration(
                                    color: AdminTheme.primary.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(role,
                                      style: const TextStyle(
                                          color: AdminTheme.primary, fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                                if (subtitle.isNotEmpty)
                                  Text(subtitle, style: const TextStyle(color: AdminTheme.textMuted, fontSize: 11)),
                                if (bio.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(bio,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: AdminTheme.textMuted, fontSize: 12)),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        );
      },
    );
  }

  void _openLeadershipDialog(List<Map<String, dynamic>> allItems, int? editIndex) {
    final current = editIndex != null ? allItems[editIndex] : <String, dynamic>{};
    final nameCtrl = TextEditingController(text: current['name'] ?? '');
    final nameHiCtrl = TextEditingController(text: current['nameHi'] ?? '');
    final roleCtrl = TextEditingController(text: current['role'] ?? '');
    final roleHiCtrl = TextEditingController(text: current['roleHi'] ?? '');
    final subCtrl = TextEditingController(text: current['subtitle'] ?? '');
    final subHiCtrl = TextEditingController(text: current['subtitleHi'] ?? '');
    final photoCtrl = TextEditingController(text: current['photoUrl'] ?? current['avatarUrl'] ?? '');
    final bioCtrl = TextEditingController(text: current['bio'] ?? '');
    final bioHiCtrl = TextEditingController(text: current['bioHi'] ?? '');
    final footerCtrl = TextEditingController(text: current['footerText'] ?? '');

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final currentPhoto = photoCtrl.text.trim();

          return AlertDialog(
            backgroundColor: AdminTheme.cardDark,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: AdminTheme.border)),
            title: Text(editIndex != null ? 'Edit Leadership Member' : 'Add Leadership Member',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Member Photo Avatar Preview & Upload
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: AdminTheme.primary.withValues(alpha: 0.2),
                          child: currentPhoto.isNotEmpty
                              ? ClipOval(
                                  child: buildCmsImage(
                                    currentPhoto,
                                    height: 60,
                                    width: 60,
                                    fit: BoxFit.cover,
                                    errorWidget: const Icon(Icons.person, color: AdminTheme.primary, size: 28),
                                  ),
                                )
                              : const Icon(Icons.person, color: AdminTheme.primary, size: 28),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AdminTheme.primary.withValues(alpha: 0.25),
                                        foregroundColor: Colors.white,
                                        side: const BorderSide(color: AdminTheme.primary),
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      icon: const Icon(Icons.photo_library_rounded, size: 16, color: Colors.tealAccent),
                                      label: const Text('Gallery Se Photo Lein', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                      onPressed: () async {
                                        final b64 = await _pickImageFromDevice(source: ImageSource.gallery);
                                        if (b64 != null) {
                                          photoCtrl.text = b64;
                                          setDialogState(() {});
                                          _showSnack('Photo selected from phone!');
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  IconButton.filledTonal(
                                    icon: const Icon(Icons.camera_alt_rounded, color: Colors.amberAccent, size: 18),
                                    tooltip: 'Camera',
                                    onPressed: () async {
                                      final b64 = await _pickImageFromDevice(source: ImageSource.camera);
                                      if (b64 != null) {
                                        photoCtrl.text = b64;
                                        setDialogState(() {});
                                        _showSnack('Photo captured!');
                                      }
                                    },
                                  ),
                                ],
                              ),
                              if (currentPhoto.isNotEmpty)
                                TextButton.icon(
                                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                                  icon: const Icon(Icons.close_rounded, size: 14, color: Colors.redAccent),
                                  label: const Text('Remove Photo', style: TextStyle(fontSize: 11, color: Colors.redAccent)),
                                  onPressed: () {
                                    photoCtrl.clear();
                                    setDialogState(() {});
                                  },
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Or Paste Drive / Web Link
                    TextField(
                      controller: photoCtrl,
                      decoration: InputDecoration(
                        labelText: 'Ya Photo URL / Google Drive Link',
                        hintText: 'Paste Google Drive share link here',
                        suffixIcon: photoCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 16),
                                onPressed: () {
                                  photoCtrl.clear();
                                  setDialogState(() {});
                                },
                              )
                            : null,
                      ),
                      onChanged: (val) {
                        final converted = resolveDriveImageUrl(val);
                        if (converted != val) {
                          photoCtrl.text = converted;
                          photoCtrl.selection = TextSelection.fromPosition(TextPosition(offset: converted.length));
                          _showSnack('Drive link converted to direct image!');
                        }
                        setDialogState(() {});
                      },
                    ),

                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name (English) *'))),
                        const SizedBox(width: 10),
                        Expanded(child: TextField(controller: nameHiCtrl, decoration: const InputDecoration(labelText: 'Name (Hindi)'))),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: roleCtrl, decoration: const InputDecoration(labelText: 'Role / Designation (EN) *'))),
                        const SizedBox(width: 10),
                        Expanded(child: TextField(controller: roleHiCtrl, decoration: const InputDecoration(labelText: 'Role (Hindi)'))),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: subCtrl, decoration: const InputDecoration(labelText: 'Subtitle / Dept (EN)'))),
                        const SizedBox(width: 10),
                        Expanded(child: TextField(controller: subHiCtrl, decoration: const InputDecoration(labelText: 'Subtitle (Hindi)'))),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(controller: bioCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Biography / Message (English)')),
                    const SizedBox(height: 10),
                    TextField(controller: bioHiCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Biography (Hindi)')),
                    const SizedBox(height: 10),
                    TextField(controller: footerCtrl, decoration: const InputDecoration(labelText: 'Footer Badge / Desk Info')),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel', style: TextStyle(color: AdminTheme.textMuted))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AdminTheme.primary, foregroundColor: Colors.white),
                onPressed: () async {
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty) {
                    _showSnack('Please enter member name', isError: true);
                    return;
                  }

                  final newMember = {
                    'id': current['id'] ?? 'lead_${DateTime.now().millisecondsSinceEpoch}',
                    'name': name,
                    'nameHi': nameHiCtrl.text.trim(),
                    'role': roleCtrl.text.trim(),
                    'roleHi': roleHiCtrl.text.trim(),
                    'subtitle': subCtrl.text.trim(),
                    'subtitleHi': subHiCtrl.text.trim(),
                    'photoUrl': resolveDriveImageUrl(photoCtrl.text),
                    'avatarUrl': resolveDriveImageUrl(photoCtrl.text),
                    'bio': bioCtrl.text.trim(),
                    'bioHi': bioHiCtrl.text.trim(),
                    'footerText': footerCtrl.text.trim(),
                  };

                  final updatedList = List<Map<String, dynamic>>.from(allItems);
                  if (editIndex != null) {
                    updatedList[editIndex] = newMember;
                  } else {
                    updatedList.add(newMember);
                  }

                  try {
                    await Future.wait([
  _db.collection('schoolDirectory').doc('website_leadership').set({'items': updatedList}, SetOptions(merge: true)),
  _db.collection('schools').doc('SCHOOL_007').collection('website_content').doc('leadership').set({'items': updatedList}, SetOptions(merge: true)).catchError((_) {}),
  _db.collection('schools').doc('SCHOOL_001').collection('website_content').doc('leadership').set({'items': updatedList}, SetOptions(merge: true)).catchError((_) {}),
]);
                    if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                    _showSnack(editIndex != null ? 'Profile updated!' : 'Leadership profile added to website!');
                  } catch (e) {
                    _showSnack('Error saving profile: $e', isError: true);
                  }
                },
                child: Text(editIndex != null ? 'Save Changes' : 'Add Member'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _deleteLeadershipItem(List<Map<String, dynamic>> allItems, Map<String, dynamic> leader) {
    final leaderId = (leader['id'] ?? '').toString();
    final leaderName = (leader['name'] ?? leader['nameHi'] ?? 'Profile').toString();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AdminTheme.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AdminTheme.border)),
        title: const Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Delete Profile', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text('Are you sure you want to remove "$leaderName" from the leadership section?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: AdminTheme.textMuted))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(ctx);
              final updated = allItems.where((l) {
                if (leaderId.isNotEmpty && (l['id'] ?? '').toString() == leaderId) {
                  return false;
                }
                if ((l['name'] ?? '').toString() == leaderName) {
                  return false;
                }
                return true;
              }).toList();
              try {
                await Future.wait([
  _db.collection('schoolDirectory').doc('website_leadership').set({'items': updated}, SetOptions(merge: true)),
  _db.collection('schools').doc('SCHOOL_007').collection('website_content').doc('leadership').set({'items': updated}, SetOptions(merge: true)).catchError((_) {}),
  _db.collection('schools').doc('SCHOOL_001').collection('website_content').doc('leadership').set({'items': updated}, SetOptions(merge: true)).catchError((_) {}),
]);
                _showSnack('Profile removed.');
              } catch (e) {
                _showSnack('Error deleting profile: $e', isError: true);
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 5: PARENT REVIEWS & RATINGS (website_reviews)
  // ===========================================================================
  Widget _buildReviewsTab() {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _db.collection('schoolDirectory').doc('website_reviews').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final items = List<Map<String, dynamic>>.from(
          ((snapshot.data?.data()?['items'] as List<dynamic>?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)),
        );

        return Scaffold(
          backgroundColor: Colors.transparent,
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: AdminTheme.primary,
            icon: const Icon(Icons.rate_review_rounded, color: Colors.white),
            label: const Text('Add Review', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            onPressed: () => _openReviewDialog(items, null),
          ),
          body: items.isEmpty
              ? _buildEmptyState(
                  icon: Icons.rate_review_rounded,
                  title: 'No Reviews Published',
                  subtitle: 'Add verified parent testimonials, feedback, and 5-star ratings for the website.',
                  buttonLabel: 'Add First Review',
                  onTap: () => _openReviewDialog(items, null),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (ctx, idx) {
                    final rev = items[idx];
                    final author = rev['authorName'] ?? 'Parent';
                    final relation = rev['relation'] ?? '';
                    final text = rev['text'] ?? '';
                    final rating = (rev['rating'] as num?)?.toInt() ?? 5;

                    return Container(
                      decoration: BoxDecoration(
                        color: AdminTheme.cardDark,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AdminTheme.border),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              ...List.generate(
                                5,
                                (sIdx) => Icon(
                                  Icons.star_rounded,
                                  size: 18,
                                  color: sIdx < rating ? Colors.amberAccent : Colors.grey.shade700,
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.edit_rounded, color: AdminTheme.secondary, size: 18),
                                visualDensity: VisualDensity.compact,
                                onPressed: () => _openReviewDialog(items, idx),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                                visualDensity: VisualDensity.compact,
                                onPressed: () => _deleteReviewItem(items, rev),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(text,
                              style: const TextStyle(
                                  color: AdminTheme.textMain, fontSize: 13, fontStyle: FontStyle.italic, height: 1.4)),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: AdminTheme.secondary.withValues(alpha: 0.2),
                                child: Text(author.isNotEmpty ? author.substring(0, 1) : 'P',
                                    style: const TextStyle(
                                        fontSize: 12, fontWeight: FontWeight.bold, color: AdminTheme.secondary)),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(author,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                                  if (relation.isNotEmpty)
                                    Text(relation,
                                        style: const TextStyle(color: AdminTheme.textMuted, fontSize: 11)),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        );
      },
    );
  }

  void _openReviewDialog(List<Map<String, dynamic>> allItems, int? editIndex) {
    final current = editIndex != null ? allItems[editIndex] : <String, dynamic>{};
    final authorCtrl = TextEditingController(text: current['authorName'] ?? '');
    final authorHiCtrl = TextEditingController(text: current['authorNameHi'] ?? '');
    final relCtrl = TextEditingController(text: current['relation'] ?? '');
    final relHiCtrl = TextEditingController(text: current['relationHi'] ?? '');
    final textCtrl = TextEditingController(text: current['text'] ?? '');
    final textHiCtrl = TextEditingController(text: current['textHi'] ?? '');
    int rating = (current['rating'] as num?)?.toInt() ?? 5;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AdminTheme.cardDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: AdminTheme.border)),
          title: Text(editIndex != null ? 'Edit Parent Review' : 'Add Parent Review',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Star Rating:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AdminTheme.textMuted)),
                  const SizedBox(height: 6),
                  Row(
                    children: List.generate(
                      5,
                      (idx) => IconButton(
                        icon: Icon(
                          Icons.star_rounded,
                          size: 28,
                          color: idx < rating ? Colors.amberAccent : Colors.grey.shade600,
                        ),
                        onPressed: () => setDialogState(() => rating = idx + 1),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: authorCtrl, decoration: const InputDecoration(labelText: 'Parent Name (EN) *'))),
                      const SizedBox(width: 10),
                      Expanded(child: TextField(controller: authorHiCtrl, decoration: const InputDecoration(labelText: 'Parent Name (HI)'))),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: relCtrl, decoration: const InputDecoration(labelText: 'Relation / Grade (EN)', hintText: 'Father of Aarav • Grade 4'))),
                      const SizedBox(width: 10),
                      Expanded(child: TextField(controller: relHiCtrl, decoration: const InputDecoration(labelText: 'Relation (HI)', hintText: 'आरव के पिता • कक्षा 4'))),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(controller: textCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Review Feedback (English) *')),
                  const SizedBox(height: 10),
                  TextField(controller: textHiCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Review Feedback (Hindi)')),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel', style: TextStyle(color: AdminTheme.textMuted))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AdminTheme.primary, foregroundColor: Colors.white),
              onPressed: () async {
                final author = authorCtrl.text.trim();
                final text = textCtrl.text.trim();
                if (author.isEmpty || text.isEmpty) {
                  _showSnack('Please fill parent name and review text', isError: true);
                  return;
                }

                final newReview = {
                  'id': current['id'] ?? 'rev_${DateTime.now().millisecondsSinceEpoch}',
                  'authorName': author,
                  'authorNameHi': authorHiCtrl.text.trim(),
                  'relation': relCtrl.text.trim(),
                  'relationHi': relHiCtrl.text.trim(),
                  'rating': rating,
                  'text': text,
                  'textHi': textHiCtrl.text.trim(),
                  'date': current['date'] ?? DateFormat('dd MMM yyyy').format(DateTime.now()),
                };

                final updatedList = List<Map<String, dynamic>>.from(allItems);
                if (editIndex != null) {
                  updatedList[editIndex] = newReview;
                } else {
                  updatedList.insert(0, newReview);
                }

                try {
                  await Future.wait([
  _db.collection('schoolDirectory').doc('website_reviews').set({'items': updatedList}, SetOptions(merge: true)),
  _db.collection('schools').doc('SCHOOL_007').collection('website_content').doc('reviews').set({'items': updatedList}, SetOptions(merge: true)).catchError((_) {}),
  _db.collection('schools').doc('SCHOOL_001').collection('website_content').doc('reviews').set({'items': updatedList}, SetOptions(merge: true)).catchError((_) {}),
]);
                  if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                  _showSnack(editIndex != null ? 'Review updated!' : 'Review published on website!');
                } catch (e) {
                  _showSnack('Error saving review: $e', isError: true);
                }
              },
              child: Text(editIndex != null ? 'Save Changes' : 'Publish Review'),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteReviewItem(List<Map<String, dynamic>> allItems, Map<String, dynamic> review) {
    final revId = (review['id'] ?? '').toString();
    final author = (review['authorName'] ?? review['authorNameHi'] ?? 'Parent').toString();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AdminTheme.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AdminTheme.border)),
        title: const Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Delete Review', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text('Are you sure you want to remove the review from "$author"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: AdminTheme.textMuted))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(ctx);
              final updated = allItems.where((r) {
                if (revId.isNotEmpty && (r['id'] ?? '').toString() == revId) {
                  return false;
                }
                if ((r['text'] ?? '').toString() == (review['text'] ?? '').toString() &&
                    (r['authorName'] ?? '').toString() == author) {
                  return false;
                }
                return true;
              }).toList();
              try {
                await Future.wait([
  _db.collection('schoolDirectory').doc('website_reviews').set({'items': updated}, SetOptions(merge: true)),
  _db.collection('schools').doc('SCHOOL_007').collection('website_content').doc('reviews').set({'items': updated}, SetOptions(merge: true)).catchError((_) {}),
  _db.collection('schools').doc('SCHOOL_001').collection('website_content').doc('reviews').set({'items': updated}, SetOptions(merge: true)).catchError((_) {}),
]);
                _showSnack('Review removed.');
              } catch (e) {
                _showSnack('Error deleting review: $e', isError: true);
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required String buttonLabel,
    required VoidCallback onTap,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AdminTheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AdminTheme.primary, size: 48),
            ),
            const SizedBox(height: 18),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.white)),
            const SizedBox(height: 6),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AdminTheme.textMuted, height: 1.4)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: onTap,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(buttonLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
