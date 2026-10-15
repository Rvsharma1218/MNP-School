import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/services/subscription_service.dart';
import '../../data/services/database_service.dart';
import '../../data/services/session_service.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  bool _isYearly = false;
  bool _loading = true;
  Map<String, dynamic> _subInfo = {};
  int _currentStudentCount = 0;
  Map<String, dynamic> _plansConfig = {};
  StreamSubscription<Map<String, dynamic>>? _plansSub;

  @override
  void initState() {
    super.initState();
    _loadData();
    _plansSub = SubscriptionService.instance.getSystemPlansConfigStream().listen((cfg) {
      if (mounted) {
        setState(() {
          _plansConfig = cfg;
        });
      }
    });
  }

  @override
  void dispose() {
    _plansSub?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final info = await SubscriptionService.instance.getSubscriptionInfo();
    final count = await DatabaseService.instance.getStudentCount();
    final config = await SubscriptionService.instance.getSystemPlansConfig();
    if (mounted) {
      setState(() {
        _subInfo = info;
        _currentStudentCount = count;
        _plansConfig = config;
        _loading = false;
      });
    }
  }

  void _contactForUpgrade(SubscriptionPlan plan) async {
    final schoolId = SessionService.instance.activeSchoolUidOrNull ?? 'MySchool';
    final billingPeriod = _isYearly ? 'Yearly (${plan.priceYearly})' : 'Monthly (${plan.priceMonthly})';
    final promo = (_plansConfig['isOfferActive'] == true && _plansConfig['promoCode'] != null && _plansConfig['promoCode'].toString().isNotEmpty)
        ? '\nPromo Code Applied: ${_plansConfig['promoCode']} (${_plansConfig['offerDiscount'] ?? 20}% Discount)'
        : '';
    final message = Uri.encodeComponent(
      'Hello Admin, I want to upgrade to the "${plan.name}" plan ($billingPeriod) for School ID: $schoolId.$promo\nPlease share payment details / activate my account.',
    );

    String targetPhone = '918568643490';
    try {
      final sDoc = await FirebaseFirestore.instance.collection('schoolDirectory').doc('support_info').get();
      if (sDoc.exists && sDoc.data() != null) {
        final raw = (sDoc.data()!['supportWhatsapp'] ?? sDoc.data()!['supportPhone'])?.toString() ?? '';
        final clean = raw.replaceAll(RegExp(r'[^0-9]'), '');
        if (clean.isNotEmpty) {
          targetPhone = clean.startsWith('91') ? clean : (clean.length == 10 ? '91$clean' : clean);
        }
      }
    } catch (_) {}

    final whatsappUrl = Uri.parse('https://wa.me/$targetPhone?text=$message');

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.verified_rounded, color: Color(0xFF1E3A8A), size: 28),
                const SizedBox(width: 10),
                Text('Upgrade to ${plan.name}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Selected Plan: ${plan.name} ($billingPeriod)\nCapacity: ${plan.maxStudents == -1 ? "Unlimited" : "${plan.maxStudents} Students"}',
              style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.chat_rounded),
                label: const Text('Contact on WhatsApp for Instant Activation', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () async {
                  Navigator.pop(ctx);
                  if (await canLaunchUrl(whatsappUrl)) {
                    await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
                  } else {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('WhatsApp not installed. Please contact your administrator.')),
                      );
                    }
                  }
                },
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.key_rounded),
                label: const Text('Enter Activation License Key'),
                onPressed: () {
                  Navigator.pop(ctx);
                  _showLicenseKeyDialog();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLicenseKeyDialog() {
    final keyCtrl = TextEditingController();
    bool isVerifying = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.vpn_key_rounded, color: Color(0xFF1E3A8A), size: 20),
              SizedBox(width: 8),
              Text('Enter License Key', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter the official license activation key provided by Super Administrator:',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: keyCtrl,
                enabled: !isVerifying,
                style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
                decoration: const InputDecoration(
                  hintText: 'e.g. SCH-PRO-8492-X9M2',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              if (isVerifying) ...[
                const SizedBox(height: 12),
                const Row(
                  children: [
                    SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 10),
                    Text('Verifying with database...', style: TextStyle(fontSize: 12, color: Colors.blueAccent)),
                  ],
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: isVerifying ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A), foregroundColor: Colors.white),
              onPressed: isVerifying
                  ? null
                  : () async {
                      final key = keyCtrl.text.trim().toUpperCase();
                      if (key.length < 5) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter a valid license key format.')),
                        );
                        return;
                      }

                      setDState(() => isVerifying = true);
                      try {
                        final db = FirebaseFirestore.instance;

                        // 1. Check primary licenseKeys collection
                        DocumentSnapshot<Map<String, dynamic>>? docSnap;
                        try {
                          final snap = await db.collection('licenseKeys').doc(key).get();
                          if (snap.exists) docSnap = snap;
                        } catch (_) {}

                        // 2. Check schoolDirectory backup collection
                        if (docSnap == null || !docSnap.exists) {
                          try {
                            final snap = await db
                                .collection('schoolDirectory')
                                .doc('system_license_keys')
                                .collection('keys')
                                .doc(key)
                                .get();
                            if (snap.exists) docSnap = snap;
                          } catch (_) {}
                        }

                        if (docSnap == null || !docSnap.exists) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Invalid License Key. Contact administrator for a valid key.')),
                            );
                          }
                          setDState(() => isVerifying = false);
                          return;
                        }

                        final data = docSnap.data()!;
                        if (data['status'] == 'used') {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('This License Key has already been redeemed by a school.')),
                            );
                          }
                          setDState(() => isVerifying = false);
                          return;
                        }

                        // Valid active key found!
                        final planId = data['planId'] ?? 'pro';
                        final planName = data['planName'] ?? 'Pro Unlimited';
                        final maxStudents = (data['maxStudents'] as num?)?.toInt() ?? -1;
                        final currentSchoolId = SessionService.instance.activeSchoolId;

                        // Activate in local & Firestore subscription
                        await SubscriptionService.instance.updateSubscription(
                          planId: planId,
                          planName: planName,
                          maxStudents: maxStudents,
                        );

                        // Mark key as redeemed in database
                        final updatePayload = {
                          'status': 'used',
                          'usedBySchoolId': currentSchoolId,
                          'usedAt': FieldValue.serverTimestamp(),
                        };

                        try {
                          await db.collection('licenseKeys').doc(key).set(updatePayload, SetOptions(merge: true));
                        } catch (_) {}
                        try {
                          await db
                              .collection('schoolDirectory')
                              .doc('system_license_keys')
                              .collection('keys')
                              .doc(key)
                              .set(updatePayload, SetOptions(merge: true));
                        } catch (_) {}

                        if (ctx.mounted) Navigator.pop(ctx);
                        _loadData();

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('✓ $planName activated successfully!'),
                              backgroundColor: Colors.teal,
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error validating key: $e')),
                          );
                        }
                        setDState(() => isVerifying = false);
                      }
                    },
              child: const Text('Verify & Activate'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentPlanId = _subInfo['planId'] ?? 'trial';
    final int maxStudents = (_subInfo['maxStudents'] as num?)?.toInt() ?? 10;
    final progress = maxStudents == -1 ? 0.0 : (_currentStudentCount / maxStudents).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Subscription & Plans', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─── Special Promotional Discount Banner (From Super Admin) ───
                  if (_plansConfig['isOfferActive'] == true) ...[
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFDC2626), Color(0xFFF97316)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.deepOrange.withValues(alpha: 0.35),
                            blurRadius: 10,
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
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '🔥 SPECIAL OFFER • ${_plansConfig['offerDiscount'] ?? 20}% OFF',
                                  style: const TextStyle(
                                    color: Color(0xFFDC2626),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              if (_plansConfig['promoCode'] != null && _plansConfig['promoCode'].toString().isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black26,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.white38),
                                  ),
                                  child: Text(
                                    'Code: ${_plansConfig['promoCode']}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _plansConfig['offerBanner'] != null && _plansConfig['offerBanner'].toString().isNotEmpty
                                ? _plansConfig['offerBanner'].toString()
                                : 'Limited Time Offer! Upgrade today to get exclusive discounts on all plans.',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Discount will be applied instantly upon account upgrade or license activation.',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Current Active Plan Status Banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(color: const Color(0xFF1E3A8A).withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('CURRENT PLAN', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                                const SizedBox(height: 4),
                                Text(
                                  _subInfo['planName'] ?? 'Free Trial',
                                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.shade500,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text('ACTIVE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Student Capacity Usage', style: TextStyle(color: Colors.white70, fontSize: 12)),
                            Text(
                              maxStudents == -1 ? '$_currentStudentCount / Unlimited' : '$_currentStudentCount / $maxStudents Students',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: progress,
                            backgroundColor: Colors.white.withValues(alpha: 0.2),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              progress >= 0.9 ? Colors.amberAccent : Colors.lightGreenAccent,
                            ),
                            minHeight: 8,
                          ),
                        ),
                        if (currentPlanId == 'trial' && _subInfo['isSubscriptionEnabled'] != false) ...[
                          const SizedBox(height: 10),
                          const Text(
                            '💡 Trial limit: 10 students. Upgrade to add more students and unlock batch reports.',
                            style: TextStyle(color: Colors.white, fontSize: 11),
                          ),
                        ] else if (_subInfo['isSubscriptionEnabled'] == false) ...[
                          const SizedBox(height: 10),
                          const Text(
                            '✨ Unrestricted Full Access: Master subscription switch is currently OFF. All modules & student admissions are 100% free with unlimited capacity.',
                            style: TextStyle(color: Colors.white, fontSize: 11),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Billing Cycle Toggle (Monthly vs Yearly)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: () => setState(() => _isYearly = false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                              decoration: BoxDecoration(
                                color: !_isYearly ? const Color(0xFF1E3A8A) : Colors.transparent,
                                borderRadius: BorderRadius.circular(25),
                              ),
                              child: Text(
                                'Monthly Billing',
                                style: TextStyle(
                                  color: !_isYearly ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF475569)),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => setState(() => _isYearly = true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                              decoration: BoxDecoration(
                                color: _isYearly ? const Color(0xFF1E3A8A) : Colors.transparent,
                                borderRadius: BorderRadius.circular(25),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    'Yearly Billing',
                                    style: TextStyle(
                                      color: _isYearly ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF475569)),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.green,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Text('SAVE 25%', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Available Plans List (Live pricing & limits from Cloud Super Admin)
                  ...SubscriptionService.instance.getDynamicPlans(_plansConfig).map((plan) {
                    final isCurrent = currentPlanId == plan.id;
                    final price = _isYearly ? plan.priceYearly : plan.priceMonthly;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: plan.isPopular
                              ? const Color(0xFF3B82F6)
                              : (isCurrent ? Colors.green : const Color(0xFFE2E8F0)),
                          width: plan.isPopular || isCurrent ? 2 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: plan.isPopular ? 0.08 : 0.02),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (plan.isPopular)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 5),
                              decoration: const BoxDecoration(
                                color: Color(0xFF3B82F6),
                                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                              ),
                              alignment: Alignment.center,
                              child: const Text(
                                '★ MOST POPULAR FOR SCHOOLS',
                                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(plan.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                                    Text(
                                      price,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                        color: plan.id == 'trial' ? Colors.green : const Color(0xFF1E3A8A),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  plan.maxStudents == -1 ? 'Unlimited Student Admissions' : 'Up to ${plan.maxStudents} Students capacity',
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 14),
                                const Divider(height: 1),
                                const SizedBox(height: 12),
                                ...plan.features.map(
                                  (feat) => Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.check_circle_rounded, color: Colors.green, size: 16),
                                        const SizedBox(width: 8),
                                        Expanded(child: Text(feat, style: const TextStyle(fontSize: 12))),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: isCurrent
                                      ? OutlinedButton(
                                          onPressed: null,
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          ),
                                          child: const Text('Current Active Plan', style: TextStyle(fontWeight: FontWeight.bold)),
                                        )
                                      : ElevatedButton(
                                          onPressed: () => _contactForUpgrade(plan),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: plan.isPopular ? const Color(0xFF3B82F6) : const Color(0xFF1E3A8A),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          ),
                                          child: Text('Choose ${plan.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
    );
  }
}
