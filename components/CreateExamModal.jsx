'use client';

import React, { useState } from 'react';
import { X, Save, Plus, Trash2, BookOpen, Calendar, Award, CheckCircle2, Sliders, Sparkles } from 'lucide-react';
import { useSchoolStore } from '../lib/store';

const STANDARD_SUBJECT_OPTIONS = [
  'Mathematics',
  'Science',
  'Social Science',
  'English',
  'Hindi',
  'Sanskrit',
  'Urdu',
  'EVS',
  'Moral Science',
  'Computer',
  'General Knowledge',
  'Drawing / Art',
  'Physical Education',
  'Music',
  'Physics',
  'Chemistry',
  'Biology',
  'Economics',
  'Accountancy',
  'Business Studies',
  'History',
  'Geography',
  'Political Science',
  'Other'
];

export default function CreateExamModal({ isOpen, onClose, editExam = null, onSaved = null }) {
  const { settings, saveExam, showToast } = useSchoolStore();

  const [activeTab, setActiveTab] = useState('details'); // 'details' | 'subjects'

  // Exam Details State
  const [title, setTitle] = useState(editExam?.title || 'Annual Examination 2026-27');
  const [term, setTerm] = useState(editExam?.term || 'Annual');
  const [className, setClassName] = useState(editExam?.className || 'All Classes');
  const [academicYear, setAcademicYear] = useState(editExam?.academicYear || settings?.currentSession || '2026-27');
  const [examDate, setExamDate] = useState(editExam?.examDate ? editExam.examDate.split('T')[0] : new Date().toISOString().split('T')[0]);
  const [status, setStatus] = useState(editExam?.status || 'In Progress');
  const [isDetailedMode, setIsDetailedMode] = useState(editExam?.isDetailedMode || false);

  // Subjects Configuration State
  const [subjects, setSubjects] = useState(() => {
    if (editExam?.subjects && editExam.subjects.length > 0) {
      return editExam.subjects.map((s, idx) => ({
        id: `sub_${idx}_${Date.now()}`,
        subjectName: s.subjectName || 'Subject',
        isCompulsory: s.isCompulsory !== false,
        totalMarks: Number(s.totalMarks) || 100,
        passingMarks: Number(s.passingMarks) || 33,
        theoryMax: Number(s.theoryMax) || 100,
        theoryPassing: Number(s.theoryPassing) || 33,
        practicalMax: Number(s.practicalMax) || 0,
        practicalPassing: Number(s.practicalPassing) || 0,
        internalMax: Number(s.internalMax) || 0,
        internalPassing: Number(s.internalPassing) || 0
      }));
    }
    // Default 5 standard subjects
    return [
      { id: 'sub_1', subjectName: 'Mathematics', isCompulsory: true, totalMarks: 100, passingMarks: 33, theoryMax: 100, theoryPassing: 33, practicalMax: 0, practicalPassing: 0, internalMax: 0, internalPassing: 0 },
      { id: 'sub_2', subjectName: 'Science', isCompulsory: true, totalMarks: 100, passingMarks: 33, theoryMax: 80, theoryPassing: 26, practicalMax: 20, practicalPassing: 7, internalMax: 0, internalPassing: 0 },
      { id: 'sub_3', subjectName: 'Social Science', isCompulsory: true, totalMarks: 100, passingMarks: 33, theoryMax: 100, theoryPassing: 33, practicalMax: 0, practicalPassing: 0, internalMax: 0, internalPassing: 0 },
      { id: 'sub_4', subjectName: 'English', isCompulsory: true, totalMarks: 100, passingMarks: 33, theoryMax: 100, theoryPassing: 33, practicalMax: 0, practicalPassing: 0, internalMax: 0, internalPassing: 0 },
      { id: 'sub_5', subjectName: 'Hindi', isCompulsory: true, totalMarks: 100, passingMarks: 33, theoryMax: 100, theoryPassing: 33, practicalMax: 0, practicalPassing: 0, internalMax: 0, internalPassing: 0 },
    ];
  });

  if (!isOpen) return null;

  const availableClasses = ['All Classes', ...(settings?.schoolClasses || ['Nursery', 'LKG', 'UKG', '1st', '2nd', '3rd', '4th', '5th', '6th', '7th', '8th', '9th', '10th', '11th-Sci', '12th-Sci'])];

  const handleAddSubject = () => {
    const nextIdx = subjects.length + 1;
    setSubjects(prev => [
      ...prev,
      {
        id: `sub_${Date.now()}_${nextIdx}`,
        subjectName: STANDARD_SUBJECT_OPTIONS[nextIdx % STANDARD_SUBJECT_OPTIONS.length] || 'New Subject',
        isCompulsory: true,
        totalMarks: 100,
        passingMarks: 33,
        theoryMax: 100,
        theoryPassing: 33,
        practicalMax: 0,
        practicalPassing: 0,
        internalMax: 0,
        internalPassing: 0
      }
    ]);
  };

  const handleRemoveSubject = (id) => {
    if (subjects.length <= 1) {
      showToast('An exam must have at least one subject.', 'error');
      return;
    }
    setSubjects(prev => prev.filter(s => s.id !== id));
  };

  const handleUpdateSubject = (id, key, value) => {
    setSubjects(prev => prev.map(s => {
      if (s.id !== id) return s;
      const updated = { ...s, [key]: value };
      if (isDetailedMode && (key === 'theoryMax' || key === 'practicalMax' || key === 'internalMax')) {
        const t = Number(key === 'theoryMax' ? value : updated.theoryMax) || 0;
        const p = Number(key === 'practicalMax' ? value : updated.practicalMax) || 0;
        const i = Number(key === 'internalMax' ? value : updated.internalMax) || 0;
        updated.totalMarks = t + p + i;
      }
      return updated;
    }));
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!title.trim()) {
      showToast('Please enter an exam title', 'error');
      return;
    }
    if (subjects.length === 0) {
      showToast('Please configure at least one subject', 'error');
      return;
    }

    const payload = {
      id: editExam?.id || `exam_${Date.now()}`,
      title: title.trim(),
      term,
      className,
      academicYear,
      examDate: new Date(examDate).toISOString(),
      status,
      isDetailedMode,
      subjects: subjects.map(s => ({
        subjectName: s.subjectName.trim() || 'General',
        isCompulsory: s.isCompulsory !== false,
        totalMarks: Number(s.totalMarks) || 100,
        passingMarks: Number(s.passingMarks) || 33,
        theoryMax: Number(s.theoryMax) || 100,
        theoryPassing: Number(s.theoryPassing) || 33,
        practicalMax: Number(s.practicalMax) || 0,
        practicalPassing: Number(s.practicalPassing) || 0,
        internalMax: Number(s.internalMax) || 0,
        internalPassing: Number(s.internalPassing) || 0
      }))
    };

    try {
      await saveExam(payload);
      if (onSaved) onSaved(payload);
      onClose();
    } catch (err) {
      // Toast handled by store
    }
  };

  const PRESET_TITLES = [
    'Annual Examination 2026-27',
    'Half Yearly Examination',
    'Unit Test 1',
    'Quarterly Examination',
    'Pre-Board Examination'
  ];

  return (
    <div
      onClick={(e) => {
        if (e.target === e.currentTarget) onClose();
      }}
      className="fixed inset-0 z-50 overflow-y-auto bg-black/75 backdrop-blur-xs p-2 sm:p-4 md:p-6 flex justify-center items-center"
    >
      <div className="bg-white rounded-2xl w-full max-w-3xl shadow-2xl overflow-hidden flex flex-col max-h-[92vh] border border-slate-200 animate-in fade-in zoom-in-95 duration-200">
        
        {/* Header */}
        <div className="px-4 sm:px-6 py-4 bg-gradient-to-r from-[#1f108e] via-[#160c6d] to-[#0b1c30] text-white flex items-center justify-between shrink-0 shadow-sm">
          <div className="flex items-center gap-3 min-w-0">
            <div className="w-10 h-10 rounded-xl bg-white/10 flex items-center justify-center shrink-0 border border-white/20 shadow-inner">
              <Award className="w-5 h-5 text-amber-300" />
            </div>
            <div className="min-w-0">
              <h3 className="text-base sm:text-lg font-black tracking-tight truncate">
                {editExam ? 'Edit Examination' : 'Create New Examination'}
              </h3>
              <p className="text-[11px] text-amber-200/90 font-medium truncate">
                Configure exam term, target class & subjects marking breakdown
              </p>
            </div>
          </div>
          <button
            onClick={onClose}
            className="w-8 h-8 rounded-lg bg-white/10 hover:bg-white/20 text-white flex items-center justify-center transition-all cursor-pointer shrink-0"
          >
            <X className="w-4 h-4" />
          </button>
        </div>

        {/* Tab Controls */}
        <div className="flex border-b border-slate-200 bg-slate-50 px-4 sm:px-6 gap-2 pt-2 shrink-0">
          <button
            type="button"
            onClick={() => setActiveTab('details')}
            className={`px-4 py-2.5 text-xs font-black rounded-t-xl transition-all flex items-center gap-2 border-b-2 cursor-pointer ${
              activeTab === 'details'
                ? 'bg-white border-[#1f108e] text-[#1f108e] shadow-xs'
                : 'border-transparent text-slate-500 hover:text-slate-800'
            }`}
          >
            <BookOpen className="w-3.5 h-3.5" />
            <span>1. Exam Details</span>
          </button>
          <button
            type="button"
            onClick={() => setActiveTab('subjects')}
            className={`px-4 py-2.5 text-xs font-black rounded-t-xl transition-all flex items-center gap-2 border-b-2 cursor-pointer ${
              activeTab === 'subjects'
                ? 'bg-white border-[#1f108e] text-[#1f108e] shadow-xs'
                : 'border-transparent text-slate-500 hover:text-slate-800'
            }`}
          >
            <Sliders className="w-3.5 h-3.5" />
            <span>2. Subjects & Marks ({subjects.length})</span>
          </button>
        </div>

        {/* Form Body */}
        <form onSubmit={handleSubmit} className="flex-1 overflow-y-auto p-4 sm:p-6 space-y-5">
          
          {activeTab === 'details' ? (
            <div className="space-y-4">
              {/* Exam Title with Presets */}
              <div>
                <label className="block text-xs font-black text-slate-700 uppercase tracking-wider mb-1.5">
                  Exam Title <span className="text-rose-500">*</span>
                </label>
                <input
                  type="text"
                  value={title}
                  onChange={(e) => setTitle(e.target.value)}
                  placeholder="e.g. Annual Examination 2026-27"
                  className="w-full px-3.5 py-2.5 text-sm font-bold bg-white border border-slate-300 rounded-xl focus:ring-2 focus:ring-[#1f108e] focus:border-[#1f108e] outline-none shadow-xs text-slate-900"
                  required
                />
                <div className="flex flex-wrap gap-1.5 mt-2">
                  <span className="text-[10px] text-slate-400 font-bold uppercase py-0.5">Quick Presets:</span>
                  {PRESET_TITLES.map((pt) => (
                    <button
                      key={pt}
                      type="button"
                      onClick={() => setTitle(pt)}
                      className="text-[10.5px] font-semibold px-2 py-0.5 rounded-md bg-slate-100 hover:bg-indigo-50 text-slate-700 hover:text-[#1f108e] border border-slate-200/80 transition-all cursor-pointer"
                    >
                      {pt}
                    </button>
                  ))}
                </div>
              </div>

              {/* Grid 1: Term, Class, Academic Year */}
              <div className="grid grid-cols-1 sm:grid-cols-3 gap-3.5">
                <div>
                  <label className="block text-xs font-black text-slate-700 uppercase tracking-wider mb-1.5">
                    Term / Category
                  </label>
                  <select
                    value={term}
                    onChange={(e) => setTerm(e.target.value)}
                    className="w-full px-3 py-2 text-xs font-bold bg-white border border-slate-300 rounded-xl focus:ring-2 focus:ring-[#1f108e] outline-none shadow-xs text-slate-800"
                  >
                    <option value="Annual">Annual Exam</option>
                    <option value="Half Yearly">Half Yearly</option>
                    <option value="Quarterly">Quarterly</option>
                    <option value="Unit Test">Unit Test</option>
                    <option value="Pre-Board">Pre-Board</option>
                    <option value="Term 1">Term 1</option>
                    <option value="Term 2">Term 2</option>
                    <option value="Monthly Test">Monthly Test</option>
                  </select>
                </div>

                <div>
                  <label className="block text-xs font-black text-slate-700 uppercase tracking-wider mb-1.5">
                    Target Class
                  </label>
                  <select
                    value={className}
                    onChange={(e) => setClassName(e.target.value)}
                    className="w-full px-3 py-2 text-xs font-bold bg-white border border-slate-300 rounded-xl focus:ring-2 focus:ring-[#1f108e] outline-none shadow-xs text-slate-800"
                  >
                    {availableClasses.map((c) => (
                      <option key={c} value={c}>{c}</option>
                    ))}
                  </select>
                </div>

                <div>
                  <label className="block text-xs font-black text-slate-700 uppercase tracking-wider mb-1.5">
                    Academic Session
                  </label>
                  <select
                    value={academicYear}
                    onChange={(e) => setAcademicYear(e.target.value)}
                    className="w-full px-3 py-2 text-xs font-bold bg-white border border-slate-300 rounded-xl focus:ring-2 focus:ring-[#1f108e] outline-none shadow-xs text-slate-800"
                  >
                    <option value="2024-25">2024-25</option>
                    <option value="2025-26">2025-26</option>
                    <option value="2026-27">2026-27</option>
                    <option value="2027-28">2027-28</option>
                  </select>
                </div>
              </div>

              {/* Grid 2: Exam Date & Status */}
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3.5">
                <div>
                  <label className="block text-xs font-black text-slate-700 uppercase tracking-wider mb-1.5">
                    Examination Date
                  </label>
                  <input
                    type="date"
                    value={examDate}
                    onChange={(e) => setExamDate(e.target.value)}
                    className="w-full px-3 py-2 text-xs font-bold bg-white border border-slate-300 rounded-xl focus:ring-2 focus:ring-[#1f108e] outline-none shadow-xs text-slate-800"
                  />
                </div>

                <div>
                  <label className="block text-xs font-black text-slate-700 uppercase tracking-wider mb-1.5">
                    Publication Status
                  </label>
                  <select
                    value={status}
                    onChange={(e) => setStatus(e.target.value)}
                    className="w-full px-3 py-2 text-xs font-bold bg-white border border-slate-300 rounded-xl focus:ring-2 focus:ring-[#1f108e] outline-none shadow-xs text-slate-800"
                  >
                    <option value="In Progress">In Progress (Marks Being Entered)</option>
                    <option value="Published">Published (Live on Portal & Marksheets)</option>
                    <option value="Draft">Draft (Hidden)</option>
                  </select>
                </div>
              </div>

              {/* Mode Switch Card */}
              <div className="p-4 rounded-xl border border-indigo-100 bg-gradient-to-r from-indigo-50/60 to-purple-50/60 flex items-center justify-between gap-4">
                <div>
                  <div className="flex items-center gap-2">
                    <span className="text-xs font-black text-[#1f108e]">Detailed Marks Breakdown</span>
                    <span className="px-2 py-0.5 text-[9px] font-bold rounded-full bg-indigo-100 text-indigo-700">
                      {isDetailedMode ? 'Theory + Practical + Internal' : 'Direct Total Only'}
                    </span>
                  </div>
                  <p className="text-[11px] text-slate-600 mt-0.5">
                    Enable if your school records Theory, Practical, and Internal assessments separately.
                  </p>
                </div>
                <label className="relative inline-flex items-center cursor-pointer shrink-0">
                  <input
                    type="checkbox"
                    checked={isDetailedMode}
                    onChange={(e) => setIsDetailedMode(e.target.checked)}
                    className="sr-only peer"
                  />
                  <div className="w-11 h-6 bg-slate-300 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-slate-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-[#1f108e]"></div>
                </label>
              </div>

              <div className="pt-2 flex justify-end">
                <button
                  type="button"
                  onClick={() => setActiveTab('subjects')}
                  className="px-4 py-2 bg-[#1f108e] text-white text-xs font-bold rounded-xl shadow-xs hover:bg-[#160c6d] transition-all cursor-pointer flex items-center gap-2"
                >
                  <span>Configure Subjects & Marks</span>
                  <span>→</span>
                </button>
              </div>
            </div>
          ) : (
            <div className="space-y-4">
              <div className="flex items-center justify-between gap-3">
                <div>
                  <h4 className="text-xs font-black text-slate-800 uppercase tracking-wider">
                    Exam Subjects & Max Marks
                  </h4>
                  <p className="text-[11px] text-slate-500">
                    Set up subjects, maximum marks, and passing criteria for this exam.
                  </p>
                </div>
                <button
                  type="button"
                  onClick={handleAddSubject}
                  className="px-3 py-1.5 bg-emerald-600 hover:bg-emerald-700 text-white text-xs font-bold rounded-xl shadow-xs transition-all flex items-center gap-1.5 cursor-pointer"
                >
                  <Plus className="w-3.5 h-3.5" />
                  <span>Add Subject</span>
                </button>
              </div>

              {/* Subject Rows */}
              <div className="space-y-3">
                {subjects.map((sub, i) => (
                  <div
                    key={sub.id}
                    className="p-3.5 rounded-xl border border-slate-200 bg-slate-50/60 hover:bg-slate-50 transition-all space-y-3"
                  >
                    <div className="flex items-center justify-between gap-2">
                      <div className="flex items-center gap-2 flex-1 min-w-0">
                        <span className="w-5 h-5 rounded-full bg-slate-200 text-slate-700 text-[10px] font-black flex items-center justify-center shrink-0">
                          {i + 1}
                        </span>
                        <div className="flex-1 min-w-0 flex flex-col sm:flex-row sm:items-center gap-2">
                          <select
                            value={STANDARD_SUBJECT_OPTIONS.includes(sub.subjectName) ? sub.subjectName : 'Other'}
                            onChange={(e) => {
                              const val = e.target.value;
                              handleUpdateSubject(sub.id, 'subjectName', val === 'Other' ? '' : val);
                            }}
                            className="px-2.5 py-1.5 text-xs font-bold bg-white border border-slate-300 rounded-lg outline-none text-slate-800 shrink-0"
                          >
                            {STANDARD_SUBJECT_OPTIONS.map((opt) => (
                              <option key={opt} value={opt}>{opt}</option>
                            ))}
                          </select>
                          {(!STANDARD_SUBJECT_OPTIONS.includes(sub.subjectName) || sub.subjectName === 'Other' || sub.subjectName === '') && (
                            <input
                              type="text"
                              value={sub.subjectName === 'Other' ? '' : sub.subjectName}
                              onChange={(e) => handleUpdateSubject(sub.id, 'subjectName', e.target.value)}
                              placeholder="Enter Custom Subject Name"
                              className="px-2.5 py-1.5 text-xs font-bold bg-white border border-slate-300 rounded-lg outline-none flex-1 min-w-[140px] text-slate-900"
                            />
                          )}
                        </div>
                      </div>

                      <div className="flex items-center gap-2 shrink-0">
                        <label className="flex items-center gap-1.5 text-[11px] font-bold text-slate-600 cursor-pointer">
                          <input
                            type="checkbox"
                            checked={sub.isCompulsory}
                            onChange={(e) => handleUpdateSubject(sub.id, 'isCompulsory', e.target.checked)}
                            className="rounded text-[#1f108e] focus:ring-[#1f108e]"
                          />
                          <span className="hidden sm:inline">Compulsory</span>
                        </label>
                        <button
                          type="button"
                          onClick={() => handleRemoveSubject(sub.id)}
                          className="w-7 h-7 rounded-lg text-slate-400 hover:text-rose-600 hover:bg-rose-50 flex items-center justify-center transition-all cursor-pointer"
                          title="Delete Subject"
                        >
                          <Trash2 className="w-3.5 h-3.5" />
                        </button>
                      </div>
                    </div>

                    {/* Marks Inputs */}
                    {!isDetailedMode ? (
                      <div className="grid grid-cols-2 sm:grid-cols-4 gap-2.5 pt-1">
                        <div>
                          <label className="block text-[10px] font-bold text-slate-500 uppercase mb-0.5">
                            Total / Max
                          </label>
                          <input
                            type="number"
                            value={sub.totalMarks}
                            onChange={(e) => handleUpdateSubject(sub.id, 'totalMarks', Number(e.target.value))}
                            className="w-full px-2.5 py-1.5 text-xs font-bold bg-white border border-slate-300 rounded-lg outline-none text-slate-800"
                            min="1"
                          />
                        </div>
                        <div>
                          <label className="block text-[10px] font-bold text-slate-500 uppercase mb-0.5">
                            Passing Marks
                          </label>
                          <input
                            type="number"
                            value={sub.passingMarks}
                            onChange={(e) => handleUpdateSubject(sub.id, 'passingMarks', Number(e.target.value))}
                            className="w-full px-2.5 py-1.5 text-xs font-bold bg-white border border-slate-300 rounded-lg outline-none text-slate-800"
                            min="0"
                          />
                        </div>
                      </div>
                    ) : (
                      <div className="grid grid-cols-2 sm:grid-cols-4 gap-2 pt-1 border-t border-slate-200/80">
                        <div>
                          <label className="block text-[9.5px] font-bold text-slate-500 uppercase mb-0.5">
                            Theory Max / Pass
                          </label>
                          <div className="flex gap-1">
                            <input
                              type="number"
                              value={sub.theoryMax}
                              onChange={(e) => handleUpdateSubject(sub.id, 'theoryMax', Number(e.target.value))}
                              placeholder="Max"
                              className="w-1/2 px-2 py-1 text-xs font-bold bg-white border border-slate-300 rounded-lg outline-none text-slate-800"
                            />
                            <input
                              type="number"
                              value={sub.theoryPassing}
                              onChange={(e) => handleUpdateSubject(sub.id, 'theoryPassing', Number(e.target.value))}
                              placeholder="Pass"
                              className="w-1/2 px-2 py-1 text-xs font-bold bg-white border border-slate-300 rounded-lg outline-none text-slate-800"
                            />
                          </div>
                        </div>

                        <div>
                          <label className="block text-[9.5px] font-bold text-slate-500 uppercase mb-0.5">
                            Practical Max / Pass
                          </label>
                          <div className="flex gap-1">
                            <input
                              type="number"
                              value={sub.practicalMax}
                              onChange={(e) => handleUpdateSubject(sub.id, 'practicalMax', Number(e.target.value))}
                              placeholder="Max"
                              className="w-1/2 px-2 py-1 text-xs font-bold bg-white border border-slate-300 rounded-lg outline-none text-slate-800"
                            />
                            <input
                              type="number"
                              value={sub.practicalPassing}
                              onChange={(e) => handleUpdateSubject(sub.id, 'practicalPassing', Number(e.target.value))}
                              placeholder="Pass"
                              className="w-1/2 px-2 py-1 text-xs font-bold bg-white border border-slate-300 rounded-lg outline-none text-slate-800"
                            />
                          </div>
                        </div>

                        <div>
                          <label className="block text-[9.5px] font-bold text-slate-500 uppercase mb-0.5">
                            Internal Max / Pass
                          </label>
                          <div className="flex gap-1">
                            <input
                              type="number"
                              value={sub.internalMax}
                              onChange={(e) => handleUpdateSubject(sub.id, 'internalMax', Number(e.target.value))}
                              placeholder="Max"
                              className="w-1/2 px-2 py-1 text-xs font-bold bg-white border border-slate-300 rounded-lg outline-none text-slate-800"
                            />
                            <input
                              type="number"
                              value={sub.internalPassing}
                              onChange={(e) => handleUpdateSubject(sub.id, 'internalPassing', Number(e.target.value))}
                              placeholder="Pass"
                              className="w-1/2 px-2 py-1 text-xs font-bold bg-white border border-slate-300 rounded-lg outline-none text-slate-800"
                            />
                          </div>
                        </div>

                        <div>
                          <label className="block text-[9.5px] font-bold text-slate-500 uppercase mb-0.5">
                            Combined Total
                          </label>
                          <div className="px-2.5 py-1 text-xs font-black bg-indigo-50 border border-indigo-200 rounded-lg text-[#1f108e]">
                            Max: {sub.totalMarks}
                          </div>
                        </div>
                      </div>
                    )}
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* Footer Actions */}
          <div className="border-t border-slate-200 pt-4 flex flex-col sm:flex-row items-center justify-between gap-3 shrink-0">
            <span className="text-xs text-slate-500 font-medium order-2 sm:order-1">
              Class: <strong className="text-slate-800">{className}</strong> • Subjects: <strong className="text-slate-800">{subjects.length}</strong>
            </span>
            <div className="flex items-center gap-2.5 w-full sm:w-auto order-1 sm:order-2">
              <button
                type="button"
                onClick={onClose}
                className="flex-1 sm:flex-initial px-4 py-2 border border-slate-300 text-slate-700 hover:bg-slate-100 text-xs font-bold rounded-xl transition-all cursor-pointer"
              >
                Cancel
              </button>
              <button
                type="submit"
                className="flex-1 sm:flex-initial px-5 py-2 bg-gradient-to-r from-[#1f108e] to-[#0051d5] hover:opacity-95 text-white text-xs font-bold rounded-xl shadow-md transition-all flex items-center justify-center gap-2 cursor-pointer"
              >
                <Save className="w-3.5 h-3.5" />
                <span>{editExam ? 'Update Examination' : 'Save & Publish Exam'}</span>
              </button>
            </div>
          </div>
        </form>
      </div>
    </div>
  );
}
