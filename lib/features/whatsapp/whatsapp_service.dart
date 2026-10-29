import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/student_model.dart';
import '../../data/models/settings_model.dart';
import '../../data/models/fee_model.dart';
import 'widgets/whatsapp_fee_reminder_dialog.dart';

class WhatsAppService {
  static const MethodChannel _channel = MethodChannel('school_app/whatsapp');

  static String formatPhone(String? raw) {
    if (raw == null) return '';
    var p = raw.replaceAll(RegExp(r'\D'), '');
    while (p.startsWith('0')) {
      p = p.substring(1);
    }
    if (p.length == 10) {
      return '91$p';
    }
    if (p.length == 12 && p.startsWith('91')) {
      return p;
    }
    return p;
  }

  static Future<Map<String, bool>> checkInstalledApps() async {
    try {
      final result = await _channel.invokeMethod<Map>('checkWhatsAppInstalled');
      if (result != null) {
        return {
          'whatsapp': result['whatsapp'] == true,
          'business': result['business'] == true,
        };
      }
    } catch (e) {
      debugPrint('WhatsApp check error: $e');
    }
    return {'whatsapp': false, 'business': false};
  }

  static Future<String?> showChooserDialog(BuildContext context) async {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => const _WhatsAppChooserSheet(),
    );
  }

  static Future<String?> promptPhoneNumber(BuildContext context, {String title = 'Enter WhatsApp Number'}) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Registered number not found. Enter 10-digit mobile number to send on WhatsApp:', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              autofocus: true,
              decoration: const InputDecoration(
                prefixText: '+91 ',
                hintText: '9876543210',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final val = ctrl.text.trim().replaceAll(RegExp(r'\D'), '');
              if (val.length >= 10) {
                Navigator.pop(ctx, val);
              }
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  static Future<void> sendMessage({
    required BuildContext context,
    required String phone,
    required String message,
  }) async {
    String targetPhone = formatPhone(phone);
    if (targetPhone.isEmpty) {
      if (!context.mounted) return;
      final entered = await promptPhoneNumber(context);
      if (entered == null || entered.isEmpty) return;
      targetPhone = formatPhone(entered);
    }

    final apps = await checkInstalledApps();
    final hasWa = apps['whatsapp'] == true;
    final hasW4b = apps['business'] == true;

    if (!hasWa && !hasW4b) {
      // Fallback via URL launcher if MethodChannel package check doesn't detect installed app or on desktop/emulator
      final number = targetPhone.startsWith('91') ? targetPhone : '91$targetPhone';
      final encoded = Uri.encodeComponent(message);
      final uri = Uri.parse('https://api.whatsapp.com/send?phone=$number&text=$encoded');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('WhatsApp / WhatsApp Business not installed on this device'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    String? selectedPackage;
    if (hasWa && hasW4b) {
      if (!context.mounted) return;
      selectedPackage = await showChooserDialog(context);
      if (selectedPackage == null) return; // Cancelled
    } else if (hasWa) {
      selectedPackage = 'com.whatsapp';
    } else {
      selectedPackage = 'com.whatsapp.w4b';
    }

    try {
      await _channel.invokeMethod('sendWhatsAppMessage', {
        'phone': targetPhone,
        'message': message,
        'package': selectedPackage,
      });
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error launching WhatsApp: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  static Future<void> sendPdf({
    required BuildContext context,
    required String phone,
    required String message,
    required String filePath,
  }) async {
    String targetPhone = formatPhone(phone);
    if (targetPhone.isEmpty) {
      if (!context.mounted) return;
      final entered = await promptPhoneNumber(context);
      if (entered == null || entered.isEmpty) return;
      targetPhone = formatPhone(entered);
    }

    final apps = await checkInstalledApps();
    final hasWa = apps['whatsapp'] == true;
    final hasW4b = apps['business'] == true;

    if (!hasWa && !hasW4b) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('WhatsApp / WhatsApp Business not installed on this device'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    String? selectedPackage;
    if (hasWa && hasW4b) {
      if (!context.mounted) return;
      selectedPackage = await showChooserDialog(context);
      if (selectedPackage == null) return; // Cancelled
    } else if (hasWa) {
      selectedPackage = 'com.whatsapp';
    } else {
      selectedPackage = 'com.whatsapp.w4b';
    }

    try {
      await _channel.invokeMethod('sendWhatsAppPdf', {
        'phone': targetPhone,
        'message': message,
        'filePath': filePath,
        'package': selectedPackage,
      });
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing PDF to WhatsApp: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  static Future<void> showReceiptShareSheet(
    BuildContext context, {
    required String studentName,
    String? phone,
    String? alternatePhone,
    required String receiptNumber,
    required String message,
    String? filePath,
  }) async {
    final candidatePhone = (phone != null && phone.trim().isNotEmpty)
        ? phone.trim()
        : (alternatePhone?.trim() ?? '');
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ReceiptShareSheet(
        studentName: studentName,
        initialPhone: candidatePhone,
        receiptNumber: receiptNumber,
        message: message,
        filePath: filePath,
      ),
    );
  }

  static Future<void> showDocumentShareSheet(
    BuildContext context, {
    required String title,
    required String subtitle,
    String? phone,
    String? alternatePhone,
    required String message,
    String? filePath,
    String pdfButtonLabel = 'Share PDF File (PDF भेजें)',
    IconData documentIcon = Icons.chat_bubble_rounded,
  }) async {
    final candidatePhone = (phone != null && phone.trim().isNotEmpty)
        ? phone.trim()
        : (alternatePhone?.trim() ?? '');
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _DocumentShareSheet(
        title: title,
        subtitle: subtitle,
        initialPhone: candidatePhone,
        message: message,
        filePath: filePath,
        pdfButtonLabel: pdfButtonLabel,
        documentIcon: documentIcon,
      ),
    );
  }

  static Future<void> showResultShareSheet(
    BuildContext context, {
    required String studentName,
    String? phone,
    String? alternatePhone,
    required String examName,
    required String message,
    String? filePath,
  }) {
    return showDocumentShareSheet(
      context,
      title: 'WhatsApp Result / Marksheet',
      subtitle: '$studentName • $examName',
      phone: phone,
      alternatePhone: alternatePhone,
      message: message,
      filePath: filePath,
      pdfButtonLabel: 'Share Result PDF (मार्कशीट PDF भेजें)',
      documentIcon: Icons.school_rounded,
    );
  }

  static Future<void> showAdmitCardShareSheet(
    BuildContext context, {
    required String studentName,
    String? phone,
    String? alternatePhone,
    required String examTitle,
    required String message,
    String? filePath,
  }) {
    return showDocumentShareSheet(
      context,
      title: 'WhatsApp Admit Card Share',
      subtitle: '$studentName • $examTitle',
      phone: phone,
      alternatePhone: alternatePhone,
      message: message,
      filePath: filePath,
      pdfButtonLabel: 'Share Admit Card PDF (प्रवेश पत्र PDF भेजें)',
      documentIcon: Icons.confirmation_number_rounded,
    );
  }

  static Future<void> showIdCardShareSheet(
    BuildContext context, {
    required String studentName,
    String? phone,
    String? alternatePhone,
    required String message,
    String? filePath,
  }) {
    return showDocumentShareSheet(
      context,
      title: 'WhatsApp ID Card Share',
      subtitle: '$studentName • Student ID Card',
      phone: phone,
      alternatePhone: alternatePhone,
      message: message,
      filePath: filePath,
      pdfButtonLabel: 'Share ID Card PDF (आईडी कार्ड PDF भेजें)',
      documentIcon: Icons.badge_rounded,
    );
  }

  static String buildResultVoucherText({
    required String studentName,
    String? rollNumber,
    String? admissionNumber,
    String? className,
    required String examName,
    required double totalMarks,
    required double obtainedMarks,
    required double percentage,
    required String grade,
    required String status,
    List<Map<String, dynamic>>? subjects,
    String? remarks,
    required String instituteName,
    String? institutePhone,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('🎓 *ACADEMIC MARKSHEET / RESULT*');
    buffer.writeln('*${instituteName.toUpperCase()}*');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('👤 *Student:* $studentName');
    if (className != null && className.trim().isNotEmpty) {
      buffer.writeln('🏫 *Class:* ${className.trim()}');
    }
    if (rollNumber != null && rollNumber.trim().isNotEmpty) {
      buffer.writeln('🆔 *Roll No:* ${rollNumber.trim()}');
    } else if (admissionNumber != null && admissionNumber.trim().isNotEmpty) {
      buffer.writeln('📄 *Adm No:* ${admissionNumber.trim()}');
    }
    buffer.writeln('📝 *Exam:* $examName');
    if (subjects != null && subjects.isNotEmpty) {
      buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
      buffer.writeln('📚 *Subject-wise Marks:*');
      for (final sub in subjects) {
        final sName = sub['name'] ?? sub['subject'] ?? 'Subject';
        final obt = sub['obtained'] ?? sub['marks'] ?? 0;
        final maxM = sub['total'] ?? sub['totalMarks'] ?? 100;
        buffer.writeln('• $sName: $obt / $maxM');
      }
    }
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('🎯 *Total Marks:* ${obtainedMarks.toInt()} / ${totalMarks.toInt()}');
    buffer.writeln('📊 *Percentage:* ${percentage.toStringAsFixed(1)}%');
    buffer.writeln('🏅 *Grade:* $grade');
    buffer.writeln('🏆 *Result Status:* *${status.toUpperCase() == 'FAIL' ? 'NEEDS IMPROVEMENT' : status.toUpperCase()}*');
    if (remarks != null && remarks.trim().isNotEmpty) {
      buffer.writeln('💬 *Remarks:* ${remarks.trim()}');
    }
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('📄 Official mark sheet PDF attached.');
    if (institutePhone != null && institutePhone.trim().isNotEmpty) {
      buffer.writeln('📞 *Helpline / Office:* ${institutePhone.trim()}');
    }
    buffer.writeln('Thank you!');
    buffer.writeln('*$instituteName*');
    return buffer.toString();
  }

  static String buildAdmitCardText({
    required String studentName,
    String? fatherName,
    String? rollNumber,
    String? admissionNumber,
    String? className,
    required String examTitle,
    required String instituteName,
    String? institutePhone,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('🎫 *EXAMINATION ADMIT CARD / HALL TICKET*');
    buffer.writeln('*${instituteName.toUpperCase()}*');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('👤 *Candidate:* $studentName');
    if (fatherName != null && fatherName.trim().isNotEmpty) {
      buffer.writeln('👨‍👦 *Father:* ${fatherName.trim()}');
    }
    if (className != null && className.trim().isNotEmpty) {
      buffer.writeln('🏫 *Class:* ${className.trim()}');
    }
    if (rollNumber != null && rollNumber.trim().isNotEmpty) {
      buffer.writeln('🆔 *Roll No:* ${rollNumber.trim()}');
    }
    if (admissionNumber != null && admissionNumber.trim().isNotEmpty) {
      buffer.writeln('📄 *Adm No:* ${admissionNumber.trim()}');
    }
    buffer.writeln('📝 *Exam:* $examTitle');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('📄 Official Hall Ticket & Subject Time Table PDF attached.');
    buffer.writeln('⚠️ *Note:* Please print and bring this admit card to the examination hall.');
    if (institutePhone != null && institutePhone.trim().isNotEmpty) {
      buffer.writeln('📞 *Office:* ${institutePhone.trim()}');
    }
    buffer.writeln('*$instituteName*');
    return buffer.toString();
  }

  static String buildIdCardText({
    required String studentName,
    String? studentId,
    String? admissionNumber,
    String? fatherName,
    String? className,
    String? mobile,
    required String instituteName,
    String? institutePhone,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('🪪 *OFFICIAL STUDENT IDENTITY CARD*');
    buffer.writeln('*${instituteName.toUpperCase()}*');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('👤 *Student:* $studentName');
    if (studentId != null && studentId.trim().isNotEmpty) {
      buffer.writeln('🆔 *Student ID:* ${studentId.trim()}');
    }
    if (admissionNumber != null && admissionNumber.trim().isNotEmpty) {
      buffer.writeln('📄 *Adm No:* ${admissionNumber.trim()}');
    }
    if (className != null && className.trim().isNotEmpty) {
      buffer.writeln('🏫 *Class / Course:* ${className.trim()}');
    }
    if (fatherName != null && fatherName.trim().isNotEmpty) {
      buffer.writeln('👨‍👦 *Father:* ${fatherName.trim()}');
    }
    if (mobile != null && mobile.trim().isNotEmpty) {
      buffer.writeln('📞 *Contact:* ${mobile.trim()}');
    }
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('📄 Verified Digital ID Card PDF attached.');
    if (institutePhone != null && institutePhone.trim().isNotEmpty) {
      buffer.writeln('📞 *Office:* ${institutePhone.trim()}');
    }
    buffer.writeln('*$instituteName*');
    return buffer.toString();
  }

  static String buildReceiptVoucherText({
    required String studentName,
    String? fatherName,
    String? className,
    required String receiptNumber,
    required DateTime paymentDate,
    required double amount,
    required String paymentMode,
    String? feeMonth,
    double? totalDemand,
    double? previousPaid,
    double? totalPaid,
    double? balanceDue,
    required String instituteName,
    String? institutePhone,
  }) {
    final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(paymentDate);
    final buffer = StringBuffer();
    buffer.writeln('🧾 *FEE PAYMENT RECEIPT*');
    buffer.writeln('*${instituteName.toUpperCase()}*');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('👤 *Student:* $studentName');
    if (fatherName != null && fatherName.trim().isNotEmpty) {
      buffer.writeln('👨‍👦 *Father:* ${fatherName.trim()}');
    }
    if (className != null && className.trim().isNotEmpty) {
      buffer.writeln('🏫 *Class:* ${className.trim()}');
    }
    buffer.writeln('📄 *Receipt No:* #$receiptNumber');
    buffer.writeln('📅 *Date:* $dateStr');
    if (feeMonth != null && feeMonth.trim().isNotEmpty) {
      buffer.writeln('📆 *Fees For:* ${feeMonth.trim()}');
    }
    if (totalDemand != null && totalDemand > 0) {
      buffer.writeln('💰 *Total Demand:* ₹${totalDemand.toInt()}');
    }
    if (previousPaid != null && previousPaid > 0) {
      buffer.writeln('💵 *Previous Paid:* ₹${previousPaid.toInt()}');
    }
    buffer.writeln('✅ *Paid Now:* ₹${amount.toInt()} via ${paymentMode.toUpperCase()}');
    if (totalPaid != null && totalPaid > 0 && totalPaid != amount) {
      buffer.writeln('💳 *Total Paid:* ₹${totalPaid.toInt()}');
    }
    if (balanceDue != null) {
      if (balanceDue <= 0) {
        buffer.writeln('🎉 *Balance Due:* ₹0 (FULL PAID)');
      } else {
        buffer.writeln('⚠️ *Balance Due:* ₹${balanceDue.toInt()}');
      }
    }
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('Official fee payment recorded successfully.');
    if (institutePhone != null && institutePhone.trim().isNotEmpty) {
      buffer.writeln('📞 *Helpline / Office:* ${institutePhone.trim()}');
    }
    buffer.writeln('Thank you!');
    return buffer.toString();
  }

  /// Shows interactive WhatsApp Fee Due Reminder Dialog with Hindi/English options
  static Future<void> showFeeReminderDialog(
    BuildContext context, {
    required StudentModel student,
    required SettingsModel settings,
    required double dueAmount,
    double totalFee = 0,
    double paidFee = 0,
    List<PaymentModel>? payments,
  }) async {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => WhatsAppFeeReminderDialog(
        student: student,
        settings: settings,
        dueAmount: dueAmount,
        totalFee: totalFee,
        paidFee: paidFee,
        payments: payments,
      ),
    );
  }

  /// Builds the complete official Fee Reminder message with father's name,
  /// pending months list, month-wise fee/payment breakdown, totals, and due date.
  static String buildDetailedFeeReminderMessage({
    required StudentModel student,
    required SettingsModel settings,
    required double dueAmount,
    double totalFee = 0,
    double paidFee = 0,
    List<PaymentModel>? payments,
    String lang = 'hi',
  }) {
    final s = student;
    final set = settings;
    final instName = set.instituteName.isNotEmpty ? set.instituteName : 'Mission Navodaya Public School';
    final instPhone = set.mobile.isNotEmpty ? set.mobile : '';
    final classStr = s.studentType == 'school'
        ? 'Class ${s.className ?? ''}${s.section != null && s.section!.isNotEmpty ? ' (${s.section})' : ''}'
        : (s.course ?? 'Student');

    final payList = payments ?? [];
    final actualPaid = payList.isNotEmpty
        ? payList.fold(0.0, (sum, p) => sum + p.amount).toInt()
        : paidFee.toInt();
    final due = dueAmount.toInt();
    final paid = actualPaid;
    final total = totalFee > 0 ? totalFee.toInt() : (due + paid);
    final fatherName = s.fatherName.trim();

    final now = DateTime.now();
    final sessionStartYear = now.month >= 4 ? now.year : now.year - 1;
    int startYear = sessionStartYear;
    int startMonth = 4;
    final sessionStartDate = DateTime(sessionStartYear, 4, 1);
    if (s.admissionDate.isAfter(sessionStartDate) && !s.admissionDate.isAfter(now)) {
      startYear = s.admissionDate.year;
      startMonth = s.admissionDate.month;
    }

    final fs = s.feeStructure;
    double recurringTuition = 0.0;
    if (fs != null && fs['tuitionFee'] != null && (fs['tuitionFee'] as num) > 0) {
      recurringTuition = (fs['tuitionFee'] as num).toDouble();
    } else if (s.monthlyFee != null && s.monthlyFee! > 0) {
      recurringTuition = s.monthlyFee!;
    } else if (s.initialTotalFees != null && s.initialTotalFees! > 0) {
      recurringTuition = (s.initialTotalFees! / 12).roundToDouble();
    }

    final recurringTransport = (fs != null && fs['transportFee'] != null) ? (fs['transportFee'] as num).toDouble() : 0.0;
    final recurringGame = (fs != null && fs['gameFee'] != null) ? (fs['gameFee'] as num).toDouble() : 0.0;

    const mNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];

    final List<Map<String, dynamic>> items = [];
    DateTime cursor = DateTime(startYear, startMonth, 1);
    final endCursor = DateTime(now.year, now.month, 1);

    int iterations = 0;
    while (!cursor.isAfter(endCursor) && iterations < 36) {
      iterations++;
      final y = cursor.year;
      final m = cursor.month;
      final mKey = '$y-${m.toString().padLeft(2, '0')}';
      final mLabel = '${mNames[m - 1]} $y';

      final mp = (s.monthlyParticulars != null && s.monthlyParticulars![mKey] is Map)
          ? s.monthlyParticulars![mKey] as Map
          : null;

      double tuition = recurringTuition;
      double transport = recurringTransport;
      double game = recurringGame;
      double other = 0.0;

      if (mp != null) {
        if (mp['tuitionFee'] != null && (mp['tuitionFee'] as num) > 0) {
          tuition = (mp['tuitionFee'] as num).toDouble();
        }
        if (mp['transportFee'] != null) transport = (mp['transportFee'] as num).toDouble();
        if (mp['gameFee'] != null) game = (mp['gameFee'] as num).toDouble();
        if (mp['examinationFee'] != null) other += (mp['examinationFee'] as num).toDouble();
        if (mp['admissionFee'] != null) other += (mp['admissionFee'] as num).toDouble();
        if (mp['developmentFee'] != null) other += (mp['developmentFee'] as num).toDouble();
        if (mp['lateFine'] != null) other += (mp['lateFine'] as num).toDouble();
        if (mp['otherFee'] != null) other += (mp['otherFee'] as num).toDouble();
      }

      final monthCharge = tuition + transport + game + other;

      final paidInMonth = payList.where((p) {
        if (p.feeMonth != null && p.feeMonth!.isNotEmpty) {
          final fm = p.feeMonth!.trim().toLowerCase();
          if (fm == mKey || fm == mLabel.toLowerCase() || (fm.contains(mNames[m - 1].toLowerCase()) && fm.contains('$y'))) {
            return true;
          }
        }
        if (p.paymentDate.year == y && p.paymentDate.month == m) {
          return true;
        }
        return false;
      }).fold(0.0, (sum, p) => sum + p.amount);

      final closingDue = (monthCharge - paidInMonth).clamp(0.0, double.infinity);

      items.add({
        'label': mLabel,
        'charge': monthCharge,
        'paid': paidInMonth,
        'due': closingDue,
      });

      cursor = DateTime(y, m + 1, 1);
    }

    final pendingList = items.where((i) => (i['due'] as double) > 0).toList();
    final pendingMonthNames = pendingList.map((i) => i['label'] as String).toList();
    final pendingCount = pendingList.length;

    if (lang == 'hi') {
      final buffer = StringBuffer();
      buffer.writeln('नमस्ते! *$instName* से सादर अभिवादन।\n');
      buffer.writeln('प्रिय अभिभावक,');
      if (fatherName.isNotEmpty) {
        buffer.writeln('👨‍👦 *पिता/अभिभावक का नाम:* श्री $fatherName');
      }
      buffer.writeln('👤 *छात्र/छात्रा:* *${s.name}* ($classStr)\n');
      buffer.writeln('यह संदेश बकाया स्कूल फीस के संबंध में है:\n');

      if (s.studentType != 'computer' && items.isNotEmpty) {
        if (pendingCount > 0) {
          buffer.writeln('📌 *बकाया महीने (Pending Months):* $pendingCount महीने');
          buffer.writeln('⚠️ *बकाया महीने की सूची:* ${pendingMonthNames.join(', ')}\n');
        } else {
          buffer.writeln('📌 *बकाया महीने:* कोई बकाया महीना नहीं\n');
        }

        final activeMonths = items
            .where((m) => (m['due'] as double) > 0 || (m['paid'] as double) > 0)
            .toList();
        final displayMonths = activeMonths.length > 12 ? activeMonths.sublist(activeMonths.length - 12) : activeMonths;
        if (displayMonths.isNotEmpty) {
          buffer.writeln('📊 *महीनेवार फीस व भुगतान विवरण:*');
          for (final m in displayMonths) {
            final dueVal = (m['due'] as double).toInt();
            final chargeVal = (m['charge'] as double).toInt();
            final paidVal = (m['paid'] as double).toInt();
            final status = dueVal <= 0 ? '✅ (चुकता)' : '⚠️';
            buffer.writeln('• *${m['label']}*: कुल शुल्क ₹$chargeVal | जमा ₹$paidVal | बकाया ₹$dueVal $status');
          }
          buffer.writeln();
        }
      } else if (s.studentType == 'computer' && payList.isNotEmpty) {
        buffer.writeln('📊 *जमा की गई किश्तों/रसीदों का विवरण:*');
        for (int i = 0; i < payList.length; i++) {
          final p = payList[i];
          final dateStr = DateFormat('dd MMM yyyy').format(p.paymentDate);
          buffer.writeln('• रसीद #${p.receiptNumber} ($dateStr): ₹${p.amount.toInt()} [${p.paymentMode.toUpperCase()}]');
        }
        buffer.writeln();
      }

      // Summary Box: Total Fee (Top) -> Paid Fee -> Due Balance -> Due Period
      buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
      buffer.writeln('💳 *कुल देय फीस (Total Fees):* ₹$total');
      buffer.writeln('✅ *कुल जमा फीस (Total Paid):* ₹$paid');
      buffer.writeln('💰 *कुल बकाया राशि (Due Balance):* ₹$due');
      if (s.studentType != 'computer' && pendingCount > 0) {
        buffer.writeln('📌 *बकाया अवधि (Due Period):* $pendingCount महीने (${pendingMonthNames.join(', ')})');
      }
      buffer.writeln('━━━━━━━━━━━━━━━━━━━━\n');
      buffer.writeln('कृपया अंतिम तिथि से पहले बकाया फीस विद्यालय कार्यालय में जमा कराने का कष्ट करें।\n');
      if (instPhone.isNotEmpty) {
        buffer.writeln('📞 सहायता / संपर्क: $instPhone');
      }
      buffer.writeln('धन्यवाद,\n*$instName*');
      return buffer.toString();
    } else {
      final buffer = StringBuffer();
      buffer.writeln('Dear Parent / Guardian,\n');
      buffer.writeln('Greetings from *$instName*!\n');
      if (fatherName.isNotEmpty) {
        buffer.writeln('👨‍👦 *Father\'s / Guardian Name:* Mr. $fatherName');
      }
      buffer.writeln('👤 *Student Name:* *${s.name}* ($classStr)\n');
      buffer.writeln('This is an official reminder regarding the pending fee dues:\n');

      if (s.studentType != 'computer' && items.isNotEmpty) {
        if (pendingCount > 0) {
          buffer.writeln('📌 *Pending Months Count:* $pendingCount ${pendingCount == 1 ? 'Month' : 'Months'}');
          buffer.writeln('⚠️ *Pending Months List:* ${pendingMonthNames.join(', ')}\n');
        } else {
          buffer.writeln('📌 *Pending Months:* No pending months\n');
        }

        final activeMonths = items
            .where((m) => (m['due'] as double) > 0 || (m['paid'] as double) > 0)
            .toList();
        final displayMonths = activeMonths.length > 12 ? activeMonths.sublist(activeMonths.length - 12) : activeMonths;
        if (displayMonths.isNotEmpty) {
          buffer.writeln('📊 *Month-wise Fee & Payment Breakdown:*');
          for (final m in displayMonths) {
            final dueVal = (m['due'] as double).toInt();
            final chargeVal = (m['charge'] as double).toInt();
            final paidVal = (m['paid'] as double).toInt();
            final status = dueVal <= 0 ? '✅ (Paid)' : '⚠️';
            buffer.writeln('• *${m['label']}*: Total ₹$chargeVal | Paid ₹$paidVal | Due ₹$dueVal $status');
          }
          buffer.writeln();
        }
      } else if (s.studentType == 'computer' && payList.isNotEmpty) {
        buffer.writeln('📊 *Payments & Receipts Record:*');
        for (int i = 0; i < payList.length; i++) {
          final p = payList[i];
          final dateStr = DateFormat('dd MMM yyyy').format(p.paymentDate);
          buffer.writeln('• Receipt #${p.receiptNumber} ($dateStr): ₹${p.amount.toInt()} [${p.paymentMode.toUpperCase()}]');
        }
        buffer.writeln();
      }

      // Summary Box: Total Fee (Top) -> Paid Fee -> Due Balance -> Due Period
      buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
      buffer.writeln('💳 *Overall Total Fee:* ₹$total');
      buffer.writeln('✅ *Total Fee Paid:* ₹$paid');
      buffer.writeln('💰 *Total Outstanding Due:* ₹$due');
      if (s.studentType != 'computer' && pendingCount > 0) {
        buffer.writeln('📌 *Due Period:* $pendingCount ${pendingCount == 1 ? 'Month' : 'Months'} (${pendingMonthNames.join(', ')})');
      }
      buffer.writeln('━━━━━━━━━━━━━━━━━━━━\n');
      buffer.writeln('Kindly clear the outstanding dues at the earliest.\n');
      if (instPhone.isNotEmpty) {
        buffer.writeln('📞 Helpline / Contact: $instPhone');
      }
      buffer.writeln('Thank you,\n*$instName*');
      return buffer.toString();
    }
  }

  static String feeReminderHindiMessage({
    required String studentName,
    required String className,
    required String instituteName,
    required double due,
    required double total,
    required double paid,
    String? fatherName,
    String? institutePhone,
  }) {
    final fLine = fatherName != null && fatherName.trim().isNotEmpty
        ? '👨‍👦 *पिता/अभिभावक का नाम:* श्री ${fatherName.trim()}\n'
        : '';
    return '''नमस्ते! *$instituteName* से सादर अभिवादन।

प्रिय अभिभावक,
$fLine👤 *छात्र/छात्रा:* *$studentName* ($className)

यह संदेश बकाया स्कूल फीस के संबंध में है:

💰 *कुल फीस:* ₹${total.toInt()}
✅ *जमा फीस:* ₹${paid.toInt()}
⚠️ *बकाया राशि (Due):* ₹${due.toInt()}

कृपया अंतिम तिथि से पहले बकाया फीस विद्यालय कार्यालय में जमा कराने का कष्ट करें।

${institutePhone != null && institutePhone.isNotEmpty ? '📞 *सहायता / संपर्क:* $institutePhone\n' : ''}धन्यवाद!
*$instituteName*''';
  }

  static String feeReminderEnglishMessage({
    required String studentName,
    required String className,
    required String instituteName,
    required double due,
    required double total,
    required double paid,
    String? fatherName,
    String? institutePhone,
  }) {
    final fLine = fatherName != null && fatherName.trim().isNotEmpty
        ? '👨‍👦 *Parent/Father\'s Name:* Mr. ${fatherName.trim()}\n'
        : '';
    return '''Dear Parent / Guardian,

Greetings from *$instituteName*!

$fLine👤 *Student:* *$studentName* ($className)

This is a gentle reminder regarding the pending fee balance:

💰 *Total Fee:* ₹${total.toInt()}
✅ *Paid Amount:* ₹${paid.toInt()}
⚠️ *Due Amount:* ₹${due.toInt()}

Kindly clear the outstanding dues at the earliest. For any queries, feel free to contact the school office.

${institutePhone != null && institutePhone.isNotEmpty ? '📞 *Helpdesk:* $institutePhone\n' : ''}Thank you!
*$instituteName*''';
  }

  static String feeReminderMessage({
    required String studentName,
    required String instituteName,
    required double remaining,
    required double total,
  }) {
    return feeReminderEnglishMessage(
      studentName: studentName,
      className: 'Student',
      instituteName: instituteName,
      due: remaining,
      total: total,
      paid: total > remaining ? total - remaining : 0,
    );
  }

  static String feeReceiptMessage({
    required String studentName,
    required String admissionNumber,
    required String receiptNumber,
    required String instituteName,
  }) {
    return '''Dear Parent,

Please find the fee receipt of $studentName attached.

Student: $studentName
Admission No: $admissionNumber
Receipt No: $receiptNumber

Regards,
$instituteName''';
  }

  static String admissionConfirmationMessage({
    required String studentName,
    required String studentId,
    required String admissionNumber,
    required String instituteName,
    required String classOrCourse,
  }) {
    return '''Dear Parent,

🎉 Admission Confirmed!

Student: $studentName
Student ID: $studentId
Admission No: $admissionNumber
Class/Course: $classOrCourse

Welcome to $instituteName!
We look forward to a bright future together.

Regards,
$instituteName''';
  }

  static String attendanceNotificationMessage({
    required String studentName,
    required String status,
    required String date,
    required String instituteName,
  }) {
    final emoji = status == 'present' ? '✅' : status == 'absent' ? '❌' : '🟡';
    return '''Dear Parent,

$emoji Attendance Update

Student: $studentName
Date: $date
Status: ${status.toUpperCase()}

$instituteName''';
  }
}

class WhatsAppButtons extends StatelessWidget {
  final String studentName;
  final String mobile;
  final double? remainingFees;
  final double? totalFees;
  final String? studentId;
  final String? admissionNumber;
  final String? classOrCourse;
  final String instituteName;

  const WhatsAppButtons({
    super.key,
    required this.studentName,
    required this.mobile,
    required this.instituteName,
    this.remainingFees,
    this.totalFees,
    this.studentId,
    this.admissionNumber,
    this.classOrCourse,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (remainingFees != null && remainingFees! > 0)
          _WAButton(
            label: 'Send Fee Reminder',
            icon: Icons.payments_outlined,
            color: AppColors.warning,
            onTap: () async {
              try {
                await WhatsAppService.sendMessage(
                  context: context,
                  phone: mobile,
                  message: WhatsAppService.feeReminderMessage(
                    studentName: studentName,
                    instituteName: instituteName,
                    remaining: remainingFees!,
                    total: totalFees ?? 0,
                  ),
                );
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
                  );
                }
              }
            },
          ),
        if (studentId != null)
          _WAButton(
            label: 'Send Admission Confirmation',
            icon: Icons.verified_outlined,
            color: AppColors.success,
            onTap: () async {
              try {
                await WhatsAppService.sendMessage(
                  context: context,
                  phone: mobile,
                  message: WhatsAppService.admissionConfirmationMessage(
                    studentName: studentName,
                    studentId: studentId!,
                    admissionNumber: admissionNumber ?? '',
                    instituteName: instituteName,
                    classOrCourse: classOrCourse ?? '',
                  ),
                );
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
                  );
                }
              }
            },
          ),
      ],
    );
  }
}

class _WAButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _WAButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }
}

/// Bottom-sheet picker shown when both WhatsApp and WhatsApp Business are
/// installed — replaces the old centered AlertDialog. Slides up from the
/// bottom, matches the app's rounded-card + AppColors look, and each option
/// is a full-width tappable row instead of a plain ListTile.
class _WhatsAppChooserSheet extends StatelessWidget {
  const _WhatsAppChooserSheet();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 24, offset: const Offset(0, -4)),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF25D366).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.chat_bubble_rounded, color: Color(0xFF25D366), size: 22),
                ),
                const SizedBox(width: 12),
                Text('Choose WhatsApp',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: cs.onSurface)),
              ],
            ),
            const SizedBox(height: 18),
            _chooserRow(
              context: context,
              icon: Icons.chat_bubble_rounded,
              iconColor: const Color(0xFF25D366),
              title: 'WhatsApp',
              subtitle: 'Send via the regular WhatsApp app',
              onTap: () => Navigator.pop(context, 'com.whatsapp'),
            ),
            const SizedBox(height: 10),
            _chooserRow(
              context: context,
              icon: Icons.store_rounded,
              iconColor: const Color(0xFF075E54),
              title: 'WhatsApp Business',
              subtitle: 'Send via WhatsApp Business',
              onTap: () => Navigator.pop(context, 'com.whatsapp.w4b'),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context, null),
                style: TextButton.styleFrom(foregroundColor: cs.onSurfaceVariant),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chooserRow({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.surfaceVariant.withOpacity(0.4),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outline.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: cs.onSurface)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _DocumentShareSheet extends StatefulWidget {
  final String title;
  final String subtitle;
  final String initialPhone;
  final String message;
  final String? filePath;
  final String pdfButtonLabel;
  final IconData documentIcon;

  const _DocumentShareSheet({
    required this.title,
    required this.subtitle,
    required this.initialPhone,
    required this.message,
    this.filePath,
    this.pdfButtonLabel = 'Share PDF File (PDF भेजें)',
    this.documentIcon = Icons.chat_bubble_rounded,
  });

  @override
  State<_DocumentShareSheet> createState() => _DocumentShareSheetState();
}

class _DocumentShareSheetState extends State<_DocumentShareSheet> {
  late TextEditingController _phoneController;
  bool _isEditingPhone = false;

  @override
  void initState() {
    super.initState();
    String digits = widget.initialPhone.replaceAll(RegExp(r'\D'), '');
    while (digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    if (digits.startsWith('91') && digits.length == 12) {
      digits = digits.substring(2);
    }
    _phoneController = TextEditingController(text: digits);
    _isEditingPhone = digits.length < 10;
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  String _cleanEnteredPhone() {
    return _phoneController.text.trim().replaceAll(RegExp(r'\D'), '');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final digits = _cleanEnteredPhone();
    final hasValidPhone = digits.length >= 10;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.16),
                blurRadius: 24,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: cs.onSurfaceVariant.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFF25D366).withOpacity(0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(widget.documentIcon, color: const Color(0xFF25D366), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: cs.onSurface),
                        ),
                        Text(
                          widget.subtitle,
                          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: cs.surfaceVariant.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: hasValidPhone ? const Color(0xFF25D366).withOpacity(0.4) : AppColors.warning.withOpacity(0.5),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.phone_android_rounded,
                              size: 16,
                              color: hasValidPhone ? const Color(0xFF25D366) : AppColors.warning,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'WhatsApp Mobile Number',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        if (!_isEditingPhone && digits.length >= 10)
                          GestureDetector(
                            onTap: () => setState(() => _isEditingPhone = true),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              child: Text(
                                'Change / Edit',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF25D366),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (_isEditingPhone)
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: cs.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: cs.outline.withOpacity(0.3)),
                            ),
                            child: const Text(
                              '+91',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              maxLength: 10,
                              autofocus: digits.length < 10,
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                counterText: '',
                                hintText: 'Enter 10-digit number',
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                          if (digits.length >= 10) ...[
                            const SizedBox(width: 6),
                            IconButton(
                              icon: const Icon(Icons.check_circle_rounded, color: Color(0xFF25D366)),
                              onPressed: () => setState(() => _isEditingPhone = false),
                              tooltip: 'Save',
                            ),
                          ],
                        ],
                      )
                    else
                      Row(
                        children: [
                          Text(
                            '+91 $digits',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 0.5),
                          ),
                          const Spacer(),
                          const Text(
                            'Registered Contact',
                            style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: !hasValidPhone
                    ? null
                    : () async {
                        final nav = Navigator.of(context);
                        nav.pop();
                        await WhatsAppService.sendMessage(
                          context: context,
                          phone: digits,
                          message: widget.message,
                        );
                      },
                icon: const Icon(Icons.chat_bubble_rounded, size: 20, color: Colors.white),
                label: const Text(
                  'Direct WhatsApp Chat (सीधा चैट खोलें)',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  disabledBackgroundColor: Colors.grey.shade400,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
              const SizedBox(height: 8),
              if (widget.filePath != null && widget.filePath!.isNotEmpty) ...[
                OutlinedButton.icon(
                  onPressed: !hasValidPhone
                      ? null
                      : () async {
                          final nav = Navigator.of(context);
                          nav.pop();
                          await WhatsAppService.sendPdf(
                            context: context,
                            phone: digits,
                            message: widget.message,
                            filePath: widget.filePath!,
                          );
                        },
                  icon: const Icon(Icons.picture_as_pdf_rounded, size: 20, color: Color(0xFF075E54)),
                  label: Text(
                    widget.pdfButtonLabel,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF075E54)),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF075E54)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel', style: TextStyle(color: cs.onSurfaceVariant)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReceiptShareSheet extends StatelessWidget {
  final String studentName;
  final String initialPhone;
  final String receiptNumber;
  final String message;
  final String? filePath;

  const _ReceiptShareSheet({
    required this.studentName,
    required this.initialPhone,
    required this.receiptNumber,
    required this.message,
    this.filePath,
  });

  @override
  Widget build(BuildContext context) {
    return _DocumentShareSheet(
      title: 'WhatsApp Receipt Share',
      subtitle: '$studentName • Receipt #$receiptNumber',
      initialPhone: initialPhone,
      message: message,
      filePath: filePath,
      pdfButtonLabel: 'Share PDF File (PDF रसीद भेजें)',
      documentIcon: Icons.receipt_long_rounded,
    );
  }
}
