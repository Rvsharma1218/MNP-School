import React, { useState, useEffect, useRef } from 'react';
import { useSchoolStore } from '../lib/store';
import {
  X,
  Plus,
  Save,
  GraduationCap,
  Monitor,
  User,
  Phone,
  Mail,
  MapPin,
  Calendar,
  CreditCard,
  Camera,
  Upload,
  Crop,
  Trash2,
  Image as ImageIcon,
  FileText,
  Eye,
  FileCheck
} from 'lucide-react';
import ImageCropperModal from './ImageCropperModal';

export default function AddEditStudentModal({ student, isOpen, onClose }) {
  const { students, settings, currentUser, addStudent, updateStudent, getNextAdmissionNumber, getNextStudentId, showToast } = useSchoolStore();

  const isEdit = !!student;
  const teacherAssignedClass = currentUser?.role === 'teacher' ? (currentUser.assignedClass || 'Class Nursery') : '';

  const [studentType, setStudentType] = useState('school');
  const [isCropperOpen, setIsCropperOpen] = useState(false);
  const [imageToCrop, setImageToCrop] = useState(null);
  const [previewDocModal, setPreviewDocModal] = useState(false);
  const photoInputRef = useRef(null);
  const aadhaarInputRef = useRef(null);

  const [formData, setFormData] = useState({
    name: '',
    fatherName: '',
    motherName: '',
    mobile: '',
    alternateMobile: '',
    email: '',
    dob: '2010-01-01',
    gender: 'Male',
    address: '',
    photoPath: '',
    aadhaarNumber: '',
    aadhaarDocUrl: '',
    admissionNumber: '',
    studentId: '',
    rollNumber: '',
    className: teacherAssignedClass || settings.schoolClasses?.[0] || '10th',
    section: 'A',
    course: 'ADCA (12 Months)',
    batch: '10:00 AM - 12:00 PM',
    courseDurationMonths: 12,
    totalFees: '0',
    paidFees: '0',
    initialPaymentMode: 'Cash',
    dueDate: '',
    status: 'active',
    session: settings.currentSession || '2026-27',
    admissionDate: new Date().toISOString().split('T')[0]
  });

  useEffect(() => {
    if (student) {
      setStudentType(student.studentType || 'school');
      setFormData({
        ...student,
        name: student.name || '',
        fatherName: student.fatherName || '',
        motherName: student.motherName || '',
        mobile: student.mobile || '',
        alternateMobile: student.alternateMobile || '',
        email: student.email || '',
        dob: student.dob ? (typeof student.dob === 'string' ? student.dob.split('T')[0] : '2010-01-01') : '2010-01-01',
        gender: student.gender || 'Male',
        address: student.address || '',
        photoPath: student.photoPath || student.photoUrl || '',
        photoUrl: student.photoPath || student.photoUrl || '',
        aadhaarNumber: student.aadhaarNumber || student.aadharNumber || '',
        aadhaarDocUrl: student.aadhaarDocUrl || student.aadhaarDocPath || student.aadhaarCardUrl || '',
        admissionNumber: student.admissionNumber || student.admissionNo || '',
        studentId: student.studentId || student.id || '',
        rollNumber: student.rollNumber || '',
        className: student.className || teacherAssignedClass || settings.schoolClasses?.[0] || '10th',
        section: student.section || 'A',
        course: student.course || settings.computerCourses?.[0] || 'ADCA (12 Months)',
        batch: student.batch || settings.batches?.[0] || '10:00 AM - 12:00 PM',
        courseDurationMonths: Number(student.courseDurationMonths) || 12,
        totalFees: String(student.totalFees || 0),
        paidFees: String(student.paidFees || 0),
        initialPaymentMode: 'Cash'
      });
    } else {
      const activeSession = settings.currentSession || '2026-27';
      const nextAdm = getNextAdmissionNumber ? getNextAdmissionNumber(students, activeSession) : `ADM-2026-001`;
      const nextId = getNextStudentId ? getNextStudentId(students, activeSession) : `STU2026001`;
      const defaultClass = teacherAssignedClass || settings.schoolClasses?.[0] || '10th';

      setStudentType('school');
      setFormData({
        name: '',
        fatherName: '',
        motherName: '',
        mobile: '',
        alternateMobile: '',
        email: '',
        dob: '2010-01-01',
        gender: 'Male',
        address: '',
        photoPath: '',
        aadhaarNumber: '',
        aadhaarDocUrl: '',
        admissionNumber: nextAdm,
        studentId: nextId,
        rollNumber: '',
        className: defaultClass,
        section: 'A',
        course: settings.computerCourses?.[0] || 'ADCA (12 Months)',
        batch: settings.batches?.[0] || '10:00 AM - 12:00 PM',
        courseDurationMonths: 12,
        totalFees: '0',
        paidFees: '0',
        initialPaymentMode: 'Cash',
        dueDate: '',
        status: 'active',
        session: activeSession,
        admissionDate: new Date().toISOString().split('T')[0]
      });
    }
  }, [student, settings, students, isOpen, teacherAssignedClass]);

  if (!isOpen) return null;

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!formData.name?.trim() || !formData.mobile?.trim()) {
      showToast("Please provide at least Student Name and Mobile Number.", "error");
      return;
    }

    const payload = {
      ...formData,
      photoPath: formData.photoPath || '',
      photoUrl: formData.photoPath || '',
      aadhaarNumber: formData.aadhaarNumber || '',
      aadharNumber: formData.aadhaarNumber || '',
      aadhaarDocUrl: formData.aadhaarDocUrl || '',
      aadhaarDocPath: formData.aadhaarDocUrl || '',
      aadhaarCardUrl: formData.aadhaarDocUrl || '',
      studentType,
      totalFees: Number(formData.totalFees) || 0,
      paidFees: Number(formData.paidFees) || 0,
    };

    if (isEdit) {
      await updateStudent(student.id, payload);
      showToast(`Student "${formData.name}" updated successfully!`, "success");
      onClose();
    } else {
      const added = await addStudent(payload);
      if (added) {
        showToast(`New admission for "${formData.name}" completed in ${payload.className}!`, "success");
        onClose();
      }
    }
  };

  const handleAadhaarFileSelect = (e) => {
    const file = e.target.files?.[0];
    if (file) {
      if (!file.type.startsWith('image/')) {
        showToast('Please select a valid image file (JPG/PNG/WebP).', 'error');
        return;
      }
      const reader = new FileReader();
      reader.onload = (event) => {
        const img = new Image();
        img.onload = () => {
          const canvas = document.createElement('canvas');
          let width = img.width;
          let height = img.height;
          const maxWidth = 1000;
          if (width > maxWidth) {
            height = Math.round((height * maxWidth) / width);
            width = maxWidth;
          }
          canvas.width = width;
          canvas.height = height;
          const ctx = canvas.getContext('2d');
          ctx.drawImage(img, 0, 0, width, height);
          const compressedDataUrl = canvas.toDataURL('image/jpeg', 0.82);
          setFormData(prev => ({
            ...prev,
            aadhaarDocUrl: compressedDataUrl
          }));
          showToast('Aadhaar / ID document photo attached!', 'success');
        };
        img.onerror = () => {
          setFormData(prev => ({
            ...prev,
            aadhaarDocUrl: event.target.result
          }));
        };
        img.src = event.target.result;
      };
      reader.readAsDataURL(file);
    }
    e.target.value = '';
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
    // Reset input so re-selecting same file triggers onChange
    e.target.value = '';
  };

  const handleCropComplete = (croppedDataUrl) => {
    setFormData(prev => ({
      ...prev,
      photoPath: croppedDataUrl,
      photoUrl: croppedDataUrl
    }));
    showToast('Student photo cropped and applied!', 'success');
  };

  const handleOpenExistingPhotoCropper = () => {
    if (formData.photoPath) {
      setImageToCrop(formData.photoPath);
      setIsCropperOpen(true);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-xs overflow-y-auto">
      <div className="bg-card border border-border rounded-2xl w-full max-w-3xl shadow-2xl overflow-hidden my-8 animate-in fade-in zoom-in-95 duration-200">
        {/* Header */}
        <div className="px-6 py-4 border-b border-border bg-surface2/50 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-primary/10 text-primary flex items-center justify-center font-bold">
              {studentType === 'school' ? <GraduationCap className="w-5 h-5" /> : <Monitor className="w-5 h-5" />}
            </div>
            <div>
              <h3 className="font-bold text-base text-text">
                {isEdit ? 'Edit Student Details' : 'New Student Admission'}
              </h3>
              <p className="text-xs text-text-secondary">
                Fill in the academic, personal, and fee details
              </p>
            </div>
          </div>

          <button
            onClick={onClose}
            className="p-2 rounded-xl text-text-muted hover:text-text hover:bg-surface2 transition-colors cursor-pointer"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Student Type Selector */}
        <div className="p-6 border-b border-border bg-surface2/20">
          <label className="block text-xs font-bold text-text mb-2 uppercase tracking-wider">
            Enrollment Type
          </label>
          <div className="grid grid-cols-2 gap-3">
            <button
              type="button"
              onClick={() => setStudentType('school')}
              className={`p-3 rounded-xl border text-left flex items-center gap-3 transition-all cursor-pointer ${
                studentType === 'school'
                  ? 'border-primary bg-primary/10 text-primary font-bold shadow-xs'
                  : 'border-border bg-card text-text hover:bg-surface2'
              }`}
            >
              <div className={`w-8 h-8 rounded-lg flex items-center justify-center ${studentType === 'school' ? 'bg-primary text-white' : 'bg-surface2 text-text-muted'}`}>
                <GraduationCap className="w-4 h-4" />
              </div>
              <div>
                <div className="text-xs font-bold">School Student</div>
                <div className="text-[11px] text-text-secondary">Classes Nursery to 12th</div>
              </div>
            </button>

            <button
              type="button"
              onClick={() => setStudentType('computer')}
              className={`p-3 rounded-xl border text-left flex items-center gap-3 transition-all cursor-pointer ${
                studentType === 'computer'
                  ? 'border-teal-500 bg-teal-500/10 text-teal-600 dark:text-teal-400 font-bold shadow-xs'
                  : 'border-border bg-card text-text hover:bg-surface2'
              }`}
            >
              <div className={`w-8 h-8 rounded-lg flex items-center justify-center ${studentType === 'computer' ? 'bg-teal-500 text-white' : 'bg-surface2 text-text-muted'}`}>
                <Monitor className="w-4 h-4" />
              </div>
              <div>
                <div className="text-xs font-bold">Computer Institute</div>
                <div className="text-[11px] text-text-secondary">ADCA, DCA, Tally, Web, etc.</div>
              </div>
            </button>
          </div>
        </div>

        {/* Form Body */}
        <form onSubmit={handleSubmit} className="p-6 space-y-6 max-h-[68vh] overflow-y-auto custom-scrollbar">
          {/* Photo & Basic Info */}
          <div className="flex flex-col sm:flex-row gap-5 items-start bg-surface2/40 p-4 rounded-2xl border border-border/80">
            {/* Photo Avatar with Actions */}
            <div className="flex flex-col items-center gap-2 flex-shrink-0 w-full sm:w-auto">
              <div className="w-24 h-28 rounded-2xl bg-surface2 border-2 border-dashed border-amber-400/60 overflow-hidden relative flex items-center justify-center text-text-muted group shadow-sm bg-slate-900">
                {formData.photoPath ? (
                  <img
                    src={formData.photoPath}
                    alt="Preview"
                    className="w-full h-full object-cover"
                    onError={(e) => { e.currentTarget.style.display = 'none'; }}
                  />
                ) : (
                  <div className="flex flex-col items-center justify-center text-slate-400 p-2 text-center">
                    <User className="w-9 h-9 mb-1 text-slate-400/80" />
                    <span className="text-[9px] font-bold text-slate-400">No Photo</span>
                  </div>
                )}

                {/* Quick overlay button */}
                <label className="absolute inset-0 bg-black/50 text-white flex flex-col items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity cursor-pointer text-[10px] font-bold">
                  <Camera className="w-5 h-5 mb-1 text-amber-300" />
                  <span>{formData.photoPath ? 'Change' : 'Upload'}</span>
                  <input
                    ref={photoInputRef}
                    type="file"
                    accept="image/*"
                    onChange={handlePhotoFileSelect}
                    className="hidden"
                  />
                </label>
              </div>

              {/* Photo Action Buttons */}
              <div className="flex items-center gap-1.5 flex-wrap justify-center">
                <button
                  type="button"
                  onClick={() => photoInputRef.current?.click()}
                  className="px-2.5 py-1 rounded-lg bg-primary hover:bg-primary-dark text-white text-[10px] font-bold flex items-center gap-1 shadow-2xs cursor-pointer transition-colors"
                >
                  <Upload className="w-3 h-3" />
                  <span>{formData.photoPath ? 'Change' : 'Upload Photo'}</span>
                </button>

                {formData.photoPath && (
                  <>
                    <button
                      type="button"
                      onClick={handleOpenExistingPhotoCropper}
                      className="px-2 py-1 rounded-lg bg-amber-400 hover:bg-amber-500 text-slate-950 text-[10px] font-bold flex items-center gap-1 shadow-2xs cursor-pointer transition-colors"
                      title="Crop and frame photo"
                    >
                      <Crop className="w-3 h-3" />
                      <span>Crop</span>
                    </button>
                    <button
                      type="button"
                      onClick={() => setFormData(prev => ({ ...prev, photoPath: '', photoUrl: '' }))}
                      className="p-1 rounded-lg bg-rose-50 hover:bg-rose-100 text-rose-600 border border-rose-200 text-[10px] font-bold cursor-pointer transition-colors"
                      title="Remove Photo"
                    >
                      <Trash2 className="w-3.5 h-3.5" />
                    </button>
                  </>
                )}
              </div>
            </div>

            {/* Core Fields */}
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3.5 flex-1 w-full">
              <div>
                <label className="block text-[11px] font-bold text-text mb-1">
                  Full Name <span className="text-rose-500">*</span>
                </label>
                <input
                  type="text"
                  required
                  placeholder="e.g. Rahul Sharma"
                  value={formData.name || ''}
                  onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                  className="w-full px-3 py-2 rounded-xl bg-surface2 border border-border text-xs text-text focus:outline-none focus:border-primary"
                />
              </div>

              <div>
                <label className="block text-[11px] font-bold text-text mb-1">
                  Father's Name
                </label>
                <input
                  type="text"
                  placeholder="e.g. Manoj Sharma"
                  value={formData.fatherName || ''}
                  onChange={(e) => setFormData({ ...formData, fatherName: e.target.value })}
                  className="w-full px-3 py-2 rounded-xl bg-surface2 border border-border text-xs text-text focus:outline-none focus:border-primary"
                />
              </div>

              <div>
                <label className="block text-[11px] font-bold text-text mb-1">
                  Mother's Name
                </label>
                <input
                  type="text"
                  placeholder="e.g. Sunita Sharma"
                  value={formData.motherName || ''}
                  onChange={(e) => setFormData({ ...formData, motherName: e.target.value })}
                  className="w-full px-3 py-2 rounded-xl bg-surface2 border border-border text-xs text-text focus:outline-none focus:border-primary"
                />
              </div>

              <div>
                <label className="block text-[11px] font-bold text-text mb-1">
                  Mobile Number (WhatsApp) <span className="text-rose-500">*</span>
                </label>
                <input
                  type="tel"
                  required
                  placeholder="10-digit mobile"
                  value={formData.mobile || ''}
                  onChange={(e) => setFormData({ ...formData, mobile: e.target.value })}
                  className="w-full px-3 py-2 rounded-xl bg-surface2 border border-border text-xs text-text focus:outline-none focus:border-primary"
                />
              </div>
            </div>
          </div>

          {/* Academic Particulars */}
          <div className="p-4 rounded-xl bg-surface2/50 border border-border space-y-3">
            <h4 className="text-xs font-bold text-text uppercase tracking-wider flex items-center gap-2">
              <span>Academic Details</span>
              <span className="text-[10px] text-text-muted font-normal">• {studentType.toUpperCase()}</span>
            </h4>

            {/* ID, Admission Number and Session Indicators */}
            <div className="grid grid-cols-1 sm:grid-cols-3 gap-3 pb-2 border-b border-border/50">
              <div>
                <label className="block text-[11px] font-bold text-text mb-1 flex items-center justify-between">
                  <span>Admission Number</span>
                  <span className="text-[9px] bg-emerald-500/10 text-emerald-600 dark:text-emerald-400 px-1.5 py-0.5 rounded font-sans font-bold uppercase">Auto</span>
                </label>
                <div className="w-full px-3 py-2 rounded-xl bg-surface2 border border-border text-xs text-text font-mono font-bold flex items-center justify-between">
                  <span>{formData.admissionNumber || 'Auto-generated'}</span>
                  <span className="text-[10px] text-text-muted">🔒</span>
                </div>
              </div>

              <div>
                <label className="block text-[11px] font-bold text-text mb-1 flex items-center justify-between">
                  <span>Student System ID</span>
                  <span className="text-[9px] bg-primary/10 text-primary px-1.5 py-0.5 rounded font-sans font-bold uppercase">Auto</span>
                </label>
                <div className="w-full px-3 py-2 rounded-xl bg-primary/10 border border-primary/25 text-xs text-primary font-mono font-bold flex items-center justify-between">
                  <span>{formData.studentId || 'Auto on save'}</span>
                  <span className="text-[10px] text-primary">🔒</span>
                </div>
              </div>

              <div>
                <label className="block text-[11px] font-bold text-text mb-1">
                  Academic Session
                </label>
                <input
                  type="text"
                  value={formData.session || '2026-27'}
                  onChange={(e) => {
                    const newSess = e.target.value;
                    if (!isEdit && getNextAdmissionNumber && getNextStudentId) {
                      setFormData({
                        ...formData,
                        session: newSess,
                        admissionNumber: getNextAdmissionNumber(students, newSess),
                        studentId: getNextStudentId(students, newSess)
                      });
                    } else {
                      setFormData({ ...formData, session: newSess });
                    }
                  }}
                  placeholder="e.g. 2026-27 or 2027-28"
                  className="w-full px-3 py-2 rounded-xl bg-card border border-border text-xs text-text font-bold focus:outline-none focus:border-primary"
                />
              </div>
            </div>

            {studentType === 'school' ? (
              <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
                <div>
                  <label className="block text-[11px] font-bold text-text mb-1">Class</label>
                  <select
                    value={formData.className || ''}
                    onChange={(e) => setFormData({ ...formData, className: e.target.value })}
                    className="w-full px-3 py-2 rounded-xl bg-card border border-border text-xs text-text focus:outline-none focus:border-primary cursor-pointer"
                  >
                    {settings.schoolClasses?.map(c => (
                      <option key={c} value={c}>Class {c}</option>
                    ))}
                  </select>
                </div>

                <div>
                  <label className="block text-[11px] font-bold text-text mb-1">Section</label>
                  <select
                    value={formData.section || ''}
                    onChange={(e) => setFormData({ ...formData, section: e.target.value })}
                    className="w-full px-3 py-2 rounded-xl bg-card border border-border text-xs text-text focus:outline-none focus:border-primary cursor-pointer"
                  >
                    {(settings.sections || ['A', 'B', 'C', 'D']).map(s => (
                      <option key={s} value={s}>Section {s}</option>
                    ))}
                  </select>
                </div>

                <div>
                  <label className="block text-[11px] font-bold text-text mb-1">Roll Number</label>
                  <input
                    type="text"
                    placeholder="e.g. 101"
                    value={formData.rollNumber || ''}
                    onChange={(e) => setFormData({ ...formData, rollNumber: e.target.value })}
                    className="w-full px-3 py-2 rounded-xl bg-card border border-border text-xs text-text focus:outline-none focus:border-primary"
                  />
                </div>
              </div>
            ) : (
              <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
                <div>
                  <label className="block text-[11px] font-bold text-text mb-1">Course</label>
                  <select
                    value={formData.course || ''}
                    onChange={(e) => setFormData({ ...formData, course: e.target.value })}
                    className="w-full px-3 py-2 rounded-xl bg-card border border-border text-xs text-text focus:outline-none focus:border-primary cursor-pointer"
                  >
                    {settings.computerCourses?.map(c => (
                      <option key={c} value={c}>{c}</option>
                    ))}
                  </select>
                </div>

                <div>
                  <label className="block text-[11px] font-bold text-text mb-1">Batch Time</label>
                  <select
                    value={formData.batch || ''}
                    onChange={(e) => setFormData({ ...formData, batch: e.target.value })}
                    className="w-full px-3 py-2 rounded-xl bg-card border border-border text-xs text-text focus:outline-none focus:border-primary cursor-pointer"
                  >
                    {settings.batches?.map(b => (
                      <option key={b} value={b}>{b}</option>
                    ))}
                  </select>
                </div>

                <div>
                  <label className="block text-[11px] font-bold text-text mb-1">Duration (Months)</label>
                  <input
                    type="number"
                    value={formData.courseDurationMonths || 6}
                    onChange={(e) => setFormData({ ...formData, courseDurationMonths: Number(e.target.value) })}
                    className="w-full px-3 py-2 rounded-xl bg-card border border-border text-xs text-text focus:outline-none focus:border-primary"
                  />
                </div>
              </div>
            )}
          </div>

          {/* Personal & Contact Details */}
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3.5">
            <div>
              <label className="block text-[11px] font-bold text-text mb-1">Date of Birth</label>
              <input
                type="date"
                value={formData.dob || '2010-01-01'}
                onChange={(e) => setFormData({ ...formData, dob: e.target.value })}
                className="w-full px-3 py-2 rounded-xl bg-surface2 border border-border text-xs text-text focus:outline-none focus:border-primary"
              />
            </div>

            <div>
              <label className="block text-[11px] font-bold text-text mb-1">Gender</label>
              <select
                value={formData.gender || 'Male'}
                onChange={(e) => setFormData({ ...formData, gender: e.target.value })}
                className="w-full px-3 py-2 rounded-xl bg-surface2 border border-border text-xs text-text focus:outline-none focus:border-primary cursor-pointer"
              >
                <option value="Male">Male</option>
                <option value="Female">Female</option>
                <option value="Other">Other</option>
              </select>
            </div>

            <div>
              <label className="block text-[11px] font-bold text-text mb-1">Alternate Mobile</label>
              <input
                type="tel"
                placeholder="Optional"
                value={formData.alternateMobile || ''}
                onChange={(e) => setFormData({ ...formData, alternateMobile: e.target.value })}
                className="w-full px-3 py-2 rounded-xl bg-surface2 border border-border text-xs text-text focus:outline-none focus:border-primary"
              />
            </div>
          </div>

          <div>
            <label className="block text-[11px] font-bold text-text mb-1">Residential Address</label>
            <input
              type="text"
              placeholder="Full address, City, Pincode"
              value={formData.address || ''}
              onChange={(e) => setFormData({ ...formData, address: e.target.value })}
              className="w-full px-3 py-2 rounded-xl bg-surface2 border border-border text-xs text-text focus:outline-none focus:border-primary"
            />
          </div>

          {/* Identity & Aadhaar Card Documents */}
          <div className="p-4 rounded-xl bg-surface2/60 border border-border space-y-3">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-1">
              <h4 className="text-xs font-bold text-text uppercase tracking-wider flex items-center gap-2">
                <FileCheck className="w-4 h-4 text-emerald-600" />
                <span>Identity & Aadhaar Card Document</span>
              </h4>
              <span className="text-[10px] text-text-muted">Student Official Verification Document</span>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-4 items-center">
              <div>
                <label className="block text-[11px] font-bold text-text mb-1">
                  12-Digit Aadhaar Card Number
                </label>
                <input
                  type="text"
                  maxLength={14}
                  placeholder="e.g. 1234 5678 9012"
                  value={formData.aadhaarNumber || ''}
                  onChange={(e) => setFormData({ ...formData, aadhaarNumber: e.target.value })}
                  className="w-full px-3.5 py-2.5 rounded-xl bg-card border border-border text-xs text-text focus:outline-none focus:border-primary font-mono font-bold"
                />
                <span className="text-[10px] text-text-muted mt-1 block">Government UIDAI Number for student record</span>
              </div>

              {/* Aadhaar Card Document Upload Card */}
              <div className="flex items-center gap-3 bg-card p-3 rounded-xl border border-dashed border-border min-w-0">
                {formData.aadhaarDocUrl ? (
                  <div className="relative w-20 h-14 rounded-lg overflow-hidden border border-border flex-shrink-0 bg-slate-900 group">
                    <img
                      src={formData.aadhaarDocUrl}
                      alt="Aadhaar Card"
                      className="w-full h-full object-cover"
                    />
                    <button
                      type="button"
                      onClick={() => setPreviewDocModal(true)}
                      className="absolute inset-0 bg-black/50 text-white flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity cursor-pointer text-[10px]"
                      title="View Document"
                    >
                      <Eye className="w-4 h-4 text-white" />
                    </button>
                  </div>
                ) : (
                  <div className="w-20 h-14 rounded-lg bg-surface2 border border-border flex flex-col items-center justify-center text-text-muted flex-shrink-0">
                    <FileText className="w-5 h-5 text-text-muted/60" />
                    <span className="text-[8px] font-bold mt-0.5">No Doc</span>
                  </div>
                )}

                <div className="flex-1 min-w-0">
                  <span className="text-[11px] font-bold text-text block truncate">
                    {formData.aadhaarDocUrl ? 'Aadhaar Card Photo Attached' : 'Attach Aadhaar Card Photo'}
                  </span>
                  <span className="text-[9.5px] text-text-muted block">
                    {formData.aadhaarDocUrl ? 'Click view or change photo' : 'Front/Both sides photo (Auto-compressed)'}
                  </span>
                  <div className="flex items-center gap-2 mt-1.5 flex-wrap">
                    <input
                      ref={aadhaarInputRef}
                      type="file"
                      accept="image/*"
                      onChange={handleAadhaarFileSelect}
                      className="hidden"
                    />
                    <button
                      type="button"
                      onClick={() => aadhaarInputRef.current?.click()}
                      className="px-2.5 py-1 rounded-lg bg-emerald-600 hover:bg-emerald-700 text-white text-[10px] font-bold flex items-center gap-1 cursor-pointer transition-colors"
                    >
                      <Upload className="w-3 h-3" />
                      <span>{formData.aadhaarDocUrl ? 'Change' : 'Upload Card'}</span>
                    </button>
                    {formData.aadhaarDocUrl && (
                      <>
                        <button
                          type="button"
                          onClick={() => setPreviewDocModal(true)}
                          className="px-2 py-1 rounded-lg bg-surface2 hover:bg-surface2/80 text-text text-[10px] font-bold flex items-center gap-1 cursor-pointer border border-border"
                        >
                          <Eye className="w-3 h-3" />
                          <span>View</span>
                        </button>
                        <button
                          type="button"
                          onClick={() => setFormData(prev => ({ ...prev, aadhaarDocUrl: '' }))}
                          className="p-1 rounded-lg bg-rose-50 text-rose-600 border border-rose-200 text-[10px] cursor-pointer hover:bg-rose-100"
                          title="Remove attached Aadhaar document"
                        >
                          <Trash2 className="w-3 h-3" />
                        </button>
                      </>
                    )}
                  </div>
                </div>
              </div>
            </div>
          </div>

          {/* Footer Submit */}
          <div className="pt-3 border-t border-border flex items-center justify-end gap-3">
            <button
              type="button"
              onClick={onClose}
              className="px-4 py-2 rounded-xl bg-surface2 hover:bg-surface2/80 text-text font-semibold text-xs transition-colors cursor-pointer"
            >
              Cancel
            </button>

            <button
              type="submit"
              className="px-6 py-2.5 rounded-xl bg-primary hover:bg-primary-dark text-white font-bold text-xs shadow-md shadow-primary/20 flex items-center gap-2 transition-all cursor-pointer transform active:scale-95"
            >
              <Save className="w-4 h-4" />
              <span>{isEdit ? 'Save Changes' : 'Complete Admission'}</span>
            </button>
          </div>
        </form>
      </div>

      {/* Interactive Photo Cropper Modal */}
      <ImageCropperModal
        isOpen={isCropperOpen}
        imageSrc={imageToCrop}
        title="Crop Student Photo"
        initialAspect="3:4"
        onCropComplete={handleCropComplete}
        onClose={() => {
          setIsCropperOpen(false);
          setImageToCrop(null);
        }}
      />

      {/* Full Document Preview Modal */}
      {previewDocModal && formData.aadhaarDocUrl && (
        <div className="fixed inset-0 z-[60] flex items-center justify-center p-4 bg-black/80 backdrop-blur-sm animate-in fade-in duration-200">
          <div className="bg-card border border-border rounded-2xl max-w-2xl w-full p-4 overflow-hidden shadow-2xl space-y-3">
            <div className="flex items-center justify-between pb-2 border-b border-border">
              <div className="flex items-center gap-2">
                <FileCheck className="w-5 h-5 text-emerald-600" />
                <span className="font-bold text-sm text-text">Aadhaar Card / Document Preview</span>
              </div>
              <button
                type="button"
                onClick={() => setPreviewDocModal(false)}
                className="p-1 rounded-lg bg-surface2 text-text-muted hover:text-text cursor-pointer"
              >
                <X className="w-4 h-4" />
              </button>
            </div>
            <div className="max-h-[70vh] overflow-auto rounded-xl border border-border bg-slate-950 flex items-center justify-center p-2">
              <img
                src={formData.aadhaarDocUrl}
                alt="Aadhaar Document Full"
                className="max-h-[65vh] w-auto object-contain rounded-lg shadow-md"
              />
            </div>
            <div className="flex justify-between items-center pt-2">
              <span className="text-xs text-text-muted font-mono">
                {formData.aadhaarNumber ? `UIDAI No: ${formData.aadhaarNumber}` : 'Document Attached'}
              </span>
              <button
                type="button"
                onClick={() => setPreviewDocModal(false)}
                className="px-4 py-1.5 rounded-xl bg-primary text-white font-bold text-xs cursor-pointer"
              >
                Close Preview
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
