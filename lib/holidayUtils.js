/**
 * School Calendar & Holiday Management Utility
 * Handles pre-set national & festival holidays, automatic Sunday detection,
 * and custom school-declared holidays with causes/reasons.
 */

export const PRESET_HOLIDAYS_2026 = {
  '01-01': { title: "New Year's Day (नव वर्ष)", reason: 'Public Holiday', type: 'national' },
  '01-26': { title: 'Republic Day (गणतंत्र दिवस)', reason: 'National Holiday', type: 'national' },
  '03-03': { title: 'Holika Dahan (होलिका दहन)', reason: 'Festival Holiday', type: 'festival' },
  '03-04': { title: 'Holi (धुलंडी / रंगों का त्योहार)', reason: 'Festival Holiday', type: 'festival' },
  '04-14': { title: 'Ambedkar Jayanti (आंबेडकर जयंती)', reason: 'Gazetted Holiday', type: 'national' },
  '08-15': { title: 'Independence Day (स्वतंत्रता दिवस)', reason: 'National Holiday', type: 'national' },
  '10-02': { title: 'Gandhi Jayanti (गांधी जयंती)', reason: 'National Holiday', type: 'national' },
  '10-20': { title: 'Dussehra / Vijayadashami (दशहरा)', reason: 'Festival Holiday', type: 'festival' },
  '11-08': { title: 'Diwali / Deepavali (दीपावली)', reason: 'Festival Holiday', type: 'festival' },
  '11-09': { title: 'Govardhan Puja (गोवर्धन पूजा)', reason: 'Festival Holiday', type: 'festival' },
  '11-10': { title: 'Bhai Dooj (भाई दूज)', reason: 'Festival Holiday', type: 'festival' },
  '11-15': { title: 'Chhath Puja (छठ पूजा - संध्या अर्घ्य)', reason: 'Festival Holiday', type: 'festival' },
  '11-16': { title: 'Chhath Puja (छठ पूजा - प्रातः अर्घ्य)', reason: 'Festival Holiday', type: 'festival' },
  '12-25': { title: 'Christmas Day (क्रिसमस)', reason: 'Festival Holiday', type: 'festival' }
};

/**
 * Checks if a given date is Sunday, an official preset holiday, or a school-declared holiday.
 * Returns null if regular working school day.
 */
export function getHolidayInfo(dateInput, customHolidays = {}) {
  if (!dateInput) return null;
  const d = typeof dateInput === 'string'
    ? new Date(dateInput.includes('T') ? dateInput : `${dateInput}T00:00:00`)
    : new Date(dateInput);
  if (isNaN(d.getTime())) return null;

  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  const dateKey = `${y}-${m}-${day}`;
  const mdKey = `${m}-${day}`;

  // 1. Check custom declared holiday for this school (DM order, heavy rain, local holiday)
  if (customHolidays && customHolidays[dateKey]) {
    const custom = customHolidays[dateKey];
    return {
      isHoliday: true,
      isSunday: false,
      isCustom: true,
      date: dateKey,
      title: custom.title || 'School Holiday',
      reason: custom.reason || custom.cause || 'Declared by School Management',
      type: custom.type || 'declared'
    };
  }

  // 2. Check Sunday (day 0)
  if (d.getDay() === 0) {
    return {
      isHoliday: true,
      isSunday: true,
      isCustom: false,
      date: dateKey,
      title: 'Sunday (रविवार)',
      reason: 'Weekly Off / साप्ताहिक अवकाश',
      type: 'sunday'
    };
  }

  // 3. Check preset calendar festival / gazetted holiday
  if (PRESET_HOLIDAYS_2026[mdKey]) {
    const preset = PRESET_HOLIDAYS_2026[mdKey];
    return {
      isHoliday: true,
      isSunday: false,
      isCustom: false,
      date: dateKey,
      title: preset.title,
      reason: preset.reason,
      type: preset.type
    };
  }

  return null;
}
