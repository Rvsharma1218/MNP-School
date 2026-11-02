import 'dart:async';
import 'dart:ffi';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'device_security_service.dart';

class DeviceSecurityGate extends StatefulWidget {
  final Widget child;

  const DeviceSecurityGate({super.key, required this.child});

  @override
  State<DeviceSecurityGate> createState() => _DeviceSecurityGateState();
}

class _DeviceSecurityGateState extends State<DeviceSecurityGate> {
  static const int currentVersionCode = 8;
  static const String currentVersion = '2.0.1';

  bool _isRevoked = false;
  bool _isCheckingRevocation = false;
  StreamSubscription<bool>? _revocationSub;
  StreamSubscription<Map<String, String>>? _alertSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _updateSub;

  Map<String, dynamic>? _pendingUpdate;
  bool _dismissedOptionalUpdate = false;

  String _resolveDeviceApkUrl(Map<String, dynamic> data) {
    final v8 = (data['apk_v8_url']?.toString() ?? '').trim();
    final v7 = (data['apk_v7_url']?.toString() ?? '').trim();
    final universal = (data['apkUrl']?.toString() ?? '').trim();

    try {
      final abi = Abi.current();
      if (abi == Abi.androidArm) {
        // 32-bit ARM (armeabi-v7a)
        if (v7.isNotEmpty) return v7;
      } else if (abi == Abi.androidArm64) {
        // 64-bit ARM (arm64-v8a)
        if (v8.isNotEmpty) return v8;
      }
    } catch (_) {}

    if (v8.isNotEmpty) return v8;
    if (v7.isNotEmpty) return v7;
    return universal;
  }

  String _getDeviceArchitectureLabel() {
    try {
      final abi = Abi.current();
      if (abi == Abi.androidArm) return 'CPU: armeabi-v7a (32-bit)';
      if (abi == Abi.androidArm64) return 'CPU: arm64-v8a (64-bit)';
      if (abi == Abi.androidX64) return 'CPU: x86_64 (64-bit)';
    } catch (_) {}
    return 'CPU: arm64-v8a (64-bit)';
  }

  @override
  void initState() {
    super.initState();
    // 1. Check initial persistent revocation state
    _isRevoked = DeviceSecurityService.instance.isRevoked;

    // 2. Listen for real-time revocation / unrevocation changes
    _revocationSub = DeviceSecurityService.instance.onRevocationChanged.listen((revoked) {
      if (mounted) {
        setState(() => _isRevoked = revoked);
      }
    });

    // 3. Listen for incoming remote push alerts to show in-app banner
    _alertSub = DeviceSecurityService.instance.onRemoteAlert.listen((alert) {
      if (!mounted) return;
      _showInAppAlertBanner(alert['title'] ?? 'School Notice', alert['body'] ?? '');
    });

    // 4. Listen for Remote App Update broadcasts from School Admin
    _listenAppUpdate();
  }

  @override
  void dispose() {
    _revocationSub?.cancel();
    _alertSub?.cancel();
    _updateSub?.cancel();
    super.dispose();
  }

  void _listenAppUpdate() {
    _updateSub?.cancel();
    _updateSub = FirebaseFirestore.instance
        .collection('schoolDirectory')
        .doc('system_app_update')
        .snapshots()
        .listen((snap) async {
      if (!snap.exists || snap.data() == null) {
        if (mounted && _pendingUpdate != null) {
          setState(() => _pendingUpdate = null);
        }
        return;
      }

      final data = snap.data()!;
      // Must be explicitly active: true (or not false)
      final active = data['active'] == true;
      if (!active) {
        if (mounted && _pendingUpdate != null) {
          setState(() => _pendingUpdate = null);
        }
        return;
      }

      final remoteVersionCode = int.tryParse(data['versionCode']?.toString() ?? '0') ?? 0;
      final effectiveApkUrl = _resolveDeviceApkUrl(data);
      final isForced = data['forceUpdate'] == true && effectiveApkUrl.isNotEmpty;

      // Check if user permanently dismissed this specific update version
      try {
        final prefs = await SharedPreferences.getInstance();
        final dismissedCode = prefs.getInt('dismissed_app_update_version_code') ?? 0;
        if (remoteVersionCode <= dismissedCode && !isForced) {
          if (mounted && _pendingUpdate != null) {
            setState(() => _pendingUpdate = null);
          }
          return;
        }
      } catch (_) {}

      if (remoteVersionCode > currentVersionCode) {
        if (mounted) {
          setState(() {
            _pendingUpdate = data;
          });
        }
      } else {
        if (mounted && _pendingUpdate != null) {
          setState(() => _pendingUpdate = null);
        }
      }
    }, onError: (_) {});
  }

  void _showInAppAlertBanner(String title, String body) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        backgroundColor: const Color(0xFF0F172A),
        elevation: 12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFF59E0B), width: 1.2),
        ),
        duration: const Duration(seconds: 7),
        content: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.notifications_active_rounded, color: Color(0xFFF59E0B), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Colors.white),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    body,
                    style: TextStyle(fontSize: 11.5, color: Colors.white.withValues(alpha: 0.8), height: 1.35),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _checkAccessStatus() async {
    setState(() => _isCheckingRevocation = true);
    final isStillRevoked = await DeviceSecurityService.instance.checkRevocationStatus();
    if (!mounted) return;
    setState(() {
      _isRevoked = isStillRevoked;
      _isCheckingRevocation = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isStillRevoked
              ? '❌ Device remains revoked. Please contact School Admin.'
              : '✅ Access restored! Welcome back.',
        ),
        backgroundColor: isStillRevoked ? Colors.redAccent : Colors.green,
      ),
    );
  }

  Future<void> _openUpdateUrl(String url) async {
    if (url.trim().isEmpty) return;
    try {
      final uri = Uri.parse(url.trim());
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open update link'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _dismissPermanently(int versionCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('dismissed_app_update_version_code', versionCode);
    } catch (_) {}
    if (mounted) {
      setState(() {
        _pendingUpdate = null;
        _dismissedOptionalUpdate = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. If device is revoked by School Admin, block ALL access
    if (_isRevoked) {
      return PopScope(
        canPop: false,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            backgroundColor: const Color(0xFF0F172A),
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3), width: 2),
                        ),
                        child: const Icon(Icons.gpp_bad_rounded, size: 72, color: Colors.redAccent),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Device Access Revoked',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'This phone has been disconnected by School Super Admin.\nRestarting the app will not bypass this security lock.',
                        style: TextStyle(fontSize: 13, color: Colors.white70, height: 1.4),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'HARDWARE SESSION IDENTIFIER',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white38, letterSpacing: 0.8),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              DeviceSecurityService.instance.sessionId,
                              style: const TextStyle(
                                fontSize: 11,
                                fontFamily: 'monospace',
                                color: Colors.cyanAccent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Row(
                              children: [
                                Icon(Icons.circle, color: Colors.redAccent, size: 8),
                                SizedBox(width: 6),
                                Text('Status: Access Blocked', style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.tealAccent.shade700,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: _isCheckingRevocation
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.refresh_rounded),
                          label: Text(
                            _isCheckingRevocation ? 'Checking...' : 'Check Access Status',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          onPressed: _isCheckingRevocation ? null : _checkAccessStatus,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // 2. If an App Update is pending
    if (_pendingUpdate != null && !_dismissedOptionalUpdate) {
      final remoteVersionCode = int.tryParse(_pendingUpdate!['versionCode']?.toString() ?? '0') ?? 0;
      final effectiveApkUrl = _resolveDeviceApkUrl(_pendingUpdate!);
      final hasUrl = effectiveApkUrl.isNotEmpty;
      final isForced = _pendingUpdate!['forceUpdate'] == true && hasUrl;
      final newVer = _pendingUpdate!['latestVersion']?.toString() ?? '2.0.2';
      final notes = _pendingUpdate!['releaseNotes']?.toString() ?? 'Performance fixes & security improvements.';
      final archLabel = _getDeviceArchitectureLabel();

      return Stack(
        children: [
          widget.child,
          // Premium Frosted Backdrop & Modal
          PopScope(
            canPop: !isForced,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                color: Colors.black.withValues(alpha: isForced ? 0.88 : 0.65),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF0F172A),
                            Color(0xFF1E293B),
                            Color(0xFF0B132B),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isForced
                              ? Colors.redAccent.withValues(alpha: 0.4)
                              : const Color(0xFF6366F1).withValues(alpha: 0.35),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isForced
                                ? Colors.redAccent.withValues(alpha: 0.25)
                                : const Color(0xFF6366F1).withValues(alpha: 0.30),
                            blurRadius: 36,
                            spreadRadius: 2,
                            offset: const Offset(0, 8),
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.6),
                            blurRadius: 24,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Header Banner with Status Pill & Icon
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    (isForced ? Colors.redAccent : const Color(0xFF6366F1))
                                        .withValues(alpha: 0.18),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                              child: Column(
                                children: [
                                  // Top Status Tag
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: (isForced ? Colors.redAccent : const Color(0xFF6366F1))
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: (isForced ? Colors.redAccent : const Color(0xFF6366F1))
                                            .withValues(alpha: 0.4),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 7,
                                          height: 7,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: isForced ? Colors.redAccent : const Color(0xFF38BDF8),
                                            boxShadow: [
                                              BoxShadow(
                                                color: (isForced ? Colors.redAccent : const Color(0xFF38BDF8))
                                                    .withValues(alpha: 0.8),
                                                blurRadius: 6,
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 7),
                                        Text(
                                          isForced ? 'MANDATORY UPDATE' : 'NEW UPDATE AVAILABLE',
                                          style: TextStyle(
                                            color: isForced ? const Color(0xFFFCA5A5) : const Color(0xFFBAE6FD),
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.8,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  // Glowing Center Icon
                                  Container(
                                    width: 72,
                                    height: 72,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: isForced
                                            ? [const Color(0xFFEF4444), const Color(0xFF991B1B)]
                                            : [const Color(0xFF6366F1), const Color(0xFF3B82F6)],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: (isForced ? const Color(0xFFEF4444) : const Color(0xFF6366F1))
                                              .withValues(alpha: 0.45),
                                          blurRadius: 20,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        Icons.rocket_launch_rounded,
                                        color: Colors.white,
                                        size: 36,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 14),

                                  // Title
                                  Text(
                                    isForced ? 'Critical App Upgrade' : 'Exciting New Update!',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: -0.3,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),

                                  // Version Comparison Pill: Current -> Latest
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.35),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: Colors.white12),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'v$currentVersion',
                                          style: const TextStyle(
                                            color: Colors.white60,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const Padding(
                                          padding: EdgeInsets.symmetric(horizontal: 8),
                                          child: Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF34D399)),
                                        ),
                                        Text(
                                          'v$newVer',
                                          style: const TextStyle(
                                            color: Color(0xFF34D399),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 6),

                                  // Architecture chip
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0284C7).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.3)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.memory_rounded, size: 12, color: Color(0xFF38BDF8)),
                                        const SizedBox(width: 5),
                                        Text(
                                          archLabel,
                                          style: const TextStyle(
                                            color: Color(0xFFBAE6FD),
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Body: Release notes & Actions
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                              child: Column(
                                children: [
                                  // What's New Box
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0F172A).withValues(alpha: 0.7),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Row(
                                          children: [
                                            Icon(Icons.auto_awesome_rounded, color: Color(0xFFFBBF24), size: 14),
                                            SizedBox(width: 6),
                                            Text(
                                              "WHAT'S NEW",
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFFFBBF24),
                                                letterSpacing: 0.8,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        ConstrainedBox(
                                          constraints: const BoxConstraints(maxHeight: 110),
                                          child: SingleChildScrollView(
                                            physics: const BouncingScrollPhysics(),
                                            child: Text(
                                              notes,
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                color: Colors.white.withValues(alpha: 0.85),
                                                height: 1.45,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 18),

                                  if (!hasUrl)
                                    Container(
                                      width: double.infinity,
                                      margin: const EdgeInsets.only(bottom: 12),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                                      ),
                                      child: const Row(
                                        children: [
                                          Icon(Icons.info_outline_rounded, color: Colors.amber, size: 16),
                                          SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Notice broadcast without direct download link. You may continue.',
                                              style: TextStyle(color: Colors.amber, fontSize: 11),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                  // Download Button
                                  if (hasUrl) ...[
                                    Container(
                                      width: double.infinity,
                                      height: 52,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: isForced
                                              ? [const Color(0xFFEF4444), const Color(0xFFDC2626)]
                                              : [const Color(0xFF4F46E5), const Color(0xFF2563EB)],
                                        ),
                                        borderRadius: BorderRadius.circular(14),
                                        boxShadow: [
                                          BoxShadow(
                                            color: (isForced ? const Color(0xFFEF4444) : const Color(0xFF4F46E5))
                                                .withValues(alpha: 0.4),
                                            blurRadius: 18,
                                            offset: const Offset(0, 6),
                                          ),
                                        ],
                                      ),
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.transparent,
                                          shadowColor: Colors.transparent,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                        ),
                                        icon: const Icon(Icons.download_for_offline_rounded, size: 20),
                                        label: Text(
                                          isForced ? 'Update Now to Continue' : 'Download & Install Update',
                                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                                        ),
                                        onPressed: () => _openUpdateUrl(effectiveApkUrl),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      '⚡ High-speed direct download • Auto-installs over current app',
                                      style: TextStyle(fontSize: 10, color: Colors.white38),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],

                                  // Optional Dismiss actions
                                  if (!isForced || !hasUrl) ...[
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextButton(
                                            style: TextButton.styleFrom(
                                              foregroundColor: Colors.white60,
                                              padding: const EdgeInsets.symmetric(vertical: 10),
                                            ),
                                            onPressed: () => setState(() => _dismissedOptionalUpdate = true),
                                            child: const Text('Remind Me Later', style: TextStyle(fontSize: 12)),
                                          ),
                                        ),
                                        Container(
                                          height: 14,
                                          width: 1,
                                          color: Colors.white12,
                                        ),
                                        Expanded(
                                          child: TextButton.icon(
                                            style: TextButton.styleFrom(
                                              foregroundColor: const Color(0xFFFBBF24),
                                              padding: const EdgeInsets.symmetric(vertical: 10),
                                            ),
                                            icon: const Icon(Icons.visibility_off_outlined, size: 14),
                                            label: const Text("Don't Show Again", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                            onPressed: () => _dismissPermanently(remoteVersionCode),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return widget.child;
  }
}
