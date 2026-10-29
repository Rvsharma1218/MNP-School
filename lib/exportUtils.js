import * as XLSX from 'xlsx';
import { jsPDF } from 'jspdf';

// ─── Helper: Get Base64 Image Data URL for jsPDF ──────────────────────────────
export function getImageDataUrl(src) {
  return new Promise((resolve) => {
    if (!src || typeof window === 'undefined') return resolve(null);
    if (typeof src === 'string' && (src.startsWith('data:image/png') || src.startsWith('data:image/jpeg') || src.startsWith('data:image/jpg') || src.startsWith('data:image/webp'))) {
      return resolve(src);
    }
    const img = new Image();
    img.crossOrigin = 'anonymous';
    img.onload = () => {
      try {
        const canvas = document.createElement('canvas');
        canvas.width = img.naturalWidth || img.width || 200;
        canvas.height = img.naturalHeight || img.height || 200;
        const ctx = canvas.getContext('2d');
        if (!ctx) return resolve(null);
        ctx.drawImage(img, 0, 0);
        resolve(canvas.toDataURL('image/png'));
      } catch (e) {
        resolve(typeof src === 'string' && src.startsWith('data:') ? src : null);
      }
    };
    img.onerror = () => {
      resolve(typeof src === 'string' && src.startsWith('data:') ? src : null);
    };
    img.src = src;
  });
}

// ─── Helper: Generate Individual Fee Receipt jsPDF Document ───────────────
export async function createReceiptPDFDoc(payment, student, settings = {}, allPayments = []) {
  const doc = new jsPDF({ format: 'a5', unit: 'mm' });
  const W = 148, H = 210, M = 8;
  const contentW = W - 2 * M;

  const logoSrc = settings.logoUrl || settings.logoPath || settings.logo;
  const sigSrc = settings.principalSignature || settings.signatureUrl || settings.signaturePath || settings.signature;
  const stampSrc = settings.schoolStamp || settings.stampUrl || settings.sealUrl;
  const [logoData, sigData, stampData] = await Promise.all([
    getImageDataUrl(logoSrc),
    getImageDataUrl(sigSrc),
    getImageDataUrl(stampSrc)
  ]);

  // Outer Border Box
  doc.setDrawColor(0, 0, 0);
  doc.setLineWidth(0.4);
  doc.rect(M, M, contentW, H - 2 * M);

  let y = M + 4;

  if (logoData) {
    try {
      doc.addImage(logoData, 'PNG', W / 2 - 8, y, 16, 10);
      y += 11;
    } catch (e) {
      console.warn('Failed to embed logo in PDF:', e);
    }
  }

  // Header
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(8);
  doc.setTextColor(30, 30, 30);
  doc.text('OFFICIAL FEE RECEIPT VOUCHER', W / 2, y, { align: 'center' });
  y += 4.5;

  doc.setFontSize(11);
  doc.text((settings.instituteName || 'MY SCHOOL & COMPUTER INSTITUTE').toUpperCase(), W / 2, y, { align: 'center' });
  y += 4;

  doc.setFont('helvetica', 'normal');
  doc.setFontSize(7);
  doc.text(`Add- ${settings.address || 'Siwan, Bihar'}`, W / 2, y, { align: 'center' });
  y += 3.5;
  doc.text(`Mob- ${settings.mobile || '9876543210'}`, W / 2, y, { align: 'center' });
  y += 3;

  // Divider Line
  doc.setLineWidth(0.3);
  doc.line(M, y, W - M, y);
  y += 4.5;

  // Meta details
  const payDateObj = payment.paymentDate ? new Date(payment.paymentDate) : new Date();
  const paymentDate = isNaN(payDateObj.getTime()) ? new Date() : payDateObj;
  const dateFormatted = paymentDate.toLocaleDateString('en-GB', { day: '2-digit', month: '2-digit', year: 'numeric' });
  const timeFormatted = paymentDate.toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit', hour12: true });

  const monthKey = payment.monthKey || `${paymentDate.getFullYear()}-${String(paymentDate.getMonth() + 1).padStart(2, '0')}`;
  // Use particularsSnapshot from payment if available (live at time of payment), else fall back to student.monthlyParticulars
  const mp = payment.particularsSnapshot || student.monthlyParticulars?.[monthKey] || {};

  doc.setFontSize(7.5);
  // Row 1: Receipt No & Date
  doc.setFont('helvetica', 'normal');
  doc.text('Receipt No: ', M + 4, y);
  doc.setFont('helvetica', 'bold');
  doc.text(payment.receiptNumber || 'REC000001', M + 20, y);

  doc.setFont('helvetica', 'normal');
  doc.text('Payment Date: ', W - M - 48, y);
  doc.setFont('helvetica', 'bold');
  doc.text(`${dateFormatted} ${timeFormatted}`, W - M - 4, y, { align: 'right' });
  y += 4.5;

  // Row 2: Student Name & System ID
  doc.setFont('helvetica', 'normal');
  doc.text("Student's Name:", M + 4, y);
  doc.setFont('helvetica', 'bold');
  doc.text((student.name || '').toUpperCase(), M + 26, y);

  doc.setFont('helvetica', 'normal');
  doc.text('Student ID: ', W - M - 48, y);
  doc.setFont('helvetica', 'bold');
  doc.text(student.studentId || '-', W - M - 4, y, { align: 'right' });
  y += 4.5;

  // Row 3: Admission No & Father's Name
  doc.setFont('helvetica', 'normal');
  doc.text('Admission No: ', M + 4, y);
  doc.setFont('helvetica', 'bold');
  doc.text(student.admissionNumber || '-', M + 24, y);

  doc.setFont('helvetica', 'normal');
  doc.text("Father's Name: ", W - M - 48, y);
  doc.setFont('helvetica', 'bold');
  doc.text(student.fatherName || '-', W - M - 4, y, { align: 'right' });
  y += 4.5;

  // Row 4: Class/Course & Roll No
  const classStr = student.studentType === 'school' ? `Class ${student.className || ''} - ${student.section || 'A'}` : (student.course || 'ADCA');
  doc.setFont('helvetica', 'normal');
  doc.text('Class / Course: ', M + 4, y);
  doc.setFont('helvetica', 'bold');
  doc.text(classStr, M + 24, y);

  doc.setFont('helvetica', 'normal');
  doc.text('Roll No: ', W - M - 48, y);
  doc.setFont('helvetica', 'bold');
  doc.text(student.rollNumber || '-', W - M - 4, y, { align: 'right' });
  y += 4.5;

  // Row 5: Fee Month & Payment Mode
  doc.setFont('helvetica', 'normal');
  doc.text('Fees For Period: ', M + 4, y);
  doc.setFont('helvetica', 'bold');
  doc.text(payment.feeMonth || 'Monthly Tuition Fee', M + 25, y);

  doc.setFont('helvetica', 'normal');
  doc.text('Payment Mode: ', W - M - 48, y);
  doc.setFont('helvetica', 'bold');
  doc.text(payment.paymentMode || 'Cash', W - M - 4, y, { align: 'right' });
  y += 5;

  // 13 Particulars Table
  const tableX = M + 3;
  const tableW = contentW - 6;
  const colSN = 9;
  const colAmt = 22;
  const colP = 7;
  const colPart = tableW - colSN - colAmt - colP;

  // Table Header
  doc.setFillColor(245, 245, 245);
  doc.rect(tableX, y, tableW, 4.5, 'FD');
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(7);
  doc.text('S.N.', tableX + colSN / 2, y + 3.2, { align: 'center' });
  doc.text('Particulars', tableX + colSN + 2, y + 3.2);
  doc.text('Amount (Rs)', tableX + colSN + colPart + colAmt - 2, y + 3.2, { align: 'right' });
  doc.text('P.', tableX + colSN + colPart + colAmt + colP / 2, y + 3.2, { align: 'center' });

  // Column vertical gridlines
  doc.line(tableX + colSN, y, tableX + colSN, y + 4.5);
  doc.line(tableX + colSN + colPart, y, tableX + colSN + colPart, y + 4.5);
  doc.line(tableX + colSN + colPart + colAmt, y, tableX + colSN + colPart + colAmt, y + 4.5);
  y += 4.5;

  const standardTuition = Number(student.feeStructure?.tuitionFee) > 0
    ? Number(student.feeStructure.tuitionFee)
    : (Number(student.monthlyFee) > 0 ? Number(student.monthlyFee) : 0);

  const resolvedTuition = (mp.tuitionFee !== undefined && Number(mp.tuitionFee) > 0)
    ? Number(mp.tuitionFee)
    : (standardTuition > 0 ? standardTuition : (Number(payment.totalMonthDemand) || Number(payment.amount) || 0));

  const resolvedPrevDue = (mp.previousDues !== undefined && Number(mp.previousDues) > 0)
    ? Number(mp.previousDues)
    : (Number(payment.previousDue) || Number(student.previousDue) || 0);

  const items = [
    { sn: '1', label: 'Admission Fee', amt: mp.admissionFee || 0 },
    { sn: '2', label: 'Tuition Fee', amt: resolvedTuition },
    { sn: '3', label: 'Examination Fee', amt: mp.examinationFee || 0 },
    { sn: '4', label: 'Previous Dues', amt: resolvedPrevDue },
    { sn: '5', label: 'Game Fee', amt: mp.gameFee || 0 },
    { sn: '6', label: 'Re-Admission Fee', amt: mp.reAdmissionFee || 0 },
    { sn: '7', label: 'Development Fee', amt: mp.developmentFee || 0 },
    { sn: '8', label: 'School ID', amt: mp.schoolId || 0 },
    { sn: '9', label: 'Tie, Bag, Belt', amt: mp.tieBagBelt || 0 },
    { sn: '10', label: 'Back Dues', amt: mp.backDues || 0 },
    { sn: '11', label: 'Transport Fee', amt: mp.transportFee || 0 },
    { sn: '12', label: 'Other Fee', amt: mp.otherFee || 0 },
    { sn: '★', label: 'Late Fine', amt: mp.lateFine || 0, isLate: true },
  ];

  const totalCalculated = items.reduce((acc, p) => acc + (Number(p.amt) || 0), 0);

  // Use stored payment-time values if available; else calculate live
  const amountPaid = Number(payment.amount || 0);
  const totalAmount = Number(payment.totalMonthDemand) || (totalCalculated > 0 ? totalCalculated : amountPaid);

  // Find prior payment
  const studentPayments = (allPayments || []).filter(
    p => (p.studentId === student.id || (student.studentId && p.studentId === student.studentId)) && p.id !== payment.id
  );
  studentPayments.sort((a, b) => new Date(b.paymentDate || 0) - new Date(a.paymentDate || 0));
  const lastPriorPayment = studentPayments[0];

  const isSameMonthPrior = lastPriorPayment && (
    (lastPriorPayment.feeMonth && payment.feeMonth && lastPriorPayment.feeMonth === payment.feeMonth) ||
    (lastPriorPayment.monthKey && payment.monthKey && lastPriorPayment.monthKey === payment.monthKey)
  );

  const previousPaid = payment.previousPaid !== undefined && Number(payment.previousPaid) > 0
    ? Number(payment.previousPaid)
    : (isSameMonthPrior && lastPriorPayment ? Number(lastPriorPayment.amount) : 0);

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

  const totalPaidAfter = Number(payment.totalPaidAfter) || (previousPaid + amountPaid);
  const balanceDue = Number(payment.balanceDue) !== undefined ? Number(payment.balanceDue) : Math.max(0, totalAmount - totalPaidAfter);

  const rowH = 4;
  items.forEach((item) => {
    doc.rect(tableX, y, tableW, rowH);
    doc.line(tableX + colSN, y, tableX + colSN, y + rowH);
    doc.line(tableX + colSN + colPart, y, tableX + colSN + colPart, y + rowH);
    doc.line(tableX + colSN + colPart + colAmt, y, tableX + colSN + colPart + colAmt, y + rowH);

    doc.setFont('helvetica', item.isLate ? 'bold' : 'normal');
    doc.setFontSize(6.5);
    doc.text(item.sn, tableX + colSN / 2, y + 2.8, { align: 'center' });
    doc.text(item.label, tableX + colSN + 2, y + 2.8);
    if (item.amt > 0) {
      doc.text(Number(item.amt).toFixed(2), tableX + colSN + colPart + colAmt - 2, y + 2.8, { align: 'right' });
      doc.text('00', tableX + colSN + colPart + colAmt + colP / 2, y + 2.8, { align: 'center' });
    }
    y += rowH;
  });

  // Summary Rows (Multi-payment & Full Paid Breakdown)
  const summaryRows = [
    { label: 'Total Fee Demand', amt: totalAmount },
    ...(previousPaid > 0 ? [{
      label: `Previous Payment ${lastPaymentDateFormatted ? `(Last Paid: ${lastPaymentDateFormatted})` : ''}`,
      amt: previousPaid,
      isPrevious: true
    }] : []),
    { label: 'Current Payment (Paid Now)', amt: amountPaid, isHighlight: true },
    ...(previousPaid > 0 ? [{
      label: 'Total Amount Paid',
      amt: totalPaidAfter,
      isTotalPaid: true
    }] : []),
    {
      label: balanceDue <= 0 ? 'Remaining Balance (FULL PAID)' : 'Pending Balance Due',
      amt: balanceDue,
      isPending: balanceDue > 0,
      isFullPaid: balanceDue <= 0
    }
  ];

  summaryRows.forEach((row, i) => {
    if (row.isHighlight) doc.setFillColor(235, 248, 235);
    else if (row.isPending && row.amt > 0) doc.setFillColor(254, 242, 242);
    else if (row.isFullPaid) doc.setFillColor(235, 248, 235);
    else if (row.isPrevious && row.amt > 0) doc.setFillColor(255, 251, 235);
    else if (row.isTotalPaid) doc.setFillColor(240, 248, 255);
    else if (i === 0) doc.setFillColor(240, 240, 240);

    const fill = row.isHighlight || (row.isPending && row.amt > 0) || row.isFullPaid || (row.isPrevious && row.amt > 0) || row.isTotalPaid || i === 0;
    doc.rect(tableX, y, tableW, rowH, fill ? 'FD' : 'D');
    doc.line(tableX + colSN + colPart, y, tableX + colSN + colPart, y + rowH);
    doc.line(tableX + colSN + colPart + colAmt, y, tableX + colSN + colPart + colAmt, y + rowH);

    doc.setFont('helvetica', 'bold');
    doc.setFontSize(6.5);
    if (row.isPending && row.amt > 0) doc.setTextColor(180, 30, 30);
    else if (row.isFullPaid) doc.setTextColor(30, 120, 40);
    else if (row.isPrevious && row.amt > 0) doc.setTextColor(160, 100, 0);
    else if (row.isTotalPaid) doc.setTextColor(20, 60, 140);
    else doc.setTextColor(30, 30, 30);

    doc.text(row.label, tableX + colSN + colPart - 2, y + 2.8, { align: 'right' });
    doc.text(Number(row.amt).toFixed(2), tableX + colSN + colPart + colAmt - 2, y + 2.8, { align: 'right' });
    doc.text('00', tableX + colSN + colPart + colAmt + colP / 2, y + 2.8, { align: 'center' });
    doc.setTextColor(0, 0, 0);
    y += rowH;
  });

  y += 4;

  // Number to Words
  function toWords(num) {
    const a = ['', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine', 'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen'];
    const b = ['', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'];
    const n = Math.floor(num || 0);
    if (n === 0) return 'Zero';
    if (n < 20) return a[n];
    if (n < 100) return b[Math.floor(n / 10)] + ' ' + a[n % 10];
    if (n < 1000) return a[Math.floor(n / 100)] + ' Hundred ' + toWords(n % 100);
    if (n < 100000) return toWords(Math.floor(n / 1000)) + ' Thousand ' + toWords(n % 1000);
    if (n < 10000000) return toWords(Math.floor(n / 100000)) + ' Lakh ' + toWords(n % 100000);
    return 'Rupees';
  }

  doc.setFont('helvetica', 'bold');
  doc.setFontSize(7.5);
  doc.text('Amount in Words: ', M + 4, y);
  doc.setFont('helvetica', 'normal');
  doc.text(`${toWords(amountPaid).trim()} Rupees Only`, M + 28, y);
  y += 3.5;

  doc.line(M, y, W - M, y);
  y += 3.5;

  // Paid / Partial Payment Stamp Badge
  const isFullPaid = balanceDue <= 0;
  doc.setDrawColor(isFullPaid ? 46 : 185, isFullPaid ? 125 : 28, isFullPaid ? 50 : 28);
  doc.setFillColor(isFullPaid ? 240 : 255, isFullPaid ? 248 : 235, isFullPaid ? 235 : 238);
  doc.roundedRect(W / 2 - 45, y, 90, 5.5, 1, 1, 'FD');
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(6.8);
  doc.setTextColor(isFullPaid ? 46 : 185, isFullPaid ? 125 : 28, isFullPaid ? 50 : 28);
  const paidDateLong = paymentDate.toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric' });
  const badgeText = isFullPaid
    ? `FULL PAID: Rs. ${totalPaidAfter.toLocaleString('en-IN')} Cleared (Paid: Rs. ${amountPaid.toLocaleString('en-IN')} on ${paidDateLong} via ${payment.paymentMode || 'Cash'})`
    : `PARTIAL PAYMENT: Rs. ${amountPaid.toLocaleString('en-IN')} Received | Balance Due: Rs. ${balanceDue.toLocaleString('en-IN')} (${paidDateLong} via ${payment.paymentMode || 'Cash'})`;
  doc.text(badgeText, W / 2, y + 3.8, { align: 'center' });
  y += 8;

  // Signatures & Stamp
  doc.setTextColor(0, 0, 0);
  doc.setFont('helvetica', 'normal');
  doc.setFontSize(7);
  doc.line(M + 4, y + 1, M + 44, y + 1);
  doc.text('Cashier / Accountant Sign.', M + 24, y + 4.5, { align: 'center' });

  const rightCenterX = W - M - 24;

  const stampScale = Number(settings.stampScale) || 1.0;
  const sigScale = Number(settings.signatureScale) || 1.0;
  const sSize = 18 * stampScale;
  const sW = 28 * sigScale;
  const sH = 9.5 * sigScale;

  // In the app (receipt_pdf_service.dart:580), Stamp & Signature sit in a unified stack entirely ABOVE the line
  const stampY = y - sSize - 0.5;
  const sigY = y - sH - 0.5;

  // Stamp (Mohar) centered at signature area above line
  if (stampData) {
    try {
      doc.addImage(stampData, 'PNG', rightCenterX - sSize / 2, stampY, sSize, sSize);
    } catch (e) {
      console.warn('Failed to embed stamp in PDF:', e);
    }
  }

  // Signature layered naturally inside / over the stamp
  if (sigData) {
    try {
      doc.addImage(sigData, 'PNG', rightCenterX - sW / 2, sigY, sW, sH);
    } catch (e) {
      console.warn('Failed to embed signature in PDF:', e);
    }
  }

  doc.line(rightCenterX - 20, y + 1, rightCenterX + 20, y + 1);
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(7.5);
  doc.text('Principal Sign', rightCenterX, y + 4.5, { align: 'center' });
  y += 9;

  doc.line(M, y, W - M, y);
  y += 3.5;

  // Rules
  const dueDay = student.feeStructure?.dueDay || 10;
  const lateFinePerDay = student.feeStructure?.lateFinePerDay || 5;

  doc.setFont('helvetica', 'bold');
  doc.setFontSize(7);
  doc.text('Terms & Conditions:-', M + 4, y);
  y += 3;
  doc.setFont('helvetica', 'normal');
  doc.setFontSize(6.5);
  doc.text(`1. Fees once deposited will not be refunded under any circumstances.`, M + 4, y);
  y += 2.8;
  doc.text(`2. Monthly fee must be cleared on or before ${dueDay}th of each month. Late fine: Rs. ${lateFinePerDay}/day.`, M + 4, y);

  return doc;
}

// ─── PDF: Individual Fee Receipt (Exact School Voucher Design) ───────────────
export async function exportReceiptPDF(payment, student, settings = {}, allPayments = []) {
  try {
    const doc = await createReceiptPDFDoc(payment, student, settings, allPayments);
    doc.save(`Receipt_${payment.receiptNumber || 'receipt'}.pdf`);
  } catch (err) {
    console.error("PDF generation error:", err);
  }
}

// ─── PDF: Fee Structure (Class-wise) ─────────────────────────────────────────
export function exportFeeStructurePDF(students, settings) {
  const doc = new jsPDF({ format: 'a4', unit: 'mm' });
  const W = 210, M = 15;

  doc.setFillColor(26, 35, 126); doc.rect(0, 0, W, 28, 'F');
  doc.setTextColor(255, 215, 0); doc.setFontSize(16); doc.setFont('helvetica', 'bold');
  doc.text(settings.instituteName || 'School Manager', W / 2, 12, { align: 'center' });
  doc.setFontSize(9); doc.setFont('helvetica', 'normal'); doc.setTextColor(200, 210, 255);
  doc.text('FEE STRUCTURE REPORT — ' + (settings.currentSession || new Date().getFullYear()), W / 2, 19, { align: 'center' });
  doc.text('Generated: ' + new Date().toLocaleDateString('en-IN'), W / 2, 25, { align: 'center' });

  // Group by class
  const groups = {};
  students.forEach(s => {
    const key = s.studentType === 'school' ? `Class ${s.className || 'Other'}` : (s.course || 'Other');
    if (!groups[key]) groups[key] = [];
    groups[key].push(s);
  });

  let y = 36;
  Object.entries(groups).sort().forEach(([cls, studs]) => {
    const total = studs.reduce((a, s) => a + (s.totalFees || 0), 0);
    const paid = studs.reduce((a, s) => a + (s.paidFees || 0), 0);
    const pending = total - paid;

    doc.setFillColor(240, 243, 255); doc.roundedRect(M, y, W - 2 * M, 10, 2, 2, 'F');
    doc.setFont('helvetica', 'bold'); doc.setFontSize(10); doc.setTextColor(26, 35, 126);
    doc.text(cls, M + 4, y + 7);
    doc.setFontSize(8.5); doc.setTextColor(60, 60, 80);
    doc.text(`${studs.length} Students`, W - M - 4, y + 7, { align: 'right' });
    y += 12;

    doc.setFont('helvetica', 'normal'); doc.setFontSize(8.5); doc.setTextColor(40, 40, 60);
    [
      [`Total Fee Expected:`, `Rs. ${total.toLocaleString('en-IN')}`],
      [`Total Fee Collected:`, `Rs. ${paid.toLocaleString('en-IN')}`],
      [`Total Pending:`, `Rs. ${pending.toLocaleString('en-IN')}`],
    ].forEach(([lbl, val]) => {
      doc.text(lbl, M + 6, y); doc.text(val, W - M - 4, y, { align: 'right' });
      y += 6;
    });
    y += 4;
    if (y > 265) { doc.addPage(); y = 20; }
  });

  // Grand total
  doc.setFillColor(26, 35, 126); doc.roundedRect(M, y, W - 2 * M, 14, 2, 2, 'F');
  doc.setFont('helvetica', 'bold'); doc.setFontSize(10); doc.setTextColor(255, 255, 255);
  const gt = students.reduce((a, s) => a + (s.totalFees || 0), 0);
  const gp = students.reduce((a, s) => a + (s.paidFees || 0), 0);
  doc.text(`GRAND TOTAL — Expected: Rs. ${gt.toLocaleString('en-IN')}  |  Collected: Rs. ${gp.toLocaleString('en-IN')}  |  Pending: Rs. ${(gt - gp).toLocaleString('en-IN')}`, W / 2, y + 9, { align: 'center' });

  doc.save(`FeeStructure_${settings.currentSession || 'report'}.pdf`);
}

// ─── PDF: Full Student List ───────────────────────────────────────────────────
export function exportStudentsPDF(students, settings) {
  const doc = new jsPDF({ orientation: 'landscape', format: 'a4', unit: 'mm' });
  const W = 297, M = 10;

  doc.setFillColor(26, 35, 126); doc.rect(0, 0, W, 20, 'F');
  doc.setTextColor(255, 215, 0); doc.setFontSize(13); doc.setFont('helvetica', 'bold');
  doc.text(`${settings.instituteName || 'School'} — Student Master List`, W / 2, 8, { align: 'center' });
  doc.setFontSize(8); doc.setFont('helvetica', 'normal'); doc.setTextColor(200, 210, 255);
  doc.text(`Session: ${settings.currentSession || ''} | Total: ${students.length} | Generated: ${new Date().toLocaleDateString('en-IN')}`, W / 2, 15, { align: 'center' });

  const headers = ['#', 'ID', 'Name', 'Father', 'Class/Course', 'Mobile', 'Total Fee', 'Paid', 'Pending', 'Status'];
  const colW = [8, 18, 42, 38, 28, 28, 22, 18, 22, 18];
  let y = 25;

  doc.setFillColor(240, 243, 255); doc.rect(M, y, W - 2 * M, 8, 'F');
  doc.setFont('helvetica', 'bold'); doc.setFontSize(7.5); doc.setTextColor(26, 35, 126);
  let x = M + 2;
  headers.forEach((h, i) => { doc.text(h, x, y + 5.5); x += colW[i]; });
  y += 9;

  doc.setFont('helvetica', 'normal'); doc.setFontSize(7); doc.setTextColor(30, 30, 50);
  students.forEach((s, idx) => {
    if (y > 188) { doc.addPage(); y = 15; }
    const pending = Math.max(0, (s.totalFees || 0) - (s.paidFees || 0));
    const row = [
      String(idx + 1), s.studentId || '', s.name || '', s.fatherName || '',
      s.studentType === 'school' ? `Cls ${s.className || ''}${s.section ? '-' + s.section : ''}` : (s.course || ''),
      s.mobile || '',
      `Rs.${(s.totalFees || 0).toLocaleString('en-IN')}`,
      `Rs.${(s.paidFees || 0).toLocaleString('en-IN')}`,
      `Rs.${pending.toLocaleString('en-IN')}`,
      (s.status || 'Active').toUpperCase()
    ];
    if (idx % 2 === 0) { doc.setFillColor(248, 249, 255); doc.rect(M, y - 1, W - 2 * M, 7, 'F'); }
    x = M + 2;
    if (pending > 0) doc.setTextColor(180, 30, 30); else doc.setTextColor(30, 30, 50);
    row.forEach((v, i) => {
      if (i !== row.length - 1 && i !== row.length - 2) doc.setTextColor(30, 30, 50);
      doc.text(String(v).substring(0, 20), x, y + 4.5); x += colW[i];
    });
    y += 7;
  });

  doc.save(`Students_${settings.instituteName?.replace(/[^a-zA-Z0-9]/g, '_') || 'list'}_${new Date().toISOString().split('T')[0]}.pdf`);
}

// ─── EXCEL IMPORT: Parse uploaded Excel → student objects ────────────────────
export function importStudentsFromExcel(file) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = (e) => {
      try {
        const wb = XLSX.read(e.target.result, { type: 'array' });
        const ws = wb.Sheets[wb.SheetNames[0]];
        const rows = XLSX.utils.sheet_to_json(ws, { defval: '' });
        // Filter out example/header rows (from App's 31-col template)
        const dataRows = rows.filter(r => {
          const first = String(Object.values(r)[0] || '').toLowerCase();
          return !first.includes('example') && !first.includes('basic information') && !first.includes('start entering');
        });
        const students = dataRows.map((r, idx) => ({
          // Name — supports both simple and App 31-col headers
          name: r['Full Name'] || r['Student Name'] || r['Name'] || '',
          fatherName: r["Father's Name"] || r['Father Name'] || r['Father'] || '',
          motherName: r["Mother's Name"] || r['Mother Name'] || r['Mother'] || '',
          mobile: String(r['Mobile'] || r['Mobile Number'] || r['Phone'] || ''),
          alternateMobile: String(r['WhatsApp'] || r['Alternate Mobile'] || r['Alt Mobile'] || r['Alt. Mobile'] || ''),
          gender: r['Gender'] || '',
          dob: r['DOB'] || r['Date of Birth'] || r['Birth Date'] || '',
          address: r['Address'] || '',
          // Student type — recognizes 'Computer Institute' from App export
          studentType: (String(r['Type'] || r['Student Type'] || '').toLowerCase().includes('computer')) ? 'computer' : 'school',
          // Class/Course
          className: r['Class'] || r['Class / Course'] || r['Class/Course'] || '',
          section: r['Section'] || r['Section/Batch'] || '',
          course: r['Course'] || '',
          batch: r['Batch'] || r['Roll / Batch'] || r['Section/Batch'] || '',
          rollNumber: String(r['Roll No'] || r['Roll Number'] || r['Roll / Batch'] || ''),
          // Admission
          admissionNumber: r['Admission No'] || r['Admission Number'] || r['Adm No'] || '',
          studentId: r['Student ID'] || r['Student Id'] || '',
          admissionDate: r['Admission Date'] || '',
          session: r['Session'] || r['Academic Session'] || '',
          status: (r['Status'] || 'active').toLowerCase(),
          // Fees
          totalFees: Number(r['Total Fees (₹)'] || r['Total Fees'] || r['Total Fee'] || 0),
          paidFees: Number(r['Paid Fees (₹)'] || r['Paid Fees'] || r['Paid Fee'] || 0),
        })).filter(s => s.name.trim() !== '');
        resolve(students);
      } catch (err) { reject(err); }
    };
    reader.onerror = reject;
    reader.readAsArrayBuffer(file);
  });
}



/**
 * Export student list to Excel (.xlsx)
 */
export function exportStudentsToExcel(students, instituteName = 'Institute') {
  const data = students.map((s, idx) => ({
    'S.No': idx + 1,
    'Student ID': s.studentId || '',
    'Admission No': s.admissionNumber || '',
    'Full Name': s.name || '',
    'Father Name': s.fatherName || '',
    'Mother Name': s.motherName || '',
    'Type': s.studentType === 'school' ? 'School' : 'Computer Institute',
    'Class / Course': s.studentType === 'school' ? (s.className ? `Class ${s.className}${s.section ? ` - ${s.section}` : ''}` : '') : (s.course || ''),
    'Roll / Batch': s.studentType === 'school' ? (s.rollNumber || '') : (s.batch || ''),
    'Mobile': s.mobile || '',
    'WhatsApp': s.alternateMobile || s.mobile || '',
    'Gender': s.gender || '',
    'DOB': s.dob || '',
    'Total Fees (₹)': s.totalFees || 0,
    'Paid Fees (₹)': s.paidFees || 0,
    'Pending Fees (₹)': Math.max(0, (s.totalFees || 0) - (s.paidFees || 0)),
    'Status': s.status?.toUpperCase() || 'ACTIVE',
    'Admission Date': s.admissionDate || '',
    'Address': s.address || ''
  }));

  const worksheet = XLSX.utils.json_to_sheet(data);
  const workbook = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(workbook, worksheet, 'Students');

  // Auto-fit column widths
  const max_width = data.reduce((w, r) => Math.max(w, 20), 10);
  worksheet['!cols'] = Object.keys(data[0] || {}).map(() => ({ wch: 18 }));

  const dateStr = new Date().toISOString().split('T')[0];
  XLSX.writeFile(workbook, `${instituteName.replace(/[^a-zA-Z0-9]/g, '_')}_Students_${dateStr}.xlsx`);
}

/**
 * Export payments history / ledger to Excel
 */
export function exportPaymentsToExcel(payments, instituteName = 'Institute') {
  const data = payments.map((p, idx) => ({
    'S.No': idx + 1,
    'Receipt No': p.receiptNumber || '',
    'Student Name': p.studentName || '',
    'Amount (₹)': p.amount || 0,
    'Payment Mode': p.paymentMode || 'Cash',
    'Date': p.paymentDate ? new Date(p.paymentDate).toLocaleDateString() : '',
    'Fee Month / Term': p.feeMonth || '',
    'Remarks': p.remarks || ''
  }));

  const worksheet = XLSX.utils.json_to_sheet(data);
  const workbook = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(workbook, worksheet, 'Fee Ledger');
  worksheet['!cols'] = Object.keys(data[0] || {}).map(() => ({ wch: 18 }));

  const dateStr = new Date().toISOString().split('T')[0];
  XLSX.writeFile(workbook, `${instituteName.replace(/[^a-zA-Z0-9]/g, '_')}_Fee_Ledger_${dateStr}.xlsx`);
}

/**
 * Export Pending Fees / Defaulters List to Excel
 */
export function exportDefaultersToExcel(students, instituteName = 'Institute') {
  const defaulters = students
    .filter(s => ((s.totalFees || 0) - (s.paidFees || 0)) > 0)
    .map((s, idx) => {
      const pending = (s.totalFees || 0) - (s.paidFees || 0);
      return {
        'S.No': idx + 1,
        'Student ID': s.studentId || '',
        'Name': s.name || '',
        'Father Name': s.fatherName || '',
        'Class / Course': s.studentType === 'school' ? `Class ${s.className || ''}` : (s.course || ''),
        'Mobile': s.mobile || '',
        'Total Fees (₹)': s.totalFees || 0,
        'Paid Fees (₹)': s.paidFees || 0,
        'Pending Dues (₹)': pending,
        'Due Date': s.dueDate || 'N/A',
        'Status': s.status?.toUpperCase() || 'ACTIVE'
      };
    });

  const worksheet = XLSX.utils.json_to_sheet(defaulters);
  const workbook = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(workbook, worksheet, 'Defaulters List');
  worksheet['!cols'] = Object.keys(defaulters[0] || {}).map(() => ({ wch: 18 }));

  const dateStr = new Date().toISOString().split('T')[0];
  XLSX.writeFile(workbook, `${instituteName.replace(/[^a-zA-Z0-9]/g, '_')}_Fee_Defaulters_${dateStr}.xlsx`);
}

/**
 * Export Attendance Report to Excel
 */
export function exportAttendanceToExcel(students, attendance, dateStr, instituteName = 'Institute') {
  const dayRecords = attendance[dateStr] || {};
  const data = students.map((s, idx) => ({
    'S.No': idx + 1,
    'Student ID': s.studentId || '',
    'Roll No': s.rollNumber || '',
    'Name': s.name || '',
    'Father Name': s.fatherName || '',
    'Class / Course': s.studentType === 'school' ? `Class ${s.className || ''}` : (s.course || ''),
    'Date': dateStr,
    'Status': (dayRecords[s.id] || 'unmarked').toUpperCase(),
    'Mobile': s.mobile || ''
  }));

  const worksheet = XLSX.utils.json_to_sheet(data);
  const workbook = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(workbook, worksheet, `Attendance_${dateStr}`);
  worksheet['!cols'] = Object.keys(data[0] || {}).map(() => ({ wch: 18 }));

  XLSX.writeFile(workbook, `${instituteName.replace(/[^a-zA-Z0-9]/g, '_')}_Attendance_${dateStr}.xlsx`);
}

/**
 * Helper to clean and format Indian WhatsApp numbers
 */
export function cleanWhatsAppNumber(phone) {
  if (!phone) return '';
  let clean = String(phone).replace(/[^0-9]/g, '');
  clean = clean.replace(/^0+/, ''); // Remove leading zeros (e.g. 09876543210 -> 9876543210)
  if (clean.length === 10) return `91${clean}`;
  if (clean.length === 12 && clean.startsWith('91')) return clean;
  return clean;
}

/**
 * Generate WhatsApp Fee Receipt Voucher Share (Opens direct chat with student's number & auto-downloads PDF)
 */
export async function openWhatsAppReceiptShare(payment, student, settings = {}, allPayments = []) {
  let mobile = student?.alternateMobile || student?.mobile || student?.phone || student?.contactNumber || student?.parentMobile || student?.fatherMobile || payment?.mobile || payment?.phone || payment?.alternateMobile;
  let finalMobile = cleanWhatsAppNumber(mobile);

  if (!finalMobile && typeof window !== 'undefined') {
    const inputNumber = window.prompt(
      `⚠️ WhatsApp Number Not Found for ${student?.name || payment?.studentName || 'Student'}!\n\nEnter 10-digit mobile number to share receipt on WhatsApp:`
    );
    if (!inputNumber) {
      return; // User cancelled
    }
    finalMobile = cleanWhatsAppNumber(inputNumber);
  }

  // Find prior payment
  const studentPayments = (allPayments || []).filter(
    p => (p.studentId === student?.id || (student?.studentId && p.studentId === student.studentId)) && p.id !== payment.id
  );
  studentPayments.sort((a, b) => new Date(b.paymentDate || 0) - new Date(a.paymentDate || 0));
  const lastPriorPayment = studentPayments[0];

  const isSameMonthPrior = lastPriorPayment && (
    (lastPriorPayment.feeMonth && payment?.feeMonth && lastPriorPayment.feeMonth === payment.feeMonth) ||
    (lastPriorPayment.monthKey && payment?.monthKey && lastPriorPayment.monthKey === payment.monthKey)
  );

  const amountPaid = Number(payment.amount || 0);
  const previousPaid = payment.previousPaid !== undefined && Number(payment.previousPaid) > 0
    ? Number(payment.previousPaid)
    : (isSameMonthPrior && lastPriorPayment ? Number(lastPriorPayment.amount) : 0);

  let lastPaymentDateFormatted = '';
  if (payment.lastPaidDate) {
    const d = new Date(payment.lastPaidDate);
    if (!isNaN(d.getTime())) lastPaymentDateFormatted = d.toLocaleDateString('en-GB', { day: '2-digit', month: '2-digit', year: 'numeric' });
  } else if (lastPriorPayment?.paymentDate) {
    const d = new Date(lastPriorPayment.paymentDate);
    if (!isNaN(d.getTime())) lastPaymentDateFormatted = d.toLocaleDateString('en-GB', { day: '2-digit', month: '2-digit', year: 'numeric' });
  } else if (student?.lastPaidDate) {
    const d = new Date(student.lastPaidDate);
    if (!isNaN(d.getTime())) lastPaymentDateFormatted = d.toLocaleDateString('en-GB', { day: '2-digit', month: '2-digit', year: 'numeric' });
  }

  const standardMonthlyFee = Number(student?.feeStructure?.tuitionFee) > 0
    ? Number(student.feeStructure.tuitionFee)
    : (Number(student?.monthlyFee) > 0 ? Number(student.monthlyFee) : 0);
  const totalDemand = Number(payment.totalMonthDemand) || Number(payment.totalDemand) || Number(payment.totalDue) || (standardMonthlyFee > 0 ? standardMonthlyFee : (previousPaid + amountPaid));
  const totalPaidAfter = payment.totalPaidAfter !== undefined ? Number(payment.totalPaidAfter) : (previousPaid + amountPaid);
  const balanceDue = payment.balanceDue !== undefined && payment.balanceDue !== null ? Number(payment.balanceDue) : Math.max(0, totalDemand - totalPaidAfter);

  const paymentDate = payment?.paymentDate ? new Date(payment.paymentDate).toLocaleDateString('en-GB') : new Date().toLocaleDateString('en-GB');
  const classStr = student?.studentType === 'school' ? `Class ${student?.className || ''} - ${student?.section || 'A'}` : (student?.course || 'Student');

  const instituteName = settings?.instituteName || settings?.schoolName || 'Smart School';
  const instituteAddress = settings?.address || 'School Campus';
  const institutePhone = settings?.phone || settings?.mobile || '';

  const receiptNo = payment?.receiptNumber || payment?.receiptNo || 'REC000001';

  const msg = `🧾 *OFFICIAL FEE RECEIPT VOUCHER*
*${instituteName.toUpperCase()}*
📍 ${instituteAddress} ${institutePhone ? `| 📞 ${institutePhone}` : ''}
━━━━━━━━━━━━━━━━━━━━
👤 *Student:* ${student?.name || payment?.studentName || '-'}
🆔 *Student ID:* ${student?.studentId || '-'}
📄 *Admission No:* ${student?.admissionNumber || student?.admissionNo || '-'}
🏫 *Class / Course:* ${classStr}
💳 *Receipt No:* ${receiptNo}
📅 *Payment Date:* ${paymentDate}
💰 *Total Fee Demand:* ₹${Number(totalDemand).toLocaleString('en-IN')}
${previousPaid > 0 ? `⏮️ *Previous Payment:* ₹${Number(previousPaid).toLocaleString('en-IN')}${lastPaymentDateFormatted ? ` (Paid on: ${lastPaymentDateFormatted})` : ''}\n` : ''}💵 *Paid Now:* ₹${Number(amountPaid).toLocaleString('en-IN')} via ${payment?.paymentMode || 'Cash'}
${previousPaid > 0 ? `✅ *Total Amount Paid:* ₹${Number(totalPaidAfter).toLocaleString('en-IN')}\n` : ''}⚖️ *Month Balance Due:* ${balanceDue <= 0 ? '₹0.00 (FULL PAID ✅)' : `₹${Number(balanceDue).toLocaleString('en-IN')} (PENDING)`}
━━━━━━━━━━━━━━━━━━━━
📄 *Official Fee Receipt PDF generated & saved.*
*${instituteName}*`;

  const waUrl = finalMobile
    ? `https://api.whatsapp.com/send?phone=${finalMobile}&text=${encodeURIComponent(msg)}`
    : `https://api.whatsapp.com/send?text=${encodeURIComponent(msg)}`;

  // Open WhatsApp directly for this number immediately (avoids browser popup blocker)
  if (typeof window !== 'undefined') {
    window.open(waUrl, '_blank');
  }

  // Auto-download receipt PDF in background
  try {
    createReceiptPDFDoc(payment, student, settings, allPayments).then((doc) => {
      if (doc) {
        doc.save(`Receipt_${receiptNo}.pdf`);
      }
    }).catch((err) => {
      console.warn("Receipt PDF background generation note:", err);
    });
  } catch (e) { }
}

/**
 * Generate Complete WhatsApp Fee Statement for all payments of a student
 */
export function openWhatsAppFeeStatement(student, studentPayments = [], settings = {}) {
  const mobile = student?.alternateMobile || student?.mobile || student?.phone || student?.contactNumber;
  const finalMobile = cleanWhatsAppNumber(mobile);

  const instituteName = settings?.instituteName || settings?.schoolName || 'Smart School';
  const instituteAddress = settings?.address || 'School Campus';
  const institutePhone = settings?.phone || settings?.mobile || '';

  const totalPaid = studentPayments.reduce((sum, p) => sum + (Number(p.amount) || 0), 0);
  const classStr = student?.studentType === 'school' ? `Class ${student?.className || ''} - ${student?.section || 'A'}` : (student?.course || 'Student');

  let receiptsList = '';
  studentPayments.forEach((p, idx) => {
    const d = p.paymentDate ? new Date(p.paymentDate).toLocaleDateString('en-GB') : '-';
    receiptsList += `${idx + 1}. *Receipt #${p.receiptNumber || 'REC'}* (${d}): ₹${Number(p.amount || 0).toLocaleString('en-IN')} [${p.paymentMode || 'Cash'}]\n`;
  });

  const msg = `🧾 *COMPLETE FEE PAYMENT STATEMENT*
*${instituteName.toUpperCase()}*
📍 ${instituteAddress} ${institutePhone ? `| 📞 ${institutePhone}` : ''}
━━━━━━━━━━━━━━━━━━━━
👤 *Student:* ${student?.name || '-'}
🆔 *Student ID:* ${student?.studentId || '-'}
📄 *Admission No:* ${student?.admissionNumber || student?.admissionNo || '-'}
🏫 *Class / Course:* ${classStr}
💰 *Total Fees Received:* ₹${Number(totalPaid).toLocaleString('en-IN')} (${studentPayments.length} Receipts)
━━━━━━━━━━━━━━━━━━━━
📋 *RECEIPTS BREAKDOWN:*
${receiptsList || 'No receipts recorded.\n'}━━━━━━━━━━━━━━━━━━━━
*Thank you for timely fee payment!*
*${instituteName}*`;

  const waUrl = finalMobile
    ? `https://api.whatsapp.com/send?phone=${finalMobile}&text=${encodeURIComponent(msg)}`
    : `https://api.whatsapp.com/send?text=${encodeURIComponent(msg)}`;

  window.open(waUrl, '_blank');
}

/**
 * Generate WhatsApp Fee Reminder URL
 */
export function openWhatsAppFeeReminder(student, settings, payments = []) {
  const pending = Math.max(0, (student.totalFees || 0) - (student.paidFees || 0));
  let mobile = student.alternateMobile || student.mobile || student.phone || student.contactNumber;
  let finalMobile = cleanWhatsAppNumber(mobile);

  if (!finalMobile && typeof window !== 'undefined') {
    const inputNumber = window.prompt(
      `⚠️ WhatsApp Number Not Found for ${student.name}!\n\nEnter 10-digit mobile number to send fee reminder on WhatsApp:`
    );
    if (!inputNumber) {
      return; // Cancelled
    }
    finalMobile = cleanWhatsAppNumber(inputNumber);
  }

  const fatherName = (student.fatherName || '').trim();
  const className = student.studentType === 'school' ? `Class ${student.className || ''}` : (student.course || 'Student');

  let msg = `Dear Parent / Guardian,\n\n`;
  msg += `Greetings from *${settings.instituteName}*!\n\n`;
  if (fatherName) {
    msg += `👨‍👦 *Parent/Father's Name:* Mr. ${fatherName}\n`;
  }
  msg += `👤 *Student:* *${student.name}* (${className})\n\n`;
  msg += `This is a reminder regarding pending school fees:\n\n`;

  // If student has monthlyParticulars
  if (student.monthlyParticulars && typeof student.monthlyParticulars === 'object') {
    const currentKey = `${new Date().getFullYear()}-${String(new Date().getMonth() + 1).padStart(2, '0')}`;
    const entries = Object.entries(student.monthlyParticulars).sort();
    const pendingMonths = [];
    const breakdownLines = [];

    entries.forEach(([mKey, data]) => {
      if (!data || mKey > currentKey) return;
      const due = Number(data.closingDue ?? data.totalDue ?? 0);
      const paid = Number(data.paidAmount ?? data.paidInMonth ?? 0);
      const charge = Number(data.totalDue ?? data.totalMonthCharge ?? 0);
      if (due > 0) pendingMonths.push(mKey);
      if (charge > 0 || paid > 0) {
        breakdownLines.push(`• *${mKey}*: Total ₹${charge} | Paid ₹${paid} | Due ₹${due} ${due <= 0 ? '✅' : '⚠️'}`);
      }
    });

    if (pendingMonths.length > 0) {
      msg += `📌 *Pending Months Count:* ${pendingMonths.length} Months\n`;
      msg += `⚠️ *Pending Months:* ${pendingMonths.join(', ')}\n\n`;
    }
    if (breakdownLines.length > 0) {
      msg += `📊 *Month-wise Fee Breakdown:*\n${breakdownLines.slice(-12).join('\n')}\n\n`;
    }
  }

  msg += `━━━━━━━━━━━━━━━━━━━━\n`;
  msg += `💰 *Outstanding Due:* ₹${pending}\n`;
  msg += `✅ *Fee Paid:* ₹${student.paidFees || 0}\n`;
  msg += `💳 *Total Fee:* ₹${student.totalFees || 0}\n`;
  if (student.dueDate) {
    msg += `📅 *Due Date:* ${student.dueDate}\n`;
  }
  msg += `━━━━━━━━━━━━━━━━━━━━\n\n`;
  msg += `Kindly clear the balance at the earliest to ensure uninterrupted academic services.\n\n`;
  if (settings.mobile) {
    msg += `📞 Contact: ${settings.mobile}\n`;
  }
  msg += `Thank you!\n*${settings.instituteName}*`;

  const url = `https://wa.me/${finalMobile}?text=${encodeURIComponent(msg)}`;
  window.open(url, '_blank');
}

/**
 * Generate WhatsApp Attendance Notification URL
 */
export function openWhatsAppAttendanceAlert(student, status, dateStr, settings) {
  const mobile = student.alternateMobile || student.mobile;
  if (!mobile) {
    console.warn("No mobile number found for this student!");
    return;
  }
  const cleanMobile = mobile.replace(/[^0-9]/g, '');
  const finalMobile = cleanMobile.length === 10 ? `91${cleanMobile}` : cleanMobile;

  const actualStatus = typeof status === 'object' ? (status.status || 'present') : (status || 'present');
  const actualDate = typeof status === 'object' ? (status.date || dateStr || new Date().toISOString().split('T')[0]) : (dateStr || new Date().toISOString().split('T')[0]);
  const statusText = actualStatus === 'absent' ? '❌ ABSENT' : actualStatus === 'leave' ? '📝 ON LEAVE' : '✅ PRESENT';

  const msg = `Dear Parent,

Attendance Notification from *${settings?.instituteName || 'Smart School'}*:

👤 Student: *${student.name}*
🎓 Class/Course: *${student.studentType === 'school' ? `Class ${student.className || ''}` : student.course || ''}*
🆔 Roll / Adm No: *${student.admissionNumber || student.rollNumber || student.studentId || ''}*
📅 Date: *${actualDate}*
📊 Attendance: *${statusText}*

For any queries, please contact: ${settings?.mobile || ''}

Regards,
*${settings?.instituteName || 'Smart School'}*`;

  const url = `https://wa.me/${finalMobile}?text=${encodeURIComponent(msg)}`;
  window.open(url, '_blank');
}

/**
 * PDF: Create Today's Daily Attendance Register Document
 */
export function createTodayAttendancePDFDoc(students = [], attendance = {}, dateStr = '', settings = {}) {
  const doc = new jsPDF({ format: 'a4', unit: 'mm' });
  const W = 210, M = 15;
  const targetDate = dateStr || new Date().toISOString().split('T')[0];
  const dayRecords = (attendance && attendance[targetDate]) || {};
  const studentList = Array.isArray(students) ? students : [];

  // Header Banner
  doc.setFillColor(31, 16, 142);
  doc.rect(0, 0, W, 26, 'F');
  doc.setTextColor(255, 255, 255);
  doc.setFontSize(15); doc.setFont('helvetica', 'bold');
  doc.text(String(settings?.instituteName || 'Smart School Management'), W / 2, 10, { align: 'center' });
  doc.setFontSize(9); doc.setFont('helvetica', 'normal');
  doc.setTextColor(220, 233, 255);
  doc.text(`DAILY ATTENDANCE REGISTER — DATE: ${targetDate}`, W / 2, 17, { align: 'center' });
  doc.text(`Session: ${settings?.currentSession || '2026-27'}  |  Generated: ${new Date().toLocaleTimeString('en-IN')}`, W / 2, 22, { align: 'center' });

  // Summary Metrics Bar
  const total = studentList.length;
  let present = 0, absent = 0, leave = 0;
  studentList.forEach(s => {
    if (!s) return;
    const st = dayRecords[s.id];
    if (st === 'present') present++;
    else if (st === 'absent') absent++;
    else if (st === 'leave' || st === 'late') leave++;
  });
  const pct = total > 0 ? Math.round((present / total) * 100) : 0;

  doc.setFillColor(239, 244, 255);
  doc.roundedRect(M, 32, W - 2 * M, 14, 2, 2, 'F');
  doc.setFontSize(9); doc.setFont('helvetica', 'bold');
  doc.setTextColor(31, 16, 142);
  doc.text(`Total Students: ${total}`, M + 5, 41);
  doc.setTextColor(16, 185, 129);
  doc.text(`Present: ${present}`, M + 45, 41);
  doc.setTextColor(239, 68, 68);
  doc.text(`Absent: ${absent}`, M + 80, 41);
  doc.setTextColor(245, 158, 11);
  doc.text(`Leave: ${leave}`, M + 115, 41);
  doc.setTextColor(31, 16, 142);
  doc.text(`Rate: ${pct}%`, W - M - 20, 41);

  // Table Header
  let y = 54;
  doc.setFillColor(220, 233, 255);
  doc.rect(M, y - 5, W - 2 * M, 8, 'F');
  doc.setFontSize(8); doc.setFont('helvetica', 'bold');
  doc.setTextColor(11, 28, 48);
  doc.text('#', M + 2, y);
  doc.text('Adm No / ID', M + 10, y);
  doc.text('Student Name', M + 40, y);
  doc.text('Father Name', M + 85, y);
  doc.text('Class / Course', M + 130, y);
  doc.text('Status', W - M - 20, y);

  // Table Rows
  doc.setFont('helvetica', 'normal');
  studentList.forEach((s, idx) => {
    if (!s) return;
    y += 7.5;
    if (y > 275) {
      doc.addPage();
      y = 20;
    }
    const st = dayRecords[s.id] || 'unmarked';
    doc.setTextColor(100, 100, 100);
    doc.text(String(idx + 1), M + 2, y);
    doc.setTextColor(31, 16, 142);
    doc.text(String(s.admissionNumber || s.studentId || '-'), M + 10, y);
    doc.setTextColor(11, 28, 48);
    doc.setFont('helvetica', 'bold');
    doc.text(String(s.name || '-'), M + 40, y);
    doc.setFont('helvetica', 'normal');
    doc.setTextColor(70, 70, 80);
    doc.text(String(s.fatherName || '-'), M + 85, y);
    const cls = s.studentType === 'school' ? `Class ${s.className || ''}` : (s.course || '');
    doc.text(String(cls || '-'), M + 130, y);

    if (st === 'present') {
      doc.setTextColor(16, 185, 129); doc.setFont('helvetica', 'bold');
      doc.text('PRESENT', W - M - 20, y);
    } else if (st === 'absent') {
      doc.setTextColor(239, 68, 68); doc.setFont('helvetica', 'bold');
      doc.text('ABSENT', W - M - 20, y);
    } else if (st === 'leave' || st === 'late') {
      doc.setTextColor(245, 158, 11); doc.setFont('helvetica', 'bold');
      doc.text(st === 'late' ? 'LATE' : 'LEAVE', W - M - 20, y);
    } else {
      doc.setTextColor(150, 150, 150); doc.setFont('helvetica', 'normal');
      doc.text('UNMARKED', W - M - 20, y);
    }
    doc.setDrawColor(230, 235, 245); doc.line(M, y + 2, W - M, y + 2);
  });

  return doc;
}

/**
 * PDF: Export Today's Daily Attendance Register File
 */
export function exportTodayAttendancePDF(students, attendance, dateStr, settings) {
  try {
    const doc = createTodayAttendancePDFDoc(students, attendance, dateStr, settings);
    doc.save(`Daily_Attendance_${dateStr || 'today'}.pdf`);
  } catch (e) {
    console.error('exportTodayAttendancePDF error:', e);
  }
}

/**
 * Print: Open Attendance PDF in Print Preview
 */
export function printTodayAttendancePDF(students, attendance, dateStr, settings) {
  try {
    const doc = createTodayAttendancePDFDoc(students, attendance, dateStr, settings);
    doc.autoPrint();
    const blobUrl = doc.output('bloburl');
    window.open(blobUrl, '_blank');
  } catch (e) {
    console.error('printTodayAttendancePDF error:', e);
    // Fallback: window print
    window.print();
  }
}

/**
 * PDF: Create Date Range Attendance Register Document
 */
export function createDateRangeAttendancePDFDoc(students = [], attendance = {}, fromDate = '', toDate = '', settings = {}) {
  const doc = new jsPDF({ orientation: 'landscape', format: 'a4', unit: 'mm' });
  const W = 297, M = 12;
  const studentList = Array.isArray(students) ? students : [];

  // Header Banner
  doc.setFillColor(31, 16, 142);
  doc.rect(0, 0, W, 24, 'F');
  doc.setTextColor(255, 255, 255);
  doc.setFontSize(15); doc.setFont('helvetica', 'bold');
  doc.text(String(settings?.instituteName || 'Smart School Management'), W / 2, 9, { align: 'center' });
  doc.setFontSize(9); doc.setFont('helvetica', 'normal');
  doc.setTextColor(220, 233, 255);
  doc.text(`ATTENDANCE REGISTER REPORT: ${fromDate} TO ${toDate}`, W / 2, 16, { align: 'center' });
  doc.text(`Session: ${settings?.currentSession || '2026-27'}  |  Total Enrolled: ${studentList.length}`, W / 2, 21, { align: 'center' });

  // Generate list of dates in range
  const dates = [];
  const curr = new Date(fromDate || new Date());
  const end = new Date(toDate || new Date());
  while (curr <= end && dates.length <= 31) {
    dates.push(curr.toISOString().split('T')[0]);
    curr.setDate(curr.getDate() + 1);
  }

  let y = 35;
  doc.setFillColor(220, 233, 255);
  doc.rect(M, y - 5, W - 2 * M, 7, 'F');
  doc.setFontSize(7.5); doc.setFont('helvetica', 'bold');
  doc.setTextColor(11, 28, 48);
  doc.text('Adm No', M + 2, y);
  doc.text('Student Name', M + 28, y);
  doc.text('Class', M + 68, y);

  // Date column headers
  const colStart = M + 95;
  const colW = Math.min(6, (W - colStart - M - 25) / Math.max(1, dates.length));
  dates.forEach((d, i) => {
    const dayNum = d.split('-')[2];
    doc.text(dayNum, colStart + i * colW, y);
  });
  doc.text('P', W - M - 22, y);
  doc.text('A', W - M - 14, y);
  doc.text('%', W - M - 6, y);

  // Table rows
  studentList.forEach((s, idx) => {
    if (!s) return;
    y += 6.5;
    if (y > 195) {
      doc.addPage();
      y = 20;
    }
    doc.setFont('helvetica', 'normal'); doc.setFontSize(7);
    doc.setTextColor(31, 16, 142);
    doc.text(String(s.admissionNumber || s.studentId || '-'), M + 2, y);
    doc.setTextColor(11, 28, 48);
    doc.text(String(s.name || '-').substring(0, 18), M + 28, y);
    const cls = s.studentType === 'school' ? (s.className || '') : (s.course?.substring(0, 10) || '');
    doc.text(String(cls || '-'), M + 68, y);

    let pCount = 0, aCount = 0, totalMarked = 0;
    dates.forEach((d, i) => {
      const st = attendance?.[d]?.[s.id];
      if (st === 'present') {
        pCount++; totalMarked++;
        doc.setTextColor(16, 185, 129);
        doc.text('P', colStart + i * colW, y);
      } else if (st === 'absent') {
        aCount++; totalMarked++;
        doc.setTextColor(239, 68, 68);
        doc.text('A', colStart + i * colW, y);
      } else if (st === 'leave' || st === 'late') {
        totalMarked++;
        doc.setTextColor(245, 158, 11);
        doc.text('L', colStart + i * colW, y);
      } else {
        doc.setTextColor(180, 180, 180);
        doc.text('-', colStart + i * colW, y);
      }
    });

    const pct = totalMarked > 0 ? Math.round((pCount / totalMarked) * 100) : 0;
    doc.setTextColor(16, 185, 129); doc.setFont('helvetica', 'bold');
    doc.text(String(pCount), W - M - 22, y);
    doc.setTextColor(239, 68, 68);
    doc.text(String(aCount), W - M - 14, y);
    doc.setTextColor(pct >= 75 ? 31 : 239, pct >= 75 ? 16 : 68, pct >= 75 ? 142 : 68);
    doc.text(`${pct}%`, W - M - 6, y);

    doc.setDrawColor(235, 240, 250); doc.line(M, y + 1.5, W - M, y + 1.5);
  });

  return doc;
}

/**
 * PDF: Date Range Attendance Register (e.g. Month or Custom Span)
 */
export function exportDateRangeAttendancePDF(students, attendance, fromDate, toDate, settings) {
  try {
    const doc = createDateRangeAttendancePDFDoc(students, attendance, fromDate, toDate, settings);
    doc.save(`Attendance_Report_${fromDate}_to_${toDate}.pdf`);
  } catch (e) {
    console.error('exportDateRangeAttendancePDF error:', e);
  }
}

/**
 * Print: Date Range Attendance Register
 */
export function printDateRangeAttendancePDF(students, attendance, fromDate, toDate, settings) {
  try {
    const doc = createDateRangeAttendancePDFDoc(students, attendance, fromDate, toDate, settings);
    doc.autoPrint();
    const blobUrl = doc.output('bloburl');
    window.open(blobUrl, '_blank');
  } catch (e) {
    console.error('printDateRangeAttendancePDF error:', e);
    window.print();
  }
}

/**
 * PDF: Individual Student Attendance Card
 */
export function exportStudentAttendancePDF(student, attendance, settings) {
  const doc = new jsPDF({ format: 'a5', unit: 'mm' });
  const W = 148, M = 12;

  // Header Banner
  doc.setFillColor(31, 16, 142);
  doc.rect(0, 0, W, 22, 'F');
  doc.setTextColor(255, 255, 255);
  doc.setFontSize(13); doc.setFont('helvetica', 'bold');
  doc.text(settings?.instituteName || 'Smart School', W / 2, 9, { align: 'center' });
  doc.setFontSize(8); doc.setFont('helvetica', 'normal');
  doc.setTextColor(220, 233, 255);
  doc.text('STUDENT ATTENDANCE PERFORMANCE REPORT', W / 2, 15, { align: 'center' });
  doc.text(`Session: ${settings?.currentSession || '2026-27'}`, W / 2, 19.5, { align: 'center' });

  // Student Particulars Card
  doc.setFillColor(239, 244, 255);
  doc.roundedRect(M, 28, W - 2 * M, 24, 2, 2, 'F');
  doc.setFontSize(10); doc.setFont('helvetica', 'bold'); doc.setTextColor(11, 28, 48);
  doc.text(student.name || '-', M + 4, 35);
  doc.setFontSize(8); doc.setFont('helvetica', 'normal'); doc.setTextColor(70, 70, 90);
  const clsStr = student.studentType === 'school' ? `Class ${student.className || ''} (Sec ${student.section || 'A'})` : student.course || '';
  doc.text(`Class/Course: ${clsStr}`, M + 4, 41);
  doc.text(`Adm No: ${student.admissionNumber || '-'}  |  Roll: ${student.rollNumber || '-'}  |  ID: ${student.studentId || '-'}`, M + 4, 47);
  doc.text(`Father's Name: ${student.fatherName || '-'}  |  Mobile: ${student.mobile || '-'}`, M + 4, 53);

  // Compute attendance stats
  let presentDays = 0, absentDays = 0, leaveDays = 0, totalMarked = 0;
  const logEntries = [];
  Object.keys(attendance).sort().reverse().forEach(dateStr => {
    const st = attendance[dateStr]?.[student.id];
    if (st) {
      totalMarked++;
      if (st === 'present') presentDays++;
      else if (st === 'absent') absentDays++;
      else if (st === 'leave') leaveDays++;
      logEntries.push({ date: dateStr, status: st });
    }
  });

  const rate = totalMarked > 0 ? Math.round((presentDays / totalMarked) * 100) : 100;

  // Stat summary pills
  let y = 58;
  doc.setFontSize(8.5); doc.setFont('helvetica', 'bold');
  doc.setTextColor(16, 185, 129);
  doc.text(`Present: ${presentDays}`, M + 4, y);
  doc.setTextColor(239, 68, 68);
  doc.text(`Absent: ${absentDays}`, M + 35, y);
  doc.setTextColor(245, 158, 11);
  doc.text(`Leave: ${leaveDays}`, M + 65, y);
  doc.setTextColor(31, 16, 142);
  doc.text(`Attendance Rate: ${rate}%`, W - M - 36, y);

  // Recent History Table
  y = 68;
  doc.setFillColor(220, 233, 255);
  doc.rect(M, y - 4, W - 2 * M, 6, 'F');
  doc.setFontSize(8); doc.setFont('helvetica', 'bold'); doc.setTextColor(11, 28, 48);
  doc.text('Date', M + 4, y);
  doc.text('Status', W / 2, y);
  doc.text('Remarks', W - M - 25, y);

  logEntries.slice(0, 15).forEach((entry, idx) => {
    y += 6;
    doc.setFont('helvetica', 'normal'); doc.setFontSize(7.5);
    doc.setTextColor(50, 50, 70);
    doc.text(entry.date, M + 4, y);
    if (entry.status === 'present') {
      doc.setTextColor(16, 185, 129); doc.setFont('helvetica', 'bold');
      doc.text('PRESENT', W / 2, y);
    } else if (entry.status === 'absent') {
      doc.setTextColor(239, 68, 68); doc.setFont('helvetica', 'bold');
      doc.text('ABSENT', W / 2, y);
    } else {
      doc.setTextColor(245, 158, 11); doc.setFont('helvetica', 'bold');
      doc.text('LEAVE', W / 2, y);
    }
    doc.setFont('helvetica', 'normal'); doc.setTextColor(120, 120, 140);
    doc.text('Recorded on cloud', W - M - 25, y);
    doc.setDrawColor(240, 240, 250); doc.line(M, y + 1.5, W - M, y + 1.5);
  });

  doc.save(`Attendance_${student.name?.replace(/\s+/g, '_')}.pdf`);
}

/**
 * ─────────────────────────────────────────────────────────────────────────────
 * FULL STUDENT MASTER IMPORT & EXPORT SUITE (Aligned with Mobile App Schema)
 * ─────────────────────────────────────────────────────────────────────────────
 */

export const STUDENT_TEMPLATE_COLUMNS = [
  { key: 'admissionNumber', header: 'Admission Number', example1: 'ADM-2026-001', example2: 'ADM-2026-002', required: true },
  { key: 'studentId', header: 'Student ID', example1: 'STU2026001', example2: 'STU2026002', required: true },
  { key: 'name', header: 'Student Name', example1: 'Rahul Sharma', example2: 'Priya Singh', required: true },
  { key: 'fatherName', header: "Father's Name", example1: 'Rajesh Sharma', example2: 'Suresh Singh', required: true },
  { key: 'motherName', header: "Mother's Name", example1: 'Sunita Sharma', example2: 'Kavita Singh', required: false },
  { key: 'mobile', header: 'Mobile', example1: '9876543210', example2: '9876543211', required: true },
  { key: 'alternateMobile', header: 'Alternate Mobile', example1: '9876543212', example2: '', required: false },
  { key: 'gender', header: 'Gender', example1: 'Male', example2: 'Female', required: false },
  { key: 'dob', header: 'Date of Birth', example1: '2010-01-01', example2: '2012-06-15', required: false },
  { key: 'address', header: 'Address', example1: 'Main Market, Siwan', example2: 'Station Road, Patna', required: true },
  { key: 'studentType', header: 'Student Type', example1: 'school', example2: 'computer', required: true },
  { key: 'className', header: 'Class', example1: '10th', example2: '', required: false },
  { key: 'section', header: 'Section', example1: 'A', example2: '', required: false },
  { key: 'rollNumber', header: 'Roll Number', example1: '15', example2: '', required: false },
  { key: 'course', header: 'Course', example1: '', example2: 'ADCA (12 Months)', required: false },
  { key: 'batch', header: 'Batch', example1: '', example2: '10:00 AM - 12:00 PM', required: false },
  { key: 'admissionDate', header: 'Admission Date', example1: '2026-04-01', example2: '2026-04-05', required: false },
  { key: 'session', header: 'Academic Session', example1: '2026-27', example2: '2026-27', required: false },
  { key: 'status', header: 'Status', example1: 'active', example2: 'active', required: false },
  { key: 'admissionFee', header: 'Admission Fee', example1: '2500', example2: '2000', required: false },
  { key: 'tuitionFee', header: 'Tuition Fee', example1: '3000', example2: '3500', required: false },
  { key: 'monthlyFee', header: 'Monthly Fee', example1: '1500', example2: '1800', required: false },
  { key: 'examinationFee', header: 'Examination Fee', example1: '500', example2: '500', required: false },
  { key: 'previousDues', header: 'Previous Dues', example1: '0', example2: '0', required: false },
  { key: 'gameFee', header: 'Game Fee', example1: '300', example2: '300', required: false },
  { key: 'reAdmissionFee', header: 'Re-Admission Fee', example1: '0', example2: '0', required: false },
  { key: 'developmentFee', header: 'Development Fee', example1: '500', example2: '500', required: false },
  { key: 'schoolIdFee', header: 'School ID Fee', example1: '150', example2: '150', required: false },
  { key: 'tieBagBeltFee', header: 'Tie Bag Belt Fee', example1: '450', example2: '450', required: false },
  { key: 'backDues', header: 'Back Dues', example1: '0', example2: '0', required: false },
  { key: 'transportFee', header: 'Transport Fee', example1: '800', example2: '0', required: false },
  { key: 'otherFee', header: 'Other Fee', example1: '0', example2: '0', required: false },
  { key: 'totalFees', header: 'Total Annual Fees', example1: '9700', example2: '8900', required: false },
  { key: 'paidFees', header: 'Paid Fees', example1: '3000', example2: '8900', required: false },
  { key: 'dueDate', header: 'Due Date', example1: '2026-05-10', example2: '2026-05-10', required: false }
];

/**
 * 1. Download Official Excel Import Template (.xlsx) matching Mobile App Template
 */
export function downloadStudentImportTemplate(instituteName = 'Smart School') {
  const wb = XLSX.utils.book_new();

  // Sheet 1: Template Data with Header + Example Rows
  const headers = STUDENT_TEMPLATE_COLUMNS.map(c => c.header);
  const rowExample1 = STUDENT_TEMPLATE_COLUMNS.map(c => c.example1);
  const rowExample2 = STUDENT_TEMPLATE_COLUMNS.map(c => c.example2);
  const promptRow = ['← Start entering student data here from row 4'];

  const wsData = [headers, rowExample1, rowExample2, promptRow];
  const ws = XLSX.utils.aoa_to_sheet(wsData);

  // Set column widths
  ws['!cols'] = STUDENT_TEMPLATE_COLUMNS.map(() => ({ wch: 20 }));
  XLSX.utils.book_append_sheet(wb, ws, 'Import Template');

  // Sheet 2: Instructions Sheet
  const instructions = [
    ['STUDENT DATABASE IMPORT TEMPLATE INSTRUCTIONS'],
    [''],
    ['1. Do NOT delete or rename the "Import Template" sheet.'],
    ['2. Do NOT modify or re-order the header row (Row 1).'],
    ['3. Example rows (2 and 3) are for reference only and will NOT be imported.'],
    ['4. Enter your new student records starting from Row 4.'],
    ['5. Required columns: Admission Number, Student ID, Student Name, Father\'s Name, Mobile, Address, Student Type.'],
    ['6. Student Type must be either "school" or "computer" (lowercase).'],
    ['7. Date format: YYYY-MM-DD or DD-MM-YYYY (e.g. 2026-04-01 or 01-04-2026).'],
    ['8. Status options: active | left | completed | suspended.'],
    ['9. Fee amounts must be numbers only (without ₹ or currency symbols).'],
    ['10. Save the file and upload back via the Reports / Import Center on Web or Mobile App.']
  ];
  const wsInst = XLSX.utils.aoa_to_sheet(instructions);
  wsInst['!cols'] = [{ wch: 80 }];
  XLSX.utils.book_append_sheet(wb, wsInst, 'Instructions');

  const cleanName = (instituteName || 'Smart_School').replace(/[^a-zA-Z0-9]/g, '_');
  const dateStr = new Date().toISOString().split('T')[0];
  XLSX.writeFile(wb, `${cleanName}_Student_Import_Template_${dateStr}.xlsx`);
}

/**
 * 2. Export Complete Student Master Database to Excel (.xlsx) with all 35+ fields
 */
export function exportFullStudentsMasterToExcel(students, instituteName = 'Institute') {
  const data = students.map((s, idx) => {
    const totalFees = Number(s.totalFees) || 0;
    const paidFees = Number(s.paidFees) || 0;
    const pendingDues = Math.max(0, totalFees - paidFees);
    const fs = s.feeStructure || {};

    return {
      'S.No': idx + 1,
      'Admission Number': s.admissionNumber || '',
      'Student ID': s.studentId || '',
      'Student Name': s.name || '',
      "Father's Name": s.fatherName || '',
      "Mother's Name": s.motherName || '',
      'Mobile': s.mobile || '',
      'Alternate Mobile': s.alternateMobile || '',
      'Gender': s.gender || 'Male',
      'Date of Birth': s.dob || '',
      'Residential Address': s.address || '',
      'Student Type': s.studentType === 'school' ? 'School' : 'Computer Institute',
      'Class': s.studentType === 'school' ? (s.className || '') : '',
      'Section': s.studentType === 'school' ? (s.section || 'A') : '',
      'Roll Number': s.rollNumber || '',
      'Course': s.studentType === 'computer' ? (s.course || '') : '',
      'Batch': s.studentType === 'computer' ? (s.batch || '') : '',
      'Admission Date': s.admissionDate || '',
      'Academic Session': s.session || '2026-27',
      'Enrollment Status': (s.status || 'Active').toUpperCase(),
      'Admission Fee (₹)': Number(fs.admissionFee || 0),
      'Tuition Fee (₹)': Number(fs.tuitionFee || s.monthlyFee || 0),
      'Monthly Fee (₹)': Number(s.monthlyFee || fs.tuitionFee || 0),
      'Examination Fee (₹)': Number(fs.examinationFee || 0),
      'Previous Dues (₹)': Number(fs.previousDues || 0),
      'Game Fee (₹)': Number(fs.gameFee || 0),
      'Re-Admission Fee (₹)': Number(fs.reAdmissionFee || 0),
      'Development Fee (₹)': Number(fs.developmentFee || 0),
      'School ID Fee (₹)': Number(fs.schoolIdFee || 0),
      'Tie Bag Belt Fee (₹)': Number(fs.tieBagBeltFee || 0),
      'Back Dues (₹)': Number(fs.backDues || 0),
      'Transport Fee (₹)': Number(fs.transportFee || 0),
      'Other Fee (₹)': Number(fs.otherFee || 0),
      'Total Annual Fees (₹)': totalFees,
      'Total Paid Fees (₹)': paidFees,
      'Outstanding Dues (₹)': pendingDues,
      'Fee Status': pendingDues === 0 && totalFees > 0 ? 'PAID' : (paidFees === 0 ? 'UNPAID' : 'PARTIAL DUE'),
      'Due Date': s.dueDate || '10th of Month'
    };
  });

  const ws = XLSX.utils.json_to_sheet(data);
  const wb = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(wb, ws, 'Student Master Directory');

  ws['!cols'] = Object.keys(data[0] || {}).map(() => ({ wch: 18 }));

  const cleanName = (instituteName || 'Smart_School').replace(/[^a-zA-Z0-9]/g, '_');
  const dateStr = new Date().toISOString().split('T')[0];
  XLSX.writeFile(wb, `${cleanName}_Complete_Student_Master_${dateStr}.xlsx`);
}

/**
 * 3. Export Complete Student Master Database to Formal Landscape PDF
 */
export function exportFullStudentsMasterPDF(students, settings = {}) {
  const doc = new jsPDF({ orientation: 'landscape', format: 'a4', unit: 'mm' });
  const W = 297, M = 10;

  // Header Banner
  doc.setFillColor(31, 16, 142);
  doc.rect(0, 0, W, 25, 'F');
  doc.setTextColor(255, 255, 255);
  doc.setFontSize(16); doc.setFont('helvetica', 'bold');
  doc.text((settings?.instituteName || 'Smart School').toUpperCase(), W / 2, 9, { align: 'center' });
  doc.setFontSize(9); doc.setFont('helvetica', 'normal');
  doc.setTextColor(220, 233, 255);
  doc.text('OFFICIAL COMPREHENSIVE STUDENT MASTER DIRECTORY REGISTER', W / 2, 16, { align: 'center' });
  doc.text(`Academic Session: ${settings?.currentSession || '2026-27'}  |  Total Enrolled Students: ${students.length}  |  Generated: ${new Date().toLocaleDateString('en-GB')}`, W / 2, 21, { align: 'center' });

  let y = 33;
  // Table Column Headers
  doc.setFillColor(220, 233, 255);
  doc.rect(M, y - 4, W - 2 * M, 7, 'F');
  doc.setFontSize(7.5); doc.setFont('helvetica', 'bold');
  doc.setTextColor(11, 28, 48);

  doc.text('S.N', M + 2, y);
  doc.text('Adm No', M + 10, y);
  doc.text('Student Name', M + 34, y);
  doc.text("Father's Name", M + 75, y);
  doc.text('Class / Course', M + 115, y);
  doc.text('Roll', M + 145, y);
  doc.text('Mobile', M + 158, y);
  doc.text('Total (₹)', M + 185, y);
  doc.text('Paid (₹)', M + 205, y);
  doc.text('Due (₹)', M + 225, y);
  doc.text('Fee Status', M + 245, y);
  doc.text('Status', M + 268, y);

  // Table Body Rows
  students.forEach((s, idx) => {
    y += 6.2;
    if (y > 192) {
      doc.addPage();
      y = 20;
      // Repeat header on new page
      doc.setFillColor(220, 233, 255);
      doc.rect(M, y - 4, W - 2 * M, 7, 'F');
      doc.setFontSize(7.5); doc.setFont('helvetica', 'bold');
      doc.setTextColor(11, 28, 48);
      doc.text('S.N', M + 2, y);
      doc.text('Adm No', M + 10, y);
      doc.text('Student Name', M + 34, y);
      doc.text("Father's Name", M + 75, y);
      doc.text('Class / Course', M + 115, y);
      doc.text('Roll', M + 145, y);
      doc.text('Mobile', M + 158, y);
      doc.text('Total (₹)', M + 185, y);
      doc.text('Paid (₹)', M + 205, y);
      doc.text('Due (₹)', M + 225, y);
      doc.text('Fee Status', M + 245, y);
      doc.text('Status', M + 268, y);
      y += 6.2;
    }

    const totalFees = Number(s.totalFees) || 0;
    const paidFees = Number(s.paidFees) || 0;
    const dues = Math.max(0, totalFees - paidFees);
    const clsStr = s.studentType === 'school' ? `Class ${s.className || ''} (${s.section || 'A'})` : (s.course?.substring(0, 14) || '');

    doc.setFont('helvetica', 'normal'); doc.setFontSize(7);
    doc.setTextColor(50, 50, 70);
    doc.text(String(idx + 1), M + 2, y);
    doc.setTextColor(31, 16, 142); doc.setFont('helvetica', 'bold');
    doc.text(s.admissionNumber || s.studentId || '-', M + 10, y);
    doc.setTextColor(11, 28, 48);
    doc.text((s.name || '').substring(0, 20), M + 34, y);
    doc.setFont('helvetica', 'normal');
    doc.text((s.fatherName || '-').substring(0, 18), M + 75, y);
    doc.text(clsStr, M + 115, y);
    doc.text(s.rollNumber || '-', M + 145, y);
    doc.text(s.mobile || '-', M + 158, y);

    doc.text(String(totalFees), M + 185, y);
    doc.setTextColor(16, 185, 129);
    doc.text(String(paidFees), M + 205, y);
    doc.setTextColor(dues > 0 ? 239 : 16, dues > 0 ? 68 : 185, dues > 0 ? 68 : 129);
    doc.text(String(dues), M + 225, y);

    // Fee Status Badge text
    if (dues === 0 && totalFees > 0) {
      doc.setTextColor(16, 185, 129); doc.setFont('helvetica', 'bold');
      doc.text('PAID', M + 245, y);
    } else if (paidFees === 0) {
      doc.setTextColor(239, 68, 68); doc.setFont('helvetica', 'bold');
      doc.text('UNPAID', M + 245, y);
    } else {
      doc.setTextColor(245, 158, 11); doc.setFont('helvetica', 'bold');
      doc.text('DUE', M + 245, y);
    }

    doc.setFont('helvetica', 'normal');
    doc.setTextColor(16, 185, 129);
    doc.text((s.status || 'Active').toUpperCase(), M + 268, y);

    doc.setDrawColor(235, 240, 250);
    doc.line(M, y + 1.8, W - M, y + 1.8);
  });

  const dateStr = new Date().toISOString().split('T')[0];
  doc.save(`Student_Master_Register_${dateStr}.pdf`);
}

/**
 * 4. Comprehensive Excel / CSV Import Parser (matching Mobile App Template)
 */
export function importFullStudentsFromExcel(file) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = (e) => {
      try {
        const data = new Uint8Array(e.target.result);
        const workbook = XLSX.read(data, { type: 'array' });
        const sheetName = workbook.SheetNames[0];
        const worksheet = workbook.Sheets[sheetName];
        const json = XLSX.utils.sheet_to_json(worksheet, { header: 1 });

        if (json.length < 2) {
          throw new Error("The Excel file is empty or does not contain a header row.");
        }

        const rawHeaders = json[0] || [];
        const normalize = (str) => String(str || '').toLowerCase().replace(/[^a-z0-9]/g, '');

        // Map column header index to field
        const headerIndexMap = {};
        rawHeaders.forEach((h, idx) => {
          const norm = normalize(h);
          if (norm.includes('admissionno') || norm.includes('admno') || norm === 'admissionnumber') headerIndexMap.admissionNumber = idx;
          else if (norm.includes('studentid') || norm === 'id') headerIndexMap.studentId = idx;
          else if (norm.includes('name') && !norm.includes('father') && !norm.includes('mother')) headerIndexMap.name = idx;
          else if (norm.includes('father')) headerIndexMap.fatherName = idx;
          else if (norm.includes('mother')) headerIndexMap.motherName = idx;
          else if (norm === 'mobile' || norm.includes('phone') || norm.includes('contact')) headerIndexMap.mobile = idx;
          else if (norm.includes('alt') || norm.includes('whatsapp')) headerIndexMap.alternateMobile = idx;
          else if (norm.includes('gender') || norm.includes('sex')) headerIndexMap.gender = idx;
          else if (norm.includes('dob') || norm.includes('birth')) headerIndexMap.dob = idx;
          else if (norm.includes('address') || norm.includes('city')) headerIndexMap.address = idx;
          else if (norm.includes('type')) headerIndexMap.studentType = idx;
          else if (norm === 'class' || norm.includes('grade') || norm.includes('classname')) headerIndexMap.className = idx;
          else if (norm === 'section' || norm.includes('sec')) headerIndexMap.section = idx;
          else if (norm.includes('roll')) headerIndexMap.rollNumber = idx;
          else if (norm.includes('course')) headerIndexMap.course = idx;
          else if (norm.includes('batch')) headerIndexMap.batch = idx;
          else if (norm.includes('session')) headerIndexMap.session = idx;
          else if (norm.includes('status')) headerIndexMap.status = idx;
          else if (norm.includes('admissionfee')) headerIndexMap.admissionFee = idx;
          else if (norm.includes('tuitionfee')) headerIndexMap.tuitionFee = idx;
          else if (norm.includes('monthlyfee')) headerIndexMap.monthlyFee = idx;
          else if (norm.includes('examfee') || norm.includes('examinationfee')) headerIndexMap.examinationFee = idx;
          else if (norm.includes('prevdue') || norm.includes('previousdue')) headerIndexMap.previousDues = idx;
          else if (norm.includes('gamefee')) headerIndexMap.gameFee = idx;
          else if (norm.includes('transportfee')) headerIndexMap.transportFee = idx;
          else if (norm.includes('totalfee') || norm.includes('total')) headerIndexMap.totalFees = idx;
          else if (norm.includes('paidfee') || norm.includes('paid')) headerIndexMap.paidFees = idx;
          else if (norm.includes('duedate')) headerIndexMap.dueDate = idx;
        });

        const rows = json.slice(1);
        const importedStudents = [];

        rows.forEach((row, rowIdx) => {
          if (!row || row.length === 0) return;
          const val = (idx) => (idx !== undefined && row[idx] !== undefined) ? String(row[idx]).trim() : '';

          const name = val(headerIndexMap.name) || val(2);
          if (!name || name.startsWith('←') || name.toLowerCase().includes('example') || name === 'Student Name') return;

          const fatherName = val(headerIndexMap.fatherName) || val(3) || 'Father';
          const mobile = val(headerIndexMap.mobile) || val(5) || '9876543210';
          const studentType = (val(headerIndexMap.studentType) || 'school').toLowerCase().includes('comp') ? 'computer' : 'school';
          const className = val(headerIndexMap.className) || '10th';
          const section = val(headerIndexMap.section) || 'A';
          const rollNumber = val(headerIndexMap.rollNumber) || String(rowIdx + 1);
          const course = val(headerIndexMap.course) || 'ADCA (12 Months)';
          const batch = val(headerIndexMap.batch) || '10:00 AM - 12:00 PM';
          const address = val(headerIndexMap.address) || val(9) || 'Siwan, Bihar';
          const dob = val(headerIndexMap.dob) || '2010-01-01';
          const gender = val(headerIndexMap.gender) || 'Male';
          const admNo = val(headerIndexMap.admissionNumber) || val(0) || `ADM-${Date.now().toString().slice(-4)}`;
          const stuId = val(headerIndexMap.studentId) || val(1) || `STU${Date.now().toString().slice(-4)}`;

          const totalFees = Number(val(headerIndexMap.totalFees)) || Number(val(headerIndexMap.tuitionFee)) || 5000;
          const paidFees = Number(val(headerIndexMap.paidFees)) || 0;

          importedStudents.push({
            name,
            fatherName,
            motherName: val(headerIndexMap.motherName) || '',
            mobile,
            alternateMobile: val(headerIndexMap.alternateMobile) || '',
            studentType,
            className,
            section,
            rollNumber,
            course,
            batch,
            address,
            dob,
            gender,
            admissionNumber: admNo,
            studentId: stuId,
            session: val(headerIndexMap.session) || '2026-27',
            status: val(headerIndexMap.status) || 'active',
            admissionDate: new Date().toISOString().split('T')[0],
            totalFees,
            paidFees,
            feeStructure: {
              admissionFee: Number(val(headerIndexMap.admissionFee)) || 0,
              tuitionFee: Number(val(headerIndexMap.tuitionFee)) || totalFees,
              monthlyFee: Number(val(headerIndexMap.monthlyFee)) || 0,
              examinationFee: Number(val(headerIndexMap.examinationFee)) || 0,
              previousDues: Number(val(headerIndexMap.previousDues)) || 0,
              gameFee: Number(val(headerIndexMap.gameFee)) || 0,
              transportFee: Number(val(headerIndexMap.transportFee)) || 0,
              lateFinePerDay: 0,
              dueDay: 10
            }
          });
        });

        if (importedStudents.length === 0) {
          throw new Error("No valid student rows found in the selected Excel sheet. Please make sure data starts from row 4 or headers are valid.");
        }

        resolve(importedStudents);
      } catch (err) {
        reject(err);
      }
    };
    reader.onerror = (err) => reject(err);
    reader.readAsArrayBuffer(file);
  });
}

// ─── Export Exam Results & Academic Performance to Excel ──────────────────────
export function exportExamResultsToExcel(results = [], students = [], settingsOrName = 'School') {
  const schoolName = typeof settingsOrName === 'string'
    ? settingsOrName
    : (settingsOrName?.instituteName || settingsOrName?.schoolName || 'School');

  const findStudent = (r) => {
    if (!r) return {};
    const rId = (r.studentId ? String(r.studentId) : '').trim().toLowerCase();
    const rName = (r.studentName ? String(r.studentName) : '').trim().toLowerCase();
    return (students || []).find(s => {
      if (rId) {
        if (s.id && String(s.id).trim().toLowerCase() === rId) return true;
        if (s.studentId && String(s.studentId).trim().toLowerCase() === rId) return true;
        if (s.admissionNumber && String(s.admissionNumber).trim().toLowerCase() === rId) return true;
        if (s.admissionNo && String(s.admissionNo).trim().toLowerCase() === rId) return true;
      }
      if (rName && s.name && String(s.name).trim().toLowerCase() === rName) return true;
      return false;
    }) || {};
  };

  const data = (results || []).map((r, idx) => {
    const stu = findStudent(r);
    const rawSubs = Array.isArray(r.subjects) && r.subjects.length > 0 ? r.subjects : [];
    const subjectsStr = rawSubs.map(s => `${s.subjectName || s.name || 'Subject'}: ${s.marks ?? s.obtainedMarks ?? 0}/${s.totalMarks ?? s.fullMarks ?? 100}`).join(' | ');
    const totalMax = rawSubs.reduce((sum, s) => sum + (Number(s.totalMarks || s.fullMarks) || 0), 0) || Number(r.totalMarks) || 100;
    const totalObt = rawSubs.reduce((sum, s) => sum + (Number(s.marks || s.obtainedMarks) || 0), 0) || Number(r.obtainedMarks || r.marks) || 0;
    const pct = totalMax > 0 ? Number(((totalObt / totalMax) * 100).toFixed(1)) : 0;
    const passCriteria = Number(r.passingMarks || r.passMarks || 33);
    const failedSubs = rawSubs.filter(s => {
      const sMax = Number(s.totalMarks || s.fullMarks) || 100;
      const sObt = Number(s.marks || s.obtainedMarks) || 0;
      const minPass = s.passingMarks != null ? Number(s.passingMarks) : Math.round(sMax * (passCriteria / 100));
      return sObt < minPass;
    });
    const isPass = failedSubs.length === 0 && pct >= passCriteria;

    let finalStatus = 'PASS';
    if (r.status === 'PROMOTED') finalStatus = 'PROMOTED';
    else if (failedSubs.length > 0 || !isPass || r.status === 'FAIL') finalStatus = 'FAIL';
    else finalStatus = 'PASS';

    const grade = pct >= 90 ? 'A+' : pct >= 80 ? 'A' : pct >= 70 ? 'B+' : pct >= 60 ? 'B' : pct >= 50 ? 'C' : pct >= 40 ? 'D' : 'F';

    const rollNo = r.rollNumber || stu.rollNumber || '-';
    const studentId = r.studentId || stu.studentId || '-';
    const studentName = r.studentName || stu.name || '-';
    const fatherName = r.fatherName || stu.fatherName || '-';
    const motherName = r.motherName || stu.motherName || '-';
    const className = r.className || r.class || (stu.studentType === 'computer' ? stu.course : (stu.className || '-'));
    const section = r.section || stu.section || 'A';
    const admNo = stu.admissionNumber || stu.admissionNo || r.admissionNumber || '-';

    return {
      'S.No': idx + 1,
      'Roll No': rollNo,
      'Student ID': studentId,
      'Student Name': studentName,
      'Father Name': fatherName,
      'Mother Name': motherName,
      'Class': className,
      'Section': section,
      'Admission No': admNo,
      'Exam Name': r.examName || r.examType || 'Term Exam',
      'Subjects & Marks': subjectsStr || '-',
      'Total Marks': totalMax,
      'Obtained Marks': totalObt,
      'Percentage (%)': `${pct}%`,
      'Grade': grade,
      'Result Status': finalStatus,
      'Date': r.createdAt ? (typeof r.createdAt === 'string' ? r.createdAt.split('T')[0] : new Date(r.createdAt).toISOString().split('T')[0]) : '-'
    };
  });

  const ws = XLSX.utils.json_to_sheet(data);
  const wb = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(wb, ws, 'Exam Results');
  XLSX.writeFile(wb, `${schoolName.replace(/[^a-zA-Z0-9]/g, '_')}_Exam_Results_${new Date().toISOString().split('T')[0]}.xlsx`);
}

// ─── Export Institutional Exam Results Master Sheet to PDF ───────────────────
export async function exportExamResultsPDF(results = [], students = [], settings = {}) {
  const doc = new jsPDF({ orientation: 'landscape', unit: 'mm', format: 'a4' });
  const W = 297, H = 210, M = 10;
  const contentW = W - 2 * M; // 277 mm

  const logoSrc = settings.logoUrl || settings.logoPath || settings.logo;
  const sigSrc = settings.principalSignature || settings.signatureUrl || settings.signaturePath || settings.signature;
  const stampSrc = settings.schoolSeal || settings.schoolStamp || settings.stampUrl || settings.sealUrl || settings.stampPath;

  const [logoData, sigData, stampData] = await Promise.all([
    getImageDataUrl(logoSrc),
    getImageDataUrl(sigSrc),
    getImageDataUrl(stampSrc)
  ]);

  const findStudent = (r) => {
    if (!r) return {};
    const rId = (r.studentId ? String(r.studentId) : '').trim().toLowerCase();
    const rName = (r.studentName ? String(r.studentName) : '').trim().toLowerCase();
    return (students || []).find(s => {
      if (rId) {
        if (s.id && String(s.id).trim().toLowerCase() === rId) return true;
        if (s.studentId && String(s.studentId).trim().toLowerCase() === rId) return true;
        if (s.admissionNumber && String(s.admissionNumber).trim().toLowerCase() === rId) return true;
        if (s.admissionNo && String(s.admissionNo).trim().toLowerCase() === rId) return true;
      }
      if (rName && s.name && String(s.name).trim().toLowerCase() === rName) return true;
      return false;
    }) || {};
  };

  const drawHeader = (pageNum) => {
    doc.setFillColor(31, 16, 142);
    doc.rect(M, M, contentW, 20, 'F');

    if (logoData) {
      try {
        doc.addImage(logoData, 'PNG', M + 4, M + 2, 16, 16);
      } catch (e) {
        console.warn('Could not add logo', e);
      }
    }

    doc.setTextColor(255, 255, 255);
    doc.setFont('helvetica', 'bold');
    doc.setFontSize(13);
    const instName = (settings.instituteName || settings.schoolName || 'SMART SCHOOL MANAGEMENT').toUpperCase();
    doc.text(instName, W / 2, M + 7.5, { align: 'center' });

    doc.setFontSize(8);
    doc.setFont('helvetica', 'normal');
    const tagline = settings.tagline ? `${settings.tagline} · ` : (settings.address ? `${settings.address} · ` : '');
    doc.text(`${tagline}EXAMINATION RESULTS & TABULATION SHEET — SESSION: ${settings.currentSession || '2026-27'}`, W / 2, M + 13, { align: 'center' });

    doc.setFontSize(7);
    doc.text(`Page ${pageNum}`, W - M - 4, M + 6, { align: 'right' });
  };

  const cols = [
    { label: '#', w: 8, align: 'center' },
    { label: 'Roll No', w: 16, align: 'center' },
    { label: 'Student ID', w: 24, align: 'left' },
    { label: 'Student Name', w: 40, align: 'left' },
    { label: "Father's Name", w: 36, align: 'left' },
    { label: "Mother's Name", w: 34, align: 'left' },
    { label: 'Class', w: 18, align: 'center' },
    { label: 'Sec', w: 12, align: 'center' },
    { label: 'Max', w: 17, align: 'center' },
    { label: 'Obt', w: 17, align: 'center' },
    { label: '%', w: 17, align: 'center' },
    { label: 'Grade', w: 18, align: 'center' },
    { label: 'Status', w: 20, align: 'center' },
  ];

  const drawTableHeader = (curY) => {
    doc.setFillColor(241, 245, 249);
    doc.rect(M, curY, contentW, 6.5, 'F');
    doc.setDrawColor(203, 213, 225);
    doc.setLineWidth(0.3);
    doc.rect(M, curY, contentW, 6.5);

    doc.setTextColor(30, 41, 59);
    doc.setFont('helvetica', 'bold');
    doc.setFontSize(7.5);

    let x = M;
    cols.forEach(c => {
      const textX = c.align === 'center' ? x + c.w / 2 : (c.align === 'right' ? x + c.w - 1.5 : x + 2);
      doc.text(c.label, textX, curY + 4.5, { align: c.align === 'center' ? 'center' : (c.align === 'right' ? 'right' : 'left') });
      x += c.w;
      if (x < W - M) doc.line(x, curY, x, curY + 6.5);
    });
  };

  let pageNum = 1;
  drawHeader(pageNum);
  let y = M + 23;
  drawTableHeader(y);
  y += 6.5;

  let totalStudents = 0;
  let passedCount = 0;
  let failedCount = 0;
  let promotedCount = 0;

  (results || []).forEach((r, idx) => {
    if (y > H - 24) {
      doc.addPage();
      pageNum++;
      drawHeader(pageNum);
      y = M + 23;
      drawTableHeader(y);
      y += 6.5;
    }

    const stu = findStudent(r);
    const rawSubs = Array.isArray(r.subjects) && r.subjects.length > 0
      ? r.subjects
      : [{ subjectName: r.subject || 'General', totalMarks: r.totalMarks || 100, marks: r.marks || 0 }];
    const tMax = rawSubs.reduce((sum, s) => sum + (Number(s.totalMarks || s.fullMarks) || 0), 0) || Number(r.totalMarks) || 100;
    const tObt = rawSubs.reduce((sum, s) => sum + (Number(s.marks || s.obtainedMarks) || 0), 0) || Number(r.obtainedMarks || r.marks) || 0;
    const pctVal = tMax > 0 ? ((tObt / tMax) * 100).toFixed(1) : '0.0';
    const grd = Number(pctVal) >= 90 ? 'A+' : Number(pctVal) >= 80 ? 'A' : Number(pctVal) >= 70 ? 'B+' : Number(pctVal) >= 60 ? 'B' : Number(pctVal) >= 50 ? 'C' : Number(pctVal) >= 40 ? 'D' : 'F';

    const passCriteria = Number(r.passingMarks || r.passMarks || 33);
    const isPass = Number(pctVal) >= passCriteria;
    const failedSubs = rawSubs.filter(s => {
      const sMax = Number(s.totalMarks || s.fullMarks) || 100;
      const sObt = Number(s.marks || s.obtainedMarks) || 0;
      const minPass = s.passingMarks != null ? Number(s.passingMarks) : Math.round(sMax * (passCriteria / 100));
      return sObt < minPass;
    });

    let finalStatus = 'PASS';
    if (r.status === 'PROMOTED') {
      finalStatus = 'PROMOTED';
      promotedCount++;
    } else if (failedSubs.length > 0 || !isPass || r.status === 'FAIL') {
      finalStatus = 'FAIL';
      failedCount++;
    } else {
      finalStatus = 'PASS';
      passedCount++;
    }
    totalStudents++;

    const rollNo = String(r.rollNumber || stu.rollNumber || '-');
    const stuId = String(r.studentId || stu.studentId || '-');
    const stuName = String(r.studentName || stu.name || '-');
    const fatherName = String(r.fatherName || stu.fatherName || '-');
    const motherName = String(r.motherName || stu.motherName || '-');
    const cls = String(r.className || r.class || (stu.studentType === 'computer' ? stu.course : (stu.className || '-')));
    const sec = String(r.section || stu.section || 'A');

    const rowH = 6;
    if (idx % 2 === 1) {
      doc.setFillColor(248, 250, 252);
      doc.rect(M, y, contentW, rowH, 'F');
    }
    doc.setDrawColor(226, 232, 240);
    doc.rect(M, y, contentW, rowH);

    doc.setFont('helvetica', 'normal');
    doc.setFontSize(7);
    doc.setTextColor(15, 23, 42);

    let x = M;
    const values = [
      { text: String(idx + 1), align: 'center', bold: false },
      { text: rollNo, align: 'center', bold: true },
      { text: stuId.slice(0, 16), align: 'left', bold: false },
      { text: stuName.slice(0, 24), align: 'left', bold: true },
      { text: fatherName.slice(0, 22), align: 'left', bold: false },
      { text: motherName.slice(0, 20), align: 'left', bold: false },
      { text: cls.slice(0, 12), align: 'center', bold: false },
      { text: sec.slice(0, 6), align: 'center', bold: false },
      { text: String(tMax), align: 'center', bold: false },
      { text: String(tObt), align: 'center', bold: true },
      { text: `${pctVal}%`, align: 'center', bold: false },
      { text: grd, align: 'center', bold: true },
      { text: finalStatus, align: 'center', bold: true, status: finalStatus },
    ];

    values.forEach((v, i) => {
      const col = cols[i];
      if (v.status) {
        if (v.status === 'PROMOTED') doc.setTextColor(180, 83, 9);
        else if (v.status === 'PASS') doc.setTextColor(22, 101, 52);
        else doc.setTextColor(185, 28, 28);
      } else {
        doc.setTextColor(15, 23, 42);
      }
      doc.setFont('helvetica', v.bold ? 'bold' : 'normal');

      const textX = col.align === 'center' ? x + col.w / 2 : (c.align === 'right' ? x + col.w - 1.5 : x + 2);
      doc.text(v.text, textX, y + 4.2, { align: col.align === 'center' ? 'center' : (col.align === 'right' ? 'right' : 'left') });
      x += col.w;
      if (x < W - M) doc.line(x, y, x, y + rowH);
    });

    y += rowH;
  });

  // Check if signatures fit on current page
  if (y > H - 32) {
    doc.addPage();
    pageNum++;
    drawHeader(pageNum);
    y = M + 25;
  } else {
    y += 3;
  }

  // Summary KPI Strip
  const passPct = totalStudents > 0 ? ((passedCount / totalStudents) * 100).toFixed(1) : '0.0';
  doc.setFillColor(241, 245, 249);
  doc.setDrawColor(203, 213, 225);
  doc.rect(M, y, contentW, 6.5, 'FD');
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(7.5);
  doc.setTextColor(15, 23, 42);
  doc.text(`Total Students: ${totalStudents}   |   Passed: ${passedCount}   |   Failed: ${failedCount}   |   Promoted: ${promotedCount}   |   Overall Pass Rate: ${passPct}%`, W / 2, y + 4.5, { align: 'center' });
  y += 16;

  // Signatures
  const signY = Math.max(y, H - M - 12);
  const leftX = M + 35;
  const midX = W / 2;
  const rightX = W - M - 35;

  if (stampData) {
    try {
      doc.addImage(stampData, 'PNG', rightX - 11, signY - 18, 22, 22);
    } catch (e) {}
  }
  if (sigData) {
    try {
      doc.addImage(sigData, 'PNG', rightX - 16, signY - 12, 32, 10);
    } catch (e) {}
  }

  doc.setDrawColor(100, 116, 139);
  doc.setLineWidth(0.4);

  // Left: Class Teacher Sign
  doc.line(leftX - 25, signY, leftX + 25, signY);
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(8);
  doc.setTextColor(30, 41, 59);
  doc.text('Class Teacher Sign', leftX, signY + 4, { align: 'center' });

  // Center: Exam Incharge Sign
  doc.line(midX - 25, signY, midX + 25, signY);
  doc.text('Exam Incharge Sign', midX, signY + 4, { align: 'center' });

  // Right: Principal Sign & Stamp
  doc.line(rightX - 25, signY, rightX + 25, signY);
  doc.text('Principal Sign & Stamp', rightX, signY + 4, { align: 'center' });

  const instShort = (settings.instituteName || settings.schoolName || 'School').replace(/[^a-zA-Z0-9]/g, '_');
  doc.save(`${instShort}_Exam_Results_Tabulation_${new Date().toISOString().split('T')[0]}.pdf`);
}

// ─── Individual & Bulk Exam Result / Marksheet PDF Generator (Matching Web & App 1:1) ───
export async function renderMarksheetPageOnDoc(doc, result = {}, student = {}, settings = {}, preloadedAssets = null) {
  const W = 210, H = 297, M = 11;
  const contentW = W - 2 * M;

  // Assets
  let logoData = preloadedAssets?.logoData;
  let sigData = preloadedAssets?.sigData;
  let stampData = preloadedAssets?.stampData;

  if (!preloadedAssets) {
    const logoSrc = settings.logoUrl || settings.logoPath || settings.logo;
    const sigSrc = settings.principalSignature || settings.signatureUrl || settings.signaturePath || settings.signature;
    const stampSrc = settings.schoolSeal || settings.schoolStamp || settings.stampUrl || settings.sealUrl || settings.stampPath;
    const [l, s, st] = await Promise.all([
      getImageDataUrl(logoSrc),
      getImageDataUrl(sigSrc),
      getImageDataUrl(stampSrc)
    ]);
    logoData = l;
    sigData = s;
    stampData = st;
  }

  // Student Photo
  const photoSrc = student?.photoUrl || student?.photoPath || student?.photo;
  let photoData = null;
  if (photoSrc) {
    try {
      photoData = await getImageDataUrl(photoSrc);
    } catch (e) { }
  }

  // Outer Royal Navy Blue Double Border Box
  doc.setDrawColor(30, 58, 138); // #1E3A8A
  doc.setLineWidth(0.8);
  doc.rect(M, M, contentW, H - 2 * M);
  doc.setLineWidth(0.3);
  doc.rect(M + 1.2, M + 1.2, contentW - 2.4, H - 2 * M - 2.4);

  let y = M + 3;

  // 1. Header Logo (Circular)
  if (logoData) {
    try {
      doc.addImage(logoData, 'PNG', W / 2 - 8, y, 16, 16);
      y += 18;
    } catch (e) {
      console.warn('Failed to embed logo in result PDF:', e);
      y += 3;
    }
  } else {
    y += 3;
  }

  // 2. School Name Header
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(15);
  doc.setTextColor(30, 58, 138);
  const schoolName = (settings.instituteName || settings.schoolName || 'MISSION NAVODAYA PUBLIC SCHOOL MORA').toUpperCase();
  doc.text(schoolName, W / 2, y, { align: 'center' });
  y += 5;

  // 3. Subtitle (Address, Affiliation, Helpline)
  doc.setFont('helvetica', 'normal');
  doc.setFontSize(7.5);
  doc.setTextColor(75, 85, 99);
  const addr = settings.address || 'MORA BHAGWANPUR HAT (SIWAN)';
  const aff = settings.affiliationNumber ? `Affiliation: ${settings.affiliationNumber}` : 'Affiliation: 00';
  const mob = settings.mobile ? `Helpline: ${settings.mobile}` : 'Helpline: 8603481865';
  doc.text(`${addr} • ${aff} • ${mob}`, W / 2, y, { align: 'center' });
  y += 4.5;

  // 4. Royal Navy Blue Title Banner with Golden Text
  const pillW = 96, pillH = 6.2;
  doc.setFillColor(30, 58, 138);
  doc.roundedRect(W / 2 - pillW / 2, y, pillW, pillH, 3, 3, 'F');
  doc.setTextColor(255, 215, 0); // #FFD700
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(8.5);
  doc.text('OFFICIAL REPORT CARD & STATEMENT OF MARKS', W / 2, y + 4.3, { align: 'center' });
  y += 9.5;

  // 5. Exam Title
  doc.setTextColor(15, 23, 42);
  doc.setFontSize(10.5);
  doc.setFont('helvetica', 'bold');
  doc.text(String(result.examName || 'Mid Term Examination 2026'), W / 2, y, { align: 'center' });
  y += 5.5;

  // 6. Student Particulars Profile Card
  const stuCardX = M + 3;
  const stuCardW = contentW - 6;
  const stuCardH = 26;
  doc.setFillColor(248, 250, 252);
  doc.setDrawColor(203, 213, 225);
  doc.setLineWidth(0.4);
  doc.roundedRect(stuCardX, y, stuCardW, stuCardH, 2, 2, 'FD');

  // Student Photo box on left
  const photoW = 16, photoH = 20;
  const photoX = stuCardX + 3.5, photoY = y + 3;
  if (photoData) {
    try {
      doc.addImage(photoData, 'JPEG', photoX, photoY, photoW, photoH);
      doc.setDrawColor(203, 213, 225);
      doc.rect(photoX, photoY, photoW, photoH);
    } catch (e) {
      doc.setFillColor(255, 255, 255);
      doc.roundedRect(photoX, photoY, photoW, photoH, 1, 1, 'FD');
      doc.setFont('helvetica', 'bold');
      doc.setFontSize(6.5);
      doc.setTextColor(148, 163, 184);
      doc.text('PHOTO', photoX + photoW / 2, photoY + photoH / 2 + 1, { align: 'center' });
    }
  } else {
    doc.setFillColor(255, 255, 255);
    doc.roundedRect(photoX, photoY, photoW, photoH, 1, 1, 'FD');
    doc.setFont('helvetica', 'bold');
    doc.setFontSize(6.5);
    doc.setTextColor(148, 163, 184);
    doc.text('PHOTO', photoX + photoW / 2, photoY + photoH / 2 + 1, { align: 'center' });
  }

  // Student details beside photo
  const studentName = student?.name || result?.studentName || '-';
  const fatherName = student?.fatherName || '-';
  const classStr = student?.studentType === 'school' ? `Class ${student?.className || ''} - ${student?.section || 'A'}` : (student?.course || result?.className || result?.class || 'General');
  const stuId = student?.studentId || result?.studentId || '—';
  const rollNo = student?.rollNumber || result?.rollNumber || '01';
  const sessionStr = student?.session || settings.currentSession || '2026-27';

  // Middle info
  const infoX = photoX + photoW + 4;
  doc.setFontSize(6.5);
  doc.setFont('helvetica', 'bold');
  doc.setTextColor(100, 116, 139);
  doc.text('STUDENT PROFILE', infoX, y + 5.5);

  doc.setFontSize(10.5);
  doc.setFont('helvetica', 'bold');
  doc.setTextColor(30, 58, 138);
  doc.text(String(studentName), infoX, y + 10.5);

  doc.setFontSize(7.5);
  doc.setFont('helvetica', 'normal');
  doc.setTextColor(71, 85, 105);
  doc.text("Father's Name :", infoX, y + 15.5);
  doc.setFont('helvetica', 'bold');
  doc.setTextColor(30, 41, 59);
  doc.text(String(fatherName), infoX + 22, y + 15.5);

  doc.setFont('helvetica', 'normal');
  doc.setTextColor(71, 85, 105);
  doc.text("Class / Course :", infoX, y + 21);
  doc.setFont('helvetica', 'bold');
  doc.setTextColor(30, 58, 138);
  doc.text(String(classStr), infoX + 22, y + 21);

  // Right column: ID, Roll, Session
  const metaRightX = stuCardX + stuCardW - 4;
  doc.setFont('helvetica', 'normal');
  doc.setFontSize(7);
  doc.setTextColor(100, 116, 139);
  doc.text('Student ID', metaRightX, y + 5.5, { align: 'right' });
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(8.5);
  doc.setTextColor(30, 58, 138);
  doc.text(String(stuId), metaRightX, y + 9.5, { align: 'right' });

  doc.setFont('helvetica', 'normal');
  doc.setFontSize(7);
  doc.setTextColor(100, 116, 139);
  doc.text('Roll Number', metaRightX, y + 14.5, { align: 'right' });
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(11);
  doc.setTextColor(15, 23, 42);
  doc.text(String(rollNo).padStart(2, '0'), metaRightX, y + 19, { align: 'right' });

  doc.setFont('helvetica', 'normal');
  doc.setFontSize(7);
  doc.setTextColor(100, 116, 139);
  doc.text(`Session: ${sessionStr}`, metaRightX, y + 23.5, { align: 'right' });

  y += stuCardH + 4;

  // 7. Marks Table
  const rawSubjects = Array.isArray(result.subjects) && result.subjects.length > 0
    ? result.subjects
    : [{ subjectName: result.subject || 'General', totalMarks: result.totalMarks || 100, marks: result.marks || 0 }];

  const hasDetailedBreakdown = rawSubjects.some(
    s => (Number(s.theoryMarks) > 0 || Number(s.practicalMarks) > 0 || Number(s.internalMarks) > 0)
  );

  const totalMax = rawSubjects.reduce((sum, s) => sum + (Number(s.totalMarks) || 0), 0);
  const totalObt = rawSubjects.reduce((sum, s) => sum + (Number(s.marks) || 0), 0);
  const pct = totalMax > 0 ? ((totalObt / totalMax) * 100).toFixed(1) : '0.0';
  const overallGrade = Number(pct) >= 90 ? 'A+' : Number(pct) >= 80 ? 'A' : Number(pct) >= 70 ? 'B+' : Number(pct) >= 60 ? 'B' : Number(pct) >= 50 ? 'C' : Number(pct) >= 40 ? 'D' : 'F';
  const passingCriteria = Number(result.passingMarks || result.passMarks || 33);
  const isPass = Number(pct) >= passingCriteria;

  const failedSubjects = rawSubjects.filter(s => {
    const sMax = Number(s.totalMarks) || 100;
    const sObt = Number(s.marks) || 0;
    const minPass = s.passingMarks != null ? Number(s.passingMarks) : Math.round(sMax * (passingCriteria / 100));
    return sObt < minPass;
  });
  const failCount = failedSubjects.length;

  let finalStatus = 'PASS';
  if (result.status === 'PROMOTED') finalStatus = 'PROMOTED';
  else if (failCount > 0 || !isPass || result.status === 'FAIL') finalStatus = 'FAIL';
  else finalStatus = 'PASS';

  const division = !isPass ? 'Needs Improvement' : (Number(pct) >= 60 ? '1st Division' : Number(pct) >= 45 ? '2nd Division' : '3rd Division');

  const tableX = M + 3;
  const tableW = contentW - 6;
  const rowH = 6.2;

  if (hasDetailedBreakdown) {
    // 8 COLUMNS: S.N. | Subject | Theory | Pract. | Int. | Max | Obt. | Grade
    const colSN = 12;
    const colTh = 18;
    const colPr = 18;
    const colIn = 18;
    const colMax = 20;
    const colObt = 22;
    const colGrd = 18;
    const colSub = tableW - (colSN + colTh + colPr + colIn + colMax + colObt + colGrd);

    // Header
    doc.setFillColor(30, 58, 138);
    doc.rect(tableX, y, tableW, 6.5, 'F');
    doc.setTextColor(255, 255, 255);
    doc.setFont('helvetica', 'bold');
    doc.setFontSize(7.5);

    let hx = tableX;
    doc.text('S.No', hx + colSN / 2, y + 4.5, { align: 'center' }); hx += colSN;
    doc.text('Subject Name', hx + 3, y + 4.5); hx += colSub;
    doc.text('Theory', hx + colTh / 2, y + 4.5, { align: 'center' }); hx += colTh;
    doc.text('Practical', hx + colPr / 2, y + 4.5, { align: 'center' }); hx += colPr;
    doc.text('Internal', hx + colIn / 2, y + 4.5, { align: 'center' }); hx += colIn;
    doc.text('Max Marks', hx + colMax / 2, y + 4.5, { align: 'center' }); hx += colMax;
    doc.text('Marks Obtained', hx + colObt / 2, y + 4.5, { align: 'center' }); hx += colObt;
    doc.text('Grade', hx + colGrd / 2, y + 4.5, { align: 'center' });
    y += 6.5;

    // Rows
    rawSubjects.forEach((sub, idx) => {
      const sMax = Number(sub.totalMarks) || 0;
      const sObt = Number(sub.marks) || 0;
      const minPass = sub.passingMarks != null ? Number(sub.passingMarks) : Math.round(sMax * (passingCriteria / 100));
      const subPass = sObt >= minPass;
      const sPct = sMax > 0 ? (sObt / sMax) * 100 : 0;
      const sGrd = !subPass ? 'F' : sPct >= 90 ? 'A+' : sPct >= 80 ? 'A' : sPct >= 70 ? 'B+' : sPct >= 60 ? 'B' : sPct >= 50 ? 'C' : 'D';

      if (idx % 2 === 1) {
        doc.setFillColor(248, 250, 252);
        doc.rect(tableX, y, tableW, rowH, 'F');
      }
      doc.setDrawColor(203, 213, 225);
      doc.rect(tableX, y, tableW, rowH);

      let lx = tableX + colSN;
      doc.line(lx, y, lx, y + rowH); lx += colSub;
      doc.line(lx, y, lx, y + rowH); lx += colTh;
      doc.line(lx, y, lx, y + rowH); lx += colPr;
      doc.line(lx, y, lx, y + rowH); lx += colIn;
      doc.line(lx, y, lx, y + rowH); lx += colMax;
      doc.line(lx, y, lx, y + rowH); lx += colObt;
      doc.line(lx, y, lx, y + rowH);

      doc.setFont('helvetica', 'normal');
      doc.setFontSize(7.5);
      doc.setTextColor(50, 50, 50);

      let rx = tableX;
      doc.text(String(idx + 1), rx + colSN / 2, y + 4.3, { align: 'center' }); rx += colSN;
      doc.setFont('helvetica', 'bold');
      doc.text(String(sub.subjectName || 'Subject'), rx + 3, y + 4.3); rx += colSub;
      doc.setFont('helvetica', 'normal');
      doc.text(String(sub.theoryMarks != null ? sub.theoryMarks : '-'), rx + colTh / 2, y + 4.3, { align: 'center' }); rx += colTh;
      doc.text(String(sub.practicalMarks != null ? sub.practicalMarks : '-'), rx + colPr / 2, y + 4.3, { align: 'center' }); rx += colPr;
      doc.text(String(sub.internalMarks != null ? sub.internalMarks : '-'), rx + colIn / 2, y + 4.3, { align: 'center' }); rx += colIn;
      doc.text(String(sMax), rx + colMax / 2, y + 4.3, { align: 'center' }); rx += colMax;
      doc.setFont('helvetica', 'bold');
      doc.setTextColor(subPass ? 30 : 180, subPass ? 58 : 20, subPass ? 138 : 20);
      doc.text(String(sObt), rx + colObt / 2, y + 4.3, { align: 'center' }); rx += colObt;
      doc.setTextColor(50, 50, 50);
      doc.text(sGrd, rx + colGrd / 2, y + 4.3, { align: 'center' });

      y += rowH;
    });

    // Grand Total Row
    const prefixW = colSN + colSub + colTh + colPr + colIn;
    doc.setFillColor(238, 242, 255);
    doc.rect(tableX, y, tableW, rowH + 0.5, 'F');
    doc.setDrawColor(30, 58, 138);
    doc.rect(tableX, y, tableW, rowH + 0.5);
    doc.line(tableX + prefixW, y, tableX + prefixW, y + rowH + 0.5);
    doc.line(tableX + prefixW + colMax, y, tableX + prefixW + colMax, y + rowH + 0.5);
    doc.line(tableX + prefixW + colMax + colObt, y, tableX + prefixW + colMax + colObt, y + rowH + 0.5);

    doc.setFont('helvetica', 'bold');
    doc.setFontSize(8);
    doc.setTextColor(30, 58, 138);
    doc.text('GRAND TOTAL', tableX + prefixW / 2, y + 4.7, { align: 'center' });
    doc.text(String(totalMax), tableX + prefixW + colMax / 2, y + 4.7, { align: 'center' });
    doc.text(String(totalObt), tableX + prefixW + colMax + colObt / 2, y + 4.7, { align: 'center' });
    doc.text(overallGrade, tableX + prefixW + colMax + colObt + colGrd / 2, y + 4.7, { align: 'center' });
    y += rowH + 4.5;

  } else {
    // 5 COLUMNS: S.No | Subject Name | Max Marks | Marks Obtained | Grade (App Matching)
    const colSN = 14;
    const colMax = 28;
    const colObt = 34;
    const colGrd = 26;
    const colSub = tableW - (colSN + colMax + colObt + colGrd);

    // Table Header
    doc.setFillColor(30, 58, 138);
    doc.rect(tableX, y, tableW, 6.5, 'F');
    doc.setTextColor(255, 255, 255);
    doc.setFont('helvetica', 'bold');
    doc.setFontSize(8);

    doc.text('S.No', tableX + colSN / 2, y + 4.5, { align: 'center' });
    doc.text('Subject Name', tableX + colSN + 3, y + 4.5);
    doc.text('Max Marks', tableX + colSN + colSub + colMax / 2, y + 4.5, { align: 'center' });
    doc.text('Marks Obtained', tableX + colSN + colSub + colMax + colObt / 2, y + 4.5, { align: 'center' });
    doc.text('Grade', tableX + colSN + colSub + colMax + colObt + colGrd / 2, y + 4.5, { align: 'center' });
    y += 6.5;

    // Table Rows
    rawSubjects.forEach((sub, idx) => {
      const sMax = Number(sub.totalMarks) || 0;
      const sObt = Number(sub.marks) || 0;
      const minPass = sub.passingMarks != null ? Number(sub.passingMarks) : Math.round(sMax * (passingCriteria / 100));
      const subPass = sObt >= minPass;
      const sPct = sMax > 0 ? (sObt / sMax) * 100 : 0;
      const sGrd = !subPass ? 'F' : sPct >= 90 ? 'A+' : sPct >= 80 ? 'A' : sPct >= 70 ? 'B+' : sPct >= 60 ? 'B' : sPct >= 50 ? 'C' : 'D';

      if (idx % 2 === 1) {
        doc.setFillColor(248, 250, 252);
        doc.rect(tableX, y, tableW, rowH, 'F');
      }
      doc.setDrawColor(203, 213, 225);
      doc.rect(tableX, y, tableW, rowH);
      doc.line(tableX + colSN, y, tableX + colSN, y + rowH);
      doc.line(tableX + colSN + colSub, y, tableX + colSN + colSub, y + rowH);
      doc.line(tableX + colSN + colSub + colMax, y, tableX + colSN + colSub + colMax, y + rowH);
      doc.line(tableX + colSN + colSub + colMax + colObt, y, tableX + colSN + colSub + colMax + colObt, y + rowH);

      doc.setFont('helvetica', 'normal');
      doc.setFontSize(8);
      doc.setTextColor(50, 50, 50);

      doc.text(String(idx + 1), tableX + colSN / 2, y + 4.3, { align: 'center' });
      doc.setFont('helvetica', 'bold');
      doc.setTextColor(30, 41, 59);
      doc.text(String(sub.subjectName || 'Subject'), tableX + colSN + 3, y + 4.3);
      doc.setFont('helvetica', 'normal');
      doc.setTextColor(71, 85, 105);
      doc.text(String(sMax), tableX + colSN + colSub + colMax / 2, y + 4.3, { align: 'center' });
      doc.setFont('helvetica', 'bold');
      doc.setTextColor(15, 23, 42);
      doc.text(String(sObt), tableX + colSN + colSub + colMax + colObt / 2, y + 4.3, { align: 'center' });
      doc.setTextColor(subPass ? 30 : 15, subPass ? 58 : 23, subPass ? 138 : 42);
      doc.text(sGrd, tableX + colSN + colSub + colMax + colObt + colGrd / 2, y + 4.3, { align: 'center' });

      y += rowH;
    });

    // Grand Total Row
    doc.setFillColor(238, 242, 255);
    doc.rect(tableX, y, tableW, rowH + 0.5, 'F');
    doc.setDrawColor(30, 58, 138);
    doc.rect(tableX, y, tableW, rowH + 0.5);
    doc.line(tableX + colSN + colSub, y, tableX + colSN + colSub, y + rowH + 0.5);
    doc.line(tableX + colSN + colSub + colMax, y, tableX + colSN + colSub + colMax, y + rowH + 0.5);
    doc.line(tableX + colSN + colSub + colMax + colObt, y, tableX + colSN + colSub + colMax + colObt, y + rowH + 0.5);

    doc.setFont('helvetica', 'bold');
    doc.setFontSize(8);
    doc.setTextColor(30, 58, 138);
    doc.text('GRAND TOTAL', tableX + (colSN + colSub) / 2, y + 4.7, { align: 'center' });
    doc.text(String(totalMax), tableX + colSN + colSub + colMax / 2, y + 4.7, { align: 'center' });
    doc.setTextColor(15, 23, 42);
    doc.text(String(totalObt), tableX + colSN + colSub + colMax + colObt / 2, y + 4.7, { align: 'center' });
    doc.setTextColor(30, 58, 138);
    doc.text(overallGrade, tableX + colSN + colSub + colMax + colObt + colGrd / 2, y + 4.7, { align: 'center' });

    y += rowH + 4.5;
  }

  // 8. Performance Summary Card (App Matching)
  const sumH = 10.5;
  doc.setFillColor(248, 250, 252);
  doc.setDrawColor(30, 58, 138);
  doc.setLineWidth(0.4);
  doc.roundedRect(tableX, y, tableW, sumH, 2, 2, 'FD');

  doc.setFontSize(8);
  doc.setFont('helvetica', 'normal');
  doc.setTextColor(100, 116, 139);
  doc.text('Percentage: ', tableX + 5, y + 6.8);
  doc.setFont('helvetica', 'bold');
  doc.setTextColor(15, 23, 42);
  doc.text(`${pct}%`, tableX + 22, y + 6.8);

  doc.setFont('helvetica', 'normal');
  doc.setTextColor(100, 116, 139);
  doc.text('Overall Grade: ', tableX + 42, y + 6.8);
  doc.setFont('helvetica', 'bold');
  doc.setTextColor(30, 58, 138);
  doc.text(overallGrade, tableX + 62, y + 6.8);

  doc.setFont('helvetica', 'normal');
  doc.setTextColor(100, 116, 139);
  doc.text('Division: ', tableX + 74, y + 6.8);
  doc.setFont('helvetica', 'bold');
  doc.setTextColor(15, 23, 42);
  doc.text(division, tableX + 88, y + 6.8);

  // Status Badge Pill
  const pillStatusW = 60;
  const pillStatusX = tableX + tableW - pillStatusW - 3;
  if (finalStatus === 'PROMOTED') {
    doc.setFillColor(254, 243, 199);
    doc.setDrawColor(245, 158, 11);
    doc.roundedRect(pillStatusX, y + 2, pillStatusW, 6.5, 3, 3, 'FD');
    doc.setTextColor(180, 83, 9);
    doc.setFont('helvetica', 'bold');
    doc.setFontSize(7.5);
    doc.text('STATUS: PROMOTED', pillStatusX + pillStatusW / 2, y + 6.2, { align: 'center' });
  } else if (finalStatus === 'PASS') {
    doc.setFillColor(220, 252, 231);
    doc.setDrawColor(34, 197, 94);
    doc.roundedRect(pillStatusX, y + 2, pillStatusW, 6.5, 3, 3, 'FD');
    doc.setTextColor(22, 101, 52);
    doc.setFont('helvetica', 'bold');
    doc.setFontSize(7.5);
    doc.text('STATUS: PASSED', pillStatusX + pillStatusW / 2, y + 6.2, { align: 'center' });
  } else {
    doc.setFillColor(254, 226, 226);
    doc.setDrawColor(239, 68, 68);
    doc.roundedRect(pillStatusX, y + 2, pillStatusW, 6.5, 3, 3, 'FD');
    doc.setTextColor(153, 27, 27);
    doc.setFont('helvetica', 'bold');
    doc.setFontSize(7.5);
    doc.text('STATUS: NEEDS IMPROVEMENT', pillStatusX + pillStatusW / 2, y + 6.2, { align: 'center' });
  }
  y += sumH + 3.5;

  // 9. Faculty / Teacher Remarks
  const remH = 9.5;
  doc.setFillColor(248, 250, 252);
  doc.setDrawColor(226, 232, 240);
  doc.roundedRect(tableX, y, tableW, remH, 1.5, 1.5, 'FD');

  doc.setFont('helvetica', 'bold');
  doc.setFontSize(6.5);
  doc.setTextColor(100, 116, 139);
  doc.text('FACULTY / TEACHER REMARKS:', tableX + 3.5, y + 3.5);

  doc.setFont('helvetica', 'normal');
  doc.setFontSize(7.5);
  doc.setTextColor(51, 65, 85);
  const defaultRemarks = isPass
    ? 'Excellent academic performance and consistent participation in class activities.'
    : finalStatus === 'PROMOTED'
    ? 'Promoted to the next standard with advisory for subject enhancement.'
    : 'Needs focused attention in compartment subject(s).';
  const displayRemarks = result.remarks || defaultRemarks;
  doc.text(`"${displayRemarks}"`, tableX + 3.5, y + 7.2);
  y += remH + 3;

  // 10. Grading Scale Legend
  const scaleH = 5.5;
  doc.setFillColor(241, 245, 249);
  doc.setDrawColor(226, 232, 240);
  doc.roundedRect(tableX, y, tableW, scaleH, 1.5, 1.5, 'FD');

  doc.setFont('helvetica', 'normal');
  doc.setFontSize(6.5);
  doc.setTextColor(71, 85, 105);
  doc.text(
    'GRADING SCALE:   A+ (90-100%)   •   A (80-89%)   •   B+ (70-79%)   •   B (60-69%)   •   C (50-59%)   •   D (33-49%)   •   F (<33%)',
    tableX + tableW / 2,
    y + 3.8,
    { align: 'center' }
  );

  // 11. Signatures & QR Code (Positioned consistently at bottom)
  const signY = H - M - 19;

  // Class Teacher Signature
  doc.setDrawColor(30, 58, 138);
  doc.setLineWidth(0.4);
  doc.line(tableX + 4, signY, tableX + 44, signY);
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(7.5);
  doc.setTextColor(51, 65, 85);
  doc.text("CLASS TEACHER'S SIGN", tableX + 24, signY + 4, { align: 'center' });

  // Center: QR Code with "Verified Marksheet"
  const qrX = W / 2 - 8;
  const qrY = signY - 17;
  const qrSize = 16;
  try {
    const qrData = `RESULT:${result.examName || 'Exam'}|STUDENT:${student?.studentId || result?.studentId}|PCT:${pct}%|GRADE:${overallGrade}|STATUS:${finalStatus}`;
    const qrUrl = `https://api.qrserver.com/v1/create-qr-code/?size=100x100&data=${encodeURIComponent(qrData)}`;
    const qrImgData = await getImageDataUrl(qrUrl);
    if (qrImgData) {
      doc.addImage(qrImgData, 'PNG', qrX, qrY, qrSize, qrSize);
      doc.setDrawColor(203, 213, 225);
      doc.rect(qrX, qrY, qrSize, qrSize);
    } else {
      doc.setDrawColor(203, 213, 225);
      doc.setFillColor(255, 255, 255);
      doc.roundedRect(qrX, qrY, qrSize, qrSize, 1, 1, 'FD');
      doc.setFont('helvetica', 'bold');
      doc.setFontSize(6);
      doc.setTextColor(100, 116, 139);
      doc.text('QR CODE', qrX + qrSize / 2, qrY + qrSize / 2 + 1, { align: 'center' });
    }
  } catch (e) {
    doc.setDrawColor(203, 213, 225);
    doc.setFillColor(255, 255, 255);
    doc.roundedRect(qrX, qrY, qrSize, qrSize, 1, 1, 'FD');
  }
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(6.5);
  doc.setTextColor(100, 116, 139);
  doc.text('VERIFIED MARKSHEET', qrX + qrSize / 2, signY + 4, { align: 'center' });

  // Right: Principal Sign & Stamp
  const rightSignCenterX = tableX + tableW - 25;
  const stampSize = 18;
  const sigW = 34, sigH = 12;

  // Stamp
  if (stampData) {
    try {
      doc.addImage(stampData, 'PNG', rightSignCenterX - stampSize / 2, signY - stampSize - 0.5, stampSize, stampSize);
    } catch (e) { }
  }

  // Signature layered over stamp
  if (sigData) {
    try {
      doc.addImage(sigData, 'PNG', rightSignCenterX - sigW / 2, signY - sigH - 0.5, sigW, sigH);
    } catch (e) { }
  }

  doc.line(tableX + tableW - 46, signY, tableX + tableW - 4, signY);
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(7.5);
  doc.setTextColor(51, 65, 85);
  doc.text('PRINCIPAL SIGN', rightSignCenterX, signY + 4, { align: 'center' });

  // 12. Bottom Footer Note
  doc.setFont('helvetica', 'normal');
  doc.setFontSize(6.5);
  doc.setTextColor(148, 163, 184);
  const todayStr = new Date().toLocaleDateString('en-GB');
  doc.text(`Generated on ${todayStr} • Official Academic Record of ${schoolName}`, W / 2, H - M - 2.5, { align: 'center' });
}

// ─── Single Marksheet PDF Document ──────────────────────────────────────────
export async function createSingleResultPDFDoc(result = {}, student = {}, settings = {}) {
  const doc = new jsPDF({ orientation: 'portrait', unit: 'mm', format: 'a4' });
  await renderMarksheetPageOnDoc(doc, result, student, settings);
  return doc;
}

// ─── Bulk Multi-Page Marksheets PDF Document ────────────────────────────────
export async function createBulkResultMarksheetsPDFDoc(results = [], students = [], settings = {}) {
  const doc = new jsPDF({ orientation: 'portrait', unit: 'mm', format: 'a4' });

  // Preload common assets once for high performance
  const logoSrc = settings.logoUrl || settings.logoPath || settings.logo;
  const sigSrc = settings.principalSignature || settings.signatureUrl || settings.signaturePath || settings.signature;
  const stampSrc = settings.schoolSeal || settings.schoolStamp || settings.stampUrl || settings.sealUrl || settings.stampPath;
  const [logoData, sigData, stampData] = await Promise.all([
    getImageDataUrl(logoSrc),
    getImageDataUrl(sigSrc),
    getImageDataUrl(stampSrc)
  ]);
  const preloadedAssets = { logoData, sigData, stampData };

  const findStudentMatch = (r) => {
    if (!r) return null;
    const rId = String(r.studentId || '').trim().toLowerCase();
    const rName = String(r.studentName || '').trim().toLowerCase();
    return students.find(s => {
      if (rId) {
        if (s.id && String(s.id).trim().toLowerCase() === rId) return true;
        if (s.studentId && String(s.studentId).trim().toLowerCase() === rId) return true;
        if (s.admissionNumber && String(s.admissionNumber).trim().toLowerCase() === rId) return true;
        if (s.admissionNo && String(s.admissionNo).trim().toLowerCase() === rId) return true;
      }
      if (rName && s.name && String(s.name).trim().toLowerCase() === rName) return true;
      return false;
    }) || null;
  };

  for (let i = 0; i < results.length; i++) {
    if (i > 0) doc.addPage('a4', 'portrait');
    const r = results[i];
    const s = findStudentMatch(r);
    await renderMarksheetPageOnDoc(doc, r, s, settings, preloadedAssets);
  }

  return doc;
}

// ─── Export Single Result PDF ────────────────────────────────────────────────


// ─── Single Student Official Admit Card PDF Generator (Exact 1-Page A4) ──────
export async function createSingleAdmitCardPDFDoc(student = {}, settings = {}, timetable = null, examTitle = 'ANNUAL EXAMINATION 2026') {
  const doc = new jsPDF({ orientation: 'portrait', unit: 'mm', format: 'a4' });
  const W = 210, H = 297, M = 10;
  const cardW = W - 2 * M;
  const cardH = 277;

  const schoolName = (settings.instituteName || settings.schoolName || 'MISSION NAVODAYA').toUpperCase();
  const session = settings.currentSession || settings.academicYear || '2026-27';
  const address = settings.address || 'Mora Mairi, BagwaanPur hat ,Siwan,Bihar 841507';

  const logoSrc = settings.logoUrl || settings.logoPath || settings.logo;
  const sigSrc = settings.principalSignature || settings.signatureUrl || settings.signaturePath || settings.signature;
  const stampSrc = settings.schoolStamp || settings.stampUrl || settings.sealUrl;

  const [logoData, sigData, stampData, photoData] = await Promise.all([
    getImageDataUrl(logoSrc),
    getImageDataUrl(sigSrc),
    getImageDataUrl(stampSrc),
    getImageDataUrl(student.photoUrl || student.photoPath)
  ]);

  // Outer rounded blue border
  doc.setDrawColor(30, 58, 138); // #1E3A8A
  doc.setLineWidth(1.2);
  doc.roundedRect(M, M, cardW, cardH, 4, 4);

  // Header Top Banner
  const bannerH = 26;
  doc.setFillColor(30, 58, 138);
  doc.roundedRect(M + 1, M + 1, cardW - 2, bannerH, 3, 3, 'F');

  // Logo inside banner
  if (logoData) {
    try {
      doc.setFillColor(255, 255, 255);
      doc.roundedRect(M + 4, M + 4, 18, 18, 2, 2, 'F');
      doc.addImage(logoData, 'PNG', M + 5, M + 5, 16, 16);
    } catch (e) { }
  }

  // Header School Name & Address
  const headerTextX = logoData ? M + 26 : M + 8;
  doc.setTextColor(255, 255, 255);
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(14);
  doc.text(schoolName, headerTextX, M + 12);

  doc.setTextColor(255, 255, 255);
  doc.setFont('helvetica', 'normal');
  doc.setFontSize(8);
  doc.text(address, headerTextX, M + 18);

  // Right side of banner: Session & ADMIT CARD
  doc.setTextColor(255, 215, 0); // Gold
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(8.5);
  doc.text(`SESSION: ${session}`, M + cardW - 6, M + 11, { align: 'right' });

  doc.setTextColor(255, 255, 255);
  doc.setFontSize(11);
  doc.text('ADMIT CARD', M + cardW - 6, M + 18, { align: 'right' });

  // Centered Exam Title Pill Badge
  const pillTop = M + bannerH + 4;
  const pillW = 86;
  const pillH = 9;
  const pillX = (W - pillW) / 2;

  doc.setDrawColor(30, 58, 138);
  doc.setLineWidth(0.8);
  doc.setFillColor(255, 255, 255);
  doc.roundedRect(pillX, pillTop, pillW, pillH, 2, 2, 'FD');

  doc.setTextColor(30, 58, 138);
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(11);
  doc.text(String(examTitle || 'ANNUAL EXAMINATION 2026').toUpperCase(), W / 2, pillTop + 6.5, { align: 'center' });

  // Middle Info Section: Photo, Student Details, QR Code
  const infoTop = pillTop + pillH + 6;
  const photoW = 34;
  const photoH = 42;
  const photoX = M + 6;
  const photoY = infoTop;

  // Student Photo Box
  if (photoData) {
    try {
      doc.addImage(photoData, 'JPEG', photoX, photoY, photoW, photoH);
      doc.setDrawColor(180, 180, 180);
      doc.rect(photoX, photoY, photoW, photoH);
    } catch (e) {
      doc.setFillColor(243, 244, 246);
      doc.rect(photoX, photoY, photoW, photoH, 'F');
      doc.setDrawColor(209, 213, 219);
      doc.rect(photoX, photoY, photoW, photoH);
      doc.setTextColor(156, 163, 175);
      doc.setFont('helvetica', 'bold');
      doc.setFontSize(8);
      doc.text('PASSPORT PHOTO', photoX + photoW / 2, photoY + photoH / 2, { align: 'center' });
    }
  } else {
    doc.setFillColor(243, 244, 246);
    doc.rect(photoX, photoY, photoW, photoH, 'F');
    doc.setDrawColor(209, 213, 219);
    doc.rect(photoX, photoY, photoW, photoH);
    doc.setTextColor(156, 163, 175);
    doc.setFont('helvetica', 'bold');
    doc.setFontSize(8);
    doc.text('PASSPORT PHOTO', photoX + photoW / 2, photoY + photoH / 2, { align: 'center' });
  }

  // Student Details
  const detailX = photoX + photoW + 8;
  const aadhaar = student.aadhaarNumber || student.aadharNumber || student.aadhaar || 'NOT-LINKED';
  const dobStr = student.dob ? (typeof student.dob === 'string' ? student.dob.slice(0, 10) : '01/01/2010') : '01/01/2010';
  const genderStr = student.gender || 'Male';

  const rows = [
    ['STUDENT NAME:', (student.name || '').toUpperCase()],
    ['ROLL NO / ADM NO:', `${student.rollNumber || student.id || 'N/A'}  /  ${student.admissionNumber || student.id || 'N/A'}`],
    ['CLASS & SECTION:', student.studentType === 'school' ? `Class ${student.className || ''} - ${student.section || 'A'}` : (student.course || '—')],
    ['FATHER\'S NAME:', (student.fatherName || '-').toUpperCase()],
    ['DOB / GENDER:', `${dobStr}  /  ${genderStr}`],
    ['AADHAAR NUMBER:', aadhaar]
  ];

  let curY = infoTop + 6;
  doc.setFontSize(9.5);
  rows.forEach(([label, val], rIdx) => {
    doc.setTextColor(60, 60, 60);
    doc.setFont('helvetica', 'bold');
    doc.text(label, detailX, curY);

    if (rIdx === 5) {
      doc.setTextColor(37, 99, 235);
    } else {
      doc.setTextColor(15, 23, 42);
    }
    doc.setFont('helvetica', rIdx === 0 ? 'bold' : 'normal');
    doc.text(val, detailX + 44, curY);

    curY += 6.8;
  });

  // QR Code on right
  const qrX = M + cardW - 30;
  const qrY = infoTop + 4;
  const qrSize = 24;
  try {
    const qrData = `STUDENT ADMIT CARD | Name: ${student.name} | Roll: ${student.rollNumber || 'N/A'} | Class: ${student.className || ''} | Aadhaar: ${aadhaar}`;
    const qrUrl = `https://api.qrserver.com/v1/create-qr-code/?size=100x100&data=${encodeURIComponent(qrData)}`;
    const qrImgData = await getImageDataUrl(qrUrl);
    if (qrImgData) {
      doc.addImage(qrImgData, 'PNG', qrX, qrY, qrSize, qrSize);
      doc.setDrawColor(200, 200, 200);
      doc.rect(qrX - 1, qrY - 1, qrSize + 2, qrSize + 2);
    }
  } catch (e) { }

  // Section Title: EXAMINATION SCHEDULE & TIME TABLE
  const tableTitleY = infoTop + photoH + 10;
  doc.setTextColor(30, 58, 138);
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(10.5);
  doc.text('EXAMINATION SCHEDULE & TIME TABLE', M + 6, tableTitleY);

  // Schedule Table
  const tableTop = tableTitleY + 3;
  const colW = [28, 48, 54, cardW - 12 - 28 - 48 - 54];

  // Table Header
  doc.setFillColor(243, 244, 246);
  doc.rect(M + 6, tableTop, cardW - 12, 7.5, 'F');
  doc.setDrawColor(209, 213, 219);
  doc.rect(M + 6, tableTop, cardW - 12, 7.5);

  doc.setTextColor(17, 24, 39);
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(8.5);
  doc.text('DATE', M + 9, tableTop + 5);
  doc.text('SUBJECT', M + 6 + colW[0] + 3, tableTop + 5);
  doc.text('TIMING', M + 6 + colW[0] + colW[1] + 3, tableTop + 5);
  doc.text('INVIGILATOR SIGN', M + 6 + colW[0] + colW[1] + colW[2] + 8, tableTop + 5);

  // Schedule items fallback
  const scheduleItems = (Array.isArray(timetable) && timetable.length > 0)
    ? timetable
    : [
        { day: '15/03/2026', subject: 'Mathematics', timing: '09:30 AM - 12:30 PM' },
        { day: '17/03/2026', subject: 'Science', timing: '09:30 AM - 12:30 PM' },
        { day: '19/03/2026', subject: 'Social Studies', timing: '09:30 AM - 12:30 PM' },
        { day: '21/03/2026', subject: 'English', timing: '09:30 AM - 12:30 PM' },
        { day: '23/03/2026', subject: 'Hindi', timing: '09:30 AM - 12:30 PM' },
        { day: '25/03/2026', subject: 'Computer', timing: '09:30 AM - 12:30 PM' },
      ];

  // Table Rows
  let rowY = tableTop + 7.5;
  scheduleItems.forEach((t, i) => {
    doc.setFillColor(i % 2 === 0 ? 255 : 249, i % 2 === 0 ? 255 : 250, i % 2 === 0 ? 255 : 251);
    doc.rect(M + 6, rowY, cardW - 12, 7, 'F');
    doc.setDrawColor(229, 231, 235);
    doc.rect(M + 6, rowY, cardW - 12, 7);

    doc.setTextColor(55, 65, 81);
    doc.setFont('helvetica', 'normal');
    doc.setFontSize(8.5);
    doc.text(t.day || t.date || `Day ${i + 1}`, M + 9, rowY + 5);

    doc.setFont('helvetica', 'bold');
    doc.setTextColor(17, 24, 39);
    doc.text(t.subject || '', M + 6 + colW[0] + 3, rowY + 5);

    doc.setFont('helvetica', 'normal');
    doc.setTextColor(55, 65, 81);
    doc.text(t.timing || '09:30 AM - 12:30 PM', M + 6 + colW[0] + colW[1] + 3, rowY + 5);

    rowY += 7;
  });

  // Instructions for Candidates
  const instY = rowY + 9;
  doc.setTextColor(17, 24, 39);
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(8.5);
  doc.text('INSTRUCTIONS FOR CANDIDATES:', M + 6, instY);

  doc.setFont('helvetica', 'normal');
  doc.setFontSize(7.5);
  doc.setTextColor(75, 85, 99);
  doc.text('1. Candidate must bring this Admit Card to the Examination Centre on every exam day.', M + 6, instY + 5);
  doc.text('2. Entry to the examination hall is permitted up to 15 minutes prior to commencement.', M + 6, instY + 9.5);
  doc.text('3. Electronic devices, mobile phones, and calculators are strictly prohibited.', M + 6, instY + 14);

  // Bottom Signatures Section
  const sigLineY = cardH - 21;

  // Left: Candidate Signature
  doc.setDrawColor(156, 163, 175);
  doc.setLineWidth(0.8);
  doc.line(M + 10, sigLineY, M + 65, sigLineY);
  doc.setTextColor(55, 65, 81);
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(8.5);
  doc.text('Candidate Signature', M + 37, sigLineY + 4.5, { align: 'center' });

  // Right: Principal Signature
  const rightSigX = M + cardW - 65;
  const rightCenterX = rightSigX + 27.5;

  const stampScale = Number(settings.stampScale) || 1.0;
  const sigScale = Number(settings.signatureScale) || 1.0;
  const stampSize = 22 * stampScale;
  const sigW = 38 * sigScale;
  const sigH = 12 * sigScale;

  // In the app (admit_card_screen.dart:755), Stamp & Signature sit in a unified stack entirely ABOVE the line
  const stampY = sigLineY - stampSize - 0.5;
  const sigY = sigLineY - sigH - 0.5;

  // Stamp centered at signature position above line
  if (stampData) {
    try {
      doc.addImage(stampData, 'PNG', rightCenterX - stampSize / 2, stampY, stampSize, stampSize);
    } catch (e) {
      console.warn('Failed to embed stamp in admit card PDF:', e);
    }
  }

  // Signature layered naturally inside / over the stamp
  if (sigData) {
    try {
      doc.addImage(sigData, 'PNG', rightCenterX - sigW / 2, sigY, sigW, sigH);
    } catch (e) { }
  }

  doc.setDrawColor(30, 58, 138);
  doc.setLineWidth(1.0);
  doc.line(rightSigX, sigLineY, rightSigX + 55, sigLineY);

  doc.setTextColor(30, 58, 138);
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(8.5);
  doc.text('Principal Sign', rightCenterX, sigLineY + 4, { align: 'center' });

  return doc;
}

export async function exportSingleAdmitCardPDF(student, settings, timetable, examTitle = 'ANNUAL EXAMINATION 2026') {
  try {
    const doc = await createSingleAdmitCardPDFDoc(student, settings, timetable, examTitle);
    const stuName = (student?.name || 'Student').replace(/[^a-zA-Z0-9]/g, '_');
    doc.save(`AdmitCard_${stuName}.pdf`);
  } catch (e) {
    console.error('exportSingleAdmitCardPDF error:', e);
  }
}

export async function exportSingleResultPDF(result, student, settings) {
  try {
    const doc = await createSingleResultPDFDoc(result, student, settings);
    const stuName = (student?.name || result?.studentName || 'Student').replace(/[^a-zA-Z0-9]/g, '_');
    const examName = (result?.examName || 'Exam').replace(/[^a-zA-Z0-9]/g, '_');
    doc.save(`Marksheet_${stuName}_${examName}.pdf`);
  } catch (e) {
    console.error('exportSingleResultPDF error:', e);
  }
}

export async function exportBulkResultMarksheetsPDF(results = [], students = [], settings = {}, examTitle = 'Annual Examination') {
  try {
    const doc = await createBulkResultMarksheetsPDFDoc(results, students, settings);
    const cleanExam = (examTitle || 'All_Results').replace(/[^a-zA-Z0-9]/g, '_');
    doc.save(`Bulk_Marksheets_${cleanExam}.pdf`);
  } catch (e) {
    console.error('exportBulkResultMarksheetsPDF error:', e);
  }
}

export async function printSingleResultPDF(result, student, settings) {
  try {
    const doc = await createSingleResultPDFDoc(result, student, settings);
    doc.autoPrint();
    const blobUrl = doc.output('bloburl');
    window.open(blobUrl, '_blank');
  } catch (e) {
    console.error('printSingleResultPDF error:', e);
    window.print();
  }
}

// ─── Helper: Filter Student Data by Month ────────────────────────────────────
export function filterStudentDataByMonth(payments = [], attendance = {}, results = [], monthFilter = 'all') {
  let filteredPayments = payments || [];
  let filteredAttendance = attendance || {};
  let filteredResults = results || [];
  let filterLabel = 'All Time / Comprehensive Lifetime (Till Date)';

  if (monthFilter && monthFilter !== 'all') {
    const [year, month] = monthFilter.split('-');
    const dateObj = new Date(parseInt(year, 10), parseInt(month, 10) - 1, 1);
    const monthName = !isNaN(dateObj.getTime())
      ? dateObj.toLocaleDateString('en-US', { month: 'long', year: 'numeric' })
      : monthFilter;
    filterLabel = `Month: ${monthName}`;

    filteredPayments = (payments || []).filter(p => {
      const d = p.date || p.paymentDate || p.createdAt || '';
      return String(d).startsWith(monthFilter);
    });

    const attEntries = Object.entries(attendance || {}).filter(([dateStr]) => dateStr.startsWith(monthFilter));
    filteredAttendance = Object.fromEntries(attEntries);

    filteredResults = (results || []).filter(r => {
      const d = r.date || r.examDate || r.createdAt || '';
      return d ? String(d).startsWith(monthFilter) : true;
    });
  }

  return { filteredPayments, filteredAttendance, filteredResults, filterLabel };
}

// ─── Comprehensive Student Full Report PDF Document Generator ───────────────
export async function createStudentFullReportPDFDoc(student = {}, payments = [], attendance = {}, results = [], settings = {}, monthFilter = 'all') {
  const { filteredPayments, filteredAttendance, filteredResults, filterLabel } = filterStudentDataByMonth(payments, attendance, results, monthFilter);

  const doc = new jsPDF({ orientation: 'portrait', unit: 'mm', format: 'a4' });
  const W = 210, H = 297, M = 12;
  const contentW = W - 2 * M;

  const logoSrc = settings.logoUrl || settings.logoPath || settings.logo;
  const sigSrc = settings.principalSignature || settings.signatureUrl || settings.signaturePath || settings.signature;
  const stampSrc = settings.schoolStamp || settings.stampUrl || settings.sealUrl;
  const [logoData, sigData, stampData] = await Promise.all([
    getImageDataUrl(logoSrc),
    getImageDataUrl(sigSrc),
    getImageDataUrl(stampSrc)
  ]);

  // Outer Border Box
  doc.setDrawColor(31, 16, 142);
  doc.setLineWidth(0.8);
  doc.rect(M, M, contentW, H - 2 * M);
  doc.setLineWidth(0.3);
  doc.rect(M + 1.5, M + 1.5, contentW - 3, H - 2 * M - 3);

  let y = M + 4;

  // Header Logo (if present)
  if (logoData) {
    try {
      doc.addImage(logoData, 'PNG', W / 2 - 9, y, 18, 18);
      y += 24;
    } catch (e) {
      y += 2;
    }
  } else {
    y += 2;
  }

  // Institute Name Header
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(16);
  doc.setTextColor(31, 16, 142);
  doc.text((settings.instituteName || settings.schoolName || 'SMART SCHOOL & INSTITUTE').toUpperCase(), W / 2, y, { align: 'center' });
  y += 5.5;

  doc.setFont('helvetica', 'normal');
  doc.setFontSize(8);
  doc.setTextColor(70, 70, 80);
  if (settings.address) {
    doc.text(settings.address, W / 2, y, { align: 'center' });
    y += 4;
  }
  const affText = settings.affiliationNumber ? `Affiliation No: ${settings.affiliationNumber}` : 'Govt. Recognized Academic Institution';
  const mobText = settings.mobile ? ` | Helpline: ${settings.mobile}` : '';
  doc.text(`${affText}${mobText}`, W / 2, y, { align: 'center' });
  y += 5;

  // Title Banner
  doc.setFillColor(31, 16, 142);
  doc.roundedRect(W / 2 - 58, y, 116, 7, 2, 2, 'F');
  doc.setTextColor(255, 215, 0);
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(9);
  doc.text('STUDENT COMPREHENSIVE PERFORMANCE & FEE STATEMENT', W / 2, y + 4.8, { align: 'center' });
  y += 10;

  // Filter/Period Tag
  doc.setTextColor(70, 70, 80);
  doc.setFontSize(8);
  doc.setFont('helvetica', 'bold');
  doc.text(`REPORT PERIOD: ${filterLabel.toUpperCase()}`, W / 2, y, { align: 'center' });
  y += 5;

  // Section 1: Student Particulars Box
  doc.setFillColor(248, 250, 252);
  doc.setDrawColor(203, 213, 225);
  doc.roundedRect(M + 4, y, contentW - 8, 25, 2, 2, 'FD');

  const studentName = student?.name || '—';
  const fatherName = student?.fatherName || '—';
  const classStr = student?.studentType === 'school' ? `Class ${student?.className || ''} - ${student?.section || 'A'}` : (student?.course || '—');
  const stuId = student?.studentId || '—';
  const rollNo = student?.rollNumber || 'N/A';
  const sessionStr = student?.session || settings.currentSession || '2026-27';
  const contactNo = student?.mobile || student?.whatsapp || '—';

  doc.setFontSize(8.5);
  doc.setTextColor(15, 23, 42);

  // Left Column
  doc.setFont('helvetica', 'normal');
  doc.text("Student Name:", M + 8, y + 6);
  doc.setFont('helvetica', 'bold');
  doc.text(String(studentName).toUpperCase(), M + 34, y + 6);

  doc.setFont('helvetica', 'normal');
  doc.text("Father's Name:", M + 8, y + 13);
  doc.setFont('helvetica', 'bold');
  doc.text(String(fatherName), M + 34, y + 13);

  doc.setFont('helvetica', 'normal');
  doc.text("Class / Course:", M + 8, y + 20);
  doc.setFont('helvetica', 'bold');
  doc.text(String(classStr), M + 34, y + 20);

  // Right Column
  doc.setFont('helvetica', 'normal');
  doc.text("Student ID:", W / 2 + 10, y + 6);
  doc.setFont('helvetica', 'bold');
  doc.text(String(stuId), W / 2 + 35, y + 6);

  doc.setFont('helvetica', 'normal');
  doc.text("Roll / Contact:", W / 2 + 10, y + 13);
  doc.setFont('helvetica', 'bold');
  doc.text(`Roll: ${rollNo} • Mob: ${contactNo}`, W / 2 + 35, y + 13);

  doc.setFont('helvetica', 'normal');
  doc.text("Academic Session:", W / 2 + 10, y + 20);
  doc.setFont('helvetica', 'bold');
  doc.text(String(sessionStr), W / 2 + 42, y + 20);

  y += 30;

  // Section 2: Fee Account Standing & Transaction Ledger
  const totalFees = Number(student?.totalFees) || Number(student?.feeAmount) || 0;
  const paidFees = filteredPayments.reduce((acc, p) => acc + (Number(p.amount) || 0), 0) || Number(student?.paidFees) || 0;
  const remainingDue = Math.max(0, totalFees - paidFees);

  const tableX = M + 4;
  const tableW = contentW - 8;

  // Fee Summary Ribbon
  doc.setFillColor(238, 242, 255);
  doc.setDrawColor(31, 16, 142);
  doc.roundedRect(tableX, y, tableW, 11, 2, 2, 'FD');

  doc.setFont('helvetica', 'bold');
  doc.setFontSize(8);
  doc.setTextColor(31, 16, 142);
  doc.text('FEE ACCOUNT STATUS:', tableX + 4, y + 7);

  doc.setFont('helvetica', 'normal');
  doc.setTextColor(50, 50, 50);
  doc.text(`Total Course Fee: Rs. ${totalFees.toLocaleString('en-IN')}`, tableX + 42, y + 7);
  doc.text(`Total Paid: Rs. ${paidFees.toLocaleString('en-IN')}`, tableX + 90, y + 7);
  doc.setFont('helvetica', 'bold');
  doc.setTextColor(remainingDue > 0 ? 185 : 22, remainingDue > 0 ? 28 : 101, remainingDue > 0 ? 28 : 52);
  doc.text(`Balance Due: Rs. ${remainingDue.toLocaleString('en-IN')}`, tableX + 134, y + 7);

  y += 14;

  // Payment Receipts Mini-Table
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(8.5);
  doc.setTextColor(31, 16, 142);
  doc.text(`Fee Payment Receipts (${filteredPayments.length})`, tableX, y);
  y += 3;

  const colP1 = 12, colP2 = 30, colP3 = 30, colP4 = 30, colP5 = tableW - colP1 - colP2 - colP3 - colP4;
  doc.setFillColor(31, 16, 142);
  doc.rect(tableX, y, tableW, 6, 'F');
  doc.setTextColor(255, 255, 255);
  doc.setFontSize(7.5);
  doc.text('S.N.', tableX + colP1 / 2, y + 4.2, { align: 'center' });
  doc.text('Receipt No', tableX + colP1 + 2, y + 4.2);
  doc.text('Date', tableX + colP1 + colP2 + 2, y + 4.2);
  doc.text('Amount (Rs.)', tableX + colP1 + colP2 + colP3 + colP4 / 2, y + 4.2, { align: 'center' });
  doc.text('Mode & Remarks', tableX + colP1 + colP2 + colP3 + colP4 + 2, y + 4.2);
  y += 6;

  if (filteredPayments.length === 0) {
    doc.setFillColor(248, 250, 252);
    doc.rect(tableX, y, tableW, 6, 'F');
    doc.setDrawColor(203, 213, 225);
    doc.rect(tableX, y, tableW, 6);
    doc.setTextColor(120, 120, 130);
    doc.setFont('helvetica', 'normal');
    doc.setFontSize(7.5);
    doc.text('No payment transactions recorded for this period.', tableX + tableW / 2, y + 4.2, { align: 'center' });
    y += 8;
  } else {
    filteredPayments.slice(0, 6).forEach((p, idx) => {
      const amt = Number(p.amount) || 0;
      const rNo = p.receiptNumber || p.receiptNo || 'REC-' + (p.id || '').slice(0, 6);
      
      const rawD = p.date || p.paymentDate || '';
      let pDate = '—';
      if (rawD) {
        const dt = new Date(rawD);
        if (!isNaN(dt.getTime())) {
          pDate = `${String(dt.getDate()).padStart(2, '0')}/${String(dt.getMonth() + 1).padStart(2, '0')}/${dt.getFullYear()}`;
        } else {
          pDate = String(rawD).slice(0, 10);
        }
      }

      const pMode = p.mode || p.paymentMode || 'Cash';
      const pRem = p.remarks || p.forMonth || 'Fee Payment';

      if (idx % 2 === 1) {
        doc.setFillColor(248, 250, 252);
        doc.rect(tableX, y, tableW, 5.5, 'F');
      }
      doc.setDrawColor(203, 213, 225);
      doc.rect(tableX, y, tableW, 5.5);
      doc.line(tableX + colP1, y, tableX + colP1, y + 5.5);
      doc.line(tableX + colP1 + colP2, y, tableX + colP1 + colP2, y + 5.5);
      doc.line(tableX + colP1 + colP2 + colP3, y, tableX + colP1 + colP2 + colP3, y + 5.5);
      doc.line(tableX + colP1 + colP2 + colP3 + colP4, y, tableX + colP1 + colP2 + colP3 + colP4, y + 5.5);

      doc.setFont('helvetica', 'normal');
      doc.setFontSize(7.5);
      doc.setTextColor(50, 50, 50);
      doc.text(String(idx + 1), tableX + colP1 / 2, y + 4, { align: 'center' });
      doc.setFont('helvetica', 'bold');
      doc.text(String(rNo), tableX + colP1 + 2, y + 4);
      doc.setFont('helvetica', 'normal');
      doc.text(String(pDate), tableX + colP1 + colP2 + 2, y + 4);
      doc.setFont('helvetica', 'bold');
      doc.setTextColor(22, 101, 52);
      doc.text(`Rs. ${amt.toLocaleString('en-IN')}`, tableX + colP1 + colP2 + colP3 + colP4 / 2, y + 4, { align: 'center' });
      doc.setFont('helvetica', 'normal');
      doc.setTextColor(50, 50, 50);
      doc.text(`${pMode} • ${pRem}`.slice(0, 36), tableX + colP1 + colP2 + colP3 + colP4 + 2, y + 4);
      y += 5.5;
    });
    if (filteredPayments.length > 6) {
      doc.setFont('helvetica', 'normal');
      doc.setFontSize(7);
      doc.setTextColor(100, 100, 110);
      doc.text(`...and ${filteredPayments.length - 6} more payment receipts. Full transaction ledger available in Excel export.`, tableX + 2, y + 3.5);
      y += 5;
    } else {
      y += 3;
    }
  }

  // Section 3: Attendance Summary Box
  let totalMarked = 0, presentDays = 0, absentDays = 0, leaveDays = 0;
  Object.entries(filteredAttendance).forEach(([_, rec]) => {
    const st = typeof rec === 'object' ? rec[student?.id] : rec;
    if (st) {
      totalMarked++;
      if (st === 'present') presentDays++;
      if (st === 'absent') absentDays++;
      if (st === 'leave') leaveDays++;
    }
  });
  const attPct = totalMarked > 0 ? ((presentDays / totalMarked) * 100).toFixed(1) : '0.0';

  doc.setFillColor(248, 250, 252);
  doc.setDrawColor(203, 213, 225);
  doc.roundedRect(tableX, y, tableW, 11, 2, 2, 'FD');

  doc.setFont('helvetica', 'bold');
  doc.setFontSize(8);
  doc.setTextColor(31, 16, 142);
  doc.text('ATTENDANCE RECORD:', tableX + 4, y + 7);

  doc.setFont('helvetica', 'normal');
  doc.setTextColor(50, 50, 50);
  doc.text(`Total Days: ${totalMarked}`, tableX + 42, y + 7);
  doc.text(`Present: ${presentDays}`, tableX + 72, y + 7);
  doc.text(`Absent: ${absentDays}`, tableX + 100, y + 7);
  doc.text(`Leave: ${leaveDays}`, tableX + 126, y + 7);
  doc.setFont('helvetica', 'bold');
  doc.setTextColor(Number(attPct) >= 75 ? 22 : 185, Number(attPct) >= 75 ? 101 : 28, Number(attPct) >= 75 ? 52 : 28);
  doc.text(`Rate: ${attPct}%`, tableX + 152, y + 7);

  y += 14;

  // Section 4: Exam Results Mini-Table (if available)
  if (filteredResults.length > 0) {
    doc.setFont('helvetica', 'bold');
    doc.setFontSize(8.5);
    doc.setTextColor(31, 16, 142);
    doc.text(`Academic Examination Results (${filteredResults.length})`, tableX, y);
    y += 3;

    const colE1 = 12, colE2 = 50, colE3 = 30, colE4 = 30, colE5 = 26, colE6 = tableW - colE1 - colE2 - colE3 - colE4 - colE5;
    doc.setFillColor(31, 16, 142);
    doc.rect(tableX, y, tableW, 6, 'F');
    doc.setTextColor(255, 255, 255);
    doc.setFontSize(7.5);
    doc.text('S.N.', tableX + colE1 / 2, y + 4.2, { align: 'center' });
    doc.text('Examination Name', tableX + colE1 + 2, y + 4.2);
    doc.text('Max Marks', tableX + colE1 + colE2 + colE3 / 2, y + 4.2, { align: 'center' });
    doc.text('Marks Obtained', tableX + colE1 + colE2 + colE3 + colE4 / 2, y + 4.2, { align: 'center' });
    doc.text('Percentage', tableX + colE1 + colE2 + colE3 + colE4 + colE5 / 2, y + 4.2, { align: 'center' });
    doc.text('Grade & Status', tableX + colE1 + colE2 + colE3 + colE4 + colE5 + colE6 / 2, y + 4.2, { align: 'center' });
    y += 6;

    filteredResults.slice(0, 4).forEach((r, idx) => {
      const subs = Array.isArray(r.subjects) && r.subjects.length > 0
        ? r.subjects
        : [{ subjectName: r.subject || 'General', totalMarks: r.totalMarks || 100, marks: r.marks || 0 }];
      const eMax = subs.reduce((sum, s) => sum + (Number(s.totalMarks) || 0), 0);
      const eObt = subs.reduce((sum, s) => sum + (Number(s.marks) || 0), 0);
      const ePct = eMax > 0 ? ((eObt / eMax) * 100).toFixed(1) : '0.0';
      const eGrd = Number(ePct) >= 90 ? 'A+' : Number(ePct) >= 80 ? 'A' : Number(ePct) >= 70 ? 'B+' : Number(ePct) >= 60 ? 'B' : Number(ePct) >= 50 ? 'C' : Number(ePct) >= 40 ? 'D' : 'F';

      if (idx % 2 === 1) {
        doc.setFillColor(248, 250, 252);
        doc.rect(tableX, y, tableW, 5.5, 'F');
      }
      doc.setDrawColor(203, 213, 225);
      doc.rect(tableX, y, tableW, 5.5);
      doc.line(tableX + colE1, y, tableX + colE1, y + 5.5);
      doc.line(tableX + colE1 + colE2, y, tableX + colE1 + colE2, y + 5.5);
      doc.line(tableX + colE1 + colE2 + colE3, y, tableX + colE1 + colE2 + colE3, y + 5.5);
      doc.line(tableX + colE1 + colE2 + colE3 + colE4, y, tableX + colE1 + colE2 + colE3 + colE4, y + 5.5);
      doc.line(tableX + colE1 + colE2 + colE3 + colE4 + colE5, y, tableX + colE1 + colE2 + colE3 + colE4 + colE5, y + 5.5);

      doc.setFont('helvetica', 'normal');
      doc.setFontSize(7.5);
      doc.setTextColor(50, 50, 50);
      doc.text(String(idx + 1), tableX + colE1 / 2, y + 4, { align: 'center' });
      doc.setFont('helvetica', 'bold');
      doc.text(String(r.examName || 'Examination'), tableX + colE1 + 2, y + 4);
      doc.setFont('helvetica', 'normal');
      doc.text(String(eMax), tableX + colE1 + colE2 + colE3 / 2, y + 4, { align: 'center' });
      doc.setFont('helvetica', 'bold');
      doc.setTextColor(31, 16, 142);
      doc.text(String(eObt), tableX + colE1 + colE2 + colE3 + colE4 / 2, y + 4, { align: 'center' });
      doc.setTextColor(50, 50, 50);
      doc.text(`${ePct}%`, tableX + colE1 + colE2 + colE3 + colE4 + colE5 / 2, y + 4, { align: 'center' });
      const passCrit = Number(r.passingMarks || r.passMarks || 33);
      const failedSubs = subs.filter(s => {
        const sMax = Number(s.totalMarks) || 100;
        const sObt = Number(s.marks) || 0;
        const minP = s.passingMarks != null ? Number(s.passingMarks) : Math.round(sMax * (passCrit / 100));
        return sObt < minP;
      });
      let rStatus = 'PASS';
      if (r.status === 'PROMOTED') rStatus = 'PROMOTED';
      else if (failedSubs.length > 0 || Number(ePct) < passCrit || r.status === 'FAIL') rStatus = 'FAIL';
      else rStatus = 'PASS';

      doc.setFont('helvetica', 'bold');
      if (rStatus === 'PROMOTED') {
        doc.setTextColor(180, 83, 9);
        doc.text(`${eGrd} (Promoted)`, tableX + colE1 + colE2 + colE3 + colE4 + colE5 + colE6 / 2, y + 4, { align: 'center' });
      } else if (rStatus === 'PASS') {
        doc.setTextColor(22, 101, 52);
        doc.text(`${eGrd} (Pass)`, tableX + colE1 + colE2 + colE3 + colE4 + colE5 + colE6 / 2, y + 4, { align: 'center' });
      } else {
        doc.setTextColor(185, 28, 28);
        doc.text(`${eGrd} (Fail)`, tableX + colE1 + colE2 + colE3 + colE4 + colE5 + colE6 / 2, y + 4, { align: 'center' });
      }
      y += 5.5;
    });
    y += 2;
  }

  // Signatures at Bottom
  const signY = H - M - 24;
  const rightSignCenterX = tableX + tableW - 27.5;

  const stampScale = Number(settings.stampScale) || 1.0;
  const sigScale = Number(settings.signatureScale) || 1.0;
  const stampSize = 22 * stampScale;
  const sigW = 38 * sigScale;
  const sigH = 12 * sigScale;

  const stampY = signY - stampSize - 0.5;
  const sigY = signY - sigH - 0.5;

  // Official Stamp centered at Principal signature position
  if (stampData) {
    try {
      doc.addImage(stampData, 'PNG', rightSignCenterX - stampSize / 2, stampY, stampSize, stampSize);
    } catch (e) {
      console.warn('Failed to embed stamp in full report PDF:', e);
    }
  }

  // Principal Signature layered naturally inside / over the stamp
  if (sigData) {
    try {
      doc.addImage(sigData, 'PNG', rightSignCenterX - sigW / 2, sigY, sigW, sigH);
    } catch (e) {
      console.warn('Failed to embed signature in full report PDF:', e);
    }
  }

  doc.setDrawColor(50, 50, 50);
  doc.setLineWidth(0.4);

  doc.line(tableX + 5, signY, tableX + 50, signY);
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(8);
  doc.setTextColor(30, 30, 30);
  doc.text("Class Incharge / Office", tableX + 27.5, signY + 4.5, { align: 'center' });

  doc.line(tableX + tableW - 50, signY, tableX + tableW - 5, signY);
  doc.text("Principal Sign", rightSignCenterX, signY + 4.5, { align: 'center' });

  // Issue Date & Disclaimer
  doc.setFont('helvetica', 'normal');
  doc.setFontSize(7);
  doc.setTextColor(120, 120, 130);
  doc.text(`Statement Generated on: ${new Date().toLocaleDateString('en-GB')}  |  Official Student Master Record`, W / 2, H - M - 5, { align: 'center' });

  return doc;
}

export async function exportStudentFullReportPDF(student = {}, payments = [], attendance = {}, results = [], settings = {}, monthFilter = 'all') {
  try {
    const doc = await createStudentFullReportPDFDoc(student, payments, attendance, results, settings, monthFilter);
    const stuName = (student?.name || 'Student').replace(/[^a-zA-Z0-9]/g, '_');
    const filterTag = (monthFilter === 'all' ? 'AllTime' : monthFilter).replace(/[^a-zA-Z0-9]/g, '_');
    doc.save(`Student_Report_${stuName}_${filterTag}.pdf`);
  } catch (e) {
    console.error('exportStudentFullReportPDF error:', e);
  }
}

export async function printStudentFullReportPDF(student = {}, payments = [], attendance = {}, results = [], settings = {}, monthFilter = 'all') {
  try {
    const doc = await createStudentFullReportPDFDoc(student, payments, attendance, results, settings, monthFilter);
    doc.autoPrint();
    const blobUrl = doc.output('bloburl');
    window.open(blobUrl, '_blank');
  } catch (e) {
    console.error('printStudentFullReportPDF error:', e);
    window.print();
  }
}

// ─── Export Comprehensive Student Report to Multi-Sheet Excel (.xlsx) ────────
export function exportStudentFullReportExcel(student = {}, payments = [], attendance = {}, results = [], settings = {}, monthFilter = 'all') {
  const { filteredPayments, filteredAttendance, filteredResults, filterLabel } = filterStudentDataByMonth(payments, attendance, results, monthFilter);
  const wb = XLSX.utils.book_new();

  // Sheet 1: Student Profile & Executive Summary
  const totalFees = Number(student?.totalFees) || 0;
  const paidFees = filteredPayments.reduce((acc, p) => acc + (Number(p.amount) || 0), 0) || Number(student?.paidFees) || 0;
  const remainingDue = Math.max(0, totalFees - paidFees);

  const profileRows = [
    ['INSTITUTION', settings?.instituteName || 'Smart School & Computer Institute'],
    ['REPORT TYPE', 'Student Comprehensive Full Statement'],
    ['PERIOD / FILTER', filterLabel],
    ['DATE OF EXPORT', new Date().toLocaleDateString('en-GB')],
    [],
    ['--- STUDENT MASTER PARTICULARS ---'],
    ['Student Name', student?.name || ''],
    ['Student ID', student?.studentId || ''],
    ['Admission Number', student?.admissionNumber || ''],
    ['Class / Course', student?.studentType === 'school' ? `Class ${student?.className || ''} - ${student?.section || ''}` : (student?.course || '')],
    ['Roll Number', student?.rollNumber || ''],
    ['Father\'s Name', student?.fatherName || ''],
    ['Mother\'s Name', student?.motherName || ''],
    ['Mobile Number', student?.mobile || ''],
    ['WhatsApp Number', student?.whatsapp || student?.mobile || ''],
    ['Date of Birth', student?.dob || ''],
    ['Gender', student?.gender || ''],
    ['Aadhaar Number', student?.aadhaarNumber || student?.aadharNumber || ''],
    ['Address', student?.address || ''],
    ['Session', student?.session || settings?.currentSession || ''],
    [],
    ['--- FINANCIAL ACCOUNT STANDING ---'],
    ['Total Course/Session Fees (INR)', totalFees],
    ['Total Fees Paid (INR)', paidFees],
    ['Remaining Balance Due (INR)', remainingDue],
    ['Monthly Tuition (INR)', Number(student?.monthlyFee) || 0]
  ];
  const wsProfile = XLSX.utils.aoa_to_sheet(profileRows);
  XLSX.utils.book_append_sheet(wb, wsProfile, 'Profile & Summary');

  // Sheet 2: Fee Transactions Ledger
  const feeHeader = ['S.N.', 'Receipt No', 'Date', 'Amount (INR)', 'Payment Mode', 'Remarks / For Month', 'Collected By'];
  const feeRows = filteredPayments.map((p, idx) => [
    idx + 1,
    p.receiptNumber || p.receiptNo || 'REC-' + (p.id || '').slice(0, 8),
    p.date || p.paymentDate || '',
    Number(p.amount) || 0,
    p.mode || p.paymentMode || 'Cash',
    p.remarks || p.forMonth || p.note || 'Fee Payment',
    p.collectedBy || 'Office'
  ]);
  const wsFees = XLSX.utils.aoa_to_sheet([feeHeader, ...feeRows]);
  XLSX.utils.book_append_sheet(wb, wsFees, 'Fee Transactions');

  // Sheet 3: Attendance Log
  const attHeader = ['Date', 'Status', 'Notes'];
  const attRows = Object.entries(filteredAttendance).map(([dateStr, dayRecords]) => {
    const status = typeof dayRecords === 'object' ? (dayRecords[student?.id] || 'N/A') : dayRecords;
    return [dateStr, String(status).toUpperCase(), ''];
  });
  const wsAtt = XLSX.utils.aoa_to_sheet([attHeader, ...attRows]);
  XLSX.utils.book_append_sheet(wb, wsAtt, 'Attendance Log');

  // Sheet 4: Exam Results
  const resHeader = ['Exam Name', 'Date', 'Subject', 'Marks Obtained', 'Max Marks', 'Percentage (%)', 'Grade', 'Result Status'];
  const resRows = [];
  filteredResults.forEach(r => {
    const rawSubs = Array.isArray(r.subjects) && r.subjects.length > 0 ? r.subjects : [];
    const tMax = rawSubs.reduce((sum, s) => sum + (Number(s.totalMarks || s.fullMarks) || 0), 0) || Number(r.totalMarks) || 100;
    const tObt = rawSubs.reduce((sum, s) => sum + (Number(s.marks || s.obtainedMarks) || 0), 0) || Number(r.obtainedMarks || r.marks) || 0;
    const pct = tMax > 0 ? Number(((tObt / tMax) * 100).toFixed(1)) : 0;
    const passCriteria = Number(r.passingMarks || r.passMarks || 33);
    const failedSubs = rawSubs.filter(s => {
      const sMax = Number(s.totalMarks || s.fullMarks) || 100;
      const sObt = Number(s.marks || s.obtainedMarks) || 0;
      const minPass = s.passingMarks != null ? Number(s.passingMarks) : Math.round(sMax * (passCriteria / 100));
      return sObt < minPass;
    });
    let finalStatus = 'PASS';
    if (r.status === 'PROMOTED') finalStatus = 'PROMOTED';
    else if (failedSubs.length > 0 || pct < passCriteria || r.status === 'FAIL') finalStatus = 'FAIL';
    else finalStatus = 'PASS';

    if (rawSubs.length > 0) {
      rawSubs.forEach(s => {
        const sMax = Number(s.totalMarks || s.fullMarks) || 100;
        const sObt = Number(s.marks || s.obtainedMarks) || 0;
        const sPct = sMax > 0 ? ((sObt / sMax) * 100).toFixed(1) : '0';
        const sGrd = Number(sPct) >= 90 ? 'A+' : Number(sPct) >= 80 ? 'A' : Number(sPct) >= 70 ? 'B+' : Number(sPct) >= 60 ? 'B' : Number(sPct) >= 50 ? 'C' : Number(sPct) >= 40 ? 'D' : 'F';
        resRows.push([r.examName || 'Exam', r.date || '', s.subjectName || s.name || 'General', sObt, sMax, `${sPct}%`, sGrd, finalStatus]);
      });
    } else {
      resRows.push([r.examName || 'Exam', r.date || '', r.subject || 'General', tObt, tMax, `${pct}%`, r.grade || '—', finalStatus]);
    }
  });
  const wsRes = XLSX.utils.aoa_to_sheet([resHeader, ...resRows]);
  XLSX.utils.book_append_sheet(wb, wsRes, 'Exam Results');

  const cleanName = (student?.name || 'Student').replace(/[^a-zA-Z0-9]/g, '_');
  const cleanFilter = (monthFilter === 'all' ? 'AllTime' : monthFilter).replace(/[^a-zA-Z0-9]/g, '_');
  XLSX.writeFile(wb, `Student_Full_Report_${cleanName}_${cleanFilter}.xlsx`);
}

// ─── Share Student Full Report WhatsApp Formatted Message ───────────────────
export function openWhatsAppStudentFullReport(student = {}, payments = [], attendance = {}, results = [], settings = {}, monthFilter = 'all') {
  const { filteredPayments, filteredAttendance, filteredResults, filterLabel } = filterStudentDataByMonth(payments, attendance, results, monthFilter);

  const phone = (student?.whatsapp || student?.mobile || student?.parentMobile || '').replace(/[^0-9]/g, '');
  const instituteName = settings?.instituteName || settings?.schoolName || 'Institute';
  
  const totalFees = Number(student?.totalFees) || 0;
  const paidFees = filteredPayments.reduce((acc, p) => acc + (Number(p.amount) || 0), 0) || Number(student?.paidFees) || 0;
  const remainingDue = Math.max(0, totalFees - paidFees);

  // Attendance stats
  let totalDays = 0, presentDays = 0;
  Object.entries(filteredAttendance).forEach(([_, rec]) => {
    const st = typeof rec === 'object' ? rec[student?.id] : rec;
    if (st) {
      totalDays++;
      if (st === 'present') presentDays++;
    }
  });
  const attPct = totalDays > 0 ? ((presentDays / totalDays) * 100).toFixed(1) : 'N/A';

  const latestResult = filteredResults[filteredResults.length - 1];
  let resText = 'N/A';
  if (latestResult) {
    const rawSubs = Array.isArray(latestResult.subjects) && latestResult.subjects.length > 0 ? latestResult.subjects : [];
    const tMax = rawSubs.reduce((sum, s) => sum + (Number(s.totalMarks || s.fullMarks) || 0), 0) || Number(latestResult.totalMarks) || 100;
    const tObt = rawSubs.reduce((sum, s) => sum + (Number(s.marks || s.obtainedMarks) || 0), 0) || Number(latestResult.obtainedMarks || latestResult.marks) || 0;
    const pct = tMax > 0 ? Number(((tObt / tMax) * 100).toFixed(1)) : 0;
    const passCriteria = Number(latestResult.passingMarks || latestResult.passMarks || 33);
    const failedSubs = rawSubs.filter(s => {
      const sMax = Number(s.totalMarks || s.fullMarks) || 100;
      const sObt = Number(s.marks || s.obtainedMarks) || 0;
      const minPass = s.passingMarks != null ? Number(s.passingMarks) : Math.round(sMax * (passCriteria / 100));
      return sObt < minPass;
    });
    let st = 'PASSED';
    if (latestResult.status === 'PROMOTED') st = 'PROMOTED';
    else if (failedSubs.length > 0 || pct < passCriteria || latestResult.status === 'FAIL') st = 'FAILED';
    resText = `${latestResult.examName || 'Exam'} — ${tObt}/${tMax} (${pct}%) • Status: ${st}`;
  }

  const msg = 
`🎓 *${instituteName.toUpperCase()}*
📋 *STUDENT COMPREHENSIVE PERFORMANCE & ACCOUNT STATEMENT*
📅 *Period:* ${filterLabel}

👤 *STUDENT DETAILS:*
• Name: *${student?.name || 'Student'}*
• Student ID: ${student?.studentId || 'N/A'}
• Class/Course: ${student?.studentType === 'school' ? `Class ${student?.className || ''} ${student?.section || ''}` : (student?.course || 'N/A')}
• Roll No: ${student?.rollNumber || 'N/A'}

💰 *FEE ACCOUNT STANDING:*
• Total Fees: ₹${totalFees.toLocaleString('en-IN')}
• Total Paid: ₹${paidFees.toLocaleString('en-IN')}
• Balance Due: *₹${remainingDue.toLocaleString('en-IN')}*
• Status: *${remainingDue <= 0 ? 'FULLY PAID ✅' : 'DUES PENDING ⚠️'}*
• Total Receipts: ${filteredPayments.length}

📊 *ATTENDANCE RECORD:*
• Working Days Marked: ${totalDays}
• Present Days: ${presentDays}
• Attendance Rate: ${attPct}${attPct !== 'N/A' ? '%' : ''}

🏆 *LATEST EXAM RESULT:*
• ${resText}

_For any queries or official paper receipt, kindly contact the institute office._
${settings?.mobile ? `📞 Helpline: ${settings.mobile}` : ''}`;

  const cleanPhone = phone.length === 10 ? `91${phone}` : phone;
  const encoded = encodeURIComponent(msg);
  const url = cleanPhone ? `https://wa.me/${cleanPhone}?text=${encoded}` : `https://api.whatsapp.com/send?text=${encoded}`;
  window.open(url, '_blank');
}

// ─── Native Web Share API for Student Full Report PDF ───────────────────────
export async function shareStudentFullReportNative(student = {}, payments = [], attendance = {}, results = [], settings = {}, monthFilter = 'all') {
  try {
    const doc = await createStudentFullReportPDFDoc(student, payments, attendance, results, settings, monthFilter);
    const pdfBlob = doc.output('blob');
    const cleanName = (student?.name || 'Student').replace(/[^a-zA-Z0-9]/g, '_');
    const fileName = `Student_Report_${cleanName}.pdf`;

    if (typeof window !== 'undefined' && typeof File !== 'undefined' && navigator.canShare) {
      const file = new File([pdfBlob], fileName, { type: 'application/pdf' });
      if (navigator.canShare({ files: [file] })) {
        await navigator.share({
          files: [file],
          title: `Student Statement - ${student?.name || 'Student'}`,
          text: `Official report statement for ${student?.name || 'student'} from ${settings?.instituteName || 'School'}.`
        });
        return true;
      }
    }
    // Fallback to normal save
    doc.save(fileName);
    return false;
  } catch (err) {
    console.error('shareStudentFullReportNative error:', err);
    return false;
  }
}



// ─── Export Batch Student ID Cards to Printable PDF ──────────────────────────
export async function exportIdCardsPDF(students = [], settings = {}) {
  if (!students || students.length === 0) return;

  const doc = new jsPDF({ orientation: 'portrait', unit: 'mm', format: 'a4' });
  const W = 210, H = 297;

  const logoSrc = settings.logoUrl || settings.logoPath || settings.logo;
  const sigSrc = settings.principalSignature || settings.signatureUrl || settings.signaturePath || settings.signature || settings.rawSignature;

  // Preload logo and signature in parallel
  const stampSrc = settings.schoolStamp || settings.stampUrl || settings.sealUrl;
  const [logoData, sigData, stampData] = await Promise.all([
    getImageDataUrl(logoSrc),
    getImageDataUrl(sigSrc),
    getImageDataUrl(stampSrc)
  ]);

  // Preload all student photos in parallel
  const photoDataList = await Promise.all(
    students.map(s => {
      const p = s.photoPath || s.photo;
      return p ? getImageDataUrl(p) : Promise.resolve(null);
    })
  );

  // Render cards per page (Front + Back pair per student)
  for (let idx = 0; idx < students.length; idx++) {
    const s = students[idx];
    const photoData = photoDataList[idx];
    if (idx > 0) doc.addPage();

    const instName = (settings.instituteName || 'MISSION NAVODAYA PUBLIC SCHOOL').toUpperCase();
    const instAddr = settings.address || 'Mora Mairi, Bhagwaanpur, Siwan, Bihar 841507';
    const mobile = settings.mobile || '9876543210';
    const session = s.session || settings.currentSession || '2026-27';

    // Page Title
    doc.setFont('helvetica', 'bold');
    doc.setFontSize(11);
    doc.setTextColor(31, 16, 142);
    doc.text(`STUDENT ID CARD PRINT SHEET — ${idx + 1} OF ${students.length}`, W / 2, 14, { align: 'center' });

    // ─── FRONT CARD ───
    const cardW = 120, cardH = 75;
    const cardX = (W - cardW) / 2;
    const cardY1 = 24;

    // Card background
    doc.setFillColor(10, 17, 40); // Dark navy
    doc.roundedRect(cardX, cardY1, cardW, cardH, 3, 3, 'F');
    doc.setDrawColor(255, 215, 0); // Gold border
    doc.setLineWidth(0.6);
    doc.roundedRect(cardX, cardY1, cardW, cardH, 3, 3);

    // Top Gold Bar
    doc.setFillColor(255, 215, 0);
    doc.rect(cardX, cardY1, cardW, 6, 'F');
    doc.setFont('helvetica', 'bold');
    doc.setFontSize(6.5);
    doc.setTextColor(10, 17, 40);
    doc.text('OFFICIAL STUDENT ID', cardX + 4, cardY1 + 4.2);
    doc.text(`SESSION ${session}`, cardX + cardW - 4, cardY1 + 4.2, { align: 'right' });

    // Header Institute Box & Logo
    if (logoData) {
      try {
        const logoW = 10, logoH = 10;
        const logoX = cardX + 3.5;
        const logoY = cardY1 + 6.5;
        doc.addImage(logoData, 'PNG', logoX, logoY, logoW, logoH);
      } catch (e) {
        console.warn('Could not add logo to PDF:', e);
      }
      doc.setTextColor(255, 255, 255);
      doc.setFontSize(9.5);
      doc.setFont('helvetica', 'bold');
      doc.text(instName.slice(0, 36), cardX + (cardW + 11) / 2, cardY1 + 10.8, { align: 'center' });
      doc.setFontSize(6);
      doc.setFont('helvetica', 'normal');
      doc.setTextColor(255, 215, 0);
      doc.text(instAddr.slice(0, 55), cardX + (cardW + 11) / 2, cardY1 + 14.8, { align: 'center' });
    } else {
      doc.setTextColor(255, 255, 255);
      doc.setFontSize(9.5);
      doc.setFont('helvetica', 'bold');
      doc.text(instName.slice(0, 36), cardX + cardW / 2, cardY1 + 11, { align: 'center' });
      doc.setFontSize(6);
      doc.setFont('helvetica', 'normal');
      doc.setTextColor(255, 215, 0);
      doc.text(instAddr.slice(0, 55), cardX + cardW / 2, cardY1 + 15, { align: 'center' });
    }

    // Divider
    doc.setDrawColor(255, 215, 0);
    doc.setLineWidth(0.3);
    doc.line(cardX + 4, cardY1 + 17, cardX + cardW - 4, cardY1 + 17);

    // Photo Box (Enlarged)
    const photoX = cardX + 5, photoY = cardY1 + 19, photoW = 27, photoH = 33;
    doc.setFillColor(15, 23, 42);
    doc.rect(photoX, photoY, photoW, photoH, 'F');
    doc.setDrawColor(255, 215, 0);
    doc.setLineWidth(0.5);
    doc.rect(photoX, photoY, photoW, photoH);

    if (photoData) {
      try {
        doc.addImage(photoData, 'PNG', photoX, photoY, photoW, photoH);
      } catch (e) {
        doc.setFontSize(16);
        doc.setTextColor(255, 255, 255);
        doc.setFont('helvetica', 'bold');
        doc.text((s.name || 'S').charAt(0).toUpperCase(), photoX + photoW / 2, photoY + photoH / 2 + 6, { align: 'center' });
      }
    } else {
      doc.setFontSize(16);
      doc.setTextColor(255, 255, 255);
      doc.setFont('helvetica', 'bold');
      doc.text((s.name || 'S').charAt(0).toUpperCase(), photoX + photoW / 2, photoY + photoH / 2 + 6, { align: 'center' });
    }

    // Student pill under photo
    doc.setFillColor(255, 215, 0);
    doc.roundedRect(photoX + 2, photoY + photoH + 1.2, photoW - 4, 3.8, 0.8, 0.8, 'F');
    doc.setFontSize(5.5);
    doc.setFont('helvetica', 'bold');
    doc.setTextColor(10, 17, 40);
    doc.text('STUDENT', photoX + photoW / 2, photoY + photoH + 4, { align: 'center' });

    // Student Details (Enlarged text)
    const textX = cardX + 36;
    let detY = cardY1 + 22.5;
    doc.setFontSize(9.5);
    doc.setTextColor(255, 255, 255);
    doc.setFont('helvetica', 'bold');
    doc.text((s.name || '-').toUpperCase().slice(0, 22), textX, detY);

    detY += 5;
    doc.setFontSize(7.5);
    const renderRow = (lbl, val) => {
      doc.setFont('helvetica', 'bold');
      doc.setTextColor(255, 215, 0);
      doc.text(lbl, textX, detY);
      doc.setFont('helvetica', 'bold');
      doc.setTextColor(255, 255, 255);
      doc.text(String(val || '-').slice(0, 25), textX + 17, detY);
      detY += 4.6;
    };

    renderRow('ID NO:', s.studentId);
    renderRow('ADM NO:', s.admissionNumber || s.studentId);
    renderRow(s.studentType === 'school' ? 'CLASS:' : 'COURSE:', s.studentType === 'school' ? `Class ${s.className || ''} - ${s.section || 'A'}` : s.course);
    renderRow('FATHER:', s.fatherName);
    renderRow('MOBILE:', s.mobile);

    // Front Bottom Bar
    doc.setFillColor(5, 9, 30);
    doc.rect(cardX, cardY1 + cardH - 6, cardW, 6, 'F');
    doc.setFontSize(5.5);
    doc.setTextColor(148, 163, 184);
    doc.text(`PROPERTY OF ${instName.slice(0, 28)}`, cardX + 4, cardY1 + cardH - 2.2);

    // Front Authorized Signature Image (Enlarged)
    if (sigData) {
      try {
        const signW = 28, signH = 10;
        const signX = cardX + cardW - signW - 3;
        const signY = cardY1 + cardH - 16.5;
        doc.addImage(sigData, 'PNG', signX, signY, signW, signH);
      } catch (e) {
        console.warn('Could not add signature to front card in PDF:', e);
      }
    }

    doc.setTextColor(255, 215, 0);
    doc.setFont('helvetica', 'bold');
    doc.setFontSize(5.5);
    doc.text('AUTH SIGNATURE', cardX + cardW - 4, cardY1 + cardH - 2.2, { align: 'right' });

    // ─── BACK CARD ───
    const cardY2 = cardY1 + cardH + 16;
    doc.setFillColor(10, 17, 40);
    doc.roundedRect(cardX, cardY2, cardW, cardH, 3, 3, 'F');
    doc.setDrawColor(255, 215, 0);
    doc.setLineWidth(0.6);
    doc.roundedRect(cardX, cardY2, cardW, cardH, 3, 3);

    // Top gold accent
    doc.setFillColor(255, 215, 0);
    doc.rect(cardX, cardY2, cardW, 3, 'F');

    // Terms
    doc.setFont('helvetica', 'bold');
    doc.setFontSize(7.5);
    doc.setTextColor(255, 215, 0);
    doc.text('TERMS & CONDITIONS', cardX + 6, cardY2 + 10);

    doc.setFont('helvetica', 'normal');
    doc.setFontSize(6.5);
    doc.setTextColor(226, 232, 240);
    doc.text('1. This card is non-transferable and must be presented upon request.', cardX + 6, cardY2 + 16);
    doc.text('2. If found, please return to the institute address mentioned below.', cardX + 6, cardY2 + 21);
    doc.text('3. Loss of this card must be reported immediately to school administration.', cardX + 6, cardY2 + 26);
    doc.text('4. Misuse or tampering of this identification badge is strictly prohibited.', cardX + 6, cardY2 + 31);

    // Divider
    doc.setDrawColor(255, 215, 0);
    doc.setLineWidth(0.3);
    doc.line(cardX + 6, cardY2 + 38, cardX + cardW - 6, cardY2 + 38);

    // Institute footer on back
    doc.setFontSize(7.5);
    doc.setFont('helvetica', 'bold');
    doc.setTextColor(255, 255, 255);
    doc.text(instName.slice(0, 36), cardX + 6, cardY2 + 46);
    doc.setFontSize(6);
    doc.setFont('helvetica', 'normal');
    doc.setTextColor(203, 213, 225);
    doc.text(`Phone: ${mobile}`, cardX + 6, cardY2 + 51);
    doc.text(instAddr.slice(0, 48), cardX + 6, cardY2 + 55);

    // Back Principal Signature Image (Enlarged)
    if (sigData) {
      try {
        const backSignW = 32, backSignH = 11.5;
        const backSignX = cardX + cardW - backSignW - 3;
        const backSignY = cardY2 + 46;
        doc.addImage(sigData, 'PNG', backSignX, backSignY, backSignW, backSignH);
      } catch (e) {
        console.warn('Could not add signature to back card in PDF:', e);
      }
    }

    // Principal Signature Line
    doc.setDrawColor(255, 255, 255);
    doc.setLineWidth(0.4);
    doc.line(cardX + cardW - 32, cardY2 + 58, cardX + cardW - 6, cardY2 + 58);
    doc.setFontSize(5.5);
    doc.setFont('helvetica', 'bold');
    doc.setTextColor(255, 215, 0);
    doc.text('PRINCIPAL SIGN', cardX + cardW - 19, cardY2 + 63, { align: 'center' });
  }

  doc.save(`${(settings.instituteName || 'School').replace(/[^a-zA-Z0-9]/g, '_')}_ID_Cards_Batch.pdf`);
}

// ─── Auto Background Remover & High-Contrast White Ink Converter ─────────────
export function removeSignatureBackground(imageDataUrl, threshold = 210, colorMode = 'white') {
  return new Promise((resolve) => {
    if (!imageDataUrl || typeof window === 'undefined') {
      resolve(imageDataUrl);
      return;
    }
    const img = new Image();
    img.crossOrigin = 'anonymous';
    img.onload = () => {
      try {
        const isStamp = colorMode === 'transparent' || colorMode === 'preserve' || colorMode === 'original';
        // Downscale stamps to 180px (<20KB) and signatures to 360px to stay well within Firestore 1MB document limit
        const MAX_DIM = isStamp ? 180 : 360;
        let targetW = img.naturalWidth || img.width || MAX_DIM;
        let targetH = img.naturalHeight || img.height || MAX_DIM;
        if (targetW > MAX_DIM || targetH > MAX_DIM) {
          if (targetW > targetH) {
            targetH = Math.round((targetH * MAX_DIM) / targetW);
            targetW = MAX_DIM;
          } else {
            targetW = Math.round((targetW * MAX_DIM) / targetH);
            targetH = MAX_DIM;
          }
        }

        const canvas = document.createElement('canvas');
        canvas.width = Math.max(1, targetW);
        canvas.height = Math.max(1, targetH);
        const ctx = canvas.getContext('2d', { willReadFrequently: true });
        if (!ctx) {
          resolve(imageDataUrl);
          return;
        }
        ctx.drawImage(img, 0, 0, canvas.width, canvas.height);
        const imgData = ctx.getImageData(0, 0, canvas.width, canvas.height);
        const d = imgData.data;

        let minLum = 255;
        let maxLum = 0;
        let transparentCount = 0;
        const totalPixels = d.length / 4;
        const lumValues = new Float32Array(totalPixels);

        for (let i = 0, j = 0; i < d.length; i += 4, j++) {
          const r = d[i];
          const g = d[i + 1];
          const b = d[i + 2];
          const a = d[i + 3];

          if (a < 20) {
            transparentCount++;
            lumValues[j] = 255;
            continue;
          }

          const lum = 0.299 * r + 0.587 * g + 0.114 * b;
          lumValues[j] = lum;
          if (lum < minLum) minLum = lum;
          if (lum > maxLum) maxLum = lum;
        }

        // If the signature or stamp is already transparent, return clean resized PNG
        if (transparentCount > totalPixels * 0.2) {
          resolve(canvas.toDataURL('image/png'));
          return;
        }

        // Step 2: Safe handling for stamps vs signatures
        const lumRange = Math.max(1, maxLum - minLum);

        if (isStamp) {
          // RUBBER STAMP PROCESSING:
          // Stamps have ink (blue, violet, red, green, black) on paper.
          // Neutral paper background is made 100% transparent.
          let paperCount = 0;
          for (let i = 0, j = 0; i < d.length; i += 4, j++) {
            const r = d[i];
            const g = d[i + 1];
            const b = d[i + 2];
            const a = d[i + 3];

            if (a < 20) {
              paperCount++;
              d[i + 3] = 0;
              continue;
            }

            const lum = lumValues[j];
            const maxC = Math.max(r, g, b);
            const minC = Math.min(r, g, b);
            const sat = maxC - minC;

            // Paper is bright (lum > 185) with low color saturation (sat < 35), OR bright neutral off-white
            const isPaper = (lum > 185 && sat < 35) || (r > 215 && g > 215 && b > 215 && sat < 25);

            if (isPaper) {
              paperCount++;
              d[i] = 0;
              d[i + 1] = 0;
              d[i + 2] = 0;
              d[i + 3] = 0;
            } else {
              d[i + 3] = 255;
            }
          }

          // Safety guard: only abort if > 98.5% was erased (empty blank sheet)
          if (paperCount > totalPixels * 0.985) {
            resolve(imageDataUrl);
            return;
          }

          ctx.putImageData(imgData, 0, 0);
          resolve(canvas.toDataURL('image/png'));
          return;
        }

        const strokeCutoff = Math.min(160, minLum + lumRange * 0.45);
        const featherStart = strokeCutoff * 0.70;

        for (let i = 0, j = 0; i < d.length; i += 4, j++) {
          const r = d[i];
          const g = d[i + 1];
          const b = d[i + 2];
          const lum = lumValues[j];

          // STRICT CHECK: If pixel is paper or light background, FORCE 100% TRANSPARENT
          const isPaperWhite = (r > 210 && g > 210 && b > 210) || lum >= strokeCutoff;
          if (isPaperWhite || d[i + 3] < 20) {
            d[i] = 0;
            d[i + 1] = 0;
            d[i + 2] = 0;
            d[i + 3] = 0;
            continue;
          }

          // Smooth anti-aliased alpha only for real ink stroke edges
          let alpha;
          if (lum <= featherStart) {
            alpha = 255;
          } else {
            const t = (strokeCutoff - lum) / Math.max(1, strokeCutoff - featherStart);
            alpha = Math.floor(Math.pow(t, 1.2) * 255);
          }

          d[i + 3] = alpha;

          if (colorMode === 'white' || colorMode === 'auto') {
            d[i] = 255;
            d[i + 1] = 255;
            d[i + 2] = 255;
          } else if (colorMode === 'gold') {
            d[i] = 255;
            d[i + 1] = 215;
            d[i + 2] = 0;
          } else if (colorMode === 'blue') {
            d[i] = 30;
            d[i + 1] = 64;
            d[i + 2] = 175;
          } else {
            d[i] = 10;
            d[i + 1] = 17;
            d[i + 2] = 40;
          }
        }

        ctx.putImageData(imgData, 0, 0);
        resolve(canvas.toDataURL('image/png'));
      } catch (err) {
        resolve(imageDataUrl);
      }
    };
    img.onerror = () => resolve(imageDataUrl);
    img.src = imageDataUrl;
  });
}

// ─── Export ID Card to PNG Image (Instant Canvas Download) ───────────────────
export async function exportIdCardPNG(student = {}, settings = {}, isBack = false) {
  if (!student || !student.name) return;

  const canvas = document.createElement('canvas');
  canvas.width = 1000;
  canvas.height = 625;
  const ctx = canvas.getContext('2d');
  if (!ctx) return;

  const instName = (settings.instituteName || 'MISSION NAVODAYA PUBLIC SCHOOL').toUpperCase();
  const instAddr = settings.address || 'Mora Mairi, Bhagwaanpur, Siwan, Bihar 841507';
  const mobile = settings.mobile || '9876543210';
  const session = student.session || settings.currentSession || '2026-27';

  const logoSrc = settings.logoUrl || settings.logoPath || settings.logo;
  const sigSrc = settings.principalSignature || settings.signatureUrl || settings.signaturePath || settings.signature || settings.rawSignature;
  const photoSrc = student.photoPath || student.photo || student.photoUrl;

  // Helper to load image
  const loadImage = (src) => new Promise((resolve) => {
    if (!src) return resolve(null);
    const img = new Image();
    img.crossOrigin = 'anonymous';
    img.onload = () => resolve(img);
    img.onerror = () => resolve(null);
    img.src = src;
  });

  const [logoImg, sigImg, photoImg] = await Promise.all([
    loadImage(logoSrc),
    loadImage(sigSrc),
    loadImage(photoSrc)
  ]);

  if (!isBack) {
    // ─── FRONT CARD ───
    // Background gradient
    const grad = ctx.createLinearGradient(0, 0, 1000, 625);
    grad.addColorStop(0, '#0A1128');
    grad.addColorStop(1, '#1C2541');
    ctx.fillStyle = grad;
    ctx.fillRect(0, 0, 1000, 625);

    // Gold Top Bar
    ctx.fillStyle = '#FFD700';
    ctx.fillRect(0, 0, 1000, 50);
    ctx.fillStyle = '#0A1128';
    ctx.font = 'bold 20px Helvetica, Arial, sans-serif';
    ctx.fillText('OFFICIAL STUDENT ID', 35, 33);
    ctx.textAlign = 'right';
    ctx.fillText(`SESSION ${session}`, 965, 33);
    ctx.textAlign = 'left';

    // Institute Header Box
    ctx.fillStyle = '#0A1128';
    ctx.fillRect(0, 50, 1000, 85);

    // Draw Logo if available
    if (logoImg) {
      ctx.drawImage(logoImg, 35, 54, 76, 76);
    }

    ctx.fillStyle = '#FFFFFF';
    ctx.font = 'bold 29px Helvetica, Arial, sans-serif';
    ctx.textAlign = 'center';
    ctx.fillText(instName, 520, 92);

    ctx.fillStyle = '#FFD700';
    ctx.font = '16px Helvetica, Arial, sans-serif';
    ctx.fillText(instAddr, 520, 120);
    ctx.textAlign = 'left';

    // Gold separator
    ctx.strokeStyle = '#FFD700';
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(35, 140);
    ctx.lineTo(965, 140);
    ctx.stroke();

    // Photo Box (Enlarged)
    ctx.fillStyle = '#0A1128';
    ctx.strokeStyle = '#FFD700';
    ctx.lineWidth = 4;
    ctx.fillRect(45, 160, 210, 255);
    ctx.strokeRect(45, 160, 210, 255);

    if (photoImg) {
      ctx.drawImage(photoImg, 45, 160, 210, 255);
    } else {
      ctx.fillStyle = '#FFFFFF';
      ctx.font = 'bold 85px Helvetica, Arial, sans-serif';
      ctx.textAlign = 'center';
      ctx.fillText((student.name || 'S').charAt(0).toUpperCase(), 150, 310);
      ctx.textAlign = 'left';
    }

    // STUDENT pill
    ctx.fillStyle = '#FFD700';
    ctx.fillRect(80, 425, 140, 32);
    ctx.fillStyle = '#0A1128';
    ctx.font = 'bold 17px Helvetica, Arial, sans-serif';
    ctx.textAlign = 'center';
    ctx.fillText('STUDENT', 150, 447);
    ctx.textAlign = 'left';

    // Details Column (Enlarged text)
    const dX = 285;
    let dY = 195;
    ctx.fillStyle = '#FFFFFF';
    ctx.font = 'bold 34px Helvetica, Arial, sans-serif';
    ctx.fillText((student.name || '').toUpperCase(), dX, dY);

    dY += 46;
    const addRow = (lbl, val) => {
      ctx.font = 'bold 22px Helvetica, Arial, sans-serif';
      ctx.fillStyle = '#FFD700';
      ctx.fillText(lbl, dX, dY);
      ctx.fillStyle = '#FFFFFF';
      ctx.font = 'bold 22px Helvetica, Arial, sans-serif';
      ctx.fillText(String(val || '—'), dX + 175, dY);
      dY += 40;
    };

    addRow('STUDENT ID:', student.studentId);
    addRow('ADM NO:', student.admissionNumber || student.studentId);
    addRow(student.studentType === 'school' ? 'CLASS / SEC:' : 'COURSE:', student.studentType === 'school' ? `Class ${student.className || ''} - ${student.section || 'A'}` : student.course);
    addRow("FATHER'S NAME:", student.fatherName);
    addRow('CONTACT NO:', student.mobile);

    // Bottom Bar
    ctx.fillStyle = '#05091E';
    ctx.fillRect(0, 575, 1000, 50);
    ctx.fillStyle = '#94A3B8';
    ctx.font = 'bold 15px Helvetica, Arial, sans-serif';
    ctx.fillText(`PROPERTY OF ${instName}`, 35, 605);

    // Draw Signature (Enlarged)
    if (sigImg) {
      ctx.drawImage(sigImg, 740, 505, 220, 75);
    }

    ctx.fillStyle = '#FFD700';
    ctx.textAlign = 'right';
    ctx.font = 'bold 16px Helvetica, Arial, sans-serif';
    ctx.fillText('AUTH SIGNATURE', 965, 605);
  } else {
    // ─── BACK CARD ───
    ctx.fillStyle = '#0A1128';
    ctx.fillRect(0, 0, 1000, 625);

    // Top gold bar
    ctx.fillStyle = '#FFD700';
    ctx.fillRect(0, 0, 1000, 20);

    // Terms
    ctx.fillStyle = '#FFD700';
    ctx.font = 'bold 26px Helvetica, Arial, sans-serif';
    ctx.fillText('TERMS & CONDITIONS', 50, 80);

    ctx.fillStyle = '#CBD5E1';
    ctx.font = '19px Helvetica, Arial, sans-serif';
    ctx.fillText('1. This card is non-transferable and must be presented upon request.', 50, 130);
    ctx.fillText('2. If found, please return to the institute address mentioned below.', 50, 180);
    ctx.fillText('3. Loss of this card must be reported immediately to administration.', 50, 230);
    ctx.fillText('4. Any misuse or damage of this identification badge is prohibited.', 50, 280);

    // Gold Divider
    ctx.strokeStyle = '#FFD700';
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(50, 360);
    ctx.lineTo(950, 360);
    ctx.stroke();

    // Footer Info
    ctx.fillStyle = '#FFFFFF';
    ctx.font = 'bold 24px Helvetica, Arial, sans-serif';
    ctx.fillText(instName, 50, 420);
    ctx.fillStyle = '#94A3B8';
    ctx.font = '18px Helvetica, Arial, sans-serif';
    ctx.fillText(`Contact: ${mobile}`, 50, 460);
    ctx.fillText(instAddr, 50, 495);

    // Draw Signature above sign line if available (Enlarged)
    if (sigImg) {
      ctx.drawImage(sigImg, 720, 410, 220, 95);
    }

    // Principal Sign Line
    ctx.strokeStyle = '#FFFFFF';
    ctx.lineWidth = 3;
    ctx.beginPath();
    ctx.moveTo(700, 510);
    ctx.lineTo(950, 510);
    ctx.stroke();

    ctx.fillStyle = '#FFD700';
    ctx.font = 'bold 18px Helvetica, Arial, sans-serif';
    ctx.textAlign = 'center';
    ctx.fillText('PRINCIPAL SIGN', 825, 545);
  }

  // Trigger download
  canvas.toBlob((blob) => {
    if (!blob) return;
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    const cleanName = (student.name || 'Student').replace(/[^a-zA-Z0-9]/g, '_');
    a.download = `${cleanName}_ID_Card_${isBack ? 'Back' : 'Front'}.png`;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  }, 'image/png');
}

// ─── Export Faculty & Teachers Master to Excel ───────────────────────────────
export function exportFacultyToExcel(teachers = [], schoolName = 'School') {
  const data = (teachers || []).map((t, idx) => ({
    'S.No': idx + 1,
    'Teacher ID': t.teacherId || t.id || `T${String(idx + 1).padStart(3, '0')}`,
    'Full Name': t.name || '-',
    'Mobile / Contact': t.mobile || '-',
    'Auth Email': t.authEmail || t.email || '-',
    'Assigned Class': t.assignedClass ? `Class ${t.assignedClass}` : 'General',
    'Assigned Section': t.assignedSection || 'A',
    'Status': t.active ? 'Active' : 'Inactive',
    'Joined Date': t.createdAt ? (typeof t.createdAt === 'string' ? t.createdAt.split('T')[0] : new Date(t.createdAt).toISOString().split('T')[0]) : '-'
  }));

  const ws = XLSX.utils.json_to_sheet(data);
  const wb = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(wb, ws, 'Faculty Directory');
  XLSX.writeFile(wb, `${schoolName.replace(/[^a-zA-Z0-9]/g, '_')}_Faculty_Directory_${new Date().toISOString().split('T')[0]}.xlsx`);
}

// ─── Export Faculty & Teachers Master to PDF ─────────────────────────────────
export function exportFacultyPDF(teachers = [], settings = {}) {
  const doc = new jsPDF({ orientation: 'portrait', unit: 'mm', format: 'a4' });
  const W = 210, H = 297, M = 10;

  // Header
  doc.setFillColor(15, 23, 42);
  doc.rect(M, M, W - 2 * M, 22, 'F');

  doc.setTextColor(255, 255, 255);
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(13);
  doc.text((settings.instituteName || settings.schoolName || 'SMART SCHOOL & INSTITUTE').toUpperCase(), W / 2, M + 9, { align: 'center' });

  doc.setFontSize(8.5);
  doc.setFont('helvetica', 'normal');
  doc.text('FACULTY & TEACHERS MASTER DIRECTORY', W / 2, M + 16, { align: 'center' });

  let y = M + 30;

  // Table Headers
  doc.setFillColor(241, 245, 249);
  doc.rect(M, y, W - 2 * M, 8, 'F');
  doc.setDrawColor(203, 213, 225);
  doc.rect(M, y, W - 2 * M, 8);

  doc.setTextColor(51, 65, 85);
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(8);

  doc.text('#', M + 3, y + 5.5);
  doc.text('Teacher ID', M + 12, y + 5.5);
  doc.text('Faculty Name', M + 40, y + 5.5);
  doc.text('Mobile No', M + 85, y + 5.5);
  doc.text('Assigned Class', M + 120, y + 5.5);
  doc.text('Section', M + 155, y + 5.5);
  doc.text('Status', M + 172, y + 5.5);

  y += 8;

  doc.setFont('helvetica', 'normal');
  doc.setFontSize(8);
  doc.setTextColor(15, 23, 42);

  (teachers || []).forEach((t, idx) => {
    if (y > H - 18) {
      doc.addPage();
      y = M + 10;
    }

    if (idx % 2 === 1) {
      doc.setFillColor(248, 250, 252);
      doc.rect(M, y, W - 2 * M, 8, 'F');
    }
    doc.rect(M, y, W - 2 * M, 8);

    doc.text(String(idx + 1), M + 3, y + 5.2);
    doc.text(t.teacherId || t.id || `T${String(idx + 1).padStart(3, '0')}`, M + 12, y + 5.2);
    doc.text((t.name || '-').slice(0, 24), M + 40, y + 5.2);
    doc.text(t.mobile || '-', M + 85, y + 5.2);
    doc.text(t.assignedClass ? `Class ${t.assignedClass}` : 'General', M + 120, y + 5.2);
    doc.text(t.assignedSection || 'A', M + 155, y + 5.2);
    doc.text(t.active ? 'Active' : 'Inactive', M + 172, y + 5.2);

    y += 8;
  });

  // Footer
  doc.setFontSize(7.5);
  doc.setTextColor(100, 116, 139);
  doc.text(`Generated on ${new Date().toLocaleDateString('en-GB')} | Total Faculty: ${teachers.length} | ${settings.instituteName || 'Smart School'}`, W / 2, H - 6, { align: 'center' });

  doc.save(`${(settings.instituteName || 'School').replace(/[^a-zA-Z0-9]/g, '_')}_Faculty_Directory_${new Date().toISOString().split('T')[0]}.pdf`);
}


/**
 * Direct WhatsApp Result / Marksheet Share (Voucher text + Auto-downloaded PDF)
 */
export async function openWhatsAppResultShare(result, student, settings = {}) {
  let mobile = student?.alternateMobile || student?.mobile || student?.parentPhone || student?.phone || student?.contactNumber || student?.whatsappNumber;
  let finalMobile = cleanWhatsAppNumber(mobile);

  if (!finalMobile && typeof window !== 'undefined') {
    const inputNumber = window.prompt(
      `⚠️ WhatsApp Number Not Found for ${student?.name || 'Student'}!\n\nEnter 10-digit mobile number to share Marksheet on WhatsApp:`
    );
    if (!inputNumber) {
      return; // User cancelled
    }
    finalMobile = cleanWhatsAppNumber(inputNumber);
  }

  const schoolName = settings?.instituteName || settings?.schoolName || 'School';
  const schoolPhone = settings?.phone || settings?.mobile || '';
  const totalObt = result.subjects?.reduce((a, s) => a + (Number(s.marks) || 0), 0) || Number(result.obtainedMarks || 0);
  const totalMax = result.subjects?.reduce((a, s) => a + (Number(s.totalMarks) || 100), 0) || Number(result.totalMarks || 100);
  const pct = Math.round((totalObt / (totalMax || 1)) * 100);

  const passCriteria = Number(result.passingMarks || 33);
  const failedSubs = result.subjects?.filter(sub => {
    const sMax = Number(sub.totalMarks) || 100;
    const sObt = Number(sub.marks) || 0;
    const minP = sub.passingMarks != null ? Number(sub.passingMarks) : Math.round(sMax * (passCriteria / 100));
    return sObt < minP;
  }) || [];
  const failCount = failedSubs.length;

  const statusText = result.status === 'PROMOTED'
    ? 'PROMOTED TO NEXT CLASS'
    : (failCount > 0 || pct < passCriteria || result.status === 'FAIL')
    ? 'NEEDS IMPROVEMENT / FAILED'
    : 'PASSED';

  let subjectLines = '';
  if (Array.isArray(result.subjects) && result.subjects.length > 0) {
    subjectLines = result.subjects.map(s => `• ${s.subjectName || s.name || 'Subject'}: ${s.marks || 0} / ${s.totalMarks || 100}`).join('\n');
  }

  const msg = `🎓 *ACADEMIC MARKSHEET / RESULT*\n` +
`*${schoolName.toUpperCase()}*\n` +
`━━━━━━━━━━━━━━━━━━━━\n` +
`👤 *Student:* ${student?.name || 'Student'}\n` +
`🆔 *Roll No:* ${student?.rollNumber || student?.studentId || '-'}\n` +
`📄 *Admission No:* ${student?.admissionNumber || student?.admissionNo || '-'}\n` +
`🏫 *Class:* ${student?.displayClass || student?.className || '-'}\n` +
`📝 *Exam:* ${result?.examName || 'Annual Examination'}\n` +
`━━━━━━━━━━━━━━━━━━━━\n` +
`📚 *Subject-wise Marks:*\n` +
`${subjectLines || '• Marks recorded in attached PDF'}\n` +
`━━━━━━━━━━━━━━━━━━━━\n` +
`🎯 *Total Marks:* ${totalObt} / ${totalMax}\n` +
`📊 *Percentage:* ${pct}%\n` +
`🏅 *Grade:* ${result?.overallGrade || (pct >= 80 ? 'A' : pct >= 60 ? 'B' : pct >= 40 ? 'C' : 'D')}\n` +
`🏆 *Result Status:* *${statusText}*\n` +
`${result?.remarks ? `💬 *Remarks:* ${result.remarks}\n` : ''}` +
`━━━━━━━━━━━━━━━━━━━━\n` +
`📄 *Official Marksheet PDF generated & saved.*\n` +
`${schoolPhone ? `📞 Helpline / Office: ${schoolPhone}\n` : ''}` +
`Thank you!\n` +
`*${schoolName}*`;

  const waUrl = finalMobile
    ? `https://api.whatsapp.com/send?phone=${finalMobile}&text=${encodeURIComponent(msg)}`
    : `https://api.whatsapp.com/send?text=${encodeURIComponent(msg)}`;

  if (typeof window !== 'undefined') {
    window.open(waUrl, '_blank');
  }

  // Auto-download Marksheet PDF in background
  try {
    createSingleResultPDFDoc(result, student, settings).then((doc) => {
      if (doc) {
        const fName = `Marksheet_${(student?.name || 'Student').replace(/\s+/g, '_')}_${(result?.examName || 'Exam').replace(/\s+/g, '_')}.pdf`;
        doc.save(fName);
      }
    }).catch((err) => {
      console.warn("Result PDF auto-download error:", err);
    });
  } catch (e) { }
}

/**
 * Direct WhatsApp Admit Card Share (Voucher text + Auto-downloaded PDF)
 */
export async function openWhatsAppAdmitCardShare(student, settings = {}, timetable = [], examTitle = 'Annual Examination 2026') {
  let mobile = student?.alternateMobile || student?.mobile || student?.parentPhone || student?.phone || student?.contactNumber;
  let finalMobile = cleanWhatsAppNumber(mobile);

  if (!finalMobile && typeof window !== 'undefined') {
    const inputNumber = window.prompt(
      `⚠️ WhatsApp Number Not Found for ${student?.name || 'Student'}!\n\nEnter 10-digit mobile number to share Admit Card on WhatsApp:`
    );
    if (!inputNumber) return;
    finalMobile = cleanWhatsAppNumber(inputNumber);
  }

  const schoolName = settings?.instituteName || settings?.schoolName || 'School';
  const schoolPhone = settings?.phone || settings?.mobile || '';

  const msg = `🎫 *EXAMINATION ADMIT CARD / HALL TICKET*\n` +
`*${schoolName.toUpperCase()}*\n` +
`━━━━━━━━━━━━━━━━━━━━\n` +
`👤 *Candidate:* ${student?.name || 'Student'}\n` +
`👨‍👦 *Father:* ${student?.fatherName || '-'}\n` +
`🆔 *Roll No:* ${student?.rollNumber || '-'}\n` +
`📄 *Adm No:* ${student?.admissionNumber || student?.admissionNo || '-'}\n` +
`🏫 *Class:* ${student?.displayClass || student?.className || '-'}\n` +
`📝 *Exam:* ${examTitle}\n` +
`━━━━━━━━━━━━━━━━━━━━\n` +
`📄 *Official Hall Ticket & Subject Time Table PDF generated & attached.*\n` +
`⚠️ *Note:* Please print and carry this Admit Card to the examination hall.\n` +
`${schoolPhone ? `📞 Office: ${schoolPhone}\n` : ''}` +
`*${schoolName}*`;

  const waUrl = finalMobile
    ? `https://api.whatsapp.com/send?phone=${finalMobile}&text=${encodeURIComponent(msg)}`
    : `https://api.whatsapp.com/send?text=${encodeURIComponent(msg)}`;

  if (typeof window !== 'undefined') {
    window.open(waUrl, '_blank');
  }

  // Auto-download Admit Card PDF
  try {
    createSingleAdmitCardPDFDoc(student, settings, timetable, examTitle).then((doc) => {
      if (doc) {
        doc.save(`AdmitCard_${(student?.name || 'Student').replace(/\s+/g, '_')}.pdf`);
      }
    }).catch((err) => {
      console.warn("Admit Card PDF auto-download error:", err);
    });
  } catch (e) { }
}

/**
 * Direct WhatsApp ID Card Share (Voucher text + Auto-downloaded ID Card)
 */
export async function openWhatsAppIdCardShare(student, settings = {}) {
  let mobile = student?.alternateMobile || student?.mobile || student?.parentPhone || student?.phone || student?.contactNumber;
  let finalMobile = cleanWhatsAppNumber(mobile);

  if (!finalMobile && typeof window !== 'undefined') {
    const inputNumber = window.prompt(
      `⚠️ WhatsApp Number Not Found for ${student?.name || 'Student'}!\n\nEnter 10-digit mobile number to share ID Card on WhatsApp:`
    );
    if (!inputNumber) return;
    finalMobile = cleanWhatsAppNumber(inputNumber);
  }

  const schoolName = settings?.instituteName || settings?.schoolName || 'School';
  const schoolPhone = settings?.phone || settings?.mobile || '';

  const msg = `🪪 *OFFICIAL STUDENT IDENTITY CARD*\n` +
`*${schoolName.toUpperCase()}*\n` +
`━━━━━━━━━━━━━━━━━━━━\n` +
`👤 *Student:* ${student?.name || 'Student'}\n` +
`🆔 *Student ID:* ${student?.studentId || student?.id || '-'}\n` +
`📄 *Adm No:* ${student?.admissionNumber || student?.admissionNo || '-'}\n` +
`🏫 *Class / Course:* ${student?.displayClass || student?.className || student?.course || '-'}\n` +
`👨‍👦 *Father:* ${student?.fatherName || '-'}\n` +
`📞 *Contact:* ${student?.mobile || student?.phone || '-'}\n` +
`━━━━━━━━━━━━━━━━━━━━\n` +
`📄 *Verified Digital Student ID Card PDF generated & attached.*\n` +
`${schoolPhone ? `📞 Office: ${schoolPhone}\n` : ''}` +
`*${schoolName}*`;

  const waUrl = finalMobile
    ? `https://api.whatsapp.com/send?phone=${finalMobile}&text=${encodeURIComponent(msg)}`
    : `https://api.whatsapp.com/send?text=${encodeURIComponent(msg)}`;

  if (typeof window !== 'undefined') {
    window.open(waUrl, '_blank');
  }

  // Auto-download ID Card PDF
  try {
    exportIdCardsPDF([student], settings).catch((err) => {
      console.warn("ID Card auto-download error:", err);
    });
  } catch (e) { }
}
