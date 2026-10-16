'use client';

import React, { useState } from 'react';
import { useSchoolStore } from '../lib/store';
import {
  GraduationCap,
  Calendar,
  CreditCard,
  Award,
  Bell,
  Printer,
  User,
  Phone,
  MapPin,
  CheckCircle,
  XCircle,
  AlertCircle,
  Sparkles,
  LogOut,
  ArrowRight,
  Sun,
  Moon,
  ExternalLink,
  ShieldCheck,
  Heart,
  FileText,
  ChevronRight,
  BookOpen,
  Clock,
  School,
  Share2,
  CheckCircle2,
  CalendarCheck2
} from 'lucide-react';

export default function ParentPortalView() {
  const {
    currentUser,
    settings,
    students,
    payments,
    attendance,
    results,
    notices,
    setPrintReceiptData,
    setPrintResultData,
    showToast,
    logout,
    toggleTheme,
    themeMode
  } = useSchoolStore();

  const [activeTab, setActiveTab] = useState('overview'); // 'overview' | 'attendance' | 'fees' | 'results' | 'notices'
  const [selectedExamId, setSelectedExamId] = useState('all');

  // Find target student
  const student =
    students.find(
      (s) =>
        s.id === currentUser?.studentId ||
        s.admissionNo === currentUser?.admissionNumber ||
        s.admissionNumber === currentUser?.admissionNumber ||
        (currentUser?.mobile && (s.mobile === currentUser.mobile || s.parentMobile === currentUser.mobile))
    ) ||
    currentUser?.student ||
    {};

  // Filter payments for this student
  const studentPayments = payments.filter((p) => {
    if (!student) return false;
    if (p.studentId && (p.studentId === student.id || p.studentId === student.studentId)) return true;
    if (student.admissionNo && (p.admissionNumber === student.admissionNo || p.admissionNo === student.admissionNo)) return true;
    if (student.admissionNumber && (p.admissionNumber === student.admissionNumber || p.admissionNo === student.admissionNumber)) return true;
    return false;
  });

  const totalPaid = studentPayments.reduce((acc, p) => acc + (Number(p.amount) || 0), 0);
  const totalFee = Number(student.totalFees || student.totalFee || 0);
  const currentDue = Math.max(
    0,
    (Number(student.previousDue) || 0) +
      (totalFee > 0 ? totalFee - totalPaid : Number(student.remainingFees || student.totalPending || 0))
  );

  // Filter attendance for this student
  let totalMarkedDays = 0;
  let presentDays = 0;
  let absentDays = 0;
  let leaveDays = 0;
  const attLogs = [];

  Object.entries(attendance || {}).forEach(([dateStr, dayMap]) => {
    if (dayMap && student.id && dayMap[student.id]) {
      totalMarkedDays++;
      const st = dayMap[student.id];
      if (st === 'present') presentDays++;
      else if (st === 'absent') absentDays++;
      else if (st === 'leave' || st === 'late') leaveDays++;
      attLogs.push({ date: dateStr, status: st });
    }
  });
  attLogs.sort((a, b) => b.date.localeCompare(a.date));
  const attendanceRate = totalMarkedDays > 0 ? Math.round((presentDays / totalMarkedDays) * 100) : 100;

  // Filter results for this student
  const studentResults = results.filter((r) => {
    if (!student) return false;
    return (
      r.studentId === student.id ||
      r.admissionNumber === student.admissionNo ||
      r.admissionNo === student.admissionNo
    );
  });

  // Filter notices for students/parents
  const studentNotices = notices.filter((n) => {
    const aud = n.targetAudience || n.audience || 'all';
    return (
      aud === 'all' ||
      aud === 'students' ||
      aud === 'parents' ||
      (student.className && aud.toLowerCase() === student.className.toLowerCase())
    );
  });

  // School contact number
  const schoolPhone = settings?.phone || settings?.mobile || '9876543210';
  const schoolName = settings?.instituteName || settings?.schoolName || currentUser?.instituteName || 'Smart School System';

  const handleOpenWhatsApp = () => {
    const cleanPhone = schoolPhone.replace(/[^0-9]/g, '');
    const msg = encodeURIComponent(
      `Hello ${schoolName} Administration,\n\nI am the parent of ${student?.name || 'my child'} (Class ${student?.className || ''} - Sec ${student?.section || 'A'}, Admission No: ${student?.admissionNo || student?.admissionNumber || 'N/A'}).\n\nI would like to inquire about: `
    );
    window.open(`https://wa.me/91${cleanPhone}?text=${msg}`, '_blank');
  };

  return (
    <div className="min-h-screen bg-[#f4f7fb] dark:bg-[#0b1329] text-[#1c2438] dark:text-[#e2e8f0] font-sans transition-colors duration-200">
      
      {/* ── Top Navigation Header ── */}
      <header className="sticky top-0 z-40 bg-white/95 dark:bg-[#111c38]/95 backdrop-blur-md border-b border-slate-200 dark:border-slate-800 shadow-sm">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 h-16 flex items-center justify-between gap-4">
          
          {/* Brand Info */}
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-[#1f108e] to-[#3b4ef8] flex items-center justify-center text-white shadow-md shadow-indigo-500/20">
              <School className="w-5 h-5" />
            </div>
            <div>
              <div className="flex items-center gap-2">
                <h1 className="font-extrabold text-sm sm:text-base text-slate-900 dark:text-white tracking-tight leading-tight">
                  {schoolName}
                </h1>
                <span className="hidden sm:inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-bold bg-indigo-50 dark:bg-indigo-900/40 text-indigo-700 dark:text-indigo-300 border border-indigo-200/60 dark:border-indigo-700/50">
                  <Sparkles className="w-3 h-3 text-amber-500" />
                  Parent Portal
                </span>
              </div>
              <p className="text-[11px] text-slate-500 dark:text-slate-400 font-medium">
                Student: <span className="font-bold text-indigo-600 dark:text-indigo-400">{student?.name || 'Student Record'}</span> (Class {student?.className || 'N/A'}-{student?.section || 'A'})
              </p>
            </div>
          </div>

          {/* Right Action Icons */}
          <div className="flex items-center gap-2">
            <button
              onClick={handleOpenWhatsApp}
              title="Chat with School on WhatsApp"
              className="hidden sm:inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-emerald-50 dark:bg-emerald-950/40 border border-emerald-200 dark:border-emerald-800/60 text-emerald-700 dark:text-emerald-300 text-xs font-bold hover:bg-emerald-100 transition-colors shadow-sm cursor-pointer"
            >
              <Phone className="w-3.5 h-3.5 text-emerald-600" />
              <span>Contact School</span>
            </button>

            <button
              onClick={toggleTheme}
              className="p-2 rounded-xl text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors cursor-pointer"
              title="Toggle Theme"
            >
              {themeMode === 'dark' ? <Sun className="w-4 h-4 text-amber-400" /> : <Moon className="w-4 h-4 text-indigo-600" />}
            </button>

            <button
              onClick={() => {
                if (window.confirm('Are you sure you want to log out from Parent Portal?')) {
                  logout();
                  if (typeof window !== 'undefined') window.location.href = '/signin';
                }
              }}
              className="inline-flex items-center gap-1.5 px-3 py-2 rounded-xl bg-rose-50 dark:bg-rose-950/40 border border-rose-200 dark:border-rose-800/50 text-rose-600 dark:text-rose-400 text-xs font-bold hover:bg-rose-100 dark:hover:bg-rose-900/30 transition-all cursor-pointer"
            >
              <LogOut className="w-3.5 h-3.5" />
              <span className="hidden sm:inline">Logout</span>
            </button>
          </div>

        </div>
      </header>

      {/* ── Main Container ── */}
      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6 space-y-6">
        
        {/* ── Hero Student Card ── */}
        <div className="relative overflow-hidden rounded-3xl bg-gradient-to-r from-[#191068] via-[#1f1a8f] to-[#120950] p-6 sm:p-8 text-white shadow-xl border border-white/10">
          <div className="absolute -right-12 -top-12 w-64 h-64 bg-white/5 rounded-full blur-2xl pointer-events-none" />
          <div className="absolute right-32 bottom-0 w-48 h-48 bg-indigo-500/20 rounded-full blur-3xl pointer-events-none" />

          <div className="relative z-10 flex flex-col md:flex-row md:items-center justify-between gap-6">
            
            {/* Student Info Left */}
            <div className="flex items-center gap-5">
              <div className="w-20 h-20 sm:w-24 sm:h-24 rounded-2xl bg-white/10 backdrop-blur-md border border-white/20 p-1 flex-shrink-0 shadow-lg flex items-center justify-center overflow-hidden">
                {student?.avatarUrl || student?.photoUrl ? (
                  <img
                    src={student.avatarUrl || student.photoUrl}
                    alt={student.name}
                    className="w-full h-full object-cover rounded-xl"
                  />
                ) : (
                  <div className="w-full h-full rounded-xl bg-gradient-to-tr from-indigo-500 to-purple-500 flex items-center justify-center text-white font-black text-2xl">
                    {student?.name ? student.name.charAt(0).toUpperCase() : 'S'}
                  </div>
                )}
              </div>

              <div className="space-y-1">
                <div className="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full bg-emerald-400/20 border border-emerald-400/30 text-emerald-300 text-[10px] font-bold">
                  <CheckCircle2 className="w-3 h-3 text-emerald-400" />
                  <span>Enrolled Student</span>
                </div>
                <h2 className="text-xl sm:text-2xl font-black tracking-tight text-white">
                  {student?.name || 'Aarav Sharma'}
                </h2>
                <div className="flex flex-wrap items-center gap-2 text-xs text-white/80 font-medium pt-0.5">
                  <span className="bg-white/15 px-2.5 py-0.5 rounded-lg border border-white/15">
                    Class: <strong className="text-white">{student?.className || '10th'} - {student?.section || 'A'}</strong>
                  </span>
                  <span className="bg-white/15 px-2.5 py-0.5 rounded-lg border border-white/15">
                    Roll No: <strong className="text-white">{student?.rollNumber || student?.rollNo || '1'}</strong>
                  </span>
                  <span className="bg-white/15 px-2.5 py-0.5 rounded-lg border border-white/15">
                    Adm No: <strong className="text-white">{student?.admissionNo || student?.admissionNumber || 'ADM-2026-001'}</strong>
                  </span>
                </div>
              </div>
            </div>

            {/* Quick Metrics Badges Right */}
            <div className="grid grid-cols-2 sm:grid-cols-3 gap-3">
              
              <div className="p-3 rounded-2xl bg-white/10 backdrop-blur-md border border-white/15 text-center">
                <p className="text-[10px] text-white/70 font-bold uppercase tracking-wider">Attendance</p>
                <p className="text-lg font-black text-emerald-400 mt-0.5">{attendanceRate}%</p>
                <p className="text-[10px] text-white/60 font-medium">{presentDays} / {totalMarkedDays || 1} Days</p>
              </div>

              <div className="p-3 rounded-2xl bg-white/10 backdrop-blur-md border border-white/15 text-center">
                <p className="text-[10px] text-white/70 font-bold uppercase tracking-wider">Pending Dues</p>
                <p className={`text-lg font-black mt-0.5 ${currentDue > 0 ? 'text-amber-400' : 'text-emerald-400'}`}>
                  ₹{currentDue.toLocaleString('en-IN')}
                </p>
                <p className="text-[10px] text-white/60 font-medium">
                  {currentDue === 0 ? 'All Clear' : 'Due Balance'}
                </p>
              </div>

              <div className="col-span-2 sm:col-span-1 p-3 rounded-2xl bg-white/10 backdrop-blur-md border border-white/15 text-center flex flex-col justify-center">
                <p className="text-[10px] text-white/70 font-bold uppercase tracking-wider">Academic Year</p>
                <p className="text-sm font-black text-white mt-0.5">{student?.session || '2026-2027'}</p>
                <p className="text-[10px] text-white/60 font-medium">CBSE / State Board</p>
              </div>

            </div>

          </div>
        </div>

        {/* ── Navigation Tabs ── */}
        <div className="flex items-center gap-2 overflow-x-auto pb-2 scrollbar-none border-b border-slate-200 dark:border-slate-800">
          
          <button
            onClick={() => setActiveTab('overview')}
            className={`px-4 py-2.5 rounded-2xl text-xs font-bold transition-all flex items-center gap-2 whitespace-nowrap cursor-pointer ${
              activeTab === 'overview'
                ? 'bg-[#1f108e] text-white shadow-md shadow-indigo-500/20'
                : 'bg-white dark:bg-[#111c38] text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800 border border-slate-200/80 dark:border-slate-800'
            }`}
          >
            <User className="w-4 h-4" />
            <span>Profile & Overview</span>
          </button>

          <button
            onClick={() => setActiveTab('attendance')}
            className={`px-4 py-2.5 rounded-2xl text-xs font-bold transition-all flex items-center gap-2 whitespace-nowrap cursor-pointer ${
              activeTab === 'attendance'
                ? 'bg-[#1f108e] text-white shadow-md shadow-indigo-500/20'
                : 'bg-white dark:bg-[#111c38] text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800 border border-slate-200/80 dark:border-slate-800'
            }`}
          >
            <CalendarCheck2 className="w-4 h-4" />
            <span>Attendance Log ({attendanceRate}%)</span>
          </button>

          <button
            onClick={() => setActiveTab('fees')}
            className={`px-4 py-2.5 rounded-2xl text-xs font-bold transition-all flex items-center gap-2 whitespace-nowrap cursor-pointer ${
              activeTab === 'fees'
                ? 'bg-[#1f108e] text-white shadow-md shadow-indigo-500/20'
                : 'bg-white dark:bg-[#111c38] text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800 border border-slate-200/80 dark:border-slate-800'
            }`}
          >
            <CreditCard className="w-4 h-4" />
            <span>Fee Ledger & Receipts ({studentPayments.length})</span>
          </button>

          <button
            onClick={() => setActiveTab('results')}
            className={`px-4 py-2.5 rounded-2xl text-xs font-bold transition-all flex items-center gap-2 whitespace-nowrap cursor-pointer ${
              activeTab === 'results'
                ? 'bg-[#1f108e] text-white shadow-md shadow-indigo-500/20'
                : 'bg-white dark:bg-[#111c38] text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800 border border-slate-200/80 dark:border-slate-800'
            }`}
          >
            <Award className="w-4 h-4" />
            <span>Exams & Marksheet ({studentResults.length})</span>
          </button>

          <button
            onClick={() => setActiveTab('notices')}
            className={`px-4 py-2.5 rounded-2xl text-xs font-bold transition-all flex items-center gap-2 whitespace-nowrap cursor-pointer ${
              activeTab === 'notices'
                ? 'bg-[#1f108e] text-white shadow-md shadow-indigo-500/20'
                : 'bg-white dark:bg-[#111c38] text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800 border border-slate-200/80 dark:border-slate-800'
            }`}
          >
            <Bell className="w-4 h-4" />
            <span>School Notices ({studentNotices.length})</span>
          </button>

        </div>

        {/* ── TAB 1: OVERVIEW & PROFILE ── */}
        {activeTab === 'overview' && (
          <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
            
            {/* Student Dossier Information */}
            <div className="lg:col-span-2 space-y-6">
              
              <div className="bg-white dark:bg-[#111c38] rounded-3xl p-6 border border-slate-200/80 dark:border-slate-800 shadow-sm space-y-5">
                <div className="flex items-center justify-between pb-3 border-b border-slate-100 dark:border-slate-800">
                  <h3 className="font-extrabold text-sm sm:text-base text-slate-900 dark:text-white flex items-center gap-2">
                    <User className="w-4 h-4 text-indigo-600" />
                    <span>Student Profile & Academic Dossier</span>
                  </h3>
                  <span className="text-xs font-bold text-slate-400">ID: {student?.id || 'N/A'}</span>
                </div>

                <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 text-xs">
                  
                  <div className="p-3.5 rounded-2xl bg-slate-50 dark:bg-slate-900/60 border border-slate-100 dark:border-slate-800">
                    <p className="text-slate-400 font-semibold mb-1">Father's Name</p>
                    <p className="font-bold text-slate-800 dark:text-slate-200 text-sm">
                      {student?.fatherName || 'Mr. Rajesh Sharma'}
                    </p>
                  </div>

                  <div className="p-3.5 rounded-2xl bg-slate-50 dark:bg-slate-900/60 border border-slate-100 dark:border-slate-800">
                    <p className="text-slate-400 font-semibold mb-1">Mother's Name</p>
                    <p className="font-bold text-slate-800 dark:text-slate-200 text-sm">
                      {student?.motherName || 'Mrs. Sunita Sharma'}
                    </p>
                  </div>

                  <div className="p-3.5 rounded-2xl bg-slate-50 dark:bg-slate-900/60 border border-slate-100 dark:border-slate-800">
                    <p className="text-slate-400 font-semibold mb-1">Date of Birth</p>
                    <p className="font-bold text-slate-800 dark:text-slate-200 text-sm">
                      {student?.dob || student?.dateOfBirth || '15 May 2010'}
                    </p>
                  </div>

                  <div className="p-3.5 rounded-2xl bg-slate-50 dark:bg-slate-900/60 border border-slate-100 dark:border-slate-800">
                    <p className="text-slate-400 font-semibold mb-1">Gender / Blood Group</p>
                    <p className="font-bold text-slate-800 dark:text-slate-200 text-sm">
                      {student?.gender || 'Male'} • {student?.bloodGroup || 'B+'}
                    </p>
                  </div>

                  <div className="p-3.5 rounded-2xl bg-slate-50 dark:bg-slate-900/60 border border-slate-100 dark:border-slate-800">
                    <p className="text-slate-400 font-semibold mb-1">Primary Registered Mobile</p>
                    <p className="font-bold text-slate-800 dark:text-slate-200 text-sm flex items-center gap-1.5">
                      <Phone className="w-3.5 h-3.5 text-indigo-500" />
                      <span>{student?.mobile || student?.parentMobile || '9876543210'}</span>
                    </p>
                  </div>

                  <div className="p-3.5 rounded-2xl bg-slate-50 dark:bg-slate-900/60 border border-slate-100 dark:border-slate-800">
                    <p className="text-slate-400 font-semibold mb-1">Admission Date</p>
                    <p className="font-bold text-slate-800 dark:text-slate-200 text-sm flex items-center gap-1.5">
                      <Calendar className="w-3.5 h-3.5 text-indigo-500" />
                      <span>{student?.admissionDate || '01 Apr 2024'}</span>
                    </p>
                  </div>

                  <div className="sm:col-span-2 p-3.5 rounded-2xl bg-slate-50 dark:bg-slate-900/60 border border-slate-100 dark:border-slate-800">
                    <p className="text-slate-400 font-semibold mb-1">Permanent Residential Address</p>
                    <p className="font-bold text-slate-800 dark:text-slate-200 text-sm flex items-start gap-1.5">
                      <MapPin className="w-3.5 h-3.5 text-indigo-500 flex-shrink-0 mt-0.5" />
                      <span>{student?.address || 'Near Main Bazar, School Road, City Center'}</span>
                    </p>
                  </div>

                </div>
              </div>

              {/* Recent Payment Receipts Preview */}
              <div className="bg-white dark:bg-[#111c38] rounded-3xl p-6 border border-slate-200/80 dark:border-slate-800 shadow-sm space-y-4">
                <div className="flex items-center justify-between">
                  <h3 className="font-extrabold text-sm sm:text-base text-slate-900 dark:text-white flex items-center gap-2">
                    <CreditCard className="w-4 h-4 text-emerald-600" />
                    <span>Recent Fee Payment Receipts</span>
                  </h3>
                  <button
                    onClick={() => setActiveTab('fees')}
                    className="text-xs font-bold text-indigo-600 dark:text-indigo-400 hover:underline flex items-center gap-1 cursor-pointer"
                  >
                    <span>View All</span>
                    <ChevronRight className="w-3.5 h-3.5" />
                  </button>
                </div>

                {studentPayments.length === 0 ? (
                  <div className="text-center py-8 text-slate-400 text-xs">
                    No fee receipts generated yet.
                  </div>
                ) : (
                  <div className="space-y-3">
                    {studentPayments.slice(0, 3).map((p) => (
                      <div
                        key={p.id || p.receiptNo}
                        className="p-3.5 rounded-2xl bg-slate-50 dark:bg-slate-900/60 border border-slate-100 dark:border-slate-800 flex items-center justify-between gap-3"
                      >
                        <div>
                          <div className="flex items-center gap-2">
                            <span className="font-bold text-xs text-slate-800 dark:text-slate-200">
                              Receipt #{p.receiptNo || 'REC-101'}
                            </span>
                            <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-emerald-50 dark:bg-emerald-950/40 text-emerald-600 dark:text-emerald-300 border border-emerald-200/60">
                              {p.paymentMode || 'Online'}
                            </span>
                          </div>
                          <p className="text-[11px] text-slate-500 mt-0.5">
                            Date: {p.paymentDate || p.date || 'Today'} • {p.remarks || 'Monthly Fee'}
                          </p>
                        </div>

                        <div className="flex items-center gap-3">
                          <span className="text-sm font-black text-slate-900 dark:text-white">
                            ₹{Number(p.amount || 0).toLocaleString('en-IN')}
                          </span>
                          <button
                            onClick={() => setPrintReceiptData(p)}
                            className="p-2 rounded-xl bg-white dark:bg-slate-800 hover:bg-slate-100 text-indigo-600 dark:text-indigo-300 border border-slate-200 dark:border-slate-700 shadow-sm transition-all cursor-pointer"
                            title="Print & Download Receipt"
                          >
                            <Printer className="w-4 h-4" />
                          </button>
                        </div>
                      </div>
                    ))}
                  </div>
                )}
              </div>

            </div>

            {/* Right Side Cards */}
            <div className="space-y-6">
              
              {/* Fee Payment Quick Action Box */}
              <div className="bg-gradient-to-br from-indigo-50 to-blue-50 dark:from-[#131d3d] dark:to-[#0f172a] rounded-3xl p-6 border border-indigo-100 dark:border-indigo-900/50 shadow-sm space-y-4">
                <div className="flex items-center justify-between">
                  <span className="text-xs font-bold text-indigo-900 dark:text-indigo-300 uppercase tracking-wider">
                    Fee Status
                  </span>
                  <span
                    className={`px-2.5 py-1 rounded-full text-xs font-black ${
                      currentDue === 0
                        ? 'bg-emerald-100 text-emerald-800 dark:bg-emerald-900/40 dark:text-emerald-300'
                        : 'bg-amber-100 text-amber-800 dark:bg-amber-900/40 dark:text-amber-300'
                    }`}
                  >
                    {currentDue === 0 ? '✓ All Fees Paid' : 'Payment Due'}
                  </span>
                </div>

                <div>
                  <p className="text-3xl font-black text-slate-900 dark:text-white">
                    ₹{currentDue.toLocaleString('en-IN')}
                  </p>
                  <p className="text-xs text-slate-500 dark:text-slate-400 mt-1">
                    {currentDue > 0
                      ? 'Please clear dues through school bank account or campus accounts office.'
                      : 'Thank you! All fees for current term are settled.'}
                  </p>
                </div>

                <div className="pt-2 border-t border-indigo-100 dark:border-indigo-900/50 space-y-2 text-xs">
                  <div className="flex justify-between text-slate-600 dark:text-slate-400">
                    <span>Total Annual Fee:</span>
                    <strong className="text-slate-900 dark:text-white">₹{totalFee.toLocaleString('en-IN')}</strong>
                  </div>
                  <div className="flex justify-between text-slate-600 dark:text-slate-400">
                    <span>Total Paid to Date:</span>
                    <strong className="text-emerald-600 dark:text-emerald-400">₹{totalPaid.toLocaleString('en-IN')}</strong>
                  </div>
                </div>

                <button
                  onClick={handleOpenWhatsApp}
                  className="w-full py-3 px-4 rounded-2xl bg-[#1f108e] hover:bg-[#150b69] text-white font-bold text-xs shadow-md transition-all flex items-center justify-center gap-2 cursor-pointer"
                >
                  <Phone className="w-4 h-4" />
                  <span>Contact Accounts Office</span>
                </button>
              </div>

              {/* Latest Notice Bulletin */}
              <div className="bg-white dark:bg-[#111c38] rounded-3xl p-6 border border-slate-200/80 dark:border-slate-800 shadow-sm space-y-4">
                <div className="flex items-center justify-between pb-3 border-b border-slate-100 dark:border-slate-800">
                  <h3 className="font-extrabold text-sm text-slate-900 dark:text-white flex items-center gap-2">
                    <Bell className="w-4 h-4 text-amber-500" />
                    <span>Official Announcements</span>
                  </h3>
                  <button
                    onClick={() => setActiveTab('notices')}
                    className="text-xs font-bold text-indigo-600 hover:underline"
                  >
                    View All
                  </button>
                </div>

                {studentNotices.length === 0 ? (
                  <p className="text-xs text-slate-400 py-4 text-center">No active circulars at this moment.</p>
                ) : (
                  <div className="space-y-3">
                    {studentNotices.slice(0, 2).map((n) => (
                      <div
                        key={n.id}
                        className="p-3.5 rounded-2xl bg-amber-50/50 dark:bg-amber-950/20 border border-amber-200/50 dark:border-amber-900/30"
                      >
                        <p className="text-xs font-bold text-slate-900 dark:text-white">
                          {n.title}
                        </p>
                        <p className="text-[11px] text-slate-600 dark:text-slate-300 line-clamp-2 mt-1">
                          {n.content || n.description}
                        </p>
                        <p className="text-[10px] text-slate-400 mt-2 font-medium">
                          {n.date || n.createdAt || 'Recent Notice'}
                        </p>
                      </div>
                    ))}
                  </div>
                )}
              </div>

            </div>

          </div>
        )}

        {/* ── TAB 2: ATTENDANCE LOG ── */}
        {activeTab === 'attendance' && (
          <div className="space-y-6">
            
            <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
              
              <div className="p-5 rounded-3xl bg-white dark:bg-[#111c38] border border-slate-200/80 dark:border-slate-800 shadow-sm">
                <p className="text-xs font-bold text-slate-400 uppercase">Attendance Rate</p>
                <p className="text-3xl font-black text-emerald-600 dark:text-emerald-400 mt-1">
                  {attendanceRate}%
                </p>
                <p className="text-xs text-slate-500 mt-1">Overall Percentage</p>
              </div>

              <div className="p-5 rounded-3xl bg-white dark:bg-[#111c38] border border-slate-200/80 dark:border-slate-800 shadow-sm">
                <p className="text-xs font-bold text-slate-400 uppercase">Total Days Present</p>
                <p className="text-3xl font-black text-indigo-600 dark:text-indigo-400 mt-1">
                  {presentDays}
                </p>
                <p className="text-xs text-slate-500 mt-1">Days Attended</p>
              </div>

              <div className="p-5 rounded-3xl bg-white dark:bg-[#111c38] border border-slate-200/80 dark:border-slate-800 shadow-sm">
                <p className="text-xs font-bold text-slate-400 uppercase">Days Absent</p>
                <p className="text-3xl font-black text-rose-500 mt-1">
                  {absentDays}
                </p>
                <p className="text-xs text-slate-500 mt-1">Unexcused Absences</p>
              </div>

              <div className="p-5 rounded-3xl bg-white dark:bg-[#111c38] border border-slate-200/80 dark:border-slate-800 shadow-sm">
                <p className="text-xs font-bold text-slate-400 uppercase">Official Leaves</p>
                <p className="text-3xl font-black text-amber-500 mt-1">
                  {leaveDays}
                </p>
                <p className="text-xs text-slate-500 mt-1">Permitted Leaves</p>
              </div>

            </div>

            {/* Attendance Records Table */}
            <div className="bg-white dark:bg-[#111c38] rounded-3xl p-6 border border-slate-200/80 dark:border-slate-800 shadow-sm space-y-4">
              <h3 className="font-extrabold text-sm sm:text-base text-slate-900 dark:text-white flex items-center gap-2">
                <CalendarCheck2 className="w-4 h-4 text-indigo-600" />
                <span>Daily Attendance Log</span>
              </h3>

              {attLogs.length === 0 ? (
                <div className="text-center py-12 text-slate-400 text-xs">
                  No attendance entries marked for this student yet.
                </div>
              ) : (
                <div className="overflow-x-auto">
                  <table className="w-full text-xs text-left">
                    <thead className="bg-slate-50 dark:bg-slate-900/60 text-slate-500 font-bold uppercase text-[10px] border-b border-slate-100 dark:border-slate-800">
                      <tr>
                        <th className="py-3 px-4">Date</th>
                        <th className="py-3 px-4">Day</th>
                        <th className="py-3 px-4">Class</th>
                        <th className="py-3 px-4">Status</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-slate-100 dark:divide-slate-800">
                      {attLogs.map((log) => {
                        const dateObj = new Date(log.date);
                        const dayName = isNaN(dateObj)
                          ? ''
                          : dateObj.toLocaleDateString('en-US', { weekday: 'long' });
                        return (
                          <tr key={log.date} className="hover:bg-slate-50/50 dark:hover:bg-slate-900/40">
                            <td className="py-3 px-4 font-bold text-slate-800 dark:text-slate-200">{log.date}</td>
                            <td className="py-3 px-4 text-slate-500">{dayName}</td>
                            <td className="py-3 px-4 text-slate-600 dark:text-slate-400 font-medium">
                              Class {student?.className || '10th'}
                            </td>
                            <td className="py-3 px-4">
                              <span
                                className={`inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-[11px] font-bold ${
                                  log.status === 'present'
                                    ? 'bg-emerald-50 dark:bg-emerald-950/40 text-emerald-600 dark:text-emerald-300 border border-emerald-200/60'
                                    : log.status === 'absent'
                                    ? 'bg-rose-50 dark:bg-rose-950/40 text-rose-600 dark:text-rose-400 border border-rose-200/60'
                                    : 'bg-amber-50 dark:bg-amber-950/40 text-amber-600 dark:text-amber-300 border border-amber-200/60'
                                }`}
                              >
                                {log.status === 'present' && <CheckCircle className="w-3.5 h-3.5" />}
                                {log.status === 'absent' && <XCircle className="w-3.5 h-3.5" />}
                                {log.status !== 'present' && log.status !== 'absent' && <Clock className="w-3.5 h-3.5" />}
                                <span className="capitalize">{log.status}</span>
                              </span>
                            </td>
                          </tr>
                        );
                      })}
                    </tbody>
                  </table>
                </div>
              )}
            </div>

          </div>
        )}

        {/* ── TAB 3: FEES & RECEIPTS ── */}
        {activeTab === 'fees' && (
          <div className="space-y-6">
            
            {/* Fee Metrics Header */}
            <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
              
              <div className="p-5 rounded-3xl bg-white dark:bg-[#111c38] border border-slate-200/80 dark:border-slate-800 shadow-sm">
                <p className="text-xs font-bold text-slate-400 uppercase">Total Annual Fees</p>
                <p className="text-2xl sm:text-3xl font-black text-slate-900 dark:text-white mt-1">
                  ₹{totalFee.toLocaleString('en-IN')}
                </p>
                <p className="text-xs text-slate-500 mt-1">Tuition, Transport & Activities</p>
              </div>

              <div className="p-5 rounded-3xl bg-white dark:bg-[#111c38] border border-slate-200/80 dark:border-slate-800 shadow-sm">
                <p className="text-xs font-bold text-slate-400 uppercase">Total Paid to Date</p>
                <p className="text-2xl sm:text-3xl font-black text-emerald-600 dark:text-emerald-400 mt-1">
                  ₹{totalPaid.toLocaleString('en-IN')}
                </p>
                <p className="text-xs text-slate-500 mt-1">Across {studentPayments.length} Receipts</p>
              </div>

              <div className="p-5 rounded-3xl bg-white dark:bg-[#111c38] border border-slate-200/80 dark:border-slate-800 shadow-sm">
                <p className="text-xs font-bold text-slate-400 uppercase">Outstanding Balance</p>
                <p
                  className={`text-2xl sm:text-3xl font-black mt-1 ${
                    currentDue > 0 ? 'text-amber-500' : 'text-emerald-600'
                  }`}
                >
                  ₹{currentDue.toLocaleString('en-IN')}
                </p>
                <p className="text-xs text-slate-500 mt-1">
                  {currentDue === 0 ? 'No balance pending' : 'Pending payment'}
                </p>
              </div>

            </div>

            {/* Fee Receipts List with Download */}
            <div className="bg-white dark:bg-[#111c38] rounded-3xl p-6 border border-slate-200/80 dark:border-slate-800 shadow-sm space-y-4">
              <div className="flex items-center justify-between">
                <div>
                  <h3 className="font-extrabold text-sm sm:text-base text-slate-900 dark:text-white flex items-center gap-2">
                    <CreditCard className="w-4 h-4 text-indigo-600" />
                    <span>Official Fee Receipts & Payment History</span>
                  </h3>
                  <p className="text-xs text-slate-400 mt-0.5">
                    Click "Print & Download Receipt" to save an official verified receipt copy.
                  </p>
                </div>
              </div>

              {studentPayments.length === 0 ? (
                <div className="text-center py-12 text-slate-400 text-xs">
                  No payment transactions recorded for this student.
                </div>
              ) : (
                <div className="overflow-x-auto">
                  <table className="w-full text-xs text-left">
                    <thead className="bg-slate-50 dark:bg-slate-900/60 text-slate-500 font-bold uppercase text-[10px] border-b border-slate-100 dark:border-slate-800">
                      <tr>
                        <th className="py-3 px-4">Receipt #</th>
                        <th className="py-3 px-4">Payment Date</th>
                        <th className="py-3 px-4">Description / Remarks</th>
                        <th className="py-3 px-4">Mode</th>
                        <th className="py-3 px-4 text-right">Amount Paid</th>
                        <th className="py-3 px-4 text-center">Action</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-slate-100 dark:divide-slate-800">
                      {studentPayments.map((p) => (
                        <tr key={p.id || p.receiptNo} className="hover:bg-slate-50/50 dark:hover:bg-slate-900/40">
                          <td className="py-3 px-4 font-bold text-indigo-600 dark:text-indigo-400">
                            #{p.receiptNo || 'REC-101'}
                          </td>
                          <td className="py-3 px-4 text-slate-600 dark:text-slate-300">
                            {p.paymentDate || p.date || 'Today'}
                          </td>
                          <td className="py-3 px-4 text-slate-800 dark:text-slate-200 font-medium">
                            {p.remarks || p.installmentMonth || 'Tuition & Academic Fees'}
                          </td>
                          <td className="py-3 px-4">
                            <span className="px-2.5 py-0.5 rounded-full text-[10px] font-bold bg-slate-100 dark:bg-slate-800 text-slate-700 dark:text-slate-300 border border-slate-200 dark:border-slate-700">
                              {p.paymentMode || 'Online'}
                            </span>
                          </td>
                          <td className="py-3 px-4 text-right font-black text-slate-900 dark:text-white">
                            ₹{Number(p.amount || 0).toLocaleString('en-IN')}
                          </td>
                          <td className="py-3 px-4 text-center">
                            <button
                              onClick={() => setPrintReceiptData(p)}
                              className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-indigo-50 dark:bg-indigo-950/40 hover:bg-indigo-100 text-indigo-700 dark:text-indigo-300 font-bold text-xs border border-indigo-200 dark:border-indigo-800/60 shadow-sm transition-all cursor-pointer"
                            >
                              <Printer className="w-3.5 h-3.5" />
                              <span>View & Print</span>
                            </button>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}
            </div>

          </div>
        )}

        {/* ── TAB 4: EXAM RESULTS & MARKSHEET ── */}
        {activeTab === 'results' && (
          <div className="space-y-6">
            
            <div className="flex items-center justify-between">
              <div>
                <h3 className="font-extrabold text-sm sm:text-base text-slate-900 dark:text-white flex items-center gap-2">
                  <Award className="w-4 h-4 text-indigo-600" />
                  <span>Academic Performance & Marksheets</span>
                </h3>
                <p className="text-xs text-slate-400 mt-0.5">
                  Review exam scores, subject-wise marks, and download verified grade cards.
                </p>
              </div>
            </div>

            {studentResults.length === 0 ? (
              <div className="bg-white dark:bg-[#111c38] rounded-3xl p-12 text-center border border-slate-200/80 dark:border-slate-800 shadow-sm space-y-3">
                <Award className="w-12 h-12 text-slate-300 dark:text-slate-600 mx-auto" />
                <h4 className="font-bold text-slate-700 dark:text-slate-300 text-sm">No Examination Records Found</h4>
                <p className="text-xs text-slate-400 max-w-sm mx-auto">
                  Examination results have not been published for this student yet. They will appear here once entered by teachers.
                </p>
              </div>
            ) : (
              <div className="space-y-6">
                {studentResults.map((r) => {
                  const rawSubjects = Array.isArray(r.subjects) && r.subjects.length > 0
                    ? r.subjects
                    : [{ subjectName: r.subject || 'General', totalMarks: r.totalMarks || 100, marks: r.marks || 0 }];
                  
                  const total = rawSubjects.reduce((sum, s) => sum + (Number(s.totalMarks) || 0), 0);
                  const obt = rawSubjects.reduce((sum, s) => sum + (Number(s.marks) || 0), 0);
                  const pct = total > 0 ? ((obt / total) * 100).toFixed(1) : '0.0';
                  const grade = Number(pct) >= 90 ? 'A+' : Number(pct) >= 80 ? 'A' : Number(pct) >= 70 ? 'B+' : Number(pct) >= 60 ? 'B' : Number(pct) >= 50 ? 'C' : Number(pct) >= 40 ? 'D' : 'F';

                  return (
                    <div
                      key={r.id}
                      className="bg-white dark:bg-[#111c38] rounded-3xl p-6 border border-slate-200/80 dark:border-slate-800 shadow-sm space-y-5"
                    >
                      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 pb-4 border-b border-slate-100 dark:border-slate-800">
                        <div>
                          <div className="flex items-center gap-2">
                            <h4 className="font-extrabold text-base text-slate-900 dark:text-white">
                              {r.examName || r.exam || 'Terminal Examination'}
                            </h4>
                            <span className="px-2.5 py-0.5 rounded-full text-xs font-black bg-emerald-100 dark:bg-emerald-950/40 text-emerald-800 dark:text-emerald-300 border border-emerald-200/60">
                              Grade: {grade} ({pct}%)
                            </span>
                          </div>
                          <p className="text-xs text-slate-500 mt-1">
                            Class: {r.className || student?.className || '10th'} • Date: {r.examDate || r.createdAt || 'Recent'}
                          </p>
                        </div>

                        <button
                          onClick={() => setPrintResultData({ result: r, student })}
                          className="inline-flex items-center gap-2 px-4 py-2.5 rounded-2xl bg-[#1f108e] hover:bg-[#150b69] text-white font-bold text-xs shadow-md transition-all cursor-pointer self-start sm:self-auto"
                        >
                          <Printer className="w-4 h-4" />
                          <span>Download Marksheet PDF</span>
                        </button>
                      </div>

                      {/* Subjects Table */}
                      <div className="overflow-x-auto">
                        <table className="w-full text-xs text-left">
                          <thead className="bg-slate-50 dark:bg-slate-900/60 text-slate-500 font-bold uppercase text-[10px] border-b border-slate-100 dark:border-slate-800">
                            <tr>
                              <th className="py-2.5 px-4">Subject</th>
                              <th className="py-2.5 px-4 text-center">Max Marks</th>
                              <th className="py-2.5 px-4 text-center">Marks Obtained</th>
                              <th className="py-2.5 px-4 text-center">Percentage</th>
                            </tr>
                          </thead>
                          <tbody className="divide-y divide-slate-100 dark:divide-slate-800">
                            {rawSubjects.map((s, idx) => {
                              const sMax = Number(s.totalMarks) || 100;
                              const sObt = Number(s.marks) || 0;
                              const sPct = sMax > 0 ? ((sObt / sMax) * 100).toFixed(0) : '0';
                              return (
                                <tr key={idx} className="hover:bg-slate-50/50 dark:hover:bg-slate-900/40">
                                  <td className="py-2.5 px-4 font-bold text-slate-800 dark:text-slate-200">
                                    {s.subjectName || s.subject || 'Subject'}
                                  </td>
                                  <td className="py-2.5 px-4 text-center text-slate-500">{sMax}</td>
                                  <td className="py-2.5 px-4 text-center font-black text-slate-900 dark:text-white">
                                    {sObt}
                                  </td>
                                  <td className="py-2.5 px-4 text-center">
                                    <span
                                      className={`font-bold ${
                                        Number(sPct) >= 75
                                          ? 'text-emerald-600'
                                          : Number(sPct) >= 40
                                          ? 'text-indigo-600'
                                          : 'text-rose-500'
                                      }`}
                                    >
                                      {sPct}%
                                    </span>
                                  </td>
                                </tr>
                              );
                            })}
                          </tbody>
                          <tfoot className="bg-slate-50/80 dark:bg-slate-900/80 font-black border-t border-slate-200 dark:border-slate-800 text-slate-900 dark:text-white">
                            <tr>
                              <td className="py-2.5 px-4">Grand Total</td>
                              <td className="py-2.5 px-4 text-center">{total}</td>
                              <td className="py-2.5 px-4 text-center text-indigo-600 dark:text-indigo-400">{obt}</td>
                              <td className="py-2.5 px-4 text-center text-emerald-600">{pct}%</td>
                            </tr>
                          </tfoot>
                        </table>
                      </div>
                    </div>
                  );
                })}
              </div>
            )}

          </div>
        )}

        {/* ── TAB 5: NOTICES & CIRCULARS ── */}
        {activeTab === 'notices' && (
          <div className="space-y-6">
            
            <div className="flex items-center justify-between">
              <div>
                <h3 className="font-extrabold text-sm sm:text-base text-slate-900 dark:text-white flex items-center gap-2">
                  <Bell className="w-4 h-4 text-indigo-600" />
                  <span>School Circulars & Event Notices</span>
                </h3>
                <p className="text-xs text-slate-400 mt-0.5">
                  Official notices issued by the Principal and Administrative Office.
                </p>
              </div>
            </div>

            {studentNotices.length === 0 ? (
              <div className="bg-white dark:bg-[#111c38] rounded-3xl p-12 text-center border border-slate-200/80 dark:border-slate-800 shadow-sm space-y-3">
                <Bell className="w-12 h-12 text-slate-300 dark:text-slate-600 mx-auto" />
                <h4 className="font-bold text-slate-700 dark:text-slate-300 text-sm">No Active Notices</h4>
                <p className="text-xs text-slate-400 max-w-sm mx-auto">
                  There are no announcements currently published for this class or school.
                </p>
              </div>
            ) : (
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                {studentNotices.map((n) => (
                  <div
                    key={n.id}
                    className="bg-white dark:bg-[#111c38] rounded-3xl p-6 border border-slate-200/80 dark:border-slate-800 shadow-sm space-y-3 flex flex-col justify-between"
                  >
                    <div className="space-y-2">
                      <div className="flex items-center justify-between gap-2">
                        <span className="px-2.5 py-0.5 rounded-full text-[10px] font-bold bg-indigo-50 dark:bg-indigo-950/40 text-indigo-700 dark:text-indigo-300 border border-indigo-200/60">
                          {n.category || 'General Notice'}
                        </span>
                        <span className="text-[11px] text-slate-400 font-medium">
                          {n.date || n.createdAt || 'Recent'}
                        </span>
                      </div>

                      <h4 className="font-extrabold text-sm sm:text-base text-slate-900 dark:text-white">
                        {n.title}
                      </h4>

                      <p className="text-xs text-slate-600 dark:text-slate-300 leading-relaxed whitespace-pre-line">
                        {n.content || n.description}
                      </p>
                    </div>

                    <div className="pt-3 border-t border-slate-100 dark:border-slate-800 flex items-center justify-between text-[11px] text-slate-400">
                      <span>Issued by: {n.author || 'School Administration'}</span>
                      <span className="font-bold text-emerald-600">Verified</span>
                    </div>
                  </div>
                ))}
              </div>
            )}

          </div>
        )}

      </main>

    </div>
  );
}
