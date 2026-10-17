'use client';

import React, { useState, useEffect } from 'react';
import { useSchoolStore, calculateStudentFeeMetrics } from '../lib/store';
import {
  Users, GraduationCap, Monitor, CalendarCheck, CreditCard, AlertCircle,
  Plus, Receipt, MessageSquare, ChevronRight, Award, Contact,
  FileSpreadsheet, Search, CheckCircle2, XCircle, Eye, BarChart3,
  TrendingUp, ArrowUpRight, Sparkles, UserCheck, Phone, ArrowRight,
  Megaphone, Pin, Calendar, Image as ImageIcon, FileText
} from 'lucide-react';
import { openWhatsAppFeeReminder } from '../lib/exportUtils';

function KpiCard({ icon: Icon, iconBg, label, value, sub, trend, onClick, trendColor }) {
  return (
    <div
      onClick={onClick}
      className="bg-white rounded-2xl p-3.5 sm:p-4 border border-[#c8c4d5]/60 hover:border-[#1f108e]/40 shadow-2xs hover:shadow-md transition-all duration-200 cursor-pointer group flex items-center gap-3.5"
    >
      <div className={`w-11 h-11 rounded-xl ${iconBg} flex items-center justify-center flex-shrink-0 group-hover:scale-105 transition-transform shadow-2xs`}>
        <Icon className="w-5 h-5" />
      </div>
      <div className="flex-1 min-w-0">
        <div className="flex items-center justify-between gap-1 mb-0.5">
          <span className="text-[11px] font-bold text-[#464553] uppercase tracking-wider truncate">{label}</span>
          {trend && (
            <span className={`px-2 py-0.5 rounded-full text-[10px] font-extrabold ${trendColor} flex-shrink-0`}>
              {trend}
            </span>
          )}
        </div>
        <div className="text-xl sm:text-2xl font-black text-[#0b1c30] tracking-tight truncate leading-tight">{value}</div>
        <p className="text-[10px] font-medium text-[#777584] truncate mt-0.5">{sub}</p>
      </div>
    </div>
  );
}

export default function DashboardView() {
  const {
    students, payments, attendance, results, settings, stats,
    setSelectedStudentId, setIsAddStudentOpen, currentUser, navigate,
    setFeeDetailStudent, setIsFeeDetailSelectorOpen, setWhatsAppReminderData,
    notices, setIsAddNoticeOpen, setViewingNotice, unreadNoticeCount,
    teacherPermissions
  } = useSchoolStore();

  const isPrincipal = currentUser?.role === 'principal';
  const assignedClass = currentUser?.assignedClass || '10th';

  const [searchQuery, setSearchQuery] = useState('');
  const [selectedClass, setSelectedClass] = useState(isPrincipal ? 'all' : assignedClass);
  const [selectedSection, setSelectedSection] = useState('all');

  // Reset to assigned class for teacher on component mount or role change
  useEffect(() => {
    if (!isPrincipal && assignedClass) {
      setSelectedClass(assignedClass);
    }
  }, [assignedClass, isPrincipal]);

  const filteredStudents = students.filter(s => {
    if (selectedClass !== 'all') {
      if (s.studentType === 'school' && s.className !== selectedClass) return false;
      if (s.studentType === 'computer' && s.course !== selectedClass) return false;
    }
    if (selectedSection !== 'all' && s.section !== selectedSection) return false;
    if (searchQuery.trim()) {
      const q = searchQuery.toLowerCase();
      if (!s.name?.toLowerCase().includes(q) && !s.studentId?.toLowerCase().includes(q) && !s.rollNumber?.toLowerCase().includes(q) && !s.mobile?.includes(q)) return false;
    }
    return true;
  });

  const collectionPercent = stats.totalFeesExpected > 0
    ? Math.round((stats.totalFeesCollected / stats.totalFeesExpected) * 100) : 0;

  const teacherStudents = students.filter(s => s.className === assignedClass);

  return (
    <div className="space-y-6 pb-16 w-full animate-in fade-in duration-300 font-sans">

      {/* ── Top Header Banner ── */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 bg-gradient-to-r from-[#eff4ff] via-[#dce9ff] to-[#eff4ff] p-4 sm:p-5 rounded-2xl border border-[#c8c4d5]/40 shadow-xs">
        <div>
          <div className="inline-flex items-center gap-1.5 px-3 py-0.5 rounded-full bg-white/80 text-[11px] font-bold text-[#1f108e] mb-1.5 shadow-2xs">
            <Sparkles className="w-3.5 h-3.5 text-amber-500" />
            <span>Welcome back, {currentUser?.name || 'Administrator'}</span>
          </div>
          <h2 className="text-xl sm:text-2xl font-black text-[#0b1c30] tracking-tight">
            {isPrincipal ? `${settings.instituteName || 'Smart School'} Executive Overview` : `Class ${assignedClass} Faculty Desk`}
          </h2>
          <p className="text-xs text-[#464553] font-medium mt-0.5">
            Academic Session {settings.currentSession || '2026-27'} &nbsp;·&nbsp; Live Cloud Synchronized
          </p>
        </div>

        <div className="flex items-center gap-2">
          {isPrincipal && (
            <button
              onClick={() => setIsAddStudentOpen(true)}
              className="px-3.5 py-2 bg-[#1f108e] hover:bg-[#0f0069] text-white font-bold text-xs rounded-xl shadow-md transition-all flex items-center gap-2 cursor-pointer"
            >
              <Plus className="w-4 h-4" />
              <span>Enroll Student</span>
            </button>
          )}
          <button
            onClick={() => navigate('/reports')}
            className="px-3.5 py-2 bg-white hover:bg-white/80 text-[#0b1c30] font-bold text-xs rounded-xl shadow-xs border border-[#c8c4d5]/50 transition-all flex items-center gap-2 cursor-pointer"
          >
            <FileSpreadsheet className="w-4 h-4 text-[#0051d5]" />
            <span>Generate Report</span>
          </button>
        </div>
      </div>

      {/* ── KPI Metric Cards ── */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-3 sm:gap-4">
        {isPrincipal ? (
          <>
            <KpiCard
              iconBg="bg-blue-50 text-blue-600"
              icon={GraduationCap}
              label="School Students"
              value={stats.schoolCount}
              sub="K-12 Active Enrollment"
              trend="+4.2% Growth"
              trendColor="bg-blue-50 text-blue-700"
              onClick={() => navigate('/students')}
            />
            <KpiCard
              iconBg="bg-indigo-50 text-indigo-600"
              icon={Monitor}
              label="Computer Students"
              value={stats.computerCount}
              sub="ADCA · DCA · Tally · Web"
              trend="Active Courses"
              trendColor="bg-indigo-50 text-indigo-700"
              onClick={() => navigate('/students')}
            />
            <KpiCard
              iconBg="bg-emerald-50 text-emerald-600"
              icon={CreditCard}
              label="Fees Recovered"
              value={`₹${stats.totalFeesCollected.toLocaleString('en-IN')}`}
              sub={`${collectionPercent}% of total dues`}
              trend="Collected"
              trendColor="bg-emerald-50 text-emerald-700"
              onClick={() => navigate('/fees')}
            />
            <KpiCard
              iconBg={stats.totalPendingFees > 0 ? "bg-rose-50 text-rose-600" : "bg-emerald-50 text-emerald-600"}
              icon={stats.totalPendingFees > 0 ? AlertCircle : CheckCircle2}
              label="Pending Defaulters"
              value={`₹${stats.totalPendingFees.toLocaleString('en-IN')}`}
              sub={stats.defaultersCount > 0 ? `${stats.defaultersCount} students overdue` : 'All cleared'}
              trend={stats.totalPendingFees > 0 ? 'Action Needed' : 'Zero Dues'}
              trendColor={stats.totalPendingFees > 0 ? 'bg-rose-50 text-rose-700' : 'bg-emerald-50 text-emerald-700'}
              onClick={() => navigate('/fees')}
            />
          </>
        ) : (
          <>
            <KpiCard
              iconBg="bg-blue-50 text-blue-600"
              icon={Users}
              label="Assigned Students"
              value={teacherStudents.length}
              sub={`Class ${assignedClass} Register`}
              trend="Assigned"
              trendColor="bg-blue-50 text-blue-700"
              onClick={() => navigate('/students')}
            />
            <KpiCard
              iconBg="bg-emerald-50 text-emerald-600"
              icon={CalendarCheck}
              label="Attendance Rate"
              value={`${stats.attendanceRate}%`}
              sub="Today's Classroom Log"
              trend="Active"
              trendColor="bg-emerald-50 text-emerald-700"
              onClick={() => navigate('/attendance')}
            />
            <KpiCard
              iconBg="bg-indigo-50 text-indigo-600"
              icon={CheckCircle2}
              label="Present in Class"
              value={stats.todayPresent}
              sub="Attended today"
              trend="Logged"
              trendColor="bg-indigo-50 text-indigo-700"
              onClick={() => navigate('/attendance')}
            />
            <KpiCard
              iconBg="bg-rose-50 text-rose-600"
              icon={XCircle}
              label="Absent Students"
              value={stats.todayAbsent}
              sub="Requires verification"
              trend="Follow-up"
              trendColor="bg-rose-50 text-rose-700"
              onClick={() => navigate('/attendance')}
            />
          </>
        )}
      </div>

      {/* ── Overdue Fee Defaulters Alert Banner ── */}
      {stats.defaultersCount > 0 && isPrincipal && (
        <div className="p-4 sm:p-5 rounded-2xl bg-rose-50 border border-rose-200 flex flex-col sm:flex-row sm:items-center justify-between gap-4 shadow-2xs">
          <div className="flex items-center gap-3.5">
            <div className="w-10 h-10 rounded-xl bg-rose-600 text-white flex items-center justify-center flex-shrink-0 shadow-sm">
              <AlertCircle className="w-5 h-5" />
            </div>
            <div>
              <h4 className="font-bold text-rose-800 text-sm">{stats.defaultersCount} Students Have Overdue Fee Invoices</h4>
              <p className="text-xs text-rose-600 mt-0.5">Total Pending Amount: ₹{stats.totalPendingFees.toLocaleString('en-IN')} — Send automated reminders via WhatsApp</p>
            </div>
          </div>
          <div className="flex items-center gap-2">
            <button
              onClick={() => {
                const defaulters = students.filter(s => {
                  const m = calculateStudentFeeMetrics(s, payments);
                  return m.currentDue > 0;
                });
                setWhatsAppReminderData({ students: defaulters });
              }}
              className="px-4 py-2 rounded-xl bg-emerald-600 hover:bg-emerald-700 text-white font-bold text-xs shadow-sm transition-colors cursor-pointer whitespace-nowrap flex items-center gap-1.5"
              title="Send WhatsApp Fee Reminder (Hindi / English)"
            >
              <MessageSquare className="w-4 h-4" />
              <span>Send WhatsApp ({stats.defaultersCount})</span>
            </button>
            <button
              onClick={() => navigate('/fees')}
              className="px-4 py-2 rounded-xl bg-white border border-rose-200 hover:bg-rose-100/50 text-rose-700 font-bold text-xs shadow-2xs transition-colors cursor-pointer whitespace-nowrap self-start sm:self-auto"
            >
              Review Defaulters
            </button>
          </div>
        </div>
      )}

      {/* ── Notice Board & Circulars Live Widget ── */}
      <div className="rounded-2xl bg-white border border-[#c8c4d5]/50 p-5 shadow-xs space-y-4">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 pb-3 border-b border-[#c8c4d5]/40">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-[#eff4ff] text-[#1f108e] flex items-center justify-center flex-shrink-0">
              <Megaphone className="w-5 h-5" />
            </div>
            <div>
              <div className="flex items-center gap-2">
                <h3 className="font-bold text-sm text-[#0b1c30]">School Notice Board & Circulars</h3>
                {unreadNoticeCount > 0 && (
                  <span className="px-2 py-0.2 rounded-full bg-rose-500 text-white text-[10px] font-extrabold animate-pulse">
                    {unreadNoticeCount} new
                  </span>
                )}
              </div>
              <p className="text-xs text-[#777584]">Official circulars, staff meeting agendas, holiday notices & updates</p>
            </div>
          </div>

          <div className="flex items-center gap-2">
            {(isPrincipal || teacherPermissions?.canPostNotices !== false) && (
              <button
                onClick={() => setIsAddNoticeOpen(true)}
                className="px-3.5 py-2 rounded-xl bg-[#1f108e] hover:bg-[#0f0069] text-white text-xs font-bold shadow-xs transition-all flex items-center gap-1.5 cursor-pointer"
              >
                <Plus className="w-3.5 h-3.5" />
                <span>Publish Notice</span>
              </button>
            )}
            <button
              onClick={() => navigate('/notices')}
              className="px-3.5 py-2 rounded-xl bg-[#eff4ff] hover:bg-[#dce9ff] text-[#1f108e] text-xs font-bold border border-[#c8c4d5]/40 transition-colors flex items-center gap-1 cursor-pointer"
            >
              <span>View Board ({notices.length})</span>
              <ArrowRight className="w-3.5 h-3.5" />
            </button>
          </div>
        </div>

        {/* Notices Preview Grid */}
        {notices.length > 0 ? (
          <div className="grid grid-cols-1 md:grid-cols-3 gap-3.5">
            {notices.slice(0, 3).map((n) => {
              const currentUserId = currentUser?.uid || currentUser?.teacherId || currentUser?.id || '';
              const isRead = currentUserId ? (n.readBy || []).includes(currentUserId) : true;
              const date = n.createdAt ? new Date(n.createdAt) : new Date();
              const dateStr = date.toLocaleDateString('en-IN', { day: 'numeric', month: 'short' });

              const categoryBadge = {
                Urgent: 'bg-rose-50 text-rose-700 border-rose-200',
                Meeting: 'bg-blue-50 text-blue-700 border-blue-200',
                Holiday: 'bg-emerald-50 text-emerald-700 border-emerald-200',
                Academic: 'bg-purple-50 text-purple-700 border-purple-200',
                Event: 'bg-amber-50 text-amber-700 border-amber-200',
                General: 'bg-slate-100 text-slate-700 border-slate-200'
              }[n.category] || 'bg-slate-100 text-slate-700 border-slate-200';

              return (
                <div
                  key={n.id}
                  onClick={() => setViewingNotice(n)}
                  className={`p-3.5 rounded-xl border transition-all duration-200 hover:shadow-sm cursor-pointer flex flex-col justify-between group ${
                    n.isPinned
                      ? 'bg-amber-50/30 border-amber-300'
                      : (!isRead ? 'bg-[#eff4ff]/30 border-[#1f108e]/40' : 'bg-[#eff4ff]/20 border-[#c8c4d5]/50 hover:bg-[#eff4ff]/50')
                  }`}
                >
                  <div>
                    <div className="flex items-center justify-between gap-1 mb-2">
                      <div className="flex items-center gap-1.5">
                        <span className={`text-[10px] font-bold px-2 py-0.5 rounded-md border ${categoryBadge}`}>
                          {n.category || 'General'}
                        </span>
                        {n.isPinned && (
                          <span className="text-[10px] font-bold px-1.5 py-0.5 rounded-md bg-amber-100 text-amber-800 flex items-center gap-0.5">
                            <Pin className="w-2.5 h-2.5 fill-amber-600" />
                            Pinned
                          </span>
                        )}
                      </div>
                      <span className="text-[10px] text-[#777584] font-medium">{dateStr}</span>
                    </div>

                    <h4 className="font-bold text-xs text-[#0b1c30] group-hover:text-[#1f108e] transition-colors line-clamp-1 leading-snug">
                      {n.title}
                    </h4>

                    {n.content && (
                      <p className="text-[11px] text-[#464553] line-clamp-2 mt-1 leading-relaxed">
                        {n.content}
                      </p>
                    )}
                  </div>

                  <div className="flex items-center justify-between gap-1 pt-2.5 mt-2 border-t border-[#c8c4d5]/30 text-[10px]">
                    <span className="text-[#777584] truncate">By {n.authorName || 'Principal'}</span>
                    {n.imageUrl ? (
                      n.fileType === 'pdf' || n.imageUrl?.startsWith('data:application/pdf') || n.fileName?.toLowerCase().endsWith('.pdf') ? (
                        <span className="text-rose-600 font-bold flex items-center gap-1 bg-rose-50 px-1.5 py-0.2 rounded border border-rose-200">
                          <FileText className="w-3 h-3" />
                          <span>PDF ({n.fileSize || '≤50KB'})</span>
                        </span>
                      ) : (
                        <span className="text-[#1f108e] font-bold flex items-center gap-1 bg-[#eff4ff] px-1.5 py-0.2 rounded border border-[#c8c4d5]/40">
                          <ImageIcon className="w-3 h-3" />
                          <span>Photo ({n.fileSize || '≤50KB'})</span>
                        </span>
                      )
                    ) : (
                      <span className="text-[#1f108e] font-bold group-hover:underline">Read →</span>
                    )}
                  </div>
                </div>
              );
            })}
          </div>
        ) : (
          <div className="p-5 text-center bg-[#eff4ff]/30 rounded-xl border border-dashed border-[#c8c4d5]/60">
            <p className="text-xs text-[#777584]">No notices published yet.</p>
          </div>
        )}
      </div>

      {/* ── Search & Filter Tool Bar ── */}
      <div className="bg-white rounded-2xl border border-[#c8c4d5]/50 p-4 shadow-xs flex flex-col md:flex-row items-center gap-3">
        <div className="relative flex-1 w-full">
          <Search className="w-4 h-4 text-[#777584] absolute left-3.5 top-1/2 -translate-y-1/2" />
          <input
            type="text"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            placeholder="Search students by name, roll number, ID, or phone..."
            className="w-full pl-10 pr-4 py-2.5 rounded-xl bg-[#eff4ff] border border-[#c8c4d5]/40 text-xs font-medium text-[#0b1c30] placeholder-[#777584] focus:outline-none focus:ring-2 focus:ring-[#1f108e]/30 focus:border-[#1f108e] transition-all"
          />
        </div>
        <div className="flex items-center gap-2 w-full md:w-auto">
          <select
            value={selectedClass}
            onChange={(e) => setSelectedClass(e.target.value)}
            className="flex-1 md:flex-none px-3 py-2.5 rounded-xl bg-[#eff4ff] border border-[#c8c4d5]/40 text-xs font-bold text-[#0b1c30] focus:outline-none cursor-pointer min-w-[140px]"
          >
            <option value="all">All Classes / Courses</option>
            {settings.schoolClasses?.map(c => <option key={c} value={c}>Class {c}</option>)}
            {settings.computerCourses?.map(c => <option key={c} value={c}>{c}</option>)}
          </select>
          <select
            value={selectedSection}
            onChange={(e) => setSelectedSection(e.target.value)}
            className="flex-1 md:flex-none px-3 py-2.5 rounded-xl bg-[#eff4ff] border border-[#c8c4d5]/40 text-xs font-bold text-[#0b1c30] focus:outline-none cursor-pointer min-w-[120px]"
          >
            <option value="all">All Sections</option>
            {settings.sections?.map(s => <option key={s} value={s}>Section {s}</option>)}
          </select>
          {!isPrincipal && selectedClass !== assignedClass && (
            <button
              onClick={() => { setSelectedClass(assignedClass); setSelectedSection('all'); }}
              className="px-3 py-2 rounded-xl bg-[#1f108e]/10 hover:bg-[#1f108e]/20 text-[#1f108e] text-xs font-bold transition-all flex items-center gap-1 cursor-pointer whitespace-nowrap"
              title="Return to your assigned class"
            >
              <span>↩ Back to Class {assignedClass}</span>
            </button>
          )}
        </div>
      </div>

      {/* ── 2-Column Content Grid ── */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6 items-start">
        
        {/* Left: Student Directory Table */}
        <div className="lg:col-span-8 bg-white rounded-2xl border border-[#c8c4d5]/50 shadow-xs overflow-hidden">
          <div className="px-5 py-4 border-b border-[#c8c4d5]/40 flex items-center justify-between bg-[#eff4ff]/60">
            <div className="flex items-center gap-2.5">
              <div className="w-8 h-8 rounded-lg bg-[#316bf3]/10 text-[#0051d5] flex items-center justify-center font-bold">
                <Users className="w-4 h-4" />
              </div>
              <div>
                <h3 className="font-bold text-sm text-[#0b1c30]">Active Student Directory</h3>
                <p className="text-[11px] text-[#464553]">{filteredStudents.length} registered students</p>
              </div>
            </div>
            <button
              onClick={() => navigate('/students')}
              className="text-xs font-bold text-[#0051d5] hover:underline flex items-center gap-1 cursor-pointer"
            >
              <span>View Full Directory</span>
              <ChevronRight className="w-3.5 h-3.5" />
            </button>
          </div>

          <div className="overflow-x-auto max-h-[500px] overflow-y-auto">
            <table className="w-full text-left text-xs">
              <thead className="bg-[#eff4ff] border-b border-[#c8c4d5]/40 sticky top-0 z-10 text-[#777584]">
                <tr>
                  {(isPrincipal
                    ? ['Student Name', 'Class / Course', 'Parent Contact', 'Fee Account', 'Action']
                    : ['Student Name', 'Class / Course', 'Parent Contact', 'Status', 'Action']
                  ).map(h => (
                    <th key={h} className="py-3 px-4 text-[10px] font-black uppercase tracking-wider whitespace-nowrap">{h}</th>
                  ))}
                </tr>
              </thead>
              <tbody className="divide-y divide-[#c8c4d5]/30">
                {filteredStudents.length === 0 ? (
                  <tr>
                    <td colSpan={5} className="py-12 text-center text-[#777584]">
                      No student records found matching query.
                    </td>
                  </tr>
                ) : filteredStudents.slice(0, 15).map(s => {
                  const m = calculateStudentFeeMetrics(s, payments);
                  const pending = m.currentDue;
                  const totalPaid = m.totalPaid;
                  const totalExpected = m.setTotalFees;
                  const isPaid = pending <= 0 && (totalExpected > 0 || totalPaid > 0);
                  const isUnpaid = totalPaid <= 0 && pending > 0;

                  return (
                    <tr
                      key={s.id}
                      onClick={() => { setSelectedStudentId(s.id); navigate('/students'); }}
                      className="hover:bg-[#eff4ff]/70 transition-colors cursor-pointer group"
                    >
                      {/* Name & ID */}
                      <td className="py-3 px-4">
                        <div className="flex items-center gap-2.5">
                          <div className="w-8 h-8 rounded-full bg-[#1f108e]/10 text-[#1f108e] flex items-center justify-center font-bold text-xs flex-shrink-0">
                            {s.photoPath ? <img src={s.photoPath} alt={s.name} className="w-full h-full object-cover rounded-full" /> : s.name?.charAt(0) || 'S'}
                          </div>
                          <div>
                            <div className="font-bold text-[#0b1c30] group-hover:text-[#1f108e] transition-colors">{s.name}</div>
                            <div className="text-[10px] text-[#777584]">ID: {s.studentId} · Roll: {s.rollNumber || '—'}</div>
                          </div>
                        </div>
                      </td>

                      {/* Class */}
                      <td className="py-3 px-4">
                        <div className="font-bold text-[#0b1c30]">
                          {s.studentType === 'school' ? `Class ${s.className || ''}` : s.course}
                        </div>
                        <div className="text-[10px] text-[#777584]">
                          {s.studentType === 'school' ? `Sec ${s.section || 'A'}` : s.batch || 'General'}
                        </div>
                      </td>

                      {/* Father / Phone */}
                      <td className="py-3 px-4">
                        <div className="font-semibold text-[#0b1c30]">{s.fatherName || '—'}</div>
                        <div className="text-[10px] text-[#777584]">{s.mobile}</div>
                      </td>

                      {/* Fee Badge (Principal) or Enrollment Status (Teacher) */}
                      <td className="py-3 px-4" onClick={e => e.stopPropagation()}>
                        {isPrincipal ? (
                          <span className={`inline-flex px-2.5 py-0.5 rounded-md text-[10px] font-bold ${
                            isPaid
                              ? 'bg-emerald-50 text-emerald-700 border border-emerald-200'
                              : isUnpaid
                              ? 'bg-rose-50 text-rose-700 border border-rose-200'
                              : 'bg-amber-50 text-amber-700 border border-amber-200'
                          }`}>
                            {isPaid ? '✓ Paid' : isUnpaid ? `Unpaid ₹${pending.toLocaleString('en-IN')}` : `Due ₹${pending.toLocaleString('en-IN')}`}
                          </span>
                        ) : (
                          <span className="inline-flex px-2.5 py-0.5 rounded-md text-[10px] font-bold bg-emerald-50 text-emerald-700 border border-emerald-200">
                            Active
                          </span>
                        )}
                      </td>

                      {/* Actions */}
                      <td className="py-3 px-4" onClick={e => e.stopPropagation()}>
                        <div className="flex items-center gap-1">
                          {pending > 0 && isPrincipal && (
                            <button
                              onClick={() => setWhatsAppReminderData({ student: s, dueAmount: pending })}
                              className="p-1.5 rounded-lg bg-emerald-50 hover:bg-emerald-100 text-emerald-600 transition-colors cursor-pointer"
                              title="Send WhatsApp Fee Due Reminder (Hindi / English)"
                            >
                              <MessageSquare className="w-3.5 h-3.5" />
                            </button>
                          )}
                          {isPrincipal && (
                            <button
                              onClick={() => {
                                setIsFeeDetailSelectorOpen(false);
                                setFeeDetailStudent(s);
                              }}
                              className="p-1.5 rounded-lg bg-amber-50 hover:bg-amber-100 text-amber-600 transition-colors cursor-pointer"
                              title="Fee Structure & Pay"
                            >
                              <CreditCard className="w-3.5 h-3.5" />
                            </button>
                          )}
                          <button
                            onClick={() => { setSelectedStudentId(s.id); navigate('/students'); }}
                            className="p-1.5 rounded-lg bg-[#eff4ff] hover:bg-[#dce9ff] text-[#0051d5] transition-colors cursor-pointer"
                            title="View Profile"
                          >
                            <Eye className="w-3.5 h-3.5" />
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

        {/* Right: Attendance Summary & Recovery Widgets */}
        <div className="lg:col-span-4 space-y-4">
          
          {/* Today's Attendance Widget */}
          <div className="bg-white rounded-2xl border border-[#c8c4d5]/50 p-5 shadow-xs space-y-4">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2.5">
                <div className="w-8 h-8 rounded-lg bg-emerald-50 text-emerald-600 flex items-center justify-center font-bold">
                  <CalendarCheck className="w-4 h-4" />
                </div>
                <div>
                  <h4 className="font-bold text-sm text-[#0b1c30]">Daily Attendance</h4>
                  <p className="text-[10px] text-[#777584]">{new Date().toLocaleDateString('en-IN', { weekday: 'short', day: 'numeric', month: 'short' })}</p>
                </div>
              </div>
              <span className="px-2.5 py-0.5 rounded-full text-xs font-black bg-emerald-50 text-emerald-700 border border-emerald-200">
                {stats.attendanceRate}%
              </span>
            </div>

            <div className="grid grid-cols-3 gap-2 text-center">
              <div className="p-3 rounded-xl bg-emerald-50/80 border border-emerald-100">
                <div className="text-xl font-black text-emerald-700">{stats.todayPresent}</div>
                <div className="text-[10px] font-bold uppercase text-emerald-700 mt-0.5">Present</div>
              </div>
              <div className="p-3 rounded-xl bg-rose-50/80 border border-rose-100">
                <div className="text-xl font-black text-rose-700">{stats.todayAbsent}</div>
                <div className="text-[10px] font-bold uppercase text-rose-700 mt-0.5">Absent</div>
              </div>
              <div className="p-3 rounded-xl bg-amber-50/80 border border-amber-100">
                <div className="text-xl font-black text-amber-700">{stats.todayLeave}</div>
                <div className="text-[10px] font-bold uppercase text-amber-700 mt-0.5">Leave</div>
              </div>
            </div>

            <button
              onClick={() => navigate('/attendance')}
              className="w-full py-2.5 rounded-xl bg-[#eff4ff] hover:bg-[#dce9ff] text-[#1f108e] font-bold text-xs flex items-center justify-center gap-1.5 transition-colors cursor-pointer"
            >
              <span>Take Attendance</span>
              <ChevronRight className="w-3.5 h-3.5" />
            </button>
          </div>

          {/* Fee Recovery Progress Bar (Principal only) */}
          {isPrincipal && (
            <div className="bg-white rounded-2xl border border-[#c8c4d5]/50 p-5 shadow-xs space-y-3">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <CreditCard className="w-4 h-4 text-[#0051d5]" />
                  <h4 className="font-bold text-xs text-[#0b1c30]">Fee Recovery Ratio</h4>
                </div>
                <span className="text-xs font-black text-emerald-600">{collectionPercent}%</span>
              </div>

              <div className="space-y-1.5 text-xs text-[#464553] font-medium">
                <div className="flex justify-between items-center text-[11px]">
                  <span>Collected</span>
                  <span className="font-bold text-emerald-700">₹{stats.totalFeesCollected.toLocaleString('en-IN')}</span>
                </div>
                <div className="flex justify-between items-center text-[11px]">
                  <span>Pending</span>
                  <span className="font-bold text-rose-700">₹{stats.totalPendingFees.toLocaleString('en-IN')}</span>
                </div>
                <div className="w-full h-2 bg-[#eff4ff] rounded-full overflow-hidden border border-[#c8c4d5]/40 mt-2">
                  <div
                    className="h-full bg-gradient-to-r from-[#0051d5] to-emerald-500 rounded-full transition-all duration-700"
                    style={{ width: `${Math.min(100, collectionPercent)}%` }}
                  />
                </div>
              </div>

              <button
                onClick={() => navigate('/fees')}
                className="w-full py-2 rounded-xl bg-white hover:bg-[#eff4ff] text-[#0b1c30] font-bold text-xs flex items-center justify-center gap-1 transition-colors cursor-pointer border border-[#c8c4d5]/50"
              >
                <span>Open Ledger</span>
                <ChevronRight className="w-3.5 h-3.5" />
              </button>
            </div>
          )}

          {/* Quick Shortcuts */}
          <div className="bg-white rounded-2xl border border-[#c8c4d5]/50 p-5 shadow-xs space-y-3">
            <h4 className="font-bold text-xs text-[#0b1c30] flex items-center gap-1.5">
              <Sparkles className="w-3.5 h-3.5 text-amber-500" />
              <span>Quick Shortcuts</span>
            </h4>
            <div className="grid grid-cols-3 gap-2">
              {[
                { icon: Plus, label: 'Add Student', show: isPrincipal, onClick: () => setIsAddStudentOpen(true) },
                { icon: CalendarCheck, label: 'Attendance', show: true, onClick: () => navigate('/attendance') },
                { icon: CreditCard, label: 'Fees', show: isPrincipal, onClick: () => navigate('/fees') },
                { icon: Contact, label: 'ID Cards', show: true, onClick: () => navigate('/idcards') },
                { icon: Award, label: 'Results', show: true, onClick: () => navigate('/results') },
                { icon: FileSpreadsheet, label: 'Reports', show: true, onClick: () => navigate('/reports') },
              ].filter(s => s.show).map(({ icon: I, label, onClick }) => (
                <button
                  key={label}
                  onClick={onClick}
                  className="p-2.5 rounded-xl border border-[#c8c4d5]/40 bg-[#eff4ff]/60 hover:bg-[#dce9ff] flex flex-col items-center justify-center text-center transition-all cursor-pointer group"
                >
                  <I className="w-4 h-4 text-[#1f108e] mb-1 group-hover:scale-110 transition-transform" />
                  <span className="text-[10px] font-bold text-[#0b1c30] leading-tight">{label}</span>
                </button>
              ))}
            </div>
          </div>

        </div>

      </div>

    </div>
  );
}
