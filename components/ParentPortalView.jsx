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
  CalendarCheck2,
  Download,
  Eye,
  X,
  MessageSquare,
  Send,
  Inbox
} from 'lucide-react';
import { exportSingleAdmitCardPDF } from '../lib/exportUtils';
import { db } from '../lib/firebase';
import { collection, addDoc, doc, setDoc } from 'firebase/firestore';

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

  const [activeTab, setActiveTab] = useState('overview'); // 'overview' | 'attendance' | 'fees' | 'results' | 'admitcard' | 'complaints' | 'notices'
  const [selectedExamId, setSelectedExamId] = useState('all');
  const [previewAadhaarModal, setPreviewAadhaarModal] = useState(false);
  const [downloadingAdmitCard, setDownloadingAdmitCard] = useState(false);

  // Complaints / Message to Principal State
  const [complaintCategory, setComplaintCategory] = useState('Academic & Studies (पढ़ाई संबंधी)');
  const [complaintSubject, setComplaintSubject] = useState('');
  const [complaintMessage, setComplaintMessage] = useState('');
  const [isUrgentComplaint, setIsUrgentComplaint] = useState(false);
  const [submittingComplaint, setSubmittingComplaint] = useState(false);
  const [complaintsFilter, setComplaintsFilter] = useState('all');
  const [complaintsList, setComplaintsList] = useState(() => {
    if (typeof window !== 'undefined') {
      try {
        const raw = localStorage.getItem(`parent_complaints_${currentUser?.studentId || 'default'}`);
        if (raw) return JSON.parse(raw);
      } catch (_) {}
    }
    return [];
  });

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

  // Dynamic Exam Timetable for Admit Card
  const classKey = student?.className ? `school_admit_schedule_${student.className}` : 'school_admit_schedule_default';
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

  const handleOpenWhatsApp = () => {
    const cleanPhone = schoolPhone.replace(/[^0-9]/g, '');
    const msg = encodeURIComponent(
      `Hello ${schoolName} Administration,\n\nI am the parent of ${student?.name || 'my child'} (Class ${student?.className || ''} - Sec ${student?.section || 'A'}, Admission No: ${student?.admissionNo || student?.admissionNumber || 'N/A'}).\n\nI would like to inquire about: `
    );
    window.open(`https://wa.me/91${cleanPhone}?text=${msg}`, '_blank');
  };

  const handleSendComplaint = async (e) => {
    e?.preventDefault();
    if (!complaintSubject.trim() || !complaintMessage.trim()) {
      showToast('Please fill out both subject and message', 'error');
      return;
    }
    setSubmittingComplaint(true);
    try {
      const now = new Date();
      const docId = `complaint_${Date.now()}_${student.admissionNo || student.admissionNumber || 'ADM'}`;
      const payload = {
        docId,
        id: docId,
        category: complaintCategory,
        subject: complaintSubject.trim(),
        message: complaintMessage.trim(),
        urgent: isUrgentComplaint,
        priority: isUrgentComplaint ? 'urgent' : 'normal',
        status: 'new',
        type: 'parent_complaint',
        device: 'web',
        studentId: student.id || currentUser?.studentId || '',
        studentName: student.name || 'Student',
        className: student.className || '',
        section: student.section || 'A',
        admissionNo: student.admissionNo || student.admissionNumber || '',
        senderName: `${student.fatherName || 'Parent'} (Parent of ${student.name || 'Student'})`,
        senderPhone: student.mobile || student.parentMobile || currentUser?.mobile || '',
        senderEmail: currentUser?.email || 'parent@school.local',
        schoolId: settings?.schoolId || currentUser?.schoolId || 'SCHOOL_001',
        schoolName: schoolName,
        date: now.toLocaleString('en-IN', { dateStyle: 'medium', timeStyle: 'short' }),
        createdAt: now.toISOString()
      };

      try {
        await addDoc(collection(db, 'feedbacks'), payload);
        await setDoc(doc(db, 'schoolDirectory', 'system_feedbacks', 'items', docId), payload);
      } catch (err) {
        console.warn('Firestore complaints write note:', err);
      }

      const updated = [payload, ...complaintsList];
      setComplaintsList(updated);
      if (typeof window !== 'undefined') {
        localStorage.setItem(`parent_complaints_${student.id || currentUser?.studentId || 'default'}`, JSON.stringify(updated));
      }

      setComplaintSubject('');
      setComplaintMessage('');
      setIsUrgentComplaint(false);
      showToast('Message sent to Principal successfully!', 'success');
    } catch (e) {
      showToast('Failed to send complaint: ' + e.message, 'error');
    } finally {
      setSubmittingComplaint(false);
    }
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
            onClick={() => setActiveTab('admitcard')}
            className={`px-4 py-2.5 rounded-2xl text-xs font-bold transition-all flex items-center gap-2 whitespace-nowrap cursor-pointer ${
              activeTab === 'admitcard'
                ? 'bg-[#1f108e] text-white shadow-md shadow-indigo-500/20'
                : 'bg-white dark:bg-[#111c38] text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800 border border-slate-200/80 dark:border-slate-800'
            }`}
          >
            <FileText className="w-4 h-4 text-purple-400" />
            <span>Admit Card</span>
          </button>

          <button
            onClick={() => setActiveTab('complaints')}
            className={`px-4 py-2.5 rounded-2xl text-xs font-bold transition-all flex items-center gap-2 whitespace-nowrap cursor-pointer ${
              activeTab === 'complaints'
                ? 'bg-[#1f108e] text-white shadow-md shadow-indigo-500/20'
                : 'bg-white dark:bg-[#111c38] text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800 border border-slate-200/80 dark:border-slate-800'
            }`}
          >
            <MessageSquare className="w-4 h-4 text-emerald-400" />
            <span>Message Principal</span>
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

                  {/* Student Aadhaar Verification & Document Preview */}
                  <div className="sm:col-span-2 p-3.5 rounded-2xl bg-slate-50 dark:bg-slate-900/60 border border-slate-100 dark:border-slate-800 flex flex-col sm:flex-row sm:items-center justify-between gap-3">
                    <div>
                      <p className="text-slate-400 font-semibold mb-1">Aadhaar Card (Official ID)</p>
                      <p className="font-bold text-slate-800 dark:text-slate-200 text-sm flex items-center gap-2">
                        <ShieldCheck className="w-4 h-4 text-emerald-500" />
                        <span className="font-mono tracking-wider">{student?.aadhaarNumber || student?.aadharNumber || student?.aadhaar || 'NOT-LINKED'}</span>
                        <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-emerald-50 text-emerald-700 dark:bg-emerald-950/40 dark:text-emerald-300 border border-emerald-200">Verified</span>
                      </p>
                    </div>
                    {(student?.aadhaarDocUrl || student?.aadhaarDocPath || student?.aadhaarCardUrl) && (
                      <div className="flex items-center gap-2">
                        <div 
                          onClick={() => setPreviewAadhaarModal(true)}
                          className="w-14 h-10 rounded-lg overflow-hidden border border-slate-300 dark:border-slate-700 cursor-pointer shadow-sm relative group"
                        >
                          <img 
                            src={student.aadhaarDocUrl || student.aadhaarDocPath || student.aadhaarCardUrl} 
                            alt="Aadhaar Card" 
                            className="w-full h-full object-cover group-hover:scale-110 transition-transform"
                          />
                          <div className="absolute inset-0 bg-black/30 flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity">
                            <Eye className="w-3.5 h-3.5 text-white" />
                          </div>
                        </div>
                        <button
                          onClick={() => setPreviewAadhaarModal(true)}
                          className="px-2.5 py-1.5 rounded-xl bg-white dark:bg-slate-800 text-indigo-600 dark:text-indigo-400 text-xs font-bold border border-slate-200 dark:border-slate-700 hover:bg-slate-50 transition-colors flex items-center gap-1 cursor-pointer"
                        >
                          <Eye className="w-3.5 h-3.5" />
                          <span>View Aadhaar Photo</span>
                        </button>
                      </div>
                    )}
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

              {/* Admit Card Quick Access Card */}
              <div className="bg-gradient-to-br from-purple-50 to-indigo-50 dark:from-[#1e1b4b] dark:to-[#0f172a] rounded-3xl p-6 border border-purple-100 dark:border-purple-900/50 shadow-sm space-y-3">
                <div className="flex items-center justify-between">
                  <span className="text-xs font-bold text-purple-900 dark:text-purple-300 uppercase tracking-wider flex items-center gap-1.5">
                    <FileText className="w-4 h-4 text-purple-600 dark:text-purple-400" />
                    <span>Exam Admit Card</span>
                  </span>
                  <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-purple-100 text-purple-800 dark:bg-purple-900/40 dark:text-purple-300">
                    Active
                  </span>
                </div>
                <p className="text-xs text-slate-600 dark:text-slate-300">
                  Annual examination admit card is available for Class {student?.className || '10th'}. Download official PDF with QR verification.
                </p>
                <button
                  onClick={() => setActiveTab('admitcard')}
                  className="w-full py-2.5 px-4 rounded-2xl bg-gradient-to-r from-purple-600 to-indigo-600 hover:from-purple-700 hover:to-indigo-700 text-white font-bold text-xs shadow-md transition-all flex items-center justify-center gap-2 cursor-pointer"
                >
                  <Eye className="w-4 h-4" />
                  <span>View & Download Admit Card</span>
                </button>
              </div>

              {/* Message to Principal Action Card */}
              <div className="bg-gradient-to-br from-emerald-50 to-teal-50 dark:from-[#064e3b]/30 dark:to-[#0f172a] rounded-3xl p-6 border border-emerald-100 dark:border-emerald-900/50 shadow-sm space-y-3">
                <div className="flex items-center justify-between">
                  <span className="text-xs font-bold text-emerald-900 dark:text-emerald-300 uppercase tracking-wider flex items-center gap-1.5">
                    <MessageSquare className="w-4 h-4 text-emerald-600 dark:text-emerald-400" />
                    <span>Principal Direct Desk</span>
                  </span>
                  <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-emerald-100 text-emerald-800 dark:bg-emerald-900/40 dark:text-emerald-300">
                    Active Desk
                  </span>
                </div>
                <p className="text-xs text-slate-600 dark:text-slate-300">
                  Have any concern, feedback or inquiry? Send a confidential direct message or complaint to the Principal.
                </p>
                <button
                  onClick={() => setActiveTab('complaints')}
                  className="w-full py-2.5 px-4 rounded-2xl bg-gradient-to-r from-emerald-600 to-teal-600 hover:from-emerald-700 hover:to-teal-700 text-white font-bold text-xs shadow-md transition-all flex items-center justify-center gap-2 cursor-pointer"
                >
                  <Send className="w-4 h-4" />
                  <span>Send Message to Principal</span>
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

            {/* Fee Breakdown / Monthly Particulars */}
            <div className="bg-white dark:bg-[#111c38] rounded-3xl p-6 border border-slate-200/80 dark:border-slate-800 shadow-sm space-y-4">
              <div className="flex items-center justify-between">
                <div>
                  <h3 className="font-extrabold text-sm sm:text-base text-slate-900 dark:text-white flex items-center gap-2">
                    <Sparkles className="w-4 h-4 text-amber-500" />
                    <span>Fee Structure & Monthly Dues Breakdown</span>
                  </h3>
                  <p className="text-xs text-slate-400 mt-0.5">
                    Official itemized ledger of tuition, development and ancillary fee heads.
                  </p>
                </div>
                <span className="px-3 py-1 rounded-full text-xs font-black bg-indigo-50 dark:bg-indigo-950/40 text-indigo-700 dark:text-indigo-300 border border-indigo-200 dark:border-indigo-800">
                  Current Session
                </span>
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-4 gap-3 text-xs">
                <div className="p-3.5 rounded-2xl bg-slate-50 dark:bg-slate-900/60 border border-slate-100 dark:border-slate-800">
                  <span className="text-slate-400 block font-semibold">Tuition Fee</span>
                  <span className="text-base font-black text-slate-900 dark:text-white mt-1 block">
                    ₹{(student?.monthlyParticulars?.tuitionFee ?? 1500).toLocaleString('en-IN')}
                  </span>
                  <span className="text-[10px] text-slate-500">Per Month</span>
                </div>

                <div className="p-3.5 rounded-2xl bg-slate-50 dark:bg-slate-900/60 border border-slate-100 dark:border-slate-800">
                  <span className="text-slate-400 block font-semibold">Tie / Belt / Bag</span>
                  <span className="text-base font-black text-slate-900 dark:text-white mt-1 block">
                    ₹{(student?.monthlyParticulars?.tieBagBelt ?? 600).toLocaleString('en-IN')}
                  </span>
                  <span className="text-[10px] text-slate-500">Kit Charges</span>
                </div>

                <div className="p-3.5 rounded-2xl bg-slate-50 dark:bg-slate-900/60 border border-slate-100 dark:border-slate-800">
                  <span className="text-slate-400 block font-semibold">Development Charges</span>
                  <span className="text-base font-black text-slate-900 dark:text-white mt-1 block">
                    ₹{(student?.monthlyParticulars?.developmentCharges ?? 1000).toLocaleString('en-IN')}
                  </span>
                  <span className="text-[10px] text-slate-500">Facility & Lab</span>
                </div>

                <div className="p-3.5 rounded-2xl bg-slate-50 dark:bg-slate-900/60 border border-slate-100 dark:border-slate-800">
                  <span className="text-slate-400 block font-semibold">Monthly Total Expected</span>
                  <span className="text-base font-black text-indigo-600 dark:text-indigo-400 mt-1 block">
                    ₹{(
                      (student?.monthlyParticulars?.tuitionFee ?? 1500) +
                      (student?.monthlyParticulars?.tieBagBelt ?? 600) +
                      (student?.monthlyParticulars?.developmentCharges ?? 1000) +
                      (student?.monthlyParticulars?.otherCharges ?? 0)
                    ).toLocaleString('en-IN')}
                  </span>
                  <span className="text-[10px] text-emerald-600 font-bold">Standard Term Rate</span>
                </div>
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

        {/* ── TAB 5: ADMIT CARD & HALL TICKET ── */}
        {activeTab === 'admitcard' && (
          <div className="space-y-6">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
              <div>
                <h3 className="font-extrabold text-sm sm:text-base text-slate-900 dark:text-white flex items-center gap-2">
                  <FileText className="w-4 h-4 text-purple-600" />
                  <span>Official Examination Admit Card</span>
                </h3>
                <p className="text-xs text-slate-400 mt-0.5">
                  Verified hall ticket for {settings.currentSession || '2026-2027'} examination session.
                </p>
              </div>

              <button
                onClick={async () => {
                  try {
                    setDownloadingAdmitCard(true);
                    await exportSingleAdmitCardPDF(student, settings, studentTimetable, 'ANNUAL EXAMINATION 2026');
                    showToast('Admit Card downloaded successfully!', 'success');
                  } catch (e) {
                    showToast('Failed to download Admit Card', 'error');
                  } finally {
                    setDownloadingAdmitCard(false);
                  }
                }}
                disabled={downloadingAdmitCard}
                className="inline-flex items-center gap-2 px-5 py-2.5 rounded-2xl bg-[#1f108e] hover:bg-[#150b69] text-white font-bold text-xs shadow-md transition-all cursor-pointer disabled:opacity-50"
              >
                <Download className="w-4 h-4" />
                <span>{downloadingAdmitCard ? 'Generating PDF...' : 'Download Official Admit Card (A4 PDF)'}</span>
              </button>
            </div>

            {/* Admit Card Visual Preview Card */}
            <div className="max-w-2xl mx-auto bg-white dark:bg-[#111c38] rounded-3xl p-6 sm:p-8 border-2 border-indigo-200 dark:border-indigo-900 shadow-xl space-y-6">
              
              {/* Institution Header */}
              <div className="text-center pb-4 border-b border-slate-200 dark:border-slate-800 space-y-1">
                <div className="inline-flex items-center justify-center w-12 h-12 rounded-2xl bg-indigo-50 dark:bg-indigo-950/60 text-indigo-600 dark:text-indigo-400 mb-2">
                  <School className="w-6 h-6" />
                </div>
                <h4 className="font-black text-base sm:text-lg text-slate-900 dark:text-white uppercase tracking-wider">
                  {schoolName}
                </h4>
                <p className="text-xs text-slate-500 dark:text-slate-400">
                  {settings.address || 'Senior Secondary Academic Institution'}
                </p>
                <div className="pt-1">
                  <span className="inline-flex items-center gap-1 px-3 py-1 rounded-full text-[11px] font-black bg-indigo-50 dark:bg-indigo-950/40 text-indigo-700 dark:text-indigo-300 border border-indigo-200 dark:border-indigo-800">
                    <Sparkles className="w-3.5 h-3.5 text-amber-500" />
                    ANNUAL EXAMINATION ADMIT CARD • {settings.currentSession || '2026-27'}
                  </span>
                </div>
              </div>

              {/* Student Metadata & QR */}
              <div className="p-4 rounded-2xl bg-slate-50 dark:bg-slate-900/60 border border-slate-200/80 dark:border-slate-800 flex flex-col sm:flex-row items-center justify-between gap-4">
                <div className="grid grid-cols-2 gap-3 text-xs w-full">
                  <div>
                    <span className="text-slate-400 font-semibold block text-[10px] uppercase">Student Name</span>
                    <strong className="text-slate-900 dark:text-white uppercase">{student?.name || 'Student'}</strong>
                  </div>
                  <div>
                    <span className="text-slate-400 font-semibold block text-[10px] uppercase">Roll Number</span>
                    <strong className="text-indigo-600 dark:text-indigo-400">{student?.rollNumber || student?.rollNo || '1'}</strong>
                  </div>
                  <div>
                    <span className="text-slate-400 font-semibold block text-[10px] uppercase">Class & Section</span>
                    <strong className="text-slate-900 dark:text-white">{student?.className || '10th'} - {student?.section || 'A'}</strong>
                  </div>
                  <div>
                    <span className="text-slate-400 font-semibold block text-[10px] uppercase">Admission No</span>
                    <strong className="text-slate-900 dark:text-white font-mono">{student?.admissionNo || student?.admissionNumber || 'N/A'}</strong>
                  </div>
                  <div>
                    <span className="text-slate-400 font-semibold block text-[10px] uppercase">Father's Name</span>
                    <strong className="text-slate-900 dark:text-white">{student?.fatherName || 'N/A'}</strong>
                  </div>
                  <div>
                    <span className="text-slate-400 font-semibold block text-[10px] uppercase">Aadhaar No</span>
                    <strong className="text-slate-900 dark:text-white font-mono">{student?.aadhaarNumber || student?.aadharNumber || student?.aadhaar || 'NOT-LINKED'}</strong>
                  </div>
                </div>

                <div className="flex flex-col items-center flex-shrink-0 bg-white dark:bg-slate-800 p-2 rounded-xl border border-slate-200 dark:border-slate-700 shadow-sm">
                  <img
                    src={`https://api.qrserver.com/v1/create-qr-code/?size=80x80&data=${encodeURIComponent(`STUDENT ADMIT CARD | Name: ${student.name} | Roll: ${student.rollNumber || 'N/A'} | Class: ${student.className || ''} | Aadhaar: ${student.aadhaarNumber || 'N/A'}`)}`}
                    alt="Admit Card QR"
                    className="w-16 h-16 object-contain"
                  />
                  <span className="text-[8px] font-black text-emerald-600 mt-1 uppercase">VERIFIED ENTRY</span>
                </div>
              </div>

              {/* Exam Schedule */}
              <div className="space-y-2">
                <div className="flex items-center justify-between text-xs">
                  <span className="font-extrabold text-slate-800 dark:text-slate-200 uppercase tracking-wide">Examination Timetable</span>
                  <span className="text-[11px] text-indigo-600 font-bold">{studentTimetable.length} Subjects</span>
                </div>
                <div className="overflow-hidden rounded-2xl border border-slate-200 dark:border-slate-800">
                  <table className="w-full text-xs text-left">
                    <thead className="bg-slate-50 dark:bg-slate-900/60 text-slate-500 font-bold uppercase text-[10px] border-b border-slate-200 dark:border-slate-800">
                      <tr>
                        <th className="py-2.5 px-3">Date</th>
                        <th className="py-2.5 px-3">Subject</th>
                        <th className="py-2.5 px-3">Timing</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-slate-100 dark:divide-slate-800">
                      {studentTimetable.map((t, idx) => (
                        <tr key={idx} className={idx % 2 === 1 ? 'bg-slate-50/50 dark:bg-slate-900/30' : ''}>
                          <td className="py-2.5 px-3 font-bold text-indigo-600 dark:text-indigo-400">{t.day || t.date}</td>
                          <td className="py-2.5 px-3 font-semibold text-slate-800 dark:text-slate-200">{t.subject}</td>
                          <td className="py-2.5 px-3 text-slate-500">{t.timing}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </div>

              {/* Instructions */}
              <div className="p-3.5 rounded-2xl bg-amber-50/60 dark:bg-amber-950/20 border border-amber-200/50 dark:border-amber-900/30 text-[11px] text-amber-900 dark:text-amber-300 space-y-1">
                <p className="font-bold">Instructions for Candidate:</p>
                <ul className="list-disc list-inside space-y-0.5 text-[10px] text-slate-600 dark:text-slate-400">
                  <li>Please bring this printed Admit Card and School ID to every examination.</li>
                  <li>Students must report to the examination hall 15 minutes before scheduled start time.</li>
                  <li>Electronic devices and mobile phones are strictly prohibited inside the hall.</li>
                </ul>
              </div>

              {/* Signatures */}
              <div className="pt-4 border-t border-dashed border-slate-200 dark:border-slate-800 flex items-end justify-between text-[11px] text-slate-400">
                <div className="text-center">
                  <div className="w-24 border-b border-slate-300 dark:border-slate-700 mb-1"></div>
                  <span>Student Sign</span>
                </div>
                <div className="text-center">
                  <div className="w-24 border-b border-slate-300 dark:border-slate-700 mb-1"></div>
                  <span>Class Teacher</span>
                </div>
                <div className="text-center">
                  <div className="w-24 border-b border-slate-300 dark:border-slate-700 mb-1"></div>
                  <span className="font-bold text-indigo-600 dark:text-indigo-400">Principal / Director</span>
                </div>
              </div>

            </div>
          </div>
        )}

        {/* ── TAB 6: COMPLAINTS & MESSAGE TO PRINCIPAL ── */}
        {activeTab === 'complaints' && (
          <div className="space-y-6">
            
            <div className="flex items-center justify-between">
              <div>
                <h3 className="font-extrabold text-sm sm:text-base text-slate-900 dark:text-white flex items-center gap-2">
                  <MessageSquare className="w-4 h-4 text-emerald-600" />
                  <span>Message & Complaint to Principal Desk</span>
                </h3>
                <p className="text-xs text-slate-400 mt-0.5">
                  Direct official communication with School Administration. Private, secure, and reviewed directly by the Principal.
                </p>
              </div>
            </div>

            <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
              
              {/* Left Column: Compose Complaint Form */}
              <div className="lg:col-span-5 bg-white dark:bg-[#111c38] rounded-3xl p-6 border border-slate-200/80 dark:border-slate-800 shadow-sm space-y-4">
                <div className="flex items-center gap-2 pb-3 border-b border-slate-100 dark:border-slate-800">
                  <Send className="w-4 h-4 text-indigo-600" />
                  <h4 className="font-extrabold text-sm text-slate-900 dark:text-white">Compose Message / Complaint</h4>
                </div>

                <form onSubmit={handleSendComplaint} className="space-y-4 text-xs">
                  <div>
                    <label className="block text-slate-500 font-bold mb-1.5 uppercase text-[10px]">
                      Topic / Category
                    </label>
                    <select
                      value={complaintCategory}
                      onChange={(e) => setComplaintCategory(e.target.value)}
                      className="w-full px-3 py-2.5 rounded-xl bg-slate-50 dark:bg-slate-900 border border-slate-200 dark:border-slate-700 text-slate-800 dark:text-slate-200 text-xs font-semibold focus:outline-none focus:ring-2 focus:ring-indigo-500"
                    >
                      <option value="Academic & Studies (पढ़ाई संबंधी)">Academic & Studies (पढ़ाई संबंधी)</option>
                      <option value="Fees & Accounts (फीस व रसीद संबंधी)">Fees & Accounts (फीस व रसीद संबंधी)</option>
                      <option value="Bus & Transport (बस व वाहन संबंधी)">Bus & Transport (बस व वाहन संबंधी)</option>
                      <option value="Discipline & Behavior (अनुशासन संबंधी)">Discipline & Behavior (अनुशासन संबंधी)</option>
                      <option value="School Facilities (व्यवस्था व स्वच्छता)">School Facilities (व्यवस्था व स्वच्छता)</option>
                      <option value="Direct Message to Principal (प्रधानाचार्य को सीधा संदेश)">Direct Message to Principal (प्रधानाचार्य को सीधा संदेश)</option>
                      <option value="Other Concern (अन्य शिकायत या सुझाव)">Other Concern (अन्य शिकायत या सुझाव)</option>
                    </select>
                  </div>

                  <div>
                    <label className="block text-slate-500 font-bold mb-1.5 uppercase text-[10px]">
                      Subject / विषय
                    </label>
                    <input
                      type="text"
                      value={complaintSubject}
                      onChange={(e) => setComplaintSubject(e.target.value)}
                      placeholder="e.g. Issue regarding transport timing / Homework clarification"
                      className="w-full px-3 py-2.5 rounded-xl bg-slate-50 dark:bg-slate-900 border border-slate-200 dark:border-slate-700 text-slate-800 dark:text-slate-200 text-xs focus:outline-none focus:ring-2 focus:ring-indigo-500"
                      required
                    />
                  </div>

                  <div>
                    <label className="block text-slate-500 font-bold mb-1.5 uppercase text-[10px]">
                      Detailed Message / Complaint
                    </label>
                    <textarea
                      rows={4}
                      value={complaintMessage}
                      onChange={(e) => setComplaintMessage(e.target.value)}
                      placeholder="Type details of your complaint or query here. The Principal will review and take necessary action."
                      className="w-full px-3 py-2.5 rounded-xl bg-slate-50 dark:bg-slate-900 border border-slate-200 dark:border-slate-700 text-slate-800 dark:text-slate-200 text-xs focus:outline-none focus:ring-2 focus:ring-indigo-500"
                      required
                    />
                  </div>

                  <div className="flex items-center justify-between p-3 rounded-xl bg-slate-50 dark:bg-slate-900/60 border border-slate-200 dark:border-slate-800">
                    <span className="font-bold text-slate-700 dark:text-slate-300">Mark as Urgent Priority</span>
                    <input
                      type="checkbox"
                      checked={isUrgentComplaint}
                      onChange={(e) => setIsUrgentComplaint(e.target.checked)}
                      className="w-4 h-4 rounded text-indigo-600 focus:ring-indigo-500 cursor-pointer"
                    />
                  </div>

                  <button
                    type="submit"
                    disabled={submittingComplaint}
                    className="w-full py-3 px-4 rounded-xl bg-[#1f108e] hover:bg-[#150b69] text-white font-bold text-xs shadow-md transition-all flex items-center justify-center gap-2 cursor-pointer disabled:opacity-50"
                  >
                    <Send className="w-4 h-4" />
                    <span>{submittingComplaint ? 'Sending...' : 'Send Message to Principal'}</span>
                  </button>
                </form>
              </div>

              {/* Right Column: List of Sent Messages & Replies */}
              <div className="lg:col-span-7 bg-white dark:bg-[#111c38] rounded-3xl p-6 border border-slate-200/80 dark:border-slate-800 shadow-sm space-y-4">
                <div className="flex items-center justify-between pb-3 border-b border-slate-100 dark:border-slate-800">
                  <div className="flex items-center gap-2">
                    <Inbox className="w-4 h-4 text-emerald-600" />
                    <h4 className="font-extrabold text-sm text-slate-900 dark:text-white">
                      Sent Messages ({complaintsList.length})
                    </h4>
                  </div>

                  {/* Filter Tabs */}
                  <div className="flex items-center gap-1">
                    {['all', 'pending', 'resolved'].map((f) => (
                      <button
                        key={f}
                        onClick={() => setComplaintsFilter(f)}
                        className={`px-2.5 py-1 rounded-lg text-[10px] font-bold capitalize transition-colors cursor-pointer ${
                          complaintsFilter === f
                            ? 'bg-indigo-600 text-white'
                            : 'bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-400'
                        }`}
                      >
                        {f}
                      </button>
                    ))}
                  </div>
                </div>

                {complaintsList.length === 0 ? (
                  <div className="text-center py-12 text-slate-400 text-xs space-y-2">
                    <MessageSquare className="w-8 h-8 text-slate-300 dark:text-slate-600 mx-auto" />
                    <p>No messages or complaints submitted yet.</p>
                    <p className="text-[10px]">Use the form on the left to send your first message to the Principal.</p>
                  </div>
                ) : (
                  <div className="space-y-3">
                    {complaintsList
                      .filter((c) => {
                        const st = (c.status || 'new').toLowerCase();
                        if (complaintsFilter === 'pending') return st !== 'resolved';
                        if (complaintsFilter === 'resolved') return st === 'resolved';
                        return true;
                      })
                      .map((c) => {
                        const isResolved = (c.status || '').toLowerCase() === 'resolved';
                        return (
                          <div
                            key={c.docId || c.id || Math.random()}
                            className="p-4 rounded-2xl bg-slate-50 dark:bg-slate-900/60 border border-slate-100 dark:border-slate-800 space-y-2"
                          >
                            <div className="flex items-center justify-between gap-2">
                              <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-indigo-50 dark:bg-indigo-950/40 text-indigo-700 dark:text-indigo-300 border border-indigo-200/60">
                                {c.category || 'Complaint'}
                              </span>
                              <span
                                className={`px-2 py-0.5 rounded-full text-[10px] font-bold ${
                                  isResolved
                                    ? 'bg-emerald-50 text-emerald-700 dark:bg-emerald-950/40 dark:text-emerald-300'
                                    : 'bg-amber-50 text-amber-700 dark:bg-amber-950/40 dark:text-amber-300'
                                }`}
                              >
                                {isResolved ? '✓ Resolved' : '● Under Review'}
                              </span>
                            </div>

                            <h5 className="font-bold text-xs text-slate-900 dark:text-white">{c.subject}</h5>
                            <p className="text-[11px] text-slate-600 dark:text-slate-300 whitespace-pre-line leading-relaxed">
                              {c.message}
                            </p>

                            <p className="text-[10px] text-slate-400">Date: {c.date || c.createdAt || 'Recent'}</p>

                            {/* Principal Reply Box */}
                            {(c.reply || c.adminReply) && (
                              <div className="mt-2 p-3 rounded-xl bg-blue-50 dark:bg-blue-950/30 border border-blue-200 dark:border-blue-900/40">
                                <div className="flex items-center gap-1.5 text-blue-700 dark:text-blue-300 font-bold text-[11px]">
                                  <ShieldCheck className="w-3.5 h-3.5" />
                                  <span>Principal Office Reply:</span>
                                </div>
                                <p className="text-[11px] text-slate-700 dark:text-slate-200 mt-1">
                                  {c.reply || c.adminReply}
                                </p>
                              </div>
                            )}
                          </div>
                        );
                      })}
                  </div>
                )}
              </div>

            </div>

          </div>
        )}

        {/* ── TAB 7: NOTICES & CIRCULARS ── */}
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

      {/* ── Aadhaar Card Zoom Modal ── */}
      {previewAadhaarModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/80 backdrop-blur-sm">
          <div className="relative max-w-lg w-full bg-white dark:bg-[#111c38] rounded-3xl p-6 shadow-2xl border border-slate-200 dark:border-slate-800 space-y-4">
            <div className="flex items-center justify-between pb-3 border-b border-slate-100 dark:border-slate-800">
              <div>
                <h4 className="font-black text-sm text-slate-900 dark:text-white flex items-center gap-2">
                  <ShieldCheck className="w-4 h-4 text-emerald-500" />
                  <span>Student Aadhaar Card Preview</span>
                </h4>
                <p className="text-[11px] text-slate-400">
                  {student?.name} • No: {student?.aadhaarNumber || student?.aadharNumber || student?.aadhaar || 'Verified'}
                </p>
              </div>
              <button
                onClick={() => setPreviewAadhaarModal(false)}
                className="p-1.5 rounded-xl text-slate-400 hover:text-slate-600 hover:bg-slate-100 dark:hover:bg-slate-800 cursor-pointer"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <div className="rounded-2xl overflow-hidden bg-slate-100 dark:bg-slate-900 border border-slate-200 dark:border-slate-800 max-h-[70vh] flex items-center justify-center">
              <img
                src={student?.aadhaarDocUrl || student?.aadhaarDocPath || student?.aadhaarCardUrl}
                alt="Aadhaar Card"
                className="w-full h-auto object-contain max-h-[65vh]"
              />
            </div>

            <div className="flex justify-end pt-2">
              <button
                onClick={() => setPreviewAadhaarModal(false)}
                className="px-4 py-2 rounded-xl bg-slate-100 dark:bg-slate-800 hover:bg-slate-200 text-slate-700 dark:text-slate-300 text-xs font-bold transition-colors cursor-pointer"
              >
                Close
              </button>
            </div>
          </div>
        </div>
      )}

    </div>
  );
}
