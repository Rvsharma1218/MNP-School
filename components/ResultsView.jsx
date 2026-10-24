'use client';

import React, { useState, useEffect } from 'react';
import { useSchoolStore } from '../lib/store';
import {
  Award, Plus, Search, Printer, Trash2, Edit,
  GraduationCap, Calendar, Percent, CheckCircle2,
  FileSpreadsheet, X, Save, Share2, ClipboardList, TrendingUp, Sparkles, ChevronRight, BarChart, Download, FileText,
  Users, Check, MessageCircle, AlertCircle
} from 'lucide-react';
import { exportExamResultsToExcel, exportExamResultsPDF, exportSingleResultPDF, openWhatsAppResultShare } from '../lib/exportUtils';


const STANDARD_RESULT_SUBJECTS = [
  'Mathematics',
  'Science',
  'Social Science',
  'English',
  'Hindi',
  'Computer',
  'Sanskrit',
  'General Knowledge',
  'Drawing / Art',
  'Physics',
  'Chemistry',
  'Biology',
  'Economics',
  'Accountancy',
  'Other'
];

export default function ResultsView() {
  const {
    students,
    results,
    settings,
    currentUser,
    saveResult,
    deleteResult,
    setPrintResultData,
    showToast
  } = useSchoolStore();

  const isPrincipal = currentUser?.role === 'principal';
  const assignedClass = currentUser?.assignedClass || '10th';

  const [activeTab, setActiveTab] = useState('saved'); // 'saved' | 'entry'
  const [searchQuery, setSearchQuery] = useState('');
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [editingResult, setEditingResult] = useState(null);

  // New/Edit Result Form State (for single modal entry)
  const [selectedStudentId, setSelectedStudentId] = useState('');
  const [modalStudentType, setModalStudentType] = useState('all'); // 'all' | 'school' | 'computer'
  const [modalClassFilter, setModalClassFilter] = useState('all'); // 'all' | class/course
  const [modalStudentSearch, setModalStudentSearch] = useState('');
  const [examName, setExamName] = useState('Term Examination');
  const [passingMarks, setPassingMarks] = useState(33);
  const [resultStatus, setResultStatus] = useState('AUTO'); // 'AUTO' | 'PASS' | 'FAIL' | 'PROMOTED'
  const [subjects, setSubjects] = useState([
    { subjectName: 'Mathematics', marks: '', totalMarks: 100 },
    { subjectName: 'Science', marks: '', totalMarks: 100 },
    { subjectName: 'English', marks: '', totalMarks: 100 }
  ]);

  // Bulk Mark Entry Form State
  const [bulkClass, setBulkClass] = useState(isPrincipal ? (settings.schoolClasses?.[0] || '10th') : assignedClass);
  const [bulkExam, setBulkExam] = useState('Term Examination');
  const [isDetailedBreakdownMode, setIsDetailedBreakdownMode] = useState(false);
  const [savedStudentIds, setSavedStudentIds] = useState(new Set());
  
  // Multi-subject list for Bulk Mark Entry Desk
  const [bulkSubjects, setBulkSubjects] = useState([
    { id: 'sub_1', name: 'Mathematics', totalMarks: 100 },
    { id: 'sub_2', name: 'Science', totalMarks: 100 },
    { id: 'sub_3', name: 'English', totalMarks: 100 }
  ]);
  const [activeBulkSubjectId, setActiveBulkSubjectId] = useState('sub_1');
  
  // markEntries: { [subjectId]: { [studentId]: { marks: '', theory: '', practical: '', internal: '' } } }
  const [markEntries, setMarkEntries] = useState({});

  // Reset to teacher assigned class on mount
  useEffect(() => {
    if (!isPrincipal && assignedClass) {
      setBulkClass(assignedClass);
    }
  }, [assignedClass, isPrincipal]);

  // Available classes for modal filter
  const availableModalClasses = React.useMemo(() => {
    const set = new Set();
    if (settings?.schoolClasses && Array.isArray(settings.schoolClasses)) {
      settings.schoolClasses.forEach(c => c && set.add(String(c).trim()));
    }
    if (settings?.computerCourses && Array.isArray(settings.computerCourses)) {
      settings.computerCourses.forEach(c => c && set.add(String(c).trim()));
    }
    students.forEach(s => {
      const c = s.studentType === 'school' ? s.className : s.course;
      if (c && String(c).trim()) set.add(String(c).trim());
    });
    return Array.from(set).filter(Boolean).sort();
  }, [students, settings]);

  // Filtered students for single result modal
  const modalFilteredStudents = React.useMemo(() => {
    return students.filter(s => {
      if (modalStudentType !== 'all' && s.studentType !== modalStudentType) return false;
      if (modalClassFilter !== 'all') {
        const c = s.studentType === 'school' ? s.className : s.course;
        if (String(c || '').trim().toLowerCase() !== modalClassFilter.toLowerCase()) return false;
      }
      if (modalStudentSearch.trim()) {
        const q = modalStudentSearch.toLowerCase().trim();
        const matchName = s.name?.toLowerCase().includes(q);
        const matchId = s.studentId?.toLowerCase().includes(q);
        const matchAdm = (s.admissionNumber || s.admissionNo)?.toLowerCase().includes(q);
        const matchRoll = s.rollNumber?.toLowerCase().includes(q);
        if (!matchName && !matchId && !matchAdm && !matchRoll) return false;
      }
      return true;
    });
  }, [students, modalStudentType, modalClassFilter, modalStudentSearch]);

  const selectedStudentObj = students.find(s => s.id === selectedStudentId);

  // Handle single modal entry
  const handleOpenAdd = () => {
    setEditingResult(null);
    setModalStudentType('all');
    setModalClassFilter('all');
    setModalStudentSearch('');
    setSelectedStudentId('');
    setExamName('Term Examination');
    setPassingMarks(33);
    setResultStatus('AUTO');
    setSubjects([
      { subjectName: 'Mathematics', marks: '', totalMarks: 100 },
      { subjectName: 'Science', marks: '', totalMarks: 100 },
      { subjectName: 'English', marks: '', totalMarks: 100 }
    ]);
    setIsModalOpen(true);
  };

  const handleOpenEdit = (res) => {
    setEditingResult(res);
    setSelectedStudentId(res.studentId);
    const targetStudent = students.find(s => s.id === res.studentId);
    if (targetStudent) {
      if (targetStudent.studentType) setModalStudentType(targetStudent.studentType);
      const c = targetStudent.studentType === 'school' ? targetStudent.className : targetStudent.course;
      if (c) setModalClassFilter(c);
    }
    setExamName(res.examName || 'Term Examination');
    setPassingMarks(res.passingMarks || 33);
    setResultStatus(res.status || 'AUTO');
    setSubjects(res.subjects && res.subjects.length > 0 ? [...res.subjects] : [
      { subjectName: 'Mathematics', marks: '', totalMarks: 100 },
      { subjectName: 'Science', marks: '', totalMarks: 100 },
      { subjectName: 'English', marks: '', totalMarks: 100 }
    ]);
    setIsModalOpen(true);
  };

  const handleAddSubjectRow = () => {
    setSubjects(prev => [...prev, { subjectName: '', marks: '', totalMarks: 100 }]);
  };

  const handleRemoveSubjectRow = (idx) => {
    setSubjects(prev => prev.filter((_, i) => i !== idx));
  };

  const handleSubjectChange = (idx, field, val) => {
    setSubjects(prev => {
      const copy = [...prev];
      copy[idx] = { ...copy[idx], [field]: val };
      return copy;
    });
  };

  const handleSubmit = (e) => {
    e.preventDefault();
    if (!selectedStudentId) return;

    const payload = {
      id: editingResult?.id,
      studentId: selectedStudentId,
      examName,
      passingMarks: Number(passingMarks) || 33,
      status: resultStatus,
      subjects: subjects.map(s => ({
        subjectName: s.subjectName || 'Subject',
        marks: Number(s.marks) || 0,
        totalMarks: Number(s.totalMarks) || 100,
        passingMarks: Number(s.passingMarks || passingMarks || 33),
        theoryMarks: s.theoryMarks != null ? Number(s.theoryMarks) : 0,
        practicalMarks: s.practicalMarks != null ? Number(s.practicalMarks) : 0,
        internalMarks: s.internalMarks != null ? Number(s.internalMarks) : 0,
      }))
    };

    saveResult(payload);
    showToast('Result saved successfully!', 'success');
    setIsModalOpen(false);
  };

  // WhatsApp Share handler
  const handleWhatsAppShare = async (res, stu) => {
    try {
      showToast(`Preparing WhatsApp Marksheet & PDF for ${stu?.name || 'student'}...`, 'info');
      await openWhatsAppResultShare(res, stu, settings);
    } catch (e) {
      console.error(e);
      showToast('Error sharing result on WhatsApp', 'error');
    }
  };

  // Filter saved results
  const filteredResults = results.filter(r => {
    const student = students.find(s => s.id === r.studentId);
    if (!searchQuery.trim()) return true;
    const q = searchQuery.toLowerCase();
    return (
      r.examName?.toLowerCase().includes(q) ||
      student?.name?.toLowerCase().includes(q) ||
      student?.studentId?.toLowerCase().includes(q)
    );
  });

  // Filter students for bulk mark entry based on selected class
  const classStudents = students.filter(s => {
    if (s.studentType === 'school') return s.className === bulkClass;
    return s.course === bulkClass;
  });

  // Dynamic pass rate and grade distribution across all real exam results
  let totalResultScores = 0;
  let passedCount = 0;
  const gradeCounts = { 'A+': 0, 'A': 0, 'B': 0, 'C': 0, 'D': 0, 'F': 0 };

  results.forEach(res => {
    if (res.subjects && res.subjects.length > 0) {
      const totalMarksObt = res.subjects.reduce((a, s) => a + (Number(s.marks) || 0), 0);
      const totalMax = res.subjects.reduce((a, s) => a + (Number(s.totalMarks) || 100), 0);
      const pct = totalMax > 0 ? Math.round((totalMarksObt / totalMax) * 100) : 0;
      totalResultScores++;
      const passCriteria = Number(res.passingMarks || 33);
      const failedSubs = res.subjects?.filter(sub => {
        const sMax = Number(sub.totalMarks) || 100;
        const sObt = Number(sub.marks) || 0;
        const minP = sub.passingMarks != null ? Number(sub.passingMarks) : Math.round(sMax * (passCriteria / 100));
        return sObt < minP;
      }) || [];

      if (res.status === 'PROMOTED' || (res.status !== 'FAIL' && failedSubs.length === 0 && pct >= passCriteria)) {
        passedCount++;
      }

      if (pct >= 90) gradeCounts['A+']++;
      else if (pct >= 75) gradeCounts['A']++;
      else if (pct >= 60) gradeCounts['B']++;
      else if (pct >= 45) gradeCounts['C']++;
      else if (pct >= 33) gradeCounts['D']++;
      else gradeCounts['F']++;
    }
  });

  const overallPassRate = totalResultScores > 0 ? Math.round((passedCount / totalResultScores) * 100) : 0;

  // Initialize bulk mark entries when class/exam/subjects change
  useEffect(() => {
    const initial = {};
    bulkSubjects.forEach(bs => {
      initial[bs.id] = {};
      classStudents.forEach(s => {
        const existing = results.find(r => r.studentId === s.id && r.examName === bulkExam);
        const subMark = existing?.subjects?.find(sub => sub.subjectName === bs.name);
        if (subMark) {
          const total = subMark.marks;
          const theory = subMark.theoryMarks != null ? subMark.theoryMarks : Math.round(total * 0.8);
          const practical = subMark.practicalMarks != null ? subMark.practicalMarks : Math.round(total * 0.15);
          const internal = subMark.internalMarks != null ? subMark.internalMarks : (total - theory - practical);
          initial[bs.id][s.id] = { marks: total, theory, practical, internal };
        } else {
          initial[bs.id][s.id] = { marks: '', theory: '', practical: '', internal: '' };
        }
      });
    });
    setMarkEntries(initial);
  }, [bulkClass, bulkExam, bulkSubjects.map(s => s.name).join(','), results]);

  const handleBulkMarkChange = (subjectId, studentId, field, val) => {
    setMarkEntries(prev => {
      const prevEntry = prev[subjectId]?.[studentId] || { marks: '', theory: '', practical: '', internal: '' };
      const parsedVal = val === '' ? '' : Math.max(0, Number(val));
      const nextEntry = { ...prevEntry, [field]: parsedVal };

      // In detailed mode, sync total marks
      if (field === 'theory' || field === 'practical' || field === 'internal') {
        const t = Number(nextEntry.theory) || 0;
        const p = Number(nextEntry.practical) || 0;
        const i = Number(nextEntry.internal) || 0;
        nextEntry.marks = t + p + i;
      }

      return {
        ...prev,
        [subjectId]: {
          ...(prev[subjectId] || {}),
          [studentId]: nextEntry
        }
      };
    });
  };

  const handleAddBulkSubject = () => {
    const newId = `sub_${Date.now()}`;
    const newSub = { id: newId, name: `Subject ${bulkSubjects.length + 1}`, totalMarks: 100 };
    setBulkSubjects(prev => [...prev, newSub]);
    setActiveBulkSubjectId(newId);
  };

  const handleRemoveBulkSubject = (subId) => {
    if (bulkSubjects.length <= 1) {
      showToast("At least one subject is required in mark desk.", "info");
      return;
    }
    setBulkSubjects(prev => prev.filter(s => s.id !== subId));
    if (activeBulkSubjectId === subId) {
      const remaining = bulkSubjects.filter(s => s.id !== subId);
      setActiveBulkSubjectId(remaining[0]?.id || '');
    }
  };

  const handleUpdateBulkSubject = (subId, field, val) => {
    setBulkSubjects(prev => prev.map(s => s.id === subId ? { ...s, [field]: val } : s));
  };

  // Save a single student's marks directly from the table row
  const handleSaveSingleStudent = (student) => {
    const existing = results.find(r => r.studentId === student.id && r.examName === bulkExam);
    let updatedSubjects = existing ? [...existing.subjects] : [];

    bulkSubjects.forEach(bs => {
      const entry = markEntries[bs.id]?.[student.id];
      if (!entry) return;

      const maxMarks = Number(bs.totalMarks) || 100;

      if (isDetailedBreakdownMode) {
        const theory = Number(entry.theory) || 0;
        const practical = Number(entry.practical) || 0;
        const internal = Number(entry.internal) || 0;
        const total = theory + practical + internal;
        if (theory === 0 && practical === 0 && internal === 0 && entry.theory === '' && entry.practical === '' && entry.internal === '') {
          return;
        }

        const subIndex = updatedSubjects.findIndex(sub => sub.subjectName === bs.name);
        const subData = {
          subjectName: bs.name,
          marks: total,
          totalMarks: maxMarks,
          theoryMarks: theory,
          practicalMarks: practical,
          internalMarks: internal
        };
        if (subIndex >= 0) updatedSubjects[subIndex] = subData;
        else updatedSubjects.push(subData);
      } else {
        if (entry.marks === '' && entry.marks == null) return;
        const total = Number(entry.marks) || 0;
        const subIndex = updatedSubjects.findIndex(sub => sub.subjectName === bs.name);
        const subData = {
          subjectName: bs.name,
          marks: total,
          totalMarks: maxMarks,
          theoryMarks: 0,
          practicalMarks: 0,
          internalMarks: 0
        };
        if (subIndex >= 0) updatedSubjects[subIndex] = subData;
        else updatedSubjects.push(subData);
      }
    });

    if (updatedSubjects.length > 0) {
      saveResult({
        id: existing?.id,
        studentId: student.id,
        examName: bulkExam,
        subjects: updatedSubjects,
        status: existing?.status || 'AUTO'
      });
      setSavedStudentIds(prev => new Set([...prev, student.id]));
      showToast(`Marks saved for ${student.name}!`, 'success');
    } else {
      showToast(`No marks entered for ${student.name}`, 'info');
    }
  };

  // Batch save all students in current class
  const handleSaveBulk = (isPublish = false) => {
    const newlySaved = new Set(savedStudentIds);

    classStudents.forEach(s => {
      const existing = results.find(r => r.studentId === s.id && r.examName === bulkExam);
      let updatedSubjects = existing ? [...existing.subjects] : [];

      bulkSubjects.forEach(bs => {
        const entry = markEntries[bs.id]?.[s.id];
        if (!entry) return;

        const maxMarks = Number(bs.totalMarks) || 100;

        if (isDetailedBreakdownMode) {
          const theory = Number(entry.theory) || 0;
          const practical = Number(entry.practical) || 0;
          const internal = Number(entry.internal) || 0;
          const total = theory + practical + internal;

          if (theory === 0 && practical === 0 && internal === 0 && entry.theory === '' && entry.practical === '' && entry.internal === '') {
            return;
          }

          const subIndex = updatedSubjects.findIndex(sub => sub.subjectName === bs.name);
          const subData = {
            subjectName: bs.name,
            marks: total,
            totalMarks: maxMarks,
            theoryMarks: theory,
            practicalMarks: practical,
            internalMarks: internal
          };
          if (subIndex >= 0) updatedSubjects[subIndex] = subData;
          else updatedSubjects.push(subData);
        } else {
          if (entry.marks === '' && entry.marks == null) return;
          const total = Number(entry.marks) || 0;
          const subIndex = updatedSubjects.findIndex(sub => sub.subjectName === bs.name);
          const subData = {
            subjectName: bs.name,
            marks: total,
            totalMarks: maxMarks,
            theoryMarks: 0,
            practicalMarks: 0,
            internalMarks: 0
          };
          if (subIndex >= 0) updatedSubjects[subIndex] = subData;
          else updatedSubjects.push(subData);
        }
      });

      if (updatedSubjects.length > 0) {
        saveResult({
          id: existing?.id,
          studentId: s.id,
          examName: bulkExam,
          subjects: updatedSubjects,
          status: existing?.status || 'AUTO'
        });
        newlySaved.add(s.id);
      }
    });

    setSavedStudentIds(newlySaved);
    showToast(isPublish ? "Marks published successfully for all students!" : "Marks saved successfully for all students!", "success");
  };

  const activeSubject = bulkSubjects.find(s => s.id === activeBulkSubjectId) || bulkSubjects[0];

  return (
    <div className="space-y-6 pb-12 font-sans">
      {/* Top Navigation Tabs */}
      <div className="flex items-center gap-2 border-b border-border pb-1 overflow-x-auto custom-scrollbar">
        <button
          onClick={() => setActiveTab('saved')}
          className={`flex items-center gap-2 px-4 py-2.5 font-bold text-xs rounded-xl cursor-pointer transition-all ${
            activeTab === 'saved'
              ? 'bg-primary text-white shadow-sm'
              : 'text-text-secondary hover:text-text hover:bg-surface2'
          }`}
        >
          <Award className="w-4 h-4" />
          <span>Saved Results ({results.length})</span>
        </button>

        <button
          onClick={() => setActiveTab('entry')}
          className={`flex items-center gap-2 px-4 py-2.5 font-bold text-xs rounded-xl cursor-pointer transition-all ${
            activeTab === 'entry'
              ? 'bg-primary text-white shadow-sm'
              : 'text-text-secondary hover:text-text hover:bg-surface2'
          }`}
        >
          <ClipboardList className="w-4 h-4" />
          <span>Mark Entry Desk</span>
        </button>
      </div>

      {/* ──────── TAB 1: SAVED RESULTS ──────── */}
      {activeTab === 'saved' && (
        <div className="space-y-6 animate-in fade-in duration-200">
          {/* Header Actions */}
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
            <div>
              <h2 className="text-xl font-black text-text tracking-tight">Academic Marksheets & Results</h2>
              <p className="text-xs text-text-muted mt-0.5">Generate, print and share examination result cards for school & computer students.</p>
            </div>

            <div className="flex items-center gap-2 flex-wrap text-xs font-bold">
              <button
                onClick={() => exportExamResultsPDF(filteredResults, students, settings)}
                className="px-3 py-2 rounded-xl bg-surface2 hover:bg-surface2/80 text-text border border-border flex items-center gap-1.5 cursor-pointer transition-all"
                title="Download consolidated PDF report"
              >
                <Download className="w-3.5 h-3.5 text-primary" />
                <span>Export PDF</span>
              </button>

              <button
                onClick={() => exportExamResultsToExcel(filteredResults, students, settings)}
                className="px-3 py-2 rounded-xl bg-surface2 hover:bg-surface2/80 text-text border border-border flex items-center gap-1.5 cursor-pointer transition-all"
                title="Export results spreadsheet to Excel"
              >
                <FileSpreadsheet className="w-3.5 h-3.5 text-emerald-600" />
                <span>Export Excel</span>
              </button>

              <button
                onClick={handleOpenAdd}
                className="px-4 py-2 rounded-xl bg-primary hover:bg-primary-dark text-white flex items-center gap-1.5 cursor-pointer shadow-md transition-all active:scale-95"
              >
                <Plus className="w-4 h-4" />
                <span>Single Entry</span>
              </button>
            </div>
          </div>

          {/* Quick Metrics Cards */}
          <div className="grid grid-cols-2 lg:grid-cols-4 gap-4 text-xs">
            <div className="bg-white border border-border rounded-2xl p-4 shadow-xs">
              <span className="text-text-secondary font-bold uppercase text-[10px] tracking-wider">Overall Pass Rate</span>
              <p className="text-2xl font-black text-emerald-600 mt-1">{overallPassRate}%</p>
              <p className="text-[10px] text-text-muted mt-0.5">{passedCount} of {totalResultScores} scored passed</p>
            </div>

            <div className="bg-white border border-border rounded-2xl p-4 shadow-xs">
              <span className="text-text-secondary font-bold uppercase text-[10px] tracking-wider">Total Exam Records</span>
              <p className="text-2xl font-black text-primary mt-1">{results.length}</p>
              <p className="text-[10px] text-text-muted mt-0.5">Published marksheets</p>
            </div>

            <div className="bg-white border border-border rounded-2xl p-4 shadow-xs col-span-2">
              <span className="text-text-secondary font-bold uppercase text-[10px] tracking-wider">Grade Distribution</span>
              <div className="flex items-center gap-3 mt-2">
                {Object.entries(gradeCounts).map(([g, cnt]) => (
                  <div key={g} className="flex-1 text-center">
                    <span className="text-xs font-black text-text">{cnt}</span>
                    <div className="text-[9px] font-bold text-text-muted">{g}</div>
                  </div>
                ))}
              </div>
            </div>
          </div>

          {/* Search bar */}
          <div className="bg-white border border-border rounded-2xl p-4 shadow-xs">
            <div className="relative">
              <Search className="w-4 h-4 text-text-muted absolute left-3.5 top-1/2 -translate-y-1/2" />
              <input
                type="text"
                value={searchQuery}
                onChange={e => setSearchQuery(e.target.value)}
                placeholder="Search result records by exam, student name, or ID..."
                className="w-full pl-10 pr-4 py-2 rounded-xl bg-surface2 border border-border text-xs text-text focus:outline-none focus:border-primary"
              />
            </div>
          </div>

          {/* Results Table */}
          <div className="bg-white border border-border rounded-2xl shadow-sm overflow-hidden flex flex-col">
            <div className="overflow-x-auto">
              <table className="w-full text-left text-xs border-collapse">
                <thead>
                  <tr className="bg-surface2/60 border-b border-border text-text-secondary font-bold text-[10px] uppercase">
                    <th className="py-3 px-4">Student</th>
                    <th className="py-3 px-4">Exam Name</th>
                    <th className="py-3 px-4 text-center">Subjects</th>
                    <th className="py-3 px-4 text-right">Total Marks</th>
                    <th className="py-3 px-4 text-center">Percentage</th>
                    <th className="py-3 px-4 text-center">Status</th>
                    <th className="py-3 px-4 text-right">Actions</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-border text-text font-medium">
                  {filteredResults.length === 0 ? (
                    <tr>
                      <td colSpan="7" className="py-12 text-center text-text-muted text-xs">
                        No result records found. Use 'Mark Entry Desk' or 'Single Entry' to enter marks.
                      </td>
                    </tr>
                  ) : (
                    filteredResults.map(r => {
                      const student = students.find(s => s.id === r.studentId);
                      const totalMarksObt = r.subjects?.reduce((a, s) => a + (Number(s.marks) || 0), 0) || 0;
                      const totalMax = r.subjects?.reduce((a, s) => a + (Number(s.totalMarks) || 100), 0) || 1;
                      const pct = Math.round((totalMarksObt / totalMax) * 100);

                      const passCriteria = Number(r.passingMarks || 33);
                      const failedSubs = r.subjects?.filter(sub => {
                        const sMax = Number(sub.totalMarks) || 100;
                        const sObt = Number(sub.marks) || 0;
                        const minP = sub.passingMarks != null ? Number(sub.passingMarks) : Math.round(sMax * (passCriteria / 100));
                        return sObt < minP;
                      }) || [];
                      const failCount = failedSubs.length;

                      let finalStatus = 'PASS';
                      if (r.status === 'PROMOTED') finalStatus = 'PROMOTED';
                      else if (failCount > 0 || pct < passCriteria || r.status === 'FAIL') finalStatus = 'FAIL';
                      else finalStatus = 'PASS';

                      return (
                        <tr key={r.id} className="hover:bg-surface2/30 transition-colors">
                          <td className="py-3.5 px-4 font-bold text-text">
                            <div>
                              <div>{student?.name || 'Unknown Student'}</div>
                              <div className="text-[9px] text-text-muted">ID: {student?.studentId || '-'} · Class: {student?.className || student?.course || '-'}</div>
                            </div>
                          </td>
                          <td className="py-3.5 px-4">{r.examName}</td>
                          <td className="py-3.5 px-4 text-center">
                            <span className="px-2 py-0.5 rounded-full bg-primary/10 text-primary font-bold text-[10px]">
                              {r.subjects?.length || 0} Subjects
                            </span>
                          </td>
                          <td className="py-3.5 px-4 text-right font-black text-text">
                            {totalMarksObt} / {totalMax}
                          </td>
                          <td className="py-3.5 px-4 text-center">
                            <span className={`px-2 py-0.5 rounded-full text-[10px] font-black ${
                              pct >= 40 ? 'bg-emerald-100 text-emerald-700' : 'bg-rose-100 text-rose-700'
                            }`}>
                              {pct}%
                            </span>
                          </td>
                          <td className="py-3.5 px-4 text-center">
                            {finalStatus === 'PROMOTED' ? (
                              <span className="px-2.5 py-0.5 rounded-full text-[10px] font-black bg-amber-100 text-amber-800 border border-amber-300">
                                PROMOTED
                              </span>
                            ) : finalStatus === 'PASS' ? (
                              <span className="px-2.5 py-0.5 rounded-full text-[10px] font-black bg-emerald-100 text-emerald-800 border border-emerald-300">
                                PASSED
                              </span>
                            ) : (
                              <span className="px-2.5 py-0.5 rounded-full text-[10px] font-black bg-rose-100 text-rose-800 border border-rose-300">
                                FAILED {failCount > 0 ? `(${failCount})` : ''}
                              </span>
                            )}
                          </td>
                          <td className="py-3.5 px-4 text-right">
                            <div className="flex items-center justify-end gap-1.5">
                              {/* Direct WhatsApp Share */}
                              <button
                                onClick={() => handleWhatsAppShare(r, student)}
                                className="p-1.5 rounded-lg bg-surface2 hover:bg-emerald-50 text-emerald-600 border border-border cursor-pointer transition-colors"
                                title="Share Marksheet on WhatsApp"
                              >
                                <MessageCircle className="w-3.5 h-3.5" />
                              </button>
                              <button
                                onClick={async () => {
                                  await exportSingleResultPDF(r, student, settings);
                                  showToast(`Downloaded marksheet PDF for ${student?.name || 'student'}!`, 'success');
                                }}
                                className="p-1.5 rounded-lg bg-surface2 hover:bg-emerald-100 text-emerald-600 border border-border cursor-pointer transition-colors"
                                title="Download Marksheet PDF"
                              >
                                <Download className="w-3.5 h-3.5" />
                              </button>
                              <button
                                onClick={() => setPrintResultData({ result: r, student })}
                                className="p-1.5 rounded-lg bg-surface2 hover:bg-primary/10 text-primary border border-border cursor-pointer transition-colors"
                                title="Print Marksheet"
                              >
                                <Printer className="w-3.5 h-3.5" />
                              </button>
                              <button
                                onClick={() => handleOpenEdit(r)}
                                className="p-1.5 rounded-lg bg-surface2 hover:bg-primary/10 text-text border border-border cursor-pointer transition-colors"
                                title="Edit Result"
                              >
                                <Edit className="w-3.5 h-3.5" />
                              </button>
                              <button
                                onClick={() => deleteResult(r.id)}
                                className="p-1.5 rounded-lg bg-surface2 hover:bg-rose-100 text-rose-600 border border-border cursor-pointer transition-colors"
                                title="Delete Result"
                              >
                                <Trash2 className="w-3.5 h-3.5" />
                              </button>
                            </div>
                          </td>
                        </tr>
                      );
                    })
                  )}
                </tbody>
              </table>
            </div>
          </div>
        </div>
      )}

      {/* ──────── TAB 2: BULK MARK ENTRY DESK ──────── */}
      {activeTab === 'entry' && (
        <div className="space-y-6 animate-in fade-in duration-200">
          {/* Desk Header & Controls */}
          <div className="bg-white border border-border rounded-2xl p-5 shadow-xs space-y-4">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 border-b border-border pb-3">
              <div>
                <h3 className="font-extrabold text-sm text-text flex items-center gap-2">
                  <ClipboardList className="w-4 h-4 text-primary" />
                  <span>Bulk Mark Entry Desk</span>
                </h3>
                <p className="text-[11px] text-text-muted mt-0.5">Quickly enter and save examination marks for all enrolled students.</p>
              </div>

              {/* Mode Toggle & Save All Buttons */}
              <div className="flex items-center gap-2 flex-wrap">
                {/* Mode Selector Toggle */}
                <div className="flex items-center bg-surface2 p-1 rounded-xl border border-border text-xs">
                  <button
                    type="button"
                    onClick={() => setIsDetailedBreakdownMode(false)}
                    className={`px-3 py-1 rounded-lg font-bold cursor-pointer transition-all ${
                      !isDetailedBreakdownMode
                        ? 'bg-white text-primary shadow-xs'
                        : 'text-text-secondary hover:text-text'
                    }`}
                  >
                    Direct Marks
                  </button>
                  <button
                    type="button"
                    onClick={() => setIsDetailedBreakdownMode(true)}
                    className={`px-3 py-1 rounded-lg font-bold cursor-pointer transition-all ${
                      isDetailedBreakdownMode
                        ? 'bg-white text-primary shadow-xs'
                        : 'text-text-secondary hover:text-text'
                    }`}
                  >
                    Detailed (Theory/Practical)
                  </button>
                </div>

                <button
                  onClick={() => handleSaveBulk(false)}
                  className="px-4 py-2 rounded-xl bg-surface2 hover:bg-primary/10 text-primary border border-border font-bold text-xs cursor-pointer transition-all active:scale-95 flex items-center gap-1.5"
                >
                  <Save className="w-3.5 h-3.5" />
                  <span>Save All</span>
                </button>
                <button
                  onClick={() => handleSaveBulk(true)}
                  className="px-4 py-2 rounded-xl bg-primary hover:bg-primary-dark text-white font-bold text-xs cursor-pointer shadow-md transition-all active:scale-95 flex items-center gap-1.5"
                >
                  <CheckCircle2 className="w-3.5 h-3.5" />
                  <span>Publish All</span>
                </button>
              </div>
            </div>

            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 text-xs font-semibold">
              <div>
                <label className="block text-text-secondary mb-1">Class / Course</label>
                <select
                  value={bulkClass}
                  onChange={e => setBulkClass(e.target.value)}
                  className="w-full px-3 py-2 rounded-xl bg-surface2 border border-border text-text font-bold"
                >
                  {settings.schoolClasses?.map(c => <option key={c} value={c}>Class {c}</option>)}
                  {settings.computerCourses?.map(c => <option key={c} value={c}>{c}</option>)}
                </select>
              </div>
              <div>
                <label className="block text-text-secondary mb-1">Examination</label>
                <input
                  type="text"
                  value={bulkExam}
                  onChange={e => setBulkExam(e.target.value)}
                  className="w-full px-3 py-2 rounded-xl bg-surface2 border border-border text-text font-bold"
                  placeholder="e.g. Mid-Term Examination 2026"
                />
              </div>
            </div>

            {/* Subject Tabs / Selector with Add Subject */}
            <div className="pt-3 border-t border-border space-y-2">
              <div className="flex items-center justify-between">
                <label className="text-xs font-bold text-text-secondary">Subjects in Desk ({bulkSubjects.length})</label>
                <button
                  type="button"
                  onClick={handleAddBulkSubject}
                  className="px-3 py-1 rounded-lg bg-primary/10 hover:bg-primary/20 text-primary text-xs font-bold flex items-center gap-1 cursor-pointer transition-colors"
                >
                  <Plus className="w-3.5 h-3.5" />
                  <span>Add Subject</span>
                </button>
              </div>

              <div className="flex flex-wrap items-center gap-2">
                {bulkSubjects.map(sub => (
                  <div
                    key={sub.id}
                    onClick={() => setActiveBulkSubjectId(sub.id)}
                    className={`px-3 py-1.5 rounded-xl border text-xs font-bold flex items-center gap-2 cursor-pointer transition-all ${
                      activeBulkSubjectId === sub.id
                        ? 'bg-primary text-white border-primary shadow-xs'
                        : 'bg-surface2 text-text border-border hover:border-primary/50'
                    }`}
                  >
                    <span>{sub.name}</span>
                    <span className={`text-[10px] px-1.5 py-0.2 rounded-md ${
                      activeBulkSubjectId === sub.id ? 'bg-white/20 text-white' : 'bg-border text-text-secondary'
                    }`}>
                      Max: {sub.totalMarks || 100}
                    </span>
                    {bulkSubjects.length > 1 && (
                      <button
                        type="button"
                        onClick={(e) => {
                          e.stopPropagation();
                          handleRemoveBulkSubject(sub.id);
                        }}
                        className={`p-0.5 rounded hover:bg-rose-500 hover:text-white transition-colors ${
                          activeBulkSubjectId === sub.id ? 'text-white/80' : 'text-text-muted'
                        }`}
                      >
                        <X className="w-3 h-3" />
                      </button>
                    )}
                  </div>
                ))}
              </div>

              {/* Active Subject Configuration */}
              {activeSubject && (
                <div className="p-3 bg-surface2/60 border border-border rounded-xl flex flex-wrap items-center gap-3 text-xs">
                  <div className="flex-1 min-w-[200px]">
                    <label className="block text-[10px] font-bold text-text-secondary mb-1">Active Subject Name</label>
                    <input
                      type="text"
                      value={activeSubject.name}
                      onChange={e => handleUpdateBulkSubject(activeSubject.id, 'name', e.target.value)}
                      className="w-full px-3 py-1.5 rounded-lg bg-white border border-border font-bold text-text"
                      placeholder="e.g. Mathematics"
                    />
                  </div>
                  <div className="w-32">
                    <label className="block text-[10px] font-bold text-text-secondary mb-1">Total Max Marks</label>
                    <input
                      type="number"
                      min="1"
                      value={activeSubject.totalMarks || 100}
                      onChange={e => handleUpdateBulkSubject(activeSubject.id, 'totalMarks', Number(e.target.value) || 100)}
                      className="w-full px-3 py-1.5 rounded-lg bg-white border border-border font-bold text-text text-center font-mono"
                      placeholder="100"
                    />
                  </div>
                </div>
              )}
            </div>
          </div>

          {/* Bulk entry table for active subject */}
          <div className="bg-white border border-border rounded-2xl shadow-sm overflow-hidden flex flex-col">
            <div className="p-3.5 bg-surface2/80 border-b border-border flex items-center justify-between text-xs font-bold">
              <span>Entering marks for: <strong className="text-primary">{activeSubject?.name || 'Subject'}</strong> (Max: {activeSubject?.totalMarks || 100})</span>
              <span className="text-text-secondary">{classStudents.length} Students in Class {bulkClass}</span>
            </div>

            <div className="overflow-x-auto">
              <table className="w-full text-left text-xs border-collapse">
                <thead>
                  <tr className="bg-surface2/60 border-b border-border text-text-secondary font-bold text-[10px] uppercase">
                    <th className="py-3 px-4">Student</th>
                    {isDetailedBreakdownMode ? (
                      <>
                        <th className="py-3 px-4 text-center">Theory</th>
                        <th className="py-3 px-4 text-center">Practical</th>
                        <th className="py-3 px-4 text-center">Internal</th>
                        <th className="py-3 px-4 text-right">Total / Max</th>
                      </>
                    ) : (
                      <>
                        <th className="py-3 px-4 text-center">Marks Obtained</th>
                        <th className="py-3 px-4 text-center">Max Marks</th>
                        <th className="py-3 px-4 text-center">Percentage</th>
                      </>
                    )}
                    <th className="py-3 px-4 text-center">Row Action</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-border text-text font-medium">
                  {classStudents.length === 0 ? (
                    <tr>
                      <td colSpan={isDetailedBreakdownMode ? 6 : 5} className="py-12 text-center text-text-muted text-xs">
                        No students enrolled in Class {bulkClass}.
                      </td>
                    </tr>
                  ) : (
                    classStudents.map(s => {
                      const entry = markEntries[activeSubject?.id]?.[s.id] || { marks: '', theory: '', practical: '', internal: '' };
                      const max = activeSubject?.totalMarks || 100;
                      const isSaved = savedStudentIds.has(s.id);

                      if (isDetailedBreakdownMode) {
                        const total = (Number(entry.theory) || 0) + (Number(entry.practical) || 0) + (Number(entry.internal) || 0);
                        return (
                          <tr key={s.id} className="hover:bg-surface2/30 transition-colors">
                            <td className="py-3 px-4 font-bold">
                              <div>{s.name}</div>
                              <div className="text-[9px] text-text-muted">Roll: {s.rollNumber || '-'} · ID: {s.studentId}</div>
                            </td>
                            <td className="py-3 px-4 text-center">
                              <input
                                type="number"
                                min="0"
                                value={entry.theory}
                                onChange={e => handleBulkMarkChange(activeSubject?.id, s.id, 'theory', e.target.value)}
                                placeholder="0"
                                className="w-16 px-2 py-1 rounded-lg bg-surface2 border border-border text-center font-mono font-bold focus:outline-none focus:border-primary"
                              />
                            </td>
                            <td className="py-3 px-4 text-center">
                              <input
                                type="number"
                                min="0"
                                value={entry.practical}
                                onChange={e => handleBulkMarkChange(activeSubject?.id, s.id, 'practical', e.target.value)}
                                placeholder="0"
                                className="w-16 px-2 py-1 rounded-lg bg-surface2 border border-border text-center font-mono font-bold focus:outline-none focus:border-primary"
                              />
                            </td>
                            <td className="py-3 px-4 text-center">
                              <input
                                type="number"
                                min="0"
                                value={entry.internal}
                                onChange={e => handleBulkMarkChange(activeSubject?.id, s.id, 'internal', e.target.value)}
                                placeholder="0"
                                className="w-16 px-2 py-1 rounded-lg bg-surface2 border border-border text-center font-mono font-bold focus:outline-none focus:border-primary"
                              />
                            </td>
                            <td className="py-3 px-4 text-right font-black text-primary font-mono text-sm">
                              {total} / {max}
                            </td>
                            <td className="py-3 px-4 text-center">
                              <button
                                type="button"
                                onClick={() => handleSaveSingleStudent(s)}
                                className={`px-3 py-1 rounded-lg text-xs font-bold inline-flex items-center gap-1 cursor-pointer transition-all active:scale-95 ${
                                  isSaved
                                    ? 'bg-emerald-100 text-emerald-800 border border-emerald-300 hover:bg-emerald-200'
                                    : 'bg-primary hover:bg-primary-dark text-white shadow-xs'
                                }`}
                                title="Save marks for this student row"
                              >
                                {isSaved ? (
                                  <>
                                    <Check className="w-3.5 h-3.5 text-emerald-700" />
                                    <span>Saved</span>
                                  </>
                                ) : (
                                  <>
                                    <Save className="w-3.5 h-3.5" />
                                    <span>Save</span>
                                  </>
                                )}
                              </button>
                            </td>
                          </tr>
                        );
                      } else {
                        // Direct Marks mode
                        const currentObt = entry.marks !== '' ? Number(entry.marks) : '';
                        const obtNum = Number(entry.marks) || 0;
                        const subPct = max > 0 ? Math.round((obtNum / max) * 100) : 0;
                        return (
                          <tr key={s.id} className="hover:bg-surface2/30 transition-colors">
                            <td className="py-3 px-4 font-bold">
                              <div>{s.name}</div>
                              <div className="text-[9px] text-text-muted">Roll: {s.rollNumber || '-'} · ID: {s.studentId}</div>
                            </td>
                            <td className="py-3 px-4 text-center">
                              <input
                                type="number"
                                min="0"
                                max={max}
                                value={entry.marks}
                                onChange={e => handleBulkMarkChange(activeSubject?.id, s.id, 'marks', e.target.value)}
                                placeholder="0"
                                className="w-24 px-3 py-1.5 rounded-lg bg-surface2 border-2 border-border font-bold text-center font-mono text-sm focus:border-primary focus:bg-white transition-colors"
                              />
                            </td>
                            <td className="py-3 px-4 text-center font-bold text-text-muted font-mono">
                              {max}
                            </td>
                            <td className="py-3 px-4 text-center">
                              <span className={`px-2 py-0.5 rounded-full text-[10px] font-black ${
                                subPct >= 33 ? 'bg-emerald-100 text-emerald-800' : 'bg-rose-100 text-rose-800'
                              }`}>
                                {subPct}%
                              </span>
                            </td>
                            <td className="py-3 px-4 text-center">
                              <button
                                type="button"
                                onClick={() => handleSaveSingleStudent(s)}
                                className={`px-3 py-1.5 rounded-lg text-xs font-bold inline-flex items-center gap-1 cursor-pointer transition-all active:scale-95 ${
                                  isSaved
                                    ? 'bg-emerald-100 text-emerald-800 border border-emerald-300 hover:bg-emerald-200'
                                    : 'bg-primary hover:bg-primary-dark text-white shadow-xs'
                                }`}
                                title="Save marks for this student row"
                              >
                                {isSaved ? (
                                  <>
                                    <Check className="w-3.5 h-3.5 text-emerald-700" />
                                    <span>Saved</span>
                                  </>
                                ) : (
                                  <>
                                    <Save className="w-3.5 h-3.5" />
                                    <span>Save</span>
                                  </>
                                )}
                              </button>
                            </td>
                          </tr>
                        );
                      }
                    })
                  )}
                </tbody>
              </table>
            </div>
          </div>
        </div>
      )}

      {/* ──────── SINGLE ENTRY MODAL ──────── */}
      {isModalOpen && (
        <div className="fixed inset-0 z-50 bg-black/60 backdrop-blur-xs flex items-center justify-center p-4 overflow-y-auto">
          <div className="bg-card border border-border w-full max-w-lg rounded-3xl p-6 shadow-2xl space-y-5 animate-in zoom-in-95 duration-200">
            <div className="flex items-center justify-between border-b border-border pb-3">
              <h3 className="font-bold text-base text-text">
                {editingResult ? 'Edit Exam Result' : 'Enter Student Exam Result'}
              </h3>
              <button onClick={() => setIsModalOpen(false)} className="p-1 rounded-lg hover:bg-surface2 cursor-pointer">
                <X className="w-5 h-5 text-text-secondary" />
              </button>
            </div>

            <form onSubmit={handleSubmit} className="space-y-4 text-xs font-semibold">
              {/* STEP 1: Filter and Select Student */}
              <div className="p-4 rounded-2xl bg-surface2/60 border border-border space-y-3">
                <div className="flex items-center justify-between">
                  <span className="text-[11px] font-black uppercase tracking-wider text-text flex items-center gap-1.5">
                    <Users className="w-3.5 h-3.5 text-primary" />
                    <span>Step 1: Filter & Choose Student</span>
                  </span>
                  {selectedStudentObj ? (
                    <span className="text-[10px] font-bold text-emerald-700 bg-emerald-50 px-2 py-0.5 rounded-full border border-emerald-200">
                      ✓ Student Selected
                    </span>
                  ) : (
                    <span className="text-[10px] font-bold text-amber-700 bg-amber-50 px-2 py-0.5 rounded-full border border-amber-200">
                      Choose Student Below
                    </span>
                  )}
                </div>

                {/* Filter Controls */}
                <div className="grid grid-cols-1 sm:grid-cols-3 gap-2">
                  <div>
                    <label className="block text-[10px] text-text-muted mb-1 font-bold">Filter Type</label>
                    <select
                      value={modalStudentType}
                      onChange={e => {
                        setModalStudentType(e.target.value);
                        setSelectedStudentId('');
                      }}
                      className="w-full px-2.5 py-1.5 rounded-xl bg-card border border-border text-text font-bold text-xs"
                    >
                      <option value="all">All Types</option>
                      <option value="school">School Students</option>
                      <option value="computer">Computer Students</option>
                    </select>
                  </div>

                  <div>
                    <label className="block text-[10px] text-text-muted mb-1 font-bold">Filter Class / Course</label>
                    <select
                      value={modalClassFilter}
                      onChange={e => {
                        setModalClassFilter(e.target.value);
                        setSelectedStudentId('');
                      }}
                      className="w-full px-2.5 py-1.5 rounded-xl bg-card border border-border text-text font-bold text-xs"
                    >
                      <option value="all">All Classes & Courses</option>
                      {availableModalClasses.map(cls => (
                        <option key={cls} value={cls}>{cls}</option>
                      ))}
                    </select>
                  </div>

                  <div>
                    <label className="block text-[10px] text-text-muted mb-1 font-bold">Search Student</label>
                    <div className="relative">
                      <input
                        type="text"
                        value={modalStudentSearch}
                        onChange={e => setModalStudentSearch(e.target.value)}
                        placeholder="Name, ID, Roll..."
                        className="w-full pl-7 pr-2 py-1.5 rounded-xl bg-card border border-border text-text font-bold text-xs"
                      />
                      <Search className="w-3.5 h-3.5 text-text-muted absolute left-2 top-2" />
                    </div>
                  </div>
                </div>

                {/* Filtered Student Dropdown */}
                <div>
                  <label className="block text-[11px] text-text mb-1 font-bold flex items-center justify-between">
                    <span>Select Student ({modalFilteredStudents.length} available)</span>
                    {modalClassFilter !== 'all' && (
                      <span className="text-[10px] text-primary font-bold">Filtered: {modalClassFilter}</span>
                    )}
                  </label>
                  <select
                    value={selectedStudentId}
                    onChange={e => setSelectedStudentId(e.target.value)}
                    className="w-full px-3 py-2 rounded-xl bg-card border-2 border-primary/30 hover:border-primary text-text font-bold text-xs focus:ring-2 focus:ring-primary/20 transition-all cursor-pointer"
                    required
                  >
                    <option value="">-- Choose Student from Filtered List --</option>
                    {modalFilteredStudents.map(s => (
                      <option key={s.id} value={s.id}>
                        {s.name} • {s.studentType === 'school' ? `Class ${s.className}` : s.course} • ID: {s.studentId}
                      </option>
                    ))}
                  </select>
                </div>

                {/* Selected Student Information Highlight Card */}
                {selectedStudentObj && (
                  <div className="p-3 rounded-xl bg-white border border-border flex items-center justify-between gap-3 shadow-xs animate-in fade-in duration-200">
                    <div className="flex items-center gap-3 min-w-0">
                      <div className="w-10 h-10 rounded-xl bg-primary/10 text-primary font-black flex items-center justify-center text-sm flex-shrink-0">
                        {selectedStudentObj.photoPath || selectedStudentObj.photoUrl ? (
                          <img src={selectedStudentObj.photoPath || selectedStudentObj.photoUrl} alt="" className="w-full h-full object-cover rounded-xl" />
                        ) : (
                          selectedStudentObj.name?.charAt(0) || 'S'
                        )}
                      </div>
                      <div className="min-w-0">
                        <div className="font-extrabold text-text text-xs sm:text-sm truncate">{selectedStudentObj.name}</div>
                        <div className="text-[11px] text-text-muted flex items-center gap-2 flex-wrap">
                          <span className="text-primary font-bold">
                            {selectedStudentObj.studentType === 'school' ? `Class ${selectedStudentObj.className}` : selectedStudentObj.course}
                          </span>
                          {selectedStudentObj.rollNumber && <span>• Roll: {selectedStudentObj.rollNumber}</span>}
                          {selectedStudentObj.admissionNumber && <span>• Adm: {selectedStudentObj.admissionNumber}</span>}
                          <span>• ID: {selectedStudentObj.studentId}</span>
                        </div>
                      </div>
                    </div>
                  </div>
                )}
              </div>

              {/* STEP 2: Exam & Passing Configuration */}
              <div className="space-y-4 pt-1">
                <div>
                  <div className="flex items-center justify-between mb-1">
                    <label className="text-text-secondary font-bold">Step 2: Exam Name</label>
                    <span className="text-[10px] text-text-muted font-bold">Select quick tag or type</span>
                  </div>
                  <input
                    type="text"
                    value={examName}
                    onChange={e => setExamName(e.target.value)}
                    className="w-full px-3 py-2 rounded-xl bg-surface2 border border-border text-text font-bold text-xs"
                    placeholder="e.g. Mid-Term Examination"
                    required
                  />

                  {/* Passing Marks & Result Status */}
                  <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 mt-3">
                    <div className="p-3 rounded-xl bg-surface2/80 border border-border flex items-center justify-between gap-2">
                      <div>
                        <label className="block text-[11px] font-bold text-text">Passing Criteria (%)</label>
                        <span className="text-[10px] text-text-muted">Min score to pass</span>
                      </div>
                      <div className="flex items-center gap-1.5">
                        <input
                          type="number"
                          min="1"
                          max="100"
                          value={passingMarks}
                          onChange={e => setPassingMarks(e.target.value)}
                          className="w-14 px-2 py-1 rounded-lg bg-white border border-border text-center font-bold text-xs font-mono text-primary"
                          required
                        />
                        <span className="text-xs font-bold text-text-muted">%</span>
                      </div>
                    </div>

                    <div className="p-3 rounded-xl bg-surface2/80 border border-border">
                      <label className="block text-[11px] font-bold text-text mb-1">Result Status</label>
                      <select
                        value={resultStatus}
                        onChange={e => setResultStatus(e.target.value)}
                        className="w-full px-2.5 py-1 rounded-lg bg-white border border-border text-text font-bold text-xs"
                      >
                        <option value="AUTO">Auto-Calculate (Standard)</option>
                        <option value="PROMOTED">PROMOTED (Next Class)</option>
                        <option value="PASS">PASS (Manual Override)</option>
                        <option value="FAIL">FAIL (Manual Override)</option>
                      </select>
                    </div>
                  </div>

                  <div className="flex items-center gap-1.5 mt-2 flex-wrap">
                    {['1st Unit Test', 'Mid-Term Examination', 'Term Examination', 'Annual Examination'].map(tag => (
                      <button
                        key={tag}
                        type="button"
                        onClick={() => setExamName(tag)}
                        className="px-2 py-0.5 rounded-md text-[10px] bg-surface2 hover:bg-surface2/80 text-text-secondary hover:text-text border border-border cursor-pointer transition-colors"
                      >
                        {tag}
                      </button>
                    ))}
                  </div>
                </div>

                {/* STEP 3: Subjects & Marks Entry */}
                <div className="space-y-2">
                  <div className="space-y-1.5">
                    <div className="flex items-center justify-between">
                      <label className="text-text-secondary font-bold">Step 3: Subjects & Marks (Dropdown Selection)</label>
                      <button
                        type="button"
                        onClick={handleAddSubjectRow}
                        className="text-[11px] text-primary font-bold hover:underline cursor-pointer flex items-center gap-1"
                      >
                        <Plus className="w-3.5 h-3.5" />
                        <span>Add Subject</span>
                      </button>
                    </div>
                    <div className="flex items-center gap-1 flex-wrap">
                      <span className="text-[10px] text-text-muted">Quick Add:</span>
                      {['Mathematics', 'Science', 'English', 'Hindi', 'Social Science', 'Computer'].map(qSub => (
                        <button
                          key={qSub}
                          type="button"
                          onClick={() => {
                            setSubjects(prev => [...prev, { subjectName: qSub, marks: '', totalMarks: 100 }]);
                          }}
                          className="px-2 py-0.5 rounded-md text-[10px] font-bold bg-surface2 hover:bg-primary/10 text-text-secondary hover:text-primary border border-border cursor-pointer transition-colors"
                        >
                          + {qSub}
                        </button>
                      ))}
                    </div>
                  </div>

                  <div className="space-y-2 max-h-56 overflow-y-auto pr-1 custom-scrollbar">
                    {subjects.map((sub, idx) => (
                      <div key={idx} className="flex items-center gap-2 bg-surface2/40 p-2 rounded-xl border border-border">
                        <div className="flex-1">
                          <select
                            value={STANDARD_RESULT_SUBJECTS.includes(sub.subjectName) ? sub.subjectName : 'Other'}
                            onChange={e => {
                              const val = e.target.value;
                              handleSubjectChange(idx, 'subjectName', val === 'Other' ? '' : val);
                            }}
                            className="w-full px-2.5 py-1.5 rounded-lg bg-white border border-border text-text font-bold text-xs"
                          >
                            {STANDARD_RESULT_SUBJECTS.map(s => (
                              <option key={s} value={s}>{s}</option>
                            ))}
                          </select>
                          {!STANDARD_RESULT_SUBJECTS.filter(s => s !== 'Other').includes(sub.subjectName) && (
                            <input
                              type="text"
                              value={sub.subjectName}
                              onChange={e => handleSubjectChange(idx, 'subjectName', e.target.value)}
                              placeholder="Type custom subject name"
                              className="mt-1 w-full px-2 py-1 rounded bg-white border border-border text-text text-xs"
                              required
                            />
                          )}
                        </div>
                        <div className="w-20">
                          <input
                            type="number"
                            min="0"
                            value={sub.marks}
                            onChange={e => handleSubjectChange(idx, 'marks', e.target.value)}
                            placeholder="Marks"
                            className="w-full px-2 py-1.5 rounded-lg bg-white border border-border text-center font-mono font-bold text-text text-xs"
                            required
                          />
                        </div>
                        <span className="text-text-muted font-bold">/</span>
                        <div className="w-20">
                          <input
                            type="number"
                            min="1"
                            value={sub.totalMarks || 100}
                            onChange={e => handleSubjectChange(idx, 'totalMarks', Number(e.target.value) || 100)}
                            placeholder="Total"
                            className="w-full px-2 py-1.5 rounded-lg bg-white border border-border text-center font-mono font-bold text-text text-xs"
                            title="Manually Editable Total Marks"
                            required
                          />
                        </div>
                        {subjects.length > 1 && (
                          <button
                            type="button"
                            onClick={() => handleRemoveSubjectRow(idx)}
                            className="p-1 text-rose-500 hover:bg-rose-50 rounded cursor-pointer"
                          >
                            <X className="w-4 h-4" />
                          </button>
                        )}
                      </div>
                    ))}
                  </div>
                </div>

                {/* Score Summary Live Card & Fail / Promoted Notice */}
                {(() => {
                  const totalMax = subjects.reduce((a, s) => a + (Number(s.totalMarks) || 100), 0);
                  const totalObt = subjects.reduce((a, s) => a + (Number(s.marks) || 0), 0);
                  const pct = totalMax > 0 ? Math.round((totalObt / totalMax) * 100) : 0;
                  const passingCrit = Number(passingMarks) || 33;

                  const failedSubs = subjects.filter(s => {
                    const sMax = Number(s.totalMarks) || 100;
                    const sObt = Number(s.marks) || 0;
                    const minPass = s.passingMarks != null ? Number(s.passingMarks) : Math.round(sMax * (passingCrit / 100));
                    return sObt < minPass;
                  });
                  const failCount = failedSubs.length;

                  let displayStatus = 'PASS';
                  if (resultStatus === 'PROMOTED') displayStatus = 'PROMOTED';
                  else if (failCount > 0 || pct < passingCrit || resultStatus === 'FAIL') displayStatus = 'FAIL';
                  else displayStatus = 'PASS';

                  const grade = pct >= 90 ? 'A+' : pct >= 75 ? 'A' : pct >= 60 ? 'B' : pct >= 45 ? 'C' : pct >= 33 ? 'D' : 'F';

                  return (
                    <div className="space-y-2">
                      <div className="p-3 rounded-xl bg-surface2/60 border border-border flex items-center justify-between text-xs">
                        <div>
                          <span className="text-[10px] text-text-muted block">Score Preview</span>
                          <span className="font-extrabold text-text">{totalObt} / {totalMax} Marks</span>
                        </div>
                        <div className="text-right">
                          <span className="text-base font-black text-primary">{pct}% ({grade})</span>
                          <span className={`block text-[10px] font-bold ${
                            displayStatus === 'PROMOTED' ? 'text-amber-700' : displayStatus === 'PASS' ? 'text-emerald-600' : 'text-rose-600'
                          }`}>
                            {displayStatus === 'PROMOTED' ? 'Promoted to Next Class' : displayStatus === 'PASS' ? 'Passed' : `Failed (${failCount} Subj)`}
                          </span>
                        </div>
                      </div>

                      {/* Promoted Opportunity Alert */}
                      {failCount > 0 && resultStatus !== 'PROMOTED' && (
                        <div className="p-2.5 rounded-xl bg-amber-50 border border-amber-200 text-amber-900 flex items-start gap-2 text-[11px]">
                          <AlertCircle className="w-4 h-4 text-amber-600 flex-shrink-0 mt-0.5" />
                          <div>
                            <span className="font-bold">Student has not passed {failCount} subject(s)</span> ({failedSubs.map(s => s.subjectName || 'Subject').join(', ')}).
                            <p className="mt-0.5 text-[10px] text-amber-800">
                              You can select <strong>PROMOTED (Next Class)</strong> in Result Status if granting grace promotion.
                            </p>
                          </div>
                        </div>
                      )}
                    </div>
                  );
                })()}
              </div>

              <div className="pt-4 border-t border-border flex items-center justify-end gap-2">
                <button
                  type="button"
                  onClick={() => setIsModalOpen(false)}
                  className="px-4 py-2 rounded-xl bg-surface2 hover:bg-border text-text font-bold cursor-pointer transition-colors"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={!selectedStudentId}
                  className="px-5 py-2 rounded-xl bg-primary hover:bg-primary-dark disabled:opacity-50 text-white font-bold cursor-pointer shadow-sm transition-all active:scale-95"
                >
                  Save Result
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
