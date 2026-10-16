'use client';

import React, { useState } from 'react';
import { useSchoolStore } from '../lib/store';
import { exportSingleResultPDF, exportSingleAdmitCardPDF } from '../lib/exportUtils';
import {
  X,
  User,
  Phone,
  Mail,
  MapPin,
  Calendar,
  CreditCard,
  GraduationCap,
  Monitor,
  Award,
  Contact,
  MessageSquare,
  Edit,
  Trash2,
  Printer,
  Plus,
  Receipt,
  CheckCircle2,
  AlertCircle,
  Download,
  FileText,
  FileCheck,
  FileSpreadsheet,
  Share2,
  Filter,
  Eye
} from 'lucide-react';
import { 
  openWhatsAppFeeReminder, 
  openWhatsAppReceiptShare, 
  exportReceiptPDF,
  exportStudentFullReportPDF,
  printStudentFullReportPDF,
  exportStudentFullReportExcel,
  openWhatsAppStudentFullReport,
  shareStudentFullReportNative
} from '../lib/exportUtils';
import { QRCodeSVG } from 'qrcode.react';


const STANDARD_PROFILE_SUBJECTS = [
  'Mathematics',
  'Science',
  'Social Science',
  'English',
  'Hindi',
  'Computer',
  'Sanskrit',
  'General Knowledge',
  'Drawing / Art',
  'Physics',
  'Chemistry',
  'Biology',
  'Economics',
  'Accountancy',
  'Other'
];

export default function StudentProfileModal({ student, onClose }) {
  const {
    settings,
    payments,
    attendance,
    results,
    saveResult,
    deleteResult,
    setPrintResultData,
    showToast,
    setCollectFeeStudent,
    feeDetailStudent,
    setFeeDetailStudent,
    setIsFeeDetailSelectorOpen,
    setEditingStudent,
    setIsAddStudentOpen,
    setPrintReceiptData,
    setPrintIdCardsData,
    deleteStudent
  } = useSchoolStore();

  const [activeTab, setActiveTab] = useState('overview'); // 'overview' | 'fees' | 'attendance' | 'results' | 'reports' | 'idcard'
  const [previewAadhaarModal, setPreviewAadhaarModal] = useState(false);
  const [reportMonthFilter, setReportMonthFilter] = useState('all'); // 'all' or 'YYYY-MM'
  const [isAddResultOpen, setIsAddResultOpen] = useState(false);
  const [editingResultItem, setEditingResultItem] = useState(null);
  const [resultExamName, setResultExamName] = useState('Term Examination');
  const [resultSubjects, setResultSubjects] = useState([
    { subjectName: 'Mathematics', marks: '', totalMarks: 100 },
    { subjectName: 'Science', marks: '', totalMarks: 100 },
    { subjectName: 'English', marks: '', totalMarks: 100 }
  ]);

  if (!student) return null;

  const handleOpenAddResult = () => {
    setEditingResultItem(null);
    setResultExamName('Term Examination');
    setResultSubjects([
      { subjectName: 'Mathematics', marks: '', totalMarks: 100 },
      { subjectName: 'Science', marks: '', totalMarks: 100 },
      { subjectName: 'English', marks: '', totalMarks: 100 }
    ]);
    setIsAddResultOpen(true);
  };

  const handleOpenEditResult = (res) => {
    setEditingResultItem(res);
    setResultExamName(res.examName || 'Term Examination');
    setResultSubjects(
      res.subjects && res.subjects.length > 0
        ? res.subjects.map(s => ({
            subjectName: s.subjectName || '',
            marks: s.marks ?? '',
            totalMarks: s.totalMarks || 100
          }))
        : [{ subjectName: 'General', marks: '', totalMarks: 100 }]
    );
    setIsAddResultOpen(true);
  };

  const handleAddResultSubjectRow = () => {
    setResultSubjects(prev => [...prev, { subjectName: '', marks: '', totalMarks: 100 }]);
  };

  const handleRemoveResultSubjectRow = (idx) => {
    setResultSubjects(prev => prev.filter((_, i) => i !== idx));
  };

  const handleResultSubjectChange = (idx, field, val) => {
    setResultSubjects(prev => {
      const copy = [...prev];
      copy[idx] = { ...copy[idx], [field]: val };
      return copy;
    });
  };

  const handleSaveResultSubmit = async (e) => {
    e.preventDefault();
    if (!student?.id) return;
    const cleanedSubjects = resultSubjects
      .filter(s => s.subjectName?.trim())
      .map(s => ({
        subjectName: s.subjectName.trim(),
        marks: Number(s.marks) || 0,
        totalMarks: Number(s.totalMarks) || 100
      }));

    if (cleanedSubjects.length === 0) {
      if (showToast) showToast('Please enter at least one subject with valid marks.', 'warning');
      return;
    }

    try {
      if (saveResult) {
        await saveResult({
          id: editingResultItem?.id,
          studentId: student.id,
          examName: resultExamName.trim() || 'Term Examination',
          subjects: cleanedSubjects
        });
      }
      if (showToast) showToast('Exam result saved successfully!', 'success');
      setIsAddResultOpen(false);
      setEditingResultItem(null);
    } catch (err) {
      if (showToast) showToast('Failed to save exam result.', 'error');
    }
  };

  const handleDeleteResult = async (resId) => {
    if (!confirm('Are you sure you want to delete this exam result?')) return;
    try {
      if (deleteResult) {
        await deleteResult(resId);
      }
      if (showToast) showToast('Exam result deleted successfully.', 'info');
    } catch (err) {
      if (showToast) showToast('Failed to delete result.', 'error');
    }
  };

  const studentPayments = payments.filter(p =>
    p.studentId === student.id ||
    (student.studentId && p.studentId === student.studentId) ||
    (student.admissionNumber && (p.admissionNumber === student.admissionNumber || p.admissionNo === student.admissionNumber))
  );
  const studentResults = results.filter(r => r.studentId === student.id);

  // Real-time calculated financial metrics
  const totalExpectedFees = Number(student.totalFees) > 0 ? Number(student.totalFees) : 0;
  const realPaidFees = studentPayments.reduce((acc, p) => acc + (Number(p.amount) || 0), 0) || Number(student.paidFees) || 0;
  const realPendingDue = Math.max(0, totalExpectedFees - realPaidFees);
  const fsTuition = Number(student.feeStructure?.tuitionFee);
  const monthlyTuition = (!isNaN(fsTuition) && fsTuition > 0)
    ? fsTuition
    : (Number(student.monthlyFee) > 0 ? Number(student.monthlyFee) : 0);
  const feeDueDay = student.feeStructure?.dueDay || 10;

  // Attendance stats for this student
  let totalMarked = 0;
  let presentDays = 0;
  let absentDays = 0;
  let leaveDays = 0;
  const attendanceHistory = [];

  Object.entries(attendance).forEach(([dateStr, dayRecords]) => {
    const status = dayRecords[student.id];
    if (status) {
      totalMarked++;
      if (status === 'present') presentDays++;
      if (status === 'absent') absentDays++;
      if (status === 'leave') leaveDays++;
      attendanceHistory.push({ date: dateStr, status });
    }
  });

  attendanceHistory.sort((a, b) => new Date(b.date) - new Date(a.date));

  const attendancePercent = totalMarked > 0 ? Math.round((presentDays / totalMarked) * 100) : 100;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-3 sm:p-4 bg-black/60 backdrop-blur-xs overflow-hidden">
      <div className="bg-card border border-border rounded-2xl w-full max-w-4xl shadow-2xl overflow-hidden my-auto animate-in fade-in zoom-in-95 duration-200 flex flex-col h-[88vh] max-h-[88vh]">
        {/* Header Hero */}
        <div className="relative bg-gradient-to-r from-primary via-indigo-900 to-indigo-950 p-6 text-white flex-shrink-0">

          <div className="flex flex-col sm:flex-row items-center sm:items-start gap-5">
            <div className="w-20 h-20 rounded-2xl bg-white/10 border-2 border-white/20 overflow-hidden flex items-center justify-center text-white font-bold text-2xl flex-shrink-0 shadow-lg">
              {student.photoPath || student.photoUrl ? (
                <img
                  src={student.photoPath || student.photoUrl}
                  alt={student.name}
                  className="w-full h-full object-cover"
                  onError={(e) => { e.currentTarget.style.display = 'none'; }}
                />
              ) : (
                student.name?.charAt(0) || 'S'
              )}
            </div>

            <div className="flex-1 text-center sm:text-left space-y-1">
              <div className="flex flex-wrap items-center justify-center sm:justify-start gap-2">
                <h3 className="text-xl lg:text-2xl font-black text-white">{student.name}</h3>
                <span className="px-2.5 py-0.5 rounded-full text-[10px] font-bold uppercase tracking-wider bg-amber-400 text-slate-950">
                  {student.studentType === 'school' ? 'School' : 'Computer Institute'}
                </span>
                <span className="px-2.5 py-0.5 rounded-full text-[10px] font-bold uppercase tracking-wider bg-emerald-500/20 text-emerald-300 border border-emerald-500/30">
                  {student.status || 'Active'}
                </span>
              </div>

              <p className="text-xs text-indigo-200">
                {student.studentType === 'school' 
                  ? `Class ${student.className || ''}${student.section ? ` - ${student.section}` : ''} • Roll No: ${student.rollNumber || 'N/A'}`
                  : `${student.course || ''} • Batch: ${student.batch || 'General'}`}
              </p>

              <div className="flex flex-wrap items-center justify-center sm:justify-start gap-4 text-xs text-indigo-200/80 pt-1">
                <span>Student ID: <strong className="text-white">{student.studentId}</strong></span>
                <span>Admission No: <strong className="text-white">{student.admissionNumber}</strong></span>
                <span>Mobile: <strong className="text-white">{student.mobile}</strong></span>
              </div>
            </div>

            {/* Top Quick Actions */}
            <div className="flex items-center gap-2 flex-shrink-0">
              <button
                onClick={() => setActiveTab('reports')}
                className="px-3 py-2 rounded-xl bg-amber-400 hover:bg-amber-500 text-slate-950 font-black text-xs shadow-md transition-all cursor-pointer flex items-center gap-1.5 active:scale-95"
                title="Download / Share Full Student Statement & Reports"
              >
                <FileText className="w-4 h-4 text-slate-950" />
                <span className="inline">Full Report</span>
              </button>

              <button
                onClick={() => openWhatsAppFeeReminder(student, settings)}
                className="p-2.5 rounded-xl bg-emerald-500 hover:bg-emerald-600 text-white font-bold shadow-md transition-all cursor-pointer"
                title="Send WhatsApp Message"
              >
                <MessageSquare className="w-4 h-4" />
              </button>

              <button
                onClick={() => {
                  setEditingStudent(student);
                  setIsAddStudentOpen(true);
                  onClose();
                }}
                className="p-2.5 rounded-xl bg-white/10 hover:bg-white/20 text-white transition-all cursor-pointer"
                title="Edit Student"
              >
                <Edit className="w-4 h-4" />
              </button>

              <button
                onClick={() => {
                  if (window.confirm(`Are you sure you want to delete ${student.name}?`)) {
                    deleteStudent(student.id);
                    onClose();
                  }
                }}
                className="p-2.5 rounded-xl bg-rose-500/20 hover:bg-rose-500 text-rose-300 hover:text-white transition-all cursor-pointer"
                title="Delete Student"
              >
                <Trash2 className="w-4 h-4" />
              </button>

              <div className="w-px h-6 bg-white/20 mx-1" />

              <button
                onClick={onClose}
                className="p-2.5 rounded-xl bg-white/15 hover:bg-white/30 text-white transition-all cursor-pointer"
                title="Close"
              >
                <X className="w-4 h-4" />
              </button>
            </div>
          </div>

          {/* Navigation Tabs */}
          <div className="flex items-center gap-2 mt-6 border-t border-white/10 pt-3 overflow-x-auto custom-scrollbar">
            {[
              { id: 'overview', label: 'Overview', icon: User },
              { id: 'fees', label: `Fees (₹${realPendingDue.toLocaleString('en-IN')} Due)`, icon: CreditCard },
              { id: 'attendance', label: `Attendance (${attendancePercent}%)`, icon: Calendar },
              { id: 'results', label: `Exam Results (${studentResults.length})`, icon: Award },
              { id: 'reports', label: 'Full Report & Statement', icon: FileText },
              { id: 'idcard', label: 'ID Card', icon: Contact },
              { id: 'admitcard', label: 'Admit Card', icon: FileCheck },
            ].map(tab => {
              const Icon = tab.icon;
              const isActive = activeTab === tab.id;
              return (
                <button
                  key={tab.id}
                  onClick={() => setActiveTab(tab.id)}
                  className={`px-3.5 py-1.5 rounded-xl text-xs font-bold transition-all cursor-pointer whitespace-nowrap flex items-center gap-1.5 ${
                    isActive 
                      ? 'bg-white text-slate-900 shadow-md' 
                      : 'text-indigo-200 hover:text-white hover:bg-white/10'
                  }`}
                >
                  <Icon className="w-3.5 h-3.5" />
                  <span>{tab.label}</span>
                </button>
              );
            })}
          </div>
        </div>

        {/* Tab Contents */}
        <div className="p-6 overflow-y-auto flex-1 custom-scrollbar">
          {/* TAB 1: OVERVIEW (Purely Personal & Academic Details) */}
          {activeTab === 'overview' && (
            <div className="space-y-6">

              {/* Personal & Academic Details Grid */}
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div className="p-4 rounded-xl bg-surface2/40 border border-border space-y-3">
                  <h4 className="text-xs font-bold text-text uppercase tracking-wider">Personal Particulars</h4>
                  <div className="space-y-2 text-xs">
                    <div className="flex justify-between py-1 border-b border-border/50">
                      <span className="text-text-secondary">Father's Name</span>
                      <span className="font-semibold text-text">{student.fatherName || '—'}</span>
                    </div>
                    <div className="flex justify-between py-1 border-b border-border/50">
                      <span className="text-text-secondary">Mother's Name</span>
                      <span className="font-semibold text-text">{student.motherName || '—'}</span>
                    </div>
                    <div className="flex justify-between py-1 border-b border-border/50">
                      <span className="text-text-secondary">Date of Birth</span>
                      <span className="font-semibold text-text">{student.dob || '—'}</span>
                    </div>
                    <div className="flex justify-between py-1 border-b border-border/50">
                      <span className="text-text-secondary">Gender</span>
                      <span className="font-semibold text-text">{student.gender || '—'}</span>
                    </div>
                    <div className="flex justify-between py-1 border-b border-border/50">
                      <span className="text-text-secondary">Aadhaar / Document ID</span>
                      <span className="font-semibold text-text font-mono">{student.aadhaarNumber || student.aadharNumber || '—'}</span>
                    </div>
                    <div className="flex justify-between py-1">
                      <span className="text-text-secondary">Address</span>
                      <span className="font-semibold text-text text-right max-w-xs">{student.address || '—'}</span>
                    </div>
                  </div>
                </div>

                <div className="p-4 rounded-xl bg-surface2/40 border border-border space-y-3">
                  <h4 className="text-xs font-bold text-text uppercase tracking-wider">Academic Particulars</h4>
                  <div className="space-y-2 text-xs">
                    <div className="flex justify-between py-1 border-b border-border/50">
                      <span className="text-text-secondary">Enrollment Type</span>
                      <span className="font-semibold text-text capitalize">{student.studentType}</span>
                    </div>
                    {student.studentType === 'school' ? (
                      <>
                        <div className="flex justify-between py-1 border-b border-border/50">
                          <span className="text-text-secondary">Class & Section</span>
                          <span className="font-semibold text-text">Class {student.className} ({student.section || 'A'})</span>
                        </div>
                        <div className="flex justify-between py-1 border-b border-border/50">
                          <span className="text-text-secondary">Roll Number</span>
                          <span className="font-semibold text-text">{student.rollNumber || '—'}</span>
                        </div>
                      </>
                    ) : (
                      <>
                        <div className="flex justify-between py-1 border-b border-border/50">
                          <span className="text-text-secondary">Course Name</span>
                          <span className="font-semibold text-text">{student.course}</span>
                        </div>
                        <div className="flex justify-between py-1 border-b border-border/50">
                          <span className="text-text-secondary">Batch Schedule</span>
                          <span className="font-semibold text-text">{student.batch || '—'}</span>
                        </div>
                        <div className="flex justify-between py-1 border-b border-border/50">
                          <span className="text-text-secondary">Duration</span>
                          <span className="font-semibold text-text">{student.courseDurationMonths || 6} Months</span>
                        </div>
                      </>
                    )}
                    <div className="flex justify-between py-1 border-b border-border/50">
                      <span className="text-text-secondary">Academic Session</span>
                      <span className="font-semibold text-text">{student.session || '2026-27'}</span>
                    </div>
                    <div className="flex justify-between py-1">
                      <span className="text-text-secondary">Admission Date</span>
                      <span className="font-semibold text-text">{student.admissionDate || '—'}</span>
                    </div>
                  </div>
                </div>
              </div>

              {/* Identity & Aadhaar Card Official Document Card */}
              {(() => {
                const aadhaarDoc = student.aadhaarDocUrl || student.aadhaarDocPath || student.aadhaarCardUrl;
                return (
                  <div className="p-4 rounded-xl bg-surface2/50 border border-border space-y-3">
                    <div className="flex flex-wrap items-center justify-between gap-2 pb-2 border-b border-border/50">
                      <div className="flex items-center gap-2">
                        <FileCheck className="w-4 h-4 text-emerald-600" />
                        <h4 className="text-xs font-bold text-text uppercase tracking-wider">
                          Official Aadhaar & Verification Document
                        </h4>
                      </div>
                      <span className="text-[10px] text-text-muted">
                        UIDAI Identification: <strong className="text-text font-mono">{student.aadhaarNumber || student.aadharNumber || 'Not Linked'}</strong>
                      </span>
                    </div>

                    <div className="flex flex-col sm:flex-row items-center justify-between gap-4 bg-card p-3 rounded-xl border border-border">
                      <div className="flex items-center gap-3 w-full sm:w-auto">
                        {aadhaarDoc ? (
                          <div 
                            onClick={() => setPreviewAadhaarModal(true)}
                            className="relative w-24 h-16 rounded-lg overflow-hidden border border-border bg-slate-900 cursor-pointer group flex-shrink-0 shadow-sm"
                            title="Click to view full Aadhaar document"
                          >
                            <img
                              src={aadhaarDoc}
                              alt="Aadhaar Card"
                              className="w-full h-full object-cover group-hover:scale-105 transition-transform"
                            />
                            <div className="absolute inset-0 bg-black/40 opacity-0 group-hover:opacity-100 flex items-center justify-center text-white text-[10px] font-bold transition-opacity">
                              <Eye className="w-4 h-4" />
                            </div>
                          </div>
                        ) : (
                          <div className="w-24 h-16 rounded-lg bg-surface2 border border-dashed border-border flex flex-col items-center justify-center text-text-muted flex-shrink-0">
                            <FileText className="w-5 h-5 text-text-muted/60" />
                            <span className="text-[9px] font-bold mt-1">No Photo</span>
                          </div>
                        )}

                        <div>
                          <div className="font-bold text-xs text-text flex items-center gap-1.5">
                            <span>Aadhaar Card Photo</span>
                            {aadhaarDoc ? (
                              <span className="px-1.5 py-0.5 rounded text-[9px] font-bold bg-emerald-500/10 text-emerald-600 uppercase">
                                Verified Attachment
                              </span>
                            ) : (
                              <span className="px-1.5 py-0.5 rounded text-[9px] font-bold bg-amber-500/10 text-amber-600 uppercase">
                                Not Uploaded
                              </span>
                            )}
                          </div>
                          <span className="text-[11px] text-text-muted block mt-0.5">
                            {aadhaarDoc 
                              ? 'Original copy stored securely for official student records.'
                              : 'Upload student Aadhaar card photo from Edit Student.'}
                          </span>
                        </div>
                      </div>

                      <div className="flex items-center gap-2 w-full sm:w-auto justify-end">
                        {aadhaarDoc && (
                          <button
                            type="button"
                            onClick={() => setPreviewAadhaarModal(true)}
                            className="px-3 py-1.5 rounded-xl bg-emerald-600 hover:bg-emerald-700 text-white text-xs font-bold flex items-center gap-1.5 cursor-pointer shadow-xs transition-colors"
                          >
                            <Eye className="w-3.5 h-3.5" />
                            <span>View Full Card</span>
                          </button>
                        )}
                        <button
                          type="button"
                          onClick={() => {
                            setEditingStudent(student);
                            setIsAddStudentOpen(true);
                            onClose();
                          }}
                          className="px-3 py-1.5 rounded-xl bg-surface2 hover:bg-surface2/80 text-text text-xs font-bold flex items-center gap-1.5 cursor-pointer border border-border transition-colors"
                        >
                          <Edit className="w-3.5 h-3.5" />
                          <span>{aadhaarDoc ? 'Update Card' : 'Upload Card'}</span>
                        </button>
                      </div>
                    </div>
                  </div>
                );
              })()}
            </div>
          )}

          {/* TAB 2: FEES */}
          {activeTab === 'fees' && (
            <div className="space-y-5">
              {/* Fee Financial Metrics Cards */}
              <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
                <div className="p-3.5 rounded-xl bg-surface2/60 border border-border">
                  <span className="text-[10px] font-bold text-text-secondary uppercase">Total Fees Demand</span>
                  <div className="text-base font-black text-text mt-0.5">₹{totalExpectedFees.toLocaleString('en-IN')}</div>
                </div>

                <div className="p-3.5 rounded-xl bg-emerald-500/10 border border-emerald-500/20">
                  <span className="text-[10px] font-bold text-emerald-600 uppercase">Total Paid</span>
                  <div className="text-base font-black text-emerald-600 mt-0.5">₹{realPaidFees.toLocaleString('en-IN')}</div>
                </div>

                <div className="p-3.5 rounded-xl bg-rose-500/10 border border-rose-500/20">
                  <span className="text-[10px] font-bold text-rose-600 uppercase">Balance Due</span>
                  <div className="text-base font-black text-rose-600 mt-0.5">₹{realPendingDue.toLocaleString('en-IN')}</div>
                </div>

                <div className="p-3.5 rounded-xl bg-surface2/60 border border-border">
                  <span className="text-[10px] font-bold text-text-secondary uppercase">Monthly Tuition</span>
                  <div className="text-base font-black text-text mt-0.5">
                    ₹{monthlyTuition.toLocaleString('en-IN')}
                    <span className="text-[10px] text-text-muted font-normal"> /mo (Due: {feeDueDay}th)</span>
                  </div>
                </div>
              </div>

              <div className="flex items-center justify-between pt-1">
                <div>
                  <h4 className="text-xs font-bold text-text uppercase tracking-wider">Payment Receipts & History</h4>
                  <p className="text-[11px] text-text-secondary">Official voucher history with instant WhatsApp share & PDF download</p>
                </div>
                <button
                  type="button"
                  onClick={() => {
                    setIsFeeDetailSelectorOpen(false);
                    setFeeDetailStudent(student);
                  }}
                  className="px-3.5 py-1.5 rounded-xl bg-primary hover:bg-primary-dark text-white font-bold text-xs shadow-sm flex items-center gap-1.5 cursor-pointer transition-colors"
                >
                  <Plus className="w-3.5 h-3.5" />
                  <span>Collect Payment</span>
                </button>
              </div>

              {studentPayments.length === 0 ? (
                <div className="p-8 text-center bg-surface2/30 rounded-xl border border-dashed border-border text-text-muted text-xs">
                  No payment transactions recorded yet.
                </div>
              ) : (
                <div className="divide-y divide-border border border-border rounded-xl overflow-hidden">
                  {studentPayments.map(pay => (
                    <div key={pay.id} className="p-3.5 flex items-center justify-between hover:bg-surface2/50 transition-colors">
                      <div className="flex items-center gap-3">
                        <div className="w-9 h-9 rounded-xl bg-emerald-500/10 text-emerald-600 flex items-center justify-center font-bold">
                          <Receipt className="w-4 h-4" />
                        </div>
                        <div>
                          <div className="font-bold text-xs text-text">{pay.receiptNumber}</div>
                          <div className="text-[11px] text-text-secondary">
                            {pay.feeMonth || 'Fee Payment'} • {pay.paymentMode} • {new Date(pay.paymentDate).toLocaleDateString()}
                          </div>
                        </div>
                      </div>

                      <div className="flex items-center gap-3">
                        <span className="font-black text-sm text-emerald-600">
                          ₹{pay.amount.toLocaleString('en-IN')}
                        </span>
                        <button
                          type="button"
                          onClick={() => openWhatsAppReceiptShare(pay, student, settings, payments)}
                          className="p-1.5 rounded-lg bg-emerald-50 hover:bg-emerald-100 text-emerald-700 border border-emerald-200 cursor-pointer transition-colors"
                          title="Share Receipt on WhatsApp"
                        >
                          <MessageSquare className="w-4 h-4" />
                        </button>
                        <button
                          type="button"
                          onClick={() => exportReceiptPDF(pay, student, settings, payments)}
                          className="p-1.5 rounded-lg bg-indigo-50 hover:bg-indigo-100 text-indigo-700 border border-indigo-200 cursor-pointer transition-colors"
                          title="Download Receipt PDF"
                        >
                          <Download className="w-4 h-4" />
                        </button>
                        <button
                          type="button"
                          onClick={() => setPrintReceiptData({ payment: pay, student, settings })}
                          className="p-1.5 rounded-lg bg-surface2 hover:bg-surface2/80 text-text-secondary hover:text-text cursor-pointer transition-colors"
                          title="Print Receipt Slip"
                        >
                          <Printer className="w-4 h-4" />
                        </button>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>
          )}

          {/* TAB 3: ATTENDANCE */}
          {activeTab === 'attendance' && (
            <div className="space-y-4">
              <div className="grid grid-cols-4 gap-2 text-center">
                <div className="p-3 rounded-xl bg-surface2/60 border border-border">
                  <div className="text-base font-black text-text">{totalMarked}</div>
                  <div className="text-[10px] text-text-secondary font-bold uppercase">Total Days</div>
                </div>
                <div className="p-3 rounded-xl bg-emerald-500/10 border border-emerald-500/20">
                  <div className="text-base font-black text-emerald-600">{presentDays}</div>
                  <div className="text-[10px] text-emerald-600 font-bold uppercase">Present</div>
                </div>
                <div className="p-3 rounded-xl bg-rose-500/10 border border-rose-500/20">
                  <div className="text-base font-black text-rose-600">{absentDays}</div>
                  <div className="text-[10px] text-rose-600 font-bold uppercase">Absent</div>
                </div>
                <div className="p-3 rounded-xl bg-amber-500/10 border border-amber-500/20">
                  <div className="text-base font-black text-amber-600">{leaveDays}</div>
                  <div className="text-[10px] text-amber-600 font-bold uppercase">Leave</div>
                </div>
              </div>

              <div className="border border-border rounded-xl overflow-hidden">
                <div className="px-4 py-2.5 bg-surface2/60 text-xs font-bold text-text uppercase">
                  Recent Attendance Logs
                </div>
                <div className="divide-y divide-border max-h-60 overflow-y-auto">
                  {attendanceHistory.length === 0 ? (
                    <div className="p-6 text-center text-text-muted text-xs">No attendance marked yet.</div>
                  ) : (
                    attendanceHistory.map((item, idx) => (
                      <div key={idx} className="px-4 py-2.5 flex items-center justify-between text-xs">
                        <span className="font-semibold text-text">{item.date}</span>
                        <span className={`px-2 py-0.5 rounded-md text-[10px] font-bold uppercase ${
                          item.status === 'present' 
                            ? 'bg-emerald-500/15 text-emerald-600' 
                            : item.status === 'absent' 
                            ? 'bg-rose-500/15 text-rose-600' 
                            : 'bg-amber-500/15 text-amber-600'
                        }`}>
                          {item.status}
                        </span>
                      </div>
                    ))
                  )}
                </div>
              </div>
            </div>
          )}

          {/* TAB 4: RESULTS */}
          {activeTab === 'results' && (
            <div className="space-y-4">
              <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2 pb-2 border-b border-border">
                <div>
                  <h4 className="font-extrabold text-xs text-text uppercase tracking-wider flex items-center gap-1.5">
                    <Award className="w-4 h-4 text-primary" />
                    <span>Academic Exam Results ({studentResults.length})</span>
                  </h4>
                  <p className="text-[10px] text-text-secondary">View, record, and print report cards for {student.name}</p>
                </div>
                <button
                  type="button"
                  onClick={handleOpenAddResult}
                  className="px-3.5 py-1.5 rounded-xl bg-primary hover:bg-primary-dark text-white font-bold text-xs flex items-center gap-1.5 cursor-pointer shadow-sm transition-all active:scale-95 self-start sm:self-auto"
                >
                  <Plus className="w-3.5 h-3.5" />
                  <span>Add Result</span>
                </button>
              </div>

              {studentResults.length === 0 ? (
                <div className="p-8 text-center bg-surface2/30 rounded-2xl border border-dashed border-border space-y-3">
                  <div className="w-12 h-12 rounded-2xl bg-primary/10 text-primary flex items-center justify-center mx-auto">
                    <Award className="w-6 h-6" />
                  </div>
                  <div>
                    <h5 className="font-bold text-xs text-text">No Exam Results Registered Yet</h5>
                    <p className="text-[11px] text-text-muted mt-0.5">Click the button below to add the first exam score for this student.</p>
                  </div>
                  <button
                    type="button"
                    onClick={handleOpenAddResult}
                    className="px-4 py-2 rounded-xl bg-primary hover:bg-primary-dark text-white font-bold text-xs inline-flex items-center gap-1.5 cursor-pointer shadow-sm transition-all active:scale-95"
                  >
                    <Plus className="w-3.5 h-3.5" />
                    <span>Add First Result</span>
                  </button>
                </div>
              ) : (
                studentResults.map(res => {
                  const total = res.subjects.reduce((sum, s) => sum + Number(s.totalMarks || 100), 0);
                  const obt = res.subjects.reduce((sum, s) => sum + Number(s.marks || 0), 0);
                  const pct = total > 0 ? Math.round((obt / total) * 100) : 0;
                  const passCriteria = Number(res.passingMarks || 33);
                  const failedSubs = (res.subjects || []).filter(sub => {
                    const sMax = Number(sub.totalMarks) || 100;
                    const sObt = Number(sub.marks) || 0;
                    const minP = sub.passingMarks != null ? Number(sub.passingMarks) : Math.round(sMax * (passCriteria / 100));
                    return sObt < minP;
                  });
                  const failCount = failedSubs.length;
                  let finalStatus = 'PASS';
                  if (res.status === 'PROMOTED') finalStatus = 'PROMOTED';
                  else if (failCount > 0 || pct < passCriteria || res.status === 'FAIL') finalStatus = 'FAIL';
                  else finalStatus = 'PASS';
                  const grade = pct >= 90 ? 'A+' : pct >= 75 ? 'A' : pct >= 60 ? 'B' : pct >= 45 ? 'C' : pct >= 33 ? 'D' : 'F';
                  return (
                    <div key={res.id} className="p-4 rounded-xl bg-surface2/40 border border-border space-y-3 hover:border-primary/40 transition-all">
                      <div className="flex items-center justify-between border-b border-border pb-2.5">
                        <div>
                          <h5 className="font-bold text-xs text-text">{res.examName}</h5>
                          <span className="text-[10px] text-text-secondary">
                            {new Date(res.createdAt || Date.now()).toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric' })}
                          </span>
                        </div>
                        <div className="flex items-center gap-3">
                          <div className="text-right">
                            <span className="text-xs font-black text-primary">{pct}% ({grade})</span>
                            <div className={`text-[10px] font-bold ${finalStatus === 'PROMOTED' ? 'text-amber-600' : finalStatus === 'PASS' ? 'text-emerald-600' : 'text-rose-600'}`}>
                              {finalStatus === 'PROMOTED' ? 'Promoted' : finalStatus === 'PASS' ? 'Passed' : `Failed (${failCount} Subj)`}
                            </div>
                          </div>
                          <div className="flex items-center gap-1 pl-2 border-l border-border">
                            <button
                              type="button"
                              onClick={() => setPrintResultData({ result: res, student, settings })}
                              className="p-1.5 rounded-lg bg-surface2 hover:bg-surface2/80 text-text-secondary hover:text-text cursor-pointer transition-colors"
                              title="Print Result Slip"
                            >
                              <Printer className="w-3.5 h-3.5" />
                            </button>
                            <button
                              type="button"
                              onClick={() => handleOpenEditResult(res)}
                              className="p-1.5 rounded-lg bg-surface2 hover:bg-surface2/80 text-text-secondary hover:text-text cursor-pointer transition-colors"
                              title="Edit Result"
                            >
                              <Edit className="w-3.5 h-3.5" />
                            </button>
                            <button
                              type="button"
                              onClick={() => handleDeleteResult(res.id)}
                              className="p-1.5 rounded-lg bg-rose-50 hover:bg-rose-100 text-rose-600 cursor-pointer transition-colors"
                              title="Delete Result"
                            >
                              <Trash2 className="w-3.5 h-3.5" />
                            </button>
                          </div>
                        </div>
                      </div>

                      <div className="grid grid-cols-2 sm:grid-cols-3 gap-2">
                        {res.subjects.map((sub, i) => (
                          <div key={i} className="p-2 rounded-lg bg-card border border-border text-xs flex justify-between items-center">
                            <span className="text-text-secondary truncate">{sub.subjectName}</span>
                            <span className="font-bold text-text">{sub.marks}/{sub.totalMarks || 100}</span>
                          </div>
                        ))}
                      </div>
                    </div>
                  );
                })
              )}
            </div>
          )}

          {/* TAB 5: COMPREHENSIVE FULL REPORTS & STATEMENTS */}
          {activeTab === 'reports' && (() => {
            const now = new Date();
            const thisMonthStr = now.toISOString().slice(0, 7);
            const prevMonthDate = new Date(now.getFullYear(), now.getMonth() - 1, 1);
            const lastMonthStr = prevMonthDate.toISOString().slice(0, 7);

            // Compute filtered metrics for live preview
            const filteredPaymentsList = reportMonthFilter === 'all'
              ? studentPayments
              : studentPayments.filter(p => String(p.date || p.paymentDate || p.createdAt || '').startsWith(reportMonthFilter));

            const filteredAttEntries = Object.entries(attendance).filter(([dateStr]) => 
              reportMonthFilter === 'all' ? true : dateStr.startsWith(reportMonthFilter)
            );

            let periodMarked = 0, periodPresent = 0, periodAbsent = 0, periodLeave = 0;
            filteredAttEntries.forEach(([_, rec]) => {
              const st = typeof rec === 'object' ? rec[student.id] : rec;
              if (st) {
                periodMarked++;
                if (st === 'present') periodPresent++;
                if (st === 'absent') periodAbsent++;
                if (st === 'leave') periodLeave++;
              }
            });
            const periodAttPct = periodMarked > 0 ? ((periodPresent / periodMarked) * 100).toFixed(1) : '0.0';

            const filteredResultsList = reportMonthFilter === 'all'
              ? studentResults
              : studentResults.filter(r => {
                  const d = r.date || r.examDate || r.createdAt || '';
                  return d ? String(d).startsWith(reportMonthFilter) : true;
                });

            const periodPaidAmt = filteredPaymentsList.reduce((acc, p) => acc + (Number(p.amount) || 0), 0);

            return (
              <div className="space-y-6">
                {/* Header Banner */}
                <div className="p-4 sm:p-5 rounded-2xl bg-gradient-to-r from-indigo-900/90 via-primary/85 to-indigo-950 text-white shadow-lg space-y-2 border border-white/10">
                  <div className="flex items-center gap-2">
                    <span className="p-2 rounded-xl bg-amber-400 text-slate-950">
                      <FileText className="w-5 h-5" />
                    </span>
                    <div>
                      <h4 className="font-black text-sm sm:text-base text-white">Comprehensive Student Master Report & Statement</h4>
                      <p className="text-[11px] text-indigo-200">
                        Generate official paper PDF statements, structured multi-sheet Excel files, or send via WhatsApp.
                      </p>
                    </div>
                  </div>
                </div>

                {/* Filter Controls Card */}
                <div className="p-4 rounded-xl bg-surface2/50 border border-border space-y-3">
                  <div className="flex flex-wrap items-center justify-between gap-2">
                    <div className="flex items-center gap-2">
                      <Filter className="w-4 h-4 text-primary" />
                      <span className="text-xs font-bold text-text">Statement Period Filter:</span>
                    </div>

                    <div className="flex items-center gap-2">
                      <span className="text-[11px] text-text-secondary font-medium">Custom Month:</span>
                      <input
                        type="month"
                        value={reportMonthFilter === 'all' ? '' : reportMonthFilter}
                        onChange={(e) => setReportMonthFilter(e.target.value || 'all')}
                        className="px-2.5 py-1 rounded-lg bg-surface border border-border text-xs font-bold text-text cursor-pointer focus:ring-1 focus:ring-primary"
                      />
                    </div>
                  </div>

                  {/* Quick Filter Buttons */}
                  <div className="flex flex-wrap items-center gap-2 pt-1">
                    <button
                      type="button"
                      onClick={() => setReportMonthFilter('all')}
                      className={`px-3 py-1.5 rounded-lg text-xs font-bold transition-all cursor-pointer ${
                        reportMonthFilter === 'all'
                          ? 'bg-primary text-white shadow-sm'
                          : 'bg-surface2 hover:bg-border text-text'
                      }`}
                    >
                      All Time (Till Date)
                    </button>
                    <button
                      type="button"
                      onClick={() => setReportMonthFilter(thisMonthStr)}
                      className={`px-3 py-1.5 rounded-lg text-xs font-bold transition-all cursor-pointer ${
                        reportMonthFilter === thisMonthStr
                          ? 'bg-primary text-white shadow-sm'
                          : 'bg-surface2 hover:bg-border text-text'
                      }`}
                    >
                      This Month ({now.toLocaleDateString('en-US', { month: 'short' })})
                    </button>
                    <button
                      type="button"
                      onClick={() => setReportMonthFilter(lastMonthStr)}
                      className={`px-3 py-1.5 rounded-lg text-xs font-bold transition-all cursor-pointer ${
                        reportMonthFilter === lastMonthStr
                          ? 'bg-primary text-white shadow-sm'
                          : 'bg-surface2 hover:bg-border text-text'
                      }`}
                    >
                      Last Month ({prevMonthDate.toLocaleDateString('en-US', { month: 'short' })})
                    </button>

                    <span className="text-xs text-primary font-bold ml-auto px-2 py-1 rounded bg-primary/10">
                      {reportMonthFilter === 'all'
                        ? 'Showing: Lifetime Full Record'
                        : `Showing: Month ${reportMonthFilter}`}
                    </span>
                  </div>
                </div>

                {/* Primary Action Buttons */}
                <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
                  <button
                    onClick={async () => {
                      await exportStudentFullReportPDF(student, studentPayments, attendance, studentResults, settings, reportMonthFilter);
                      showToast(`Downloaded full report PDF for ${student.name}!`, 'success');
                    }}
                    className="p-3.5 rounded-xl bg-emerald-600 hover:bg-emerald-700 text-white font-bold text-xs flex flex-col items-center justify-center gap-1.5 cursor-pointer shadow-md transition-all active:scale-95 text-center"
                    title="Download Official A4 Statement as PDF"
                  >
                    <Download className="w-5 h-5" />
                    <span>Download PDF</span>
                  </button>

                  <button
                    onClick={async () => {
                      await printStudentFullReportPDF(student, studentPayments, attendance, studentResults, settings, reportMonthFilter);
                    }}
                    className="p-3.5 rounded-xl bg-primary hover:bg-primary-dark text-white font-bold text-xs flex flex-col items-center justify-center gap-1.5 cursor-pointer shadow-md transition-all active:scale-95 text-center"
                    title="Print Statement Preview"
                  >
                    <Printer className="w-5 h-5" />
                    <span>Print Statement</span>
                  </button>

                  <button
                    onClick={() => {
                      exportStudentFullReportExcel(student, studentPayments, attendance, studentResults, settings, reportMonthFilter);
                      showToast(`Exported full report Excel (.xlsx) for ${student.name}!`, 'success');
                    }}
                    className="p-3.5 rounded-xl bg-teal-600 hover:bg-teal-700 text-white font-bold text-xs flex flex-col items-center justify-center gap-1.5 cursor-pointer shadow-md transition-all active:scale-95 text-center"
                    title="Export Multi-Sheet Excel Workbook"
                  >
                    <FileSpreadsheet className="w-5 h-5" />
                    <span>Export Excel (.xlsx)</span>
                  </button>

                  <button
                    onClick={() => {
                      openWhatsAppStudentFullReport(student, studentPayments, attendance, studentResults, settings, reportMonthFilter);
                    }}
                    className="p-3.5 rounded-xl bg-green-600 hover:bg-green-700 text-white font-bold text-xs flex flex-col items-center justify-center gap-1.5 cursor-pointer shadow-md transition-all active:scale-95 text-center"
                    title="Send Formatted Summary via WhatsApp"
                  >
                    <MessageSquare className="w-5 h-5" />
                    <span>Share WhatsApp</span>
                  </button>
                </div>

                {/* Live Data Summary Cards for the Selected Period */}
                <div className="grid grid-cols-1 md:grid-cols-3 gap-3 text-xs">
                  {/* Fee Metric */}
                  <div className="p-3.5 rounded-xl bg-surface2/40 border border-border space-y-1.5">
                    <div className="flex items-center justify-between text-text-secondary">
                      <span className="font-bold uppercase tracking-wider text-[10px]">Fee Standing</span>
                      <CreditCard className="w-3.5 h-3.5 text-primary" />
                    </div>
                    <div className="text-base font-black text-text">
                      ₹{periodPaidAmt.toLocaleString('en-IN')}
                      <span className="text-[10px] text-text-secondary font-medium ml-1">Paid in Period</span>
                    </div>
                    <div className="flex justify-between text-[11px] pt-1 border-t border-border/50 text-text-muted">
                      <span>Total Due: <strong className="text-rose-600">₹{realPendingDue.toLocaleString('en-IN')}</strong></span>
                      <span>Receipts: <strong>{filteredPaymentsList.length}</strong></span>
                    </div>
                  </div>

                  {/* Attendance Metric */}
                  <div className="p-3.5 rounded-xl bg-surface2/40 border border-border space-y-1.5">
                    <div className="flex items-center justify-between text-text-secondary">
                      <span className="font-bold uppercase tracking-wider text-[10px]">Attendance Rate</span>
                      <Calendar className="w-3.5 h-3.5 text-emerald-600" />
                    </div>
                    <div className="text-base font-black text-emerald-600">
                      {periodAttPct}%
                      <span className="text-[10px] text-text-secondary font-medium ml-1">Present Rate</span>
                    </div>
                    <div className="flex justify-between text-[11px] pt-1 border-t border-border/50 text-text-muted">
                      <span>Marked: <strong>{periodMarked} Days</strong></span>
                      <span>Present: <strong className="text-emerald-700">{periodPresent}</strong></span>
                    </div>
                  </div>

                  {/* Academic Results Metric */}
                  <div className="p-3.5 rounded-xl bg-surface2/40 border border-border space-y-1.5">
                    <div className="flex items-center justify-between text-text-secondary">
                      <span className="font-bold uppercase tracking-wider text-[10px]">Exams Record</span>
                      <Award className="w-3.5 h-3.5 text-amber-500" />
                    </div>
                    <div className="text-base font-black text-text">
                      {filteredResultsList.length}
                      <span className="text-[10px] text-text-secondary font-medium ml-1">Examinations</span>
                    </div>
                    <div className="flex justify-between text-[11px] pt-1 border-t border-border/50 text-text-muted">
                      <span>Status: <strong className="text-primary font-bold">Recorded</strong></span>
                      <span>Latest: <strong>{filteredResultsList[filteredResultsList.length - 1]?.examName || '—'}</strong></span>
                    </div>
                  </div>
                </div>

                {/* Transactions in Period */}
                <div className="border border-border rounded-xl overflow-hidden bg-surface">
                  <div className="px-4 py-2.5 bg-surface2/60 text-xs font-bold text-text uppercase flex items-center justify-between">
                    <span>Period Fee Payment Transactions ({filteredPaymentsList.length})</span>
                    <span className="text-[10px] text-text-muted font-normal">Shows in official statement</span>
                  </div>
                  <div className="divide-y divide-border max-h-60 overflow-y-auto">
                    {filteredPaymentsList.length === 0 ? (
                      <div className="p-6 text-center text-text-muted text-xs">
                        No payments recorded for the selected filter period.
                      </div>
                    ) : (
                      filteredPaymentsList.map((p, idx) => (
                        <div key={idx} className="px-4 py-2.5 flex items-center justify-between text-xs hover:bg-surface2/20">
                          <div>
                            <span className="font-bold text-text block">{p.receiptNumber || 'REC-' + (p.id || '').slice(0, 6)}</span>
                            <span className="text-[10px] text-text-secondary">{p.date || p.paymentDate || '—'} • {p.mode || 'Cash'}</span>
                          </div>
                          <div className="text-right">
                            <span className="font-black text-emerald-600 block">₹{Number(p.amount || 0).toLocaleString('en-IN')}</span>
                            <span className="text-[10px] text-text-muted">{p.remarks || p.forMonth || 'Fee Payment'}</span>
                          </div>
                        </div>
                      ))
                    )}
                  </div>
                </div>
              </div>
            );
          })()}

          {/* TAB 6: ID CARD */}
          {activeTab === 'idcard' && (
            <div className="flex flex-col items-center justify-center p-6 space-y-4">
              {/* Card Preview */}
              <div className="w-80 rounded-2xl bg-gradient-to-br from-indigo-900 via-primary to-indigo-950 text-white p-4 shadow-xl border border-white/20 relative overflow-hidden">
                <div className="flex items-center justify-between border-b border-white/20 pb-2 mb-3">
                  <div>
                    <h5 className="font-black text-[11px] uppercase tracking-wider text-amber-300 truncate max-w-[180px]">
                      {settings.instituteName}
                    </h5>
                    <span className="text-[9px] text-indigo-200">STUDENT IDENTITY CARD</span>
                  </div>
                  <span className="text-[9px] font-mono bg-white/20 px-1.5 py-0.5 rounded text-white">
                    {student.session || '2026-27'}
                  </span>
                </div>

                <div className="flex gap-3 items-center">
                  <div className="w-16 h-20 rounded-xl bg-white/20 border border-white/30 overflow-hidden flex items-center justify-center text-white font-bold text-base flex-shrink-0">
                    {student.photoPath ? (
                      <img src={student.photoPath} alt={student.name} className="w-full h-full object-cover" />
                    ) : (
                      student.name?.charAt(0) || 'S'
                    )}
                  </div>

                  <div className="text-[10px] space-y-0.5 min-w-0 flex-1">
                    <div className="font-extrabold text-xs text-white truncate">{student.name}</div>
                    <div className="text-amber-200 truncate">
                      {student.studentType === 'school' ? `Class ${student.className}` : student.course}
                    </div>
                    <div className="text-indigo-200">ID: {student.studentId}</div>
                    <div className="text-indigo-200">Adm: {student.admissionNumber}</div>
                    <div className="text-indigo-200">Mob: {student.mobile}</div>
                  </div>

                  <div className="p-1 bg-white rounded-lg flex-shrink-0 shadow-xs">
                    <QRCodeSVG value={`STUDENT:${student.studentId}|NAME:${student.name}|ADM:${student.admissionNumber}`} size={46} />
                  </div>
                </div>
              </div>

              <button
                onClick={() => setPrintIdCardsData({ students: [student], settings })}
                className="px-4 py-2 rounded-xl bg-primary hover:bg-primary-dark text-white font-bold text-xs shadow-md flex items-center gap-2 cursor-pointer"
              >
                <Printer className="w-4 h-4" />
                <span>Print Official ID Card</span>
              </button>
            </div>
          )}

          {/* TAB 7: ADMIT CARD */}
          {/* TAB 7: ADMIT CARD (Dynamic Class Schedule & Official 1-Page A4 PDF) */}
          {activeTab === 'admitcard' && (() => {
            const classKey = student.className ? `school_admit_schedule_${student.className}` : 'school_admit_schedule_default';
            let studentTimetable = [
              { day: '15/03/2026', subject: 'Mathematics', timing: '09:30 AM - 12:30 PM' },
              { day: '17/03/2026', subject: 'Science', timing: '09:30 AM - 12:30 PM' },
              { day: '19/03/2026', subject: 'Social Studies', timing: '09:30 AM - 12:30 PM' },
              { day: '21/03/2026', subject: 'English', timing: '09:30 AM - 12:30 PM' },
              { day: '23/03/2026', subject: 'Hindi', timing: '09:30 AM - 12:30 PM' },
              { day: '25/03/2026', subject: 'Computer', timing: '09:30 AM - 12:30 PM' },
            ];

            if (typeof window !== 'undefined') {
              const saved = localStorage.getItem(classKey);
              if (saved) {
                try {
                  const parsed = JSON.parse(saved);
                  if (Array.isArray(parsed) && parsed.length > 0) studentTimetable = parsed;
                } catch (e) {}
              }
            }

            return (
              <div className="flex flex-col items-center justify-center p-4 space-y-4">
                <div className="w-full max-w-xl bg-card border-2 border-primary/40 rounded-2xl p-5 shadow-xl text-text-primary">
                  {/* Header */}
                  <div className="text-center border-b border-border pb-3 mb-3">
                    <h4 className="font-black text-sm uppercase text-primary tracking-wide">{settings.instituteName || 'ACADEMIC INSTITUTION'}</h4>
                    <p className="text-[11px] text-text-muted">{settings.address || 'Official Examination Hall Ticket'}</p>
                    <span className="inline-block mt-1 px-3 py-0.5 rounded-full bg-primary/10 text-primary text-[10px] font-bold">
                      ANNUAL EXAMINATION ADMIT CARD • {settings.currentSession || '2026-27'}
                    </span>
                  </div>

                  {/* Student Info Grid with QR Code */}
                  <div className="flex gap-3 text-xs bg-muted/40 p-3 rounded-xl mb-3 border border-border items-center">
                    <div className="grid grid-cols-2 gap-2 flex-1">
                      <div><span className="font-semibold text-text-muted">Student Name:</span> <span className="font-bold uppercase text-primary">{student.name}</span></div>
                      <div><span className="font-semibold text-text-muted">Roll No:</span> <span className="font-bold">{student.rollNumber || 'N/A'}</span></div>
                      <div><span className="font-semibold text-text-muted">Class & Sec:</span> <span className="font-bold">{student.className} {student.section || ''}</span></div>
                      <div><span className="font-semibold text-text-muted">Father's Name:</span> <span className="font-bold">{student.fatherName || 'N/A'}</span></div>
                      <div><span className="font-semibold text-text-muted">Admission No:</span> <span className="font-mono">{student.admissionNumber || student.studentId}</span></div>
                      <div><span className="font-semibold text-text-muted">Aadhaar No:</span> <span className="font-bold text-indigo-900 bg-indigo-50 px-1.5 py-0.5 rounded border border-indigo-200">{student.aadhaarNumber || student.aadharNumber || student.aadhaar || 'N/A'}</span></div>
                    </div>
                    <div className="p-1 bg-white border border-border rounded-lg flex flex-col items-center">
                      <img
                        src={`https://api.qrserver.com/v1/create-qr-code/?size=70x70&data=${encodeURIComponent(`STUDENT ADMIT CARD | Name: ${student.name} | Roll: ${student.rollNumber || 'N/A'} | Class: ${student.className || ''} | Aadhaar: ${student.aadhaarNumber || 'N/A'}`)}`}
                        alt="QR Code"
                        className="w-14 h-14 object-contain"
                      />
                      <span className="text-[7px] text-text-muted font-bold mt-0.5">VERIFIED</span>
                    </div>
                  </div>

                  {/* Timetable Snippet with Real Dates */}
                  <div className="mb-4">
                    <div className="flex items-center justify-between mb-1.5">
                      <h5 className="font-bold text-xs text-text-muted uppercase">Exam Schedule ({student.className ? 'Class ' + student.className : 'Standard'})</h5>
                      <span className="text-[10px] text-emerald-600 font-bold">{studentTimetable.length} Subjects Scheduled</span>
                    </div>
                    <div className="border border-border rounded-xl overflow-hidden text-xs">
                      <table className="w-full text-left">
                        <thead className="bg-muted text-[11px] font-bold text-text-muted border-b border-border">
                          <tr>
                            <th className="p-2">Exam Date</th>
                            <th className="p-2">Subject</th>
                            <th className="p-2">Timing</th>
                          </tr>
                        </thead>
                        <tbody className="divide-y divide-border">
                          {studentTimetable.map((t, idx) => (
                            <tr key={idx} className={idx % 2 === 1 ? 'bg-muted/20' : ''}>
                              <td className="p-2 font-bold text-primary">{t.day || t.date}</td>
                              <td className="p-2 font-semibold text-text">{t.subject}</td>
                              <td className="p-2 text-text-muted">{t.timing}</td>
                            </tr>
                          ))}
                        </tbody>
                      </table>
                    </div>
                  </div>

                  {/* Signatures */}
                  <div className="flex justify-between items-end pt-4 border-t border-dashed border-border text-[10px] text-text-muted">
                    <div className="text-center">
                      <div className="w-24 border-b border-border mb-1"></div>
                      <span>Candidate Sign</span>
                    </div>
                    <div className="text-center">
                      <div className="w-24 border-b border-border mb-1"></div>
                      <span>Class Teacher Sign</span>
                    </div>
                    <div className="text-center">
                      <div className="w-24 border-b border-border mb-1"></div>
                      <span className="font-bold text-text-primary">Principal Sign & Seal</span>
                    </div>
                  </div>
                </div>

                <div className="flex flex-wrap gap-3 justify-center">
                  <button
                    type="button"
                    onClick={() => exportSingleAdmitCardPDF(student, settings, studentTimetable, 'ANNUAL EXAMINATION 2026')}
                    className="px-5 py-2.5 rounded-xl bg-primary hover:bg-primary-dark text-white font-bold text-xs shadow-md flex items-center gap-2 cursor-pointer transition-all active:scale-95"
                  >
                    <Download className="w-4 h-4" />
                    <span>Download Official Admit Card (A4 PDF)</span>
                  </button>
                  <button
                    type="button"
                    onClick={() => window.print()}
                    className="px-4 py-2.5 rounded-xl bg-surface2 hover:bg-surface2/80 text-text font-bold text-xs border border-border shadow-xs flex items-center gap-2 cursor-pointer transition-all"
                  >
                    <Printer className="w-4 h-4" />
                    <span>Print Browser Slip</span>
                  </button>
                </div>
              </div>
            );
          })()}
        </div>
      </div>

      {/* Add / Edit Exam Result Modal for this student */}
      {isAddResultOpen && (
        <div className="fixed inset-0 z-60 bg-black/60 backdrop-blur-xs flex items-center justify-center p-3 sm:p-4 overflow-y-auto animate-in fade-in duration-150">
          <div className="bg-card border border-border w-full max-w-lg rounded-2xl p-5 sm:p-6 shadow-2xl space-y-4 my-auto animate-in zoom-in-95 duration-200">
            <div className="flex items-center justify-between border-b border-border pb-3">
              <div>
                <h3 className="font-extrabold text-sm sm:text-base text-text flex items-center gap-2">
                  <Award className="w-4 h-4 text-primary" />
                  <span>{editingResultItem ? 'Edit Exam Result' : 'Add Exam Result'}</span>
                </h3>
                <p className="text-[11px] text-text-muted mt-0.5">
                  Recording score for <strong className="text-text font-bold">{student.name}</strong> ({student.studentType === 'school' ? `Class ${student.className}` : student.course})
                </p>
              </div>
              <button
                type="button"
                onClick={() => { setIsAddResultOpen(false); setEditingResultItem(null); }}
                className="p-1.5 rounded-lg hover:bg-surface2 text-text-secondary hover:text-text cursor-pointer transition-colors"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <form onSubmit={handleSaveResultSubmit} className="space-y-4 text-xs font-semibold">
              <div>
                <label className="block text-text-secondary mb-1">Exam Name</label>
                <input
                  type="text"
                  value={resultExamName}
                  onChange={e => setResultExamName(e.target.value)}
                  className="w-full px-3 py-2 rounded-xl bg-surface2 border border-border text-text font-bold text-xs focus:ring-2 focus:ring-primary/20"
                  placeholder="e.g. 1st Unit Test, Mid-Term Exam, Annual Exam"
                  required
                />
                <div className="flex items-center gap-1.5 mt-1.5 flex-wrap">
                  {['1st Unit Test', 'Mid-Term Exam', 'Term Examination', 'Annual Exam'].map(examTag => (
                    <button
                      key={examTag}
                      type="button"
                      onClick={() => setResultExamName(examTag)}
                      className="px-2 py-0.5 rounded-md text-[10px] bg-surface2 hover:bg-surface2/80 text-text-secondary hover:text-text border border-border cursor-pointer transition-colors"
                    >
                      {examTag}
                    </button>
                  ))}
                </div>
              </div>

              <div className="space-y-2">
                <div className="flex items-center justify-between">
                  <label className="text-text-secondary font-bold">Subjects & Marks</label>
                  <button
                    type="button"
                    onClick={handleAddResultSubjectRow}
                    className="text-[11px] text-primary font-bold hover:underline cursor-pointer flex items-center gap-1"
                  >
                    <Plus className="w-3.5 h-3.5" />
                    <span>Add Subject</span>
                  </button>
                </div>

                <div className="space-y-2 max-h-56 overflow-y-auto pr-1 custom-scrollbar">
                  {resultSubjects.map((sub, idx) => (
                    <div key={idx} className="flex items-center gap-2 bg-surface2/40 p-2 rounded-xl border border-border">
                      <div className="flex-1">
                        <input
                          type="text"
                          value={sub.subjectName}
                          onChange={e => handleResultSubjectChange(idx, 'subjectName', e.target.value)}
                          placeholder="Subject Name"
                          className="w-full px-2.5 py-1.5 rounded-lg bg-white border border-border text-text font-bold text-xs"
                          required
                        />
                      </div>
                      <div className="w-20">
                        <input
                          type="number"
                          min="0"
                          value={sub.marks}
                          onChange={e => handleResultSubjectChange(idx, 'marks', e.target.value)}
                          placeholder="Marks"
                          className="w-full px-2 py-1.5 rounded-lg bg-white border border-border text-center font-mono font-bold text-text text-xs"
                          required
                        />
                      </div>
                      <span className="text-text-muted font-bold">/</span>
                      <div className="w-20">
                        <input
                          type="number"
                          min="1"
                          value={sub.totalMarks || 100}
                          onChange={e => handleResultSubjectChange(idx, 'totalMarks', Number(e.target.value) || 100)}
                          placeholder="Total"
                          className="w-full px-2 py-1.5 rounded-lg bg-white border border-border text-center font-mono font-bold text-text text-xs"
                          required
                        />
                      </div>
                      {resultSubjects.length > 1 && (
                        <button
                          type="button"
                          onClick={() => handleRemoveResultSubjectRow(idx)}
                          className="p-1 text-rose-500 hover:bg-rose-50 rounded cursor-pointer"
                          title="Remove Subject"
                        >
                          <X className="w-4 h-4" />
                        </button>
                      )}
                    </div>
                  ))}
                </div>
              </div>

              {/* Total & Percentage Live Preview */}
              {(() => {
                const totalMax = resultSubjects.reduce((acc, s) => acc + (Number(s.totalMarks) || 100), 0);
                const totalObt = resultSubjects.reduce((acc, s) => acc + (Number(s.marks) || 0), 0);
                const pct = totalMax > 0 ? Math.round((totalObt / totalMax) * 100) : 0;
                const isPassed = pct >= 33;
                return (
                  <div className="p-3 rounded-xl bg-surface2/60 border border-border flex items-center justify-between text-xs">
                    <div>
                      <span className="text-text-muted block text-[10px]">Score Summary</span>
                      <span className="font-extrabold text-text">{totalObt} / {totalMax} Marks</span>
                    </div>
                    <div className="text-right">
                      <span className="text-base font-black text-primary">{pct}%</span>
                      <span className={`block text-[10px] font-bold ${isPassed ? 'text-emerald-600' : 'text-rose-600'}`}>
                        {isPassed ? 'Passed' : 'Needs Improvement'}
                      </span>
                    </div>
                  </div>
                );
              })()}

              <div className="pt-3 border-t border-border flex items-center justify-end gap-2">
                <button
                  type="button"
                  onClick={() => { setIsAddResultOpen(false); setEditingResultItem(null); }}
                  className="px-4 py-2 rounded-xl bg-surface2 hover:bg-border text-text font-bold cursor-pointer transition-colors"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="px-5 py-2 rounded-xl bg-primary hover:bg-primary-dark text-white font-bold cursor-pointer shadow-sm transition-all active:scale-95"
                >
                  Save Result
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Full Size Student Aadhaar Document Preview Modal */}
      {previewAadhaarModal && (student.aadhaarDocUrl || student.aadhaarDocPath || student.aadhaarCardUrl) && (
        <div className="fixed inset-0 z-[70] flex items-center justify-center p-4 bg-black/85 backdrop-blur-sm animate-in fade-in duration-200">
          <div className="bg-card border border-border rounded-2xl max-w-3xl w-full p-4 overflow-hidden shadow-2xl space-y-3">
            <div className="flex items-center justify-between pb-2 border-b border-border">
              <div className="flex items-center gap-2">
                <FileCheck className="w-5 h-5 text-emerald-600" />
                <div>
                  <h4 className="font-bold text-sm text-text">
                    Aadhaar Card: {student.name}
                  </h4>
                  <span className="text-[10px] text-text-muted font-mono">
                    UIDAI No: {student.aadhaarNumber || student.aadharNumber || 'Not Linked'}
                  </span>
                </div>
              </div>
              <button
                type="button"
                onClick={() => setPreviewAadhaarModal(false)}
                className="p-1.5 rounded-lg bg-surface2 text-text-muted hover:text-text cursor-pointer transition-colors"
              >
                <X className="w-4 h-4" />
              </button>
            </div>

            <div className="max-h-[72vh] overflow-auto rounded-xl border border-border bg-slate-950 flex items-center justify-center p-3">
              <img
                src={student.aadhaarDocUrl || student.aadhaarDocPath || student.aadhaarCardUrl}
                alt="Aadhaar Card Full"
                className="max-h-[68vh] w-auto object-contain rounded-lg shadow-lg"
              />
            </div>

            <div className="flex items-center justify-between pt-2">
              <span className="text-[11px] text-text-muted">
                Student ID: <strong className="text-text font-mono">{student.studentId}</strong>
              </span>
              <div className="flex items-center gap-2">
                <a
                  href={student.aadhaarDocUrl || student.aadhaarDocPath || student.aadhaarCardUrl}
                  download={`Aadhaar_${(student.name || 'student').replace(/\s+/g, '_')}.jpg`}
                  className="px-3.5 py-1.5 rounded-xl bg-surface2 hover:bg-surface2/80 text-text text-xs font-bold flex items-center gap-1.5 cursor-pointer border border-border transition-colors"
                >
                  <Download className="w-3.5 h-3.5" />
                  <span>Download</span>
                </a>
                <button
                  type="button"
                  onClick={() => setPreviewAadhaarModal(false)}
                  className="px-4 py-1.5 rounded-xl bg-primary hover:bg-primary-dark text-white font-bold text-xs cursor-pointer transition-colors"
                >
                  Close
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
