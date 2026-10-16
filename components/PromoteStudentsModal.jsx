'use client';

import React, { useState, useMemo } from 'react';
import { useSchoolStore } from '../lib/store';
import {
  GraduationCap, X, ArrowRight, CheckCircle2, AlertCircle,
  Users, Check, Search, Sparkles, Filter, RefreshCw
} from 'lucide-react';

const CLASS_PROGRESSION = {
  'Nursery': 'LKG',
  'LKG': 'UKG',
  'UKG': 'Class 1',
  'Class 1': 'Class 2',
  'Class 2': 'Class 3',
  'Class 3': 'Class 4',
  'Class 4': 'Class 5',
  'Class 5': 'Class 6',
  'Class 6': 'Class 7',
  'Class 7': 'Class 8',
  'Class 8': 'Class 9',
  'Class 9': 'Class 10',
  'Class 10': 'Passout / Alumni',
  '1st': '2nd',
  '2nd': '3rd',
  '3rd': '4th',
  '4th': '5th',
  '5th': '6th',
  '6th': '7th',
  '7th': '8th',
  '8th': '9th',
  '9th': '10th',
  '10th': 'Passout / Alumni',
  '11th': '12th',
  '12th': 'Passout / Alumni'
};

export default function PromoteStudentsModal({ isOpen, onClose }) {
  const { students, settings, promoteStudents, showToast } = useSchoolStore();

  const allClasses = settings?.schoolClasses || [
    'Nursery', 'LKG', 'UKG',
    'Class 1', 'Class 2', 'Class 3', 'Class 4', 'Class 5',
    'Class 6', 'Class 7', 'Class 8', 'Class 9', 'Class 10',
    '1st', '2nd', '3rd', '4th', '5th', '6th', '7th', '8th', '9th', '10th'
  ];

  const [fromClass, setFromClass] = useState(allClasses[0] || 'Class 1');
  const [fromSession, setFromSession] = useState('2026-27');
  const [toClass, setToClass] = useState(CLASS_PROGRESSION[fromClass] || 'Class 2');
  const [toSession, setToSession] = useState('2027-28');
  const [toSection, setToSection] = useState('A');
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedIds, setSelectedIds] = useState(new Set());
  const [isPromoting, setIsPromoting] = useState(false);

  // Fee options
  const [updateFeeStructure, setUpdateFeeStructure] = useState(false);
  const [newTotalFee, setNewTotalFee] = useState('');
  const [newMonthlyFee, setNewMonthlyFee] = useState('');
  const [resetPayments, setResetPayments] = useState(true);

  // Handle auto target class on fromClass change
  const handleFromClassChange = (newFrom) => {
    setFromClass(newFrom);
    const suggested = CLASS_PROGRESSION[newFrom] || allClasses[Math.min(allClasses.indexOf(newFrom) + 1, allClasses.length - 1)] || newFrom;
    setToClass(suggested);
  };

  // Filter students belonging to fromClass
  const eligibleStudents = useMemo(() => {
    return students.filter(s => {
      const matchClass = s.className?.toLowerCase() === fromClass?.toLowerCase();
      const matchStatus = s.status !== 'inactive' && s.status !== 'graduated';
      if (!matchClass || !matchStatus) return false;
      if (!searchQuery.trim()) return true;
      const q = searchQuery.toLowerCase();
      return (
        s.name?.toLowerCase().includes(q) ||
        s.rollNumber?.toLowerCase().includes(q) ||
        s.studentId?.toLowerCase().includes(q)
      );
    });
  }, [students, fromClass, searchQuery]);

  // Sync selectedIds when eligible list changes
  React.useEffect(() => {
    setSelectedIds(new Set(eligibleStudents.map(s => s.id)));
  }, [fromClass]);

  if (!isOpen) return null;

  const handleToggleSelectAll = () => {
    if (selectedIds.size === eligibleStudents.length) {
      setSelectedIds(new Set());
    } else {
      setSelectedIds(new Set(eligibleStudents.map(s => s.id)));
    }
  };

  const handleToggleStudent = (id) => {
    const next = new Set(selectedIds);
    if (next.has(id)) next.delete(id);
    else next.add(id);
    setSelectedIds(next);
  };

  const handleExecutePromotion = async () => {
    if (selectedIds.size === 0) {
      showToast?.('Please select at least 1 student to promote!', 'error');
      return;
    }
    if (!toClass) {
      showToast?.('Please select target class!', 'error');
      return;
    }

    setIsPromoting(true);
    try {
      await promoteStudents({
        studentIds: Array.from(selectedIds),
        targetClass: toClass,
        targetSection: toSection,
        targetSession: toSession,
        resetPayments,
        newTotalFee: updateFeeStructure && newTotalFee ? Number(newTotalFee) : null,
        newMonthlyFee: updateFeeStructure && newMonthlyFee ? Number(newMonthlyFee) : null
      });

      showToast?.(`Successfully promoted ${selectedIds.size} students to ${toClass} (${toSession})!`, 'success');
      onClose();
    } catch (err) {
      console.error(err);
      showToast?.('Promotion failed: ' + err.message, 'error');
    } finally {
      setIsPromoting(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-xs animate-in fade-in duration-150">
      <div className="bg-surface border border-border w-full max-w-2xl rounded-2xl shadow-2xl overflow-hidden flex flex-col max-h-[92vh]">
        {/* Modal Header */}
        <div className="p-4 sm:p-5 border-b border-border bg-surface2/50 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-primary/10 text-primary flex items-center justify-center border border-primary/20">
              <GraduationCap className="w-5 h-5" />
            </div>
            <div>
              <h3 className="font-bold text-base text-text flex items-center gap-2">
                1-Click Student Promotion
              </h3>
              <p className="text-xs text-textMuted">
                Promote students to next class and new academic session
              </p>
            </div>
          </div>
          <button
            onClick={onClose}
            className="p-2 rounded-xl text-textMuted hover:text-text hover:bg-surface2 transition-colors cursor-pointer"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Content Body */}
        <div className="p-5 overflow-y-auto space-y-5 flex-1">
          {/* Progression Step Card */}
          <div className="p-4 rounded-xl border border-border bg-surface2/30 grid grid-cols-1 sm:grid-cols-11 gap-3 items-center">
            {/* From Class */}
            <div className="sm:col-span-5 space-y-2">
              <label className="text-[11px] font-bold text-textMuted uppercase tracking-wider">
                Current Class & Session
              </label>
              <div className="grid grid-cols-2 gap-2">
                <select
                  value={fromClass}
                  onChange={(e) => handleFromClassChange(e.target.value)}
                  className="w-full text-xs font-bold p-2.5 rounded-xl border border-border bg-surface text-text focus:outline-hidden focus:border-primary"
                >
                  {allClasses.map(c => (
                    <option key={c} value={c}>{c}</option>
                  ))}
                </select>
                <select
                  value={fromSession}
                  onChange={(e) => setFromSession(e.target.value)}
                  className="w-full text-xs font-bold p-2.5 rounded-xl border border-border bg-surface text-text focus:outline-hidden focus:border-primary"
                >
                  <option value="2024-25">2024-25</option>
                  <option value="2025-26">2025-26</option>
                  <option value="2026-27">2026-27</option>
                  <option value="2027-28">2027-28</option>
                </select>
              </div>
            </div>

            {/* Arrow Divider */}
            <div className="sm:col-span-1 flex justify-center text-primary">
              <div className="w-8 h-8 rounded-full bg-primary/10 flex items-center justify-center">
                <ArrowRight className="w-4 h-4" />
              </div>
            </div>

            {/* Target Class */}
            <div className="sm:col-span-5 space-y-2">
              <label className="text-[11px] font-bold text-emerald-500 uppercase tracking-wider">
                Promote To Class & Session
              </label>
              <div className="grid grid-cols-2 gap-2">
                <select
                  value={toClass}
                  onChange={(e) => setToClass(e.target.value)}
                  className="w-full text-xs font-black p-2.5 rounded-xl border border-emerald-500/40 bg-surface text-text focus:outline-hidden focus:border-emerald-500"
                >
                  {allClasses.map(c => (
                    <option key={c} value={c}>{c}</option>
                  ))}
                  <option value="Passout / Alumni">Passout / Alumni</option>
                </select>
                <select
                  value={toSession}
                  onChange={(e) => setToSession(e.target.value)}
                  className="w-full text-xs font-black p-2.5 rounded-xl border border-emerald-500/40 bg-surface text-text focus:outline-hidden focus:border-emerald-500"
                >
                  <option value="2025-26">2025-26</option>
                  <option value="2026-27">2026-27</option>
                  <option value="2027-28">2027-28</option>
                  <option value="2028-29">2028-29</option>
                </select>
              </div>
            </div>
          </div>

          {/* Student Selection Header */}
          <div className="space-y-2.5">
            <div className="flex items-center justify-between gap-3">
              <div className="flex items-center gap-2">
                <button
                  type="button"
                  onClick={handleToggleSelectAll}
                  className="text-xs font-bold px-3 py-1.5 rounded-lg border border-border bg-surface2 hover:bg-surface text-text flex items-center gap-1.5 cursor-pointer transition-colors"
                >
                  <Check className="w-3.5 h-3.5" />
                  <span>{selectedIds.size === eligibleStudents.length ? 'Deselect All' : 'Select All'}</span>
                </button>
                <span className="text-xs font-bold text-textMuted">
                  Selected: <strong className="text-primary">{selectedIds.size}</strong> / {eligibleStudents.length} Students
                </span>
              </div>

              {/* Search */}
              <div className="relative max-w-xs flex-1">
                <Search className="w-3.5 h-3.5 absolute left-3 top-1/2 -translate-y-1/2 text-textMuted" />
                <input
                  type="text"
                  placeholder="Search student or roll no..."
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  className="w-full pl-8 pr-3 py-1.5 text-xs rounded-xl border border-border bg-surface text-text focus:outline-hidden focus:border-primary"
                />
              </div>
            </div>

            {/* Students Table / List */}
            <div className="border border-border rounded-xl bg-surface overflow-hidden max-h-52 overflow-y-auto divide-y divide-border">
              {eligibleStudents.length === 0 ? (
                <div className="p-8 text-center text-textMuted text-xs">
                  No active students found in <strong>{fromClass}</strong>.
                </div>
              ) : (
                eligibleStudents.map(s => {
                  const isSelected = selectedIds.has(s.id);
                  return (
                    <div
                      key={s.id}
                      onClick={() => handleToggleStudent(s.id)}
                      className={`p-2.5 sm:px-4 flex items-center justify-between gap-3 cursor-pointer transition-colors ${
                        isSelected ? 'bg-primary/5 hover:bg-primary/10' : 'hover:bg-surface2/50'
                      }`}
                    >
                      <div className="flex items-center gap-3 min-w-0">
                        <input
                          type="checkbox"
                          checked={isSelected}
                          onChange={() => {}} // Handled by parent div
                          className="rounded-sm text-primary focus:ring-primary border-border cursor-pointer w-4 h-4"
                        />
                        <div className="w-8 h-8 rounded-lg bg-surface2 border border-border flex items-center justify-center font-bold text-xs text-text overflow-hidden flex-shrink-0">
                          {s.photoUrl || s.photoPath ? (
                            <img src={s.photoUrl || s.photoPath} alt="" className="w-full h-full object-cover" />
                          ) : (
                            s.name?.[0]?.toUpperCase() || 'S'
                          )}
                        </div>
                        <div className="min-w-0">
                          <p className="font-bold text-xs text-text truncate">{s.name}</p>
                          <p className="text-[10px] text-textMuted">
                            Roll: {s.rollNumber || 'N/A'} • Adm: {s.admissionNumber || s.admissionNo || 'N/A'}
                          </p>
                        </div>
                      </div>
                      <div className="text-right flex-shrink-0">
                        <span className="text-[11px] font-bold px-2 py-0.5 rounded-md bg-surface2 text-textMuted border border-border">
                          {s.className} ({s.section || 'A'})
                        </span>
                      </div>
                    </div>
                  );
                })
              )}
            </div>
          </div>

          {/* New Session Fee Settings (Optional) */}
          <div className="p-4 rounded-xl border border-border bg-surface2/30 space-y-3">
            <div className="flex items-center justify-between">
              <label className="text-xs font-bold text-text flex items-center gap-2 cursor-pointer">
                <input
                  type="checkbox"
                  checked={updateFeeStructure}
                  onChange={(e) => setUpdateFeeStructure(e.target.checked)}
                  className="rounded-sm text-primary focus:ring-primary border-border cursor-pointer w-4 h-4"
                />
                <span>Set New Fee Structure for <strong>{toClass}</strong> ({toSession})</span>
              </label>
            </div>

            {updateFeeStructure && (
              <div className="grid grid-cols-2 gap-3 pt-2">
                <div>
                  <label className="block text-[11px] font-bold text-textMuted mb-1">New Total / Annual Fee (₹)</label>
                  <input
                    type="number"
                    placeholder="e.g. 6000"
                    value={newTotalFee}
                    onChange={(e) => setNewTotalFee(e.target.value)}
                    className="w-full text-xs font-bold p-2.5 rounded-xl border border-border bg-surface text-text focus:outline-hidden focus:border-primary"
                  />
                </div>
                <div>
                  <label className="block text-[11px] font-bold text-textMuted mb-1">New Monthly Fee (₹)</label>
                  <input
                    type="number"
                    placeholder="e.g. 500"
                    value={newMonthlyFee}
                    onChange={(e) => setNewMonthlyFee(e.target.value)}
                    className="w-full text-xs font-bold p-2.5 rounded-xl border border-border bg-surface text-text focus:outline-hidden focus:border-primary"
                  />
                </div>
              </div>
            )}
          </div>
        </div>

        {/* Footer Actions */}
        <div className="p-4 border-t border-border bg-surface2/30 flex items-center justify-between gap-3">
          <button
            type="button"
            onClick={onClose}
            className="px-4 py-2.5 rounded-xl border border-border hover:bg-surface2 text-xs font-bold text-textMuted hover:text-text transition-colors cursor-pointer"
          >
            Cancel
          </button>

          <button
            type="button"
            disabled={isPromoting || selectedIds.size === 0}
            onClick={handleExecutePromotion}
            className="px-6 py-2.5 rounded-xl bg-primary hover:bg-primaryHover text-white text-xs font-black transition-all flex items-center gap-2 shadow-sm disabled:opacity-50 cursor-pointer"
          >
            {isPromoting ? (
              <>
                <RefreshCw className="w-4 h-4 animate-spin" />
                <span>Promoting Students...</span>
              </>
            ) : (
              <>
                <GraduationCap className="w-4 h-4" />
                <span>Promote {selectedIds.size} Students Now</span>
              </>
            )}
          </button>
        </div>
      </div>
    </div>
  );
}
