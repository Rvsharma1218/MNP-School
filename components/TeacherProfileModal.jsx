'use client';

import React, { useState, useRef, useEffect } from 'react';
import { useSchoolStore, getActiveSchoolId } from '../lib/store';
import {
  X,
  User,
  Phone,
  Mail,
  MapPin,
  Calendar,
  CreditCard,
  GraduationCap,
  Briefcase,
  Award,
  BookOpen,
  Edit,
  Trash2,
  Copy,
  CheckCircle,
  Eye,
  EyeOff,
  ShieldCheck,
  Camera,
  Upload,
  Crop,
  Download,
  Share2,
  Check,
  AlertTriangle,
  KeyRound,
  FileText,
  Printer,
  ChevronRight,
  Clock,
  FileCheck
} from 'lucide-react';
import ImageCropperModal from './ImageCropperModal';

export default function TeacherProfileModal({ teacher, onClose, onEdit, onOpenPermissions }) {
  const {
    settings,
    updateTeacher,
    deleteTeacher,
    showToast,
    teacherAttendance,
    markTeacherAttendance
  } = useSchoolStore();

  const [activeTab, setActiveTab] = useState('overview'); // 'overview' | 'professional' | 'salary' | 'credentials' | 'attendance'
  const [showPassword, setShowPassword] = useState(false);
  const [previewAadhaarModal, setPreviewAadhaarModal] = useState(false);
  const [copiedField, setCopiedField] = useState(null);
  const [isCropperOpen, setIsCropperOpen] = useState(false);
  const [imageToCrop, setImageToCrop] = useState(null);
  const photoInputRef = useRef(null);

  // Modals for Actions
  const [isToggleActiveModalOpen, setIsToggleActiveModalOpen] = useState(false);
  const [isResetPasswordModalOpen, setIsResetPasswordModalOpen] = useState(false);
  const [isDeleteModalOpen, setIsDeleteModalOpen] = useState(false);
  const [isPaySalaryModalOpen, setIsPaySalaryModalOpen] = useState(false);

  // Form states
  const [resetPasswordVal, setResetPasswordVal] = useState('123456');
  const [salaryAmount, setSalaryAmount] = useState(teacher?.salary || 25000);
  const [salaryMonth, setSalaryMonth] = useState(() => {
    const d = new Date();
    return d.toLocaleString('en-US', { month: 'long', year: 'numeric' });
  });
  const [salaryMode, setSalaryMode] = useState('Bank Transfer');
  const [salaryNote, setSalaryNote] = useState('');

  // Local Salary History
  const [salaryHistory, setSalaryHistory] = useState([]);

  const activeSchoolId = getActiveSchoolId();
  const teacherKey = teacher?.authUid || teacher?.id || teacher?.teacherId;

  // Load salary history from localStorage
  useEffect(() => {
    if (!teacherKey) return;
    try {
      const stored = localStorage.getItem(`teacher_salary_history_${activeSchoolId}`);
      if (stored) {
        const parsed = JSON.parse(stored);
        if (parsed[teacherKey]) {
          setSalaryHistory(parsed[teacherKey]);
        }
      }
    } catch (_) {}
  }, [teacherKey, activeSchoolId]);

  if (!teacher) return null;

  const isActive = teacher.active !== false && teacher.status !== 'disabled';

  const handleCopy = (text, fieldName) => {
    if (!text) return;
    navigator.clipboard.writeText(text);
    setCopiedField(fieldName);
    showToast(`Copied ${fieldName} to clipboard!`, 'info');
    setTimeout(() => setCopiedField(null), 2000);
  };

  const handlePhotoFileSelect = (e) => {
    const file = e.target.files?.[0];
    if (file) {
      if (!file.type.startsWith('image/')) {
        showToast('Please select a valid image file.', 'error');
        return;
      }
      const reader = new FileReader();
      reader.onload = (event) => {
        const dataUrl = event.target.result;
        setImageToCrop(dataUrl);
        setIsCropperOpen(true);
      };
      reader.readAsDataURL(file);
    }
    e.target.value = '';
  };

  const handleCropComplete = async (croppedDataUrl) => {
    try {
      const uid = teacher.authUid || teacher.id || teacher.teacherId;
      await updateTeacher(uid, { ...teacher, photoUrl: croppedDataUrl });
      setIsCropperOpen(false);
      showToast('Profile photo updated successfully!', 'success');
    } catch (err) {
      showToast(`Error saving photo: ${err.message || err}`, 'error');
    }
  };

  // ─── TOGGLE ACTIVE CONFIRMATION (YES / NO) ──────────────────────────────────
  const handleConfirmToggleActive = async () => {
    try {
      const uid = teacher.authUid || teacher.id || teacher.teacherId;
      const newStatus = !isActive;
      await updateTeacher(uid, {
        ...teacher,
        active: newStatus,
        status: newStatus ? 'active' : 'disabled'
      });
      setIsToggleActiveModalOpen(false);
      showToast(`${teacher.name} is now ${newStatus ? 'Active' : 'Disabled'}!`, 'success');
    } catch (err) {
      showToast(`Failed to update status: ${err.message || err}`, 'error');
    }
  };

  // ─── RESET PASSWORD CONFIRMATION ───────────────────────────────────────────
  const handleConfirmResetPassword = async () => {
    if (resetPasswordVal.trim().length < 6) {
      showToast('Password must be at least 6 characters.', 'error');
      return;
    }
    try {
      const uid = teacher.authUid || teacher.id || teacher.teacherId;
      await updateTeacher(uid, {
        ...teacher,
        password: resetPasswordVal.trim()
      });
      setIsResetPasswordModalOpen(false);
      showToast('Portal password updated! Share new password with teacher.', 'success');
    } catch (err) {
      showToast(`Failed to reset password: ${err.message || err}`, 'error');
    }
  };

  // ─── DELETE TEACHER CONFIRMATION ───────────────────────────────────────────
  const handleConfirmDelete = async () => {
    try {
      deleteTeacher(teacher);
      setIsDeleteModalOpen(false);
      onClose();
    } catch (err) {
      showToast(`Failed to delete teacher: ${err.message || err}`, 'error');
    }
  };

  // ─── PAY SALARY & RECORD HISTORY & PRINT VOUCHER ────────────────────────────
  const handlePaySalarySubmit = (e) => {
    e.preventDefault();
    const amt = Number(salaryAmount) || teacher.salary || 25000;
    const now = new Date();
    const record = {
      teacherId: teacher.teacherId || teacher.id,
      teacherName: teacher.name,
      month: salaryMonth,
      amount: amt,
      mode: salaryMode,
      note: salaryNote.trim(),
      date: now.toISOString(),
      timestampFormatted: now.toLocaleString('en-US', {
        day: '2-digit',
        month: 'short',
        year: 'numeric',
        hour: '2-digit',
        minute: '2-digit',
        hour12: true
      })
    };

    const updatedList = [record, ...salaryHistory];
    setSalaryHistory(updatedList);

    try {
      const stored = localStorage.getItem(`teacher_salary_history_${activeSchoolId}`);
      const parsed = stored ? JSON.parse(stored) : {};
      parsed[teacherKey] = updatedList;
      localStorage.setItem(`teacher_salary_history_${activeSchoolId}`, JSON.stringify(parsed));
    } catch (_) {}

    setIsPaySalaryModalOpen(false);
    showToast(`Salary payment recorded for ${teacher.name}!`, 'success');
    printSalarySlip(record);
  };

  // Helper to format raw ISO dates into clean human format (e.g. 15 Jan 1995)
  const formatDob = (val) => {
    if (!val) return '—';
    try {
      const clean = String(val).split('T')[0];
      const parts = clean.split('-');
      if (parts.length === 3 && parts[0].length === 4) {
        const d = new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]));
        if (!isNaN(d.getTime())) {
          return d.toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' });
        }
      }
      return clean;
    } catch {
      return String(val).split('T')[0];
    }
  };

  // ─── OFFICIAL PRINTABLE SALARY SLIP (STAMP + SIGN + LOGO + DATE/TIME) ─────────────
  const printSalarySlip = (record) => {
    const schoolName = settings.instituteName || settings.schoolName || 'SMART HIGH SCHOOL';
    const schoolAddress = settings.address || 'Main Campus';
    const schoolPhone = settings.phone || settings.mobile || 'Support Line';
    const schoolEmail = settings.email || 'info@school.com';
    const rawLogo = settings.logoUrl || settings.logoPath || settings.logo || '';
    const rawStamp = settings.schoolStamp || settings.stamp || '';
    const rawSig = settings.principalSignature || settings.rawSignature || settings.signature || '';
    const printDate = record.timestampFormatted || new Date().toLocaleString();

    const formatImgSrc = (val) => {
      if (!val || typeof val !== 'string') return '';
      val = val.trim();
      if (val.startsWith('http://') || val.startsWith('https://') || val.startsWith('data:')) return val;
      return `data:image/png;base64,${val}`;
    };

    const logoSrc = formatImgSrc(rawLogo);
    const stampSrc = formatImgSrc(rawStamp);
    const sigSrc = formatImgSrc(rawSig);

    const stampScale = Number(settings.stampScale) || 1.0;
    const signatureScale = Number(settings.signatureScale) || 1.0;
    const stampHeight = Math.round(68 * stampScale);
    const sigHeight = Math.round(44 * signatureScale);
    const boxHeight = Math.max(stampHeight, sigHeight) + 12;
    const boxWidth = Math.max(160, Math.round(stampHeight * 1.3), Math.round(sigHeight * 2.5));

    const slipWindow = window.open('', '_blank', 'width=800,height=900');
    if (!slipWindow) {
      showToast('Popup blocker prevented voucher print window. Please allow popups.', 'error');
      return;
    }

    const htmlContent = `
      <!DOCTYPE html>
      <html>
        <head>
          <title>Salary_Slip_${(teacher.name || 'Teacher').replace(/\s+/g, '_')}_${record.month}</title>
          <style>
            * { box-sizing: border-box; margin: 0; padding: 0; }
            body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background: #fff; color: #1e293b; padding: 30px; }
            .voucher-card { border: 2px solid #334155; border-radius: 12px; padding: 25px; max-width: 720px; margin: 0 auto; position: relative; }
            .header-row { display: flex; align-items: center; border-bottom: 2px solid #e2e8f0; padding-bottom: 14px; margin-bottom: 14px; gap: 16px; }
            .school-logo { height: 60px; max-width: 90px; object-fit: contain; }
            .school-title { font-size: 20px; font-weight: 900; color: #1e3a8a; text-transform: uppercase; letter-spacing: -0.5px; }
            .school-sub { font-size: 11px; color: #64748b; margin-top: 3px; }
            .badge-title { background: #f0fdf4; border: 1px solid #bbf7d0; color: #166534; padding: 6px 14px; border-radius: 20px; font-size: 11px; font-weight: 800; text-align: center; margin-bottom: 16px; text-transform: uppercase; letter-spacing: 0.5px; }
            .info-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 10px 24px; font-size: 12.5px; margin-bottom: 18px; }
            .info-item { display: flex; justify-content: space-between; border-bottom: 1px dashed #e2e8f0; padding-bottom: 4px; }
            .info-label { font-weight: 700; color: #475569; }
            .info-val { font-weight: 600; color: #0f172a; }
            .amount-box { background: #f8fafc; border: 1.5px solid #cbd5e1; border-radius: 8px; padding: 14px 18px; display: flex; justify-content: space-between; align-items: center; margin-bottom: 18px; }
            .amount-label { font-size: 13px; font-weight: 800; color: #1e293b; }
            .amount-val { font-size: 22px; font-weight: 900; color: #047857; font-family: monospace; }
            .words-row { font-size: 11.5px; font-style: italic; color: #475569; margin-bottom: 30px; }
            .sig-section { display: flex; justify-content: space-between; align-items: flex-end; margin-top: 40px; }
            .sig-col { text-align: center; width: 220px; position: relative; }
            .sig-line { border-top: 1.5px solid #475569; margin-top: 8px; padding-top: 4px; font-size: 11px; font-weight: 700; color: #1e293b; }
            .stamp-sig-box { min-height: 75px; height: ${boxHeight}px; width: ${boxWidth}px; position: relative; display: flex; align-items: center; justify-content: center; margin-left: auto; margin-right: auto; margin-bottom: 2px; }
            .stamp-img { height: ${stampHeight}px; max-width: 100%; width: auto; opacity: 0.90; object-fit: contain; mix-blend-mode: multiply; filter: contrast(115%); }
            .sig-img { height: ${sigHeight}px; max-width: 90%; width: auto; object-fit: contain; position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%); z-index: 2; mix-blend-mode: multiply; filter: contrast(130%); }
            .footer-note { margin-top: 25px; text-align: center; font-size: 10px; color: #94a3b8; border-top: 1px solid #f1f5f9; padding-top: 8px; }
            @media print {
              body { padding: 0; }
              .voucher-card { border: 1.5px solid #000; }
            }
          </style>
        </head>
        <body>
          <div class="voucher-card">
            <div class="header-row">
              ${logoSrc ? `<img src="${logoSrc}" class="school-logo" alt="School Logo" />` : ''}
              <div style="flex: 1;">
                <div class="school-title">${schoolName}</div>
                <div class="school-sub">${schoolAddress} | Phone: ${schoolPhone} | Email: ${schoolEmail}</div>
              </div>
            </div>

            <div class="badge-title">Official Staff Salary Disbursement Voucher</div>

            <div class="info-grid">
              <div class="info-item"><span class="info-label">Faculty Name:</span><span class="info-val">${teacher.name}</span></div>
              <div class="info-item"><span class="info-label">Teacher ID:</span><span class="info-val">${teacher.teacherId || 'T001'}</span></div>
              <div class="info-item"><span class="info-label">Designation:</span><span class="info-val">${teacher.designation || 'Teacher'}</span></div>
              <div class="info-item"><span class="info-label">Assigned Class / Sub:</span><span class="info-val">${teacher.assignedClass ? 'Class ' + teacher.assignedClass : (teacher.subject || 'Faculty')}</span></div>
              <div class="info-item"><span class="info-label">Salary Month:</span><span class="info-val">${record.month}</span></div>
              <div class="info-item"><span class="info-label">Payment Mode:</span><span class="info-val">${record.mode}</span></div>
              <div class="info-item"><span class="info-label">Transaction Ref:</span><span class="info-val">${record.note || 'N/A'}</span></div>
              <div class="info-item"><span class="info-label">Date & Time:</span><span class="info-val">${printDate}</span></div>
            </div>

            <div class="amount-box">
              <span class="amount-label">NET SALARY PAID:</span>
              <span class="amount-val">₹ ${Number(record.amount).toLocaleString('en-IN')}</span>
            </div>

            <div class="words-row">
              Amount in Words: <strong>Rupees ${Number(record.amount).toLocaleString('en-IN')} Only</strong>
            </div>

            <div class="sig-section">
              <div class="sig-col">
                <div style="height: 50px;"></div>
                <div class="sig-line">Teacher's Signature</div>
              </div>

              <div class="sig-col">
                <div class="stamp-sig-box">
                  ${stampSrc ? `<img src="${stampSrc}" class="stamp-img" alt="Stamp" />` : ''}
                  ${sigSrc ? `<img src="${sigSrc}" class="sig-img" alt="Principal Sign" />` : ''}
                </div>
                <div class="sig-line">Director / Principal Sign & Stamp</div>
              </div>
            </div>

            <div class="footer-note">
              This is a computer-generated official payment receipt issued by ${schoolName}.
            </div>
          </div>
          <script>
            window.onload = function() {
              window.print();
            };
          </script>
        </body>
      </html>
    `;

    slipWindow.document.open();
    slipWindow.document.write(htmlContent);
    slipWindow.document.close();
  };

  // ─── 1-CLICK ATTENDANCE (PRESENT, ABSENT, HALF DAY, LEAVE) ──────────────────
  const todayStr = new Date().toISOString().split('T')[0];
  const todayRecords = teacherAttendance?.[todayStr] || {};
  const todayStatus = todayRecords[teacherKey] || 
                      todayRecords[teacher.teacherId] || 
                      todayRecords[teacher.authUid] || 
                      todayRecords[teacher.id] || null;

  const handle1ClickAttendance = async (status) => {
    try {
      await markTeacherAttendance(todayStr, teacherKey, status);
      showToast(`Marked ${teacher.name} as ${status.toUpperCase()} for Today!`, 'success');
    } catch (err) {
      showToast(`Failed to mark attendance: ${err.message || err}`, 'error');
    }
  };

  const isClassTeacher = teacher.assignedClass && teacher.assignedClass !== 'none' && teacher.assignedClass !== 'None';
  const roleLabel = isClassTeacher
    ? `Class Teacher: Class ${teacher.assignedClass}${teacher.assignedSection ? ` - ${teacher.assignedSection}` : ''}`
    : 'Subject Teacher (All Classes)';

  return (
    <div
      onClick={(e) => {
        if (e.target === e.currentTarget) onClose();
      }}
      className="fixed inset-0 z-50 overflow-y-auto bg-black/75 backdrop-blur-xs p-2 sm:p-4 lg:p-6 flex justify-center items-start animate-in fade-in duration-200"
    >
      <div className="bg-card border border-border rounded-2xl w-full max-w-2xl shadow-2xl overflow-hidden my-2 sm:my-6 flex flex-col relative animate-in zoom-in-95 duration-200">
        
        {/* Cover Gradient Banner */}
        <div className="h-28 sm:h-36 bg-gradient-to-r from-indigo-700 via-primary to-blue-600 relative p-4 flex justify-between items-start">
          <div className="flex items-center gap-2">
            <span className="px-2.5 py-1 rounded-full bg-white/20 backdrop-blur-md text-white font-mono font-extrabold text-[11px] shadow-xs">
              {teacher.teacherId || 'T-ID'}
            </span>
            <span className={`px-2.5 py-1 rounded-full backdrop-blur-md text-white font-bold text-[10px] flex items-center gap-1 shadow-xs ${
              isActive ? 'bg-emerald-500/80' : 'bg-rose-500/80'
            }`}>
              <CheckCircle className="w-3 h-3" />
              <span>{isActive ? 'Active Faculty' : 'Account Disabled'}</span>
            </span>
          </div>

          <button
            onClick={onClose}
            className="w-8 h-8 rounded-full bg-black/30 hover:bg-black/50 text-white flex items-center justify-center cursor-pointer transition-all active:scale-95"
            title="Close"
          >
            <X className="w-4 h-4" />
          </button>
        </div>

        {/* Profile Avatar & Top Bar */}
        <div className="px-5 sm:px-6 pb-4 relative -mt-14 sm:-mt-16 flex flex-col sm:flex-row sm:items-end justify-between gap-4 border-b border-border/80 bg-card">
          <div className="flex items-end gap-3.5 sm:gap-4">
            {/* Avatar with Crop / Upload overlay */}
            <div className="relative group shrink-0">
              <div className="w-24 h-24 sm:w-28 sm:h-28 rounded-2xl border-4 border-card bg-surface2 overflow-hidden shadow-lg flex items-center justify-center text-primary font-black text-3xl">
                {teacher.photoUrl ? (
                  <img src={teacher.photoUrl} alt={teacher.name} className="w-full h-full object-cover" />
                ) : (
                  <span>{teacher.name?.charAt(0) || 'T'}</span>
                )}
              </div>
              
              <button
                onClick={() => photoInputRef.current?.click()}
                className="absolute inset-0 m-auto w-full h-full rounded-2xl bg-black/50 text-white opacity-0 group-hover:opacity-100 transition-opacity flex flex-col items-center justify-center gap-1 cursor-pointer"
                title="Change Profile Photo"
              >
                <Camera className="w-5 h-5" />
                <span className="text-[10px] font-bold">Change DP</span>
              </button>
              <input
                ref={photoInputRef}
                type="file"
                accept="image/*"
                className="hidden"
                onChange={handlePhotoFileSelect}
              />
            </div>

            <div className="min-w-0 pb-1">
              <h2 className="text-lg sm:text-xl font-extrabold text-text truncate">
                {teacher.name}
              </h2>
              <div className="flex flex-wrap items-center gap-1.5 mt-0.5">
                <span className="text-xs font-bold text-primary">
                  {teacher.designation || 'Teacher'}
                </span>
                <span className="text-text-muted">•</span>
                <span className="text-[11px] text-text-secondary font-medium">
                  {teacher.subject || 'All Subjects'}
                </span>
              </div>
              <div className="mt-1">
                <span className={`inline-flex items-center gap-1 px-2.5 py-0.5 rounded-md text-[10.5px] font-bold ${
                  isClassTeacher ? 'bg-primary/10 text-primary' : 'bg-emerald-50 dark:bg-emerald-950/40 text-emerald-700 dark:text-emerald-300 border border-emerald-200 dark:border-emerald-800'
                }`}>
                  <BookOpen className="w-3 h-3" />
                  <span>{roleLabel}</span>
                </span>
              </div>
            </div>
          </div>

          {/* Top Actions: Edit, Disable, Delete */}
          <div className="flex items-center gap-2 self-start sm:self-end pt-1 flex-wrap">
            <button
              onClick={() => {
                onClose();
                onEdit(teacher);
              }}
              className="px-3 py-1.5 rounded-xl bg-primary hover:bg-primary-dark text-white font-bold text-xs shadow-xs flex items-center gap-1.5 cursor-pointer transition-all active:scale-95"
            >
              <Edit className="w-3.5 h-3.5" />
              <span>Edit</span>
            </button>

            {/* Toggle Disable / Enable with Yes/No Modal */}
            <button
              onClick={() => setIsToggleActiveModalOpen(true)}
              className={`px-3 py-1.5 rounded-xl font-bold text-xs border flex items-center gap-1.5 cursor-pointer transition-all active:scale-95 ${
                isActive
                  ? 'bg-amber-50 dark:bg-amber-950/40 text-amber-700 dark:text-amber-300 border-amber-200 dark:border-amber-800 hover:bg-amber-100'
                  : 'bg-emerald-50 dark:bg-emerald-950/40 text-emerald-700 dark:text-emerald-300 border-emerald-200 dark:border-emerald-800 hover:bg-emerald-100'
              }`}
            >
              <span>{isActive ? 'Disable' : 'Enable'}</span>
            </button>

            {/* Delete button */}
            <button
              onClick={() => setIsDeleteModalOpen(true)}
              className="p-1.5 rounded-xl bg-rose-50 dark:bg-rose-950/40 hover:bg-rose-100 text-rose-600 font-bold text-xs border border-rose-200 dark:border-rose-900 cursor-pointer transition-all active:scale-95"
              title="Delete Teacher"
            >
              <Trash2 className="w-4 h-4" />
            </button>
          </div>
        </div>

        {/* Tab Navigation */}
        <div className="flex border-b border-border bg-surface2 px-5 sm:px-6 gap-1 overflow-x-auto">
          {[
            { id: 'overview', label: 'Personal Info', icon: User },
            { id: 'professional', label: 'Academic Info', icon: Briefcase },
            { id: 'salary', label: 'Salary & Slips', icon: CreditCard },
            { id: 'credentials', label: 'Portal Login', icon: KeyRound },
            { id: 'attendance', label: 'Attendance', icon: Calendar }
          ].map(tab => {
            const Icon = tab.icon;
            const isTabActive = activeTab === tab.id;
            return (
              <button
                key={tab.id}
                onClick={() => setActiveTab(tab.id)}
                className={`py-3 px-3.5 text-xs font-bold border-b-2 flex items-center gap-1.5 transition-all cursor-pointer whitespace-nowrap ${
                  isTabActive
                    ? 'border-primary text-primary'
                    : 'border-transparent text-text-secondary hover:text-text'
                }`}
              >
                <Icon className="w-3.5 h-3.5" />
                <span>{tab.label}</span>
              </button>
            );
          })}
        </div>

        {/* Tab Content Body */}
        <div className="p-5 sm:p-6 space-y-4 max-h-[60vh] overflow-y-auto">
          {/* TAB 1: OVERVIEW */}
          {activeTab === 'overview' && (
            <div className="space-y-4">
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3.5 text-xs">
                <div className="p-3 rounded-xl bg-surface2 border border-border/70 space-y-1">
                  <span className="text-[10.5px] text-text-muted font-medium block">Full Name</span>
                  <span className="font-bold text-text text-sm block">{teacher.name}</span>
                </div>

                <div className="p-3 rounded-xl bg-surface2 border border-border/70 space-y-1">
                  <span className="text-[10.5px] text-text-muted font-medium block">Father's Name</span>
                  <span className="font-bold text-text text-sm block">{teacher.fatherName || '—'}</span>
                </div>

                <div className="p-3 rounded-xl bg-surface2 border border-border/70 space-y-1">
                  <span className="text-[10.5px] text-text-muted font-medium block">Mother's Name</span>
                  <span className="font-bold text-text text-sm block">{teacher.motherName || '—'}</span>
                </div>

                <div className="p-3 rounded-xl bg-surface2 border border-border/70 space-y-1">
                  <span className="text-[10.5px] text-text-muted font-medium block">Date of Birth & Gender</span>
                  <span className="font-bold text-text text-sm block">
                    {formatDob(teacher.dob)} ({teacher.gender || 'Male'})
                  </span>
                </div>

                <div className="p-3 rounded-xl bg-surface2 border border-border/70 space-y-1">
                  <span className="text-[10.5px] text-text-muted font-medium block">Primary Mobile</span>
                  <div className="flex items-center justify-between">
                    <span className="font-mono font-bold text-text text-sm">{teacher.mobile || '—'}</span>
                    {teacher.mobile && (
                      <button
                        onClick={() => handleCopy(teacher.mobile, 'Mobile')}
                        className="text-text-muted hover:text-primary p-1 cursor-pointer"
                        title="Copy Mobile"
                      >
                        {copiedField === 'Mobile' ? <Check className="w-3.5 h-3.5 text-emerald-500" /> : <Copy className="w-3.5 h-3.5" />}
                      </button>
                    )}
                  </div>
                </div>

                <div className="p-3 rounded-xl bg-surface2 border border-border/70 space-y-1">
                  <span className="text-[10.5px] text-text-muted font-medium block">Alternate Mobile</span>
                  <span className="font-mono font-bold text-text text-sm block">{teacher.alternateMobile || '—'}</span>
                </div>

                {/* Aadhaar Card & Identity Document Card */}
                {(() => {
                  const teacherAadhaarDoc = teacher.aadhaarDocUrl || teacher.aadhaarDocPath || teacher.aadhaarCardUrl;
                  return (
                    <div className="p-3.5 rounded-xl bg-surface2 border border-border/80 space-y-2.5 sm:col-span-2">
                      <div className="flex items-center justify-between pb-1 border-b border-border/50">
                        <div className="flex items-center gap-1.5">
                          <FileCheck className="w-4 h-4 text-emerald-600" />
                          <span className="text-[11px] font-bold text-text uppercase tracking-wider">Aadhaar Card & Identity Document</span>
                        </div>
                        <span className="font-mono text-xs font-bold text-text">
                          {teacher.aadhaarNumber || teacher.aadharNumber ? `UIDAI: ${teacher.aadhaarNumber || teacher.aadharNumber}` : 'Not Linked'}
                        </span>
                      </div>

                      <div className="flex items-center justify-between gap-3 bg-card p-2.5 rounded-xl border border-border">
                        <div className="flex items-center gap-3">
                          {teacherAadhaarDoc ? (
                            <div
                              onClick={() => setPreviewAadhaarModal(true)}
                              className="relative w-20 h-14 rounded-lg overflow-hidden border border-border bg-slate-900 cursor-pointer group flex-shrink-0 shadow-xs"
                              title="Click to view full Aadhaar document"
                            >
                              <img
                                src={teacherAadhaarDoc}
                                alt="Aadhaar Card"
                                className="w-full h-full object-cover group-hover:scale-105 transition-transform"
                              />
                              <div className="absolute inset-0 bg-black/40 opacity-0 group-hover:opacity-100 flex items-center justify-center text-white text-[10px] font-bold transition-opacity">
                                <Eye className="w-4 h-4" />
                              </div>
                            </div>
                          ) : (
                            <div className="w-20 h-14 rounded-lg bg-surface2 border border-dashed border-border flex flex-col items-center justify-center text-text-muted flex-shrink-0">
                              <FileText className="w-4 h-4 text-text-muted/60" />
                              <span className="text-[8px] font-bold mt-0.5">No Doc</span>
                            </div>
                          )}

                          <div>
                            <div className="font-bold text-xs text-text flex items-center gap-1.5">
                              <span>Official Document Photo</span>
                              {teacherAadhaarDoc ? (
                                <span className="px-1.5 py-0.2 rounded text-[9px] font-bold bg-emerald-500/10 text-emerald-600">Attached</span>
                              ) : (
                                <span className="px-1.5 py-0.2 rounded text-[9px] font-bold bg-amber-500/10 text-amber-600">Missing</span>
                              )}
                            </div>
                            <span className="text-[10.5px] text-text-muted block mt-0.5">
                              {teacherAadhaarDoc ? 'Aadhaar ID photo attached to faculty profile.' : 'Upload Aadhaar copy from Edit Faculty.'}
                            </span>
                          </div>
                        </div>

                        <div className="flex items-center gap-1.5">
                          {teacherAadhaarDoc && (
                            <button
                              type="button"
                              onClick={() => setPreviewAadhaarModal(true)}
                              className="px-2.5 py-1.5 rounded-lg bg-emerald-600 hover:bg-emerald-700 text-white text-xs font-bold flex items-center gap-1 cursor-pointer transition-colors shadow-2xs"
                            >
                              <Eye className="w-3.5 h-3.5" />
                              <span>View</span>
                            </button>
                          )}
                          <button
                            type="button"
                            onClick={() => {
                              onEdit(teacher);
                              onClose();
                            }}
                            className="px-2.5 py-1.5 rounded-lg bg-surface2 hover:bg-border text-text text-xs font-bold flex items-center gap-1 cursor-pointer border border-border transition-colors"
                          >
                            <Edit className="w-3.5 h-3.5" />
                            <span>{teacherAadhaarDoc ? 'Update' : 'Upload'}</span>
                          </button>
                        </div>
                      </div>
                    </div>
                  );
                })()}

                <div className="p-3 rounded-xl bg-surface2 border border-border/70 space-y-1 sm:col-span-2">
                  <span className="text-[10.5px] text-text-muted font-medium block">Residential Address</span>
                  <span className="font-medium text-text text-xs leading-relaxed block">
                    {teacher.address || 'Address not registered'}
                  </span>
                </div>
              </div>
            </div>
          )}

          {/* TAB 2: ACADEMIC */}
          {activeTab === 'professional' && (
            <div className="space-y-4">
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3.5 text-xs">
                <div className="p-3 rounded-xl bg-surface2 border border-border/70 space-y-1">
                  <span className="text-[10.5px] text-text-muted font-medium block">Highest Qualification</span>
                  <span className="font-bold text-text text-sm block">{teacher.qualification || 'B.Ed, Master Degree'}</span>
                </div>

                <div className="p-3 rounded-xl bg-surface2 border border-border/70 space-y-1">
                  <span className="text-[10.5px] text-text-muted font-medium block">Designation</span>
                  <span className="font-bold text-text text-sm block">{teacher.designation || 'Teacher'}</span>
                </div>

                <div className="p-3 rounded-xl bg-surface2 border border-border/70 space-y-1">
                  <span className="text-[10.5px] text-text-muted font-medium block">Specialization / Subject</span>
                  <span className="font-bold text-indigo-900 dark:text-indigo-300 text-sm block">{teacher.subject || 'All Subjects'}</span>
                </div>

                <div className="p-3 rounded-xl bg-surface2 border border-border/70 space-y-1">
                  <span className="text-[10.5px] text-text-muted font-medium block">Assigned Class</span>
                  <span className="font-bold text-primary text-sm block">
                    {teacher.assignedClass && teacher.assignedClass !== 'none'
                      ? `Class ${teacher.assignedClass}${teacher.assignedSection ? ` - ${teacher.assignedSection}` : ''}`
                      : 'Subject Teacher (All Classes)'}
                  </span>
                </div>

                <div className="p-3 rounded-xl bg-surface2 border border-border/70 space-y-1">
                  <span className="text-[10.5px] text-text-muted font-medium block">Joining Date</span>
                  <span className="font-bold text-text text-sm block">{teacher.joiningDate || '—'}</span>
                </div>

                <div className="p-3 rounded-xl bg-surface2 border border-border/70 space-y-1">
                  <span className="text-[10.5px] text-text-muted font-medium block">Base Monthly Salary</span>
                  <span className="font-mono font-extrabold text-emerald-600 text-sm block">
                    ₹{Number(teacher.salary || 25000).toLocaleString('en-IN')} / month
                  </span>
                </div>
              </div>
            </div>
          )}

          {/* TAB 3: SALARY & PAYMENT HISTORY */}
          {activeTab === 'salary' && (
            <div className="space-y-4">
              {/* Current Salary Card with Pay Salary Button */}
              <div className="p-5 rounded-2xl bg-gradient-to-r from-emerald-600 to-teal-600 text-white shadow-md flex items-center justify-between">
                <div>
                  <span className="text-[11px] uppercase font-extrabold tracking-wider text-emerald-100 block">
                    Configured Monthly Compensation
                  </span>
                  <span className="text-2xl font-black font-mono block mt-1">
                    ₹{Number(teacher.salary || 25000).toLocaleString('en-IN')} / month
                  </span>
                  <span className="text-[11px] text-emerald-100 block mt-0.5">
                    Annual CTC Estimate: ₹{(Number(teacher.salary || 25000) * 12).toLocaleString('en-IN')}
                  </span>
                </div>

                <button
                  onClick={() => {
                    setSalaryAmount(teacher.salary || 25000);
                    setIsPaySalaryModalOpen(true);
                  }}
                  className="px-4 py-2.5 rounded-xl bg-white text-emerald-700 font-extrabold text-xs shadow-md hover:bg-emerald-50 transition-all cursor-pointer active:scale-95 flex items-center gap-1.5"
                >
                  <CreditCard className="w-4 h-4" />
                  <span>Pay Salary</span>
                </button>
              </div>

              {/* Salary Slips & History List */}
              <div className="rounded-xl border border-border overflow-hidden bg-card">
                <div className="px-4 py-2.5 bg-surface2 border-b border-border flex items-center justify-between">
                  <span className="text-xs font-bold text-text">Salary Payment History & Slips</span>
                  <span className="text-[10.5px] text-text-muted">{salaryHistory.length} disbursements recorded</span>
                </div>

                {salaryHistory.length === 0 ? (
                  <div className="py-8 text-center text-xs text-text-muted">
                    No salary payments logged yet.
                    <p className="text-[11px] mt-1 text-text-secondary">Click "Pay Salary" above to record a payment and print official salary voucher.</p>
                  </div>
                ) : (
                  <div className="divide-y divide-border max-h-56 overflow-y-auto">
                    {salaryHistory.map((item, idx) => (
                      <div key={idx} className="px-4 py-3 flex items-center justify-between text-xs hover:bg-surface2/50 transition-colors">
                        <div>
                          <div className="font-bold text-text flex items-center gap-2">
                            <span>₹{Number(item.amount).toLocaleString('en-IN')} Disbursed</span>
                            <span className="text-[10px] font-mono px-2 py-0.2 rounded bg-emerald-50 text-emerald-700 font-bold border border-emerald-200">
                              {item.mode}
                            </span>
                          </div>
                          <div className="text-[11px] text-text-secondary mt-0.5">
                            Month: <strong>{item.month}</strong> {item.note ? `• ${item.note}` : ''}
                          </div>
                          <div className="text-[10px] text-text-muted">
                            {item.timestampFormatted || item.date}
                          </div>
                        </div>

                        <button
                          onClick={() => printSalarySlip(item)}
                          className="px-2.5 py-1.5 rounded-lg bg-indigo-50 hover:bg-indigo-100 text-indigo-700 dark:bg-indigo-950/50 dark:text-indigo-300 font-bold text-xs flex items-center gap-1 cursor-pointer transition-all border border-indigo-200 dark:border-indigo-800"
                          title="Print / View Salary Slip Voucher (Mohar & Sign)"
                        >
                          <Printer className="w-3.5 h-3.5" />
                          <span>Slip</span>
                        </button>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            </div>
          )}

          {/* TAB 4: PORTAL CREDENTIALS */}
          {activeTab === 'credentials' && (
            <div className="space-y-4">
              <div className="p-3.5 rounded-xl bg-amber-500/10 border border-amber-500/20 text-xs text-amber-800 dark:text-amber-200">
                <span className="font-bold block mb-0.5">Faculty Portal Credentials:</span>
                Teachers can log in directly using this unique Auth Email and Password to mark attendance and manage records.
              </div>

              <div className="space-y-3 text-xs">
                {/* Auth Email */}
                <div className="p-3.5 rounded-xl bg-surface2 border border-border/70 flex items-center justify-between gap-2">
                  <div className="min-w-0">
                    <span className="text-[10.5px] text-text-muted font-medium block">Login Auth Email</span>
                    <span className="font-mono font-bold text-text text-xs sm:text-sm truncate block" title={teacher.authEmail || teacher.email}>
                      {teacher.authEmail || teacher.email || '—'}
                    </span>
                  </div>
                  <button
                    onClick={() => handleCopy(teacher.authEmail || teacher.email, 'Email')}
                    className="px-2.5 py-1.5 rounded-lg bg-card hover:bg-surface border border-border text-text font-bold text-xs flex items-center gap-1 cursor-pointer shrink-0 transition-all"
                  >
                    {copiedField === 'Email' ? <Check className="w-3.5 h-3.5 text-emerald-500" /> : <Copy className="w-3.5 h-3.5" />}
                    <span>{copiedField === 'Email' ? 'Copied' : 'Copy'}</span>
                  </button>
                </div>

                {/* Password with Reveal & Reset Action */}
                <div className="p-3.5 rounded-xl bg-surface2 border border-border/70 flex items-center justify-between gap-2">
                  <div className="min-w-0">
                    <span className="text-[10.5px] text-text-muted font-medium block">Portal Password</span>
                    <span className="font-mono font-bold text-text text-sm block">
                      {showPassword ? (teacher.password || '123456') : '••••••••'}
                    </span>
                  </div>
                  <div className="flex items-center gap-1.5 shrink-0">
                    <button
                      onClick={() => setShowPassword(!showPassword)}
                      className="p-1.5 rounded-lg bg-card hover:bg-surface border border-border text-text-muted hover:text-text cursor-pointer"
                      title={showPassword ? 'Hide Password' : 'Show Password'}
                    >
                      {showPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                    </button>
                    <button
                      onClick={() => {
                        setResetPasswordVal(teacher.password || '123456');
                        setIsResetPasswordModalOpen(true);
                      }}
                      className="px-2.5 py-1.5 rounded-lg bg-primary/10 hover:bg-primary/20 text-primary font-bold text-xs flex items-center gap-1 cursor-pointer transition-all"
                      title="Reset Portal Password"
                    >
                      <KeyRound className="w-3.5 h-3.5" />
                      <span>Reset</span>
                    </button>
                  </div>
                </div>

                {/* Teacher System ID */}
                <div className="p-3.5 rounded-xl bg-surface2 border border-border/70 flex items-center justify-between gap-2">
                  <div>
                    <span className="text-[10.5px] text-text-muted font-medium block">System Teacher ID</span>
                    <span className="font-mono font-bold text-text text-sm">{teacher.teacherId || 'T001'}</span>
                  </div>
                  <button
                    onClick={() => handleCopy(teacher.teacherId, 'Teacher ID')}
                    className="px-2.5 py-1.5 rounded-lg bg-card hover:bg-surface border border-border text-text font-bold text-xs flex items-center gap-1 cursor-pointer shrink-0 transition-all"
                  >
                    {copiedField === 'Teacher ID' ? <Check className="w-3.5 h-3.5 text-emerald-500" /> : <Copy className="w-3.5 h-3.5" />}
                    <span>{copiedField === 'Teacher ID' ? 'Copied' : 'Copy'}</span>
                  </button>
                </div>
              </div>
            </div>
          )}

          {/* TAB 5: ATTENDANCE & 1-CLICK MARKING */}
          {activeTab === 'attendance' && (() => {
            const historyLogs = [];
            let totalDays = 0;
            let presentDays = 0;
            let absentDays = 0;
            let leaveDays = 0;

            if (teacherAttendance && typeof teacherAttendance === 'object') {
              Object.entries(teacherAttendance).forEach(([date, recMap]) => {
                if (recMap && typeof recMap === 'object') {
                  const status = recMap[teacherKey] || recMap[teacher.teacherId] || recMap[teacher.authUid];
                  if (status) {
                    totalDays++;
                    if (status === 'present') presentDays++;
                    else if (status === 'absent') absentDays++;
                    else leaveDays++;
                    historyLogs.push({ date, status });
                  }
                }
              });
            }
            historyLogs.sort((a, b) => b.date.localeCompare(a.date));
            const attendanceRate = totalDays > 0 ? Math.round((presentDays / totalDays) * 100) : 100;

            return (
              <div className="space-y-4">
                {/* 1-Click Today Attendance Bar */}
                <div className="p-4 rounded-xl bg-surface2 border border-border/80">
                  <div className="flex items-center justify-between mb-2.5">
                    <span className="text-xs font-bold text-text">
                      Today's Attendance ({todayStr}):
                    </span>
                    {todayStatus && (
                      <span className="text-[10px] font-bold uppercase px-2 py-0.5 rounded-full bg-primary/10 text-primary">
                        Logged: {todayStatus}
                      </span>
                    )}
                  </div>
                  <div className="grid grid-cols-4 gap-2">
                    {[
                      { key: 'present', label: 'Present', color: 'hover:bg-emerald-500 hover:text-white', activeColor: 'bg-emerald-600 text-white' },
                      { key: 'absent', label: 'Absent', color: 'hover:bg-rose-500 hover:text-white', activeColor: 'bg-rose-600 text-white' },
                      { key: 'half_day', label: 'Half Day', color: 'hover:bg-amber-500 hover:text-white', activeColor: 'bg-amber-600 text-white' },
                      { key: 'leave', label: 'Leave', color: 'hover:bg-purple-500 hover:text-white', activeColor: 'bg-purple-600 text-white' }
                    ].map(btn => (
                      <button
                        key={btn.key}
                        onClick={() => handle1ClickAttendance(btn.key)}
                        className={`py-2 px-1 text-center rounded-lg text-xs font-bold transition-all border border-border cursor-pointer ${
                          todayStatus === btn.key ? btn.activeColor : `bg-card text-text ${btn.color}`
                        }`}
                      >
                        {btn.label}
                      </button>
                    ))}
                  </div>
                </div>

                {/* 1-Click Navigate to Full Teacher Attendance Register */}
                <button
                  type="button"
                  onClick={() => {
                    onClose();
                    if (typeof window !== 'undefined') {
                      localStorage.setItem('attendance_active_tab', 'teachers');
                      window.location.href = '/attendance?tab=teachers';
                    }
                  }}
                  className="w-full py-2.5 px-3 rounded-xl bg-gradient-to-r from-blue-700 to-indigo-700 hover:from-blue-800 hover:to-indigo-800 text-white text-xs font-bold shadow-md flex items-center justify-center gap-2 cursor-pointer transition-all active:scale-[0.99]"
                >
                  <CalendarCheck className="w-4 h-4 text-emerald-300" />
                  <span>Open Full Teacher Attendance Register (1-Click) ➔</span>
                </button>

                {/* Metrics row */}
                <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 text-xs">
                  <div className="p-3.5 rounded-xl bg-emerald-50 dark:bg-emerald-950/40 border border-emerald-200 dark:border-emerald-800">
                    <span className="text-[10px] uppercase font-bold text-emerald-700 dark:text-emerald-300 block">Attendance Rate</span>
                    <span className="text-xl font-extrabold text-emerald-800 dark:text-emerald-200 block mt-0.5">{attendanceRate}%</span>
                    <span className="text-[10px] text-emerald-600 dark:text-emerald-400 block">{presentDays} / {totalDays} days</span>
                  </div>

                  <div className="p-3.5 rounded-xl bg-surface2 border border-border/70">
                    <span className="text-[10px] uppercase font-bold text-text-secondary block">Present</span>
                    <span className="text-xl font-extrabold text-text block mt-0.5">{presentDays}</span>
                    <span className="text-[10px] text-text-muted block">Days present</span>
                  </div>

                  <div className="p-3.5 rounded-xl bg-rose-50 dark:bg-rose-950/40 border border-rose-200 dark:border-rose-900">
                    <span className="text-[10px] uppercase font-bold text-rose-700 dark:text-rose-300 block">Absent</span>
                    <span className="text-xl font-extrabold text-rose-800 dark:text-rose-200 block mt-0.5">{absentDays}</span>
                    <span className="text-[10px] text-rose-600 dark:text-rose-400 block">Days absent</span>
                  </div>

                  <div className="p-3.5 rounded-xl bg-amber-50 dark:bg-amber-950/40 border border-amber-200 dark:border-amber-900">
                    <span className="text-[10px] uppercase font-bold text-amber-700 dark:text-amber-300 block">Leave</span>
                    <span className="text-xl font-extrabold text-amber-800 dark:text-amber-200 block mt-0.5">{leaveDays}</span>
                    <span className="text-[10px] text-amber-600 dark:text-amber-400 block">Leave logged</span>
                  </div>
                </div>

                {/* History table */}
                <div className="rounded-xl border border-border overflow-hidden bg-card">
                  <div className="px-4 py-2.5 bg-surface2 border-b border-border flex items-center justify-between">
                    <span className="text-xs font-bold text-text">Recent Attendance Records</span>
                    <span className="text-[10.5px] text-text-muted">{historyLogs.length} entries</span>
                  </div>

                  {historyLogs.length === 0 ? (
                    <div className="py-8 text-center text-xs text-text-muted">
                      No attendance logged for this faculty member yet.
                      <p className="text-[11px] mt-1 text-text-secondary">Use the 1-click buttons above to log today's status.</p>
                    </div>
                  ) : (
                    <div className="divide-y divide-border max-h-56 overflow-y-auto">
                      {historyLogs.slice(0, 20).map(log => {
                        let badgeStyle = 'bg-emerald-50 text-emerald-700 border-emerald-200';
                        let label = 'PRESENT';
                        if (log.status === 'absent') {
                          badgeStyle = 'bg-rose-50 text-rose-700 border-rose-200';
                          label = 'ABSENT';
                        } else if (log.status === 'half_day') {
                          badgeStyle = 'bg-amber-50 text-amber-700 border-amber-200';
                          label = 'HALF DAY';
                        } else if (log.status === 'leave') {
                          badgeStyle = 'bg-purple-50 text-purple-700 border-purple-200';
                          label = 'LEAVE';
                        }

                        return (
                          <div key={log.date} className="px-4 py-2.5 flex items-center justify-between text-xs hover:bg-surface2/50 transition-colors">
                            <span className="font-semibold text-text">{log.date}</span>
                            <span className={`px-2.5 py-0.5 rounded-full text-[10px] font-bold border ${badgeStyle}`}>
                              {label}
                            </span>
                          </div>
                        );
                      })}
                    </div>
                  )}
                </div>
              </div>
            );
          })()}
        </div>

        {/* Modal Footer */}
        <div className="px-5 sm:px-6 py-3.5 border-t border-border bg-surface2 flex items-center justify-between text-xs">
          <span className="text-text-muted text-[11px]">
            Faculty ID: <strong className="font-mono text-text">{teacher.teacherId || 'T-ID'}</strong>
          </span>
          <button
            onClick={onClose}
            className="px-4 py-1.5 rounded-xl bg-card hover:bg-surface border border-border text-text font-bold text-xs cursor-pointer transition-all active:scale-95"
          >
            Close
          </button>
        </div>

      </div>

      {/* ─── MODAL 1: CONFIRM DISABLE / ENABLE (YES / NO) ────────────────── */}
      {isToggleActiveModalOpen && (
        <div className="fixed inset-0 z-60 bg-black/60 backdrop-blur-xs flex items-center justify-center p-4">
          <div className="bg-card border border-border rounded-2xl max-w-sm w-full p-5 shadow-2xl space-y-4 animate-in zoom-in-95">
            <div className="flex items-center gap-3">
              <div className={`w-10 h-10 rounded-full flex items-center justify-center shrink-0 ${
                isActive ? 'bg-amber-100 text-amber-600' : 'bg-emerald-100 text-emerald-600'
              }`}>
                <AlertTriangle className="w-5 h-5" />
              </div>
              <div>
                <h4 className="font-bold text-sm text-text">
                  {isActive ? 'Disable Faculty Account?' : 'Enable Faculty Account?'}
                </h4>
                <p className="text-xs text-text-muted">
                  {isActive
                    ? `Are you sure you want to disable ${teacher.name}'s account? They will not be able to log in.`
                    : `Are you sure you want to enable ${teacher.name}'s account? They will be granted portal access.`}
                </p>
              </div>
            </div>

            <div className="flex items-center justify-end gap-2 pt-2">
              <button
                type="button"
                onClick={() => setIsToggleActiveModalOpen(false)}
                className="px-4 py-2 rounded-xl border border-border bg-card text-text font-bold text-xs hover:bg-surface cursor-pointer"
              >
                No
              </button>
              <button
                type="button"
                onClick={handleConfirmToggleActive}
                className={`px-4 py-2 rounded-xl text-white font-bold text-xs cursor-pointer ${
                  isActive ? 'bg-amber-600 hover:bg-amber-700' : 'bg-emerald-600 hover:bg-emerald-700'
                }`}
              >
                Yes, {isActive ? 'Disable' : 'Enable'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* ─── MODAL 2: RESET PASSWORD ───────────────────────────────────────── */}
      {isResetPasswordModalOpen && (
        <div className="fixed inset-0 z-60 bg-black/60 backdrop-blur-xs flex items-center justify-center p-4">
          <div className="bg-card border border-border rounded-2xl max-w-sm w-full p-5 shadow-2xl space-y-4 animate-in zoom-in-95">
            <h4 className="font-bold text-sm text-text flex items-center gap-2">
              <KeyRound className="w-4 h-4 text-primary" />
              <span>Reset Portal Password</span>
            </h4>
            <p className="text-xs text-text-muted">
              Enter a new login password for <strong>{teacher.name}</strong> (minimum 6 characters):
            </p>
            <input
              type="text"
              value={resetPasswordVal}
              onChange={(e) => setResetPasswordVal(e.target.value)}
              className="w-full px-3.5 py-2 rounded-xl border border-border bg-surface text-text font-mono text-xs focus:outline-hidden focus:border-primary"
              placeholder="e.g. 123456"
            />
            <div className="flex items-center justify-end gap-2 pt-2">
              <button
                type="button"
                onClick={() => setIsResetPasswordModalOpen(false)}
                className="px-4 py-2 rounded-xl border border-border bg-card text-text font-bold text-xs hover:bg-surface cursor-pointer"
              >
                Cancel
              </button>
              <button
                type="button"
                onClick={handleConfirmResetPassword}
                className="px-4 py-2 rounded-xl bg-primary text-white font-bold text-xs hover:bg-primary-dark cursor-pointer"
              >
                Save New Password
              </button>
            </div>
          </div>
        </div>
      )}

      {/* ─── MODAL 3: CONFIRM DELETE ───────────────────────────────────────── */}
      {isDeleteModalOpen && (
        <div className="fixed inset-0 z-60 bg-black/60 backdrop-blur-xs flex items-center justify-center p-4">
          <div className="bg-card border border-border rounded-2xl max-w-sm w-full p-5 shadow-2xl space-y-4 animate-in zoom-in-95">
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 rounded-full bg-rose-100 text-rose-600 flex items-center justify-center shrink-0">
                <Trash2 className="w-5 h-5" />
              </div>
              <div>
                <h4 className="font-bold text-sm text-text">Permanently Delete Teacher?</h4>
                <p className="text-xs text-text-muted">
                  Are you sure you want to delete <strong>{teacher.name}</strong>? This action cannot be reversed.
                </p>
              </div>
            </div>
            <div className="flex items-center justify-end gap-2 pt-2">
              <button
                type="button"
                onClick={() => setIsDeleteModalOpen(false)}
                className="px-4 py-2 rounded-xl border border-border bg-card text-text font-bold text-xs hover:bg-surface cursor-pointer"
              >
                No, Keep
              </button>
              <button
                type="button"
                onClick={handleConfirmDelete}
                className="px-4 py-2 rounded-xl bg-rose-600 text-white font-bold text-xs hover:bg-rose-700 cursor-pointer"
              >
                Yes, Delete
              </button>
            </div>
          </div>
        </div>
      )}

      {/* ─── MODAL 4: PAY SALARY FORM ──────────────────────────────────────── */}
      {isPaySalaryModalOpen && (
        <div className="fixed inset-0 z-60 bg-black/60 backdrop-blur-xs flex items-center justify-center p-4">
          <div className="bg-card border border-border rounded-2xl max-w-md w-full p-6 shadow-2xl space-y-4 animate-in zoom-in-95">
            <div className="flex items-center justify-between border-b border-border pb-3">
              <h4 className="font-bold text-sm text-text flex items-center gap-2">
                <CreditCard className="w-4 h-4 text-emerald-600" />
                <span>Pay Salary — {teacher.name}</span>
              </h4>
              <button onClick={() => setIsPaySalaryModalOpen(false)} className="text-text-muted hover:text-text cursor-pointer">
                <X className="w-4 h-4" />
              </button>
            </div>

            <form onSubmit={handlePaySalarySubmit} className="space-y-3.5 text-xs">
              <div>
                <label className="font-bold text-text block mb-1">Salary Amount (₹)</label>
                <input
                  type="number"
                  value={salaryAmount}
                  onChange={(e) => setSalaryAmount(e.target.value)}
                  required
                  className="w-full px-3.5 py-2 rounded-xl border border-border bg-surface text-text font-mono font-bold text-sm focus:outline-hidden focus:border-primary"
                />
              </div>

              <div>
                <label className="font-bold text-text block mb-1">Salary Month</label>
                <input
                  type="text"
                  value={salaryMonth}
                  onChange={(e) => setSalaryMonth(e.target.value)}
                  required
                  className="w-full px-3.5 py-2 rounded-xl border border-border bg-surface text-text text-xs focus:outline-hidden focus:border-primary"
                  placeholder="e.g. October 2026"
                />
              </div>

              <div>
                <label className="font-bold text-text block mb-1">Payment Mode</label>
                <select
                  value={salaryMode}
                  onChange={(e) => setSalaryMode(e.target.value)}
                  className="w-full px-3.5 py-2 rounded-xl border border-border bg-surface text-text text-xs focus:outline-hidden focus:border-primary"
                >
                  <option value="Bank Transfer">Bank Transfer</option>
                  <option value="UPI / Online">UPI / Online</option>
                  <option value="Cash">Cash</option>
                  <option value="Cheque">Cheque</option>
                </select>
              </div>

              <div>
                <label className="font-bold text-text block mb-1">Transaction Ref / Note</label>
                <input
                  type="text"
                  value={salaryNote}
                  onChange={(e) => setSalaryNote(e.target.value)}
                  className="w-full px-3.5 py-2 rounded-xl border border-border bg-surface text-text text-xs focus:outline-hidden focus:border-primary"
                  placeholder="e.g. Txn #987623 / UTR / Cheque #"
                />
              </div>

              <div className="flex items-center justify-end gap-2 pt-3 border-t border-border">
                <button
                  type="button"
                  onClick={() => setIsPaySalaryModalOpen(false)}
                  className="px-4 py-2 rounded-xl border border-border bg-card text-text font-bold text-xs hover:bg-surface cursor-pointer"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="px-4 py-2 rounded-xl bg-emerald-600 hover:bg-emerald-700 text-white font-bold text-xs cursor-pointer shadow-md flex items-center gap-1.5"
                >
                  <Printer className="w-3.5 h-3.5" />
                  <span>Confirm & Print Voucher</span>
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Embedded Photo Cropper */}
      {isCropperOpen && (
        <ImageCropperModal
          imageSrc={imageToCrop}
          onCropComplete={handleCropComplete}
          onClose={() => setIsCropperOpen(false)}
          aspectRatio={3 / 4}
        />
      )}

      {/* Full Size Teacher Aadhaar Document Preview Modal */}
      {previewAadhaarModal && (teacher.aadhaarDocUrl || teacher.aadhaarDocPath || teacher.aadhaarCardUrl) && (
        <div className="fixed inset-0 z-[70] flex items-center justify-center p-4 bg-black/85 backdrop-blur-sm animate-in fade-in duration-200">
          <div className="bg-card border border-border rounded-2xl max-w-3xl w-full p-4 overflow-hidden shadow-2xl space-y-3">
            <div className="flex items-center justify-between pb-2 border-b border-border">
              <div className="flex items-center gap-2">
                <FileCheck className="w-5 h-5 text-emerald-600" />
                <div>
                  <h4 className="font-bold text-sm text-text">
                    Aadhaar Card: {teacher.name}
                  </h4>
                  <span className="text-[10px] text-text-muted font-mono">
                    UIDAI: {teacher.aadhaarNumber || teacher.aadharNumber || 'Not Linked'}
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
                src={teacher.aadhaarDocUrl || teacher.aadhaarDocPath || teacher.aadhaarCardUrl}
                alt="Teacher Aadhaar Document Full"
                className="max-h-[68vh] w-auto object-contain rounded-lg shadow-lg"
              />
            </div>

            <div className="flex items-center justify-between pt-2">
              <span className="text-[11px] text-text-muted">
                Teacher ID: <strong className="text-text font-mono">{teacher.teacherId || 'T001'}</strong>
              </span>
              <div className="flex items-center gap-2">
                <a
                  href={teacher.aadhaarDocUrl || teacher.aadhaarDocPath || teacher.aadhaarCardUrl}
                  download={`Aadhaar_Teacher_${(teacher.name || 'faculty').replace(/\s+/g, '_')}.jpg`}
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
