import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
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

class _DeviceSecurityGateState extends State<DeviceSecurityGate> with TickerProviderStateMixin {
  static int currentVersionCode = 2015;
  static String currentVersion = '2.0.8';

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  late final AnimationController _rotateController;

  HttpClient? _downloadClient;
  bool _isDownloadingUpdate = false;
  double _downloadProgress = 0.0;
  int _downloadedBytes = 0;
  int _totalBytes = 0;
  String _downloadStatus = 'Preparing...';
  String? _downloadError;
  String? _downloadedApkPath;

  bool _isSemanticVersionHigher(String remote, String current) {
    try {
      final rParts = remote.split('.').map((e) => int.tryParse(e.replaceAll(RegExp(r'\D'), '')) ?? 0).toList();
      final cParts = current.split('.').map((e) => int.tryParse(e.replaceAll(RegExp(r'\D'), '')) ?? 0).toList();
      while (rParts.length < 3) { rParts.add(0); }
      while (cParts.length < 3) { cParts.add(0); }
      for (int i = 0; i < 3; i++) {
        if (rParts[i] > cParts[i]) return true;
        if (rParts[i] < cParts[i]) return false;
      }
    } catch (_) {}
    return false;
  }

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
    _initAppVersion();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
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
    _pulseController.dispose();
    _rotateController.dispose();
    _downloadClient?.close(force: true);
    _revocationSub?.cancel();
    _alertSub?.cancel();
    _updateSub?.cancel();
    super.dispose();
  }

  Future<void> _initAppVersion() async {
    try {
      const platform = MethodChannel('school_app/whatsapp');
      final res = await platform.invokeMapMethod<String, dynamic>('getAppVersion');
      if (res != null) {
        final code = int.tryParse(res['versionCode']?.toString() ?? '') ?? 0;
        final name = (res['versionName']?.toString() ?? '').trim();
        if (code > 0) currentVersionCode = code;
        if (name.isNotEmpty) currentVersion = name;
        if (mounted) setState(() {});
      }
    } catch (_) {}
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
      final remoteVersion = (data['latestVersion']?.toString() ?? '').trim();
      final effectiveApkUrl = _resolveDeviceApkUrl(data);
      final isForced = data['forceUpdate'] == true && effectiveApkUrl.isNotEmpty;

      final isNewerBuild = remoteVersionCode > currentVersionCode;
      final isNewerVersion = remoteVersion.isNotEmpty && _isSemanticVersionHigher(remoteVersion, currentVersion);
      final isSameOrOlder = remoteVersionCode <= currentVersionCode && (remoteVersion == currentVersion || !_isSemanticVersionHigher(remoteVersion, currentVersion));
      final shouldPrompt = !isSameOrOlder && (isNewerBuild || isNewerVersion || (isForced && (remoteVersionCode > currentVersionCode || remoteVersion != currentVersion)));

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

      if (shouldPrompt) {
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

  Future<void> _startInAppUpdate(String apkUrl) async {
    if (_isDownloadingUpdate) return;
    if (apkUrl.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Update URL is missing'), backgroundColor: Colors.redAccent),
        );
      }
      return;
    }

    setState(() {
      _isDownloadingUpdate = true;
      _downloadError = null;
      _downloadedApkPath = null;
    });

    _pulseController.repeat(reverse: true);
    _rotateController.repeat();

    final dir = await getTemporaryDirectory();
    final apkFile = File('${dir.path}/mnp_school_update.apk');

    // Build primary and mirror CDN URLs for maximum reliability
    final primaryUrl = apkUrl.trim();
    String mirrorUrl = '';
    if (primaryUrl.contains('mnp-school.vercel.app')) {
      mirrorUrl = primaryUrl.replaceAll('https://mnp-school.vercel.app', 'https://raw.githubusercontent.com/Rvsharma1218/MNP-School/master/public');
    } else if (primaryUrl.contains('raw.githubusercontent.com')) {
      mirrorUrl = primaryUrl.replaceAll('https://raw.githubusercontent.com/Rvsharma1218/MNP-School/master/public', 'https://mnp-school.vercel.app');
    }

    int retryCount = 0;
    const maxRetries = 7;
    bool completed = false;

    while (retryCount < maxRetries && !completed && _isDownloadingUpdate) {
      HttpClient? client;
      IOSink? sink;
      try {
        // Switch between primary and high-speed mirror CDN if retrying
        final currentUrl = (retryCount >= 2 && mirrorUrl.isNotEmpty) ? mirrorUrl : primaryUrl;
        final uri = Uri.parse(currentUrl);

        client = HttpClient();
        client.connectionTimeout = const Duration(seconds: 15);
        _downloadClient = client;

        // Check already downloaded bytes for resume support
        int existingBytes = 0;
        if (await apkFile.exists()) {
          existingBytes = await apkFile.length();
        }

        final request = await client.getUrl(uri);
        request.headers.set(HttpHeaders.userAgentHeader, 'MNPSchoolApp/2.0');
        request.headers.set(HttpHeaders.acceptEncodingHeader, 'identity'); // prevent gzip chunking so Content-Length is exact
        if (existingBytes > 0) {
          request.headers.set(HttpHeaders.rangeHeader, 'bytes=$existingBytes-');
        }

        final response = await request.close();

        // 200 = OK (Full download), 206 = Partial Content (Resumed)
        if (response.statusCode != 200 && response.statusCode != 206) {
          if (response.statusCode == 416) {
            // Range not satisfiable (file already full or server mismatch), clean and restart
            if (await apkFile.exists()) {
              await apkFile.delete();
            }
            existingBytes = 0;
            retryCount++;
            continue;
          }
          throw Exception('Server returned HTTP ${response.statusCode}');
        }

        int total = 0;
        if (response.statusCode == 206) {
          final contentRange = response.headers.value('content-range');
          if (contentRange != null && contentRange.contains('/')) {
            total = int.tryParse(contentRange.split('/').last) ?? (existingBytes + response.contentLength);
          } else {
            total = existingBytes + response.contentLength;
          }
        } else {
          // If 200 was returned when we had partial bytes, server doesn't support range; restart file
          if (existingBytes > 0 && await apkFile.exists()) {
            await apkFile.delete();
            existingBytes = 0;
          }
          total = response.contentLength;
        }

        if (mounted) {
          setState(() {
            _totalBytes = total > 0 ? total : 0;
            _downloadedBytes = existingBytes;
            _downloadProgress = (total > 0 && existingBytes > 0) ? (existingBytes / total).clamp(0.0, 1.0) : _downloadProgress;
            _downloadStatus = existingBytes > 0
                ? 'Resuming download: ${(_downloadProgress * 100).toInt()}%'
                : 'Downloading update package...';
          });
        }

        sink = apkFile.openWrite(mode: existingBytes > 0 ? FileMode.append : FileMode.write);
        int received = existingBytes;
        DateTime lastUiTick = DateTime.now();

        await for (final chunk in response) {
          if (!_isDownloadingUpdate) break; // User cancelled
          sink.add(chunk);
          received += chunk.length;

          final now = DateTime.now();
          if (now.difference(lastUiTick).inMilliseconds > 70 || (total > 0 && received >= total)) {
            lastUiTick = now;
            if (mounted) {
              setState(() {
                _downloadedBytes = received;
                _downloadProgress = total > 0 ? (received / total).clamp(0.0, 1.0) : 0.0;
                final percent = (_downloadProgress * 100).toInt();
                _downloadStatus = 'Downloading update: $percent%';
              });
            }
          }
        }

        await sink.flush();
        await sink.close();
        sink = null;

        if (!_isDownloadingUpdate) return;

        // Check if finished
        if (total > 0 && received >= total) {
          completed = true;
          if (mounted) {
            setState(() {
              _downloadProgress = 1.0;
              _downloadedBytes = received;
              _downloadStatus = '✓ Download complete! Launching installer...';
              _downloadedApkPath = apkFile.path;
              _isDownloadingUpdate = false;
            });
          }
          _pulseController.stop();
          _rotateController.stop();
          await _launchApkInstaller(apkFile.path, fallbackUrl: apkUrl);
          return;
        }

      } catch (e) {
        if (!_isDownloadingUpdate) return;
        retryCount++;
        if (sink != null) {
          try {
            await sink.flush();
            await sink.close();
          } catch (_) {}
          sink = null;
        }

        if (retryCount < maxRetries && _isDownloadingUpdate) {
          final resumeMb = ((await apkFile.exists() ? await apkFile.length() : 0) / (1024 * 1024)).toStringAsFixed(1);
          if (mounted) {
            setState(() {
              _downloadStatus = 'Connection slow, auto-resuming from ${resumeMb}MB ($retryCount/$maxRetries)...';
            });
          }
          await Future.delayed(Duration(seconds: 1 + retryCount));
        } else {
          if (mounted) {
            setState(() {
              _downloadError = 'Download paused. Tap "Resume Download" to continue without losing progress.';
              _isDownloadingUpdate = false;
            });
          }
          _pulseController.stop();
          _rotateController.stop();
        }
      } finally {
        client?.close();
        _downloadClient = null;
      }
    }
  }

  Future<void> _launchApkInstaller(String filePath, {required String fallbackUrl}) async {
    try {
      const platform = MethodChannel('school_app/whatsapp');
      final res = await platform.invokeMethod('installApk', {'filePath': filePath});
      if (res != true) {
        throw Exception('Install intent could not be started');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Opening via browser: $e'),
            backgroundColor: Colors.orangeAccent,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      await _openUpdateUrl(fallbackUrl);
    }
  }

  void _cancelInAppUpdate() {
    _downloadClient?.close(force: true);
    _downloadClient = null;
    _pulseController.stop();
    _rotateController.stop();
    if (mounted) {
      setState(() {
        _isDownloadingUpdate = false;
        _downloadProgress = 0.0;
        _downloadStatus = 'Download paused';
        _downloadError = 'Download paused. Tap Resume to continue.';
        _downloadError = null;
      });
    }
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
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: isForced ? null : () => setState(() => _dismissedOptionalUpdate = true),
                child: Container(
                  color: Colors.black.withValues(alpha: isForced ? 0.88 : 0.65),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: GestureDetector(
                    onTap: () {}, // Absorb click inside modal
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
                                  // Top Row: Status Tag & Optional Close 'X' Button
                                  Row(
                                    children: [
                                      const SizedBox(width: 32),
                                      const Spacer(),
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
                                      const Spacer(),
                                      if (!isForced)
                                        InkWell(
                                          borderRadius: BorderRadius.circular(20),
                                          onTap: () => setState(() => _dismissedOptionalUpdate = true),
                                          child: Container(
                                            padding: const EdgeInsets.all(5),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withValues(alpha: 0.1),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(Icons.close_rounded, size: 16, color: Colors.white70),
                                          ),
                                        )
                                      else
                                        const SizedBox(width: 32),
                                    ],
                                  ),
                                  const SizedBox(height: 16),

                                  // Glowing Center Icon with Live Pulse & Rotation Animation
                                  AnimatedBuilder(
                                    animation: _pulseAnimation,
                                    builder: (context, child) {
                                      return Transform.scale(
                                        scale: _isDownloadingUpdate ? _pulseAnimation.value : 1.0,
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            if (_isDownloadingUpdate)
                                              RotationTransition(
                                                turns: _rotateController,
                                                child: Container(
                                                  width: 86,
                                                  height: 86,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color: const Color(0xFF38BDF8).withValues(alpha: 0.6),
                                                      width: 2,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            Container(
                                              width: 76,
                                              height: 76,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                gradient: LinearGradient(
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                  colors: _downloadedApkPath != null
                                                      ? [const Color(0xFF10B981), const Color(0xFF059669)]
                                                      : (isForced
                                                          ? [const Color(0xFFEF4444), const Color(0xFF991B1B)]
                                                          : [const Color(0xFF6366F1), const Color(0xFF38BDF8)]),
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: (_downloadedApkPath != null
                                                            ? const Color(0xFF10B981)
                                                            : (isForced ? const Color(0xFFEF4444) : const Color(0xFF6366F1)))
                                                        .withValues(alpha: _isDownloadingUpdate ? 0.7 : 0.45),
                                                    blurRadius: _isDownloadingUpdate ? 28 : 20,
                                                    spreadRadius: _isDownloadingUpdate ? 3 : 0,
                                                    offset: const Offset(0, 6),
                                                  ),
                                                ],
                                              ),
                                              child: Center(
                                                child: Icon(
                                                  _downloadedApkPath != null
                                                      ? Icons.check_circle_rounded
                                                      : (_isDownloadingUpdate
                                                          ? Icons.cloud_download_rounded
                                                          : Icons.rocket_launch_rounded),
                                                  color: Colors.white,
                                                  size: 38,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
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

                            // Body: Release notes, Animated Live Download Progress & Actions
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                              child: Column(
                                children: [
                                  // Live Download Progress Card (When updating in-app)
                                  if (_isDownloadingUpdate || _downloadedApkPath != null) ...[
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0F172A).withValues(alpha: 0.9),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: _downloadedApkPath != null
                                              ? const Color(0xFF10B981).withValues(alpha: 0.6)
                                              : const Color(0xFF38BDF8).withValues(alpha: 0.5),
                                          width: 1.4,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: (_downloadedApkPath != null ? const Color(0xFF10B981) : const Color(0xFF38BDF8)).withValues(alpha: 0.15),
                                            blurRadius: 16,
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(6),
                                                decoration: BoxDecoration(
                                                  color: (_downloadedApkPath != null ? const Color(0xFF10B981) : const Color(0xFF38BDF8)).withValues(alpha: 0.15),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Icon(
                                                  _downloadedApkPath != null ? Icons.check_circle_rounded : Icons.sync_rounded,
                                                  size: 16,
                                                  color: _downloadedApkPath != null ? const Color(0xFF10B981) : const Color(0xFF38BDF8),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  _downloadedApkPath != null
                                                      ? 'UPDATE READY TO INSTALL'
                                                      : 'DOWNLOADING UPDATE...',
                                                  style: TextStyle(
                                                    color: _downloadedApkPath != null ? const Color(0xFF10B981) : const Color(0xFF38BDF8),
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w800,
                                                    letterSpacing: 0.8,
                                                  ),
                                                ),
                                              ),
                                              Text(
                                                '${(_downloadProgress * 100).toInt()}%',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(6),
                                            child: SizedBox(
                                              height: 8,
                                              child: LinearProgressIndicator(
                                                value: _downloadProgress > 0 ? _downloadProgress : null,
                                                backgroundColor: Colors.white12,
                                                valueColor: AlwaysStoppedAnimation<Color>(
                                                  _downloadedApkPath != null ? const Color(0xFF10B981) : const Color(0xFF38BDF8),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  _downloadStatus,
                                                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              if (_totalBytes > 0)
                                                Text(
                                                  '${(_downloadedBytes / (1024 * 1024)).toStringAsFixed(1)} / ${(_totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB',
                                                  style: const TextStyle(color: Colors.white60, fontSize: 10.5, fontWeight: FontWeight.w600),
                                                ),
                                            ],
                                          ),
                                          if (_downloadError != null) ...[
                                            const SizedBox(height: 10),
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: Colors.redAccent.withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                _downloadError!,
                                                style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 11),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                  ] else ...[
                                    // What's New Box (Shown before download starts)
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
                                  ],

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

                                  // Action Buttons Area
                                  if (hasUrl) ...[
                                    if (_downloadedApkPath != null) ...[
                                      // State 3: Download finished, ready to install
                                      Container(
                                        width: double.infinity,
                                        height: 52,
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [Color(0xFF10B981), Color(0xFF059669)],
                                          ),
                                          borderRadius: BorderRadius.circular(14),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFF10B981).withValues(alpha: 0.4),
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
                                          icon: const Icon(Icons.install_mobile_rounded, size: 22),
                                          label: const Text(
                                            'Tap to Install Update',
                                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                                          ),
                                          onPressed: () => _launchApkInstaller(_downloadedApkPath!, fallbackUrl: effectiveApkUrl),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      const Text(
                                        '✓ Package downloaded. Tap to launch Android installer.',
                                        style: TextStyle(fontSize: 10.5, color: Colors.white60),
                                        textAlign: TextAlign.center,
                                      ),
                                    ] else if (_isDownloadingUpdate) ...[
                                      // State 2: Actively downloading in popup
                                      Container(
                                        width: double.infinity,
                                        height: 48,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(color: Colors.white12),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF38BDF8)),
                                            ),
                                            const SizedBox(width: 10),
                                            Text(
                                              'Downloading in Progress (${(_downloadProgress * 100).toInt()}%)',
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      TextButton(
                                        onPressed: _cancelInAppUpdate,
                                        style: TextButton.styleFrom(foregroundColor: Colors.white54),
                                        child: const Text('Cancel Download', style: TextStyle(fontSize: 11)),
                                      ),
                                    ] else ...[
                                      // State 1: Ready to start update
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
                                            _downloadProgress > 0 && _downloadError != null ? 'Resume Download (${(_downloadProgress * 100).toInt()}%)' : (isForced ? 'Update Now to Continue' : 'Download & Install Update'),
                                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                                          ),
                                          onPressed: () => _startInAppUpdate(effectiveApkUrl),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Text(
                                            '⚡ In-App direct download • ',
                                            style: TextStyle(fontSize: 10.5, color: Colors.white38),
                                          ),
                                          InkWell(
                                            onTap: () => _openUpdateUrl(effectiveApkUrl),
                                            child: const Text(
                                              'Or open in browser',
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                color: Color(0xFF818CF8),
                                                fontWeight: FontWeight.bold,
                                                decoration: TextDecoration.underline,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
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
        ),
      ),
    ],
  );
    }

    return widget.child;
  }
}
