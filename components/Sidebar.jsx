'use client';

import React from 'react';
import { useSchoolStore } from '../lib/store';
import { t } from '../lib/translations';
import {
  LayoutDashboard, Users, UserPlus, CalendarCheck,
  CreditCard, AlertCircle, FileSpreadsheet, QrCode,
  Settings, GraduationCap, Award, Contact,
  ShieldCheck, UserCheck, School, Sun, Moon, Zap,
  ChevronRight, ChevronLeft, Plus, FileText, Megaphone, X,
  Building2, Calendar, Sparkles,
  HelpCircle, MessageSquare
} from 'lucide-react';

function NavBtn({ icon: Icon, label, badge, active, onClick, iconColor, collapsed }) {
  return (
    <button
      onClick={onClick}
      title={collapsed ? label : undefined}
      className={[
        'w-full flex items-center rounded-xl font-bold transition-all duration-200 cursor-pointer group relative text-xs',
        collapsed ? 'px-0 py-3 justify-center' : 'px-3.5 py-2.5 gap-3 justify-between',
        active
          ? 'bg-[#316bf3] text-white shadow-md'
          : 'text-[#464553] hover:text-[#0b1c30] hover:bg-[#dce9ff]'
      ].join(' ')}
    >
      <div className={`flex items-center ${collapsed ? '' : 'gap-3 min-w-0'}`}>
        <Icon className={[
          'flex-shrink-0 transition-transform group-hover:scale-110',
          collapsed ? 'w-5 h-5' : 'w-4 h-4',
          active ? 'text-white' : (iconColor || 'text-[#464553] group-hover:text-[#0b1c30]')
        ].join(' ')} />
        {!collapsed && <span className="truncate">{label}</span>}
      </div>
      {!collapsed && badge != null && (
        <span className={`text-[10px] font-extrabold px-2 py-0.5 rounded-full flex-shrink-0 ${
          active ? 'bg-white/25 text-white' : 'bg-[#dce9ff] text-[#0051d5]'
        }`}>
          {badge}
        </span>
      )}
      {collapsed && (
        <span className="absolute left-full ml-3 px-3 py-1.5 bg-[#0b1c30] text-white text-xs font-semibold rounded-xl whitespace-nowrap opacity-0 group-hover:opacity-100 pointer-events-none transition-opacity z-[60] shadow-xl border border-white/10">
          {label}{badge != null && <span className="ml-2 text-indigo-300 font-bold">{badge}</span>}
        </span>
      )}
    </button>
  );
}

function SectionLabel({ children, collapsed }) {
  if (collapsed) return <div className="h-px bg-[#c8c4d5]/40 my-2 mx-2" />;
  return <div className="px-3.5 pt-4 pb-1.5 text-[10px] font-black uppercase tracking-[0.15em] text-[#777584] select-none">{children}</div>;
}

export default function Sidebar({ isOpen, onClose, collapsed, onCollapseChange }) {
  const {
    settings, stats, currentUser, themeMode, toggleTheme, teacherPermissions,
    setIsAddStudentOpen, currentTeacher, currentPath, navigate,
    unreadNoticeCount,
    isTeacherPermissionsModalOpen, setIsTeacherPermissionsModalOpen,
    isHelpFeedbackOpen, setIsHelpFeedbackOpen,
    language
  } = useSchoolStore();

  if (!currentUser) return null;

  const isPrincipal = currentUser.role === 'principal';
  const nav = (v) => { navigate('/' + v); if (onClose) onClose(); };

  return (
    <>
      {isOpen && (
        <div className="fixed inset-0 bg-black/60 z-40 lg:hidden backdrop-blur-xs" onClick={onClose} />
      )}

      <aside className={[
        'fixed top-0 bottom-0 left-0 z-50 flex flex-col border-r border-[#c8c4d5]/50 shadow-sm',
        'bg-[#eff4ff] text-[#0b1c30]',
        'transition-all duration-300 ease-in-out overflow-hidden font-sans',
        collapsed ? 'w-[72px]' : 'w-72',
        isOpen ? 'translate-x-0 pointer-events-auto' : '-translate-x-full pointer-events-none lg:translate-x-0 lg:pointer-events-auto'
      ].join(' ')}>

        {/* ── Brand Header ── */}
        <div className={`flex items-center border-b border-[#c8c4d5]/40 flex-shrink-0 ${collapsed ? 'p-3 justify-center flex-col gap-2' : 'p-3.5 gap-2.5'}`}>
          <div className="w-10 h-10 rounded-full overflow-hidden border border-slate-200 bg-white flex items-center justify-center flex-shrink-0 drop-shadow-sm">
            <img
              src={settings.logoUrl || settings.logoPath || settings.logo || '/logo.png'}
              alt="Logo"
              className="w-full h-full object-cover rounded-full"
              onError={(e) => {
                e.currentTarget.onerror = null;
                e.currentTarget.src = '/logo.png';
              }}
            />
          </div>
          {!collapsed && (
            <div className="min-w-0 flex-1">
              <div className="font-extrabold text-xs sm:text-[13px] text-[#1f108e] leading-snug line-clamp-2" title={settings.instituteName || 'Mission Navodaya Public School'}>
                {settings.instituteName || 'Mission Navodaya Public School'}
              </div>
              <div className="mt-1 inline-flex items-center gap-1 px-2 py-0.5 rounded-md bg-[#dce9ff] text-[10px] font-bold text-[#0051d5]">
                <span>Session {settings.currentSession || '2026-27'}</span>
              </div>
            </div>
          )}
          <button
            onClick={() => onCollapseChange(!collapsed)}
            className="hidden lg:flex p-1.5 rounded-lg bg-white/70 hover:bg-white text-[#777584] hover:text-[#0b1c30] transition-all cursor-pointer flex-shrink-0 shadow-2xs border border-[#c8c4d5]/40"
            title={collapsed ? 'Expand sidebar' : 'Collapse sidebar'}
          >
            {collapsed ? <ChevronRight className="w-3.5 h-3.5" /> : <ChevronLeft className="w-3.5 h-3.5" />}
          </button>
          <button
            onClick={onClose}
            className="lg:hidden p-1.5 rounded-lg bg-white/70 hover:bg-white text-[#777584] hover:text-[#0b1c30] transition-all cursor-pointer flex-shrink-0 shadow-2xs border border-[#c8c4d5]/40"
            title="Close navigation"
          >
            <X className="w-4 h-4" />
          </button>
        </div>

        {/* ── Scrollable Nav Menu List ── */}
        <div className="flex-1 overflow-y-auto px-3 py-3 space-y-1">
          {(() => {
            const lang = language || settings?.appLanguage || 'en';
            return (
              <>
                {/* Core Operations */}
                <SectionLabel collapsed={collapsed}>{lang === 'hi' ? 'मुख्य मेनू' : 'Main Menu'}</SectionLabel>
                <NavBtn icon={LayoutDashboard} label={t('dashboard', lang)} active={currentPath === '/dashboard' || currentPath === '/'} onClick={() => nav('dashboard')} collapsed={collapsed} />

                {/* Academic Management */}
                <SectionLabel collapsed={collapsed}>{lang === 'hi' ? 'अकादमिक प्रबंधन' : 'Academic'}</SectionLabel>
                {(isPrincipal || teacherPermissions?.canPostNotices !== false) && (
                  <NavBtn icon={Megaphone} label={t('notices', lang)} badge={unreadNoticeCount > 0 ? `${unreadNoticeCount} new` : undefined} active={currentPath === '/notices'} onClick={() => nav('notices')} collapsed={collapsed} />
                )}
                {(isPrincipal || teacherPermissions?.canViewStudents !== false) && (
                  <NavBtn icon={Users} label={t('students', lang)} badge={stats.totalStudents} active={currentPath === '/students'} onClick={() => nav('students')} collapsed={collapsed} />
                )}
                {(isPrincipal || teacherPermissions?.canMarkAttendance !== false) && (
                  <NavBtn icon={CalendarCheck} label={t('attendance', lang)} active={currentPath === '/attendance'} onClick={() => nav('attendance')} collapsed={collapsed} />
                )}
                {(isPrincipal || teacherPermissions?.canEnterResults !== false) && (
                  <NavBtn icon={Award} label={t('results', lang)} active={currentPath === '/results'} onClick={() => nav('results')} collapsed={collapsed} />
                )}
                {(isPrincipal || teacherPermissions?.canManageClasses !== false) && (
                  <NavBtn icon={Building2} label={t('classes', lang)} active={currentPath === '/classes'} onClick={() => nav('classes')} collapsed={collapsed} />
                )}
                {(isPrincipal || teacherPermissions?.canManageTimetable !== false) && (
                  <NavBtn icon={Calendar} label={t('timetable', lang)} active={currentPath === '/timetable'} onClick={() => nav('timetable')} collapsed={collapsed} />
                )}
                {(isPrincipal || teacherPermissions?.canViewIdCards !== false) && (
                  <NavBtn icon={Contact} label={t('idcards', lang)} active={currentPath === '/idcards'} onClick={() => nav('idcards')} collapsed={collapsed} />
                )}
                {(isPrincipal || teacherPermissions?.canViewAdmitCards !== false) && (
                  <NavBtn icon={FileText} label={t('admitcards', lang)} active={currentPath === '/admitcards'} onClick={() => nav('admitcards')} collapsed={collapsed} />
                )}
                {!isPrincipal && teacherPermissions?.canCollectFees && (
                  <NavBtn icon={CreditCard} label={t('fees', lang)} active={currentPath === '/fees'} onClick={() => nav('fees')} collapsed={collapsed} />
                )}
                {!isPrincipal && teacherPermissions?.canExportReports && (
                  <NavBtn icon={FileSpreadsheet} label={t('reports', lang)} active={currentPath === '/reports'} onClick={() => nav('reports')} collapsed={collapsed} />
                )}

                {/* Administrative / Principal Only */}
                {isPrincipal && (
                  <>
                    <SectionLabel collapsed={collapsed}>{lang === 'hi' ? 'प्रशासन' : 'Administration'}</SectionLabel>
                    <NavBtn icon={CreditCard} label={t('fees', lang)} badge={stats.defaultersCount > 0 ? `${stats.defaultersCount} dues` : undefined} active={currentPath === '/fees'} onClick={() => nav('fees')} collapsed={collapsed} />
                    <NavBtn icon={GraduationCap} label={t('teachers', lang)} active={currentPath === '/teachers'} onClick={() => nav('teachers')} collapsed={collapsed} />
                    <NavBtn
                      icon={ShieldCheck}
                      label={t('teacherAccess', lang)}
                      badge="Roles"
                      active={currentPath === '/teacher-access' || isTeacherPermissionsModalOpen}
                      onClick={() => {
                        setIsTeacherPermissionsModalOpen(true);
                        if (onClose) onClose();
                      }}
                      collapsed={collapsed}
                    />
                    <NavBtn icon={FileSpreadsheet} label={t('reports', lang)} active={currentPath === '/reports'} onClick={() => nav('reports')} collapsed={collapsed} />
                    <NavBtn icon={QrCode} label="QR Scanner" active={currentPath === '/qrscanner'} onClick={() => nav('qrscanner')} collapsed={collapsed} />
                    <NavBtn icon={UserCheck} label="User Management" active={currentPath === '/users'} onClick={() => nav('users')} collapsed={collapsed} />
                    <NavBtn icon={MessageSquare} label={lang === 'hi' ? 'अभिभावक शिकायतें' : 'Parent Complaints'} badge="Desk" active={currentPath === '/complaints'} onClick={() => nav('complaints')} collapsed={collapsed} />
                    <NavBtn icon={Settings} label={t('settings', lang)} active={currentPath.startsWith('/settings')} onClick={() => nav('settings')} collapsed={collapsed} />
                    <NavBtn icon={HelpCircle} label={t('helpSupport', lang)} active={isHelpFeedbackOpen} onClick={() => { setIsHelpFeedbackOpen(true); if (onClose) onClose(); }} collapsed={collapsed} />
                    <NavBtn icon={Sparkles} label={t('subscription', lang)} badge="All Access" active={currentPath === '/subscription'} onClick={() => nav('subscription')} collapsed={collapsed} />
                  </>
                )}

                {/* Action Button at bottom */}
                {!collapsed && (isPrincipal || teacherPermissions?.canAddStudents) && (
                  <div className="pt-4 px-1">
                    <button
                      onClick={() => setIsAddStudentOpen(true)}
                      className="w-full py-2.5 px-3 rounded-xl bg-[#1f108e] hover:bg-[#0f0069] text-white font-bold text-xs shadow-md transition-all flex items-center justify-center gap-2 cursor-pointer"
                    >
                      <Plus className="w-4 h-4" />
                      <span>{lang === 'hi' ? 'नया छात्र जोड़ें' : 'Add New Student'}</span>
                    </button>
                  </div>
                )}
              </>
            );
          })()}
        </div>

        {/* ── User & Theme Footer ── */}
        <div className="p-3 border-t border-[#c8c4d5]/40 flex-shrink-0 bg-white/40">
          {(() => {
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

            return (
              <div className={`flex items-center ${collapsed ? 'justify-center flex-col gap-2' : 'justify-between'}`}>
                <button
                  onClick={() => nav('profile')}
                  className={`flex items-center gap-2.5 text-left rounded-xl p-1.5 hover:bg-white/80 transition-colors cursor-pointer ${collapsed ? 'justify-center' : 'min-w-0'}`}
                  title={collapsed ? principalDisplayName : undefined}
                >
                  <div className="w-8 h-8 rounded-full bg-[#1f108e]/10 text-[#1f108e] flex items-center justify-center font-bold text-xs flex-shrink-0 border border-[#c8c4d5]/50">
                    {avatarInitials}
                  </div>
                  {!collapsed && (
                    <div className="min-w-0">
                      <div className="text-xs font-bold text-[#0b1c30] truncate">{principalDisplayName}</div>
                      <div className="text-[10px] text-[#464553] truncate capitalize">{isPrincipal ? 'Principal / Admin' : 'Teacher'}</div>
                    </div>
                  )}
                </button>

                <button
                  onClick={toggleTheme}
                  className="p-2 rounded-xl bg-white hover:bg-[#dce9ff] text-[#464553] hover:text-[#0b1c30] transition-colors cursor-pointer border border-[#c8c4d5]/40 flex-shrink-0 shadow-2xs"
                  title={themeMode === 'dark' ? 'Switch to Light Mode' : 'Switch to Dark Mode'}
                >
                  {themeMode === 'dark' ? <Sun className="w-3.5 h-3.5 text-amber-500" /> : <Moon className="w-3.5 h-3.5 text-[#1f108e]" />}
                </button>
              </div>
            );
          })()}
        </div>

      </aside>
    </>
  );
}
