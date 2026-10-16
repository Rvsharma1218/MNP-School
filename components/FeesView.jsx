'use client';

import React, { useState } from 'react';
import { useSchoolStore, calculateStudentFeeMetrics } from '../lib/store';
import {
  CreditCard, Plus, Search, Download, Printer, MessageSquare,
  Receipt, FileSpreadsheet, AlertCircle, TrendingUp, CheckCircle2,
  Trash2, Calendar, X, BarChart3, Info, Sparkles, ChevronDown, ChevronUp, Users
} from 'lucide-react';
import { exportPaymentsToExcel, exportDefaultersToExcel, openWhatsAppFeeReminder, openWhatsAppReceiptShare, openWhatsAppFeeStatement, exportReceiptPDF } from '../lib/exportUtils';
import CollectFeeModal from './CollectFeeModal';
import WhatsAppReminderModal from './WhatsAppReminderModal';

export default function FeesView() {
  const {
    students,
    payments,
    settings,
    stats,
    collectFeeStudent,
    setCollectFeeStudent,
    feeDetailStudent,
    setFeeDetailStudent,
    setIsFeeDetailSelectorOpen,
    setPrintReceiptData,
    whatsAppReminderData,
    setWhatsAppReminderData,
    deletePayment
  } = useSchoolStore();

  const [activeTab, setActiveTab] = useState('dashboard'); // 'dashboard' | 'ledger' | 'defaulters'
  const [searchQuery, setSearchQuery] = useState('');
  const [filterMode, setFilterMode] = useState('all'); // 'all' | 'date' | 'month'

  // Class filtering
  const [collectedClass, setCollectedClass] = useState('all'); // 'all' | class name
  const [pendingClass, setPendingClass] = useState('all'); // 'all' | class name

  // Pending date filtering
  const [pendingFilterMode, setPendingFilterMode] = useState('all'); // 'all' | 'date' | 'month'
  const todayStr = new Date().toISOString().split('T')[0];
  const [selectedDate, setSelectedDate] = useState(todayStr);
  const [selectedMonth, setSelectedMonth] = useState(todayStr.slice(0, 7)); // 'YYYY-MM'
  const [pendingSelectedDate, setPendingSelectedDate] = useState(todayStr);
  const [pendingSelectedMonth, setPendingSelectedMonth] = useState(todayStr.slice(0, 7));

  // Extract all distinct classes
  const availableClasses = React.useMemo(() => {
    const set = new Set();
    students.forEach(s => {
      const cls = s.studentType === 'school' ? s.className : s.course;
      if (cls && String(cls).trim()) {
        set.add(String(cls).trim());
      }
    });
    return Array.from(set).sort((a, b) => {
      const numA = parseInt(a.replace(/\D/g, ''), 10);
      const numB = parseInt(b.replace(/\D/g, ''), 10);
      if (!isNaN(numA) && !isNaN(numB)) return numA - numB;
      return a.localeCompare(b);
    });
  }, [students]);

  const getFilterLabel = () => {
    const classSuffix = collectedClass !== 'all' ? ` (Class ${collectedClass})` : '';
    if (filterMode === 'all') return `All-Time Collections${classSuffix}`;
    if (filterMode === 'date') {
      try {
        const d = new Date(selectedDate + 'T00:00:00');
        return `Collection on ${d.toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric' })}${classSuffix}`;
      } catch {
        return `Collection on ${selectedDate}${classSuffix}`;
      }
    }
    if (filterMode === 'month') {
      try {
        const [y, m] = selectedMonth.split('-');
        const d = new Date(Number(y), Number(m) - 1, 1);
        return `Collection in ${d.toLocaleDateString('en-IN', { month: 'long', year: 'numeric' })}${classSuffix}`;
      } catch {
        return `Collection in ${selectedMonth}${classSuffix}`;
      }
    }
    return `Fee Collections${classSuffix}`;
  };

  // Filter payments by class
  const classFilteredPayments = payments.filter(p => {
    if (collectedClass === 'all') return true;
    let student = null;
    if (p.studentId) {
      student = students.find(s => s.id === p.studentId || (s.studentId && s.studentId === p.studentId));
    }
    if (!student && (p.admissionNumber || p.admissionNo)) {
      const adm = String(p.admissionNumber || p.admissionNo).trim();
      student = students.find(s => (s.admissionNumber && String(s.admissionNumber).trim() === adm) || (s.admissionNo && String(s.admissionNo).trim() === adm));
    }
    if (!student && p.studentName && p.studentName.trim()) {
      const pName = p.studentName.trim().toLowerCase();
      student = students.find(s => s.name && s.name.trim().toLowerCase() === pName);
    }
    const cls = student ? (student.studentType === 'school' ? student.className : student.course) : (p.className || '');
    return String(cls).trim().toLowerCase() === String(collectedClass).trim().toLowerCase();
  });

  // Filter payments by selected date or month
  const dateFilteredPayments = classFilteredPayments.filter(p => {
    if (filterMode === 'all') return true;
    if (!p.paymentDate) return false;
    if (filterMode === 'date') {
      return p.paymentDate.startsWith(selectedDate);
    }
    if (filterMode === 'month') {
      return p.paymentDate.startsWith(selectedMonth);
    }
    return true;
  });

  const selectedDateCollected = dateFilteredPayments.reduce((acc, p) => acc + (Number(p.amount) || 0), 0);

  // Filter payments ledger by date/month and search query
  const filteredPayments = dateFilteredPayments.filter(p => {
    if (!searchQuery.trim()) return true;
    const q = searchQuery.toLowerCase();
    const student = students.find(s => s.id === p.studentId || (s.studentId && s.studentId === p.studentId));
    return (
      p.receiptNumber?.toLowerCase().includes(q) ||
      p.studentName?.toLowerCase().includes(q) ||
      student?.name?.toLowerCase().includes(q) ||
      p.paymentMode?.toLowerCase().includes(q) ||
      p.feeMonth?.toLowerCase().includes(q)
    );
  });

  // Group filtered payments by student with expandable accordion state
  const [ledgerViewMode, setLedgerViewMode] = useState('grouped'); // 'grouped' | 'flat'
  const [expandedStudents, setExpandedStudents] = useState({});

  const toggleStudentExpand = (key) => {
    setExpandedStudents(prev => ({
      ...prev,
      [key]: !prev[key]
    }));
  };

  const studentPaymentGroups = React.useMemo(() => {
    const map = new Map();
    filteredPayments.forEach(p => {
      // 1. Exact match by student ID (s.id or s.studentId)
      let student = null;
      if (p.studentId) {
        student = students.find(s => s.id === p.studentId || (s.studentId && s.studentId === p.studentId));
      }
      // 2. Fallback match by admission number if no studentId match
      if (!student && (p.admissionNumber || p.admissionNo)) {
        const adm = String(p.admissionNumber || p.admissionNo).trim();
        student = students.find(s => (s.admissionNumber && String(s.admissionNumber).trim() === adm) || (s.admissionNo && String(s.admissionNo).trim() === adm));
      }
      // 3. Fallback match by trimmed lowercase student name
      if (!student && p.studentName && p.studentName.trim()) {
        const pName = p.studentName.trim().toLowerCase();
        student = students.find(s => s.name && s.name.trim().toLowerCase() === pName);
      }

      // Unique key: prefer student.id, then p.studentId, then studentName, then receiptNumber
      const key = (student && student.id)
        ? student.id
        : (p.studentId || (p.studentName ? `name_${p.studentName.trim()}` : (p.receiptNumber || `rcpt_${Math.random()}`)));

      if (!map.has(key)) {
        map.set(key, {
          key,
          student: student || {
            id: key,
            name: p.studentName || 'Student',
            studentId: p.studentId || '',
            className: p.className || '',
            session: settings.currentSession
          },
          payments: [],
          totalPaid: 0,
        });
      }
      const entry = map.get(key);
      entry.payments.push(p);
      entry.totalPaid += Number(p.amount) || 0;
    });

    return Array.from(map.values()).sort((a, b) => {
      const dateA = a.payments[0]?.paymentDate ? new Date(a.payments[0].paymentDate).getTime() : 0;
      const dateB = b.payments[0]?.paymentDate ? new Date(b.payments[0].paymentDate).getTime() : 0;
      return dateB - dateA;
    });
  }, [filteredPayments, students, settings.currentSession]);

  // Filter Defaulters using live auto-accrued dues, class filter, and pending date filter
  const defaultersList = students.map(s => ({
    ...s,
    feeMetrics: calculateStudentFeeMetrics(s, payments)
  })).filter(s => {
    if (s.feeMetrics.currentDue <= 0) return false;

    // Class filter
    if (pendingClass !== 'all') {
      const cls = s.studentType === 'school' ? s.className : s.course;
      if (String(cls).trim().toLowerCase() !== String(pendingClass).trim().toLowerCase()) {
        return false;
      }
    }

    // Pending Date / Month filter
    if (pendingFilterMode === 'date') {
      if (pendingSelectedDate !== todayStr) {
        const selDate = new Date(pendingSelectedDate);
        if (s.admissionDate) {
          const adm = new Date(s.admissionDate);
          if (adm > selDate) return false;
        }
      }
    } else if (pendingFilterMode === 'month') {
      const [selYear, selMonth] = pendingSelectedMonth.split('-').map(Number);
      if (s.admissionDate) {
        const adm = new Date(s.admissionDate);
        if (adm.getFullYear() > selYear || (adm.getFullYear() === selYear && (adm.getMonth() + 1) > selMonth)) {
          return false;
        }
      }
    }

    if (!searchQuery.trim()) return true;
    const q = searchQuery.toLowerCase();
    return (
      s.name?.toLowerCase().includes(q) ||
      s.studentId?.toLowerCase().includes(q) ||
      s.mobile?.includes(q) ||
      (s.className && String(s.className).toLowerCase().includes(q))
    );
  });

  const totalDefaultersDue = defaultersList.reduce((acc, s) => acc + (Number(s.feeMetrics.currentDue) || 0), 0);

  // Global Dynamic Fee Totals (respecting selected class)
  const classStudents = collectedClass === 'all'
    ? students
    : students.filter(s => {
        const cls = s.studentType === 'school' ? s.className : s.course;
        return String(cls).trim().toLowerCase() === String(collectedClass).trim().toLowerCase();
      });

  const totalCollected = classFilteredPayments.reduce((acc, p) => acc + (Number(p.amount) || 0), 0);
  const totalPending = classStudents.reduce((acc, s) => {
    const m = calculateStudentFeeMetrics(s, payments);
    return acc + (Number(m.currentDue) || 0);
  }, 0);
  const totalExpected = totalCollected + totalPending;

  // Today's Real Collections
  const todayPayments = classFilteredPayments.filter(p => p.paymentDate && p.paymentDate.startsWith(todayStr));
  const todayCollected = todayPayments.reduce((a, p) => a + (Number(p.amount) || 0), 0);

  // Dynamic breakdown across fee heads from actual payment particulars
  const feeHeadTotals = {
    admissionFee: 0,
    tuitionFee: 0,
    examinationFee: 0,
    previousDues: 0,
    gameFee: 0,
    reAdmissionFee: 0,
    developmentFee: 0,
    schoolId: 0,
    tieBagBelt: 0,
    backDues: 0,
    transportFee: 0,
    otherFee: 0,
    lateFine: 0
  };

  payments.forEach(p => {
    if (p.particulars) {
      Object.keys(feeHeadTotals).forEach(k => {
        if (p.particulars[k]) feeHeadTotals[k] += Number(p.particulars[k]) || 0;
      });
    } else {
      feeHeadTotals.tuitionFee += Number(p.amount) || 0;
    }
  });

  const feeHeadItems = [
    { label: 'Tuition Fee', val: feeHeadTotals.tuitionFee, color: 'bg-[#0051d5]' },
    { label: 'Admission Fee', val: feeHeadTotals.admissionFee, color: 'bg-[#1f108e]' },
    { label: 'Examination Fee', val: feeHeadTotals.examinationFee, color: 'bg-amber-500' },
    { label: 'Transport / Bus Fee', val: feeHeadTotals.transportFee, color: 'bg-blue-600' },
    { label: 'Previous Dues', val: feeHeadTotals.previousDues, color: 'bg-rose-500' },
    { label: 'Development & Lab Fee', val: feeHeadTotals.developmentFee, color: 'bg-purple-500' },
    { label: 'Game & Sports Fee', val: feeHeadTotals.gameFee, color: 'bg-teal-500' },
    { label: 'School ID, Tie & Bag', val: (feeHeadTotals.schoolId + feeHeadTotals.tieBagBelt), color: 'bg-cyan-600' },
    { label: 'Re-Admission Fee', val: feeHeadTotals.reAdmissionFee, color: 'bg-indigo-400' },
    { label: 'Late Fine', val: feeHeadTotals.lateFine, color: 'bg-orange-500' },
  ];

  const renderClassFilterBar = (selected, onSelect, label = 'Filter by Class:') => (
    <div className="flex items-center gap-2 overflow-x-auto py-1 custom-scrollbar text-xs">
      <span className="text-[11px] font-bold text-text-secondary whitespace-nowrap">{label}</span>
      <button
        type="button"
        onClick={() => onSelect('all')}
        className={`px-3 py-1 rounded-xl font-bold transition-all cursor-pointer whitespace-nowrap text-xs ${
          selected === 'all'
            ? 'bg-primary text-white shadow-xs'
            : 'bg-surface2 hover:bg-border text-text border border-border'
        }`}
      >
        All Classes
      </button>
      {availableClasses.map(cls => (
        <button
          key={cls}
          type="button"
          onClick={() => onSelect(cls)}
          className={`px-3 py-1 rounded-xl font-bold transition-all cursor-pointer whitespace-nowrap text-xs ${
            selected === cls
              ? 'bg-primary text-white shadow-xs'
              : 'bg-surface2 hover:bg-border text-text border border-border'
          }`}
        >
          Class {cls}
        </button>
      ))}
    </div>
  );

  return (
    <div className="space-y-6 pb-12 animate-in fade-in duration-200 font-sans">
      {/* Top Tabs */}
      <div className="flex items-center gap-2 border-b border-border pb-1 overflow-x-auto custom-scrollbar">
        <button
          onClick={() => setActiveTab('dashboard')}
          className={`px-4 py-2 rounded-xl text-xs font-bold transition-all cursor-pointer whitespace-nowrap flex items-center gap-2 ${activeTab === 'dashboard'
              ? 'bg-primary text-white shadow-xs'
              : 'text-text-secondary hover:text-text hover:bg-surface2'
            }`}
        >
          <BarChart3 className="w-3.5 h-3.5" />
          <span>Fee Dashboard</span>
        </button>

        <button
          onClick={() => setActiveTab('ledger')}
          className={`px-4 py-2 rounded-xl text-xs font-bold transition-all cursor-pointer whitespace-nowrap flex items-center gap-2 ${activeTab === 'ledger'
              ? 'bg-primary text-white shadow-xs'
              : 'text-text-secondary hover:text-text hover:bg-surface2'
            }`}
        >
          <Receipt className="w-3.5 h-3.5" />
          <span>Transactions Register ({payments.length})</span>
        </button>

        <button
          onClick={() => setActiveTab('defaulters')}
          className={`px-4 py-2 rounded-xl text-xs font-bold transition-all cursor-pointer whitespace-nowrap flex items-center gap-2 ${activeTab === 'defaulters'
              ? 'bg-primary text-white shadow-xs'
              : 'text-text-secondary hover:text-text hover:bg-surface2'
            }`}
        >
          <AlertCircle className="w-3.5 h-3.5 text-rose-500" />
          <span>Outstanding Defaulters ({defaultersList.length})</span>
        </button>
      </div>

      {activeTab === 'dashboard' ? (
        /* ─── DASHBOARD VIEW ─── */
        <div className="space-y-6">
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
            <div>
              <h2 className="text-xl lg:text-2xl font-bold text-text tracking-tight">Fee Management</h2>
              <p className="text-xs text-text-secondary mt-0.5">Track collections, manage dues, and monitor fee structure allocations.</p>
            </div>

            <div className="flex items-center gap-2.5">
              {students.length > 0 && (
                <button
                  onClick={() => {
                    setIsFeeDetailSelectorOpen(true);
                    setFeeDetailStudent(students[0] || null);
                  }}
                  className="px-4 py-2 rounded-xl bg-primary hover:bg-primary-dark text-white font-bold text-xs shadow-md transition-all flex items-center gap-1.5 cursor-pointer"
                >
                  <Plus className="w-4 h-4" />
                  <span>Student Fee Structure & Pay</span>
                </button>
              )}
              <button
                onClick={() => exportPaymentsToExcel(payments, settings.instituteName)}
                className="px-3.5 py-2 rounded-xl bg-white border border-border hover:bg-surface2 text-text flex items-center gap-1.5 cursor-pointer text-xs font-bold"
              >
                <Download className="w-4 h-4 text-emerald-600" />
                <span>Export Report</span>
              </button>
            </div>
          </div>

          {/* Calendar, Date & Month Filter Bar */}
          <div className="bg-white border border-border rounded-2xl p-4 shadow-2xs space-y-3">
            <div className="flex flex-col lg:flex-row lg:items-center justify-between gap-3.5">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-xl bg-primary/10 text-primary flex items-center justify-center font-bold flex-shrink-0">
                  <Calendar className="w-5 h-5" />
                </div>
                <div>
                  <div className="text-xs font-bold text-text">
                    {filterMode === 'all'
                      ? 'All-Time Fee Collections'
                      : filterMode === 'date'
                      ? 'Date-Wise Fee Collection'
                      : 'Month-Wise Fee Collection'}
                  </div>
                  <div className="text-[11px] text-text-secondary mt-0.5">
                    {filterMode === 'all'
                      ? `Showing all-time recorded collections: ₹${totalCollected.toLocaleString('en-IN')} (${classFilteredPayments.length} receipts)`
                      : `Showing ${getFilterLabel()}: ₹${selectedDateCollected.toLocaleString('en-IN')} (${dateFilteredPayments.length} receipts)`}
                  </div>
                </div>
              </div>

              <div className="flex items-center gap-2 flex-wrap">
                {/* Quick Preset Buttons */}
                <button
                  type="button"
                  onClick={() => setFilterMode('all')}
                  className={`px-3 py-1.5 rounded-xl text-xs font-bold transition-all cursor-pointer ${
                    filterMode === 'all'
                      ? 'bg-primary text-white shadow-xs'
                      : 'bg-surface2 hover:bg-border text-text border border-border'
                  }`}
                >
                  All
                </button>

                <button
                  type="button"
                  onClick={() => {
                    setSelectedDate(todayStr);
                    setFilterMode('date');
                  }}
                  className={`px-3 py-1.5 rounded-xl text-xs font-bold transition-all cursor-pointer ${
                    filterMode === 'date' && selectedDate === todayStr
                      ? 'bg-primary text-white shadow-xs'
                      : 'bg-surface2 hover:bg-border text-text border border-border'
                  }`}
                >
                  Today
                </button>

                <button
                  type="button"
                  onClick={() => {
                    setSelectedMonth(todayStr.slice(0, 7));
                    setFilterMode('month');
                  }}
                  className={`px-3 py-1.5 rounded-xl text-xs font-bold transition-all cursor-pointer ${
                    filterMode === 'month' && selectedMonth === todayStr.slice(0, 7)
                      ? 'bg-primary text-white shadow-xs'
                      : 'bg-surface2 hover:bg-border text-text border border-border'
                  }`}
                >
                  This Month
                </button>

                {/* Specific Date Picker */}
                <div className={`flex items-center gap-1.5 px-2.5 py-1 rounded-xl border transition-all ${
                  filterMode === 'date' ? 'border-primary bg-primary/5 text-primary' : 'border-border bg-surface2 text-text'
                }`}>
                  <span className="text-[10px] font-bold uppercase text-text-secondary">Date:</span>
                  <input
                    type="date"
                    value={selectedDate}
                    onChange={(e) => {
                      if (e.target.value) {
                        setSelectedDate(e.target.value);
                        setFilterMode('date');
                      }
                    }}
                    className="bg-transparent text-xs font-bold text-text focus:outline-none cursor-pointer"
                    title="Choose a specific date"
                  />
                </div>

                {/* Specific Month Picker */}
                <div className={`flex items-center gap-1.5 px-2.5 py-1 rounded-xl border transition-all ${
                  filterMode === 'month' ? 'border-primary bg-primary/5 text-primary' : 'border-border bg-surface2 text-text'
                }`}>
                  <span className="text-[10px] font-bold uppercase text-text-secondary">Month:</span>
                  <input
                    type="month"
                    value={selectedMonth}
                    onChange={(e) => {
                      if (e.target.value) {
                        setSelectedMonth(e.target.value);
                        setFilterMode('month');
                      }
                    }}
                    className="bg-transparent text-xs font-bold text-text focus:outline-none cursor-pointer"
                    title="Choose a specific month"
                  />
                </div>
              </div>
            </div>

            {/* Class Filter Bar */}
            <div className="pt-2 border-t border-border/60">
              {renderClassFilterBar(collectedClass, setCollectedClass, 'Filter Collections by Class:')}
            </div>
          </div>

          {/* Stats metrics cards */}
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
            <div className="bg-white border border-border rounded-2xl p-5 shadow-xs flex items-center justify-between">
              <div>
                <div className="text-[10px] font-bold text-text-secondary uppercase">
                  {getFilterLabel()}
                </div>
                <div className="text-2xl font-black text-text mt-1">
                  ₹{(filterMode === 'all' ? totalCollected : selectedDateCollected).toLocaleString('en-IN')}
                </div>
                <p className="text-[10px] text-text-muted font-semibold mt-1">
                  {filterMode === 'all'
                    ? `${payments.length} receipts issued`
                    : `${dateFilteredPayments.length} receipts matching filter`}
                </p>
              </div>
              <div className="w-10 h-10 rounded-xl bg-emerald-50 text-emerald-600 flex items-center justify-center font-bold">₹</div>
            </div>

            <div className="bg-white border border-border rounded-2xl p-5 shadow-xs flex items-center justify-between">
              <div>
                <div className="text-[10px] font-bold text-text-secondary uppercase flex items-center gap-1.5">
                  <span>Pending Dues</span>
                  {totalPending > 0 && (
                    <span className="px-1.5 py-0.5 rounded bg-rose-100 text-rose-700 text-[8px] font-bold">Action Needed</span>
                  )}
                </div>
                <div className="text-2xl font-black text-rose-600 mt-1">₹{totalPending.toLocaleString('en-IN')}</div>
                <p className="text-[10px] text-text-muted mt-1">{defaultersList.length} students with pending dues</p>
              </div>
              <div className="w-10 h-10 rounded-xl bg-rose-50 text-rose-600 flex items-center justify-center font-bold">!</div>
            </div>

            <div className="bg-white border border-border rounded-2xl p-5 shadow-xs flex items-center justify-between">
              <div>
                <div className="text-[10px] font-bold text-text-secondary uppercase">
                  {selectedDate !== 'all' && selectedDate !== todayStr ? `Date: ${selectedDate}` : "Today's Collection"}
                </div>
                <div className="text-2xl font-black text-primary mt-1">
                  ₹{(selectedDate !== 'all' && selectedDate !== todayStr ? selectedDateCollected : todayCollected).toLocaleString('en-IN')}
                </div>
                <p className="text-[10px] text-text-muted mt-1">
                  {selectedDate !== 'all' && selectedDate !== todayStr
                    ? `${dateFilteredPayments.length} transactions recorded`
                    : `${todayPayments.length} transactions today`}
                </p>
              </div>
              <div className="w-10 h-10 rounded-xl bg-primary/10 text-primary flex items-center justify-center font-bold">✔</div>
            </div>
          </div>

          {/* Table & Structure layout */}
          <div className="grid grid-cols-1 lg:grid-cols-12 gap-6 items-start">
            {/* Left table: Recent Transactions */}
            <div className="lg:col-span-8 bg-white border border-border rounded-2xl shadow-sm overflow-hidden flex flex-col">
              <div className="px-5 py-4 border-b border-border bg-surface2/40 flex items-center justify-between">
                <span className="font-bold text-xs text-text uppercase">
                  Transactions {selectedDate !== 'all' ? `(${selectedDate})` : ''} ({filteredPayments.length})
                </span>
                {payments.length > 0 && (
                  <span className="text-[10px] font-bold text-primary cursor-pointer hover:underline" onClick={() => setActiveTab('ledger')}>View Full Ledger</span>
                )}
              </div>
              <div className="overflow-x-auto">
                <table className="w-full text-left text-xs border-collapse">
                  <thead>
                    <tr className="bg-surface2/60 border-b border-border text-text-secondary font-bold text-[10px] uppercase">
                      <th className="py-3 px-4">Date</th>
                      <th className="py-3 px-4">Student</th>
                      <th className="py-3 px-4">Fee Month</th>
                      <th className="py-3 px-4 text-right">Amount</th>
                      <th className="py-3 px-4 text-center">Mode</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-border text-text">
                    {payments.length === 0 ? (
                      <tr>
                        <td colSpan="5" className="py-10 text-center text-text-muted text-xs">
                          No fee payments recorded yet. Open a student's profile to record payments.
                        </td>
                      </tr>
                    ) : (
                      payments.slice(0, 5).map((p, idx) => {
                        const student = students.find(s => s.id === p.studentId);
                        return (
                          <tr
                            key={p.id ? `${p.id}_${idx}` : `pay_${idx}`}
                            onClick={() => {
                              if (student) {
                                setIsFeeDetailSelectorOpen(false);
                                setFeeDetailStudent(student);
                              }
                            }}
                            className="hover:bg-surface2/50 transition-colors cursor-pointer"
                            title="Click to view & manage student fee structure"
                          >
                            <td className="py-3 px-4 font-mono text-text-secondary">{p.paymentDate ? new Date(p.paymentDate).toLocaleDateString() : '-'}</td>
                            <td className="py-3 px-4 font-bold">
                              <div>
                                <div className="text-primary hover:underline">{p.studentName || student?.name}</div>
                                <div className="text-[9px] text-text-muted">ID: {student?.studentId || '-'} · {student?.admissionNumber || ''}</div>
                              </div>
                            </td>
                            <td className="py-3 px-4 text-text-secondary">{p.feeMonth || 'Monthly'}</td>
                            <td className="py-3 px-4 text-right font-black text-primary">₹{(Number(p.amount) || 0).toLocaleString('en-IN')}</td>
                            <td className="py-3 px-4 text-center"><span className="px-2 py-0.5 rounded bg-surface2 border border-border text-[9px] font-bold font-mono">{p.paymentMode || 'Cash'}</span></td>
                          </tr>
                        );
                      })
                    )}
                  </tbody>
                </table>
              </div>
            </div>

            {/* Right panel: Fee Collections Distribution */}
            <div className="lg:col-span-4 space-y-5">
              <div className="bg-white border border-border rounded-2xl p-6 shadow-sm space-y-4">
                <div className="flex items-center justify-between">
                  <h3 className="font-bold text-base text-text">Fee Collections Distribution</h3>
                  <span className="text-[10px] bg-primary/10 text-primary font-bold px-2 py-0.5 rounded-full">Active</span>
                </div>
                <p className="text-xs text-text-muted">Breakdown of recorded payments across institutional fee heads.</p>

                <div className="space-y-3 text-xs font-semibold text-text-secondary max-h-[380px] overflow-y-auto pr-1 custom-scrollbar">
                  {totalCollected === 0 ? (
                    <div className="py-8 text-center text-text-muted text-xs">
                      No collections recorded yet.
                    </div>
                  ) : (
                    feeHeadItems.filter(f => f.val > 0).map((fee, idx) => {
                      const pct = Math.round((fee.val / totalCollected) * 100);
                      return (
                        <div key={idx} className="space-y-1">
                          <div className="flex justify-between">
                            <span className="flex items-center gap-2">
                              <span className={`w-2 h-2 rounded-full ${fee.color}`} />
                              <span className="text-[11px] text-text">{fee.label}</span>
                            </span>
                            <span className="font-bold text-text text-[11px]">₹{fee.val.toLocaleString('en-IN')} ({pct}%)</span>
                          </div>
                          <div className="w-full h-1.5 bg-surface2 rounded-full overflow-hidden">
                            <div className={`h-full ${fee.color} rounded-full`} style={{ width: `${pct}%` }}></div>
                          </div>
                        </div>
                      );
                    })
                  )}
                </div>
              </div>
            </div>
          </div>
        </div>
      ) : activeTab === 'ledger' ? (
        /* ─── TRANSACTIONS REGISTER ─── */
        <div className="space-y-6">
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
            <div>
              <h2 className="text-xl lg:text-2xl font-bold text-text tracking-tight">Transactions Register</h2>
              <p className="text-xs text-text-secondary mt-0.5">Spreadsheet ledger of all recorded student fee receipts.</p>
            </div>
            <div className="flex items-center gap-2.5 flex-wrap">
              {/* View Mode Toggle: By Student (Accordion Dropdown) vs All Receipts (Flat) */}
              <div className="flex items-center bg-white p-1 rounded-xl border border-border shadow-2xs">
                <button
                  type="button"
                  onClick={() => setLedgerViewMode('grouped')}
                  className={`px-3 py-1.5 rounded-lg text-xs font-bold transition-all flex items-center gap-1.5 cursor-pointer ${
                    ledgerViewMode === 'grouped'
                      ? 'bg-primary text-white shadow-xs'
                      : 'text-text-secondary hover:text-text hover:bg-surface2'
                  }`}
                  title="Group payments by student with expandable dropdown of receipts"
                >
                  <Users className="w-3.5 h-3.5" />
                  <span>By Student ({studentPaymentGroups.length})</span>
                </button>
                <button
                  type="button"
                  onClick={() => setLedgerViewMode('flat')}
                  className={`px-3 py-1.5 rounded-lg text-xs font-bold transition-all flex items-center gap-1.5 cursor-pointer ${
                    ledgerViewMode === 'flat'
                      ? 'bg-primary text-white shadow-xs'
                      : 'text-text-secondary hover:text-text hover:bg-surface2'
                  }`}
                  title="Show all individual receipts in spreadsheet view"
                >
                  <Receipt className="w-3.5 h-3.5" />
                  <span>All Receipts ({filteredPayments.length})</span>
                </button>
              </div>

              <button
                onClick={() => exportPaymentsToExcel(filteredPayments, settings.instituteName)}
                className="px-4 py-2 rounded-xl bg-emerald-600 hover:bg-emerald-700 text-white font-bold text-xs shadow-md transition-all flex items-center gap-1.5 cursor-pointer"
              >
                <FileSpreadsheet className="w-4 h-4" />
                <span>Export Ledger (.xlsx)</span>
              </button>
            </div>
          </div>

          <div className="bg-white border border-border rounded-2xl p-4 shadow-sm space-y-3">
            <div className="flex flex-col md:flex-row md:items-center justify-between gap-3">
              <div className="relative flex-1">
                <Search className="w-4 h-4 text-text-muted absolute left-3.5 top-1/2 -translate-y-1/2" />
                <input
                  type="text"
                  value={searchQuery}
                  onChange={e => setSearchQuery(e.target.value)}
                  placeholder="Search by receipt no, student name, payment mode, or month..."
                  className="w-full pl-10 pr-4 py-2 rounded-xl bg-surface2 border border-border text-xs text-text focus:outline-none focus:border-primary"
                />
              </div>

              <div className="flex items-center gap-2 flex-wrap">
                <button
                  type="button"
                  onClick={() => setFilterMode('all')}
                  className={`px-3 py-1.5 rounded-xl text-xs font-bold transition-all cursor-pointer ${
                    filterMode === 'all'
                      ? 'bg-primary text-white shadow-xs'
                      : 'bg-surface2 hover:bg-border text-text border border-border'
                  }`}
                >
                  All
                </button>

                <button
                  type="button"
                  onClick={() => {
                    setSelectedDate(todayStr);
                    setFilterMode('date');
                  }}
                  className={`px-3 py-1.5 rounded-xl text-xs font-bold transition-all cursor-pointer ${
                    filterMode === 'date' && selectedDate === todayStr
                      ? 'bg-primary text-white shadow-xs'
                      : 'bg-surface2 hover:bg-border text-text border border-border'
                  }`}
                >
                  Today
                </button>

                <button
                  type="button"
                  onClick={() => {
                    setSelectedMonth(todayStr.slice(0, 7));
                    setFilterMode('month');
                  }}
                  className={`px-3 py-1.5 rounded-xl text-xs font-bold transition-all cursor-pointer ${
                    filterMode === 'month' && selectedMonth === todayStr.slice(0, 7)
                      ? 'bg-primary text-white shadow-xs'
                      : 'bg-surface2 hover:bg-border text-text border border-border'
                  }`}
                >
                  This Month
                </button>

                <div className={`flex items-center gap-1.5 px-2.5 py-1 rounded-xl border transition-all ${
                  filterMode === 'date' ? 'border-primary bg-primary/5 text-primary' : 'border-border bg-surface2 text-text'
                }`}>
                  <span className="text-[10px] font-bold uppercase text-text-secondary">Date:</span>
                  <input
                    type="date"
                    value={selectedDate}
                    onChange={(e) => {
                      if (e.target.value) {
                        setSelectedDate(e.target.value);
                        setFilterMode('date');
                      }
                    }}
                    className="bg-transparent text-xs font-bold text-text focus:outline-none cursor-pointer"
                    title="Filter transactions by date"
                  />
                </div>

                <div className={`flex items-center gap-1.5 px-2.5 py-1 rounded-xl border transition-all ${
                  filterMode === 'month' ? 'border-primary bg-primary/5 text-primary' : 'border-border bg-surface2 text-text'
                }`}>
                  <span className="text-[10px] font-bold uppercase text-text-secondary">Month:</span>
                  <input
                    type="month"
                    value={selectedMonth}
                    onChange={(e) => {
                      if (e.target.value) {
                        setSelectedMonth(e.target.value);
                        setFilterMode('month');
                      }
                    }}
                    className="bg-transparent text-xs font-bold text-text focus:outline-none cursor-pointer"
                    title="Filter transactions by month"
                  />
                </div>
              </div>
            </div>

            {/* Class Filter Bar */}
            <div className="pt-2 border-t border-border/60">
              {renderClassFilterBar(collectedClass, setCollectedClass, 'Filter Ledger by Class:')}
            </div>
          </div>

          {/* Register Content: Either Student-Grouped Accordion or Flat Spreadsheet Table */}
          {ledgerViewMode === 'grouped' ? (
            <div className="space-y-3.5">
              {studentPaymentGroups.length === 0 ? (
                <div className="bg-white border border-border rounded-2xl p-12 text-center text-text-muted text-xs shadow-sm">
                  <Receipt className="w-10 h-10 text-text-muted/40 mx-auto mb-2" />
                  <p className="font-bold text-text">No student payment records found</p>
                  <p className="text-[11px] text-text-secondary mt-1">Try changing your search query, date filter, or class filter.</p>
                </div>
              ) : (
                studentPaymentGroups.map((group) => {
                  const s = group.student;
                  const isExpanded = !!expandedStudents[group.key];
                  const studentClass = s.studentType === 'school' ? `Class ${s.className || '-'}` : (s.course || '-');

                  return (
                    <div
                      key={group.key}
                      className="bg-white border border-border rounded-2xl shadow-xs overflow-hidden transition-all duration-200 hover:border-primary/40"
                    >
                      {/* Student Card Accordion Header */}
                      <div
                        onClick={() => toggleStudentExpand(group.key)}
                        className="p-4 sm:p-5 flex items-center justify-between gap-4 cursor-pointer hover:bg-surface2/30 transition-colors select-none"
                      >
                        <div className="flex items-center gap-3.5 min-w-0">
                          <div className="w-10 h-10 rounded-xl bg-emerald-50 text-emerald-600 flex items-center justify-center font-bold text-sm shrink-0 border border-emerald-100">
                            {s.name ? s.name.charAt(0).toUpperCase() : 'S'}
                          </div>
                          <div className="min-w-0">
                            <div className="flex items-center gap-2 flex-wrap">
                              <span className="font-bold text-sm text-text hover:text-primary transition-colors">
                                {s.name || 'Student'}
                              </span>
                              <span className="text-[10px] font-bold px-2 py-0.5 rounded-full bg-surface2 text-text-secondary border border-border">
                                {studentClass}
                              </span>
                              {s.admissionNumber && (
                                <span className="text-[10px] font-mono text-text-muted">
                                  Adm: {s.admissionNumber}
                                </span>
                              )}
                            </div>
                            <div className="text-[11px] text-text-muted mt-0.5 flex items-center gap-2 sm:gap-3 flex-wrap">
                              <span className="font-medium text-emerald-700 bg-emerald-50 px-2 py-0.5 rounded-md border border-emerald-100">
                                {group.payments.length} {group.payments.length === 1 ? 'Receipt' : 'Receipts'}
                              </span>
                              <span>•</span>
                              <span>Latest: {group.payments[0]?.paymentDate ? new Date(group.payments[0].paymentDate).toLocaleDateString('en-IN') : '-'}</span>
                              {s.mobile && (
                                <>
                                  <span>•</span>
                                  <span>Mob: {s.mobile}</span>
                                </>
                              )}
                            </div>
                          </div>
                        </div>

                        <div className="flex items-center gap-3 shrink-0">
                          <div className="text-right">
                            <div className="text-[10px] uppercase font-bold text-text-secondary">Total Collected</div>
                            <div className="text-base sm:text-lg font-black text-emerald-600 font-mono">
                              ₹{group.totalPaid.toLocaleString('en-IN')}
                            </div>
                          </div>
                          <div className={`w-8 h-8 rounded-xl flex items-center justify-center transition-all duration-200 border ${
                            isExpanded ? 'bg-primary text-white border-primary shadow-xs' : 'bg-surface2 text-text-secondary border-border hover:bg-border'
                          }`}>
                            {isExpanded ? <ChevronUp className="w-4 h-4" /> : <ChevronDown className="w-4 h-4" />}
                          </div>
                        </div>
                      </div>

                      {/* Dropdown / Accordion Body (Revealed on click) */}
                      {isExpanded && (
                        <div className="border-t border-border bg-surface2/25 p-4 sm:p-5 space-y-4 animate-in slide-in-from-top-2 duration-150">
                          {/* Inner Bar: Summary & WhatsApp / Structure Buttons */}
                          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 bg-white p-3.5 rounded-xl border border-border shadow-2xs">
                            <div className="text-xs text-text-secondary">
                              Showing all <strong className="text-text">{group.payments.length} receipts</strong> recorded for <strong className="text-primary">{s.name}</strong>.
                            </div>
                            <div className="flex items-center gap-2 flex-wrap">
                              <button
                                type="button"
                                onClick={(e) => {
                                  e.stopPropagation();
                                  openWhatsAppFeeStatement(s, group.payments, settings);
                                }}
                                className="px-3 py-1.5 rounded-lg bg-emerald-50 hover:bg-emerald-100 text-emerald-700 text-xs font-bold border border-emerald-200 flex items-center gap-1.5 cursor-pointer transition-colors shadow-2xs"
                                title="Send complete fee statement on WhatsApp"
                              >
                                <MessageSquare className="w-3.5 h-3.5" />
                                <span>WhatsApp All Receipts</span>
                              </button>
                              <button
                                type="button"
                                onClick={(e) => {
                                  e.stopPropagation();
                                  setIsFeeDetailSelectorOpen(false);
                                  setFeeDetailStudent(s);
                                }}
                                className="px-3 py-1.5 rounded-lg bg-primary hover:bg-primary-dark text-white text-xs font-bold flex items-center gap-1.5 cursor-pointer transition-colors shadow-2xs"
                                title="Manage fee structure and collect new payment"
                              >
                                <CreditCard className="w-3.5 h-3.5" />
                                <span>Fee Profile / Pay</span>
                              </button>
                            </div>
                          </div>

                          {/* Receipts Table for this Student */}
                          <div className="bg-white rounded-xl border border-border overflow-hidden shadow-2xs">
                            <div className="overflow-x-auto">
                              <table className="w-full text-left text-xs border-collapse">
                                <thead>
                                  <tr className="bg-surface2/60 border-b border-border text-text-secondary font-bold text-[10px] uppercase">
                                    <th className="py-2.5 px-3.5">Receipt #</th>
                                    <th className="py-2.5 px-3.5">Payment Date</th>
                                    <th className="py-2.5 px-3.5">Fee Month</th>
                                    <th className="py-2.5 px-3.5 text-right">Amount Paid</th>
                                    <th className="py-2.5 px-3.5 text-center">Payment Mode</th>
                                    <th className="py-2.5 px-3.5 text-right">Remaining Due</th>
                                    <th className="py-2.5 px-3.5 text-right">Receipt Actions</th>
                                  </tr>
                                </thead>
                                <tbody className="divide-y divide-border text-text font-medium">
                                  {group.payments.map((p, pIdx) => (
                                    <tr key={p.id ? `${p.id}_${pIdx}` : `subpay_${pIdx}`} className="hover:bg-surface2/40 transition-colors">
                                      <td className="py-3 px-3.5 font-mono font-bold text-primary">{p.receiptNumber || 'REC'}</td>
                                      <td className="py-3 px-3.5 font-mono text-text-secondary">
                                        {p.paymentDate ? new Date(p.paymentDate).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' }) : '-'}
                                      </td>
                                      <td className="py-3 px-3.5 text-text-secondary">{p.feeMonth || 'Monthly Fee'}</td>
                                      <td className="py-3 px-3.5 text-right font-black text-emerald-600 font-mono text-sm">
                                        ₹{(Number(p.amount) || 0).toLocaleString('en-IN')}
                                      </td>
                                      <td className="py-3 px-3.5 text-center">
                                        <span className="px-2 py-0.5 rounded bg-surface2 border border-border text-[9px] font-bold font-mono uppercase">
                                          {p.paymentMode || 'Cash'}
                                        </span>
                                      </td>
                                      <td className="py-3 px-3.5 text-right font-mono">
                                        {(() => {
                                          let rem = 0;
                                          if (p.balanceDue !== undefined && p.balanceDue !== null && !isNaN(Number(p.balanceDue))) {
                                            rem = Number(p.balanceDue);
                                          } else if (p.remainingFees !== undefined && p.remainingFees !== null && !isNaN(Number(p.remainingFees))) {
                                            rem = Number(p.remainingFees);
                                          } else {
                                            const st = students.find(stud => stud.id === p.studentId || (stud.studentId && stud.studentId === p.studentId));
                                            if (st) {
                                              const m = calculateStudentFeeMetrics(st, payments);
                                              rem = m.currentDue;
                                            }
                                          }
                                          return (
                                            <span className={`font-bold text-xs ${rem > 0 ? 'text-rose-600' : 'text-emerald-600'}`}>
                                              ₹{rem.toLocaleString('en-IN')}
                                            </span>
                                          );
                                        })()}
                                      </td>
                                      <td className="py-3 px-3.5 text-right">
                                        <div className="flex items-center justify-end gap-1.5">
                                          <button
                                            type="button"
                                            onClick={() => openWhatsAppReceiptShare(p, s, settings, payments)}
                                            className="p-1.5 rounded-lg bg-emerald-50 hover:bg-emerald-100 text-emerald-700 border border-emerald-200 cursor-pointer transition-colors"
                                            title="Share this receipt on WhatsApp"
                                          >
                                            <MessageSquare className="w-3.5 h-3.5" />
                                          </button>
                                          <button
                                            type="button"
                                            onClick={() => setPrintReceiptData({
                                              payment: p,
                                              student: s || { name: p.studentName, studentId: p.studentId, session: settings.currentSession },
                                              settings
                                            })}
                                            className="p-1.5 rounded-lg bg-surface2 hover:bg-primary/10 text-primary border border-border cursor-pointer transition-colors"
                                            title="Print Receipt Slip"
                                          >
                                            <Printer className="w-3.5 h-3.5" />
                                          </button>
                                          <button
                                            type="button"
                                            onClick={() => deletePayment(p.id)}
                                            className="p-1.5 rounded-lg bg-surface2 hover:bg-rose-100 text-rose-600 border border-border cursor-pointer transition-colors"
                                            title="Delete Transaction"
                                          >
                                            <Trash2 className="w-3.5 h-3.5" />
                                          </button>
                                        </div>
                                      </td>
                                    </tr>
                                  ))}
                                </tbody>
                              </table>
                            </div>
                          </div>
                        </div>
                      )}
                    </div>
                  );
                })
              )}
            </div>
          ) : (
            <div className="bg-white border border-border rounded-2xl shadow-sm overflow-hidden flex flex-col">
              <div className="overflow-x-auto">
                <table className="w-full text-left text-xs border-collapse">
                  <thead>
                    <tr className="bg-surface2/60 border-b border-border text-text-secondary font-bold text-[10px] uppercase">
                      <th className="py-3 px-4">Receipt</th>
                      <th className="py-3 px-4">Date</th>
                      <th className="py-3 px-4">Student</th>
                      <th className="py-3 px-4">Class</th>
                      <th className="py-3 px-4">Fee Month</th>
                      <th className="py-3 px-4 text-right">Paid</th>
                      <th className="py-3 px-4 text-right text-rose-600">Remaining Due</th>
                      <th className="py-3 px-4 text-center">Mode</th>
                      <th className="py-3 px-4 text-right">Actions</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-border text-text font-medium">
                    {filteredPayments.length === 0 ? (
                      <tr>
                        <td colSpan="8" className="py-12 text-center text-text-muted text-xs">
                          No transactions found.
                        </td>
                      </tr>
                    ) : (
                      filteredPayments.map((p, idx) => {
                        const student = students.find(s => s.id === p.studentId);
                        return (
                          <tr key={p.id ? `${p.id}_${idx}` : `ledger_${idx}`} className="hover:bg-surface2/30 transition-colors">
                            <td className="py-3.5 px-4 font-mono font-bold text-primary">{p.receiptNumber}</td>
                            <td className="py-3.5 px-4 font-mono text-text-secondary">{p.paymentDate ? new Date(p.paymentDate).toLocaleDateString() : '-'}</td>
                            <td className="py-3.5 px-4 font-bold text-text">{p.studentName || student?.name}</td>
                            <td className="py-3.5 px-4 text-text-secondary">{student ? (student.studentType === 'school' ? `Class ${student.className}` : student.course) : '-'}</td>
                            <td className="py-3.5 px-4">{p.feeMonth}</td>
                            <td className="py-3.5 px-4 text-right font-black text-emerald-600">₹{(Number(p.amount) || 0).toLocaleString('en-IN')}</td>
                            <td className="py-3.5 px-4 text-right">
                              {(() => {
                                let rem = 0;
                                if (p.balanceDue !== undefined && p.balanceDue !== null && !isNaN(Number(p.balanceDue))) {
                                  rem = Number(p.balanceDue);
                                } else if (p.remainingFees !== undefined && p.remainingFees !== null && !isNaN(Number(p.remainingFees))) {
                                  rem = Number(p.remainingFees);
                                } else if (p.totalPending !== undefined && p.totalPending !== null && !isNaN(Number(p.totalPending))) {
                                  rem = Number(p.totalPending);
                                } else {
                                  const st = students.find(s => s.id === p.studentId || (s.studentId && s.studentId === p.studentId));
                                  if (st) {
                                    const m = calculateStudentFeeMetrics(st, payments);
                                    rem = m.currentDue;
                                  }
                                }
                                return (
                                  <span className={`font-black font-mono text-xs ${rem > 0 ? 'text-rose-600' : 'text-emerald-600'}`}>
                                    ₹{rem.toLocaleString('en-IN')}
                                  </span>
                                );
                              })()}
                            </td>
                            <td className="py-3.5 px-4 text-center"><span className="px-2 py-0.5 rounded bg-surface2 border border-border text-[9px] font-bold font-mono">{p.paymentMode}</span></td>
                            <td className="py-3.5 px-4 text-right">
                              <div className="flex items-center justify-end gap-1.5">
                                <button
                                  onClick={() => openWhatsAppReceiptShare(p, student, settings, payments)}
                                  className="p-1.5 rounded-lg bg-emerald-50 hover:bg-emerald-100 text-emerald-700 border border-emerald-200 cursor-pointer transition-colors"
                                  title="Share Receipt Voucher on WhatsApp"
                                >
                                  <MessageSquare className="w-3.5 h-3.5" />
                                </button>
                                <button
                                  onClick={() => setPrintReceiptData({
                                    payment: p,
                                    student: student || { name: p.studentName, studentId: p.studentId, session: settings.currentSession },
                                    settings
                                  })}
                                  className="p-1.5 rounded-lg bg-surface2 hover:bg-primary/10 text-primary border border-border cursor-pointer transition-colors"
                                  title="Print Receipt Slip"
                                >
                                  <Printer className="w-3.5 h-3.5" />
                                </button>
                                <button
                                  onClick={() => deletePayment(p.id)}
                                  className="p-1.5 rounded-lg bg-surface2 hover:bg-rose-100 text-rose-600 border border-border cursor-pointer transition-colors"
                                  title="Delete Transaction"
                                >
                                  <Trash2 className="w-3.5 h-3.5" />
                                </button>
                              </div>
                            </td>
                          </tr>
                        );
                      })
                    )}
                  </tbody>
                </table>
              </div>
            </div>
          )}
        </div>
      ) : (
        /* ─── OUTSTANDING DEFAULTERS ─── */
        <div className="space-y-6">
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
            <div>
              <h2 className="text-xl lg:text-2xl font-bold text-rose-600 tracking-tight">Outstanding Defaulters</h2>
              <p className="text-xs text-text-secondary mt-0.5">List of students with auto-accrued monthly dues and quick reminders.</p>
            </div>
            <div className="flex items-center gap-2">
              {defaultersList.length > 0 && (
                <button
                  onClick={() => setWhatsAppReminderData({ students: defaultersList })}
                  className="px-4 py-2 rounded-xl bg-emerald-600 hover:bg-emerald-700 text-white font-bold text-xs shadow-xs transition-all flex items-center gap-1.5 cursor-pointer"
                >
                  <MessageSquare className="w-4 h-4" />
                  <span>Bulk WhatsApp ({defaultersList.length})</span>
                </button>
              )}
              <button
                onClick={() => exportDefaultersToExcel(defaultersList, settings.instituteName)}
                className="px-4 py-2 rounded-xl bg-white border border-border hover:bg-surface2 text-text font-bold text-xs shadow-xs transition-all flex items-center gap-1.5 cursor-pointer"
              >
                <FileSpreadsheet className="w-4 h-4 text-rose-600" />
                <span>Export Defaulters</span>
              </button>
            </div>
          </div>

          <div className="bg-white border border-border rounded-2xl p-4 shadow-sm space-y-3.5">
            <div className="flex flex-col md:flex-row md:items-center justify-between gap-3">
              <div className="relative flex-1">
                <Search className="w-4 h-4 text-text-muted absolute left-3.5 top-1/2 -translate-y-1/2" />
                <input
                  type="text"
                  value={searchQuery}
                  onChange={e => setSearchQuery(e.target.value)}
                  placeholder="Search defaulters by student name, roll number, or phone..."
                  className="w-full pl-10 pr-4 py-2 rounded-xl bg-surface2 border border-border text-xs text-text focus:outline-none focus:border-primary"
                />
              </div>

              {/* Date/Month Filter Buttons */}
              <div className="flex items-center gap-2 flex-wrap">
                <button
                  type="button"
                  onClick={() => setPendingFilterMode('all')}
                  className={`px-3 py-1.5 rounded-xl text-xs font-bold transition-all cursor-pointer ${
                    pendingFilterMode === 'all'
                      ? 'bg-rose-600 text-white shadow-xs'
                      : 'bg-surface2 hover:bg-border text-text border border-border'
                  }`}
                >
                  All
                </button>

                <button
                  type="button"
                  onClick={() => {
                    setPendingSelectedDate(todayStr);
                    setPendingFilterMode('date');
                  }}
                  className={`px-3 py-1.5 rounded-xl text-xs font-bold transition-all cursor-pointer ${
                    pendingFilterMode === 'date' && pendingSelectedDate === todayStr
                      ? 'bg-rose-600 text-white shadow-xs'
                      : 'bg-surface2 hover:bg-border text-text border border-border'
                  }`}
                >
                  Today
                </button>

                <button
                  type="button"
                  onClick={() => {
                    setPendingSelectedMonth(todayStr.slice(0, 7));
                    setPendingFilterMode('month');
                  }}
                  className={`px-3 py-1.5 rounded-xl text-xs font-bold transition-all cursor-pointer ${
                    pendingFilterMode === 'month' && pendingSelectedMonth === todayStr.slice(0, 7)
                      ? 'bg-rose-600 text-white shadow-xs'
                      : 'bg-surface2 hover:bg-border text-text border border-border'
                  }`}
                >
                  This Month
                </button>

                <div className={`flex items-center gap-1.5 px-2.5 py-1 rounded-xl border transition-all ${
                  pendingFilterMode === 'date' ? 'border-rose-500 bg-rose-50 text-rose-700' : 'border-border bg-surface2 text-text'
                }`}>
                  <span className="text-[10px] font-bold uppercase text-text-secondary">Date:</span>
                  <input
                    type="date"
                    value={pendingSelectedDate}
                    onChange={(e) => {
                      if (e.target.value) {
                        setPendingSelectedDate(e.target.value);
                        setPendingFilterMode('date');
                      }
                    }}
                    className="bg-transparent text-xs font-bold text-text focus:outline-none cursor-pointer"
                    title="Filter pending dues by date"
                  />
                </div>

                <div className={`flex items-center gap-1.5 px-2.5 py-1 rounded-xl border transition-all ${
                  pendingFilterMode === 'month' ? 'border-rose-500 bg-rose-50 text-rose-700' : 'border-border bg-surface2 text-text'
                }`}>
                  <span className="text-[10px] font-bold uppercase text-text-secondary">Month:</span>
                  <input
                    type="month"
                    value={pendingSelectedMonth}
                    onChange={(e) => {
                      if (e.target.value) {
                        setPendingSelectedMonth(e.target.value);
                        setPendingFilterMode('month');
                      }
                    }}
                    className="bg-transparent text-xs font-bold text-text focus:outline-none cursor-pointer"
                    title="Filter pending dues by month"
                  />
                </div>
              </div>
            </div>

            <div className="pt-2 border-t border-border/60 flex flex-col sm:flex-row sm:items-center justify-between gap-2">
              {renderClassFilterBar(pendingClass, setPendingClass, 'Filter Pending by Class:')}
              <div className="text-[11px] font-bold text-rose-600 whitespace-nowrap bg-rose-50 px-3 py-1 rounded-lg border border-rose-100 self-start sm:self-auto">
                Filtered Pending: ₹{totalDefaultersDue.toLocaleString('en-IN')} ({defaultersList.length} students)
              </div>
            </div>
          </div>

          <div className="bg-white border border-border rounded-2xl shadow-sm overflow-hidden flex flex-col">
            <div className="overflow-x-auto">
              <table className="w-full text-left text-xs border-collapse">
                <thead>
                  <tr className="bg-surface2/60 border-b border-border text-text-secondary font-bold text-[10px] uppercase">
                    <th className="py-3 px-4">Student Name</th>
                    <th className="py-3 px-4">Class</th>
                    <th className="py-3 px-4 text-center">Set Monthly Fee</th>
                    <th className="py-3 px-4 text-right">Accrued Expected</th>
                    <th className="py-3 px-4 text-right">Paid Fees</th>
                    <th className="py-3 px-4 text-right">Outstanding Dues</th>
                    <th className="py-3 px-4">Mobile</th>
                    <th className="py-3 px-4 text-right">Actions</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-border text-text font-medium">
                  {defaultersList.length === 0 ? (
                    <tr>
                      <td colSpan="8" className="py-12 text-center text-text-muted text-xs">
                        🎉 No pending fee defaulters. All active student accounts are cleared.
                      </td>
                    </tr>
                  ) : (
                    defaultersList.map(s => {
                      const m = s.feeMetrics;
                      return (
                        <tr key={s.id} className="hover:bg-surface2/30 transition-colors">
                          <td className="py-3.5 px-4 font-bold text-text">
                            <div>{s.name}</div>
                            <div className="text-[9px] text-text-muted font-normal">ID: {s.studentId} · Adm: {s.admissionNumber || '-'}</div>
                          </td>
                          <td className="py-3.5 px-4 text-text-secondary">{s.studentType === 'school' ? `Class ${s.className}` : s.course}</td>
                          <td className="py-3.5 px-4 text-center font-semibold">₹{m.monthlyFee.toLocaleString('en-IN')}/mo</td>
                          <td className="py-3.5 px-4 text-right text-text-secondary font-mono">₹{m.accruedExpected.toLocaleString('en-IN')} ({m.elapsedMonths} mos)</td>
                          <td className="py-3.5 px-4 text-right text-emerald-600 font-bold font-mono">₹{m.totalPaid.toLocaleString('en-IN')}</td>
                          <td className="py-3.5 px-4 text-right font-black text-rose-600 font-mono text-sm">₹{m.currentDue.toLocaleString('en-IN')}</td>
                          <td className="py-3.5 px-4 font-mono text-text-secondary">{s.mobile || '-'}</td>
                          <td className="py-3.5 px-4 text-right">
                            <div className="flex items-center justify-end gap-2">
                              {s.mobile && (
                                <button
                                  onClick={() => setWhatsAppReminderData({ student: s, dueAmount: m.currentDue })}
                                  className="px-2.5 py-1 rounded-lg bg-emerald-50 text-emerald-700 hover:bg-emerald-100 font-bold text-[11px] flex items-center gap-1 border border-emerald-200 cursor-pointer"
                                  title="Send WhatsApp Fee Due Reminder (Hindi / English)"
                                >
                                  <MessageSquare className="w-3 h-3" />
                                  <span>WhatsApp</span>
                                </button>
                              )}
                              <button
                                onClick={() => {
                                  setIsFeeDetailSelectorOpen(false);
                                  setFeeDetailStudent(s);
                                }}
                                className="px-2.5 py-1 rounded-lg bg-primary text-white hover:bg-primary-dark font-bold text-[11px] flex items-center gap-1 cursor-pointer shadow-2xs"
                              >
                                <CreditCard className="w-3 h-3" />
                                <span>Fee Structure</span>
                              </button>
                            </div>
                          </td>
                        </tr>
                      );
                    })
                  )}
                </tbody>
              </table>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
