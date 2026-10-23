'use client';

import React, { useState } from 'react';
import { useSchoolStore } from '../lib/store';
import {
  X, Search, Phone, MessageSquare, CheckCircle2, XCircle, Clock,
  Calendar, MapPin, User, GraduationCap, Briefcase, Award,
  Sparkles, Filter, ChevronDown, Trash2, ArrowRight, BookOpen,
  UserCheck, AlertCircle, Building, Check, ExternalLink, Bus,
  Eye, Printer, FileText, BadgeCheck, ShieldCheck, Download
} from 'lucide-react';

export default function OnlineEnquiriesModal({ isOpen, onClose, initialTab = 'admissions' }) {
  const {
    admissionEnquiries = [],
    teacherApplications = [],
    updateAdmissionEnquiryStatus,
    deleteAdmissionEnquiry,
    updateTeacherApplicationStatus,
    deleteTeacherApplication,
    addStudent,
    addTeacher,
    setIsAddStudentOpen,
    setEditingStudent,
    showToast,
    settings
  } = useSchoolStore();

  const [activeTab, setActiveTab] = useState(initialTab);

  React.useEffect(() => {
    if (initialTab) setActiveTab(initialTab);
  }, [initialTab]);

  const [searchQuery, setSearchQuery] = useState('');
  const [statusFilter, setStatusFilter] = useState('all');
  const [classFilter, setClassFilter] = useState('all');
  const [processingId, setProcessingId] = useState(null);

  // Modals for full Form View
  const [selectedAdmissionForView, setSelectedAdmissionForView] = useState(null);
  const [selectedTeacherForView, setSelectedTeacherForView] = useState(null);

  if (!isOpen) return null;

  const schoolName = settings?.instituteName || settings?.schoolName || 'Mission Navodaya Public School';
  const logoSrc = settings?.logoUrl || settings?.logoPath || settings?.logo || '/logo.png';
  const schoolPhone = settings?.phone || '8603481865';

  // ── Filtered Admission Enquiries ──
  const filteredAdmissions = admissionEnquiries.filter(item => {
    if (statusFilter !== 'all' && (item.status || 'pending') !== statusFilter) return false;
    if (classFilter !== 'all' && item.admissionClass !== classFilter) return false;
    if (searchQuery.trim()) {
      const q = searchQuery.toLowerCase();
      const matchName = (item.studentName || '').toLowerCase().includes(q);
      const matchFather = (item.fatherName || '').toLowerCase().includes(q);
      const matchMob = (item.mobile || '').includes(q);
      const matchRef = (item.refNo || '').toLowerCase().includes(q);
      const matchClass = (item.admissionClass || '').toLowerCase().includes(q);
      if (!matchName && !matchFather && !matchMob && !matchRef && !matchClass) return false;
    }
    return true;
  });

  // ── Filtered Teacher Applications ──
  const filteredTeachers = teacherApplications.filter(item => {
    if (statusFilter !== 'all' && (item.status || 'pending') !== statusFilter) return false;
    if (searchQuery.trim()) {
      const q = searchQuery.toLowerCase();
      const matchName = (item.teacherName || '').toLowerCase().includes(q);
      const matchSub = (item.subjectSpecialization || '').toLowerCase().includes(q);
      const matchMob = (item.mobile || '').includes(q);
      const matchEmail = (item.email || '').toLowerCase().includes(q);
      const matchRef = (item.refNo || '').toLowerCase().includes(q);
      if (!matchName && !matchSub && !matchMob && !matchEmail && !matchRef) return false;
    }
    return true;
  });

  const pendingAdmissionsCount = admissionEnquiries.filter(a => (a.status || 'pending') === 'pending').length;
  const pendingTeachersCount = teacherApplications.filter(t => (t.status || 'pending') === 'pending').length;

  // ── WhatsApp Helper for Admission ──
  const handleWhatsAppAdmission = (item) => {
    const rawMob = (item.mobile || '').replace(/\D/g, '');
    const cleanMob = rawMob.length === 10 ? '91' + rawMob : rawMob;
    const text = `नमस्ते ${item.fatherName ? item.fatherName + ' जी' : 'अभिभावक'},

${schoolName} में ${item.studentName} के ऑनलाइन प्रवेश आवेदन (Ref: ${item.refNo}, कक्षा: ${item.admissionClass}) के संबंध में विद्यालय प्रबंधन की ओर से आपसे संपर्क किया जा रहा है।

प्रवेश संबंधी औपचारिकताएं एवं आगे की जानकारी के लिए कृपया बताएं कि हम आपसे किस समय वार्ता कर सकते हैं?

धन्यवाद,
${schoolName}
हेल्पलाइन: ${schoolPhone}`;
    window.open(`https://wa.me/${cleanMob}?text=${encodeURIComponent(text)}`, '_blank');
  };

  // ── WhatsApp Helper for Teacher ──
  const handleWhatsAppTeacher = (item) => {
    const rawMob = (item.mobile || '').replace(/\D/g, '');
    const cleanMob = rawMob.length === 10 ? '91' + rawMob : rawMob;
    const text = `Dear ${item.teacherName},

Greetings from ${schoolName}!

We received your job application for the faculty position (${item.subjectSpecialization || 'Teaching'}, Ref: ${item.refNo}).

Our Academic Selection Committee has reviewed your profile. We would like to invite you for a personal interview and demo session at our campus.

Please let us know your availability.

Regards,
Principal / Academic Director
${schoolName}`;
    window.open(`https://wa.me/${cleanMob}?text=${encodeURIComponent(text)}`, '_blank');
  };

  // ── 1-Click Convert to Enrolled Student ──
  const handleConvertToStudent = async (item) => {
    setProcessingId(item.refNo);
    try {
      const cleanClass = (item.admissionClass || '1st').replace(/^Class\s+/i, '');
      const studentPayload = {
        name: item.studentName || 'Student',
        className: cleanClass,
        section: 'A',
        fatherName: item.fatherName || '',
        motherName: item.motherName || '',
        mobile: item.mobile || '',
        gender: item.gender || 'Male',
        address: item.address || '',
        dob: item.dob || '2015-01-01',
        admissionDate: new Date().toISOString().split('T')[0],
        status: 'active',
        studentType: 'school',
        transportNeeded: item.transportRequired === 'Yes',
        remarks: `Website Online Admission Enquiry Ref: ${item.refNo}`
      };

      if (addStudent) {
        await addStudent(studentPayload);
      }
      if (updateAdmissionEnquiryStatus) {
        await updateAdmissionEnquiryStatus(item.refNo, 'approved');
      }
      showToast(`🎉 ${item.studentName} को कक्षा ${cleanClass} में सफलतापूर्वक नामांकित कर दिया गया!`, 'success');

      if (selectedAdmissionForView?.refNo === item.refNo) {
        setSelectedAdmissionForView(prev => prev ? { ...prev, status: 'approved' } : null);
      }
    } catch (err) {
      console.error('Enroll error:', err);
      showToast('नामांकन में त्रुटि: ' + (err.message || 'Error occurred'), 'error');
    } finally {
      setProcessingId(null);
    }
  };

  // ── Open Full Editor in AddEditStudentModal ──
  const handleOpenInFullEditor = (item) => {
    const cleanClass = (item.admissionClass || '1st').replace(/^Class\s+/i, '');
    const studentData = {
      name: item.studentName || '',
      className: cleanClass,
      section: 'A',
      fatherName: item.fatherName || '',
      motherName: item.motherName || '',
      mobile: item.mobile || '',
      gender: item.gender || 'Male',
      address: item.address || '',
      dob: item.dob || '2015-01-01',
      admissionDate: new Date().toISOString().split('T')[0],
      status: 'active',
      studentType: 'school',
      transportNeeded: item.transportRequired === 'Yes',
      remarks: `Website Online Enquiry Ref: ${item.refNo}`
    };

    if (setEditingStudent) setEditingStudent(studentData);
    if (setIsAddStudentOpen) setIsAddStudentOpen(true);
    setSelectedAdmissionForView(null);
    onClose();
  };

  // ── 1-Click Convert to Teacher ──
  const handleConvertToTeacher = async (item) => {
    setProcessingId(item.refNo);
    try {
      const teacherPayload = {
        name: item.teacherName,
        subject: item.subjectSpecialization || 'General',
        mobile: item.mobile || '',
        email: item.email || '',
        qualification: item.highestDegree || '',
        role: 'teacher',
        status: 'active',
        experience: item.experience || '',
        remarks: `Website Faculty Application Ref: ${item.refNo}`
      };

      if (addTeacher) {
        await addTeacher(teacherPayload);
      }
      if (updateTeacherApplicationStatus) {
        await updateTeacherApplicationStatus(item.refNo, 'approved');
      }
      showToast(`🎉 ${item.teacherName} को शिक्षक सूची में सफलतापूर्वक जोड़ दिया गया!`, 'success');

      if (selectedTeacherForView?.refNo === item.refNo) {
        setSelectedTeacherForView(prev => prev ? { ...prev, status: 'approved' } : null);
      }
    } catch (err) {
      showToast('शिक्षक जोड़ने में त्रुटि: ' + (err.message || 'Error occurred'), 'error');
    } finally {
      setProcessingId(null);
    }
  };

  return (
    <>
      <div className="fixed inset-0 z-50 flex items-center justify-center p-3 sm:p-5 bg-black/60 backdrop-blur-sm animate-in fade-in duration-200">
        <div className="bg-[#f8fafc] w-full max-w-5xl rounded-3xl border border-slate-200/90 shadow-2xl flex flex-col max-h-[92vh] overflow-hidden">
          
          {/* ── Modal Top Header ── */}
          <div className="p-5 sm:p-6 bg-gradient-to-r from-[#0c2340] via-[#153459] to-[#0c2340] text-white flex items-center justify-between gap-4 flex-shrink-0">
            <div className="flex items-center gap-3">
              <div className="w-11 h-11 rounded-2xl bg-amber-400 text-[#0c2340] flex items-center justify-center font-black shadow-md flex-shrink-0">
                <Sparkles className="w-6 h-6" />
              </div>
              <div>
                <div className="flex items-center gap-2">
                  <h3 className="text-lg sm:text-xl font-black tracking-tight text-white">
                    Online Admissions & Faculty Desk
                  </h3>
                  <span className="px-2 py-0.5 rounded-full bg-emerald-500/20 border border-emerald-400/30 text-[10px] font-extrabold text-emerald-300 flex items-center gap-1">
                    <span className="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse" />
                    Live Sync
                  </span>
                </div>
                <p className="text-xs text-slate-300 mt-0.5">
                  वेबसाइट से प्राप्त नए छात्र नामांकन एवं शिक्षक भर्ती आवेदन (क्लिक करके पूरा फॉर्म देखें)
                </p>
              </div>
            </div>

            <button
              onClick={onClose}
              className="w-9 h-9 rounded-xl bg-white/10 hover:bg-white/20 text-white flex items-center justify-center transition-all cursor-pointer flex-shrink-0"
              title="Close modal"
            >
              <X className="w-5 h-5" />
            </button>
          </div>

          {/* ── Navigation Tabs & Filters Bar ── */}
          <div className="px-5 py-3.5 bg-white border-b border-slate-200 flex flex-wrap items-center justify-between gap-3 flex-shrink-0">
            {/* Tabs */}
            <div className="flex items-center gap-2">
              <button
                onClick={() => { setActiveTab('admissions'); setStatusFilter('all'); }}
                className={`px-4 py-2 rounded-xl text-xs font-black flex items-center gap-2 transition-all cursor-pointer ${
                  activeTab === 'admissions'
                    ? 'bg-[#0c2340] text-white shadow-xs'
                    : 'bg-slate-100 text-slate-600 hover:bg-slate-200'
                }`}
              >
                <BookOpen className="w-3.5 h-3.5 text-amber-400" />
                <span>Student Admissions</span>
                {pendingAdmissionsCount > 0 && (
                  <span className="px-1.5 py-0.2 rounded-full bg-amber-400 text-[#0c2340] text-[10px] font-black">
                    {pendingAdmissionsCount}
                  </span>
                )}
              </button>

              <button
                onClick={() => { setActiveTab('teachers'); setStatusFilter('all'); }}
                className={`px-4 py-2 rounded-xl text-xs font-black flex items-center gap-2 transition-all cursor-pointer ${
                  activeTab === 'teachers'
                    ? 'bg-[#0c2340] text-white shadow-xs'
                    : 'bg-slate-100 text-slate-600 hover:bg-slate-200'
                }`}
              >
                <GraduationCap className="w-3.5 h-3.5 text-indigo-400" />
                <span>Teacher Applications</span>
                {pendingTeachersCount > 0 && (
                  <span className="px-1.5 py-0.2 rounded-full bg-indigo-400 text-white text-[10px] font-black">
                    {pendingTeachersCount}
                  </span>
                )}
              </button>
            </div>

            {/* Search & Status Filter */}
            <div className="flex items-center gap-2 flex-grow sm:flex-grow-0">
              <div className="relative flex-grow sm:w-56">
                <Search className="w-3.5 h-3.5 text-slate-400 absolute left-3 top-1/2 -translate-y-1/2" />
                <input
                  type="text"
                  placeholder={activeTab === 'admissions' ? 'Search student, mobile, class...' : 'Search teacher, subject...'}
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  className="w-full pl-8 pr-3 py-1.5 bg-slate-50 border border-slate-200 rounded-xl text-xs text-slate-800 placeholder:text-slate-400 focus:outline-none focus:border-[#0c2340]"
                />
              </div>

              <select
                value={statusFilter}
                onChange={(e) => setStatusFilter(e.target.value)}
                className="px-2.5 py-1.5 bg-slate-50 border border-slate-200 rounded-xl text-xs font-bold text-slate-700 cursor-pointer focus:outline-none"
              >
                <option value="all">All Status</option>
                <option value="pending">🟡 Pending</option>
                <option value="contacted">🔵 Contacted</option>
                <option value="approved">🟢 Enrolled / Approved</option>
                <option value="rejected">🔴 Rejected</option>
              </select>
            </div>
          </div>

          {/* ── Content List Area ── */}
          <div className="flex-1 overflow-y-auto p-5 space-y-3.5">
            {activeTab === 'admissions' ? (
              /* Student Admissions List */
              filteredAdmissions.length === 0 ? (
                <div className="text-center py-16 bg-white rounded-2xl border border-slate-200/80 shadow-2xs space-y-3">
                  <div className="w-14 h-14 mx-auto rounded-2xl bg-amber-50 border border-amber-200 text-amber-600 flex items-center justify-center">
                    <BookOpen className="w-7 h-7" />
                  </div>
                  <h4 className="text-base font-black text-slate-800">No Admission Enquiries Found</h4>
                  <p className="text-xs text-slate-500 max-w-sm mx-auto">
                    {searchQuery || statusFilter !== 'all'
                      ? 'फ़िल्टर के अनुसार कोई परिणाम नहीं मिला। फ़िल्टर रीसेट करें।'
                      : 'वेबसाइट से छात्र प्रवेश प्रपत्र सबमिट होने पर वे यहाँ तुरंत दिखाई देंगे।'}
                  </p>
                </div>
              ) : (
                filteredAdmissions.map((item) => {
                  const status = item.status || 'pending';
                  const statusColors = {
                    pending: 'bg-amber-50 text-amber-700 border-amber-200',
                    contacted: 'bg-blue-50 text-blue-700 border-blue-200',
                    approved: 'bg-emerald-50 text-emerald-700 border-emerald-200',
                    enrolled: 'bg-emerald-50 text-emerald-700 border-emerald-200',
                    rejected: 'bg-rose-50 text-rose-700 border-rose-200'
                  };

                  return (
                    <div
                      key={item.refNo}
                      onClick={() => setSelectedAdmissionForView(item)}
                      className="p-4 sm:p-5 bg-white rounded-2xl border border-slate-200 shadow-2xs hover:shadow-md hover:border-[#0c2340]/40 transition-all space-y-3 cursor-pointer group"
                    >
                      {/* Top Row: Ref & Status */}
                      <div className="flex flex-wrap items-center justify-between gap-2 border-b border-slate-100 pb-2.5">
                        <div className="flex items-center gap-2">
                          <span className="px-2.5 py-0.5 rounded-lg bg-slate-100 border border-slate-200 text-slate-700 font-mono text-[11px] font-black">
                            {item.refNo}
                          </span>
                          <span className={`px-2.5 py-0.5 rounded-full border text-[10px] font-black uppercase tracking-wider ${statusColors[status] || statusColors.pending}`}>
                            {status === 'approved' ? 'ENROLLED / APPROVED' : status}
                          </span>
                          {item.transportRequired === 'Yes' && (
                            <span className="px-2 py-0.5 rounded-full bg-amber-50 border border-amber-200 text-amber-700 text-[10px] font-black flex items-center gap-1">
                              <Bus className="w-3 h-3" />
                              Bus Needed
                            </span>
                          )}
                        </div>

                        <div className="flex items-center gap-2">
                          <div className="text-[11px] text-slate-400 font-medium">
                            {item.submittedAt ? new Date(item.submittedAt).toLocaleString('en-IN', { dateStyle: 'medium', timeStyle: 'short' }) : 'Recently'}
                          </div>
                          <span className="text-xs font-bold text-indigo-600 group-hover:text-indigo-800 flex items-center gap-1 bg-indigo-50 px-2 py-0.5 rounded-lg border border-indigo-100">
                            <Eye className="w-3 h-3" />
                            <span>View Form</span>
                          </span>
                        </div>
                      </div>

                      {/* Middle Details Grid */}
                      <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
                        <div>
                          <div className="text-[10px] uppercase font-black text-slate-400">Student Name</div>
                          <div className="text-sm font-black text-[#0c2340] group-hover:text-indigo-900">{item.studentName}</div>
                          <div className="text-[11px] text-slate-500 font-medium">{item.gender} · {item.medium || 'English'} Med.</div>
                        </div>

                        <div>
                          <div className="text-[10px] uppercase font-black text-slate-400">Admission Class</div>
                          <div className="text-sm font-black text-indigo-700">Class {item.admissionClass}</div>
                          <div className="text-[11px] text-slate-500 font-medium">DOB: {item.dob || 'N/A'}</div>
                        </div>

                        <div>
                          <div className="text-[10px] uppercase font-black text-slate-400">Father / Guardian</div>
                          <div className="text-sm font-bold text-slate-800">{item.fatherName}</div>
                          <div className="text-[11px] text-slate-500 font-medium">{item.fatherOccupation || 'Guardian'}</div>
                        </div>

                        <div>
                          <div className="text-[10px] uppercase font-black text-slate-400">Contact & Address</div>
                          <div className="text-sm font-black text-slate-800 font-mono">{item.mobile}</div>
                          <div className="text-[11px] text-slate-500 truncate" title={item.address}>{item.address || 'Local'}</div>
                        </div>
                      </div>

                      {item.previousSchool && (
                        <div className="p-2 bg-slate-50 rounded-xl text-xs text-slate-600 flex items-center gap-1.5">
                          <Building className="w-3.5 h-3.5 text-slate-400 flex-shrink-0" />
                          <span>Previous School: <strong>{item.previousSchool}</strong> {item.lastClassPassed ? `(Class: ${item.lastClassPassed})` : ''}</span>
                        </div>
                      )}

                      {/* Bottom Action Toolbar */}
                      <div
                        onClick={(e) => e.stopPropagation()}
                        className="pt-2 flex flex-wrap items-center justify-between gap-2 border-t border-slate-100"
                      >
                        <div className="flex items-center gap-2">
                          {/* Call */}
                          <a
                            href={`tel:${item.mobile}`}
                            className="px-3 py-1.5 rounded-xl bg-slate-100 hover:bg-slate-200 text-slate-800 text-xs font-bold transition-all flex items-center gap-1.5 cursor-pointer"
                          >
                            <Phone className="w-3.5 h-3.5 text-blue-600" />
                            <span>Call</span>
                          </a>

                          {/* WhatsApp */}
                          <button
                            type="button"
                            onClick={() => handleWhatsAppAdmission(item)}
                            className="px-3 py-1.5 rounded-xl bg-emerald-50 hover:bg-emerald-100 text-emerald-800 border border-emerald-200 text-xs font-bold transition-all flex items-center gap-1.5 cursor-pointer"
                          >
                            <MessageSquare className="w-3.5 h-3.5 text-emerald-600" />
                            <span>WhatsApp</span>
                          </button>

                          {/* View Form Button */}
                          <button
                            type="button"
                            onClick={() => setSelectedAdmissionForView(item)}
                            className="px-3 py-1.5 rounded-xl bg-indigo-50 hover:bg-indigo-100 text-indigo-800 border border-indigo-200 text-xs font-bold transition-all flex items-center gap-1.5 cursor-pointer"
                          >
                            <FileText className="w-3.5 h-3.5 text-indigo-600" />
                            <span>View Details Form</span>
                          </button>

                          {/* 1-Click Convert to Enrolled Student */}
                          {status !== 'approved' && status !== 'enrolled' ? (
                            <button
                              type="button"
                              disabled={processingId === item.refNo}
                              onClick={() => handleConvertToStudent(item)}
                              className="px-3.5 py-1.5 rounded-xl bg-[#0c2340] hover:bg-[#153459] text-white text-xs font-black transition-all flex items-center gap-1.5 shadow-2xs cursor-pointer"
                            >
                              <UserCheck className="w-3.5 h-3.5 text-amber-400" />
                              <span>{processingId === item.refNo ? 'Enrolling...' : 'Enroll as Student'}</span>
                            </button>
                          ) : (
                            <span className="px-3 py-1 rounded-xl bg-emerald-100 text-emerald-800 text-xs font-black flex items-center gap-1">
                              <CheckCircle2 className="w-3.5 h-3.5" />
                              <span>Enrolled</span>
                            </span>
                          )}
                        </div>

                        <div className="flex items-center gap-2">
                          {/* Quick Status Toggles */}
                          <button
                            type="button"
                            onClick={() => updateAdmissionEnquiryStatus(item.refNo, status === 'contacted' ? 'pending' : 'contacted')}
                            className="text-[11px] font-bold text-blue-600 hover:underline cursor-pointer"
                          >
                            {status === 'contacted' ? 'Mark Pending' : 'Mark Contacted'}
                          </button>
                          <span className="text-slate-300">·</span>
                          <button
                            type="button"
                            onClick={() => {
                              if (confirm(`Delete enquiry ${item.refNo}?`)) {
                                deleteAdmissionEnquiry(item.refNo);
                              }
                            }}
                            className="text-[11px] font-bold text-rose-600 hover:text-rose-800 flex items-center gap-1 cursor-pointer"
                          >
                            <Trash2 className="w-3 h-3" />
                            <span>Delete</span>
                          </button>
                        </div>
                      </div>
                    </div>
                  );
                })
              )
            ) : (
              /* Teacher Applications List */
              filteredTeachers.length === 0 ? (
                <div className="text-center py-16 bg-white rounded-2xl border border-slate-200/80 shadow-2xs space-y-3">
                  <div className="w-14 h-14 mx-auto rounded-2xl bg-indigo-50 border border-indigo-200 text-indigo-600 flex items-center justify-center">
                    <GraduationCap className="w-7 h-7" />
                  </div>
                  <h4 className="text-base font-black text-slate-800">No Teacher Applications Found</h4>
                  <p className="text-xs text-slate-500 max-w-sm mx-auto">
                    वेबसाइट के 'Join as Faculty' फ़ॉर्म से सबमिट होने वाले सभी शिक्षक आवेदन यहाँ तुरंत दिखाई देंगे।
                  </p>
                </div>
              ) : (
                filteredTeachers.map((item) => {
                  const status = item.status || 'pending';
                  const statusColors = {
                    pending: 'bg-amber-50 text-amber-700 border-amber-200',
                    contacted: 'bg-blue-50 text-blue-700 border-blue-200',
                    approved: 'bg-emerald-50 text-emerald-700 border-emerald-200',
                    rejected: 'bg-rose-50 text-rose-700 border-rose-200'
                  };

                  return (
                    <div
                      key={item.refNo}
                      onClick={() => setSelectedTeacherForView(item)}
                      className="p-4 sm:p-5 bg-white rounded-2xl border border-slate-200 shadow-2xs hover:shadow-md hover:border-indigo-400 transition-all space-y-3 cursor-pointer group"
                    >
                      {/* Top Row: Ref & Status */}
                      <div className="flex flex-wrap items-center justify-between gap-2 border-b border-slate-100 pb-2.5">
                        <div className="flex items-center gap-2">
                          <span className="px-2.5 py-0.5 rounded-lg bg-slate-100 border border-slate-200 text-slate-700 font-mono text-[11px] font-black">
                            {item.refNo}
                          </span>
                          <span className={`px-2.5 py-0.5 rounded-full border text-[10px] font-black uppercase tracking-wider ${statusColors[status] || statusColors.pending}`}>
                            {status === 'approved' ? 'HIRED / APPROVED' : status}
                          </span>
                          {item.tetStatus && (
                            <span className="px-2 py-0.5 rounded-full bg-emerald-50 border border-emerald-200 text-emerald-700 text-[10px] font-black flex items-center gap-1">
                              <Check className="w-3 h-3" />
                              {item.tetStatus}
                            </span>
                          )}
                        </div>

                        <div className="flex items-center gap-2">
                          <div className="text-[11px] text-slate-400 font-medium">
                            {item.submittedAt ? new Date(item.submittedAt).toLocaleString('en-IN', { dateStyle: 'medium', timeStyle: 'short' }) : 'Recently'}
                          </div>
                          <span className="text-xs font-bold text-indigo-600 group-hover:text-indigo-800 flex items-center gap-1 bg-indigo-50 px-2 py-0.5 rounded-lg border border-indigo-100">
                            <Eye className="w-3 h-3" />
                            <span>View Profile</span>
                          </span>
                        </div>
                      </div>

                      {/* Middle Details Grid */}
                      <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
                        <div>
                          <div className="text-[10px] uppercase font-black text-slate-400">Teacher Candidate</div>
                          <div className="text-sm font-black text-[#0c2340] group-hover:text-indigo-900">{item.teacherName}</div>
                          <div className="text-[11px] text-slate-500 font-medium">{item.gender || 'Teacher'} · {item.experience || '1-2 yrs'}</div>
                        </div>

                        <div>
                          <div className="text-[10px] uppercase font-black text-slate-400">Specialization</div>
                          <div className="text-sm font-black text-indigo-700">{item.subjectSpecialization}</div>
                          <div className="text-[11px] text-slate-500 font-medium">{item.preferredWing || 'All Wings'}</div>
                        </div>

                        <div>
                          <div className="text-[10px] uppercase font-black text-slate-400">Qualification</div>
                          <div className="text-sm font-bold text-slate-800">{item.highestDegree || 'Degree'}</div>
                          <div className="text-[11px] text-slate-500 font-medium">{item.university || 'University'} {item.passingYear ? `(${item.passingYear})` : ''}</div>
                        </div>

                        <div>
                          <div className="text-[10px] uppercase font-black text-slate-400">Contact</div>
                          <div className="text-sm font-black text-slate-800 font-mono">{item.mobile}</div>
                          <div className="text-[11px] text-slate-500 truncate" title={item.email}>{item.email}</div>
                        </div>
                      </div>

                      {/* Bottom Action Toolbar */}
                      <div
                        onClick={(e) => e.stopPropagation()}
                        className="pt-2 flex flex-wrap items-center justify-between gap-2 border-t border-slate-100"
                      >
                        <div className="flex items-center gap-2">
                          {/* Call */}
                          <a
                            href={`tel:${item.mobile}`}
                            className="px-3 py-1.5 rounded-xl bg-slate-100 hover:bg-slate-200 text-slate-800 text-xs font-bold transition-all flex items-center gap-1.5 cursor-pointer"
                          >
                            <Phone className="w-3.5 h-3.5 text-blue-600" />
                            <span>Call</span>
                          </a>

                          {/* WhatsApp */}
                          <button
                            type="button"
                            onClick={() => handleWhatsAppTeacher(item)}
                            className="px-3 py-1.5 rounded-xl bg-emerald-50 hover:bg-emerald-100 text-emerald-800 border border-emerald-200 text-xs font-bold transition-all flex items-center gap-1.5 cursor-pointer"
                          >
                            <MessageSquare className="w-3.5 h-3.5 text-emerald-600" />
                            <span>WhatsApp</span>
                          </button>

                          {/* View Profile */}
                          <button
                            type="button"
                            onClick={() => setSelectedTeacherForView(item)}
                            className="px-3 py-1.5 rounded-xl bg-indigo-50 hover:bg-indigo-100 text-indigo-800 border border-indigo-200 text-xs font-bold transition-all flex items-center gap-1.5 cursor-pointer"
                          >
                            <FileText className="w-3.5 h-3.5 text-indigo-600" />
                            <span>View Full Profile</span>
                          </button>

                          {/* 1-Click Convert to Faculty */}
                          {status !== 'approved' ? (
                            <button
                              type="button"
                              disabled={processingId === item.refNo}
                              onClick={() => handleConvertToTeacher(item)}
                              className="px-3.5 py-1.5 rounded-xl bg-indigo-600 hover:bg-indigo-700 text-white text-xs font-black transition-all flex items-center gap-1.5 shadow-2xs cursor-pointer"
                            >
                              <UserCheck className="w-3.5 h-3.5 text-white" />
                              <span>{processingId === item.refNo ? 'Adding...' : 'Approve & Add to Faculty'}</span>
                            </button>
                          ) : (
                            <span className="px-3 py-1 rounded-xl bg-emerald-100 text-emerald-800 text-xs font-black flex items-center gap-1">
                              <CheckCircle2 className="w-3.5 h-3.5" />
                              <span>Hired Staff</span>
                            </span>
                          )}
                        </div>

                        <div className="flex items-center gap-2">
                          <button
                            type="button"
                            onClick={() => updateTeacherApplicationStatus(item.refNo, status === 'contacted' ? 'pending' : 'contacted')}
                            className="text-[11px] font-bold text-blue-600 hover:underline cursor-pointer"
                          >
                            {status === 'contacted' ? 'Mark Pending' : 'Mark Contacted'}
                          </button>
                          <span className="text-slate-300">·</span>
                          <button
                            type="button"
                            onClick={() => {
                              if (confirm(`Delete application ${item.refNo}?`)) {
                                deleteTeacherApplication(item.refNo);
                              }
                            }}
                            className="text-[11px] font-bold text-rose-600 hover:text-rose-800 flex items-center gap-1 cursor-pointer"
                          >
                            <Trash2 className="w-3 h-3" />
                            <span>Delete</span>
                          </button>
                        </div>
                      </div>
                    </div>
                  );
                })
              )
            )}
          </div>
        </div>
      </div>

      {/* ─────────────────────────────────────────────────────────────────── */}
      {/* ── MODAL 1: OFFICIAL STUDENT ADMISSION APPLICATION FORM VIEW ── */}
      {/* ─────────────────────────────────────────────────────────────────── */}
      {selectedAdmissionForView && (
        <div className="fixed inset-0 z-60 flex items-center justify-center p-3 sm:p-6 bg-black/70 backdrop-blur-md animate-in fade-in duration-200">
          <div className="bg-white w-full max-w-3xl rounded-3xl border border-slate-200 shadow-2xl flex flex-col max-h-[94vh] overflow-hidden">
            
            {/* Form Top Header */}
            <div className="p-5 sm:p-6 bg-[#0c2340] text-white flex items-center justify-between gap-4 border-b border-slate-800 flex-shrink-0">
              <div className="flex items-center gap-3">
                <div className="w-12 h-12 rounded-2xl bg-amber-400 text-[#0c2340] flex items-center justify-center font-black shadow-md flex-shrink-0">
                  <BookOpen className="w-6 h-6" />
                </div>
                <div>
                  <div className="flex items-center gap-2">
                    <span className="px-2 py-0.5 rounded-md bg-amber-400/20 border border-amber-400/40 text-amber-300 text-[10px] font-mono font-black uppercase">
                      REF: {selectedAdmissionForView.refNo}
                    </span>
                    <span className={`px-2 py-0.5 rounded-full text-[10px] font-black uppercase ${
                      selectedAdmissionForView.status === 'approved' ? 'bg-emerald-500/20 text-emerald-300 border border-emerald-400/30' : 'bg-amber-500/20 text-amber-300 border border-amber-400/30'
                    }`}>
                      {selectedAdmissionForView.status === 'approved' ? 'ENROLLED / APPROVED' : (selectedAdmissionForView.status || 'PENDING')}
                    </span>
                  </div>
                  <h3 className="text-base sm:text-lg font-black tracking-tight text-white mt-1">
                    Student Admission Application Form / छात्र प्रवेश प्रपत्र
                  </h3>
                  <p className="text-xs text-slate-300">
                    {schoolName} · Session 2026-27
                  </p>
                </div>
              </div>

              <div className="flex items-center gap-2">
                <button
                  type="button"
                  onClick={() => window.print()}
                  className="w-9 h-9 rounded-xl bg-white/10 hover:bg-white/20 text-white flex items-center justify-center transition-all cursor-pointer"
                  title="Print Form"
                >
                  <Printer className="w-4 h-4" />
                </button>
                <button
                  type="button"
                  onClick={() => setSelectedAdmissionForView(null)}
                  className="w-9 h-9 rounded-xl bg-white/10 hover:bg-white/20 text-white flex items-center justify-center transition-all cursor-pointer"
                >
                  <X className="w-5 h-5" />
                </button>
              </div>
            </div>

            {/* Form Scrollable Body Styled Like Official Printed Admission Form */}
            <div className="flex-1 overflow-y-auto p-6 space-y-5 bg-[#fafbfd]">
              
              {/* Form Watermark Banner */}
              <div className="p-4 bg-gradient-to-r from-amber-50 via-white to-amber-50 rounded-2xl border border-amber-200/80 flex items-center justify-between">
                <div>
                  <div className="text-xs font-bold text-amber-900 uppercase tracking-wider">Online Registration Details</div>
                  <div className="text-sm font-black text-[#0c2340] mt-0.5">
                    Applied For: Class {selectedAdmissionForView.admissionClass} · {selectedAdmissionForView.medium || 'English'} Medium
                  </div>
                </div>
                <div className="text-right text-xs text-slate-500 font-medium">
                  <div>Submission Date:</div>
                  <div className="font-bold text-slate-800">
                    {selectedAdmissionForView.submittedAt ? new Date(selectedAdmissionForView.submittedAt).toLocaleString('en-IN', { dateStyle: 'medium', timeStyle: 'short' }) : 'Recently'}
                  </div>
                </div>
              </div>

              {/* SECTION 1: APPLICANT (STUDENT) PARTICULARS */}
              <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-2xs space-y-4">
                <div className="flex items-center gap-2 border-b border-slate-100 pb-2">
                  <User className="w-4 h-4 text-indigo-600" />
                  <h4 className="text-xs font-black text-[#0c2340] uppercase tracking-wider">
                    Section 1: Student Information (छात्र का विवरण)
                  </h4>
                </div>

                <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                  <div className="p-3 bg-slate-50 rounded-xl border border-slate-100">
                    <div className="text-[10px] font-black text-slate-400 uppercase">Student Full Name</div>
                    <div className="text-base font-black text-[#0c2340] mt-0.5">{selectedAdmissionForView.studentName}</div>
                  </div>

                  <div className="p-3 bg-slate-50 rounded-xl border border-slate-100">
                    <div className="text-[10px] font-black text-slate-400 uppercase">Seeking Admission Class</div>
                    <div className="text-base font-black text-indigo-700 mt-0.5">Class {selectedAdmissionForView.admissionClass}</div>
                  </div>

                  <div className="p-3 bg-slate-50 rounded-xl border border-slate-100">
                    <div className="text-[10px] font-black text-slate-400 uppercase">Date of Birth (DOB)</div>
                    <div className="text-sm font-bold text-slate-800 mt-0.5">{selectedAdmissionForView.dob || 'Not provided'}</div>
                  </div>

                  <div className="p-3 bg-slate-50 rounded-xl border border-slate-100">
                    <div className="text-[10px] font-black text-slate-400 uppercase">Gender</div>
                    <div className="text-sm font-bold text-slate-800 mt-0.5">{selectedAdmissionForView.gender || 'Male'}</div>
                  </div>

                  <div className="p-3 bg-slate-50 rounded-xl border border-slate-100">
                    <div className="text-[10px] font-black text-slate-400 uppercase">Category / Caste</div>
                    <div className="text-sm font-bold text-slate-800 mt-0.5">{selectedAdmissionForView.category || 'General'}</div>
                  </div>

                  <div className="p-3 bg-slate-50 rounded-xl border border-slate-100">
                    <div className="text-[10px] font-black text-slate-400 uppercase">Blood Group</div>
                    <div className="text-sm font-bold text-slate-800 mt-0.5">{selectedAdmissionForView.bloodGroup || 'Not specified'}</div>
                  </div>
                </div>
              </div>

              {/* SECTION 2: PARENTS & GUARDIAN DETAILS */}
              <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-2xs space-y-4">
                <div className="flex items-center gap-2 border-b border-slate-100 pb-2">
                  <Building className="w-4 h-4 text-emerald-600" />
                  <h4 className="text-xs font-black text-[#0c2340] uppercase tracking-wider">
                    Section 2: Parent & Guardian Details (माता-पिता का विवरण)
                  </h4>
                </div>

                <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                  <div className="p-3 bg-slate-50 rounded-xl border border-slate-100">
                    <div className="text-[10px] font-black text-slate-400 uppercase">Father's Name</div>
                    <div className="text-sm font-black text-slate-900 mt-0.5">{selectedAdmissionForView.fatherName}</div>
                  </div>

                  <div className="p-3 bg-slate-50 rounded-xl border border-slate-100">
                    <div className="text-[10px] font-black text-slate-400 uppercase">Father's Occupation</div>
                    <div className="text-sm font-bold text-slate-800 mt-0.5">{selectedAdmissionForView.fatherOccupation || 'Not provided'}</div>
                  </div>

                  <div className="p-3 bg-slate-50 rounded-xl border border-slate-100">
                    <div className="text-[10px] font-black text-slate-400 uppercase">Mother's Name</div>
                    <div className="text-sm font-bold text-slate-800 mt-0.5">{selectedAdmissionForView.motherName || 'Not provided'}</div>
                  </div>

                  <div className="p-3 bg-slate-50 rounded-xl border border-slate-100">
                    <div className="text-[10px] font-black text-slate-400 uppercase">Contact Mobile / Phone</div>
                    <div className="text-sm font-black text-slate-900 font-mono mt-0.5">{selectedAdmissionForView.mobile}</div>
                  </div>
                </div>
              </div>

              {/* SECTION 3: ADDRESS & LOGISTICS */}
              <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-2xs space-y-4">
                <div className="flex items-center gap-2 border-b border-slate-100 pb-2">
                  <MapPin className="w-4 h-4 text-rose-600" />
                  <h4 className="text-xs font-black text-[#0c2340] uppercase tracking-wider">
                    Section 3: Address & Transport Facilities
                  </h4>
                </div>

                <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                  <div className="p-3 bg-slate-50 rounded-xl border border-slate-100 sm:col-span-2">
                    <div className="text-[10px] font-black text-slate-400 uppercase">Residential / Permanent Address</div>
                    <div className="text-sm font-medium text-slate-800 mt-0.5">{selectedAdmissionForView.address || 'Local Address'}</div>
                  </div>

                  <div className="p-3 bg-slate-50 rounded-xl border border-slate-100">
                    <div className="text-[10px] font-black text-slate-400 uppercase">School Bus Transport Required</div>
                    <div className="text-sm font-black mt-0.5 flex items-center gap-1.5">
                      {selectedAdmissionForView.transportRequired === 'Yes' ? (
                        <span className="text-amber-700 flex items-center gap-1">
                          <Bus className="w-4 h-4" />
                          <span>YES (School Bus Service Required)</span>
                        </span>
                      ) : (
                        <span className="text-slate-600">NO (Self Conveyance)</span>
                      )}
                    </div>
                  </div>

                  <div className="p-3 bg-slate-50 rounded-xl border border-slate-100">
                    <div className="text-[10px] font-black text-slate-400 uppercase">Previous School & Last Class Passed</div>
                    <div className="text-sm font-bold text-slate-800 mt-0.5">
                      {selectedAdmissionForView.previousSchool || 'First Admission'} {selectedAdmissionForView.lastClassPassed ? `(Class: ${selectedAdmissionForView.lastClassPassed})` : ''}
                    </div>
                  </div>
                </div>
              </div>
            </div>

            {/* Form Footer Action Buttons */}
            <div className="p-4 sm:p-5 bg-white border-t border-slate-200 flex flex-wrap items-center justify-between gap-3 flex-shrink-0">
              <div className="flex items-center gap-2">
                <a
                  href={`tel:${selectedAdmissionForView.mobile}`}
                  className="px-3.5 py-2 rounded-xl bg-slate-100 hover:bg-slate-200 text-slate-800 text-xs font-bold transition-all flex items-center gap-1.5 cursor-pointer"
                >
                  <Phone className="w-3.5 h-3.5 text-blue-600" />
                  <span>Call Mobile</span>
                </a>

                <button
                  type="button"
                  onClick={() => handleWhatsAppAdmission(selectedAdmissionForView)}
                  className="px-3.5 py-2 rounded-xl bg-emerald-50 hover:bg-emerald-100 text-emerald-800 border border-emerald-200 text-xs font-bold transition-all flex items-center gap-1.5 cursor-pointer"
                >
                  <MessageSquare className="w-3.5 h-3.5 text-emerald-600" />
                  <span>WhatsApp</span>
                </button>
              </div>

              <div className="flex items-center gap-2">
                <button
                  type="button"
                  onClick={() => handleOpenInFullEditor(selectedAdmissionForView)}
                  className="px-4 py-2 rounded-xl bg-slate-100 hover:bg-slate-200 text-slate-800 text-xs font-black transition-all flex items-center gap-1.5 cursor-pointer"
                >
                  <FileText className="w-3.5 h-3.5 text-indigo-600" />
                  <span>Open Full Editor</span>
                </button>

                {selectedAdmissionForView.status !== 'approved' && selectedAdmissionForView.status !== 'enrolled' ? (
                  <button
                    type="button"
                    disabled={processingId === selectedAdmissionForView.refNo}
                    onClick={() => handleConvertToStudent(selectedAdmissionForView)}
                    className="px-5 py-2 rounded-xl bg-[#0c2340] hover:bg-[#153459] text-white text-xs font-black transition-all flex items-center gap-2 shadow-md cursor-pointer"
                  >
                    <UserCheck className="w-4 h-4 text-amber-400" />
                    <span>{processingId === selectedAdmissionForView.refNo ? 'Enrolling...' : 'Confirm & Enroll Student Now'}</span>
                  </button>
                ) : (
                  <span className="px-4 py-2 rounded-xl bg-emerald-100 text-emerald-800 text-xs font-black flex items-center gap-1.5">
                    <CheckCircle2 className="w-4 h-4" />
                    <span>Already Enrolled in Student List</span>
                  </span>
                )}
              </div>
            </div>

          </div>
        </div>
      )}

      {/* ─────────────────────────────────────────────────────────────────── */}
      {/* ── MODAL 2: OFFICIAL TEACHER / FACULTY APPLICATION VIEW ── */}
      {/* ─────────────────────────────────────────────────────────────────── */}
      {selectedTeacherForView && (
        <div className="fixed inset-0 z-60 flex items-center justify-center p-3 sm:p-6 bg-black/70 backdrop-blur-md animate-in fade-in duration-200">
          <div className="bg-white w-full max-w-3xl rounded-3xl border border-slate-200 shadow-2xl flex flex-col max-h-[94vh] overflow-hidden">
            
            {/* Header */}
            <div className="p-5 sm:p-6 bg-gradient-to-r from-indigo-900 to-[#0c2340] text-white flex items-center justify-between gap-4 border-b border-indigo-950 flex-shrink-0">
              <div className="flex items-center gap-3">
                <div className="w-12 h-12 rounded-2xl bg-indigo-500 text-white flex items-center justify-center font-black shadow-md flex-shrink-0">
                  <GraduationCap className="w-6 h-6" />
                </div>
                <div>
                  <div className="flex items-center gap-2">
                    <span className="px-2 py-0.5 rounded-md bg-white/20 text-white text-[10px] font-mono font-black uppercase">
                      REF: {selectedTeacherForView.refNo}
                    </span>
                    <span className="px-2 py-0.5 rounded-full bg-emerald-400/20 text-emerald-300 text-[10px] font-black uppercase">
                      {selectedTeacherForView.status === 'approved' ? 'HIRED / APPROVED' : (selectedTeacherForView.status || 'PENDING')}
                    </span>
                  </div>
                  <h3 className="text-base sm:text-lg font-black tracking-tight text-white mt-1">
                    Faculty Job Application Form / शिक्षक भर्ती आवेदन
                  </h3>
                  <p className="text-xs text-indigo-200">
                    {schoolName} · Recruitment Cell
                  </p>
                </div>
              </div>

              <button
                type="button"
                onClick={() => setSelectedTeacherForView(null)}
                className="w-9 h-9 rounded-xl bg-white/10 hover:bg-white/20 text-white flex items-center justify-center transition-all cursor-pointer"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            {/* Content */}
            <div className="flex-1 overflow-y-auto p-6 space-y-4 bg-[#fafbfd]">
              <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-2xs space-y-4">
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                  <div className="p-3 bg-slate-50 rounded-xl border border-slate-100">
                    <div className="text-[10px] font-black text-slate-400 uppercase">Teacher Candidate Name</div>
                    <div className="text-base font-black text-[#0c2340] mt-0.5">{selectedTeacherForView.teacherName}</div>
                  </div>

                  <div className="p-3 bg-slate-50 rounded-xl border border-slate-100">
                    <div className="text-[10px] font-black text-slate-400 uppercase">Subject Specialization</div>
                    <div className="text-base font-black text-indigo-700 mt-0.5">{selectedTeacherForView.subjectSpecialization}</div>
                  </div>

                  <div className="p-3 bg-slate-50 rounded-xl border border-slate-100">
                    <div className="text-[10px] font-black text-slate-400 uppercase">Preferred Wing</div>
                    <div className="text-sm font-bold text-slate-800 mt-0.5">{selectedTeacherForView.preferredWing || 'PRT / TGT'}</div>
                  </div>

                  <div className="p-3 bg-slate-50 rounded-xl border border-slate-100">
                    <div className="text-[10px] font-black text-slate-400 uppercase">Teaching Experience</div>
                    <div className="text-sm font-bold text-slate-800 mt-0.5">{selectedTeacherForView.experience || 'Fresher'}</div>
                  </div>

                  <div className="p-3 bg-slate-50 rounded-xl border border-slate-100">
                    <div className="text-[10px] font-black text-slate-400 uppercase">Highest Qualification</div>
                    <div className="text-sm font-bold text-slate-800 mt-0.5">{selectedTeacherForView.highestDegree || 'Graduate'}</div>
                  </div>

                  <div className="p-3 bg-slate-50 rounded-xl border border-slate-100">
                    <div className="text-[10px] font-black text-slate-400 uppercase">TET / Eligibility Status</div>
                    <div className="text-sm font-black text-emerald-700 mt-0.5">{selectedTeacherForView.tetStatus || 'Not Qualified'}</div>
                  </div>

                  <div className="p-3 bg-slate-50 rounded-xl border border-slate-100">
                    <div className="text-[10px] font-black text-slate-400 uppercase">Mobile Number</div>
                    <div className="text-sm font-black text-slate-800 font-mono mt-0.5">{selectedTeacherForView.mobile}</div>
                  </div>

                  <div className="p-3 bg-slate-50 rounded-xl border border-slate-100">
                    <div className="text-[10px] font-black text-slate-400 uppercase">Email Address</div>
                    <div className="text-sm font-bold text-slate-800 mt-0.5">{selectedTeacherForView.email}</div>
                  </div>

                  <div className="p-3 bg-slate-50 rounded-xl border border-slate-100 sm:col-span-2">
                    <div className="text-[10px] font-black text-slate-400 uppercase">Residential Address</div>
                    <div className="text-sm font-medium text-slate-800 mt-0.5">{selectedTeacherForView.address || 'Local'}</div>
                  </div>

                  {selectedTeacherForView.teacherBio && (
                    <div className="p-3 bg-slate-50 rounded-xl border border-slate-100 sm:col-span-2">
                      <div className="text-[10px] font-black text-slate-400 uppercase">Candidate Bio & Teaching Philosophy</div>
                      <div className="text-xs text-slate-700 mt-1 whitespace-pre-wrap">{selectedTeacherForView.teacherBio}</div>
                    </div>
                  )}
                </div>
              </div>
            </div>

            {/* Footer */}
            <div className="p-4 sm:p-5 bg-white border-t border-slate-200 flex flex-wrap items-center justify-between gap-3 flex-shrink-0">
              <div className="flex items-center gap-2">
                <a
                  href={`tel:${selectedTeacherForView.mobile}`}
                  className="px-3.5 py-2 rounded-xl bg-slate-100 hover:bg-slate-200 text-slate-800 text-xs font-bold transition-all flex items-center gap-1.5 cursor-pointer"
                >
                  <Phone className="w-3.5 h-3.5 text-blue-600" />
                  <span>Call</span>
                </a>

                <button
                  type="button"
                  onClick={() => handleWhatsAppTeacher(selectedTeacherForView)}
                  className="px-3.5 py-2 rounded-xl bg-emerald-50 hover:bg-emerald-100 text-emerald-800 border border-emerald-200 text-xs font-bold transition-all flex items-center gap-1.5 cursor-pointer"
                >
                  <MessageSquare className="w-3.5 h-3.5 text-emerald-600" />
                  <span>WhatsApp</span>
                </button>
              </div>

              <div>
                {selectedTeacherForView.status !== 'approved' ? (
                  <button
                    type="button"
                    disabled={processingId === selectedTeacherForView.refNo}
                    onClick={() => handleConvertToTeacher(selectedTeacherForView)}
                    className="px-5 py-2 rounded-xl bg-indigo-600 hover:bg-indigo-700 text-white text-xs font-black transition-all flex items-center gap-2 shadow-md cursor-pointer"
                  >
                    <UserCheck className="w-4 h-4 text-white" />
                    <span>{processingId === selectedTeacherForView.refNo ? 'Adding...' : 'Approve & Add to Faculty Staff'}</span>
                  </button>
                ) : (
                  <span className="px-4 py-2 rounded-xl bg-emerald-100 text-emerald-800 text-xs font-black flex items-center gap-1.5">
                    <CheckCircle2 className="w-4 h-4" />
                    <span>Active Faculty Member</span>
                  </span>
                )}
              </div>
            </div>

          </div>
        </div>
      )}
    </>
  );
}
