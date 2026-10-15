import 'dart:convert';

class SettingsModel {
  final String instituteName;
  final String? tagline;
  final String? logoPath;
  final String address;
  final String mobile;
  final String? email;
  final String? website;
  final String? principalName;
  final String? affiliationNumber;
  final String? principalSignature;
  final String? schoolStamp; // Base64 transparent PNG or URL
  final String? rawSignature; // Original uploaded signature
  final String signatureColorMode; // 'white' | 'gold' | 'dark' | 'blue'
  final String currentSession; // e.g. '2026-27'
  final String themeMode; // 'system' | 'light' | 'dark'
  final String appLanguage; // 'en' | 'hi'
  final List<String> schoolClasses;
  final List<String> computerCourses;
  // Website-compatible fields (schools/{schoolId}/settings/config)
  final List<String> sections;   // e.g. ['A', 'B', 'C']
  final List<String> batches;    // Computer course time batches

  static const List<String> defaultClasses = [
    'Nursery', 'LKG', 'UKG', '1st', '2nd', '3rd', '4th', '5th',
    '6th', '7th', '8th', '9th', '10th', '11th', '11th-Math', '11th-Bio',
    '11th-Arts', '11th-Commerce', '12th', '12th-Math', '12th-Bio',
    '12th-Arts', '12th-Commerce'
  ];

  static const List<String> defaultCourses = [
    'ADCA (12 Months)', 'DCA (6 Months)', 'CCC (3 Months)',
    'Tally Prime with GST (3 Months)', 'Python & Web Dev (6 Months)',
    'Graphic Design (6 Months)', 'DTP (3 Months)', 'O Level (12 Months)',
    'Basic Computer (3 Months)', 'Java & C++ (6 Months)'
  ];

  static const List<String> defaultSections = ['A', 'B', 'C'];

  static const List<String> defaultBatches = [
    '08:00 AM - 10:00 AM',
    '10:00 AM - 12:00 PM',
    '12:00 PM - 02:00 PM',
    '03:00 PM - 05:00 PM',
    '05:00 PM - 07:00 PM',
  ];

  SettingsModel({
    required this.instituteName,
    this.tagline,
    this.logoPath,
    required this.address,
    required this.mobile,
    this.email,
    this.website,
    this.principalName,
    this.affiliationNumber,
    this.principalSignature,
    this.schoolStamp,
    this.rawSignature,
    this.signatureColorMode = 'white',
    this.currentSession = '2026-27',
    this.themeMode = 'light',
    this.appLanguage = 'en',
    this.schoolClasses = defaultClasses,
    this.computerCourses = defaultCourses,
    this.sections = defaultSections,
    this.batches = defaultBatches,
    this.stampScale = 1.0,
    this.signatureScale = 1.0,
  });

  final double stampScale;
  final double signatureScale;

  String get phone => mobile;
  String get schoolName => instituteName;
  String get receiptPrefix => 'REC';
  String? get logoUrl => logoPath;
  String? get signatureUrl => principalSignature;
  String? get stampUrl => schoolStamp;

  Map<String, dynamic> toMap() {
    return {
      'instituteName': instituteName,
      'schoolName': instituteName,
      'tagline': tagline,
      'logoPath': logoPath,
      'logoUrl': logoPath,
      'address': address,
      'mobile': mobile,
      'phone': mobile,
      'email': email,
      'website': website,
      'principalName': principalName,
      'affiliationNumber': affiliationNumber,
      'principalSignature': principalSignature,
      'signatureUrl': principalSignature,
      'schoolStamp': schoolStamp,
      'stampUrl': schoolStamp,
      'rawSignature': rawSignature,
      'signatureColorMode': signatureColorMode,
      'currentSession': currentSession,
      'academicYear': currentSession,
      'receiptPrefix': receiptPrefix,
      'themeMode': themeMode,
      'appLanguage': appLanguage,
      'schoolClasses': schoolClasses,
      'computerCourses': computerCourses,
      'sections': sections,
      'batches': batches,
      'stampScale': stampScale,
      'signatureScale': signatureScale,
    };
  }

  factory SettingsModel.fromMap(Map<String, dynamic> map) {
    List<String> parseList(dynamic val, List<String> fallback) {
      if (val == null) return List<String>.from(fallback);
      if (val is List) return val.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
      if (val is String) {
        final trimmed = val.trim();
        if (trimmed.isEmpty) return [];
        if (trimmed.startsWith('[')) {
          try {
            final decoded = jsonDecode(trimmed);
            if (decoded is List) return decoded.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
          } catch (_) {}
        }
        return trimmed.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      }
      return List<String>.from(fallback);
    }

    return SettingsModel(
      instituteName: map['instituteName'] ?? map['schoolName'] ?? 'My Institute',
      tagline: map['tagline'],
      logoPath: map['logoPath'] ?? map['logoUrl'] ?? map['logo'] ?? map['photoUrl'],
      address: map['address'] ?? '',
      mobile: map['mobile'] ?? map['phone'] ?? '',
      email: map['email'],
      website: map['website'],
      principalName: map['principalName'],
      affiliationNumber: map['affiliationNumber'],
      principalSignature: map['principalSignature'] ?? map['signatureUrl'] ?? map['signature'] ?? map['sign'],
      schoolStamp: map['schoolStamp'] ?? map['stampUrl'] ?? map['stamp'] ?? map['sealUrl'],
      rawSignature: map['rawSignature'],
      signatureColorMode: map['signatureColorMode'] ?? 'white',
      currentSession: map['currentSession'] ?? map['academicYear'] ?? '2026-27',
      themeMode: map['themeMode'] ?? 'light',
      appLanguage: map['appLanguage']?.toString() ?? 'en',
      schoolClasses: parseList(map['schoolClasses'], defaultClasses),
      computerCourses: parseList(map['computerCourses'], defaultCourses),
      sections: parseList(map['sections'], defaultSections),
      batches: parseList(map['batches'], defaultBatches),
      stampScale: (map['stampScale'] as num?)?.toDouble() ?? 1.0,
      signatureScale: (map['signatureScale'] as num?)?.toDouble() ?? 1.0,
    );
  }

  factory SettingsModel.defaultSettings() {
    return SettingsModel(
      instituteName: 'My School & Institute',
      tagline: '',
      address: 'Enter Address Here',
      mobile: '9876543210',
      currentSession: '2026-27',
      themeMode: 'light',
      appLanguage: 'en',
      signatureColorMode: 'white',
      schoolClasses: defaultClasses,
      computerCourses: defaultCourses,
      sections: defaultSections,
      batches: defaultBatches,
      stampScale: 1.0,
      signatureScale: 1.0,
    );
  }

  SettingsModel copyWith({
    String? instituteName,
    String? tagline,
    String? logoPath,
    String? address,
    String? mobile,
    String? email,
    String? website,
    String? principalName,
    String? affiliationNumber,
    String? principalSignature,
    String? schoolStamp,
    String? rawSignature,
    String? signatureColorMode,
    String? currentSession,
    String? themeMode,
    String? appLanguage,
    List<String>? schoolClasses,
    List<String>? computerCourses,
    List<String>? sections,
    List<String>? batches,
    double? stampScale,
    double? signatureScale,
  }) {
    return SettingsModel(
      instituteName: instituteName ?? this.instituteName,
      tagline: tagline ?? this.tagline,
      logoPath: logoPath ?? this.logoPath,
      address: address ?? this.address,
      mobile: mobile ?? this.mobile,
      email: email ?? this.email,
      website: website ?? this.website,
      principalName: principalName ?? this.principalName,
      affiliationNumber: affiliationNumber ?? this.affiliationNumber,
      principalSignature: principalSignature ?? this.principalSignature,
      schoolStamp: schoolStamp ?? this.schoolStamp,
      rawSignature: rawSignature ?? this.rawSignature,
      signatureColorMode: signatureColorMode ?? this.signatureColorMode,
      currentSession: currentSession ?? this.currentSession,
      themeMode: themeMode ?? this.themeMode,
      appLanguage: appLanguage ?? this.appLanguage,
      schoolClasses: schoolClasses ?? this.schoolClasses,
      computerCourses: computerCourses ?? this.computerCourses,
      sections: sections ?? this.sections,
      batches: batches ?? this.batches,
      stampScale: stampScale ?? this.stampScale,
      signatureScale: signatureScale ?? this.signatureScale,
    );
  }

  static List<String> getSessions() {
    final now = DateTime.now();
    final List<String> sessions = [];
    for (int i = -1; i <= 3; i++) {
      final y = now.year + i;
      sessions.add('$y-${(y + 1).toString().substring(2)}');
    }
    return sessions;
  }
}
