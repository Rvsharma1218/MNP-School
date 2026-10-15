import 'dart:convert';

class TeacherPermissions {
  final bool canViewStudents;
  final bool canAddStudents;
  final bool canEditStudents;
  final bool canDeleteStudents;
  final bool canMarkAttendance;
  final bool canCollectFees;
  final bool canViewFeeStatus;
  final bool canEnterResults;
  final bool canViewAdmitCards;
  final bool canViewIdCards;
  final bool canPrintCards;
  final bool canManageTimetable;
  final bool canPostNotices;
  final bool canSendWhatsApp;
  final bool canViewTransport;
  final bool canExportReports;
  final bool canManageClasses;
  final bool canMarkTeacherAtt;
  final bool canViewSchoolStatus;
  final bool canViewFacultyList;

  const TeacherPermissions({
    this.canViewStudents = true,
    this.canAddStudents = true,
    this.canEditStudents = true,
    this.canDeleteStudents = true,
    this.canMarkAttendance = true,
    this.canCollectFees = false,
    this.canViewFeeStatus = false,
    this.canEnterResults = true,
    this.canViewAdmitCards = true,
    this.canViewIdCards = true,
    this.canPrintCards = true,
    this.canManageTimetable = true,
    this.canPostNotices = true,
    this.canSendWhatsApp = true,
    this.canViewTransport = false,
    this.canExportReports = false,
    this.canManageClasses = false,
    this.canMarkTeacherAtt = false,
    this.canViewSchoolStatus = false,
    this.canViewFacultyList = false,
  });

  TeacherPermissions copyWith({
    bool? canViewStudents,
    bool? canAddStudents,
    bool? canEditStudents,
    bool? canDeleteStudents,
    bool? canMarkAttendance,
    bool? canCollectFees,
    bool? canViewFeeStatus,
    bool? canEnterResults,
    bool? canViewAdmitCards,
    bool? canViewIdCards,
    bool? canPrintCards,
    bool? canManageTimetable,
    bool? canPostNotices,
    bool? canSendWhatsApp,
    bool? canViewTransport,
    bool? canExportReports,
    bool? canManageClasses,
    bool? canMarkTeacherAtt,
    bool? canViewSchoolStatus,
    bool? canViewFacultyList,
  }) {
    return TeacherPermissions(
      canViewStudents: canViewStudents ?? this.canViewStudents,
      canAddStudents: canAddStudents ?? this.canAddStudents,
      canEditStudents: canEditStudents ?? this.canEditStudents,
      canDeleteStudents: canDeleteStudents ?? this.canDeleteStudents,
      canMarkAttendance: canMarkAttendance ?? this.canMarkAttendance,
      canCollectFees: canCollectFees ?? this.canCollectFees,
      canViewFeeStatus: canViewFeeStatus ?? this.canViewFeeStatus,
      canEnterResults: canEnterResults ?? this.canEnterResults,
      canViewAdmitCards: canViewAdmitCards ?? this.canViewAdmitCards,
      canViewIdCards: canViewIdCards ?? this.canViewIdCards,
      canPrintCards: canPrintCards ?? this.canPrintCards,
      canManageTimetable: canManageTimetable ?? this.canManageTimetable,
      canPostNotices: canPostNotices ?? this.canPostNotices,
      canSendWhatsApp: canSendWhatsApp ?? this.canSendWhatsApp,
      canViewTransport: canViewTransport ?? this.canViewTransport,
      canExportReports: canExportReports ?? this.canExportReports,
      canManageClasses: canManageClasses ?? this.canManageClasses,
      canMarkTeacherAtt: canMarkTeacherAtt ?? this.canMarkTeacherAtt,
      canViewSchoolStatus: canViewSchoolStatus ?? this.canViewSchoolStatus,
      canViewFacultyList: canViewFacultyList ?? this.canViewFacultyList,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'canViewStudents': canViewStudents,
      'canAddStudents': canAddStudents,
      'canEditStudents': canEditStudents,
      'canDeleteStudents': canDeleteStudents,
      'canMarkAttendance': canMarkAttendance,
      'canCollectFees': canCollectFees,
      'canViewFeeStatus': canViewFeeStatus,
      'canEnterResults': canEnterResults,
      'canViewAdmitCards': canViewAdmitCards,
      'canViewIdCards': canViewIdCards,
      'canPrintCards': canPrintCards,
      'canManageTimetable': canManageTimetable,
      'canPostNotices': canPostNotices,
      'canSendWhatsApp': canSendWhatsApp,
      'canViewTransport': canViewTransport,
      'canExportReports': canExportReports,
      'canManageClasses': canManageClasses,
      'canMarkTeacherAtt': canMarkTeacherAtt,
      'canViewSchoolStatus': canViewSchoolStatus,
      'canViewFacultyList': canViewFacultyList,
    };
  }

  factory TeacherPermissions.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const TeacherPermissions();
    bool parseBool(dynamic val, bool fallback) {
      if (val == null) return fallback;
      if (val is bool) return val;
      if (val is String) {
        final lower = val.trim().toLowerCase();
        if (lower == 'true' || lower == '1') return true;
        if (lower == 'false' || lower == '0') return false;
      }
      if (val is num) return val == 1;
      return fallback;
    }

    return TeacherPermissions(
      canViewStudents: parseBool(map['canViewStudents'], true),
      canAddStudents: parseBool(map['canAddStudents'], true),
      canEditStudents: parseBool(map['canEditStudents'], true),
      canDeleteStudents: parseBool(map['canDeleteStudents'], true),
      canMarkAttendance: parseBool(map['canMarkAttendance'], true),
      canCollectFees: parseBool(map['canCollectFees'], false),
      canViewFeeStatus: parseBool(map['canViewFeeStatus'], false),
      canEnterResults: parseBool(map['canEnterResults'], true),
      canViewAdmitCards: parseBool(map['canViewAdmitCards'], true),
      canViewIdCards: parseBool(map['canViewIdCards'], true),
      canPrintCards: parseBool(map['canPrintCards'], true),
      canManageTimetable: parseBool(map['canManageTimetable'], true),
      canPostNotices: parseBool(map['canPostNotices'], true),
      canSendWhatsApp: parseBool(map['canSendWhatsApp'], true),
      canViewTransport: parseBool(map['canViewTransport'], false),
      canExportReports: parseBool(map['canExportReports'], false),
      canManageClasses: parseBool(map['canManageClasses'], false),
      canMarkTeacherAtt: parseBool(map['canMarkTeacherAtt'], false),
      canViewSchoolStatus: parseBool(map['canViewSchoolStatus'], false),
      canViewFacultyList: parseBool(map['canViewFacultyList'], false),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory TeacherPermissions.fromJson(String source) =>
      TeacherPermissions.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
