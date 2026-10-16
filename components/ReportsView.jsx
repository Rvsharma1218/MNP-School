'use client';

import React, { useRef, useState } from 'react';
import * as XLSX from 'xlsx';
import { useSchoolStore, calculateStudentFeeMetrics } from '../lib/store';
import {
  FileSpreadsheet, Download, FileText, Users, CreditCard,
  Calendar, CalendarCheck, Award, Upload, CheckCircle2, AlertCircle,
  BarChart3, TrendingUp, Layers, Share2, Printer, BookOpen, Clock,
  FileCheck, CheckCircle, GraduationCap, Search, Filter, Plus,
  ChevronRight, ChevronLeft, Eye, RefreshCw, X, Database, ShieldCheck
} from 'lucide-react';
import {
  exportStudentsToExcel, exportPaymentsToExcel, exportDefaultersToExcel,
  exportAttendanceToExcel, exportFeeStructurePDF,
  exportStudentsPDF, importStudentsFromExcel, exportTodayAttendancePDF,
  exportDateRangeAttendancePDF,
  downloadStudentImportTemplate,
  exportFullStudentsMasterToExcel,
  exportFullStudentsMasterPDF,
  importFullStudentsFromExcel,
  exportExamResultsToExcel,
  exportExamResultsPDF,
  exportFacultyToExcel,
  exportFacultyPDF
} from '../lib/exportUtils';

export default function ReportsView() {
  const {
    students,
    payments,
    attendance,
    results,
    teachers,
    settings,
    stats,
    addStudent,
    showToast
  } = useSchoolStore();

  // Tabs: 'master' (Full Student Database & Import/Export) | 'center' (Institutional Reports) | 'bulk' (Import Hub)
  const [activeTab, setActiveTab] = useState('master');
  const [selectedCategory, setSelectedCategory] = useState('all');

  // Master Database Search & Filters
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedClass, setSelectedClass] = useState('all');
  const [selectedStatus, setSelectedStatus] = useState('all');
  const [selectedFeeStatus, setSelectedFeeStatus] = useState('all');
  const [currentPage, setCurrentPage] = useState(1);
  const pageSize = 15;

  // Import flow states
  const importFileRef = useRef(null);
  const [isImporting, setIsImporting] = useState(false);
  const [previewRows, setPreviewRows] = useState(null); // Preview parsed rows before saving
  // Attendance Date Range Filter State
  const [attFromDate, setAttFromDate] = useState(() => {
    const d = new Date();
    d.setDate(1);
    return d.toISOString().split('T')[0];
  });
  const [attToDate, setAttToDate] = useState(new Date().toISOString().split('T')[0]);

  // Attendance summary in selected range
  const attSummaryList = students.map(s => {
    let p = 0, a = 0, l = 0;
    Object.keys(attendance).forEach(dateStr => {
      if (dateStr >= attFromDate && dateStr <= attToDate) {
        const st = attendance[dateStr]?.[s.id];
        if (st === 'present') p++;
        else if (st === 'absent') a++;
        else if (st === 'leave') l++;
      }
    });
    const total = p + a + l;
    const pct = total > 0 ? ((p / total) * 100).toFixed(1) : '-';
    return { student: s, present: p, absent: a, leave: l, total, pct };
  });

  const totalAttStudents = attSummaryList.length;
  const totalAttPresent = attSummaryList.reduce((acc, r) => acc + r.present, 0);
  const totalAttAbsent = attSummaryList.reduce((acc, r) => acc + r.absent, 0);
  const totalAttDays = attSummaryList.reduce((acc, r) => acc + r.total, 0);
  const overallAttPct = totalAttDays > 0 ? ((totalAttPresent / totalAttDays) * 100).toFixed(1) : '-';

  const handleExportAttendanceRangeExcel = () => {
    const rows = attSummaryList.map((r, idx) => ({
      'S.No': idx + 1,
      'Student ID': r.student.studentId || '-',
      'Student Name': r.student.name || '-',
      'Class / Course': r.student.studentType === 'school' ? `Class ${r.student.className || ''}` : (r.student.course || ''),
      'Date Range': `${attFromDate} to ${attToDate}`,
      'Total Days': r.total,
      'Present': r.present,
      'Absent': r.absent,
      'Leave': r.leave,
      'Attendance %': `${r.pct}%`
    }));
    const ws = XLSX.utils.json_to_sheet(rows);
    const wb = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, ws, 'Attendance Summary');
    XLSX.writeFile(wb, `Attendance_${attFromDate}_to_${attToDate}.xlsx`);
    showToast("Date-Range Attendance Excel exported!", "success");
  };

  // Filtered Students for the Master Table
  const filteredMasterStudents = students.filter(s => {
    if (selectedClass !== 'all') {
      if (s.studentType === 'school' && s.className !== selectedClass) return false;
      if (s.studentType === 'computer' && s.course !== selectedClass) return false;
    }
    if (selectedStatus !== 'all' && (s.status || 'active').toLowerCase() !== selectedStatus.toLowerCase()) return false;

    const m = calculateStudentFeeMetrics(s, payments);
    const totalFees = m.setTotalFees;
    const paidFees = m.totalPaid;
    const pending = m.currentDue;
    if (selectedFeeStatus === 'paid' && (pending > 0 || (totalFees === 0 && paidFees === 0))) return false;
    if (selectedFeeStatus === 'due' && pending <= 0) return false;
    if (selectedFeeStatus === 'unpaid' && paidFees > 0) return false;

    if (searchQuery.trim()) {
      const q = searchQuery.toLowerCase();
      const matchName = s.name?.toLowerCase().includes(q);
      const matchId = s.studentId?.toLowerCase().includes(q);
      const matchAdm = s.admissionNumber?.toLowerCase().includes(q);
      const matchRoll = s.rollNumber?.toLowerCase().includes(q);
      const matchPhone = s.mobile?.includes(q) || s.alternateMobile?.includes(q);
      const matchFather = s.fatherName?.toLowerCase().includes(q);
      if (!matchName && !matchId && !matchAdm && !matchRoll && !matchPhone && !matchFather) return false;
    }
    return true;
  });

  const totalPages = Math.ceil(filteredMasterStudents.length / pageSize) || 1;
  const paginatedStudents = filteredMasterStudents.slice((currentPage - 1) * pageSize, currentPage * pageSize);

  // File Upload -> Parse & Show Preview
  const handleFileSelected = async (e) => {
    const file = e.target.files?.[0];
    if (!file) return;

    try {
      showToast("Reading spreadsheet and validating columns...", "info");
      const parsed = await importFullStudentsFromExcel(file);
      setPreviewRows(parsed);
    } catch (err) {
      showToast(`Import parse error: ${err.message}`, "error");
    }
    e.target.value = '';
  };

  // Commit Parsed Students to Database
  const handleConfirmImport = async () => {
    if (!previewRows || previewRows.length === 0) return;
    setIsImporting(true);
    setImportProgress({ current: 0, total: previewRows.length });

    let successCount = 0;
    let failCount = 0;

    for (let i = 0; i < previewRows.length; i++) {
      try {
        await addStudent(previewRows[i]);
        successCount++;
      } catch (err) {
        failCount++;
      }
      setImportProgress({ current: i + 1, total: previewRows.length });
    }

    setIsImporting(false);
    setPreviewRows(null);
    showToast(`Successfully imported ${successCount} students into database!${failCount > 0 ? ` (${failCount} failed)` : ''}`, "success");
  };

  const defaultersList = students.filter(s => (s.totalFees || 0) - (s.paidFees || 0) > 0);

  // Master Institutional Reports List
  const reportsList = [
    {
      id: 'students',
      category: 'students',
      title: 'Complete Student Master Register',
      description: 'Comprehensive student profile details, admission records, parent contacts, address, and status.',
      icon: Users,
      color: 'bg-blue-500/10 text-blue-600 border-blue-200',
      totalCount: `${students.length} Enrolled`,
      onPdf: () => exportFullStudentsMasterPDF(students, settings),
      onExcel: () => exportFullStudentsMasterToExcel(students, settings.instituteName)
    },
    {
      id: 'fees',
      category: 'fees',
      title: 'Fee Collections & Transactions Register',
      description: 'Full payment transaction ledger, payment modes (Cash/UPI), receipt vouchers, and dates.',
      icon: CreditCard,
      color: 'bg-emerald-500/10 text-emerald-600 border-emerald-200',
      totalCount: `${payments.length} Transactions`,
      onPdf: () => exportFeeStructurePDF(students, settings),
      onExcel: () => exportPaymentsToExcel(payments, settings.instituteName)
    },
    {
      id: 'defaulters',
      category: 'fees',
      title: 'Outstanding Dues & Fee Defaulters',
      description: 'Detailed list of students with pending fee balances, contact numbers, and unpaid terms.',
      icon: AlertCircle,
      color: 'bg-rose-500/10 text-rose-600 border-rose-200',
      totalCount: `${defaultersList.length} Defaulters`,
      onPdf: () => exportFeeStructurePDF(defaultersList, settings),
      onExcel: () => exportDefaultersToExcel(defaultersList, settings.instituteName)
    },
    {
      id: 'attendance',
      category: 'attendance',
      title: 'Daily & Monthly Attendance Register',
      description: 'Institutional attendance register sheet with present, absent, leave counts and percentages.',
      icon: CalendarCheck,
      color: 'bg-indigo-500/10 text-indigo-600 border-indigo-200',
      totalCount: `${Object.keys(attendance).length} Days Logged`,
      onPdf: () => exportTodayAttendancePDF(students, attendance, new Date().toISOString().split('T')[0], settings),
      onExcel: () => exportAttendanceToExcel(students, attendance, settings.instituteName)
    },
    {
      id: 'payroll',
      category: 'fees',
      title: 'Staff Payroll & Teacher Salary Register',
      description: 'Monthly teacher compensation, payment statuses, bank disbursements, and salary slips register.',
      icon: CreditCard,
      color: 'bg-emerald-500/10 text-emerald-600 border-emerald-200',
      totalCount: `${teachers.length} Active Staff`,
      onPdf: () => {
        showToast('Opening Faculty Payroll Register...', 'info');
        window.print();
      },
      onExcel: () => exportFacultyToExcel(teachers, settings.instituteName)
    },
    {
      id: 'routine',
      category: 'academic',
      title: 'Weekly School Routine & Timetables',
      description: 'Class-wise periods, teacher allocations, subject timing, and room distribution.',
      icon: Calendar,
      color: 'bg-blue-500/10 text-blue-600 border-blue-200',
      totalCount: `${settings.schoolClasses?.length || 15} Classes`,
      onPdf: () => {
        window.location.href = '/timetable';
      },
      onExcel: () => exportFacultyToExcel(teachers, settings.instituteName)
    },
    {
      id: 'academic',
      category: 'academic',
      title: 'Exam Results & Academic Performance',
      description: 'Term marks sheets, subject performance breakdown, grades, and passing percentages.',
      icon: Award,
      color: 'bg-amber-500/10 text-amber-600 border-amber-200',
      totalCount: `${results.length} Marksheets`,
      onPdf: () => exportExamResultsPDF(results, students, settings),
      onExcel: () => exportExamResultsToExcel(results, students, settings.instituteName)
    },
    {
      id: 'faculty',
      category: 'students',
      title: 'Faculty & Teachers Master Directory',
      description: 'Staff credentials, assigned classes, subject expertise, and contact directories.',
      icon: GraduationCap,
      color: 'bg-purple-500/10 text-purple-600 border-purple-200',
      totalCount: `${teachers.length} Faculty Members`,
      onPdf: () => exportFacultyPDF(teachers, settings),
      onExcel: () => exportFacultyToExcel(teachers, settings.instituteName)
    }
  ];

  const filteredReports = reportsList.filter(r => selectedCategory === 'all' || r.category === selectedCategory);

  return (
    <div className="space-y-6 pb-16 font-sans">

      {/* Hidden File Input for Excel Import */}
      <input
        type="file"
        ref={importFileRef}
        onChange={handleFileSelected}
        accept=".xlsx, .xls, .csv"
        className="hidden"
      />

      {/* Top Header Navigation Tabs */}
      <div className="flex items-center justify-between gap-4 border-b border-border pb-1">
        <div className="flex items-center gap-2 overflow-x-auto custom-scrollbar">
          <button
            onClick={() => setActiveTab('master')}
            className={`px-4 py-2.5 rounded-xl text-xs font-extrabold transition-all cursor-pointer whitespace-nowrap flex items-center gap-2 ${activeTab === 'master'
                ? 'bg-primary text-white shadow-md'
                : 'text-text-secondary hover:text-text hover:bg-surface2'
              }`}
          >
            <Database className="w-4 h-4" />
            <span>Complete Student Master Data</span>
          </button>

          <button
            onClick={() => setActiveTab('center')}
            className={`px-4 py-2.5 rounded-xl text-xs font-extrabold transition-all cursor-pointer whitespace-nowrap flex items-center gap-2 ${activeTab === 'center'
                ? 'bg-primary text-white shadow-md'
                : 'text-text-secondary hover:text-text hover:bg-surface2'
              }`}
          >
            <Award className="w-4 h-4" />
            <span>Institutional Reports Center</span>
          </button>

          <button
            onClick={() => setActiveTab('bulk')}
            className={`px-4 py-2.5 rounded-xl text-xs font-extrabold transition-all cursor-pointer whitespace-nowrap flex items-center gap-2 ${activeTab === 'bulk'
                ? 'bg-primary text-white shadow-md'
                : 'text-text-secondary hover:text-text hover:bg-surface2'
              }`}
          >
            <Layers className="w-4 h-4" />
            <span>Excel Template & Bulk Import Hub</span>
          </button>
        </div>

        {/* Action Header Button for Master Template */}
        <div className="hidden sm:flex items-center gap-2">
          <button
            onClick={() => downloadStudentImportTemplate(settings.instituteName)}
            className="px-3.5 py-2 rounded-xl bg-white border border-border hover:bg-surface2 text-text font-bold text-xs flex items-center gap-1.5 cursor-pointer shadow-2xs transition-all"
            title="Download formatted Excel template with sample data"
          >
            <Download className="w-3.5 h-3.5 text-primary" />
            <span>Download Template (.xlsx)</span>
          </button>
        </div>
      </div>

      {/* ─────────────────────────────────────────────────────────────────────────────
          TAB 1: COMPLETE STUDENT MASTER DATA & FULL DETAILS SUITE
          ───────────────────────────────────────────────────────────────────────────── */}
      {activeTab === 'master' && (
        <div className="space-y-6 animate-in fade-in duration-200">

          {/* Top Banner & Fast Action Bar */}
          <div className="bg-gradient-to-r from-[#eff4ff] via-[#dce9ff] to-[#eff4ff] p-6 rounded-3xl border border-[#c8c4d5]/40 shadow-xs flex flex-col lg:flex-row lg:items-center justify-between gap-5">
            <div>
              <div className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-white/80 text-[11px] font-bold text-primary mb-2 shadow-2xs">
                <Database className="w-3.5 h-3.5 text-primary" />
                <span>Student Master Records (All Fields)</span>
              </div>
              <h2 className="text-2xl font-black text-text tracking-tight">
                Complete Student Master Database
              </h2>
              <p className="text-xs text-text-secondary font-medium mt-0.5">
                Full profile details, academic records, guardian contacts, fee particulars, and 1-click bulk import/export.
              </p>
            </div>

            {/* Quick Action Button Group */}
            <div className="flex flex-wrap items-center gap-2.5">
              <button
                onClick={() => downloadStudentImportTemplate(settings.instituteName)}
                className="px-3.5 py-2.5 rounded-xl bg-white border border-border hover:bg-surface2 text-text font-bold text-xs flex items-center gap-2 cursor-pointer shadow-xs transition-all"
                title="Download standard Excel import template"
              >
                <Download className="w-4 h-4 text-primary" />
                <span>Template (.xlsx)</span>
              </button>

              <button
                onClick={() => importFileRef.current?.click()}
                className="px-4 py-2.5 rounded-xl bg-emerald-600 hover:bg-emerald-700 text-white font-bold text-xs flex items-center gap-2 cursor-pointer shadow-md transition-all active:scale-95"
                title="Upload and import student Excel spreadsheet"
              >
                <Upload className="w-4 h-4" />
                <span>Import from Excel</span>
              </button>

              <button
                onClick={() => exportFullStudentsMasterToExcel(filteredMasterStudents, settings.instituteName)}
                className="px-4 py-2.5 rounded-xl bg-primary hover:bg-primary-dark text-white font-bold text-xs flex items-center gap-2 cursor-pointer shadow-md transition-all active:scale-95"
                title="Export complete database to Excel (.xlsx)"
              >
                <FileSpreadsheet className="w-4 h-4" />
                <span>Export Full Excel</span>
              </button>

              <button
                onClick={() => exportFullStudentsMasterPDF(filteredMasterStudents, settings)}
                className="px-4 py-2.5 rounded-xl bg-[#0b1c30] hover:bg-black text-white font-bold text-xs flex items-center gap-2 cursor-pointer shadow-md transition-all active:scale-95"
                title="Export formal landscape PDF Register"
              >
                <Printer className="w-4 h-4" />
                <span>Master Register (PDF)</span>
              </button>
            </div>
          </div>

          {/* Quick Metrics Cards */}
          <div className="grid grid-cols-2 lg:grid-cols-4 gap-4 text-xs">
            <div className="bg-white border border-border rounded-2xl p-4 shadow-xs">
              <span className="text-text-secondary font-bold uppercase text-[10px] tracking-wider">Total Enrolled</span>
              <p className="text-2xl font-black text-primary mt-1">{students.length}</p>
              <p className="text-[10px] text-text-muted mt-0.5">Active Academic Session {settings.currentSession || '2026-27'}</p>
            </div>

            <div className="bg-white border border-border rounded-2xl p-4 shadow-xs">
              <span className="text-text-secondary font-bold uppercase text-[10px] tracking-wider">Filtered Records</span>
              <p className="text-2xl font-black text-text mt-1">{filteredMasterStudents.length}</p>
              <p className="text-[10px] text-text-muted mt-0.5">Matching active filters</p>
            </div>

            <div className="bg-white border border-border rounded-2xl p-4 shadow-xs">
              <span className="text-text-secondary font-bold uppercase text-[10px] tracking-wider">Fee Collections</span>
              <p className="text-2xl font-black text-emerald-600 mt-1">₹{(stats.totalFeesCollected || 0).toLocaleString('en-IN')}</p>
              <p className="text-[10px] text-emerald-600 font-semibold mt-0.5">Total collected so far</p>
            </div>

            <div className="bg-white border border-border rounded-2xl p-4 shadow-xs">
              <span className="text-text-secondary font-bold uppercase text-[10px] tracking-wider">Outstanding Dues</span>
              <p className="text-2xl font-black text-rose-600 mt-1">₹{(stats.totalFeesPending || 0).toLocaleString('en-IN')}</p>
              <p className="text-[10px] text-rose-600 font-semibold mt-0.5">{defaultersList.length} students with dues</p>
            </div>
          </div>

          {/* Search, Filter & View Controls */}
          <div className="bg-white border border-border rounded-2xl p-4 shadow-xs flex flex-col md:flex-row items-center justify-between gap-3.5">
            <div className="relative flex-1 w-full">
              <Search className="w-4 h-4 text-text-muted absolute left-3.5 top-1/2 -translate-y-1/2" />
              <input
                type="text"
                value={searchQuery}
                onChange={e => { setSearchQuery(e.target.value); setCurrentPage(1); }}
                placeholder="Search by Student Name, Admission No, Student ID, Mobile, Father..."
                className="w-full pl-10 pr-4 py-2.5 rounded-xl bg-surface2 border border-border text-xs text-text font-medium focus:outline-none focus:border-primary"
              />
            </div>

            <div className="flex flex-wrap items-center gap-2 w-full md:w-auto">
              <select
                value={selectedClass}
                onChange={e => { setSelectedClass(e.target.value); setCurrentPage(1); }}
                className="px-3 py-2.5 rounded-xl bg-surface2 border border-border text-xs font-bold text-text focus:outline-none cursor-pointer"
              >
                <option value="all">All Classes / Courses</option>
                {settings.schoolClasses?.map(c => <option key={c} value={c}>Class {c}</option>)}
                {settings.computerCourses?.map(c => <option key={c} value={c}>{c}</option>)}
              </select>

              <select
                value={selectedFeeStatus}
                onChange={e => { setSelectedFeeStatus(e.target.value); setCurrentPage(1); }}
                className="px-3 py-2.5 rounded-xl bg-surface2 border border-border text-xs font-bold text-text focus:outline-none cursor-pointer"
              >
                <option value="all">All Fee Status</option>
                <option value="paid">Paid (No Dues)</option>
                <option value="due">Pending Dues</option>
                <option value="unpaid">Unpaid</option>
              </select>

              <select
                value={selectedStatus}
                onChange={e => { setSelectedStatus(e.target.value); setCurrentPage(1); }}
                className="px-3 py-2.5 rounded-xl bg-surface2 border border-border text-xs font-bold text-text focus:outline-none cursor-pointer"
              >
                <option value="all">All Status</option>
                <option value="active">Active</option>
                <option value="left">Left</option>
                <option value="completed">Completed</option>
              </select>
            </div>
          </div>

          {/* Master Full Details Data Table */}
          <div className="bg-white border border-border rounded-2xl shadow-sm overflow-hidden flex flex-col">
            <div className="overflow-x-auto max-h-[600px] overflow-y-auto custom-scrollbar">
              <table className="w-full text-left text-xs border-collapse">
                <thead>
                  <tr className="bg-surface2/80 border-b border-border text-text-secondary font-bold text-[10px] uppercase sticky top-0 z-10">
                    <th className="py-3 px-4 w-12 text-center">S.N</th>
                    <th className="py-3 px-4">Student Particulars</th>
                    <th className="py-3 px-4">Admission & Roll</th>
                    <th className="py-3 px-4">Class / Course</th>
                    <th className="py-3 px-4">Guardian & Mobile</th>
                    <th className="py-3 px-4">Date of Birth & Gender</th>
                    <th className="py-3 px-4">Total Fees</th>
                    <th className="py-3 px-4">Paid Fees</th>
                    <th className="py-3 px-4">Dues & Status</th>
                    <th className="py-3 px-4 text-center">Status</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-border text-text">
                  {paginatedStudents.length === 0 ? (
                    <tr>
                      <td colSpan={10} className="py-16 text-center text-text-muted text-xs">
                        No student records found matching the current search criteria.
                      </td>
                    </tr>
                  ) : (
                    paginatedStudents.map((s, idx) => {
                      const m = calculateStudentFeeMetrics(s, payments);
                      const total = m.setTotalFees;
                      const paid = m.totalPaid;
                      const pending = m.currentDue;
                      const isPaid = pending <= 0 && (total > 0 || paid > 0);
                      const isUnpaid = paid <= 0 && pending > 0;

                      return (
                        <tr key={s.id || idx} className="hover:bg-surface2/40 transition-colors group">
                          <td className="py-3 px-4 text-center font-mono text-text-muted font-bold text-[11px]">
                            {(currentPage - 1) * pageSize + idx + 1}
                          </td>

                          {/* Student Name & Avatar */}
                          <td className="py-3 px-4">
                            <div className="flex items-center gap-2.5">
                              <div className="w-8 h-8 rounded-full bg-primary/10 text-primary flex items-center justify-center font-bold text-xs flex-shrink-0">
                                {s.photoPath ? <img src={s.photoPath} alt={s.name} className="w-full h-full object-cover rounded-full" /> : s.name?.charAt(0) || 'S'}
                              </div>
                              <div>
                                <div className="font-bold text-text group-hover:text-primary transition-colors">{s.name}</div>
                                <div className="text-[10px] text-text-secondary font-mono">ID: {s.studentId}</div>
                              </div>
                            </div>
                          </td>

                          {/* Admission & Roll */}
                          <td className="py-3 px-4">
                            <div className="font-mono font-bold text-primary">{s.admissionNumber || '-'}</div>
                            <div className="text-[10px] text-text-muted">Roll: {s.rollNumber || '—'}</div>
                          </td>

                          {/* Class / Course */}
                          <td className="py-3 px-4">
                            <div className="font-bold text-text">
                              {s.studentType === 'school' ? `Class ${s.className || ''}` : s.course}
                            </div>
                            <div className="text-[10px] text-text-muted">
                              {s.studentType === 'school' ? `Sec ${s.section || 'A'}` : (s.batch || 'General')}
                            </div>
                          </td>

                          {/* Guardian & Contact */}
                          <td className="py-3 px-4">
                            <div className="font-semibold text-text">{s.fatherName || '—'}</div>
                            <div className="text-[10px] text-text-secondary font-mono flex items-center gap-1">
                              <span>📞 {s.mobile}</span>
                              {s.alternateMobile && <span className="text-text-muted">· {s.alternateMobile}</span>}
                            </div>
                          </td>

                          {/* DOB & Gender */}
                          <td className="py-3 px-4">
                            <div className="font-mono text-text">{s.dob || '—'}</div>
                            <div className="text-[10px] text-text-muted">{s.gender || 'Male'}</div>
                          </td>

                          {/* Total Fees */}
                          <td className="py-3 px-4 font-mono font-bold text-text">
                            ₹{total.toLocaleString('en-IN')}
                          </td>

                          {/* Paid Fees */}
                          <td className="py-3 px-4 font-mono font-bold text-emerald-600">
                            ₹{paid.toLocaleString('en-IN')}
                          </td>

                          {/* Dues & Fee Status */}
                          <td className="py-3 px-4">
                            <span className={`inline-flex px-2 py-0.5 rounded-md text-[10px] font-bold ${isPaid
                                ? 'bg-emerald-50 text-emerald-700 border border-emerald-200'
                                : isUnpaid
                                  ? 'bg-rose-50 text-rose-700 border border-rose-200'
                                  : 'bg-amber-50 text-amber-700 border border-amber-200'
                              }`}>
                              {isPaid ? '✓ Paid' : `Due ₹${pending.toLocaleString('en-IN')}`}
                            </span>
                          </td>

                          {/* Enrollment Status */}
                          <td className="py-3 px-4 text-center">
                            <span className="inline-flex px-2 py-0.5 rounded-full text-[9px] font-bold uppercase bg-emerald-50 text-emerald-700 border border-emerald-200">
                              {s.status || 'Active'}
                            </span>
                          </td>
                        </tr>
                      );
                    })
                  )}
                </tbody>
              </table>
            </div>

            {/* Pagination Controls */}
            <div className="px-5 py-4 border-t border-border bg-surface2/30 flex flex-col sm:flex-row items-center justify-between gap-3 text-xs text-text-secondary">
              <span>
                Showing {Math.min(1, filteredMasterStudents.length) + (currentPage - 1) * pageSize} - {Math.min(currentPage * pageSize, filteredMasterStudents.length)} of {filteredMasterStudents.length} student records
              </span>

              <div className="flex items-center gap-2">
                <button
                  onClick={() => setCurrentPage(p => Math.max(1, p - 1))}
                  disabled={currentPage === 1}
                  className="p-1.5 rounded-lg bg-white border border-border disabled:opacity-40 cursor-pointer"
                >
                  <ChevronLeft className="w-4 h-4" />
                </button>
                <span className="px-3 py-1 bg-white border border-border rounded-lg font-bold text-primary">
                  Page {currentPage} of {totalPages}
                </span>
                <button
                  onClick={() => setCurrentPage(p => Math.min(totalPages, p + 1))}
                  disabled={currentPage === totalPages}
                  className="p-1.5 rounded-lg bg-white border border-border disabled:opacity-40 cursor-pointer"
                >
                  <ChevronRight className="w-4 h-4" />
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* ─────────────────────────────────────────────────────────────────────────────
          TAB 2: INSTITUTIONAL MASTER REPORTS CENTER
          ───────────────────────────────────────────────────────────────────────────── */}
      {activeTab === 'center' && (
        <div className="space-y-6 animate-in fade-in duration-200">
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
            <div>
              <h2 className="text-xl lg:text-2xl font-bold text-text tracking-tight">Institutional Reports & Exports</h2>
              <p className="text-xs text-text-secondary mt-0.5 font-medium">Download complete institutional data in official PDF and Excel formats with 1-click.</p>
            </div>

            {/* Filter categories */}
            <div className="flex items-center gap-1.5 bg-surface2 p-1 rounded-xl border border-border overflow-x-auto text-xs font-bold">
              {['all', 'students', 'fees', 'attendance', 'academic'].map(cat => (
                <button
                  key={cat}
                  onClick={() => setSelectedCategory(cat)}
                  className={`px-3 py-1 rounded-lg capitalize transition-colors cursor-pointer ${selectedCategory === cat ? 'bg-primary text-white shadow-2xs' : 'text-text-secondary hover:text-text'
                    }`}
                >
                  {cat === 'all' ? 'All Reports' : cat}
                </button>
              ))}
            </div>
          </div>

          {/* ── Attendance Summary & Date Range Card ── */}
          {(selectedCategory === 'all' || selectedCategory === 'attendance') && (
            <div className="bg-white border border-indigo-200 rounded-3xl p-6 shadow-sm space-y-4">
              <div className="flex flex-col lg:flex-row lg:items-center justify-between gap-4 border-b border-border pb-4">
                <div className="flex items-center gap-3">
                  <div className="w-10 h-10 rounded-xl bg-indigo-50 border border-indigo-200 text-indigo-600 flex items-center justify-center font-bold">
                    <CalendarCheck className="w-5 h-5" />
                  </div>
                  <div>
                    <h3 className="font-bold text-base text-text">Student Attendance Date Range Summary</h3>
                    <p className="text-xs text-text-secondary mt-0.5">Filter institutional attendance across custom date spans with per-student metrics.</p>
                  </div>
                </div>

                <div className="flex flex-wrap items-center gap-3">
                  <div className="flex items-center gap-2 bg-surface2 px-3 py-1.5 rounded-xl border border-border text-xs">
                    <span className="font-bold text-text-secondary">From:</span>
                    <input
                      type="date"
                      value={attFromDate}
                      onChange={e => setAttFromDate(e.target.value)}
                      className="bg-transparent font-bold text-text focus:outline-none cursor-pointer"
                    />
                    <span className="font-bold text-text-secondary ml-1">To:</span>
                    <input
                      type="date"
                      value={attToDate}
                      onChange={e => setAttToDate(e.target.value)}
                      className="bg-transparent font-bold text-text focus:outline-none cursor-pointer"
                    />
                  </div>

                  <button
                    onClick={handleExportAttendanceRangeExcel}
                    className="px-3.5 py-2 rounded-xl bg-emerald-50 hover:bg-emerald-100 text-emerald-700 font-bold text-xs flex items-center gap-1.5 border border-emerald-200 cursor-pointer transition-colors"
                  >
                    <FileSpreadsheet className="w-4 h-4 text-emerald-600" />
                    <span>Export Range Excel</span>
                  </button>

                  <button
                    onClick={() => exportDateRangeAttendancePDF(students, attendance, attFromDate, attToDate, settings)}
                    className="px-3.5 py-2 rounded-xl bg-indigo-600 hover:bg-indigo-700 text-white font-bold text-xs flex items-center gap-1.5 shadow-sm cursor-pointer transition-colors"
                  >
                    <Download className="w-4 h-4" />
                    <span>Export Range PDF</span>
                  </button>
                </div>
              </div>

              {/* Attendance Range Metrics */}
              <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 text-xs">
                <div className="bg-indigo-50/60 border border-indigo-100 rounded-2xl p-3.5">
                  <span className="text-[10px] font-bold text-indigo-700 uppercase tracking-wider">Total Students</span>
                  <p className="text-xl font-black text-indigo-900 mt-0.5">{totalAttStudents}</p>
                  <p className="text-[10px] text-indigo-600 font-medium mt-0.5">Enrolled institutional students</p>
                </div>

                <div className="bg-emerald-50/60 border border-emerald-100 rounded-2xl p-3.5">
                  <span className="text-[10px] font-bold text-emerald-700 uppercase tracking-wider">Total Present</span>
                  <p className="text-xl font-black text-emerald-900 mt-0.5">{totalAttPresent}</p>
                  <p className="text-[10px] text-emerald-600 font-medium mt-0.5">Present days logged</p>
                </div>

                <div className="bg-rose-50/60 border border-rose-100 rounded-2xl p-3.5">
                  <span className="text-[10px] font-bold text-rose-700 uppercase tracking-wider">Total Absent</span>
                  <p className="text-xl font-black text-rose-900 mt-0.5">{totalAttAbsent}</p>
                  <p className="text-[10px] text-rose-600 font-medium mt-0.5">Absent days logged</p>
                </div>

                <div className="bg-amber-50/60 border border-amber-100 rounded-2xl p-3.5">
                  <span className="text-[10px] font-bold text-amber-700 uppercase tracking-wider">Average Attendance</span>
                  <p className="text-xl font-black text-amber-900 mt-0.5">{overallAttPct}%</p>
                  <p className="text-[10px] text-amber-600 font-medium mt-0.5">{totalAttDays} total student-days</p>
                </div>
              </div>

              {/* Student Attendance Breakdown Table */}
              <div className="border border-border rounded-2xl overflow-hidden max-h-72 overflow-y-auto custom-scrollbar">
                <table className="w-full text-left text-xs border-collapse">
                  <thead>
                    <tr className="bg-surface2/80 border-b border-border text-text-secondary font-bold text-[10px] uppercase sticky top-0 z-10">
                      <th className="py-2.5 px-4 w-12 text-center">#</th>
                      <th className="py-2.5 px-4">Student</th>
                      <th className="py-2.5 px-4">Class / Course</th>
                      <th className="py-2.5 px-4 text-center">Total Days</th>
                      <th className="py-2.5 px-4 text-center text-emerald-600">Present</th>
                      <th className="py-2.5 px-4 text-center text-rose-600">Absent</th>
                      <th className="py-2.5 px-4 text-center text-amber-600">Leave</th>
                      <th className="py-2.5 px-4 text-right">Attendance %</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-border text-text">
                    {attSummaryList.length === 0 ? (
                      <tr>
                        <td colSpan={8} className="py-8 text-center text-text-muted text-xs">
                          No attendance data recorded in the selected date range.
                        </td>
                      </tr>
                    ) : (
                      attSummaryList.map((r, idx) => (
                        <tr key={r.student.id || idx} className="hover:bg-surface2/30 transition-colors">
                          <td className="py-2.5 px-4 text-center font-bold text-text-muted">{idx + 1}</td>
                          <td className="py-2.5 px-4 font-bold text-text">
                            <div>{r.student.name}</div>
                            <div className="text-[9px] text-text-muted">ID: {r.student.studentId || '-'}</div>
                          </td>
                          <td className="py-2.5 px-4 text-text-secondary font-medium">
                            {r.student.studentType === 'school' ? `Class ${r.student.className || ''}` : (r.student.course || '-')}
                          </td>
                          <td className="py-2.5 px-4 text-center font-bold">{r.total}</td>
                          <td className="py-2.5 px-4 text-center font-bold text-emerald-600">{r.present}</td>
                          <td className="py-2.5 px-4 text-center font-bold text-rose-600">{r.absent}</td>
                          <td className="py-2.5 px-4 text-center font-bold text-amber-600">{r.leave}</td>
                          <td className="py-2.5 px-4 text-right font-black">
                            <span className={`px-2 py-0.5 rounded-md text-[10px] ${Number(r.pct) >= 75 ? 'bg-emerald-100 text-emerald-700' : Number(r.pct) >= 50 ? 'bg-amber-100 text-amber-700' : 'bg-rose-100 text-rose-700'
                              }`}>
                              {r.pct}%
                            </span>
                          </td>
                        </tr>
                      ))
                    )}
                  </tbody>
                </table>
              </div>
            </div>
          )}

          {/* Master 6 Report Cards Grid */}
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-5">
            {filteredReports.map((report) => {
              const Icon = report.icon;
              return (
                <div
                  key={report.id}
                  className="bg-white border border-border rounded-2xl p-5 shadow-sm hover:shadow-md transition-all flex flex-col justify-between space-y-4"
                >
                  <div className="space-y-3">
                    <div className="flex items-center justify-between">
                      <div className={`w-10 h-10 rounded-xl flex items-center justify-center font-bold border ${report.color}`}>
                        <Icon className="w-5 h-5" />
                      </div>
                      <span className="text-[10px] font-bold text-text-secondary bg-surface2 px-2.5 py-1 rounded-full border border-border">
                        {report.totalCount}
                      </span>
                    </div>

                    <div>
                      <h3 className="font-bold text-sm text-text">{report.title}</h3>
                      <p className="text-xs text-text-secondary mt-1 leading-relaxed">{report.description}</p>
                    </div>
                  </div>

                  {/* 1-Click Action Buttons: PDF & Excel */}
                  <div className="grid grid-cols-2 gap-2 pt-3 border-t border-border/80">
                    <button
                      onClick={report.onPdf}
                      className="py-2 px-3 rounded-xl bg-primary hover:bg-primary-dark text-white font-bold text-xs flex items-center justify-center gap-1.5 shadow-2xs cursor-pointer transition-all active:scale-95"
                      title="Download PDF Document"
                    >
                      <Download className="w-3.5 h-3.5" />
                      <span>Download PDF</span>
                    </button>

                    <button
                      onClick={report.onExcel}
                      className="py-2 px-3 rounded-xl bg-emerald-50 hover:bg-emerald-100 text-emerald-700 font-bold text-xs flex items-center justify-center gap-1.5 border border-emerald-200 cursor-pointer transition-all active:scale-95"
                      title="Export Spreadsheet (.xlsx)"
                    >
                      <FileSpreadsheet className="w-3.5 h-3.5" />
                      <span>Export Excel</span>
                    </button>
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      )}

      {/* ─────────────────────────────────────────────────────────────────────────────
          TAB 3: EXCEL TEMPLATE DOWNLOAD & BULK IMPORT HUB
          ───────────────────────────────────────────────────────────────────────────── */}
      {activeTab === 'bulk' && (
        <div className="space-y-6 animate-in fade-in duration-200">
          <div>
            <h2 className="text-xl lg:text-2xl font-bold text-text tracking-tight">Excel Import & Backup Hub</h2>
            <p className="text-xs text-text-secondary mt-0.5 font-medium">
              Bulk import student rosters using the official app template or download full institutional backups.
            </p>
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">

            {/* Import Box */}
            <div className="bg-white border border-border rounded-2xl p-6 shadow-sm space-y-4">
              <h3 className="font-bold text-base text-text flex items-center gap-2">
                <Upload className="w-5 h-5 text-primary" />
                <span>Bulk Import Students from Excel</span>
              </h3>
              <p className="text-xs text-text-secondary leading-relaxed">
                Upload your school/institute student admission excel sheet (.xlsx or .csv). All student profiles and fee structures will be automatically synchronized into Firebase database.
              </p>

              <div
                onClick={() => importFileRef.current?.click()}
                className="border-2 border-dashed border-border rounded-2xl p-8 text-center hover:border-primary hover:bg-primary/5 transition-all cursor-pointer flex flex-col items-center justify-center gap-2.5"
              >
                <FileSpreadsheet className="w-10 h-10 text-emerald-600 animate-pulse" />
                <span className="text-xs font-bold text-text">Click to Browse or Drag Spreadsheet Here</span>
                <span className="text-[11px] text-text-muted">Supports .xlsx, .xls, and .csv formats</span>
              </div>

              <div className="pt-2 flex items-center justify-between">
                <button
                  onClick={() => downloadStudentImportTemplate(settings.instituteName)}
                  className="text-xs text-primary font-bold hover:underline flex items-center gap-1.5 cursor-pointer"
                >
                  <Download className="w-3.5 h-3.5" />
                  <span>Download Official Import Template (.xlsx)</span>
                </button>
              </div>
            </div>

            {/* Instant Backup Box */}
            <div className="bg-white border border-border rounded-2xl p-6 shadow-sm space-y-4 flex flex-col justify-between">
              <div>
                <h3 className="font-bold text-base text-text flex items-center gap-2">
                  <Database className="w-5 h-5 text-indigo-600" />
                  <span>Complete Database Backup & Exports</span>
                </h3>
                <p className="text-xs text-text-secondary mt-1 leading-relaxed">
                  Download full backup copies of your entire student directory, payment ledgers, and attendance registers with 1-click.
                </p>
              </div>

              <div className="space-y-3 pt-2">
                <button
                  onClick={() => exportFullStudentsMasterToExcel(students, settings.instituteName)}
                  className="w-full py-3 rounded-xl bg-primary hover:bg-primary-dark text-white font-bold text-xs flex items-center justify-center gap-2 shadow-xs cursor-pointer transition-all active:scale-95"
                >
                  <FileSpreadsheet className="w-4 h-4" />
                  <span>Export All Students Full Excel Master (.xlsx)</span>
                </button>

                <button
                  onClick={() => exportFullStudentsMasterPDF(students, settings)}
                  className="w-full py-3 rounded-xl bg-[#0b1c30] hover:bg-black text-white font-bold text-xs flex items-center justify-center gap-2 shadow-xs cursor-pointer transition-all active:scale-95"
                >
                  <Printer className="w-4 h-4" />
                  <span>Download Full Student Directory Register (PDF)</span>
                </button>

                <button
                  onClick={() => exportPaymentsToExcel(payments, settings.instituteName)}
                  className="w-full py-3 rounded-xl bg-emerald-600 hover:bg-emerald-700 text-white font-bold text-xs flex items-center justify-center gap-2 shadow-xs cursor-pointer transition-all active:scale-95"
                >
                  <CreditCard className="w-4 h-4" />
                  <span>Export Complete Fee Transactions Ledger</span>
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* ─────────────────────────────────────────────────────────────────────────────
          EXCEL IMPORT PREVIEW & CONFIRMATION MODAL
          ───────────────────────────────────────────────────────────────────────────── */}
      {previewRows && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-xs animate-in fade-in duration-200">
          <div className="bg-white border border-border rounded-3xl w-full max-w-4xl max-h-[90vh] shadow-2xl overflow-hidden flex flex-col animate-in zoom-in-95 duration-200">

            {/* Modal Header */}
            <div className="px-6 py-4 border-b border-border bg-surface2/60 flex items-center justify-between">
              <div className="flex items-center gap-2.5">
                <div className="w-9 h-9 rounded-xl bg-emerald-50 text-emerald-600 border border-emerald-200 flex items-center justify-center">
                  <FileSpreadsheet className="w-5 h-5" />
                </div>
                <div>
                  <h3 className="font-extrabold text-sm text-text">Import Preview & Validation</h3>
                  <p className="text-[11px] text-text-secondary">{previewRows.length} student records detected from spreadsheet.</p>
                </div>
              </div>
              <button
                onClick={() => setPreviewRows(null)}
                disabled={isImporting}
                className="p-1 rounded-lg text-text-muted hover:text-text cursor-pointer"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            {/* Modal Body: Preview Table */}
            <div className="p-6 overflow-y-auto flex-1 space-y-4">
              <div className="border border-border rounded-2xl overflow-hidden max-h-[420px] overflow-y-auto custom-scrollbar">
                <table className="w-full text-left text-xs border-collapse">
                  <thead>
                    <tr className="bg-surface2 text-text-secondary font-bold text-[10px] uppercase sticky top-0 z-10 border-b border-border">
                      <th className="py-2.5 px-3">#</th>
                      <th className="py-2.5 px-3">Student Name</th>
                      <th className="py-2.5 px-3">Admission No</th>
                      <th className="py-2.5 px-3">Class / Course</th>
                      <th className="py-2.5 px-3">Father's Name</th>
                      <th className="py-2.5 px-3">Mobile</th>
                      <th className="py-2.5 px-3">Fees (₹)</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-border">
                    {previewRows.slice(0, 50).map((r, i) => (
                      <tr key={i} className="hover:bg-surface2/30">
                        <td className="py-2 px-3 font-mono text-text-muted">{i + 1}</td>
                        <td className="py-2 px-3 font-bold text-text">{r.name}</td>
                        <td className="py-2 px-3 font-mono text-primary font-semibold">{r.admissionNumber}</td>
                        <td className="py-2 px-3">{r.studentType === 'school' ? `Class ${r.className}` : r.course}</td>
                        <td className="py-2 px-3">{r.fatherName}</td>
                        <td className="py-2 px-3 font-mono">{r.mobile}</td>
                        <td className="py-2 px-3 font-mono font-bold text-emerald-600">₹{r.totalFees}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>

              {previewRows.length > 50 && (
                <p className="text-[11px] text-text-muted text-center italic">
                  Showing first 50 rows of {previewRows.length} total students.
                </p>
              )}

              {/* Progress Bar during import */}
              {isImporting && (
                <div className="space-y-1.5 p-3 rounded-xl bg-primary/5 border border-primary/20">
                  <div className="flex justify-between text-xs font-bold text-primary">
                    <span>Importing students to cloud database...</span>
                    <span>{importProgress.current} / {importProgress.total}</span>
                  </div>
                  <div className="w-full h-2 bg-primary/20 rounded-full overflow-hidden">
                    <div
                      className="h-full bg-primary transition-all duration-200"
                      style={{ width: `${Math.round((importProgress.current / Math.max(1, importProgress.total)) * 100)}%` }}
                    />
                  </div>
                </div>
              )}
            </div>

            {/* Modal Footer Actions */}
            <div className="px-6 py-4 border-t border-border bg-surface2/40 flex items-center justify-end gap-3">
              <button
                type="button"
                onClick={() => setPreviewRows(null)}
                disabled={isImporting}
                className="px-4 py-2 rounded-xl bg-surface2 hover:bg-border text-text font-bold text-xs cursor-pointer"
              >
                Cancel
              </button>

              <button
                type="button"
                onClick={handleConfirmImport}
                disabled={isImporting}
                className="px-6 py-2.5 rounded-xl bg-primary hover:bg-primary-dark text-white font-bold text-xs shadow-md flex items-center gap-2 cursor-pointer transition-all active:scale-95 disabled:opacity-50"
              >
                {isImporting ? <RefreshCw className="w-4 h-4 animate-spin" /> : <CheckCircle className="w-4 h-4" />}
                <span>{isImporting ? `Importing (${importProgress.current}/${importProgress.total})...` : `Confirm & Import ${previewRows.length} Students`}</span>
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
