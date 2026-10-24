'use client';

import React, { useState, useEffect, useRef } from 'react';
import { useSchoolStore } from '../lib/store';
import { t } from '../lib/translations';
import {
  Menu, Search, ClipboardList, Plus, Clock, Calendar, Bell, ChevronDown, User, Settings,
  Key, LogOut, ShieldAlert, Wifi, WifiOff, RefreshCw, CheckCircle2,
  AlertCircle, ArrowLeft, HelpCircle, Languages, Sun, Moon, MessageSquare
} from 'lucide-react';

export default function Header({ onMenuClick }) {
  const {
    settings,
    stats,
    themeMode,
    toggleTheme,
    setIsAddStudentOpen,
    setIsGlobalSearchOpen,
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
    teacherPermissions,
    admissionEnquiries,
    teacherApplications,
    openEnquiriesModal
  } = useSchoolStore();

  const [mounted, setMounted] = useState(false);
  const [time, setTime] = useState(new Date());
  const [isDropdownOpen, setIsDropdownOpen] = useState(false);
  const [isNotificationsOpen, setIsNotificationsOpen] = useState(false);
  const [isLogoutModalOpen, setIsLogoutModalOpen] = useState(false);
  const [browserPerm, setBrowserPerm] = useState('granted');
  const dropdownRef = useRef(null);
  const notifRef = useRef(null);

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
        setIsGlobalSearchOpen(prev => !prev);
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

  return (
    <header
      className="sticky top-0 z-50 flex items-center justify-between px-5 lg:px-8 h-16 w-full border-b border-amber-500/40 shadow-md text-white transition-all relative overflow-visible backdrop-blur-md"
      style={{
        backgroundImage: "linear-gradient(to right, rgba(6, 20, 44, 0.94), rgba(10, 32, 66, 0.88), rgba(6, 20, 44, 0.95)), url('/header_campus_bg.jpg')",
        backgroundSize: "cover",
        backgroundPosition: "center"
      }}
    >
      
      {/* Left */}
      <div className="flex items-center gap-2 sm:gap-4 min-w-0">
        <button
          onClick={onMenuClick}
          className="lg:hidden p-2 rounded-xl bg-white/12 hover:bg-white/20 text-white border border-white/20 transition-colors cursor-pointer"
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
            className="p-2 rounded-xl bg-white/12 hover:bg-white/20 text-white border border-white/20 transition-colors cursor-pointer flex items-center justify-center"
            title="Go Back"
          >
            <ArrowLeft className="w-5 h-5" />
          </button>
        )}
        <div className="min-w-0">
          <h1 className="text-base sm:text-lg font-black text-white truncate drop-shadow-sm">{viewTitles[currentPath] || 'Dashboard'}</h1>
          <p className="text-xs text-amber-300 font-bold tracking-wide truncate hidden sm:block drop-shadow-2xs">
            {settings.instituteName || 'School Management'} &nbsp;·&nbsp; Session {settings.currentSession || '2026-27'}
          </p>
        </div>
      </div>

      {/* Right Action Cluster */}
      <div className="flex items-center gap-2 sm:gap-3 flex-shrink-0">
        {/* Universal Search Icon Button */}
        <button
          type="button"
          onClick={() => setIsGlobalSearchOpen(true)}
          className="p-2.5 rounded-xl bg-white/12 hover:bg-white/20 text-white hover:text-amber-300 transition-all cursor-pointer border border-white/20 shadow-2xs flex items-center justify-center group"
          title="Search (Ctrl+K)"
        >
          <Search className="w-4.5 h-4.5 group-hover:scale-110 transition-transform" />
        </button>
        {/* Date & Time */}
        {mounted && (
          <div className="hidden lg:flex items-center gap-2 px-3.5 py-2 rounded-xl bg-white/12 border border-white/20 text-xs font-bold text-white shadow-2xs">
            <Calendar className="w-4 h-4 text-amber-400" />
            <span>{time.toLocaleDateString('en-IN', { weekday: 'short', day: 'numeric', month: 'short', year: 'numeric' })}</span>
            <span className="text-text-muted mx-1">·</span>
            <Clock className="w-4 h-4 text-amber-400" />
            <span>{time.toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit', hour12: true }).toUpperCase()}</span>
          </div>
        )}

        {/* Online Enquiries & Admissions Desk */}
        {isPrincipal && (
          <button
            onClick={() => openEnquiriesModal('admissions')}
            className="relative hidden md:flex items-center gap-1.5 px-3 py-2 rounded-xl bg-gradient-to-r from-blue-600 to-indigo-600 hover:from-blue-700 hover:to-indigo-700 text-white font-bold text-xs shadow-md transition-all cursor-pointer"
            title="View online student admissions and teacher applications"
          >
            <ClipboardList className="w-4 h-4" />
            <span className="hidden lg:inline">Online Enquiries</span>
            {((admissionEnquiries || []).filter(e => !e.status || e.status === 'pending').length + (teacherApplications || []).filter(a => !a.status || a.status === 'pending').length) > 0 && (
              <span className="ml-1 px-1.5 py-0.5 rounded-full bg-rose-500 text-white text-[10px] font-black animate-pulse">
                {(admissionEnquiries || []).filter(e => !e.status || e.status === 'pending').length + (teacherApplications || []).filter(a => !a.status || a.status === 'pending').length}
              </span>
            )}
          </button>
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
            className="p-2 rounded-xl bg-white/12 hover:bg-white/20 text-white hover:text-amber-300 transition-colors relative cursor-pointer border border-white/20 shadow-2xs"
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
            <div className="absolute right-0 top-full mt-2 w-80 sm:w-96 bg-white border border-[#c8c4d5]/80 rounded-2xl shadow-2xl overflow-hidden text-xs z-50 animate-in fade-in slide-in-from-top-3 duration-200 text-[#0b1c30]">
              
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
          className="flex items-center gap-1.5 px-3 py-2 rounded-xl bg-white/12 hover:bg-white/20 text-amber-300 transition-all cursor-pointer border border-white/20 shadow-2xs font-extrabold text-xs"
          title={lang === 'hi' ? 'अंग्रेज़ी भाषा में बदलें (Switch to English)' : 'Switch to Hindi (हिन्दी भाषा चुनें)'}
        >
          <Languages className="w-4 h-4 text-amber-400" />
          <span className="font-bold text-[11px]">{lang === 'hi' ? 'हिन्दी' : 'English'}</span>
        </button>

        {/* Quick Help and Feedback Trigger */}
        <button
          type="button"
          onClick={() => setIsHelpFeedbackOpen(true)}
          className="p-2 rounded-xl bg-white/12 hover:bg-white/20 text-white hover:text-amber-300 transition-colors relative cursor-pointer border border-white/20 shadow-2xs"
          title="Help and feedback (FAQs, Support, Reports)"
        >
          <HelpCircle className="w-4.5 h-4.5 text-amber-300" />
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
            <Moon className="w-4.5 h-4.5 text-amber-300" />
          )}
        </button>

        {/* Quick Parent Complaints Desk Shortcut */}
        <button
          type="button"
          onClick={() => navigate('/complaints')}
          className="p-2 rounded-xl bg-[#eff4ff] hover:bg-[#dce9ff] text-[#1f108e] transition-colors relative cursor-pointer border border-[#c8c4d5]/50 shadow-2xs"
          title="Parent Complaints & Messages Desk"
        >
          <MessageSquare className="w-4.5 h-4.5 text-amber-300" />
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
              <p className="font-bold text-xs text-white">{principalDisplayName}</p>
              <p className="text-[10px] text-amber-300/90 font-medium mt-0.5 capitalize">{currentUser.role === 'principal' ? 'Principal / Admin' : 'Teacher'}</p>
            </div>
            <ChevronDown className="w-4 h-4 text-amber-300 hidden lg:block" />
          </button>

          {/* Premium Dropdown menu */}
          {isDropdownOpen && (
            <div className="absolute right-0 top-full mt-2 w-64 bg-white border border-[#c8c4d5]/80 rounded-2xl shadow-2xl py-2 overflow-hidden text-xs z-50 animate-in fade-in slide-in-from-top-3 duration-200 text-[#0b1c30]">
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
