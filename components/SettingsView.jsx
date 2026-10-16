'use client';

import React, { useState, useRef, useEffect } from 'react';
import { useSchoolStore } from '../lib/store';
import {
  Settings, Building2, Save, Download, Upload, RefreshCw,
  Plus, Trash2, CheckCircle, School, ArrowRight,
  Info, Sparkles, Check, UploadCloud, Image as ImageIcon, Camera, X, FileSignature, Crop,
  Shield, Languages, HelpCircle, Headphones, MessageCircle, PhoneCall, Mail,
  ExternalLink, GraduationCap, Lock, CheckCircle2, AlertCircle, ChevronRight, Stamp, Link2,
  Smartphone
} from 'lucide-react';
import { removeSignatureBackground } from '../lib/exportUtils';
import ImageCropperModal from './ImageCropperModal';
import ConnectedDevicesView from './ConnectedDevicesView';

export default function SettingsView() {
  const {
    settings,
    updateSettings,
    exportAllDataJson,
    importAllDataJson,
    showToast,
    teacherPermissions,
    setIsHelpFeedbackOpen
  } = useSchoolStore();

  const [activeSection, setActiveSection] = useState('branding'); // 'branding' | 'academic' | 'language' | 'subscription' | 'support' | 'backup' | 'wizard'
  const [wizardStep, setWizardStep] = useState(1); // 1 | 2 | 3
  const [isDraggingLogo, setIsDraggingLogo] = useState(false);
  const [isLogoCropperOpen, setIsLogoCropperOpen] = useState(false);
  const [logoToCrop, setLogoToCrop] = useState(null);
  const [isStampCropperOpen, setIsStampCropperOpen] = useState(false);
  const [stampToCrop, setStampToCrop] = useState(null);
  const logoInputRef = useRef(null);

  const [formData, setFormData] = useState({
    instituteName: settings.instituteName || settings.schoolName || '',
    schoolName: settings.schoolName || settings.instituteName || '',
    tagline: settings.tagline || '',
    principalName: settings.principalName || '',
    affiliationNumber: settings.affiliationNumber || '',
    mobile: settings.mobile || settings.phone || '',
    phone: settings.phone || settings.mobile || '',
    email: settings.email || '',
    address: settings.address || '',
    logoUrl: settings.logoUrl || settings.logoPath || settings.logo || '',
    logo: settings.logo || settings.logoUrl || '',
    principalSignature: settings.principalSignature || settings.signatureUrl || '',
    signatureUrl: settings.signatureUrl || settings.principalSignature || '',
    rawSignature: settings.rawSignature || '',
    signatureColorMode: settings.signatureColorMode || 'white',
    schoolStamp: settings.schoolStamp || settings.stampUrl || settings.sealUrl || '',
    stampUrl: settings.stampUrl || settings.schoolStamp || settings.sealUrl || '',
    stampScale: settings.stampScale !== undefined ? settings.stampScale : 1.0,
    signatureScale: settings.signatureScale !== undefined ? settings.signatureScale : 1.0,
    currentSession: settings.currentSession || settings.academicYear || '2026-27',
    academicYear: settings.academicYear || settings.currentSession || '2026-27',
    appLanguage: settings.appLanguage || 'en',
    classes: settings.classes || settings.schoolClasses || [],
    schoolClasses: settings.schoolClasses || settings.classes || [],
    courses: settings.courses || settings.computerCourses || [],
    computerCourses: settings.computerCourses || settings.courses || [],
    sections: settings.sections || ['A', 'B', 'C'],
    batches: settings.batches || [],
    ...settings
  });

  const [newClassName, setNewClassName] = useState('');
  const [newCourseName, setNewCourseName] = useState('');
  const [isSaved, setIsSaved] = useState(false);

  // Synchronize formData with settings whenever settings updates
  useEffect(() => {
    if (settings) {
      setFormData(prev => ({
        ...prev,
        ...settings,
        instituteName: settings.instituteName !== undefined && settings.instituteName !== '' ? settings.instituteName : (settings.schoolName || prev.instituteName || ''),
        schoolName: settings.schoolName !== undefined && settings.schoolName !== '' ? settings.schoolName : (settings.instituteName || prev.schoolName || ''),
        tagline: settings.tagline !== undefined ? settings.tagline : (prev.tagline || ''),
        principalName: settings.principalName !== undefined ? settings.principalName : (prev.principalName || ''),
        affiliationNumber: settings.affiliationNumber !== undefined ? settings.affiliationNumber : (prev.affiliationNumber || ''),
        mobile: settings.mobile || settings.phone || prev.mobile || '',
        phone: settings.phone || settings.mobile || prev.phone || '',
        email: settings.email !== undefined ? settings.email : (prev.email || ''),
        address: settings.address !== undefined ? settings.address : (prev.address || ''),
        logoUrl: settings.logoUrl || settings.logoPath || settings.logo || prev.logoUrl || '',
        logo: settings.logo || settings.logoUrl || prev.logo || '',
        principalSignature: settings.principalSignature || settings.signatureUrl || prev.principalSignature || '',
        signatureUrl: settings.signatureUrl || settings.principalSignature || prev.signatureUrl || '',
        rawSignature: settings.rawSignature || prev.rawSignature || '',
        signatureColorMode: settings.signatureColorMode || prev.signatureColorMode || 'white',
        schoolStamp: settings.schoolStamp || settings.stampUrl || settings.sealUrl || prev.schoolStamp || '',
        stampUrl: settings.stampUrl || settings.schoolStamp || settings.sealUrl || prev.stampUrl || '',
        stampScale: settings.stampScale !== undefined ? settings.stampScale : (prev.stampScale !== undefined ? prev.stampScale : 1.0),
        signatureScale: settings.signatureScale !== undefined ? settings.signatureScale : (prev.signatureScale !== undefined ? prev.signatureScale : 1.0),
        currentSession: settings.currentSession || settings.academicYear || prev.currentSession || '2026-27',
        academicYear: settings.academicYear || settings.currentSession || prev.academicYear || '2026-27',
        appLanguage: settings.appLanguage || prev.appLanguage || 'en',
        classes: (settings.classes && settings.classes.length > 0) ? settings.classes : (settings.schoolClasses || prev.classes || []),
        schoolClasses: (settings.schoolClasses && settings.schoolClasses.length > 0) ? settings.schoolClasses : (settings.classes || prev.schoolClasses || []),
        courses: (settings.courses && settings.courses.length > 0) ? settings.courses : (settings.computerCourses || prev.courses || []),
        computerCourses: (settings.computerCourses && settings.computerCourses.length > 0) ? settings.computerCourses : (settings.courses || prev.computerCourses || []),
        sections: settings.sections || prev.sections || ['A', 'B', 'C'],
        batches: settings.batches || prev.batches || []
      }));
    }
  }, [settings]);

  const handleLogoFile = (file) => {
    if (!file) return;
    if (!file.type.startsWith('image/')) {
      showToast('Please select a valid image file (PNG, JPG, SVG, WebP).', 'error');
      return;
    }
    if (file.size > 5 * 1024 * 1024) {
      showToast('Image size exceeds 5MB limit.', 'error');
      return;
    }

    const reader = new FileReader();
    reader.onload = (e) => {
      const dataUrl = e.target.result;
      setLogoToCrop(dataUrl);
      setIsLogoCropperOpen(true);
    };
    reader.readAsDataURL(file);
  };

  const handleLogoCropComplete = (croppedDataUrl) => {
    setFormData(prev => ({
      ...prev,
      logoUrl: croppedDataUrl,
      logo: croppedDataUrl,
      logoPath: croppedDataUrl
    }));
    updateSettings({
      logoUrl: croppedDataUrl,
      logo: croppedDataUrl,
      logoPath: croppedDataUrl
    });
    setIsLogoCropperOpen(false);
    showToast('Institute logo cropped & saved successfully!', 'success');
  };

  const handleSignatureFile = (file) => {
    if (!file) return;
    if (!file.type.startsWith('image/')) {
      showToast('Please select a valid image file (PNG, JPG, WebP).', 'error');
      return;
    }
    if (file.size > 5 * 1024 * 1024) {
      showToast('Signature image exceeds 5MB limit.', 'error');
      return;
    }

    const reader = new FileReader();
    reader.onload = async (e) => {
      const dataUrl = e.target.result;
      try {
        const transparentSignature = await removeSignatureBackground(dataUrl, 210, 'transparent');
        setFormData(prev => ({
          ...prev,
          principalSignature: transparentSignature,
          signatureUrl: transparentSignature,
          rawSignature: dataUrl,
          signatureColorMode: 'white'
        }));
        updateSettings({
          principalSignature: transparentSignature,
          signatureUrl: transparentSignature,
          rawSignature: dataUrl,
          signatureColorMode: 'white'
        });
        showToast('Principal signature processed with background auto-cleared!', 'success');
      } catch (err) {
        setFormData(prev => ({
          ...prev,
          principalSignature: dataUrl,
          signatureUrl: dataUrl,
          rawSignature: dataUrl,
          signatureColorMode: 'original'
        }));
        updateSettings({
          principalSignature: dataUrl,
          signatureUrl: dataUrl,
          rawSignature: dataUrl,
          signatureColorMode: 'original'
        });
        showToast('Principal signature uploaded!', 'success');
      }
    };
    reader.readAsDataURL(file);
  };

  const handleSchoolStampFile = (file) => {
    if (!file) return;
    if (!file.type.startsWith('image/')) {
      showToast('Please select a valid image file (PNG, JPG, WebP).', 'error');
      return;
    }
    if (file.size > 5 * 1024 * 1024) {
      showToast('School stamp image exceeds 5MB limit.', 'error');
      return;
    }

    const reader = new FileReader();
    reader.onload = (e) => {
      const dataUrl = e.target.result;
      setStampToCrop(dataUrl);
      setIsStampCropperOpen(true);
    };
    reader.readAsDataURL(file);
  };

  const handleStampCropComplete = async (croppedDataUrl) => {
    try {
      const cleanStamp = await removeSignatureBackground(croppedDataUrl, 210, 'transparent');
      const stampToSave = cleanStamp || croppedDataUrl;
      setFormData(prev => ({
        ...prev,
        schoolStamp: stampToSave,
        stampUrl: stampToSave
      }));
      updateSettings({
        schoolStamp: stampToSave,
        stampUrl: stampToSave,
        sealUrl: stampToSave
      });
      setIsStampCropperOpen(false);
      showToast('Official School Seal cropped & saved successfully!', 'success');
    } catch (err) {
      setFormData(prev => ({
        ...prev,
        schoolStamp: croppedDataUrl,
        stampUrl: croppedDataUrl
      }));
      updateSettings({
        schoolStamp: croppedDataUrl,
        stampUrl: croppedDataUrl,
        sealUrl: croppedDataUrl
      });
      setIsStampCropperOpen(false);
      showToast('Official School Seal saved!', 'success');
    }
  };

  const handleSubmit = (e) => {
    if (e) e.preventDefault();
    const payload = {
      ...formData,
      schoolClasses: formData.classes || formData.schoolClasses,
      computerCourses: formData.courses || formData.computerCourses
    };
    updateSettings(payload);
    setIsSaved(true);
    showToast('Settings saved successfully & synced!', 'success');
    setTimeout(() => setIsSaved(false), 3000);
  };

  const addClass = () => {
    if (!newClassName.trim()) return;
    const currentClasses = formData.classes || formData.schoolClasses || [];
    if (!currentClasses.includes(newClassName.trim())) {
      const updated = [...currentClasses, newClassName.trim()];
      updateSettings({ classes: updated, schoolClasses: updated });
      setFormData(prev => ({ ...prev, classes: updated, schoolClasses: updated }));
      setNewClassName('');
      showToast(`Class "${newClassName.trim()}" added!`, 'success');
    }
  };

  const removeClass = (cls) => {
    const currentClasses = formData.classes || formData.schoolClasses || [];
    const updated = currentClasses.filter(c => c !== cls);
    updateSettings({ classes: updated, schoolClasses: updated });
    setFormData(prev => ({ ...prev, classes: updated, schoolClasses: updated }));
    showToast(`Class "${cls}" removed.`, 'info');
  };

  const addCourse = () => {
    if (!newCourseName.trim()) return;
    const currentCourses = formData.courses || formData.computerCourses || [];
    if (!currentCourses.includes(newCourseName.trim())) {
      const updated = [...currentCourses, newCourseName.trim()];
      updateSettings({ courses: updated, computerCourses: updated });
      setFormData(prev => ({ ...prev, courses: updated, computerCourses: updated }));
      setNewCourseName('');
      showToast(`Course "${newCourseName.trim()}" added!`, 'success');
    }
  };

  const removeCourse = (crs) => {
    const currentCourses = formData.courses || formData.computerCourses || [];
    const updated = currentCourses.filter(c => c !== crs);
    updateSettings({ courses: updated, computerCourses: updated });
    setFormData(prev => ({ ...prev, courses: updated, computerCourses: updated }));
    showToast(`Course "${crs}" removed.`, 'info');
  };

  const handleJsonImport = (e) => {
    const file = e.target.files?.[0];
    if (!file) return;
    const reader = new FileReader();
    reader.onload = (event) => {
      try {
        const json = JSON.parse(event.target.result);
        if (json.students || json.settings) {
          importAllDataJson(json);
          showToast('Database successfully restored from JSON backup!', 'success');
        } else {
          showToast('Invalid backup file structure.', 'error');
        }
      } catch (err) {
        showToast('Error reading JSON file: ' + err.message, 'error');
      }
    };
    reader.readAsText(file);
    e.target.value = '';
  };

  // Modern Split-Layout Categories (Teacher Access moved to Sidebar, Dark Mode removed)
  const navCategories = [
    {
      group: 'INSTITUTION',
      items: [
        { id: 'branding', label: 'School Profile', icon: Building2, desc: 'Name, Logo & Contact Info' },
        { id: 'signatures', label: 'Official Signatures & School Seal', icon: FileSignature, desc: 'Principal Sign & School Stamp' },
        { id: 'academic', label: 'Academic & Classes', icon: GraduationCap, desc: 'Classes, Sessions & Batches' },
        { id: 'language', label: 'Portal Language', icon: Languages, desc: 'Portal Display Language' },
      ]
    },
    {
      group: 'SECURITY & HARDWARE',
      items: [
        { id: 'devices', label: 'Connected Devices & GPS', icon: Smartphone, desc: 'Real-time GPS tracking & hardware' },
        { id: 'backup', label: 'Data Backup', icon: RefreshCw, desc: 'Export & Import database' },
      ]
    },
    {
      group: 'HELP & SETUP',
      items: [
        { id: 'support', label: 'Help & Support', icon: Headphones, desc: 'WhatsApp & 24/7 Helpline' },
        { id: 'wizard', label: 'Setup Wizard', icon: School, desc: 'Quick Onboarding assistant' },
      ]
    }
  ];

  return (
    <div className="space-y-6 pb-16 max-w-7xl mx-auto font-sans">
      {/* --- Top Header Banner with Instant Save Action --- */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 bg-white dark:bg-surface border border-border p-5 sm:p-6 rounded-3xl shadow-sm">
        <div className="flex items-center gap-3.5">
          <div className="w-11 h-11 rounded-2xl bg-gradient-to-br from-primary to-primary-dark text-white flex items-center justify-center font-bold shadow-md shadow-primary/20 flex-shrink-0">
            <Settings className="w-5 h-5" />
          </div>
          <div>
            <h1 className="text-xl sm:text-2xl font-black text-text tracking-tight flex items-center gap-2">
              <span>System Settings</span>
              <span className="hidden sm:inline-block px-2.5 py-0.5 rounded-full text-[10px] font-bold bg-primary/10 text-primary border border-primary/20">
                School Config
              </span>
            </h1>
            <p className="text-xs text-text-secondary mt-0.5">
              Customize institute particulars, academic classes, regional language, and database backup.
            </p>
          </div>
        </div>

        <div className="flex items-center gap-2.5 self-end sm:self-auto">
          <button
            type="button"
            onClick={handleSubmit}
            className={`px-5 py-2.5 rounded-2xl font-bold text-xs shadow-md flex items-center gap-2 cursor-pointer transition-all active:scale-95 ${
              isSaved
                ? 'bg-emerald-600 hover:bg-emerald-700 text-white shadow-emerald-500/20'
                : 'bg-primary hover:bg-primary-dark text-white shadow-primary/25'
            }`}
          >
            {isSaved ? <CheckCircle2 className="w-4 h-4" /> : <Save className="w-4 h-4" />}
            <span>{isSaved ? 'Settings Saved!' : 'Save All Settings'}</span>
          </button>
        </div>
      </div>

      {/* --- Modern 2-Column Split Layout --- */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6 items-start">

        {/* --- Left Column: Clean Category Navigation Hub --- */}
        <div className="lg:col-span-4 xl:col-span-3 space-y-4 lg:sticky lg:top-24">
          <div className="bg-white dark:bg-surface border border-border rounded-3xl p-3 sm:p-4 shadow-sm space-y-4">
            {navCategories.map((cat, catIdx) => (
              <div key={cat.group} className={catIdx > 0 ? 'pt-3 border-t border-border/60' : ''}>
                <div className="px-3 pb-2 text-[10px] font-black uppercase tracking-[0.15em] text-text-secondary/70">
                  {cat.group}
                </div>
                <div className="space-y-1">
                  {cat.items.map((item) => {
                    const Icon = item.icon;
                    const isActive = activeSection === item.id;
                    return (
                      <button
                        key={item.id}
                        type="button"
                        onClick={() => setActiveSection(item.id)}
                        className={`w-full text-left p-2.5 rounded-2xl transition-all cursor-pointer flex items-center gap-3 group relative border ${
                          isActive
                            ? 'bg-primary text-white border-primary shadow-md shadow-primary/20'
                            : 'bg-transparent text-text hover:bg-surface2 dark:hover:bg-surface2/60 border-transparent'
                        }`}
                      >
                        <div className={`w-9 h-9 rounded-xl flex items-center justify-center flex-shrink-0 transition-transform group-hover:scale-105 ${
                          isActive
                            ? 'bg-white/20 text-white'
                            : 'bg-surface2 dark:bg-surface border border-border/80 text-primary'
                        }`}>
                          <Icon className="w-4 h-4" />
                        </div>
                        <div className="min-w-0 flex-1">
                          <div className={`text-xs font-bold truncate ${isActive ? 'text-white' : 'text-text'}`}>
                            {item.label}
                          </div>
                          <div className={`text-[10px] truncate ${isActive ? 'text-white/80' : 'text-text-secondary'}`}>
                            {item.desc}
                          </div>
                        </div>
                        {isActive && (
                          <ChevronRight className="w-4 h-4 text-white/90 flex-shrink-0" />
                        )}
                      </button>
                    );
                  })}
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* --- Right Column: Active Content Canvas --- */}
        <div className="lg:col-span-8 xl:col-span-9 min-w-0">

          {/* === SECTION 1: BRANDING & PROFILE === */}
          {activeSection === 'branding' && (
            <form onSubmit={handleSubmit} className="space-y-6">
              <div className="bg-white dark:bg-surface border border-border rounded-3xl p-6 sm:p-7 shadow-sm space-y-6">
                <div className="flex items-center justify-between border-b border-border pb-4">
                  <div>
                    <h2 className="text-base font-bold text-text flex items-center gap-2">
                      <Building2 className="w-5 h-5 text-primary" />
                      <span>Institute Identity, Logo, Seal & Signature</span>
                    </h2>
                    <p className="text-xs text-text-secondary mt-0.5">
                      This information appears on fee receipts, student admit cards, ID cards and report sheets.
                    </p>
                  </div>
                  <button
                    type="submit"
                    className="px-4 py-2 rounded-xl bg-primary hover:bg-primary-dark text-white font-bold text-xs shadow-md flex items-center gap-1.5 cursor-pointer transition-all"
                  >
                    <Save className="w-3.5 h-3.5" />
                    <span>Save Profile</span>
                  </button>
                </div>

                {/* Logo Upload Box */}
                <div className="p-4 sm:p-5 rounded-2xl bg-surface2/60 border border-border/80 space-y-3">
                  <div className="flex items-center justify-between">
                    <label className="text-xs font-bold text-text flex items-center gap-2">
                      <ImageIcon className="w-4 h-4 text-primary" />
                      <span>Official School Logo / Crest</span>
                    </label>
                    {formData.logoUrl && (
                      <button
                        type="button"
                        onClick={() => {
                          setLogoToCrop(formData.logoUrl);
                          setIsLogoCropperOpen(true);
                        }}
                        className="inline-flex items-center gap-1.5 px-3 py-1 rounded-xl text-xs font-bold text-primary bg-primary/10 hover:bg-primary/20 transition-colors cursor-pointer"
                      >
                        <Crop className="w-3.5 h-3.5" />
                        <span>Recrop Logo</span>
                      </button>
                    )}
                  </div>

                  <div className="flex flex-col sm:flex-row items-center gap-4">
                    <div className="w-24 h-24 rounded-2xl border-2 border-dashed border-border bg-white dark:bg-surface flex items-center justify-center overflow-hidden flex-shrink-0 shadow-inner p-1 relative group">
                      {formData.logoUrl ? (
                        <img src={formData.logoUrl} alt="Logo" className="w-full h-full object-contain" />
                      ) : (
                        <School className="w-8 h-8 text-text-secondary opacity-40" />
                      )}
                    </div>

                    <div className="flex-1 w-full space-y-2">
                      <div
                        onDragOver={(e) => { e.preventDefault(); setIsDraggingLogo(true); }}
                        onDragLeave={() => setIsDraggingLogo(false)}
                        onDrop={(e) => {
                          e.preventDefault();
                          setIsDraggingLogo(false);
                          handleLogoFile(e.dataTransfer.files?.[0]);
                        }}
                        onClick={() => logoInputRef.current?.click()}
                        className={`border-2 border-dashed rounded-2xl p-4 text-center cursor-pointer transition-colors ${
                          isDraggingLogo
                            ? 'border-primary bg-primary/5'
                            : 'border-border/80 hover:border-primary/50 bg-white/70 dark:bg-surface/70'
                        }`}
                      >
                        <input
                          ref={logoInputRef}
                          type="file"
                          accept="image/*"
                          className="hidden"
                          onChange={(e) => handleLogoFile(e.target.files?.[0])}
                        />
                        <UploadCloud className="w-5 h-5 text-primary mx-auto mb-1" />
                        <p className="text-xs font-bold text-text">Click or drag & drop image to upload</p>
                        <p className="text-[10px] text-text-secondary mt-0.5">PNG, JPG, SVG, WebP up to 5MB (Square ratio recommended)</p>
                      </div>

                      {formData.logoUrl && (
                        <div className="flex items-center justify-between text-[11px] text-text-secondary px-1">
                          <span className="text-emerald-600 font-bold flex items-center gap-1">
                            <Check className="w-3 h-3" /> Logo active
                          </span>
                          <button
                            type="button"
                            onClick={() => {
                              setFormData(prev => ({ ...prev, logoUrl: '', logo: '', logoPath: '' }));
                              updateSettings({ logoUrl: '', logo: '', logoPath: '' });
                              showToast('Logo removed.', 'info');
                            }}
                            className="text-red-500 hover:text-red-600 font-bold cursor-pointer"
                          >
                            Remove
                          </button>
                        </div>
                      )}
                    </div>
                  </div>
                </div>

                {/* Main Details Inputs */}
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                  <div className="space-y-1.5 sm:col-span-2">
                    <label className="text-xs font-bold text-text">Institution / School Name *</label>
                    <input
                      type="text"
                      required
                      value={formData.instituteName || formData.schoolName || ''}
                      onChange={(e) => setFormData({ ...formData, instituteName: e.target.value, schoolName: e.target.value })}
                      placeholder="e.g. MISSION NAVODAYA PUBLIC SCHOOL"
                      className="w-full px-3.5 py-2.5 rounded-xl border border-border bg-white dark:bg-surface text-text text-xs font-medium focus:outline-hidden focus:border-primary focus:ring-2 focus:ring-primary/20 transition-all"
                    />
                  </div>

                  <div className="space-y-1.5 sm:col-span-2">
                    <label className="text-xs font-bold text-text">Motto / Tagline</label>
                    <input
                      type="text"
                      value={formData.tagline || ''}
                      onChange={(e) => setFormData({ ...formData, tagline: e.target.value })}
                      placeholder="e.g. Empowering Education Through Excellence"
                      className="w-full px-3.5 py-2.5 rounded-xl border border-border bg-white dark:bg-surface text-text text-xs font-medium focus:outline-hidden focus:border-primary focus:ring-2 focus:ring-primary/20 transition-all"
                    />
                  </div>

                  <div className="space-y-1.5">
                    <label className="text-xs font-bold text-text">Principal / Director Name</label>
                    <input
                      type="text"
                      value={formData.principalName || ''}
                      onChange={(e) => setFormData({ ...formData, principalName: e.target.value })}
                      placeholder="e.g. Dr. A. K. Sharma"
                      className="w-full px-3.5 py-2.5 rounded-xl border border-border bg-white dark:bg-surface text-text text-xs font-medium focus:outline-hidden focus:border-primary focus:ring-2 focus:ring-primary/20 transition-all"
                    />
                  </div>

                  <div className="space-y-1.5">
                    <label className="text-xs font-bold text-text">Affiliation / Registration Code</label>
                    <input
                      type="text"
                      value={formData.affiliationNumber || ''}
                      onChange={(e) => setFormData({ ...formData, affiliationNumber: e.target.value })}
                      placeholder="e.g. CBSE / BSEB-841507"
                      className="w-full px-3.5 py-2.5 rounded-xl border border-border bg-white dark:bg-surface text-text text-xs font-medium focus:outline-hidden focus:border-primary focus:ring-2 focus:ring-primary/20 transition-all"
                    />
                  </div>

                  <div className="space-y-1.5">
                    <label className="text-xs font-bold text-text">Primary Contact Mobile *</label>
                    <input
                      type="tel"
                      required
                      value={formData.mobile || formData.phone || ''}
                      onChange={(e) => setFormData({ ...formData, mobile: e.target.value, phone: e.target.value })}
                      placeholder="e.g. 9876543210"
                      className="w-full px-3.5 py-2.5 rounded-xl border border-border bg-white dark:bg-surface text-text text-xs font-medium focus:outline-hidden focus:border-primary focus:ring-2 focus:ring-primary/20 transition-all"
                    />
                  </div>

                  <div className="space-y-1.5">
                    <label className="text-xs font-bold text-text">Official Email</label>
                    <input
                      type="email"
                      value={formData.email || ''}
                      onChange={(e) => setFormData({ ...formData, email: e.target.value })}
                      placeholder="e.g. contact@school.edu.in"
                      className="w-full px-3.5 py-2.5 rounded-xl border border-border bg-white dark:bg-surface text-text text-xs font-medium focus:outline-hidden focus:border-primary focus:ring-2 focus:ring-primary/20 transition-all"
                    />
                  </div>

                  <div className="space-y-1.5 sm:col-span-2">
                    <label className="text-xs font-bold text-text">Full Campus Address *</label>
                    <textarea
                      rows={2}
                      required
                      value={formData.address || ''}
                      onChange={(e) => setFormData({ ...formData, address: e.target.value })}
                      placeholder="e.g. Main Campus, Siwan, Bihar - 841507"
                      className="w-full px-3.5 py-2.5 rounded-xl border border-border bg-white dark:bg-surface text-text text-xs font-medium focus:outline-hidden focus:border-primary focus:ring-2 focus:ring-primary/20 transition-all resize-none"
                    />
                  </div>
                </div>

                {/* Bottom Submit Button */}
                <div className="pt-2 flex justify-end">
                  <button
                    type="submit"
                    className="px-6 py-2.5 rounded-2xl bg-primary hover:bg-primary-dark text-white font-bold text-xs shadow-md shadow-primary/25 transition-all flex items-center gap-2 cursor-pointer active:scale-95"
                  >
                    <Save className="w-4 h-4" />
                    <span>Save Profile Details</span>
                  </button>
                </div>
              </div>
            </form>
          )}
          {/* === SECTION: OFFICIAL SIGNATURES & SCHOOL SEAL === */}
          {activeSection === 'signatures' && (
            <div className="bg-white dark:bg-surface border border-border rounded-3xl p-6 sm:p-7 shadow-sm space-y-6">
              <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3 border-b border-border pb-4">
                <div>
                  <h2 className="text-base font-bold text-text flex items-center gap-2">
                    <FileSignature className="w-5 h-5 text-primary" />
                    <span>Official Signatures & School Seal</span>
                  </h2>
                  <p className="text-xs text-text-secondary mt-0.5">
                    Upload official stamps and signatures used across Admit Cards, ID Cards, Fee Receipts, and Report Cards.
                  </p>
                </div>
                <button
                  type="button"
                  onClick={handleSubmit}
                  className="self-start sm:self-auto px-4 py-2 rounded-xl bg-primary hover:bg-primary-dark text-white font-bold text-xs shadow-md flex items-center gap-1.5 cursor-pointer transition-all active:scale-95"
                >
                  <Save className="w-3.5 h-3.5" />
                  <span>Save Signatures & Seal</span>
                </button>
              </div>

              {/* Two Column Grid: Signature & Seal */}
              <div className="grid grid-cols-1 md:grid-cols-2 gap-6">

                {/* Card 1: Principal Signature */}
                <div className="p-5 sm:p-6 rounded-3xl bg-surface2/60 border border-border/80 flex flex-col justify-between space-y-4 shadow-2xs">
                  <div className="space-y-3">
                    <div className="flex items-center justify-between">
                      <div className="flex items-center gap-2">
                        <div className="w-8 h-8 rounded-xl bg-primary/10 text-primary flex items-center justify-center font-bold">
                          <FileSignature className="w-4 h-4" />
                        </div>
                        <div>
                          <div className="text-xs font-bold text-text">Principal / Authorized Signature</div>
                          <div className="text-[10px] text-text-secondary">Printed on marksheets & receipts</div>
                        </div>
                      </div>
                      {formData.principalSignature ? (
                        <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-emerald-100 text-emerald-800 dark:bg-emerald-950/60 dark:text-emerald-300 border border-emerald-300 flex items-center gap-1">
                          <Check className="w-3 h-3" /> Active
                        </span>
                      ) : (
                        <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-amber-100 text-amber-800 dark:bg-amber-950/60 dark:text-amber-300 border border-amber-300">
                          Pending
                        </span>
                      )}
                    </div>

                    {/* Preview Box with Checkerboard Background */}
                    <div className="h-32 rounded-2xl border-2 border-dashed border-border bg-white dark:bg-surface flex items-center justify-center p-3 relative overflow-hidden group shadow-inner">
                      {formData.principalSignature ? (
                        <div className="w-full h-full flex items-center justify-center">
                          <img
                            src={formData.principalSignature}
                            alt="Principal Signature"
                            className="max-h-full max-w-full object-contain filter contrast-125"
                          />
                        </div>
                      ) : (
                        <div className="text-center space-y-1">
                          <FileSignature className="w-8 h-8 text-text-secondary/40 mx-auto" />
                          <p className="text-[11px] font-bold text-text-secondary">No signature uploaded</p>
                          <p className="text-[10px] text-text-secondary/80">Upload photo from phone or scanner</p>
                        </div>
                      )}
                    </div>

                    <div className="p-2.5 rounded-xl bg-primary/5 border border-primary/15 text-[11px] text-text-secondary leading-snug">
                      <span className="font-bold text-primary">✨ Auto Background Removal:</span> When you upload a signature photo on white paper, our system automatically makes the background transparent.
                    </div>
                  </div>

                  <div className="space-y-2 pt-1">
                    <label className="w-full py-2.5 px-3 rounded-xl bg-primary hover:bg-primary-dark text-white font-bold text-xs shadow-md transition-all flex items-center justify-center gap-2 cursor-pointer active:scale-95">
                      <UploadCloud className="w-4 h-4" />
                      <span>{formData.principalSignature ? 'Change Signature Photo' : 'Upload Signature'}</span>
                      <input
                        type="file"
                        accept="image/*"
                        className="hidden"
                        onChange={(e) => handleSignatureFile(e.target.files?.[0])}
                      />
                    </label>

                    {formData.principalSignature && (
                      <button
                        type="button"
                        onClick={() => {
                          setFormData(prev => ({
                            ...prev,
                            principalSignature: '',
                            signatureUrl: '',
                            rawSignature: ''
                          }));
                          updateSettings({
                            principalSignature: '',
                            signatureUrl: '',
                            rawSignature: ''
                          });
                          showToast('Principal signature cleared.', 'info');
                        }}
                        className="w-full py-1.5 text-xs text-red-500 hover:text-red-600 font-bold transition-colors cursor-pointer text-center"
                      >
                        Remove Signature
                      </button>
                    )}

                    {/* PDF Signature Size Slider */}
                    <div className="pt-2 border-t border-border/70 space-y-1.5">
                      <div className="flex items-center justify-between text-[11px] font-bold text-text">
                        <span>PDF Signature Size</span>
                        <span className="text-primary font-mono">{Math.round((formData.signatureScale || 1.0) * 100)}% ({(38 * (formData.signatureScale || 1.0)).toFixed(1)}mm)</span>
                      </div>
                      <input
                        type="range"
                        min="0.6"
                        max="1.6"
                        step="0.05"
                        value={formData.signatureScale || 1.0}
                        onChange={(e) => {
                          const val = parseFloat(e.target.value);
                          setFormData(prev => ({ ...prev, signatureScale: val }));
                          updateSettings({ signatureScale: val });
                        }}
                        className="w-full h-1.5 bg-surface rounded-lg appearance-none cursor-pointer accent-primary"
                      />
                      <div className="flex justify-between text-[9px] text-text-muted">
                        <span>Compact (60%)</span>
                        <span>Default (100%)</span>
                        <span>Large (160%)</span>
                      </div>
                    </div>
                  </div>
                </div>

                {/* Card 2: Official School Stamp / Seal */}
                <div className="p-5 sm:p-6 rounded-3xl bg-surface2/60 border border-border/80 flex flex-col justify-between space-y-4 shadow-2xs">
                  <div className="space-y-3">
                    <div className="flex items-center justify-between">
                      <div className="flex items-center gap-2">
                        <div className="w-8 h-8 rounded-xl bg-primary/10 text-primary flex items-center justify-center font-bold">
                          <Stamp className="w-4 h-4" />
                        </div>
                        <div>
                          <div className="text-xs font-bold text-text">Official School Seal / Stamp</div>
                          <div className="text-[10px] text-text-secondary">Used on certificates, ID & admit cards</div>
                        </div>
                      </div>
                      {formData.schoolStamp ? (
                        <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-emerald-100 text-emerald-800 dark:bg-emerald-950/60 dark:text-emerald-300 border border-emerald-300 flex items-center gap-1">
                          <Check className="w-3 h-3" /> Active
                        </span>
                      ) : (
                        <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-amber-100 text-amber-800 dark:bg-amber-950/60 dark:text-amber-300 border border-amber-300">
                          Pending
                        </span>
                      )}
                    </div>

                    {/* Preview Box */}
                    <div className="h-32 rounded-2xl border-2 border-dashed border-border bg-white dark:bg-surface flex items-center justify-center p-3 relative overflow-hidden group shadow-inner">
                      {formData.schoolStamp ? (
                        <div className="w-full h-full flex items-center justify-center">
                          <img
                            src={formData.schoolStamp}
                            alt="School Seal"
                            className="max-h-full max-w-full object-contain filter contrast-125"
                            style={{ mixBlendMode: 'multiply' }}
                          />
                        </div>
                      ) : (
                        <div className="text-center space-y-1">
                          <Stamp className="w-8 h-8 text-text-secondary/40 mx-auto" />
                          <p className="text-[11px] font-bold text-text-secondary">No seal uploaded</p>
                          <p className="text-[10px] text-text-secondary/80">Round or oval school rubber stamp</p>
                        </div>
                      )}
                    </div>

                    <div className="p-2.5 rounded-xl bg-primary/5 border border-primary/15 text-[11px] text-text-secondary leading-snug">
                      <span className="font-bold text-primary">✨ Clean Seal Processing:</span> Rubber stamps stamped on white paper are processed with auto background clearing so the text stays crisp on printouts.
                    </div>
                  </div>

                  <div className="space-y-2 pt-1">
                    <label className="w-full py-2.5 px-3 rounded-xl bg-primary hover:bg-primary-dark text-white font-bold text-xs shadow-md transition-all flex items-center justify-center gap-2 cursor-pointer active:scale-95">
                      <UploadCloud className="w-4 h-4" />
                      <span>{formData.schoolStamp ? 'Change School Seal Photo' : 'Upload School Seal'}</span>
                      <input
                        type="file"
                        accept="image/*"
                        className="hidden"
                        onChange={(e) => handleSchoolStampFile(e.target.files?.[0])}
                      />
                    </label>

                    {formData.schoolStamp && (
                      <div className="flex items-center gap-2">
                        <button
                          type="button"
                          onClick={() => {
                            setStampToCrop(formData.schoolStamp);
                            setIsStampCropperOpen(true);
                          }}
                          className="flex-1 py-2 px-3 rounded-xl border border-primary/40 text-primary hover:bg-primary/5 font-bold text-xs transition-all flex items-center justify-center gap-1.5 cursor-pointer"
                        >
                          <Crop className="w-3.5 h-3.5" />
                          <span>Recrop Stamp</span>
                        </button>
                        <button
                          type="button"
                          onClick={() => {
                            setFormData(prev => ({
                              ...prev,
                              schoolStamp: '',
                              stampUrl: ''
                            }));
                            updateSettings({
                              schoolStamp: '',
                              stampUrl: '',
                              sealUrl: ''
                            });
                            showToast('School stamp cleared.', 'info');
                          }}
                          className="py-2 px-3 rounded-xl border border-red-200 text-red-500 hover:bg-red-50 font-bold text-xs transition-all cursor-pointer"
                        >
                          Remove
                        </button>
                      </div>
                    )}

                    {/* Stamp Photo / Image URL Input & Server Sync */}
                    <div className="pt-2.5 border-t border-border/70 space-y-2">
                      <div className="flex items-center justify-between text-[11px] font-bold text-text-secondary">
                        <span className="flex items-center gap-1.5 text-text">
                          <Link2 className="w-3.5 h-3.5 text-primary" />
                          <span>Stamp Image URL (Direct Link)</span>
                        </span>
                        {formData.stampUrl && formData.stampUrl.startsWith('http') && (
                          <span className="text-[10px] text-emerald-600 dark:text-emerald-400 font-bold">Cloud Link Active</span>
                        )}
                      </div>
                      <div className="flex items-center gap-1.5">
                        <input
                          type="url"
                          placeholder="https://example.com/stamp.png"
                          value={formData.stampUrl || (formData.schoolStamp?.startsWith('http') ? formData.schoolStamp : '')}
                          onChange={(e) => {
                            const val = e.target.value;
                            setFormData(prev => ({
                              ...prev,
                              stampUrl: val
                            }));
                          }}
                          className="flex-1 py-1.5 px-3 rounded-xl border border-border bg-surface text-xs text-text focus:outline-none focus:ring-1 focus:ring-primary placeholder:text-text-secondary/50"
                        />
                        <button
                          type="button"
                          onClick={() => {
                            const url = (formData.stampUrl || '').trim();
                            if (!url) {
                              showToast('Please enter an image URL', 'error');
                              return;
                            }
                            setFormData(prev => ({
                              ...prev,
                              schoolStamp: url,
                              stampUrl: url
                            }));
                            updateSettings({
                              schoolStamp: url,
                              stampUrl: url,
                              sealUrl: url
                            });
                            showToast('School stamp URL saved & synced to server!', 'success');
                          }}
                          className="py-1.5 px-3 rounded-xl bg-emerald-600 hover:bg-emerald-700 text-white font-bold text-xs shadow-xs transition-all cursor-pointer whitespace-nowrap active:scale-95"
                        >
                          Apply URL
                        </button>
                      </div>
                      <p className="text-[10.5px] text-text-secondary leading-tight">
                        Paste a direct image URL (PNG/JPG) to host your official seal on the cloud and sync across all devices.
                      </p>
                    </div>

                    {/* PDF Stamp Size Slider */}
                    <div className="pt-2 border-t border-border/70 space-y-1.5">
                      <div className="flex items-center justify-between text-[11px] font-bold text-text">
                        <span>PDF Stamp Size</span>
                        <span className="text-emerald-600 font-mono">{Math.round((formData.stampScale || 1.0) * 100)}% ({(22 * (formData.stampScale || 1.0)).toFixed(1)}mm)</span>
                      </div>
                      <input
                        type="range"
                        min="0.6"
                        max="1.6"
                        step="0.05"
                        value={formData.stampScale || 1.0}
                        onChange={(e) => {
                          const val = parseFloat(e.target.value);
                          setFormData(prev => ({ ...prev, stampScale: val }));
                          updateSettings({ stampScale: val });
                        }}
                        className="w-full h-1.5 bg-surface rounded-lg appearance-none cursor-pointer accent-emerald-600"
                      />
                      <div className="flex justify-between text-[9px] text-text-muted">
                        <span>Compact (60%)</span>
                        <span>Default (100%)</span>
                        <span>Large (160%)</span>
                      </div>
                    </div>
                  </div>
                </div>
              </div>

              {/* --- Document Footer Live Preview --- */}
              <div className="p-5 sm:p-6 rounded-3xl bg-surface2/40 border border-border space-y-3">
                <div className="flex items-center justify-between">
                  <div className="text-xs font-bold text-text flex items-center gap-2">
                    <Sparkles className="w-4 h-4 text-primary" />
                    <span>Live Document Print Preview (Marksheet & Receipt Validation)</span>
                  </div>
                  <span className="text-[10px] font-bold text-text-secondary">Real-time Layout</span>
                </div>

                <div className="bg-white dark:bg-surface border border-border/80 rounded-2xl p-6 shadow-sm flex flex-col sm:flex-row items-center justify-between gap-6">
                  {/* Left: School Stamp */}
                  <div className="flex flex-col items-center gap-2 text-center">
                    <div className="w-20 h-20 rounded-2xl border border-dashed border-border/80 flex items-center justify-center p-1 bg-surface2/30">
                      {formData.schoolStamp ? (
                        <img src={formData.schoolStamp} alt="Seal Preview" className="max-h-full max-w-full object-contain" style={{ mixBlendMode: 'multiply' }} />
                      ) : (
                        <span className="text-[10px] text-text-secondary italic">Stamp Area</span>
                      )}
                    </div>
                    <div className="text-[10px] font-black uppercase tracking-wider text-text-secondary">
                      [ Official Institute Seal ]
                    </div>
                  </div>

                  {/* Right: Principal Signature */}
                  <div className="flex flex-col items-center gap-1.5 text-center sm:text-right sm:items-end">
                    <div className="h-14 w-44 flex items-center justify-center sm:justify-end">
                      {formData.principalSignature ? (
                        <img src={formData.principalSignature} alt="Sign Preview" className="max-h-full object-contain" />
                      ) : (
                        <span className="text-[10px] text-text-secondary italic">Signature Area</span>
                      )}
                    </div>
                    <div className="w-44 border-t border-text/40 pt-1">
                      <div className="text-xs font-bold text-text leading-tight">
                        {formData.principalName || 'Principal / Administrator'}
                      </div>
                      <div className="text-[10px] font-bold text-text-secondary uppercase tracking-wider">
                        Authorized Signatory
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          )}

          {/* === SECTION 2: ACADEMIC & CLASSES === */}
          {activeSection === 'academic' && (
            <div className="bg-white dark:bg-surface border border-border rounded-3xl p-6 sm:p-7 shadow-sm space-y-6">
              <div className="flex items-center justify-between border-b border-border pb-4">
                <div>
                  <h2 className="text-base font-bold text-text flex items-center gap-2">
                    <GraduationCap className="w-5 h-5 text-primary" />
                    <span>Academic Sessions, Classes & Courses</span>
                  </h2>
                  <p className="text-xs text-text-secondary mt-0.5">
                    Define active academic sessions, enrolled classes, sections and computer vocational batches.
                  </p>
                </div>
              </div>

              {/* Academic Session */}
              <div className="p-4 rounded-2xl bg-surface2/60 border border-border/80 space-y-2">
                <label className="text-xs font-bold text-text">Current Active Academic Session</label>
                <div className="flex items-center gap-3">
                  <select
                    value={formData.currentSession || formData.academicYear || '2026-27'}
                    onChange={(e) => {
                      setFormData({ ...formData, currentSession: e.target.value, academicYear: e.target.value });
                      updateSettings({ currentSession: e.target.value, academicYear: e.target.value });
                      showToast(`Academic session set to ${e.target.value}`, 'success');
                    }}
                    className="px-3.5 py-2 rounded-xl border border-border bg-white dark:bg-surface text-text text-xs font-bold focus:outline-hidden focus:border-primary"
                  >
                    <option value="2025-26">Session 2025-26</option>
                    <option value="2026-27">Session 2026-27 (Current)</option>
                    <option value="2027-28">Session 2027-28</option>
                    <option value="2028-29">Session 2028-29</option>
                  </select>
                  <span className="text-[11px] text-text-secondary">Used as default for new admissions & receipts</span>
                </div>
              </div>

              {/* Class Management */}
              <div className="space-y-3">
                <label className="text-xs font-bold text-text flex items-center justify-between">
                  <span>Enrolled Standard Classes</span>
                  <span className="text-[11px] text-text-secondary font-normal">{(formData.classes || formData.schoolClasses || []).length} Classes configured</span>
                </label>

                <div className="flex items-center gap-2">
                  <input
                    type="text"
                    value={newClassName}
                    onChange={(e) => setNewClassName(e.target.value)}
                    onKeyDown={(e) => { if (e.key === 'Enter') { e.preventDefault(); addClass(); } }}
                    placeholder="e.g. Pre-Nursery, 10th-B"
                    className="flex-1 px-3.5 py-2 rounded-xl border border-border bg-white dark:bg-surface text-text text-xs focus:outline-hidden focus:border-primary"
                  />
                  <button
                    type="button"
                    onClick={addClass}
                    className="px-4 py-2 rounded-xl bg-primary hover:bg-primary-dark text-white font-bold text-xs flex items-center gap-1.5 cursor-pointer shadow-sm transition-all"
                  >
                    <Plus className="w-3.5 h-3.5" />
                    <span>Add Class</span>
                  </button>
                </div>

                <div className="flex flex-wrap gap-2 pt-1 max-h-56 overflow-y-auto p-1">
                  {(formData.classes || formData.schoolClasses || []).map((cls) => (
                    <span
                      key={cls}
                      className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-surface2 border border-border text-xs font-bold text-text shadow-2xs group"
                    >
                      <span>{cls}</span>
                      <button
                        type="button"
                        onClick={() => removeClass(cls)}
                        className="text-text-secondary hover:text-red-500 cursor-pointer p-0.5 rounded-md transition-colors"
                        title="Remove Class"
                      >
                        <Trash2 className="w-3 h-3" />
                      </button>
                    </span>
                  ))}
                </div>
              </div>

              {/* Computer Courses */}
              <div className="border-t border-border pt-4 space-y-3">
                <label className="text-xs font-bold text-text flex items-center justify-between">
                  <span>Vocational & Computer Courses</span>
                  <span className="text-[11px] text-text-secondary font-normal">{(formData.courses || formData.computerCourses || []).length} Courses</span>
                </label>

                <div className="flex items-center gap-2">
                  <input
                    type="text"
                    value={newCourseName}
                    onChange={(e) => setNewCourseName(e.target.value)}
                    onKeyDown={(e) => { if (e.key === 'Enter') { e.preventDefault(); addCourse(); } }}
                    placeholder="e.g. ADCA (12 Months), Python AI"
                    className="flex-1 px-3.5 py-2 rounded-xl border border-border bg-white dark:bg-surface text-text text-xs focus:outline-hidden focus:border-primary"
                  />
                  <button
                    type="button"
                    onClick={addCourse}
                    className="px-4 py-2 rounded-xl bg-primary hover:bg-primary-dark text-white font-bold text-xs flex items-center gap-1.5 cursor-pointer shadow-sm transition-all"
                  >
                    <Plus className="w-3.5 h-3.5" />
                    <span>Add Course</span>
                  </button>
                </div>

                <div className="flex flex-wrap gap-2 pt-1 max-h-56 overflow-y-auto p-1">
                  {(formData.courses || formData.computerCourses || []).map((crs) => (
                    <span
                      key={crs}
                      className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-surface2 border border-border text-xs font-bold text-text shadow-2xs group"
                    >
                      <span>{crs}</span>
                      <button
                        type="button"
                        onClick={() => removeCourse(crs)}
                        className="text-text-secondary hover:text-red-500 cursor-pointer p-0.5 rounded-md transition-colors"
                        title="Remove Course"
                      >
                        <Trash2 className="w-3 h-3" />
                      </button>
                    </span>
                  ))}
                </div>
              </div>
            </div>
          )}

          {/* === SECTION 3: LANGUAGE / भाषा === */}
          {activeSection === 'language' && (
            <div className="bg-white dark:bg-surface border border-border rounded-3xl p-6 sm:p-7 shadow-sm space-y-6">
              <div className="flex items-center justify-between border-b border-border pb-4">
                <div>
                  <h2 className="text-base font-bold text-text flex items-center gap-2">
                    <Languages className="w-5 h-5 text-primary" />
                    <span>{formData.appLanguage === 'hi' ? 'पोर्टल प्रदर्शन भाषा' : 'System Display Language'}</span>
                  </h2>
                  <p className="text-xs text-text-secondary mt-0.5">
                    Select your preferred interface language for teacher and principal views.
                  </p>
                </div>
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <button
                  type="button"
                  onClick={() => {
                    setFormData({ ...formData, appLanguage: 'en' });
                    updateSettings({ appLanguage: 'en' });
                    showToast('Display language switched to English', 'success');
                  }}
                  className={`p-5 rounded-2xl border text-left cursor-pointer transition-all flex items-start gap-3.5 ${
                    (formData.appLanguage || 'en') === 'en'
                      ? 'border-primary bg-primary/5 ring-2 ring-primary/20 shadow-xs'
                      : 'border-border hover:border-primary/40 bg-surface2/40'
                  }`}
                >
                  <div className="w-10 h-10 rounded-xl bg-primary/10 text-primary flex items-center justify-center font-bold text-sm flex-shrink-0">
                    EN
                  </div>
                  <div>
                    <div className="text-sm font-bold text-text flex items-center gap-2">
                      <span>English (Standard)</span>
                      {(formData.appLanguage || 'en') === 'en' && <Check className="w-4 h-4 text-primary" />}
                    </div>
                    <p className="text-xs text-text-secondary mt-1">
                      Full system menus, student certificates, fee receipts, and exports in English.
                    </p>
                  </div>
                </button>

                <button
                  type="button"
                  onClick={() => {
                    setFormData({ ...formData, appLanguage: 'hi' });
                    updateSettings({ appLanguage: 'hi' });
                    showToast('पोर्टल भाषा हिंदी में सेट हो गई है!', 'success');
                  }}
                  className={`p-5 rounded-2xl border text-left cursor-pointer transition-all flex items-start gap-3.5 ${
                    formData.appLanguage === 'hi'
                      ? 'border-primary bg-primary/5 ring-2 ring-primary/20 shadow-xs'
                      : 'border-border hover:border-primary/40 bg-surface2/40'
                  }`}
                >
                  <div className="w-10 h-10 rounded-xl bg-orange-500/10 text-orange-600 flex items-center justify-center font-bold text-sm flex-shrink-0">
                    हिं
                  </div>
                  <div>
                    <div className="text-sm font-bold text-text flex items-center gap-2">
                      <span>हिन्दी (Hindi)</span>
                      {formData.appLanguage === 'hi' && <Check className="w-4 h-4 text-primary" />}
                    </div>
                    <p className="text-xs text-text-secondary mt-1">
                      कक्षा, विद्यार्थी सूची, और शिक्षक डैशबोर्ड में हिंदी शब्दों की अनुकूलता।
                    </p>
                  </div>
                </button>
              </div>
            </div>
          )}

          {/* === SECTION 4: SUBSCRIPTION & PLANS === */}
          {activeSection === 'subscription' && (
            <div className="bg-white dark:bg-surface border border-border rounded-3xl p-6 sm:p-7 shadow-sm space-y-6">
              <div className="flex items-center justify-between border-b border-border pb-4">
                <div>
                  <h2 className="text-base font-bold text-text flex items-center gap-2">
                    <Sparkles className="w-5 h-5 text-primary" />
                    <span>School Cloud Subscription & Plans</span>
                  </h2>
                  <p className="text-xs text-text-secondary mt-0.5">
                    Har subscription plan me 100% full access shamil hai. Koi feature locked nahi hai.
                  </p>
                </div>
                <span className="px-3 py-1 rounded-full text-xs font-bold bg-emerald-100 text-emerald-800 dark:bg-emerald-950/60 dark:text-emerald-300 border border-emerald-300">
                  Active (All Access)
                </span>
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
                {[
                  { name: 'Free Trial', price: '₹0', dur: 'Trial', note: 'Max 10 Students', badge: 'Test Drive' },
                  { name: 'Starter Plan', price: '₹199', dur: '/ mo', note: 'Up to 50 Students', badge: 'Affordable' },
                  { name: 'Standard School', price: '₹399', dur: '/ mo', note: 'Up to 200 Students', badge: 'Most Popular', highlight: true },
                  { name: 'Pro Unlimited', price: '₹699', dur: '/ mo', note: 'Unlimited Students', badge: 'Unlimited' },
                ].map((plan) => (
                  <div
                    key={plan.name}
                    className={`p-4 rounded-2xl border flex flex-col justify-between transition-all relative ${
                      plan.highlight
                        ? 'border-primary bg-primary/5 ring-2 ring-primary/20 shadow-md'
                        : 'border-border bg-surface2/30'
                    }`}
                  >
                    {plan.badge && (
                      <span className={`absolute -top-3 left-4 px-2 py-0.5 rounded-full text-[9px] font-black uppercase tracking-wider ${
                        plan.highlight ? 'bg-primary text-white' : 'bg-surface2 text-text-secondary border border-border'
                      }`}>
                        {plan.badge}
                      </span>
                    )}
                    <div className="space-y-1.5 mt-1">
                      <div className="text-xs font-bold text-text">{plan.name}</div>
                      <div className="flex items-baseline gap-1">
                        <span className="text-xl font-black text-text">{plan.price}</span>
                        <span className="text-[10px] text-text-secondary">{plan.dur}</span>
                      </div>
                      <p className="text-[11px] font-semibold text-emerald-600">{plan.note}</p>
                    </div>

                    <div className="mt-3 pt-2.5 border-t border-border/80 space-y-1 text-xs text-text-secondary">
                      <div className="flex items-center gap-1.5 font-bold text-text text-[10px]">
                        <Check className="w-3 h-3 text-emerald-600" />
                        <span>All 15+ Modules Unlocked</span>
                      </div>
                      <div className="flex items-center gap-1.5 text-[10px]">
                        <Check className="w-3 h-3 text-emerald-600" />
                        <span>Receipts & Marksheets PDF</span>
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* === SECTION 5: HELP & SUPPORT === */}
          {activeSection === 'support' && (
            <div className="bg-white dark:bg-surface border border-border rounded-3xl p-6 sm:p-7 shadow-sm space-y-6">
              <div className="flex items-center justify-between border-b border-border pb-4">
                <div>
                  <h2 className="text-base font-bold text-text flex items-center gap-2">
                    <Headphones className="w-5 h-5 text-primary" />
                    <span>Customer Support & Helpline</span>
                  </h2>
                  <p className="text-xs text-text-secondary mt-0.5">
                    Need assistance? Connect with our dedicated support executive instantly.
                  </p>
                </div>
                <button
                  type="button"
                  onClick={() => setIsHelpFeedbackOpen(true)}
                  className="px-4 py-2 rounded-2xl bg-[#121212] hover:bg-[#1f1f1f] text-white border border-[#333333] text-xs font-bold flex items-center gap-2 cursor-pointer shadow-sm transition-all"
                >
                  <HelpCircle className="w-4 h-4 text-teal-400" />
                  <span>Help & Feedback Suite</span>
                </button>
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <a
                  href="https://wa.me/918603481865?text=Hello%20School%20Support%20Team%2C%20I%20need%20assistance%20with%20my%20school%20management%20portal."
                  target="_blank"
                  rel="noreferrer"
                  className="p-5 rounded-2xl border border-emerald-500/30 bg-emerald-500/5 hover:bg-emerald-500/10 transition-all flex items-start gap-4 group"
                >
                  <div className="w-11 h-11 rounded-2xl bg-emerald-500 text-white flex items-center justify-center font-bold flex-shrink-0 shadow-md">
                    <MessageCircle className="w-6 h-6" />
                  </div>
                  <div>
                    <div className="text-sm font-bold text-text group-hover:text-emerald-700 transition-colors">
                      WhatsApp Live Support
                    </div>
                    <p className="text-xs text-text-secondary mt-1">
                      Direct chat for quick setup questions, receipt printing issues and feature guidance.
                    </p>
                    <span className="inline-flex items-center gap-1 text-xs font-bold text-emerald-600 mt-2">
                      <span>Chat on WhatsApp</span>
                      <ExternalLink className="w-3.5 h-3.5" />
                    </span>
                  </div>
                </a>

                <a
                  href="tel:+918603481865"
                  className="p-5 rounded-2xl border border-primary/30 bg-primary/5 hover:bg-primary/10 transition-all flex items-start gap-4 group"
                >
                  <div className="w-11 h-11 rounded-2xl bg-primary text-white flex items-center justify-center font-bold flex-shrink-0 shadow-md">
                    <PhoneCall className="w-6 h-6" />
                  </div>
                  <div>
                    <div className="text-sm font-bold text-text group-hover:text-primary transition-colors">
                      Direct Voice Helpline
                    </div>
                    <p className="text-xs text-text-secondary mt-1">
                      Talk directly with our support specialist Monday - Saturday 9:00 AM to 7:00 PM.
                    </p>
                    <span className="inline-flex items-center gap-1 text-xs font-bold text-primary mt-2">
                      <span>Call +91 86034 81865</span>
                    </span>
                  </div>
                </a>
              </div>
            </div>
          )}

          {/* === SECTION 6: DATA BACKUP & RESTORE === */}
          {activeSection === 'backup' && (
            <div className="bg-white dark:bg-surface border border-border rounded-3xl p-6 sm:p-7 shadow-sm space-y-6">
              <div className="flex items-center justify-between border-b border-border pb-4">
                <div>
                  <h2 className="text-base font-bold text-text flex items-center gap-2">
                    <RefreshCw className="w-5 h-5 text-primary" />
                    <span>Database Backup & Data Restoration</span>
                  </h2>
                  <p className="text-xs text-text-secondary mt-0.5">
                    Download full offline snapshot of your school directory or restore from a previous JSON backup.
                  </p>
                </div>
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div className="p-5 rounded-2xl border border-border bg-surface2/40 space-y-3">
                  <div className="flex items-center gap-2.5">
                    <Download className="w-5 h-5 text-primary" />
                    <span className="text-sm font-bold text-text">Export Full Database Backup</span>
                  </div>
                  <p className="text-xs text-text-secondary leading-relaxed">
                    Downloads an encrypted JSON backup file containing all student records, fee ledger history, and attendance records.
                  </p>
                  <button
                    type="button"
                    onClick={exportAllDataJson}
                    className="w-full py-2.5 rounded-xl bg-primary hover:bg-primary-dark text-white font-bold text-xs shadow-md transition-all flex items-center justify-center gap-2 cursor-pointer"
                  >
                    <Download className="w-4 h-4" />
                    <span>Download JSON Backup</span>
                  </button>
                </div>

                <div className="p-5 rounded-2xl border border-border bg-surface2/40 space-y-3">
                  <div className="flex items-center gap-2.5">
                    <Upload className="w-5 h-5 text-primary" />
                    <span className="text-sm font-bold text-text">Restore From JSON File</span>
                  </div>
                  <p className="text-xs text-text-secondary leading-relaxed">
                    Select a previously exported JSON backup file to restore records into your active session.
                  </p>
                  <label className="w-full py-2.5 rounded-xl bg-surface2 hover:bg-border border border-border text-text font-bold text-xs transition-all flex items-center justify-center gap-2 cursor-pointer">
                    <Upload className="w-4 h-4 text-primary" />
                    <span>Select Backup File</span>
                    <input
                      type="file"
                      accept=".json"
                      className="hidden"
                      onChange={handleJsonImport}
                    />
                  </label>
                </div>
              </div>
            </div>
          )}

          {/* === SECTION: CONNECTED DEVICES & GPS === */}
          {activeSection === 'devices' && (
            <ConnectedDevicesView />
          )}

          {/* === SECTION 7: SETUP WIZARD === */}
          {activeSection === 'wizard' && (
            <div className="bg-white dark:bg-surface border border-border rounded-3xl p-6 sm:p-7 shadow-sm space-y-6">
              <div className="flex items-center justify-between border-b border-border pb-4">
                <div>
                  <h2 className="text-base font-bold text-text flex items-center gap-2">
                    <School className="w-5 h-5 text-primary" />
                    <span>Interactive School Setup Wizard</span>
                  </h2>
                  <p className="text-xs text-text-secondary mt-0.5">
                    Follow these 3 easy steps to configure your school management workspace.
                  </p>
                </div>
              </div>

              {/* Progress Stepper */}
              <div className="flex items-center justify-between max-w-md mx-auto py-2">
                {[
                  { step: 1, label: 'School Particulars' },
                  { step: 2, label: 'Classes & Sections' },
                  { step: 3, label: 'Logo & Sign' },
                ].map((s) => (
                  <div key={s.step} className="flex flex-col items-center gap-1.5">
                    <button
                      type="button"
                      onClick={() => setWizardStep(s.step)}
                      className={`w-9 h-9 rounded-2xl flex items-center justify-center font-bold text-xs transition-all cursor-pointer ${
                        wizardStep === s.step
                          ? 'bg-primary text-white shadow-md shadow-primary/20 scale-105'
                          : wizardStep > s.step
                          ? 'bg-emerald-600 text-white'
                          : 'bg-surface2 text-text-secondary border border-border'
                      }`}
                    >
                      {wizardStep > s.step ? <Check className="w-4 h-4" /> : s.step}
                    </button>
                    <span className="text-[10px] font-bold text-text-secondary">{s.label}</span>
                  </div>
                ))}
              </div>

              {/* Wizard Body */}
              <div className="p-5 rounded-2xl bg-surface2/40 border border-border space-y-4">
                {wizardStep === 1 && (
                  <div className="space-y-3">
                    <h3 className="text-xs font-bold uppercase tracking-wider text-text">Step 1: Confirm School Particulars</h3>
                    <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 text-xs">
                      <div>
                        <span className="text-text-secondary block text-[10px]">School Name:</span>
                        <span className="font-bold text-text">{formData.instituteName || 'Not Set'}</span>
                      </div>
                      <div>
                        <span className="text-text-secondary block text-[10px]">Contact Mobile:</span>
                        <span className="font-bold text-text">{formData.mobile || 'Not Set'}</span>
                      </div>
                      <div className="sm:col-span-2">
                        <span className="text-text-secondary block text-[10px]">Campus Address:</span>
                        <span className="font-bold text-text">{formData.address || 'Not Set'}</span>
                      </div>
                    </div>
                  </div>
                )}

                {wizardStep === 2 && (
                  <div className="space-y-3">
                    <h3 className="text-xs font-bold uppercase tracking-wider text-text">Step 2: Configured Academic Standards</h3>
                    <p className="text-xs text-text-secondary">
                      You currently have {(formData.classes || formData.schoolClasses || []).length} active classes configured for student admissions.
                    </p>
                    <div className="flex flex-wrap gap-1.5 max-h-36 overflow-y-auto">
                      {(formData.classes || formData.schoolClasses || []).map(c => (
                        <span key={c} className="px-2.5 py-1 rounded-lg bg-surface border border-border text-[11px] font-bold text-text">
                          {c}
                        </span>
                      ))}
                    </div>
                  </div>
                )}

                {wizardStep === 3 && (
                  <div className="space-y-3">
                    <h3 className="text-xs font-bold uppercase tracking-wider text-text">Step 3: Identity & Printing Assets</h3>
                    <div className="flex items-center gap-4">
                      <div className="w-16 h-16 rounded-xl border border-border bg-white dark:bg-surface p-1 flex items-center justify-center">
                        {formData.logoUrl ? (
                          <img src={formData.logoUrl} alt="Logo" className="w-full h-full object-contain" />
                        ) : (
                          <School className="w-6 h-6 text-text-secondary opacity-40" />
                        )}
                      </div>
                      <div className="text-xs space-y-1">
                        <p className="font-bold text-text">{formData.logoUrl ? '✓ Logo configured' : '⚠ Logo pending'}</p>
                        <p className="text-text-secondary">{formData.principalSignature ? '✓ Signature configured' : '⚠ Signature pending'}</p>
                      </div>
                    </div>
                  </div>
                )}

                <div className="flex items-center justify-between pt-3 border-t border-border">
                  <button
                    type="button"
                    disabled={wizardStep === 1}
                    onClick={() => setWizardStep(prev => Math.max(1, prev - 1))}
                    className="px-4 py-2 rounded-xl border border-border text-xs font-bold text-text disabled:opacity-40 cursor-pointer"
                  >
                    Previous
                  </button>
                  {wizardStep < 3 ? (
                    <button
                      type="button"
                      onClick={() => setWizardStep(prev => Math.min(3, prev + 1))}
                      className="px-4 py-2 rounded-xl bg-primary text-white text-xs font-bold cursor-pointer"
                    >
                      Next Step
                    </button>
                  ) : (
                    <button
                      type="button"
                      onClick={() => {
                        handleSubmit();
                        setActiveSection('branding');
                        showToast('Setup wizard finished! All settings configured.', 'success');
                      }}
                      className="px-4 py-2 rounded-xl bg-emerald-600 text-white text-xs font-bold cursor-pointer"
                    >
                      Complete & Save
                    </button>
                  )}
                </div>
              </div>
            </div>
          )}

        </div>
      </div>

      {/* Recrop Logo Modal */}
      {isLogoCropperOpen && logoToCrop && (
        <ImageCropperModal
          isOpen={isLogoCropperOpen}
          imageSrc={logoToCrop}
          title="Crop & Align Institute Logo"
          initialAspect="1:1"
          onClose={() => setIsLogoCropperOpen(false)}
          onCropComplete={handleLogoCropComplete}
        />
      )}

      {/* Recrop Stamp Modal */}
      {isStampCropperOpen && stampToCrop && (
        <ImageCropperModal
          isOpen={isStampCropperOpen}
          imageSrc={stampToCrop}
          title={formData.appLanguage === 'hi' ? 'स्कूल मुहर क्रॉप करें' : 'Crop School Stamp'}
          initialAspect="1:1"
          onClose={() => setIsStampCropperOpen(false)}
          onCropComplete={handleStampCropComplete}
        />
      )}
    </div>
  );
}
