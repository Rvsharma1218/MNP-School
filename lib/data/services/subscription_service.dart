import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'database_service.dart';
import 'session_service.dart';
import '../../features/settings/subscription_screen.dart';

class SubscriptionPlan {
  final String id;
  final String name;
  final String priceMonthly;
  final String priceYearly;
  final int maxStudents;
  final List<String> features;
  final bool isPopular;

  const SubscriptionPlan({
    required this.id,
    required this.name,
    required this.priceMonthly,
    required this.priceYearly,
    required this.maxStudents,
    required this.features,
    this.isPopular = false,
  });
}

class SubscriptionService {
  static final SubscriptionService instance = SubscriptionService._internal();
  SubscriptionService._internal();

  static const List<SubscriptionPlan> plans = [
    SubscriptionPlan(
      id: 'trial',
      name: 'Free Trial',
      priceMonthly: '₹0',
      priceYearly: '₹0',
      maxStudents: 10,
      features: [
        'Up to 10 Students',
        'Basic Attendance & Student Profiles',
        'Collect Fees & Print Receipts',
        'Marksheet Generation & PDFs',
        'WhatsApp Reminder Alerts',
      ],
    ),
    SubscriptionPlan(
      id: 'starter',
      name: 'Starter Plan',
      priceMonthly: '₹199 / mo',
      priceYearly: '₹1,799 / yr',
      maxStudents: 50,
      features: [
        'Up to 50 Students',
        'Complete Fee Ledger & Defaulter List',
        'Daily Attendance & WhatsApp Reports',
        'Multi-term Marksheets & Reports',
        'Cloud Backup & Sync',
      ],
    ),
    SubscriptionPlan(
      id: 'standard',
      name: 'Standard School',
      priceMonthly: '₹399 / mo',
      priceYearly: '₹3,499 / yr',
      maxStudents: 200,
      isPopular: true,
      features: [
        'Up to 200 Students',
        'All Starter Features Included',
        'Batch PDF Marksheets Download',
        'Student ID Cards & Admit Cards',
        'Multi-teacher Role Permissions',
        'Priority Phone & Chat Support',
      ],
    ),
    SubscriptionPlan(
      id: 'pro',
      name: 'Pro Unlimited',
      priceMonthly: '₹699 / mo',
      priceYearly: '₹5,999 / yr',
      maxStudents: -1, // Unlimited
      features: [
        'Unlimited Students & Classes',
        'Full Multi-Admin & Teacher Portal',
        'Custom School Header & Branding',
        'Automated Cloud Sync to All Devices',
        'Dedicated Account Manager 24/7',
      ],
    ),
  ];

  /// Checks whether the global subscription system is enabled in Cloud by Super Admin.
  /// Real-time stream of system plans configuration & active promotional offers
  Stream<Map<String, dynamic>> getSystemPlansConfigStream() {
    return FirebaseFirestore.instance
        .collection('schoolDirectory')
        .doc('system_subscription_plans')
        .snapshots()
        .map((snap) => (snap.exists && snap.data() != null) ? snap.data()! : <String, dynamic>{});
  }

  /// Fetches system-wide plans configuration including promotional banners and offers
  Future<Map<String, dynamic>> getSystemPlansConfig() async {
    try {
      final doc1 = await FirebaseFirestore.instance
          .collection('schoolDirectory')
          .doc('system_subscription_plans')
          .get();
      if (doc1.exists && doc1.data() != null) {
        return doc1.data()!;
      }

      final doc2 = await FirebaseFirestore.instance
          .collection('system_config')
          .doc('subscription_plans')
          .get();
      if (doc2.exists && doc2.data() != null) {
        return doc2.data()!;
      }
    } catch (e) {
      debugPrint('[SubscriptionService] fetch plans config: $e');
    }
    return {};
  }

  Future<bool> isSubscriptionSystemEnabled() async {
    return false; // Subscription system disabled: 100% free unlimited access
  }

  /// Fetches subscription info from Firestore. Master switch takes absolute priority.
  Future<Map<String, dynamic>> getSubscriptionInfo() async {
    // 1. MASTER SUBSCRIPTION SWITCH TAKES HIGHEST PRIORITY:
    // If Super Admin turns OFF the global subscription system, ALL schools instantly
    // receive 100% free unlimited access without any capacity paywall.
    final isEnabled = await isSubscriptionSystemEnabled();
    if (!isEnabled) {
      return {
        'planId': 'full_unlimited',
        'planName': 'Unlimited Access (Free Mode)',
        'maxStudents': -1,
        'studentLimit': -1,
        'status': 'active',
        'isSubscriptionEnabled': false,
        'activatedAt': DateTime.now().toIso8601String(),
      };
    }

    final schoolId = SessionService.instance.activeSchoolUidOrNull ??
        (SessionService.instance.activeSchoolId.isNotEmpty
            ? SessionService.instance.activeSchoolId
            : FirebaseAuth.instance.currentUser?.uid);

    if (schoolId != null) {
      try {
        // 2. Check schools/{schoolId} main document (written by Super Admin)
        final schoolDoc = await FirebaseFirestore.instance
            .collection('schools')
            .doc(schoolId)
            .get();

        if (schoolDoc.exists && schoolDoc.data() != null) {
          final sData = schoolDoc.data()!;
          final limit = sData['studentLimit'] ??
              sData['maxStudents'] ??
              (sData['subscription'] is Map ? sData['subscription']['maxStudents'] : null);
          final plan = sData['subscriptionPlan'] ??
              sData['planId'] ??
              (sData['subscription'] is Map ? sData['subscription']['planId'] : null);
          final planName = sData['subscriptionPlanName'] ??
              sData['planName'] ??
              (sData['subscription'] is Map ? sData['subscription']['planName'] : null);

          if (limit != null) {
            final int parsedLimit = (limit as num).toInt();
            return {
              'planId': plan ?? 'custom',
              'planName': planName ??
                  (parsedLimit == -1
                      ? 'Pro Unlimited'
                      : (plan == 'standard'
                          ? 'Standard School'
                          : (plan == 'starter' ? 'Starter Plan' : 'Active Plan'))),
              'maxStudents': parsedLimit,
              'studentLimit': parsedLimit,
              'status': 'active',
              'isSubscriptionEnabled': true,
              'activatedAt': DateTime.now().toIso8601String(),
            };
          }
        }

        // 3. Check schools/{schoolId}/subscription/current
        final subDoc = await FirebaseFirestore.instance
            .collection('schools')
            .doc(schoolId)
            .collection('subscription')
            .doc('current')
            .get();

        if (subDoc.exists && subDoc.data() != null) {
          final data = Map<String, dynamic>.from(subDoc.data()!);
          if (data['maxStudents'] != null) {
            data['isSubscriptionEnabled'] = true;
            return data;
          }
        }
      } catch (e) {
        debugPrint('[SubscriptionService] Error getting subscription info: $e');
      }
    }

    // Default: Free Trial with capacity configured in Cloud by Admin
    final sysConfig = await getSystemPlansConfig();
    final defaultTrialLimit = (sysConfig['trialLimit'] as num?)?.toInt() ?? 10;

    return {
      'planId': 'trial',
      'planName': 'Free Trial',
      'maxStudents': defaultTrialLimit,
      'studentLimit': defaultTrialLimit,
      'status': 'active',
      'isSubscriptionEnabled': true,
      'activatedAt': DateTime.now().toIso8601String(),
    };
  }

  /// Returns subscription plans dynamically styled with prices and student capacity
  /// configured in the Super Admin app.
  List<SubscriptionPlan> getDynamicPlans(Map<String, dynamic> config) {
    final starterMonth = config['starterMonthPrice'] ?? 199;
    final starterYear = config['starterYearPrice'] ?? 1790;
    final starterLimit = config['starterLimit'] ?? 50;

    final standardMonth = config['standardMonthPrice'] ?? 399;
    final standardYear = config['standardYearPrice'] ?? 3590;
    final standardLimit = config['standardLimit'] ?? 200;

    final proMonth = config['proMonthPrice'] ?? 699;
    final proYear = config['proYearPrice'] ?? 6290;

    final trialLimit = config['trialLimit'] ?? 10;

    return [
      SubscriptionPlan(
        id: 'trial',
        name: 'Free Trial',
        priceMonthly: '₹0',
        priceYearly: '₹0',
        maxStudents: trialLimit,
        features: [
          'Up to $trialLimit Students',
          'Basic Attendance & Student Profiles',
          'Collect Fees & Print Receipts',
          'Marksheet Generation & PDFs',
          'WhatsApp Reminder Alerts',
        ],
      ),
      SubscriptionPlan(
        id: 'starter',
        name: 'Starter Plan',
        priceMonthly: '₹$starterMonth / mo',
        priceYearly: '₹$starterYear / yr',
        maxStudents: starterLimit,
        features: [
          'Up to $starterLimit Students',
          'Complete Fee Ledger & Defaulter List',
          'Daily Attendance & WhatsApp Reports',
          'Multi-term Marksheets & Reports',
          'Cloud Backup & Sync',
        ],
      ),
      SubscriptionPlan(
        id: 'standard',
        name: 'Standard School',
        priceMonthly: '₹$standardMonth / mo',
        priceYearly: '₹$standardYear / yr',
        maxStudents: standardLimit,
        isPopular: true,
        features: [
          'Up to $standardLimit Students',
          'All Starter Features Included',
          'Batch PDF Marksheets Download',
          'Student ID Cards & Admit Cards',
          'Multi-teacher Role Permissions',
          'Priority Phone & Chat Support',
        ],
      ),
      SubscriptionPlan(
        id: 'pro',
        name: 'Pro Unlimited',
        priceMonthly: '₹$proMonth / mo',
        priceYearly: '₹$proYear / yr',
        maxStudents: -1, // Unlimited
        features: const [
          'Unlimited Students & Classes',
          'Full Multi-Admin & Teacher Portal',
          'Custom School Header & Branding',
          'Automated Cloud Sync to All Devices',
          'Dedicated Account Manager 24/7',
        ],
      ),
    ];
  }

  /// Updates subscription plan in Firestore
  Future<void> updateSubscription({
    required String planId,
    required String planName,
    required int maxStudents,
  }) async {
    final schoolId = SessionService.instance.activeSchoolUidOrNull;
    if (schoolId == null) return;

    final data = {
      'planId': planId,
      'planName': planName,
      'maxStudents': maxStudents,
      'status': 'active',
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      await FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolId)
          .collection('subscription')
          .doc('current')
          .set(data, SetOptions(merge: true));

      // Also mirror in school directory
      await FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolId)
          .set({'subscription': data}, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[Subscription] Update note: $e');
    }
  }

  /// Checks if adding another student is permitted.
  /// If limit is reached, shows upgrade modal and returns false.
  Future<bool> checkCanAddStudent(BuildContext context) async {
    final isEnabled = await isSubscriptionSystemEnabled();
    if (!isEnabled) {
      return true; // Master subscription switch is OFF: unlimited free students allowed.
    }

    final subInfo = await getSubscriptionInfo();
    final int maxStudents = (subInfo['maxStudents'] as num?)?.toInt() ?? -1;
    
    // -1 means unlimited or system switch off
    if (maxStudents == -1 || subInfo['isSubscriptionEnabled'] == false) return true;

    final currentCount = await DatabaseService.instance.getStudentCount();
    if (currentCount >= maxStudents) {
      if (context.mounted) {
        showDialog<void>(
          context: context,
          builder: (dCtx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.workspace_premium_rounded, color: Colors.amber.shade900, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('Student Limit Reached', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Aapka current plan "${subInfo['planName'] ?? 'Free Trial'}" maximum $maxStudents students tak allow karta hai.',
                  style: const TextStyle(fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Added Students:', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      Text('$currentCount / $maxStudents', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.red)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Aur students add karne ke liye plan upgrade karein (Starting at just ₹199/month).',
                  style: TextStyle(fontSize: 12, color: Color(0xFF475569)),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dCtx),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.upgrade_rounded, size: 18),
                label: const Text('View Plans & Upgrade'),
                onPressed: () {
                  Navigator.pop(dCtx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
                  );
                },
              ),
            ],
          ),
        );
      }
      return false;
    }
    return true;
  }
}
