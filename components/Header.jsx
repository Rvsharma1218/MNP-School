'use client';

import React, { useState, useEffect, useRef } from 'react';
import { useSchoolStore } from '../lib/store';
import { t } from '../lib/translations';
import {
  Menu, Search, Plus, CreditCard, Clock, Calendar, ShieldCheck,
  UserCheck, Bell, ChevronDown, User, Settings, Key, LogOut, X, ShieldAlert,
  Wifi, WifiOff, RefreshCw, CheckCircle2, AlertCircle, ArrowLeft,
  Receipt, Eye, GraduationCap, ArrowRight, HelpCircle, Languages,
  Sun, Moon, MessageSquare
} from 'lucide-react';

export default function Header({ onMenuClick }) {
  const {
    settings,
    stats,
    themeMode,
    toggleTheme,
    students,
    teachers,
    payments,
    setIsAddStudentOpen,
    setIsGlobalSearchOpen,
    setSelectedStudentId,
    setViewingStudentProfile,
    setFeeDetailStudent,
    setIsFeeDetailSelectorOpen,
    setPrintReceiptData,
    calculateStudentFeeMetrics,
    currentUser,
    logout,
    currentPath,
    navigate,
    syncStatus,
    notices,
    unreadNoticeCount,
    setViewingNotice,
    markNoticeAsRead,
    markAllNoticesAsRead,
    showToast,
    setIsHelpFeedbackOpen,
    updateSettings,
    teacherPermissions
  } = useSchoolStore();

  const [mounted, setMounted] = useState(false);
  const [time, setTime] = useState(new Date());
  const [isDropdownOpen, setIsDropdownOpen] = useState(false);
  const [isNotificationsOpen, setIsNotificationsOpen] = useState(false);
  const [isLogoutModalOpen, setIsLogoutModalOpen] = useState(false);
  const [browserPerm, setBrowserPerm] = useState('granted');
  const dropdownRef = useRef(null);
  const notifRef = useRef(null);

  // Universal Header Search State
  const [headerSearchQuery, setHeaderSearchQuery] = useState('');
  const [isSearchDropdownOpen, setIsSearchDropdownOpen] = useState(false);
  const searchContainerRef = useRef(null);
  const searchInputRef = useRef(null);

  useEffect(() => {
    setMounted(true);
    const t = setInterval(() => setTime(new Date()), 1000);
    if (typeof window !== 'undefined' && 'Notification' in window) {
      setBrowserPerm(Notification.permission);
    }
    return () => clearInterval(t);
  }, []);

  const enableDesktopNotifications = async () => {
    if (typeof window !== 'undefined' && 'Notification' in window) {
      try {
        const p = await Notification.requestPermission();
        setBrowserPerm(p);
        if (p === 'granted') {
          showToast('Desktop notifications enabled!', 'success');
        }
      } catch (_) { }
    }
  };

  // Close dropdowns on click outside
  useEffect(() => {
    const handleOutsideClick = (e) => {
      if (searchContainerRef.current && !searchContainerRef.current.contains(e.target)) {
        setIsSearchDropdownOpen(false);
      }
      if (dropdownRef.current && !dropdownRef.current.contains(e.target)) {
        setIsDropdownOpen(false);
      }
      if (notifRef.current && !notifRef.current.contains(e.target)) {
        setIsNotificationsOpen(false);
      }
    };
    document.addEventListener('mousedown', handleOutsideClick);
    return () => document.removeEventListener('mousedown', handleOutsideClick);
  }, []);

  // Keyboard shortcut: Ctrl+K or Cmd+K to open Universal Search
  useEffect(() => {
    const handleKeyDown = (e) => {
      if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'k') {
        e.preventDefault();
        if (searchInputRef.current && window.innerWidth >= 768) {
          searchInputRef.current.focus();
          setIsSearchDropdownOpen(true);
        } else {
          setIsGlobalSearchOpen(prev => !prev);
        }
      }
      if (e.key === 'Escape') {
        setIsSearchDropdownOpen(false);
      }
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [setIsGlobalSearchOpen]);

  if (!currentUser) return null;

  const lang = settings?.appLanguage || 'en';

  const viewTitles = {
    '/dashboard': t('dashboard', lang),
    '/notices': t('notices', lang),
    '/students': t('students', lang),
    '/fees': t('fees', lang),
    '/attendance': t('attendance', lang),
    '/results': t('results', lang),
    '/classes': t('classes', lang),
    '/timetable': t('timetable', lang),
    '/idcards': t('idcards', lang),
    '/admitcards': t('admitcards', lang),
    '/teachers': t('teachers', lang),
    '/reports': t('reports', lang),
    '/qrscanner': lang === 'hi' ? 'QR स्कैनर' : 'QR Scanner',
    '/settings': t('settings', lang),
    '/users': lang === 'hi' ? 'यूज़र अकाउंट्स' : 'User Account Management',
    '/profile': t('profile', lang),
    '/subscription': t('subscription', lang),
    '/setup': lang === 'hi' ? 'सेटअप विज़ार्ड' : 'Initial Setup Wizard',
    '/access-denied': lang === 'hi' ? 'अनुमति अस्वीकृत' : 'Access Restrained'
  };

  const isPrincipal = currentUser.role === 'principal';
  const currentUserId = currentUser.uid || currentUser.teacherId || currentUser.id || '';

  const principalDisplayName = (() => {
    if (!currentUser) return 'Principal';
    if (currentUser.role === 'principal' && settings.principalName && settings.principalName.trim() !== '') {
      return settings.principalName.trim();
    }
    if (currentUser.displayName && currentUser.displayName.trim() !== '') {
      return currentUser.displayName.trim();
    }
    const raw = currentUser.name || '';
    if (!raw) return currentUser.role === 'principal' ? 'Principal' : 'Teacher';
    const clean = raw.includes('@') ? raw.split('@')[0] : raw;
    const alphaOnly = clean.replace(/[0-9_.-]/g, ' ').trim();
    if (alphaOnly && alphaOnly.length >= 3) {
      return alphaOnly.split(/\s+/).map(w => w.charAt(0).toUpperCase() + w.slice(1).toLowerCase()).join(' ');
    }
    return clean.charAt(0).toUpperCase() + clean.slice(1);
  })();

  const avatarInitials = principalDisplayName
    .split(' ')
    .filter(Boolean)
    .map(w => w[0])
    .slice(0, 2)
    .join('')
    .toUpperCase() || 'PR';

  const handleLogoutConfirm = () => {
    setIsLogoutModalOpen(false);
    logout();
  };

  const searchQ = headerSearchQuery.trim().toLowerCase();

  const matchedStudents = searchQ
    ? (students || []).filter(s => {
        return (
          String(s.name || '').toLowerCase().includes(searchQ) ||
          String(s.studentId || '').toLowerCase().includes(searchQ) ||
          String(s.admissionNumber || s.admissionNo || '').toLowerCase().includes(searchQ) ||
          String(s.rollNumber || '').toLowerCase().includes(searchQ) ||
          String(s.mobile || '').includes(searchQ) ||
          String(s.fatherName || '').toLowerCase().includes(searchQ) ||
          String(s.motherName || '').toLowerCase().includes(searchQ) ||
          String(s.className || '').toLowerCase().includes(searchQ) ||
          String(s.section || '').toLowerCase().includes(searchQ) ||
          String(s.course || '').toLowerCase().includes(searchQ) ||
          String(s.batch || '').toLowerCase().includes(searchQ)
        );
      }).slice(0, 5)
    : [];

  const matchedTeachers = searchQ
    ? (teachers || []).filter(t => {
        return (
          String(t.name || '').toLowerCase().includes(searchQ) ||
          String(t.teacherId || '').toLowerCase().includes(searchQ) ||
          String(t.mobile || '').includes(searchQ) ||
          String(t.subject || '').toLowerCase().includes(searchQ) ||
          String(t.designation || '').toLowerCase().includes(searchQ)
        );
      }).slice(0, 3)
    : [];

  const matchedPayments = searchQ
    ? (payments || []).filter(p => {
        return (
          String(p.receiptNumber || '').toLowerCase().includes(searchQ) ||
          String(p.studentName || '').toLowerCase().includes(searchQ) ||
          String(p.studentId || '').toLowerCase().includes(searchQ) ||
          String(p.amount || '').includes(searchQ) ||
          String(p.paymentMode || '').toLowerCase().includes(searchQ)
        );
      }).slice(0, 3)
    : [];

  const navShortcuts = [
    { title: 'Student Directory', path: '/students', tag: 'Directory' },
    { title: 'Fee Structure & Collections', path: '/fees', tag: 'Billing' },
    { title: 'Daily Attendance Register', path: '/attendance', tag: 'Attendance' },
    { title: 'Exam Results & Marksheets', path: '/results', tag: 'Academic' },
    { title: 'ID Cards Studio', path: '/idcards', tag: 'Printing' },
    { title: 'Faculty & Teachers', path: '/teachers', tag: 'Staff' },
    { title: 'Notice Board & Circulars', path: '/notices', tag: 'Notices' },
    { title: 'System Settings', path: '/settings', tag: 'System' },
  ];

  const matchedPages = searchQ
    ? navShortcuts.filter(p =>
        p.title.toLowerCase().includes(searchQ) ||
        p.path.toLowerCase().includes(searchQ) ||
        p.tag.toLowerCase().includes(searchQ)
      ).slice(0, 3)
    : [];

  const hasAnyResults = matchedStudents.length > 0 || matchedTeachers.length > 0 || matchedPayments.length > 0 || matchedPages.length > 0;

  return (
    <header className="sticky top-0 z-30 flex items-center justify-between px-5 lg:px-8 h-16 w-full bg-white/90 backdrop-blur-md border-b border-border shadow-sm">
      
      {/* Left */}
      <div className="flex items-center gap-2 sm:gap-4 min-w-0">
        <button
          onClick={onMenuClick}
          className="lg:hidden p-2 rounded-xl bg-surface2 hover:bg-border text-text transition-colors cursor-pointer"
          title="Open Menu"
        >
          <Menu className="w-5 h-5" />
        </button>
        {currentPath !== '/dashboard' && (
          <button
            onClick={() => {
              if (typeof window !== 'undefined' && window.history.length > 1) {
                window.history.back();
              } else {
                navigate('/dashboard');
              }
            }}
            className="p-2 rounded-xl bg-surface2 hover:bg-border text-text transition-colors cursor-pointer flex items-center justify-center"
            title="Go Back"
          >
            <ArrowLeft className="w-5 h-5" />
          </button>
        )}
        <div className="min-w-0">
          <h1 className="text-base sm:text-lg font-bold text-text truncate">{viewTitles[currentPath] || 'Dashboard'}</h1>
          <p className="text-xs text-text-secondary font-semibold truncate hidden sm:block">
            {settings.instituteName || 'School Management'} &nbsp;·&nbsp; Session {settings.currentSession || '2026-27'}
          </p>
        </div>
      </div>

      {/* Center — Universal Search Bar (Desktop / Tablet) */}
      <div ref={searchContainerRef} className="relative flex-1 max-w-md mx-2 sm:mx-4 hidden md:block">
        <div className={`relative flex items-center h-10 w-full rounded-xl border transition-all ${
          isSearchDropdownOpen
            ? 'bg-white border-primary shadow-md ring-2 ring-primary/20'
            : 'bg-surface2 hover:bg-white border-border hover:border-border-focus'
        }`}>
          <Search className={`w-4 h-4 ml-3.5 flex-shrink-0 transition-colors ${
            isSearchDropdownOpen ? 'text-primary' : 'text-text-muted'
          }`} />
          <input
            ref={searchInputRef}
            type="text"
            value={headerSearchQuery}
            onChange={(e) => {
              setHeaderSearchQuery(e.target.value);
              if (!isSearchDropdownOpen) setIsSearchDropdownOpen(true);
            }}
            onFocus={() => setIsSearchDropdownOpen(true)}
            onKeyDown={(e) => {
              if (e.key === 'Enter') {
                setIsSearchDropdownOpen(false);
                setIsGlobalSearchOpen(true);
              }
            }}
            placeholder="Universal search: student, roll, fee, teacher..."
            className="flex-1 bg-transparent px-3 text-xs text-text placeholder-text-muted focus:outline-none font-medium truncate"
          />
          {headerSearchQuery ? (
            <button
              type="button"
              onClick={() => {
                setHeaderSearchQuery('');
                searchInputRef.current?.focus();
              }}
              className="p-1 mr-2 rounded-md hover:bg-surface2 text-text-muted hover:text-text cursor-pointer transition-colors"
              title="Clear search"
            >
              <X className="w-3.5 h-3.5" />
            </button>
          ) : (
            <button
              type="button"
              onClick={() => setIsGlobalSearchOpen(true)}
              className="mr-2 text-[10px] bg-white border border-border rounded px-1.5 py-0.5 font-mono text-text-muted font-bold shadow-2xs hover:border-primary/50 cursor-pointer"
              title="Click or press Ctrl+K for full search"
            >
              Ctrl K
            </button>
          )}
        </div>

        {/* Live Search Floating Dropdown */}
        {isSearchDropdownOpen && (
          <div className="absolute top-full left-0 right-0 mt-2 bg-card border border-border rounded-2xl shadow-2xl overflow-hidden z-50 animate-in fade-in slide-in-from-top-2 duration-150">
            <div className="max-h-[420px] overflow-y-auto p-3 space-y-3 custom-scrollbar text-xs">
              
              {/* When query is empty -> Quick Suggestions */}
              {!searchQ && (
                <div>
                  <div className="text-[10px] font-bold text-text-secondary uppercase tracking-wider px-1 mb-1.5 flex items-center justify-between">
                    <span>Quick Navigation</span>
                    <span className="text-[9px] text-text-muted font-normal">Type to search anything</span>
                  </div>
                  <div className="grid grid-cols-2 gap-1.5">
                    {navShortcuts.slice(0, 4).map((item, idx) => (
                      <button
                        key={idx}
                        type="button"
                        onClick={() => {
                          navigate(item.path);
                          setIsSearchDropdownOpen(false);
                        }}
                        className="p-2 rounded-xl bg-surface2/60 hover:bg-surface2 border border-border/40 hover:border-primary/30 flex items-center justify-between text-left transition-all cursor-pointer group"
                      >
                        <span className="font-semibold text-text group-hover:text-primary transition-colors truncate">{item.title}</span>
                        <ArrowRight className="w-3 h-3 text-text-muted group-hover:text-primary group-hover:translate-x-0.5 transition-all flex-shrink-0" />
                      </button>
                    ))}
                  </div>
                </div>
              )}

              {/* Matched Students */}
              {matchedStudents.length > 0 && (
                <div>
                  <div className="text-[10px] font-bold text-text-secondary uppercase tracking-wider px-1 mb-1.5 flex items-center justify-between">
                    <span>Students ({matchedStudents.length})</span>
                    <span className="text-[9px] text-text-muted font-normal">Profile & Fee Actions</span>
                  </div>
                  <div className="space-y-1.5">
                    {matchedStudents.map(s => {
                      const metrics = calculateStudentFeeMetrics ? calculateStudentFeeMetrics(s, payments) : null;
                      const sDue = metrics ? metrics.currentDue : Math.max(0, (Number(s.totalFees) || 0) - (Number(s.paidFees) || 0));

                      return (
                        <div
                          key={s.id}
                          className="p-2 rounded-xl bg-surface2/40 hover:bg-surface2 border border-border/50 hover:border-primary/40 flex items-center justify-between gap-2 transition-all group"
                        >
                          <button
                            type="button"
                            onClick={() => {
                              setSelectedStudentId(s.id);
                              setViewingStudentProfile(s);
                              setIsSearchDropdownOpen(false);
                            }}
                            className="flex items-center gap-2.5 flex-1 text-left min-w-0 cursor-pointer"
                          >
                            <div className="w-8 h-8 rounded-lg bg-primary/10 text-primary flex items-center justify-center font-bold text-xs flex-shrink-0 overflow-hidden">
                              {s.photoPath || s.photoUrl ? (
                                <img src={s.photoPath || s.photoUrl} alt={s.name} className="w-full h-full object-cover" />
                              ) : (
                                s.name?.charAt(0) || 'S'
                              )}
                            </div>
                            <div className="min-w-0 flex-1">
                              <div className="font-bold text-text group-hover:text-primary transition-colors flex items-center gap-1.5 truncate">
                                <span>{s.name}</span>
                                <span className="text-[9px] px-1 rounded bg-surface border border-border text-text-secondary font-mono">
                                  Roll: {s.rollNumber || '-'}
                                </span>
                              </div>
                              <div className="text-[10px] text-text-secondary truncate">
                                {s.studentType === 'school' ? `Class ${s.className || ''} (${s.section || 'A'})` : s.course} • ID: {s.studentId}
                              </div>
                            </div>
                          </button>

                          <div className="flex items-center gap-1.5 flex-shrink-0">
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
                                setIsSearchDropdownOpen(false);
                              }}
                              className="px-2 py-1 rounded-lg bg-emerald-600 hover:bg-emerald-500 text-white font-bold text-[10px] flex items-center gap-1 cursor-pointer transition-colors shadow-2xs"
                              title="Open Fee Structure & Collect Payment"
                            >
                              <CreditCard className="w-3 h-3" />
                              <span>Pay</span>
                            </button>

                            <button
                              type="button"
                              onClick={() => {
                                setSelectedStudentId(s.id);
                                setViewingStudentProfile(s);
                                setIsSearchDropdownOpen(false);
                              }}
                              className="p-1 rounded-lg text-text-muted hover:text-text hover:bg-card cursor-pointer transition-colors"
                              title="View Full Profile"
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
                  <div className="text-[10px] font-bold text-text-secondary uppercase tracking-wider px-1 mb-1.5">
                    Faculty & Teachers ({matchedTeachers.length})
                  </div>
                  <div className="space-y-1.5">
                    {matchedTeachers.map(t => (
                      <button
                        key={t.id}
                        type="button"
                        onClick={() => {
                          navigate('/teachers');
                          setIsSearchDropdownOpen(false);
                        }}
                        className="w-full p-2 rounded-xl bg-surface2/40 hover:bg-surface2 border border-border/50 hover:border-primary/40 flex items-center justify-between text-left transition-colors cursor-pointer group"
                      >
                        <div className="flex items-center gap-2.5 min-w-0">
                          <div className="w-7 h-7 rounded-lg bg-indigo-500/10 text-indigo-600 flex items-center justify-center font-bold text-[11px] flex-shrink-0">
                            <GraduationCap className="w-3.5 h-3.5" />
                          </div>
                          <div className="truncate">
                            <span className="font-bold text-text group-hover:text-primary transition-colors">{t.name}</span>
                            <span className="text-[10px] text-text-secondary ml-1.5">({t.teacherId || 'Teacher'}) • {t.subject || t.designation || 'Faculty'}</span>
                          </div>
                        </div>
                        <span className="text-[10px] text-primary font-bold">View Staff →</span>
                      </button>
                    ))}
                  </div>
                </div>
              )}

              {/* Matched Receipts */}
              {matchedPayments.length > 0 && (
                <div>
                  <div className="text-[10px] font-bold text-text-secondary uppercase tracking-wider px-1 mb-1.5">
                    Matching Fee Receipts ({matchedPayments.length})
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
                            setIsSearchDropdownOpen(false);
                          }}
                          className="w-full p-2 rounded-xl bg-surface2/40 hover:bg-surface2 border border-border/50 hover:border-emerald-500/40 flex items-center justify-between text-left transition-colors cursor-pointer group"
                        >
                          <div className="flex items-center gap-2.5 min-w-0">
                            <div className="w-7 h-7 rounded-lg bg-emerald-500/10 text-emerald-600 flex items-center justify-center font-bold text-[11px] flex-shrink-0">
                              <Receipt className="w-3.5 h-3.5" />
                            </div>
                            <div className="truncate">
                              <span className="font-mono font-bold text-text group-hover:text-emerald-600 transition-colors">{p.receiptNumber}</span>
                              <span className="text-[10px] text-text-secondary ml-1.5">₹{Number(p.amount).toLocaleString('en-IN')} • {p.studentName}</span>
                            </div>
                          </div>
                          <span className="text-[10px] text-emerald-600 font-bold">Print Slip →</span>
                        </button>
                      );
                    })}
                  </div>
                </div>
              )}

              {/* Matched Pages */}
              {matchedPages.length > 0 && (
                <div>
                  <div className="text-[10px] font-bold text-text-secondary uppercase tracking-wider px-1 mb-1.5">
                    Navigation Pages
                  </div>
                  <div className="space-y-1">
                    {matchedPages.map((pg, idx) => (
                      <button
                        key={idx}
                        type="button"
                        onClick={() => {
                          navigate(pg.path);
                          setIsSearchDropdownOpen(false);
                        }}
                        className="w-full p-2 rounded-xl hover:bg-surface2 flex items-center justify-between text-left cursor-pointer group"
                      >
                        <span className="font-semibold text-text group-hover:text-primary transition-colors">{pg.title}</span>
                        <span className="text-[10px] text-text-muted">{pg.path}</span>
                      </button>
                    ))}
                  </div>
                </div>
              )}

              {/* No Results Message */}
              {searchQ && !hasAnyResults && (
                <div className="py-6 text-center text-text-muted">
                  <p className="text-xs">No matching student, roll number, teacher, or receipt found.</p>
                  <button
                    type="button"
                    onClick={() => {
                      setIsSearchDropdownOpen(false);
                      setIsGlobalSearchOpen(true);
                    }}
                    className="mt-2 text-[11px] text-primary font-bold hover:underline cursor-pointer"
                  >
                    Open Universal Command Search →
                  </button>
                </div>
              )}
            </div>

            {/* Dropdown Bottom Bar */}
            <div className="p-2.5 px-3 border-t border-border bg-surface2/60 flex items-center justify-between text-[10px] text-text-muted">
              <span>Press <kbd className="px-1 py-0.5 rounded bg-card border border-border font-mono text-[9px]">Enter</kbd> or click button for full modal</span>
              <button
                type="button"
                onClick={() => {
                  setIsSearchDropdownOpen(false);
                  setIsGlobalSearchOpen(true);
                }}
                className="font-bold text-primary hover:underline cursor-pointer flex items-center gap-1"
              >
                <span>Full Search Modal</span>
                <ArrowRight className="w-3 h-3" />
              </button>
            </div>
          </div>
        )}
      </div>

      {/* Right */}
      <div className="flex items-center gap-2 sm:gap-3.5 flex-shrink-0">
        {/* Mobile Search Icon Button */}
        <button
          type="button"
          onClick={() => setIsGlobalSearchOpen(true)}
          className="md:hidden p-2 rounded-xl bg-surface2 hover:bg-border text-text transition-colors cursor-pointer border border-border shadow-2xs"
          title="Search"
        >
          <Search className="w-4.5 h-4.5" />
        </button>
        {/* Date & Time */}
        {mounted && (
          <div className="hidden lg:flex items-center gap-2 px-3.5 py-2 rounded-xl bg-surface2 border border-border text-xs font-bold text-text">
            <Calendar className="w-4 h-4 text-primary" />
            <span>{time.toLocaleDateString('en-IN', { weekday: 'short', day: 'numeric', month: 'short', year: 'numeric' })}</span>
            <span className="text-text-muted mx-1">·</span>
            <Clock className="w-4 h-4 text-primary" />
            <span>{time.toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit', hour12: true }).toUpperCase()}</span>
          </div>
        )}

        {/* Add Student */}
        {(isPrincipal || teacherPermissions?.canAddStudents !== false) && (
          <button
            onClick={() => setIsAddStudentOpen(true)}
            className="hidden sm:flex items-center gap-2 px-3.5 py-2 rounded-xl bg-primary hover:bg-primary-dark text-white font-bold text-xs shadow-md transition-all cursor-pointer"
          >
            <Plus className="w-4 h-4" />
            <span className="hidden lg:inline">{lang === 'hi' ? 'छात्र जोड़ें' : 'Add Student'}</span>
          </button>
        )}

        {/* Firebase Sync Status Indicator */}
        {(() => {
          const configs = {
            synced:       { icon: CheckCircle2, label: 'Live', cls: 'text-emerald-600 bg-emerald-50 border-emerald-200' },
            syncing:      { icon: RefreshCw,    label: 'Syncing…', cls: 'text-blue-600 bg-blue-50 border-blue-200 animate-pulse' },
            reconnecting: { icon: WifiOff,      label: 'Reconnecting…', cls: 'text-amber-600 bg-amber-50 border-amber-200 animate-pulse' },
            cached:       { icon: Wifi,         label: 'Cached', cls: 'text-slate-500 bg-slate-50 border-slate-200' },
            error:        { icon: AlertCircle,  label: 'Sync Error', cls: 'text-rose-600 bg-rose-50 border-rose-200' },
          };
          const cfg = configs[syncStatus] || configs.syncing;
          const Icon = cfg.icon;
          return (
            <div
              title={`Firebase sync: ${syncStatus}`}
              className={`hidden sm:flex items-center gap-1.5 px-2.5 py-1 rounded-full border text-[10px] font-bold transition-all ${cfg.cls}`}
            >
              <Icon className="w-3 h-3" />
              <span className="hidden lg:inline">{cfg.label}</span>
            </div>
          );
        })()}

        {/* ── Notification Bell with Real-Time Notice Badges ── */}
        <div className="relative" ref={notifRef}>
          <button
            onClick={() => setIsNotificationsOpen(p => !p)}
            className="p-2 rounded-xl bg-[#eff4ff] hover:bg-[#dce9ff] text-[#464553] hover:text-[#0b1c30] transition-colors relative cursor-pointer border border-[#c8c4d5]/50 shadow-2xs"
            title="Notice Board & Notifications"
          >
            <Bell className="w-4.5 h-4.5" />
            {unreadNoticeCount > 0 && (
              <span className="absolute -top-1 -right-1 min-w-[18px] h-[18px] px-1 rounded-full bg-rose-600 text-white text-[10px] font-black flex items-center justify-center shadow-md animate-pulse">
                {unreadNoticeCount > 9 ? '9+' : unreadNoticeCount}
              </span>
            )}
          </button>

          {/* Notifications Popover Menu */}
          {isNotificationsOpen && (
            <div className="absolute right-0 mt-2 w-80 sm:w-96 bg-white border border-[#c8c4d5]/60 rounded-2xl shadow-2xl overflow-hidden text-xs z-50 animate-in fade-in slide-in-from-top-3 duration-200">
              
              {/* Header */}
              <div className="p-3.5 bg-gradient-to-r from-[#1f108e] to-[#0f0069] text-white flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <Bell className="w-4 h-4" />
                  <span className="font-bold text-sm">Notice Board Alerts</span>
                  {unreadNoticeCount > 0 && (
                    <span className="px-2 py-0.2 rounded-full bg-rose-500 text-white text-[10px] font-extrabold">
                      {unreadNoticeCount} new
                    </span>
                  )}
                </div>

                {unreadNoticeCount > 0 && (
                  <button
                    onClick={() => markAllNoticesAsRead()}
                    className="text-[11px] text-white/80 hover:text-white underline cursor-pointer font-medium"
                  >
                    Mark all read
                  </button>
                )}
              </div>

              {/* Browser Desktop Notification Permission Banner */}
              {browserPerm === 'default' && (
                <div className="p-2.5 bg-amber-50 border-b border-amber-200 flex items-center justify-between gap-2">
                  <div className="flex items-center gap-1.5 text-[11px] text-amber-800 font-semibold">
                    <Bell className="w-3.5 h-3.5 text-amber-600 flex-shrink-0" />
                    <span>Get screen alerts for new circulars</span>
                  </div>
                  <button
                    onClick={enableDesktopNotifications}
                    className="px-2.5 py-1 rounded-lg bg-amber-600 hover:bg-amber-700 text-white text-[10px] font-bold cursor-pointer whitespace-nowrap shadow-2xs"
                  >
                    Enable Alerts
                  </button>
                </div>
              )}

              {/* Notice List */}
              <div className="max-h-80 overflow-y-auto divide-y divide-[#c8c4d5]/30">
                {notices.length > 0 ? (
                  notices.slice(0, 6).map((notice) => {
                    const isRead = currentUserId ? (notice.readBy || []).includes(currentUserId) : true;
                    const date = notice.createdAt ? new Date(notice.createdAt) : new Date();
                    const timeAgo = date.toLocaleDateString('en-IN', { day: 'numeric', month: 'short' });

                    return (
                      <div
                        key={notice.id}
                        onClick={() => {
                          setIsNotificationsOpen(false);
                          setViewingNotice(notice);
                        }}
                        className={`p-3.5 hover:bg-[#eff4ff]/60 transition-colors cursor-pointer flex items-start gap-3 ${
                          !isRead ? 'bg-[#eff4ff]/40' : ''
                        }`}
                      >
                        <div className="mt-0.5 flex-shrink-0">
                          {!isRead ? (
                            <span className="w-2.5 h-2.5 rounded-full bg-rose-500 ring-2 ring-rose-200 block" />
                          ) : (
                            <span className="w-2 h-2 rounded-full bg-slate-300 block" />
                          )}
                        </div>

                        <div className="flex-1 min-w-0">
                          <div className="flex items-center justify-between gap-1 mb-1">
                            <span className="text-[10px] font-bold px-2 py-0.2 rounded-md bg-[#dce9ff] text-[#0051d5] uppercase">
                              {notice.category || 'General'}
                            </span>
                            <span className="text-[10px] text-[#777584]">{timeAgo}</span>
                          </div>

                          <p className="font-bold text-xs text-[#0b1c30] truncate leading-tight">
                            {notice.title}
                          </p>

                          {notice.content && (
                            <p className="text-[11px] text-[#777584] line-clamp-1 mt-0.5">
                              {notice.content}
                            </p>
                          )}
                        </div>
                      </div>
                    );
                  })
                ) : (
                  <div className="p-6 text-center text-[#777584]">
                    <Bell className="w-6 h-6 mx-auto mb-1 opacity-40" />
                    <p className="text-xs font-semibold">No circulars or notices yet</p>
                  </div>
                )}
              </div>

              {/* Bottom Footer */}
              <div className="p-2.5 bg-[#eff4ff]/60 border-t border-[#c8c4d5]/40 text-center">
                <button
                  onClick={() => {
                    setIsNotificationsOpen(false);
                    navigate('/notices');
                  }}
                  className="text-xs font-bold text-[#1f108e] hover:underline cursor-pointer"
                >
                  View Full Notice Board →
                </button>
              </div>

            </div>
          )}
        </div>

        {/* Quick Language Switcher Toggle */}
        <button
          type="button"
          onClick={() => {
            const nextLang = lang === 'hi' ? 'en' : 'hi';
            updateSettings({ appLanguage: nextLang });
            showToast(nextLang === 'hi' ? 'पोर्टल भाषा हिन्दी में बदल दी गई है' : 'Display language switched to English', 'success');
          }}
          className="flex items-center gap-1.5 px-3 py-2 rounded-xl bg-[#eff4ff] hover:bg-[#dce9ff] text-[#1f108e] transition-all cursor-pointer border border-[#c8c4d5]/50 shadow-2xs font-extrabold text-xs"
          title={lang === 'hi' ? 'अंग्रेज़ी भाषा में बदलें (Switch to English)' : 'Switch to Hindi (हिन्दी भाषा चुनें)'}
        >
          <Languages className="w-4 h-4 text-[#1f108e]" />
          <span className="font-bold text-[11px]">{lang === 'hi' ? 'हिन्दी' : 'English'}</span>
        </button>

        {/* Quick Help and Feedback Trigger */}
        <button
          type="button"
          onClick={() => setIsHelpFeedbackOpen(true)}
          className="p-2 rounded-xl bg-[#eff4ff] hover:bg-[#dce9ff] text-[#464553] hover:text-[#0b1c30] transition-colors relative cursor-pointer border border-[#c8c4d5]/50 shadow-2xs"
          title="Help and feedback (FAQs, Support, Reports)"
        >
          <HelpCircle className="w-4.5 h-4.5 text-[#1f108e]" />
        </button>

        {/* Dark / Light Mode Theme Toggle */}
        <button
          type="button"
          onClick={toggleTheme}
          className="p-2 rounded-xl bg-[#eff4ff] hover:bg-[#dce9ff] text-[#1f108e] transition-colors cursor-pointer border border-[#c8c4d5]/50 shadow-2xs"
          title={themeMode === 'dark' ? 'Switch to Light Mode' : 'Switch to Dark Mode'}
        >
          {themeMode === 'dark' ? (
            <Sun className="w-4.5 h-4.5 text-amber-500" />
          ) : (
            <Moon className="w-4.5 h-4.5 text-[#1f108e]" />
          )}
        </button>

        {/* Quick Parent Complaints Desk Shortcut */}
        <button
          type="button"
          onClick={() => navigate('/complaints')}
          className="p-2 rounded-xl bg-[#eff4ff] hover:bg-[#dce9ff] text-[#1f108e] transition-colors relative cursor-pointer border border-[#c8c4d5]/50 shadow-2xs"
          title="Parent Complaints & Messages Desk"
        >
          <MessageSquare className="w-4.5 h-4.5 text-[#1f108e]" />
        </button>

        {/* User Info Profile Dropdown */}
        <div className="relative" ref={dropdownRef}>
          <button
            onClick={() => setIsDropdownOpen(p => !p)}
            className="flex items-center gap-2.5 pl-2 border-l border-border hover:opacity-85 transition-opacity cursor-pointer text-left"
          >
            <div className="w-10 h-10 rounded-full border border-border bg-primary/10 text-primary flex items-center justify-center font-bold text-sm overflow-hidden flex-shrink-0 shadow-2xs">
              {currentUser.photoPath ? (
                <img src={currentUser.photoPath} alt={principalDisplayName} className="w-full h-full object-cover" />
              ) : (
                avatarInitials
              )}
            </div>
            <div className="hidden lg:block leading-none">
              <p className="font-bold text-xs text-text">{principalDisplayName}</p>
              <p className="text-[10px] text-text-secondary mt-0.5 capitalize">{currentUser.role === 'principal' ? 'Principal / Admin' : 'Teacher'}</p>
            </div>
            <ChevronDown className="w-4 h-4 text-text-secondary hidden lg:block" />
          </button>

          {/* Premium Dropdown menu */}
          {isDropdownOpen && (
            <div className="absolute right-0 mt-2 w-64 bg-card border border-border rounded-2xl shadow-xl py-2 overflow-hidden text-xs z-50 animate-in fade-in slide-in-from-top-3 duration-200">
              {/* Profile Card Header */}
              <div className="px-4 py-3 border-b border-border space-y-1">
                <p className="font-bold text-text leading-tight">{principalDisplayName}</p>
                <p className="text-[10px] text-text-secondary font-mono">{currentUser.email}</p>
                <div className="inline-flex items-center gap-1 mt-1 px-1.5 py-0.5 rounded bg-primary/15 text-primary text-[9px] font-bold uppercase tracking-wider font-mono">
                  {currentUser.role === 'principal' ? 'Admin Access' : 'Teacher Access'}
                </div>
              </div>

              {/* Options */}
              <div className="p-1 space-y-0.5 font-semibold text-text-secondary">
                <button
                  onClick={() => { setIsDropdownOpen(false); navigate('/profile'); }}
                  className="w-full flex items-center gap-2 px-3 py-2 rounded-xl hover:bg-surface2 hover:text-text text-left transition-colors cursor-pointer"
                >
                  <User className="w-4 h-4 text-primary" />
                  <span>My Profile</span>
                </button>

                {isPrincipal && (
                  <button
                    onClick={() => { setIsDropdownOpen(false); navigate('/settings'); }}
                    className="w-full flex items-center gap-2 px-3 py-2 rounded-xl hover:bg-surface2 hover:text-text text-left transition-colors cursor-pointer"
                  >
                    <Settings className="w-4 h-4 text-primary" />
                    <span>Account Settings</span>
                  </button>
                )}

                <button
                  onClick={() => { setIsDropdownOpen(false); navigate('/profile'); }}
                  className="w-full flex items-center gap-2 px-3 py-2 rounded-xl hover:bg-surface2 hover:text-text text-left transition-colors cursor-pointer"
                >
                  <Key className="w-4 h-4 text-primary" />
                  <span>Change Password</span>
                </button>

                <button
                  onClick={() => {
                    const nextLang = lang === 'hi' ? 'en' : 'hi';
                    updateSettings({ appLanguage: nextLang });
                    showToast(nextLang === 'hi' ? 'पोर्टल भाषा हिन्दी में बदल दी गई है' : 'Display language switched to English', 'success');
                  }}
                  className="w-full flex items-center justify-between px-3 py-2 rounded-xl hover:bg-surface2 hover:text-text text-left transition-colors cursor-pointer"
                >
                  <div className="flex items-center gap-2">
                    <Languages className="w-4 h-4 text-primary" />
                    <span>{lang === 'hi' ? 'भाषा (Language)' : 'Portal Language'}</span>
                  </div>
                  <span className="text-[10px] font-black px-1.5 py-0.5 rounded bg-primary/10 text-primary uppercase">
                    {lang === 'hi' ? 'हिन्दी' : 'English'}
                  </span>
                </button>

                <button
                  onClick={() => { setIsDropdownOpen(false); setIsHelpFeedbackOpen(true); }}
                  className="w-full flex items-center gap-2 px-3 py-2 rounded-xl hover:bg-surface2 hover:text-text text-left transition-colors cursor-pointer"
                >
                  <HelpCircle className="w-4 h-4 text-primary" />
                  <span>{lang === 'hi' ? 'सहायता एवं फ़ीडबैक' : 'Help and feedback'}</span>
                </button>

                <div className="border-t border-border my-1" />

                <button
                  onClick={() => { setIsDropdownOpen(false); setIsLogoutModalOpen(true); }}
                  className="w-full flex items-center gap-2 px-3 py-2 rounded-xl hover:bg-rose-500/10 text-rose-600 hover:text-rose-700 text-left transition-colors cursor-pointer font-bold"
                >
                  <LogOut className="w-4 h-4" />
                  <span>Logout</span>
                </button>
              </div>
            </div>
          )}
        </div>
      </div>

      {/* ─── SECURE LOGOUT CONFIRMATION MODAL ─── */}
      {isLogoutModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-xs">
          <div className="bg-card border border-border rounded-2xl w-full max-w-sm shadow-2xl overflow-hidden animate-in fade-in zoom-in-95 duration-200">
            <div className="p-6 text-center space-y-4">
              <div className="w-12 h-12 rounded-full bg-rose-50 text-rose-600 flex items-center justify-center mx-auto border border-rose-200 shadow-xs animate-pulse">
                <ShieldAlert className="w-6 h-6" />
              </div>
              <div className="space-y-1">
                <h3 className="font-bold text-base text-text">Are you sure you want to logout?</h3>
                <p className="text-[10px] text-text-secondary">Your active administrative session will be terminated.</p>
              </div>
            </div>
            <div className="flex border-t border-border text-xs font-bold divide-x divide-border">
              <button
                onClick={() => setIsLogoutModalOpen(false)}
                className="flex-1 py-3 text-center text-text-secondary hover:bg-surface2 transition-colors cursor-pointer"
              >
                Cancel
              </button>
              <button
                onClick={handleLogoutConfirm}
                className="flex-1 py-3 text-center text-rose-600 hover:bg-rose-500/10 transition-colors cursor-pointer font-extrabold"
              >
                Logout
              </button>
            </div>
          </div>
        </div>
      )}
    </header>
  );
}
