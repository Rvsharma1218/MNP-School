'use client';

import React, { useState, useEffect } from 'react';
import { useSchoolStore, getStudentMonthLedger } from '../lib/store';
import {
  X, ChevronLeft, ChevronRight, Save, Calendar, CreditCard,
  Receipt, Printer, MessageSquare, CheckCircle, Clock, AlertCircle,
  IndianRupee, Sparkles, SlidersHorizontal, Trash2, ArrowRight, RotateCcw
} from 'lucide-react';
import { openWhatsAppFeeReminder, exportReceiptPDF } from '../lib/exportUtils';

export default function StudentFeeDetailModal({ student, isOpen, onClose }) {
  const { students, settings, payments, addPayment, updateStudent, setPrintReceiptData, getNextReceiptNumber, setWhatsAppReminderData, showToast, isFeeDetailSelectorOpen } = useSchoolStore();

  const [currentDate, setCurrentDate] = useState(new Date());

  // Recurring Fee Structure State
  const [feeStructure, setFeeStructure] = useState({
    tuitionFee: '',
    transportFee: '',
    gameFee: '',
    lateFinePerDay: '',
    dueDay: 10
  });

  // Monthly Fee Particulars (13 Heads)
  const [particulars, setParticulars] = useState({
    admissionFee: '',
    tuitionFee: '',
    examinationFee: '',
    previousDues: '',
    gameFee: '',
    reAdmissionFee: '',
    developmentFee: '',
    schoolId: '',
    tieBagBelt: '',
    backDues: '',
    transportFee: '',
    otherFee: '',
    lateFine: ''
  });

  const [dueDate, setDueDate] = useState('');

  // Payment Form State
  const [paymentAmount, setPaymentAmount] = useState('');
  const [paymentMode, setPaymentMode] = useState('Cash');
  const [remarks, setRemarks] = useState('');

  const monthNames = [
    "January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December"
  ];

  const monthYearLabel = `${monthNames[currentDate.getMonth()]} ${currentDate.getFullYear()}`;
  const monthKey = `${currentDate.getFullYear()}-${String(currentDate.getMonth() + 1).padStart(2, '0')}`;

  const [selectedStudentId, setSelectedStudentId] = useState(student?.id || (students[0]?.id || ''));
  const [classFilter, setClassFilter] = useState('all');
  const [sectionFilter, setSectionFilter] = useState('all');
  const [studentSearch, setStudentSearch] = useState('');

  useEffect(() => {
    if (isOpen) {
      setCurrentDate(new Date());
    }
    if (student?.id) {
      setSelectedStudentId(student.id);
      if (!isFeeDetailSelectorOpen) {
        if (student.className) setClassFilter(student.className);
        if (student.section) setSectionFilter(student.section);
      } else {
        // When opening global Fee Collection, show All Classes by default so ALL students are accessible!
        setClassFilter('all');
        setSectionFilter('all');
      }
    } else if (students.length > 0 && !selectedStudentId) {
      setSelectedStudentId(students[0].id);
      setClassFilter('all');
      setSectionFilter('all');
    }
  }, [student, isOpen, isFeeDetailSelectorOpen]);

  // Always use the latest selected student record from store
  const currentStudent = (!isFeeDetailSelectorOpen && student)
    ? (students.find(s => s.id === student.id) || student)
    : (students.find(s => s.id === selectedStudentId) || (student ? (students.find(s => s.id === student.id) || student) : students[0]));

  // Extract unique classes and courses
  const uniqueClasses = Array.from(new Set(students.map(s => s.studentType === 'school' ? s.className : s.course).filter(Boolean))).sort();
  const uniqueSections = Array.from(new Set(students.map(s => s.section).filter(Boolean))).sort();

  const filteredStudents = students.filter(s => {
    const sClass = s.studentType === 'school' ? s.className : s.course;
    if (classFilter !== 'all' && sClass !== classFilter && s.className !== classFilter && s.course !== classFilter) return false;
    if (sectionFilter !== 'all' && s.section !== sectionFilter) return false;
    if (studentSearch.trim()) {
      const q = studentSearch.trim().toLowerCase();
      const matchName = s.name?.toLowerCase().includes(q);
      const matchAdm = s.admissionNumber?.toLowerCase().includes(q) || s.studentId?.toLowerCase().includes(q);
      const matchPhone = s.mobile?.includes(q);
      if (!matchName && !matchAdm && !matchPhone) return false;
    }
    return true;
  });

  // Get dynamic chronological month-by-month auto-rollover ledger
  const monthLedger = currentStudent ? getStudentMonthLedger(currentStudent, payments) : {};
  const currentMonthData = monthLedger[monthKey] || {
    previousDue: 0,
    tuitionFee: 0,
    transportFee: 0,
    gameFee: 0,
    admissionFee: 0,
    developmentFee: 0,
    schoolId: 0,
    tieBagBelt: 0,
    totalMonthCharge: 0,
    totalDueThisMonth: 0,
    paidInMonth: 0,
    closingDue: 0
  };

  useEffect(() => {
    if (currentStudent) {
      const fs = currentStudent.feeStructure || {};
      const mp = currentStudent.monthlyParticulars?.[monthKey] || {};

      const startMonthKey = fs.startMonth || (currentStudent.admissionDate ? String(currentStudent.admissionDate).substring(0, 7) : '');
      const isPreStart = Boolean(startMonthKey && monthKey < startMonthKey);

      const tuitionDefault = isPreStart
        ? ''
        : ((fs.tuitionFee !== undefined && fs.tuitionFee !== '' && fs.tuitionFee !== null && Number(fs.tuitionFee) > 0)
          ? String(fs.tuitionFee)
          : (currentStudent.monthlyFee && Number(currentStudent.monthlyFee) > 0 ? String(currentStudent.monthlyFee) : (currentMonthData.tuitionFee ? String(currentMonthData.tuitionFee) : '')));
      const transportDefault = isPreStart
        ? ''
        : ((fs.transportFee !== undefined && fs.transportFee !== '' && fs.transportFee !== null)
          ? String(fs.transportFee)
          : (currentMonthData.transportFee ? String(currentMonthData.transportFee) : ''));
      const gameDefault = isPreStart
        ? ''
        : ((fs.gameFee !== undefined && fs.gameFee !== '' && fs.gameFee !== null)
          ? String(fs.gameFee)
          : (currentMonthData.gameFee ? String(currentMonthData.gameFee) : ''));

      setFeeStructure({
        tuitionFee: tuitionDefault,
        transportFee: transportDefault,
        gameFee: gameDefault,
        lateFinePerDay: fs.lateFinePerDay ? String(fs.lateFinePerDay) : '',
        dueDay: fs.dueDay || 10
      });

      // Automatically pull rolling previousDue from continuous ledger
      const autoPrevDue = currentMonthData.previousDue;

      setParticulars({
        admissionFee: (mp.admissionFee !== undefined && mp.admissionFee !== '' && mp.admissionFee !== null)
          ? String(mp.admissionFee)
          : '',
        tuitionFee: (mp.tuitionFee !== undefined && mp.tuitionFee !== '' && mp.tuitionFee !== null)
          ? String(mp.tuitionFee)
          : (tuitionDefault || ''),
        examinationFee: mp.examinationFee !== undefined && mp.examinationFee !== '' ? String(mp.examinationFee) : '',
        previousDues: String(autoPrevDue || 0),
        gameFee: (mp.gameFee !== undefined && mp.gameFee !== '' && mp.gameFee !== null)
          ? String(mp.gameFee)
          : (gameDefault || ''),
        reAdmissionFee: mp.reAdmissionFee !== undefined && mp.reAdmissionFee !== '' ? String(mp.reAdmissionFee) : '',
        developmentFee: (mp.developmentFee !== undefined && mp.developmentFee !== '' && mp.developmentFee !== null)
          ? String(mp.developmentFee)
          : '',
        schoolId: (mp.schoolId !== undefined && mp.schoolId !== '' && mp.schoolId !== null)
          ? String(mp.schoolId)
          : '',
        tieBagBelt: (mp.tieBagBelt !== undefined && mp.tieBagBelt !== '' && mp.tieBagBelt !== null)
          ? String(mp.tieBagBelt)
          : '',
        backDues: mp.backDues !== undefined && mp.backDues !== '' ? String(mp.backDues) : '',
        transportFee: (mp.transportFee !== undefined && mp.transportFee !== '' && mp.transportFee !== null)
          ? String(mp.transportFee)
          : (transportDefault || ''),
        otherFee: mp.otherFee !== undefined && mp.otherFee !== '' ? String(mp.otherFee) : '',
        lateFine: (mp.lateFine !== undefined && mp.lateFine !== '' && mp.lateFine !== null)
          ? String(mp.lateFine)
          : (currentMonthData.lateFine ? String(currentMonthData.lateFine) : '')
      });

      const dDate = mp.dueDate || `${currentDate.getFullYear()}-${String(currentDate.getMonth() + 1).padStart(2, '0')}-${String(fs.dueDay || 10).padStart(2, '0')}`;
      setDueDate(dDate);

      // Pre-fill payment amount with closing due for this month
      if (currentMonthData.closingDue > 0) {
        setPaymentAmount(String(currentMonthData.closingDue));
      } else {
        setPaymentAmount('');
      }
    }
  }, [currentStudent, monthKey]);

  if (!isOpen || !currentStudent) return null;

  const particularValues = Object.values(particulars).map(v => Number(v) || 0);
  const totalDueForMonth = particularValues.reduce((acc, v) => acc + v, 0);

  const studentMonthPayments = (payments || []).filter(p => {
    let isStudent = false;
    if (p.studentId) {
      isStudent = p.studentId === currentStudent.id || (currentStudent.studentId && p.studentId === currentStudent.studentId);
    } else if (currentStudent.admissionNumber && (p.admissionNumber || p.admissionNo)) {
      isStudent = p.admissionNumber === currentStudent.admissionNumber || p.admissionNo === currentStudent.admissionNumber;
    } else if (p.studentName && currentStudent.name) {
      isStudent = p.studentName.trim().toLowerCase() === currentStudent.name.trim().toLowerCase();
    }
    if (!isStudent) return false;

    // 1. Exact monthKey match ('2026-08')
    if (p.monthKey && p.monthKey === monthKey) return true;

    // 2. Exact or formatted feeMonth match ('August 2026')
    if (p.feeMonth && p.feeMonth.trim().toLowerCase() === monthYearLabel.toLowerCase()) return true;
    if (p.feeMonth && p.feeMonth.trim() === monthKey) return true;
    if (p.feeMonth && p.feeMonth.toLowerCase().includes(monthNames[currentDate.getMonth()].toLowerCase()) && p.feeMonth.includes(String(currentDate.getFullYear()))) return true;

    // 3. Numeric feeYear + feeMonthNum / feeMonth
    if (p.feeYear && (p.feeMonthNum || p.feeMonth || p.month)) {
      const pYear = Number(p.feeYear) || Number(p.year);
      const pMonth = Number(p.feeMonthNum) || Number(p.month) || (typeof p.feeMonth === 'number' ? p.feeMonth : 0);
      if (pYear === currentDate.getFullYear() && pMonth === (currentDate.getMonth() + 1)) return true;
    }

    // 4. Fallback to paymentDate only if feeMonth is not explicitly pointing to another month
    if (!p.feeMonth || p.feeMonth === 'Monthly Tuition Fee' || p.feeMonth === 'Fee Payment') {
      if (p.paymentDate && typeof p.paymentDate === 'string' && p.paymentDate.startsWith(monthKey)) return true;
      if (p.paymentDate) {
        const pDate = new Date(p.paymentDate);
        if (pDate.getFullYear() === currentDate.getFullYear() && pDate.getMonth() === currentDate.getMonth()) return true;
      }
    }
    return false;
  });
  const paidForMonth = studentMonthPayments.reduce((acc, p) => acc + (Number(p.amount) || 0), 0);
  const remainingForMonth = Math.max(0, totalDueForMonth - paidForMonth);

  const handlePrevMonth = () => {
    const d = new Date(currentDate);
    d.setMonth(d.getMonth() - 1);
    setCurrentDate(d);
  };

  const handleNextMonth = () => {
    const d = new Date(currentDate);
    d.setMonth(d.getMonth() + 1);
    setCurrentDate(d);
  };

  const [showResetConfirm, setShowResetConfirm] = useState(false);

  // Reset Fee Particulars for current month to defaults
  const handleResetParticulars = () => {
    const fs = currentStudent.feeStructure || {};
    const defaultTuition = (fs.tuitionFee !== undefined && fs.tuitionFee !== '' && fs.tuitionFee !== null && Number(fs.tuitionFee) > 0)
      ? String(fs.tuitionFee)
      : (currentStudent.monthlyFee && Number(currentStudent.monthlyFee) > 0 ? String(currentStudent.monthlyFee) : '');
    const defaultTransport = (fs.transportFee !== undefined && fs.transportFee !== '' && fs.transportFee !== null) ? String(fs.transportFee) : '';
    const defaultGame = (fs.gameFee !== undefined && fs.gameFee !== '' && fs.gameFee !== null) ? String(fs.gameFee) : '';

    setParticulars({
      admissionFee: '',
      tuitionFee: defaultTuition,
      examinationFee: '',
      previousDues: String(currentMonthData.previousDue || 0),
      gameFee: defaultGame,
      reAdmissionFee: '',
      developmentFee: '',
      schoolId: '',
      tieBagBelt: '',
      backDues: '',
      transportFee: defaultTransport,
      otherFee: '',
      lateFine: ''
    });

    const currentMonthly = { ...(currentStudent.monthlyParticulars || {}) };
    delete currentMonthly[monthKey];

    const updatedStudent = {
      ...currentStudent,
      monthlyParticulars: currentMonthly
    };
    updateStudent(currentStudent.id, updatedStudent);
    setShowResetConfirm(false);
    showToast(`Fee particulars for ${monthYearLabel} reset to default tuition!`, "success");
  };

  // Save Monthly Particulars
  const handleSaveParticulars = (e) => {
    e.preventDefault();
    const numericParticulars = {};
    for (const [k, v] of Object.entries(particulars)) {
      if (v !== '' && v !== null && v !== undefined) {
        numericParticulars[k] = Number(v) || 0;
      }
    }

    const tFee = Number(particulars.tuitionFee) || Number(currentStudent.monthlyFee) || 0;
    const currentMonthly = currentStudent.monthlyParticulars || {};
    const updatedStudent = {
      ...currentStudent,
      monthlyFee: tFee,
      feeStructure: {
        ...(currentStudent.feeStructure || {}),
        tuitionFee: tFee,
        transportFee: Number(particulars.transportFee) || 0,
        gameFee: Number(particulars.gameFee) || 0,
      },
      monthlyParticulars: {
        ...currentMonthly,
        [monthKey]: {
          ...numericParticulars,
          dueDate,
          totalDue: totalDueForMonth,
          monthName: monthYearLabel
        }
      }
    };
    updateStudent(currentStudent.id, updatedStudent);
    showToast(`Fee Particulars for ${monthYearLabel} saved! Total Demand: ₹${totalDueForMonth.toLocaleString('en-IN')}`, "success");
  };

  // Record Payment
  const handleRecordPayment = async (e) => {
    e.preventDefault();
    const amt = Number(paymentAmount);
    if (!amt || amt <= 0) {
      showToast("Please enter a valid payment amount.", "error");
      return;
    }

    // Collect current month's accrued data for receipt
    const finalTuition = Number(particulars.tuitionFee) || Number(feeStructure.tuitionFee) || Number(currentStudent.monthlyFee) || amt;
    const prevDue = Number(particulars.previousDues) || currentMonthData.previousDue || 0;
    const totalDemand = totalDueForMonth > 0 ? totalDueForMonth : (prevDue + finalTuition);
    const alreadyPaidThisMonth = paidForMonth || currentMonthData.paidInMonth || 0;
    const totalPaidAfterPayment = alreadyPaidThisMonth + amt;
    const remainingAfterPayment = Math.max(0, totalDemand - totalPaidAfterPayment);

    // Save current month particulars snapshot into payment so receipt & PDF render them exactly
    const particularsSnapshot = {
      admissionFee: Number(particulars.admissionFee) || 0,
      tuitionFee: finalTuition,
      examinationFee: Number(particulars.examinationFee) || 0,
      previousDues: prevDue,
      gameFee: Number(particulars.gameFee) || 0,
      reAdmissionFee: Number(particulars.reAdmissionFee) || 0,
      developmentFee: Number(particulars.developmentFee) || 0,
      schoolId: Number(particulars.schoolId) || 0,
      tieBagBelt: Number(particulars.tieBagBelt) || 0,
      backDues: Number(particulars.backDues) || 0,
      transportFee: Number(particulars.transportFee) || 0,
      otherFee: Number(particulars.otherFee) || 0,
      lateFine: Number(particulars.lateFine) || 0,
    };

    const recYear = currentDate.getFullYear();
    const receiptNo = getNextReceiptNumber ? getNextReceiptNumber(payments, recYear) : `REC-${recYear}-001`;

    const updatedMonthlyParticulars = {
      ...(currentStudent.monthlyParticulars || {}),
      [monthKey]: {
        ...particularsSnapshot,
        dueDate,
        totalDue: totalDemand,
        monthName: monthYearLabel
      }
    };
    const tFee = Number(feeStructure.tuitionFee) > 0 ? Number(feeStructure.tuitionFee) : finalTuition;
    const updatedFeeStructure = {
      ...(currentStudent.feeStructure || {}),
      tuitionFee: tFee,
      dueDay: Number(feeStructure.dueDay) || 10
    };

    const newPayment = await addPayment({
      studentId: currentStudent.id,
      studentName: currentStudent.name,
      mobile: currentStudent.mobile || '',
      alternateMobile: currentStudent.alternateMobile || '',
      admissionNumber: currentStudent.admissionNumber || '',
      amount: amt,
      paymentMode,
      feeMonth: monthYearLabel,
      monthKey,
      receiptNumber: receiptNo,
      remarks: remarks || `Fee payment for ${monthYearLabel}`,
      paymentDate: new Date().toISOString(),
      // Extra context for receipt voucher
      previousDue: prevDue,
      totalMonthDemand: totalDemand,
      alreadyPaid: alreadyPaidThisMonth,
      totalPaidAfter: totalPaidAfterPayment,
      balanceDue: remainingAfterPayment,
      particularsSnapshot,
      monthlyParticulars: updatedMonthlyParticulars,
      feeStructure: updatedFeeStructure,
      monthlyFee: tFee
    });

    await updateStudent(currentStudent.id, {
      ...currentStudent,
      monthlyFee: tFee,
      feeStructure: updatedFeeStructure,
      monthlyParticulars: updatedMonthlyParticulars
    });

    setPaymentAmount('');
    setRemarks('');
    showToast(`Payment of ₹${amt.toLocaleString('en-IN')} recorded & Receipt generated!`, "success");

    // Open receipt modal — include a studentSnapshot so PDF and voucher have the latest particulars
    const studentSnapshot = {
      ...currentStudent,
      paidFees: (Number(currentStudent.paidFees) || 0) + amt,
      monthlyParticulars: updatedMonthlyParticulars
    };
    setPrintReceiptData({
      payment: {
        ...newPayment,
        previousDue: prevDue,
        totalMonthDemand: totalDemand,
        totalPaidAfter: totalPaidAfterPayment,
        balanceDue: remainingAfterPayment,
        particularsSnapshot
      },
      student: studentSnapshot,
      settings
    });
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-3 sm:p-6 bg-black/75 backdrop-blur-xs overflow-y-auto font-sans">
      <div className="bg-[#0f172a] text-white border border-[#1e293b] rounded-3xl w-full max-w-2xl shadow-2xl overflow-hidden my-6 animate-in fade-in zoom-in-95 duration-200">

        {/* ── Top Bar ── */}
        <div className="px-6 py-4 bg-[#1e1b4b] border-b border-[#312e81] flex items-center justify-between">
          <div className="flex items-center gap-3">
            <button
              onClick={onClose}
              className="p-2 rounded-xl bg-white/10 hover:bg-white/20 text-white transition-colors cursor-pointer"
            >
              <ChevronLeft className="w-5 h-5" />
            </button>
            <div>
              <h2 className="text-lg font-black tracking-tight text-white flex items-center gap-2">
                <span>Fees — {currentStudent.name}</span>
              </h2>
              <p className="text-[11px] text-indigo-200 font-medium">
                {currentStudent.studentType === 'school' ? `Class ${currentStudent.className || ''} (Sec ${currentStudent.section || 'A'})` : currentStudent.course || ''} · Adm No: {currentStudent.admissionNumber || currentStudent.studentId}
              </p>
            </div>
          </div>

          <div className="flex items-center gap-2">
            <button
              onClick={() => setWhatsAppReminderData({ student: currentStudent, dueAmount: totalRemainingBalance })}
              className="px-3 py-1.5 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white text-xs font-bold flex items-center gap-1.5 transition-colors cursor-pointer shadow-sm"
              title="Send WhatsApp Fee Due Reminder (Hindi / English)"
            >
              <MessageSquare className="w-3.5 h-3.5" />
              <span>WhatsApp</span>
            </button>
            <button
              onClick={onClose}
              className="p-2 rounded-xl bg-white/10 hover:bg-white/20 text-white transition-colors cursor-pointer"
            >
              <X className="w-4 h-4" />
            </button>
          </div>
        </div>

        {/* ── Student Selector & Filter Bar (Only visible from top "Student Fee Structure & Pay" button) ── */}
        {isFeeDetailSelectorOpen && (
          <div className="px-6 py-2.5 bg-[#0e1726] border-b border-[#1e293b] flex flex-wrap items-center gap-2.5">
            {/* Instant Search Box */}
            <div className="flex items-center gap-1.5 flex-1 min-w-[140px]">
              <input
                type="text"
                placeholder="Search Name / ID..."
                value={studentSearch}
                onChange={(e) => setStudentSearch(e.target.value)}
                className="w-full px-2.5 py-1.5 rounded-lg bg-[#1e293b] border border-indigo-500/30 text-xs text-white placeholder-indigo-300/40 focus:outline-none focus:border-indigo-400"
              />
            </div>

            {/* Class Filter */}
            <div className="flex items-center gap-1.5 flex-1 min-w-[120px]">
              <span className="text-[10px] text-indigo-300 font-bold uppercase whitespace-nowrap">Class:</span>
              <select
                value={classFilter}
                onChange={(e) => {
                  const newClass = e.target.value;
                  setClassFilter(newClass);
                  const match = students.find(s => (newClass === 'all' || s.className === newClass) && (sectionFilter === 'all' || s.section === sectionFilter));
                  if (match) setSelectedStudentId(match.id);
                }}
                className="w-full px-2.5 py-1.5 rounded-lg bg-[#1e293b] border border-indigo-500/30 text-xs text-white font-bold focus:outline-none focus:border-indigo-400 cursor-pointer"
              >
                <option value="all">All Classes</option>
                {uniqueClasses.map(c => (
                  <option key={c} value={c}>Class {c}</option>
                ))}
              </select>
            </div>

            {/* Section Filter */}
            {uniqueSections.length > 0 && (
              <div className="flex items-center gap-1.5 min-w-[100px]">
                <span className="text-[10px] text-indigo-300 font-bold uppercase whitespace-nowrap">Sec:</span>
                <select
                  value={sectionFilter}
                  onChange={(e) => {
                    const newSec = e.target.value;
                    setSectionFilter(newSec);
                    const match = students.find(s => (classFilter === 'all' || s.className === classFilter) && (newSec === 'all' || s.section === newSec));
                    if (match) setSelectedStudentId(match.id);
                  }}
                  className="w-full px-2.5 py-1.5 rounded-lg bg-[#1e293b] border border-indigo-500/30 text-xs text-white font-bold focus:outline-none focus:border-indigo-400 cursor-pointer"
                >
                  <option value="all">All</option>
                  {uniqueSections.map(sec => (
                    <option key={sec} value={sec}>{sec}</option>
                  ))}
                </select>
              </div>
            )}

            {/* Student Selector Dropdown */}
            <div className="flex items-center gap-1.5 flex-2 min-w-[210px]">
              <span className="text-[10px] text-indigo-300 font-bold uppercase whitespace-nowrap">Student:</span>
              <select
                value={selectedStudentId}
                onChange={(e) => setSelectedStudentId(e.target.value)}
                className="w-full px-2.5 py-1.5 rounded-lg bg-[#1e293b] border border-indigo-500/30 text-xs text-white font-bold focus:outline-none focus:border-indigo-400 cursor-pointer"
              >
                {filteredStudents.map(s => {
                  const sLedger = getStudentMonthLedger(s, payments);
                  const sMonthData = sLedger[monthKey] || {};
                  const sDue = sMonthData.closingDue !== undefined ? sMonthData.closingDue : Math.max(0, (s.totalFees || 0) - (s.paidFees || 0));
                  return (
                    <option key={s.id} value={s.id}>
                      {s.name} ({s.studentType === 'school' ? `Class ${s.className || ''}` : s.course}) — Due: ₹{sDue.toLocaleString('en-IN')}
                    </option>
                  );
                })}
              </select>
            </div>
          </div>
        )}

        <div className="p-6 space-y-6 max-h-[80vh] overflow-y-auto custom-scrollbar">

          {/* ── Month Selector with Auto-Rollover Badge ── */}
          <div className="flex items-center justify-between bg-[#1e293b] p-3.5 rounded-2xl border border-[#334155]">
            <button
              onClick={handlePrevMonth}
              className="p-2 rounded-xl bg-[#0f172a] hover:bg-[#334155] text-white transition-colors cursor-pointer"
            >
              <ChevronLeft className="w-4 h-4" />
            </button>

            <div className="text-center">
              <div className="text-sm font-black text-white flex items-center justify-center gap-2">
                <Calendar className="w-4 h-4 text-indigo-400" />
                <span>{monthYearLabel}</span>
              </div>
              <div className="text-[10px] text-emerald-400 font-bold mt-0.5 flex items-center justify-center gap-1">
                <Sparkles className="w-3 h-3" />
                <span>Previous Dues Automatically Carried Forward</span>
              </div>
            </div>

            <button
              onClick={handleNextMonth}
              className="p-2 rounded-xl bg-[#0f172a] hover:bg-[#334155] text-white transition-colors cursor-pointer"
            >
              <ChevronRight className="w-4 h-4" />
            </button>
          </div>

          {/* ── Auto-Accrued Monthly Summary Ribbon ── */}
          <div className="grid grid-cols-2 sm:grid-cols-4 gap-2.5 text-xs font-semibold">
            <div className="p-3 bg-[#1e293b]/70 border border-amber-500/30 rounded-xl">
              <div className="text-[9px] font-bold text-amber-400 uppercase">Previous Due (Carried)</div>
              <div className="text-sm font-black text-amber-400 mt-1">₹{(Number(particulars.previousDues) || currentMonthData.previousDue || 0).toLocaleString('en-IN')}</div>
              <div className="text-[8px] text-slate-400">Auto rolled from last month</div>
            </div>

            <div className="p-3 bg-[#1e293b]/70 border border-[#334155] rounded-xl">
              <div className="text-[9px] font-bold text-slate-400 uppercase">Total Demand (This Month)</div>
              <div className="text-sm font-black text-indigo-300 mt-1">₹{totalDueForMonth.toLocaleString('en-IN')}</div>
              <div className="text-[8px] text-slate-400">Sum of all 13 fee heads</div>
            </div>

            <div className="p-3 bg-[#1e293b]/70 border border-emerald-500/30 rounded-xl">
              <div className="text-[9px] font-bold text-emerald-400 uppercase">Paid This Month</div>
              <div className="text-sm font-black text-emerald-400 mt-1">₹{paidForMonth.toLocaleString('en-IN')}</div>
              <div className="text-[8px] text-slate-400">{studentMonthPayments.length} receipt(s)</div>
            </div>

            <div className={`p-3 border rounded-xl ${remainingForMonth > 0 ? 'bg-rose-950/50 border-rose-500/40' : 'bg-emerald-950/40 border-emerald-500/30'}`}>
              <div className={`text-[9px] font-bold uppercase ${remainingForMonth > 0 ? 'text-rose-400' : 'text-emerald-400'}`}>Remaining Fee</div>
              <div className={`text-sm font-black mt-1 ${remainingForMonth > 0 ? 'text-rose-400' : 'text-emerald-400'}`}>₹{remainingForMonth.toLocaleString('en-IN')}</div>
              <div className="text-[8px] text-slate-400">{remainingForMonth > 0 ? 'Auto rolls to next month' : '✓ Month Cleared'}</div>
            </div>
          </div>

          {/* ── 2. Monthly Fee Particulars (13 Fee Heads) ── */}
          <div className="bg-[#1e293b] border border-[#334155] rounded-2xl p-5 space-y-4">
            <div className="flex items-center justify-between border-b border-[#334155] pb-3">
              <div>
                <h3 className="font-bold text-sm text-white flex items-center gap-2">
                  <Receipt className="w-4 h-4 text-indigo-400" />
                  <span>Fee Particulars</span>
                </h3>
                <p className="text-[11px] text-slate-400">
                  Previous Dues is automatically pulled from the preceding month's balance. Customize for {monthYearLabel}.
                </p>
              </div>
              <div className="flex items-center gap-2">
                <button
                  type="button"
                  onClick={() => setShowResetConfirm(true)}
                  className="px-3 py-1.5 bg-slate-800 hover:bg-slate-700 text-slate-300 hover:text-white rounded-xl text-xs font-bold flex items-center gap-1.5 cursor-pointer border border-[#334155] transition-colors"
                  title="Reset particulars to default fee"
                >
                  <RotateCcw className="w-3.5 h-3.5 text-amber-400" />
                  <span>Reset Fee</span>
                </button>
                <button
                  type="button"
                  onClick={handleSaveParticulars}
                  className="px-3.5 py-1.5 bg-indigo-600 hover:bg-indigo-500 text-white rounded-xl text-xs font-bold flex items-center gap-1.5 cursor-pointer shadow-sm transition-colors"
                >
                  <Save className="w-3.5 h-3.5" />
                  <span>Save Fee Particulars</span>
                </button>
              </div>
            </div>

            {/* Reset Fee Confirmation Modal */}
            {showResetConfirm && (
              <div className="fixed inset-0 z-50 bg-black/70 backdrop-blur-xs flex items-center justify-center p-4">
                <div className="bg-[#1e293b] border border-[#334155] rounded-2xl p-5 max-w-sm w-full space-y-4 shadow-2xl animate-in fade-in zoom-in-95">
                  <div className="flex items-center gap-3">
                    <div className="p-2.5 bg-amber-500/10 rounded-xl text-amber-400">
                      <AlertCircle className="w-5 h-5" />
                    </div>
                    <div>
                      <h4 className="font-bold text-sm text-white">Reset Fee Particulars?</h4>
                      <p className="text-[11px] text-slate-400">{monthYearLabel}</p>
                    </div>
                  </div>
                  <p className="text-xs text-slate-300 leading-relaxed">
                    Kya aap {monthYearLabel} ke extra fee heads ko reset karna chahte hain? Regular monthly fees aur previous dues ledger se restore ho jayenge.
                  </p>
                  <div className="flex items-center justify-end gap-2 pt-2">
                    <button
                      type="button"
                      onClick={() => setShowResetConfirm(false)}
                      className="px-3.5 py-1.5 bg-slate-800 hover:bg-slate-700 text-slate-300 text-xs font-bold rounded-xl transition-colors cursor-pointer"
                    >
                      No, Cancel
                    </button>
                    <button
                      type="button"
                      onClick={handleResetParticulars}
                      className="px-3.5 py-1.5 bg-rose-600 hover:bg-rose-500 text-white text-xs font-bold rounded-xl transition-colors cursor-pointer shadow-sm"
                    >
                      Yes, Reset Fee
                    </button>
                  </div>
                </div>
              </div>
            )}

            <div className="grid grid-cols-2 sm:grid-cols-3 gap-3 text-xs">
              {[
                { label: 'Admission Fee', key: 'admissionFee' },
                { label: 'Tuition Fee', key: 'tuitionFee' },
                { label: 'Examination Fee', key: 'examinationFee' },
                { label: 'Previous Dues (Carry/Initial)', key: 'previousDues', readOnly: false, highlight: true },
                { label: 'Game Fee', key: 'gameFee' },
                { label: 'Re-Admission Fee', key: 'reAdmissionFee' },
                { label: 'Development Fee', key: 'developmentFee' },
                { label: 'School ID', key: 'schoolId' },
                { label: 'Tie, Bag, Belt', key: 'tieBagBelt' },
                { label: 'Back Dues', key: 'backDues' },
                { label: 'Transport Fee', key: 'transportFee' },
                { label: 'Other Fee', key: 'otherFee' },
                { label: 'Late Fine', key: 'lateFine' },
              ].map(head => (
                <div key={head.key} className="space-y-1">
                  <label className={`block text-[11px] font-bold ${head.highlight ? 'text-amber-400' : 'text-slate-300'}`}>
                    {head.label}
                  </label>
                  <div className="relative">
                    <span className="absolute left-2.5 top-1/2 -translate-y-1/2 text-slate-400 text-xs">₹</span>
                    <input
                      type="number"
                      min="0"
                      readOnly={head.readOnly}
                      value={particulars[head.key]}
                      onChange={(e) => {
                        if (!head.readOnly) {
                          setParticulars({ ...particulars, [head.key]: e.target.value });
                        }
                      }}
                      placeholder="0"
                      className={`w-full pl-6 pr-2.5 py-1.5 rounded-xl bg-[#0f172a] border text-xs font-mono font-bold focus:outline-none focus:border-indigo-500 ${head.readOnly ? 'opacity-85 cursor-not-allowed bg-slate-900/60' : ''
                        } ${head.highlight ? 'border-amber-500/60 text-amber-300' : 'border-[#334155] text-white'
                        }`}
                    />
                  </div>
                </div>
              ))}
            </div>

            <div className="flex items-center justify-between border-t border-[#334155] pt-3">
              <span className="font-black text-sm text-slate-300">TOTAL PARTICULAR DEMAND</span>
              <span className="font-black text-lg text-white">₹{totalDueForMonth.toLocaleString('en-IN')}</span>
            </div>
          </div>

          {/* ── 3. Due Date ── */}
          <div className="bg-[#1e293b] border border-[#334155] rounded-2xl p-5 space-y-3">
            <div className="flex items-center justify-between">
              <div>
                <h4 className="font-bold text-sm text-amber-400 flex items-center gap-2">
                  <Calendar className="w-4 h-4" />
                  <span>Due Date</span>
                </h4>
                <p className="text-[11px] text-slate-400">Payment due date for {monthYearLabel}</p>
              </div>
              <div className="flex items-center gap-2">
                <input
                  type="date"
                  value={dueDate}
                  onChange={(e) => setDueDate(e.target.value)}
                  className="px-3 py-1.5 rounded-xl bg-[#0f172a] border border-[#334155] text-white text-xs font-mono focus:outline-none focus:border-amber-500"
                />
              </div>
            </div>
          </div>

          {/* ── 4. Add Payment / Record Payment ── */}
          <div className="bg-[#1e293b] border border-emerald-500/30 rounded-2xl p-5 space-y-4">
            <div className="flex items-center justify-between border-b border-[#334155] pb-3">
              <div className="flex items-center gap-2 text-emerald-400 font-bold text-sm">
                <Receipt className="w-4 h-4" />
                <span>Add Payment</span>
              </div>
              <div className="text-right">
                {remainingForMonth > 0 ? (
                  <>
                    <span className="text-[11px] text-slate-400 mr-2">Remaining Due:</span>
                    <span className="font-black text-base text-rose-400">₹{remainingForMonth.toLocaleString('en-IN')}</span>
                  </>
                ) : (
                  <span className="text-[11px] font-bold text-emerald-400">✓ Month Fully Cleared</span>
                )}
              </div>
            </div>

            <form onSubmit={handleRecordPayment} className="space-y-4 text-xs">
              {/* Active Fee Month & Payment Date Context Banner */}
              <div className="flex items-center justify-between p-2.5 bg-[#0f172a] border border-emerald-500/20 rounded-xl">
                <div className="flex items-center gap-2">
                  <Calendar className="w-3.5 h-3.5 text-emerald-400" />
                  <span className="text-[11px] text-slate-300">
                    Applying fee to: <strong className="text-emerald-400 font-bold">{monthYearLabel}</strong>
                  </span>
                </div>
                <div className="text-[11px] text-slate-400">
                  Payment Date: <strong className="text-white font-mono">{new Date().toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' })}</strong>
                </div>
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
                <div>
                  <label className="block text-slate-300 font-bold mb-1">
                    Payment Amount (₹) <span className="text-rose-400">*</span>
                  </label>
                  <input
                    type="number"
                    min="1"
                    required
                    placeholder="Enter amount to pay"
                    value={paymentAmount}
                    onChange={(e) => setPaymentAmount(e.target.value)}
                    className="w-full px-3 py-2 rounded-xl bg-[#0f172a] border border-[#334155] text-white font-mono font-bold focus:outline-none focus:border-emerald-500"
                  />
                </div>

                <div>
                  <label className="block text-slate-300 font-bold mb-1">Payment Mode</label>
                  <select
                    value={paymentMode}
                    onChange={(e) => setPaymentMode(e.target.value)}
                    className="w-full px-3 py-2 rounded-xl bg-[#0f172a] border border-[#334155] text-white focus:outline-none focus:border-emerald-500 cursor-pointer"
                  >
                    <option value="Cash">Cash</option>
                    <option value="UPI">UPI / QR Code</option>
                    <option value="Bank Transfer">Bank Transfer</option>
                    <option value="Card">Debit/Credit Card</option>
                    <option value="Cheque">Cheque</option>
                    <option value="NEFT">NEFT / RTGS</option>
                  </select>
                </div>

                <div>
                  <label className="block text-slate-300 font-bold mb-1">Remarks (optional)</label>
                  <input
                    type="text"
                    placeholder="e.g. Fee cleared via GPay"
                    value={remarks}
                    onChange={(e) => setRemarks(e.target.value)}
                    className="w-full px-3 py-2 rounded-xl bg-[#0f172a] border border-[#334155] text-white focus:outline-none focus:border-emerald-500"
                  />
                </div>
              </div>

              <div className="flex items-center justify-between pt-2">
                <div className="text-[11px] text-slate-400">
                  Payment will be logged in ledger & receipt voucher generated.
                </div>

                <button
                  type="submit"
                  disabled={currentMonthData.closingDue <= 0 && (!paymentAmount || Number(paymentAmount) <= 0)}
                  className="px-5 py-2.5 bg-emerald-600 hover:bg-emerald-500 text-white font-bold rounded-xl shadow-md flex items-center gap-2 cursor-pointer transition-all disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  <CheckCircle className="w-4 h-4" />
                  <span>Cut Receipt / Record Payment</span>
                </button>
              </div>
            </form>
          </div>

        </div>
      </div>
    </div>
  );
}
