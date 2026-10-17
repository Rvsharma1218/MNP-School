/**
 * Speech synthesis utility for Hindi/English text-to-speech
 * Designed for illiterate or vernacular parents and students.
 */

let currentSpeakingId = null;

export function isSpeechSupported() {
  return typeof window !== 'undefined' && 'speechSynthesis' in window;
}

export function stopSpeech() {
  if (isSpeechSupported()) {
    try {
      window.speechSynthesis.cancel();
    } catch (_) {}
  }
  currentSpeakingId = null;
}

export function getCurrentSpeakingId() {
  return currentSpeakingId;
}

export function speakHindi(text, id = null, onEnd = null) {
  if (!isSpeechSupported()) return false;

  stopSpeech();
  if (!text || !text.trim()) return false;

  currentSpeakingId = id;

  try {
    const utterance = new SpeechSynthesisUtterance(text.trim());
    utterance.lang = 'hi-IN';
    utterance.rate = 0.92; // Slightly slower for clarity
    utterance.pitch = 1.0;

    // Pick best Hindi / Indian English voice if available
    const voices = window.speechSynthesis.getVoices() || [];
    const hindiVoice = voices.find(
      (v) =>
        v.lang === 'hi-IN' ||
        v.lang.startsWith('hi') ||
        v.name.toLowerCase().includes('hindi') ||
        v.name.toLowerCase().includes('india')
    );
    if (hindiVoice) {
      utterance.voice = hindiVoice;
    }

    utterance.onend = () => {
      currentSpeakingId = null;
      if (onEnd) onEnd();
    };
    utterance.onerror = () => {
      currentSpeakingId = null;
      if (onEnd) onEnd();
    };

    window.speechSynthesis.speak(utterance);
    return true;
  } catch (err) {
    console.warn('SpeechSynthesis error:', err);
    currentSpeakingId = null;
    return false;
  }
}

/**
 * Generates natural Hindi speech for complaints and replies
 */
export function generateComplaintHindiSpeech({ subject, message, reply, status, studentName }) {
  const parts = [];
  if (studentName) {
    parts.push(`छात्र ${studentName} के अभिभावक का संदेश।`);
  }
  if (subject) {
    parts.push(`विषय: ${subject}।`);
  }
  if (message) {
    parts.push(`शिकायत विवरण: ${message}।`);
  }
  const isResolved = (status || '').toLowerCase() === 'resolved';
  if (isResolved) {
    parts.push('स्थिति: यह समस्या सुलझा दी गई है।');
  } else {
    parts.push('स्थिति: यह शिकायत अभी विचाराधीन है।');
  }
  if (reply) {
    parts.push(`प्रिंसिपल कार्यालय का जवाब: ${reply}।`);
  }
  return parts.join(' ');
}

/**
 * Generates natural Hindi speech for exam results
 */
export function generateResultHindiSpeech({ examName, studentName, obtainedMarks, totalMarks, percentage, grade, isPass }) {
  const parts = [];
  parts.push(`परीक्षा परिणाम की जानकारी।`);
  if (studentName) {
    parts.push(`छात्र: ${studentName}।`);
  }
  if (examName) {
    parts.push(`परीक्षा: ${examName}।`);
  }
  if (totalMarks > 0) {
    parts.push(`कुल अंक: ${totalMarks} में से ${obtainedMarks} अंक प्राप्त हुए हैं।`);
  }
  if (percentage) {
    parts.push(`प्रतिशत: ${percentage} प्रतिशत।`);
  }
  if (grade) {
    parts.push(`ग्रेड: ${grade}।`);
  }
  if (isPass !== undefined) {
    parts.push(isPass ? 'बधाई हो, छात्र परीक्षा में उत्तीर्ण हुआ है।' : 'छात्र अनुत्तीर्ण रहा है, और मेहनत की आवश्यकता है।');
  }
  return parts.join(' ');
}

/**
 * Generates natural Hindi speech for notice/circulars
 */
export function generateNoticeHindiSpeech({ title, content }) {
  const parts = ['स्कूल की आधिकारिक सूचना।'];
  if (title) parts.push(`शीर्षक: ${title}।`);
  if (content) parts.push(`विवरण: ${content}।`);
  return parts.join(' ');
}
