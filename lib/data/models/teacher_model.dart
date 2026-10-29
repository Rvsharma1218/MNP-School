import 'package:cloud_firestore/cloud_firestore.dart';

class TeacherModel {
  final String authUid;
  final String teacherId;
  final String id;
  final String name;
  final String authEmail;
  final String email;
  final String mobile;
  final String password;
  final String schoolId;
  final String? assignedClass;   // e.g. "Class 5" or "Nursery"
  final String? assignedSection; // e.g. "A"
  final bool active;
  final String status;
  final DateTime createdAt;

  // ── Extended details (just like Student) ──
  final String? fatherName;
  final String? motherName;
  final DateTime? dob;
  final String? gender;          // 'Male', 'Female', 'Other'
  final String? address;
  final String? alternateMobile;
  final String? aadhaarNumber;
  final String? qualification;    // e.g. 'B.Ed, M.Sc'
  final String? designation;      // e.g. 'Senior Teacher', 'TGT', 'PRT'
  final String? subject;          // e.g. 'Mathematics, Science'
  final DateTime? joiningDate;
  final double? salary;
  final String? photoUrl;
  final String? aadhaarDocUrl;

  TeacherModel({
    required this.authUid,
    required this.teacherId,
    String? id,
    required this.name,
    required this.authEmail,
    String? email,
    this.mobile = '',
    this.password = '',
    this.schoolId = '',
    this.assignedClass,
    this.assignedSection,
    required this.active,
    this.status = 'active',
    required this.createdAt,
    this.fatherName,
    this.motherName,
    this.dob,
    this.gender,
    this.address,
    this.alternateMobile,
    this.aadhaarNumber,
    this.qualification,
    this.designation,
    this.subject,
    this.joiningDate,
    this.salary,
    this.photoUrl,
    this.aadhaarDocUrl,
  })  : id = (id != null && id.isNotEmpty) ? id : teacherId,
        email = (email != null && email.isNotEmpty) ? email : authEmail;

  Map<String, dynamic> toMap() {
    return {
      'id': teacherId,
      'teacherId': teacherId,
      'name': name,
      'authEmail': authEmail,
      'email': email,
      'authUid': authUid,
      'mobile': mobile,
      'password': password,
      'schoolId': schoolId,
      'assignedClass': assignedClass,
      'assignedSection': assignedSection,
      'active': active,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'fatherName': fatherName,
      'motherName': motherName,
      'dob': dob?.toIso8601String(),
      'gender': gender,
      'address': address,
      'alternateMobile': alternateMobile,
      'aadhaarNumber': aadhaarNumber,
      'qualification': qualification,
      'designation': designation,
      'subject': subject,
      'joiningDate': joiningDate?.toIso8601String(),
      'salary': salary,
      'photoUrl': photoUrl,
      'aadhaarDocUrl': aadhaarDocUrl,
      'aadhaarDocPath': aadhaarDocUrl,
      'aadhaarCardUrl': aadhaarDocUrl,
    };
  }

  factory TeacherModel.fromMap(Map<String, dynamic> map) {
    final tId = (map['teacherId'] as String?) ?? (map['id'] as String?) ?? '';
    final aEmail = (map['authEmail'] as String?) ?? (map['email'] as String?) ?? '';
    final aUid = (map['authUid'] as String?) ?? (map['uid'] as String?) ?? tId;
    final isActive = (map['active'] as bool?) ?? (map['status'] == 'active');

    DateTime parseDt(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      if (val is String && val.isNotEmpty) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    DateTime? parseDtNullable(dynamic val) {
      if (val == null) return null;
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      if (val is String && val.isNotEmpty) return DateTime.tryParse(val);
      return null;
    }

    final double? parsedSalary = map['salary'] != null ? (map['salary'] as num).toDouble() : null;

    return TeacherModel(
      authUid: aUid,
      teacherId: tId.isNotEmpty ? tId : aUid,
      id: tId.isNotEmpty ? tId : aUid,
      name: (map['name'] as String?) ?? '',
      authEmail: aEmail,
      email: aEmail,
      mobile: (map['mobile'] as String?) ?? '',
      password: (map['password'] as String?) ?? '',
      schoolId: (map['schoolId'] as String?) ?? '',
      assignedClass: map['assignedClass'] as String?,
      assignedSection: map['assignedSection'] as String?,
      active: isActive,
      status: (map['status'] as String?) ?? (isActive ? 'active' : 'disabled'),
      createdAt: parseDt(map['createdAt']),
      fatherName: map['fatherName'] as String?,
      motherName: map['motherName'] as String?,
      dob: parseDtNullable(map['dob']),
      gender: map['gender'] as String?,
      address: map['address'] as String?,
      alternateMobile: map['alternateMobile'] as String?,
      aadhaarNumber: (map['aadhaarNumber'] as String?) ?? (map['aadharNumber'] as String?),
      qualification: map['qualification'] as String?,
      designation: map['designation'] as String?,
      subject: (map['subject'] as String?) ?? (map['subjects'] as String?),
      joiningDate: parseDtNullable(map['joiningDate']),
      salary: parsedSalary,
      photoUrl: (map['photoUrl'] as String?) ?? (map['photoPath'] as String?),
      aadhaarDocUrl: (map['aadhaarDocUrl'] as String?) ?? (map['aadhaarDocPath'] as String?) ?? (map['aadhaarCardUrl'] as String?),
    );
  }

  Map<String, dynamic> toPublicMap() {
    return {
      'id': teacherId,
      'teacherId': teacherId,
      'name': name,
      'authEmail': authEmail,
      'email': email,
      'authUid': authUid,
      'mobile': mobile,
      'password': password,
      'assignedClass': assignedClass,
      'assignedSection': assignedSection,
      'active': active,
      'qualification': qualification,
      'designation': designation,
      'subject': subject,
      'salary': salary,
      'photoUrl': photoUrl,
    };
  }

  factory TeacherModel.fromPublicMap(Map<String, dynamic> map) {
    return TeacherModel.fromMap(map);
  }

  bool canAccessClass(String? targetClass) {
    final cls = assignedClass?.trim() ?? '';
    if (cls.isEmpty || cls.toLowerCase() == 'none' || cls.toLowerCase() == 'all' || cls.toLowerCase() == 'all classes' || cls.toLowerCase() == 'not assigned') {
      return true;
    }
    if (targetClass == null || targetClass.trim().isEmpty) return true;
    final target = targetClass.trim().toLowerCase();
    final allowed = cls.split(',').map((c) => c.trim().toLowerCase()).where((c) => c.isNotEmpty);
    return allowed.any((a) => a == target || target.contains(a) || a.contains(target));
  }

  String get displayAssignedClass {
    final cls = assignedClass ?? '';
    final sec = assignedSection ?? '';
    if (cls.isEmpty || cls.toLowerCase() == 'none' || cls.toLowerCase() == 'not assigned' || cls.toLowerCase() == 'all' || cls.toLowerCase() == 'all classes') {
      return 'All Classes (Full Access)';
    }
    return '$cls${sec.isNotEmpty && sec != 'None' ? ' - Section $sec' : ''}';
  }

  TeacherModel copyWith({
    String? name,
    String? mobile,
    String? password,
    String? assignedClass,
    String? assignedSection,
    bool? active,
    String? status,
    String? fatherName,
    String? motherName,
    DateTime? dob,
    String? gender,
    String? address,
    String? alternateMobile,
    String? aadhaarNumber,
    String? qualification,
    String? designation,
    String? subject,
    DateTime? joiningDate,
    double? salary,
    String? photoUrl,
    String? aadhaarDocUrl,
  }) {
    return TeacherModel(
      authUid: authUid,
      teacherId: teacherId,
      id: id,
      name: name ?? this.name,
      authEmail: authEmail,
      email: email,
      mobile: mobile ?? this.mobile,
      password: password ?? this.password,
      schoolId: schoolId,
      assignedClass: assignedClass ?? this.assignedClass,
      assignedSection: assignedSection ?? this.assignedSection,
      active: active ?? this.active,
      status: status ?? this.status,
      createdAt: createdAt,
      fatherName: fatherName ?? this.fatherName,
      motherName: motherName ?? this.motherName,
      dob: dob ?? this.dob,
      gender: gender ?? this.gender,
      address: address ?? this.address,
      alternateMobile: alternateMobile ?? this.alternateMobile,
      aadhaarNumber: aadhaarNumber ?? this.aadhaarNumber,
      qualification: qualification ?? this.qualification,
      designation: designation ?? this.designation,
      subject: subject ?? this.subject,
      joiningDate: joiningDate ?? this.joiningDate,
      salary: salary ?? this.salary,
      photoUrl: photoUrl ?? this.photoUrl,
      aadhaarDocUrl: aadhaarDocUrl ?? this.aadhaarDocUrl,
    );
  }
}