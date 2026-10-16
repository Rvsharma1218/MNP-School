import React, { useState, useEffect, useRef } from 'react';
import { useSchoolStore, calculateStudentFeeMetrics } from '../lib/store';
import {
  Users, Search, Plus, X, GraduationCap, Monitor, Phone,
  MessageSquare, User, Calendar, Mail, MapPin, CheckCircle, Info, Trash2,
  AlertCircle, ShieldAlert, Award, FileText, Check, Layout, ClipboardList, CreditCard,
  Camera, Upload, Crop, Edit, Eye
} from 'lucide-react';
import { openWhatsAppFeeReminder } from '../lib/exportUtils';
import ImageCropperModal from './ImageCropperModal';
import PromoteStudentsModal from './PromoteStudentsModal';
import WhatsAppReminderModal from './WhatsAppReminderModal';

export default function StudentsView() {
  const {
    students,
    payments,
    settings,
    currentUser,
    addStudent,
    updateStudent,
    deleteStudent,
    promoteStudents,
    selectedStudentId,
    setSelectedStudentId,
    isAddStudentOpen,
    setIsAddStudentOpen,
    editingStudent,
    setEditingStudent,
    viewingStudentProfile,
    setViewingStudentProfile,
    setFeeDetailStudent,
    setIsFeeDetailSelectorOpen,
    isPromoteModalOpen,
    setIsPromoteModalOpen,
    whatsAppReminderData,
    setWhatsAppReminderData,
    teacherPermissions,
    showToast
  } = useSchoolStore();

  const isPrincipal = currentUser?.role === 'principal';
  const assignedClass = currentUser?.assignedClass && currentUser.assignedClass !== 'none' && currentUser.assignedClass !== 'None' ? currentUser.assignedClass : '';

  const [searchQuery, setSearchQuery] = useState('');
  const [selectedClass, setSelectedClass] = useState(isPrincipal || !assignedClass ? 'all' : assignedClass);
  const [selectedStatus, setSelectedStatus] = useState('all');
  const [isCropperOpen, setIsCropperOpen] = useState(false);
  const [imageToCrop, setImageToCrop] = useState(null);
  const photoInputRef = useRef(null);
  
  // Reset to assigned class whenever teacher opens StudentsView (if assigned)
  useEffect(() => {
    if (!isPrincipal && assignedClass && assignedClass !== 'all') {
      setSelectedClass(assignedClass);
    }
  }, [assignedClass, isPrincipal]);

  // Right side panel states: 'quickview' | 'edit' | 'add'
  const [panelMode, setPanelMode] = useState('quickview'); 

  // Form State for Profile Edit / Admission
  const [profileForm, setProfileForm] = useState({
    name: '',
    dob: '',
    gender: 'Male',
    mobile: '',
    email: '',
    admissionNumber: '',
    studentId: '',
    admissionDate: '',
    className: '',
    section: 'A',
    rollNumber: '',
    course: '',
    session: '2026-27',
    fatherName: '',
    motherName: '',
    address: '',
    studentType: 'school',
    totalFees: 0,
    paidFees: 0,
    status: 'active'
  });

  // Pick active student
  const activeStudent = students.find(s => s.id === selectedStudentId);

  // Sync profile form state with selected student
  useEffect(() => {
    if (activeStudent && panelMode !== 'add') {
      setProfileForm({
        name: activeStudent.name || '',
        photoPath: activeStudent.photoPath || activeStudent.photoUrl || '',
        photoUrl: activeStudent.photoPath || activeStudent.photoUrl || '',
        aadhaarNumber: activeStudent.aadhaarNumber || activeStudent.aadharNumber || '',
        dob: activeStudent.dob || '',
        gender: activeStudent.gender || 'Male',
        mobile: activeStudent.mobile || '',
        email: activeStudent.email || '',
        admissionNumber: activeStudent.admissionNumber || '',
        studentId: activeStudent.studentId || '',
        admissionDate: activeStudent.admissionDate || '',
        className: activeStudent.className || '',
        section: activeStudent.section || 'A',
        rollNumber: activeStudent.rollNumber || '',
        course: activeStudent.course || '',
        session: activeStudent.session || '2026-27',
        fatherName: activeStudent.fatherName || '',
        motherName: activeStudent.motherName || '',
        address: activeStudent.address || '',
        studentType: activeStudent.studentType || 'school',
        totalFees: activeStudent.totalFees || 0,
        paidFees: activeStudent.paidFees || 0,
        status: activeStudent.status || 'active'
      });
    } else if (!activeStudent && students.length > 0 && panelMode !== 'add') {
      setSelectedStudentId(students[0].id);
      setPanelMode('quickview');
    }
  }, [selectedStudentId, activeStudent, panelMode, students]);

  // Filter students list
  const filteredStudents = students.filter(s => {
    const matchesSearch = !searchQuery.trim() ||
      s.name?.toLowerCase().includes(searchQuery.toLowerCase()) ||
      s.studentId?.toLowerCase().includes(searchQuery.toLowerCase()) ||
      s.fatherName?.toLowerCase().includes(searchQuery.toLowerCase());

    const matchesClass = selectedClass === 'all' || s.className === selectedClass || s.course === selectedClass;
    const matchesStatus = selectedStatus === 'all' || s.status === selectedStatus;

    return matchesSearch && matchesClass && matchesStatus;
  });

  const handleInputChange = (field, val) => {
    setProfileForm(prev => ({ ...prev, [field]: val }));
  };

  const handleAddNewClick = () => {
    setPanelMode('add');
    setProfileForm({
      name: 'New Student',
      dob: '2012-05-10',
      gender: 'Male',
      mobile: '',
      email: '',
      photoPath: '',
      photoUrl: '',
      aadhaarNumber: '',
      admissionNumber: '',
      studentId: '',
      admissionDate: new Date().toISOString().split('T')[0],
      className: isPrincipal ? (settings.schoolClasses?.[0] || '1st') : assignedClass,
      section: 'A',
      rollNumber: '',
      course: settings.computerCourses?.[0] || '',
      session: settings.currentSession || '2026-27',
      fatherName: '',
      motherName: '',
      address: '',
      studentType: 'school',
      totalFees: 12000,
      paidFees: 0,
      status: 'active'
    });
  };

  const handleSaveProfile = async (e) => {
    e.preventDefault();
    const payload = {
      ...profileForm,
      photoPath: profileForm.photoPath || '',
      photoUrl: profileForm.photoPath || '',
      aadhaarNumber: profileForm.aadhaarNumber || '',
      aadharNumber: profileForm.aadhaarNumber || ''
    };
    if (panelMode === 'add') {
      const added = await addStudent(payload);
      setPanelMode('quickview');
      if (added) setSelectedStudentId(added.id);
      showToast(`New admission for "${profileForm.name}" added successfully!`, 'success');
    } else if (activeStudent) {
      await updateStudent(activeStudent.id, payload);
      setPanelMode('quickview');
      showToast(`Profile for "${profileForm.name}" updated successfully!`, 'success');
    }
  };

  const handleDeleteClick = () => {
    if (activeStudent) {
      deleteStudent(activeStudent.id);
      setPanelMode('quickview');
    }
  };

  return (
    <div className="space-y-6 pb-12">
      {/* Top action header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h2 className="text-xl lg:text-2xl font-bold text-text tracking-tight">Student Directory</h2>
          <p className="text-xs text-text-secondary mt-0.5 font-medium">Manage enrollments, track performance, and monitor administrative status.</p>
        </div>

        <div className="flex items-center gap-2">
          {isPrincipal && (
            <button
              onClick={() => setIsPromoteModalOpen(true)}
              className="px-3.5 py-2 rounded-xl bg-purple-50 text-purple-700 hover:bg-purple-100 border border-purple-200 font-bold text-xs transition-colors cursor-pointer flex items-center gap-1.5 shadow-2xs"
              title="Promote students to next class (1-Click)"
            >
              <GraduationCap className="w-4 h-4 text-purple-600" />
              <span>Promote Class</span>
            </button>
          )}
          <button
            onClick={() => showToast("Opening Reports view for Excel import/export...", "info")}
            className="px-3.5 py-2 rounded-xl bg-white border border-border hover:bg-surface2 text-text font-bold text-xs transition-colors cursor-pointer shadow-2xs"
          >
            Import
          </button>
          <button
            onClick={() => showToast("Exporting students directory PDF...", "info")}
            className="px-3.5 py-2 rounded-xl bg-white border border-border hover:bg-surface2 text-text font-bold text-xs transition-colors cursor-pointer shadow-2xs"
          >
            Export PDF
          </button>
          {(isPrincipal || teacherPermissions?.canAddStudents !== false) && (
            <button
              onClick={() => {
                setEditingStudent(null);
                setIsAddStudentOpen(true);
              }}
              className="px-4 py-2 rounded-xl bg-primary hover:bg-primary-dark text-white font-bold text-xs shadow-md transition-all cursor-pointer flex items-center gap-1.5"
            >
              <Plus className="w-4 h-4" />
              <span>Add New Student</span>
            </button>
          )}
        </div>
      </div>

      {/* Main Split Layout */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6 items-start">
        {/* Left Side: Student Directory scroll list in a table format */}
        <div className="lg:col-span-8 bg-white border border-border rounded-2xl shadow-sm overflow-hidden flex flex-col">
          {/* Filters Bar */}
          <div className="p-4 border-b border-border flex flex-col sm:flex-row sm:items-center justify-between gap-3.5 bg-surface2/30">
            <div className="relative flex-1">
              <Search className="w-4 h-4 text-text-muted absolute left-3 top-1/2 -translate-y-1/2" />
              <input
                type="text"
                value={searchQuery}
                onChange={e => setSearchQuery(e.target.value)}
                placeholder="Search by Name, Admission ID..."
                className="w-full pl-9 pr-4 py-2 rounded-xl bg-white border border-border text-xs text-text focus:outline-none focus:border-primary"
              />
            </div>
            
            <div className="flex items-center gap-2">
              <select
                value={selectedClass}
                onChange={e => setSelectedClass(e.target.value)}
                className="px-3 py-2 rounded-xl bg-white border border-border text-xs text-text font-bold focus:outline-none cursor-pointer"
              >
                <option value="all">All Classes & Courses</option>
                {settings.schoolClasses?.map(c => <option key={c} value={c}>Class {c}</option>)}
                {settings.computerCourses?.map(c => <option key={c} value={c}>{c}</option>)}
              </select>

              <select
                value={selectedStatus}
                onChange={e => setSelectedStatus(e.target.value)}
                className="px-3 py-2 rounded-xl bg-white border border-border text-xs text-text font-bold focus:outline-none cursor-pointer"
              >
                <option value="all">All Status</option>
                <option value="active">Active</option>
                <option value="left">Left</option>
              </select>

              {!isPrincipal && selectedClass !== assignedClass && (
                <button
                  onClick={() => setSelectedClass(assignedClass)}
                  className="px-3 py-2 rounded-xl bg-primary/10 hover:bg-primary/20 text-primary text-xs font-bold transition-all flex items-center gap-1 cursor-pointer whitespace-nowrap"
                  title="Return to your assigned class"
                >
                  <span>↩ Back to Class {assignedClass}</span>
                </button>
              )}
            </div>
          </div>

          {/* Directory Scroll List Table */}
          <div className="overflow-x-auto max-h-[560px] overflow-y-auto custom-scrollbar">
            <table className="w-full text-left text-xs border-collapse">
              <thead>
                <tr className="bg-surface2/60 border-b border-border text-text-secondary font-bold text-[10px] uppercase">
                  <th className="py-3 px-4 w-10 text-center">
                    <input type="checkbox" className="w-4 h-4 rounded text-primary focus:ring-primary/20 cursor-pointer" />
                  </th>
                  <th className="py-3 px-4">Student Name</th>
                  <th className="py-3 px-4">Admission ID</th>
                  <th className="py-3 px-4">Class</th>
                  <th className="py-3 px-4">Status</th>
                  <th className="py-3 px-4 text-right">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border text-text">
                {filteredStudents.length === 0 ? (
                  <tr>
                    <td colSpan={6} className="py-12 text-center text-text-muted">No students matching criteria.</td>
                  </tr>
                ) : filteredStudents.map(s => {
                  const isSelected = s.id === selectedStudentId && panelMode !== 'add';
                  return (
                    <tr
                      key={s.id}
                      onClick={() => {
                        setPanelMode('quickview');
                        setSelectedStudentId(s.id);
                      }}
                      className={`cursor-pointer transition-colors ${
                        isSelected ? 'bg-primary/5 font-semibold' : 'hover:bg-surface2/30'
                      }`}
                    >
                      <td className="py-3.5 px-4 text-center" onClick={e => e.stopPropagation()}>
                        <input type="checkbox" className="w-4 h-4 rounded text-primary focus:ring-primary/20 cursor-pointer" />
                      </td>
                      <td className="py-3.5 px-4 font-bold text-text">
                        <div
                          className="flex items-center gap-2.5 hover:text-primary transition-colors cursor-pointer"
                          onClick={(e) => {
                            e.stopPropagation();
                            setViewingStudentProfile(s);
                          }}
                          title="Click to view full profile"
                        >
                          <div className="w-8 h-8 rounded-full bg-primary/10 text-primary flex items-center justify-center font-bold text-xs flex-shrink-0 overflow-hidden shadow-2xs">
                            {s.photoPath ? <img src={s.photoPath} alt={s.name} className="w-full h-full object-cover" /> : s.name?.charAt(0)}
                          </div>
                          <div>
                            <div>{s.name}</div>
                            <div className="text-[9px] text-text-muted font-normal">{s.mobile}</div>
                          </div>
                        </div>
                      </td>
                      <td className="py-3.5 px-4 font-mono font-medium text-text-secondary">{s.admissionNumber || 'ADM-24-001'}</td>
                      <td className="py-3.5 px-4 text-text-secondary">
                        {s.studentType === 'school' ? `Class ${s.className || ''} - ${s.section || 'A'}` : s.course}
                      </td>
                      <td className="py-3.5 px-4">
                        <span className={`px-2.5 py-0.5 rounded-full text-[9px] font-bold uppercase tracking-wider ${
                          s.status === 'active' ? 'bg-emerald-100 text-emerald-700' : 'bg-rose-100 text-rose-700'
                        }`}>
                          {s.status || 'Active'}
                        </span>
                      </td>
                      <td className="py-3.5 px-4 text-right" onClick={e => e.stopPropagation()}>
                        <div className="flex items-center justify-end gap-1.5">
                          <button
                            onClick={() => setViewingStudentProfile(s)}
                            className="p-1.5 rounded-lg bg-indigo-50 hover:bg-indigo-100 text-indigo-600 transition-colors cursor-pointer"
                            title="View Full Profile"
                          >
                            <Eye className="w-3.5 h-3.5" />
                          </button>
                          {currentUser?.role === 'principal' && (
                            <button
                              onClick={() => {
                                setIsFeeDetailSelectorOpen(false);
                                setFeeDetailStudent(s);
                              }}
                              className="p-1.5 rounded-lg bg-primary/10 hover:bg-primary/20 text-primary transition-colors cursor-pointer"
                              title="Manage Fee Structure & Payments"
                            >
                              <CreditCard className="w-3.5 h-3.5" />
                            </button>
                          )}
                          <button
                            onClick={() => {
                              setEditingStudent(s);
                              setIsAddStudentOpen(true);
                            }}
                            className="p-1.5 rounded-lg bg-surface2 hover:bg-border text-text-secondary transition-colors cursor-pointer"
                            title="Edit Profile"
                          >
                            <Edit className="w-3.5 h-3.5" />
                          </button>
                          {currentUser?.role === 'principal' && (
                            <button
                              onClick={() => deleteStudent(s.id)}
                              className="p-1.5 rounded-lg bg-rose-50 hover:bg-rose-100 text-rose-600 border border-rose-200 transition-colors cursor-pointer"
                              title="Delete Student"
                            >
                              <Trash2 className="w-3.5 h-3.5" />
                            </button>
                          )}
                        </div>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
          {/* Footer entries count */}
          <div className="px-5 py-4 border-t border-border bg-surface2/25 flex items-center justify-between text-xs text-text-secondary">
            <span>Showing 1-{filteredStudents.length} of {students.length} entries</span>
            <div className="flex items-center gap-2">
              <button className="px-2.5 py-1 bg-white border border-border rounded cursor-pointer">&lt;</button>
              <span className="font-bold text-primary px-2">1</span>
              <button className="px-2.5 py-1 bg-white border border-border rounded cursor-pointer">&gt;</button>
            </div>
          </div>
        </div>

        {/* Right Side: Dual-mode panel (Quick View / Profile Edit) */}
        <div className="lg:col-span-4 bg-white border border-border rounded-2xl shadow-sm overflow-hidden flex flex-col">
          {panelMode === 'quickview' && activeStudent ? (
            /* ─── STATE 1: STUDENT QUICK VIEW PANEL ─── */
            <div className="p-6 space-y-6 animate-in fade-in duration-200">
              {/* Header */}
              <div className="flex justify-between items-center">
                <h3 className="font-bold text-base text-text">Quick View</h3>
                <div className="flex items-center gap-1">
                  <button
                    onClick={() => {
                      setEditingStudent(activeStudent);
                      setIsAddStudentOpen(true);
                    }}
                    className="p-1.5 rounded-lg text-text-secondary hover:text-primary hover:bg-primary/10 transition-all cursor-pointer flex items-center gap-1 text-xs font-semibold"
                    title="Edit Profile"
                  >
                    <Edit className="w-3.5 h-3.5" />
                    <span>Edit</span>
                  </button>
                  <button
                    onClick={() => setSelectedStudentId(null)}
                    className="p-1 rounded-lg text-text-muted hover:text-text hover:bg-surface2 transition-all cursor-pointer"
                  >
                    <X className="w-4 h-4" />
                  </button>
                </div>
              </div>

              {/* Avatar and name details */}
              <div className="flex flex-col items-center text-center space-y-2 py-2">
                <div className="w-16 h-16 rounded-full bg-primary/10 text-primary flex items-center justify-center font-black text-lg overflow-hidden shadow-sm">
                  {activeStudent.photoPath ? (
                    <img src={activeStudent.photoPath} alt={activeStudent.name} className="w-full h-full object-cover" />
                  ) : (
                    activeStudent.name?.charAt(0) || 'S'
                  )}
                </div>
                <div>
                  <h4 className="font-black text-lg text-text leading-tight">{activeStudent.name}</h4>
                  <p className="text-xs text-text-secondary font-mono mt-0.5">ID: {activeStudent.studentId} · Roll: {activeStudent.rollNumber || '—'}</p>
                  {(activeStudent.aadhaarNumber || activeStudent.aadharNumber) && (
                    <p className="text-[11px] text-text-secondary font-mono mt-0.5">
                      Aadhaar: <span className="font-bold text-text">{activeStudent.aadhaarNumber || activeStudent.aadharNumber}</span>
                    </p>
                  )}
                </div>
                <span className="px-3 py-1 bg-primary/10 text-primary rounded-full text-[10px] font-bold">
                  {activeStudent.studentType === 'school' ? `Class ${activeStudent.className || ''} - Sec ${activeStudent.section || 'A'}` : activeStudent.course}
                </span>
              </div>

              {/* Attendance widget */}
              <div className="space-y-2 border-t border-border pt-4 text-xs font-semibold">
                <div className="flex justify-between text-text-secondary">
                  <span>Attendance (Current Term)</span>
                  <span className="text-primary font-bold">92%</span>
                </div>
                <div className="w-full h-2 bg-surface2 rounded-full overflow-hidden border border-border">
                  <div className="h-full bg-primary rounded-full" style={{ width: '92%' }}></div>
                </div>
                <div className="flex justify-between text-[10px] text-text-muted font-bold font-mono">
                  <span>Present: 46 Days</span>
                  <span>Absent: 4 Days</span>
                </div>
              </div>

              {/* Fee Status widgets (Principal Only) */}
              {currentUser?.role === 'principal' && (
                <div className="space-y-3 border-t border-border pt-4">
                  <span className="text-[10px] font-bold uppercase tracking-wider text-text-secondary">Fee Status</span>
                  <div className="space-y-2.5 text-xs font-semibold">
                    {(() => {
                      const m = calculateStudentFeeMetrics(activeStudent, payments);
                      return (
                        <>
                          <div className="p-3 bg-surface2/30 border border-border rounded-xl flex items-center justify-between">
                            <div>
                              <p className="text-text-secondary text-[10px]">Total Paid So Far</p>
                              <p className="text-sm font-bold text-emerald-600 mt-0.5">₹{(m.totalPaid || 0).toLocaleString('en-IN')}</p>
                            </div>
                            <span className="px-2 py-0.5 rounded bg-emerald-100 text-emerald-700 text-[9px] font-bold">PAID</span>
                          </div>

                          <div className={`p-3 border rounded-xl flex items-center justify-between ${m.currentDue > 0 ? 'bg-rose-50/40 border-rose-100' : 'bg-emerald-50/40 border-emerald-100'}`}>
                            <div>
                              <p className={`text-[10px] ${m.currentDue > 0 ? 'text-rose-600' : 'text-emerald-700'}`}>
                                {m.currentDue > 0 ? 'Outstanding Dues (Current Month)' : 'Fee Status'}
                              </p>
                              <p className={`text-sm font-bold mt-0.5 ${m.currentDue > 0 ? 'text-rose-600' : 'text-emerald-700'}`}>
                                ₹{(m.currentDue || 0).toLocaleString('en-IN')}
                              </p>
                            </div>
                            <span className={`px-2 py-0.5 rounded text-[9px] font-bold ${m.currentDue > 0 ? 'bg-rose-100 text-rose-700' : 'bg-emerald-100 text-emerald-700'}`}>
                              {m.currentDue > 0 ? 'OVERDUE' : 'CLEARED'}
                            </span>
                          </div>
                        </>
                      );
                    })()}
                  </div>
                </div>
              )}

              {/* Guardian Info */}
              <div className="space-y-2 border-t border-border pt-4 text-xs font-semibold">
                <span className="text-[10px] font-bold uppercase tracking-wider text-text-secondary">Primary Guardian</span>
                <div className="p-3 bg-surface2/30 border border-border rounded-xl space-y-1.5 leading-tight">
                  <p className="text-text font-bold">{activeStudent.fatherName || 'Guardian'} (Father)</p>
                  <p className="text-[10px] text-text-secondary flex items-center gap-1"><Phone className="w-3 h-3 text-text-muted" /> {activeStudent.mobile}</p>
                  <p className="text-[10px] text-text-secondary flex items-center gap-1"><Mail className="w-3 h-3 text-text-muted" /> {activeStudent.email || 'guardian@example.com'}</p>
                </div>
              </div>

              {/* Actions row */}
              <div className="grid grid-cols-2 gap-3 pt-4 text-xs font-bold">
                <button
                  onClick={() => setWhatsAppReminderData({ student: activeStudent })}
                  className="py-2.5 rounded-xl border border-border bg-surface2 hover:bg-border text-text text-center transition-colors cursor-pointer flex items-center justify-center gap-1"
                  title="Send WhatsApp Fee Reminder / Message (Hindi / English)"
                >
                  <MessageSquare className="w-4 h-4 text-emerald-600" />
                  <span>WhatsApp</span>
                </button>
                <button
                  onClick={() => setViewingStudentProfile(activeStudent)}
                  className="py-2.5 rounded-xl bg-primary hover:bg-primary-dark text-white text-center transition-all cursor-pointer shadow-sm flex items-center justify-center gap-1.5"
                >
                  <Eye className="w-4 h-4" />
                  <span>Full Profile</span>
                </button>
              </div>
            </div>
          ) : (
            /* ─── STATE 2 & 3: ADMISSION FORM & PROFILE EDITOR ─── */
            <form onSubmit={handleSaveProfile} className="animate-in fade-in duration-200">
              <div className="px-5 py-4 border-b border-border bg-surface2/25 flex items-center justify-between">
                <div>
                  <h3 className="font-bold text-xs uppercase text-text tracking-wider">
                    {panelMode === 'add' ? 'New Admission' : 'Edit Profile'}
                  </h3>
                </div>
                <div className="flex items-center gap-2">
                  <button
                    type="button"
                    onClick={() => setPanelMode('quickview')}
                    className="px-3 py-1 rounded bg-surface2 hover:bg-border text-text font-bold text-[10px] border border-border cursor-pointer"
                  >
                    Cancel
                  </button>
                  <button
                    type="submit"
                    className="px-3.5 py-1 rounded bg-primary hover:bg-primary-dark text-white font-bold text-[10px] shadow-xs cursor-pointer"
                  >
                    {panelMode === 'add' ? 'Create' : 'Save'}
                  </button>
                </div>
              </div>

              <div className="p-5 space-y-4 max-h-[580px] overflow-y-auto custom-scrollbar text-xs font-semibold text-text-secondary">
                {/* Student Photo in Form */}
                <div className="flex items-center gap-3 p-3 bg-surface2/40 rounded-xl border border-border/80">
                  <div className="w-14 h-16 rounded-xl bg-slate-900 border border-amber-400/50 flex items-center justify-center overflow-hidden flex-shrink-0 shadow-2xs">
                    {profileForm.photoPath ? (
                      <img src={profileForm.photoPath} alt="Photo" className="w-full h-full object-cover" onError={(e) => { e.currentTarget.style.display = 'none'; }} />
                    ) : (
                      <User className="w-7 h-7 text-slate-400" />
                    )}
                  </div>
                  <div className="flex-1 space-y-1">
                    <p className="text-[11px] font-bold text-text">Student Photo</p>
                    <div className="flex items-center gap-1.5 flex-wrap">
                      <label className="cursor-pointer">
                        <input
                          ref={photoInputRef}
                          type="file"
                          accept="image/*"
                          className="hidden"
                          onChange={(e) => {
                            const file = e.target.files?.[0];
                            if (file) {
                              const reader = new FileReader();
                              reader.onload = (ev) => {
                                setImageToCrop(ev.target?.result);
                                setIsCropperOpen(true);
                              };
                              reader.readAsDataURL(file);
                              e.target.value = '';
                            }
                          }}
                        />
                        <span className="px-2 py-1 rounded bg-primary hover:bg-primary-dark text-white text-[10px] font-bold flex items-center gap-1 shadow-2xs">
                          <Upload className="w-3 h-3" />
                          <span>{profileForm.photoPath ? 'Change' : 'Upload'}</span>
                        </span>
                      </label>
                      {profileForm.photoPath && (
                        <>
                          <button
                            type="button"
                            onClick={() => {
                              setImageToCrop(profileForm.photoPath);
                              setIsCropperOpen(true);
                            }}
                            className="px-2 py-1 rounded bg-amber-400 hover:bg-amber-500 text-slate-950 text-[10px] font-bold flex items-center gap-1 shadow-2xs cursor-pointer"
                          >
                            <Crop className="w-3 h-3" /> Crop
                          </button>
                          <button
                            type="button"
                            onClick={() => setProfileForm(prev => ({ ...prev, photoPath: '', photoUrl: '' }))}
                            className="p-1 rounded bg-rose-50 hover:bg-rose-100 text-rose-600 border border-rose-200 text-[10px] font-bold cursor-pointer"
                            title="Remove Photo"
                          >
                            <Trash2 className="w-3 h-3" />
                          </button>
                        </>
                      )}
                    </div>
                  </div>
                </div>

                {/* Inputs Fields */}
                <div>
                  <label className="block mb-1 text-text">Full Name *</label>
                  <input
                    type="text"
                    required
                    value={profileForm.name}
                    onChange={e => handleInputChange('name', e.target.value)}
                    className="w-full px-2.5 py-1.5 rounded bg-surface2 border border-border text-xs text-text font-semibold focus:outline-none focus:border-primary"
                  />
                </div>

                <div className="grid grid-cols-2 gap-3">
                  <div>
                    <label className="block mb-1 text-text">Date of Birth</label>
                    <input
                      type="date"
                      value={profileForm.dob}
                      onChange={e => handleInputChange('dob', e.target.value)}
                      className="w-full px-2.5 py-1.5 rounded bg-surface2 border border-border text-xs text-text font-semibold focus:outline-none"
                    />
                  </div>
                  <div>
                    <label className="block mb-1 text-text">Gender</label>
                    <select
                      value={profileForm.gender}
                      onChange={e => handleInputChange('gender', e.target.value)}
                      className="w-full px-2.5 py-1.5 rounded bg-surface2 border border-border text-xs text-text font-semibold focus:outline-none cursor-pointer"
                    >
                      <option value="Male">Male</option>
                      <option value="Female">Female</option>
                    </select>
                  </div>
                </div>

                <div>
                  <label className="block mb-1 text-text">Mobile Number *</label>
                  <input
                    type="text"
                    required
                    value={profileForm.mobile}
                    onChange={e => handleInputChange('mobile', e.target.value)}
                    className="w-full px-2.5 py-1.5 rounded bg-surface2 border border-border text-xs text-text font-semibold focus:outline-none"
                  />
                </div>

                <div className="grid grid-cols-2 gap-3">
                  <div>
                    <label className="block mb-1 text-text">Email Address</label>
                    <input
                      type="email"
                      value={profileForm.email}
                      onChange={e => handleInputChange('email', e.target.value)}
                      className="w-full px-2.5 py-1.5 rounded bg-surface2 border border-border text-xs text-text font-semibold focus:outline-none"
                    />
                  </div>
                  <div>
                    <label className="block mb-1 text-text">Aadhaar / Document ID</label>
                    <input
                      type="text"
                      maxLength={14}
                      placeholder="12-digit Aadhaar No."
                      value={profileForm.aadhaarNumber || ''}
                      onChange={e => handleInputChange('aadhaarNumber', e.target.value)}
                      className="w-full px-2.5 py-1.5 rounded bg-surface2 border border-border text-xs text-text font-mono focus:outline-none"
                    />
                  </div>
                </div>

                <div className="border-t border-border pt-3 space-y-3">
                  <h4 className="font-bold text-[10px] text-primary uppercase">Academic Information</h4>
                  
                  <div className="grid grid-cols-2 gap-3">
                    <div>
                      <label className="block mb-1 text-text">Student ID</label>
                      <input
                        type="text"
                        value={profileForm.studentId}
                        onChange={e => handleInputChange('studentId', e.target.value)}
                        className="w-full px-2.5 py-1.5 rounded bg-surface2 border border-border text-xs text-text focus:outline-none"
                      />
                    </div>
                    <div>
                      <label className="block mb-1 text-text">Roll Number</label>
                      <input
                        type="text"
                        value={profileForm.rollNumber}
                        onChange={e => handleInputChange('rollNumber', e.target.value)}
                        className="w-full px-2.5 py-1.5 rounded bg-surface2 border border-border text-xs text-text focus:outline-none"
                      />
                    </div>
                  </div>

                  <div>
                    <label className="block mb-1 text-text">Enrollment Sector</label>
                    <select
                      value={profileForm.studentType}
                      onChange={e => handleInputChange('studentType', e.target.value)}
                      className="w-full px-2.5 py-1.5 rounded bg-surface2 border border-border text-xs text-text font-semibold focus:outline-none cursor-pointer"
                    >
                      <option value="school">School</option>
                      <option value="computer">Computer Institute</option>
                    </select>
                  </div>

                  {profileForm.studentType === 'school' ? (
                    <div className="grid grid-cols-2 gap-3">
                      <div>
                        <label className="block mb-1 text-text">Class Grade</label>
                        <select
                          value={profileForm.className || ''}
                          onChange={e => handleInputChange('className', e.target.value)}
                          className="w-full px-2.5 py-1.5 rounded bg-surface2 border border-border text-xs text-text font-semibold focus:outline-none cursor-pointer"
                        >
                          {settings.schoolClasses?.map(c => <option key={c} value={c}>Class {c}</option>)}
                        </select>
                      </div>
                      <div>
                        <label className="block mb-1 text-text">Section</label>
                        <select
                          value={profileForm.section || ''}
                          onChange={e => handleInputChange('section', e.target.value)}
                          className="w-full px-2.5 py-1.5 rounded bg-surface2 border border-border text-xs text-text font-semibold focus:outline-none cursor-pointer"
                        >
                          <option value="A">A</option>
                          <option value="B">B</option>
                          <option value="C">C</option>
                        </select>
                      </div>
                    </div>
                  ) : (
                    <div>
                      <label className="block mb-1 text-text">Course Details</label>
                      <select
                        value={profileForm.course || ''}
                        onChange={e => handleInputChange('course', e.target.value)}
                        className="w-full px-2.5 py-1.5 rounded bg-surface2 border border-border text-xs text-text font-semibold focus:outline-none cursor-pointer"
                      >
                        {settings.computerCourses?.map(c => <option key={c} value={c}>{c}</option>)}
                      </select>
                    </div>
                  )}
                </div>

                <div className="border-t border-border pt-3 space-y-3">
                  <h4 className="font-bold text-[10px] text-primary uppercase">Guardians Details</h4>
                  <div>
                    <label className="block mb-1 text-text">Father's Name</label>
                    <input
                      type="text"
                      value={profileForm.fatherName}
                      onChange={e => handleInputChange('fatherName', e.target.value)}
                      className="w-full px-2.5 py-1.5 rounded bg-surface2 border border-border text-xs text-text focus:outline-none"
                    />
                  </div>
                  <div>
                    <label className="block mb-1 text-text">Mother's Name</label>
                    <input
                      type="text"
                      value={profileForm.motherName}
                      onChange={e => handleInputChange('motherName', e.target.value)}
                      className="w-full px-2.5 py-1.5 rounded bg-surface2 border border-border text-xs text-text focus:outline-none"
                    />
                  </div>
                  <div>
                    <label className="block mb-1 text-text">Campus Address</label>
                    <textarea
                      rows={2}
                      value={profileForm.address}
                      onChange={e => handleInputChange('address', e.target.value)}
                      className="w-full px-2.5 py-1.5 rounded bg-surface2 border border-border text-xs text-text focus:outline-none resize-none"
                    />
                  </div>
                </div>

                {panelMode !== 'add' && (
                  <div className="pt-2 flex justify-end">
                    <button
                      type="button"
                      onClick={handleDeleteClick}
                      className="px-3 py-1.5 rounded bg-rose-50 hover:bg-rose-100 text-rose-600 font-bold border border-rose-200 cursor-pointer"
                    >
                      Delete Student
                    </button>
                  </div>
                )}
              </div>
            </form>
          )}
        </div>
      </div>
      {/* Interactive Photo Cropper Modal */}
      <ImageCropperModal
        isOpen={isCropperOpen}
        imageSrc={imageToCrop}
        title="Crop Student Photo"
        initialAspect="3:4"
        onCropComplete={(croppedDataUrl) => {
          handleInputChange('photoPath', croppedDataUrl);
          showToast('Photo cropped and applied!', 'success');
        }}
        onClose={() => {
          setIsCropperOpen(false);
          setImageToCrop(null);
        }}
      />

      {/* 1-Click Student Promotion Modal */}
      <PromoteStudentsModal
        isOpen={isPromoteModalOpen}
        onClose={() => setIsPromoteModalOpen(false)}
      />

      {/* WhatsApp Reminder Modal (Hindi & English) */}
      <WhatsAppReminderModal
        isOpen={!!whatsAppReminderData}
        onClose={() => setWhatsAppReminderData(null)}
        {...(whatsAppReminderData || {})}
      />
    </div>
  );
}
