'use client';

import React, { useState, useEffect, useMemo } from 'react';
import { useSchoolStore } from '../lib/store';
import {
  Award, Plus, Search, Printer, Trash2, Edit,
  GraduationCap, Calendar, Percent, CheckCircle2,
  FileSpreadsheet, X, Save, Share2, ClipboardList, TrendingUp, Sparkles, ChevronRight, BarChart, Download, FileText,
  Users, Check, MessageCircle, AlertCircle, ChevronLeft, Layers, Sliders, ArrowRight, Eye, CheckSquare, Clock, Filter,
  BookOpen
} from 'lucide-react';
import {
  exportExamResultsToExcel,
  exportExamResultsPDF,
  exportSingleResultPDF,
  exportBulkResultMarksheetsPDF,
  openWhatsAppResultShare
} from '../lib/exportUtils';
import CreateExamModal from './CreateExamModal';

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
    students = [],
    results = [],
    exams = [],
    settings = {},
    currentUser = {},
    saveResult,
    deleteResult,
    deleteExam,
    setPrintResultData,
    showToast
  } = useSchoolStore();

  const isPrincipal = currentUser?.role === 'principal' || (!isTeacher && currentUser?.role !== 'parent');
  const assignedClass = (currentUser?.assignedClass || '').trim();

  // Navigation Tabs: 'saved' | 'entry' | 'exams'
  const [activeTab, setActiveTab] = useState('exams');

  // Exam Creation Modal State
  const [isCreateExamOpen, setIsCreateExamOpen] = useState(false);
  const [editingExamData, setEditingExamData] = useState(null);

  // ─────────────────────────────────────────────────────────────
  // 1. SAVED RESULTS TAB STATE
  // ─────────────────────────────────────────────────────────────
  const [searchQuery, setSearchQuery] = useState('');
  const [resultsClassFilter, setResultsClassFilter] = useState(
    isPrincipal || hasAllClassesAccess ? 'all' : (allowedClasses[0] || 'all')
  );

  useEffect(() => {
    if (!isPrincipal && !hasAllClassesAccess && allowedClasses.length === 1) {
      setResultsClassFilter(allowedClasses[0]);
    }
  }, [isPrincipal, hasAllClassesAccess, allowedClasses]);
  const [resultsExamFilter, setResultsExamFilter] = useState('all');
  const [savedViewMode, setSavedViewMode] = useState('cards'); // 'cards' | 'table'

  // Student Matcher
  const findStudent = (r) => {
    if (!r) return null;
    const rId = (r.studentId ? String(r.studentId) : '').trim().toLowerCase();
    const rName = (r.studentName ? String(r.studentName) : '').trim().toLowerCase();
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

  const matchesStudent = (r, s) => {
    if (!r || !s) return false;
    const sId = String(s.id || '').toLowerCase();
    const sStuId = String(s.studentId || '').toLowerCase();
    const sAdm = String(s.admissionNumber || s.admissionNo || '').toLowerCase();
    const sName = String(s.name || '').trim().toLowerCase();
    const rId = String(r.studentId || '').toLowerCase();
    const rName = String(r.studentName || '').trim().toLowerCase();
    return (
      (rId && (rId === sId || rId === sStuId || rId === sAdm)) ||
      (rName && sName && rName === sName)
    );
  };

  // Available classes list from settings and students
  const availableClasses = useMemo(() => {
    if (!isPrincipal && !hasAllClassesAccess) {
      return allowedClasses;
    }
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
    return Array.from(set).filter(Boolean).sort((a, b) => {
      const numA = parseInt(a, 10);
      const numB = parseInt(b, 10);
      if (!isNaN(numA) && !isNaN(numB)) return numA - numB;
      return a.localeCompare(b);
    });
  }, [students, settings, isPrincipal, hasAllClassesAccess, allowedClasses]);

  // Teacher accessible results overall (for total counters and badge counts)
  const scopedResults = useMemo(() => {
    return results.filter(r => {
      const student = findStudent(r);
      const studentClass = student?.className || student?.course || r.className || r.class || '';
      return isPrincipal || hasAllClassesAccess || canAccessClass(studentClass);
    });
  }, [results, students, isPrincipal, hasAllClassesAccess, canAccessClass]);

  // Filter and sort saved results Roll Number wise
  const filteredResults = useMemo(() => {
    return scopedResults
      .filter(r => {
        const student = findStudent(r);
        const studentClass = student?.className || student?.course || r.className || r.class || '';

        if (resultsClassFilter !== 'all' && String(studentClass).trim().toLowerCase() !== resultsClassFilter.toLowerCase()) {
          return false;
        }

        if (resultsExamFilter !== 'all' && String(r.examName || '').trim().toLowerCase() !== resultsExamFilter.toLowerCase()) {
          return false;
        }

        if (!searchQuery.trim()) return true;
        const q = searchQuery.toLowerCase().trim();
        const sName = (student?.name || r.studentName || '').toLowerCase();
        const sId = (student?.studentId || r.studentId || '').toLowerCase();
        const sRoll = String(student?.rollNumber || r.rollNumber || '').toLowerCase();
        const sExam = (r.examName || '').toLowerCase();
        return (
          sExam.includes(q) ||
          sName.includes(q) ||
          sId.includes(q) ||
          sRoll.includes(q)
        );
      })
      .sort((a, b) => {
        const sa = findStudent(a);
        const sb = findStudent(b);
        const rA = String(sa?.rollNumber || a.rollNumber || '').trim();
        const rB = String(sb?.rollNumber || b.rollNumber || '').trim();
        const nA = parseInt(rA, 10);
        const nB = parseInt(rB, 10);
        if (!isNaN(nA) && !isNaN(nB)) {
          if (nA !== nB) return nA - nB;
        } else if (rA && rB) {
          if (rA !== rB) return rA.localeCompare(rB);
        } else if (rA) {
          return -1;
        } else if (rB) {
          return 1;
        }
        const nameA = sa?.name || a.studentName || '';
        const nameB = sb?.name || b.studentName || '';
        return nameA.localeCompare(nameB);
      });
  }, [results, students, resultsClassFilter, resultsExamFilter, searchQuery]);

  // Overall KPI statistics
  const stats = useMemo(() => {
    let totalScore = 0;
    let passed = 0;
    let failed = 0;
    filteredResults.forEach(r => {
      const subs = r.subjects || [];
      const passCrit = Number(r.passingMarks || 33);
      const totalMax = subs.reduce((a, s) => a + (Number(s.totalMarks) || 100), 0);
      const totalObt = subs.reduce((a, s) => a + (Number(s.marks) || 0), 0);
      const pct = totalMax > 0 ? (totalObt / totalMax) * 100 : 0;

      const hasFailedSub = subs.some(s => {
        const sMax = Number(s.totalMarks) || 100;
        const sObt = Number(s.marks) || 0;
        const minP = s.passingMarks != null ? Number(s.passingMarks) : Math.round(sMax * (passCrit / 100));
        return sObt < minP;
      });

      if (r.status === 'PROMOTED') {
        passed++;
      } else if (r.status === 'FAIL' || hasFailedSub || pct < passCrit) {
        failed++;
      } else {
        passed++;
      }
      totalScore++;
    });

    const passRate = totalScore > 0 ? Math.round((passed / totalScore) * 100) : 0;
    return { total: totalScore, passed, failed, passRate };
  }, [filteredResults]);

  // Open Full-Screen Multi-Page Booklet Marksheet
  const handleOpenMarksheet = (res, index) => {
    const stu = findStudent(res);
    setPrintResultData({
      result: res,
      student: stu,
      allResults: filteredResults,
      currentIndex: index,
      settings
    });
  };

  // WhatsApp Share handler
  const handleWhatsAppShare = async (res, stu) => {
    try {
      showToast(`Preparing WhatsApp Marksheet for ${stu?.name || res.studentName}...`, 'info');
      await openWhatsAppResultShare(res, stu || findStudent(res), settings);
    } catch (e) {
      console.error(e);
      showToast('Error sharing result on WhatsApp', 'error');
    }
  };

  // Delete Result handler
  const handleDeleteResult = async (res) => {
    if (window.confirm(`Are you sure you want to delete result for ${res.studentName} (${res.examName})?`)) {
      await deleteResult(res.id);
      showToast('Result deleted successfully', 'success');
    }
  };

  // ─────────────────────────────────────────────────────────────
  // 2. MARK ENTRY DESK STATE (Matching App 1:1)
  // ─────────────────────────────────────────────────────────────
  const [selectedExamId, setSelectedExamId] = useState('');
  const [bulkExamTitle, setBulkExamTitle] = useState('Term Examination 2026');
  const [bulkClass, setBulkClass] = useState(isPrincipal ? (settings.schoolClasses?.[0] || '10th') : assignedClass);
  const [bulkPassingMarks, setBulkPassingMarks] = useState(33);
  const [isDetailedBreakdownMode, setIsDetailedBreakdownMode] = useState(false);
  const [deskStatusFilter, setDeskStatusFilter] = useState('All'); // 'All' | 'Pending' | 'Completed'
  const [deskSearchQuery, setDeskSearchQuery] = useState('');
  const [deskViewStyle, setDeskViewStyle] = useState('grid'); // 'grid' (table) | 'cards' (mobile touch cards)

  // Multi-subject list for Mark Entry Desk
  const [deskSubjects, setDeskSubjects] = useState([
    { id: 'sub_1', name: 'Mathematics', totalMarks: 100, passingMarks: 33, theoryMax: 80, practicalMax: 20, internalMax: 0 },
    { id: 'sub_2', name: 'Science', totalMarks: 100, passingMarks: 33, theoryMax: 70, practicalMax: 30, internalMax: 0 },
    { id: 'sub_3', name: 'English', totalMarks: 100, passingMarks: 33, theoryMax: 80, practicalMax: 0, internalMax: 20 },
    { id: 'sub_4', name: 'Social Science', totalMarks: 100, passingMarks: 33, theoryMax: 80, practicalMax: 0, internalMax: 20 },
    { id: 'sub_5', name: 'Hindi', totalMarks: 100, passingMarks: 33, theoryMax: 80, practicalMax: 0, internalMax: 20 }
  ]);
  const [activeDeskSubjectId, setActiveDeskSubjectId] = useState('sub_1');

  // markEntries: { [subjectId]: { [studentId]: { marks: '', theory: '', practical: '', internal: '' } } }
  const [markEntries, setMarkEntries] = useState({});
  const [savedRowsMap, setSavedRowsMap] = useState({}); // studentId -> true (visual feedback)

  // Student Mark Entry Modal (for individual scoring on mobile or desktop)
  const [modalStudent, setModalStudent] = useState(null);
  const [modalStudentResult, setModalStudentResult] = useState(null);
  const [modalStudentIndex, setModalStudentIndex] = useState(0);

  // When selected exam changes, auto-populate title, mode, and subjects
  const handleSelectExam = (examId) => {
    setSelectedExamId(examId);
    if (!examId || examId === 'custom') {
      return;
    }
    const found = exams.find(e => e.id === examId);
    if (found) {
      setBulkExamTitle(found.title);
      setIsDetailedBreakdownMode(found.isDetailedMode || false);
      if (found.className && found.className !== 'All Classes' && availableClasses.includes(found.className)) {
        setBulkClass(found.className);
      }
      if (found.subjects && found.subjects.length > 0) {
        const seen = new Set();
        const loadedSubs = [];
        found.subjects.forEach((s, idx) => {
          const name = (s.subjectName || 'Subject').trim();
          if (seen.has(name.toLowerCase())) return;
          seen.add(name.toLowerCase());
          loadedSubs.push({
            id: `sub_${idx}_${Date.now()}`,
            name: name,
            totalMarks: Number(s.totalMarks) || 100,
            passingMarks: Number(s.passingMarks) || 33,
            theoryMax: Number(s.theoryMax) || 100,
            practicalMax: Number(s.practicalMax) || 0,
            internalMax: Number(s.internalMax) || 0
          });
        });
        setDeskSubjects(loadedSubs);
        setActiveDeskSubjectId(loadedSubs[0]?.id || '');
      }
      showToast(`Loaded exam template: ${found.title}`, 'info');
    }
  };

  // Jump from Exams tab directly to Mark Entry Desk for that exam
  const handleJumpToMarkEntry = (exam) => {
    setActiveTab('entry');
    handleSelectExam(exam.id);
  };

  // Students in selected class
  const classStudents = useMemo(() => {
    return students.filter(s => {
      const sClass = s.studentType === 'school' ? s.className : s.course;
      if (!bulkClass || bulkClass === 'All Classes') return true;
      return String(sClass || '').trim().toLowerCase() === String(bulkClass).trim().toLowerCase();
    }).sort((a, b) => {
      const rA = parseInt(a.rollNumber, 10);
      const rB = parseInt(b.rollNumber, 10);
      if (!isNaN(rA) && !isNaN(rB)) return rA - rB;
      return (a.name || '').localeCompare(b.name || '');
    });
  }, [students, bulkClass]);

  // Filtered students for mark entry desk (status + search)
  const deskFilteredStudents = useMemo(() => {
    return classStudents.filter(s => {
      const existing = results.find(r => matchesStudent(r, s) && r.examName === bulkExamTitle);
      if (deskStatusFilter === 'Completed' && !existing) return false;
      if (deskStatusFilter === 'Pending' && existing) return false;

      if (!deskSearchQuery.trim()) return true;
      const q = deskSearchQuery.toLowerCase().trim();
      const sName = (s.name || '').toLowerCase();
      const sRoll = String(s.rollNumber || '').toLowerCase();
      const sId = (s.studentId || '').toLowerCase();
      return sName.includes(q) || sRoll.includes(q) || sId.includes(q);
    });
  }, [classStudents, results, bulkExamTitle, deskStatusFilter, deskSearchQuery]);

  // Sync mark entries from existing results when class / exam / subjects change
  useEffect(() => {
    const initial = {};
    deskSubjects.forEach(bs => {
      initial[bs.id] = {};
      classStudents.forEach(s => {
        const existing = results.find(r => matchesStudent(r, s) && r.examName === bulkExamTitle);
        const subMark = existing?.subjects?.find(sub => sub.subjectName === bs.name);
        if (subMark) {
          const total = subMark.marks != null ? subMark.marks : '';
          const theory = subMark.theoryMarks != null ? subMark.theoryMarks : '';
          const practical = subMark.practicalMarks != null ? subMark.practicalMarks : '';
          const internal = subMark.internalMarks != null ? subMark.internalMarks : '';
          initial[bs.id][s.id] = { marks: total, theory, practical, internal };
        } else {
          initial[bs.id][s.id] = { marks: '', theory: '', practical: '', internal: '' };
        }
      });
    });
    setMarkEntries(initial);
  }, [bulkClass, bulkExamTitle, deskSubjects.map(s => s.name).join(','), results]);

  const handleDeskMarkChange = (subjectId, studentId, field, val) => {
    setMarkEntries(prev => {
      const prevEntry = prev[subjectId]?.[studentId] || { marks: '', theory: '', practical: '', internal: '' };
      const parsedVal = val === '' ? '' : Math.max(0, Number(val));
      const nextEntry = { ...prevEntry, [field]: parsedVal };

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

  // Save single student's marks from desk
  const handleSaveStudentMarks = async (student) => {
    const existing = results.find(r => matchesStudent(r, student) && r.examName === bulkExamTitle);
    let updatedSubjects = existing ? [...existing.subjects] : [];

    deskSubjects.forEach(bs => {
      const entry = markEntries[bs.id]?.[student.id];
      if (!entry) return;

      const maxMarks = Number(bs.totalMarks) || 100;
      const passMarks = Number(bs.passingMarks) || Math.round(maxMarks * 0.33);

      if (isDetailedBreakdownMode) {
        if (entry.theory === '' && entry.practical === '' && entry.internal === '' && entry.marks === '') return;
        const theory = Number(entry.theory) || 0;
        const practical = Number(entry.practical) || 0;
        const internal = Number(entry.internal) || 0;
        const total = theory + practical + internal;

        const subIndex = updatedSubjects.findIndex(sub => sub.subjectName === bs.name);
        const subData = {
          subjectName: bs.name,
          marks: total,
          totalMarks: maxMarks,
          passingMarks: passMarks,
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
          passingMarks: passMarks,
          theoryMarks: total,
          practicalMarks: 0,
          internalMarks: 0
        };
        if (subIndex >= 0) updatedSubjects[subIndex] = subData;
        else updatedSubjects.push(subData);
      }
    });

    if (updatedSubjects.length === 0) {
      showToast('Please enter marks for at least one subject.', 'error');
      return;
    }

    const totalObtained = updatedSubjects.reduce((a, s) => a + (Number(s.marks) || 0), 0);
    const grandMax = updatedSubjects.reduce((a, s) => a + (Number(s.totalMarks) || 100), 0);
    const pct = grandMax > 0 ? (totalObtained / grandMax) * 100 : 0;
    const hasFailSub = updatedSubjects.some(s => {
      const m = Number(s.marks) || 0;
      const minP = Number(s.passingMarks) || Math.round((Number(s.totalMarks) || 100) * 0.33);
      return m < minP;
    });

    const status = (hasFailSub || pct < bulkPassingMarks) ? 'FAIL' : 'PASS';

    const payload = {
      id: existing?.id,
      studentId: student.studentId || student.id,
      studentName: student.name,
      rollNumber: student.rollNumber || '',
      className: student.className || student.course || bulkClass,
      section: student.section || 'A',
      fatherName: student.fatherName || '',
      motherName: student.motherName || '',
      admissionNumber: student.admissionNumber || student.admissionNo || '',
      academicYear: student.session || settings.currentSession || '2026-27',
      examName: bulkExamTitle,
      passingMarks: bulkPassingMarks,
      status: existing?.status === 'PROMOTED' ? 'PROMOTED' : status,
      isDetailedMode: isDetailedBreakdownMode,
      subjects: updatedSubjects
    };

    await saveResult(payload);
    setSavedRowsMap(prev => ({ ...prev, [student.id]: true }));
    setTimeout(() => {
      setSavedRowsMap(prev => ({ ...prev, [student.id]: false }));
    }, 2500);

    showToast(`✓ Marks saved for ${student.name}`, 'success');
  };

  // Save All Filtered Students at Once
  const handleSaveAllClassMarks = async () => {
    let count = 0;
    for (const student of deskFilteredStudents) {
      const hasMarks = deskSubjects.some(bs => {
        const e = markEntries[bs.id]?.[student.id];
        return e && (e.marks !== '' || e.theory !== '');
      });
      if (hasMarks) {
        await handleSaveStudentMarks(student);
        count++;
      }
    }
    showToast(`Successfully saved marks for ${count} students!`, 'success');
  };

  // Open Individual Student Mark Entry Modal (matching student_mark_entry_screen.dart)
  const handleOpenIndividualStudentModal = (student, index) => {
    const existing = results.find(r => matchesStudent(r, student) && r.examName === bulkExamTitle);
    setModalStudent(student);
    setModalStudentResult(existing || null);
    setModalStudentIndex(index);
  };

  // ─────────────────────────────────────────────────────────────
  // RENDER
  // ─────────────────────────────────────────────────────────────
  return (
    <div className="space-y-4 sm:space-y-6 animate-in fade-in duration-200">

      {/* TOP HEADER & TABS NAVIGATION */}
      <div className="bg-white rounded-2xl p-4 sm:p-5 shadow-xs border border-slate-200 flex flex-col md:flex-row items-start md:items-center justify-between gap-4">
        <div>
          <div className="flex items-center gap-2">
            <div className="w-9 h-9 rounded-xl bg-indigo-50 border border-indigo-100 flex items-center justify-center text-indigo-700">
              <Award className="w-5 h-5" />
            </div>
            <div>
              <h1 className="text-xl sm:text-2xl font-black text-slate-900 tracking-tight">Academic Results & Exams</h1>
              <p className="text-xs text-slate-500 font-medium">Exams creation, fast class mark entry, and official marksheets</p>
            </div>
          </div>
        </div>

        {/* Responsive Segmented Tabs */}
        <div className="flex items-center p-1 bg-slate-100 rounded-xl border border-slate-200 w-full md:w-auto overflow-x-auto gap-1">
          <button
            onClick={() => setActiveTab('exams')}
            className={`flex-1 md:flex-none px-4 py-2 rounded-lg text-xs font-bold transition-all cursor-pointer flex items-center justify-center gap-1.5 whitespace-nowrap ${
              activeTab === 'exams'
                ? 'bg-[#1E3A8A] text-white shadow-xs'
                : 'text-slate-600 hover:text-slate-900'
            }`}
          >
            <BookOpen className="w-3.5 h-3.5" />
            <span>Exams</span>
            <span className={`ml-1 px-1.5 py-0.2 rounded-full text-[10px] font-black ${activeTab === 'exams' ? 'bg-white/20 text-white' : 'bg-indigo-50 text-indigo-700'}`}>
              {exams.length}
            </span>
          </button>

          <button
            onClick={() => setActiveTab('saved')}
            className={`flex-1 md:flex-none px-4 py-2 rounded-lg text-xs font-bold transition-all cursor-pointer flex items-center justify-center gap-1.5 whitespace-nowrap ${
              activeTab === 'saved'
                ? 'bg-[#1E3A8A] text-white shadow-xs'
                : 'text-slate-600 hover:text-slate-900'
            }`}
          >
            <CheckSquare className="w-3.5 h-3.5" />
            <span>Results</span>
            <span className={`ml-1 px-1.5 py-0.2 rounded-full text-[10px] font-black ${activeTab === 'saved' ? 'bg-white/20 text-white' : 'bg-indigo-50 text-indigo-700'}`}>
              {scopedResults.length}
            </span>
          </button>

          {activeTab === 'entry' && (
            <div className="flex items-center gap-1.5 bg-[#1E3A8A] text-white px-3 py-1.5 rounded-lg text-xs font-bold shadow-xs whitespace-nowrap">
              <Edit className="w-3.5 h-3.5 text-amber-300" />
              <span>Mark Entry Desk</span>
              <button
                type="button"
                onClick={() => setActiveTab('exams')}
                className="ml-1 p-0.5 hover:bg-white/20 rounded text-white/80 hover:text-white cursor-pointer"
                title="Back to Exams"
              >
                <X className="w-3 h-3" />
              </button>
            </div>
          )}
        </div>
      </div>

      {/* ═════════════════════════════════════════════════════════ */}
      {/* TAB 1: SAVED RESULTS                                      */}
      {/* ═════════════════════════════════════════════════════════ */}
      {activeTab === 'saved' && (
        <div className="space-y-4">

          {/* Quick KPI Strip (Matching Mobile App Result Dashboard) */}
          <div className="grid grid-cols-2 lg:grid-cols-4 gap-2.5 sm:gap-4">
            <div className="bg-white p-3.5 sm:p-4 rounded-xl border border-slate-200 shadow-xs flex items-center justify-between">
              <div>
                <p className="text-[11px] text-slate-500 font-bold uppercase tracking-wider">Total Evaluated</p>
                <h3 className="text-xl sm:text-2xl font-black text-slate-900 mt-0.5">{stats.total}</h3>
              </div>
              <div className="w-10 h-10 rounded-xl bg-indigo-50 text-indigo-700 flex items-center justify-center shrink-0">
                <Users className="w-5 h-5" />
              </div>
            </div>

            <div className="bg-white p-3.5 sm:p-4 rounded-xl border border-slate-200 shadow-xs flex items-center justify-between">
              <div>
                <p className="text-[11px] text-emerald-600 font-bold uppercase tracking-wider">Passed</p>
                <h3 className="text-xl sm:text-2xl font-black text-emerald-700 mt-0.5">{stats.passed}</h3>
              </div>
              <div className="w-10 h-10 rounded-xl bg-emerald-50 text-emerald-700 flex items-center justify-center shrink-0">
                <CheckCircle2 className="w-5 h-5" />
              </div>
            </div>

            <div className="bg-white p-3.5 sm:p-4 rounded-xl border border-slate-200 shadow-xs flex items-center justify-between">
              <div>
                <p className="text-[11px] text-rose-600 font-bold uppercase tracking-wider">Needs Improvement</p>
                <h3 className="text-xl sm:text-2xl font-black text-rose-700 mt-0.5">{stats.failed}</h3>
              </div>
              <div className="w-10 h-10 rounded-xl bg-rose-50 text-rose-700 flex items-center justify-center shrink-0">
                <AlertCircle className="w-5 h-5" />
              </div>
            </div>

            <div className="bg-white p-3.5 sm:p-4 rounded-xl border border-slate-200 shadow-xs flex items-center justify-between">
              <div>
                <p className="text-[11px] text-indigo-600 font-bold uppercase tracking-wider">Pass Rate</p>
                <h3 className="text-xl sm:text-2xl font-black text-indigo-900 mt-0.5">{stats.passRate}%</h3>
              </div>
              <div className="w-10 h-10 rounded-xl bg-indigo-50 text-indigo-700 flex items-center justify-center shrink-0">
                <TrendingUp className="w-5 h-5" />
              </div>
            </div>
          </div>

          {/* Filter Bar & View Toggles */}
          <div className="bg-white p-3 sm:p-4 rounded-xl border border-slate-200 shadow-xs flex flex-col md:flex-row items-stretch md:items-center justify-between gap-3">
            
            {/* Search + Dropdowns */}
            <div className="flex flex-col sm:flex-row items-stretch sm:items-center gap-2 flex-1">
              <div className="relative flex-1">
                <Search className="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
                <input
                  type="text"
                  placeholder="Search student, roll no, exam..."
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  className="w-full pl-9 pr-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-xs text-slate-900 placeholder-slate-400 focus:outline-hidden focus:border-indigo-500"
                />
              </div>

              {/* Class Filter */}
              <select
                value={resultsClassFilter}
                onChange={(e) => setResultsClassFilter(e.target.value)}
                className="px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-xs font-bold text-slate-800 focus:outline-hidden focus:border-indigo-500"
              >
                {(isPrincipal || hasAllClassesAccess || availableClasses.length > 1) && (
                  <option value="all">All Classes</option>
                )}
                {availableClasses.map(c => (
                  <option key={c} value={c}>Class {c}</option>
                ))}
              </select>

              {/* Exam Filter */}
              <select
                value={resultsExamFilter}
                onChange={(e) => setResultsExamFilter(e.target.value)}
                className="px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-xs font-bold text-slate-800 focus:outline-hidden focus:border-indigo-500"
              >
                <option value="all">All Exams</option>
                {Array.from(new Set(results.map(r => r.examName).filter(Boolean))).map(exName => (
                  <option key={exName} value={exName}>{exName}</option>
                ))}
              </select>
            </div>

            {/* Actions: View Toggle + Excel/PDF Export */}
            <div className="flex items-center gap-1.5 shrink-0 self-end md:self-auto">
              
              {/* Cards vs Table View Toggle */}
              <div className="p-1 bg-slate-100 rounded-xl border border-slate-200 flex items-center">
                <button
                  onClick={() => setSavedViewMode('cards')}
                  className={`p-1.5 rounded-lg text-xs font-bold transition-all cursor-pointer ${
                    savedViewMode === 'cards' ? 'bg-white text-indigo-900 shadow-xs' : 'text-slate-500 hover:text-slate-800'
                  }`}
                  title="App Cards View"
                >
                  <Layers className="w-4 h-4" />
                </button>
                <button
                  onClick={() => setSavedViewMode('table')}
                  className={`p-1.5 rounded-lg text-xs font-bold transition-all cursor-pointer ${
                    savedViewMode === 'table' ? 'bg-white text-indigo-900 shadow-xs' : 'text-slate-500 hover:text-slate-800'
                  }`}
                  title="Desktop Spreadsheet Table"
                >
                  <FileSpreadsheet className="w-4 h-4" />
                </button>
              </div>

              {/* Excel Export */}
              <button
                onClick={() => exportExamResultsToExcel(filteredResults, students, settings)}
                className="p-2 sm:px-3 sm:py-2 rounded-xl bg-emerald-50 hover:bg-emerald-100 text-emerald-700 font-bold text-xs border border-emerald-200 shadow-xs flex items-center gap-1 cursor-pointer transition-all active:scale-95"
                title="Export Results to Excel"
              >
                <Download className="w-3.5 h-3.5" />
                <span className="hidden sm:inline">Excel</span>
              </button>

              {/* PDF 1: Results List (Tabulation Register PDF) */}
              <button
                onClick={() => exportExamResultsPDF(filteredResults, students, settings, resultsExamFilter !== 'all' ? resultsExamFilter : 'Annual Examination')}
                className="p-2 sm:px-3 sm:py-2 rounded-xl bg-blue-50 hover:bg-blue-100 text-blue-900 font-bold text-xs border border-blue-200 shadow-xs flex items-center gap-1 cursor-pointer transition-all active:scale-95"
                title="Download Results List (Tabulation Register PDF)"
              >
                <FileText className="w-3.5 h-3.5" />
                <span className="hidden sm:inline">Results List</span>
              </button>

              {/* PDF 2: Bulk All Student Marksheets PDF */}
              <button
                onClick={async () => {
                  if (filteredResults.length === 0) {
                    showToast('No results available to download', 'info');
                    return;
                  }
                  try {
                    showToast(`Generating bulk marksheets for ${filteredResults.length} students...`, 'info');
                    await exportBulkResultMarksheetsPDF(filteredResults, students, settings, resultsExamFilter !== 'all' ? resultsExamFilter : 'Annual Examination');
                    showToast('Bulk marksheets PDF downloaded successfully!', 'success');
                  } catch (e) {
                    console.error(e);
                    showToast('Error downloading bulk marksheets', 'error');
                  }
                }}
                className="p-2 sm:px-3 sm:py-2 rounded-xl bg-[#1E3A8A] hover:bg-[#162a65] text-white font-bold text-xs shadow-xs flex items-center gap-1 cursor-pointer transition-all active:scale-95"
                title={`Download all ${filteredResults.length} student marksheets in one combined PDF`}
              >
                <Printer className="w-3.5 h-3.5 text-amber-300" />
                <span className="hidden sm:inline">Bulk Marksheets</span>
              </button>
            </div>
          </div>

          {/* RESULTS CONTENT: CARDS VIEW VS TABLE VIEW */}
          {filteredResults.length === 0 ? (
            <div className="bg-white rounded-2xl p-8 sm:p-12 text-center border border-slate-200 shadow-xs">
              <div className="w-14 h-14 rounded-2xl bg-indigo-50 text-indigo-700 flex items-center justify-center mx-auto mb-3">
                <Award className="w-7 h-7" />
              </div>
              <h3 className="text-base font-bold text-slate-800">No examination results found</h3>
              <p className="text-xs text-slate-500 max-w-sm mx-auto mt-1 mb-4">
                No results match your search or filter. You can enter class marks or create a new exam right now.
              </p>
              <button
                onClick={() => setActiveTab('exams')}
                className="px-4 py-2 rounded-xl bg-[#1E3A8A] hover:bg-[#162a65] text-white font-bold text-xs shadow-xs inline-flex items-center gap-1.5 cursor-pointer"
              >
                <BookOpen className="w-4 h-4" />
                <span>Go to Exams</span>
              </button>
            </div>
          ) : savedViewMode === 'cards' ? (
            
            /* ── CARDS VIEW (Matching Mobile App 1:1) ── */
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-3 sm:gap-4">
              {filteredResults.map((res, idx) => {
                const stu = findStudent(res);
                const subs = res.subjects || [];
                const totalObt = subs.reduce((a, s) => a + (Number(s.marks) || 0), 0);
                const grandMax = subs.reduce((a, s) => a + (Number(s.totalMarks) || 100), 0);
                const pct = grandMax > 0 ? (totalObt / grandMax * 100).toFixed(1) : '0.0';
                const passCrit = Number(res.passingMarks || 33);

                const failedSubs = subs.filter(s => {
                  const sMax = Number(s.totalMarks) || 100;
                  const sObt = Number(s.marks) || 0;
                  const minP = s.passingMarks != null ? Number(s.passingMarks) : Math.round(sMax * (passCrit / 100));
                  return sObt < minP;
                });
                const isPass = res.status === 'PROMOTED' ? true : (res.status !== 'FAIL' && failedSubs.length === 0 && Number(pct) >= passCrit);
                const grade = Number(pct) >= 90 ? 'A+' : Number(pct) >= 80 ? 'A' : Number(pct) >= 70 ? 'B+' : Number(pct) >= 60 ? 'B' : Number(pct) >= 50 ? 'C' : Number(pct) >= 40 ? 'D' : 'F';

                return (
                  <div
                    key={res.id || idx}
                    className="bg-white rounded-2xl border border-slate-200 shadow-xs hover:shadow-md transition-all p-4 flex flex-col justify-between group relative overflow-hidden"
                  >
                    {/* Top strip */}
                    <div>
                      <div className="flex items-start justify-between gap-2 mb-3">
                        <div className="flex items-center gap-2.5 min-w-0">
                          {/* Circular Grade Avatar */}
                          <div className={`w-11 h-11 rounded-2xl flex items-center justify-center font-black text-sm shrink-0 border ${
                            grade === 'A+' || grade === 'A'
                              ? 'bg-emerald-50 text-emerald-700 border-emerald-200'
                              : grade === 'B+' || grade === 'B'
                              ? 'bg-indigo-50 text-indigo-700 border-indigo-200'
                              : grade === 'C' || grade === 'D'
                              ? 'bg-amber-50 text-amber-700 border-amber-200'
                              : 'bg-rose-50 text-rose-700 border-rose-200'
                          }`}>
                            {grade}
                          </div>

                          <div className="min-w-0">
                            <h4 className="text-sm font-extrabold text-slate-900 truncate leading-tight group-hover:text-indigo-900 transition-colors">
                              {stu?.name || res.studentName}
                            </h4>
                            <p className="text-[11px] text-slate-500 font-medium truncate mt-0.5">
                              Roll No: <strong className="text-slate-800">{stu?.rollNumber || res.rollNumber || '—'}</strong> • Class {stu?.className || res.className || '10th'}
                            </p>
                          </div>
                        </div>

                        {/* Status Badge */}
                        <span className={`text-[10px] font-black px-2 py-0.5 rounded-full shrink-0 ${
                          res.status === 'PROMOTED'
                            ? 'bg-amber-100 text-amber-800 border border-amber-200'
                            : isPass
                            ? 'bg-emerald-100 text-emerald-800 border border-emerald-200'
                            : 'bg-rose-100 text-rose-800 border border-rose-200'
                        }`}>
                          {res.status === 'PROMOTED' ? 'PROMOTED' : isPass ? 'PASSED' : 'NEEDS IMPROVEMENT'}
                        </span>
                      </div>

                      {/* Exam & Score Metrics */}
                      <div className="p-2.5 rounded-xl bg-slate-50 border border-slate-100 space-y-1.5 text-xs mb-3">
                        <div className="flex items-center justify-between text-slate-500 text-[11px]">
                          <span className="truncate">{res.examName}</span>
                          <span className="font-mono text-slate-400 font-medium">{res.academicYear || '2026-27'}</span>
                        </div>

                        <div className="flex items-center justify-between pt-1 border-t border-slate-200/60">
                          <div>
                            <span className="text-[10px] uppercase font-bold text-slate-400 block">Marks</span>
                            <span className="font-black text-slate-900 text-sm">
                              {totalObt} <span className="text-slate-400 font-normal text-xs">/ {grandMax}</span>
                            </span>
                          </div>

                          <div className="text-right">
                            <span className="text-[10px] uppercase font-bold text-slate-400 block">Percentage</span>
                            <span className={`font-black text-sm ${isPass ? 'text-indigo-950' : 'text-rose-600'}`}>
                              {pct}%
                            </span>
                          </div>
                        </div>
                      </div>
                    </div>

                    {/* Bottom Action Buttons */}
                    <div className="flex items-center justify-between gap-1 pt-2 border-t border-slate-100">
                      
                      {/* View Marksheet (Triggers Full-Screen Multi-Page Booklet) */}
                      <button
                        onClick={() => handleOpenMarksheet(res, idx)}
                        className="flex-1 py-1.5 px-2 rounded-lg bg-indigo-900 hover:bg-indigo-950 text-white font-bold text-xs flex items-center justify-center gap-1 cursor-pointer transition-all active:scale-95 shadow-xs"
                        title="View Official Student Marksheet Booklet"
                      >
                        <Eye className="w-3.5 h-3.5" />
                        <span>Marksheet</span>
                      </button>

                      {/* WhatsApp Share */}
                      <button
                        onClick={() => handleWhatsAppShare(res, stu)}
                        className="p-1.5 rounded-lg bg-emerald-50 hover:bg-emerald-100 text-emerald-700 border border-emerald-200 cursor-pointer transition-all active:scale-95"
                        title="Share on WhatsApp"
                      >
                        <Share2 className="w-3.5 h-3.5" />
                      </button>

                      {/* Download PDF */}
                      <button
                        onClick={() => exportSingleResultPDF(res, stu, settings)}
                        className="p-1.5 rounded-lg bg-slate-100 hover:bg-slate-200 text-slate-700 cursor-pointer transition-all active:scale-95"
                        title="Download Marksheet PDF"
                      >
                        <Download className="w-3.5 h-3.5" />
                      </button>

                      {/* Delete */}
                      <button
                        onClick={() => handleDeleteResult(res)}
                        className="p-1.5 rounded-lg hover:bg-rose-50 text-slate-400 hover:text-rose-600 cursor-pointer transition-all active:scale-95"
                        title="Delete Result"
                      >
                        <Trash2 className="w-3.5 h-3.5" />
                      </button>
                    </div>

                  </div>
                );
              })}
            </div>
          ) : (
            
            /* ── SPREADSHEET TABLE VIEW (For Desktop Power Users) ── */
            <div className="bg-white rounded-2xl border border-slate-200 shadow-xs overflow-hidden">
              <div className="overflow-x-auto">
                <table className="w-full text-xs text-left border-collapse min-w-[700px]">
                  <thead className="bg-slate-50 text-slate-700 font-bold border-b border-slate-200 text-[11px] uppercase tracking-wider">
                    <tr>
                      <th className="p-3 text-center w-12">Roll</th>
                      <th className="p-3">Student Name</th>
                      <th className="p-3">Class</th>
                      <th className="p-3">Exam Name</th>
                      <th className="p-3 text-center">Marks</th>
                      <th className="p-3 text-center">Percentage</th>
                      <th className="p-3 text-center">Grade</th>
                      <th className="p-3 text-center">Status</th>
                      <th className="p-3 text-right">Actions</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-100">
                    {filteredResults.map((res, idx) => {
                      const stu = findStudent(res);
                      const subs = res.subjects || [];
                      const totalObt = subs.reduce((a, s) => a + (Number(s.marks) || 0), 0);
                      const grandMax = subs.reduce((a, s) => a + (Number(s.totalMarks) || 100), 0);
                      const pct = grandMax > 0 ? (totalObt / grandMax * 100).toFixed(1) : '0.0';
                      const isPass = res.status === 'PROMOTED' ? true : res.status !== 'FAIL' && Number(pct) >= 33;
                      const grade = Number(pct) >= 90 ? 'A+' : Number(pct) >= 80 ? 'A' : Number(pct) >= 70 ? 'B+' : Number(pct) >= 60 ? 'B' : Number(pct) >= 50 ? 'C' : Number(pct) >= 40 ? 'D' : 'F';

                      return (
                        <tr key={res.id || idx} className="hover:bg-slate-50 transition-colors">
                          <td className="p-3 text-center font-mono font-bold text-slate-700">
                            {stu?.rollNumber || res.rollNumber || idx + 1}
                          </td>
                          <td className="p-3">
                            <span className="font-extrabold text-slate-900 block">{stu?.name || res.studentName}</span>
                            <span className="text-[10px] text-slate-400">{stu?.studentId || res.studentId}</span>
                          </td>
                          <td className="p-3 font-medium text-slate-700">{stu?.className || res.className || '10th'}</td>
                          <td className="p-3 text-slate-600">{res.examName}</td>
                          <td className="p-3 text-center font-black text-slate-900">{totalObt} / {grandMax}</td>
                          <td className="p-3 text-center font-bold text-indigo-950">{pct}%</td>
                          <td className="p-3 text-center font-black text-indigo-900">{grade}</td>
                          <td className="p-3 text-center">
                            <span className={`text-[10px] font-black px-2 py-0.5 rounded-full ${
                              res.status === 'PROMOTED' ? 'bg-amber-100 text-amber-800' : isPass ? 'bg-emerald-100 text-emerald-800' : 'bg-rose-100 text-rose-800'
                            }`}>
                              {res.status === 'PROMOTED' ? 'PROMOTED' : isPass ? 'PASS' : 'NEEDS IMPROVEMENT'}
                            </span>
                          </td>
                          <td className="p-3 text-right">
                            <div className="flex items-center justify-end gap-1.5">
                              <button
                                onClick={() => handleOpenMarksheet(res, idx)}
                                className="px-2.5 py-1 rounded-lg bg-indigo-900 hover:bg-indigo-950 text-white font-bold text-[11px] inline-flex items-center gap-1 cursor-pointer shadow-xs"
                              >
                                <Eye className="w-3 h-3" />
                                <span>Marksheet</span>
                              </button>
                              <button
                                onClick={() => handleWhatsAppShare(res, stu)}
                                className="p-1 rounded-lg hover:bg-emerald-50 text-emerald-700 cursor-pointer"
                                title="WhatsApp"
                              >
                                <Share2 className="w-3.5 h-3.5" />
                              </button>
                              <button
                                onClick={() => handleDeleteResult(res)}
                                className="p-1 rounded-lg hover:bg-rose-50 text-rose-600 cursor-pointer"
                                title="Delete"
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

        </div>
      )}

      {/* ═════════════════════════════════════════════════════════ */}
      {/* TAB 2: MARK ENTRY DESK (Matching Mobile App 1:1)          */}
      {/* ═════════════════════════════════════════════════════════ */}
      {activeTab === 'entry' && (
        <div className="space-y-4">

          {/* Desk Top Navigation Header */}
          <div className="bg-white p-3 sm:p-4 rounded-2xl border border-slate-200 shadow-xs flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3">
            <div className="flex items-center gap-2">
              <button
                type="button"
                onClick={() => setActiveTab('exams')}
                className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-slate-100 hover:bg-slate-200 text-slate-800 font-bold text-xs transition-all cursor-pointer shadow-xs active:scale-95"
              >
                <ChevronLeft className="w-4 h-4" />
                <span>Back to Exams</span>
              </button>
              <div className="h-4 w-px bg-slate-200 hidden sm:block" />
              <div className="min-w-0">
                <span className="text-xs font-black text-slate-900 block truncate">
                  Mark Entry Desk
                </span>
                <span className="text-[11px] text-slate-500 font-medium truncate block">
                  {bulkExamTitle} • Class {bulkClass}
                </span>
              </div>
            </div>

            <div className="flex items-center gap-2 w-full sm:w-auto justify-end">
              <button
                type="button"
                onClick={() => setActiveTab('saved')}
                className="px-3 py-1.5 rounded-xl bg-indigo-50 hover:bg-indigo-100 text-indigo-900 font-bold text-xs border border-indigo-200 flex items-center gap-1.5 cursor-pointer shadow-xs"
              >
                <Award className="w-3.5 h-3.5" />
                <span>View Results ({scopedResults.length})</span>
              </button>
            </div>
          </div>

          {/* Desk Top Configuration Controls */}
          <div className="bg-white p-3.5 sm:p-5 rounded-2xl border border-slate-200 shadow-xs space-y-3.5">
            
            {/* Row 1: Exam Selector & Class Selector (Retained) */}
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3">
              
              {/* Exam Selector */}
              <div>
                <label className="text-[11px] font-bold uppercase text-slate-500 block mb-1">
                  1. Select Exam / Test
                </label>
                <div className="flex items-center gap-1.5">
                  <select
                    value={selectedExamId}
                    onChange={(e) => handleSelectExam(e.target.value)}
                    className="flex-1 px-3 py-2 bg-slate-50 border border-slate-300 rounded-xl text-xs font-bold text-slate-900 focus:outline-hidden focus:border-indigo-500"
                  >
                    <option value="">Custom Exam Name</option>
                    {exams.map(ex => (
                      <option key={ex.id} value={ex.id}>
                        {ex.title} {ex.className !== 'All Classes' ? `(${ex.className})` : ''}
                      </option>
                    ))}
                  </select>
                  <button
                    onClick={() => {
                      setEditingExamData(null);
                      setIsCreateExamOpen(true);
                    }}
                    className="p-2 rounded-xl bg-indigo-50 hover:bg-indigo-100 text-indigo-700 border border-indigo-200 shrink-0 cursor-pointer"
                    title="Create New Exam"
                  >
                    <Plus className="w-4 h-4" />
                  </button>
                </div>
              </div>

              {/* Exam Title Text Input (Editable) */}
              <div>
                <label className="text-[11px] font-bold uppercase text-slate-500 block mb-1">
                  Exam Title on Marksheet
                </label>
                <input
                  type="text"
                  value={bulkExamTitle}
                  onChange={(e) => setBulkExamTitle(e.target.value)}
                  className="w-full px-3 py-2 bg-slate-50 border border-slate-300 rounded-xl text-xs font-bold text-slate-900 focus:outline-hidden focus:border-indigo-500"
                  placeholder="e.g. Annual Examination 2026-27"
                />
              </div>

              {/* Class Selector (CRITICAL: RETAINED IN STATE) */}
              <div>
                <label className="text-[11px] font-bold uppercase text-slate-500 block mb-1">
                  2. Select Class / Standard
                </label>
                <select
                  value={bulkClass}
                  onChange={(e) => setBulkClass(e.target.value)}
                  className="w-full px-3 py-2 bg-slate-50 border border-slate-300 rounded-xl text-xs font-bold text-indigo-950 focus:outline-hidden focus:border-indigo-500"
                >
                  <option value="All Classes">All Classes ({students.length})</option>
                  {availableClasses.map(c => {
                    const cCount = students.filter(s => (s.className === c || s.course === c)).length;
                    return (
                      <option key={c} value={c}>Class {c} ({cCount} Students)</option>
                    );
                  })}
                </select>
              </div>

              {/* Mode Toggle & Passing Criteria */}
              <div>
                <label className="text-[11px] font-bold uppercase text-slate-500 block mb-1">
                  Scoring Mode
                </label>
                <div className="flex items-center gap-1.5">
                  <button
                    type="button"
                    onClick={() => setIsDetailedBreakdownMode(prev => !prev)}
                    className={`flex-1 px-3 py-2 rounded-xl border text-xs font-bold transition-all cursor-pointer ${
                      isDetailedBreakdownMode
                        ? 'bg-indigo-950 text-amber-300 border-indigo-950 shadow-xs'
                        : 'bg-slate-50 text-slate-700 border-slate-300 hover:bg-slate-100'
                    }`}
                  >
                    {isDetailedBreakdownMode ? 'Detailed (Th+Pr+In)' : 'Direct Total Marks'}
                  </button>
                  <div className="w-16 shrink-0">
                    <input
                      type="number"
                      value={bulkPassingMarks}
                      onChange={(e) => setBulkPassingMarks(Number(e.target.value) || 33)}
                      className="w-full px-2 py-2 text-center bg-slate-50 border border-slate-300 rounded-xl text-xs font-bold"
                      title="Passing Percentage %"
                    />
                  </div>
                </div>
              </div>

            </div>

            {/* Row 2: Desk Subject Pills Selector */}
            <div className="pt-2 border-t border-slate-200/70 flex items-center justify-between gap-2 overflow-x-auto">
              <div className="flex items-center gap-1.5 overflow-x-auto py-1">
                <span className="text-[11px] font-bold uppercase text-slate-400 mr-1 shrink-0">Subjects:</span>
                {deskSubjects.map(sub => {
                  const isActive = sub.id === activeDeskSubjectId;
                  return (
                    <button
                      key={sub.id}
                      onClick={() => setActiveDeskSubjectId(sub.id)}
                      className={`px-3 py-1.5 rounded-lg text-xs font-bold transition-all cursor-pointer whitespace-nowrap flex items-center gap-1.5 shrink-0 ${
                        isActive
                          ? 'bg-indigo-900 text-white shadow-xs'
                          : 'bg-slate-100 hover:bg-slate-200 text-slate-700'
                      }`}
                    >
                      <span>{sub.name}</span>
                      <span className={`text-[10px] px-1 rounded-sm ${isActive ? 'bg-indigo-800 text-indigo-200' : 'bg-slate-200 text-slate-600'}`}>
                        {sub.totalMarks}M
                      </span>
                    </button>
                  );
                })}
              </div>

              {/* View Style Switcher for Mobile Phone / Desktop */}
              <div className="flex items-center gap-1 shrink-0">
                <button
                  onClick={() => setDeskViewStyle('grid')}
                  className={`p-1.5 rounded-lg border text-xs font-bold cursor-pointer ${
                    deskViewStyle === 'grid' ? 'bg-indigo-50 text-indigo-700 border-indigo-200' : 'text-slate-500 border-transparent'
                  }`}
                  title="Grid Entry Table"
                >
                  <FileSpreadsheet className="w-4 h-4" />
                </button>
                <button
                  onClick={() => setDeskViewStyle('cards')}
                  className={`p-1.5 rounded-lg border text-xs font-bold cursor-pointer ${
                    deskViewStyle === 'cards' ? 'bg-indigo-50 text-indigo-700 border-indigo-200' : 'text-slate-500 border-transparent'
                  }`}
                  title="Mobile Touch Cards"
                >
                  <Layers className="w-4 h-4" />
                </button>
              </div>
            </div>

            {/* Row 3: Status Filter + Search + Save All Button */}
            <div className="flex flex-col sm:flex-row items-stretch sm:items-center justify-between gap-2 pt-2 border-t border-slate-200/70">
              <div className="flex items-center gap-2 flex-1">
                <div className="relative flex-1 max-w-xs">
                  <Search className="w-3.5 h-3.5 absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
                  <input
                    type="text"
                    placeholder="Search name, roll no..."
                    value={deskSearchQuery}
                    onChange={(e) => setDeskSearchQuery(e.target.value)}
                    className="w-full pl-8 pr-3 py-1.5 bg-slate-50 border border-slate-200 rounded-xl text-xs"
                  />
                </div>

                <div className="flex items-center p-0.5 bg-slate-100 rounded-lg text-xs">
                  {['All', 'Pending', 'Completed'].map(st => (
                    <button
                      key={st}
                      onClick={() => setDeskStatusFilter(st)}
                      className={`px-2.5 py-1 rounded-md font-bold text-[11px] transition-all cursor-pointer ${
                        deskStatusFilter === st ? 'bg-white text-indigo-900 shadow-xs' : 'text-slate-500'
                      }`}
                    >
                      {st}
                    </button>
                  ))}
                </div>
              </div>

              <div className="flex items-center gap-2 shrink-0">
                <span className="text-xs text-slate-500 font-medium">
                  Showing <strong>{deskFilteredStudents.length}</strong> Students
                </span>

                <button
                  onClick={handleSaveAllClassMarks}
                  className="px-3.5 py-1.5 rounded-xl bg-emerald-600 hover:bg-emerald-700 text-white font-bold text-xs shadow-xs flex items-center gap-1.5 cursor-pointer active:scale-95"
                >
                  <Save className="w-3.5 h-3.5" />
                  <span>Save All Class Marks</span>
                </button>
              </div>
            </div>

          </div>

          {/* DESK MAIN CONTENT: TABLE GRID VS TOUCH CARDS */}
          {deskFilteredStudents.length === 0 ? (
            <div className="bg-white rounded-2xl p-8 text-center border border-slate-200">
              <Users className="w-8 h-8 text-slate-300 mx-auto mb-2" />
              <p className="text-sm font-bold text-slate-700">No students found in {bulkClass}</p>
              <p className="text-xs text-slate-400 mt-1">Please pick another class or clear the search query.</p>
            </div>
          ) : deskViewStyle === 'grid' ? (
            
            /* ── DESKTOP & TABLET FAST INPUT GRID ── */
            <div className="bg-white rounded-2xl border border-slate-200 shadow-xs overflow-hidden">
              <div className="overflow-x-auto">
                <table className="w-full text-xs text-left border-collapse min-w-[760px]">
                  <thead className="bg-slate-50 text-slate-700 font-bold border-b border-slate-200 text-[11px] uppercase tracking-wider">
                    <tr>
                      <th className="p-3 text-center w-12">Roll</th>
                      <th className="p-3 min-w-[160px]">Student Name</th>
                      <th className="p-3">Class</th>
                      
                      {/* Active Subject Header */}
                      <th className="p-3 text-center min-w-[140px] bg-indigo-50/70 text-indigo-950 border-x border-indigo-100">
                        {deskSubjects.find(s => s.id === activeDeskSubjectId)?.name || 'Subject'} Marks
                        <span className="block text-[10px] text-indigo-700 font-normal">
                          Max: {deskSubjects.find(s => s.id === activeDeskSubjectId)?.totalMarks || 100}
                        </span>
                      </th>

                      {/* Live Auto Calculation Columns */}
                      <th className="p-3 text-center w-24">Live Total</th>
                      <th className="p-3 text-center w-20">Live %</th>
                      <th className="p-3 text-center w-16">Grade</th>
                      <th className="p-3 text-center w-20">Status</th>
                      <th className="p-3 text-right w-36">Actions</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-100">
                    {deskFilteredStudents.map((student, idx) => {
                      const entry = markEntries[activeDeskSubjectId]?.[student.id] || { marks: '', theory: '', practical: '', internal: '' };
                      const isRowSaved = savedRowsMap[student.id];

                      // Compute live aggregate total for this student across all desk subjects
                      let liveObt = 0;
                      let liveMax = 0;
                      deskSubjects.forEach(bs => {
                        const se = markEntries[bs.id]?.[student.id];
                        if (se && se.marks !== '') {
                          liveObt += Number(se.marks) || 0;
                          liveMax += Number(bs.totalMarks) || 100;
                        }
                      });
                      const livePct = liveMax > 0 ? ((liveObt / liveMax) * 100).toFixed(0) : '0';
                      const liveGrade = Number(livePct) >= 90 ? 'A+' : Number(livePct) >= 80 ? 'A' : Number(livePct) >= 70 ? 'B+' : Number(livePct) >= 60 ? 'B' : Number(livePct) >= 50 ? 'C' : Number(livePct) >= 40 ? 'D' : 'F';
                      const livePass = Number(livePct) >= bulkPassingMarks;

                      return (
                        <tr
                          key={student.id}
                          className={`hover:bg-slate-50 transition-colors ${isRowSaved ? 'bg-emerald-50/60' : ''}`}
                        >
                          {/* Roll No */}
                          <td className="p-3 text-center font-mono font-bold text-slate-800">
                            {student.rollNumber || idx + 1}
                          </td>

                          {/* Student Profile Info */}
                          <td className="p-3">
                            <span className="font-extrabold text-slate-900 block truncate">{student.name}</span>
                            <span className="text-[10px] text-slate-400 block truncate">
                              Father: {student.fatherName || '—'}
                            </span>
                          </td>

                          {/* Class */}
                          <td className="p-3 text-slate-700 font-medium">
                            {student.className || bulkClass}
                          </td>

                          {/* Active Subject Marks Input Cell */}
                          <td className="p-2.5 text-center bg-indigo-50/30 border-x border-indigo-100/60">
                            {isDetailedBreakdownMode ? (
                              <div className="flex items-center justify-center gap-1">
                                <input
                                  type="number"
                                  placeholder="Th"
                                  value={entry.theory}
                                  onChange={(e) => handleDeskMarkChange(activeDeskSubjectId, student.id, 'theory', e.target.value)}
                                  className="w-12 px-1 py-1 text-center bg-white border border-slate-300 rounded-lg text-xs font-bold"
                                  title="Theory Marks"
                                />
                                <input
                                  type="number"
                                  placeholder="Pr"
                                  value={entry.practical}
                                  onChange={(e) => handleDeskMarkChange(activeDeskSubjectId, student.id, 'practical', e.target.value)}
                                  className="w-12 px-1 py-1 text-center bg-white border border-slate-300 rounded-lg text-xs font-bold"
                                  title="Practical Marks"
                                />
                                <input
                                  type="number"
                                  placeholder="In"
                                  value={entry.internal}
                                  onChange={(e) => handleDeskMarkChange(activeDeskSubjectId, student.id, 'internal', e.target.value)}
                                  className="w-12 px-1 py-1 text-center bg-white border border-slate-300 rounded-lg text-xs font-bold"
                                  title="Internal Marks"
                                />
                              </div>
                            ) : (
                              <div className="flex items-center justify-center">
                                <input
                                  type="number"
                                  placeholder="0"
                                  value={entry.marks}
                                  onChange={(e) => handleDeskMarkChange(activeDeskSubjectId, student.id, 'marks', e.target.value)}
                                  className="w-20 px-2 py-1.5 text-center bg-white border-2 border-indigo-200 focus:border-indigo-600 rounded-lg text-xs font-black text-indigo-950 shadow-xs"
                                />
                              </div>
                            )}
                          </td>

                          {/* Live Total */}
                          <td className="p-3 text-center font-bold text-slate-900">
                            {liveMax > 0 ? `${liveObt}/${liveMax}` : '—'}
                          </td>

                          {/* Live % */}
                          <td className="p-3 text-center font-black text-indigo-950">
                            {liveMax > 0 ? `${livePct}%` : '—'}
                          </td>

                          {/* Live Grade */}
                          <td className="p-3 text-center">
                            {liveMax > 0 ? (
                              <span className="font-black text-indigo-900">{liveGrade}</span>
                            ) : '—'}
                          </td>

                          {/* Live Status */}
                          <td className="p-3 text-center">
                            {liveMax > 0 ? (
                              <span className={`text-[10px] font-black px-2 py-0.5 rounded-full ${
                                livePass ? 'bg-emerald-100 text-emerald-800' : 'bg-rose-100 text-rose-800'
                              }`}>
                                {livePass ? 'PASS' : 'NEEDS IMPROVEMENT'}
                              </span>
                            ) : (
                              <span className="text-[10px] text-slate-400 font-bold">PENDING</span>
                            )}
                          </td>

                          {/* Actions: Save Single + Open Individual Sheet */}
                          <td className="p-3 text-right">
                            <div className="flex items-center justify-end gap-1.5">
                              <button
                                onClick={() => handleSaveStudentMarks(student)}
                                className={`px-2.5 py-1.5 rounded-lg text-xs font-bold transition-all flex items-center gap-1 cursor-pointer active:scale-95 shadow-xs ${
                                  isRowSaved
                                    ? 'bg-emerald-600 text-white'
                                    : 'bg-indigo-900 hover:bg-indigo-950 text-white'
                                }`}
                                title="Save Marks for this Student"
                              >
                                {isRowSaved ? <Check className="w-3.5 h-3.5" /> : <Save className="w-3.5 h-3.5" />}
                                <span>{isRowSaved ? 'Saved' : 'Save'}</span>
                              </button>

                              <button
                                onClick={() => handleOpenIndividualStudentModal(student, idx)}
                                className="p-1.5 rounded-lg bg-slate-100 hover:bg-slate-200 text-slate-700 cursor-pointer"
                                title="Open Detailed Scoring Sheet"
                              >
                                <Sliders className="w-3.5 h-3.5" />
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
          ) : (

            /* ── MOBILE PHONE TOUCH CARDS VIEW ── */
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
              {deskFilteredStudents.map((student, idx) => {
                const existing = results.find(r => matchesStudent(r, student) && r.examName === bulkExamTitle);
                const hasEntered = !!existing;

                return (
                  <div
                    key={student.id}
                    className="bg-white rounded-2xl border border-slate-200 p-3.5 sm:p-4 shadow-xs space-y-3"
                  >
                    <div className="flex items-start justify-between gap-2">
                      <div className="flex items-center gap-2.5 min-w-0">
                        <span className="w-9 h-9 rounded-xl bg-indigo-50 text-indigo-700 font-black text-xs flex items-center justify-center shrink-0 border border-indigo-100">
                          {student.rollNumber || idx + 1}
                        </span>
                        <div className="min-w-0">
                          <h4 className="text-sm font-extrabold text-slate-900 truncate">{student.name}</h4>
                          <p className="text-[11px] text-slate-500 truncate">
                            Class {student.className || bulkClass} • ID: {student.studentId || '—'}
                          </p>
                        </div>
                      </div>

                      <span className={`text-[10px] font-black px-2 py-0.5 rounded-full ${
                        hasEntered ? 'bg-emerald-100 text-emerald-800' : 'bg-slate-100 text-slate-600'
                      }`}>
                        {hasEntered ? 'COMPLETED' : 'PENDING'}
                      </span>
                    </div>

                    {/* Quick Marks summary if existing */}
                    {hasEntered ? (
                      <div className="p-2.5 rounded-xl bg-slate-50 flex items-center justify-between text-xs">
                        <div>
                          <span className="text-[10px] uppercase font-bold text-slate-400 block">Total Marks</span>
                          <span className="font-black text-slate-900">
                            {existing.subjects?.reduce((a, s) => a + (Number(s.marks) || 0), 0)} / {existing.subjects?.reduce((a, s) => a + (Number(s.totalMarks) || 100), 0)}
                          </span>
                        </div>
                        <div className="text-right">
                          <span className="text-[10px] uppercase font-bold text-slate-400 block">Status</span>
                          <span className={`font-black ${existing.status === 'FAIL' ? 'text-rose-600' : 'text-emerald-700'}`}>
                            {existing.status === 'FAIL' ? 'NEEDS IMPROVEMENT' : (existing.status || 'PASS')}
                          </span>
                        </div>
                      </div>
                    ) : (
                      <div className="p-2.5 rounded-xl bg-amber-50/60 border border-amber-100 text-[11px] text-amber-800 font-medium">
                        Marks pending for {bulkExamTitle}
                      </div>
                    )}

                    {/* Action buttons */}
                    <div className="flex items-center gap-2 pt-1 border-t border-slate-100">
                      <button
                        onClick={() => handleOpenIndividualStudentModal(student, idx)}
                        className="flex-1 py-2 px-3 rounded-xl bg-indigo-900 hover:bg-indigo-950 text-white font-bold text-xs flex items-center justify-center gap-1.5 cursor-pointer active:scale-95 shadow-xs"
                      >
                        <Edit className="w-3.5 h-3.5" />
                        <span>{hasEntered ? 'Edit Marks' : 'Enter Marks'}</span>
                      </button>

                      {hasEntered && (
                        <button
                          onClick={() => handleOpenMarksheet(existing, 0)}
                          className="p-2 rounded-xl bg-indigo-50 hover:bg-indigo-100 text-indigo-700 cursor-pointer"
                          title="View Marksheet"
                        >
                          <Eye className="w-4 h-4" />
                        </button>
                      )}
                    </div>
                  </div>
                );
              })}
            </div>
          )}

        </div>
      )}

      {/* ═════════════════════════════════════════════════════════ */}
      {/* TAB 3: EXAMS & TESTS (Create, List, Manage)               */}
      {/* ═════════════════════════════════════════════════════════ */}
      {activeTab === 'exams' && (
        <div className="space-y-4">

          {/* Top Header Bar */}
          <div className="bg-white p-3.5 sm:p-5 rounded-2xl border border-slate-200 shadow-xs flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3">
            <div>
              <h2 className="text-base sm:text-lg font-black text-slate-900">Configured Examinations</h2>
              <p className="text-xs text-slate-500 font-medium">
                Create term exams, define subjects, and set theory & practical criteria
              </p>
            </div>

            <button
              onClick={() => {
                setEditingExamData(null);
                setIsCreateExamOpen(true);
              }}
              className="w-full sm:w-auto px-4 py-2.5 rounded-xl bg-indigo-900 hover:bg-indigo-950 text-white font-bold text-xs shadow-xs flex items-center justify-center gap-1.5 cursor-pointer transition-all active:scale-95"
            >
              <Plus className="w-4 h-4" />
              <span>+ Create New Exam</span>
            </button>
          </div>

          {/* Exam Cards Grid */}
          {exams.length === 0 ? (
            <div className="bg-white rounded-2xl p-8 sm:p-12 text-center border border-slate-200 shadow-xs">
              <div className="w-14 h-14 rounded-2xl bg-indigo-50 text-indigo-700 flex items-center justify-center mx-auto mb-3">
                <BookOpen className="w-7 h-7" />
              </div>
              <h3 className="text-base font-bold text-slate-800">No exams created yet</h3>
              <p className="text-xs text-slate-500 max-w-sm mx-auto mt-1 mb-4">
                Set up your first term or annual examination to start scoring students and issuing official marksheets.
              </p>
              <button
                onClick={() => {
                  setEditingExamData(null);
                  setIsCreateExamOpen(true);
                }}
                className="px-4 py-2.5 rounded-xl bg-indigo-900 hover:bg-indigo-950 text-white font-bold text-xs shadow-xs inline-flex items-center gap-1.5 cursor-pointer"
              >
                <Plus className="w-4 h-4" />
                <span>Create First Exam</span>
              </button>
            </div>
          ) : (
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
              {exams.map(exam => {
                const subCount = exam.subjects?.length || 0;
                const isPublished = exam.status === 'Published';

                return (
                  <div
                    key={exam.id}
                    className="bg-white rounded-2xl border border-slate-200 p-4 sm:p-5 shadow-xs hover:shadow-md transition-all flex flex-col justify-between space-y-4 group"
                  >
                    <div>
                      {/* Top Badges */}
                      <div className="flex items-center justify-between gap-2 mb-2">
                        <span className="text-[10px] font-black uppercase px-2.5 py-0.5 rounded-full bg-indigo-50 text-indigo-700 border border-indigo-100">
                          {exam.term || 'Annual'}
                        </span>
                        <span className={`text-[10px] font-black uppercase px-2.5 py-0.5 rounded-full ${
                          isPublished ? 'bg-emerald-100 text-emerald-800' : 'bg-amber-100 text-amber-800'
                        }`}>
                          {exam.status || 'In Progress'}
                        </span>
                      </div>

                      {/* Exam Title */}
                      <h3 className="text-base font-extrabold text-slate-900 group-hover:text-indigo-900 transition-colors leading-tight">
                        {exam.title}
                      </h3>

                      {/* Meta Pills */}
                      <div className="grid grid-cols-2 gap-2 mt-3 pt-3 border-t border-slate-100 text-xs text-slate-600">
                        <div>
                          <span className="text-[10px] uppercase font-bold text-slate-400 block">Class</span>
                          <span className="font-bold text-slate-800">{exam.className || 'All Classes'}</span>
                        </div>
                        <div>
                          <span className="text-[10px] uppercase font-bold text-slate-400 block">Academic Session</span>
                          <span className="font-bold text-slate-800">{exam.academicYear || '2026-27'}</span>
                        </div>
                        <div>
                          <span className="text-[10px] uppercase font-bold text-slate-400 block">Mode</span>
                          <span className="font-bold text-indigo-950">
                            {exam.isDetailedMode ? 'Detailed (Th+Pr)' : 'Direct Marks'}
                          </span>
                        </div>
                        <div>
                          <span className="text-[10px] uppercase font-bold text-slate-400 block">Subjects</span>
                          <span className="font-bold text-slate-800">{subCount} Configured</span>
                        </div>
                      </div>

                      {/* Subject Preview Tags */}
                      {exam.subjects && exam.subjects.length > 0 && (
                        <div className="mt-3 flex flex-wrap gap-1">
                          {exam.subjects.slice(0, 4).map((s, i) => (
                            <span key={i} className="text-[10px] font-medium px-2 py-0.5 rounded-md bg-slate-100 text-slate-600">
                              {s.subjectName}
                            </span>
                          ))}
                          {exam.subjects.length > 4 && (
                            <span className="text-[10px] font-medium px-2 py-0.5 rounded-md bg-slate-100 text-slate-400">
                              +{exam.subjects.length - 4} more
                            </span>
                          )}
                        </div>
                      )}
                    </div>

                    {/* Bottom Actions */}
                    <div className="flex items-center justify-between gap-2 pt-3 border-t border-slate-100">
                      <button
                        onClick={() => handleJumpToMarkEntry(exam)}
                        className="flex-1 py-2 px-3 rounded-xl bg-indigo-900 hover:bg-indigo-950 text-white font-bold text-xs flex items-center justify-center gap-1.5 cursor-pointer active:scale-95 shadow-xs"
                      >
                        <Edit className="w-3.5 h-3.5" />
                        <span>Enter Marks</span>
                      </button>

                      <button
                        onClick={() => {
                          setEditingExamData(exam);
                          setIsCreateExamOpen(true);
                        }}
                        className="p-2 rounded-xl bg-slate-100 hover:bg-slate-200 text-slate-700 cursor-pointer transition-all active:scale-95"
                        title="Edit Exam Configuration"
                      >
                        <Sliders className="w-4 h-4" />
                      </button>

                      {isPrincipal && (
                        <button
                          onClick={async () => {
                            if (window.confirm(`Delete exam "${exam.title}"? This cannot be undone.`)) {
                              await deleteExam(exam.id);
                              showToast('Exam deleted', 'info');
                            }
                          }}
                          className="p-2 rounded-xl hover:bg-rose-50 text-slate-400 hover:text-rose-600 cursor-pointer transition-all active:scale-95"
                          title="Delete Exam"
                        >
                          <Trash2 className="w-4 h-4" />
                        </button>
                      )}
                    </div>

                  </div>
                );
              })}
            </div>
          )}

        </div>
      )}

      {/* ═════════════════════════════════════════════════════════ */}
      {/* DEDICATED STUDENT MARK ENTRY MODAL                        */}
      {/* (Matches student_mark_entry_screen.dart 1:1)             */}
      {/* ═════════════════════════════════════════════════════════ */}
      {modalStudent && (
        <StudentDetailedMarkEntryModal
          student={modalStudent}
          examTitle={bulkExamTitle}
          examId={selectedExamId}
          subjects={deskSubjects}
          isDetailedMode={isDetailedBreakdownMode}
          passingMarks={bulkPassingMarks}
          existingResult={results.find(r => matchesStudent(r, modalStudent) && r.examName === bulkExamTitle)}
          onClose={() => setModalStudent(null)}
          onSaved={async (savedPayload) => {
            await saveResult(savedPayload);
            showToast(`Marks saved for ${modalStudent.name}!`, 'success');
            setModalStudent(null);
          }}
          onSaveAndNext={async (savedPayload) => {
            await saveResult(savedPayload);
            showToast(`Marks saved for ${modalStudent.name}!`, 'success');
            const nextIdx = modalStudentIndex + 1;
            if (nextIdx < deskFilteredStudents.length) {
              setModalStudentIndex(nextIdx);
              setModalStudent(deskFilteredStudents[nextIdx]);
            } else {
              setModalStudent(null);
            }
          }}
          hasPrev={modalStudentIndex > 0}
          hasNext={modalStudentIndex < deskFilteredStudents.length - 1}
          onPrev={() => {
            if (modalStudentIndex > 0) {
              const prevIdx = modalStudentIndex - 1;
              setModalStudentIndex(prevIdx);
              setModalStudent(deskFilteredStudents[prevIdx]);
            }
          }}
          onNext={() => {
            if (modalStudentIndex < deskFilteredStudents.length - 1) {
              const nextIdx = modalStudentIndex + 1;
              setModalStudentIndex(nextIdx);
              setModalStudent(deskFilteredStudents[nextIdx]);
            }
          }}
        />
      )}

      {/* CREATE / EDIT EXAM MODAL */}
      {isCreateExamOpen && (
        <CreateExamModal
          isOpen={isCreateExamOpen}
          editExam={editingExamData}
          onClose={() => {
            setIsCreateExamOpen(false);
            setEditingExamData(null);
          }}
          onSaved={(newExam) => {
            if (newExam?.id) {
              setSelectedExamId(newExam.id);
            }
          }}
        />
      )}

    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// COMPONENT: INDIVIDUAL STUDENT DETAILED MARK ENTRY MODAL
// Matches mobile app student_mark_entry_screen.dart
// ─────────────────────────────────────────────────────────────
function StudentDetailedMarkEntryModal({
  student,
  examTitle,
  subjects: templateSubjects,
  isDetailedMode: initialDetailedMode,
  passingMarks: initialPassingMarks,
  existingResult,
  onClose,
  onSaved,
  onSaveAndNext,
  hasPrev,
  hasNext,
  onPrev,
  onNext
}) {
  const { settings = {} } = useSchoolStore();

  const [isDetailed, setIsDetailed] = useState(() => {
    if (existingResult) {
      return existingResult.isDetailedMode ||
        existingResult.subjects?.some(s => Number(s.theoryMarks) > 0 || Number(s.practicalMarks) > 0 || Number(s.internalMarks) > 0) || false;
    }
    return initialDetailedMode;
  });

  const [remarks, setRemarks] = useState(existingResult?.remarks || '');
  const [manualStatus, setManualStatus] = useState(existingResult?.status || 'AUTO');

  // Subjects rows state
  const [rows, setRows] = useState(() => {
    if (existingResult?.subjects && existingResult.subjects.length > 0) {
      return existingResult.subjects.map(s => ({
        name: s.subjectName,
        totalMarks: Number(s.totalMarks) || 100,
        passingMarks: Number(s.passingMarks) || 33,
        marks: s.marks != null ? String(s.marks) : '',
        theory: s.theoryMarks != null ? String(s.theoryMarks) : '',
        practical: s.practicalMarks != null ? String(s.practicalMarks) : '',
        internal: s.internalMarks != null ? String(s.internalMarks) : ''
      }));
    }
    return templateSubjects.map(ts => ({
      name: ts.name,
      totalMarks: Number(ts.totalMarks) || 100,
      passingMarks: Number(ts.passingMarks) || 33,
      marks: '',
      theory: '',
      practical: '',
      internal: ''
    }));
  });

  const handleRowChange = (idx, field, val) => {
    setRows(prev => {
      const copy = [...prev];
      const updated = { ...copy[idx], [field]: val };

      if (field === 'theory' || field === 'practical' || field === 'internal') {
        const t = Number(updated.theory) || 0;
        const p = Number(updated.practical) || 0;
        const i = Number(updated.internal) || 0;
        updated.marks = String(t + p + i);
      }
      copy[idx] = updated;
      return copy;
    });
  };

  // Live Calculations
  const grandTotalMarks = rows.reduce((a, r) => a + (Number(r.totalMarks) || 100), 0);
  const totalObtainedMarks = rows.reduce((a, r) => a + (Number(r.marks) || 0), 0);
  const livePct = grandTotalMarks > 0 ? ((totalObtainedMarks / grandTotalMarks) * 100).toFixed(1) : '0.0';
  const liveGrade = Number(livePct) >= 90 ? 'A+' : Number(livePct) >= 80 ? 'A' : Number(livePct) >= 70 ? 'B+' : Number(livePct) >= 60 ? 'B' : Number(livePct) >= 50 ? 'C' : Number(livePct) >= 40 ? 'D' : 'F';

  const failedSubjects = rows.filter(r => {
    const sMax = Number(r.totalMarks) || 100;
    const sObt = Number(r.marks) || 0;
    const sPass = Number(r.passingMarks) || Math.round(sMax * 0.33);
    return sObt < sPass;
  });
  const autoPass = failedSubjects.length === 0 && Number(livePct) >= initialPassingMarks;

  let finalStatus = 'PASS';
  if (manualStatus === 'PROMOTED') finalStatus = 'PROMOTED';
  else if (manualStatus === 'FAIL' || !autoPass) finalStatus = 'FAIL';
  else finalStatus = 'PASS';

  const buildPayload = () => {
    return {
      id: existingResult?.id,
      studentId: student.studentId || student.id,
      studentName: student.name,
      rollNumber: student.rollNumber || '',
      className: student.className || student.course || '',
      section: student.section || 'A',
      fatherName: student.fatherName || '',
      motherName: student.motherName || '',
      admissionNumber: student.admissionNumber || student.admissionNo || '',
      academicYear: student.session || settings?.currentSession || '2026-27',
      examName: examTitle,
      passingMarks: initialPassingMarks,
      status: finalStatus,
      isDetailedMode: isDetailed,
      remarks,
      subjects: rows.map(r => ({
        subjectName: r.name,
        marks: Number(r.marks) || 0,
        totalMarks: Number(r.totalMarks) || 100,
        passingMarks: Number(r.passingMarks) || Math.round((Number(r.totalMarks) || 100) * 0.33),
        theoryMarks: Number(r.theory) || 0,
        practicalMarks: Number(r.practical) || 0,
        internalMarks: Number(r.internal) || 0
      }))
    };
  };

  return (
    <div
      onClick={(e) => {
        if (e.target === e.currentTarget) onClose();
      }}
      className="fixed inset-0 z-50 overflow-y-auto bg-slate-950/80 backdrop-blur-xs p-2 sm:p-4 flex justify-center items-start"
    >
      <div className="bg-white text-slate-900 rounded-2xl w-full max-w-2xl shadow-2xl overflow-hidden my-2 sm:my-6 flex flex-col relative animate-in fade-in zoom-in-95 duration-200">

        {/* Modal Top Header */}
        <div className="px-4 py-3 bg-slate-900 text-white flex items-center justify-between">
          <div className="flex items-center gap-2.5 min-w-0">
            <span className="w-8 h-8 rounded-lg bg-indigo-600 text-white font-black text-xs flex items-center justify-center shrink-0">
              {student.rollNumber || '•'}
            </span>
            <div className="min-w-0">
              <h3 className="text-sm font-black truncate">{student.name}</h3>
              <p className="text-[10px] text-slate-400 truncate">
                Class {student.className} • ID: {student.studentId || '—'} • {examTitle}
              </p>
            </div>
          </div>

          {/* Prev / Next inside modal */}
          <div className="flex items-center gap-1 shrink-0">
            <button
              onClick={onPrev}
              disabled={!hasPrev}
              className="p-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 disabled:opacity-30 disabled:pointer-events-none text-white text-xs cursor-pointer"
              title="Previous Student"
            >
              <ChevronLeft className="w-4 h-4" />
            </button>
            <button
              onClick={onNext}
              disabled={!hasNext}
              className="p-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 disabled:opacity-30 disabled:pointer-events-none text-white text-xs cursor-pointer"
              title="Next Student"
            >
              <ChevronRight className="w-4 h-4" />
            </button>
            <button
              onClick={onClose}
              className="p-1.5 rounded-lg hover:bg-rose-900/60 text-slate-400 hover:text-white ml-1 cursor-pointer"
            >
              <X className="w-4 h-4" />
            </button>
          </div>
        </div>

        {/* Modal Body */}
        <div className="p-4 sm:p-5 overflow-y-auto space-y-4 max-h-[80vh]">

          {/* Mode Switch Pill */}
          <div className="flex items-center justify-between p-2.5 rounded-xl bg-slate-100 text-xs">
            <span className="font-bold text-slate-700">Detailed Components (Theory / Practical / Internal):</span>
            <button
              type="button"
              onClick={() => setIsDetailed(prev => !prev)}
              className={`px-3 py-1 rounded-lg font-bold transition-all text-xs cursor-pointer ${
                isDetailed ? 'bg-indigo-900 text-white shadow-xs' : 'bg-white text-slate-700 border border-slate-300'
              }`}
            >
              {isDetailed ? 'ENABLED' : 'DISABLED'}
            </button>
          </div>

          {/* Subjects Scoring List */}
          <div className="space-y-2">
            <label className="text-[11px] font-bold uppercase text-slate-400 block">
              Enter Marks for each subject
            </label>

            <div className="space-y-2">
              {rows.map((row, idx) => (
                <div
                  key={idx}
                  className="p-3 rounded-xl border border-slate-200 bg-slate-50/60 flex flex-col sm:flex-row sm:items-center justify-between gap-2.5"
                >
                  <div className="min-w-0">
                    <span className="text-xs font-black text-slate-900 block truncate">{row.name}</span>
                    <span className="text-[10px] text-slate-500">
                      Max: {row.totalMarks} • Min Pass: {row.passingMarks}
                    </span>
                  </div>

                  {isDetailed ? (
                    <div className="flex items-center gap-2">
                      <div>
                        <span className="text-[9px] font-bold text-slate-400 block text-center">Theory</span>
                        <input
                          type="number"
                          value={row.theory}
                          placeholder="0"
                          onChange={(e) => handleRowChange(idx, 'theory', e.target.value)}
                          className="w-14 px-2 py-1.5 text-center bg-white border border-slate-300 rounded-lg text-xs font-bold"
                        />
                      </div>
                      <div>
                        <span className="text-[9px] font-bold text-slate-400 block text-center">Practical</span>
                        <input
                          type="number"
                          value={row.practical}
                          placeholder="0"
                          onChange={(e) => handleRowChange(idx, 'practical', e.target.value)}
                          className="w-14 px-2 py-1.5 text-center bg-white border border-slate-300 rounded-lg text-xs font-bold"
                        />
                      </div>
                      <div>
                        <span className="text-[9px] font-bold text-slate-400 block text-center">Internal</span>
                        <input
                          type="number"
                          value={row.internal}
                          placeholder="0"
                          onChange={(e) => handleRowChange(idx, 'internal', e.target.value)}
                          className="w-14 px-2 py-1.5 text-center bg-white border border-slate-300 rounded-lg text-xs font-bold"
                        />
                      </div>
                      <div>
                        <span className="text-[9px] font-bold text-indigo-700 block text-center">Total</span>
                        <span className="w-12 py-1.5 block text-center font-black text-indigo-950 text-xs">
                          {row.marks || 0}
                        </span>
                      </div>
                    </div>
                  ) : (
                    <div className="flex items-center gap-2">
                      <span className="text-xs text-slate-400 font-bold">Marks:</span>
                      <input
                        type="number"
                        value={row.marks}
                        placeholder="0"
                        onChange={(e) => handleRowChange(idx, 'marks', e.target.value)}
                        className="w-24 px-3 py-1.5 text-center bg-white border-2 border-indigo-200 focus:border-indigo-600 rounded-xl text-sm font-black text-indigo-950 shadow-xs"
                      />
                    </div>
                  )}
                </div>
              ))}
            </div>
          </div>

          {/* Live Performance Summary Strip */}
          <div className="p-3.5 rounded-xl border-2 border-indigo-950 bg-indigo-50/50 flex flex-wrap items-center justify-between gap-3 text-xs">
            <div>
              <span className="text-slate-500 block text-[10px] uppercase font-bold">Total Marks</span>
              <span className="text-indigo-950 text-base font-black">
                {totalObtainedMarks} <span className="text-slate-400 font-normal text-xs">/ {grandTotalMarks}</span>
              </span>
            </div>

            <div>
              <span className="text-slate-500 block text-[10px] uppercase font-bold">Percentage</span>
              <span className="text-indigo-950 text-base font-black">{livePct}%</span>
            </div>

            <div>
              <span className="text-slate-500 block text-[10px] uppercase font-bold">Grade</span>
              <span className="text-indigo-900 text-base font-black">{liveGrade}</span>
            </div>

            <div className={`px-3 py-1 rounded-full text-xs font-black uppercase ${
              finalStatus === 'PROMOTED'
                ? 'bg-amber-100 text-amber-800'
                : finalStatus === 'PASS'
                ? 'bg-emerald-100 text-emerald-800'
                : 'bg-rose-100 text-rose-800'
            }`}>
              {finalStatus === 'FAIL' ? 'NEEDS IMPROVEMENT' : finalStatus}
            </div>
          </div>

          {/* Remarks & Manual Status Override */}
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
            <div className="sm:col-span-2">
              <label className="text-[11px] font-bold uppercase text-slate-500 block mb-1">
                Faculty Remarks
              </label>
              <input
                type="text"
                value={remarks}
                onChange={(e) => setRemarks(e.target.value)}
                placeholder="e.g. Excellent performance and active participation"
                className="w-full px-3 py-2 bg-slate-50 border border-slate-300 rounded-xl text-xs font-medium"
              />
            </div>

            <div>
              <label className="text-[11px] font-bold uppercase text-slate-500 block mb-1">
                Status Override
              </label>
              <select
                value={manualStatus}
                onChange={(e) => setManualStatus(e.target.value)}
                className="w-full px-3 py-2 bg-slate-50 border border-slate-300 rounded-xl text-xs font-bold text-slate-800"
              >
                <option value="AUTO">AUTO (Calculated)</option>
                <option value="PASS">PASS</option>
                <option value="FAIL">NEEDS IMPROVEMENT</option>
                <option value="PROMOTED">PROMOTED</option>
              </select>
            </div>
          </div>

        </div>

        {/* Modal Bottom Footer Actions */}
        <div className="p-3 sm:p-4 bg-slate-100 border-t border-slate-200 flex items-center justify-between gap-2">
          <button
            onClick={onClose}
            className="px-4 py-2 rounded-xl bg-slate-200 hover:bg-slate-300 text-slate-700 font-bold text-xs cursor-pointer"
          >
            Cancel
          </button>

          <div className="flex items-center gap-2">
            <button
              onClick={() => onSaved(buildPayload())}
              className="px-4 py-2 rounded-xl bg-indigo-900 hover:bg-indigo-950 text-white font-bold text-xs shadow-xs flex items-center gap-1.5 cursor-pointer active:scale-95"
            >
              <Save className="w-3.5 h-3.5" />
              <span>Save Marks</span>
            </button>

            {hasNext && (
              <button
                onClick={() => onSaveAndNext(buildPayload())}
                className="px-4 py-2 rounded-xl bg-emerald-600 hover:bg-emerald-700 text-white font-bold text-xs shadow-xs flex items-center gap-1.5 cursor-pointer active:scale-95"
              >
                <span>Save & Next</span>
                <ArrowRight className="w-3.5 h-3.5" />
              </button>
            )}
          </div>
        </div>

      </div>
    </div>
  );
}
