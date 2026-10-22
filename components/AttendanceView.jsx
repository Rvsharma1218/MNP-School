'use client';

import React, { useState, useEffect } from 'react';
import { useSchoolStore } from '../lib/store';
import {
  CalendarCheck, CheckCircle2, XCircle, Clock, MessageSquare,
  FileSpreadsheet, Users, GraduationCap, Monitor, ChevronLeft,
  ChevronRight, Filter, Check, X, AlertTriangle, Share2, Printer, ArrowRight, Search, Download, FileText, Calendar,
  MapPin, Navigation
} from 'lucide-react';
import {
  exportAttendanceToExcel,
  openWhatsAppAttendanceAlert,
  exportTodayAttendancePDF,
  printTodayAttendancePDF,
  exportDateRangeAttendancePDF,
  printDateRangeAttendancePDF,
  exportStudentAttendancePDF
} from '../lib/exportUtils';

export default function AttendanceView() {
  const {
    students,
    teachers = [],
    attendance,
    settings,
    currentUser,
    markStudentAttendance,
    bulkMarkAttendance,
    teacherAttendance,
    bulkMarkTeacherAttendance,
    teacherPermissions,
    teacherPunchIns,
    punchInTeacherGeofence,
    showToast
  } = useSchoolStore();

  const lang = settings?.appLanguage || 'en';

  const [selectedTeacherDate, setSelectedTeacherDate] = useState(new Date().toISOString().split('T')[0]);
  const [localTeacherStatus, setLocalTeacherStatus] = useState({});
  const [isSavingTeacherAtt, setIsSavingTeacherAtt] = useState(false);
  const [isPunchingIn, setIsPunchingIn] = useState(false);
  const [punchModalResult, setPunchModalResult] = useState(null);

  useEffect(() => {
    const saved = (teacherAttendance && teacherAttendance[selectedTeacherDate]) || {};
    const initialMap = {};
    (teachers || []).forEach(t => {
      initialMap[t.id || t.teacherId] = saved[t.id] || saved[t.teacherId] || saved[t.authUid] || 'present';
    });
    setLocalTeacherStatus(initialMap);
  }, [selectedTeacherDate, teacherAttendance, teachers]);

  const isPrincipal = currentUser?.role === 'principal';
  const assignedClass = currentUser?.assignedClass && currentUser.assignedClass !== 'none' && currentUser.assignedClass !== 'None' ? currentUser.assignedClass : '';

  const [activeTab, setActiveTab] = useState('daily'); // default directly to daily register for teacher ease
  const [selectedDate, setSelectedDate] = useState(new Date().toISOString().split('T')[0]);
  const [selectedType, setSelectedType] = useState('all'); // 'all' | 'school' | 'computer'
  const [selectedClass, setSelectedClass] = useState(isPrincipal || !assignedClass ? 'all' : assignedClass);
  const [searchQuery, setSearchQuery] = useState('');

  // Auto-switch to teachers tab if navigated from Teacher Profile or query param
  useEffect(() => {
    if (typeof window !== 'undefined') {
      const urlParams = new URLSearchParams(window.location.search);
      const tabParam = urlParams.get('tab');
      const savedTab = localStorage.getItem('attendance_active_tab');
      if (tabParam === 'teachers' || savedTab === 'teachers') {
        setActiveTab('teachers');
        localStorage.removeItem('attendance_active_tab');
      }
    }
  }, []);

  // Auto-filter to specific class if navigated from Classes card
  useEffect(() => {
    if (typeof window !== 'undefined') {
      const target = localStorage.getItem('school_attendance_target_class');
      if (target) {
        setSelectedClass(target);
        localStorage.removeItem('school_attendance_target_class');
      }
    }
  }, []);

  // Reset to assigned class on view mount or role change (if teacher has specific assigned class)
  useEffect(() => {
    if (!isPrincipal && assignedClass && assignedClass !== 'all') {
      setSelectedClass(assignedClass);
    }
  }, [assignedClass, isPrincipal]);

  // Date Range state for Range PDF Export
  const [fromDate, setFromDate] = useState(() => {
    const d = new Date();
    d.setDate(1);
    return d.toISOString().split('T')[0];
  });
  const [toDate, setToDate] = useState(new Date().toISOString().split('T')[0]);
  const [isDateRangeOpen, setIsDateRangeOpen] = useState(false);

  // Daily records for selected date
  const dayAttendance = attendance[selectedDate] || {};

  // Filter students
  const filteredStudents = students.filter(s => {
    if (selectedType === 'school' && s.studentType !== 'school') return false;
    if (selectedType === 'computer' && s.studentType !== 'computer') return false;
    if (selectedClass !== 'all') {
      if (s.studentType === 'school' && s.className !== selectedClass) return false;
      if (s.studentType === 'computer' && s.course !== selectedClass) return false;
    }
    if (searchQuery.trim()) {
      return s.name?.toLowerCase().includes(searchQuery.toLowerCase()) ||
             s.studentId?.toLowerCase().includes(searchQuery.toLowerCase()) ||
             s.admissionNumber?.toLowerCase().includes(searchQuery.toLowerCase());
    }
    return true;
  });

  // Calculate daily stats
  let presentCount = 0;
  let absentCount = 0;
  let halfDayCount = 0;
  let lateCount = 0;
  let unmarkedCount = 0;

  filteredStudents.forEach(s => {
    const st = dayAttendance[s.id];
    if (st === 'present') presentCount++;
    else if (st === 'absent') absentCount++;
    else if (st === 'half_day') halfDayCount++;
    else if (st === 'leave' || st === 'late') lateCount++;
    else unmarkedCount++;
  });

  const rate = filteredStudents.length > 0 ? Math.round((presentCount / filteredStudents.length) * 100) : 0;

  // Calculate overall institutional attendance rate across all recorded days (for active students only)
  const activeStudentIdSet = new Set(students.map(s => s.id));
  let totalAllLogs = 0;
  let totalAllPresents = 0;

  if (students.length > 0) {
    Object.values(attendance).forEach(dayMap => {
      Object.entries(dayMap).forEach(([stuId, status]) => {
        if (activeStudentIdSet.has(stuId)) {
          totalAllLogs++;
          if (status === 'present') totalAllPresents++;
        }
      });
    });
  }

  const overallRate = totalAllLogs > 0 ? Math.round((totalAllPresents / totalAllLogs) * 100) : 0;

  // Dynamic Trend of logged dates (sorted)
  const loggedDates = Object.keys(attendance).sort().slice(-10);
  const trendData = loggedDates.map(d => {
    const dayObj = attendance[d] || {};
    let total = 0;
    let presents = 0;
    Object.entries(dayObj).forEach(([stuId, status]) => {
      if (activeStudentIdSet.has(stuId)) {
        total++;
        if (status === 'present') presents++;
      }
    });
    const pct = total > 0 ? Math.round((presents / total) * 100) : 0;
    return { date: d, pct, total, presents };
  }).filter(t => t.total > 0);

  // Calculate per-student attendance rate for alerts (<75%)
  const studentAlerts = students.map(s => {
    let studentLogs = 0;
    let studentPresents = 0;
    Object.values(attendance).forEach(dayMap => {
      if (dayMap[s.id]) {
        studentLogs++;
        if (dayMap[s.id] === 'present') studentPresents++;
      }
    });
    const sRate = studentLogs > 0 ? Math.round((studentPresents / studentLogs) * 100) : 100;
    return { ...s, attendanceRate: sRate, totalDays: studentLogs };
  }).filter(s => s.totalDays > 0 && s.attendanceRate < 75);

  const handlePrevDay = () => {
    const d = new Date(selectedDate);
    d.setDate(d.getDate() - 1);
    setSelectedDate(d.toISOString().split('T')[0]);
  };

  const handleNextDay = () => {
    const d = new Date(selectedDate);
    d.setDate(d.getDate() + 1);
    setSelectedDate(d.toISOString().split('T')[0]);
  };

  const handleSubmitAttendance = () => {
    showToast(`Attendance for ${selectedDate} saved! Total: ${filteredStudents.length} · Present: ${presentCount} · Absent: ${absentCount}`, 'success');
  };

  return (
    <div className="space-y-6 pb-12 font-sans">
      {/* Top Tabs */}
      <div className="flex items-center justify-between gap-4 border-b border-border pb-1">
        <div className="flex items-center gap-2 overflow-x-auto custom-scrollbar">
          <button
            onClick={() => setActiveTab('overview')}
            className={`px-4 py-2 rounded-xl text-xs font-bold transition-all cursor-pointer whitespace-nowrap flex items-center gap-2 ${
              activeTab === 'overview'
                ? 'bg-primary text-white shadow-xs'
                : 'text-text-secondary hover:text-text hover:bg-surface2'
            }`}
          >
            <CalendarCheck className="w-3.5 h-3.5" />
            <span>Attendance Overview</span>
          </button>

          <button
            onClick={() => setActiveTab('daily')}
            className={`px-4 py-2 rounded-xl text-xs font-bold transition-all cursor-pointer whitespace-nowrap flex items-center gap-2 ${
              activeTab === 'daily'
                ? 'bg-primary text-white shadow-xs'
                : 'text-text-secondary hover:text-text hover:bg-surface2'
            }`}
          >
            <Users className="w-3.5 h-3.5" />
            <span>Mark Daily Attendance</span>
          </button>

          {(isPrincipal || currentUser?.role !== 'teacher' || teacherPermissions?.canMarkTeacherAtt) && (
            <button
              onClick={() => setActiveTab('teachers')}
              className={`px-4 py-2 rounded-xl text-xs font-bold transition-all cursor-pointer whitespace-nowrap flex items-center gap-2 ${
                activeTab === 'teachers'
                  ? 'bg-[#1E3A8A] text-white shadow-xs'
                  : 'text-text-secondary hover:text-text hover:bg-surface2'
              }`}
            >
              <GraduationCap className="w-3.5 h-3.5" />
              <span>{lang === 'hi' ? 'शिक्षक उपस्थिति' : 'Teacher Attendance'}</span>
            </button>
          )}
        </div>

        {/* Global Export Actions */}
        <div className="flex items-center gap-2">
          <button
            onClick={() => setIsDateRangeOpen(!isDateRangeOpen)}
            className="px-3.5 py-2 rounded-xl bg-white border border-border hover:bg-surface2 text-text font-bold text-xs flex items-center gap-1.5 cursor-pointer shadow-2xs"
            title="Date Range Attendance Register"
          >
            <Calendar className="w-3.5 h-3.5 text-primary" />
            <span className="hidden sm:inline">Date Range</span>
          </button>

          <button
            onClick={() => printTodayAttendancePDF(filteredStudents, attendance, selectedDate, settings)}
            className="px-3.5 py-2 rounded-xl bg-white border border-border hover:bg-surface2 text-text font-bold text-xs flex items-center gap-1.5 cursor-pointer shadow-2xs transition-all"
            title="Print Attendance Register"
          >
            <Printer className="w-3.5 h-3.5 text-primary" />
            <span>Print Register</span>
          </button>

          <button
            onClick={() => exportTodayAttendancePDF(filteredStudents, attendance, selectedDate, settings)}
            className="px-3.5 py-2 rounded-xl bg-primary hover:bg-primary-dark text-white font-bold text-xs flex items-center gap-1.5 cursor-pointer shadow-md transition-all"
            title="Download Today's Attendance Register as PDF"
          >
            <Download className="w-3.5 h-3.5" />
            <span>Download PDF</span>
          </button>
        </div>
      </div>

      {/* ── Faculty GPS Geofence Punch-In Bar ── */}
      {(() => {
        const todayStr = new Date().toISOString().split('T')[0];
        const currentTeacherId = currentUser?.teacherId || currentUser?.uid || currentUser?.id || '';
        const currentTeacherName = currentUser?.name || currentUser?.displayName || 'Faculty Member';
        const myPunch = teacherPunchIns?.[todayStr]?.[currentTeacherId];
        const isConfigured = Boolean(settings.campusLatitude && settings.campusLongitude);

        return (
          <div className="p-4 rounded-2xl bg-gradient-to-r from-blue-50 via-indigo-50/70 to-slate-50 border border-blue-200/80 shadow-2xs flex flex-col sm:flex-row sm:items-center justify-between gap-4">
            <div className="flex items-center gap-3.5">
              <div className="w-10 h-10 rounded-xl bg-indigo-600 text-white flex items-center justify-center flex-shrink-0 shadow-sm shadow-indigo-600/20">
                <MapPin className="w-5 h-5" />
              </div>
              <div>
                <div className="flex items-center gap-2">
                  <span className="text-xs font-black text-slate-900 uppercase tracking-wider">
                    Campus GPS Geofence Attendance
                  </span>
                  <span className={`px-2 py-0.5 rounded-full text-[10px] font-extrabold border ${
                    isConfigured
                      ? 'bg-emerald-50 text-emerald-700 border-emerald-200'
                      : 'bg-amber-50 text-amber-700 border-amber-200'
                  }`}>
                    {isConfigured ? `${settings.geofenceRadiusMeters || 300}m Active` : 'GPS Not Set'}
                  </span>
                </div>
                <p className="text-xs text-slate-600 mt-0.5">
                  {myPunch
                    ? `✓ Verified inside school perimeter at ${myPunch.timeStr} (${myPunch.distanceMeters}m from center)`
                    : isConfigured
                    ? `Mark faculty attendance verified by live GPS within ${settings.geofenceRadiusMeters || 300}m of school grounds.`
                    : 'School campus coordinates not set. Configure in Settings → Campus GPS & Geofence.'}
                </p>
              </div>
            </div>

            <div className="flex items-center gap-2 self-start sm:self-auto flex-shrink-0">
              {myPunch ? (
                <div className="px-3.5 py-2 rounded-xl bg-emerald-600 text-white text-xs font-bold shadow-sm flex items-center gap-1.5">
                  <CheckCircle2 className="w-4 h-4" />
                  <span>Punched In Today ({myPunch.timeStr})</span>
                </div>
              ) : (
                <button
                  type="button"
                  disabled={isPunchingIn}
                  onClick={async () => {
                    setIsPunchingIn(true);
                    try {
                      const res = await punchInTeacherGeofence(currentTeacherId, currentTeacherName);
                      setPunchModalResult(res);
                    } catch (err) {
                      showToast(err.message, 'error');
                    } finally {
                      setIsPunchingIn(false);
                    }
                  }}
                  className="px-4 py-2 rounded-xl bg-indigo-600 hover:bg-indigo-700 text-white text-xs font-bold shadow-md shadow-indigo-600/20 transition-all flex items-center gap-2 cursor-pointer disabled:opacity-60"
                >
                  {isPunchingIn ? (
                    <>
                      <Clock className="w-4 h-4 animate-spin" />
                      <span>Verifying GPS...</span>
                    </>
                  ) : (
                    <>
                      <Navigation className="w-4 h-4" />
                      <span>Punch In (GPS Verified)</span>
                    </>
                  )}
                </button>
              )}
            </div>
          </div>
        );
      })()}

      {/* Date Range Selector Box */}
      {isDateRangeOpen && (
        <div className="p-4 bg-white border border-border rounded-2xl shadow-md flex flex-col sm:flex-row items-center justify-between gap-4 animate-in fade-in duration-200">
          <div className="flex items-center gap-3">
            <Calendar className="w-5 h-5 text-primary" />
            <div>
              <h4 className="text-xs font-bold text-text">Date Range Attendance Register</h4>
              <p className="text-[11px] text-text-muted">Print or download complete attendance register matrix.</p>
            </div>
          </div>

          <div className="flex items-center gap-3 w-full sm:w-auto">
            <div className="flex items-center gap-1.5">
              <span className="text-xs font-bold text-text-secondary">From:</span>
              <input
                type="date"
                value={fromDate}
                onChange={e => setFromDate(e.target.value)}
                className="px-2.5 py-1.5 rounded-lg bg-surface2 border border-border text-xs font-bold text-text"
              />
            </div>
            <div className="flex items-center gap-1.5">
              <span className="text-xs font-bold text-text-secondary">To:</span>
              <input
                type="date"
                value={toDate}
                onChange={e => setToDate(e.target.value)}
                className="px-2.5 py-1.5 rounded-lg bg-surface2 border border-border text-xs font-bold text-text"
              />
            </div>
            <button
              onClick={() => {
                printDateRangeAttendancePDF(filteredStudents, attendance, fromDate, toDate, settings);
                setIsDateRangeOpen(false);
              }}
              className="px-3.5 py-1.5 rounded-lg bg-surface2 border border-border hover:bg-white text-text font-bold text-xs flex items-center gap-1 cursor-pointer shadow-2xs"
              title="Print Date Range Register"
            >
              <Printer className="w-3.5 h-3.5 text-primary" />
              <span>Print</span>
            </button>
            <button
              onClick={() => {
                exportDateRangeAttendancePDF(filteredStudents, attendance, fromDate, toDate, settings);
                setIsDateRangeOpen(false);
              }}
              className="px-4 py-1.5 rounded-lg bg-primary hover:bg-primary-dark text-white font-bold text-xs flex items-center gap-1 cursor-pointer shadow-xs"
            >
              <Download className="w-3.5 h-3.5" />
              <span>Download PDF</span>
            </button>
          </div>
        </div>
      )}

      {activeTab === 'overview' ? (
        /* ─── OVERVIEW DASHBOARD VIEW ─── */
        <div className="space-y-6 animate-in fade-in duration-200">
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
            <div>
              <h2 className="text-xl lg:text-2xl font-bold text-text tracking-tight">Attendance Overview</h2>
              <p className="text-xs text-text-secondary mt-0.5">Real-time attendance metrics for the current academic session.</p>
            </div>
            <div className="flex items-center gap-2">
              <button
                onClick={() => printTodayAttendancePDF(filteredStudents, attendance, selectedDate, settings)}
                className="px-3.5 py-2 rounded-xl bg-white border border-border hover:bg-surface2 text-text font-bold text-xs shadow-2xs transition-all flex items-center gap-1.5 cursor-pointer"
              >
                <Printer className="w-4 h-4 text-primary" />
                <span>Print Register</span>
              </button>
              <button
                onClick={() => exportTodayAttendancePDF(filteredStudents, attendance, selectedDate, settings)}
                className="px-4 py-2 rounded-xl bg-primary hover:bg-primary-dark text-white font-bold text-xs shadow-md transition-all flex items-center gap-1.5 cursor-pointer"
              >
                <Download className="w-4 h-4" />
                <span>Download Report (PDF)</span>
              </button>
            </div>
          </div>

          {/* Stats Cards Row */}
          <div className="grid grid-cols-2 lg:grid-cols-4 gap-4 text-xs">
            <div className="bg-white border border-border rounded-2xl p-5 shadow-xs">
              <div className="text-text-secondary font-bold uppercase text-[9px] tracking-wider">Overall Attendance</div>
              <div className="text-2xl font-black text-primary mt-1.5">{overallRate}%</div>
              <p className="text-[10px] text-text-muted font-medium mt-1">{totalAllLogs} total attendance logs</p>
            </div>

            <div className="bg-white border border-border rounded-2xl p-5 shadow-xs">
              <div className="text-text-secondary font-bold uppercase text-[9px] tracking-wider">Present Today</div>
              <div className="text-2xl font-black text-text mt-1.5">{presentCount} / {filteredStudents.length}</div>
              <p className="text-[10px] text-text-muted mt-1">{rate}% present for {selectedDate}</p>
            </div>

            <div className="bg-white border border-border rounded-2xl p-5 shadow-xs">
              <div className="text-text-secondary font-bold uppercase text-[9px] tracking-wider">Students Absent</div>
              <div className="text-2xl font-black text-rose-600 mt-1.5">{absentCount}</div>
              <p className="text-[10px] text-rose-500 font-bold mt-1">● Absent for {selectedDate}</p>
            </div>

            <div className="bg-white border border-border rounded-2xl p-5 shadow-xs">
              <div className="text-text-secondary font-bold uppercase text-[9px] tracking-wider">Leave & Late</div>
              <div className="text-2xl font-black text-amber-500 mt-1.5">{lateCount}</div>
              <p className="text-[10px] text-amber-600 font-bold mt-1">● Marked leave/late</p>
            </div>
          </div>

          {/* Chart & Alerts split */}
          <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
            {/* Left Card: 30-Day Trend Chart */}
            <div className="lg:col-span-8 bg-white border border-border rounded-2xl p-5 shadow-sm space-y-4">
              <div className="flex justify-between items-center">
                <h3 className="font-bold text-base text-text">Attendance Trend History</h3>
                <span className="text-[10px] text-text-muted font-mono">{trendData.length} days recorded</span>
              </div>
              
              {trendData.length === 0 ? (
                <div className="h-44 flex items-center justify-center text-text-muted text-xs border-b border-border">
                  No attendance history logged yet. Go to 'Mark Daily Attendance' to record today's register.
                </div>
              ) : (
                <div className="h-44 flex items-end justify-start gap-3 pt-4 border-b border-border overflow-x-auto pb-1 custom-scrollbar">
                  {trendData.map((day, idx) => (
                    <div key={idx} className="flex flex-col items-center gap-1.5 min-w-[40px] group">
                      <div className="text-[8px] font-mono font-bold text-text opacity-0 group-hover:opacity-100 transition-opacity">{day.pct}%</div>
                      <div
                        style={{ height: `${Math.max(8, day.pct * 1.3)}px` }}
                        className="w-7 rounded-t bg-primary group-hover:bg-primary-dark transition-all shadow-xs"
                      />
                      <span className="text-[8px] text-text-muted mt-1 font-mono whitespace-nowrap">{day.date.slice(5)}</span>
                    </div>
                  ))}
                </div>
              )}
            </div>

            {/* Right Card: Attendance Alerts */}
            <div className="lg:col-span-4 bg-white border border-border rounded-2xl p-5 shadow-sm space-y-4">
              <h3 className="font-bold text-base text-rose-600 flex items-center gap-2">
                <AlertTriangle className="w-5 h-5" />
                <span>Low Attendance (&lt;75%)</span>
              </h3>
              
              <div className="space-y-3 text-xs">
                {studentAlerts.length === 0 ? (
                  <div className="p-4 text-center text-text-muted text-xs">
                    🎉 No attendance alerts. All students have satisfactory attendance.
                  </div>
                ) : (
                  studentAlerts.slice(0, 4).map(s => (
                    <div key={s.id} className="p-2.5 bg-rose-50/50 border border-rose-100 rounded-xl flex items-center justify-between">
                      <div className="flex items-center gap-2">
                        <div className="w-7 h-7 rounded-full bg-rose-200 text-rose-800 flex items-center justify-center font-bold text-[10px]">
                          {s.name?.charAt(0)}
                        </div>
                        <div>
                          <div className="font-bold text-text">{s.name}</div>
                          <div className="text-[9px] text-text-muted">{s.studentType === 'school' ? `Class ${s.className}` : s.course}</div>
                        </div>
                      </div>
                      <div className="flex items-center gap-1.5 font-bold">
                        <span className="text-rose-600 font-mono">{s.attendanceRate}%</span>
                        <button
                          onClick={() => openWhatsAppAttendanceAlert(s, 'absent', selectedDate, settings)}
                          className="p-1 rounded bg-white border border-rose-200 text-rose-500 hover:bg-rose-50 cursor-pointer shadow-2xs"
                          title="Send WhatsApp Low Attendance Warning"
                        >
                          <MessageSquare className="w-3.5 h-3.5" />
                        </button>
                      </div>
                    </div>
                  ))
                )}
              </div>
            </div>
          </div>
        </div>
      ) : activeTab === 'teachers' ? (
        /* TEACHER ATTENDANCE REGISTER */
        <div className="space-y-6 animate-in fade-in duration-200">
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
            <div>
              <h2 className="text-xl lg:text-2xl font-bold text-text tracking-tight flex items-center gap-2">
                <span>{lang === 'hi' ? 'शिक्षक दैनिक उपस्थिति' : 'Teacher Daily Attendance'}</span>
              </h2>
              <p className="text-xs text-text-secondary mt-0.5">
                {lang === 'hi' ? 'शिक्षकों की दैनिक उपस्थिति और अवकाश दर्ज व अद्यतन करें।' : 'Mark, update, and sync faculty daily presence & leave status.'}
              </p>
            </div>

            <div className="flex items-center gap-2 flex-wrap">
              <input
                type="date"
                value={selectedTeacherDate}
                onChange={(e) => setSelectedTeacherDate(e.target.value)}
                className="px-3 py-2 rounded-xl bg-white border border-border text-xs text-text font-bold shadow-2xs focus:outline-none focus:border-primary"
              />
              <button
                type="button"
                onClick={() => {
                  const m = {};
                  (teachers || []).forEach(t => { m[t.id || t.teacherId] = 'present'; });
                  setLocalTeacherStatus(m);
                  showToast('All teachers marked Present for today', 'info');
                }}
                className="px-3.5 py-2 rounded-xl bg-white border border-emerald-300 text-emerald-700 hover:bg-emerald-50 text-xs font-bold shadow-2xs transition-all cursor-pointer"
              >
                Mark All Present
              </button>
              <button
                type="button"
                disabled={isSavingTeacherAtt}
                onClick={async () => {
                  setIsSavingTeacherAtt(true);
                  await bulkMarkTeacherAttendance(selectedTeacherDate, localTeacherStatus);
                  setIsSavingTeacherAtt(false);
                }}
                className="px-4 py-2 rounded-xl bg-[#1E3A8A] hover:bg-[#152865] text-white text-xs font-bold shadow-md transition-all flex items-center gap-1.5 cursor-pointer disabled:opacity-50"
              >
                <Check className="w-4 h-4" />
                <span>{isSavingTeacherAtt ? 'Saving...' : 'Save Attendance'}</span>
              </button>
            </div>
          </div>

          {/* Metrics summary */}
          <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
            <div className="p-3.5 bg-white rounded-2xl border border-border shadow-2xs">
              <div className="text-[11px] font-bold text-slate-500 uppercase">Total Faculty</div>
              <div className="text-xl font-extrabold text-text mt-0.5">{(teachers || []).length}</div>
            </div>
            <div className="p-3.5 bg-emerald-50/60 rounded-2xl border border-emerald-200 shadow-2xs">
              <div className="text-[11px] font-bold text-emerald-700 uppercase">Present</div>
              <div className="text-xl font-extrabold text-emerald-800 mt-0.5">
                {Object.values(localTeacherStatus).filter(s => s === 'present').length}
              </div>
            </div>
            <div className="p-3.5 bg-rose-50/60 rounded-2xl border border-rose-200 shadow-2xs">
              <div className="text-[11px] font-bold text-rose-700 uppercase">Absent</div>
              <div className="text-xl font-extrabold text-rose-800 mt-0.5">
                {Object.values(localTeacherStatus).filter(s => s === 'absent').length}
              </div>
            </div>
            <div className="p-3.5 bg-amber-50/60 rounded-2xl border border-amber-200 shadow-2xs">
              <div className="text-[11px] font-bold text-amber-700 uppercase">Half Day / Leave</div>
              <div className="text-xl font-extrabold text-amber-800 mt-0.5">
                {Object.values(localTeacherStatus).filter(s => s === 'half_day' || s === 'leave').length}
              </div>
            </div>
          </div>

          {/* Teacher Attendance List */}
          <div className="bg-white rounded-2xl border border-border shadow-xs overflow-hidden">
            <div className="overflow-x-auto">
              <table className="w-full text-left text-xs">
                <thead className="bg-[#f8fafc] text-text-secondary border-b border-border font-bold uppercase tracking-wider text-[10px]">
                  <tr>
                    <th className="py-3 px-4">Faculty Member</th>
                    <th className="py-3 px-4">Teacher ID</th>
                    <th className="py-3 px-4">Assigned Class</th>
                    <th className="py-3 px-4">Contact</th>
                    <th className="py-3 px-4 text-center">Attendance Status</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-border">
                  {(teachers || []).length === 0 ? (
                    <tr>
                      <td colSpan="5" className="py-12 text-center text-text-secondary font-medium">
                        No faculty members added yet. Add teachers in Faculty & Teachers section.
                      </td>
                    </tr>
                  ) : (
                    (teachers || []).map(t => {
                      const tKey = t.id || t.teacherId;
                      const status = localTeacherStatus[tKey] || 'present';

                      return (
                        <tr key={tKey} className="hover:bg-surface2/40 transition-colors">
                          <td className="py-3 px-4 font-bold text-text flex items-center gap-2.5">
                            <div className="w-8 h-8 rounded-full bg-[#1E3A8A] text-white flex items-center justify-center font-extrabold text-xs flex-shrink-0">
                              {(t.name || 'T')[0]}
                            </div>
                            <div>
                              <div className="font-extrabold text-text">{t.name}</div>
                              <div className="text-[10px] text-text-secondary">{t.authEmail || t.email || ''}</div>
                              {(() => {
                                const punchRecord = teacherPunchIns?.[selectedTeacherDate]?.[tKey] ||
                                  teacherPunchIns?.[selectedTeacherDate]?.[t.id] ||
                                  teacherPunchIns?.[selectedTeacherDate]?.[t.teacherId] ||
                                  teacherPunchIns?.[selectedTeacherDate]?.[t.authUid];
                                if (!punchRecord) return null;
                                return (
                                  <div
                                    className="mt-1 inline-flex items-center gap-1 px-1.5 py-0.5 rounded-md bg-emerald-50 text-emerald-700 border border-emerald-200 text-[10px] font-bold"
                                    title={`GPS: ${punchRecord.latitude}, ${punchRecord.longitude}`}
                                  >
                                    <MapPin className="w-2.5 h-2.5 text-emerald-600" />
                                    <span>{punchRecord.timeStr} • {punchRecord.distanceMeters}m</span>
                                  </div>
                                );
                              })()}
                            </div>
                          </td>
                          <td className="py-3 px-4 font-mono font-bold text-slate-700">
                            {t.teacherId || t.id}
                          </td>
                          <td className="py-3 px-4 font-semibold text-text">
                            {t.assignedClass ? `${t.assignedClass} (Sec ${t.assignedSection || 'A'})` : 'General'}
                          </td>
                          <td className="py-3 px-4 text-text-secondary font-medium">
                            {t.mobile || '—'}
                          </td>
                          <td className="py-3 px-4 text-center">
                            <div className="inline-flex items-center gap-1.5 p-1 bg-surface2 rounded-xl border border-border">
                              <button
                                type="button"
                                onClick={() => setLocalTeacherStatus(prev => ({ ...prev, [tKey]: 'present' }))}
                                className={`px-2.5 py-1 rounded-lg text-xs font-bold transition-all cursor-pointer ${
                                  status === 'present'
                                    ? 'bg-emerald-600 text-white shadow-2xs'
                                    : 'text-slate-600 hover:bg-white'
                                }`}
                              >
                                Present
                              </button>
                              <button
                                type="button"
                                onClick={() => setLocalTeacherStatus(prev => ({ ...prev, [tKey]: 'absent' }))}
                                className={`px-2.5 py-1 rounded-lg text-xs font-bold transition-all cursor-pointer ${
                                  status === 'absent'
                                    ? 'bg-rose-600 text-white shadow-2xs'
                                    : 'text-slate-600 hover:bg-white'
                                }`}
                              >
                                Absent
                              </button>
                              <button
                                type="button"
                                onClick={() => setLocalTeacherStatus(prev => ({ ...prev, [tKey]: 'half_day' }))}
                                className={`px-2.5 py-1 rounded-lg text-xs font-bold transition-all cursor-pointer ${
                                  status === 'half_day'
                                    ? 'bg-amber-600 text-white shadow-2xs'
                                    : 'text-slate-600 hover:bg-white'
                                }`}
                              >
                                Half Day
                              </button>
                              <button
                                type="button"
                                onClick={() => setLocalTeacherStatus(prev => ({ ...prev, [tKey]: 'leave' }))}
                                className={`px-2.5 py-1 rounded-lg text-xs font-bold transition-all cursor-pointer ${
                                  status === 'leave'
                                    ? 'bg-blue-600 text-white shadow-2xs'
                                    : 'text-slate-600 hover:bg-white'
                                }`}
                              >
                                Leave
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
      ) : (
        /* DAILY ATTENDANCE REGISTER */
        <div className="space-y-6 animate-in fade-in duration-200">
          {/* Controls Bar */}
          <div className="bg-white border border-border rounded-2xl p-4 shadow-sm flex flex-col md:flex-row items-center justify-between gap-4">
            <div className="flex items-center gap-2 w-full md:w-auto">
              <button
                onClick={handlePrevDay}
                className="p-2 rounded-xl bg-surface2 hover:bg-border text-text transition-colors cursor-pointer"
                title="Previous Day"
              >
                <ChevronLeft className="w-4 h-4" />
              </button>
              <input
                type="date"
                value={selectedDate}
                onChange={e => setSelectedDate(e.target.value)}
                className="px-3 py-1.5 rounded-xl bg-surface2 border border-border text-xs font-bold text-text focus:outline-none focus:border-primary"
              />
              <button
                onClick={handleNextDay}
                className="p-2 rounded-xl bg-surface2 hover:bg-border text-text transition-colors cursor-pointer"
                title="Next Day"
              >
                <ChevronRight className="w-4 h-4" />
              </button>

              <select
                value={selectedClass}
                onChange={e => setSelectedClass(e.target.value)}
                className="px-3 py-1.5 rounded-xl bg-surface2 border border-border text-xs font-bold text-text focus:outline-none cursor-pointer"
              >
                <option value="all">All Classes</option>
                {settings.schoolClasses?.map(c => <option key={c} value={c}>Class {c}</option>)}
                {settings.computerCourses?.map(c => <option key={c} value={c}>{c}</option>)}
              </select>

              {!isPrincipal && selectedClass !== assignedClass && (
                <button
                  onClick={() => setSelectedClass(assignedClass)}
                  className="px-3 py-1.5 rounded-xl bg-primary/10 hover:bg-primary/20 text-primary text-xs font-bold transition-all flex items-center gap-1 cursor-pointer whitespace-nowrap"
                  title="Return to your assigned class"
                >
                  <span>↩ Back to Class {assignedClass}</span>
                </button>
              )}
            </div>

            {/* Quick Bulk Actions */}
            <div className="flex items-center gap-2 w-full md:w-auto overflow-x-auto">
              <button
                onClick={() => bulkMarkAttendance(filteredStudents.map(s => s.id), selectedDate, 'present')}
                className="px-3 py-1.5 rounded-xl bg-emerald-100 hover:bg-emerald-200 text-emerald-800 font-bold text-xs flex items-center gap-1 cursor-pointer transition-colors whitespace-nowrap"
              >
                <Check className="w-3.5 h-3.5" />
                <span>Mark All Present</span>
              </button>
              <button
                onClick={() => bulkMarkAttendance(filteredStudents.map(s => s.id), selectedDate, 'absent')}
                className="px-3 py-1.5 rounded-xl bg-rose-100 hover:bg-rose-200 text-rose-800 font-bold text-xs flex items-center gap-1 cursor-pointer transition-colors whitespace-nowrap"
              >
                <X className="w-3.5 h-3.5" />
                <span>Mark All Absent</span>
              </button>
              <button
                onClick={handleSubmitAttendance}
                className="px-4 py-1.5 rounded-xl bg-primary hover:bg-primary-dark text-white font-bold text-xs cursor-pointer transition-all shadow-xs whitespace-nowrap"
              >
                Save Register
              </button>
            </div>
          </div>

          {/* Student attendance table */}
          <div className="bg-white border border-border rounded-2xl shadow-sm overflow-hidden flex flex-col">
            <div className="overflow-x-auto">
              <table className="w-full text-left text-xs border-collapse">
                <thead>
                  <tr className="bg-surface2/60 border-b border-border text-text-secondary font-bold text-[10px] uppercase">
                    <th className="py-3 px-4">Student</th>
                    <th className="py-3 px-4">Class</th>
                    <th className="py-3 px-4">Roll No.</th>
                    <th className="py-3 px-4 text-center">Status</th>
                    <th className="py-3 px-4 text-right">Actions</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-border text-text font-medium">
                  {filteredStudents.length === 0 ? (
                    <tr>
                      <td colSpan="5" className="py-12 text-center text-text-muted text-xs">
                        No students enrolled yet. Add students to take attendance.
                      </td>
                    </tr>
                  ) : (
                    filteredStudents.map(s => {
                      const st = dayAttendance[s.id] || 'unmarked';
                      return (
                        <tr key={s.id} className="hover:bg-surface2/30 transition-colors">
                          <td className="py-3.5 px-4 font-bold text-text">
                            <div className="flex items-center gap-2.5">
                              <div className="w-8 h-8 rounded-full bg-primary/10 text-primary flex items-center justify-center font-bold text-xs">
                                {s.name?.charAt(0)}
                              </div>
                              <div>
                                <div>{s.name}</div>
                                <div className="text-[9px] text-text-muted">ID: {s.studentId} · Adm: {s.admissionNumber || s.studentId}</div>
                              </div>
                            </div>
                          </td>
                          <td className="py-3.5 px-4 text-text-secondary">{s.studentType === 'school' ? `Class ${s.className}` : s.course}</td>
                          <td className="py-3.5 px-4 font-mono">{s.rollNumber || '-'}</td>
                          <td className="py-3.5 px-4 text-center">
                            <div className="inline-flex items-center gap-1.5 p-1 bg-surface2 rounded-xl border border-border">
                              <button
                                onClick={() => markStudentAttendance(s.id, selectedDate, 'present')}
                                className={`px-2.5 py-1 rounded-lg font-bold text-[10px] uppercase tracking-wider cursor-pointer transition-all ${
                                  st === 'present' ? 'bg-emerald-600 text-white shadow-2xs' : 'text-text-secondary hover:text-text'
                                }`}
                              >
                                Present
                              </button>
                              <button
                                onClick={() => markStudentAttendance(s.id, selectedDate, 'absent')}
                                className={`px-2.5 py-1 rounded-lg font-bold text-[10px] uppercase tracking-wider cursor-pointer transition-all ${
                                  st === 'absent' ? 'bg-rose-600 text-white shadow-2xs' : 'text-text-secondary hover:text-text'
                                }`}
                              >
                                Absent
                              </button>
                              <button
                                onClick={() => markStudentAttendance(s.id, selectedDate, 'half_day')}
                                className={`px-2.5 py-1 rounded-lg font-bold text-[10px] uppercase tracking-wider cursor-pointer transition-all ${
                                  st === 'half_day' ? 'bg-purple-600 text-white shadow-2xs' : 'text-text-secondary hover:text-text'
                                }`}
                              >
                                Half Day
                              </button>
                              <button
                                onClick={() => markStudentAttendance(s.id, selectedDate, 'leave')}
                                className={`px-2.5 py-1 rounded-lg font-bold text-[10px] uppercase tracking-wider cursor-pointer transition-all ${
                                  st === 'leave' || st === 'late' ? 'bg-amber-500 text-white shadow-2xs' : 'text-text-secondary hover:text-text'
                                }`}
                              >
                                Leave
                              </button>
                            </div>
                          </td>
                          <td className="py-3.5 px-4 text-right">
                            <div className="flex items-center justify-end gap-1.5">
                              <button
                                onClick={() => openWhatsAppAttendanceAlert(s, st, selectedDate, settings)}
                                className="p-1.5 rounded-lg bg-emerald-50 text-emerald-700 hover:bg-emerald-100 border border-emerald-200 cursor-pointer"
                                title="Send WhatsApp Attendance Message to Parent"
                              >
                                <MessageSquare className="w-3.5 h-3.5" />
                              </button>
                              <button
                                onClick={() => exportStudentAttendancePDF(s, attendance, settings)}
                                className="p-1.5 rounded-lg bg-surface2 hover:bg-border text-text border border-border cursor-pointer"
                                title="Download Student Attendance PDF"
                              >
                                <Download className="w-3.5 h-3.5" />
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

      {/* Geofence Punch-In Result Modal */}
      {punchModalResult && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-xs animate-in fade-in">
          <div className="w-full max-w-md bg-white rounded-3xl p-6 border border-border shadow-2xl space-y-4">
            <div className="flex items-center gap-3">
              <div className={`w-12 h-12 rounded-2xl flex items-center justify-center flex-shrink-0 ${
                punchModalResult.success
                  ? 'bg-emerald-100 text-emerald-600'
                  : 'bg-rose-100 text-rose-600'
              }`}>
                {punchModalResult.success ? (
                  <CheckCircle2 className="w-6 h-6" />
                ) : (
                  <AlertTriangle className="w-6 h-6" />
                )}
              </div>
              <div>
                <h3 className="text-base font-extrabold text-slate-900">
                  {punchModalResult.success ? 'GPS Attendance Verified' : 'Attendance Verification Failed'}
                </h3>
                <p className="text-xs text-slate-500">
                  {punchModalResult.success ? 'Campus geofence perimeter matched' : 'Outside permissible campus radius'}
                </p>
              </div>
            </div>

            <div className={`p-4 rounded-2xl text-xs font-medium space-y-2 ${
              punchModalResult.success
                ? 'bg-emerald-50 text-emerald-900 border border-emerald-200'
                : 'bg-rose-50 text-rose-900 border border-rose-200'
            }`}>
              <p className="font-bold leading-relaxed">{punchModalResult.message}</p>
              <div className="pt-2 border-t border-current/20 flex items-center justify-between text-[11px]">
                <span>Distance from School:</span>
                <strong>{punchModalResult.distanceMeters} Meters</strong>
              </div>
              <div className="flex items-center justify-between text-[11px]">
                <span>Allowed Perimeter:</span>
                <strong>{punchModalResult.allowedRadius} Meters</strong>
              </div>
            </div>

            <button
              type="button"
              onClick={() => setPunchModalResult(null)}
              className="w-full py-2.5 rounded-xl bg-slate-900 hover:bg-slate-800 text-white text-xs font-bold transition-all cursor-pointer shadow-md"
            >
              Close Window
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
