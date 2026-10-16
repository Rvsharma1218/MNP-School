'use client';

import React, { useState, useEffect } from 'react';
import { useSchoolStore } from '../lib/store';
import {
  Search,
  X,
  User,
  CreditCard,
  CalendarCheck,
  Award,
  Contact,
  ArrowRight,
  Receipt,
  Eye,
  Plus,
  GraduationCap
} from 'lucide-react';

export default function GlobalSearchModal({ isOpen, onClose }) {
  const {
    students,
    teachers,
    payments,
    settings,
    navigate,
    setSelectedStudentId,
    setViewingStudentProfile,
    setFeeDetailStudent,
    setIsFeeDetailSelectorOpen,
    setIsAddStudentOpen,
    setPrintReceiptData,
    calculateStudentFeeMetrics
  } = useSchoolStore();

  const [query, setQuery] = useState('');

  // Handle ESC key
  useEffect(() => {
    if (!isOpen) return;
    const handleKeyDown = (e) => {
      if (e.key === 'Escape') onClose();
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [isOpen, onClose]);

  if (!isOpen) return null;

  const q = query.trim().toLowerCase();

  const matchedStudents = q
    ? (students || []).filter(s =>
        String(s.name || '').toLowerCase().includes(q) ||
        String(s.studentId || '').toLowerCase().includes(q) ||
        String(s.admissionNumber || s.admissionNo || '').toLowerCase().includes(q) ||
        String(s.rollNumber || '').toLowerCase().includes(q) ||
        String(s.mobile || '').includes(q) ||
        String(s.fatherName || '').toLowerCase().includes(q) ||
        String(s.motherName || '').toLowerCase().includes(q) ||
        String(s.className || '').toLowerCase().includes(q) ||
        String(s.section || '').toLowerCase().includes(q) ||
        String(s.course || '').toLowerCase().includes(q) ||
        String(s.batch || '').toLowerCase().includes(q)
      ).slice(0, 8)
    : [];

  const matchedTeachers = q
    ? (teachers || []).filter(t =>
        String(t.name || '').toLowerCase().includes(q) ||
        String(t.teacherId || '').toLowerCase().includes(q) ||
        String(t.mobile || '').includes(q) ||
        String(t.subject || '').toLowerCase().includes(q) ||
        String(t.designation || '').toLowerCase().includes(q)
      ).slice(0, 4)
    : [];

  const matchedPayments = q
    ? (payments || []).filter(p =>
        String(p.receiptNumber || '').toLowerCase().includes(q) ||
        String(p.studentName || '').toLowerCase().includes(q) ||
        String(p.studentId || '').toLowerCase().includes(q) ||
        String(p.amount || '').includes(q) ||
        String(p.paymentMode || '').toLowerCase().includes(q)
      ).slice(0, 4)
    : [];

  const quickNav = [
    { label: 'Add New Student Admission', icon: User, action: () => { setIsAddStudentOpen(true); onClose(); } },
    { label: 'Fee Structure & Collect Pay', icon: CreditCard, action: () => { setIsFeeDetailSelectorOpen(true); setFeeDetailStudent(students[0] || null); onClose(); } },
    { label: 'Open Daily Attendance Register', icon: CalendarCheck, action: () => { navigate('/attendance'); onClose(); } },
    { label: 'Print Student ID Cards Studio', icon: Contact, action: () => { navigate('/idcards'); onClose(); } },
    { label: 'Examinations & Marksheets', icon: Award, action: () => { navigate('/results'); onClose(); } },
  ];

  return (
    <div className="fixed inset-0 z-50 flex items-start justify-center p-3 sm:p-4 pt-12 sm:pt-16 bg-black/70 backdrop-blur-xs font-sans">
      <div className="bg-card border border-border rounded-2xl w-full max-w-xl shadow-2xl overflow-hidden animate-in fade-in zoom-in-95 duration-200">
        
        {/* Search Input Bar */}
        <div className="p-3.5 sm:p-4 border-b border-border flex items-center gap-3 bg-surface2/60">
          <Search className="w-5 h-5 text-primary flex-shrink-0" />
          <input
            type="text"
            autoFocus
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="Search student name, roll number, student ID, mobile or receipt..."
            className="flex-1 bg-transparent text-sm text-text placeholder-text-muted focus:outline-none font-medium"
          />
          {query && (
            <button
              onClick={() => setQuery('')}
              className="p-1 rounded-md text-text-muted hover:text-text hover:bg-surface2 cursor-pointer text-xs"
            >
              Clear
            </button>
          )}
          <button onClick={onClose} className="p-1 text-text-muted hover:text-text cursor-pointer">
            <X className="w-4 h-4" />
          </button>
        </div>

        {/* Results Body */}
        <div className="max-h-96 overflow-y-auto p-4 space-y-4 custom-scrollbar text-xs">
          {/* Matched Students */}
          {matchedStudents.length > 0 && (
            <div>
              <div className="text-[10px] font-bold text-text-secondary uppercase tracking-wider mb-2 flex items-center justify-between">
                <span>Matching Students ({matchedStudents.length})</span>
                <span className="text-[9px] text-text-muted">Click to view profile or pay fee</span>
              </div>
              <div className="space-y-1.5">
                {matchedStudents.map(s => {
                  const metrics = calculateStudentFeeMetrics ? calculateStudentFeeMetrics(s, payments) : null;
                  const sDue = metrics ? metrics.currentDue : Math.max(0, (Number(s.totalFees) || 0) - (Number(s.paidFees) || 0));

                  return (
                    <div
                      key={s.id}
                      className="p-2.5 rounded-xl border border-border/60 hover:border-primary/40 bg-surface2/40 hover:bg-surface2 flex items-center justify-between transition-all gap-2 group"
                    >
                      <button
                        type="button"
                        onClick={() => {
                          setSelectedStudentId(s.id);
                          setViewingStudentProfile(s);
                          onClose();
                        }}
                        className="flex items-center gap-2.5 flex-1 text-left min-w-0 cursor-pointer"
                      >
                        <div className="w-9 h-9 rounded-xl bg-primary/10 text-primary flex items-center justify-center font-bold text-xs flex-shrink-0 overflow-hidden">
                          {s.photoPath || s.photoUrl ? (
                            <img src={s.photoPath || s.photoUrl} alt={s.name} className="w-full h-full object-cover" />
                          ) : (
                            s.name?.charAt(0) || 'S'
                          )}
                        </div>
                        <div className="min-w-0 flex-1">
                          <div className="font-bold text-text group-hover:text-primary transition-colors flex items-center gap-1.5 truncate">
                            <span>{s.name}</span>
                            <span className="text-[9px] px-1.5 py-0.2 rounded bg-surface border border-border text-text-secondary font-normal font-mono">
                              Roll: {s.rollNumber || '-'}
                            </span>
                          </div>
                          <div className="text-[10px] text-text-secondary truncate">
                            {s.studentType === 'school' ? `Class ${s.className || ''} (${s.section || 'A'})` : s.course} • ID: {s.studentId}
                          </div>
                        </div>
                      </button>

                      <div className="flex items-center gap-2 flex-shrink-0">
                        <span className={`text-[10px] font-bold px-2 py-0.5 rounded font-mono ${
                          sDue <= 0 ? 'bg-emerald-500/10 text-emerald-600' : 'bg-rose-500/10 text-rose-600'
                        }`}>
                          {sDue <= 0 ? 'Paid' : `₹${sDue.toLocaleString('en-IN')} Due`}
                        </span>

                        <button
                          type="button"
                          onClick={() => {
                            setIsFeeDetailSelectorOpen(false);
                            setFeeDetailStudent(s);
                            onClose();
                          }}
                          className="px-2.5 py-1 rounded-lg bg-emerald-600 hover:bg-emerald-500 text-white font-bold text-[10px] flex items-center gap-1 cursor-pointer transition-colors shadow-2xs"
                          title="Open Fee Structure & Pay"
                        >
                          <CreditCard className="w-3 h-3" />
                          <span>Pay</span>
                        </button>

                        <button
                          type="button"
                          onClick={() => {
                            setSelectedStudentId(s.id);
                            setViewingStudentProfile(s);
                            onClose();
                          }}
                          className="p-1 rounded-lg text-text-muted hover:text-text hover:bg-card cursor-pointer transition-colors"
                          title="View Profile"
                        >
                          <Eye className="w-3.5 h-3.5" />
                        </button>
                      </div>
                    </div>
                  );
                })}
              </div>
            </div>
          )}

          {/* Matched Teachers */}
          {matchedTeachers.length > 0 && (
            <div>
              <div className="text-[10px] font-bold text-text-secondary uppercase tracking-wider mb-2">
                Faculty & Teachers ({matchedTeachers.length})
              </div>
              <div className="space-y-1.5">
                {matchedTeachers.map(t => (
                  <button
                    key={t.id}
                    type="button"
                    onClick={() => {
                      navigate('/teachers');
                      onClose();
                    }}
                    className="w-full p-2.5 rounded-xl border border-border/60 hover:border-primary/40 bg-surface2/40 hover:bg-surface2 flex items-center justify-between text-left transition-colors cursor-pointer group"
                  >
                    <div className="flex items-center gap-2.5 min-w-0">
                      <div className="w-8 h-8 rounded-lg bg-indigo-500/10 text-indigo-600 flex items-center justify-center font-bold text-xs flex-shrink-0">
                        <GraduationCap className="w-4 h-4" />
                      </div>
                      <div className="truncate">
                        <div className="font-bold text-text group-hover:text-primary transition-colors">{t.name}</div>
                        <div className="text-[10px] text-text-secondary">
                          {t.teacherId || 'Teacher'} • {t.subject || t.designation || 'Faculty'} • {t.mobile || ''}
                        </div>
                      </div>
                    </div>
                    <span className="text-[10px] text-primary font-bold">View Staff →</span>
                  </button>
                ))}
              </div>
            </div>
          )}

          {/* Matched Payments */}
          {matchedPayments.length > 0 && (
            <div>
              <div className="text-[10px] font-bold text-text-secondary uppercase tracking-wider mb-2">
                Matching Receipts ({matchedPayments.length})
              </div>
              <div className="space-y-1.5">
                {matchedPayments.map(p => {
                  const matchedStudent = students.find(st => st.id === p.studentId || (st.studentId && st.studentId === p.studentId));
                  return (
                    <button
                      key={p.id}
                      type="button"
                      onClick={() => {
                        setPrintReceiptData({
                          payment: p,
                          student: matchedStudent || { name: p.studentName, studentId: p.studentId, session: settings.currentSession },
                          settings
                        });
                        onClose();
                      }}
                      className="w-full p-2.5 rounded-xl border border-border/60 hover:border-emerald-500/40 bg-surface2/40 hover:bg-surface2 flex items-center justify-between transition-colors text-left group cursor-pointer"
                    >
                      <div className="flex items-center gap-2.5">
                        <div className="w-8 h-8 rounded-lg bg-emerald-500/10 text-emerald-600 flex items-center justify-center font-bold text-xs flex-shrink-0">
                          <Receipt className="w-4 h-4" />
                        </div>
                        <div>
                          <div className="font-bold text-text font-mono group-hover:text-emerald-600 transition-colors">
                            {p.receiptNumber} — ₹{Number(p.amount).toLocaleString('en-IN')}
                          </div>
                          <div className="text-[10px] text-text-secondary">
                            {p.studentName} • {p.paymentMode} • {new Date(p.paymentDate).toLocaleDateString('en-GB')}
                          </div>
                        </div>
                      </div>

                      <div className="flex items-center gap-1.5 text-text-muted group-hover:text-emerald-600 transition-colors text-[10px] font-bold">
                        <span>Print Slip</span>
                        <ArrowRight className="w-3.5 h-3.5 group-hover:translate-x-0.5 transition-all" />
                      </div>
                    </button>
                  );
                })}
              </div>
            </div>
          )}

          {/* No results message */}
          {query.trim() && matchedStudents.length === 0 && matchedTeachers.length === 0 && matchedPayments.length === 0 && (
            <div className="py-8 text-center text-text-muted">
              No matching students, roll numbers, teachers, or receipts found for "<span className="text-text font-semibold">{query}</span>".
            </div>
          )}

          {/* Default Quick Actions when query is empty */}
          {!query.trim() && (
            <div>
              <div className="text-[10px] font-bold text-text-secondary uppercase tracking-wider mb-2">
                Quick Shortcuts
              </div>
              <div className="space-y-1">
                {quickNav.map((item, idx) => {
                  const Icon = item.icon;
                  return (
                    <button
                      key={idx}
                      type="button"
                      onClick={item.action}
                      className="w-full p-2.5 rounded-xl hover:bg-surface2 flex items-center justify-between text-text transition-colors cursor-pointer group"
                    >
                      <div className="flex items-center gap-2.5">
                        <Icon className="w-4 h-4 text-primary" />
                        <span className="font-semibold text-xs">{item.label}</span>
                      </div>
                      <ArrowRight className="w-3.5 h-3.5 text-text-muted group-hover:text-primary transition-colors" />
                    </button>
                  );
                })}
              </div>
            </div>
          )}
        </div>

        {/* Footer */}
        <div className="p-3 border-t border-border bg-surface2/50 flex items-center justify-between text-[11px] text-text-muted">
          <span>Search works across all classes, roll numbers & payments</span>
          <kbd className="px-1.5 py-0.5 rounded bg-card border border-border font-mono text-[10px]">ESC to close</kbd>
        </div>
      </div>
    </div>
  );
}
