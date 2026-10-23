import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../attendance/teacher_geofence_service.dart';

class CampusGeofenceSettingsScreen extends StatefulWidget {
  const CampusGeofenceSettingsScreen({super.key});

  @override
  State<CampusGeofenceSettingsScreen> createState() => _CampusGeofenceSettingsScreenState();
}

class _CampusGeofenceSettingsScreenState extends State<CampusGeofenceSettingsScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isDetecting = false;
  bool _isTestingDistance = false;

  CampusGeofenceConfig _config = const CampusGeofenceConfig();
  final _combinedCoordsCtrl = TextEditingController();
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();
  final _radiusCtrl = TextEditingController();

  double _selectedRadius = 300.0;
  bool _geofenceEnabled = true;
  String? _testResult;
  bool? _testSuccess;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _combinedCoordsCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    _radiusCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    setState(() => _isLoading = true);
    final cfg = await TeacherGeofenceService.instance.getCampusConfig();
    if (mounted) {
      setState(() {
        _config = cfg;
        _isLoading = false;
        if (cfg.latitude != null && cfg.longitude != null) {
          final latStr = cfg.latitude!.toStringAsFixed(6);
          final lngStr = cfg.longitude!.toStringAsFixed(6);
          _latCtrl.text = latStr;
          _lngCtrl.text = lngStr;
          _combinedCoordsCtrl.text = '$latStr, $lngStr';
        }
        _selectedRadius = cfg.radiusMeters;
        _geofenceEnabled = cfg.geofenceEnabled;
        _radiusCtrl.text = cfg.radiusMeters.round().toString();
      });
    }
  }

  /// Robust GPS coordinate parser for Google Maps links, DMS, comma separated, etc.
  ({double lat, double lng})? _parseCoordinateInput(String input) {
    final text = input.trim();
    if (text.isEmpty) return null;

    // 1. Google Maps URL regex (q=lat,lng or @lat,lng)
    final urlMatch = RegExp(r'[@?&]q?=([+-]?\d+\.?\d*),([+-]?\d+\.?\d*)').firstMatch(text);
    if (urlMatch != null) {
      final lat = double.tryParse(urlMatch.group(1)!);
      final lng = double.tryParse(urlMatch.group(2)!);
      if (lat != null && lng != null && lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180) {
        return (lat: lat, lng: lng);
      }
    }

    // 2. Degrees Minutes Seconds (DMS) e.g. 26°03'55.8"N 84°22'18.4"E
    final dmsMatch = RegExp(
      r'''(\d+)[°\s]+(\d+)['\s]+([\d.]+)["]?\s*([NSns])[,;\s]+(\d+)[°\s]+(\d+)['\s]+([\d.]+)["]?\s*([EWew])''',
    ).firstMatch(text);
    if (dmsMatch != null) {
      try {
        final latDeg = double.parse(dmsMatch.group(1)!);
        final latMin = double.parse(dmsMatch.group(2)!);
        final latSec = double.parse(dmsMatch.group(3)!);
        final latDir = dmsMatch.group(4)!.toUpperCase();

        final lngDeg = double.parse(dmsMatch.group(5)!);
        final lngMin = double.parse(dmsMatch.group(6)!);
        final lngSec = double.parse(dmsMatch.group(7)!);
        final lngDir = dmsMatch.group(8)!.toUpperCase();

        double lat = latDeg + (latMin / 60.0) + (latSec / 3600.0);
        if (latDir == 'S') lat = -lat;

        double lng = lngDeg + (lngMin / 60.0) + (lngSec / 3600.0);
        if (lngDir == 'W') lng = -lng;

        if (lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180) {
          return (lat: lat, lng: lng);
        }
      } catch (_) {}
    }

    // 3. Comma / space / semicolon separated decimal: "26.065489, 84.371769"
    final decMatch = RegExp(r'([+-]?\d+\.?\d*)\s*[,;\s]\s*([+-]?\d+\.?\d*)').firstMatch(text);
    if (decMatch != null) {
      final lat = double.tryParse(decMatch.group(1)!);
      final lng = double.tryParse(decMatch.group(2)!);
      if (lat != null && lng != null && lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180) {
        return (lat: lat, lng: lng);
      }
    }

    return null;
  }

  void _onCombinedChanged(String val) {
    final parsed = _parseCoordinateInput(val);
    if (parsed != null) {
      _latCtrl.text = parsed.lat.toStringAsFixed(6);
      _lngCtrl.text = parsed.lng.toStringAsFixed(6);
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Clipboard is empty.'), backgroundColor: AppColors.warning),
        );
      }
      return;
    }
    _combinedCoordsCtrl.text = text;
    final parsed = _parseCoordinateInput(text);
    if (parsed != null) {
      setState(() {
        final latStr = parsed.lat.toStringAsFixed(6);
        final lngStr = parsed.lng.toStringAsFixed(6);
        _latCtrl.text = latStr;
        _lngCtrl.text = lngStr;
        _combinedCoordsCtrl.text = '$latStr, $lngStr';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Coordinates detected: ${parsed.lat.toStringAsFixed(6)}, ${parsed.lng.toStringAsFixed(6)}'),
            backgroundColor: const Color(0xFF059669),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not find GPS coordinates in copied text.'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _openInGoogleMaps() async {
    double? lat = double.tryParse(_latCtrl.text.trim());
    double? lng = double.tryParse(_lngCtrl.text.trim());
    if (lat == null || lng == null) {
      if (_config.isConfigured) {
        lat = _config.latitude;
        lng = _config.longitude;
      }
    }
    if (lat == null || lng == null || (lat == 0.0 && lng == 0.0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('School campus coordinates not set yet.'), backgroundColor: AppColors.warning),
      );
      return;
    }

    final geoUri = Uri.parse('geo:$lat,$lng?q=$lat,$lng(School+Campus)');
    final webUri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');

    try {
      bool launched = false;
      // 1. Try native Google Maps intent via geo: scheme
      try {
        launched = await launchUrl(geoUri, mode: LaunchMode.externalApplication);
      } catch (_) {}

      // 2. Fallback to Google Maps web URL in external application
      if (!launched) {
        try {
          launched = await launchUrl(webUri, mode: LaunchMode.externalApplication);
        } catch (_) {}
      }

      // 3. Fallback to platform default browser
      if (!launched) {
        try {
          launched = await launchUrl(webUri, mode: LaunchMode.platformDefault);
        } catch (_) {}
      }

      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Google Maps.'), backgroundColor: AppColors.error),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening Google Maps: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _detectAndSetLocation() async {
    setState(() => _isDetecting = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enable GPS / Location service on your device.'), backgroundColor: AppColors.error),
          );
        }
        setState(() => _isDetecting = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permission was denied.'), backgroundColor: AppColors.error),
            );
          }
          setState(() => _isDetecting = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission is permanently denied. Please enable in phone settings.'), backgroundColor: AppColors.error),
          );
        }
        setState(() => _isDetecting = false);
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 12),
      );

      final latStr = pos.latitude.toStringAsFixed(6);
      final lngStr = pos.longitude.toStringAsFixed(6);
      _latCtrl.text = latStr;
      _lngCtrl.text = lngStr;
      _combinedCoordsCtrl.text = '$latStr, $lngStr';

      final ok = await TeacherGeofenceService.instance.setCampusLocation(
        latitude: pos.latitude,
        longitude: pos.longitude,
        radiusMeters: _selectedRadius,
        geofenceEnabled: _geofenceEnabled,
      );

      if (mounted) {
        if (ok) {
          await _loadConfig();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('School Campus GPS successfully set!\nLat: $latStr, Lng: $lngStr (Accuracy: ±${pos.accuracy.round()}m)'),
              backgroundColor: const Color(0xFF059669),
              duration: const Duration(seconds: 4),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to save campus GPS location.'), backgroundColor: AppColors.error),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error detecting location: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isDetecting = false);
    }
  }

  Future<void> _saveManualCoordinates() async {
    // 1. Try parsing combined input first
    final parsed = _parseCoordinateInput(_combinedCoordsCtrl.text.trim());
    double? lat = parsed?.lat ?? double.tryParse(_latCtrl.text.trim());
    double? lng = parsed?.lng ?? double.tryParse(_lngCtrl.text.trim());
    final radius = double.tryParse(_radiusCtrl.text.trim()) ?? _selectedRadius;

    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter valid GPS coordinates (e.g. 26.065489, 84.371769).'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid GPS coordinate range (-90 to 90, -180 to 180).'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _isSaving = true);
    final ok = await TeacherGeofenceService.instance.setCampusLocation(
      latitude: lat,
      longitude: lng,
      radiusMeters: radius,
      geofenceEnabled: _geofenceEnabled,
    );
    setState(() => _isSaving = false);

    if (mounted) {
      if (ok) {
        await _loadConfig();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Campus GPS & Geofence updated successfully!'), backgroundColor: Color(0xFF059669)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update campus location.'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _testCurrentDistance() async {
    if (!_config.isConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please set School Campus GPS location first.'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() {
      _isTestingDistance = true;
      _testResult = null;
      _testSuccess = null;
    });

    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 12),
      );

      final distanceMeters = Geolocator.distanceBetween(
        _config.latitude!,
        _config.longitude!,
        pos.latitude,
        pos.longitude,
      );

      final accuracyMargin = (pos.accuracy > 0 && pos.accuracy <= 150) ? pos.accuracy : 0.0;
      final effectiveDistance = (distanceMeters - accuracyMargin).clamp(0.0, double.infinity);
      final isInside = !_config.geofenceEnabled || effectiveDistance <= _config.radiusMeters;

      setState(() {
        _testSuccess = isInside;
        if (!_config.geofenceEnabled) {
          _testResult = 'Geofence is Relaxed (Disabled): Teachers can punch in from anywhere!\n(Current Distance: ${distanceMeters.toStringAsFixed(1)}m, Accuracy: ±${pos.accuracy.round()}m)';
        } else if (isInside) {
          _testResult = 'Inside Campus: You are ${distanceMeters.toStringAsFixed(1)}m from center (GPS Accuracy: ±${pos.accuracy.round()}m).\nAllowed radius: ${_config.radiusMeters.round()}m — Punch In will SUCCEED!';
        } else {
          final distStr = distanceMeters >= 1000
              ? '${(distanceMeters / 1000).toStringAsFixed(2)} km'
              : '${distanceMeters.toStringAsFixed(1)} meters';
          _testResult = 'Outside Campus: You are $distStr away from school.\nAllowed radius: ${_config.radiusMeters.round()}m — Punch In will be REJECTED until teacher is inside campus or radius is increased!';
        }
      });
    } catch (e) {
      setState(() {
        _testSuccess = false;
        _testResult = 'Error getting location: $e';
      });
    } finally {
      if (mounted) setState(() => _isTestingDistance = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isConfigured = _config.isConfigured;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('School Campus GPS & Geofence', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (isConfigured)
            IconButton(
              icon: const Icon(Icons.map_rounded),
              tooltip: 'Open in Google Maps',
              onPressed: _openInGoogleMaps,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─── Status Overview Card ───
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isConfigured
                            ? [const Color(0xFF065F46), const Color(0xFF047857)]
                            : [const Color(0xFFB45309), const Color(0xFFD97706)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: (isConfigured ? const Color(0xFF047857) : const Color(0xFFD97706)).withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
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
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isConfigured ? Icons.verified_user_rounded : Icons.warning_amber_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  isConfigured ? 'Campus GPS Configured' : 'GPS Not Configured',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isConfigured ? (_config.geofenceEnabled ? 'ACTIVE (ENFORCED)' : 'RELAXED (NO BLOCK)') : 'ACTION REQUIRED',
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        if (isConfigured) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.place_rounded, color: Colors.white70, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: SelectableText(
                                    '${_config.latitude!.toStringAsFixed(6)}, ${_config.longitude!.toStringAsFixed(6)}',
                                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                                  ),
                                ),
                                InkWell(
                                  onTap: _openInGoogleMaps,
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.25),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.open_in_new_rounded, size: 13, color: Colors.white),
                                        SizedBox(width: 4),
                                        Text('Google Maps', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Allowed Punch-In Radius: ${_config.radiusMeters.round()} meters from school center',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.95), fontSize: 12.5, fontWeight: FontWeight.w500),
                          ),
                          if (!_config.geofenceEnabled)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '• Geofence enforcement is turned OFF: Teachers can punch-in from anywhere with GPS recorded.',
                                style: TextStyle(color: Colors.amber.shade200, fontSize: 12, fontStyle: FontStyle.italic),
                              ),
                            ),
                        ] else ...[
                          const Text(
                            'Enter your coordinates below or tap "Auto-Detect School Location" while you are at the school to lock your campus location.',
                            style: TextStyle(color: Colors.white, fontSize: 13, height: 1.35),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ─── Auto-Detect School Location ───
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.gps_fixed_rounded, color: Color(0xFF2563EB), size: 20),
                            SizedBox(width: 8),
                            Text('Auto-Detect School Location', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Stand at your school main gate or office and tap below. The app will fetch high-precision GPS satellite coordinates automatically.',
                          style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B), height: 1.35),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isDetecting ? null : _detectAndSetLocation,
                            icon: _isDetecting
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.my_location_rounded, size: 18),
                            label: Text(
                              _isDetecting ? 'Fetching GPS Satellite Data...' : 'Set Current Location as School Campus',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ─── Manual / Google Maps Coordinates & Settings ───
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.edit_location_alt_rounded, color: Color(0xFF7C3AED), size: 20),
                            SizedBox(width: 8),
                            Text('Google Maps Coordinates Format', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Google Maps format is: "26.065489, 84.371769" (Latitude, Longitude). You can copy directly from Google Maps or WhatsApp and paste here.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.35),
                        ),
                        const SizedBox(height: 14),

                        // Combined coordinates input with Paste button
                        TextField(
                          controller: _combinedCoordsCtrl,
                          onChanged: _onCombinedChanged,
                          decoration: InputDecoration(
                            labelText: 'School GPS Coordinates (Lat, Long)',
                            hintText: 'e.g. 26.065489, 84.371769 or Maps Link',
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.content_paste_rounded, color: Color(0xFF7C3AED)),
                              tooltip: 'Paste from Clipboard',
                              onPressed: _pasteFromClipboard,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Separate Lat and Long inputs (stay in sync)
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _latCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                                onChanged: (v) {
                                  _combinedCoordsCtrl.text = '$v, ${_lngCtrl.text}';
                                },
                                decoration: const InputDecoration(
                                  labelText: 'Latitude',
                                  hintText: 'e.g. 26.065489',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: _lngCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                                onChanged: (v) {
                                  _combinedCoordsCtrl.text = '${_latCtrl.text}, $v';
                                },
                                decoration: const InputDecoration(
                                  labelText: 'Longitude',
                                  hintText: 'e.g. 84.371769',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Geofence enforcement toggle
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Enforce Geofence for Punch-In', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                            subtitle: Text(
                              _geofenceEnabled
                                  ? 'Teachers MUST be within campus radius to punch-in.'
                                  : 'Teachers can punch-in from anywhere (location still recorded).',
                              style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                            ),
                            value: _geofenceEnabled,
                            activeTrackColor: const Color(0xFF059669),
                            onChanged: (val) {
                              setState(() => _geofenceEnabled = val);
                            },
                          ),
                        ),
                        const SizedBox(height: 16),

                        const Text('Allowed Punch-In Boundary Radius:', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [50.0, 100.0, 200.0, 300.0, 500.0, 1000.0, 2000.0].map((r) {
                            final isSel = (_selectedRadius - r).abs() < 1.0;
                            final label = r >= 1000 ? '${(r / 1000).round()} km' : '${r.round()}m';
                            return ChoiceChip(
                              label: Text(label),
                              selected: isSel,
                              onSelected: (_) {
                                setState(() {
                                  _selectedRadius = r;
                                  _radiusCtrl.text = r.round().toString();
                                });
                              },
                              selectedColor: const Color(0xFF2563EB),
                              labelStyle: TextStyle(
                                color: isSel ? Colors.white : const Color(0xFF334155),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _radiusCtrl,
                          keyboardType: TextInputType.number,
                          onChanged: (v) {
                            final parsed = double.tryParse(v);
                            if (parsed != null && parsed > 0) {
                              setState(() => _selectedRadius = parsed);
                            }
                          },
                          decoration: const InputDecoration(
                            labelText: 'Custom Radius in Meters',
                            suffixText: 'meters',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isSaving ? null : _saveManualCoordinates,
                            icon: _isSaving
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.save_rounded, size: 18),
                            label: Text(_isSaving ? 'Saving...' : 'Save Coordinates & Radius'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF7C3AED),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ─── Test Distance Card ───
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.straighten_rounded, color: Color(0xFF0D9488), size: 20),
                            SizedBox(width: 8),
                            Text('Test Teacher Distance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Test your current real-time distance from the configured school campus to see if punch-in would be accepted right now.',
                          style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B), height: 1.35),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isTestingDistance ? null : _testCurrentDistance,
                            icon: _isTestingDistance
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.radar_rounded, size: 18),
                            label: Text(_isTestingDistance ? 'Calculating Distance...' : 'Calculate My Current Distance'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0D9488),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        if (_testResult != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: (_testSuccess == true ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: (_testSuccess == true ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  _testSuccess == true ? Icons.check_circle_rounded : Icons.cancel_rounded,
                                  color: _testSuccess == true ? const Color(0xFF059669) : const Color(0xFFDC2626),
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _testResult!,
                                    style: TextStyle(
                                      color: _testSuccess == true ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 25),
                ],
              ),
            ),
    );
  }
}
