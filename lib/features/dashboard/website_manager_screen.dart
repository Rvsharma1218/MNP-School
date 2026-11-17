import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../data/services/firestore_service.dart';

/// Helper to convert standard Google Drive sharing links & relative paths to direct CDN image URLs
String resolveDriveImageUrl(String url) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return '';
  if (trimmed.startsWith('data:image')) return trimmed;

  // Rewrite apex domain to www canonical to avoid Vercel 308 redirects that break in Flutter
  if (trimmed.startsWith('https://mnpschool.in/')) {
    return trimmed.replaceFirst('https://mnpschool.in/', 'https://www.mnpschool.in/');
  }
  if (trimmed.startsWith('http://mnpschool.in/')) {
    return trimmed.replaceFirst('http://mnpschool.in/', 'https://www.mnpschool.in/');
  }

  // If it's a relative path like '/campus_building.jpg' or 'campus_building.jpg'
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
          color: const Color(0xFFF1F5F9),
          child: const Center(
            child: Icon(Icons.image_outlined, color: Colors.grey, size: 28),
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
              color: const Color(0xFFF1F5F9),
              child: const Icon(Icons.broken_image_rounded, color: Colors.grey),
            ),
      );
    } catch (_) {
      imgWidget = errorWidget ??
          Container(
            height: height,
            width: width,
            color: const Color(0xFFF1F5F9),
            child: const Icon(Icons.broken_image_rounded, color: Colors.grey),
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
            color: const Color(0xFFF1F5F9),
            child: const Center(
              child: Icon(Icons.broken_image_rounded, color: Colors.grey, size: 24),
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
  const WebsiteManagerScreen({super.key});

  @override
  State<WebsiteManagerScreen> createState() => _WebsiteManagerScreenState();
}

class _WebsiteManagerScreenState extends State<WebsiteManagerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _saving = false;

  // Selected Category filter for Photo Gallery
  String _selectedGalleryCategory = 'all';

  // Toggle between Crop (Square Cover) vs Full Photo (Fit uncropped)
  bool _isGalleryFullPhotoFit = true;

  // Default initial school photos in case Firestore has none
  static const List<Map<String, String>> defaultSchoolPhotos = [
    {
      'id': 'gal_default_1',
      'title': 'Main Campus Entrance',
      'titleHi': 'मुख्य कैंपस प्रवेश द्वार',
      'description': 'Secure entrance with official school identification',
      'descriptionHi': 'स्कूल की आधिकारिक पहचान के साथ सुरक्षित प्रवेश',
      'category': 'campus',
      'imageUrl': 'https://www.mnpschool.in/school_gate_banner.jpg',
      'date': 'Campus Photo',
    },
    {
      'id': 'gal_default_2',
      'title': 'Sports & Football Arena',
      'titleHi': 'खेलकूद एवं फुटबॉल मैदान',
      'description': 'Expansive open playground for athletics and football',
      'descriptionHi': 'एथलेटिक्स और फुटबॉल के लिए विशाल खुला खेल का मैदान',
      'category': 'sports',
      'imageUrl': 'https://www.mnpschool.in/campus_playground.jpg',
      'date': 'Sports Field',
    },
    {
      'id': 'gal_default_3',
      'title': 'Academic Building Block',
      'titleHi': 'शैक्षणिक भवन ब्लॉक',
      'description': 'Spacious, ventilated classrooms and digital study points',
      'descriptionHi': 'हवादार व बड़े क्लासरूम और डिजिटल लर्निंग पॉइंट्स',
      'category': 'campus',
      'imageUrl': 'https://www.mnpschool.in/campus_building.jpg',
      'date': 'Academic Wing',
    },
    {
      'id': 'gal_default_4',
      'title': 'Student Arrival & Campus Life',
      'titleHi': 'विद्यार्थी आगमन एवं कैंपस जीवन',
      'description': 'Disciplined campus gates, bicycle parking and arrival',
      'descriptionHi': 'अनुशासित कैंपस गेट, साइकिल पार्किंग और आगमन',
      'category': 'campus',
      'imageUrl': 'https://www.mnpschool.in/school_entrance.jpg',
      'date': 'Campus Life',
    },
  ];

  // ─── Admission Banner Form State ───────────────────────────────────────
  String _selectedBannerStyle = 'royal_navy';
  final _bannerSessionCtrl = TextEditingController(text: '2026-27');
  final _bannerClassesCtrl = TextEditingController(text: 'Nursery to 8th');
  final _bannerTagEnCtrl = TextEditingController(
      text: 'Special Scholarship & Early Admission Offer Available');
  final _bannerTagHiCtrl = TextEditingController(
      text: 'विशेष छात्रवृत्ति एवं प्रारंभिक नामांकन छूट उपलब्ध');
  final _bannerHeadlineEnCtrl =
      TextEditingController(text: 'Admissions Open for Session 2026-27');
  final _bannerHeadlineHiCtrl =
      TextEditingController(text: 'सत्र 2026-27 हेतु नवीन नामांकन प्रारंभ');
  final _bannerSubheadlineEnCtrl = TextEditingController(
      text: 'For Classes Nursery to 8th • Limited Seats Available');
  final _bannerSubheadlineHiCtrl = TextEditingController(
      text: 'कक्षा नर्सरी से 8वीं तक • सीमित सीटें उपलब्ध');
  final _bannerPhoneCtrl = TextEditingController(text: '8603481865');
  final _bannerWhatsappCtrl = TextEditingController(text: '8603481865');
  bool _isAdmissionOpen = true;
  bool _bannerLoaded = false;

  // ─── Flash Notice & Popup Form State ──────────────────────────────────
  bool _flashNoticeEnabled = true;
  final _flashNoticeBadgeEnCtrl = TextEditingController(text: 'NEW NOTICE');
  final _flashNoticeBadgeHiCtrl = TextEditingController(text: 'नवीन सूचना');
  final _flashNoticeTextEnCtrl = TextEditingController(
      text:
          '📢 Admissions Open for Session 2026-27. Limited seats available. Special Navodaya entrance prep batch. Helpline: +91 8603481865');
  final _flashNoticeTextHiCtrl = TextEditingController(
      text:
          '📢 सत्र 2026-27 के लिए नवीन नामांकन प्रारंभ है। सीमित सीटें उपलब्ध। विशेष नवोदय प्रवेश परीक्षा तैयारी बैच। संपर्क: 8603481865');

  bool _popupAlertEnabled = false;
  final _popupAlertBadgeEnCtrl = TextEditingController(text: 'ADMISSION ALERT');
  final _popupAlertBadgeHiCtrl = TextEditingController(text: 'नामांकन सूचना');
  final _popupAlertTitleEnCtrl =
      TextEditingController(text: 'Official School Announcement');
  final _popupAlertTitleHiCtrl =
      TextEditingController(text: 'विशेष विद्यालय सूचना');
  final _popupAlertMessageEnCtrl = TextEditingController(
      text:
          'Online applications are accepted for Admission in session 2026-27 from Nursery to 8th class.');
  final _popupAlertMessageHiCtrl = TextEditingController(
      text:
          'सत्र 2026-27 हेतु कक्षा नर्सरी से 8वीं तक में नामांकन हेतु ऑनलाइन आवेदन स्वीकार किए जा रहे हैं।');
  final _popupAlertActionEnCtrl =
      TextEditingController(text: 'Apply Online');
  final _popupAlertActionHiCtrl =
      TextEditingController(text: 'नामांकन फॉर्म भरें');
  bool _noticesLoaded = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _bannerSessionCtrl.dispose();
    _bannerClassesCtrl.dispose();
    _bannerTagEnCtrl.dispose();
    _bannerTagHiCtrl.dispose();
    _bannerHeadlineEnCtrl.dispose();
    _bannerHeadlineHiCtrl.dispose();
    _bannerSubheadlineEnCtrl.dispose();
    _bannerSubheadlineHiCtrl.dispose();
    _bannerPhoneCtrl.dispose();
    _bannerWhatsappCtrl.dispose();
    _flashNoticeBadgeEnCtrl.dispose();
    _flashNoticeBadgeHiCtrl.dispose();
    _flashNoticeTextEnCtrl.dispose();
    _flashNoticeTextHiCtrl.dispose();
    _popupAlertBadgeEnCtrl.dispose();
    _popupAlertBadgeHiCtrl.dispose();
    _popupAlertTitleEnCtrl.dispose();
    _popupAlertTitleHiCtrl.dispose();
    _popupAlertMessageEnCtrl.dispose();
    _popupAlertMessageHiCtrl.dispose();
    _popupAlertActionEnCtrl.dispose();
    _popupAlertActionHiCtrl.dispose();
    super.dispose();
  }

  void _populateConfigOnce(Map<String, dynamic> data) {
    if (data.isEmpty) return;
    if (!_bannerLoaded && data.containsKey('admissionBanner')) {
      final b = Map<String, dynamic>.from(data['admissionBanner'] as Map? ?? {});
      if (b.isNotEmpty) {
        _selectedBannerStyle = b['style']?.toString() ?? 'royal_navy';
        _bannerSessionCtrl.text = b['session']?.toString() ?? '2026-27';
        _bannerClassesCtrl.text = b['classes']?.toString() ?? 'Nursery to 8th';

        final rawTag = b['tagText']?.toString() ?? '';
        _bannerTagEnCtrl.text = b['tagTextEn']?.toString() ?? rawTag;
        _bannerTagHiCtrl.text = b['tagTextHi']?.toString() ?? (b['tagTextEn'] != null ? '' : rawTag);

        final rawHead = b['headline']?.toString() ?? '';
        _bannerHeadlineEnCtrl.text = b['headlineEn']?.toString() ?? rawHead;
        _bannerHeadlineHiCtrl.text = b['headlineHi']?.toString() ?? (b['headlineEn'] != null ? '' : rawHead);

        final rawSub = b['subheadline']?.toString() ?? '';
        _bannerSubheadlineEnCtrl.text = b['subheadlineEn']?.toString() ?? rawSub;
        _bannerSubheadlineHiCtrl.text = b['subheadlineHi']?.toString() ?? (b['subheadlineEn'] != null ? '' : rawSub);

        _bannerPhoneCtrl.text = b['phone']?.toString() ?? '8603481865';
        _bannerWhatsappCtrl.text = b['whatsapp']?.toString() ?? '8603481865';
        _isAdmissionOpen = b['isAdmissionOpen'] != false;
        _bannerLoaded = true;
      }
    }
    if (!_noticesLoaded) {
      if (data.containsKey('flashNotice')) {
        final f = Map<String, dynamic>.from(data['flashNotice'] as Map? ?? {});
        _flashNoticeEnabled = f['enabled'] == true;
        final rawBadge = f['badge']?.toString() ?? '';
        _flashNoticeBadgeEnCtrl.text = f['badgeEn']?.toString() ?? rawBadge;
        _flashNoticeBadgeHiCtrl.text = f['badgeHi']?.toString() ?? (f['badgeEn'] != null ? '' : rawBadge);

        final rawText = f['text']?.toString() ?? '';
        _flashNoticeTextEnCtrl.text = f['textEn']?.toString() ?? rawText;
        _flashNoticeTextHiCtrl.text = f['textHi']?.toString() ?? (f['textEn'] != null ? '' : rawText);
      }
      if (data.containsKey('popupAlert')) {
        final p = Map<String, dynamic>.from(data['popupAlert'] as Map? ?? {});
        _popupAlertEnabled = p['enabled'] == true;
        final rawBadge = p['badge']?.toString() ?? '';
        _popupAlertBadgeEnCtrl.text = p['badgeEn']?.toString() ?? rawBadge;
        _popupAlertBadgeHiCtrl.text = p['badgeHi']?.toString() ?? (p['badgeEn'] != null ? '' : rawBadge);

        final rawTitle = p['title']?.toString() ?? '';
        _popupAlertTitleEnCtrl.text = p['titleEn']?.toString() ?? rawTitle;
        _popupAlertTitleHiCtrl.text = p['titleHi']?.toString() ?? (p['titleEn'] != null ? '' : rawTitle);

        final rawMsg = p['message']?.toString() ?? '';
        _popupAlertMessageEnCtrl.text = p['messageEn']?.toString() ?? rawMsg;
        _popupAlertMessageHiCtrl.text = p['messageHi']?.toString() ?? (p['messageEn'] != null ? '' : rawMsg);

        final rawAct = p['actionText']?.toString() ?? '';
        _popupAlertActionEnCtrl.text = p['actionTextEn']?.toString() ?? rawAct;
        _popupAlertActionHiCtrl.text = p['actionTextHi']?.toString() ?? (p['actionTextEn'] != null ? '' : rawAct);
      }
      _noticesLoaded = true;
    }
  }

  // ─── Save Admission Banner ─────────────────────────────────────────────
  Future<void> _saveAdmissionBanner() async {
    setState(() => _saving = true);
    try {
      final tagEn = _bannerTagEnCtrl.text.trim();
      final tagHi = _bannerTagHiCtrl.text.trim();
      final headEn = _bannerHeadlineEnCtrl.text.trim();
      final headHi = _bannerHeadlineHiCtrl.text.trim();
      final subEn = _bannerSubheadlineEnCtrl.text.trim();
      final subHi = _bannerSubheadlineHiCtrl.text.trim();

      final config = {
        'admissionBanner': {
          'style': _selectedBannerStyle,
          'session': _bannerSessionCtrl.text.trim(),
          'classes': _bannerClassesCtrl.text.trim(),
          'tagText': tagEn.isNotEmpty ? tagEn : tagHi,
          'tagTextEn': tagEn,
          'tagTextHi': tagHi,
          'headline': headEn.isNotEmpty ? headEn : headHi,
          'headlineEn': headEn,
          'headlineHi': headHi,
          'subheadline': subEn.isNotEmpty ? subEn : subHi,
          'subheadlineEn': subEn,
          'subheadlineHi': subHi,
          'phone': _bannerPhoneCtrl.text.trim(),
          'whatsapp': _bannerWhatsappCtrl.text.trim(),
          'isAdmissionOpen': _isAdmissionOpen,
        }
      };
      await FirestoreService.instance.saveWebsiteConfig(config);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF059669),
            content: Text(
              '✅ Admission Banner live website par turant apply ho gaya!',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.red, content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ─── Save Notices & Popup ──────────────────────────────────────────────
  Future<void> _saveNotices() async {
    setState(() => _saving = true);
    try {
      final fBadgeEn = _flashNoticeBadgeEnCtrl.text.trim();
      final fBadgeHi = _flashNoticeBadgeHiCtrl.text.trim();
      final fTextEn = _flashNoticeTextEnCtrl.text.trim();
      final fTextHi = _flashNoticeTextHiCtrl.text.trim();

      final pBadgeEn = _popupAlertBadgeEnCtrl.text.trim();
      final pBadgeHi = _popupAlertBadgeHiCtrl.text.trim();
      final pTitleEn = _popupAlertTitleEnCtrl.text.trim();
      final pTitleHi = _popupAlertTitleHiCtrl.text.trim();
      final pMsgEn = _popupAlertMessageEnCtrl.text.trim();
      final pMsgHi = _popupAlertMessageHiCtrl.text.trim();
      final pActEn = _popupAlertActionEnCtrl.text.trim();
      final pActHi = _popupAlertActionHiCtrl.text.trim();

      final config = {
        'flashNotice': {
          'enabled': _flashNoticeEnabled,
          'badge': fBadgeEn.isNotEmpty ? fBadgeEn : fBadgeHi,
          'badgeEn': fBadgeEn,
          'badgeHi': fBadgeHi,
          'text': fTextEn.isNotEmpty ? fTextEn : fTextHi,
          'textEn': fTextEn,
          'textHi': fTextHi,
        },
        'popupAlert': {
          'enabled': _popupAlertEnabled,
          'badge': pBadgeEn.isNotEmpty ? pBadgeEn : pBadgeHi,
          'badgeEn': pBadgeEn,
          'badgeHi': pBadgeHi,
          'title': pTitleEn.isNotEmpty ? pTitleEn : pTitleHi,
          'titleEn': pTitleEn,
          'titleHi': pTitleHi,
          'message': pMsgEn.isNotEmpty ? pMsgEn : pMsgHi,
          'messageEn': pMsgEn,
          'messageHi': pMsgHi,
          'actionText': pActEn.isNotEmpty ? pActEn : pActHi,
          'actionTextEn': pActEn,
          'actionTextHi': pActHi,
        }
      };
      await FirestoreService.instance.saveWebsiteConfig(config);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF059669),
            content: Text(
              '✅ Top Marquee News aur Popup live website par save ho gaye!',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.red, content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>>(
      stream: FirestoreService.instance.watchWebsiteConfig(),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          _populateConfigOnce(snapshot.data!);
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            backgroundColor: const Color(0xFF0C2340),
            foregroundColor: Colors.white,
            elevation: 0,
            title: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Website CMS Control',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                Text(
                  'mnpschool.in Live Management',
                  style: TextStyle(fontSize: 11, color: Color(0xFFF4B323)),
                ),
              ],
            ),
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorColor: const Color(0xFFF4B323),
              indicatorWeight: 3,
              labelColor: const Color(0xFFF4B323),
              unselectedLabelColor: Colors.white70,
              labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              tabs: const [
                Tab(icon: Icon(Icons.palette_rounded, size: 20), text: 'Banners (6)'),
                Tab(icon: Icon(Icons.photo_library_rounded, size: 20), text: 'Gallery'),
                Tab(icon: Icon(Icons.star_rate_rounded, size: 20), text: 'Reviews'),
                Tab(icon: Icon(Icons.campaign_rounded, size: 20), text: 'Notices'),
                Tab(icon: Icon(Icons.groups_rounded, size: 20), text: 'Staff DP'),
              ],
            ),
          ),
          body: _saving
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Color(0xFF0C2340)),
                      SizedBox(height: 16),
                      Text('Live website par update ho raha hai...',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildBannerStudioTab(),
                    _buildGalleryTab(),
                    _buildReviewsTab(),
                    _buildNoticesTab(),
                    _buildStaffTab(),
                  ],
                ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 1: ADMISSION BANNER STUDIO (6 Live Interchangeable Styles)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildBannerStudioTab() {
    final styles = [
      {
        'id': 'royal_navy',
        'name': '1. Royal Navy & Gold',
        'subtitle': 'राजकीय नेवी व गोल्ड (क्लासिक प्रतिष्ठित लुक)',
        'colors': [const Color(0xFF0C2340), const Color(0xFF173A66)],
        'accent': const Color(0xFFF4B323),
        'icon': Icons.school_rounded,
      },
      {
        'id': 'festive',
        'name': '2. Festive Celebration',
        'subtitle': 'उत्सव सत्र प्रवेश (वाइब्रेंट व सेलिब्रेशन लुक)',
        'colors': [const Color(0xFF1E1B4B), const Color(0xFF4338CA)],
        'accent': const Color(0xFFF59E0B),
        'icon': Icons.celebration_rounded,
      },
      {
        'id': 'academic',
        'name': '3. Navodaya Prep',
        'subtitle': 'नवोदय प्रवेश परीक्षा व मेधावी छात्र स्पेशल',
        'colors': [const Color(0xFF082F49), const Color(0xFF0369A1)],
        'accent': const Color(0xFF38BDF8),
        'icon': Icons.emoji_events_rounded,
      },
      {
        'id': 'sports',
        'name': '4. Sports & Activity',
        'subtitle': 'खेलकूद, शारीरिक विकास व सर्वांगीण संस्कार',
        'colors': [const Color(0xFF064E3B), const Color(0xFF047857)],
        'accent': const Color(0xFF34D399),
        'icon': Icons.sports_soccer_rounded,
      },
      {
        'id': 'limited_seats',
        'name': '5. Limited Seats Alert',
        'subtitle': 'सीमित सीटें शेष (हाई अर्जेंसी व फास्ट फिलिंग)',
        'colors': [const Color(0xFF450A0A), const Color(0xFF991B1B)],
        'accent': const Color(0xFFEF4444),
        'icon': Icons.warning_amber_rounded,
      },
      {
        'id': 'minimalist',
        'name': '6. Modern Glass & Slate',
        'subtitle': 'आधुनिक स्लेट व ग्लास (इंटरनेशनल स्कूल लुक)',
        'colors': [const Color(0xFF0F172A), const Color(0xFF334155)],
        'accent': const Color(0xFF22D3EE),
        'icon': Icons.explore_rounded,
      },
    ];

    final currentStyleMeta = styles.firstWhere(
      (s) => s['id'] == _selectedBannerStyle,
      orElse: () => styles[0],
    );

    return SingleTickerProviderAndAlwaysScrollable(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Switch Card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Icon(
                    _isAdmissionOpen
                        ? Icons.check_circle_rounded
                        : Icons.cancel_rounded,
                    color: _isAdmissionOpen
                        ? const Color(0xFF059669)
                        : Colors.red,
                    size: 26,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isAdmissionOpen
                              ? 'Admission Banner: LIVE (सक्रिय)'
                              : 'Admission Banner: HIDDEN (छुपा हुआ)',
                          style: const TextStyle(
                              fontWeight: FontWeight.w900, fontSize: 14),
                        ),
                        Text(
                          _isAdmissionOpen
                              ? 'Website ke hero section par banner dikh raha hai'
                              : 'Admission band hone par banner website se gayab ho jayega',
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isAdmissionOpen,
                    activeColor: const Color(0xFF059669),
                    onChanged: (val) => setState(() => _isAdmissionOpen = val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Live Interactive Preview Box
            const Text(
              'LIVE PREVIEW (वेबसाइट पर ऐसा दिखेगा):',
              style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 0.5,
                  color: Color(0xFF0C2340)),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: currentStyleMeta['colors'] as List<Color>,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: (currentStyleMeta['accent'] as Color).withOpacity(0.6),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (currentStyleMeta['accent'] as Color).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          currentStyleMeta['icon'] as IconData,
                          color: currentStyleMeta['accent'] as Color,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _bannerHeadlineEnCtrl.text.isNotEmpty
                                  ? _bannerHeadlineEnCtrl.text
                                  : (_bannerHeadlineHiCtrl.text.isNotEmpty
                                      ? _bannerHeadlineHiCtrl.text
                                      : 'Admissions Open'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              'Session ${_bannerSessionCtrl.text} • ${_bannerClassesCtrl.text}',
                              style: TextStyle(
                                color: currentStyleMeta['accent'] as Color,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _bannerSubheadlineEnCtrl.text.isNotEmpty
                        ? _bannerSubheadlineEnCtrl.text
                        : _bannerSubheadlineHiCtrl.text,
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                  if (_bannerTagEnCtrl.text.isNotEmpty || _bannerTagHiCtrl.text.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      '✨ ${_bannerTagEnCtrl.text.isNotEmpty ? _bannerTagEnCtrl.text : _bannerTagHiCtrl.text}',
                      style: TextStyle(
                        color: currentStyleMeta['accent'] as Color,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Style Selector (6 Designs)
            const Text(
              'CHOOSE BANNER DESIGN (6 में से कोई 1 स्टाइल चुनें):',
              style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 0.5,
                  color: Color(0xFF0C2340)),
            ),
            const SizedBox(height: 10),
            ...styles.map((s) {
              final isSelected = s['id'] == _selectedBannerStyle;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF0C2340)
                        : const Color(0xFFE2E8F0),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  leading: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                          colors: s['colors'] as List<Color>),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(s['icon'] as IconData,
                        color: s['accent'] as Color, size: 20),
                  ),
                  title: Text(
                    s['name'] as String,
                    style: TextStyle(
                      fontWeight:
                          isSelected ? FontWeight.w900 : FontWeight.w700,
                      fontSize: 14,
                      color: isSelected
                          ? const Color(0xFF0C2340)
                          : const Color(0xFF1E293B),
                    ),
                  ),
                  subtitle: Text(
                    s['subtitle'] as String,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                  trailing: Radio<String>(
                    value: s['id'] as String,
                    groupValue: _selectedBannerStyle,
                    activeColor: const Color(0xFF0C2340),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedBannerStyle = val);
                    },
                  ),
                  onTap: () => setState(() => _selectedBannerStyle = s['id'] as String),
                ),
              );
            }),

            const SizedBox(height: 16),
            const Text(
              'BANNER CONTENT & TEXT (सामग्री संपादित करें):',
              style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 0.5,
                  color: Color(0xFF0C2340)),
            ),
            const SizedBox(height: 10),

            _buildInputField('Academic Session (शैक्षणिक सत्र)', _bannerSessionCtrl,
                'e.g. 2026-27'),
            _buildInputField('Eligible Classes (नामांकन कक्षाएं)',
                _bannerClassesCtrl, 'e.g. Nursery to 8th'),
            _buildInputField('Headline - English (अंग्रेजी मुख्य हेडलाइन)',
                _bannerHeadlineEnCtrl, 'e.g. Admissions Open for Session 2026-27'),
            _buildInputField('Headline - Hindi (हिन्दी हेडलाइन - वैकल्पिक)',
                _bannerHeadlineHiCtrl, 'e.g. सत्र 2026-27 हेतु नवीन नामांकन प्रारंभ'),
            _buildInputField('Subheadline - English (सब-हेडलाइन)',
                _bannerSubheadlineEnCtrl, 'e.g. For Classes Nursery to 8th • Limited Seats Available'),
            _buildInputField('Subheadline - Hindi (हिन्दी सब-हेडलाइन - वैकल्पिक)',
                _bannerSubheadlineHiCtrl, 'e.g. कक्षा नर्सरी से 8वीं तक • सीमित सीटें उपलब्ध'),
            _buildInputField('Special Offer Tag - English (ऑफर टैग)',
                _bannerTagEnCtrl, 'e.g. Special Scholarship Available (हटाने के लिए खाली छोड़ें)'),
            _buildInputField('Special Offer Tag - Hindi (हिन्दी ऑफर टैग - वैकल्पिक)',
                _bannerTagHiCtrl, 'e.g. विशेष छात्रवृत्ति एवं प्रारंभिक छूट (हटाने के लिए खाली छोड़ें)'),
            _buildInputField('Helpline Phone Number', _bannerPhoneCtrl, '8603481865',
                keyboard: TextInputType.phone),
            _buildInputField('WhatsApp Number', _bannerWhatsappCtrl, '8603481865',
                keyboard: TextInputType.phone),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0C2340),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                ),
                icon: const Icon(Icons.rocket_launch_rounded,
                    color: Color(0xFFF4B323)),
                label: const Text(
                  '🚀 Publish Banner to Live Website',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                ),
                onPressed: _saveAdmissionBanner,
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 2: LIVE PHOTO GALLERY MANAGER
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildGalleryTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FirestoreService.instance.watchWebsiteGallery(),
      builder: (context, snapshot) {
        final rawItems = snapshot.data ?? [];
        List<Map<String, dynamic>> items;
        if (rawItems.isNotEmpty) {
          items = List<Map<String, dynamic>>.from(rawItems);
        } else {
          items = List<Map<String, dynamic>>.from(defaultSchoolPhotos);
        }

        // Dynamically collect all unique categories
        final Set<String> categoriesSet = {'all', 'campus', 'sports', 'events', 'class', 'projects'};
        for (final item in items) {
          final cat = (item['category'] ?? '').toString().trim().toLowerCase();
          if (cat.isNotEmpty) categoriesSet.add(cat);
        }
        final categoriesList = categoriesSet.toList();

        // Filter items according to _selectedGalleryCategory
        final filteredItems = _selectedGalleryCategory == 'all'
            ? items
            : items.where((p) => (p['category'] ?? '').toString().toLowerCase() == _selectedGalleryCategory).toList();

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: const Color(0xFF0C2340),
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add_photo_alternate_rounded,
                color: Color(0xFFF4B323)),
            label: const Text('Add Photo',
                style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () => _showAddPhotoDialog(items, categoriesList),
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category Filter Bar (Like Phone Gallery / Albums)
              Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 0.8)),
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
                          color: isSelected ? Colors.white : const Color(0xFF0C2340),
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        ),
                      ),
                      backgroundColor: const Color(0xFFF1F5F9),
                      selectedColor: const Color(0xFF0C2340),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected ? const Color(0xFF0C2340) : const Color(0xFFCBD5E1),
                        ),
                      ),
                      onSelected: (_) {
                        setState(() => _selectedGalleryCategory = cat);
                      },
                    );
                  },
                ),
              ),

              // View & Fit Options Toolbar (Crop vs Full Photo)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 0.5)),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isGalleryFullPhotoFit ? Icons.aspect_ratio_rounded : Icons.crop_square_rounded,
                      size: 16,
                      color: const Color(0xFFF4B323),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _isGalleryFullPhotoFit
                            ? 'Full Photo (Pura Dekhein - No Crop)'
                            : 'Crop View (Card Fill / Square)',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                      ),
                    ),
                    Container(
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Row(
                        children: [
                          InkWell(
                            onTap: () => setState(() => _isGalleryFullPhotoFit = false),
                            borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: !_isGalleryFullPhotoFit ? const Color(0xFF0C2340) : Colors.transparent,
                                borderRadius: const BorderRadius.horizontal(left: Radius.circular(7)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.crop_rounded, size: 14, color: !_isGalleryFullPhotoFit ? Colors.white : const Color(0xFF64748B)),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Crop',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: !_isGalleryFullPhotoFit ? FontWeight.bold : FontWeight.normal,
                                      color: !_isGalleryFullPhotoFit ? Colors.white : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: () => setState(() => _isGalleryFullPhotoFit = true),
                            borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _isGalleryFullPhotoFit ? const Color(0xFF0C2340) : Colors.transparent,
                                borderRadius: const BorderRadius.horizontal(right: Radius.circular(7)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.fit_screen_rounded, size: 14, color: _isGalleryFullPhotoFit ? Colors.white : const Color(0xFF64748B)),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Full Photo',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: _isGalleryFullPhotoFit ? FontWeight.bold : FontWeight.normal,
                                      color: _isGalleryFullPhotoFit ? Colors.white : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Photos List / Grid
              Expanded(
                child: filteredItems.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.photo_library_outlined, size: 64, color: Colors.grey),
                              const SizedBox(height: 16),
                              Text('No Photos in "${_selectedGalleryCategory.toUpperCase()}"',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 6),
                              const Text('Neeche button dabakar is category me photo add karein.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 12, color: Colors.grey)),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0C2340),
                                  foregroundColor: Colors.white,
                                ),
                                icon: const Icon(Icons.add, color: Color(0xFFF4B323)),
                                label: const Text('Add Photo'),
                                onPressed: () => _showAddPhotoDialog(items, categoriesList),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
                        itemCount: filteredItems.length,
                        itemBuilder: (context, idx) {
                          final photo = filteredItems[idx];
                          final rawUrl = photo['imageUrl']?.toString() ?? photo['src']?.toString() ?? '';
                          final title = photo['title']?.toString() ?? photo['titleEn']?.toString() ?? 'Photo';
                          final category = (photo['category'] ?? 'campus').toString();
                          final desc = photo['description']?.toString() ?? photo['descriptionEn']?.toString() ?? '';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Row(
                              children: [
                                InkWell(
                                  onTap: () => _openFullImageViewer(
                                    imageUrl: rawUrl,
                                    title: title,
                                    category: category,
                                    description: desc,
                                  ),
                                  child: Container(
                                    width: 105,
                                    height: 100,
                                    color: Colors.black,
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        buildCmsImage(
                                          rawUrl,
                                          fit: _isGalleryFullPhotoFit ? BoxFit.contain : BoxFit.cover,
                                        ),
                                        Positioned(
                                          bottom: 4,
                                          right: 4,
                                          child: Container(
                                            padding: const EdgeInsets.all(3),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withOpacity(0.6),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(Icons.fullscreen_rounded, color: Colors.white, size: 14),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF0C2340).withOpacity(0.08),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                category.toUpperCase(),
                                                style: const TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w900,
                                                  color: Color(0xFF0C2340),
                                                ),
                                              ),
                                            ),
                                            InkWell(
                                              onTap: () => _openFullImageViewer(
                                                imageUrl: rawUrl,
                                                title: title,
                                                category: category,
                                                description: desc,
                                              ),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF0C2340).withOpacity(0.06),
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(color: const Color(0xFF0C2340).withOpacity(0.15)),
                                                ),
                                                child: const Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.visibility_rounded, size: 12, color: Color(0xFF0C2340)),
                                                    SizedBox(width: 4),
                                                    Text('View', style: TextStyle(color: Color(0xFF0C2340), fontSize: 10, fontWeight: FontWeight.bold)),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 13,
                                            color: Color(0xFF0C2340),
                                          ),
                                        ),
                                        if (desc.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            desc,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                                  tooltip: 'Delete Photo',
                                  onPressed: () => _deletePhoto(items, photo),
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
  }) {
    bool isFitCover = false;
    final TransformationController transformController = TransformationController();

    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setViewerState) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(12),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 620),
            decoration: BoxDecoration(
              color: const Color(0xFF0C2340),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF1E3A60)),
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
                          color: const Color(0xFFF4B323).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFF4B323).withOpacity(0.4)),
                        ),
                        child: Text(
                          category.toUpperCase(),
                          style: const TextStyle(color: Color(0xFFF4B323), fontWeight: FontWeight.bold, fontSize: 11),
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
                      Container(
                        height: 30,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: InkWell(
                          onTap: () => setViewerState(() => isFitCover = !isFitCover),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isFitCover ? Icons.fit_screen_rounded : Icons.crop_free_rounded,
                                color: const Color(0xFFF4B323),
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isFitCover ? 'Puri Photo' : 'Crop/Fill',
                                style: const TextStyle(color: Color(0xFFF4B323), fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white70),
                        onPressed: () => Navigator.pop(dialogCtx),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Color(0xFF1E3A60), height: 1),

                // Main Image Container with Zoom
                Stack(
                  children: [
                    Container(
                      height: 360,
                      width: double.infinity,
                      color: Colors.black,
                      child: InteractiveViewer(
                        transformationController: transformController,
                        panEnabled: true,
                        minScale: 0.8,
                        maxScale: 4.0,
                        child: Center(
                          child: buildCmsImage(
                            imageUrl,
                            fit: isFitCover ? BoxFit.cover : BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                              padding: EdgeInsets.zero,
                              icon: const Icon(Icons.zoom_in_rounded, size: 18, color: Colors.white),
                              onPressed: () {
                                final currentMatrix = transformController.value;
                                transformController.value = Matrix4.copy(currentMatrix)..scaleByDouble(1.25, 1.25, 1.0, 1.0);
                              },
                            ),
                            IconButton(
                              constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                              padding: EdgeInsets.zero,
                              icon: const Icon(Icons.zoom_out_rounded, size: 18, color: Colors.white),
                              onPressed: () {
                                final currentMatrix = transformController.value;
                                transformController.value = Matrix4.copy(currentMatrix)..scaleByDouble(0.8, 0.8, 1.0, 1.0);
                              },
                            ),
                            IconButton(
                              constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                              padding: EdgeInsets.zero,
                              icon: const Icon(Icons.restart_alt_rounded, size: 18, color: Color(0xFFF4B323)),
                              onPressed: () {
                                transformController.value = Matrix4.identity();
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                if (description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      description,
                      style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13, height: 1.4),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddPhotoDialog(List<Map<String, dynamic>> currentItems, List<String> existingCategories) {
    final titleEnCtrl = TextEditingController();
    final titleHiCtrl = TextEditingController();
    final descEnCtrl = TextEditingController();
    final descHiCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    final customCatCtrl = TextEditingController();

    final Set<String> presetCats = {
      'campus',
      'sports',
      'events',
      'class',
      'projects',
      'academics',
      'annual day',
      'competitions',
      ...existingCategories.where((c) => c != 'all')
    };

    String selectedCat = 'campus';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Add Photo to Website Gallery',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Pick From Phone Button
                  const Text('Select Photo Source:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0C2340),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.photo_library_rounded, size: 18, color: Color(0xFFF4B323)),
                          label: const Text('Phone Gallery Se Photo Chunein',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          onPressed: () async {
                            final picker = ImagePicker();
                            final xfile = await picker.pickImage(
                              source: ImageSource.gallery,
                              imageQuality: 70,
                              maxWidth: 960,
                              maxHeight: 960,
                            );
                            if (xfile != null) {
                              final bytes = await xfile.readAsBytes();
                              urlCtrl.text = 'data:image/jpeg;base64,${base64Encode(bytes)}';
                              setDlgState(() {});
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        icon: const Icon(Icons.camera_alt_rounded, color: Color(0xFF0C2340), size: 20),
                        tooltip: 'Camera',
                        onPressed: () async {
                          final picker = ImagePicker();
                          final xfile = await picker.pickImage(
                            source: ImageSource.camera,
                            imageQuality: 70,
                            maxWidth: 960,
                            maxHeight: 960,
                          );
                          if (xfile != null) {
                            final bytes = await xfile.readAsBytes();
                            urlCtrl.text = 'data:image/jpeg;base64,${base64Encode(bytes)}';
                            setDlgState(() {});
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  TextField(
                    controller: urlCtrl,
                    decoration: InputDecoration(
                      labelText: 'Ya Drive / Web Link Paste Karein *',
                      hintText: 'Paste direct link or Drive link',
                      border: const OutlineInputBorder(),
                      suffixIcon: urlCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () {
                                urlCtrl.clear();
                                setDlgState(() {});
                              },
                            )
                          : null,
                    ),
                    onChanged: (val) {
                      final converted = resolveDriveImageUrl(val);
                      if (converted != val) {
                        urlCtrl.text = converted;
                        urlCtrl.selection = TextSelection.fromPosition(TextPosition(offset: converted.length));
                      }
                      setDlgState(() {});
                    },
                  ),

                  if (urlCtrl.text.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: buildCmsImage(urlCtrl.text.trim(), height: 110, width: double.infinity),
                    ),
                  ],

                  const SizedBox(height: 12),

                  // Category Selector + Custom Category Creator
                  DropdownButtonFormField<String>(
                    initialValue: selectedCat,
                    decoration: const InputDecoration(
                      labelText: 'Photo Category',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      ...presetCats.map((c) => DropdownMenuItem(
                            value: c,
                            child: Text(c.toUpperCase(), style: const TextStyle(fontSize: 13)),
                          )),
                      const DropdownMenuItem(
                        value: '__custom__',
                        child: Row(
                          children: [
                            Icon(Icons.add_circle_outline_rounded, color: Colors.blueAccent, size: 16),
                            SizedBox(width: 8),
                            Text('+ Nayi Custom Category Banayein',
                                style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setDlgState(() => selectedCat = val);
                    },
                  ),

                  if (selectedCat == '__custom__') ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: customCatCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nayi Category Ka Naam Likhein *',
                        hintText: 'e.g. Science Project, Art Exhibition',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.category_rounded, color: Colors.blueAccent, size: 18),
                      ),
                    ),
                  ],

                  const SizedBox(height: 10),
                  TextField(
                    controller: titleEnCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Photo Title - English *',
                      hintText: 'e.g. Annual Sports Meet 2026',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: titleHiCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Photo Title - Hindi (Optional)',
                      hintText: 'e.g. वार्षिक खेलकूद प्रतियोगिता 2026',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: descEnCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Description - English',
                      hintText: 'e.g. 100m sprint race and award ceremony',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: descHiCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Description - Hindi (Optional)',
                      hintText: 'e.g. 100m दौड़ व पुरस्कार वितरण समारोह',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0C2340),
                foregroundColor: Colors.white,
              ),
              child: const Text('Add to Live Gallery'),
              onPressed: () async {
                final finalImg = resolveDriveImageUrl(urlCtrl.text);
                final titleEn = titleEnCtrl.text.trim();
                final titleHi = titleHiCtrl.text.trim();
                final descEn = descEnCtrl.text.trim();

                if (finalImg.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Kripya Photo chunein ya link paste karein')),
                  );
                  return;
                }

                String categoryToSave;
                if (selectedCat == '__custom__') {
                  final typed = customCatCtrl.text.trim().toLowerCase();
                  if (typed.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Kripya custom category ka naam likhein')),
                    );
                    return;
                  }
                  categoryToSave = typed;
                } else {
                  categoryToSave = selectedCat;
                }

                String finalTitle = titleEn.isNotEmpty ? titleEn : titleHi;
                String finalTitleHi = titleHi;
                if (finalTitle.isNotEmpty && finalTitleHi.isEmpty) {
                  finalTitleHi = await autoTranslateOnline(finalTitle, 'hi');
                } else if (finalTitle.isEmpty && finalTitleHi.isNotEmpty) {
                  finalTitle = await autoTranslateOnline(finalTitleHi, 'en');
                }

                String finalDesc = descEn;
                String finalDescHi = descHiCtrl.text.trim();
                if (finalDesc.isNotEmpty && finalDescHi.isEmpty) {
                  finalDescHi = await autoTranslateOnline(finalDesc, 'hi');
                } else if (finalDesc.isEmpty && finalDescHi.isNotEmpty) {
                  finalDesc = await autoTranslateOnline(finalDescHi, 'en');
                }

                if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                final newItem = {
                  'id': 'gal_${DateTime.now().millisecondsSinceEpoch}',
                  'title': finalTitle.isNotEmpty ? finalTitle : (finalTitleHi.isNotEmpty ? finalTitleHi : 'MNP School Photo'),
                  'titleEn': finalTitle,
                  'titleHi': finalTitleHi,
                  'description': finalDesc,
                  'descriptionEn': finalDesc,
                  'descriptionHi': finalDescHi,
                  'category': categoryToSave,
                  'imageUrl': finalImg,
                  'createdAt': DateTime.now().toIso8601String(),
                };
                final updated = List<Map<String, dynamic>>.from(currentItems)..insert(0, newItem);
                await FirestoreService.instance.saveWebsiteGallery(updated);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      backgroundColor: Color(0xFF059669),
                      content: Text('✅ Nayi Photo Gallery me add ho gayi!'),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deletePhoto(
      List<Map<String, dynamic>> currentItems, Map<String, dynamic> photo) async {
    final photoId = (photo['id'] ?? '').toString();
    final photoTitle = (photo['title'] ?? photo['titleHi'] ?? 'Photo').toString();
    final photoUrl = (photo['imageUrl'] ?? photo['src'] ?? '').toString();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Photo?'),
        content: Text(
            'Kya aap "$photoTitle" ko website gallery se hatana chahte hain?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final updated = currentItems.where((p) {
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
      await FirestoreService.instance.saveWebsiteGallery(updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo website se delete kar di gayi')),
        );
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 3: PARENT REVIEWS & RATINGS MANAGER
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildReviewsTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FirestoreService.instance.watchWebsiteReviews(),
      builder: (context, snapshot) {
        final items = snapshot.data ?? [];

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: const Color(0xFF0C2340),
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add_comment_rounded, color: Color(0xFFF4B323)),
            label: const Text('Add Review',
                style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () => _showAddReviewDialog(items),
          ),
          body: items.isEmpty
              ? const Center(child: Text('Koi Review Nahi Hai'))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  itemCount: items.length,
                  itemBuilder: (context, idx) {
                    final rev = items[idx];
                    final rating = int.tryParse(rev['rating']?.toString() ?? '5') ?? 5;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: List.generate(
                                  5,
                                  (i) => Icon(
                                    i < rating
                                        ? Icons.star_rounded
                                        : Icons.star_border_rounded,
                                    color: const Color(0xFFF59E0B),
                                    size: 18,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded,
                                    color: Colors.red, size: 20),
                                onPressed: () => _deleteReview(items, rev),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            rev['text']?.toString() ?? '',
                            style: const TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: Color(0xFF334155),
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: const Color(0xFF0C2340),
                                child: Text(
                                  (rev['authorName']?.toString() ?? 'M')
                                      .substring(0, 1)
                                      .toUpperCase(),
                                  style: const TextStyle(
                                      color: Color(0xFFF4B323),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      rev['authorName']?.toString() ?? '',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 12,
                                          color: Color(0xFF0C2340)),
                                    ),
                                    Text(
                                      rev['relation']?.toString() ?? '',
                                      style: const TextStyle(
                                          fontSize: 10, color: Color(0xFF64748B)),
                                    ),
                                  ],
                                ),
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

  void _showAddReviewDialog(List<Map<String, dynamic>> currentItems) {
    final nameEnCtrl = TextEditingController();
    final nameHiCtrl = TextEditingController();
    final relationEnCtrl = TextEditingController();
    final relationHiCtrl = TextEditingController();
    final textEnCtrl = TextEditingController();
    final textHiCtrl = TextEditingController();
    int rating = 5;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Add Parent Review (अभिभावक समीक्षा)',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameEnCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Parent / Guardian Name - English *',
                    hintText: 'e.g. Rajesh Kumar Singh',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: nameHiCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Parent Name - Hindi (Optional)',
                    hintText: 'e.g. राजेश कुमार सिंह',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: relationEnCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Student / Class Relation - English *',
                    hintText: 'e.g. Father of Aarav • Grade 4',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: relationHiCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Student Relation - Hindi (Optional)',
                    hintText: 'e.g. आरव के पिता • कक्षा 4',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Star Rating:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 4),
                Row(
                  children: List.generate(5, (i) {
                    final starIndex = i + 1;
                    return IconButton(
                      icon: Icon(
                        starIndex <= rating
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        color: const Color(0xFFF59E0B),
                        size: 32,
                      ),
                      onPressed: () => setDlgState(() => rating = starIndex),
                    );
                  }),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: textEnCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Review Feedback Text - English *',
                    hintText: 'e.g. Excellent academics, discipline and supportive teachers.',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: textHiCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Review Feedback Text - Hindi (Optional)',
                    hintText: 'e.g. स्कूल में पढ़ाई और अनुशासन दोनों बहुत बढ़िया है।',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0C2340),
                foregroundColor: Colors.white,
              ),
              child: const Text('Publish Review'),
              onPressed: () async {
                final nameEn = nameEnCtrl.text.trim();
                final nameHi = nameHiCtrl.text.trim();
                final relEn = relationEnCtrl.text.trim();
                final relHi = relationHiCtrl.text.trim();
                final textEn = textEnCtrl.text.trim();
                final textHi = textHiCtrl.text.trim();

                if ((nameEn.isEmpty && nameHi.isEmpty) || (textEn.isEmpty && textHi.isEmpty)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Kripya Name aur Review text bharein')),
                  );
                  return;
                }
                Navigator.pop(ctx);
                final newRev = {
                  'id': 'rev_${DateTime.now().millisecondsSinceEpoch}',
                  'authorName': nameEn.isNotEmpty ? nameEn : nameHi,
                  'authorNameEn': nameEn,
                  'authorNameHi': nameHi,
                  'relation': relEn.isNotEmpty ? relEn : relHi,
                  'relationEn': relEn,
                  'relationHi': relHi,
                  'rating': rating,
                  'text': textEn.isNotEmpty ? textEn : textHi,
                  'textEn': textEn,
                  'textHi': textHi,
                  'createdAt': DateTime.now().toIso8601String(),
                };
                final updated = List<Map<String, dynamic>>.from(currentItems)
                  ..insert(0, newRev);
                await FirestoreService.instance.saveWebsiteReviews(updated);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        backgroundColor: Color(0xFF059669),
                        content: Text('✅ Review website par live publish ho gaya!')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteReview(
      List<Map<String, dynamic>> currentItems, Map<String, dynamic> review) async {
    final revId = (review['id'] ?? '').toString();
    final author = (review['authorName'] ?? review['authorNameHi'] ?? 'Parent').toString();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Review?'),
        content: Text('Kya aap "$author" ka review website se hatana chahte hain?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final updated = currentItems.where((r) {
        if (revId.isNotEmpty && (r['id'] ?? '').toString() == revId) {
          return false;
        }
        if ((r['text'] ?? '').toString() == (review['text'] ?? '').toString() &&
            (r['authorName'] ?? '').toString() == author) {
          return false;
        }
        return true;
      }).toList();
      await FirestoreService.instance.saveWebsiteReviews(updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Review website se delete kar diya gaya')),
        );
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 4: FLASH MARQUEE & EMERGENCY POPUP MODAL
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildNoticesTab() {
    return SingleTickerProviderAndAlwaysScrollable(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // SECTION A: Top Flash Marquee Bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.campaign_rounded,
                              color: Color(0xFFDC2626), size: 24),
                          SizedBox(width: 8),
                          Text(
                            '1. Top Flash News Ticker (शीर्ष पट्टी)',
                            style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                color: Color(0xFF0C2340)),
                          ),
                        ],
                      ),
                      Switch(
                        value: _flashNoticeEnabled,
                        activeColor: const Color(0xFFDC2626),
                        onChanged: (val) =>
                            setState(() => _flashNoticeEnabled = val),
                      ),
                    ],
                  ),
                  const Text(
                    'Website ke sabse upar laal/amber rang me chalne wali breaking news line.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 12),
                  _buildInputField('Tag / Badge Text - English', _flashNoticeBadgeEnCtrl,
                      'e.g. FLASH NOTICE'),
                  _buildInputField('Tag / Badge Text - Hindi (Optional)', _flashNoticeBadgeHiCtrl,
                      'e.g. नवीन सूचना'),
                  _buildInputField(
                      'News Content - English', _flashNoticeTextEnCtrl,
                      'Headline text for top breaking ticker...',
                      maxLines: 2),
                  _buildInputField(
                      'News Content - Hindi (Optional)', _flashNoticeTextHiCtrl,
                      'शीर्ष पट्टी में चलने वाला समाचार हिन्दी में...',
                      maxLines: 2),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // SECTION B: Emergency Popup Modal
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.announcement_rounded,
                              color: Color(0xFFF59E0B), size: 24),
                          SizedBox(width: 8),
                          Text(
                            '2. Website Popup Alert (खुलते ही)',
                            style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                color: Color(0xFF0C2340)),
                          ),
                        ],
                      ),
                      Switch(
                        value: _popupAlertEnabled,
                        activeColor: const Color(0xFFF59E0B),
                        onChanged: (val) =>
                            setState(() => _popupAlertEnabled = val),
                      ),
                    ],
                  ),
                  const Text(
                    'Jab koi website kholega to screen ke center me popup aayega.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 12),
                  _buildInputField(
                      'Popup Badge - English', _popupAlertBadgeEnCtrl, 'e.g. ADMISSION ALERT'),
                  _buildInputField(
                      'Popup Badge - Hindi (Optional)', _popupAlertBadgeHiCtrl, 'e.g. नामांकन सूचना'),
                  _buildInputField('Popup Title - English', _popupAlertTitleEnCtrl,
                      'e.g. Official School Announcement'),
                  _buildInputField('Popup Title - Hindi (Optional)', _popupAlertTitleHiCtrl,
                      'e.g. विशेष विद्यालय सूचना'),
                  _buildInputField('Popup Message - English', _popupAlertMessageEnCtrl,
                      'Detailed notice announcement...',
                      maxLines: 3),
                  _buildInputField('Popup Message - Hindi (Optional)', _popupAlertMessageHiCtrl,
                      'विस्तृत सूचना हिन्दी में...',
                      maxLines: 3),
                  _buildInputField('Action Button Text - English', _popupAlertActionEnCtrl,
                      'e.g. Apply Online'),
                  _buildInputField('Action Button Text - Hindi (Optional)', _popupAlertActionHiCtrl,
                      'e.g. नामांकन फॉर्म भरें'),
                ],
              ),
            ),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0C2340),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                ),
                icon: const Icon(Icons.save_rounded, color: Color(0xFFF4B323)),
                label: const Text(
                  '💾 Save Notices to Live Website',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                ),
                onPressed: _saveNotices,
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 5: STAFF & LEADERSHIP TEAM (DP, Bio & Roles)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildStaffTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FirestoreService.instance.watchWebsiteLeadership(),
      builder: (context, snapshot) {
        final items = snapshot.data ?? [];

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          body: items.isEmpty
              ? const Center(child: Text('Leadership Data Load Ho Raha Hai...'))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  itemCount: items.length,
                  itemBuilder: (context, idx) {
                    final leader = items[idx];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: const Color(0xFF0C2340),
                                backgroundImage: (leader['avatarUrl'] != null &&
                                        leader['avatarUrl'].toString().isNotEmpty)
                                    ? NetworkImage(leader['avatarUrl'].toString())
                                    : null,
                                child: (leader['avatarUrl'] == null ||
                                        leader['avatarUrl'].toString().isEmpty)
                                    ? Text(
                                        leader['avatarText']?.toString() ??
                                            leader['name']
                                                ?.toString()
                                                .substring(0, 2) ??
                                            'MN',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w900),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      leader['name']?.toString() ?? '',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 15,
                                          color: Color(0xFF0C2340)),
                                    ),
                                    Text(
                                      leader['role']?.toString() ?? '',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF0284C7)),
                                    ),
                                    Text(
                                      leader['subtitle']?.toString() ?? '',
                                      style: const TextStyle(
                                          fontSize: 11, color: Color(0xFF64748B)),
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0C2340),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                ),
                                child: const Text('Edit DP & Bio',
                                    style: TextStyle(fontSize: 12)),
                                onPressed: () =>
                                    _showEditLeaderDialog(items, idx),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            leader['bio']?.toString() ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xFF475569)),
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

  void _showEditLeaderDialog(
      List<Map<String, dynamic>> currentItems, int index) {
    final leader = currentItems[index];
    final nameCtrl = TextEditingController(text: leader['name']?.toString() ?? '');
    final roleCtrl = TextEditingController(text: leader['role']?.toString() ?? '');
    final subCtrl = TextEditingController(text: leader['subtitle']?.toString() ?? '');
    final dpUrlCtrl = TextEditingController(text: leader['avatarUrl']?.toString() ?? '');
    final bioCtrl = TextEditingController(text: leader['bio']?.toString() ?? '');

    final keyRoles = (leader['keyRoles'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();
    final r1Ctrl = TextEditingController(text: keyRoles.isNotEmpty ? keyRoles[0] : '');
    final r2Ctrl = TextEditingController(text: keyRoles.length > 1 ? keyRoles[1] : '');
    final r3Ctrl = TextEditingController(text: keyRoles.length > 2 ? keyRoles[2] : '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Edit ${leader['name']} Details',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                    labelText: 'Name *', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: roleCtrl,
                decoration: const InputDecoration(
                    labelText: 'Designation / Post *', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: subCtrl,
                decoration: const InputDecoration(
                    labelText: 'Subtitle', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: dpUrlCtrl,
                decoration: const InputDecoration(
                    labelText: 'DP Photo URL',
                    hintText: 'https://... ya /staff.jpg',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 6),
              TextButton.icon(
                icon: const Icon(Icons.photo_camera_rounded, size: 18),
                label: const Text('Phone se Photo Chunein'),
                onPressed: () async {
                  final picker = ImagePicker();
                  final xfile = await picker.pickImage(source: ImageSource.gallery);
                  if (xfile != null) {
                    dpUrlCtrl.text = xfile.path;
                  }
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: bioCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                    labelText: 'Bio / Description *', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              const Text('3 Key Responsibilities (मुख्य जिम्मेदारियां):',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
              const SizedBox(height: 6),
              TextField(
                controller: r1Ctrl,
                decoration: const InputDecoration(
                    labelText: 'Role 1', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: r2Ctrl,
                decoration: const InputDecoration(
                    labelText: 'Role 2', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: r3Ctrl,
                decoration: const InputDecoration(
                    labelText: 'Role 3', border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0C2340),
              foregroundColor: Colors.white,
            ),
            child: const Text('Save to Live Website'),
            onPressed: () async {
              Navigator.pop(ctx);
              final updatedLeader = Map<String, dynamic>.from(leader);
              updatedLeader['name'] = nameCtrl.text.trim();
              updatedLeader['role'] = roleCtrl.text.trim();
              updatedLeader['subtitle'] = subCtrl.text.trim();
              updatedLeader['avatarUrl'] = dpUrlCtrl.text.trim();
              updatedLeader['bio'] = bioCtrl.text.trim();
              updatedLeader['keyRoles'] = [
                r1Ctrl.text.trim(),
                r2Ctrl.text.trim(),
                r3Ctrl.text.trim(),
              ].where((r) => r.isNotEmpty).toList();

              final updatedList = List<Map<String, dynamic>>.from(currentItems);
              updatedList[index] = updatedLeader;
              await FirestoreService.instance.saveWebsiteLeadership(updatedList);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      backgroundColor: Color(0xFF059669),
                      content: Text('✅ Staff details website par live update ho gayi!')),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  // ─── Input Field Helper ────────────────────────────────────────────────
  Widget _buildInputField(
      String label, TextEditingController ctrl, String hint,
      {int maxLines = 1, TextInputType keyboard = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Color(0xFF334155)),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: ctrl,
            maxLines: maxLines,
            keyboardType: keyboard,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
              filled: true,
              fillColor: Colors.white,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: Color(0xFF0C2340), width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SingleTickerProviderAndAlwaysScrollable extends StatelessWidget {
  final Widget child;
  const SingleTickerProviderAndAlwaysScrollable({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: child,
    );
  }
}
