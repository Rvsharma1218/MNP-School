import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../data/services/firestore_service.dart';

class WebsiteManagerScreen extends StatefulWidget {
  const WebsiteManagerScreen({super.key});

  @override
  State<WebsiteManagerScreen> createState() => _WebsiteManagerScreenState();
}

class _WebsiteManagerScreenState extends State<WebsiteManagerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _saving = false;

  // ─── Admission Banner Form State ───────────────────────────────────────
  String _selectedBannerStyle = 'royal_navy';
  final _bannerSessionCtrl = TextEditingController(text: '2026-27');
  final _bannerClassesCtrl = TextEditingController(text: 'Nursery to 8th');
  final _bannerTagCtrl = TextEditingController(
      text: 'विशेष छात्रवृत्ति एवं प्रारंभिक नामांकन छूट उपलब्ध');
  final _bannerHeadlineCtrl = TextEditingController(
      text: 'सत्र 2026-27 हेतु नवीन नामांकन प्रारंभ');
  final _bannerSubheadlineCtrl = TextEditingController(
      text: 'For Classes Nursery to 8th • Limited Seats Available');
  final _bannerPhoneCtrl = TextEditingController(text: '8603481865');
  final _bannerWhatsappCtrl = TextEditingController(text: '8603481865');
  bool _isAdmissionOpen = true;
  bool _bannerLoaded = false;

  // ─── Flash Notice & Popup Form State ──────────────────────────────────
  bool _flashNoticeEnabled = true;
  final _flashNoticeBadgeCtrl = TextEditingController(text: 'नवीन सूचना');
  final _flashNoticeTextCtrl = TextEditingController(
      text:
          '📢 सत्र 2026-27 के लिए नवीन नामांकन प्रारंभ है। सीमित सीटें उपलब्ध। विशेष नवोदय प्रवेश परीक्षा तैयारी बैच। संपर्क: 8603481865');

  bool _popupAlertEnabled = false;
  final _popupAlertBadgeCtrl = TextEditingController(text: 'नामांकन सूचना');
  final _popupAlertTitleCtrl = TextEditingController(text: 'विशेष विद्यालय सूचना');
  final _popupAlertMessageCtrl = TextEditingController(
      text:
          'सत्र 2026-27 हेतु कक्षा नर्सरी से 8वीं तक में नामांकन हेतु ऑनलाइन आवेदन स्वीकार किए जा रहे हैं।');
  final _popupAlertActionCtrl = TextEditingController(text: 'नामांकन फॉर्म भरें');
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
    _bannerTagCtrl.dispose();
    _bannerHeadlineCtrl.dispose();
    _bannerSubheadlineCtrl.dispose();
    _bannerPhoneCtrl.dispose();
    _bannerWhatsappCtrl.dispose();
    _flashNoticeBadgeCtrl.dispose();
    _flashNoticeTextCtrl.dispose();
    _popupAlertBadgeCtrl.dispose();
    _popupAlertTitleCtrl.dispose();
    _popupAlertMessageCtrl.dispose();
    _popupAlertActionCtrl.dispose();
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
        _bannerTagCtrl.text = b['tagText']?.toString() ?? '';
        _bannerHeadlineCtrl.text = b['headline']?.toString() ?? '';
        _bannerSubheadlineCtrl.text = b['subheadline']?.toString() ?? '';
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
        if (f['badge'] != null) _flashNoticeBadgeCtrl.text = f['badge'].toString();
        if (f['text'] != null) _flashNoticeTextCtrl.text = f['text'].toString();
      }
      if (data.containsKey('popupAlert')) {
        final p = Map<String, dynamic>.from(data['popupAlert'] as Map? ?? {});
        _popupAlertEnabled = p['enabled'] == true;
        if (p['badge'] != null) _popupAlertBadgeCtrl.text = p['badge'].toString();
        if (p['title'] != null) _popupAlertTitleCtrl.text = p['title'].toString();
        if (p['message'] != null) _popupAlertMessageCtrl.text = p['message'].toString();
        if (p['actionText'] != null) _popupAlertActionCtrl.text = p['actionText'].toString();
      }
      _noticesLoaded = true;
    }
  }

  // ─── Save Admission Banner ─────────────────────────────────────────────
  Future<void> _saveAdmissionBanner() async {
    setState(() => _saving = true);
    try {
      final config = {
        'admissionBanner': {
          'style': _selectedBannerStyle,
          'session': _bannerSessionCtrl.text.trim(),
          'classes': _bannerClassesCtrl.text.trim(),
          'tagText': _bannerTagCtrl.text.trim(),
          'headline': _bannerHeadlineCtrl.text.trim(),
          'subheadline': _bannerSubheadlineCtrl.text.trim(),
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
      final config = {
        'flashNotice': {
          'enabled': _flashNoticeEnabled,
          'badge': _flashNoticeBadgeCtrl.text.trim(),
          'text': _flashNoticeTextCtrl.text.trim(),
        },
        'popupAlert': {
          'enabled': _popupAlertEnabled,
          'badge': _popupAlertBadgeCtrl.text.trim(),
          'title': _popupAlertTitleCtrl.text.trim(),
          'message': _popupAlertMessageCtrl.text.trim(),
          'actionText': _popupAlertActionCtrl.text.trim(),
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
                              _bannerHeadlineCtrl.text.isNotEmpty
                                  ? _bannerHeadlineCtrl.text
                                  : 'नामांकन प्रारंभ',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              'सत्र ${_bannerSessionCtrl.text} • ${_bannerClassesCtrl.text}',
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
                    _bannerSubheadlineCtrl.text,
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                  if (_bannerTagCtrl.text.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      '✨ ${_bannerTagCtrl.text}',
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

            _buildInputField('शैक्षणिक सत्र (Academic Session)', _bannerSessionCtrl,
                'e.g. 2026-27'),
            _buildInputField('नामांकन कक्षाएं (Classes Enrolling)',
                _bannerClassesCtrl, 'e.g. Nursery to 8th'),
            _buildInputField('मुख्य हेडलाइन (Main Headline)',
                _bannerHeadlineCtrl, 'e.g. सत्र 2026-27 हेतु नामांकन प्रारंभ'),
            _buildInputField('सब-हेडलाइन (Sub-Headline)',
                _bannerSubheadlineCtrl, 'e.g. Limited Seats Available'),
            _buildInputField('विशेष छूट / टैगलाइन (Special Offer Tag)',
                _bannerTagCtrl, 'e.g. विशेष छात्रवृत्ति एवं प्रारंभिक छूट'),
            _buildInputField('हेल्पलाइन फोन नंबर', _bannerPhoneCtrl, '8603481865',
                keyboard: TextInputType.phone),
            _buildInputField('व्हाट्सएप नंबर', _bannerWhatsappCtrl, '8603481865',
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
        final items = snapshot.data ?? [];

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: const Color(0xFF0C2340),
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add_photo_alternate_rounded,
                color: Color(0xFFF4B323)),
            label: const Text('Add Photo',
                style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () => _showAddPhotoDialog(items),
          ),
          body: items.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.photo_library_outlined,
                            size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text('Koi Photo Uploaded Nahi Hai',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 6),
                        const Text(
                          'Neeche "Add Photo" button dabakar website gallery me photo add karein.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0C2340),
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.add, color: Color(0xFFF4B323)),
                          label: const Text('Pehli Photo Add Karein'),
                          onPressed: () => _showAddPhotoDialog(items),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  itemCount: items.length,
                  itemBuilder: (context, idx) {
                    final photo = items[idx];
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
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.horizontal(
                                left: Radius.circular(16)),
                            child: Image.network(
                              photo['imageUrl']?.toString() ?? '',
                              width: 100,
                              height: 90,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 100,
                                height: 90,
                                color: const Color(0xFFE2E8F0),
                                child: const Icon(Icons.broken_image,
                                    color: Colors.grey),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0C2340).withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      (photo['category'] ?? 'campus').toString().toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF0C2340),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    photo['title']?.toString() ?? '',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                      color: Color(0xFF0C2340),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    photo['description']?.toString() ?? '',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 11, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded,
                                color: Colors.red),
                            tooltip: 'Delete Photo',
                            onPressed: () =>
                                _deletePhoto(items, photo['id']?.toString() ?? ''),
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

  void _showAddPhotoDialog(List<Map<String, dynamic>> currentItems) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    String category = 'campus';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Add Photo to Website Gallery',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Photo Title *',
                    hintText: 'e.g. वार्षिक खेलकूद प्रतियोगिता 2026',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'e.g. 100m दौड़ व पुरस्कार वितरण समारोह',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'campus', child: Text('Campus (परिसर)')),
                    DropdownMenuItem(value: 'sports', child: Text('Sports (खेलकूद)')),
                    DropdownMenuItem(value: 'events', child: Text('Events (कार्यक्रम)')),
                    DropdownMenuItem(value: 'class', child: Text('Classroom (कक्षाएं)')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDlgState(() => category = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: urlCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Image URL or Path *',
                    hintText: 'e.g. /school_gate_banner.jpg ya https://...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  icon: const Icon(Icons.photo_camera_rounded, size: 18),
                  label: const Text('Phone se Photo Chunein'),
                  onPressed: () async {
                    final picker = ImagePicker();
                    final xfile = await picker.pickImage(source: ImageSource.gallery);
                    if (xfile != null) {
                      // Note: Set path or URL
                      urlCtrl.text = xfile.path;
                    }
                  },
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
              child: const Text('Add to Live Gallery'),
              onPressed: () async {
                final title = titleCtrl.text.trim();
                final url = urlCtrl.text.trim();
                if (title.isEmpty || url.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Kripya Title aur Image URL darj karein')),
                  );
                  return;
                }
                Navigator.pop(ctx);
                final newItem = {
                  'id': 'gal_${DateTime.now().millisecondsSinceEpoch}',
                  'title': title,
                  'description': descCtrl.text.trim(),
                  'category': category,
                  'imageUrl': url,
                  'createdAt': DateTime.now().toIso8601String(),
                };
                final updated = List<Map<String, dynamic>>.from(currentItems)
                  ..insert(0, newItem);
                await FirestoreService.instance.saveWebsiteGallery(updated);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        backgroundColor: Color(0xFF059669),
                        content: Text('✅ Nayi Photo Gallery me add ho gayi!')),
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
      List<Map<String, dynamic>> currentItems, String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Photo?'),
        content: const Text(
            'Kya aap is photo ko website gallery se hatana chahte hain?'),
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
      final updated = currentItems.where((p) => p['id'] != id).toList();
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
                                onPressed: () => _deleteReview(
                                    items, rev['id']?.toString() ?? ''),
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
    final nameCtrl = TextEditingController();
    final relationCtrl = TextEditingController();
    final textCtrl = TextEditingController();
    int rating = 5;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Add Parent Review (समीक्षा)',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Parent / Guardian Name *',
                    hintText: 'e.g. राजेश कुमार सिंह',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: relationCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Student / Class Relation *',
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
                  controller: textCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Review Feedback Text *',
                    hintText: 'स्कूल के बारे में अभिभावक का विचार...',
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
                final name = nameCtrl.text.trim();
                final text = textCtrl.text.trim();
                if (name.isEmpty || text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Kripya sabhi fields bharein')),
                  );
                  return;
                }
                Navigator.pop(ctx);
                final newRev = {
                  'id': 'rev_${DateTime.now().millisecondsSinceEpoch}',
                  'authorName': name,
                  'relation': relationCtrl.text.trim(),
                  'rating': rating,
                  'text': text,
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
      List<Map<String, dynamic>> currentItems, String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Review?'),
        content: const Text('Kya aap is review ko website se hatana chahte hain?'),
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
      final updated = currentItems.where((r) => r['id'] != id).toList();
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
                  _buildInputField('Tag / Badge Text', _flashNoticeBadgeCtrl,
                      'e.g. नवीन सूचना ya आवश्यक सूचना'),
                  _buildInputField(
                      'News / Notice Content', _flashNoticeTextCtrl,
                      'Headline line jo upar chalegi...',
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
                      'Popup Badge', _popupAlertBadgeCtrl, 'e.g. अवकाश सूचना'),
                  _buildInputField('Popup Title', _popupAlertTitleCtrl,
                      'e.g. शीतकालीन अवकाश की सूचना'),
                  _buildInputField('Popup Message', _popupAlertMessageCtrl,
                      'Vistrit suchna...',
                      maxLines: 3),
                  _buildInputField('Action Button Text', _popupAlertActionCtrl,
                      'e.g. समझ गया / नामांकन फॉर्म भरें'),
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
