'use client';

import React from 'react';
import { X, Printer, Award, Download, CheckCircle, AlertCircle, Sparkles, BookOpen, User, Calendar, Hash } from 'lucide-react';
import { QRCodeSVG } from 'qrcode.react';
import { exportSingleResultPDF } from '../lib/exportUtils';
import { useSchoolStore } from '../lib/store';

export default function PrintResultModal({ result: propResult, student: propStudent, data, onClose }) {
  const { settings: storeSettings, showToast } = useSchoolStore();

  const result = propResult || data?.result;
  const student = propStudent || data?.student;
  const settings = data?.settings || storeSettings || {};

  if (!result) return null;

  const rawSubjects = Array.isArray(result.subjects) && result.subjects.length > 0
    ? result.subjects
    : [{ subjectName: result.subject || 'General', totalMarks: result.totalMarks || 100, marks: result.marks || 0 }];

  const hasDetailedBreakdown = rawSubjects.some(
    s => (Number(s.theoryMarks) > 0 || Number(s.practicalMarks) > 0 || Number(s.internalMarks) > 0)
  );

  const total = rawSubjects.reduce((sum, s) => sum + (Number(s.totalMarks) || 0), 0);
  const obt = rawSubjects.reduce((sum, s) => sum + (Number(s.marks) || 0), 0);
  const pct = total > 0 ? ((obt / total) * 100).toFixed(1) : '0.0';
  const grade = Number(pct) >= 90 ? 'A+' : Number(pct) >= 80 ? 'A' : Number(pct) >= 70 ? 'B+' : Number(pct) >= 60 ? 'B' : Number(pct) >= 50 ? 'C' : Number(pct) >= 40 ? 'D' : 'F';
  const passingCriteria = Number(result.passingMarks || 33);
  const isPass = Number(pct) >= passingCriteria;

  const failedSubjects = rawSubjects.filter(s => {
    const sMax = Number(s.totalMarks) || 100;
    const sObt = Number(s.marks) || 0;
    const minPass = s.passingMarks != null ? Number(s.passingMarks) : Math.round(sMax * (passingCriteria / 100));
    return sObt < minPass;
  });
  const failCount = failedSubjects.length;

  let finalStatus = 'PASS';
  if (result.status === 'PROMOTED') {
    finalStatus = 'PROMOTED';
  } else if (failCount > 0 || !isPass || result.status === 'FAIL') {
    finalStatus = 'FAIL';
  } else {
    finalStatus = 'PASS';
  }

  // Division Calculation
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
    await exportSingleResultPDF(result, student, settings);
    showToast(`Downloaded marksheet PDF for ${student?.name || 'student'}!`, 'success');
  };

  const logoSrc = settings.logoUrl || settings.logoPath || settings.logo;
  const sigSrc = settings.principalSignature || settings.signatureUrl || settings.signaturePath || settings.signature;
  const stampSrc = settings.schoolSeal || settings.schoolStamp || settings.stampUrl || settings.stampPath || settings.sealUrl;
  const studentPhoto = student?.photoUrl || student?.photoPath;

  // Dynamic Stamp & Signature Scales from Settings
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
      className="fixed inset-0 z-50 overflow-y-auto bg-black/80 backdrop-blur-xs p-2 sm:p-4 lg:p-6 flex justify-center items-start print:p-0 print:bg-white print:static"
    >
      <div className="bg-white text-slate-900 rounded-2xl w-full max-w-3xl shadow-2xl overflow-hidden my-2 sm:my-6 print:shadow-none print:m-0 print:max-w-none print:w-full flex flex-col relative animate-in fade-in zoom-in-95 duration-200">
        
        {/* Sticky Print Controls Header */}
        <div className="sticky top-0 z-30 px-4 py-3 sm:py-3.5 border-b border-slate-200 bg-slate-100/95 backdrop-blur-md flex items-center justify-between shadow-xs print:hidden">
          <div className="flex items-center gap-2.5 min-w-0">
            <div className="w-8 h-8 rounded-lg bg-indigo-600/10 flex items-center justify-center text-indigo-700 shrink-0">
              <Award className="w-4 h-4" />
            </div>
            <div className="min-w-0">
              <span className="text-xs font-extrabold text-slate-800 block truncate">Official Student Marksheet</span>
              <span className="text-[10px] text-slate-500 font-medium truncate block">{student?.name || 'Student'} • {result.examName || 'Examination'}</span>
            </div>
          </div>

          <div className="flex items-center gap-2 shrink-0">
            <button
              onClick={handleDownloadPDF}
              className="px-3 py-1.5 rounded-lg bg-emerald-600 hover:bg-emerald-700 text-white font-bold text-xs shadow-xs flex items-center gap-1.5 cursor-pointer transition-all active:scale-95"
              title="Download Marksheet as PDF"
            >
              <Download className="w-3.5 h-3.5" />
              <span className="hidden sm:inline">Download PDF</span>
            </button>
            <button
              onClick={handlePrint}
              className="px-3 py-1.5 rounded-lg bg-indigo-900 hover:bg-indigo-950 text-white font-bold text-xs shadow-xs flex items-center gap-1.5 cursor-pointer transition-all active:scale-95"
              title="Print Marksheet"
            >
              <Printer className="w-3.5 h-3.5" />
              <span>Print</span>
            </button>
            <button
              onClick={onClose}
              className="px-2.5 py-1.5 rounded-lg bg-slate-200 hover:bg-rose-100 hover:text-rose-700 text-slate-600 font-bold text-xs flex items-center gap-1 cursor-pointer transition-all active:scale-95"
              title="Close Marksheet Preview"
            >
              <X className="w-4 h-4" />
              <span className="text-xs">Close</span>
            </button>
          </div>
        </div>

        {/* MARKSHEET BODY */}
        <div className="p-3 sm:p-6 lg:p-8 print:p-4 font-sans overflow-y-auto">
          <div className="border-4 border-double border-indigo-950 p-4 sm:p-6 lg:p-7 rounded-xl space-y-4 sm:space-y-5 bg-white shadow-xs">
            
            {/* Header: Logo, School Name, Affiliation */}
            <div className="text-center border-b-2 border-indigo-950 pb-4 space-y-1">
              {logoSrc && (
                <div className="flex justify-center mb-1.5">
                  <img src={logoSrc} alt="School Logo" className="w-14 h-14 sm:w-16 sm:h-16 object-contain" />
                </div>
              )}
              <h1 className="text-xl sm:text-2xl font-black uppercase tracking-wider text-indigo-950 leading-tight">
                {settings.instituteName || settings.schoolName || 'Smart School & Computer Institute'}
              </h1>
              <p className="text-[11px] sm:text-xs text-slate-600 font-medium">
                {settings.address || 'Main Campus'} • Affiliation: {settings.affiliationNumber || 'CBSE/Govt. Recognized'}
                {settings.mobile ? ` • Helpline: ${settings.mobile}` : ''}
              </p>
              
              <div className="inline-block mt-2 px-4 py-1 rounded-full bg-indigo-950 text-amber-300 text-[10px] sm:text-xs font-black uppercase tracking-widest shadow-xs">
                OFFICIAL REPORT CARD & STATEMENT OF MARKS
              </div>
              <p className="text-xs sm:text-sm font-bold text-slate-800 pt-1 tracking-tight">
                {result.examName || 'Annual Examination 2026-27'}
              </p>
            </div>

            {/* Student Info Box (Fully Responsive with Optional DP Avatar) */}
            <div className="p-3 sm:p-4 rounded-xl bg-slate-50 border border-slate-300 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3 sm:gap-4">
              <div className="flex items-center gap-3 w-full sm:w-auto">
                {studentPhoto ? (
                  <div className="w-14 h-18 sm:w-16 sm:h-20 rounded-lg border-2 border-slate-300 overflow-hidden bg-white shrink-0 shadow-xs">
                    <img src={studentPhoto} alt={student?.name} className="w-full h-full object-cover" />
                  </div>
                ) : (
                  <div className="w-14 h-18 sm:w-16 sm:h-20 rounded-lg border-2 border-dashed border-slate-300 flex flex-col items-center justify-center bg-white text-slate-400 shrink-0">
                    <User className="w-6 h-6 text-slate-300" />
                    <span className="text-[8px] font-bold text-slate-400 mt-0.5">PHOTO</span>
                  </div>
                )}

                <div className="space-y-1 text-xs min-w-0">
                  <div className="text-[10px] uppercase font-bold text-slate-500">Student Profile</div>
                  <h3 className="font-extrabold text-sm sm:text-base text-indigo-950 truncate">
                    {student?.name || result?.studentName || 'Student Name'}
                  </h3>
                  <div className="text-[11px] text-slate-600">
                    Father's Name: <strong className="text-slate-800">{student?.fatherName || '—'}</strong>
                  </div>
                  <div className="text-[11px] text-slate-600">
                    Class / Course: <strong className="text-indigo-900">{student?.studentType === 'school' ? `Class ${student?.className || ''} - ${student?.section || 'A'}` : (student?.course || result?.class || 'General')}</strong>
                  </div>
                </div>
              </div>

              {/* Right Meta Badges */}
              <div className="grid grid-cols-2 sm:grid-cols-1 gap-2 text-right w-full sm:w-auto text-xs shrink-0 border-t sm:border-t-0 pt-2 sm:pt-0 border-slate-200">
                <div className="text-left sm:text-right">
                  <span className="text-[10px] text-slate-500 block">Student ID</span>
                  <span className="font-mono font-bold text-indigo-950 text-xs sm:text-sm">{student?.studentId || result?.studentId || '—'}</span>
                </div>
                <div className="text-right">
                  <span className="text-[10px] text-slate-500 block">Roll Number</span>
                  <span className="font-bold text-slate-800 text-xs sm:text-sm">{student?.rollNumber || result?.rollNumber || 'N/A'}</span>
                </div>
                <div className="col-span-2 sm:col-span-1 text-left sm:text-right">
                  <span className="text-[10px] text-slate-500 block">Academic Session</span>
                  <span className="font-bold text-slate-700 text-xs">{student?.session || settings.currentSession || '2026-27'}</span>
                </div>
              </div>
            </div>

            {/* Marks Table (Responsive Horizontal Scroll Container) */}
            <div className="overflow-x-auto -mx-1 sm:mx-0 border border-slate-300 rounded-lg">
              <table className="w-full text-xs text-left border-collapse min-w-[540px]">
                <thead className="bg-indigo-950 text-white font-bold text-[11px]">
                  <tr>
                    <th className="p-2.5 border-r border-indigo-900 text-center w-12">S.No</th>
                    <th className="p-2.5 border-r border-indigo-900">Subject Name</th>
                    {hasDetailedBreakdown && (
                      <>
                        <th className="p-2.5 text-center border-r border-indigo-900 w-16">Theory</th>
                        <th className="p-2.5 text-center border-r border-indigo-900 w-16">Practical</th>
                        <th className="p-2.5 text-center border-r border-indigo-900 w-16">Internal</th>
                      </>
                    )}
                    <th className="p-2.5 text-center border-r border-indigo-900 w-20">Max Marks</th>
                    <th className="p-2.5 text-center border-r border-indigo-900 w-24">Marks Obtained</th>
                    <th className="p-2.5 text-center border-r border-indigo-900 w-14">Grade</th>
                    <th className="p-2.5 text-center w-18">Status</th>
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
                        <td className="p-2 border-r border-slate-300 text-center font-mono text-slate-500">{idx + 1}</td>
                        <td className="p-2 border-r border-slate-300 font-bold text-slate-800">{sub.subjectName}</td>
                        {hasDetailedBreakdown && (
                          <>
                            <td className="p-2 border-r border-slate-300 text-center text-slate-600">{sub.theoryMarks != null ? sub.theoryMarks : '-'}</td>
                            <td className="p-2 border-r border-slate-300 text-center text-slate-600">{sub.practicalMarks != null ? sub.practicalMarks : '-'}</td>
                            <td className="p-2 border-r border-slate-300 text-center text-slate-600">{sub.internalMarks != null ? sub.internalMarks : '-'}</td>
                          </>
                        )}
                        <td className="p-2 border-r border-slate-300 text-center font-medium">{sub.totalMarks}</td>
                        <td className="p-2 border-r border-slate-300 text-center font-extrabold text-indigo-950 text-sm">{sub.marks}</td>
                        <td className="p-2 border-r border-slate-300 text-center font-black text-indigo-900">{subGrade}</td>
                        <td className="p-2 text-center">
                          <span className={`text-[10px] font-black px-2 py-0.5 rounded-full ${
                            subPass ? 'bg-emerald-100 text-emerald-800' : 'bg-rose-100 text-rose-800'
                          }`}>
                            {subPass ? 'PASS' : 'FAIL'}
                          </span>
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
                <tfoot className="bg-indigo-50/70 font-black border-t-2 border-indigo-950">
                  <tr>
                    <td colSpan={hasDetailedBreakdown ? 5 : 2} className="p-2.5 border-r border-slate-300 uppercase text-indigo-950 text-xs">
                      Grand Total
                    </td>
                    <td className="p-2.5 border-r border-slate-300 text-center font-black">{total}</td>
                    <td className="p-2.5 border-r border-slate-300 text-center text-indigo-950 text-sm font-black">{obt}</td>
                    <td className="p-2.5 border-r border-slate-300 text-center font-black text-indigo-900">{grade}</td>
                    <td className="p-2.5 text-center">
                      <span className={`text-[10px] font-black ${
                        finalStatus === 'PROMOTED' ? 'text-amber-700' : isPass && failCount === 0 ? 'text-emerald-700' : 'text-rose-700'
                      }`}>
                        {finalStatus}
                      </span>
                    </td>
                  </tr>
                </tfoot>
              </table>
            </div>

            {/* Performance Summary Banner */}
            <div className="p-3 sm:p-4 rounded-xl border-2 border-indigo-950 bg-slate-50 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3 text-xs">
              <div className="flex flex-wrap items-center gap-x-4 gap-y-1">
                <div>
                  <span className="text-slate-500">Percentage: </span>
                  <strong className="text-indigo-950 text-base font-black">{pct}%</strong>
                </div>
                <div>
                  <span className="text-slate-500">Overall Grade: </span>
                  <strong className="text-indigo-900 text-base font-black">{grade}</strong>
                </div>
                <div>
                  <span className="text-slate-500">Division: </span>
                  <strong className="text-slate-800 font-bold">{division}</strong>
                </div>
              </div>

              <div className={`font-black text-xs sm:text-sm uppercase px-4 py-1.5 rounded-full border shadow-xs shrink-0 ${
                finalStatus === 'PROMOTED'
                  ? 'bg-amber-100 text-amber-800 border-amber-300'
                  : finalStatus === 'PASS'
                  ? 'bg-emerald-100 text-emerald-800 border-emerald-300'
                  : 'bg-rose-100 text-rose-800 border-rose-300'
              }`}>
                {finalStatus === 'PROMOTED'
                  ? 'STATUS: PROMOTED'
                  : finalStatus === 'PASS'
                  ? 'STATUS: PASSED'
                  : `STATUS: FAILED / COMPARTMENT ${failCount > 0 ? `(${failCount} SUBJ)` : ''}`}
              </div>
            </div>

            {/* Teacher Remarks Container */}
            <div className="p-3 rounded-lg border border-slate-200 bg-slate-50/70 text-xs">
              <span className="text-[10px] uppercase font-bold text-slate-500 block mb-0.5">Faculty / Teacher Remarks:</span>
              <p className="text-slate-700 font-medium italic">
                "{result.remarks || (finalStatus === 'PASS' ? 'Excellent academic performance and consistent participation in class activities.' : finalStatus === 'PROMOTED' ? 'Promoted to the next standard with advisory for subject enhancement.' : 'Needs focused attention in compartment subject(s).')}"
              </p>
            </div>

            {/* Grading Scale Reference Legend */}
            <div className="p-2 rounded-lg bg-slate-100/70 text-[9.5px] text-slate-600 flex flex-wrap items-center justify-between gap-1 leading-tight border border-slate-200">
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

            {/* Signatures & Stamp (Naturally Layered with Dynamic Settings Scale) */}
            <div className="flex items-end justify-between pt-4 sm:pt-6">
              <div className="text-center space-y-1">
                <div className="w-28 sm:w-36 border-b border-indigo-950" />
                <div className="text-[10px] font-bold uppercase text-slate-700">Class Teacher's Sign</div>
              </div>

              {/* QR Code Center */}
              <div className="flex flex-col items-center">
                <div className="p-1 border border-slate-300 rounded-md bg-white shadow-xs">
                  <QRCodeSVG
                    value={`RESULT:${result.examName || 'Exam'}|STUDENT:${student?.studentId || result?.studentId}|PCT:${pct}%|GRADE:${grade}|STATUS:${finalStatus}`}
                    size={46}
                  />
                </div>
                <span className="text-[8px] font-bold text-slate-500 uppercase tracking-tighter mt-1">Verified Marksheet</span>
              </div>

              {/* Right: Stamp & Director Sign (Dynamically Scaled via Settings) */}
              <div className="flex flex-col items-center">
                <div
                  className="relative flex items-center justify-center mb-1"
                  style={{
                    minWidth: `${Math.max(120, sigWidthPx)}px`,
                    minHeight: `${Math.max(50, stampSizePx)}px`
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
                      alt="Director Signature"
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
                <div className="w-28 sm:w-36 border-b border-indigo-950" />
                <div className="text-[10px] font-bold uppercase text-slate-700 tracking-tight mt-1">Director Sign</div>
              </div>
            </div>

            {/* Footer Disclaimer */}
            <div className="text-center pt-2 text-[9px] text-slate-400 border-t border-slate-200">
              Generated on {new Date().toLocaleDateString('en-GB')} • Official Academic Record of {settings.instituteName || 'Smart School'}
            </div>

          </div>
        </div>
      </div>
    </div>
  );
}
