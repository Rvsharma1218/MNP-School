'use client';

import React, { useState, useEffect } from 'react';
import { useSchoolStore, calculateStudentFeeMetrics } from '../lib/store';
import {
  X,
  CreditCard,
  Receipt,
  User,
  Calendar,
  CheckCircle,
  IndianRupee,
  FileText,
  Printer,
  Sparkles,
  AlertCircle
} from 'lucide-react';

export default function CollectFeeModal({ student, isOpen, onClose }) {
  const { students, settings, payments, addPayment, updateStudent, setPrintReceiptData, getNextReceiptNumber, showToast } = useSchoolStore();

  const [selectedStudentId, setSelectedStudentId] = useState(student?.id || '');
  const [amount, setAmount] = useState('');
  const [paymentMode, setPaymentMode] = useState('Cash');
  const [feeMonth, setFeeMonth] = useState('Monthly Tuition Fee');
  const [receiptNumber, setReceiptNumber] = useState('');
  const [remarks, setRemarks] = useState('');
  const [paymentDate, setPaymentDate] = useState(new Date().toISOString().split('T')[0]);

  useEffect(() => {
    const target = student || (students.length > 0 ? students[0] : null);
    if (target) {
      setSelectedStudentId(target.id);
      const metrics = calculateStudentFeeMetrics(target, payments);
      const originalFee = Number(target.monthlyFee) > 0
        ? Number(target.monthlyFee)
        : (Number(target.feeStructure?.tuitionFee) > 0
            ? Number(target.feeStructure.tuitionFee)
            : 0);
      const defaultAmt = metrics.currentDue > 0 ? metrics.currentDue : (originalFee > 0 ? originalFee : '');
      setAmount(defaultAmt ? String(defaultAmt) : '');
    }
    const recYear = new Date().getFullYear();
    const nextRecNo = getNextReceiptNumber ? getNextReceiptNumber(payments, recYear) : `REC-${recYear}-001`;
    setReceiptNumber(nextRecNo);
  }, [student, students, payments, isOpen]);

  const currentStudent = students.find(s => s.id === selectedStudentId);
  const metrics = currentStudent ? calculateStudentFeeMetrics(currentStudent, payments) : null;
  const currentMonth = metrics?.currentMonthData;

  const originalMonthlyFee = Number(currentStudent?.monthlyFee) > 0
    ? Number(currentStudent.monthlyFee)
    : (Number(currentStudent?.feeStructure?.tuitionFee) > 0
        ? Number(currentStudent.feeStructure.tuitionFee)
        : 0);
  
  // Month-specific breakdown vs Overall Session
  const activeMonthName = currentMonth?.monthLabel || currentMonth?.monthName || `${new Date().toLocaleString('default', { month: 'long' })} ${new Date().getFullYear()}`;
  const monthDemand = currentMonth ? (Number(currentMonth.totalDueThisMonth) || Number(currentMonth.totalMonthCharge) || metrics.currentDue) : (metrics?.currentDue || 0);
  const monthAlreadyPaid = currentMonth ? (Number(currentMonth.paidInMonth) || 0) : 0;
  const monthDueBeforePay = currentMonth ? Number(currentMonth.closingDue) : (metrics?.currentDue || 0);
  
  const currentPayment = Number(amount) || 0;
  const monthRemainingDue = Math.max(0, monthDueBeforePay - currentPayment);
  
  const totalSessionFee = Number(currentStudent?.totalFees) > 0 ? Number(currentStudent.totalFees) : (metrics ? metrics.setTotalFees : 0);
  const previousPaidTotal = metrics ? metrics.totalPaid : (Number(currentStudent?.paidFees) || 0);
  const totalPaidAfterClearing = previousPaidTotal + currentPayment;
  const sessionRemainingDue = Math.max(0, totalSessionFee - totalPaidAfterClearing);

  if (!isOpen) return null;

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!currentStudent) {
      showToast("Please select a student.", "error");
      return;
    }
    if (!amount || Number(amount) <= 0) {
      showToast("Please enter a valid payment amount.", "error");
      return;
    }

    let payDate = new Date();
    if (paymentDate) {
      const parts = paymentDate.split('-').map(Number);
      if (parts.length === 3 && !isNaN(parts[0]) && !isNaN(parts[1]) && !isNaN(parts[2])) {
        const now = new Date();
        payDate = new Date(parts[0], parts[1] - 1, parts[2], now.getHours(), now.getMinutes(), now.getSeconds(), now.getMilliseconds());
      } else {
        payDate = new Date(paymentDate);
      }
    }
    const payDateKey = `${payDate.getFullYear()}-${String(payDate.getMonth() + 1).padStart(2, '0')}`;
    const mNames = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
    const finalFeeMonth = (feeMonth && feeMonth !== 'Monthly Tuition Fee') ? feeMonth : (activeMonthName || `${mNames[payDate.getMonth()]} ${payDate.getFullYear()}`);
    const finalMonthKey = payDateKey;

    const prevDue = currentMonth?.previousDue || 0;
    const resolvedTuition = Number(currentMonth?.tuitionFee) > 0
      ? Number(currentMonth.tuitionFee)
      : (originalMonthlyFee > 0 ? originalMonthlyFee : Number(amount));

    const totalMonthCharge = currentMonth?.totalMonthCharge > 0 ? Number(currentMonth.totalMonthCharge) : resolvedTuition;
    const totalDemand = currentMonth?.totalDueThisMonth || (prevDue + totalMonthCharge);
    const alreadyPaidThisMonth = currentMonth?.paidInMonth || 0;
    const totalPaidAfterPayment = alreadyPaidThisMonth + Number(amount);
    const remainingAfterPayment = Math.max(0, totalDemand - totalPaidAfterPayment);

    const particularsSnapshot = {
      admissionFee:   Number(currentMonth?.admissionFee)   || 0,
      tuitionFee:     resolvedTuition,
      examinationFee: Number(currentMonth?.examinationFee) || 0,
      previousDues:   prevDue,
      gameFee:        Number(currentMonth?.gameFee)        || 0,
      reAdmissionFee: Number(currentMonth?.reAdmissionFee) || 0,
      developmentFee: Number(currentMonth?.developmentFee) || 0,
      schoolId:       Number(currentMonth?.schoolId)       || 0,
      tieBagBelt:     Number(currentMonth?.tieBagBelt)     || 0,
      transportFee:   Number(currentMonth?.transportFee)   || 0,
      otherFee:       Number(currentMonth?.otherFee)       || 0,
      lateFine:       Number(currentMonth?.lateFine)       || 0,
    };

    const updatedMonthlyParticulars = {
      ...(currentStudent.monthlyParticulars || {}),
      [finalMonthKey]: {
        ...particularsSnapshot,
        dueDate: `${payDate.getFullYear()}-${String(payDate.getMonth() + 1).padStart(2, '0')}-10`,
        totalDue: totalDemand,
        monthName: finalFeeMonth
      }
    };
    const tFee = originalMonthlyFee > 0 ? originalMonthlyFee : Number(amount);
    const updatedFeeStructure = {
      ...(currentStudent.feeStructure || {}),
      tuitionFee: tFee,
      dueDay: Number(currentStudent.feeStructure?.dueDay) || 10
    };

    const newPayment = await addPayment({
      studentId: currentStudent.id,
      studentName: currentStudent.name,
      mobile: currentStudent.mobile || '',
      alternateMobile: currentStudent.alternateMobile || '',
      admissionNumber: currentStudent.admissionNumber || '',
      amount: Number(amount),
      paymentMode,
      feeMonth: finalFeeMonth,
      monthKey: finalMonthKey,
      receiptNumber: finalRecNo,
      remarks: remarks || `Fee payment for ${finalFeeMonth}`,
      paymentDate: payDate.toISOString(),
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

    onClose();
    showToast(`Payment of ₹${Number(amount).toLocaleString('en-IN')} recorded & Receipt generated!`, "success");

    // Automatically trigger receipt voucher viewer & printer
    setPrintReceiptData({
      payment: {
        ...newPayment,
        previousDue: prevDue,
        totalMonthDemand: totalDemand,
        totalPaidAfter: totalPaidAfterPayment,
        balanceDue: remainingAfterPayment,
        particularsSnapshot
      },
      student: {
        ...currentStudent,
        paidFees: totalPaidAfterClearing,
        monthlyParticulars: updatedMonthlyParticulars
      },
      settings
    });
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-xs overflow-y-auto font-sans">
      <div className="bg-card border border-border rounded-3xl w-full max-w-lg shadow-2xl overflow-hidden my-8 animate-in fade-in zoom-in-95 duration-200">
        {/* Header */}
        <div className="px-6 py-4 border-b border-border bg-emerald-500/10 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-emerald-600 text-white flex items-center justify-center font-bold shadow-md shadow-emerald-500/20">
              <CreditCard className="w-5 h-5" />
            </div>
            <div>
              <h3 className="font-bold text-base text-text">Collect Fee Payment</h3>
              <p className="text-xs text-text-secondary">Instant voucher creation & ledger synchronization</p>
            </div>
          </div>

          <button
            onClick={onClose}
            className="p-2 rounded-xl text-text-muted hover:text-text hover:bg-surface2 transition-colors cursor-pointer"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Form Body */}
        <form onSubmit={handleSubmit} className="p-6 space-y-4">
          {/* Select Student */}
          <div>
            <label className="block text-xs font-bold text-text mb-1 uppercase tracking-wider">
              Select Student
            </label>
            <select
              value={selectedStudentId}
              onChange={(e) => {
                setSelectedStudentId(e.target.value);
                const s = students.find(st => st.id === e.target.value);
                if (s) {
                  const m = calculateStudentFeeMetrics(s, payments);
                  setAmount(m.currentDue > 0 ? String(m.currentDue) : '');
                  setFeeMonth(m.currentMonthData?.monthName || 'Monthly Tuition Fee');
                }
              }}
              className="w-full px-3.5 py-2.5 rounded-xl bg-surface2 border border-border text-xs text-text font-bold focus:outline-none focus:border-primary cursor-pointer"
            >
              {students.map(s => {
                const m = calculateStudentFeeMetrics(s, payments);
                return (
                  <option key={s.id} value={s.id}>
                    {s.name} ({s.studentType === 'school' ? `Class ${s.className || ''}` : s.course}) — Due: ₹{m.currentDue.toLocaleString('en-IN')}
                  </option>
                );
              })}
            </select>
          </div>

          {/* Real-time Fee Metrics Snapshot */}
          {metrics && (
            <div className="p-4 rounded-2xl bg-surface2/70 border border-border space-y-3">
              <div className="flex items-center justify-between pb-2 border-b border-border/60">
                <span className="text-xs font-bold text-text uppercase tracking-wider flex items-center gap-1.5">
                  <span>Fee Period:</span>
                  <span className="text-primary font-bold">{activeMonthName}</span>
                </span>
                <span className="text-[11px] font-mono font-bold text-text-secondary">ID: {currentStudent?.studentId}</span>
              </div>

              <div className="grid grid-cols-2 sm:grid-cols-4 gap-2 text-center">
                <div className="p-2 rounded-xl bg-card border border-border/70">
                  <div className="text-[10px] text-text-secondary font-bold uppercase">Month Demand</div>
                  <div className="text-xs font-black text-text mt-0.5 font-mono">₹{monthDemand.toLocaleString('en-IN')}</div>
                </div>

                <div className="p-2 rounded-xl bg-card border border-border/70">
                  <div className="text-[10px] text-text-secondary font-bold uppercase">Already Paid</div>
                  <div className="text-xs font-black text-emerald-600 mt-0.5 font-mono">₹{monthAlreadyPaid.toLocaleString('en-IN')}</div>
                </div>

                <div className="p-2 rounded-xl bg-primary/10 border border-primary/20">
                  <div className="text-[10px] text-primary font-bold uppercase">This Payment</div>
                  <div className="text-xs font-black text-primary mt-0.5 font-mono">₹{currentPayment.toLocaleString('en-IN')}</div>
                </div>

                <div className={`p-2 rounded-xl border ${monthRemainingDue === 0 ? 'bg-emerald-500/10 border-emerald-500/30' : 'bg-rose-500/10 border-rose-500/20'}`}>
                  <div className={`text-[10px] font-bold uppercase ${monthRemainingDue === 0 ? 'text-emerald-700 dark:text-emerald-400' : 'text-rose-600 dark:text-rose-400'}`}>
                    {monthRemainingDue === 0 ? 'Month Cleared' : 'Remaining Due'}
                  </div>
                  <div className={`text-xs font-black mt-0.5 font-mono ${monthRemainingDue === 0 ? 'text-emerald-700 dark:text-emerald-400' : 'text-rose-600 dark:text-rose-400'}`}>
                    ₹{monthRemainingDue.toLocaleString('en-IN')}
                  </div>
                </div>
              </div>

              <div className="flex items-center justify-between pt-1 text-xs text-text-secondary">
                <span className="font-medium">Total Paid So Far (Session):</span>
                <span className="font-bold text-emerald-600 font-mono">₹{totalPaidAfterClearing.toLocaleString('en-IN')} / ₹{totalSessionFee.toLocaleString('en-IN')}</span>
              </div>
            </div>
          )}

          {/* Amount & Mode */}
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3.5">
            <div>
              <div className="flex items-center justify-between mb-1">
                <label className="block text-xs font-bold text-text uppercase tracking-wider">
                  Current Payment (₹) <span className="text-rose-500">*</span>
                </label>
                {originalMonthlyFee > 0 && (
                  <span className="text-[10px] text-text-secondary font-medium">
                    Original Fee: <strong className="text-text font-bold">₹{originalMonthlyFee.toLocaleString('en-IN')}</strong>
                  </span>
                )}
              </div>
              <div className="relative">
                <input
                  type="number"
                  min="1"
                  required
                  placeholder="0"
                  value={amount}
                  onChange={(e) => setAmount(e.target.value)}
                  className="w-full px-3.5 py-2.5 rounded-xl bg-surface2 border border-border text-sm font-black text-emerald-600 focus:outline-none focus:border-primary"
                />
              </div>
              {/* Quick Fill Chips */}
              <div className="flex flex-wrap items-center gap-1.5 mt-1.5">
                {originalMonthlyFee > 0 && (
                  <button
                    type="button"
                    onClick={() => setAmount(String(originalMonthlyFee))}
                    className="px-2 py-0.5 rounded bg-surface2 hover:bg-surface2/80 text-text-secondary hover:text-text text-[10px] font-bold border border-border transition-colors cursor-pointer"
                  >
                    Original Fee: ₹{originalMonthlyFee}
                  </button>
                )}
                {metrics?.currentDue > 0 && metrics.currentDue !== originalMonthlyFee && (
                  <button
                    type="button"
                    onClick={() => setAmount(String(metrics.currentDue))}
                    className="px-2 py-0.5 rounded bg-rose-500/10 hover:bg-rose-500/20 text-rose-600 text-[10px] font-bold border border-rose-500/20 transition-colors cursor-pointer"
                  >
                    Full Due: ₹{metrics.currentDue}
                  </button>
                )}
              </div>
            </div>

            <div>
              <label className="block text-xs font-bold text-text mb-1 uppercase tracking-wider">
                Payment Method
              </label>
              <select
                value={paymentMode}
                onChange={(e) => setPaymentMode(e.target.value)}
                className="w-full px-3.5 py-2.5 rounded-xl bg-surface2 border border-border text-xs text-text font-bold focus:outline-none focus:border-primary cursor-pointer"
              >
                <option value="Cash">Cash</option>
                <option value="Online / UPI">Online / UPI (QR)</option>
                <option value="Bank Transfer">Bank Transfer (NEFT/IMPS)</option>
                <option value="Debit / Credit Card">Debit / Credit Card</option>
                <option value="Cheque">Cheque</option>
              </select>
            </div>
          </div>

          {/* Fee Month & Date */}
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3.5">
            <div>
              <label className="block text-xs font-bold text-text mb-1 uppercase tracking-wider">
                Fee Month / Head
              </label>
              <input
                type="text"
                value={feeMonth}
                onChange={(e) => setFeeMonth(e.target.value)}
                placeholder="e.g. August 2026 / Term 1"
                className="w-full px-3.5 py-2.5 rounded-xl bg-surface2 border border-border text-xs text-text font-semibold focus:outline-none focus:border-primary"
              />
            </div>

            <div>
              <label className="block text-xs font-bold text-text mb-1 uppercase tracking-wider">
                Payment Date
              </label>
              <input
                type="date"
                value={paymentDate}
                onChange={(e) => setPaymentDate(e.target.value)}
                className="w-full px-3.5 py-2.5 rounded-xl bg-surface2 border border-border text-xs text-text font-bold focus:outline-none focus:border-primary"
              />
            </div>
          </div>

          {/* Receipt Number */}
          <div>
            <label className="block text-xs font-bold text-text mb-1 uppercase tracking-wider flex items-center justify-between">
              <span>Receipt Number</span>
              <span className="text-[10px] bg-primary/10 text-primary px-1.5 py-0.5 rounded font-sans font-bold uppercase">Auto-Generated</span>
            </label>
            <input
              type="text"
              value={receiptNumber}
              onChange={(e) => setReceiptNumber(e.target.value)}
              className="w-full px-3.5 py-2 rounded-xl bg-surface2 border border-border text-xs font-mono font-bold text-text focus:outline-none focus:border-primary"
            />
          </div>

          {/* Remarks */}
          <div>
            <label className="block text-xs font-bold text-text mb-1 uppercase tracking-wider">
              Remarks (Optional)
            </label>
            <input
              type="text"
              value={remarks}
              onChange={(e) => setRemarks(e.target.value)}
              placeholder="e.g. Paid via UPI, fee card signed"
              className="w-full px-3.5 py-2 rounded-xl bg-surface2 border border-border text-xs text-text focus:outline-none focus:border-primary"
            />
          </div>

          {/* Actions */}
          <div className="pt-4 border-t border-border flex items-center justify-end gap-2.5">
            <button
              type="button"
              onClick={onClose}
              className="px-4 py-2.5 rounded-xl bg-surface2 hover:bg-border text-text font-bold text-xs cursor-pointer transition-colors"
            >
              Cancel
            </button>

            <button
              type="submit"
              className="px-5 py-2.5 rounded-xl bg-emerald-600 hover:bg-emerald-700 text-white font-bold text-xs shadow-md shadow-emerald-600/20 cursor-pointer flex items-center gap-1.5 transition-all"
            >
              <Receipt className="w-4 h-4" />
              <span>Record & Generate Voucher</span>
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
