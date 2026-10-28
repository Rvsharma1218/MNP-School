'use client';

import React from 'react';
import { useSchoolStore } from '../lib/store';
import { Printer, X, Download, MessageSquare } from 'lucide-react';
import { openWhatsAppReceiptShare, exportReceiptPDF } from '../lib/exportUtils';

// Helper to convert numbers to words (Indian numbering system)
function numberToWords(amount) {
  const num = Math.floor(amount || 0);
  if (num === 0) return 'Zero Rupees';

  const a = ['', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine', 'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen'];
  const b = ['', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'];

  const convertLessThanOneThousand = (n) => {
    if (n === 0) return '';
    let tempStr = '';
    if (n >= 100) {
      tempStr += a[Math.floor(n / 100)] + ' Hundred ';
      n %= 100;
    }
    if (n >= 20) {
      tempStr += b[Math.floor(n / 10)] + ' ';
      n %= 10;
    }
    if (n > 0) {
      tempStr += a[n] + ' ';
    }
    return tempStr;
  };

  let str = '';
  let remaining = num;

  if (remaining >= 10000000) { // Crore
    const crores = Math.floor(remaining / 10000000);
    str += convertLessThanOneThousand(crores) + 'Crore ';
    remaining %= 10000000;
  }
  if (remaining >= 100000) { // Lakh
    const lakhs = Math.floor(remaining / 100000);
    str += convertLessThanOneThousand(lakhs) + 'Lakh ';
    remaining %= 100000;
  }
  if (remaining >= 1000) { // Thousand
    const thousands = Math.floor(remaining / 1000);
    str += convertLessThanOneThousand(thousands) + 'Thousand ';
    remaining %= 1000;
  }
  str += convertLessThanOneThousand(remaining);
  
  return str.trim() ? str.trim() : 'Zero';
}

export default function PrintReceiptModal({ payment, student, onClose }) {
  const { students, settings, payments } = useSchoolStore();

  // Fully resolve student to guarantee registered mobile number is present (especially for newly admitted students)
  const resolvedStudent = React.useMemo(() => {
    if (student?.mobile || student?.alternateMobile) return student;
    const match = (students || []).find(s =>
      (student?.id && s.id === student.id) ||
      (student?.studentId && (s.studentId === student.studentId || s.id === student.studentId)) ||
      (payment?.studentId && (s.id === payment.studentId || s.studentId === payment.studentId)) ||
      (student?.admissionNumber && (s.admissionNumber === student.admissionNumber || s.admissionNo === student.admissionNumber)) ||
      (student?.name && s.name && s.name.trim().toLowerCase() === student.name.trim().toLowerCase()) ||
      (payment?.studentName && s.name && s.name.trim().toLowerCase() === payment.studentName.trim().toLowerCase())
    );
    return match ? { ...match, ...student, mobile: match.mobile || student?.mobile || '', alternateMobile: match.alternateMobile || student?.alternateMobile || '' } : student;
  }, [student, payment, students]);

  if (!payment || !resolvedStudent) return null;

  const handlePrint = () => {
    window.print();
  };

  const handleDownloadPDF = async () => {
    await exportReceiptPDF(payment, resolvedStudent, settings, payments);
  };

  const handleWhatsApp = async () => {
    await openWhatsAppReceiptShare(payment, resolvedStudent, settings, payments);
  };

  // Safe date parsing
  const payDateObj = payment.paymentDate ? new Date(payment.paymentDate) : new Date();
  const safePayDate = isNaN(payDateObj.getTime()) ? new Date() : payDateObj;

  // Extract fee particulars from student's active monthly particulars or construct from payment
  const monthKey = payment.monthKey || `${safePayDate.getFullYear()}-${String(safePayDate.getMonth() + 1).padStart(2, '0')}`;
  const mp = student.monthlyParticulars?.[monthKey] || {};

  // Standard 12 itemized heads + 1 late fine
  const standardTuition = Number(student.feeStructure?.tuitionFee) > 0
    ? Number(student.feeStructure.tuitionFee)
    : (Number(student.monthlyFee) > 0 ? Number(student.monthlyFee) : 0);

  const resolvedTuition = (mp.tuitionFee !== undefined && Number(mp.tuitionFee) > 0)
    ? Number(mp.tuitionFee)
    : (standardTuition > 0 ? standardTuition : (Number(payment.totalMonthDemand) || Number(payment.amount) || 0));

  const resolvedPrevDue = (mp.previousDues !== undefined && Number(mp.previousDues) > 0)
    ? Number(mp.previousDues)
    : (Number(payment.previousDue) || Number(student.previousDue) || 0);

  const particularsList = [
    { sn: 1, label: 'Admission Fee', amount: mp.admissionFee || 0 },
    { sn: 2, label: 'Tuition Fee', amount: resolvedTuition },
    { sn: 3, label: 'Examination Fee', amount: mp.examinationFee || 0 },
    { sn: 4, label: 'Previous Dues', amount: resolvedPrevDue },
    { sn: 5, label: 'Game Fee', amount: mp.gameFee || 0 },
    { sn: 6, label: 'Re-Admission Fee', amount: mp.reAdmissionFee || 0 },
    { sn: 7, label: 'Development Fee', amount: mp.developmentFee || 0 },
    { sn: 8, label: 'School ID', amount: mp.schoolId || 0 },
    { sn: 9, label: 'Tie, Bag, Belt', amount: mp.tieBagBelt || 0 },
    { sn: 10, label: 'Back Dues', amount: mp.backDues || 0 },
    { sn: 11, label: 'Transport Fee', amount: mp.transportFee || 0 },
    { sn: 12, label: 'Other Fee', amount: mp.otherFee || 0 },
    { sn: '★', label: 'Late Fine', amount: mp.lateFine || 0, isLateFine: true }
  ];

  const totalCalculated = particularsList.reduce((acc, p) => acc + (Number(p.amount) || 0), 0);
  const totalAmount = Number(payment.totalMonthDemand) || (totalCalculated > 0 ? totalCalculated : Number(student.totalFees || payment.amount || 0));
  const amountPaid = Number(payment.amount || 0);

  // Find previous payment for this student
  const studentPayments = (payments || []).filter(
    p => (p.studentId === student.id || (student.studentId && p.studentId === student.studentId)) && p.id !== payment.id
  );
  studentPayments.sort((a, b) => new Date(b.paymentDate || 0) - new Date(a.paymentDate || 0));
  const lastPriorPayment = studentPayments[0];

  const previousPaid = payment.previousPaid !== undefined && Number(payment.previousPaid) > 0
    ? Number(payment.previousPaid)
    : (lastPriorPayment ? Number(lastPriorPayment.amount) : Math.max(0, (Number(student.paidFees) || 0) - amountPaid));

  let lastPaymentDateFormatted = '';
  if (payment.lastPaidDate) {
    const d = new Date(payment.lastPaidDate);
    if (!isNaN(d.getTime())) lastPaymentDateFormatted = d.toLocaleDateString('en-GB', { day: '2-digit', month: '2-digit', year: 'numeric' });
  } else if (lastPriorPayment?.paymentDate) {
    const d = new Date(lastPriorPayment.paymentDate);
    if (!isNaN(d.getTime())) lastPaymentDateFormatted = d.toLocaleDateString('en-GB', { day: '2-digit', month: '2-digit', year: 'numeric' });
  } else if (student.lastPaidDate) {
    const d = new Date(student.lastPaidDate);
    if (!isNaN(d.getTime())) lastPaymentDateFormatted = d.toLocaleDateString('en-GB', { day: '2-digit', month: '2-digit', year: 'numeric' });
  }

  const totalPaidAfter = payment.totalPaidAfter !== undefined ? Number(payment.totalPaidAfter) : (previousPaid + amountPaid);
  const balanceDue = payment.balanceDue !== undefined && payment.balanceDue !== null
    ? Number(payment.balanceDue)
    : Math.max(0, totalAmount - totalPaidAfter);

  const paymentDateFormatted = safePayDate.toLocaleDateString('en-GB', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric'
  });
  
  const paymentTimeFormatted = safePayDate.toLocaleTimeString('en-US', {
    hour: 'numeric',
    minute: '2-digit',
    hour12: true
  });

  const paymentDateLong = safePayDate.toLocaleDateString('en-GB', {
    day: 'numeric',
    month: 'short',
    year: 'numeric'
  });

  const dueDay = student.feeStructure?.dueDay || 10;
  const lateFinePerDay = student.feeStructure?.lateFinePerDay || 5;

  return (
    <div className="fixed inset-0 z-50 bg-black/70 backdrop-blur-xs flex items-center justify-center p-2 sm:p-4 overflow-y-auto font-sans">
      <div className="bg-white border border-slate-300 w-full max-w-xl rounded-2xl shadow-2xl overflow-hidden my-6 animate-in fade-in zoom-in-95 duration-200 print:border-none print:shadow-none print:my-0 print:w-full print:max-w-none">
        
        {/* Modal Action Controls (Hidden when printing) */}
        <div className="p-3.5 bg-slate-900 text-white border-b border-slate-800 flex items-center justify-between print:hidden">
          <div className="flex items-center gap-2">
            <span className="font-bold text-xs uppercase tracking-wider text-slate-300">Fee Receipt Voucher</span>
            <span className="text-[11px] bg-slate-800 px-2 py-0.5 rounded text-emerald-400 font-mono font-bold">
              {payment.receiptNumber}
            </span>
          </div>

          <div className="flex items-center gap-2">
            <button
              onClick={handleWhatsApp}
              className="px-3 py-1.5 rounded-lg bg-emerald-600 hover:bg-emerald-500 text-white font-bold text-xs flex items-center gap-1.5 cursor-pointer shadow-xs"
            >
              <MessageSquare className="w-3.5 h-3.5" />
              <span>WhatsApp</span>
            </button>
            <button
              onClick={handleDownloadPDF}
              className="px-3 py-1.5 rounded-lg bg-indigo-600 hover:bg-indigo-500 text-white font-bold text-xs flex items-center gap-1.5 cursor-pointer shadow-xs"
            >
              <Download className="w-3.5 h-3.5" />
              <span>PDF</span>
            </button>
            <button
              onClick={handlePrint}
              className="px-3.5 py-1.5 rounded-lg bg-white text-slate-900 hover:bg-slate-100 font-black text-xs flex items-center gap-1.5 cursor-pointer shadow-xs"
            >
              <Printer className="w-3.5 h-3.5" />
              <span>Print Slip</span>
            </button>
            <button
              onClick={onClose}
              className="p-1.5 rounded-lg text-slate-400 hover:text-white hover:bg-slate-800 transition-colors cursor-pointer"
            >
              <X className="w-4 h-4" />
            </button>
          </div>
        </div>

        {/* ─── EXACT PRINTABLE SCHOOL FEE RECEIPT VOUCHER ─── */}
        <div className="p-5 sm:p-7 max-h-[82vh] overflow-y-auto print:max-h-none print:overflow-visible print:p-0">
          <div className="border border-black p-5 sm:p-6 bg-white text-black font-sans text-[11.5px] leading-snug space-y-3.5 shadow-xs">
            
            {/* Header */}
            <div className="text-center space-y-0.5">
              {(settings.logoUrl || settings.logoPath || settings.logo) && (
                <div className="flex justify-center mb-1.5">
                  <img
                    src={settings.logoUrl || settings.logoPath || settings.logo}
                    alt="School Logo"
                    className="h-12 w-auto max-w-[120px] object-contain"
                    onError={(e) => { e.currentTarget.style.display = 'none'; }}
                  />
                </div>
              )}
              <div className="text-[11px] font-bold tracking-widest text-slate-800 uppercase">OFFICIAL FEE RECEIPT VOUCHER</div>
              <h1 className="text-lg sm:text-xl font-black uppercase tracking-tight text-black">
                {settings.instituteName || 'MY SCHOOL & COMPUTER INSTITUTE'}
              </h1>
              <p className="text-[10px] text-slate-700 font-medium">Add- {settings.address || 'Enter Your Address Here'}</p>
              <p className="text-[10px] text-slate-700 font-medium">Mob- {settings.mobile || '9876543210'}</p>
            </div>

            <hr className="border-t border-black/80" />

            {/* Meta & Student Details Grid */}
            <div className="space-y-1.5 text-[11px] text-black">
              <div className="flex justify-between items-center">
                <div>
                  <span className="font-normal text-slate-700">Receipt No: </span>
                  <span className="font-bold">{payment.receiptNumber || 'REC000001'}</span>
                </div>
                <div>
                  <span className="font-normal text-slate-700">Date: </span>
                  <span className="font-bold">{paymentDateFormatted} {paymentTimeFormatted}</span>
                </div>
              </div>

              <div className="flex justify-between items-center">
                <div>
                  <span className="text-slate-700">Student's Name: </span>
                  <span className="font-bold uppercase tracking-tight">{student.name}</span>
                </div>
                <div>
                  <span className="text-slate-700">Student ID: </span>
                  <span className="font-bold font-mono">{student.studentId || '-'}</span>
                </div>
              </div>

              <div className="flex justify-between items-center">
                <div>
                  <span className="text-slate-700">Admission No: </span>
                  <span className="font-bold font-mono">{student.admissionNumber || '-'}</span>
                </div>
                <div>
                  <span className="text-slate-700">Father's Name: </span>
                  <span className="font-bold">{student.fatherName || '-'}</span>
                </div>
              </div>

              <div className="flex justify-between items-center">
                <div>
                  <span className="text-slate-700">Class / Course: </span>
                  <span className="font-bold">
                    {student.studentType === 'school' ? `Class ${student.className || ''} - ${student.section || 'A'}` : student.course || 'ADCA'}
                  </span>
                </div>
                <div>
                  <span className="text-slate-700">Roll No: </span>
                  <span className="font-bold">{student.rollNumber || '-'}</span>
                </div>
              </div>

              <div className="flex justify-between items-center">
                <div>
                  <span className="text-slate-700">Fees For Period: </span>
                  <span className="font-bold">{payment.feeMonth || 'Monthly Tuition Fee'}</span>
                </div>
                <div>
                  <span className="text-slate-700">Payment Mode: </span>
                  <span className="font-bold">{payment.paymentMode || 'Cash'}</span>
                </div>
              </div>

              <div className="flex justify-between items-center">
                <div>
                  <span className="text-slate-700">Due Date: </span>
                  <span className="font-bold">{mp.dueDate || 'Not Set'}</span>
                </div>
                <div>
                  <span className="text-slate-700">Session: </span>
                  <span className="font-bold">{student.session || settings.currentSession || '2026-27'}</span>
                </div>
              </div>
            </div>

            {/* 13 Rows Particulars Table */}
            <div className="overflow-x-auto">
              <table className="w-full border-collapse border border-black text-[10.5px]">
                <thead>
                  <tr className="border-b border-black bg-slate-50 font-bold">
                    <th className="border-r border-black py-1 px-2 w-8 text-center">S.N.</th>
                    <th className="border-r border-black py-1 px-2 text-left">Particulars</th>
                    <th className="border-r border-black py-1 px-2 w-24 text-right">Amount (₹)</th>
                    <th className="py-1 px-1.5 w-8 text-center">P.</th>
                  </tr>
                </thead>
                <tbody>
                  {particularsList.map((p) => {
                    const amt = Number(p.amount) || 0;
                    return (
                      <tr key={p.sn} className="border-b border-black/60">
                        <td className="border-r border-black py-0.5 px-2 text-center text-slate-700 font-mono">
                          {p.sn}
                        </td>
                        <td className={`border-r border-black py-0.5 px-2 ${p.isLateFine ? 'font-bold' : ''}`}>
                          {p.label}
                        </td>
                        <td className="border-r border-black py-0.5 px-2 text-right font-mono font-medium">
                          {amt > 0 ? amt.toFixed(2) : ''}
                        </td>
                        <td className="py-0.5 px-1.5 text-center font-mono text-[9.5px]">
                          {amt > 0 ? '00' : ''}
                        </td>
                      </tr>
                    );
                  })}

                  {/* Summary Rows (Multi-payment & Full Paid Breakdown) */}
                  <tr className="border-t border-black font-bold bg-slate-50">
                    <td className="border-r border-black"></td>
                    <td className="border-r border-black py-1.5 px-2.5 text-right font-bold text-slate-800">Total Fee Demand</td>
                    <td className="border-r border-black py-1.5 px-2 text-right font-mono font-bold text-black">{totalAmount.toFixed(2)}</td>
                    <td className="py-1.5 px-1.5 text-center font-mono font-bold text-black">00</td>
                  </tr>

                  {previousPaid > 0 && (
                    <tr className="border-t border-black/80 font-bold bg-amber-50/70 text-amber-950">
                      <td className="border-r border-black"></td>
                      <td className="border-r border-black py-1.5 px-2.5 text-right font-bold">
                        Previous Payment {lastPaymentDateFormatted ? `(Last Paid: ${lastPaymentDateFormatted})` : ''}
                      </td>
                      <td className="border-r border-black py-1.5 px-2 text-right font-mono font-bold text-amber-900">
                        {previousPaid.toFixed(2)}
                      </td>
                      <td className="py-1.5 px-1.5 text-center font-mono font-bold text-amber-900">00</td>
                    </tr>
                  )}
                  
                  <tr className="border-t border-black/80 font-bold bg-emerald-50 text-emerald-950">
                    <td className="border-r border-black"></td>
                    <td className="border-r border-black py-1.5 px-2.5 text-right font-bold">
                      Current Payment (Paid Now)
                    </td>
                    <td className="border-r border-black py-1.5 px-2 text-right font-mono font-black text-emerald-800">
                      {amountPaid.toFixed(2)}
                    </td>
                    <td className="py-1.5 px-1.5 text-center font-mono font-bold text-emerald-800">00</td>
                  </tr>

                  {previousPaid > 0 && (
                    <tr className="border-t border-black/80 font-bold bg-blue-50/70 text-blue-950">
                      <td className="border-r border-black"></td>
                      <td className="border-r border-black py-1.5 px-2.5 text-right font-bold">
                        Total Amount Paid
                      </td>
                      <td className="border-r border-black py-1.5 px-2 text-right font-mono font-bold text-blue-900">
                        {totalPaidAfter.toFixed(2)}
                      </td>
                      <td className="py-1.5 px-1.5 text-center font-mono font-bold text-blue-900">00</td>
                    </tr>
                  )}

                  <tr className="border-t border-black/80 font-bold bg-rose-50 text-rose-950">
                    <td className="border-r border-black"></td>
                    <td className="border-r border-black py-1.5 px-2.5 text-right font-bold">
                      {balanceDue <= 0 ? 'Remaining Balance (FULL PAID)' : 'Pending Balance Due'}
                    </td>
                    <td className={`border-r border-black py-1.5 px-2 text-right font-mono font-black ${balanceDue <= 0 ? 'text-emerald-700' : 'text-rose-700'}`}>
                      {balanceDue.toFixed(2)}
                    </td>
                    <td className={`py-1.5 px-1.5 text-center font-mono font-bold ${balanceDue <= 0 ? 'text-emerald-700' : 'text-rose-700'}`}>00</td>
                  </tr>
                </tbody>
              </table>
            </div>

            {/* Rupees in Words */}
            <div className="text-[11px]">
              <span className="font-bold">Rupees: </span>
              <span className="capitalize">{numberToWords(amountPaid)} Only</span>
            </div>

            <hr className="border-t border-black/80" />

            {/* Payment Badge */}
            <div className="flex justify-center my-1">
              <div className={`inline-flex items-center gap-1.5 border px-3 py-0.5 rounded font-bold text-[10.5px] ${
                balanceDue <= 0
                  ? 'border-emerald-700 bg-emerald-50 text-emerald-900'
                  : 'border-rose-700 bg-rose-50 text-rose-900'
              }`}>
                <span className="font-mono">☑</span>
                <span>
                  {balanceDue <= 0
                    ? `FULL PAID: ₹${totalPaidAfter.toLocaleString('en-IN')} Cleared (Paid ₹${amountPaid.toLocaleString('en-IN')} on ${paymentDateLong} via ${payment.paymentMode || 'Cash'})`
                    : `PARTIAL PAYMENT: ₹${amountPaid.toLocaleString('en-IN')} Received | Balance Due: ₹${balanceDue.toLocaleString('en-IN')} (${paymentDateLong} via ${payment.paymentMode || 'Cash'})`}
                </span>
              </div>
            </div>

            {/* Signature & Stamp Area */}
            <div className="flex justify-between items-end pt-3 pb-1 text-[10.5px]">
              <div className="font-semibold text-slate-800">
                Class Teacher Sign.
              </div>
              <div className="text-right flex flex-col items-center">
                <div className="relative flex items-center justify-center min-w-[110px] min-h-[48px] mb-1">
                  {(settings.schoolStamp || settings.stampUrl || settings.sealUrl) && (
                    <img
                      src={settings.schoolStamp || settings.stampUrl || settings.sealUrl}
                      alt="Official Stamp"
                      className="absolute inset-0 m-auto object-contain opacity-90"
                      style={{
                        width: `${Math.round(48 * (Number(settings.stampScale) || 1.0))}px`,
                        height: `${Math.round(48 * (Number(settings.stampScale) || 1.0))}px`,
                        mixBlendMode: 'multiply'
                      }}
                      onError={(e) => { e.currentTarget.style.display = 'none'; }}
                    />
                  )}
                  {(settings.principalSignature || settings.signatureUrl || settings.signaturePath || settings.signature) && (
                    <img
                      src={settings.principalSignature || settings.signatureUrl || settings.signaturePath || settings.signature}
                      alt="Principal Signature"
                      className="relative z-10 w-auto object-contain"
                      style={{
                        height: `${Math.round(32 * (Number(settings.signatureScale) || 1.0))}px`,
                        maxWidth: `${Math.round(110 * (Number(settings.signatureScale) || 1.0))}px`
                      }}
                      onError={(e) => { e.currentTarget.style.display = 'none'; }}
                    />
                  )}
                </div>
                <div className="w-28 border-t border-slate-900 pt-0.5 text-center">
                  <div className="font-bold text-slate-900 tracking-tight text-[11px]">
                    Principal Sign
                  </div>
                </div>
              </div>
            </div>

            <hr className="border-t border-black/80" />

            {/* Rules */}
            <div className="space-y-0.5 text-[9.5px] text-slate-700 leading-tight">
              <div className="font-bold text-black text-[10px]">Rules:-</div>
              <p>1. Last date of fee is {dueDay}th of the month</p>
              <p>2. A fine of Rs {lateFinePerDay}/- per day will be charged if the dues are paid after the due date</p>
            </div>

          </div>
        </div>

      </div>
    </div>
  );
}
