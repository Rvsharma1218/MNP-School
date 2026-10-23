'use client';

import React, { useState } from 'react';
import { useSchoolStore } from '../lib/store';
import {
  X, Search, Phone, MessageSquare, CheckCircle2, XCircle, Clock,
  Calendar, MapPin, User, GraduationCap, Briefcase, Award,
  Sparkles, Filter, ChevronDown, Trash2, ArrowRight, BookOpen,
  UserCheck, AlertCircle, Building, Check, ExternalLink, Bus
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

  if (!isOpen) return null;

  const schoolName = settings?.instituteName || 'Mission Navodaya Public School';

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
    const text = `नमस्ते ${item.fatherName ? item.fatherName + ' जी' : 'अभिभावक'},\n\n${schoolName} में ${item.studentName} के नवीन प्रवेश पूछताछ (Ref: ${item.refNo}, कक्षा: ${item.admissionClass}) के संबंध में विद्यालय प्रबंधन की ओर से आपसे संपर्क किया जा रहा है।\n\nप्रवेश संबंधी औपचारिकताएं एवं आगे की जानकारी के लिए कृपया बताएं कि हम आपसे किस समय वार्ता कर सकते हैं?\n\nधन्यवाद,\n${schoolName}\nहेल्पलाइन: ${settings?.phone || '8603481865'}`;
    window.open(`https://wa.me/${cleanMob}?text=${encodeURIComponent(text)}`, '_blank');
  };

  // ── WhatsApp Helper for Teacher ──
  const handleWhatsAppTeacher = (item) => {
    const rawMob = (item.mobile || '').replace(/\D/g, '');
    const cleanMob = rawMob.length === 10 ? '91' + rawMob : rawMob;
    const text = `Dear ${item.teacherName},\n\nGreetings from ${schoolName}!\n\nWe received your application for the faculty position (${item.subjectSpecialization || 'Teaching'}, Ref: ${item.refNo}).\n\nOur Academic Selection Committee has reviewed your profile. We would like to invite you for a personal interview and demo session at our campus.\n\nPlease let us know your availability.\n\nRegards,\nPrincipal / Academic Director\n${schoolName}`;
    window.open(`https://wa.me/${cleanMob}?text=${encodeURIComponent(text)}`, '_blank');
  };

  // ── 1-Click Convert to Enrolled Student ──
  const handleConvertToStudent = async (item) => {
    if (!confirm(`क्या आप ${item.studentName} (कक्षा: ${item.admissionClass}) को सीधे नामांकित छात्र सूची में जोड़ना चाहते हैं?`)) {
      return;
    }
    setProcessingId(item.refNo);
    try {
      const studentPayload = {
        name: item.studentName,
        className: item.admissionClass || '1st',
        section: 'A',
        fatherName: item.fatherName || '',
        motherName: item.motherName || '',
        mobile: item.mobile || '',
        gender: item.gender || 'Male',
        address: item.address || '',
        admissionDate: new Date().toISOString().split('T')[0],
        status: 'active',
        studentType: 'school',
        transportNeeded: item.transportRequired === 'Yes',
        remarks: `Website Online Enquiry Ref: ${item.refNo}`
      };

      if (addStudent) {
        await addStudent(studentPayload);
      }
      if (updateAdmissionEnquiryStatus) {
        await updateAdmissionEnquiryStatus(item.refNo, 'approved');
      }
      showToast(`✅ ${item.studentName} को सफलतापूर्वक नामांकित कर दिया गया!`, 'success');
    } catch (err) {
      showToast('नामांकन में त्रुटि: ' + err.message, 'error');
    } finally {
      setProcessingId(null);
    }
  };

  // ── 1-Click Convert to Teacher ──
  const handleConvertToTeacher = async (item) => {
    if (!confirm(`क्या आप ${item.teacherName} (${item.subjectSpecialization}) को सीधे शिक्षक सूची में जोड़ना चाहते हैं?`)) {
      return;
    }
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
      showToast(`✅ ${item.teacherName} को शिक्षक सूची में जोड़ दिया गया!`, 'success');
    } catch (err) {
      showToast('शिक्षक जोड़ने में त्रुटि: ' + err.message, 'error');
    } finally {
      setProcessingId(null);
    }
  };

  return (
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
                वेबसाइट से प्राप्त नए छात्र नामांकन एवं शिक्षक भर्ती आवेदन
              </p>
            </div>
          </div>

          <button
            onClick={onClose}
            className="w-9 h-9 rounded-xl bg-white/10 hover:bg-white/20 text-white flex items-center justify-center transition-all cursor-pointer flex-shrink-0"
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
                  rejected: 'bg-rose-50 text-rose-700 border-rose-200'
                };

                return (
                  <div
                    key={item.refNo}
                    className="p-4 sm:p-5 bg-white rounded-2xl border border-slate-200 shadow-2xs hover:shadow-md transition-all space-y-3"
                  >
                    {/* Top Row: Ref & Status */}
                    <div className="flex flex-wrap items-center justify-between gap-2 border-b border-slate-100 pb-2.5">
                      <div className="flex items-center gap-2">
                        <span className="px-2.5 py-0.5 rounded-lg bg-slate-100 border border-slate-200 text-slate-700 font-mono text-[11px] font-black">
                          {item.refNo}
                        </span>
                        <span className={`px-2.5 py-0.5 rounded-full border text-[10px] font-black uppercase tracking-wider ${statusColors[status] || statusColors.pending}`}>
                          {status}
                        </span>
                        {item.transportRequired === 'Yes' && (
                          <span className="px-2 py-0.5 rounded-full bg-amber-50 border border-amber-200 text-amber-700 text-[10px] font-black flex items-center gap-1">
                            <Bus className="w-3 h-3" />
                            Bus Needed
                          </span>
                        )}
                      </div>

                      <div className="text-[11px] text-slate-400 font-medium">
                        {item.submittedAt ? new Date(item.submittedAt).toLocaleString('en-IN', { dateStyle: 'medium', timeStyle: 'short' }) : 'Recently'}
                      </div>
                    </div>

                    {/* Middle Details Grid */}
                    <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
                      <div>
                        <div className="text-[10px] uppercase font-black text-slate-400">Student Name</div>
                        <div className="text-sm font-black text-[#0c2340]">{item.studentName}</div>
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
                    <div className="pt-2 flex flex-wrap items-center justify-between gap-2 border-t border-slate-100">
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

                        {/* 1-Click Convert to Enrolled Student */}
                        {status !== 'approved' && (
                          <button
                            type="button"
                            disabled={processingId === item.refNo}
                            onClick={() => handleConvertToStudent(item)}
                            className="px-3.5 py-1.5 rounded-xl bg-[#0c2340] hover:bg-[#153459] text-white text-xs font-black transition-all flex items-center gap-1.5 shadow-2xs cursor-pointer"
                          >
                            <UserCheck className="w-3.5 h-3.5 text-amber-400" />
                            <span>{processingId === item.refNo ? 'Enrolling...' : 'Enroll as Student'}</span>
                          </button>
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
                    className="p-4 sm:p-5 bg-white rounded-2xl border border-slate-200 shadow-2xs hover:shadow-md transition-all space-y-3"
                  >
                    {/* Top Row: Ref & Status */}
                    <div className="flex flex-wrap items-center justify-between gap-2 border-b border-slate-100 pb-2.5">
                      <div className="flex items-center gap-2">
                        <span className="px-2.5 py-0.5 rounded-lg bg-slate-100 border border-slate-200 text-slate-700 font-mono text-[11px] font-black">
                          {item.refNo}
                        </span>
                        <span className={`px-2.5 py-0.5 rounded-full border text-[10px] font-black uppercase tracking-wider ${statusColors[status] || statusColors.pending}`}>
                          {status}
                        </span>
                        {item.tetStatus && (
                          <span className="px-2 py-0.5 rounded-full bg-emerald-50 border border-emerald-200 text-emerald-700 text-[10px] font-black flex items-center gap-1">
                            <Check className="w-3 h-3" />
                            {item.tetStatus}
                          </span>
                        )}
                      </div>

                      <div className="text-[11px] text-slate-400 font-medium">
                        {item.submittedAt ? new Date(item.submittedAt).toLocaleString('en-IN', { dateStyle: 'medium', timeStyle: 'short' }) : 'Recently'}
                      </div>
                    </div>

                    {/* Middle Details Grid */}
                    <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
                      <div>
                        <div className="text-[10px] uppercase font-black text-slate-400">Teacher Candidate</div>
                        <div className="text-sm font-black text-[#0c2340]">{item.teacherName}</div>
                        <div className="text-[11px] text-slate-500 font-medium">{item.gender} · {item.dob || 'DOB N/A'}</div>
                      </div>

                      <div>
                        <div className="text-[10px] uppercase font-black text-slate-400">Subject & Wing</div>
                        <div className="text-sm font-black text-indigo-700">{item.subjectSpecialization}</div>
                        <div className="text-[11px] text-slate-500 font-medium">{item.preferredWing || 'PRT'}</div>
                      </div>

                      <div>
                        <div className="text-[10px] uppercase font-black text-slate-400">Qualification & Exp.</div>
                        <div className="text-sm font-bold text-slate-800">{item.highestDegree || 'Graduate'} ({item.passingYear})</div>
                        <div className="text-[11px] text-slate-500 font-medium">{item.experience || 'Fresher'} · {item.university || 'University'}</div>
                      </div>

                      <div>
                        <div className="text-[10px] uppercase font-black text-slate-400">Contact Info</div>
                        <div className="text-sm font-black text-slate-800 font-mono">{item.mobile}</div>
                        <div className="text-[11px] text-slate-500 truncate" title={item.email}>{item.email}</div>
                      </div>
                    </div>

                    {item.teacherBio && (
                      <div className="p-2.5 bg-slate-50 rounded-xl text-xs text-slate-700">
                        <span className="font-bold text-slate-800">Statement of Purpose: </span>
                        {item.teacherBio}
                      </div>
                    )}

                    {/* Bottom Action Toolbar */}
                    <div className="pt-2 flex flex-wrap items-center justify-between gap-2 border-t border-slate-100">
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
                          <span>Invite via WhatsApp</span>
                        </button>

                        {/* 1-Click Convert to Teacher */}
                        {status !== 'approved' && (
                          <button
                            type="button"
                            disabled={processingId === item.refNo}
                            onClick={() => handleConvertToTeacher(item)}
                            className="px-3.5 py-1.5 rounded-xl bg-[#0c2340] hover:bg-[#153459] text-white text-xs font-black transition-all flex items-center gap-1.5 shadow-2xs cursor-pointer"
                          >
                            <GraduationCap className="w-3.5 h-3.5 text-indigo-400" />
                            <span>{processingId === item.refNo ? 'Adding...' : 'Add to Faculty Directory'}</span>
                          </button>
                        )}
                      </div>

                      <div className="flex items-center gap-2">
                        <button
                          type="button"
                          onClick={() => updateTeacherApplicationStatus(item.refNo, status === 'contacted' ? 'pending' : 'contacted')}
                          className="text-[11px] font-bold text-blue-600 hover:underline cursor-pointer"
                        >
                          {status === 'contacted' ? 'Mark Pending' : 'Mark Interviewed'}
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

        {/* ── Modal Footer ── */}
        <div className="p-4 bg-slate-50 border-t border-slate-200/80 flex items-center justify-between text-xs text-slate-500">
          <div>
            Total Enquiries: <strong>{admissionEnquiries.length} Admissions</strong> · <strong>{teacherApplications.length} Teachers</strong>
          </div>
          <button
            onClick={onClose}
            className="px-5 py-2 rounded-xl bg-white border border-slate-300 text-slate-700 font-bold hover:bg-slate-100 transition-all cursor-pointer"
          >
            Close Desk
          </button>
        </div>

      </div>
    </div>
  );
}
