'use client';

import TeacherPermissionsModal from './TeacherPermissionsModal';
import TeacherProfileModal from './TeacherProfileModal';

import React, { useState, useRef } from 'react';
import { useSchoolStore, getNextTeacherId, getActiveSchoolId } from '../lib/store';
import { t } from '../lib/translations';
import { exportFacultyToExcel, exportFacultyPDF } from '../lib/exportUtils';
import ImageCropperModal from './ImageCropperModal';
import {
  GraduationCap,
  Plus,
  Trash2,
  Edit,
  Phone,
  Mail,
  ShieldCheck,
  UserCheck,
  CheckCircle,
  X,
  Search,
  Key,
  Copy,
  Download,
  FileSpreadsheet,
  FileText,
  Calendar,
  MapPin,
  User,
  BookOpen,
  Briefcase,
  Award,
  CreditCard,
  Camera,
  Upload,
  Crop,
  LayoutGrid,
  List,
  Eye,
  Users,
  CheckCircle2,
  Filter,
  FileCheck
} from 'lucide-react';
import * as XLSX from 'xlsx';

const parseClassString = (val) => {
  if (Array.isArray(val)) return val.join(', ');
  if (typeof val === 'string') return val;
  if (val != null) return String(val);
  return '';
};

export default function TeachersView() {
  const {
    teachers = [],
    settings,
    addTeacher,
    updateTeacher,
    deleteTeacher,
    userRole,
    setUserRole,
    currentTeacher,
    setCurrentTeacher,
    teacherApplications,
    openEnquiriesModal,
    showToast
  } = useSchoolStore();

  const [isAddOpen, setIsAddOpen] = useState(false);
  const [isPermsModalOpen, setIsPermsModalOpen] = useState(false);
  const [editingTeacher, setEditingTeacher] = useState(null);
  const [selectedTeacherForHistory, setSelectedTeacherForHistory] = useState(null);
  const [selectedTeacherForProfile, setSelectedTeacherForProfile] = useState(null);
  const [copiedId, setCopiedId] = useState(null);
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedClassFilter, setSelectedClassFilter] = useState('all');
  const [selectedDesignationFilter, setSelectedDesignationFilter] = useState('all');
  const [selectedStatusFilter, setSelectedStatusFilter] = useState('all');
  const [viewMode, setViewMode] = useState('grid'); // 'grid' | 'table'
  const [isCropperOpen, setIsCropperOpen] = useState(false);
  const [imageToCrop, setImageToCrop] = useState(null);
  const [previewAadhaarDocModal, setPreviewAadhaarDocModal] = useState(false);
  const [isImportModalOpen, setIsImportModalOpen] = useState(false);
  const [importingFaculty, setImportingFaculty] = useState(false);
  const [facultyImportPreview, setFacultyImportPreview] = useState(null);
  const photoInputRef = useRef(null);
  const aadhaarDocInputRef = useRef(null);
  const facultyImportInputRef = useRef(null);

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

  const handleCropComplete = (croppedDataUrl) => {
    setFormData(prev => ({
      ...prev,
      photoUrl: croppedDataUrl
    }));
    showToast('Teacher profile photo cropped & applied!', 'success');
  };

  const defaultFormData = {
    name: '',
    fatherName: '',
    motherName: '',
    mobile: '',
    alternateMobile: '',
    password: '123456',
    assignedClass: '',
    assignedSection: '',
    dob: '1992-05-15',
    gender: 'Male',
    address: '',
    aadhaarNumber: '',
    qualification: 'B.Ed, M.Sc',
    designation: 'Subject Teacher',
    subject: 'All Subjects',
    joiningDate: new Date().toISOString().split('T')[0],
    salary: 25000,
    photoUrl: '',
    aadhaarDocUrl: '',
    aadhaarDocPath: ''
  };

  const [formData, setFormData] = useState(defaultFormData);

  const activeSchoolId = getActiveSchoolId();

  const handleOpenAdd = () => {
    setEditingTeacher(null);
    setFormData({
      ...defaultFormData,
      assignedClass: ''
    });
    setIsAddOpen(true);
  };

  const handleOpenEdit = (t) => {
    setEditingTeacher(t);
    setFormData({
      name: t.name || '',
      fatherName: t.fatherName || '',
      motherName: t.motherName || '',
      mobile: t.mobile || '',
      alternateMobile: t.alternateMobile || '',
      password: t.password || '123456',
      assignedClass: (() => {
        const raw = t.assignedClass ?? t.assignedClasses;
        const str = parseClassString(raw);
        return (str && str !== 'none' && str !== 'None') ? str : '';
      })(),
      assignedSection: t.assignedSection || '',
      dob: t.dob ? (typeof t.dob === 'string' ? t.dob.split('T')[0] : t.dob) : '1992-05-15',
      gender: t.gender || 'Male',
      address: t.address || '',
      aadhaarNumber: t.aadhaarNumber || t.aadharNumber || '',
      qualification: t.qualification || 'B.Ed, M.Sc',
      designation: t.designation || 'Teacher',
      subject: t.subject || t.subjects || 'All Subjects',
      joiningDate: t.joiningDate ? (typeof t.joiningDate === 'string' ? t.joiningDate.split('T')[0] : t.joiningDate) : new Date().toISOString().split('T')[0],
      salary: t.salary || 25000,
      photoUrl: t.photoUrl || '',
      aadhaarDocUrl: t.aadhaarDocUrl || t.aadhaarDocPath || t.aadhaarCardUrl || '',
      aadhaarDocPath: t.aadhaarDocUrl || t.aadhaarDocPath || t.aadhaarCardUrl || ''
    });
    setIsAddOpen(true);
  };

  const handleAadhaarDocFileSelect = (e) => {
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
            aadhaarDocUrl: compressedDataUrl,
            aadhaarDocPath: compressedDataUrl
          }));
          showToast('Teacher Aadhaar / ID document photo attached!', 'success');
        };
        img.onerror = () => {
          setFormData(prev => ({
            ...prev,
            aadhaarDocUrl: event.target.result,
            aadhaarDocPath: event.target.result
          }));
        };
        img.src = event.target.result;
      };
      reader.readAsDataURL(file);
    }
    e.target.value = '';
  };

  const downloadFacultyImportTemplate = () => {
    const sampleRows = [
      {
        'Teacher Name *': 'Ramesh Kumar',
        'Mobile Number *': '9876543210',
        'Gender': 'Male',
        'Date of Birth (YYYY-MM-DD)': '1990-05-15',
        'Designation': 'Subject Teacher',
        'Subject': 'Mathematics',
        'Qualification': 'B.Ed, M.Sc',
        'Assigned Class': '10th',
        'Assigned Section': 'A',
        'Salary': 25000,
        'Aadhaar Number': '123456789012',
        'Residential Address': 'Siwan, Bihar'
      },
      {
        'Teacher Name *': 'Pooja Sharma',
        'Mobile Number *': '9876543211',
        'Gender': 'Female',
        'Date of Birth (YYYY-MM-DD)': '1994-08-20',
        'Designation': 'Senior Teacher',
        'Subject': 'Science',
        'Qualification': 'B.Ed, B.Sc',
        'Assigned Class': '8th',
        'Assigned Section': 'A',
        'Salary': 22000,
        'Aadhaar Number': '987654321098',
        'Residential Address': 'Patna, Bihar'
      }
    ];
    const ws = XLSX.utils.json_to_sheet(sampleRows);
    const wb = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, ws, 'Faculty_Import_Template');
    XLSX.writeFile(wb, 'Faculty_Import_Template.xlsx');
    showToast('Downloaded Faculty Import Template!', 'success');
  };

  const handleFacultyFileSelect = (e) => {
    const file = e.target.files?.[0];
    if (!file) return;
    const reader = new FileReader();
    reader.onload = (event) => {
      try {
        const data = new Uint8Array(event.target.result);
        const workbook = XLSX.read(data, { type: 'array' });
        const firstSheetName = workbook.SheetNames[0];
        const rows = XLSX.utils.sheet_to_json(workbook.Sheets[firstSheetName]);
        if (!rows || rows.length === 0) {
          showToast('The selected file has no data rows.', 'error');
          return;
        }
        const parsed = rows.map((r) => ({
          name: r['Teacher Name *'] || r['Teacher Name'] || r['Name'] || '',
          mobile: String(r['Mobile Number *'] || r['Mobile Number'] || r['Mobile'] || '').replace(/[^0-9]/g, ''),
          gender: r['Gender'] || 'Male',
          dob: r['Date of Birth (YYYY-MM-DD)'] || r['DOB'] || '1992-05-15',
          designation: r['Designation'] || 'Subject Teacher',
          subject: r['Subject'] || 'All Subjects',
          qualification: r['Qualification'] || 'B.Ed',
          assignedClass: r['Assigned Class'] ? String(r['Assigned Class']).replace(/^Class\s*/i, '') : '',
          assignedSection: r['Assigned Section'] || '',
          salary: Number(r['Salary']) || 20000,
          aadhaarNumber: String(r['Aadhaar Number'] || r['Aadhaar'] || '').replace(/[^0-9]/g, ''),
          address: r['Residential Address'] || r['Address'] || '',
          isValid: !!(r['Teacher Name *'] || r['Teacher Name'] || r['Name'])
        }));
        setFacultyImportPreview(parsed);
        setIsImportModalOpen(true);
      } catch (err) {
        showToast('Error reading Excel file: ' + err.message, 'error');
      }
    };
    reader.readAsArrayBuffer(file);
    e.target.value = '';
  };

  const handleConfirmImportFaculty = async () => {
    if (!facultyImportPreview || facultyImportPreview.length === 0) return;
    setImportingFaculty(true);
    let addedCount = 0;
    try {
      for (const row of facultyImportPreview) {
        if (!row.isValid) continue;
        await addTeacher({
          name: row.name,
          mobile: row.mobile,
          gender: row.gender,
          dob: row.dob,
          designation: row.designation,
          subject: row.subject,
          qualification: row.qualification,
          assignedClass: row.assignedClass,
          assignedSection: row.assignedSection,
          salary: row.salary,
          aadhaarNumber: row.aadhaarNumber,
          address: row.address,
          password: '123456'
        });
        addedCount++;
      }
      showToast(`Successfully imported ${addedCount} teachers into system!`, 'success');
      setIsImportModalOpen(false);
      setFacultyImportPreview(null);
    } catch (err) {
      showToast('Error importing teachers: ' + err.message, 'error');
    } finally {
      setImportingFaculty(false);
    }
  };

  const handleCopyEmail = (email, id) => {
    if (!email) return;
    navigator.clipboard.writeText(email);
    setCopiedId(id);
    showToast(`Copied "${email}" to clipboard!`, 'info');
    setTimeout(() => setCopiedId(null), 2000);
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!formData.name?.trim()) {
      showToast("Please enter teacher name.", "error");
      return;
    }

    try {
      const payload = {
        ...formData,
        aadhaarDocUrl: formData.aadhaarDocUrl || '',
        aadhaarDocPath: formData.aadhaarDocUrl || '',
        aadhaarCardUrl: formData.aadhaarDocUrl || ''
      };
      if (editingTeacher) {
        const targetId = editingTeacher.id || editingTeacher.teacherId || editingTeacher.authUid;
        payload.id = editingTeacher.id || editingTeacher.teacherId || targetId;
        payload.teacherId = editingTeacher.teacherId || editingTeacher.id || targetId;
        payload.authUid = editingTeacher.authUid || targetId;
        payload.authEmail = editingTeacher.authEmail || editingTeacher.email || '';
        payload.email = editingTeacher.authEmail || editingTeacher.email || '';
        await updateTeacher(targetId, payload);
        showToast(`Teacher "${formData.name}" updated successfully!`, "success");
      } else {
        await addTeacher(payload);
        showToast(`Teacher "${formData.name}" added successfully with name-based Auth email!`, "success");
      }
      setIsAddOpen(false);
    } catch (err) {
      showToast(`Error saving teacher: ${err.message || err}`, "error");
    }
  };

  // Preview generated email in the modal
  const nextTeacherId = getNextTeacherId(teachers);
  const namePart = (formData.name || '')
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]/g, '')
    .slice(0, 12);
  const schoolPart = (activeSchoolId || 'school001').toLowerCase().replace(/[^a-z0-9]/g, '');
  const previewEmail = `${namePart || 'name'}.${(editingTeacher?.teacherId || nextTeacherId).toLowerCase()}@${schoolPart}.teachers`;

  const totalFaculty = (teachers || []).length;
  const classTeachersCount = (teachers || []).filter(t => t && t.assignedClass && t.assignedClass !== 'none' && t.assignedClass !== 'None').length;
  const subjectTeachersCount = totalFaculty - classTeachersCount;
  const activeStaffCount = (teachers || []).filter(t => t && t.active !== false && t.status !== 'inactive').length;

  const availableClasses = settings?.classes || settings?.schoolClasses || [
    'Nursery', 'LKG', 'UKG', '1st', '2nd', '3rd', '4th', '5th',
    '6th', '7th', '8th', '9th', '10th', '11th-Sci', '12th-Sci'
  ];

  const filteredTeachers = (teachers || []).filter(t => {
    if (!t) return false;
    // 1. Search Query
    if (searchQuery.trim()) {
      const q = searchQuery.toLowerCase();
      const match = (
        (t.name && t.name.toLowerCase().includes(q)) ||
        (t.teacherId && t.teacherId.toLowerCase().includes(q)) ||
        (t.mobile && t.mobile.includes(q)) ||
        (t.subject && t.subject.toLowerCase().includes(q)) ||
        (t.qualification && t.qualification.toLowerCase().includes(q)) ||
        (t.assignedClass && String(t.assignedClass).toLowerCase().includes(q))
      );
      if (!match) return false;
    }

    // 2. Class Filter
    if (selectedClassFilter !== 'all') {
      const raw = t.assignedClass ?? t.assignedClasses;
      const str = parseClassString(raw).trim();
      if (selectedClassFilter === 'subject_only') {
        if (str && str !== 'none' && str !== 'None') return false;
      } else {
        const list = str.split(/[,|]/).map(s => s.trim().toLowerCase().replace(/^class\s*/i, '')).filter(Boolean);
        const isAll = list.length === 0 || list.includes('all') || list.includes('all classes');
        const targetClean = String(selectedClassFilter).trim().toLowerCase().replace(/^class\s*/i, '');
        if (!isAll && !list.includes(targetClean)) return false;
      }
    }

    // 3. Designation Filter
    if (selectedDesignationFilter !== 'all') {
      if ((t.designation || 'Teacher').toLowerCase() !== selectedDesignationFilter.toLowerCase()) return false;
    }

    // 4. Status Filter
    if (selectedStatusFilter !== 'all') {
      const isActive = t.active !== false && t.status !== 'inactive';
      if (selectedStatusFilter === 'active' && !isActive) return false;
      if (selectedStatusFilter === 'inactive' && isActive) return false;
    }

    return true;
  });

  return (
    <div className="space-y-6 pb-12 font-sans">
      {/* Top Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h2 className="text-xl lg:text-2xl font-extrabold text-text tracking-tight">
            Faculty & Teacher Management
          </h2>
          <p className="text-xs lg:text-sm text-text-secondary">
            Manage teacher profiles, photo DPs, assigned classes, and portal credentials
          </p>
        </div>

        <div className="flex flex-wrap items-center gap-2">
          {/* Faculty Excel Bulk Import */}
          <input
            ref={facultyImportInputRef}
            type="file"
            accept=".xlsx,.xls,.csv"
            onChange={handleFacultyFileSelect}
            className="hidden"
          />
          <button
            onClick={() => facultyImportInputRef.current?.click()}
            className="px-3 py-2 rounded-xl bg-surface2 hover:bg-border text-text font-bold text-xs shadow-xs flex items-center gap-1.5 transition-all cursor-pointer"
            title="Import Faculty List from Excel or CSV"
          >
            <Upload className="w-4 h-4 text-emerald-600" />
            <span className="hidden sm:inline">Import Excel</span>
          </button>

          {teachers.length > 0 && (
            <>
              <button
                onClick={() => exportFacultyToExcel(teachers, settings?.instituteName || 'School')}
                className="px-3 py-2 rounded-xl bg-surface2 hover:bg-border text-text font-bold text-xs shadow-xs flex items-center gap-1.5 transition-all cursor-pointer"
                title="Export Faculty List to Excel"
              >
                <FileSpreadsheet className="w-4 h-4 text-emerald-600" />
                <span className="hidden sm:inline">Export Excel</span>
              </button>
              <button
                onClick={() => exportFacultyPDF(teachers, settings || {})}
                className="px-3 py-2 rounded-xl bg-surface2 hover:bg-border text-text font-bold text-xs shadow-xs flex items-center gap-1.5 transition-all cursor-pointer"
                title="Export Faculty List to PDF"
              >
                <FileText className="w-4 h-4 text-primary" />
                <span className="hidden sm:inline">Export PDF</span>
              </button>
            </>
          )}

          <button
            onClick={() => openEnquiriesModal('teachers')}
            className="px-3.5 py-2 rounded-xl bg-emerald-50 hover:bg-emerald-100 text-emerald-700 border border-emerald-200 font-bold text-xs shadow-2xs flex items-center gap-1.5 transition-all cursor-pointer"
            title="View teacher job applications submitted from website"
          >
            <Briefcase className="w-4 h-4 text-emerald-600" />
            <span>Faculty Applications</span>
            {(teacherApplications || []).filter(a => !a.status || a.status === 'pending').length > 0 && (
              <span className="ml-1 px-1.5 py-0.5 rounded-full bg-rose-600 text-white text-[10px] font-black animate-pulse">
                {(teacherApplications || []).filter(a => !a.status || a.status === 'pending').length}
              </span>
            )}
          </button>

          <button
            onClick={() => setIsPermsModalOpen(true)}
            className="px-3.5 py-2 rounded-xl bg-[#1E3A8A] hover:bg-[#152865] text-white font-bold text-xs shadow-md flex items-center gap-1.5 transition-all cursor-pointer"
            title="Configure teacher login access (ON / OFF switches)"
          >
            <ShieldCheck className="w-4 h-4 text-emerald-400" />
            <span>{t('teacherAccess', settings?.appLanguage || 'en')}</span>
          </button>

          <button
            onClick={handleOpenAdd}
            className="px-4 py-2 rounded-xl bg-primary hover:bg-primary-dark text-white font-bold text-xs shadow-md flex items-center gap-2 transition-all cursor-pointer active:scale-95"
          >
            <Plus className="w-4 h-4 stroke-[3]" />
            <span>Add New Teacher</span>
          </button>
        </div>
      </div>

      {/* Metric Summary Cards */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 sm:gap-4">
        <div className="p-3.5 sm:p-4 rounded-2xl bg-card border border-border shadow-xs flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl bg-indigo-500/10 text-indigo-600 flex items-center justify-center shrink-0">
            <Users className="w-5 h-5" />
          </div>
          <div>
            <span className="text-[10.5px] font-bold text-text-muted uppercase tracking-wider block">Total Faculty</span>
            <span className="text-lg sm:text-xl font-black text-text">{totalFaculty}</span>
          </div>
        </div>

        <div className="p-3.5 sm:p-4 rounded-2xl bg-card border border-border shadow-xs flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl bg-primary/10 text-primary flex items-center justify-center shrink-0">
            <GraduationCap className="w-5 h-5" />
          </div>
          <div>
            <span className="text-[10.5px] font-bold text-text-muted uppercase tracking-wider block">Class Incharges</span>
            <span className="text-lg sm:text-xl font-black text-primary">{classTeachersCount}</span>
          </div>
        </div>

        <div className="p-3.5 sm:p-4 rounded-2xl bg-card border border-border shadow-xs flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl bg-emerald-500/10 text-emerald-600 flex items-center justify-center shrink-0">
            <BookOpen className="w-5 h-5" />
          </div>
          <div>
            <span className="text-[10.5px] font-bold text-text-muted uppercase tracking-wider block">Subject Teachers</span>
            <span className="text-lg sm:text-xl font-black text-emerald-600">{subjectTeachersCount}</span>
          </div>
        </div>

        <div className="p-3.5 sm:p-4 rounded-2xl bg-card border border-border shadow-xs flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl bg-teal-500/10 text-teal-600 flex items-center justify-center shrink-0">
            <CheckCircle className="w-5 h-5" />
          </div>
          <div>
            <span className="text-[10.5px] font-bold text-text-muted uppercase tracking-wider block">Active Staff</span>
            <span className="text-lg sm:text-xl font-black text-teal-600">{activeStaffCount}</span>
          </div>
        </div>
      </div>

      {/* Filter and View Controls Bar */}
      <div className="p-3.5 sm:p-4 rounded-2xl bg-card border border-border shadow-xs flex flex-col lg:flex-row items-stretch lg:items-center justify-between gap-3">
        {/* Search */}
        <div className="relative flex-1 min-w-[200px]">
          <Search className="w-4 h-4 text-text-muted absolute left-3.5 top-1/2 -translate-y-1/2" />
          <input
            type="text"
            placeholder="Search by name, ID, subject, phone, qualification..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full pl-10 pr-4 py-2 rounded-xl bg-surface2 border border-border text-xs text-text font-medium focus:outline-none focus:border-primary shadow-xs"
          />
          {searchQuery && (
            <button
              onClick={() => setSearchQuery('')}
              className="absolute right-3 top-1/2 -translate-y-1/2 text-text-muted hover:text-text cursor-pointer"
            >
              <X className="w-3.5 h-3.5" />
            </button>
          )}
        </div>

        {/* Dropdowns & View Toggles */}
        <div className="flex flex-wrap items-center gap-2">
          {/* Class Filter */}
          <select
            value={selectedClassFilter}
            onChange={(e) => setSelectedClassFilter(e.target.value)}
            className="px-3 py-2 rounded-xl bg-surface2 border border-border text-xs text-text font-bold focus:outline-none focus:border-primary shadow-xs cursor-pointer"
          >
            <option value="all">All Classes</option>
            <option value="subject_only">Subject Teachers (No Class)</option>
            {availableClasses.map(c => (
              <option key={c} value={c}>Class {c}</option>
            ))}
          </select>

          {/* Designation Filter */}
          <select
            value={selectedDesignationFilter}
            onChange={(e) => setSelectedDesignationFilter(e.target.value)}
            className="px-3 py-2 rounded-xl bg-surface2 border border-border text-xs text-text font-bold focus:outline-none focus:border-primary shadow-xs cursor-pointer"
          >
            <option value="all">All Roles</option>
            <option value="Subject Teacher">Subject Teacher</option>
            <option value="Class Teacher">Class Teacher</option>
            <option value="PGT">PGT</option>
            <option value="TGT">TGT</option>
            <option value="PRT">PRT</option>
            <option value="Principal">Principal</option>
            <option value="Vice Principal">Vice Principal</option>
            <option value="Lab Assistant">Lab Assistant</option>
          </select>

          {/* Status Filter */}
          <select
            value={selectedStatusFilter}
            onChange={(e) => setSelectedStatusFilter(e.target.value)}
            className="px-3 py-2 rounded-xl bg-surface2 border border-border text-xs text-text font-bold focus:outline-none focus:border-primary shadow-xs cursor-pointer"
          >
            <option value="all">All Status</option>
            <option value="active">Active Only</option>
            <option value="inactive">Inactive</option>
          </select>

          {/* Grid / Table Toggle */}
          <div className="flex items-center p-0.5 rounded-xl bg-surface2 border border-border shadow-xs">
            <button
              onClick={() => setViewMode('grid')}
              className={`p-1.5 rounded-lg transition-all cursor-pointer ${
                viewMode === 'grid' ? 'bg-card text-primary shadow-xs' : 'text-text-muted hover:text-text'
              }`}
              title="Grid Card View"
            >
              <LayoutGrid className="w-4 h-4" />
            </button>
            <button
              onClick={() => setViewMode('table')}
              className={`p-1.5 rounded-lg transition-all cursor-pointer ${
                viewMode === 'table' ? 'bg-card text-primary shadow-xs' : 'text-text-muted hover:text-text'
              }`}
              title="Table List View"
            >
              <List className="w-4 h-4" />
            </button>
          </div>
        </div>
      </div>

      {/* Teachers Display: GRID OR TABLE */}
      {filteredTeachers.length === 0 ? (
        <div className="py-16 text-center text-text-muted text-xs bg-card border border-border rounded-2xl">
          {searchQuery || selectedClassFilter !== 'all' || selectedDesignationFilter !== 'all'
            ? 'No faculty members matching the selected filters.'
            : "No teachers added yet. Click 'Add New Teacher' to add your staff."}
        </div>
      ) : viewMode === 'grid' ? (
        /* GRID VIEW */
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {filteredTeachers.map((teacher, idx) => {
            const teacherKey = teacher.authUid || teacher.id || `tch_${idx}`;
            const displayEmail = teacher.authEmail || teacher.email || `${(teacher.name || 'teacher').toLowerCase().replace(/[^a-z0-9]/g, '')}.${(teacher.teacherId || `T${idx+1}`).toLowerCase()}@${schoolPart}.teachers`;

            return (
              <div
                key={teacherKey}
                onClick={() => setSelectedTeacherForProfile(teacher)}
                className="bg-card border border-border rounded-2xl p-4 shadow-xs flex flex-col justify-between hover:border-primary/50 hover:shadow-md transition-all cursor-pointer group"
              >
                <div className="flex items-start gap-3.5">
                  {/* Circular Avatar 56x56 */}
                  <div className="w-14 h-14 rounded-full bg-primary/10 text-primary flex items-center justify-center font-bold text-lg shrink-0 overflow-hidden border-2 border-border/80 group-hover:scale-105 transition-transform">
                    {teacher.photoUrl ? (
                      <img src={teacher.photoUrl} alt={teacher.name} className="w-full h-full object-cover" />
                    ) : (
                      <span>{teacher.name?.charAt(0)?.toUpperCase() || 'T'}</span>
                    )}
                  </div>

                  {/* Teacher Info */}
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center justify-between gap-1">
                      <h4 className="font-bold text-sm text-text truncate group-hover:text-primary transition-colors">
                        {teacher.name}
                      </h4>
                      <span className="text-[10px] font-bold px-2 py-0.5 rounded-full bg-indigo-50 text-indigo-700 dark:bg-indigo-950/50 dark:text-indigo-300">
                        Staff
                      </span>
                    </div>

                    {/* Row 1: Numbers/ID + Email */}
                    <div className="flex items-center gap-1.5 text-[11px] text-text-muted mt-0.5">
                      <span className="font-mono font-bold text-primary">
                        {teacher.teacherId || `T${String(idx + 1).padStart(3, '0')}`}
                      </span>
                      <span>•</span>
                      <span className="truncate max-w-[150px] font-mono text-[10.5px]">
                        {displayEmail}
                      </span>
                    </div>

                    {/* Row 2: Assigned Class / Subject */}
                    <div className="flex items-center gap-1.5 text-[11px] text-text font-medium mt-1">
                      <GraduationCap className="w-3.5 h-3.5 text-text-muted shrink-0" />
                      <span className="truncate">
                        {(() => {
                          const raw = teacher.assignedClass ?? teacher.assignedClasses;
                          const cls = parseClassString(raw).trim();
                          if (cls && cls !== 'none' && cls !== 'None') {
                            const lower = cls.toLowerCase();
                            if (lower === 'all' || lower === 'all classes') {
                              return '★ All Classes Access';
                            }
                            return `Class ${cls}${teacher.assignedSection ? ` - ${teacher.assignedSection}` : ''}`;
                          }
                          return teacher.subject ? `Subject: ${teacher.subject}` : 'General Faculty';
                        })()}
                      </span>
                    </div>

                    {/* Row 3: Father / Desig + Phone */}
                    <div className="flex items-center gap-1.5 text-[11px] text-text-muted mt-1">
                      <User className="w-3.5 h-3.5 shrink-0" />
                      <span className="truncate max-w-[110px]">
                        {teacher.fatherName || teacher.designation || 'Teacher'}
                      </span>
                      {teacher.mobile && (
                        <>
                          <Phone className="w-3.5 h-3.5 shrink-0 ml-1" />
                          <span className="font-mono">{teacher.mobile}</span>
                        </>
                      )}
                    </div>

                    {/* Row 4: Status Chip + Salary Chip */}
                    <div className="flex items-center justify-between mt-2.5 pt-2 border-t border-border/60">
                      <div className="flex items-center gap-1.5">
                        <span className={`text-[10px] font-bold px-2 py-0.5 rounded-full ${
                          teacher.active !== false && teacher.status !== 'disabled'
                            ? 'bg-emerald-50 text-emerald-700 dark:bg-emerald-950/40 dark:text-emerald-300'
                            : 'bg-rose-50 text-rose-700 dark:bg-rose-950/40 dark:text-rose-300'
                        }`}>
                          {teacher.active !== false && teacher.status !== 'disabled' ? 'Active' : 'Disabled'}
                        </span>
                        <span className="text-[10px] font-mono font-bold px-2 py-0.5 rounded-full bg-emerald-50 dark:bg-emerald-950/40 text-emerald-700 dark:text-emerald-300">
                          ₹{Number(teacher.salary || 25000).toLocaleString('en-IN')} / mo
                        </span>
                      </div>

                      <span className="text-text-muted group-hover:text-primary transition-colors text-xs font-bold">
                        →
                      </span>
                    </div>
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      ) : (
        /* TABLE LIST VIEW */
        <div className="bg-card border border-border rounded-2xl overflow-hidden shadow-xs">
          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs border-collapse min-w-[700px]">
              <thead className="bg-surface2 text-text font-bold border-b border-border text-[11px]">
                <tr>
                  <th className="py-3 px-4">Faculty Member</th>
                  <th className="py-3 px-4">Role / Class</th>
                  <th className="py-3 px-4">Subject & Qualification</th>
                  <th className="py-3 px-4">Contact Phone</th>
                  <th className="py-3 px-4">Monthly Salary</th>
                  <th className="py-3 px-4">Status</th>
                  <th className="py-3 px-4 text-right">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border/60">
                {filteredTeachers.map((teacher, idx) => {
                  const teacherKey = teacher.authUid || teacher.id || `tch_${idx}`;
                  const isClassTch = teacher.assignedClass && teacher.assignedClass !== 'none' && teacher.assignedClass !== 'None';

                  return (
                    <tr
                      key={teacherKey}
                      onClick={() => setSelectedTeacherForProfile(teacher)}
                      className="hover:bg-surface2/60 transition-colors cursor-pointer group"
                    >
                      {/* Name & DP */}
                      <td className="py-3 px-4">
                        <div className="flex items-center gap-3">
                          <div className="w-10 h-10 rounded-xl bg-gradient-to-tr from-indigo-600 to-primary text-white flex items-center justify-center font-bold text-xs shadow-xs shrink-0 overflow-hidden border border-border">
                            {teacher.photoUrl ? (
                              <img src={teacher.photoUrl} alt={teacher.name} className="w-full h-full object-cover" />
                            ) : (
                              <span>{teacher.name?.charAt(0) || 'T'}</span>
                            )}
                          </div>
                          <div>
                            <span className="font-extrabold text-text block group-hover:text-primary transition-colors">
                              {teacher.name}
                            </span>
                            <span className="text-[10px] font-mono text-primary font-bold">
                              {teacher.teacherId || `T${String(idx + 1).padStart(3, '0')}`}
                            </span>
                          </div>
                        </div>
                      </td>

                      {/* Role / Class */}
                      <td className="py-3 px-4">
                        {(() => {
                          const raw = teacher.assignedClass ?? teacher.assignedClasses;
                          const cls = parseClassString(raw).trim();
                          const lower = cls.toLowerCase();
                          const isAll = !cls || lower === 'all' || lower === 'all classes';
                          if (isAll) {
                            return (
                              <span className="font-bold text-indigo-700 dark:text-indigo-300 px-2 py-0.5 rounded-md bg-indigo-50 dark:bg-indigo-950/40 border border-indigo-200 text-[10.5px]">
                                ★ All Classes Access
                              </span>
                            );
                          }
                          return (
                            <span className="font-bold text-teal-700 dark:text-teal-300 px-2 py-0.5 rounded-md bg-teal-50 dark:bg-teal-950/40 border border-teal-200 text-[11px]">
                              Class {cls}{teacher.assignedSection ? ` - ${teacher.assignedSection}` : ''}
                            </span>
                          );
                        })()}
                      </td>

                      {/* Subject & Qual */}
                      <td className="py-3 px-4">
                        <span className="font-bold text-text block">{teacher.subject || 'All Subjects'}</span>
                        <span className="text-[10.5px] text-text-muted">{teacher.qualification || '—'}</span>
                      </td>

                      {/* Contact */}
                      <td className="py-3 px-4 font-mono">
                        <span className="font-bold text-text block">{teacher.mobile || '—'}</span>
                        <span className="text-[10px] text-text-muted truncate max-w-[140px] block" title={teacher.authEmail}>
                          {teacher.authEmail || teacher.email || '—'}
                        </span>
                      </td>

                      {/* Salary */}
                      <td className="py-3 px-4 font-mono font-bold text-emerald-600">
                        ₹{Number(teacher.salary || 25000).toLocaleString('en-IN')}
                      </td>

                      {/* Status */}
                      <td className="py-3 px-4">
                        <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-bold bg-emerald-50 dark:bg-emerald-950/40 text-emerald-700 dark:text-emerald-400 border border-emerald-200 dark:border-emerald-800">
                          <CheckCircle className="w-2.5 h-2.5" />
                          <span>Active</span>
                        </span>
                      </td>

                      {/* Actions */}
                      <td className="py-3 px-4 text-right" onClick={(e) => e.stopPropagation()}>
                        <div className="flex items-center justify-end gap-1">
                          <button
                            onClick={() => setSelectedTeacherForProfile(teacher)}
                            className="p-1.5 rounded-lg bg-surface2 hover:bg-primary/10 text-text-muted hover:text-primary cursor-pointer transition-colors"
                            title="View Full Profile"
                          >
                            <Eye className="w-3.5 h-3.5" />
                          </button>
                          <button
                            onClick={() => handleOpenEdit(teacher)}
                            className="p-1.5 rounded-lg bg-surface2 hover:bg-border text-text-muted hover:text-text cursor-pointer transition-colors"
                            title="Edit Teacher"
                          >
                            <Edit className="w-3.5 h-3.5" />
                          </button>
                          <button
                            onClick={() => deleteTeacher(teacher)}
                            className="p-1.5 rounded-lg bg-surface2 hover:bg-rose-100 text-text-muted hover:text-rose-600 cursor-pointer transition-colors"
                            title="Delete Teacher"
                          >
                            <Trash2 className="w-3.5 h-3.5" />
                          </button>
                        </div>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* Add / Edit Teacher Modal (Complete Student-Like Details) */}
      {isAddOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-3 sm:p-4 bg-black/60 backdrop-blur-xs overflow-y-auto">
          <div className="bg-card border border-border rounded-2xl w-full max-w-2xl shadow-2xl overflow-hidden my-auto animate-in fade-in zoom-in-95 duration-200">
            <div className="px-5 sm:px-6 py-4 border-b border-border bg-surface2 flex items-center justify-between">
              <div>
                <h3 className="font-bold text-sm sm:text-base text-text">
                  {editingTeacher ? `Edit Faculty Details: ${editingTeacher.name}` : 'Add New Faculty / Teacher'}
                </h3>
                <p className="text-[11px] text-text-secondary">
                  Complete personal, academic, employment details & dedicated portal credentials
                </p>
              </div>
              <button
                onClick={() => setIsAddOpen(false)}
                className="p-1 rounded-lg text-text-muted hover:text-text hover:bg-border/60 transition-colors cursor-pointer"
              >
                <X className="w-4 h-4" />
              </button>
            </div>

            <form onSubmit={handleSubmit} className="p-5 sm:p-6 space-y-5 text-xs max-h-[80vh] overflow-y-auto">
              {/* Photo Avatar with Actions (Identical to Student) */}
              <div className="flex flex-col sm:flex-row items-center gap-4 bg-surface2/60 p-3.5 rounded-2xl border border-border/80">
                <div className="w-20 h-24 rounded-2xl bg-slate-900 border-2 border-dashed border-amber-400/60 overflow-hidden relative flex items-center justify-center text-text-muted group shadow-xs shrink-0">
                  {formData.photoUrl ? (
                    <img
                      src={formData.photoUrl}
                      alt="Preview"
                      className="w-full h-full object-cover"
                    />
                  ) : (
                    <div className="flex flex-col items-center justify-center text-slate-400 p-2 text-center">
                      <User className="w-8 h-8 mb-1 text-slate-400/80" />
                      <span className="text-[9px] font-bold text-slate-400">No Photo</span>
                    </div>
                  )}

                  <label className="absolute inset-0 bg-black/50 text-white flex flex-col items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity cursor-pointer text-[10px] font-bold">
                    <Camera className="w-4 h-4 mb-1 text-amber-300" />
                    <span>{formData.photoUrl ? 'Change' : 'Upload'}</span>
                    <input
                      ref={photoInputRef}
                      type="file"
                      accept="image/*"
                      onChange={handlePhotoFileSelect}
                      className="hidden"
                    />
                  </label>
                </div>

                <div className="flex flex-col gap-1.5 text-center sm:text-left">
                  <span className="font-bold text-xs text-text">Teacher Profile Photo (DP)</span>
                  <span className="text-[10px] text-text-muted">High-res compressed photo (&lt;100KB, 3:4 aspect ratio)</span>
                  <div className="flex items-center gap-2 mt-1">
                    <button
                      type="button"
                      onClick={() => photoInputRef.current?.click()}
                      className="px-2.5 py-1 rounded-lg bg-primary hover:bg-primary-dark text-white text-[11px] font-bold flex items-center gap-1 shadow-2xs cursor-pointer transition-colors"
                    >
                      <Upload className="w-3 h-3" />
                      <span>{formData.photoUrl ? 'Change Photo' : 'Upload Photo'}</span>
                    </button>
                    {formData.photoUrl && (
                      <>
                        <button
                          type="button"
                          onClick={() => {
                            setImageToCrop(formData.photoUrl);
                            setIsCropperOpen(true);
                          }}
                          className="px-2 py-1 rounded-lg bg-amber-400 hover:bg-amber-500 text-slate-950 text-[11px] font-bold flex items-center gap-1 shadow-2xs cursor-pointer transition-colors"
                        >
                          <Crop className="w-3 h-3" />
                          <span>Crop</span>
                        </button>
                        <button
                          type="button"
                          onClick={() => setFormData(prev => ({ ...prev, photoUrl: '' }))}
                          className="p-1 rounded-lg bg-rose-50 hover:bg-rose-100 text-rose-600 border border-rose-200 text-[11px] font-bold cursor-pointer transition-colors"
                          title="Remove Photo"
                        >
                          <Trash2 className="w-3.5 h-3.5" />
                        </button>
                      </>
                    )}
                  </div>
                </div>
              </div>

              {/* SECTION 1: Personal Information */}
              <div className="space-y-3">
                <div className="flex items-center gap-2 pb-1 border-b border-border text-primary font-bold text-xs uppercase tracking-wider">
                  <User className="w-3.5 h-3.5" />
                  <span>1. Personal Information</span>
                </div>

                <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                  <div>
                    <label className="block font-bold text-text mb-1">
                      Teacher Full Name <span className="text-rose-500">*</span>
                    </label>
                    <input
                      type="text"
                      required
                      placeholder="e.g. Suraj Sharma"
                      value={formData.name}
                      onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                      className="w-full px-3.5 py-2.5 rounded-xl bg-surface2 border border-border text-xs text-text font-bold focus:outline-none focus:border-primary"
                    />
                  </div>

                  <div>
                    <label className="block font-bold text-text mb-1">
                      Father's Name
                    </label>
                    <input
                      type="text"
                      placeholder="e.g. Ramesh Sharma"
                      value={formData.fatherName}
                      onChange={(e) => setFormData({ ...formData, fatherName: e.target.value })}
                      className="w-full px-3.5 py-2.5 rounded-xl bg-surface2 border border-border text-xs text-text font-medium focus:outline-none focus:border-primary"
                    />
                  </div>

                  <div>
                    <label className="block font-bold text-text mb-1">
                      Mother's Name
                    </label>
                    <input
                      type="text"
                      placeholder="e.g. Sunita Devi"
                      value={formData.motherName}
                      onChange={(e) => setFormData({ ...formData, motherName: e.target.value })}
                      className="w-full px-3.5 py-2.5 rounded-xl bg-surface2 border border-border text-xs text-text font-medium focus:outline-none focus:border-primary"
                    />
                  </div>

                  <div>
                    <label className="block font-bold text-text mb-1">
                      Gender
                    </label>
                    <select
                      value={formData.gender}
                      onChange={(e) => setFormData({ ...formData, gender: e.target.value })}
                      className="w-full px-3 py-2.5 rounded-xl bg-surface2 border border-border text-xs text-text font-medium focus:outline-none focus:border-primary cursor-pointer"
                    >
                      <option value="Male">Male</option>
                      <option value="Female">Female</option>
                      <option value="Other">Other</option>
                    </select>
                  </div>

                  <div>
                    <label className="block font-bold text-text mb-1">
                      Date of Birth
                    </label>
                    <input
                      type="date"
                      value={formData.dob}
                      onChange={(e) => setFormData({ ...formData, dob: e.target.value })}
                      className="w-full px-3.5 py-2.5 rounded-xl bg-surface2 border border-border text-xs text-text font-medium focus:outline-none focus:border-primary"
                    />
                  </div>

                  <div className="sm:col-span-2 p-3.5 rounded-xl bg-surface2/60 border border-border space-y-2.5">
                    <div className="flex items-center justify-between">
                      <label className="font-bold text-text text-xs flex items-center gap-1.5">
                        <FileCheck className="w-4 h-4 text-emerald-600" />
                        <span>Aadhaar Card & Identity Document</span>
                      </label>
                      <span className="text-[10px] text-text-muted">Government ID for staff records</span>
                    </div>

                    <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 items-center">
                      <div>
                        <span className="block text-[11px] font-bold text-text-secondary mb-1">12-Digit Aadhaar Number</span>
                        <input
                          type="text"
                          maxLength={14}
                          placeholder="e.g. 1234 5678 9012"
                          value={formData.aadhaarNumber || ''}
                          onChange={(e) => setFormData({ ...formData, aadhaarNumber: e.target.value })}
                          className="w-full px-3 py-2 rounded-xl bg-card border border-border text-xs text-text font-mono font-bold focus:outline-none focus:border-primary"
                        />
                      </div>

                      {/* Aadhaar Photo Upload */}
                      <div className="flex items-center gap-2.5 bg-card p-2 rounded-xl border border-dashed border-border">
                        {formData.aadhaarDocUrl ? (
                          <div className="relative w-16 h-12 rounded-lg overflow-hidden border border-border bg-slate-900 group flex-shrink-0">
                            <img
                              src={formData.aadhaarDocUrl}
                              alt="Teacher Aadhaar"
                              className="w-full h-full object-cover"
                            />
                            <button
                              type="button"
                              onClick={() => setPreviewAadhaarDocModal(true)}
                              className="absolute inset-0 bg-black/50 text-white flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity cursor-pointer text-[10px]"
                              title="View Document"
                            >
                              <Eye className="w-3.5 h-3.5" />
                            </button>
                          </div>
                        ) : (
                          <div className="w-16 h-12 rounded-lg bg-surface2 border border-border flex flex-col items-center justify-center text-text-muted flex-shrink-0">
                            <FileText className="w-4 h-4 text-text-muted/60" />
                            <span className="text-[7.5px] font-bold">No Doc</span>
                          </div>
                        )}

                        <div className="flex-1 min-w-0">
                          <span className="text-[10.5px] font-bold text-text block truncate">
                            {formData.aadhaarDocUrl ? 'Aadhaar Attached' : 'Attach Aadhaar Card'}
                          </span>
                          <div className="flex items-center gap-1.5 mt-1">
                            <input
                              ref={aadhaarDocInputRef}
                              type="file"
                              accept="image/*"
                              onChange={handleAadhaarDocFileSelect}
                              className="hidden"
                            />
                            <button
                              type="button"
                              onClick={() => aadhaarDocInputRef.current?.click()}
                              className="px-2 py-0.5 rounded-lg bg-emerald-600 hover:bg-emerald-700 text-white text-[9.5px] font-bold flex items-center gap-1 cursor-pointer"
                            >
                              <Upload className="w-2.5 h-2.5" />
                              <span>{formData.aadhaarDocUrl ? 'Change' : 'Upload'}</span>
                            </button>
                            {formData.aadhaarDocUrl && (
                              <>
                                <button
                                  type="button"
                                  onClick={() => setPreviewAadhaarDocModal(true)}
                                  className="px-1.5 py-0.5 rounded-lg bg-surface2 text-text text-[9.5px] font-bold cursor-pointer border border-border"
                                >
                                  <Eye className="w-2.5 h-2.5" />
                                </button>
                                <button
                                  type="button"
                                  onClick={() => setFormData(prev => ({ ...prev, aadhaarDocUrl: '', aadhaarDocPath: '' }))}
                                  className="p-1 rounded-lg bg-rose-50 text-rose-600 text-[9.5px] cursor-pointer hover:bg-rose-100"
                                  title="Remove Document"
                                >
                                  <Trash2 className="w-2.5 h-2.5" />
                                </button>
                              </>
                            )}
                          </div>
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              </div>

              {/* SECTION 2: Contact & Residential Details */}
              <div className="space-y-3">
                <div className="flex items-center gap-2 pb-1 border-b border-border text-primary font-bold text-xs uppercase tracking-wider">
                  <Phone className="w-3.5 h-3.5" />
                  <span>2. Contact & Address</span>
                </div>

                <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                  <div>
                    <label className="block font-bold text-text mb-1">
                      Primary Mobile Number <span className="text-text-muted font-normal">(Optional)</span>
                    </label>
                    <input
                      type="tel"
                      placeholder="e.g. 9876543210 (optional)"
                      value={formData.mobile}
                      onChange={(e) => setFormData({ ...formData, mobile: e.target.value })}
                      className="w-full px-3.5 py-2.5 rounded-xl bg-surface2 border border-border text-xs text-text font-mono focus:outline-none focus:border-primary"
                    />
                  </div>

                  <div>
                    <label className="block font-bold text-text mb-1">
                      Alternate Mobile / WhatsApp
                    </label>
                    <input
                      type="tel"
                      placeholder="e.g. 9123456789"
                      value={formData.alternateMobile}
                      onChange={(e) => setFormData({ ...formData, alternateMobile: e.target.value })}
                      className="w-full px-3.5 py-2.5 rounded-xl bg-surface2 border border-border text-xs text-text font-mono focus:outline-none focus:border-primary"
                    />
                  </div>

                  <div className="sm:col-span-2">
                    <label className="block font-bold text-text mb-1">
                      Residential Address
                    </label>
                    <input
                      type="text"
                      placeholder="e.g. Village/Town, Post, District, PIN Code"
                      value={formData.address}
                      onChange={(e) => setFormData({ ...formData, address: e.target.value })}
                      className="w-full px-3.5 py-2.5 rounded-xl bg-surface2 border border-border text-xs text-text font-medium focus:outline-none focus:border-primary"
                    />
                  </div>
                </div>
              </div>

              {/* SECTION 3: Academic & Employment Details */}
              <div className="space-y-3">
                <div className="flex items-center gap-2 pb-1 border-b border-border text-primary font-bold text-xs uppercase tracking-wider">
                  <Briefcase className="w-3.5 h-3.5" />
                  <span>3. Academic & Employment Details</span>
                </div>

                <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                  <div>
                    <label className="block font-bold text-text mb-1">
                      Highest Qualification
                    </label>
                    <input
                      type="text"
                      placeholder="e.g. B.Ed, M.Sc (Mathematics)"
                      value={formData.qualification}
                      onChange={(e) => setFormData({ ...formData, qualification: e.target.value })}
                      className="w-full px-3.5 py-2.5 rounded-xl bg-surface2 border border-border text-xs text-text font-medium focus:outline-none focus:border-primary"
                    />
                  </div>

                  <div>
                    <label className="block font-bold text-text mb-1">
                      Designation / Role
                    </label>
                    <input
                      type="text"
                      placeholder="e.g. Senior Faculty / TGT / PRT"
                      value={formData.designation}
                      onChange={(e) => setFormData({ ...formData, designation: e.target.value })}
                      className="w-full px-3.5 py-2.5 rounded-xl bg-surface2 border border-border text-xs text-text font-medium focus:outline-none focus:border-primary"
                    />
                  </div>

                  <div>
                    <label className="block font-bold text-text mb-1">
                      Teaching Subject(s)
                    </label>
                    <input
                      type="text"
                      placeholder="e.g. Mathematics, Science"
                      value={formData.subject}
                      onChange={(e) => setFormData({ ...formData, subject: e.target.value })}
                      className="w-full px-3.5 py-2.5 rounded-xl bg-surface2 border border-border text-xs text-text font-medium focus:outline-none focus:border-primary"
                    />
                  </div>

                  <div>
                    <label className="block font-bold text-text mb-1">
                      Monthly Base Salary (₹)
                    </label>
                    <input
                      type="number"
                      placeholder="e.g. 25000"
                      value={formData.salary}
                      onChange={(e) => setFormData({ ...formData, salary: Number(e.target.value) || 0 })}
                      className="w-full px-3.5 py-2.5 rounded-xl bg-surface2 border border-border text-xs text-text font-mono font-bold focus:outline-none focus:border-primary"
                    />
                  </div>

                  <div className="p-3.5 rounded-xl bg-surface2/60 border border-border/80 space-y-2.5">
                    <div className="flex items-center justify-between">
                      <label className="font-bold text-text text-xs flex items-center gap-1.5">
                        <GraduationCap className="w-3.5 h-3.5 text-primary" />
                        <span>Class Access & Permissions</span>
                      </label>
                      <span className={`text-[10px] font-bold px-2 py-0.5 rounded-full ${
                        parseClassString(formData.assignedClass) === 'All Classes' || !parseClassString(formData.assignedClass)
                          ? 'bg-primary/10 text-primary'
                          : 'bg-teal-50 text-teal-700 dark:bg-teal-950/40 dark:text-teal-300'
                      }`}>
                        {parseClassString(formData.assignedClass) === 'All Classes' || !parseClassString(formData.assignedClass)
                          ? 'Full School Access'
                          : `${parseClassString(formData.assignedClass).split(',').filter(s => s.trim() && s.trim() !== 'All Classes').length} Classes Selected`}
                      </span>
                    </div>

                    <p className="text-[11px] text-text-muted leading-tight">
                      Choose if this teacher can manage all school classes or select multiple specific classes:
                    </p>

                    <div className="flex flex-wrap gap-1.5 pt-1">
                      <button
                        type="button"
                        onClick={() => setFormData({ ...formData, assignedClass: 'All Classes' })}
                        className={`px-3 py-1.5 rounded-lg text-[11px] font-bold transition-all cursor-pointer flex items-center gap-1 ${
                          parseClassString(formData.assignedClass) === 'All Classes' || !parseClassString(formData.assignedClass)
                            ? 'bg-primary text-white shadow-sm'
                            : 'bg-surface border border-border text-text hover:border-primary'
                        }`}
                      >
                        <span>★</span>
                        <span>All Classes (Full Access)</span>
                      </button>

                      {availableClasses.map(c => {
                        const list = parseClassString(formData.assignedClass)
                          .split(/[,|]/)
                          .map(s => s.trim())
                          .filter(s => s && s !== 'All Classes');
                        const isSel = list.includes(c) && parseClassString(formData.assignedClass) !== 'All Classes';
                        return (
                          <button
                            key={c}
                            type="button"
                            onClick={() => {
                              let nextList = [...list];
                              if (formData.assignedClass === 'All Classes' || !formData.assignedClass) nextList = [];
                              if (isSel) {
                                nextList = nextList.filter(x => x !== c);
                              } else {
                                nextList.push(c);
                              }
                              setFormData({
                                ...formData,
                                assignedClass: nextList.length === 0 ? 'All Classes' : nextList.join(', ')
                              });
                            }}
                            className={`px-2.5 py-1.5 rounded-lg text-[11px] font-bold transition-all cursor-pointer flex items-center gap-1 ${
                              isSel
                                ? 'bg-teal-600 text-white shadow-sm'
                                : 'bg-surface border border-border text-text hover:border-teal-500'
                            }`}
                          >
                            {isSel && <span>✓</span>}
                            <span>Class {c}</span>
                          </button>
                        );
                      })}
                    </div>

                    {formData.assignedClass && formData.assignedClass !== 'All Classes' && (
                      <div className="text-[11px] text-teal-700 dark:text-teal-300 font-semibold pt-1 flex items-center gap-1">
                        <span>Selected:</span>
                        <span className="font-bold underline">{formData.assignedClass}</span>
                      </div>
                    )}
                  </div>

                  <div>
                    <label className="block font-bold text-text mb-1">Section</label>
                    <select
                      disabled={!formData.assignedClass || formData.assignedClass === 'none'}
                      value={formData.assignedSection}
                      onChange={(e) => setFormData({ ...formData, assignedSection: e.target.value })}
                      className="w-full px-3.5 py-2.5 rounded-xl bg-surface2 border border-border text-xs text-text font-bold focus:outline-none focus:border-primary cursor-pointer disabled:opacity-50"
                    >
                      <option value="">None / Not Applicable</option>
                      {['A', 'B', 'C', 'D', 'E'].map(s => <option key={s} value={s}>Section {s}</option>)}
                    </select>
                  </div>

                  <div>
                    <label className="block font-bold text-text mb-1">Date of Joining</label>
                    <input
                      type="date"
                      value={formData.joiningDate}
                      onChange={(e) => setFormData({ ...formData, joiningDate: e.target.value })}
                      className="w-full px-3.5 py-2.5 rounded-xl bg-surface2 border border-border text-xs text-text font-medium focus:outline-none focus:border-primary"
                    />
                  </div>
                </div>
              </div>

              {/* SECTION 4: Portal Credentials */}
              <div className="space-y-3">
                <div className="flex items-center gap-2 pb-1 border-b border-border text-primary font-bold text-xs uppercase tracking-wider">
                  <Key className="w-3.5 h-3.5" />
                  <span>4. Teacher Portal Login Credentials</span>
                </div>

                {/* Dynamic Generated Email Preview */}
                <div className="p-3 rounded-xl bg-indigo-50/60 dark:bg-indigo-950/40 border border-indigo-100 dark:border-indigo-900 space-y-1.5">
                  <div className="flex items-center justify-between text-[11px]">
                    <span className="font-bold text-indigo-950 dark:text-indigo-200 flex items-center gap-1">
                      <Mail className="w-3.5 h-3.5 text-indigo-600" />
                      <span>Auto Generated Auth Email:</span>
                    </span>
                    <span className="text-[10px] text-indigo-600 font-mono font-bold">
                      {editingTeacher?.teacherId || nextTeacherId}
                    </span>
                  </div>
                  <div className="font-mono text-[11px] text-indigo-900 dark:text-indigo-300 font-bold break-all bg-white dark:bg-slate-900 px-2.5 py-1.5 rounded-lg border border-indigo-200/60 dark:border-indigo-800">
                    {previewEmail}
                  </div>
                </div>

                <div>
                  <label className="block font-bold text-text mb-1 flex items-center justify-between">
                    <span>Portal Login Password <span className="text-rose-500">*</span></span>
                    <span className="text-[10px] text-text-muted font-normal">For Teacher Login</span>
                  </label>
                  <div className="relative">
                    <Key className="w-3.5 h-3.5 text-text-muted absolute left-3 top-1/2 -translate-y-1/2" />
                    <input
                      type="text"
                      required
                      placeholder="Enter password (e.g. 123456)"
                      value={formData.password}
                      onChange={(e) => setFormData({ ...formData, password: e.target.value })}
                      className="w-full pl-9 pr-3.5 py-2.5 rounded-xl bg-surface2 border border-border text-xs text-text font-mono focus:outline-none focus:border-primary"
                    />
                  </div>
                </div>
              </div>

              <div className="pt-4 border-t border-border flex items-center justify-end gap-2.5">
                <button
                  type="button"
                  onClick={() => setIsAddOpen(false)}
                  className="px-4 py-2.5 rounded-xl bg-surface2 hover:bg-border text-text font-bold cursor-pointer transition-colors"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="px-6 py-2.5 rounded-xl bg-primary hover:bg-primary-dark text-white font-bold cursor-pointer shadow-md transition-all"
                >
                  {editingTeacher ? 'Update Teacher' : 'Save Teacher'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Salary History & Payslip Modal */}
      {selectedTeacherForHistory && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-xs">
          <div className="bg-card border border-border rounded-2xl w-full max-w-lg shadow-2xl overflow-hidden animate-in fade-in zoom-in-95 duration-200">
            <div className="px-6 py-4 border-b border-border bg-surface2 flex items-center justify-between">
              <div>
                <h3 className="font-bold text-sm text-text">
                  Salary & Payroll Register — {selectedTeacherForHistory.name}
                </h3>
                <p className="text-[11px] text-text-secondary">
                  Class {selectedTeacherForHistory.assignedClass} Teacher | Monthly Base: ₹{(selectedTeacherForHistory.salary || 25000).toLocaleString()}
                </p>
              </div>
              <button
                onClick={() => setSelectedTeacherForHistory(null)}
                className="p-1 rounded-lg text-text-muted hover:text-text hover:bg-surface2 transition-colors cursor-pointer"
              >
                <X className="w-4 h-4" />
              </button>
            </div>

            <div className="p-6 space-y-4 max-h-[70vh] overflow-y-auto">
              <div className="space-y-2.5">
                {[
                  { month: 'October 2026', amount: selectedTeacherForHistory.salary || 25000, date: '05/10/2026', ref: 'PAY-2026-10-098', status: 'PAID' },
                  { month: 'September 2026', amount: selectedTeacherForHistory.salary || 25000, date: '04/09/2026', ref: 'PAY-2026-09-074', status: 'PAID' },
                  { month: 'August 2026', amount: selectedTeacherForHistory.salary || 25000, date: '05/08/2026', ref: 'PAY-2026-08-051', status: 'PAID' }
                ].map((s, idx) => (
                  <div key={idx} className="p-3.5 rounded-xl border border-border bg-surface2 flex items-center justify-between">
                    <div>
                      <div className="font-bold text-xs text-text">{s.month}</div>
                      <div className="text-[10px] text-text-muted">Paid on {s.date} • {s.ref}</div>
                    </div>
                    <div className="text-right">
                      <div className="font-mono font-bold text-xs text-emerald-600">₹{s.amount.toLocaleString()}</div>
                      <span className="text-[9px] font-bold text-emerald-700 bg-emerald-100 dark:bg-emerald-950 px-1.5 py-0.5 rounded">
                        {s.status}
                      </span>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Permissions Modal */}
      {isPermsModalOpen && (
        <TeacherPermissionsModal
          isOpen={isPermsModalOpen}
          onClose={() => setIsPermsModalOpen(false)}
        />
      )}

      {/* Teacher Photo Cropper Modal */}
      <ImageCropperModal
        isOpen={isCropperOpen}
        imageSrc={imageToCrop}
        title="Crop Teacher Profile Photo (DP)"
        initialAspect="3:4"
        onCropComplete={handleCropComplete}
        onClose={() => setIsCropperOpen(false)}
      />
      {/* Teacher Profile Modal */}
      {selectedTeacherForProfile && (
        <TeacherProfileModal
          teacher={selectedTeacherForProfile}
          onClose={() => setSelectedTeacherForProfile(null)}
          onEdit={(t) => handleOpenEdit(t)}
          onOpenPermissions={() => setIsPermsModalOpen(true)}
        />
      )}

      {/* Full Size Aadhaar Document Preview Modal */}
      {previewAadhaarDocModal && formData.aadhaarDocUrl && (
        <div className="fixed inset-0 z-[70] flex items-center justify-center p-4 bg-black/85 backdrop-blur-sm animate-in fade-in duration-200">
          <div className="bg-card border border-border rounded-2xl max-w-2xl w-full p-4 overflow-hidden shadow-2xl space-y-3">
            <div className="flex items-center justify-between pb-2 border-b border-border">
              <div className="flex items-center gap-2">
                <FileCheck className="w-5 h-5 text-emerald-600" />
                <span className="font-bold text-sm text-text">Teacher Aadhaar Card / ID Document Preview</span>
              </div>
              <button
                type="button"
                onClick={() => setPreviewAadhaarDocModal(false)}
                className="p-1 rounded-lg bg-surface2 text-text-muted hover:text-text cursor-pointer"
              >
                <X className="w-4 h-4" />
              </button>
            </div>
            <div className="max-h-[70vh] overflow-auto rounded-xl border border-border bg-slate-950 flex items-center justify-center p-2">
              <img
                src={formData.aadhaarDocUrl}
                alt="Teacher Aadhaar Document Full"
                className="max-h-[65vh] w-auto object-contain rounded-lg shadow-md"
              />
            </div>
            <div className="flex justify-between items-center pt-2">
              <span className="text-xs text-text-muted font-mono">
                {formData.aadhaarNumber ? `UIDAI No: ${formData.aadhaarNumber}` : 'Document Attached'}
              </span>
              <button
                type="button"
                onClick={() => setPreviewAadhaarDocModal(false)}
                className="px-4 py-1.5 rounded-xl bg-primary text-white font-bold text-xs cursor-pointer"
              >
                Close Preview
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Faculty Bulk Import Modal */}
      {isImportModalOpen && facultyImportPreview && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/70 backdrop-blur-xs animate-in fade-in duration-200">
          <div className="bg-card border border-border rounded-2xl max-w-3xl w-full p-5 overflow-hidden shadow-2xl space-y-4 max-h-[85vh] flex flex-col">
            <div className="flex items-center justify-between pb-3 border-b border-border">
              <div className="flex items-center gap-2.5">
                <div className="w-9 h-9 rounded-xl bg-emerald-500/10 text-emerald-600 flex items-center justify-center">
                  <FileSpreadsheet className="w-5 h-5" />
                </div>
                <div>
                  <h3 className="font-bold text-base text-text">Bulk Import Teachers / Faculty</h3>
                  <p className="text-xs text-text-muted">Review Excel/CSV rows before adding to system</p>
                </div>
              </div>
              <button
                onClick={() => { setIsImportModalOpen(false); setFacultyImportPreview(null); }}
                className="p-1.5 rounded-lg bg-surface2 text-text-muted hover:text-text cursor-pointer"
              >
                <X className="w-4 h-4" />
              </button>
            </div>

            <div className="flex items-center justify-between bg-surface2 p-3 rounded-xl border border-border">
              <div>
                <span className="text-xs font-bold text-text">Need Excel Format?</span>
                <span className="text-[11px] text-text-muted block">Download our template with pre-configured headers</span>
              </div>
              <button
                type="button"
                onClick={downloadFacultyImportTemplate}
                className="px-3 py-1.5 rounded-lg bg-card hover:bg-border text-text font-bold text-xs flex items-center gap-1.5 border border-border shadow-2xs cursor-pointer transition-colors"
              >
                <Download className="w-3.5 h-3.5 text-emerald-600" />
                <span>Download Template</span>
              </button>
            </div>

            <div className="flex-1 overflow-y-auto border border-border rounded-xl">
              <table className="w-full text-left text-xs border-collapse">
                <thead>
                  <tr className="bg-surface2 text-text font-bold border-b border-border">
                    <th className="p-2.5">#</th>
                    <th className="p-2.5">Teacher Name</th>
                    <th className="p-2.5">Mobile</th>
                    <th className="p-2.5">Subject</th>
                    <th className="p-2.5">Assigned Class</th>
                    <th className="p-2.5">Salary</th>
                    <th className="p-2.5 text-center">Status</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-border/60">
                  {facultyImportPreview.map((row, idx) => (
                    <tr key={idx} className={row.isValid ? 'hover:bg-surface2/50' : 'bg-rose-500/10'}>
                      <td className="p-2.5 text-text-muted font-mono">{idx + 1}</td>
                      <td className="p-2.5 font-bold text-text">{row.name || <span className="text-rose-500 font-bold">Missing Name</span>}</td>
                      <td className="p-2.5 font-mono">{row.mobile || <span className="text-rose-500 font-bold">Missing Mobile</span>}</td>
                      <td className="p-2.5">{row.subject || '—'}</td>
                      <td className="p-2.5">{row.assignedClass ? `Class ${row.assignedClass}` : '—'}</td>
                      <td className="p-2.5 font-mono">₹{Number(row.salary || 0).toLocaleString()}</td>
                      <td className="p-2.5 text-center">
                        {row.isValid ? (
                          <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-emerald-500/10 text-emerald-600">Valid</span>
                        ) : (
                          <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-rose-500/10 text-rose-600">Error</span>
                        )}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>

            <div className="pt-2 flex items-center justify-between border-t border-border">
              <span className="text-xs text-text-muted">
                Total Rows: <strong>{facultyImportPreview.length}</strong> (Valid: <strong className="text-emerald-600">{facultyImportPreview.filter(r => r.isValid).length}</strong>)
              </span>
              <div className="flex items-center gap-2">
                <button
                  type="button"
                  onClick={() => { setIsImportModalOpen(false); setFacultyImportPreview(null); }}
                  className="px-4 py-2 rounded-xl bg-surface2 text-text text-xs font-semibold hover:bg-border cursor-pointer"
                >
                  Cancel
                </button>
                <button
                  type="button"
                  disabled={importingFaculty || facultyImportPreview.filter(r => r.isValid).length === 0}
                  onClick={handleConfirmImportFaculty}
                  className="px-5 py-2 rounded-xl bg-primary hover:bg-primary-dark text-white text-xs font-bold shadow-md cursor-pointer transition-all disabled:opacity-50"
                >
                  {importingFaculty ? 'Importing Teachers...' : `Confirm Import (${facultyImportPreview.filter(r => r.isValid).length} Teachers)`}
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
