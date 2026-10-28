'use client';

import React, { useState, useEffect, useMemo } from 'react';
import { useSchoolStore } from '../lib/store';
import {
  Calendar, Clock, Plus, Trash2, Printer, Download, BookOpen, User, Building,
  CheckCircle2, Share2, Save, Sparkles, Copy, Layers, Users, AlertTriangle,
  ArrowRight, Filter, Check, CheckSquare, Square, X, Sun, Utensils, Grid, LayoutGrid,
  Search, ShieldAlert, Award
} from 'lucide-react';
import { jsPDF } from 'jspdf';
import { getImageDataUrl } from '../lib/exportUtils';

export function isPrayerPeriod(p) {
  if (!p) return false;
  if (p.type === 'prayer') return true;
  const s = ((p.subject || '') + ' ' + (p.room || '')).toLowerCase();
  return s.includes('prayer') || s.includes('assembly') || s.includes('prarthana');
}

export function isLunchPeriod(p) {
  if (!p) return false;
  if (p.type === 'lunch') return true;
  const s = ((p.subject || '') + ' ' + (p.room || '')).toLowerCase();
  return s.includes('lunch') || s.includes('recess') || s.includes('tiffin') || s.includes('break') || s.includes('interval');
}

const defaultClassSchedule = {
  Monday: [
    { id: 'm_pr', period: 0, type: 'prayer', time: '08:30 AM - 09:00 AM', subject: 'Morning Prayer & Assembly', teacher: 'All Faculty', room: 'Ground' },
    { id: 1, period: 1, type: 'regular', time: '09:00 AM - 09:45 AM', subject: 'Hindi', teacher: 'Ramesh Sir', room: '101' },
    { id: 2, period: 2, type: 'regular', time: '09:45 AM - 10:30 AM', subject: 'English', teacher: 'Pooja Ma\'am', room: '101' },
    { id: 3, period: 3, type: 'regular', time: '10:45 AM - 11:30 AM', subject: 'Mathematics', teacher: 'Vikram Sir', room: '101' },
    { id: 4, period: 4, type: 'regular', time: '11:30 AM - 12:15 PM', subject: 'Science', teacher: 'Anjali Ma\'am', room: '101' },
    { id: 'm_ln', period: 0, type: 'lunch', time: '12:15 PM - 01:00 PM', subject: 'Lunch Break & Recess', teacher: 'Duty Staff', room: 'Cafeteria' },
    { id: 5, period: 5, type: 'regular', time: '01:00 PM - 01:45 PM', subject: 'Social Studies', teacher: 'Sanjay Sir', room: '101' },
    { id: 6, period: 6, type: 'regular', time: '01:45 PM - 02:30 PM', subject: 'Computer', teacher: 'Amit Sir', room: 'Lab 1' },
  ],
  Tuesday: [
    { id: 't_pr', period: 0, type: 'prayer', time: '08:30 AM - 09:00 AM', subject: 'Morning Prayer & Assembly', teacher: 'All Faculty', room: 'Ground' },
    { id: 7, period: 1, type: 'regular', time: '09:00 AM - 09:45 AM', subject: 'Mathematics', teacher: 'Vikram Sir', room: '101' },
    { id: 8, period: 2, type: 'regular', time: '09:45 AM - 10:30 AM', subject: 'Science', teacher: 'Anjali Ma\'am', room: '101' },
    { id: 9, period: 3, type: 'regular', time: '10:45 AM - 11:30 AM', subject: 'Hindi', teacher: 'Ramesh Sir', room: '101' },
    { id: 10, period: 4, type: 'regular', time: '11:30 AM - 12:15 PM', subject: 'English', teacher: 'Pooja Ma\'am', room: '101' },
    { id: 't_ln', period: 0, type: 'lunch', time: '12:15 PM - 01:00 PM', subject: 'Lunch Break & Recess', teacher: 'Duty Staff', room: 'Cafeteria' },
    { id: 11, period: 5, type: 'regular', time: '01:00 PM - 01:45 PM', subject: 'Drawing & Art', teacher: 'Sunita Ma\'am', room: 'Art Room' },
  ],
  Wednesday: [
    { id: 'w_pr', period: 0, type: 'prayer', time: '08:30 AM - 09:00 AM', subject: 'Morning Prayer & Assembly', teacher: 'All Faculty', room: 'Ground' },
    { id: 12, period: 1, type: 'regular', time: '09:00 AM - 09:45 AM', subject: 'English', teacher: 'Pooja Ma\'am', room: '101' },
    { id: 13, period: 2, type: 'regular', time: '09:45 AM - 10:30 AM', subject: 'Computer Lab', teacher: 'Amit Sir', room: 'Lab 1' },
    { id: 14, period: 3, type: 'regular', time: '10:45 AM - 11:30 AM', subject: 'Mathematics', teacher: 'Vikram Sir', room: '101' },
    { id: 15, period: 4, type: 'regular', time: '11:30 AM - 12:15 PM', subject: 'Science', teacher: 'Anjali Ma\'am', room: '101' },
    { id: 'w_ln', period: 0, type: 'lunch', time: '12:15 PM - 01:00 PM', subject: 'Lunch Break & Recess', teacher: 'Duty Staff', room: 'Cafeteria' },
  ],
  Thursday: [
    { id: 'th_pr', period: 0, type: 'prayer', time: '08:30 AM - 09:00 AM', subject: 'Morning Prayer & Assembly', teacher: 'All Faculty', room: 'Ground' },
    { id: 16, period: 1, type: 'regular', time: '09:00 AM - 09:45 AM', subject: 'Science', teacher: 'Anjali Ma\'am', room: '101' },
    { id: 17, period: 2, type: 'regular', time: '09:45 AM - 10:30 AM', subject: 'Maths', teacher: 'Vikram Sir', room: '101' },
    { id: 18, period: 3, type: 'regular', time: '10:45 AM - 11:30 AM', subject: 'Social Studies', teacher: 'Sanjay Sir', room: '101' },
    { id: 19, period: 4, type: 'regular', time: '11:30 AM - 12:15 PM', subject: 'Hindi', teacher: 'Ramesh Sir', room: '101' },
    { id: 'th_ln', period: 0, type: 'lunch', time: '12:15 PM - 01:00 PM', subject: 'Lunch Break & Recess', teacher: 'Duty Staff', room: 'Cafeteria' },
  ],
  Friday: [
    { id: 'f_pr', period: 0, type: 'prayer', time: '08:30 AM - 09:00 AM', subject: 'Morning Prayer & Assembly', teacher: 'All Faculty', room: 'Ground' },
    { id: 20, period: 1, type: 'regular', time: '09:00 AM - 09:45 AM', subject: 'Social Studies', teacher: 'Sanjay Sir', room: '101' },
    { id: 21, period: 2, type: 'regular', time: '09:45 AM - 10:30 AM', subject: 'Drawing & Art', teacher: 'Sunita Ma\'am', room: 'Art Room' },
    { id: 22, period: 3, type: 'regular', time: '10:45 AM - 11:30 AM', subject: 'Mathematics', teacher: 'Vikram Sir', room: '101' },
    { id: 23, period: 4, type: 'regular', time: '11:30 AM - 12:15 PM', subject: 'English', teacher: 'Pooja Ma\'am', room: '101' },
    { id: 'f_ln', period: 0, type: 'lunch', time: '12:15 PM - 01:00 PM', subject: 'Lunch Break & Recess', teacher: 'Duty Staff', room: 'Cafeteria' },
  ],
  Saturday: [
    { id: 's_pr', period: 0, type: 'prayer', time: '08:30 AM - 09:00 AM', subject: 'Morning Prayer & Assembly', teacher: 'All Faculty', room: 'Ground' },
    { id: 24, period: 1, type: 'regular', time: '09:00 AM - 09:45 AM', subject: 'Physical Education', teacher: 'Rana Sir', room: 'Playground' },
    { id: 25, period: 2, type: 'regular', time: '09:45 AM - 10:30 AM', subject: 'Moral Science', teacher: 'Principal Ma\'am', room: '101' },
    { id: 26, period: 3, type: 'regular', time: '10:45 AM - 11:30 AM', subject: 'General Knowledge', teacher: 'Pooja Ma\'am', room: '101' },
    { id: 's_ln', period: 0, type: 'lunch', time: '12:15 PM - 01:00 PM', subject: 'Lunch Break & Recess', teacher: 'Duty Staff', room: 'Cafeteria' },
  ],
};

function format12h(time24) {
  if (!time24) return '';
  const [hStr, mStr] = time24.split(':');
  let h = parseInt(hStr, 10);
  const m = mStr ? mStr.padStart(2, '0') : '00';
  if (isNaN(h)) return time24;
  const ampm = h >= 12 ? 'PM' : 'AM';
  h = h % 12;
  if (h === 0) h = 12;
  return `${String(h).padStart(2, '0')}:${m} ${ampm}`;
}

function addMinutesToTime(time24, mins) {
  if (!time24) return '09:45';
  const [hStr, mStr] = time24.split(':');
  let totalMin = (parseInt(hStr, 10) || 0) * 60 + (parseInt(mStr, 10) || 0) + mins;
  totalMin = (totalMin + 1440) % 1440;
  const newH = Math.floor(totalMin / 60);
  const newM = totalMin % 60;
  return `${String(newH).padStart(2, '0')}:${String(newM).padStart(2, '0')}`;
}

function calculateDuration(start24, end24) {
  if (!start24 || !end24) return 45;
  const [sh, sm] = start24.split(':').map(Number);
  const [eh, em] = end24.split(':').map(Number);
  let startTot = sh * 60 + sm;
  let endTot = eh * 60 + em;
  if (endTot < startTot) endTot += 1440;
  return Math.max(1, endTot - startTot);
}

export default function TimetableView() {
  const { settings, teachers, showToast } = useSchoolStore();
  const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
  const [activeDay, setActiveDay] = useState('Monday');
  const [selectedClass, setSelectedClass] = useState('10th');

  // Main View Mode: 'class' | 'master' | 'teacher'
  const [viewMode, setViewMode] = useState('class');

  const schoolClasses = settings.schoolClasses && settings.schoolClasses.length > 0
    ? settings.schoolClasses
    : ['Nursery', 'LKG', 'UKG', '1st', '2nd', '3rd', '4th', '5th', '6th', '7th', '8th', '9th', '10th', '11th', '12th'];

  const [timetable, setTimetable] = useState(defaultClassSchedule);
  const [isAdding, setIsAdding] = useState(false);
  const [periodType, setPeriodType] = useState('regular'); // 'regular' | 'prayer' | 'lunch'
  const [newSubject, setNewSubject] = useState('');
  const [newTeacher, setNewTeacher] = useState('');
  const [newRoom, setNewRoom] = useState('101');
  const [currentTimeStr, setCurrentTimeStr] = useState('');
  const [isExportingPdf, setIsExportingPdf] = useState(false);
  const [isExportingMasterPdf, setIsExportingMasterPdf] = useState(false);

  // Master Grid Filter: Highlight specific teacher across all classes
  const [masterTeacherHighlight, setMasterTeacherHighlight] = useState('all');

  // ─── Time Dialer State (Start & End Time pickers) ──────────────────────────
  const [dialerStart, setDialerStart] = useState('09:00');
  const [dialerEnd, setDialerEnd] = useState('09:45');

  // ─── Bulk Copy Schedule to Other Classes Modal ────────────────────────────
  const [isCopyModalOpen, setIsCopyModalOpen] = useState(false);
  const [targetClasses, setTargetClasses] = useState([]);
  const [copyScope, setCopyScope] = useState('all_days'); // 'all_days' | 'current_day'

  // ─── Teacher Routine Inspector State ──────────────────────────────────────
  const [selectedTeacher, setSelectedTeacher] = useState('all');

  // Preset quick appliers for Prayer and Lunch
  const applyPreset = (type) => {
    setPeriodType(type);
    if (type === 'prayer') {
      setNewSubject('Morning Prayer & Assembly');
      setNewTeacher('All Faculty / Assembly');
      setNewRoom('Ground');
      setDialerStart('08:30');
      setDialerEnd('09:00');
    } else if (type === 'lunch') {
      setNewSubject('Lunch Break & Recess');
      setNewTeacher('Duty Staff / Break');
      setNewRoom('Cafeteria');
      setDialerStart('12:15');
      setDialerEnd('01:00');
    } else {
      setNewSubject('');
      setNewTeacher('');
      setNewRoom('101');
      setDialerStart('09:00');
      setDialerEnd('09:45');
    }
  };

  const handleOpenAdd = (presetType = 'regular') => {
    applyPreset(presetType);
    setIsAdding(true);
  };

  useEffect(() => {
    try {
      const saved = localStorage.getItem(`timetable_${selectedClass}`);
      if (saved) {
        setTimetable(JSON.parse(saved));
      } else {
        setTimetable(defaultClassSchedule);
      }
    } catch (e) {
      setTimetable(defaultClassSchedule);
    }
    setCurrentTimeStr(new Date().toLocaleDateString('en-IN', {
      day: 'numeric', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit'
    }));
  }, [selectedClass]);

  const saveTimetable = (updated) => {
    setTimetable(updated);
    try {
      localStorage.setItem(`timetable_${selectedClass}`, JSON.stringify(updated));
    } catch (e) {}
  };

  const handleAddPeriod = (e) => {
    e.preventDefault();
    if (!newSubject.trim()) {
      showToast('Please enter subject name', 'error');
      return;
    }

    const formattedSlot = `${format12h(dialerStart)} - ${format12h(dialerEnd)}`;
    const currentList = timetable[activeDay] || [];
    
    // Auto-calculate period numbering: Prayer = 0, Lunch = 'L', Regular = next index
    let pNum = 1;
    if (periodType === 'prayer') {
      pNum = 0;
    } else if (periodType === 'lunch') {
      pNum = 'L';
    } else {
      const regularCount = currentList.filter(p => !isPrayerPeriod(p) && !isLunchPeriod(p)).length;
      pNum = regularCount + 1;
    }

    const newPeriod = {
      id: Date.now(),
      period: pNum,
      type: periodType,
      time: formattedSlot,
      subject: newSubject.trim(),
      teacher: newTeacher.trim() || (periodType === 'prayer' ? 'All Faculty' : periodType === 'lunch' ? 'Break' : 'Faculty'),
      room: newRoom.trim() || (periodType === 'prayer' ? 'Assembly Ground' : periodType === 'lunch' ? 'Cafeteria' : '101'),
    };

    // Sort order: Prayer first, then regular periods by start time, lunch in-between
    const updatedList = [...currentList, newPeriod];
    const updated = {
      ...timetable,
      [activeDay]: updatedList
    };

    saveTimetable(updated);
    setNewSubject('');
    setNewTeacher('');
    setIsAdding(false);
    showToast(`${periodType === 'prayer' ? 'Morning Prayer' : periodType === 'lunch' ? 'Lunch Break' : 'Period'} added to ${activeDay}!`, 'success');
  };

  const handleDeletePeriod = (id) => {
    const currentList = timetable[activeDay] || [];
    const updated = {
      ...timetable,
      [activeDay]: currentList.filter(p => p.id !== id)
    };
    saveTimetable(updated);
    showToast('Period removed', 'info');
  };

  // ─── Bulk Copy Handler: Replicate Schedule to Multiple Classes ───────────
  const handleOpenCopyModal = () => {
    const others = schoolClasses.filter(c => c !== selectedClass);
    setTargetClasses(others);
    setIsCopyModalOpen(true);
  };

  const handleToggleTargetClass = (cls) => {
    setTargetClasses(prev =>
      prev.includes(cls) ? prev.filter(c => c !== cls) : [...prev, cls]
    );
  };

  const handleToggleAllClasses = () => {
    const others = schoolClasses.filter(c => c !== selectedClass);
    if (targetClasses.length === others.length) {
      setTargetClasses([]);
    } else {
      setTargetClasses(others);
    }
  };

  const handleApplyBulkCopy = () => {
    if (targetClasses.length === 0) {
      showToast('Please select at least one class to copy to.', 'error');
      return;
    }

    try {
      targetClasses.forEach(targetClass => {
        let existingTarget = {};
        try {
          const raw = localStorage.getItem(`timetable_${targetClass}`);
          if (raw) existingTarget = JSON.parse(raw);
        } catch (_) {}

        let newSchedule;
        if (copyScope === 'all_days') {
          newSchedule = JSON.parse(JSON.stringify(timetable));
        } else {
          newSchedule = {
            ...existingTarget,
            [activeDay]: JSON.parse(JSON.stringify(timetable[activeDay] || []))
          };
        }
        localStorage.setItem(`timetable_${targetClass}`, JSON.stringify(newSchedule));
      });

      showToast(`Schedule successfully copied to ${targetClasses.length} classes!`, 'success');
      setIsCopyModalOpen(false);
    } catch (e) {
      showToast('Failed to copy timetable: ' + e.message, 'error');
    }
  };

  // ─── Master All Classes Schedule Data Cache ──────────────────────────────
  const allClassesSchedule = useMemo(() => {
    const map = {};
    schoolClasses.forEach(cls => {
      let clsSched = null;
      try {
        const raw = localStorage.getItem(`timetable_${cls}`);
        if (raw) clsSched = JSON.parse(raw);
      } catch (_) {}

      if (!clsSched) {
        if (cls === selectedClass) clsSched = timetable;
        else clsSched = defaultClassSchedule;
      }
      map[cls] = clsSched;
    });
    return map;
  }, [schoolClasses, selectedClass, timetable]);

  // Master Grid Clash Detector for the Active Day
  // If a teacher is assigned to >1 class in the same period / time on activeDay
  const masterDayClashes = useMemo(() => {
    const teacherSlotMap = {}; // key: teacher_lower + '_' + periodSlotKey
    const clashMap = {}; // key: teacher_lower + '_' + periodSlotKey -> list of classes

    schoolClasses.forEach(cls => {
      const clsDayList = (allClassesSchedule[cls]?.[activeDay] || []);
      clsDayList.forEach(p => {
        if (isPrayerPeriod(p) || isLunchPeriod(p)) return; // Prayers and Lunch are school-wide, no conflict
        const t = (p.teacher || '').trim();
        if (!t || t.toLowerCase() === 'faculty' || t.toLowerCase() === 'teacher') return;

        // Use period number or time slot as key
        const slotKey = `p_${p.period || p.time}`;
        const key = `${t.toLowerCase()}__${slotKey}`;

        if (!teacherSlotMap[key]) {
          teacherSlotMap[key] = [];
        }
        teacherSlotMap[key].push({ className: cls, teacher: t, period: p.period, time: p.time, subject: p.subject });
      });
    });

    Object.entries(teacherSlotMap).forEach(([key, items]) => {
      if (items.length > 1) {
        clashMap[key] = items;
      }
    });

    return clashMap;
  }, [allClassesSchedule, activeDay, schoolClasses]);

  // ─── Gather Teacher Schedule Across ALL School Classes ────────────────────
  const teacherScheduleData = useMemo(() => {
    const teacherMap = {};
    const allUniqueTeachers = new Set();

    if (teachers && teachers.length > 0) {
      teachers.forEach(t => {
        if (t.name) allUniqueTeachers.add(t.name.trim());
      });
    }

    schoolClasses.forEach(cls => {
      const clsSched = allClassesSchedule[cls] || defaultClassSchedule;

      days.forEach(day => {
        const pList = clsSched[day] || [];
        pList.forEach(p => {
          if (isPrayerPeriod(p) || isLunchPeriod(p)) return;
          const tName = (p.teacher || 'Faculty').trim();
          if (tName && tName.toLowerCase() !== 'faculty') {
            allUniqueTeachers.add(tName);
            if (!teacherMap[tName]) teacherMap[tName] = [];
            teacherMap[tName].push({
              className: cls,
              day,
              period: p.period,
              time: p.time,
              subject: p.subject,
              room: p.room,
              id: `${cls}_${day}_${p.period}_${p.id || Math.random()}`
            });
          }
        });
      });
    });

    const teacherList = Array.from(allUniqueTeachers).sort();
    return { teacherMap, teacherList };
  }, [allClassesSchedule, days, schoolClasses, teachers]);

  // Compute conflicts for selected teacher in Teacher Mode
  const teacherConflicts = useMemo(() => {
    if (selectedTeacher === 'all') return [];
    const list = teacherScheduleData.teacherMap[selectedTeacher] || [];
    const timeSlotMap = {};
    const conflicts = [];

    list.forEach(item => {
      const key = `${item.day}_${item.time}`;
      if (!timeSlotMap[key]) {
        timeSlotMap[key] = [];
      }
      timeSlotMap[key].push(item);
    });

    Object.entries(timeSlotMap).forEach(([k, items]) => {
      if (items.length > 1) {
        conflicts.push({
          day: items[0].day,
          time: items[0].time,
          classes: items.map(i => i.className).join(' & ')
        });
      }
    });

    return conflicts;
  }, [selectedTeacher, teacherScheduleData]);

  // ─── jsPDF Routine Document Generator (Single Class) ──────────────────────
  const handleDownloadPdf = async () => {
    setIsExportingPdf(true);
    try {
      const doc = new jsPDF({ orientation: 'landscape', unit: 'mm', format: 'a4' });
      const W = 297, H = 210, M = 10;
      const contentW = W - 2 * M;

      const logoSrc = settings.logoUrl || settings.logoPath || settings.logo;
      const sigSrc = settings.principalSignature || settings.signatureUrl || settings.signature;
      const stampSrc = settings.schoolStamp || settings.stampUrl || settings.sealUrl;
      const [logoData, sigData, stampData] = await Promise.all([
        getImageDataUrl(logoSrc),
        getImageDataUrl(sigSrc),
        getImageDataUrl(stampSrc),
      ]);

      // Outer Border
      doc.setDrawColor(30, 58, 138);
      doc.setLineWidth(1.2);
      doc.rect(M, M, contentW, H - 2 * M);

      doc.setDrawColor(219, 234, 254);
      doc.setLineWidth(0.4);
      doc.rect(M + 1.5, M + 1.5, contentW - 3, H - 2 * M - 3);

      let y = M + 8;
      if (logoData) {
        try {
          doc.addImage(logoData, 'PNG', M + 8, y, 18, 18);
        } catch (e) {}
      }

      doc.setTextColor(30, 58, 138);
      doc.setFont('helvetica', 'bold');
      doc.setFontSize(16);
      doc.text((settings.instituteName || settings.schoolName || 'MISSION NAVODAYA PUBLIC SCHOOL').toUpperCase(), W / 2, y + 4, { align: 'center' });

      doc.setFont('helvetica', 'normal');
      doc.setFontSize(8.5);
      doc.setTextColor(100, 116, 139);
      doc.text(`${settings.address || 'Campus Address'} | Contact: ${settings.phone || settings.mobile || 'Phone'}`, W / 2, y + 9.5, { align: 'center' });

      doc.setFont('helvetica', 'bold');
      doc.setFontSize(12);
      doc.setTextColor(15, 23, 42);
      doc.text(`OFFICIAL WEEKLY ROUTINE & TIMETABLE — CLASS ${selectedClass}`, W / 2, y + 16, { align: 'center' });

      y += 22;
      doc.setDrawColor(30, 58, 138);
      doc.setLineWidth(0.8);
      doc.line(M, y, W - M, y);
      y += 4;

      // Table layout with Prayer, 4 periods, Lunch, 2-4 periods
      const dayColW = 28;
      const prayerColW = 26;
      const lunchColW = 26;
      const numPeriods = 6;
      const periodColW = (contentW - dayColW - prayerColW - lunchColW) / numPeriods;
      const tableW = contentW;
      const headerH = 10;

      // Header row
      doc.setFillColor(30, 58, 138);
      doc.rect(M, y, tableW, headerH, 'F');
      doc.setTextColor(255, 255, 255);
      doc.setFont('helvetica', 'bold');
      doc.setFontSize(8.5);
      doc.text('DAY', M + dayColW / 2, y + 6.5, { align: 'center' });

      const defaultPeriodTimes = {
        1: '09:00 - 09:45',
        2: '09:45 - 10:30',
        3: '10:45 - 11:30',
        4: '11:30 - 12:15',
        5: '01:00 - 01:45',
        6: '01:45 - 02:30',
      };

      let curX = M + dayColW;
      // Prayer Column
      doc.setFillColor(217, 119, 6);
      doc.rect(curX, y, prayerColW, headerH, 'F');
      doc.setTextColor(255, 255, 255);
      doc.setFont('helvetica', 'bold');
      doc.setFontSize(7.5);
      doc.text('PRAYER', curX + prayerColW / 2, y + 4.2, { align: 'center' });
      doc.setFont('helvetica', 'normal');
      doc.setFontSize(6.2);
      doc.text('08:30 - 09:00', curX + prayerColW / 2, y + 8.0, { align: 'center' });
      curX += prayerColW;

      // Periods 1 to 4
      for (let p = 1; p <= 4; p++) {
        doc.setFillColor(30, 58, 138);
        doc.rect(curX, y, periodColW, headerH, 'F');
        doc.setTextColor(255, 255, 255);
        doc.setFont('helvetica', 'bold');
        doc.setFontSize(7.5);
        doc.text(`PERIOD ${p}`, curX + periodColW / 2, y + 4.2, { align: 'center' });
        doc.setFont('helvetica', 'normal');
        doc.setFontSize(6.2);
        doc.text(defaultPeriodTimes[p] || '', curX + periodColW / 2, y + 8.0, { align: 'center' });
        curX += periodColW;
      }

      // Lunch Column
      doc.setFillColor(5, 150, 105);
      doc.rect(curX, y, lunchColW, headerH, 'F');
      doc.setTextColor(255, 255, 255);
      doc.setFont('helvetica', 'bold');
      doc.setFontSize(7.5);
      doc.text('LUNCH', curX + lunchColW / 2, y + 4.2, { align: 'center' });
      doc.setFont('helvetica', 'normal');
      doc.setFontSize(6.2);
      doc.text('12:15 - 01:00', curX + lunchColW / 2, y + 8.0, { align: 'center' });
      curX += lunchColW;

      // Periods 5 to 6
      for (let p = 5; p <= 6; p++) {
        doc.setFillColor(30, 58, 138);
        doc.rect(curX, y, periodColW, headerH, 'F');
        doc.setTextColor(255, 255, 255);
        doc.setFont('helvetica', 'bold');
        doc.setFontSize(7.5);
        doc.text(`PERIOD ${p}`, curX + periodColW / 2, y + 4.2, { align: 'center' });
        doc.setFont('helvetica', 'normal');
        doc.setFontSize(6.2);
        doc.text(defaultPeriodTimes[p] || '', curX + periodColW / 2, y + 8.0, { align: 'center' });
        curX += periodColW;
      }

      let rowY = y + headerH;
      const rowH = 16.5;

      days.forEach((day, dIdx) => {
        doc.setFillColor(dIdx % 2 === 0 ? 255 : 249, dIdx % 2 === 0 ? 255 : 250, dIdx % 2 === 0 ? 255 : 251);
        doc.rect(M, rowY, tableW, rowH, 'F');
        doc.setDrawColor(229, 231, 235);
        doc.rect(M, rowY, tableW, rowH);

        // Day label
        doc.setFillColor(243, 244, 246);
        doc.rect(M, rowY, dayColW, rowH, 'F');
        doc.setDrawColor(209, 213, 219);
        doc.line(M + dayColW, rowY, M + dayColW, rowY + rowH);

        doc.setTextColor(30, 58, 138);
        doc.setFont('helvetica', 'bold');
        doc.setFontSize(8.5);
        doc.text(day.toUpperCase(), M + dayColW / 2, rowY + rowH / 2 + 1.5, { align: 'center' });

        const dayPeriods = timetable[day] || [];
        const prayerP = dayPeriods.find(isPrayerPeriod);
        const lunchP = dayPeriods.find(isLunchPeriod);

        let cellX = M + dayColW;

        // Render Prayer Cell
        doc.setFillColor(254, 243, 199);
        doc.rect(cellX, rowY, prayerColW, rowH, 'F');
        doc.setTextColor(180, 83, 9);
        doc.setFont('helvetica', 'bold');
        doc.setFontSize(7.5);
        doc.text('Prayer / Assembly', cellX + prayerColW / 2, rowY + 6, { align: 'center' });
        doc.setFont('helvetica', 'normal');
        doc.setFontSize(6.5);
        doc.setTextColor(146, 64, 14);
        doc.text(prayerP ? prayerP.time : '08:30 - 09:00', cellX + prayerColW / 2, rowY + 11, { align: 'center' });
        doc.setDrawColor(253, 230, 138);
        doc.line(cellX + prayerColW, rowY, cellX + prayerColW, rowY + rowH);
        cellX += prayerColW;

        // Render Periods 1 to 4
        for (let p = 1; p <= 4; p++) {
          doc.setDrawColor(229, 231, 235);
          doc.line(cellX + periodColW, rowY, cellX + periodColW, rowY + rowH);
          const matched = dayPeriods.find(item => !isPrayerPeriod(item) && !isLunchPeriod(item) && item.period === p);
          if (matched) {
            doc.setTextColor(17, 24, 39);
            doc.setFont('helvetica', 'bold');
            doc.setFontSize(8.5);
            doc.text(matched.subject || '', cellX + periodColW / 2, rowY + 5.5, { align: 'center' });
            doc.setFont('helvetica', 'normal');
            doc.setFontSize(7);
            doc.setTextColor(55, 65, 81);
            doc.text(matched.teacher || '', cellX + periodColW / 2, rowY + 10, { align: 'center' });
            doc.setTextColor(107, 114, 128);
            doc.setFontSize(6.5);
            doc.text(matched.room ? `R: ${matched.room}` : '', cellX + periodColW / 2, rowY + 14, { align: 'center' });
          } else {
            doc.setTextColor(180, 180, 180);
            doc.text('-', cellX + periodColW / 2, rowY + rowH / 2, { align: 'center' });
          }
          cellX += periodColW;
        }

        // Render Lunch Cell
        doc.setFillColor(209, 250, 229);
        doc.rect(cellX, rowY, lunchColW, rowH, 'F');
        doc.setTextColor(4, 120, 87);
        doc.setFont('helvetica', 'bold');
        doc.setFontSize(7.5);
        doc.text('Lunch Break', cellX + lunchColW / 2, rowY + 6, { align: 'center' });
        doc.setFont('helvetica', 'normal');
        doc.setFontSize(6.5);
        doc.setTextColor(6, 95, 70);
        doc.text(lunchP ? lunchP.time : '12:15 - 01:00', cellX + lunchColW / 2, rowY + 11, { align: 'center' });
        doc.setDrawColor(167, 243, 208);
        doc.line(cellX + lunchColW, rowY, cellX + lunchColW, rowY + rowH);
        cellX += lunchColW;

        // Render Periods 5 to 6
        for (let p = 5; p <= 6; p++) {
          doc.setDrawColor(229, 231, 235);
          doc.line(cellX + periodColW, rowY, cellX + periodColW, rowY + rowH);
          const matched = dayPeriods.find(item => !isPrayerPeriod(item) && !isLunchPeriod(item) && item.period === p);
          if (matched) {
            doc.setTextColor(17, 24, 39);
            doc.setFont('helvetica', 'bold');
            doc.setFontSize(8.5);
            doc.text(matched.subject || '', cellX + periodColW / 2, rowY + 5.5, { align: 'center' });
            doc.setFont('helvetica', 'normal');
            doc.setFontSize(7);
            doc.setTextColor(55, 65, 81);
            doc.text(matched.teacher || '', cellX + periodColW / 2, rowY + 10, { align: 'center' });
            doc.setTextColor(107, 114, 128);
            doc.setFontSize(6.5);
            doc.text(matched.room ? `R: ${matched.room}` : '', cellX + periodColW / 2, rowY + 14, { align: 'center' });
          } else {
            doc.setTextColor(180, 180, 180);
            doc.text('-', cellX + periodColW / 2, rowY + rowH / 2, { align: 'center' });
          }
          cellX += periodColW;
        }

        rowY += rowH;
      });

      const footerY = H - 18;
      doc.setDrawColor(156, 163, 175);
      doc.setLineWidth(0.8);
      doc.line(M + 10, footerY, M + 70, footerY);
      doc.setTextColor(55, 65, 81);
      doc.setFont('helvetica', 'bold');
      doc.setFontSize(8.5);
      doc.text('Class Teacher Signature', M + 40, footerY + 5, { align: 'center' });

      const rightSigX = W - M - 75;
      const rightCenterX = rightSigX + 32;

      const stampScale = Number(settings.stampScale) || 1.0;
      const sigScale = Number(settings.signatureScale) || 1.0;

      // Stamp centered at Principal signature position
      if (stampData) {
        try {
          const sSize = 22 * stampScale;
          doc.addImage(stampData, 'PNG', rightCenterX - sSize / 2, footerY - sSize / 2 - 5, sSize, sSize);
        } catch (e) {}
      }

      // Signature layered naturally inside / over the stamp
      if (sigData) {
        try {
          const sW = 38 * sigScale;
          const sH = 12 * sigScale;
          doc.addImage(sigData, 'PNG', rightCenterX - sW / 2, footerY - sH / 2 - 3, sW, sH);
        } catch (e) {}
      }

      doc.setDrawColor(30, 58, 138);
      doc.setLineWidth(1.0);
      doc.line(rightSigX, footerY, rightSigX + 65, footerY);

      doc.setTextColor(30, 58, 138);
      doc.setFont('helvetica', 'bold');
      doc.setFontSize(9);
      doc.text('Principal Sign', rightCenterX, footerY + 5, { align: 'center' });

      doc.save(`Class_${selectedClass}_Routine_Timetable.pdf`);
      showToast(`Timetable PDF downloaded for Class ${selectedClass}!`, 'success');
    } catch (err) {
      console.error('Timetable PDF error:', err);
      showToast('Error generating timetable PDF', 'error');
    } finally {
      setIsExportingPdf(false);
    }
  };

  // ─── MASTER TIMETABLE PDF GENERATOR (ALL CLASSES ON SINGLE DOCUMENT) ─────
  const handleDownloadMasterPdf = async () => {
    setIsExportingMasterPdf(true);
    try {
      const doc = new jsPDF({ orientation: 'landscape', unit: 'mm', format: 'a4' });
      const W = 297, H = 210, M = 8;
      const contentW = W - 2 * M;

      const logoSrc = settings.logoUrl || settings.logoPath || settings.logo;
      const sigSrc = settings.principalSignature || settings.signatureUrl || settings.signature;
      const stampSrc = settings.schoolStamp || settings.stampUrl || settings.sealUrl;
      const [logoData, sigData, stampData] = await Promise.all([
        getImageDataUrl(logoSrc),
        getImageDataUrl(sigSrc),
        getImageDataUrl(stampSrc),
      ]);

      // Outer Border
      doc.setDrawColor(30, 58, 138);
      doc.setLineWidth(1.0);
      doc.rect(M, M, contentW, H - 2 * M);

      doc.setDrawColor(219, 234, 254);
      doc.setLineWidth(0.4);
      doc.rect(M + 1.2, M + 1.2, contentW - 2.4, H - 2 * M - 2.4);

      let y = M + 5;
      if (logoData) {
        try {
          doc.addImage(logoData, 'PNG', M + 5, y, 15, 15);
        } catch (e) {}
      }

      doc.setTextColor(30, 58, 138);
      doc.setFont('helvetica', 'bold');
      doc.setFontSize(15);
      doc.text((settings.instituteName || settings.schoolName || 'MISSION NAVODAYA PUBLIC SCHOOL').toUpperCase(), W / 2, y + 4, { align: 'center' });

      doc.setFont('helvetica', 'normal');
      doc.setFontSize(8);
      doc.setTextColor(100, 116, 139);
      doc.text(`${settings.address || 'Campus Address'} | Contact: ${settings.phone || settings.mobile || 'Phone'}`, W / 2, y + 8.5, { align: 'center' });

      doc.setFont('helvetica', 'bold');
      doc.setFontSize(11);
      doc.setTextColor(15, 23, 42);
      doc.text(`MASTER SCHOOL TIMETABLE — ALL CLASSES (${activeDay.toUpperCase()})`, W / 2, y + 13.5, { align: 'center' });

      y += 18;
      doc.setDrawColor(30, 58, 138);
      doc.setLineWidth(0.8);
      doc.line(M, y, W - M, y);
      y += 2.5;

      // Master Table Columns
      const classColW = 20;
      const prayerColW = 24;
      const lunchColW = 24;
      const numPeriods = 6;
      const periodColW = (contentW - classColW - prayerColW - lunchColW) / numPeriods;
      const tableW = contentW;
      const headerH = 9.5;
      const defaultPeriodTimes = {
        1: '09:00 - 09:45',
        2: '09:45 - 10:30',
        3: '10:45 - 11:30',
        4: '11:30 - 12:15',
        5: '01:00 - 01:45',
        6: '01:45 - 02:30',
      };

      // Header row
      doc.setFillColor(30, 58, 138);
      doc.rect(M, y, tableW, headerH, 'F');
      doc.setTextColor(255, 255, 255);
      doc.setFont('helvetica', 'bold');
      doc.setFontSize(8);
      doc.text('CLASS', M + classColW / 2, y + 6.0, { align: 'center' });

      let curX = M + classColW;
      // Prayer Column Header
      doc.setFillColor(217, 119, 6);
      doc.rect(curX, y, prayerColW, headerH, 'F');
      doc.setTextColor(255, 255, 255);
      doc.setFont('helvetica', 'bold');
      doc.setFontSize(7.5);
      doc.text('PRAYER', curX + prayerColW / 2, y + 4.0, { align: 'center' });
      doc.setFont('helvetica', 'normal');
      doc.setFontSize(6.0);
      doc.text('08:30 - 09:00', curX + prayerColW / 2, y + 7.8, { align: 'center' });
      curX += prayerColW;

      for (let p = 1; p <= 4; p++) {
        doc.setFillColor(30, 58, 138);
        doc.rect(curX, y, periodColW, headerH, 'F');
        doc.setTextColor(255, 255, 255);
        doc.setFont('helvetica', 'bold');
        doc.setFontSize(7.5);
        doc.text(`PERIOD ${p}`, curX + periodColW / 2, y + 4.0, { align: 'center' });
        doc.setFont('helvetica', 'normal');
        doc.setFontSize(6.0);
        doc.text(defaultPeriodTimes[p] || '', curX + periodColW / 2, y + 7.8, { align: 'center' });
        curX += periodColW;
      }

      // Lunch Column Header
      doc.setFillColor(5, 150, 105);
      doc.rect(curX, y, lunchColW, headerH, 'F');
      doc.setTextColor(255, 255, 255);
      doc.setFont('helvetica', 'bold');
      doc.setFontSize(7.5);
      doc.text('LUNCH', curX + lunchColW / 2, y + 4.0, { align: 'center' });
      doc.setFont('helvetica', 'normal');
      doc.setFontSize(6.0);
      doc.text('12:15 - 01:00', curX + lunchColW / 2, y + 7.8, { align: 'center' });
      curX += lunchColW;

      for (let p = 5; p <= 6; p++) {
        doc.setFillColor(30, 58, 138);
        doc.rect(curX, y, periodColW, headerH, 'F');
        doc.setTextColor(255, 255, 255);
        doc.setFont('helvetica', 'bold');
        doc.setFontSize(7.5);
        doc.text(`PERIOD ${p}`, curX + periodColW / 2, y + 4.0, { align: 'center' });
        doc.setFont('helvetica', 'normal');
        doc.setFontSize(6.0);
        doc.text(defaultPeriodTimes[p] || '', curX + periodColW / 2, y + 7.8, { align: 'center' });
        curX += periodColW;
      }

      let rowY = y + headerH;
      // Auto calculate row height based on number of classes to fit comfortably on 1 page!
      const availableH = H - rowY - 26; // leave room for signature footer
      const maxRows = schoolClasses.length;
      const rowH = Math.min(12, Math.max(8.5, availableH / maxRows));

      schoolClasses.forEach((cls, idx) => {
        doc.setFillColor(idx % 2 === 0 ? 255 : 249, idx % 2 === 0 ? 255 : 250, idx % 2 === 0 ? 255 : 251);
        doc.rect(M, rowY, tableW, rowH, 'F');
        doc.setDrawColor(229, 231, 235);
        doc.rect(M, rowY, tableW, rowH);

        // Class Name Box
        doc.setFillColor(238, 242, 255);
        doc.rect(M, rowY, classColW, rowH, 'F');
        doc.setTextColor(30, 58, 138);
        doc.setFont('helvetica', 'bold');
        doc.setFontSize(8);
        doc.text(`Class ${cls}`, M + classColW / 2, rowY + rowH / 2 + 1, { align: 'center' });

        const clsDayList = (allClassesSchedule[cls]?.[activeDay] || []);
        let cellX = M + classColW;

        // Prayer Cell
        doc.setFillColor(254, 243, 199);
        doc.rect(cellX, rowY, prayerColW, rowH, 'F');
        doc.setTextColor(180, 83, 9);
        doc.setFont('helvetica', 'bold');
        doc.setFontSize(6.5);
        doc.text('Morning Prayer', cellX + prayerColW / 2, rowY + rowH / 2 - 0.5, { align: 'center' });
        doc.setFont('helvetica', 'normal');
        doc.setFontSize(5.5);
        doc.setTextColor(146, 64, 14);
        doc.text('All Assembly', cellX + prayerColW / 2, rowY + rowH / 2 + 3, { align: 'center' });
        doc.setDrawColor(253, 230, 138);
        doc.line(cellX + prayerColW, rowY, cellX + prayerColW, rowY + rowH);
        cellX += prayerColW;

        // Periods 1 to 4
        for (let p = 1; p <= 4; p++) {
          doc.setDrawColor(229, 231, 235);
          doc.line(cellX + periodColW, rowY, cellX + periodColW, rowY + rowH);
          const matched = clsDayList.find(item => !isPrayerPeriod(item) && !isLunchPeriod(item) && item.period === p);
          if (matched) {
            doc.setTextColor(17, 24, 39);
            doc.setFont('helvetica', 'bold');
            doc.setFontSize(7);
            doc.text(matched.subject || '', cellX + periodColW / 2, rowY + rowH / 2 - 1, { align: 'center' });
            doc.setFont('helvetica', 'normal');
            doc.setFontSize(6);
            doc.setTextColor(79, 70, 229);
            doc.text(matched.teacher || '', cellX + periodColW / 2, rowY + rowH / 2 + 2.5, { align: 'center' });
          } else {
            doc.setTextColor(180, 180, 180);
            doc.text('-', cellX + periodColW / 2, rowY + rowH / 2, { align: 'center' });
          }
          cellX += periodColW;
        }

        // Lunch Cell
        doc.setFillColor(209, 250, 229);
        doc.rect(cellX, rowY, lunchColW, rowH, 'F');
        doc.setTextColor(4, 120, 87);
        doc.setFont('helvetica', 'bold');
        doc.setFontSize(6.5);
        doc.text('Lunch Break', cellX + lunchColW / 2, rowY + rowH / 2 - 0.5, { align: 'center' });
        doc.setFont('helvetica', 'normal');
        doc.setFontSize(5.5);
        doc.setTextColor(6, 95, 70);
        doc.text('Campus Recess', cellX + lunchColW / 2, rowY + rowH / 2 + 3, { align: 'center' });
        doc.setDrawColor(167, 243, 208);
        doc.line(cellX + lunchColW, rowY, cellX + lunchColW, rowY + rowH);
        cellX += lunchColW;

        // Periods 5 to 6
        for (let p = 5; p <= 6; p++) {
          doc.setDrawColor(229, 231, 235);
          doc.line(cellX + periodColW, rowY, cellX + periodColW, rowY + rowH);
          const matched = clsDayList.find(item => !isPrayerPeriod(item) && !isLunchPeriod(item) && item.period === p);
          if (matched) {
            doc.setTextColor(17, 24, 39);
            doc.setFont('helvetica', 'bold');
            doc.setFontSize(7);
            doc.text(matched.subject || '', cellX + periodColW / 2, rowY + rowH / 2 - 1, { align: 'center' });
            doc.setFont('helvetica', 'normal');
            doc.setFontSize(6);
            doc.setTextColor(79, 70, 229);
            doc.text(matched.teacher || '', cellX + periodColW / 2, rowY + rowH / 2 + 2.5, { align: 'center' });
          } else {
            doc.setTextColor(180, 180, 180);
            doc.text('-', cellX + periodColW / 2, rowY + rowH / 2, { align: 'center' });
          }
          cellX += periodColW;
        }

        rowY += rowH;
      });

      const footerY = H - 15;
      doc.setDrawColor(156, 163, 175);
      doc.setLineWidth(0.8);
      doc.line(M + 10, footerY, M + 70, footerY);
      doc.setTextColor(55, 65, 81);
      doc.setFont('helvetica', 'bold');
      doc.setFontSize(8);
      doc.text('Academic Incharge / Timetable Coordinator', M + 40, footerY + 4.5, { align: 'center' });

      const rightSigX = W - M - 75;
      const rightCenterX = rightSigX + 32;

      const stampScale = Number(settings.stampScale) || 1.0;
      const sigScale = Number(settings.signatureScale) || 1.0;

      // Stamp centered at Principal signature position
      if (stampData) {
        try {
          const sSize = 20 * stampScale;
          doc.addImage(stampData, 'PNG', rightCenterX - sSize / 2, footerY - sSize / 2 - 4, sSize, sSize);
        } catch (e) {}
      }

      // Signature layered naturally inside / over the stamp
      if (sigData) {
        try {
          const sW = 36 * sigScale;
          const sH = 11 * sigScale;
          doc.addImage(sigData, 'PNG', rightCenterX - sW / 2, footerY - sH / 2 - 3, sW, sH);
        } catch (e) {}
      }

      doc.setDrawColor(30, 58, 138);
      doc.setLineWidth(1.0);
      doc.line(rightSigX, footerY, rightSigX + 65, footerY);

      doc.setTextColor(30, 58, 138);
      doc.setFont('helvetica', 'bold');
      doc.setFontSize(8.5);
      doc.text('Principal Sign', rightCenterX, footerY + 4.5, { align: 'center' });

      doc.save(`Master_School_Timetable_All_Classes_${activeDay}.pdf`);
      showToast(`Master Timetable PDF (All Classes) downloaded for ${activeDay}!`, 'success');
    } catch (err) {
      console.error('Master Timetable PDF error:', err);
      showToast('Error generating Master Timetable PDF', 'error');
    } finally {
      setIsExportingMasterPdf(false);
    }
  };

  const handleShare = async () => {
    if (navigator.share) {
      try {
        await navigator.share({
          title: `Class ${selectedClass} Timetable - ${settings.instituteName || settings.schoolName || 'School'}`,
          text: `Official Routine & Weekly Timetable for Class ${selectedClass}.`,
          url: window.location.href,
        });
      } catch (e) {}
    } else {
      navigator.clipboard.writeText(window.location.href);
      showToast('Link copied to clipboard for sharing!', 'success');
    }
  };

  return (
    <div className="space-y-6 pb-12 animate-in fade-in duration-200">
      {/* Top Controls & 3-Way View Mode Switcher */}
      <div className="print:hidden flex flex-col md:flex-row md:items-center justify-between gap-4 bg-white p-5 rounded-2xl border border-border shadow-xs">
        <div>
          <div className="flex flex-wrap items-center gap-3">
            <h1 className="text-xl font-black text-text flex items-center gap-2">
              <Calendar className="w-6 h-6 text-primary" />
              <span>Routine & Timetable Studio</span>
            </h1>
            {/* View Mode Toggle: Class Routine vs Master All Classes Grid vs Teacher Schedule */}
            <div className="flex items-center p-1 bg-surface2 rounded-xl border border-border">
              <button
                type="button"
                onClick={() => setViewMode('class')}
                className={`px-3 py-1.5 rounded-lg text-xs font-bold transition-all cursor-pointer flex items-center gap-1.5 ${
                  viewMode === 'class'
                    ? 'bg-primary text-white shadow-xs'
                    : 'text-text-secondary hover:text-text'
                }`}
              >
                <BookOpen className="w-3.5 h-3.5" />
                <span>Class Routine</span>
              </button>

              <button
                type="button"
                onClick={() => setViewMode('master')}
                className={`px-3 py-1.5 rounded-lg text-xs font-bold transition-all cursor-pointer flex items-center gap-1.5 ${
                  viewMode === 'master'
                    ? 'bg-primary text-white shadow-xs'
                    : 'text-text-secondary hover:text-text'
                }`}
                title="View all classes together on one screen"
              >
                <LayoutGrid className="w-3.5 h-3.5 text-amber-300" />
                <span>Master All-Classes Grid</span>
              </button>

              <button
                type="button"
                onClick={() => setViewMode('teacher')}
                className={`px-3 py-1.5 rounded-lg text-xs font-bold transition-all cursor-pointer flex items-center gap-1.5 ${
                  viewMode === 'teacher'
                    ? 'bg-primary text-white shadow-xs'
                    : 'text-text-secondary hover:text-text'
                }`}
              >
                <Users className="w-3.5 h-3.5" />
                <span>Teacher Schedule</span>
              </button>
            </div>
          </div>
          <p className="text-xs text-text-secondary mt-1">
            {viewMode === 'class' && 'Single class routine with special Morning Prayer & Lunch Break slots, interactive time dialer & PDF.'}
            {viewMode === 'master' && 'Single-page master matrix of ALL classes. Inspect which teacher is teaching which class at any period, track clashes & export master PDF.'}
            {viewMode === 'teacher' && 'Inspect any teacher\'s full-day schedule across all classes from morning to evening.'}
          </p>
        </div>

        <div className="flex flex-wrap items-center gap-2.5">
          {viewMode === 'class' && (
            <>
              {/* Class Selector */}
              <div className="flex items-center gap-2 bg-surface2 px-3 py-2 rounded-xl border border-border">
                <span className="text-xs font-bold text-text-secondary uppercase">Class:</span>
                <select
                  value={selectedClass}
                  onChange={(e) => setSelectedClass(e.target.value)}
                  className="bg-transparent text-xs font-bold text-primary focus:outline-none cursor-pointer"
                >
                  {schoolClasses.map(c => (
                    <option key={c} value={c}>Class {c}</option>
                  ))}
                </select>
              </div>

              {/* Quick Add Buttons for Prayer & Lunch */}
              <button
                type="button"
                onClick={() => handleOpenAdd('prayer')}
                className="px-3 py-2 rounded-xl bg-amber-50 hover:bg-amber-100 text-amber-800 font-bold text-xs border border-amber-300 transition-all flex items-center gap-1.5 cursor-pointer active:scale-95 shadow-2xs"
                title="Add Morning Prayer & Assembly"
              >
                <Sun className="w-3.5 h-3.5 text-amber-600" />
                <span>+ Prayer</span>
              </button>

              <button
                type="button"
                onClick={() => handleOpenAdd('lunch')}
                className="px-3 py-2 rounded-xl bg-emerald-50 hover:bg-emerald-100 text-emerald-800 font-bold text-xs border border-emerald-300 transition-all flex items-center gap-1.5 cursor-pointer active:scale-95 shadow-2xs"
                title="Add Lunch Break & Recess"
              >
                <Utensils className="w-3.5 h-3.5 text-emerald-600" />
                <span>+ Lunch</span>
              </button>

              {/* Bulk Copy Routine to Other Classes */}
              <button
                type="button"
                onClick={handleOpenCopyModal}
                className="px-3.5 py-2 rounded-xl bg-indigo-50 hover:bg-indigo-100 text-indigo-700 font-bold text-xs border border-indigo-200 transition-all flex items-center gap-1.5 cursor-pointer active:scale-95 shadow-2xs"
                title="Quickly copy this routine to other classes"
              >
                <Copy className="w-3.5 h-3.5 text-indigo-600" />
                <span>Copy to Classes</span>
              </button>

              <button
                type="button"
                onClick={handleDownloadPdf}
                disabled={isExportingPdf}
                className="px-4 py-2 rounded-xl bg-emerald-600 hover:bg-emerald-700 text-white font-bold text-xs shadow-md transition-all flex items-center gap-1.5 cursor-pointer active:scale-95 disabled:opacity-50"
              >
                <Download className="w-3.5 h-3.5" />
                <span>{isExportingPdf ? 'Exporting...' : 'Export Class PDF'}</span>
              </button>
            </>
          )}

          {viewMode === 'master' && (
            <>
              {/* Teacher Highlight Filter */}
              <div className="flex items-center gap-2 bg-surface2 px-3 py-2 rounded-xl border border-border">
                <span className="text-xs font-bold text-text-secondary uppercase">Track Teacher:</span>
                <select
                  value={masterTeacherHighlight}
                  onChange={(e) => setMasterTeacherHighlight(e.target.value)}
                  className="bg-transparent text-xs font-bold text-primary focus:outline-none cursor-pointer"
                >
                  <option value="all">-- All Teachers --</option>
                  {teacherScheduleData.teacherList.map(t => (
                    <option key={t} value={t}>{t}</option>
                  ))}
                </select>
              </div>

              {/* Download Master Timetable PDF */}
              <button
                type="button"
                onClick={handleDownloadMasterPdf}
                disabled={isExportingMasterPdf}
                className="px-4 py-2 rounded-xl bg-indigo-600 hover:bg-indigo-700 text-white font-bold text-xs shadow-md transition-all flex items-center gap-2 cursor-pointer active:scale-95 disabled:opacity-50"
              >
                <Download className="w-4 h-4" />
                <span>{isExportingMasterPdf ? 'Generating...' : 'Export Master PDF (All Classes)'}</span>
              </button>
            </>
          )}

          {viewMode === 'teacher' && (
            <div className="flex items-center gap-2 bg-surface2 px-3.5 py-2 rounded-xl border border-border">
              <span className="text-xs font-bold text-text-secondary uppercase">Teacher:</span>
              <select
                value={selectedTeacher}
                onChange={(e) => setSelectedTeacher(e.target.value)}
                className="bg-transparent text-xs font-bold text-primary focus:outline-none cursor-pointer"
              >
                <option value="all">-- Select Teacher to Inspect --</option>
                {teacherScheduleData.teacherList.map(t => (
                  <option key={t} value={t}>{t}</option>
                ))}
              </select>
            </div>
          )}
        </div>
      </div>

      {/* ══════════════════════════════════════════════════════════════════════
          MODE 1: CLASS ROUTINE VIEW (With Prayer & Lunch Special Treatment)
          ══════════════════════════════════════════════════════════════════════ */}
      {viewMode === 'class' && (
        <>
          {/* Weekday Switcher */}
          <div className="print:hidden flex items-center gap-2 overflow-x-auto pb-1">
            {days.map(day => {
              const isActive = activeDay === day;
              const count = (timetable[day] || []).length;
              return (
                <button
                  key={day}
                  onClick={() => setActiveDay(day)}
                  className={`px-4 py-2.5 rounded-xl text-xs font-bold flex items-center gap-2 transition-all cursor-pointer whitespace-nowrap ${
                    isActive
                      ? 'bg-primary text-white shadow-md'
                      : 'bg-white border border-border text-text-secondary hover:text-text'
                  }`}
                >
                  <span>{day}</span>
                  <span className={`px-2 py-0.5 rounded-md text-[10px] font-black ${isActive ? 'bg-white/20 text-white' : 'bg-surface2 text-text-secondary'}`}>
                    {count} Slots
                  </span>
                </button>
              );
            })}
          </div>

          {/* Routine Cards Grid */}
          <div className="bg-white border-2 border-indigo-950/20 rounded-2xl p-6 shadow-sm text-black">
            <div className="border-b-2 border-indigo-950 pb-4 mb-5 flex items-center justify-between">
              <div>
                <h2 className="font-black text-lg uppercase text-indigo-950">
                  {settings.instituteName || settings.schoolName || 'MISSION NAVODAYA PUBLIC SCHOOL'}
                </h2>
                <p className="text-xs text-gray-700 font-semibold mt-0.5">
                  Class Routine · <strong>Class {selectedClass} ({activeDay})</strong>
                </p>
              </div>
              <div className="text-right flex items-center gap-2">
                <span className="inline-block px-3.5 py-1.5 bg-indigo-50 border border-indigo-200 rounded-lg text-xs font-black text-indigo-950 uppercase tracking-wide">
                  {activeDay} ({(timetable[activeDay] || []).length} Slots)
                </span>
              </div>
            </div>

            {/* Quick Action Pills for Prayer and Lunch */}
            <div className="mb-4 flex flex-wrap items-center gap-2 print:hidden">
              <span className="text-xs font-bold text-gray-500 mr-1">Quick Slots:</span>
              <button
                onClick={() => handleOpenAdd('prayer')}
                className="px-3 py-1.5 bg-amber-50 hover:bg-amber-100 text-amber-900 border border-amber-300 rounded-lg text-xs font-bold flex items-center gap-1.5 transition-all cursor-pointer shadow-2xs"
              >
                <Sun className="w-3.5 h-3.5 text-amber-600" />
                <span>+ Add Morning Prayer (08:30 - 09:00 AM)</span>
              </button>
              <button
                onClick={() => handleOpenAdd('lunch')}
                className="px-3 py-1.5 bg-emerald-50 hover:bg-emerald-100 text-emerald-900 border border-emerald-300 rounded-lg text-xs font-bold flex items-center gap-1.5 transition-all cursor-pointer shadow-2xs"
              >
                <Utensils className="w-3.5 h-3.5 text-emerald-600" />
                <span>+ Add Lunch Break (12:15 - 01:00 PM)</span>
              </button>
              <button
                onClick={() => handleOpenAdd('regular')}
                className="px-3 py-1.5 bg-indigo-50 hover:bg-indigo-100 text-indigo-900 border border-indigo-300 rounded-lg text-xs font-bold flex items-center gap-1.5 transition-all cursor-pointer shadow-2xs"
              >
                <Plus className="w-3.5 h-3.5 text-indigo-600" />
                <span>+ Add Subject Period</span>
              </button>
            </div>

            {/* Modern Period Cards Grid */}
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4 mb-6">
              {(!timetable[activeDay] || timetable[activeDay].length === 0) ? (
                <div className="col-span-full p-8 text-center bg-gray-50 rounded-xl border border-gray-200 text-gray-500 text-sm">
                  No periods scheduled for {activeDay} in Class {selectedClass}. Click "+ Add Subject Period" or quick slots above.
                </div>
              ) : (
                timetable[activeDay].map((p, idx) => {
                  const isPrayer = isPrayerPeriod(p);
                  const isLunch = isLunchPeriod(p);

                  return (
                    <div
                      key={p.id || idx}
                      className={`rounded-xl p-4 shadow-2xs hover:shadow-sm transition-all relative group flex flex-col justify-between ${
                        isPrayer
                          ? 'bg-gradient-to-br from-amber-50/90 via-amber-50/40 to-white border-2 border-amber-300 hover:border-amber-400'
                          : isLunch
                          ? 'bg-gradient-to-br from-emerald-50/90 via-teal-50/40 to-white border-2 border-emerald-300 hover:border-emerald-400'
                          : 'bg-white border-2 border-indigo-100 hover:border-indigo-300'
                      }`}
                    >
                      <div>
                        <div className="flex items-center justify-between mb-2">
                          {isPrayer ? (
                            <span className="px-2.5 py-1 rounded-md bg-amber-600 text-white text-[11px] font-black uppercase tracking-wider flex items-center gap-1">
                              <Sun className="w-3 h-3" />
                              <span>Morning Prayer</span>
                            </span>
                          ) : isLunch ? (
                            <span className="px-2.5 py-1 rounded-md bg-emerald-600 text-white text-[11px] font-black uppercase tracking-wider flex items-center gap-1">
                              <Utensils className="w-3 h-3" />
                              <span>Lunch Break</span>
                            </span>
                          ) : (
                            <span className="px-2.5 py-1 rounded-md bg-indigo-950 text-white text-[11px] font-black uppercase tracking-wider">
                              Period {p.period || idx + 1}
                            </span>
                          )}

                          <div className="flex items-center gap-1.5">
                            <span className={`px-2 py-0.5 rounded-md text-[11px] font-bold border flex items-center gap-1 font-mono ${
                              isPrayer
                                ? 'bg-amber-100 text-amber-900 border-amber-300'
                                : isLunch
                                ? 'bg-emerald-100 text-emerald-900 border-emerald-300'
                                : 'bg-indigo-50 text-indigo-900 border-indigo-200'
                            }`}>
                              <Clock className="w-3 h-3" />
                              <span>{p.time}</span>
                            </span>
                            <button
                              onClick={() => handleDeletePeriod(p.id)}
                              className="text-rose-400 hover:text-rose-600 p-1 cursor-pointer transition-colors"
                              title="Remove Slot"
                            >
                              <Trash2 className="w-3.5 h-3.5" />
                            </button>
                          </div>
                        </div>

                        <h3 className={`text-base font-black mb-2 ${
                          isPrayer ? 'text-amber-950' : isLunch ? 'text-emerald-950' : 'text-indigo-950'
                        }`}>
                          {p.subject}
                        </h3>
                      </div>

                      <div className="pt-2 border-t border-gray-100 flex items-center justify-between text-xs text-gray-600">
                        <div className="flex items-center gap-1.5 font-bold">
                          <User className="w-3.5 h-3.5 text-indigo-600" />
                          <span>{p.teacher}</span>
                        </div>
                        <div className="flex items-center gap-1 font-semibold text-gray-500">
                          <Building className="w-3.5 h-3.5" />
                          <span>{p.room ? `Room ${p.room}` : (isPrayer ? 'Ground' : isLunch ? 'Cafeteria' : '101')}</span>
                        </div>
                      </div>
                    </div>
                  );
                })
              )}
            </div>

            {/* Add Period Form with Interactive Time Dialer */}
            <div className="mt-4 print:hidden">
              {isAdding ? (
                <form onSubmit={handleAddPeriod} className="p-5 bg-slate-900 text-white rounded-2xl border border-slate-700 space-y-4 shadow-lg">
                  <div className="flex items-center justify-between border-b border-slate-800 pb-3">
                    <h3 className="font-bold text-sm text-white flex items-center gap-2">
                      <Clock className="w-4 h-4 text-emerald-400" />
                      <span>Add Slot to {activeDay} (Class {selectedClass})</span>
                    </h3>
                    <button
                      type="button"
                      onClick={() => setIsAdding(false)}
                      className="p-1 text-slate-400 hover:text-white"
                    >
                      <X className="w-4 h-4" />
                    </button>
                  </div>

                  {/* Slot Type Selector */}
                  <div className="flex items-center gap-2">
                    <span className="text-xs font-bold text-slate-300">Slot Type:</span>
                    <button
                      type="button"
                      onClick={() => applyPreset('regular')}
                      className={`px-3 py-1.5 rounded-lg text-xs font-bold border transition-all cursor-pointer ${
                        periodType === 'regular'
                          ? 'bg-indigo-600 text-white border-indigo-500'
                          : 'bg-slate-800 text-slate-300 border-slate-700'
                      }`}
                    >
                      📘 Regular Subject
                    </button>
                    <button
                      type="button"
                      onClick={() => applyPreset('prayer')}
                      className={`px-3 py-1.5 rounded-lg text-xs font-bold border transition-all cursor-pointer ${
                        periodType === 'prayer'
                          ? 'bg-amber-600 text-white border-amber-500'
                          : 'bg-slate-800 text-slate-300 border-slate-700'
                      }`}
                    >
                      ☀️ Morning Prayer
                    </button>
                    <button
                      type="button"
                      onClick={() => applyPreset('lunch')}
                      className={`px-3 py-1.5 rounded-lg text-xs font-bold border transition-all cursor-pointer ${
                        periodType === 'lunch'
                          ? 'bg-emerald-600 text-white border-emerald-500'
                          : 'bg-slate-800 text-slate-300 border-slate-700'
                      }`}
                    >
                      🍱 Lunch Break
                    </button>
                  </div>

                  {/* ─── TIME DIALER COMPONENT ─── */}
                  <div className="bg-slate-800/80 p-4 rounded-xl border border-slate-700 space-y-3">
                    <div className="flex items-center justify-between">
                      <span className="text-xs font-bold text-emerald-400 uppercase tracking-wide flex items-center gap-1.5">
                        <Clock className="w-3.5 h-3.5" />
                        <span>Slot Timing Dialer:</span>
                      </span>
                      <span className="px-2.5 py-1 rounded-lg bg-emerald-500/20 text-emerald-300 font-mono text-xs font-bold border border-emerald-500/30">
                        {format12h(dialerStart)} — {format12h(dialerEnd)} ({calculateDuration(dialerStart, dialerEnd)} mins)
                      </span>
                    </div>

                    <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                      <div>
                        <label className="text-[11px] font-bold text-slate-300 block mb-1">
                          Slot Start Time:
                        </label>
                        <input
                          type="time"
                          value={dialerStart}
                          onChange={(e) => {
                            const newS = e.target.value;
                            setDialerStart(newS);
                            const dur = calculateDuration(dialerStart, dialerEnd);
                            setDialerEnd(addMinutesToTime(newS, dur));
                          }}
                          className="w-full px-3 py-2 bg-slate-900 rounded-lg border border-slate-600 text-white font-mono font-bold text-sm focus:outline-none focus:border-emerald-500"
                        />
                      </div>

                      <div>
                        <label className="text-[11px] font-bold text-slate-300 block mb-1">
                          Slot End Time:
                        </label>
                        <input
                          type="time"
                          value={dialerEnd}
                          onChange={(e) => setDialerEnd(e.target.value)}
                          className="w-full px-3 py-2 bg-slate-900 rounded-lg border border-slate-600 text-white font-mono font-bold text-sm focus:outline-none focus:border-emerald-500"
                        />
                      </div>
                    </div>

                    {/* Quick Duration Buttons */}
                    <div className="flex items-center gap-2 flex-wrap pt-1">
                      <span className="text-[10px] text-slate-400 font-semibold uppercase">Auto Duration:</span>
                      {[20, 30, 40, 45, 50, 60].map(mins => (
                        <button
                          key={mins}
                          type="button"
                          onClick={() => setDialerEnd(addMinutesToTime(dialerStart, mins))}
                          className={`px-2.5 py-1 rounded-md text-[11px] font-bold border transition-all cursor-pointer ${
                            calculateDuration(dialerStart, dialerEnd) === mins
                              ? 'bg-emerald-500 text-slate-950 border-emerald-400 font-black'
                              : 'bg-slate-900 text-slate-300 hover:bg-slate-700 border-slate-600'
                          }`}
                        >
                          +{mins}m
                        </button>
                      ))}
                    </div>
                  </div>

                  <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
                    <div>
                      <label className="text-[11px] font-bold text-slate-300 block mb-1">Subject / Activity Name *</label>
                      <input
                        type="text"
                        placeholder="e.g. Science / Morning Prayer"
                        required
                        value={newSubject}
                        onChange={(e) => setNewSubject(e.target.value)}
                        className="w-full px-3 py-2 bg-slate-900 rounded-lg border border-slate-700 text-white text-xs font-semibold focus:outline-none focus:border-emerald-500"
                      />
                    </div>
                    <div>
                      <label className="text-[11px] font-bold text-slate-300 block mb-1">Teacher / Faculty</label>
                      <input
                        type="text"
                        placeholder="e.g. Ramesh Sir / Duty Faculty"
                        value={newTeacher}
                        onChange={(e) => setNewTeacher(e.target.value)}
                        className="w-full px-3 py-2 bg-slate-900 rounded-lg border border-slate-700 text-white text-xs font-semibold focus:outline-none focus:border-emerald-500"
                      />
                    </div>
                    <div>
                      <label className="text-[11px] font-bold text-slate-300 block mb-1">Room / Ground (optional)</label>
                      <input
                        type="text"
                        placeholder="e.g. 101 / Assembly Ground"
                        value={newRoom}
                        onChange={(e) => setNewRoom(e.target.value)}
                        className="w-full px-3 py-2 bg-slate-900 rounded-lg border border-slate-700 text-white text-xs font-semibold focus:outline-none focus:border-emerald-500"
                      />
                    </div>
                  </div>

                  <div className="flex gap-2 pt-2">
                    <button
                      type="submit"
                      className="px-5 py-2.5 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white font-bold text-xs cursor-pointer shadow-md flex items-center gap-1.5 transition-all"
                    >
                      <CheckCircle2 className="w-4 h-4" />
                      <span>Save Slot</span>
                    </button>
                    <button
                      type="button"
                      onClick={() => setIsAdding(false)}
                      className="px-4 py-2.5 rounded-xl bg-slate-800 hover:bg-slate-700 border border-slate-700 text-xs font-bold text-slate-300 cursor-pointer"
                    >
                      Cancel
                    </button>
                  </div>
                </form>
              ) : (
                <div className="flex items-center gap-2">
                  <button
                    onClick={() => handleOpenAdd('regular')}
                    className="px-4 py-2.5 rounded-xl border border-dashed border-primary text-primary hover:bg-primary/5 font-bold text-xs flex items-center gap-1.5 cursor-pointer transition-all"
                  >
                    <Plus className="w-4 h-4" />
                    <span>Add Period to {activeDay}</span>
                  </button>
                </div>
              )}
            </div>

            {/* Printable Footer */}
            <div className="mt-8 pt-4 border-t border-gray-300 flex items-center justify-between text-xs font-bold text-gray-700">
              <div>Class Teacher Signature</div>
              <div className="text-right text-[#1E3A8A] font-black uppercase">
                Principal Sign & Official Stamp
              </div>
            </div>
          </div>
        </>
      )}

      {/* ══════════════════════════════════════════════════════════════════════
          MODE 2: MASTER ALL-CLASSES GRID (ON A SINGLE PAGE)
          "aur ek hi page m all classes ka time table bn jaye kiuki ek teacher ka sub tiime period toh all day hoga n toh aisa design kro"
          ══════════════════════════════════════════════════════════════════════ */}
      {viewMode === 'master' && (
        <div className="bg-white border-2 border-indigo-950/20 rounded-2xl p-6 shadow-sm text-black space-y-6">
          <div className="border-b-2 border-indigo-950 pb-4 flex flex-col lg:flex-row lg:items-center justify-between gap-4">
            <div>
              <div className="flex items-center gap-2">
                <span className="p-2 bg-indigo-100 rounded-xl text-indigo-700">
                  <LayoutGrid className="w-5 h-5" />
                </span>
                <h2 className="font-black text-lg text-indigo-950 uppercase tracking-tight">
                  Master School Timetable — All Classes Matrix
                </h2>
              </div>
              <p className="text-xs text-gray-600 mt-1">
                Full-school comprehensive timetable. Track where every teacher is stationed during every period all day long without schedule clashes.
              </p>
            </div>

            {/* Day Switcher Buttons for Master Grid */}
            <div className="flex items-center gap-1.5 overflow-x-auto pb-1">
              {days.map(day => (
                <button
                  key={day}
                  type="button"
                  onClick={() => setActiveDay(day)}
                  className={`px-3.5 py-1.5 rounded-xl text-xs font-bold transition-all cursor-pointer whitespace-nowrap ${
                    activeDay === day
                      ? 'bg-indigo-600 text-white shadow-sm'
                      : 'bg-gray-100 hover:bg-gray-200 text-gray-700'
                  }`}
                >
                  {day}
                </button>
              ))}
            </div>
          </div>

          {/* Conflict Alert Banner if double bookings exist on this day */}
          {Object.keys(masterDayClashes).length > 0 && (
            <div className="p-4 bg-rose-50 border-2 border-rose-300 rounded-xl text-rose-950 space-y-1">
              <div className="flex items-center gap-2 font-black text-sm text-rose-700">
                <ShieldAlert className="w-5 h-5 text-rose-600" />
                <span>TEACHER DOUBLE-BOOKING CLASHES DETECTED ON {activeDay.toUpperCase()}!</span>
              </div>
              <p className="text-xs text-rose-800">
                The following teachers have been scheduled for 2 classes at the exact same period:
              </p>
              <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 gap-2 pt-1">
                {Object.entries(masterDayClashes).map(([key, items]) => (
                  <div key={key} className="p-2 bg-white rounded-lg border border-rose-200 text-xs shadow-2xs">
                    <span className="font-black text-rose-700">{items[0].teacher}</span> is scheduled at{' '}
                    <strong className="text-gray-900">{items[0].time || `Period ${items[0].period}`}</strong> in:{' '}
                    <span className="font-bold text-rose-600">{items.map(i => `Class ${i.className}`).join(' & ')}</span>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* Quick Teacher Daily Journey Tracker Bar */}
          {masterTeacherHighlight !== 'all' && (
            <div className="p-3 bg-amber-50 border border-amber-300 rounded-xl flex items-center justify-between text-xs text-amber-900">
              <div className="flex items-center gap-2">
                <Sparkles className="w-4 h-4 text-amber-600" />
                <span>
                  Highlighting full-day schedule for <strong>{masterTeacherHighlight}</strong> across all classes on <strong>{activeDay}</strong>.
                </span>
              </div>
              <button
                onClick={() => setMasterTeacherHighlight('all')}
                className="font-bold text-amber-700 hover:underline cursor-pointer"
              >
                Clear Highlight
              </button>
            </div>
          )}

          {/* Master Grid Table Container */}
          <div className="overflow-x-auto border-2 border-indigo-900/20 rounded-xl shadow-xs">
            <table className="w-full text-left border-collapse text-xs">
              <thead>
                <tr className="bg-indigo-950 text-white font-black text-center uppercase tracking-wider">
                  <th className="p-3 border-r border-indigo-800 w-28 text-left bg-indigo-900 sticky left-0 z-10">
                    Class
                  </th>
                  <th className="p-3 border-r border-indigo-800 bg-amber-700 text-white min-w-[130px]">
                    ☀️ Morning Prayer
                    <div className="text-[10px] font-normal opacity-90 font-mono">08:30 - 09:00 AM</div>
                  </th>
                  <th className="p-3 border-r border-indigo-800 min-w-[130px]">
                    Period 1
                    <div className="text-[10px] font-normal opacity-80 font-mono">09:00 - 09:45 AM</div>
                  </th>
                  <th className="p-3 border-r border-indigo-800 min-w-[130px]">
                    Period 2
                    <div className="text-[10px] font-normal opacity-80 font-mono">09:45 - 10:30 AM</div>
                  </th>
                  <th className="p-3 border-r border-indigo-800 min-w-[130px]">
                    Period 3
                    <div className="text-[10px] font-normal opacity-80 font-mono">10:45 - 11:30 AM</div>
                  </th>
                  <th className="p-3 border-r border-indigo-800 min-w-[130px]">
                    Period 4
                    <div className="text-[10px] font-normal opacity-80 font-mono">11:30 - 12:15 PM</div>
                  </th>
                  <th className="p-3 border-r border-indigo-800 bg-emerald-700 text-white min-w-[130px]">
                    🍱 Lunch Break
                    <div className="text-[10px] font-normal opacity-90 font-mono">12:15 - 01:00 PM</div>
                  </th>
                  <th className="p-3 border-r border-indigo-800 min-w-[130px]">
                    Period 5
                    <div className="text-[10px] font-normal opacity-80 font-mono">01:00 - 01:45 PM</div>
                  </th>
                  <th className="p-3 min-w-[130px]">
                    Period 6
                    <div className="text-[10px] font-normal opacity-80 font-mono">01:45 - 02:30 PM</div>
                  </th>
                </tr>
              </thead>

              <tbody className="divide-y divide-gray-200 bg-white font-medium">
                {schoolClasses.map((cls, idx) => {
                  const clsDayList = (allClassesSchedule[cls]?.[activeDay] || []);
                  const prayerP = clsDayList.find(isPrayerPeriod);
                  const lunchP = clsDayList.find(isLunchPeriod);

                  return (
                    <tr key={cls} className={`hover:bg-indigo-50/40 transition-colors ${idx % 2 === 0 ? 'bg-white' : 'bg-gray-50/60'}`}>
                      {/* Class Label Sticky Column */}
                      <td className="p-3 font-black text-indigo-950 border-r border-gray-200 bg-white sticky left-0 z-10 shadow-xs">
                        <div className="flex items-center justify-between">
                          <span className="text-sm font-black">Class {cls}</span>
                          <button
                            type="button"
                            onClick={() => {
                              setSelectedClass(cls);
                              setViewMode('class');
                            }}
                            className="p-1 text-gray-400 hover:text-indigo-600 rounded"
                            title="Edit this class routine"
                          >
                            <BookOpen className="w-3.5 h-3.5" />
                          </button>
                        </div>
                      </td>

                      {/* Prayer Cell */}
                      <td className="p-2 border-r border-gray-200 bg-amber-50/40 text-center">
                        <div className="p-2 rounded-lg bg-amber-100/70 border border-amber-300">
                          <div className="font-black text-amber-950 text-xs">Morning Assembly</div>
                          <div className="text-[10px] text-amber-800 font-semibold">All Staff & Students</div>
                          <div className="text-[9px] text-amber-700 font-mono">{prayerP ? prayerP.time : '08:30 - 09:00'}</div>
                        </div>
                      </td>

                      {/* Periods 1 to 4 */}
                      {[1, 2, 3, 4].map(pNum => {
                        const matched = clsDayList.find(item => !isPrayerPeriod(item) && !isLunchPeriod(item) && item.period === pNum);
                        const t = matched ? (matched.teacher || '').trim() : '';
                        const slotKey = matched ? `p_${matched.period || matched.time}` : `p_${pNum}`;
                        const clashKey = `${t.toLowerCase()}__${slotKey}`;
                        const isClash = Boolean(t && masterDayClashes[clashKey]);
                        const isHighlighted = masterTeacherHighlight !== 'all' && t.toLowerCase() === masterTeacherHighlight.toLowerCase();

                        return (
                          <td
                            key={pNum}
                            className={`p-2 border-r border-gray-200 text-center transition-all ${
                              isClash
                                ? 'bg-rose-100/80 border-rose-300'
                                : isHighlighted
                                ? 'bg-amber-100/80 border-amber-400 ring-2 ring-amber-400 ring-inset'
                                : ''
                            }`}
                          >
                            {matched ? (
                              <div className="space-y-0.5">
                                <div className="font-black text-gray-900 text-xs truncate" title={matched.subject}>
                                  {matched.subject}
                                </div>
                                <div className={`inline-block px-2 py-0.5 rounded text-[11px] font-bold ${
                                  isClash
                                    ? 'bg-rose-600 text-white animate-pulse'
                                    : isHighlighted
                                    ? 'bg-amber-600 text-white'
                                    : 'bg-indigo-50 text-indigo-900 border border-indigo-200'
                                }`}>
                                  {matched.teacher}
                                </div>
                                {isClash && (
                                  <div className="text-[9px] font-black text-rose-700">⚠️ CLASH!</div>
                                )}
                              </div>
                            ) : (
                              <span className="text-gray-300 font-bold">-</span>
                            )}
                          </td>
                        );
                      })}

                      {/* Lunch Cell */}
                      <td className="p-2 border-r border-gray-200 bg-emerald-50/40 text-center">
                        <div className="p-2 rounded-lg bg-emerald-100/70 border border-emerald-300">
                          <div className="font-black text-emerald-950 text-xs">Lunch Break</div>
                          <div className="text-[10px] text-emerald-800 font-semibold">Campus Recess</div>
                          <div className="text-[9px] text-emerald-700 font-mono">{lunchP ? lunchP.time : '12:15 - 01:00'}</div>
                        </div>
                      </td>

                      {/* Periods 5 and 6 */}
                      {[5, 6].map(pNum => {
                        const matched = clsDayList.find(item => !isPrayerPeriod(item) && !isLunchPeriod(item) && item.period === pNum);
                        const t = matched ? (matched.teacher || '').trim() : '';
                        const slotKey = matched ? `p_${matched.period || matched.time}` : `p_${pNum}`;
                        const clashKey = `${t.toLowerCase()}__${slotKey}`;
                        const isClash = Boolean(t && masterDayClashes[clashKey]);
                        const isHighlighted = masterTeacherHighlight !== 'all' && t.toLowerCase() === masterTeacherHighlight.toLowerCase();

                        return (
                          <td
                            key={pNum}
                            className={`p-2 border-r border-gray-200 text-center transition-all ${
                              isClash
                                ? 'bg-rose-100/80 border-rose-300'
                                : isHighlighted
                                ? 'bg-amber-100/80 border-amber-400 ring-2 ring-amber-400 ring-inset'
                                : ''
                            }`}
                          >
                            {matched ? (
                              <div className="space-y-0.5">
                                <div className="font-black text-gray-900 text-xs truncate" title={matched.subject}>
                                  {matched.subject}
                                </div>
                                <div className={`inline-block px-2 py-0.5 rounded text-[11px] font-bold ${
                                  isClash
                                    ? 'bg-rose-600 text-white animate-pulse'
                                    : isHighlighted
                                    ? 'bg-amber-600 text-white'
                                    : 'bg-indigo-50 text-indigo-900 border border-indigo-200'
                                }`}>
                                  {matched.teacher}
                                </div>
                                {isClash && (
                                  <div className="text-[9px] font-black text-rose-700">⚠️ CLASH!</div>
                                )}
                              </div>
                            ) : (
                              <span className="text-gray-300 font-bold">-</span>
                            )}
                          </td>
                        );
                      })}
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>

          {/* Master View Action Bar */}
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 pt-2 border-t border-gray-200">
            <div className="text-xs text-gray-500 font-medium">
              Showing <strong>{schoolClasses.length} Classes</strong> across <strong>{activeDay}</strong> with full teacher assignments.
            </div>
            <div className="flex items-center gap-3">
              <button
                type="button"
                onClick={handleDownloadMasterPdf}
                disabled={isExportingMasterPdf}
                className="px-5 py-2.5 rounded-xl bg-indigo-600 hover:bg-indigo-700 text-white font-bold text-xs shadow-md transition-all flex items-center gap-2 cursor-pointer active:scale-95 disabled:opacity-50"
              >
                <Download className="w-4 h-4" />
                <span>{isExportingMasterPdf ? 'Exporting PDF...' : 'Download Master Timetable (PDF)'}</span>
              </button>
            </div>
          </div>
        </div>
      )}

      {/* ══════════════════════════════════════════════════════════════════════
          MODE 3: TEACHER SCHEDULE INSPECTOR
          ══════════════════════════════════════════════════════════════════════ */}
      {viewMode === 'teacher' && (
        <div className="bg-white border-2 border-indigo-950/20 rounded-2xl p-6 shadow-sm text-black space-y-6">
          <div className="border-b-2 border-indigo-950 pb-4 flex flex-col sm:flex-row sm:items-center justify-between gap-3">
            <div>
              <h2 className="font-black text-lg text-indigo-950 flex items-center gap-2">
                <Users className="w-5 h-5 text-indigo-600" />
                <span>Teacher Routine Inspector & Schedule Analyzer</span>
              </h2>
              <p className="text-xs text-gray-600 mt-0.5">
                Check exact periods, classes, timings and workload for any faculty across the school.
              </p>
            </div>

            <div className="flex items-center gap-2">
              <span className="text-xs font-bold text-gray-700">Select Teacher:</span>
              <select
                value={selectedTeacher}
                onChange={(e) => setSelectedTeacher(e.target.value)}
                className="px-3 py-1.5 rounded-xl bg-surface2 border border-border text-xs font-bold text-primary focus:outline-none cursor-pointer"
              >
                <option value="all">-- All Teachers Overview --</option>
                {teacherScheduleData.teacherList.map(t => (
                  <option key={t} value={t}>{t}</option>
                ))}
              </select>
            </div>
          </div>

          {/* Time Clash / Conflict Warning Banner */}
          {teacherConflicts.length > 0 && (
            <div className="p-4 bg-rose-50 border-2 border-rose-300 rounded-xl text-rose-900 space-y-1">
              <div className="flex items-center gap-2 font-black text-sm text-rose-700">
                <AlertTriangle className="w-4 h-4 text-rose-600" />
                <span>SCHEDULE CONFLICT DETECTED FOR {selectedTeacher.toUpperCase()}!</span>
              </div>
              <p className="text-xs text-rose-800">
                This teacher is double-booked across different classes at the same time:
              </p>
              <ul className="text-xs list-disc list-inside space-y-0.5 font-semibold text-rose-900">
                {teacherConflicts.map((c, idx) => (
                  <li key={idx}>
                    {c.day} at {c.time} in {c.classes}
                  </li>
                ))}
              </ul>
            </div>
          )}

          {selectedTeacher === 'all' ? (
            /* All Teachers Workload Summary Table */
            <div className="space-y-4">
              <h3 className="text-sm font-bold text-gray-800">Faculty Workload Summary:</h3>
              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                {teacherScheduleData.teacherList.map(tName => {
                  const periods = teacherScheduleData.teacherMap[tName] || [];
                  const uniqueCls = Array.from(new Set(periods.map(p => p.className)));
                  return (
                    <div
                      key={tName}
                      onClick={() => setSelectedTeacher(tName)}
                      className="p-4 rounded-xl border border-gray-200 hover:border-indigo-400 bg-gray-50/50 hover:bg-indigo-50/30 transition-all cursor-pointer shadow-2xs group"
                    >
                      <div className="flex items-center justify-between mb-2">
                        <h4 className="font-black text-sm text-indigo-950 group-hover:text-indigo-600 flex items-center gap-1.5">
                          <User className="w-4 h-4 text-indigo-500" />
                          <span>{tName}</span>
                        </h4>
                        <span className="px-2 py-0.5 rounded-md bg-indigo-100 text-indigo-800 text-[11px] font-black">
                          {periods.length} Periods/wk
                        </span>
                      </div>
                      <div className="text-xs text-gray-600 space-y-1">
                        <div>Classes: <strong className="text-gray-900">{uniqueCls.join(', ') || 'None'}</strong></div>
                      </div>
                    </div>
                  );
                })}
              </div>
            </div>
          ) : (
            /* Selected Teacher Detailed Weekly Breakdown */
            <div className="space-y-5">
              <div className="flex items-center justify-between bg-indigo-50 p-4 rounded-xl border border-indigo-200">
                <div>
                  <h3 className="font-black text-base text-indigo-950 flex items-center gap-2">
                    <span>{selectedTeacher}</span>
                    <span className="text-xs font-bold text-indigo-700 bg-white px-2.5 py-0.5 rounded-full border border-indigo-200">
                      {(teacherScheduleData.teacherMap[selectedTeacher] || []).length} Total Weekly Periods
                    </span>
                  </h3>
                  <p className="text-xs text-indigo-700 mt-0.5">
                    Classes Taught: {Array.from(new Set((teacherScheduleData.teacherMap[selectedTeacher] || []).map(p => `Class ${p.className}`))).join(', ')}
                  </p>
                </div>
                <button
                  type="button"
                  onClick={() => setSelectedTeacher('all')}
                  className="text-xs font-bold text-indigo-600 hover:underline cursor-pointer"
                >
                  ← Back to All Teachers
                </button>
              </div>

              {/* Day-by-day periods for selected teacher */}
              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                {days.map(day => {
                  const allTeacherPeriods = (teacherScheduleData.teacherMap[selectedTeacher] || []);
                  const dayPeriods = allTeacherPeriods
                    .filter(p => p.day === day)
                    .sort((a, b) => a.period - b.period);

                  return (
                    <div key={day} className="rounded-xl border border-gray-200 overflow-hidden bg-white shadow-2xs">
                      <div className="px-4 py-2 bg-indigo-950 text-white flex items-center justify-between text-xs font-bold">
                        <span>{day}</span>
                        <span className="bg-white/20 px-2 py-0.5 rounded text-[10px]">
                          {dayPeriods.length} Classes
                        </span>
                      </div>

                      <div className="p-3 space-y-2 min-h-[120px]">
                        {dayPeriods.length === 0 ? (
                          <div className="text-center py-6 text-xs text-gray-400 font-medium">
                            Free Day (No periods scheduled)
                          </div>
                        ) : (
                          dayPeriods.map((p, idx) => (
                            <div key={idx} className="p-2.5 rounded-lg bg-gray-50 border border-gray-200 text-xs space-y-1">
                              <div className="flex items-center justify-between">
                                <span className="font-black text-indigo-900 bg-indigo-100 px-2 py-0.5 rounded text-[11px]">
                                  Period {p.period} · Class {p.className}
                                </span>
                                <span className="font-mono text-[10px] text-gray-600 font-bold">
                                  {p.time}
                                </span>
                              </div>
                              <div className="font-bold text-gray-900 text-sm">
                                {p.subject}
                              </div>
                              <div className="text-[11px] text-gray-500">
                                Room {p.room || '101'}
                              </div>
                            </div>
                          ))
                        )}
                      </div>
                    </div>
                  );
                })}
              </div>
            </div>
          )}
        </div>
      )}

      {/* ══════════════════════════════════════════════════════════════════════
          BULK COPY TO OTHER CLASSES MODAL
          ══════════════════════════════════════════════════════════════════════ */}
      {isCopyModalOpen && (
        <div className="fixed inset-0 z-50 bg-black/70 backdrop-blur-xs flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl max-w-lg w-full p-6 shadow-2xl border border-gray-200 space-y-5 animate-in fade-in zoom-in-95 text-black">
            <div className="flex items-center justify-between border-b pb-3 border-gray-200">
              <div className="flex items-center gap-2 text-indigo-950">
                <Copy className="w-5 h-5 text-indigo-600" />
                <h3 className="font-black text-base">Replicate Timetable to Other Classes</h3>
              </div>
              <button
                type="button"
                onClick={() => setIsCopyModalOpen(false)}
                className="p-1 rounded-lg text-gray-400 hover:text-gray-700"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <div className="text-xs text-gray-600">
              Replicate routine template from <strong>Class {selectedClass}</strong> to other classes in one click.
            </div>

            {/* Scope selection */}
            <div className="p-3 bg-gray-50 rounded-xl border border-gray-200 space-y-2">
              <span className="text-xs font-bold text-gray-800 block">Copy Scope:</span>
              <div className="flex items-center gap-4 text-xs font-semibold">
                <label className="flex items-center gap-2 cursor-pointer">
                  <input
                    type="radio"
                    name="copyScope"
                    checked={copyScope === 'all_days'}
                    onChange={() => setCopyScope('all_days')}
                    className="accent-indigo-600"
                  />
                  <span>Entire Week (Monday to Saturday)</span>
                </label>
                <label className="flex items-center gap-2 cursor-pointer">
                  <input
                    type="radio"
                    name="copyScope"
                    checked={copyScope === 'current_day'}
                    onChange={() => setCopyScope('current_day')}
                    className="accent-indigo-600"
                  />
                  <span>{activeDay} Only</span>
                </label>
              </div>
            </div>

            {/* Target Classes Selection */}
            <div className="space-y-2">
              <div className="flex items-center justify-between">
                <span className="text-xs font-bold text-gray-800">Select Target Classes:</span>
                <button
                  type="button"
                  onClick={handleToggleAllClasses}
                  className="text-xs font-bold text-indigo-600 hover:underline cursor-pointer"
                >
                  {targetClasses.length === schoolClasses.filter(c => c !== selectedClass).length ? 'Deselect All' : 'Select All'}
                </button>
              </div>

              <div className="grid grid-cols-3 sm:grid-cols-4 gap-2 max-h-48 overflow-y-auto p-2 border border-gray-200 rounded-xl bg-gray-50">
                {schoolClasses.filter(c => c !== selectedClass).map(cls => {
                  const isChecked = targetClasses.includes(cls);
                  return (
                    <button
                      key={cls}
                      type="button"
                      onClick={() => handleToggleTargetClass(cls)}
                      className={`p-2 rounded-lg text-xs font-bold flex items-center justify-between border transition-all cursor-pointer ${
                        isChecked
                          ? 'bg-indigo-600 text-white border-indigo-600 shadow-xs'
                          : 'bg-white text-gray-700 border-gray-300 hover:border-indigo-400'
                      }`}
                    >
                      <span>Class {cls}</span>
                      {isChecked ? <Check className="w-3.5 h-3.5" /> : null}
                    </button>
                  );
                })}
              </div>
            </div>

            <div className="flex items-center justify-end gap-2 pt-2 border-t border-gray-200">
              <button
                type="button"
                onClick={() => setIsCopyModalOpen(false)}
                className="px-4 py-2 rounded-xl bg-gray-100 hover:bg-gray-200 text-gray-700 text-xs font-bold cursor-pointer"
              >
                Cancel
              </button>
              <button
                type="button"
                onClick={handleApplyBulkCopy}
                disabled={targetClasses.length === 0}
                className="px-5 py-2.5 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white text-xs font-bold flex items-center gap-2 cursor-pointer shadow-md disabled:opacity-50"
              >
                <CheckCircle2 className="w-4 h-4" />
                <span>Apply to {targetClasses.length} Classes</span>
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
