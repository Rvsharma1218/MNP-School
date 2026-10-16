'use client';

import React, { useState, useMemo, useEffect } from 'react';
import { useSchoolStore } from '../lib/store';
import {
  Printer, Download, Plus, Trash2, Calendar,
  GraduationCap, FileText, CheckCircle2, User, Search, Share2, Shield, QrCode,
  ChevronLeft, ChevronRight
} from 'lucide-react';
import { jsPDF } from 'jspdf';
import { getImageDataUrl } from '../lib/exportUtils';


const STANDARD_ADMIT_SUBJECTS = [
  'Mathematics',
  'Science',
  'Social Studies',
  'English',
  'Hindi',
  'Computer',
  'General Knowledge',
  'Sanskrit',
  'Drawing / Art',
  'Physics',
  'Chemistry',
  'Biology',
  'Other'
];

export default function AdmitCardView() {
  const { students, settings, showToast } = useSchoolStore();

  const [selectedClass, setSelectedClass] = useState('all');
  const [examTitle, setExamTitle] = useState('ANNUAL EXAMINATION 2026');
  const [searchQuery, setSearchQuery] = useState('');
  const [isExportingPdf, setIsExportingPdf] = useState(false);
  const [selectedStudentIndex, setSelectedStudentIndex] = useState(0);
  const [printTargetStudentId, setPrintTargetStudentId] = useState('all');

  // Class-wise Editable Timetable
  const defaultTimetable = [
    { day: '15/03/2026', subject: 'Mathematics', timing: '09:30 AM - 12:30 PM' },
    { day: '17/03/2026', subject: 'Science', timing: '09:30 AM - 12:30 PM' },
    { day: '19/03/2026', subject: 'Social Studies', timing: '09:30 AM - 12:30 PM' },
    { day: '21/03/2026', subject: 'English', timing: '09:30 AM - 12:30 PM' },
    { day: '23/03/2026', subject: 'Hindi', timing: '09:30 AM - 12:30 PM' },
    { day: '25/03/2026', subject: 'Computer', timing: '09:30 AM - 12:30 PM' },
  ];

  const [timetable, setTimetable] = useState(defaultTimetable);
  const [newDay, setNewDay] = useState('27/03/2026');
  const [newSubject, setNewSubject] = useState('Mathematics');
  const [customSubjectName, setCustomSubjectName] = useState('');
  const [newTiming, setNewTiming] = useState('09:30 AM - 12:30 PM');
  const [isAddingSubject, setIsAddingSubject] = useState(false);

  // Load schedule for selected class from localStorage
  useEffect(() => {
    if (typeof window !== 'undefined') {
      const classKey = selectedClass === 'all' ? 'school_admit_schedule_default' : `school_admit_schedule_${selectedClass}`;
      const saved = localStorage.getItem(classKey);
      if (saved) {
        try {
          const parsed = JSON.parse(saved);
          if (Array.isArray(parsed) && parsed.length > 0) {
            setTimetable(parsed);
            return;
          }
        } catch (e) {}
      }
      setTimetable(defaultTimetable);
    }
  }, [selectedClass]);

  const handleSaveClassSchedule = () => {
    if (typeof window !== 'undefined') {
      const classKey = selectedClass === 'all' ? 'school_admit_schedule_default' : `school_admit_schedule_${selectedClass}`;
      localStorage.setItem(classKey, JSON.stringify(timetable));
      showToast(`Exam Schedule for ${selectedClass === 'all' ? 'All Classes' : 'Class ' + selectedClass} saved successfully!`, 'success');
    }
  };
  // Filter students
  const filteredStudents = useMemo(() => {
    return students.filter(s => {
      const matchClass = selectedClass === 'all' || s.className === selectedClass;
      const q = searchQuery.trim().toLowerCase();
      const matchSearch = !q ||
        (s.name && s.name.toLowerCase().includes(q)) ||
        (s.rollNumber && String(s.rollNumber).toLowerCase().includes(q)) ||
        (s.aadhaarNumber && String(s.aadhaarNumber).toLowerCase().includes(q)) ||
        (s.admissionNumber && String(s.admissionNumber).toLowerCase().includes(q));
      return matchClass && matchSearch;
    });
  }, [students, selectedClass, searchQuery]);

  const handleAddSubject = (e) => {
    e.preventDefault();
    const finalSubject = newSubject === 'Other' ? customSubjectName.trim() : newSubject.trim();
    if (!finalSubject) {
      showToast('Please enter or select a subject name', 'error');
      return;
    }
    if (!newDay.trim()) {
      showToast('Please enter an exam date', 'error');
      return;
    }
    const updated = [...timetable, { day: newDay.trim(), subject: finalSubject, timing: newTiming.trim() }];
    setTimetable(updated);
    if (typeof window !== 'undefined') {
      const classKey = selectedClass === 'all' ? 'school_admit_schedule_default' : `school_admit_schedule_${selectedClass}`;
      localStorage.setItem(classKey, JSON.stringify(updated));
    }
    setCustomSubjectName('');
    setIsAddingSubject(false);
    showToast('Subject added to exam schedule', 'success');
  };
  const handleRemoveSubject = (index) => {
    setTimetable(timetable.filter((_, i) => i !== index));
  };

  // Browser Print All with multi-page support
  const handlePrintAll = () => {
    setPrintTargetStudentId('all');
    setTimeout(() => {
      window.print();
    }, 150);
  };

  // Browser Print Single Student
  const handlePrintSingle = (student) => {
    if (!student) return;
    setPrintTargetStudentId(student.id);
    setTimeout(() => {
      window.print();
    }, 150);
  };

  // Direct jsPDF Multi-Page PDF Download for All or Single Student (guaranteed photo, sign, QR)
  const handleDownloadPdf = async (singleStudent = null) => {
    const targetList = singleStudent ? [singleStudent] : filteredStudents;
    if (targetList.length === 0) {
      showToast('No students to export', 'error');
      return;
    }

    setIsExportingPdf(true);
    showToast(`Generating official Admit Cards PDF (${targetList.length} cards)...`, 'info');

    try {
      const doc = new jsPDF({
        orientation: 'portrait',
        unit: 'mm',
        format: 'a4',
      });

      const schoolName = (settings.instituteName || settings.schoolName || 'MISSION NAVODAYA').toUpperCase();
      const session = settings.currentSession || settings.academicYear || '2026-27';
      const address = settings.address || 'Mora Mairi, BagwaanPur hat ,Siwan,Bihar 841507';

      // Preload School Logo and Principal Signature
      const logoData = await getImageDataUrl(settings.logoUrl || settings.logoPath || settings.logo);
      const sigData = await getImageDataUrl(settings.principalSignature || settings.signatureUrl || settings.signature);
        const stampData = await getImageDataUrl(settings.schoolStamp || settings.stampUrl || settings.sealUrl);

      for (let index = 0; index < targetList.length; index++) {
        const s = targetList[index];
        if (index > 0) doc.addPage();

        const W = 210;
        const M = 10;
        const cardW = W - 2 * M;
        const cardH = 277;

        // Outer rounded blue border (Matching Image 1)
        doc.setDrawColor(30, 58, 138); // #1E3A8A
        doc.setLineWidth(1.2);
        doc.roundedRect(M, M, cardW, cardH, 4, 4);

        // Header Top Banner (Solid Blue Background)
        const bannerH = 26;
        doc.setFillColor(30, 58, 138);
        doc.roundedRect(M + 1, M + 1, cardW - 2, bannerH, 3, 3, 'F');

        // Logo inside banner
        if (logoData) {
          try {
            doc.setFillColor(255, 255, 255);
            doc.roundedRect(M + 4, M + 4, 18, 18, 2, 2, 'F');
            doc.addImage(logoData, 'PNG', M + 5, M + 5, 16, 16);
          } catch (e) { }
        }

        // Header School Name & Address
        const headerTextX = logoData ? M + 26 : M + 8;
        doc.setTextColor(255, 255, 255);
        doc.setFont('helvetica', 'bold');
        doc.setFontSize(14);
        doc.text(schoolName, headerTextX, M + 12);

        doc.setTextColor(255, 255, 255);
        doc.setFont('helvetica', 'normal');
        doc.setFontSize(8);
        doc.text(address, headerTextX, M + 18);

        // Right side of banner: Session & ADMIT CARD
        doc.setTextColor(255, 215, 0); // Gold
        doc.setFont('helvetica', 'bold');
        doc.setFontSize(8.5);
        doc.text(`SESSION: ${session}`, M + cardW - 6, M + 11, { align: 'right' });

        doc.setTextColor(255, 255, 255);
        doc.setFontSize(11);
        doc.text('ADMIT CARD', M + cardW - 6, M + 18, { align: 'right' });

        // Centered Exam Title Pill Badge (Matching Image 1)
        const pillTop = M + bannerH + 4;
        const pillW = 86;
        const pillH = 9;
        const pillX = (W - pillW) / 2;

        doc.setDrawColor(30, 58, 138);
        doc.setLineWidth(0.8);
        doc.setFillColor(255, 255, 255);
        doc.roundedRect(pillX, pillTop, pillW, pillH, 2, 2, 'FD');

        doc.setTextColor(30, 58, 138);
        doc.setFont('helvetica', 'bold');
        doc.setFontSize(11);
        doc.text(examTitle.toUpperCase(), W / 2, pillTop + 6.5, { align: 'center' });

        // Middle Info Section: Photo (Left), Student Details (Middle), QR Code (Right)
        const infoTop = pillTop + pillH + 6;
        const photoW = 34;
        const photoH = 42;
        const photoX = M + 6;
        const photoY = infoTop;

        // Student Photo
        const photoData = await getImageDataUrl(s.photoUrl || s.photoPath);
        if (photoData) {
          try {
            doc.addImage(photoData, 'JPEG', photoX, photoY, photoW, photoH);
            doc.setDrawColor(180, 180, 180);
            doc.rect(photoX, photoY, photoW, photoH);
          } catch (e) {
            drawPhotoBox(doc, photoX, photoY, photoW, photoH);
          }
        } else {
          drawPhotoBox(doc, photoX, photoY, photoW, photoH);
        }

        // Student Details in large, clear, bold font
        const detailX = photoX + photoW + 8;
        const aadhaar = s.aadhaarNumber || s.aadharNumber || s.aadhaar || 'NOT-LINKED';
        const dobStr = s.dob ? (typeof s.dob === 'string' ? s.dob.slice(0, 10) : '01/01/2010') : '01/01/2010';
        const genderStr = s.gender || 'Male';

        const rows = [
          ['STUDENT NAME:', (s.name || '').toUpperCase()],
          ['ROLL NO / ADM NO:', `${s.rollNumber || s.id || 'N/A'}  /  ${s.admissionNumber || s.id || 'N/A'}`],
          ['CLASS & SECTION:', `Class ${s.className || ''} - ${s.section || 'A'}`],
          ['FATHER\'S NAME:', (s.fatherName || '-').toUpperCase()],
          ['DOB / GENDER:', `${dobStr}  /  ${genderStr}`],
          ['AADHAAR NUMBER:', aadhaar]
        ];

        let curY = infoTop + 6;
        doc.setFontSize(9.5);
        rows.forEach(([label, val], rIdx) => {
          doc.setTextColor(60, 60, 60);
          doc.setFont('helvetica', 'bold');
          doc.text(label, detailX, curY);

          if (rIdx === 5) { // Aadhaar in blue font
            doc.setTextColor(37, 99, 235);
          } else {
            doc.setTextColor(15, 23, 42);
          }
          doc.setFont('helvetica', rIdx === 0 ? 'bold' : 'normal');
          doc.text(val, detailX + 44, curY);

          curY += 6.8;
        });

        // QR Code Box on Right
        const qrSize = 34;
        const qrX = M + cardW - qrSize - 6;
        const qrY = infoTop + 2;
        const qrDataUrl = await getImageDataUrl(`https://api.qrserver.com/v1/create-qr-code/?size=120x120&data=ADMIT:${encodeURIComponent(s.name)}|Roll:${s.rollNumber || s.id}|Class:${s.className}|Aadhaar:${aadhaar}`);
        if (qrDataUrl) {
          try {
            doc.addImage(qrDataUrl, 'PNG', qrX, qrY, qrSize, qrSize);
            doc.setDrawColor(200, 200, 200);
            doc.rect(qrX - 1, qrY - 1, qrSize + 2, qrSize + 2);
          } catch (e) { }
        }

        // Section Title: EXAMINATION SCHEDULE & TIME TABLE (Matching Image 1)
        const tableTitleY = infoTop + photoH + 10;
        doc.setTextColor(30, 58, 138);
        doc.setFont('helvetica', 'bold');
        doc.setFontSize(10.5);
        doc.text('EXAMINATION SCHEDULE & TIME TABLE', M + 6, tableTitleY);

        // Schedule Table
        const tableTop = tableTitleY + 3;
        const colW = [26, 48, 54, cardW - 12 - 26 - 48 - 54]; // DATE | SUBJECT | TIMING | INVIGILATOR SIGN

        // Table Header
        doc.setFillColor(243, 244, 246);
        doc.rect(M + 6, tableTop, cardW - 12, 7.5, 'F');
        doc.setDrawColor(209, 213, 219);
        doc.rect(M + 6, tableTop, cardW - 12, 7.5);

        doc.setTextColor(17, 24, 39);
        doc.setFont('helvetica', 'bold');
        doc.setFontSize(8.5);
        doc.text('DATE', M + 9, tableTop + 5);
        doc.text('SUBJECT', M + 6 + colW[0] + 3, tableTop + 5);
        doc.text('TIMING', M + 6 + colW[0] + colW[1] + 3, tableTop + 5);
        doc.text('INVIGILATOR SIGN', M + 6 + colW[0] + colW[1] + colW[2] + 8, tableTop + 5);

        // Table Rows
        let rowY = tableTop + 7.5;
        timetable.forEach((t, i) => {
          doc.setFillColor(i % 2 === 0 ? 255 : 249, i % 2 === 0 ? 255 : 250, i % 2 === 0 ? 255 : 251);
          doc.rect(M + 6, rowY, cardW - 12, 7, 'F');
          doc.setDrawColor(229, 231, 235);
          doc.rect(M + 6, rowY, cardW - 12, 7);

          doc.setTextColor(55, 65, 81);
          doc.setFont('helvetica', 'normal');
          doc.setFontSize(8.5);
          doc.text(t.day || `Day ${i + 1}`, M + 9, rowY + 5);

          doc.setFont('helvetica', 'bold');
          doc.setTextColor(17, 24, 39);
          doc.text(t.subject || '', M + 6 + colW[0] + 3, rowY + 5);

          doc.setFont('helvetica', 'normal');
          doc.setTextColor(55, 65, 81);
          doc.text(t.timing || '09:30 AM - 12:30 PM', M + 6 + colW[0] + colW[1] + 3, rowY + 5);

          rowY += 7;
        });

        // Instructions for Candidates (Matching Image 1)
        const instY = rowY + 9;
        doc.setTextColor(17, 24, 39);
        doc.setFont('helvetica', 'bold');
        doc.setFontSize(8.5);
        doc.text('INSTRUCTIONS FOR CANDIDATES:', M + 6, instY);

        doc.setFont('helvetica', 'normal');
        doc.setFontSize(7.5);
        doc.setTextColor(75, 85, 99);
        doc.text('1. Candidate must bring this Admit Card to the Examination Centre on every exam day.', M + 6, instY + 5);
        doc.text('2. Entry to the examination hall is permitted up to 15 minutes prior to commencement.', M + 6, instY + 9.5);
        doc.text('3. Electronic devices, mobile phones, and calculators are strictly prohibited.', M + 6, instY + 14);

        // Bottom Signatures Section (Matching Image 1)
        const sigLineY = cardH - 14;

        // Left: Candidate Signature
        doc.setDrawColor(156, 163, 175);
        doc.setLineWidth(0.8);
        doc.line(M + 10, sigLineY, M + 65, sigLineY);
        doc.setTextColor(55, 65, 81);
        doc.setFont('helvetica', 'bold');
        doc.setFontSize(8.5);
        doc.text('Candidate Signature', M + 37, sigLineY + 5, { align: 'center' });

        // Right: Principal / Controller of Exam with Guaranteed Signature Image
        const rightSigX = M + cardW - 70;
        if (stampData) {
            try {
              // Stamp / Mohar placed near Principal Signature
              doc.addImage(stampData, 'PNG', rightSigX - 18, sigLineY - 21, 20, 20);
            } catch (e) { }
          }
          if (sigData) {
          try {
            // Principal Signature (+30% larger, prominent hand-signed look)
          doc.addImage(sigData, 'PNG', rightSigX + 2, sigLineY - 20, 50, 18);
          } catch (e) { }
        }

        doc.setDrawColor(30, 58, 138);
        doc.setLineWidth(1.0);
        doc.line(rightSigX, sigLineY, rightSigX + 55, sigLineY);

        doc.setTextColor(30, 58, 138);
        doc.setFont('helvetica', 'bold');
        doc.setFontSize(8.5);
        doc.text('Principal / Controller of Exam', rightSigX + 27, sigLineY + 5, { align: 'center' });
      }

      const filename = singleStudent
        ? `Admit_Card_${(singleStudent.name || 'Student').replace(/\s+/g, '_')}.pdf`
        : `Class_${selectedClass}_Admit_Cards.pdf`;

      doc.save(filename);
      showToast(`Admit Cards PDF exported successfully! (${targetList.length} cards)`, 'success');
    } catch (err) {
      console.error('PDF error:', err);
      showToast('Error generating Admit Card PDF', 'error');
    } finally {
      setIsExportingPdf(false);
    }
  };

  const drawPhotoBox = (doc, x, y, w, h) => {
    doc.setDrawColor(180, 180, 180);
    doc.setFillColor(255, 255, 255);
    doc.rect(x, y, w, h, 'FD');
    doc.setFontSize(7.5);
    doc.setTextColor(140, 140, 140);
    doc.setFont('helvetica', 'bold');
    doc.text('AFFIX', x + w / 2, y + h / 2 - 2, { align: 'center' });
    doc.text('PHOTO HERE', x + w / 2, y + h / 2 + 4, { align: 'center' });
  };

  const handleShare = async () => {
    if (navigator.share) {
      try {
        await navigator.share({
          title: `Student Admit Cards - ${settings.instituteName || 'School'}`,
          text: `Official Student Admit Cards for ${examTitle}. Total students: ${filteredStudents.length}.`,
          url: window.location.href,
        });
      } catch (err) { }
    } else {
      navigator.clipboard.writeText(window.location.href);
      showToast('Page link copied to clipboard for sharing!', 'success');
    }
  };

  const schoolClasses = settings.schoolClasses && settings.schoolClasses.length > 0
    ? settings.schoolClasses
    : ['Nursery', 'LKG', 'UKG', '1st', '2nd', '3rd', '4th', '5th', '6th', '7th', '8th', '9th', '10th', '11th', '12th'];

  return (
    <div className="space-y-6 pb-12 animate-in fade-in duration-200">
      {/* Top Controls (Hidden on Print) */}
      <div className="print:hidden flex flex-col md:flex-row md:items-center justify-between gap-4 bg-white p-5 rounded-2xl border border-border shadow-xs">
        <div>
          <h1 className="text-xl font-black text-text flex items-center gap-2">
            <FileText className="w-6 h-6 text-primary" />
            Admit Card & Hall Ticket Studio
          </h1>
          <p className="text-xs text-text-secondary mt-1">
            Official Admit Cards with Photo, Signature, QR Code verification, and full multi-page PDF export.
          </p>
        </div>
        <div className="flex flex-wrap items-center gap-3">
          <button
            onClick={handleShare}
            className="px-4 py-2.5 rounded-xl bg-surface2 hover:bg-surface2/80 text-text font-bold text-xs border border-border transition-all flex items-center gap-2 cursor-pointer active:scale-95"
          >
            <Share2 className="w-4 h-4 text-primary" />
            <span>Share</span>
          </button>
          <button
            onClick={() => handleDownloadPdf()}
            disabled={filteredStudents.length === 0 || isExportingPdf}
            className="px-5 py-2.5 rounded-xl bg-emerald-600 hover:bg-emerald-700 text-white font-bold text-xs shadow-md transition-all flex items-center gap-2 cursor-pointer disabled:opacity-50 active:scale-95"
          >
            <Download className="w-4 h-4" />
            <span>{isExportingPdf ? 'Exporting...' : `Save All as PDF (${filteredStudents.length})`}</span>
          </button>
          <button
            onClick={handlePrintAll}
            disabled={filteredStudents.length === 0}
            className="px-5 py-2.5 rounded-xl bg-primary hover:bg-primary-dark text-white font-bold text-xs shadow-md transition-all flex items-center gap-2 cursor-pointer disabled:opacity-50 active:scale-95"
          >
            <Printer className="w-4 h-4" />
            <span>Print All ({filteredStudents.length})</span>
          </button>
        </div>
      </div>

      {/* Settings Grid (Hidden on Print) */}
      <div className="print:hidden grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* 1. Exam & Class Config */}
        <div className="bg-white p-5 rounded-2xl border border-border space-y-4">
          <h2 className="text-sm font-bold text-text flex items-center gap-2">
            <GraduationCap className="w-4 h-4 text-primary" />
            1. Select Class & Exam Name
          </h2>

          <div>
            <label className="text-[11px] font-bold text-text-secondary uppercase">Select Class</label>
            <select
              value={selectedClass}
              onChange={(e) => setSelectedClass(e.target.value)}
              className="mt-1 w-full px-3 py-2 bg-surface2 rounded-xl border border-border text-xs font-semibold text-text focus:outline-primary"
            >
              <option value="all">All Classes Booklet ({students.length} Students)</option>
              {schoolClasses.map(c => (
                <option key={c} value={c}>Class {c}</option>
              ))}
            </select>
          </div>

          <div>
            <label className="text-[11px] font-bold text-text-secondary uppercase">Search Single Student</label>
            <div className="relative mt-1">
              <Search className="w-4 h-4 text-text-secondary absolute left-3 top-1/2 -translate-y-1/2" />
              <input
                type="text"
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                placeholder="Search by name, roll, or Aadhaar..."
                className="w-full pl-9 pr-3 py-2 bg-surface2 rounded-xl border border-border text-xs font-semibold text-text focus:outline-primary"
              />
            </div>
          </div>

          <div>
            <label className="text-[11px] font-bold text-text-secondary uppercase">Exam Title (Editable)</label>
            <input
              type="text"
              value={examTitle}
              onChange={(e) => setExamTitle(e.target.value)}
              className="mt-1 w-full px-3 py-2 bg-surface2 rounded-xl border border-border text-xs font-semibold text-text focus:outline-primary"
              placeholder="e.g. ANNUAL EXAMINATION 2026"
            />
          </div>

          <div className="p-3 rounded-xl bg-primary/10 border border-primary/20 text-xs font-semibold text-primary flex items-center justify-between">
            <span>Ready to Print:</span>
            <span className="font-bold">{filteredStudents.length} Students</span>
          </div>
        </div>

        {/* 2. Timetable Management */}
        <div className="lg:col-span-2 bg-white p-5 rounded-2xl border border-border space-y-4">
          <div className="flex flex-wrap items-center justify-between gap-2">
            <div>
              <h2 className="text-sm font-bold text-text flex items-center gap-2">
                <Calendar className="w-4 h-4 text-emerald-600" />
                2. Exam Time Table & Dates ({selectedClass === 'all' ? 'All Classes' : 'Class ' + selectedClass})
              </h2>
              <p className="text-[11px] text-text-secondary mt-0.5">
                Class-wise schedule persisted automatically. Change exam dates, subjects, or timings below.
              </p>
            </div>
            <div className="flex items-center gap-2">
              <button
                type="button"
                onClick={handleSaveClassSchedule}
                className="px-3 py-1.5 rounded-xl bg-emerald-600 hover:bg-emerald-700 text-white text-xs font-bold flex items-center gap-1.5 shadow-xs cursor-pointer transition-colors"
                title="Save Schedule for this class"
              >
                <CheckCircle2 className="w-3.5 h-3.5" />
                <span>Save Schedule</span>
              </button>
              <button
                type="button"
                onClick={() => setIsAddingSubject(!isAddingSubject)}
                className="px-3 py-1.5 rounded-xl bg-primary/10 hover:bg-primary/20 text-primary text-xs font-bold flex items-center gap-1 cursor-pointer transition-colors"
              >
                <Plus className="w-3.5 h-3.5" />
                <span>{isAddingSubject ? 'Close' : 'Add Subject'}</span>
              </button>
            </div>
          </div>

          {isAddingSubject && (
            <form onSubmit={handleAddSubject} className="p-3.5 bg-surface2/60 rounded-xl border border-border space-y-3">
              <div className="grid grid-cols-1 md:grid-cols-3 gap-2.5">
                <div>
                  <label className="block text-[11px] font-bold text-text-secondary mb-1">Exam Date (DD/MM/YYYY)</label>
                  <input
                    type="text"
                    placeholder="e.g. 15/03/2026"
                    value={newDay}
                    onChange={(e) => setNewDay(e.target.value)}
                    className="w-full px-3 py-1.5 bg-white rounded-lg border border-border text-xs font-semibold text-text"
                    required
                  />
                </div>
                <div>
                  <label className="block text-[11px] font-bold text-text-secondary mb-1">Subject (Dropdown)</label>
                  <select
                    value={newSubject}
                    onChange={(e) => setNewSubject(e.target.value)}
                    className="w-full px-3 py-1.5 bg-white rounded-lg border border-border text-xs font-semibold text-text"
                  >
                    {STANDARD_ADMIT_SUBJECTS.map((sub) => (
                      <option key={sub} value={sub}>{sub}</option>
                    ))}
                  </select>
                  {newSubject === 'Other' && (
                    <input
                      type="text"
                      placeholder="Enter custom subject name"
                      value={customSubjectName}
                      onChange={(e) => setCustomSubjectName(e.target.value)}
                      className="mt-1.5 w-full px-3 py-1.5 bg-white rounded-lg border border-border text-xs font-semibold text-text"
                      required
                    />
                  )}
                </div>
                <div>
                  <label className="block text-[11px] font-bold text-text-secondary mb-1">Exam Timing</label>
                  <input
                    type="text"
                    placeholder="09:30 AM - 12:30 PM"
                    value={newTiming}
                    onChange={(e) => setNewTiming(e.target.value)}
                    className="w-full px-3 py-1.5 bg-white rounded-lg border border-border text-xs font-semibold text-text"
                    required
                  />
                  <div className="flex gap-1.5 mt-1.5">
                    {['09:00 AM - 12:00 PM', '09:30 AM - 12:30 PM', '01:30 PM - 04:30 PM'].map((t) => (
                      <button
                        key={t}
                        type="button"
                        onClick={() => setNewTiming(t)}
                        className="text-[10px] px-1.5 py-0.5 rounded bg-white hover:bg-surface2 border border-border text-text-secondary cursor-pointer"
                      >
                        {t.slice(0, 8)}
                      </button>
                    ))}
                  </div>
                </div>
              </div>
              <button
                type="submit"
                className="px-4 py-1.5 rounded-lg bg-primary text-white font-bold text-xs cursor-pointer shadow-xs"
              >
                Add Subject to Schedule
              </button>
            </form>
          )}
          <div className="overflow-x-auto border border-border rounded-xl">
            <table className="w-full text-left text-xs">
              <thead className="bg-surface2 font-bold text-text-secondary border-b border-border">
                <tr>
                  <th className="py-2 px-3">Date / Day</th>
                  <th className="py-2 px-3">Subject</th>
                  <th className="py-2 px-3">Exam Timing</th>
                  <th className="py-2 px-3 text-right">Action</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border">
                {timetable.map((item, idx) => (
                  <tr key={idx} className="hover:bg-surface2/50">
                    <td className="py-2 px-3 font-bold text-text">{item.day}</td>
                    <td className="py-2 px-3 text-text font-bold">{item.subject}</td>
                    <td className="py-2 px-3 text-text-secondary font-semibold">{item.timing}</td>
                    <td className="py-2 px-3 text-right">
                      <button
                        onClick={() => handleRemoveSubject(idx)}
                        className="text-rose-500 hover:text-rose-700 p-1 cursor-pointer"
                        title="Remove"
                      >
                        <Trash2 className="w-3.5 h-3.5" />
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      </div>

      {/* Printable & Interactive Admit Cards Section */}
      <div className="space-y-4">
        {/* Interactive Navigator & Actions Header (Hidden on Print) */}
        <div className="print:hidden flex flex-col sm:flex-row sm:items-center justify-between gap-3 bg-white p-4 rounded-2xl border border-border shadow-xs">
          <div>
            <h2 className="text-sm font-black text-text flex items-center gap-2">
              <FileText className="w-4 h-4 text-primary" />
              Live Admit Card Preview
              {filteredStudents.length > 0 && (
                <span className="text-xs font-semibold px-2.5 py-0.5 rounded-full bg-primary/10 text-primary border border-primary/20 ml-2">
                  Student {Math.min(selectedStudentIndex + 1, filteredStudents.length)} of {filteredStudents.length}
                </span>
              )}
            </h2>
            <p className="text-xs text-text-secondary mt-0.5">
              Compact miniature preview. Search student or use arrows to switch without scrolling through 50 cards.
            </p>
          </div>

          {filteredStudents.length > 0 && (
            <div className="flex flex-wrap items-center gap-2">
              {/* Prev Button */}
              <button
                type="button"
                onClick={() => setSelectedStudentIndex(prev => Math.max(0, prev - 1))}
                disabled={selectedStudentIndex <= 0}
                className="p-2 rounded-xl border border-border bg-surface2 hover:bg-surface2/80 disabled:opacity-30 disabled:cursor-not-allowed cursor-pointer transition-all active:scale-95"
                title="Previous Student"
              >
                <ChevronLeft className="w-4 h-4 text-text" />
              </button>

              {/* Student Dropdown Switcher */}
              <select
                value={Math.min(selectedStudentIndex, filteredStudents.length - 1)}
                onChange={(e) => setSelectedStudentIndex(Number(e.target.value))}
                className="px-3 py-1.5 bg-surface2 border border-border rounded-xl text-xs font-bold text-text focus:outline-primary max-w-[210px] truncate"
              >
                {filteredStudents.map((s, idx) => (
                  <option key={s.id} value={idx}>
                    {idx + 1}. {s.name} (Roll: {s.rollNumber || s.id || 'N/A'})
                  </option>
                ))}
              </select>

              {/* Next Button */}
              <button
                type="button"
                onClick={() => setSelectedStudentIndex(prev => Math.min(filteredStudents.length - 1, prev + 1))}
                disabled={selectedStudentIndex >= filteredStudents.length - 1}
                className="p-2 rounded-xl border border-border bg-surface2 hover:bg-surface2/80 disabled:opacity-30 disabled:cursor-not-allowed cursor-pointer transition-all active:scale-95"
                title="Next Student"
              >
                <ChevronRight className="w-4 h-4 text-text" />
              </button>

              {/* Single Download & Print Buttons */}
              {(() => {
                const s = filteredStudents[Math.min(selectedStudentIndex, filteredStudents.length - 1)];
                return (
                  <div className="flex items-center gap-2 ml-1">
                    <button
                      type="button"
                      onClick={() => handleDownloadPdf(s)}
                      disabled={isExportingPdf}
                      className="px-3 py-1.5 rounded-xl bg-emerald-50 hover:bg-emerald-100 text-emerald-700 font-bold text-xs border border-emerald-200 flex items-center gap-1.5 transition-all cursor-pointer active:scale-95 shadow-2xs"
                      title="Download this student's Admit Card PDF"
                    >
                      <Download className="w-3.5 h-3.5" />
                      <span>Download Single PDF</span>
                    </button>
                    <button
                      type="button"
                      onClick={() => handlePrintSingle(s)}
                      className="px-3 py-1.5 rounded-xl bg-primary/10 hover:bg-primary/20 text-primary font-bold text-xs border border-primary/20 flex items-center gap-1.5 transition-all cursor-pointer active:scale-95 shadow-2xs"
                      title="Print this student's Admit Card"
                    >
                      <Printer className="w-3.5 h-3.5" />
                      <span>Print Single</span>
                    </button>
                  </div>
                );
              })()}
            </div>
          )}
        </div>

        {filteredStudents.length === 0 ? (
          <div className="p-8 text-center bg-white rounded-2xl border border-border text-text-secondary text-sm">
            No students found matching the selected class/search filter.
          </div>
        ) : (
          <>
            {/* SCREEN VIEW: Compact Miniature Preview (Less than half screen, zero scrolling clutter) */}
            {(() => {
              const safeIdx = Math.min(selectedStudentIndex, filteredStudents.length - 1);
              const s = filteredStudents[safeIdx] || filteredStudents[0];
              if (!s) return null;

              const aadhaar = s.aadhaarNumber || s.aadharNumber || s.aadhaar || 'NOT-LINKED';
              const qrData = encodeURIComponent(`ADMIT:${s.name}|Roll:${s.rollNumber || s.id}|Class:${s.className}|Aadhaar:${aadhaar}`);
              const qrUrl = `https://api.qrserver.com/v1/create-qr-code/?size=100x100&data=${qrData}`;
              const photoSrc = s.photoUrl || s.photoPath;
              const sigSrc = settings.principalSignature || settings.signatureUrl || settings.signature;

              return (
                <div className="print:hidden max-w-[500px] mx-auto transition-all">
                  <div className="bg-white border-2 border-[#1E3A8A] rounded-2xl p-4 shadow-md text-black font-sans relative">
                    {/* Header Banner */}
                    <div className="bg-[#1E3A8A] text-white rounded-xl p-3 flex items-center justify-between mb-3" style={{ backgroundColor: '#1E3A8A', color: '#ffffff' }}>
                      <div className="flex items-center gap-2.5 min-w-0">
                        {settings.logoUrl || settings.logoPath || settings.logo ? (
                          <div className="w-9 h-9 bg-white rounded-lg p-0.5 flex-shrink-0 flex items-center justify-center">
                            <img
                              src={settings.logoUrl || settings.logoPath || settings.logo}
                              alt="Logo"
                              className="w-full h-full object-contain"
                            />
                          </div>
                        ) : (
                          <div className="w-9 h-9 bg-white text-[#1E3A8A] rounded-lg flex-shrink-0 flex items-center justify-center font-black text-xs">
                            MN
                          </div>
                        )}
                        <div className="min-w-0">
                          <h3 className="font-black text-xs uppercase leading-tight tracking-wide text-white truncate">
                            {settings.instituteName || settings.schoolName || 'MISSION NAVODAYA'}
                          </h3>
                          <p className="text-[8.5px] text-white/90 font-medium truncate">
                            {settings.address || 'Mora Mairi, BagwaanPur hat ,Siwan,Bihar 841507'}
                          </p>
                        </div>
                      </div>
                      <div className="text-right flex-shrink-0 pl-2">
                        <p className="text-[8px] text-[#FFD700] font-black uppercase tracking-wider">
                          SESSION: {settings.currentSession || settings.academicYear || '2026-27'}
                        </p>
                        <p className="text-xs font-black uppercase tracking-wider text-white">
                          ADMIT CARD
                        </p>
                      </div>
                    </div>

                    {/* Exam Title Pill */}
                    <div className="my-2.5 text-center">
                      <span className="inline-block px-6 py-1 bg-white text-[#1E3A8A] font-black text-xs uppercase tracking-wider rounded-md border border-[#1E3A8A] shadow-2xs">
                        {examTitle}
                      </span>
                    </div>

                    {/* Student Info, Photo & QR Code */}
                    <div className="flex justify-between gap-3 text-xs mb-3.5 items-center">
                      {/* Photo Box */}
                      <div className="w-20 h-24 border border-gray-400 bg-white flex flex-col items-center justify-center text-[9px] font-bold text-gray-400 uppercase text-center overflow-hidden rounded flex-shrink-0">
                        {photoSrc ? (
                          <img src={photoSrc} alt="Student Photo" className="w-full h-full object-cover" />
                        ) : (
                          <div>
                            <div>AFFIX</div>
                            <div>PHOTO HERE</div>
                          </div>
                        )}
                      </div>

                      {/* Middle Details */}
                      <div className="space-y-1 font-semibold flex-1 pl-1 text-[11px] min-w-0">
                        <div className="flex truncate"><span className="w-28 text-gray-600 font-bold flex-shrink-0">STUDENT NAME:</span> <strong className="text-black uppercase truncate">{s.name}</strong></div>
                        <div className="flex truncate"><span className="w-28 text-gray-600 font-bold flex-shrink-0">ROLL / ADM NO:</span> <strong className="text-black">{s.rollNumber || s.id || 'N/A'} / {s.admissionNumber || s.id || 'N/A'}</strong></div>
                        <div className="flex truncate"><span className="w-28 text-gray-600 font-bold flex-shrink-0">CLASS & SEC:</span> <strong className="text-black">Class {s.className} - {s.section || 'A'}</strong></div>
                        <div className="flex truncate"><span className="w-28 text-gray-600 font-bold flex-shrink-0">FATHER'S NAME:</span> <span className="text-black uppercase truncate font-bold">{s.fatherName || '-'}</span></div>
                        <div className="flex truncate"><span className="w-28 text-gray-600 font-bold flex-shrink-0">DOB / GENDER:</span> <span className="text-black font-semibold">{s.dob ? String(s.dob).slice(0, 10) : '01/01/2010'} / {s.gender || 'Male'}</span></div>
                        <div className="flex truncate pt-0.5">
                          <span className="w-28 text-gray-600 font-bold flex-shrink-0">AADHAAR:</span>
                          <strong className="text-[#1D4ED8] font-black">{aadhaar}</strong>
                        </div>
                      </div>

                      {/* QR Code */}
                      <div className="flex flex-col items-center justify-center p-1 bg-white border border-gray-300 rounded-lg flex-shrink-0">
                        <img
                          src={qrUrl}
                          alt="QR"
                          className="w-14 h-14 object-contain"
                        />
                      </div>
                    </div>

                    {/* Examination Schedule Title */}
                    <div className="text-[10px] font-black uppercase text-[#1E3A8A] mb-1 tracking-wider">
                      EXAMINATION SCHEDULE & TIME TABLE
                    </div>

                    {/* Timetable Table */}
                    <div className="mb-3">
                      <table className="w-full text-left text-[10px] border border-gray-300 border-collapse">
                        <thead className="bg-gray-100 font-bold border-b border-gray-300">
                          <tr>
                            <th className="p-1.5 border-r border-gray-300 w-16">DATE</th>
                            <th className="p-1.5 border-r border-gray-300">SUBJECT</th>
                            <th className="p-1.5 border-r border-gray-300">TIMING</th>
                            <th className="p-1.5 text-center w-24">SIGN</th>
                          </tr>
                        </thead>
                        <tbody className="divide-y divide-gray-200">
                          {timetable.map((t, tIdx) => (
                            <tr key={tIdx} className={tIdx % 2 === 1 ? 'bg-gray-50/50' : 'bg-white'}>
                              <td className="p-1.5 border-r border-gray-300 font-semibold text-gray-700">{t.day}</td>
                              <td className="p-1.5 border-r border-gray-300 font-bold text-black">{t.subject}</td>
                              <td className="p-1.5 border-r border-gray-300 text-gray-700 font-semibold">{t.timing}</td>
                              <td className="p-1.5 text-center text-gray-300">_______</td>
                            </tr>
                          ))}
                        </tbody>
                      </table>
                    </div>

                    {/* Instructions for Candidate */}
                    <div className="text-[8.5px] text-gray-600 space-y-0.5 border-t border-gray-200 pt-1.5 mb-5">
                      <p className="font-bold text-black uppercase">INSTRUCTIONS FOR CANDIDATES:</p>
                      <p>1. Must bring this Admit Card to Examination Centre on exam day.</p>
                      <p>2. Entry permitted up to 15 minutes prior to commencement.</p>
                      <p>3. Electronic devices and calculators are strictly prohibited.</p>
                    </div>

                    {/* Signatures */}
                    <div className="flex justify-between items-end border-t border-gray-300 pt-2.5 text-[10px] font-bold">
                      <div className="text-center">
                        <div className="w-28 border-b border-gray-400 mb-1" />
                        <span className="text-gray-700">Candidate Signature</span>
                      </div>
                      <div className="flex items-end gap-3">
                        {(settings.schoolStamp || settings.stampUrl || settings.sealUrl) && (
                          <img
                            src={settings.schoolStamp || settings.stampUrl || settings.sealUrl}
                            alt="Stamp"
                            className="object-contain mb-1"
                            style={{
                              width: `${Math.round(40 * (Number(settings.stampScale) || 1.0))}px`,
                              height: `${Math.round(40 * (Number(settings.stampScale) || 1.0))}px`,
                              mixBlendMode: 'multiply'
                            }}
                            onError={(e) => { e.currentTarget.style.display = 'none'; }}
                          />
                        )}
                        <div className="text-center flex flex-col items-center">
                          {sigSrc ? (
                            <img
                              src={sigSrc}
                              alt="Signature"
                              className="object-contain mb-1"
                              style={{
                                height: `${Math.round(32 * (Number(settings.signatureScale) || 1.0))}px`,
                                maxWidth: `${Math.round(130 * (Number(settings.signatureScale) || 1.0))}px`
                              }}
                            />
                          ) : (
                            <div className="h-8" />
                          )}
                          <div className="w-36 border-b-2 border-[#1E3A8A] mb-1" />
                          <span className="text-[#1E3A8A] font-black uppercase tracking-wider text-[8.5px]">
                            Principal / Controller of Exam
                          </span>
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              );
            })()}

            {/* PRINT VIEW: High-Resolution Full-Size Printable Documents (Only rendered on window.print()) */}
            <div className="hidden print:block admit-cards-container">
              {(printTargetStudentId === 'all'
                ? filteredStudents
                : filteredStudents.filter(s => s.id === printTargetStudentId)
              ).map((s) => {
                const aadhaar = s.aadhaarNumber || s.aadharNumber || s.aadhaar || 'NOT-LINKED';
                const qrData = encodeURIComponent(`ADMIT:${s.name}|Roll:${s.rollNumber || s.id}|Class:${s.className}|Aadhaar:${aadhaar}`);
                const qrUrl = `https://api.qrserver.com/v1/create-qr-code/?size=120x120&data=${qrData}`;
                const photoSrc = s.photoUrl || s.photoPath;
                const sigSrc = settings.principalSignature || settings.signatureUrl || settings.signature;

                return (
                  <div
                    key={s.id}
                    className="admit-card-item bg-white border-2 border-[#1E3A8A] rounded-2xl p-6 shadow-none text-black font-sans relative m-0 mb-8"
                    style={{ printColorAdjust: 'exact', WebkitPrintColorAdjust: 'exact', pageBreakAfter: 'always' }}
                  >
                    {/* Header Banner */}
                    <div className="bg-[#1E3A8A] text-white rounded-xl p-3.5 flex items-center justify-between mb-4" style={{ backgroundColor: '#1E3A8A', color: '#ffffff' }}>
                      <div className="flex items-center gap-3">
                        {settings.logoUrl || settings.logoPath || settings.logo ? (
                          <div className="w-12 h-12 bg-white rounded-lg p-1 flex items-center justify-center">
                            <img
                              src={settings.logoUrl || settings.logoPath || settings.logo}
                              alt="Logo"
                              className="w-full h-full object-contain"
                            />
                          </div>
                        ) : (
                          <div className="w-12 h-12 bg-white text-[#1E3A8A] rounded-lg flex items-center justify-center font-black text-lg">
                            MN
                          </div>
                        )}
                        <div>
                          <h2 className="font-black text-base uppercase leading-tight tracking-wide text-white">
                            {settings.instituteName || settings.schoolName || 'MISSION NAVODAYA'}
                          </h2>
                          <p className="text-[10px] text-white/90 font-medium">
                            {settings.address || 'Mora Mairi, BagwaanPur hat ,Siwan,Bihar 841507'}
                          </p>
                        </div>
                      </div>
                      <div className="text-right">
                        <p className="text-[10px] text-[#FFD700] font-black uppercase tracking-wider">
                          SESSION: {settings.currentSession || settings.academicYear || '2026-27'}
                        </p>
                        <p className="text-sm font-black uppercase tracking-wider text-white">
                          ADMIT CARD
                        </p>
                      </div>
                    </div>

                    {/* Exam Title Pill Badge */}
                    <div className="my-3 text-center">
                      <span className="inline-block px-8 py-1.5 bg-white text-[#1E3A8A] font-black text-sm uppercase tracking-wider rounded-md border border-[#1E3A8A] shadow-2xs">
                        {examTitle}
                      </span>
                    </div>

                    {/* Student Info, Photo & QR Code */}
                    <div className="flex justify-between gap-4 text-xs mb-5 items-center">
                      {/* Photo Box */}
                      <div className="w-24 h-32 border border-gray-400 bg-white flex flex-col items-center justify-center text-[10px] font-bold text-gray-400 uppercase text-center overflow-hidden rounded flex-shrink-0">
                        {photoSrc ? (
                          <img src={photoSrc} alt="Student Photo" className="w-full h-full object-cover" />
                        ) : (
                          <div>
                            <div>AFFIX</div>
                            <div>PHOTO HERE</div>
                          </div>
                        )}
                      </div>

                      {/* Middle Details */}
                      <div className="space-y-1.5 font-semibold flex-1 pl-2 text-sm">
                        <div className="flex"><span className="w-36 text-gray-600 font-bold">STUDENT NAME:</span> <strong className="text-black uppercase text-base">{s.name}</strong></div>
                        <div className="flex"><span className="w-36 text-gray-600 font-bold">ROLL NO / ADM NO:</span> <strong className="text-black">{s.rollNumber || s.id || 'N/A'}  /  {s.admissionNumber || s.id || 'N/A'}</strong></div>
                        <div className="flex"><span className="w-36 text-gray-600 font-bold">CLASS & SECTION:</span> <strong className="text-black">Class {s.className} - {s.section || 'A'}</strong></div>
                        <div className="flex"><span className="w-36 text-gray-600 font-bold">FATHER'S NAME:</span> <span className="text-black uppercase font-bold">{s.fatherName || '-'}</span></div>
                        <div className="flex"><span className="w-36 text-gray-600 font-bold">DOB / GENDER:</span> <span className="text-black font-semibold">{s.dob ? String(s.dob).slice(0, 10) : '01/01/2010'}  /  {s.gender || 'Male'}</span></div>
                        <div className="flex pt-0.5">
                          <span className="w-36 text-gray-600 font-bold">AADHAAR NUMBER:</span>
                          <strong className="text-[#1D4ED8] font-black">{aadhaar}</strong>
                        </div>
                      </div>

                      {/* QR Code */}
                      <div className="flex flex-col items-center justify-center p-1.5 bg-white border border-gray-300 rounded-lg flex-shrink-0">
                        <img
                          src={qrUrl}
                          alt="Admit Card QR"
                          className="w-20 h-20 object-contain"
                        />
                      </div>
                    </div>

                    {/* Examination Schedule Title */}
                    <div className="text-xs font-black uppercase text-[#1E3A8A] mb-1.5 tracking-wider">
                      EXAMINATION SCHEDULE & TIME TABLE
                    </div>

                    {/* Timetable Table */}
                    <div className="mb-4">
                      <table className="w-full text-left text-xs border border-gray-300 border-collapse">
                        <thead className="bg-gray-100 font-bold border-b border-gray-300">
                          <tr>
                            <th className="p-2 border-r border-gray-300 w-24">DATE</th>
                            <th className="p-2 border-r border-gray-300">SUBJECT</th>
                            <th className="p-2 border-r border-gray-300">TIMING</th>
                            <th className="p-2 text-center w-36">INVIGILATOR SIGN</th>
                          </tr>
                        </thead>
                        <tbody className="divide-y divide-gray-200">
                          {timetable.map((t, idx) => (
                            <tr key={idx} className={idx % 2 === 1 ? 'bg-gray-50/50' : 'bg-white'}>
                              <td className="p-2 border-r border-gray-300 font-semibold text-gray-700">{t.day}</td>
                              <td className="p-2 border-r border-gray-300 font-bold text-black">{t.subject}</td>
                              <td className="p-2 border-r border-gray-300 text-gray-700 font-semibold">{t.timing}</td>
                              <td className="p-2 text-center text-gray-300">__________</td>
                            </tr>
                          ))}
                        </tbody>
                      </table>
                    </div>

                    {/* Instructions for Candidate */}
                    <div className="text-[10px] text-gray-600 space-y-0.5 border-t border-gray-200 pt-2 mb-10">
                      <p className="font-bold text-black uppercase">INSTRUCTIONS FOR CANDIDATES:</p>
                      <p>1. Candidate must bring this Admit Card to the Examination Centre on every exam day.</p>
                      <p>2. Entry to the examination hall is permitted up to 15 minutes prior to commencement.</p>
                      <p>3. Electronic devices, mobile phones, and calculators are strictly prohibited.</p>
                    </div>

                    {/* Signatures */}
                    <div className="flex justify-between items-end border-t border-gray-300 pt-4 mt-6 text-xs font-bold">
                      <div className="text-center">
                        <div className="w-36 border-b border-gray-400 mb-1.5" />
                        <span className="text-gray-700">Candidate Signature</span>
                      </div>
                      <div className="flex items-end gap-3.5">
                        {(settings.schoolStamp || settings.stampUrl || settings.sealUrl) && (
                          <img
                            src={settings.schoolStamp || settings.stampUrl || settings.sealUrl}
                            alt="Stamp"
                            className="h-11 w-11 object-contain mb-1"
                            style={{ mixBlendMode: 'multiply' }}
                            onError={(e) => { e.currentTarget.style.display = 'none'; }}
                          />
                        )}
                        <div className="text-center flex flex-col items-center">
                          {sigSrc ? (
                            <img
                              src={sigSrc}
                              alt="Signature"
                              className="h-9 object-contain mb-1"
                            />
                          ) : (
                            <div className="h-9" />
                          )}
                          <div className="w-44 border-b-2 border-[#1E3A8A] mb-1.5" />
                          <span className="text-[#1E3A8A] font-black uppercase tracking-wider">
                            Principal / Controller of Exam
                          </span>
                        </div>
                      </div>
                    </div>
                  </div>
                );
              })}
            </div>
          </>
        )}
      </div>
    </div>
  );
}
