'use client';

import React, { useState, useEffect } from 'react';
import { useSchoolStore, defaultTeacherPermissions } from '../lib/store';
import { t } from '../lib/translations';
import {
  Shield, X, Check, Users, UserPlus, Building2,
  CalendarCheck, Award, FileText, Contact, Calendar,
  Megaphone, CreditCard, FileSpreadsheet, Bus, Sparkles,
  Edit3, Trash2, Activity, MessageSquare, Printer, Coins, UserCheck
} from 'lucide-react';

export default function TeacherPermissionsModal({ isOpen, onClose }) {
  const { teacherPermissions, updateTeacherPermissions, settings, showToast } = useSchoolStore();
  const [perms, setPerms] = useState(defaultTeacherPermissions);
  const [isSaving, setIsSaving] = useState(false);

  const lang = settings?.appLanguage || 'en';

  useEffect(() => {
    if (teacherPermissions) {
      setPerms({ ...defaultTeacherPermissions, ...teacherPermissions });
    }
  }, [teacherPermissions, isOpen]);

  if (!isOpen) return null;

  const toggle = (key) => {
    setPerms(prev => ({ ...prev, [key]: !prev[key] }));
  };

  const applyPreset = (type) => {
    let updated;
    if (type === 'all') {
      updated = {
        canViewStudents: true,
        canAddStudents: true,
        canEditStudents: true,
        canDeleteStudents: true,
        canMarkAttendance: true,
        canCollectFees: true,
        canViewFeeStatus: true,
        canEnterResults: true,
        canViewAdmitCards: true,
        canViewIdCards: true,
        canPrintCards: true,
        canManageTimetable: true,
        canPostNotices: true,
        canSendWhatsApp: true,
        canViewTransport: true,
        canExportReports: true,
        canManageClasses: true,
        canMarkTeacherAtt: true,
        canViewSchoolStatus: true,
        canViewFacultyList: true,
      };
    } else if (type === 'standard') {
      updated = {
        canViewStudents: true,
        canAddStudents: true,
        canEditStudents: true,
        canDeleteStudents: true,
        canMarkAttendance: true,
        canCollectFees: false,
        canViewFeeStatus: false,
        canEnterResults: true,
        canViewAdmitCards: true,
        canViewIdCards: true,
        canPrintCards: true,
        canManageTimetable: true,
        canPostNotices: true,
        canSendWhatsApp: true,
        canViewTransport: false,
        canExportReports: false,
        canManageClasses: false,
        canMarkTeacherAtt: false,
        canViewSchoolStatus: false,
        canViewFacultyList: false,
      };
    } else if (type === 'minimal') {
      updated = {
        canViewStudents: true,
        canAddStudents: false,
        canEditStudents: false,
        canDeleteStudents: false,
        canMarkAttendance: true,
        canCollectFees: false,
        canViewFeeStatus: false,
        canEnterResults: false,
        canViewAdmitCards: false,
        canViewIdCards: false,
        canPrintCards: false,
        canManageTimetable: false,
        canPostNotices: false,
        canSendWhatsApp: false,
        canViewTransport: false,
        canExportReports: false,
        canManageClasses: false,
        canMarkTeacherAtt: false,
        canViewSchoolStatus: false,
        canViewFacultyList: false,
      };
    }
    setPerms(updated);
    showToast(`Preset "${type}" applied. Click Save to sync.`, 'info');
  };

  const handleSave = async () => {
    setIsSaving(true);
    await updateTeacherPermissions(perms);
    setIsSaving(false);
    onClose();
  };

  const renderToggleRow = (key, label, desc, icon, iconBg, iconColor) => {
    const IconComponent = icon;
    const isChecked = !!perms[key];

    return (
      <div
        key={key}
        onClick={() => toggle(key)}
        className="flex items-center justify-between p-3 rounded-xl border border-border hover:border-primary/40 bg-white/70 hover:bg-white transition-all cursor-pointer select-none"
      >
        <div className="flex items-center gap-3 min-w-0">
          <div className={`w-9 h-9 rounded-lg flex items-center justify-center flex-shrink-0 ${iconBg}`}>
            <IconComponent className={`w-4 h-4 ${iconColor}`} />
          </div>
          <div className="min-w-0">
            <div className="font-bold text-xs text-text flex items-center gap-2">
              <span>{label}</span>
              {isChecked && (
                <span className="text-[9px] font-black uppercase tracking-wider text-emerald-600 bg-emerald-50 px-1.5 py-0.2 rounded">
                  {t('enabled', lang)}
                </span>
              )}
            </div>
            <div className="text-[11px] text-text-secondary truncate">{desc}</div>
          </div>
        </div>

        {/* Switch Control */}
        <div
          className={`w-11 h-6 rounded-full p-0.5 transition-colors flex-shrink-0 cursor-pointer ${
            isChecked ? 'bg-primary' : 'bg-slate-300'
          }`}
        >
          <div
            className={`w-5 h-5 rounded-full bg-white shadow-md transform transition-transform ${
              isChecked ? 'translate-x-5' : 'translate-x-0'
            }`}
          />
        </div>
      </div>
    );
  };

  return (
    <div className="fixed inset-0 z-[100] flex items-center justify-center p-4 bg-black/60 backdrop-blur-xs animate-in fade-in duration-200">
      <div className="bg-[#f8fafc] w-full max-w-2xl rounded-2xl shadow-2xl border border-white/20 flex flex-col max-h-[90vh] overflow-hidden">
        {/* Header */}
        <div className="bg-[#1E3A8A] text-white p-5 flex items-center justify-between flex-shrink-0">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-white/10 flex items-center justify-center flex-shrink-0">
              <Shield className="w-5 h-5 text-white" />
            </div>
            <div>
              <h3 className="font-extrabold text-base leading-tight">{t('teacherPermTitle', lang)}</h3>
              <p className="text-xs text-white/75 mt-0.5">{t('teacherPermSubtitle', lang)}</p>
            </div>
          </div>
          <button
            onClick={onClose}
            className="p-1.5 rounded-lg bg-white/10 hover:bg-white/20 text-white transition-all cursor-pointer"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Info Banner & Presets */}
        <div className="bg-[#EEF2FF] border-b border-[#C7D2FE] p-4 flex-shrink-0">
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
            <div className="text-xs text-[#1E3A8A]">
              <span className="font-bold">{lang === 'hi' ? 'नियम:' : 'Rule:'} </span>
              {t('teacherPermRule', lang)}
            </div>
            <div className="flex items-center gap-2 flex-wrap">
              <span className="text-[11px] font-bold text-slate-500 mr-1">Presets:</span>
              <button
                type="button"
                onClick={() => applyPreset('standard')}
                className="px-2.5 py-1 rounded-lg text-xs font-bold bg-white text-[#1E3A8A] border border-[#C7D2FE] hover:bg-[#1E3A8A] hover:text-white transition-all cursor-pointer shadow-2xs"
              >
                {t('presetStandard', lang)}
              </button>
              <button
                type="button"
                onClick={() => applyPreset('all')}
                className="px-2.5 py-1 rounded-lg text-xs font-bold bg-white text-emerald-700 border border-emerald-200 hover:bg-emerald-600 hover:text-white transition-all cursor-pointer shadow-2xs"
              >
                {t('presetAll', lang)}
              </button>
              <button
                type="button"
                onClick={() => applyPreset('minimal')}
                className="px-2.5 py-1 rounded-lg text-xs font-bold bg-white text-amber-700 border border-amber-200 hover:bg-amber-600 hover:text-white transition-all cursor-pointer shadow-2xs"
              >
                {t('presetMinimal', lang)}
              </button>
            </div>
          </div>
        </div>

        {/* Scrollable Content */}
        <div className="flex-1 overflow-y-auto p-5 space-y-6">
          {/* Section 1: Students & Classes */}
          <div>
            <div className="text-[11px] font-black uppercase tracking-wider text-slate-500 mb-2.5 flex items-center gap-1.5">
              <span>{t('secStudentsClasses', lang)}</span>
            </div>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-2.5">
              {renderToggleRow('canViewStudents', t('permViewStudents', lang), t('permViewStudentsDesc', lang), Users, 'bg-blue-50', 'text-blue-600')}
              {renderToggleRow('canAddStudents', t('permAddStudents', lang), t('permAddStudentsDesc', lang), UserPlus, 'bg-sky-50', 'text-sky-600')}
              {renderToggleRow('canEditStudents', t('permEditStudents', lang), t('permEditStudentsDesc', lang), Edit3, 'bg-indigo-50', 'text-indigo-600')}
              {renderToggleRow('canDeleteStudents', t('permDeleteStudents', lang), t('permDeleteStudentsDesc', lang), Trash2, 'bg-rose-50', 'text-rose-600')}
              {renderToggleRow('canManageClasses', t('permManageClasses', lang), t('permManageClassesDesc', lang), Building2, 'bg-teal-50', 'text-teal-600')}
            </div>
          </div>

          {/* Section 2: Attendance */}
          <div>
            <div className="text-[11px] font-black uppercase tracking-wider text-slate-500 mb-2.5 flex items-center gap-1.5">
              <span>{t('secAttendance', lang)}</span>
            </div>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-2.5">
              {renderToggleRow('canMarkAttendance', t('permMarkAttendance', lang), t('permMarkAttendanceDesc', lang), CalendarCheck, 'bg-purple-50', 'text-purple-600')}
              {renderToggleRow('canMarkTeacherAtt', t('permMarkTeacherAtt', lang), t('permMarkTeacherAttDesc', lang), CalendarCheck, 'bg-emerald-50', 'text-emerald-600')}
            </div>
          </div>

          {/* Section 3: Exams & Credentials */}
          <div>
            <div className="text-[11px] font-black uppercase tracking-wider text-slate-500 mb-2.5 flex items-center gap-1.5">
              <span>{t('secExams', lang)}</span>
            </div>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-2.5">
              {renderToggleRow('canEnterResults', t('permEnterResults', lang), t('permEnterResultsDesc', lang), Award, 'bg-orange-50', 'text-orange-600')}
              {renderToggleRow('canViewAdmitCards', t('permViewAdmitCards', lang), t('permViewAdmitCardsDesc', lang), FileText, 'bg-indigo-50', 'text-indigo-600')}
              {renderToggleRow('canViewIdCards', t('permViewIdCards', lang), t('permViewIdCardsDesc', lang), Contact, 'bg-cyan-50', 'text-cyan-600')}
              {renderToggleRow('canPrintCards', t('permPrintCards', lang), t('permPrintCardsDesc', lang), Printer, 'bg-emerald-50', 'text-emerald-600')}
            </div>
          </div>

          {/* Section 4: Routine & Communication */}
          <div>
            <div className="text-[11px] font-black uppercase tracking-wider text-slate-500 mb-2.5 flex items-center gap-1.5">
              <span>{t('secAcademicNotice', lang)}</span>
            </div>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-2.5">
              {renderToggleRow('canManageTimetable', t('permManageTimetable', lang), t('permManageTimetableDesc', lang), Calendar, 'bg-amber-50', 'text-amber-600')}
              {renderToggleRow('canPostNotices', t('permPostNotices', lang), t('permPostNoticesDesc', lang), Megaphone, 'bg-yellow-50', 'text-yellow-600')}
              {renderToggleRow('canSendWhatsApp', t('permSendWhatsApp', lang), t('permSendWhatsAppDesc', lang), MessageSquare, 'bg-green-50', 'text-green-600')}
            </div>
          </div>

          {/* Section 5: Finance, School Status & Admin */}
          <div>
            <div className="text-[11px] font-black uppercase tracking-wider text-slate-500 mb-2.5 flex items-center gap-1.5">
              <span>{t('secFinanceAdmin', lang)}</span>
            </div>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-2.5">
              {renderToggleRow('canViewSchoolStatus', t('permViewSchoolStatus', lang), t('permViewSchoolStatusDesc', lang), Activity, 'bg-blue-100', 'text-blue-700')}
              {renderToggleRow('canCollectFees', t('permCollectFees', lang), t('permCollectFeesDesc', lang), CreditCard, 'bg-fuchsia-50', 'text-fuchsia-600')}
              {renderToggleRow('canViewFeeStatus', t('permViewFeeStatus', lang), t('permViewFeeStatusDesc', lang), Coins, 'bg-violet-50', 'text-violet-600')}
              {renderToggleRow('canExportReports', t('permExportReports', lang), t('permExportReportsDesc', lang), FileSpreadsheet, 'bg-sky-50', 'text-sky-600')}
              {renderToggleRow('canViewFacultyList', t('permViewFacultyList', lang), t('permViewFacultyListDesc', lang), UserCheck, 'bg-purple-50', 'text-purple-600')}
              {renderToggleRow('canViewTransport', t('permViewTransport', lang), t('permViewTransportDesc', lang), Bus, 'bg-teal-50', 'text-teal-600')}
            </div>
          </div>
        </div>

        {/* Footer */}
        <div className="bg-white border-t border-border p-4 flex items-center justify-between flex-shrink-0">
          <button
            type="button"
            onClick={onClose}
            className="px-4 py-2 rounded-xl text-xs font-bold text-slate-600 hover:bg-slate-100 transition-all cursor-pointer"
          >
            {t('cancel', lang)}
          </button>
          <button
            type="button"
            disabled={isSaving}
            onClick={handleSave}
            className="px-6 py-2.5 rounded-xl text-xs font-bold bg-[#1E3A8A] hover:bg-[#152865] text-white shadow-md transition-all flex items-center gap-2 cursor-pointer disabled:opacity-50"
          >
            {isSaving ? (
              <span>Saving...</span>
            ) : (
              <>
                <Check className="w-4 h-4" />
                <span>{t('savePermissions', lang)}</span>
              </>
            )}
          </button>
        </div>
      </div>
    </div>
  );
}
