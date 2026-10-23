import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/session_service.dart';
import 'teacher_geofence_service.dart';

class TeacherPunchInCard extends StatefulWidget {
  final bool isPrincipal;
  const TeacherPunchInCard({super.key, this.isPrincipal = false});

  @override
  State<TeacherPunchInCard> createState() => _TeacherPunchInCardState();
}

class _TeacherPunchInCardState extends State<TeacherPunchInCard> {
  bool _isLoading = false;
  Map<String, dynamic>? _todayPunch;
  CampusGeofenceConfig? _campusConfig;
  bool _fetchingInitial = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  String _getTeacherId() {
    final sess = SessionService.instance;
    if (sess.teacherId?.isNotEmpty ?? false) {
      return sess.teacherId!;
    }
    final user = AuthService.instance.currentUser;
    if (user != null && user.email != null) {
      final email = user.email!.toLowerCase();
      final match = RegExp(r'\.([tT]\d{3,})@').firstMatch(email);
      if (match != null) {
        return match.group(1)!.toUpperCase();
      }
    }
    return user?.uid ?? '';
  }

  String _getTeacherName() {
    final sess = SessionService.instance;
    if (sess.teacherName?.isNotEmpty ?? false) {
      return sess.teacherName!;
    }
    final user = AuthService.instance.currentUser;
    if (user?.displayName?.isNotEmpty ?? false) {
      return user!.displayName!;
    }
    if (user?.email != null) {
      final part = user!.email!.split('@').first.split('.').first;
      if (part.isNotEmpty) {
        return part[0].toUpperCase() + part.substring(1);
      }
    }
    return 'Teacher';
  }

  Future<void> _loadInitialData() async {
    final teacherId = _getTeacherId();
    final punch = await TeacherGeofenceService.instance.getTodayPunchIn(teacherId: teacherId);
    final config = await TeacherGeofenceService.instance.getCampusConfig();
    if (mounted) {
      setState(() {
        _todayPunch = punch;
        _campusConfig = config;
        _fetchingInitial = false;
      });
    }
  }

  Future<void> _handlePunchIn() async {
    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    try {
      final res = await TeacherGeofenceService.instance.punchIn(
        teacherId: _getTeacherId(),
        teacherName: _getTeacherName(),
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (res.isSuccess) {
        HapticFeedback.heavyImpact();
        await _loadInitialData();

        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 28),
                SizedBox(width: 10),
                Text('Punch-In Verified', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  res.message,
                  style: const TextStyle(fontSize: 14, color: Color(0xFF334155), height: 1.4),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.verified_user_rounded, color: Color(0xFF059669), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Marked Present for ${DateFormat('dd MMMM yyyy').format(DateTime.now())}',
                          style: const TextStyle(color: Color(0xFF065F46), fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Great!'),
              ),
            ],
          ),
        );
      } else {
        HapticFeedback.vibrate();
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.location_off_rounded, color: Color(0xFFEF4444), size: 26),
                SizedBox(width: 10),
                Text('Campus Geofence Notice', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  res.message,
                  style: const TextStyle(fontSize: 13.5, color: Color(0xFF475569), height: 1.4),
                ),
                if (res.distanceMeters != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, color: Color(0xFFDC2626), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Allowed Range: within ${res.radiusMeters?.round() ?? 300}m of school.\nCurrent Distance: ~${res.distanceMeters?.round()}m',
                            style: const TextStyle(color: Color(0xFF991B1B), fontSize: 11.5, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK, Understood'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('GPS verification error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _showSetCampusDialog() async {
    final pos = await Geolocator.getLastKnownPosition() ?? await Geolocator.getCurrentPosition();
    if (!mounted) return;

    double radius = _campusConfig?.radiusMeters ?? 300.0;
    final radiusCtrl = TextEditingController(text: radius.round().toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.edit_location_alt_rounded, color: Color(0xFF2563EB), size: 24),
            SizedBox(width: 10),
            Text('Set Campus GPS Location', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Set your current physical position as the official School Campus Geofence center point.',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.3),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Lat: ${pos.latitude.toStringAsFixed(6)}\nLng: ${pos.longitude.toStringAsFixed(6)}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: radiusCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Allowed Radius (Meters)',
                hintText: '300',
                suffixText: 'meters',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final r = double.tryParse(radiusCtrl.text) ?? 300.0;
              final ok = await TeacherGeofenceService.instance.setCampusLocation(
                latitude: pos.latitude,
                longitude: pos.longitude,
                radiusMeters: r,
              );
              if (ctx.mounted) Navigator.pop(ctx);
              if (ok) {
                _loadInitialData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Campus Geofence updated successfully!'), backgroundColor: Colors.green),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
            child: const Text('Save Campus Location'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_fetchingInitial) {
      return const SizedBox();
    }

    final isPunchedIn = _todayPunch != null;
    final punchTime = _todayPunch?['timeStr'] ?? '';
    final distance = _todayPunch?['distanceMeters'];

    if (isPunchedIn) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF065F46), Color(0xFF059669)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF059669).withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.verified_rounded, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Text(
                        'TODAY PRESENT',
                        style: TextStyle(color: Color(0xFFA7F3D0), fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 0.5),
                      ),
                      SizedBox(width: 6),
                      Icon(Icons.check_circle_rounded, color: Color(0xFFA7F3D0), size: 14),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Punched In at $punchTime',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Campus GPS Verified • ${distance != null ? '${distance}m from center' : 'On Campus'}',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 11.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Not Punched In Yet -> Punch-In Card
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF334155)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
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
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.4)),
                ),
                child: const Icon(Icons.share_location_rounded, color: Color(0xFF60A5FA), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Teacher Campus Attendance',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _campusConfig?.geofenceEnabled == false
                          ? 'Campus GPS Active • Location will be recorded'
                          : 'Mark present within ${_campusConfig?.radiusMeters.round() ?? 300}m of ${_campusConfig?.campusName ?? 'School Campus'}',
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (widget.isPrincipal)
                IconButton(
                  icon: const Icon(Icons.settings_outlined, color: Color(0xFF94A3B8), size: 20),
                  tooltip: 'Configure Campus Coordinates',
                  onPressed: _showSetCampusDialog,
                ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _handlePunchIn,
              icon: _isLoading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.fingerprint_rounded, size: 22),
              label: Text(
                _isLoading ? 'Verifying Campus GPS...' : 'Punch In Attendance Now',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
