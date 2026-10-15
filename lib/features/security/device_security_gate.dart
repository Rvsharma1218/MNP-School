import 'dart:async';
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
      final apkUrl = (data['apkUrl']?.toString() ?? '').trim();
      final isForced = data['forceUpdate'] == true && apkUrl.isNotEmpty;

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
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Colors.amber, width: 0.8),
        ),
        duration: const Duration(seconds: 7),
        content: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.notifications_active_rounded, color: Colors.amber, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    body,
                    style: const TextStyle(fontSize: 11, color: Colors.white70),
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
      final apkUrl = (_pendingUpdate!['apkUrl']?.toString() ?? '').trim();
      final hasUrl = apkUrl.isNotEmpty;
      final isForced = _pendingUpdate!['forceUpdate'] == true && hasUrl;
      final newVer = _pendingUpdate!['latestVersion']?.toString() ?? '2.0.2';
      final notes = _pendingUpdate!['releaseNotes']?.toString() ?? 'Performance fixes & updates.';

      return Stack(
        children: [
          widget.child,
          // Update Modal Overlay
          PopScope(
            canPop: !isForced,
            child: Container(
              color: Colors.black.withValues(alpha: isForced ? 0.92 : 0.70),
              alignment: Alignment.center,
              padding: const EdgeInsets.all(24),
              child: Material(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(20),
                elevation: 12,
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.purpleAccent.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.rocket_launch_rounded, color: Colors.purpleAccent, size: 40),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        isForced ? 'Mandatory App Update' : 'New Update Available!',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.purpleAccent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'v$newVer Available (Current: v$currentVersion)',
                          style: const TextStyle(color: Colors.purpleAccent, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'WHAT\'S NEW:',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white38, letterSpacing: 0.8),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              notes,
                              style: const TextStyle(fontSize: 12, color: Colors.white70, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (!hasUrl)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.info_outline_rounded, color: Colors.amber, size: 16),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Broadcast test notice without direct APK link. You can dismiss this prompt.',
                                  style: TextStyle(color: Colors.amber, fontSize: 11),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (hasUrl)
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purpleAccent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.download_rounded),
                            label: const Text('Download & Update Now', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            onPressed: () => _openUpdateUrl(apkUrl),
                          ),
                        ),
                      if (!isForced || !hasUrl) ...[
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            TextButton(
                              onPressed: () => setState(() => _dismissedOptionalUpdate = true),
                              child: const Text('Remind Me Later', style: TextStyle(color: Colors.white54, fontSize: 12)),
                            ),
                            TextButton.icon(
                              icon: const Icon(Icons.visibility_off_outlined, size: 14, color: Colors.amberAccent),
                              label: const Text('Don\'t Show Again', style: TextStyle(color: Colors.amberAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                              onPressed: () => _dismissPermanently(remoteVersionCode),
                            ),
                          ],
                        ),
                      ],
                    ],
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
