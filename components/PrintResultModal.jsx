'use client';

import React, { useState, useEffect, useMemo } from 'react';
import {
  X, Printer, Award, Download, CheckCircle, AlertCircle, Sparkles, BookOpen,
  User, Calendar, Hash, ChevronLeft, ChevronRight, Search, Share2
} from 'lucide-react';
import { QRCodeSVG } from 'qrcode.react';
import { exportSingleResultPDF, exportBulkResultMarksheetsPDF, openWhatsAppResultShare } from '../lib/exportUtils';
import { useSchoolStore } from '../lib/store';

export default function PrintResultModal({ result: propResult, student: propStudent, data, onClose }) {
  const { settings: storeSettings, students = [], showToast } = useSchoolStore();

  const settings = data?.settings || storeSettings || {};

  // Support single result or array of results for booklet navigation
  const allResults = useMemo(() => {
    if (data?.allResults && Array.isArray(data.allResults) && data.allResults.length > 0) {
      return data.allResults;
    }
    if (propResult) return [propResult];
    if (data?.result) return [data.result];
    return [];
  }, [data, propResult]);

  const initialIndex = useMemo(() => {
    if (data?.currentIndex != null && data.currentIndex >= 0 && data.currentIndex < allResults.length) {
      return data.currentIndex;
    }
    return 0;
  }, [data?.currentIndex, allResults.length]);

  const [currentIndex, setCurrentIndex] = useState(initialIndex);

  // Keep index in bounds if allResults changes
  useEffect(() => {
    if (currentIndex >= allResults.length && allResults.length > 0) {
      setCurrentIndex(0);
    }
  }, [allResults.length, currentIndex]);

  const currentResult = allResults[currentIndex] || propResult || data?.result;

  // Resolve matching student for currently selected result
  const currentStudent = useMemo(() => {
    if (data?.allStudents && data.allStudents[currentIndex]) {
      return data.allStudents[currentIndex];
    }
    if (!currentResult) return propStudent || data?.student;

    const rId = String(currentResult.studentId || '').trim().toLowerCase();
    const rName = String(currentResult.studentName || '').trim().toLowerCase();

    const found = students.find(s => {
      if (rId) {
        if (s.id && String(s.id).trim().toLowerCase() === rId) return true;
        if (s.studentId && String(s.studentId).trim().toLowerCase() === rId) return true;
        if (s.admissionNumber && String(s.admissionNumber).trim().toLowerCase() === rId) return true;
        if (s.admissionNo && String(s.admissionNo).trim().toLowerCase() === rId) return true;
      }
      if (rName && s.name && String(s.name).trim().toLowerCase() === rName) return true;
      return false;
    });

    return found || propStudent || data?.student || {
      name: currentResult.studentName,
      rollNumber: currentResult.rollNumber,
      className: currentResult.className,
      studentId: currentResult.studentId
    };
  }, [currentIndex, currentResult, students, propStudent, data]);

  const hasMultiple = allResults.length > 1;
  const hasPrev = currentIndex > 0;
  const hasNext = currentIndex < allResults.length - 1;

  const goToPrev = () => {
    if (hasPrev) setCurrentIndex(prev => prev - 1);
  };

  const goToNext = () => {
    if (hasNext) setCurrentIndex(prev => prev + 1);
  };

  // Keyboard navigation: ArrowLeft, ArrowRight, Escape
  useEffect(() => {
    const handleKeyDown = (e) => {
      if (e.target && (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA' || e.target.tagName === 'SELECT')) return;
      if (e.key === 'ArrowLeft') {
        goToPrev();
      } else if (e.key === 'ArrowRight') {
        goToNext();
      } else if (e.key === 'Escape') {
        onClose();
      }
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [hasPrev, hasNext]);

  if (!currentResult) return null;

  // Calculations for current marksheet
  const rawSubjects = Array.isArray(currentResult.subjects) && currentResult.subjects.length > 0
    ? currentResult.subjects
    : [{ subjectName: currentResult.subject || 'General', totalMarks: currentResult.totalMarks || 100, marks: currentResult.marks || 0 }];

  const hasDetailedBreakdown = rawSubjects.some(
    s => (Number(s.theoryMarks) > 0 || Number(s.practicalMarks) > 0 || Number(s.internalMarks) > 0)
  );

  const total = rawSubjects.reduce((sum, s) => sum + (Number(s.totalMarks) || 0), 0);
  const obt = rawSubjects.reduce((sum, s) => sum + (Number(s.marks) || 0), 0);
  const pct = total > 0 ? ((obt / total) * 100).toFixed(1) : '0.0';
  const grade = Number(pct) >= 90 ? 'A+' : Number(pct) >= 80 ? 'A' : Number(pct) >= 70 ? 'B+' : Number(pct) >= 60 ? 'B' : Number(pct) >= 50 ? 'C' : Number(pct) >= 40 ? 'D' : 'F';
  const passingCriteria = Number(currentResult.passingMarks || 33);
  const isPass = Number(pct) >= passingCriteria;

  const failedSubjects = rawSubjects.filter(s => {
    const sMax = Number(s.totalMarks) || 100;
    const sObt = Number(s.marks) || 0;
    const minPass = s.passingMarks != null ? Number(s.passingMarks) : Math.round(sMax * (passingCriteria / 100));
    return sObt < minPass;
  });
  const failCount = failedSubjects.length;

  let finalStatus = 'PASS';
  if (currentResult.status === 'PROMOTED') {
    finalStatus = 'PROMOTED';
  } else if (failCount > 0 || !isPass || currentResult.status === 'FAIL') {
    finalStatus = 'NEEDS IMPROVEMENT';
  } else {
    finalStatus = 'PASS';
  }

  let division = 'Needs Improvement';
  if (finalStatus === 'PASS' || finalStatus === 'PROMOTED') {
    const numPct = Number(pct);
    if (numPct >= 60) division = '1st Division (Distinction)';
    else if (numPct >= 45) division = '2nd Division';
    else if (numPct >= 33) division = '3rd Division';
  }

  const handlePrint = () => {
    window.print();
  };

  const handleDownloadPDF = async () => {
    try {
      showToast(`Generating marksheet PDF for ${currentStudent?.name || 'student'}...`, 'info');
      await exportSingleResultPDF(currentResult, currentStudent, settings);
      showToast(`Downloaded marksheet PDF!`, 'success');
    } catch (e) {
      console.error(e);
      showToast('Error downloading PDF', 'error');
    }
  };

  const handleWhatsApp = async () => {
    try {
      showToast(`Opening WhatsApp share for ${currentStudent?.name || 'student'}...`, 'info');
      await openWhatsAppResultShare(currentResult, currentStudent, settings);
    } catch (e) {
      console.error(e);
      showToast('Error sharing result', 'error');
    }
  };

  const logoSrc = settings.logoUrl || settings.logoPath || settings.logo;
  const sigSrc = settings.principalSignature || settings.signatureUrl || settings.signaturePath || settings.signature;
  const stampSrc = settings.schoolSeal || settings.schoolStamp || settings.stampUrl || settings.stampPath || settings.sealUrl;
  const studentPhoto = currentStudent?.photoUrl || currentStudent?.photoPath;

  const stampScale = Number(settings.stampScale) || 1.0;
  const sigScale = Number(settings.signatureScale) || 1.0;
  const stampSizePx = Math.round(58 * stampScale);
  const sigWidthPx = Math.round(130 * sigScale);
  const sigHeightPx = Math.round(38 * sigScale);

  return (
    <div
      onClick={(e) => {
        if (e.target === e.currentTarget) onClose();
      }}
      className="fixed inset-0 z-50 overflow-y-auto bg-slate-950/85 backdrop-blur-md p-1 sm:p-4 lg:p-6 flex justify-center items-start print:p-0 print:bg-white print:static"
    >
      <div className="bg-white text-slate-900 rounded-2xl w-full max-w-4xl shadow-2xl overflow-hidden my-1 sm:my-4 print:shadow-none print:m-0 print:max-w-none print:w-full flex flex-col relative animate-in fade-in zoom-in-95 duration-200">

        {/* ── TOP STICKY TOOLBAR (Clean Light Blue Theme - Zero Confusion) ── */}
        <div className="sticky top-0 z-40 px-3 py-2.5 sm:px-4 sm:py-3 border-b border-slate-200 bg-white/95 backdrop-blur-md flex flex-wrap items-center justify-between gap-2 shadow-xs print:hidden">
          
          {/* Left: Student Identity */}
          <div className="flex items-center gap-2 min-w-0">
            <div className="w-8 h-8 rounded-lg bg-blue-50 border border-blue-100 flex items-center justify-center text-blue-900 shrink-0">
              <Award className="w-4 h-4 text-blue-900" />
            </div>

            <div className="min-w-0">
              <span className="text-xs font-extrabold text-slate-900 block truncate">
                {currentStudent?.name || currentResult.studentName || 'Student Marksheet'}
              </span>
              <span className="text-[10px] text-slate-500 font-medium truncate block">
                {currentResult.examName || 'Examination'} • Roll {currentStudent?.rollNumber || currentResult.rollNumber || '—'}
              </span>
            </div>
          </div>

          {/* Center: Previous / Next + Student Selector (Clean, No Dark Drawer) */}
          {hasMultiple && (
            <div className="flex items-center gap-1.5 bg-slate-50 px-2 py-1 rounded-xl border border-slate-200 shadow-xs">
              <button
                onClick={goToPrev}
                disabled={!hasPrev}
                className="p-1 rounded-lg hover:bg-white text-slate-700 disabled:opacity-30 disabled:pointer-events-none transition-all cursor-pointer"
                title="Previous Student (Arrow Left)"
              >
                <ChevronLeft className="w-4 h-4" />
              </button>

              {/* Student Jump Dropdown */}
              <select
                value={currentIndex}
                onChange={(e) => setCurrentIndex(Number(e.target.value))}
                className="bg-transparent text-xs font-bold text-blue-950 focus:outline-hidden py-0.5 px-1 cursor-pointer max-w-[150px] sm:max-w-[210px] truncate"
                title="Jump to Student"
              >
                {allResults.map((r, i) => (
                  <option key={i} value={i}>
                    {i + 1}. {r.studentName || 'Student'} (Roll {r.rollNumber || '—'})
                  </option>
                ))}
              </select>

              <span className="text-[11px] font-bold text-slate-500 whitespace-nowrap hidden sm:inline">
                ({currentIndex + 1} of {allResults.length})
              </span>

              <button
                onClick={goToNext}
                disabled={!hasNext}
                className="p-1 rounded-lg hover:bg-white text-slate-700 disabled:opacity-30 disabled:pointer-events-none transition-all cursor-pointer"
                title="Next Student (Arrow Right)"
              >
                <ChevronRight className="w-4 h-4" />
              </button>
            </div>
          )}

          {/* Right: Actions */}
          <div className="flex items-center gap-1.5 sm:gap-2 shrink-0">
            <button
              onClick={handleWhatsApp}
              className="p-1.5 sm:px-2.5 sm:py-1.5 rounded-lg bg-emerald-50 hover:bg-emerald-100 text-emerald-700 font-bold text-xs border border-emerald-200 shadow-xs flex items-center gap-1 cursor-pointer transition-all active:scale-95"
              title="Share on WhatsApp"
            >
              <Share2 className="w-3.5 h-3.5" />
              <span className="hidden lg:inline">WhatsApp</span>
            </button>

            <button
              onClick={handleDownloadPDF}
              className="p-1.5 sm:px-2.5 sm:py-1.5 rounded-lg bg-blue-50 hover:bg-blue-100 text-blue-900 font-bold text-xs border border-blue-200 shadow-xs flex items-center gap-1 cursor-pointer transition-all active:scale-95"
              title="Download Current Marksheet as PDF"
            >
              <Download className="w-3.5 h-3.5" />
              <span className="hidden sm:inline">PDF</span>
            </button>

            {hasMultiple && (
              <button
                onClick={async () => {
                  try {
                    showToast(`Generating bulk marksheets for ${allResults.length} students...`, 'info');
                    await exportBulkResultMarksheetsPDF(allResults, students, settings, currentResult?.examName || 'Annual Examination');
                    showToast('All marksheets PDF downloaded successfully!', 'success');
                  } catch (e) {
                    console.error(e);
                    showToast('Error downloading bulk marksheets', 'error');
                  }
                }}
                className="p-1.5 sm:px-2.5 sm:py-1.5 rounded-lg bg-[#1E3A8A] hover:bg-[#162a65] text-white font-bold text-xs shadow-xs flex items-center gap-1 cursor-pointer transition-all active:scale-95"
                title={`Download all ${allResults.length} student marksheets in one combined PDF`}
              >
                <BookOpen className="w-3.5 h-3.5 text-amber-300" />
                <span className="hidden md:inline">Bulk PDF (${allResults.length})</span>
              </button>
            )}

            <button
              onClick={handlePrint}
              className="px-2.5 py-1.5 rounded-lg bg-blue-900 hover:bg-blue-950 text-white font-bold text-xs shadow-xs flex items-center gap-1 cursor-pointer transition-all active:scale-95"
              title="Print Marksheet (A4)"
            >
              <Printer className="w-3.5 h-3.5" />
              <span className="hidden xs:inline">Print</span>
            </button>

            <button
              onClick={onClose}
              className="p-1.5 sm:px-2 sm:py-1.5 rounded-lg bg-slate-100 hover:bg-rose-100 hover:text-rose-700 text-slate-600 font-bold text-xs flex items-center gap-1 cursor-pointer transition-all active:scale-95"
              title="Close (Esc)"
            >
              <X className="w-4 h-4" />
            </button>
          </div>
        </div>

        {/* ── MARKSHEET DOCUMENT WRAPPER ── */}
        <div className="flex-1 overflow-y-auto p-2 sm:p-5 lg:p-6 pb-20 sm:pb-6 font-sans">
          
          {/* Outer Royal Blue Double Border matching Mobile App 1:1 */}
          <div className="border-3 sm:border-4 border-double border-blue-900 p-3 sm:p-6 lg:p-7 rounded-xl space-y-3.5 sm:space-y-5 bg-white shadow-xs">
            
            {/* Header: Circle Logo, School Name, Affiliation */}
            <div className="text-center border-b-2 border-blue-900 pb-3 sm:pb-4 space-y-1">
              {logoSrc && (
                <div className="flex justify-center mb-1">
                  <img
                    src={logoSrc}
                    alt="School Logo"
                    className="w-14 h-14 sm:w-16 sm:h-16 object-contain rounded-full shadow-xs border border-slate-200"
                  />
                </div>
              )}
              <h1 className="text-lg sm:text-2xl font-black uppercase tracking-wider text-blue-950 leading-tight">
                {settings.instituteName || settings.schoolName || 'Mission Navodaya Public School'}
              </h1>
              <p className="text-[10px] sm:text-xs text-slate-600 font-medium">
                {settings.address || 'Main Campus'} • Affiliation: {settings.affiliationNumber || 'CBSE/Govt. Recognized'}
                {settings.mobile ? ` • Helpline: ${settings.mobile}` : ''}
              </p>
              
              {/* Royal Navy Blue Title Banner with Golden Text */}
              <div className="inline-block mt-1.5 px-3 py-0.5 sm:px-4 sm:py-1 rounded-full bg-blue-900 text-amber-300 text-[9px] sm:text-xs font-black uppercase tracking-widest shadow-xs">
                OFFICIAL REPORT CARD & STATEMENT OF MARKS
              </div>

              <p className="text-xs sm:text-sm font-bold text-slate-800 pt-1 tracking-tight">
                {currentResult.examName || 'Annual Examination 2026-27'}
              </p>
            </div>

            {/* Student Info Box (Clean Card) */}
            <div className="p-3 sm:p-4 rounded-xl bg-slate-50 border border-slate-300 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3 sm:gap-4">
              <div className="flex items-center gap-3 w-full sm:w-auto">
                {studentPhoto ? (
                  <div className="w-12 h-16 sm:w-16 sm:h-20 rounded-lg border-2 border-slate-300 overflow-hidden bg-white shrink-0 shadow-xs">
                    <img src={studentPhoto} alt={currentStudent?.name} className="w-full h-full object-cover" />
                  </div>
                ) : (
                  <div className="w-12 h-16 sm:w-16 sm:h-20 rounded-lg border-2 border-dashed border-slate-300 flex flex-col items-center justify-center bg-white text-slate-400 shrink-0">
                    <User className="w-5 h-5 sm:w-6 sm:h-6 text-slate-300" />
                    <span className="text-[7px] sm:text-[8px] font-bold text-slate-400 mt-0.5">PHOTO</span>
                  </div>
                )}

                <div className="space-y-0.5 sm:space-y-1 text-xs min-w-0">
                  <div className="text-[9px] sm:text-[10px] uppercase font-bold text-slate-500">Student Profile</div>
                  <h3 className="font-extrabold text-sm sm:text-base text-blue-950 truncate">
                    {currentStudent?.name || currentResult?.studentName || 'Student Name'}
                  </h3>
                  <div className="text-[10px] sm:text-[11px] text-slate-600 truncate">
                    Father's Name: <strong className="text-slate-800">{currentStudent?.fatherName || '—'}</strong>
                  </div>
                  <div className="text-[10px] sm:text-[11px] text-slate-600 truncate">
                    Class / Course: <strong className="text-blue-900">{currentStudent?.studentType === 'school' ? `Class ${currentStudent?.className || ''} - ${currentStudent?.section || 'A'}` : (currentStudent?.course || currentResult?.className || currentResult?.class || 'General')}</strong>
                  </div>
                </div>
              </div>

              {/* Right Meta Badges */}
              <div className="grid grid-cols-2 sm:grid-cols-1 gap-1.5 sm:gap-2 text-right w-full sm:w-auto text-xs shrink-0 border-t sm:border-t-0 pt-2 sm:pt-0 border-slate-200">
                <div className="text-left sm:text-right">
                  <span className="text-[9px] sm:text-[10px] text-slate-500 block">Student ID</span>
                  <span className="font-mono font-bold text-blue-950 text-xs sm:text-sm">{currentStudent?.studentId || currentResult?.studentId || '—'}</span>
                </div>
                <div className="text-right">
                  <span className="text-[9px] sm:text-[10px] text-slate-500 block">Roll Number</span>
                  <span className="font-bold text-slate-800 text-xs sm:text-sm">{currentStudent?.rollNumber || currentResult?.rollNumber || 'N/A'}</span>
                </div>
                <div className="col-span-2 sm:col-span-1 text-left sm:text-right">
                  <span className="text-[9px] sm:text-[10px] text-slate-500 block">Academic Session</span>
                  <span className="font-bold text-slate-700 text-xs">{currentStudent?.session || settings.currentSession || '2026-27'}</span>
                </div>
              </div>
            </div>

            {/* Marks Table (App Format: NO STATUS COLUMN, NO HARSH "FAIL" BADGES) */}
            <div className="overflow-x-auto -mx-1 sm:mx-0 border border-slate-300 rounded-lg">
              <table className="w-full text-xs text-left border-collapse min-w-[460px]">
                <thead className="bg-blue-900 text-white font-bold text-[10px] sm:text-[11px]">
                  <tr>
                    <th className="p-2 sm:p-2.5 border-r border-blue-800 text-center w-10 sm:w-12">S.No</th>
                    <th className="p-2 sm:p-2.5 border-r border-blue-800">Subject Name</th>
                    {hasDetailedBreakdown && (
                      <>
                        <th className="p-2 sm:p-2.5 text-center border-r border-blue-800 w-14 sm:w-16">Theory</th>
                        <th className="p-2 sm:p-2.5 text-center border-r border-blue-800 w-14 sm:w-16">Practical</th>
                        <th className="p-2 sm:p-2.5 text-center border-r border-blue-800 w-14 sm:w-16">Internal</th>
                      </>
                    )}
                    <th className="p-2 sm:p-2.5 text-center border-r border-blue-800 w-20 sm:w-24">Max Marks</th>
                    <th className="p-2 sm:p-2.5 text-center border-r border-blue-800 w-24 sm:w-28">Marks Obtained</th>
                    <th className="p-2 sm:p-2.5 text-center w-14 sm:w-16">Grade</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-200">
                  {rawSubjects.map((sub, idx) => {
                    const sMax = Number(sub.totalMarks) || 0;
                    const sObt = Number(sub.marks) || 0;
                    const minPass = sub.passingMarks != null ? Number(sub.passingMarks) : Math.round(sMax * (passingCriteria / 100));
                    const subPass = sObt >= minPass;
                    const subPct = sMax > 0 ? (sObt / sMax) * 100 : 0;
                    const subGrade = !subPass ? 'F' : subPct >= 90 ? 'A+' : subPct >= 80 ? 'A' : subPct >= 70 ? 'B+' : subPct >= 60 ? 'B' : subPct >= 50 ? 'C' : 'D';

                    return (
                      <tr key={idx} className={idx % 2 === 1 ? 'bg-slate-50/70 hover:bg-slate-100/60' : 'hover:bg-slate-50'}>
                        <td className="p-1.5 sm:p-2 border-r border-slate-300 text-center font-mono text-slate-500">{idx + 1}</td>
                        <td className="p-1.5 sm:p-2 border-r border-slate-300 font-bold text-slate-800">{sub.subjectName}</td>
                        {hasDetailedBreakdown && (
                          <>
                            <td className="p-1.5 sm:p-2 border-r border-slate-300 text-center text-slate-600">{sub.theoryMarks != null ? sub.theoryMarks : '-'}</td>
                            <td className="p-1.5 sm:p-2 border-r border-slate-300 text-center text-slate-600">{sub.practicalMarks != null ? sub.practicalMarks : '-'}</td>
                            <td className="p-1.5 sm:p-2 border-r border-slate-300 text-center text-slate-600">{sub.internalMarks != null ? sub.internalMarks : '-'}</td>
                          </>
                        )}
                        <td className="p-1.5 sm:p-2 border-r border-slate-300 text-center font-medium">{sub.totalMarks}</td>
                        <td className="p-1.5 sm:p-2 border-r border-slate-300 text-center font-extrabold text-blue-950 text-xs sm:text-sm">{sub.marks}</td>
                        <td className={`p-1.5 sm:p-2 text-center font-black ${subGrade === 'F' ? 'text-blue-950 font-bold' : 'text-blue-900'}`}>
                          {subGrade}
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
                <tfoot className="bg-indigo-50/80 font-black border-t-2 border-blue-900">
                  <tr>
                    <td colSpan={hasDetailedBreakdown ? 5 : 2} className="p-2 sm:p-2.5 border-r border-slate-300 uppercase text-blue-950 text-[10px] sm:text-xs">
                      Grand Total
                    </td>
                    <td className="p-2 sm:p-2.5 border-r border-slate-300 text-center font-black">{total}</td>
                    <td className="p-2 sm:p-2.5 border-r border-slate-300 text-center text-blue-950 text-xs sm:text-sm font-black">{obt}</td>
                    <td className="p-2 sm:p-2.5 text-center font-black text-blue-900">{grade}</td>
                  </tr>
                </tfoot>
              </table>
            </div>

            {/* Performance Summary Banner (App Format: STATUS: NEEDS IMPROVEMENT) */}
            <div className="p-3 sm:p-4 rounded-xl border-2 border-blue-900 bg-slate-50 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3 text-xs">
              <div className="flex flex-wrap items-center gap-x-4 gap-y-1">
                <div>
                  <span className="text-slate-500">Percentage: </span>
                  <strong className="text-blue-950 text-sm sm:text-base font-black">{pct}%</strong>
                </div>
                <div>
                  <span className="text-slate-500">Overall Grade: </span>
                  <strong className="text-blue-900 text-sm sm:text-base font-black">{grade}</strong>
                </div>
                <div>
                  <span className="text-slate-500">Division: </span>
                  <strong className="text-slate-800 font-bold">{division}</strong>
                </div>
              </div>

              {/* Status Pill matching Mobile App */}
              <div className={`font-black text-[11px] sm:text-xs uppercase px-3.5 py-1.5 rounded-full border shadow-xs shrink-0 ${
                finalStatus === 'PROMOTED'
                  ? 'bg-amber-100 text-amber-800 border-amber-300'
                  : finalStatus === 'PASS'
                  ? 'bg-emerald-100 text-emerald-800 border-emerald-300'
                  : 'bg-rose-50 text-rose-800 border-rose-200'
              }`}>
                {finalStatus === 'PROMOTED'
                  ? 'STATUS: PROMOTED TO NEXT CLASS'
                  : finalStatus === 'PASS'
                  ? 'STATUS: PASSED'
                  : 'STATUS: NEEDS IMPROVEMENT'}
              </div>
            </div>

            {/* Teacher Remarks Container */}
            <div className="p-2.5 sm:p-3 rounded-lg border border-slate-200 bg-slate-50/70 text-xs">
              <span className="text-[9px] sm:text-[10px] uppercase font-bold text-slate-500 block mb-0.5">Faculty / Teacher Remarks:</span>
              <p className="text-slate-700 font-medium italic text-[11px] sm:text-xs">
                "{currentResult.remarks || (finalStatus === 'PASS' ? 'Excellent academic performance and consistent participation in class activities.' : finalStatus === 'PROMOTED' ? 'Promoted to the next standard with advisory for subject enhancement.' : 'Needs focused attention in compartment subject(s).')}"
              </p>
            </div>

            {/* Grading Scale Reference Legend */}
            <div className="p-2 rounded-lg bg-slate-100/70 text-[9px] sm:text-[9.5px] text-slate-600 flex flex-wrap items-center justify-between gap-1 leading-tight border border-slate-200">
              <span className="font-bold text-slate-700 uppercase">Grading Scale:</span>
              <span>A+ (90-100%)</span>
              <span>•</span>
              <span>A (80-89%)</span>
              <span>•</span>
              <span>B+ (70-79%)</span>
              <span>•</span>
              <span>B (60-69%)</span>
              <span>•</span>
              <span>C (50-59%)</span>
              <span>•</span>
              <span>D (33-49%)</span>
              <span>•</span>
              <span>F (&lt;33%)</span>
            </div>

            {/* Signatures & Stamp */}
            <div className="flex items-end justify-between pt-3 sm:pt-6">
              <div className="text-center space-y-1">
                <div className="w-24 sm:w-36 border-b border-blue-900" />
                <div className="text-[9px] sm:text-[10px] font-bold uppercase text-slate-700">Class Teacher's Sign</div>
              </div>

              {/* QR Code Center */}
              <div className="flex flex-col items-center">
                <div className="p-1 border border-slate-300 rounded-md bg-white shadow-xs">
                  <QRCodeSVG
                    value={`RESULT:${currentResult.examName || 'Exam'}|STUDENT:${currentStudent?.studentId || currentResult?.studentId}|PCT:${pct}%|GRADE:${grade}|STATUS:${finalStatus}`}
                    size={44}
                  />
                </div>
                <span className="text-[7.5px] sm:text-[8px] font-bold text-slate-500 uppercase tracking-tighter mt-0.5">Verified Marksheet</span>
              </div>

              {/* Right: Stamp & Principal Sign */}
              <div className="flex flex-col items-center">
                <div
                  className="relative flex items-center justify-center mb-1"
                  style={{
                    minWidth: `${Math.max(100, sigWidthPx)}px`,
                    minHeight: `${Math.max(45, stampSizePx)}px`
                  }}
                >
                  {stampSrc && (
                    <img
                      src={stampSrc}
                      alt="School Seal"
                      className="absolute inset-0 m-auto object-contain opacity-85 pointer-events-none"
                      style={{
                        width: `${stampSizePx}px`,
                        height: `${stampSizePx}px`,
                        mixBlendMode: 'multiply'
                      }}
                      onError={(e) => { e.currentTarget.style.display = 'none'; }}
                    />
                  )}
                  {sigSrc ? (
                    <img
                      src={sigSrc}
                      alt="Principal Signature"
                      className="relative z-10 object-contain mb-0.5"
                      style={{
                        width: `${sigWidthPx}px`,
                        height: `${sigHeightPx}px`
                      }}
                      onError={(e) => { e.currentTarget.style.display = 'none'; }}
                    />
                  ) : (
                    <div style={{ height: `${sigHeightPx}px` }} />
                  )}
                </div>
                <div className="w-24 sm:w-36 border-b border-blue-900" />
                <div className="text-[9px] sm:text-[10px] font-bold uppercase text-slate-700 tracking-tight mt-1">Principal Sign</div>
              </div>
            </div>

            {/* Footer Disclaimer */}
            <div className="text-center pt-2 text-[8px] sm:text-[9px] text-slate-400 border-t border-slate-200">
              Generated on {new Date().toLocaleDateString('en-GB')} • Official Academic Record of {settings.instituteName || 'Mission Navodaya Public School'}
            </div>

          </div>
        </div>

        {/* ── MOBILE BOTTOM FLOATING NAVIGATION BAR ── */}
        {hasMultiple && (
          <div className="sm:hidden fixed bottom-3 left-3 right-3 z-50 bg-blue-950/95 text-white backdrop-blur-md rounded-2xl px-4 py-2.5 shadow-2xl flex items-center justify-between border border-white/10 print:hidden">
            <button
              onClick={goToPrev}
              disabled={!hasPrev}
              className="px-3 py-1.5 rounded-xl bg-blue-900 disabled:opacity-30 disabled:pointer-events-none font-bold text-xs flex items-center gap-1 cursor-pointer active:scale-95"
            >
              <ChevronLeft className="w-4 h-4" />
              <span>Prev</span>
            </button>

            <span className="text-xs font-bold text-center px-2 py-1 rounded-lg bg-white/10">
              <span className="text-amber-300">{currentIndex + 1}</span> of {allResults.length}
            </span>

            <button
              onClick={goToNext}
              disabled={!hasNext}
              className="px-3 py-1.5 rounded-xl bg-blue-600 disabled:opacity-30 disabled:pointer-events-none font-bold text-xs flex items-center gap-1 cursor-pointer active:scale-95"
            >
              <span>Next</span>
              <ChevronRight className="w-4 h-4" />
            </button>
          </div>
        )}

      </div>
    </div>
  );
}
