import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/student_model.dart';

/// Lightweight Hindi Voice Assistant for Parents & Students.
/// Uses native Android TextToSpeech via MethodChannel — 0 external packages needed,
/// works completely offline and free.
class VoiceAssistantService {
  VoiceAssistantService._() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }
  static final VoiceAssistantService instance = VoiceAssistantService._();

  static const MethodChannel _channel = MethodChannel('school_app/whatsapp');

  final ValueNotifier<bool> isSpeakingNotifier = ValueNotifier<bool>(false);
  bool get isSpeaking => isSpeakingNotifier.value;

  final ValueNotifier<String?> activePlayingIdNotifier = ValueNotifier<String?>(null);
  String? get activePlayingId => activePlayingIdNotifier.value;

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    if (call.method == 'onSpeechComplete') {
      isSpeakingNotifier.value = false;
      activePlayingIdNotifier.value = null;
    }
  }

  /// Speaks the given text in natural Hindi with an optional ID tracking which UI widget triggered it.
  Future<bool> speak(String text, {String? id}) async {
    if (text.trim().isEmpty) return false;
    try {
      isSpeakingNotifier.value = true;
      activePlayingIdNotifier.value = id;
      final result = await _channel.invokeMethod<bool>('speakHindi', {'text': text});
      return result ?? true;
    } catch (e) {
      debugPrint('[VoiceAssistantService] speak error: $e');
      isSpeakingNotifier.value = false;
      activePlayingIdNotifier.value = null;
      return false;
    }
  }

  /// Toggle speak: if currently playing the same id, stop; otherwise start speaking.
  Future<void> toggleSpeak({required String id, required String text}) async {
    if (isSpeaking && activePlayingId == id) {
      await stop();
    } else {
      await stop();
      await speak(text, id: id);
    }
  }

  /// Stops current speech playback immediately.
  Future<void> stop() async {
    try {
      await _channel.invokeMethod<bool>('stopSpeaking');
    } catch (e) {
      debugPrint('[VoiceAssistantService] stop error: $e');
    } finally {
      isSpeakingNotifier.value = false;
      activePlayingIdNotifier.value = null;
    }
  }

  /// Translates common English words and phrases used in school messages / complaints
  /// into clear Hindi so illiterate or non-English-speaking parents can understand everything clearly.
  static String translateEnglishToHindi(String text) {
    if (text.trim().isEmpty) return '';

    String cleaned = text;

    // Multi-word phrases first
    final phraseMap = <String, String>{
      r'\bplease contact school office\b': 'कृपया स्कूल कार्यालय में संपर्क करें',
      r'\bplease contact office\b': 'कृपया कार्यालय में संपर्क करें',
      r'\bplease contact principal\b': 'कृपया प्रधानाचार्य से संपर्क करें',
      r'\bcontact school office\b': 'स्कूल कार्यालय में संपर्क करें',
      r'\bcontact office\b': 'कार्यालय में संपर्क करें',
      r'\baction will be taken\b': 'उचित कार्रवाई की जाएगी',
      r'\baction has been taken\b': 'कार्रवाई कर दी गई है',
      r'\bwe are looking into this\b': 'हम इस मामले की जांच कर रहे हैं',
      r'\blooking into this\b': 'जांच की जा रही है',
      r'\bwill be resolved soon\b': 'जल्द ही समाधान कर दिया जाएगा',
      r'\bwill be resolved\b': 'समाधान कर दिया जाएगा',
      r'\bhas been resolved\b': 'समाधान हो चुका है',
      r'\bis resolved\b': 'समाधान हो चुका है',
      r'\bextra classes\b': 'अतिरिक्त कक्षाएं',
      r'\bfee receipt\b': 'फीस की रसीद',
      r'\bbus route\b': 'बस का रूट',
      r'\bbus stop\b': 'बस स्टॉप',
      r'\bunder review\b': 'समीक्षाधीन है',
      r'\bunder process\b': 'प्रक्रिया में है',
      r'\bthank you\b': 'धन्यवाद',
      r'\bthanks\b': 'धन्यवाद',
      r'\bparent complaint\b': 'अभिभावक शिकायत',
      r'\bacademic & studies\b': 'पढ़ाई संबंधी',
      r'\bfees & accounts\b': 'फीस व रसीद संबंधी',
      r'\bbus & transport\b': 'बस व वाहन संबंधी',
      r'\bdiscipline & behavior\b': 'अनुशासन संबंधी',
      r'\bschool facilities\b': 'स्कूल सुविधाएं',
      r'\bgeneral inquiry\b': 'सामान्य पूछताछ',
    };

    phraseMap.forEach((pattern, replacement) {
      cleaned = cleaned.replaceAll(RegExp(pattern, caseSensitive: false), replacement);
    });

    // Single common administrative words
    final wordMap = <String, String>{
      r'\bresolved\b': 'समाधान हो चुका है',
      r'\bpending\b': 'समीक्षाधीन है',
      r'\bnew\b': 'नया',
      r'\bapproved\b': 'स्वीकृत',
      r'\brejected\b': 'अस्वीकार',
      r'\bnoted\b': 'नोट कर लिया गया है',
      r'\btomorrow\b': 'कल',
      r'\btoday\b': 'आज',
      r'\byesterday\b': 'कल',
      r'\bmonday\b': 'सोमवार',
      r'\btuesday\b': 'मंगलवार',
      r'\bwednesday\b': 'बुधवार',
      r'\bthursday\b': 'गुरुवार',
      r'\bfriday\b': 'शुक्रवार',
      r'\bsaturday\b': 'शनिवार',
      r'\bsunday\b': 'रविवार',
      r'\bprincipal\b': 'प्रधानाचार्य',
      r'\bteacher\b': 'शिक्षक',
      r'\bteachers\b': 'शिक्षकों',
      r'\bstudent\b': 'छात्र',
      r'\bstudents\b': 'छात्रों',
      r'\bschool\b': 'स्कूल',
      r'\boffice\b': 'कार्यालय',
      r'\bfees\b': 'फीस',
      r'\bfee\b': 'फीस',
      r'\bexam\b': 'परीक्षा',
      r'\bexams\b': 'परीक्षाएं',
      r'\bresult\b': 'परिणाम',
      r'\bmarks\b': 'अंक',
      r'\bclass\b': 'कक्षा',
      r'\battendance\b': 'उपस्थिति',
      r'\bholiday\b': 'छुट्टी',
      r'\bcomplaint\b': 'शिकायत',
      r'\bcomplaints\b': 'शिकायतें',
      r'\bmessage\b': 'संदेश',
      r'\bmessages\b': 'संदेश',
      r'\byes\b': 'हाँ',
      r'\bno\b': 'नहीं',
      r'\bok\b': 'ठीक है',
      r'\bokay\b': 'ठीक है',
      r'\burgent\b': 'अति आवश्यक',
      r'\bnormal\b': 'सामान्य',
      r'\bpassed\b': 'उत्तीर्ण',
      r'\bfailed\b': 'अनुत्तीर्ण',
      r'\bpromoted\b': 'अगली कक्षा में प्रोन्नत',
    };

    wordMap.forEach((pattern, replacement) {
      cleaned = cleaned.replaceAll(RegExp(pattern, caseSensitive: false), replacement);
    });

    return cleaned;
  }

  /// Generates clear, polite Hindi speech for parents regarding a complaint or message from the school/principal.
  String generateComplaintHindiSpeech({
    required String subject,
    required String message,
    required String status,
    required String category,
    String? reply,
    String? studentName,
  }) {
    final buffer = StringBuffer();
    final isResolved = status.toLowerCase() == 'resolved';
    final hasReply = reply != null && reply.trim().isNotEmpty;

    final hindiReply = hasReply ? translateEnglishToHindi(reply.trim()) : '';
    final hindiSubject = translateEnglishToHindi(subject.trim());
    final hindiMessage = translateEnglishToHindi(message.trim());

    if (hasReply) {
      buffer.write('नमस्ते! ');
      if (studentName != null && studentName.trim().isNotEmpty) {
        buffer.write('छात्र $studentName के लिए ');
      }
      buffer.write('प्रधानाचार्य कार्यालय से आपकी शिकायत का जवाब आया है। ');
      buffer.write('प्रधानाचार्य जी का संदेश है: $hindiReply। ');
      if (hindiSubject.isNotEmpty) {
        buffer.write('आपकी शिकायत का विषय था: $hindiSubject। ');
      }
      if (isResolved) {
        buffer.write('स्थिति: इस शिकायत का समाधान हो चुका है। ');
      } else {
        buffer.write('स्थिति: यह शिकायत अभी समीक्षाधीन है। ');
      }
      buffer.write('धन्यवाद!');
    } else {
      buffer.write('नमस्ते! ');
      if (studentName != null && studentName.trim().isNotEmpty) {
        buffer.write('छात्र $studentName के लिए ');
      }
      buffer.write('आपकी भेजी गई शिकायत अभी स्कूल कार्यालय में समीक्षाधीन है। ');
      if (hindiSubject.isNotEmpty) {
        buffer.write('शिकायत का विषय: $hindiSubject। ');
      }
      if (hindiMessage.isNotEmpty) {
        buffer.write('आपका भेजा गया संदेश था: $hindiMessage। ');
      }
      buffer.write('जैसे ही प्रधानाचार्य जी का जवाब आएगा, आपको सूचित कर दिया जाएगा। धन्यवाद!');
    }

    return buffer.toString();
  }

  /// Generates an encouraging, clear Hindi speech for student exam results.
  String generateResultHindiSpeech({
    required String studentName,
    required String examName,
    required double obtainedMarks,
    required double totalMarks,
    required String pct,
    required String grade,
    required bool isPass,
    String? finalResultStatus,
  }) {
    final buffer = StringBuffer();
    buffer.write('नमस्ते! छात्र $studentName का $examName परीक्षा का परिणाम। ');
    buffer.write('कुल ${totalMarks.toInt()} अंकों में से ${obtainedMarks.toInt()} अंक प्राप्त हुए हैं। ');
    buffer.write('प्रतिशत: $pct प्रतिशत है। ');
    if (grade.isNotEmpty) {
      buffer.write('ग्रेड: $grade है। ');
    }
    if (finalResultStatus == 'PROMOTED') {
      buffer.write('बधाई हो, छात्र अगली कक्षा में प्रोन्नत हो गया है!');
    } else if (isPass) {
      buffer.write('बधाई हो, छात्र परीक्षा में सफलता पूर्वक उत्तीर्ण हो गया है!');
    } else {
      buffer.write('छात्र इस परीक्षा में अनुत्तीर्ण रहा है, आगे और अधिक परिश्रम की आवश्यकता है।');
    }
    return buffer.toString();
  }

  /// Generates a polite, clear, natural Hindi spoken summary for parents.
  String generateHindiReport({
    required StudentModel student,
    required double pendingFees,
    required double attendancePercentage,
    int? presentDays,
    int? totalDays,
    String? latestExamName,
    double? marksPercent,
    String? schoolName,
  }) {
    final buffer = StringBuffer();

    // 1. Greeting
    buffer.write('नमस्ते! ');
    if (schoolName != null && schoolName.trim().isNotEmpty) {
      buffer.write('$schoolName की तरफ से आपका स्वागत है। ');
    }

    // 2. Student Introduction
    final name = student.name.trim();
    final studentClass = student.className?.trim() ?? '';
    buffer.write('यह आपके बच्चे $name की स्कूल रिपोर्ट है। ');
    if (studentClass.isNotEmpty) {
      buffer.write('कक्षा $studentClass। ');
    }

    // 3. Attendance
    if (totalDays != null && totalDays > 0) {
      buffer.write('उपस्थिति: कुल $totalDays दिनों में से $presentDays दिन उपस्थित रहे हैं, यानी ${attendancePercentage.toStringAsFixed(0)} प्रतिशत उपस्थिति है। ');
    } else if (attendancePercentage > 0) {
      buffer.write('उपस्थिति: कुल उपस्थिति ${attendancePercentage.toStringAsFixed(0)} प्रतिशत है। ');
    } else {
      buffer.write('उपस्थिति: इस सत्र की उपस्थिति दर्ज की जा रही है। ');
    }

    // 4. Fees
    if (pendingFees <= 0) {
      buffer.write('फीस की स्थिति: स्कूल की सभी फीस पूरी तरह जमा है, कोई बकाया नहीं है। बहुत बहुत धन्यवाद! ');
    } else {
      buffer.write('फीस की स्थिति: स्कूल की कुल ${pendingFees.toStringAsFixed(0)} रुपये फीस बकाया है। कृपया इसे समय पर जमा करा दें। ');
    }

    // 5. Result
    if (latestExamName != null && latestExamName.isNotEmpty && marksPercent != null && marksPercent > 0) {
      buffer.write('परीक्षा परिणाम: $latestExamName में ${marksPercent.toStringAsFixed(0)} प्रतिशत अंक प्राप्त हुए हैं। ');
    }

    buffer.write('अधिक जानकारी या सहायता के लिए आप स्कूल कार्यालय से सीधे संपर्क कर सकते हैं। धन्यवाद!');
    return buffer.toString();
  }
}
