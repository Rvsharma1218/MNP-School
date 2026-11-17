// Automatic Bilingual (English <-> Hindi) Translation Engine for CMS Content
// Works seamlessly even if the admin entered text in only one language.

const hasDevanagari = (text) => /[\u0900-\u097F]/.test(String(text || ''));

export const CMS_DICTIONARY = {
  // Common Categories
  'all': { en: 'All Photos', hi: 'सभी तस्वीरें' },
  'campus': { en: 'Campus', hi: 'कैंपस' },
  'sports': { en: 'Sports', hi: 'खेलकूद' },
  'events': { en: 'Events', hi: 'कार्यक्रम' },
  'class': { en: 'Classrooms', hi: 'कक्षाएं' },
  'classrooms': { en: 'Classrooms', hi: 'कक्षाएं' },
  'classroom': { en: 'Classroom', hi: 'कक्षा' },
  'projects': { en: 'Projects', hi: 'प्रोजेक्ट्स' },
  'project': { en: 'Project', hi: 'प्रोजेक्ट' },
  'academics': { en: 'Academics', hi: 'शैक्षणिक' },
  'academic': { en: 'Academic', hi: 'शैक्षणिक' },
  'annual day': { en: 'Annual Day', hi: 'वार्षिक उत्सव' },
  'competitions': { en: 'Competitions', hi: 'प्रतियोगिताएं' },
  'competition': { en: 'Competition', hi: 'प्रतियोगिता' },
  'exhibitions': { en: 'Exhibitions', hi: 'प्रदर्शनी' },
  'exhibition': { en: 'Exhibition', hi: 'प्रदर्शनी' },
  'tours & trips': { en: 'Tours & Trips', hi: 'शैक्षणिक भ्रमण' },
  'tours': { en: 'Tours & Trips', hi: 'शैक्षणिक भ्रमण' },
  'independence day': { en: 'Independence Day', hi: 'स्वतंत्रता दिवस' },
  'republic day': { en: 'Republic Day', hi: 'गणतंत्र दिवस' },

  // Common School Phrases
  'computer project': { en: 'Computer Project', hi: 'कंप्यूटर प्रोजेक्ट' },
  'science project': { en: 'Science Project', hi: 'विज्ञान प्रोजेक्ट' },
  'science exhibition': { en: 'Science Exhibition', hi: 'विज्ञान प्रदर्शनी' },
  'drawing competition': { en: 'Drawing Competition', hi: 'चित्रकला प्रतियोगिता' },
  'sports & football arena': { en: 'Sports & Football Arena', hi: 'खेलकूद एवं फुटबॉल मैदान' },
  'sports arena': { en: 'Sports Field', hi: 'खेलकूद मैदान' },
  'main campus entrance': { en: 'Main Campus Entrance', hi: 'मुख्य कैंपस प्रवेश द्वार' },
  'academic building block': { en: 'Academic Building Block', hi: 'शैक्षणिक भवन ब्लॉक' },
  'student arrival & campus life': { en: 'Student Arrival & Campus Life', hi: 'विद्यार्थी आगमन एवं कैंपस जीवन' },
  'school building': { en: 'School Building', hi: 'विद्यालय भवन' },
  'morning assembly': { en: 'Morning Assembly', hi: 'प्रातःकालीन सभा' },
  'smart classroom': { en: 'Smart Classroom', hi: 'स्मार्ट क्लासरूम' },
  'computer lab': { en: 'Computer Lab', hi: 'कंप्यूटर लैब' },
  'library': { en: 'Library', hi: 'पुस्तकालय' },
  'laboratory': { en: 'Laboratory', hi: 'प्रयोगशाला' },
  'principal': { en: 'Principal', hi: 'प्रधानाचार्य' },
  'director': { en: 'Director', hi: 'निदेशक' },
  'chairman': { en: 'Chairman', hi: 'चेयरमैन' },
  'teacher': { en: 'Teacher', hi: 'शिक्षक' },
  'faculty': { en: 'Faculty', hi: 'शिक्षक दल' },
  'admissions open': { en: 'Admissions Open', hi: 'नामांकन प्रारंभ' },
  'admission': { en: 'Admission', hi: 'नामांकन' },
  'flash notice': { en: 'Flash Notice', hi: 'नवीन सूचना' },
  'notice': { en: 'Notice', hi: 'सूचना' },
  'view full photo': { en: 'View Full Photo', hi: 'बड़ी फ़ोटो देखें' },
  'explore full gallery': { en: 'Explore Full Gallery', hi: 'पूरी फोटो गैलरी देखें' }
};

// Memory cache for runtime translations
const memoryCache = new Map();

/**
 * Translate text between English and Hindi.
 * Uses dictionary first (0ms), then localStorage cache, then free Google Translate API.
 */
export async function translateText(text, targetLang = 'hi') {
  if (!text || typeof text !== 'string') return '';
  const trimmed = text.trim();
  if (!trimmed) return '';

  const isTargetHi = targetLang === 'hi';
  const textHasDevanagari = hasDevanagari(trimmed);

  // If already in target language, return as-is
  if (isTargetHi && textHasDevanagari) return trimmed;
  if (!isTargetHi && !textHasDevanagari) return trimmed;

  // Check Dictionary
  const lowerKey = trimmed.toLowerCase();
  if (CMS_DICTIONARY[lowerKey]) {
    return isTargetHi ? CMS_DICTIONARY[lowerKey].hi : CMS_DICTIONARY[lowerKey].en;
  }

  // Reverse dictionary search
  for (const item of Object.values(CMS_DICTIONARY)) {
    if (isTargetHi && item.en.toLowerCase() === lowerKey) return item.hi;
    if (!isTargetHi && item.hi === trimmed) return item.en;
  }

  // Check Cache
  const cacheKey = `mnp_tr_${targetLang}_${trimmed}`;
  if (memoryCache.has(cacheKey)) return memoryCache.get(cacheKey);

  if (typeof window !== 'undefined') {
    try {
      const stored = localStorage.getItem(cacheKey);
      if (stored) {
        memoryCache.set(cacheKey, stored);
        return stored;
      }
    } catch (_) {}
  }

  // Fetch translation via Google Translate single endpoint
  try {
    const sl = isTargetHi ? 'en' : 'hi';
    const tl = isTargetHi ? 'hi' : 'en';
    const url = `https://translate.googleapis.com/translate_a/single?client=gtx&sl=${sl}&tl=${tl}&dt=t&q=${encodeURIComponent(trimmed)}`;
    const res = await fetch(url);
    if (!res.ok) return trimmed;
    const data = await res.json();
    if (data && data[0] && Array.isArray(data[0])) {
      const translated = data[0].map(part => (part && part[0]) ? part[0] : '').join('').trim();
      if (translated) {
        memoryCache.set(cacheKey, translated);
        if (typeof window !== 'undefined') {
          try { localStorage.setItem(cacheKey, translated); } catch (_) {}
        }
        return translated;
      }
    }
  } catch (_) {}

  return trimmed;
}

/**
 * Synchronous dictionary translator for zero latency on known words
 */
export function getQuickTranslation(text, isHi) {
  if (!text || typeof text !== 'string') return '';
  const trimmed = text.trim();
  if (!trimmed) return '';

  const textHasDevanagari = hasDevanagari(trimmed);
  if (isHi && textHasDevanagari) return trimmed;
  if (!isHi && !textHasDevanagari) return trimmed;

  const lowerKey = trimmed.toLowerCase();
  if (CMS_DICTIONARY[lowerKey]) {
    return isHi ? CMS_DICTIONARY[lowerKey].hi : CMS_DICTIONARY[lowerKey].en;
  }

  // Check memory cache
  const cacheKey = `mnp_tr_${isHi ? 'hi' : 'en'}_${trimmed}`;
  if (memoryCache.has(cacheKey)) return memoryCache.get(cacheKey);

  if (typeof window !== 'undefined') {
    try {
      const stored = localStorage.getItem(cacheKey);
      if (stored) {
        memoryCache.set(cacheKey, stored);
        return stored;
      }
    } catch (_) {}
  }

  return trimmed;
}

/**
 * Resolves a CMS field, prioritizing explicit language fields, then auto-translating.
 */
export function resolveCmsWithAutoTranslate(obj, keyBase, fallbackEn, fallbackHi, isHi) {
  if (!obj) return isHi ? (fallbackHi ?? '') : (fallbackEn ?? '');

  const raw = obj[keyBase];
  const rawEn = obj[keyBase + 'En'];
  const rawHi = obj[keyBase + 'Hi'];

  const isExplicitlyCleared =
    (raw !== undefined && String(raw).trim() === '') &&
    (rawEn === undefined || String(rawEn).trim() === '') &&
    (rawHi === undefined || String(rawHi).trim() === '');

  if (isExplicitlyCleared) return '';

  if (isHi) {
    // 1. Explicit Hindi entered by admin
    if (rawHi !== undefined && String(rawHi).trim() !== '') return String(rawHi).trim();
    // 2. Generic field if written in Hindi
    if (raw !== undefined && String(raw).trim() !== '' && hasDevanagari(raw)) return String(raw).trim();
    // 3. Fallback Hindi text if provided
    if (fallbackHi !== undefined && fallbackHi !== null && String(fallbackHi).trim() !== '' && hasDevanagari(fallbackHi)) return fallbackHi;

    // 4. Source text in English that needs translation to Hindi
    const sourceText = (rawEn && String(rawEn).trim()) || (raw && String(raw).trim()) || fallbackEn || '';
    if (sourceText) {
      const quick = getQuickTranslation(sourceText, true);
      // Trigger background translation fetch if not in dictionary
      if (quick === sourceText && !hasDevanagari(quick)) {
        translateText(sourceText, 'hi').catch(() => {});
      }
      return quick;
    }
    return fallbackHi ?? '';
  } else {
    // 1. Explicit English entered by admin
    if (rawEn !== undefined && String(rawEn).trim() !== '') return String(rawEn).trim();
    // 2. Generic field if written in English
    if (raw !== undefined && String(raw).trim() !== '' && !hasDevanagari(raw)) return String(raw).trim();
    // 3. Fallback English text if provided
    if (fallbackEn !== undefined && fallbackEn !== null && String(fallbackEn).trim() !== '' && !hasDevanagari(fallbackEn)) return fallbackEn;

    // 4. Source text in Hindi that needs translation to English
    const sourceText = (rawHi && String(rawHi).trim()) || (raw && String(raw).trim()) || fallbackHi || '';
    if (sourceText) {
      const quick = getQuickTranslation(sourceText, false);
      if (quick === sourceText && hasDevanagari(quick)) {
        translateText(sourceText, 'en').catch(() => {});
      }
      return quick;
    }
    return fallbackEn ?? '';
  }
}
