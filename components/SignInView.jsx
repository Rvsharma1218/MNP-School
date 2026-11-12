'use client';

import {
  AboutPageView,
  AdmissionsPageView,
  AcademicsPageView,
  GalleryPageView,
  ContactPageView,
  DownloadPageView
} from './PublicPages';
import React, { useState, useEffect } from 'react';
import { db } from '../lib/firebase';
import { doc, onSnapshot } from 'firebase/firestore';
import { useSchoolStore } from '../lib/store';
import { translations } from '../lib/translations';
import {
  GraduationCap, Mail, Lock, Eye, EyeOff, ShieldCheck,
  School, ArrowRight, AlertCircle, CheckCircle2,
  User, ChevronDown, ChevronRight, Phone, Hash, ArrowLeft, BookOpen,
  Users, CalendarCheck, CreditCard, Shield, FileText, CheckCircle,
  Award, Heart, Compass, Sparkles, Building, Quote, Check,
  Activity, Monitor, Trophy, HelpCircle, MapPin, Clock, MessageSquare,
  Globe, Briefcase, Menu, X, ExternalLink, Calendar, Star,
  TrendingUp, QrCode, CheckCircle as CheckIcon, Smartphone, Download
} from 'lucide-react';

export default function SignInView() {
  const {
    signIn,
    teacherSignIn,
    parentSignIn,
    fetchSchoolTeachersByEmail,
    teachers,
    settings,
    currentUser,
    currentPath,
    navigate,
    language = 'en',
    toggleLanguage,
    setSignUpFormTab,
    openEnquiriesModal,
    setIsEnquiriesModalOpen
  } = useSchoolStore();

  const t = translations[language] || translations.en;
  const isHi = language === 'hi';
  const activeRoute = (currentPath || '/').split('?')[0].split('#')[0].replace(/\/+$/, '') || '/';

  const [isLoginModalOpen, setIsLoginModalOpen] = useState(false);
  const [isAdmissionInquiryOpen, setIsAdmissionInquiryOpen] = useState(false);
  const [inquirySuccess, setInquirySuccess] = useState(null);
  const [inquiryLoading, setInquiryLoading] = useState(false);
  const [inquiryForm, setInquiryForm] = useState({
    studentName: '',
    fatherName: '',
    mobile: '',
    admissionClass: 'Nursery',
    address: '',
    message: ''
  });
  const [isMobileMenuOpen, setIsMobileMenuOpen] = useState(false);
  const [isNavDropdownOpen, setIsNavDropdownOpen] = useState(false);
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [role, setRole] = useState('parent'); // 'parent' | 'teacher' | 'principal'
  const [parentAdmissionNo, setParentAdmissionNo] = useState('');
  const [parentMobile, setParentMobile] = useState('');
  const [selectedTeacherId, setSelectedTeacherId] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [rememberMe, setRememberMe] = useState(true);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  // Live Website CMS Dynamic State (Synced in Real-Time with Admin App)
  const [websiteConfig, setWebsiteConfig] = useState(null);
  const [websiteGallery, setWebsiteGallery] = useState([]);
  const [websiteReviews, setWebsiteReviews] = useState([]);
  const [websiteLeadership, setWebsiteLeadership] = useState([]);
  const [isPopupAlertDismissed, setIsPopupAlertDismissed] = useState(false);

  useEffect(() => {
    // 1. Live Website Config (Banner Style, Marquee, Emergency Popup)
    const unsubConfig = onSnapshot(doc(db, 'schoolDirectory', 'website_config'), (snap) => {
      if (snap.exists()) setWebsiteConfig(snap.data());
    }, () => {});

    // 2. Live Photo Gallery
    const unsubGallery = onSnapshot(doc(db, 'schoolDirectory', 'website_gallery'), (snap) => {
      if (snap.exists()) setWebsiteGallery(snap.data()?.items || []);
    }, () => {});

    // 3. Live Parent Reviews & Ratings
    const unsubReviews = onSnapshot(doc(db, 'schoolDirectory', 'website_reviews'), (snap) => {
      if (snap.exists()) setWebsiteReviews(snap.data()?.items || []);
    }, () => {});

    // 4. Live Leadership & Staff
    const unsubLeadership = onSnapshot(doc(db, 'schoolDirectory', 'website_leadership'), (snap) => {
      if (snap.exists()) setWebsiteLeadership(snap.data()?.items || []);
    }, () => {});

    return () => {
      unsubConfig();
      unsubGallery();
      unsubReviews();
      unsubLeadership();
    };
  }, []);

  // Institution Verified Details from Official School Settings
  const schoolName = settings?.instituteName || settings?.schoolName || 'MISSION NAVODAYA PUBLIC SCHOOL';
  const schoolSubtitle = 'PUBLIC SCHOOL, MORA-MAIRI';
  const schoolLocation = 'Mora-Mairi, Siwan (Bihar)';
  const logoSrc = settings?.logoUrl || settings?.logoPath || settings?.logo || '/logo.png';
  const primaryPhone = settings?.phone || settings?.mobile || '8603481865';
  const officialEmail = settings?.email || 'mnps@mnpschool.in';
  const currentSession = settings?.currentSession || settings?.academicYear || '2026-27';
  const isAdmissionOpen = settings?.isAdmissionOpen !== false;
  const admissionClasses = settings?.admissionClasses || 'For Classes Nursery to 8th';

  useEffect(() => {
    if (role === 'teacher' && email) {
      fetchSchoolTeachersByEmail(email).then(list => {
        if (list && list.length > 0) {
          setSelectedTeacherId(prev => {
            const match = list.find(t => (t.authUid || t.id) === prev);
            return match ? prev : (list[0].authUid || list[0].id || '');
          });
        }
      });
    }
  }, [role, email, fetchSchoolTeachersByEmail]);

  useEffect(() => {
    if (teachers && teachers.length > 0 && !selectedTeacherId) {
      setSelectedTeacherId(teachers[0].authUid || teachers[0].id || '');
    }
  }, [teachers, role, selectedTeacherId]);

  useEffect(() => {
    if (isMobileMenuOpen) {
      document.body.style.overflow = 'hidden';
    } else {
      document.body.style.overflow = '';
    }
    return () => {
      document.body.style.overflow = '';
    };
  }, [isMobileMenuOpen]);

  const openPortalLogin = (targetRole = 'parent') => {
    setRole(targetRole);
    setError('');
    setIsLoginModalOpen(true);
    setIsMobileMenuOpen(false);
    window.scrollTo({ top: 0, behavior: 'smooth' });
  };

  const closeMobileMenuAndNavigate = (target) => {
    setIsMobileMenuOpen(false);
    if (isLoginModalOpen) {
      setIsLoginModalOpen(false);
    }
    if (target.startsWith('/')) {
      window.scrollTo({ top: 0, behavior: 'smooth' });
      navigate(target);
      return;
    }
    setTimeout(() => {
      const el = document.querySelector(target);
      if (el) {
        el.scrollIntoView({ behavior: 'smooth' });
      }
    }, 120);
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');
    setLoading(true);

    try {
      if (role === 'parent') {
        const cleanAdmInput = parentAdmissionNo.trim();
        const cleanPhoneDigits = parentMobile.replace(/\D/g, '');

        if (!cleanAdmInput) {
          throw new Error(language === 'hi' ? 'कृपया छात्र प्रवेश संख्या या स्टूडेंट आईडी दर्ज करें।' : "Please enter Admission Number or Student ID");
        }
        if (!cleanPhoneDigits || cleanPhoneDigits.length < 10) {
          throw new Error(language === 'hi' ? 'कृपया मान्य 10 अंकों का पंजीकृत मोबाइल नंबर दर्ज करें।' : 'Please enter a valid 10-digit registered mobile number');
        }
        await parentSignIn('', cleanAdmInput, cleanPhoneDigits);
      } else if (role === 'teacher') {
        if (!selectedTeacherId) {
          throw new Error(language === 'hi' ? 'कृपया सूची से अपना शिक्षक नाम चुनें।' : "Please select your teacher profile from the dropdown.");
        }
        await teacherSignIn(email.trim(), selectedTeacherId, password);
      } else {
        await signIn(email.trim(), password);
      }

      if (typeof window !== 'undefined') {
        window.location.href = '/dashboard';
      }
    } catch (err) {
      console.warn('Sign In attempt error:', err.message);
      if (err.message?.includes('user-not-found') || err.message?.includes('invalid-credential')) {
        setError(language === 'hi' ? 'अमान्य ईमेल या पासवर्ड। कृपया विवरण जांचें।' : 'Invalid email or password. Please verify your credentials.');
      } else if (err.message?.includes('wrong-password')) {
        setError(language === 'hi' ? 'गलत पासवर्ड दर्ज किया गया है।' : 'Incorrect password. Please try again.');
      } else {
        setError(err.message || 'Failed to sign in. Please verify your details.');
      }
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen w-full max-w-full overflow-x-hidden relative flex flex-col justify-between font-sans antialiased text-[#14243B] bg-[#F7F9FC] selection:bg-[#102747] selection:text-white">

      {/* ───────────────────────────────────────────────────────────── */}
      {/* 0. LIVE FLASH MARQUEE / BREAKING NEWS BAR (Controlled via App)*/}
      {/* ───────────────────────────────────────────────────────────── */}
      {websiteConfig?.flashNotice?.enabled && (websiteConfig?.flashNotice?.text || websiteConfig?.flashNotice?.textEn) && (
        <div className="bg-gradient-to-r from-red-700 via-amber-600 to-red-700 text-white text-[11px] sm:text-xs font-bold py-1.5 px-4 overflow-hidden relative shadow-md flex items-center justify-between gap-3 border-b border-red-800/40">
          <div className="flex items-center gap-2.5 overflow-hidden flex-1">
            <span className="flex-shrink-0 bg-white text-red-700 text-[10px] font-black uppercase px-2 py-0.5 rounded shadow-xs tracking-wider animate-pulse flex items-center gap-1">
              <span className="w-1.5 h-1.5 rounded-full bg-red-600 animate-ping inline-block" />
              {isHi
                ? (websiteConfig.flashNotice.badgeHi || websiteConfig.flashNotice.badge || 'नवीन सूचना')
                : (websiteConfig.flashNotice.badgeEn || (!/[\u0900-\u097F]/.test(websiteConfig.flashNotice.badge || '') ? websiteConfig.flashNotice.badge : null) || 'FLASH NOTICE')
              }
            </span>
            <div className="truncate text-slate-100 font-semibold tracking-wide">
              {isHi
                ? (websiteConfig.flashNotice.textHi || websiteConfig.flashNotice.text || '📢 सत्र 2026-27 के लिए नवीन नामांकन प्रारंभ है। सीमित सीटें उपलब्ध। विशेष नवोदय प्रवेश परीक्षा तैयारी बैच।')
                : (websiteConfig.flashNotice.textEn || (!/[\u0900-\u097F]/.test(websiteConfig.flashNotice.text || '') ? websiteConfig.flashNotice.text : null) || '📢 Admissions Open for Session 2026-27. Limited seats available. Special Navodaya entrance prep batch. Helpline: +91 8603481865')
              }
            </div>
          </div>
          <a
            href={`tel:${primaryPhone}`}
            className="flex-shrink-0 hidden md:inline-flex items-center gap-1.5 text-[11px] font-black bg-black/25 hover:bg-black/40 text-amber-300 px-3 py-0.5 rounded-full border border-white/20 transition-colors"
          >
            <Phone className="w-3 h-3 text-amber-300" />
            <span>{isHi ? 'हेल्पलाइन:' : 'Helpline:'} +91 {primaryPhone}</span>
          </a>
        </div>
      )}

      {/* ───────────────────────────────────────────────────────────── */}
      {/* 0B. EMERGENCY POPUP MODAL (Controlled via Admin App)          */}
      {/* ───────────────────────────────────────────────────────────── */}
      {websiteConfig?.popupAlert?.enabled && !isPopupAlertDismissed && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/70 backdrop-blur-sm animate-fadeIn">
          <div className="bg-white rounded-3xl max-w-lg w-full p-6 sm:p-8 shadow-2xl border border-slate-200 space-y-4 relative animate-scaleUp">
            <button
              onClick={() => setIsPopupAlertDismissed(true)}
              className="absolute top-4 right-4 p-2 rounded-full text-slate-400 hover:text-slate-700 hover:bg-slate-100 transition-colors"
              aria-label="Close"
            >
              <X className="w-5 h-5" />
            </button>
            <div className="flex items-center gap-2">
              <span className="px-3 py-1 rounded-full bg-amber-100 text-amber-900 border border-amber-300 text-xs font-black uppercase tracking-wider flex items-center gap-1.5">
                <AlertCircle className="w-3.5 h-3.5 text-amber-700" />
                {isHi
                  ? (websiteConfig.popupAlert.badgeHi || websiteConfig.popupAlert.badge || 'विशेष विद्यालय सूचना')
                  : (websiteConfig.popupAlert.badgeEn || (!/[\u0900-\u097F]/.test(websiteConfig.popupAlert.badge || '') ? websiteConfig.popupAlert.badge : null) || 'SCHOOL ANNOUNCEMENT')
                }
              </span>
            </div>
            <h3 className="text-xl font-black text-[#0c2340] tracking-tight">
              {isHi
                ? (websiteConfig.popupAlert.titleHi || websiteConfig.popupAlert.title || 'आवश्यक विद्यालय सूचना')
                : (websiteConfig.popupAlert.titleEn || (!/[\u0900-\u097F]/.test(websiteConfig.popupAlert.title || '') ? websiteConfig.popupAlert.title : null) || 'Official Notice')
              }
            </h3>
            <p className="text-xs sm:text-sm text-slate-600 leading-relaxed whitespace-pre-line">
              {isHi
                ? (websiteConfig.popupAlert.messageHi || websiteConfig.popupAlert.message || 'सत्र 2026-27 हेतु कक्षा नर्सरी से 8वीं तक में नामांकन हेतु ऑनलाइन आवेदन स्वीकार किए जा रहे हैं।')
                : (websiteConfig.popupAlert.messageEn || (!/[\u0900-\u097F]/.test(websiteConfig.popupAlert.message || '') ? websiteConfig.popupAlert.message : null) || 'Online admissions for Session 2026-27 are now open from Nursery to Class 8th. Limited seats available.')
              }
            </p>
            <div className="pt-3 border-t border-slate-100 flex items-center justify-end gap-3">
              <button
                onClick={() => {
                  setIsPopupAlertDismissed(true);
                  if (setSignUpFormTab) setSignUpFormTab('student');
                  navigate('/signup?tab=admission');
                }}
                className="px-5 py-2.5 rounded-xl bg-[#0c2340] hover:bg-[#143763] text-white font-bold text-xs shadow-md transition-all flex items-center gap-1.5"
              >
                <span>
                  {isHi
                    ? (websiteConfig.popupAlert.actionTextHi || websiteConfig.popupAlert.actionText || 'नामांकन फॉर्म भरें →')
                    : (websiteConfig.popupAlert.actionTextEn || (!/[\u0900-\u097F]/.test(websiteConfig.popupAlert.actionText || '') ? websiteConfig.popupAlert.actionText : null) || 'Apply Online →')
                  }
                </span>
              </button>
              <button
                onClick={() => setIsPopupAlertDismissed(true)}
                className="px-4 py-2.5 rounded-xl bg-slate-100 hover:bg-slate-200 text-slate-700 font-bold text-xs transition-colors"
              >
                {isHi ? 'बंद करें' : 'Close'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* ───────────────────────────────────────────────────────────── */}
      {/* 1. TOP ANNOUNCEMENT STRIP (Navy #102747 + Gold #F4B323)       */}
      {/* ───────────────────────────────────────────────────────────── */}
      <div className="bg-[#091A32] text-white text-[11px] font-bold px-4 sm:px-6 lg:px-8 py-2 border-b border-[#1E3A60] hidden sm:block">
        <div className="w-full flex items-center justify-between gap-4">
          <div className="flex items-center gap-3">
            {isAdmissionOpen ? (
              <>
                <span className="px-2.5 py-0.5 rounded-full bg-[#F4B323] text-[#091A32] text-[10px] font-black uppercase tracking-wider">
                  {isHi ? `प्रवेश प्रारंभ ${currentSession}` : `Admissions ${currentSession}`}
                </span>
                <span className="text-slate-200">
                  {isHi ? `नर्सरी से 8वीं तक नामांकन जारी · मोरा-मैरी, सीवान (बिहार)` : `Now Enrolling ${admissionClasses} · ${schoolLocation}`}
                </span>
              </>
            ) : (
              <>
                <span className="px-2.5 py-0.5 rounded-full bg-slate-700 text-slate-200 text-[10px] font-bold uppercase tracking-wider border border-slate-600">
                  {isHi ? `सत्र ${currentSession}` : `Session ${currentSession}`}
                </span>
                <span className="text-slate-200">
                  {isHi ? `शैक्षणिक सत्र प्रगति पर है · मोरा-मैरी, सीवान (बिहार)` : `Academic Session in Progress · ${schoolLocation}`}
                </span>
              </>
            )}
          </div>

          <div className="flex items-center gap-5 text-slate-300">
            <a href={`tel:${primaryPhone}`} className="hover:text-[#F4B323] transition-colors flex items-center gap-1.5">
              <Phone className="w-3 h-3 text-[#F4B323]" />
              <span>+91 {primaryPhone}</span>
            </a>
            <span className="text-slate-600">·</span>
            <a href={`mailto:${officialEmail}`} className="hover:text-[#F4B323] transition-colors flex items-center gap-1.5">
              <Mail className="w-3 h-3 text-[#F4B323]" />
              <span>{officialEmail}</span>
            </a>
            <span className="text-slate-600">·</span>
            <span className="flex items-center gap-1">
              <Clock className="w-3 h-3 text-[#F4B323]" />
              <span>{isHi ? 'सोम – शनि: 8:00 AM – 2:00 PM' : 'Mon – Sat: 8:00 AM – 2:00 PM'}</span>
            </span>
          </div>
        </div>
      </div>

      {/* ───────────────────────────────────────────────────────────── */}
      {/* 2. MAIN HEADER & INSTITUTIONAL NAVIGATION                    */}
      {/* ───────────────────────────────────────────────────────────── */}
      <header className="sticky top-0 z-40 w-full bg-[#08182b]/85 backdrop-blur-xl border-b border-white/10 shadow-lg transition-all">
        <div className="w-full px-3 sm:px-6 lg:px-8 h-16 sm:h-20 flex items-center justify-between gap-2 sm:gap-4">

          {/* Brand Seal, School Title & Subtitle */}
          <a href="#about" className="flex items-center gap-2 sm:gap-3.5 min-w-0 flex-1 group">
            <div className="w-10 h-10 sm:w-12 sm:h-12 flex items-center justify-center flex-shrink-0 transition-transform group-hover:scale-105 drop-shadow-md">
              <img
                src={logoSrc}
                alt={isHi ? "मिशन नवोदय पब्लिक स्कूल मोरा आधिकारिक मुहर" : "Mission Navodaya Public School Mora Official Seal"}
                className="w-full h-full object-contain"
                onError={(e) => {
                  e.currentTarget.onerror = null;
                  e.currentTarget.src = '/logo.png';
                }}
              />
            </div>
            <div className="min-w-0 flex-1">
              <div className="text-xs sm:text-base lg:text-lg font-black tracking-tight text-white leading-tight truncate uppercase">
                <span className="sm:hidden">{isHi ? 'मिशन नवोदय स्कूल' : 'MNP School Mora-Mairi'}</span>
                <span className="hidden sm:inline">{isHi ? 'मिशन नवोदय पब्लिक स्कूल' : schoolName}</span>
              </div>
              <div className="text-[10px] sm:text-[11px] font-bold text-[#F4B323] tracking-wide truncate flex items-center gap-1.5 mt-0.5">
                <span className="w-1.5 h-1.5 rounded-full bg-[#F4B323] animate-pulse flex-shrink-0" />
                <span className="sm:hidden">{isHi ? `मोरा-मैरी, सीवान · सत्र ${currentSession}` : `Mora-Mairi, Siwan · ${currentSession}`}</span>
                <span className="hidden sm:inline">{isHi ? `मोरा-मैरी, सीवान (बिहार) · सत्र ${currentSession}` : `Mora-Mairi, Siwan (Bihar) · Session ${currentSession}`}</span>
              </div>
            </div>
          </a>

          {/* Desktop Navigation Links — Visible on all Laptops & Desktops (lg and above) */}
          <nav className="hidden lg:flex items-center gap-1.5 xl:gap-2.5 text-xs font-bold">
            <button
              type="button"
              onClick={() => { setIsLoginModalOpen(false); navigate('/'); }}
              className={`px-3 py-1.5 rounded-xl transition-all cursor-pointer ${
                activeRoute === '/' 
                  ? 'bg-[#F4B323] text-[#0c2340] font-black shadow-xs' 
                  : 'text-slate-200 hover:text-[#F4B323] hover:bg-white/5'
              }`}
            >
              {isHi ? 'होम' : 'Home'}
            </button>
            <button
              type="button"
              onClick={() => { setIsLoginModalOpen(false); navigate('/about'); }}
              className={`px-3 py-1.5 rounded-xl transition-all cursor-pointer ${
                activeRoute === '/about' 
                  ? 'bg-[#F4B323] text-[#0c2340] font-black shadow-xs' 
                  : 'text-slate-200 hover:text-[#F4B323] hover:bg-white/5'
              }`}
            >
              {isHi ? 'परिचय' : 'About'}
            </button>
            {isAdmissionOpen && (
              <button
                type="button"
                onClick={() => { setIsLoginModalOpen(false); navigate('/admissions'); }}
                className={`px-3 py-1.5 rounded-xl transition-all cursor-pointer ${
                  activeRoute === '/admissions' 
                    ? 'bg-[#F4B323] text-[#0c2340] font-black shadow-xs' 
                    : 'text-amber-300 hover:text-[#F4B323] hover:bg-white/5 font-black'
                }`}
              >
                {isHi ? 'दाखिला (2026-27)' : 'Admissions'}
              </button>
            )}
            <button
              type="button"
              onClick={() => { setIsLoginModalOpen(false); navigate('/academics'); }}
              className={`px-3 py-1.5 rounded-xl transition-all cursor-pointer ${
                activeRoute === '/academics' 
                  ? 'bg-[#F4B323] text-[#0c2340] font-black shadow-xs' 
                  : 'text-slate-200 hover:text-[#F4B323] hover:bg-white/5'
              }`}
            >
              {isHi ? 'शिक्षा व सुविधाएं' : 'Academics'}
            </button>
            <button
              type="button"
              onClick={() => { setIsLoginModalOpen(false); navigate('/gallery'); }}
              className={`px-3 py-1.5 rounded-xl transition-all cursor-pointer ${
                activeRoute === '/gallery' 
                  ? 'bg-[#F4B323] text-[#0c2340] font-black shadow-xs' 
                  : 'text-slate-200 hover:text-[#F4B323] hover:bg-white/5'
              }`}
            >
              {isHi ? 'गैलरी' : 'Gallery'}
            </button>
            <button
              type="button"
              onClick={() => { setIsLoginModalOpen(false); navigate('/download'); }}
              className={`px-3 py-1.5 rounded-xl transition-all cursor-pointer inline-flex items-center gap-1.5 ${
                activeRoute === '/download' 
                  ? 'bg-[#F4B323] text-[#0c2340] font-black shadow-xs' 
                  : 'text-slate-200 hover:text-[#F4B323] hover:bg-white/5'
              }`}
            >
              <Smartphone className="w-3.5 h-3.5 text-[#F4B323]" />
              <span>{isHi ? 'ऐप' : 'App'}</span>
            </button>
            <button
              type="button"
              onClick={() => { setIsLoginModalOpen(false); navigate('/contact'); }}
              className={`px-3 py-1.5 rounded-xl transition-all cursor-pointer ${
                activeRoute === '/contact' 
                  ? 'bg-[#F4B323] text-[#0c2340] font-black shadow-xs' 
                  : 'text-slate-200 hover:text-[#F4B323] hover:bg-white/5'
              }`}
            >
              {isHi ? 'संपर्क' : 'Contact'}
            </button>
          </nav>

          {/* Adaptive Navigation Dropdown for Medium Screens (md to lg) */}
          <div className="hidden md:flex lg:hidden relative">
            <button
              type="button"
              onClick={() => setIsNavDropdownOpen(prev => !prev)}
              className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-white/10 hover:bg-white/15 border border-white/20 text-xs font-bold text-slate-100 transition-all cursor-pointer shadow-2xs"
            >
              <Compass className="w-3.5 h-3.5 text-[#F4B323]" />
              <span>{isHi ? 'नेविगेशन' : 'Menu'}</span>
              <ChevronDown className={`w-3 h-3 text-slate-300 transition-transform ${isNavDropdownOpen ? 'rotate-180' : ''}`} />
            </button>

            {isNavDropdownOpen && (
              <div className="absolute left-0 top-full mt-2 w-52 rounded-2xl bg-[#091A32]/98 backdrop-blur-xl border border-white/20 shadow-2xl py-2 z-50 animate-in fade-in slide-in-from-top-2 duration-150">
                <a href="#about" onClick={() => setIsNavDropdownOpen(false)} className="flex items-center gap-2 px-4 py-2 text-xs font-bold text-slate-200 hover:text-[#F4B323] hover:bg-white/10 transition-colors">
                  <School className="w-3.5 h-3.5 text-[#F4B323]" />
                  <span>{isHi ? 'विद्यालय परिचय' : 'About School'}</span>
                </a>
                {isAdmissionOpen && (
                  <a href="#admissions" onClick={() => setIsNavDropdownOpen(false)} className="flex items-center gap-2 px-4 py-2 text-xs font-bold text-[#F4B323] hover:bg-white/10 transition-colors">
                    <Sparkles className="w-3.5 h-3.5 text-[#F4B323]" />
                    <span>{isHi ? `प्रवेश ${currentSession}` : `Admissions ${currentSession}`}</span>
                  </a>
                )}
                <a href="#features" onClick={() => setIsNavDropdownOpen(false)} className="flex items-center gap-2 px-4 py-2 text-xs font-bold text-slate-200 hover:text-[#F4B323] hover:bg-white/10 transition-colors">
                  <Award className="w-3.5 h-3.5 text-[#F4B323]" />
                  <span>{isHi ? 'विशेषताएं' : 'Features & Pillars'}</span>
                </a>
                <a href="#leadership" onClick={() => setIsNavDropdownOpen(false)} className="flex items-center gap-2 px-4 py-2 text-xs font-bold text-slate-200 hover:text-[#F4B323] hover:bg-white/10 transition-colors">
                  <Users className="w-3.5 h-3.5 text-[#F4B323]" />
                  <span>{isHi ? 'नेतृत्व' : 'Leadership Team'}</span>
                </a>
                <a href="#campus-gallery" onClick={() => setIsNavDropdownOpen(false)} className="flex items-center gap-2 px-4 py-2 text-xs font-bold text-slate-200 hover:text-[#F4B323] hover:bg-white/10 transition-colors">
                  <Eye className="w-3.5 h-3.5 text-[#F4B323]" />
                  <span>{isHi ? 'कैंपस गैलरी' : 'Campus Gallery'}</span>
                </a>
                <a href="#reviews" onClick={() => setIsNavDropdownOpen(false)} className="flex items-center gap-2 px-4 py-2 text-xs font-bold text-slate-200 hover:text-[#F4B323] hover:bg-white/10 transition-colors">
                  <MessageSquare className="w-3.5 h-3.5 text-[#F4B323]" />
                  <span>{isHi ? 'समीक्षाएं' : 'Parent Reviews'}</span>
                </a>
                <a href="#contact" onClick={() => setIsNavDropdownOpen(false)} className="flex items-center gap-2 px-4 py-2 text-xs font-bold text-slate-200 hover:text-[#F4B323] hover:bg-white/10 transition-colors">
                  <Phone className="w-3.5 h-3.5 text-[#F4B323]" />
                  <span>{isHi ? 'संपर्क' : 'Contact & Office'}</span>
                </a>
              </div>
            )}
          </div>

          {/* Desktop Action Buttons: Language, Single Unified Portal Login, and Online Admission */}
          <div className="hidden md:flex items-center gap-2 sm:gap-2.5 flex-shrink-0">
            {/* Language Toggle */}
            <button
              type="button"
              onClick={toggleLanguage}
              className="inline-flex items-center gap-1.5 px-2.5 py-1.5 rounded-xl bg-white/10 hover:bg-white/15 border border-white/20 text-xs font-bold text-slate-100 transition-all cursor-pointer flex-shrink-0"
              title="Toggle Language"
            >
              <Globe className="w-3.5 h-3.5 text-[#F4B323]" />
              <span>{isHi ? 'English' : 'हिन्दी'}</span>
            </button>

            {/* Unified Portal Login Button */}
            <button
              type="button"
              onClick={() => openPortalLogin('parent')}
              className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-bold text-white bg-white/10 hover:bg-white/20 border border-white/20 transition-all cursor-pointer shadow-2xs flex-shrink-0"
              title={isHi ? 'स्कूल पोर्टल लॉगिन' : 'School Portal Login'}
            >
              <ShieldCheck className="w-3.5 h-3.5 text-[#F4B323]" />
              <span>{isHi ? 'पोर्टल लॉगिन' : 'Portal Login'}</span>
            </button>

            {/* Online Admission Button */}
            {isAdmissionOpen && (
              <button
                type="button"
                onClick={() => {
                  if (setSignUpFormTab) setSignUpFormTab('student');
                  navigate('/signup?tab=admission');
                }}
                className="inline-flex items-center gap-1.5 sm:gap-2 px-3.5 sm:px-4 py-2 rounded-xl text-xs font-black text-[#091A32] bg-[#F4B323] hover:bg-[#e0a21a] shadow-md hover:shadow-lg transition-all cursor-pointer flex-shrink-0 whitespace-nowrap"
              >
                <Sparkles className="w-3.5 h-3.5 text-[#091A32]" />
                <span>{isHi ? 'ऑनलाइन प्रवेश' : 'Online Admission'}</span>
              </button>
            )}
          </div>

          {/* Mobile Right Action Area (Admission CTA + Language + Hamburger) */}
          <div className="flex md:hidden items-center gap-1.5 flex-shrink-0">
            {isAdmissionOpen && (
              <button
                type="button"
                onClick={() => {
                  if (setSignUpFormTab) setSignUpFormTab('student');
                  navigate('/signup?tab=admission');
                }}
                className="hidden min-[420px]:inline-flex items-center gap-1 px-2.5 py-1.5 rounded-lg bg-[#F4B323] text-[#091A32] text-xs font-black shadow-xs whitespace-nowrap cursor-pointer flex-shrink-0"
              >
                <Sparkles className="w-3 h-3 text-[#091A32]" />
                <span>{isHi ? 'प्रवेश' : 'Admission'}</span>
              </button>
            )}

            <button
              type="button"
              onClick={toggleLanguage}
              className="inline-flex items-center gap-1 px-2.5 py-1.5 rounded-lg bg-white/10 hover:bg-white/20 text-xs font-bold text-white border border-white/20 flex-shrink-0 cursor-pointer"
              title="Toggle Language"
            >
              <Globe className="w-3 h-3 text-[#F4B323]" />
              <span className="text-[11px]">{isHi ? 'EN' : 'हिन्दी'}</span>
            </button>

            <button
              type="button"
              onClick={() => setIsMobileMenuOpen(prev => !prev)}
              aria-label="Toggle Mobile Navigation Menu"
              className="p-1.5 sm:p-2 rounded-xl bg-white/10 hover:bg-white/20 text-white border border-white/20 transition-colors cursor-pointer flex items-center justify-center flex-shrink-0"
            >
              {isMobileMenuOpen ? <X className="w-5 h-5 text-[#F4B323]" /> : <Menu className="w-5 h-5" />}
            </button>
          </div>

        </div>

        {/* Mobile Dropdown Navigation Menu */}
        {isMobileMenuOpen && (
          <>
            {/* Backdrop for click outside */}
            <div
              className="md:hidden fixed inset-0 top-16 sm:top-20 bg-black/60 backdrop-blur-xs z-40 transition-opacity"
              onClick={() => setIsMobileMenuOpen(false)}
              aria-hidden="true"
            />

            <div className="md:hidden absolute top-full left-0 right-0 w-full max-h-[calc(100vh-4.5rem)] overflow-y-auto bg-[#08182E] border-t border-[#1E3A60] border-b-2 border-[#F4B323]/50 shadow-2xl z-50 px-3.5 py-4 animate-in slide-in-from-top-2 duration-200 text-white space-y-4">
              {/* Header Info Strip (Visible only when admission is open) */}
              {isAdmissionOpen && (
                <div className="p-2.5 rounded-xl bg-[#0f2442] border border-[#1E3A60] flex items-center justify-between text-xs">
                  <div className="flex items-center gap-2 font-bold text-[#F4B323]">
                    <Sparkles className="w-4 h-4 flex-shrink-0 text-[#F4B323]" />
                    <span>{isHi ? `सत्र ${currentSession} प्रवेश प्रारंभ` : `Admissions Open ${currentSession}`}</span>
                  </div>
                  <span className="text-[10px] px-2 py-0.5 rounded-full bg-[#F4B323]/20 text-[#F4B323] font-bold border border-[#F4B323]/30">
                    {isHi ? 'नर्सरी – 8वीं' : 'Nursery to 8th'}
                  </span>
                </div>
              )}

              {/* Primary Call to Actions: Online Admission & Portal Login */}
              <div className={`grid ${isAdmissionOpen ? 'grid-cols-1 sm:grid-cols-2' : 'grid-cols-1'} gap-2`}>
                {isAdmissionOpen && (
                  <button
                    type="button"
                    onClick={() => {
                      setIsMobileMenuOpen(false);
                      if (setSignUpFormTab) setSignUpFormTab('student');
                      navigate('/signup?tab=admission');
                    }}
                    className="w-full py-2.5 px-3 rounded-xl bg-[#F4B323] hover:bg-[#e0a21a] text-[#091A32] font-black text-xs flex items-center justify-center gap-2 shadow-md cursor-pointer transition-all active:scale-[0.98]"
                  >
                    <Sparkles className="w-4 h-4 text-[#091A32]" />
                    <span>{isHi ? `ऑनलाइन प्रवेश प्रपत्र ${currentSession}` : `Online Admission Form ${currentSession}`}</span>
                  </button>
                )}

                <button
                  type="button"
                  onClick={() => openPortalLogin('parent')}
                  className="w-full py-2.5 px-3 rounded-xl bg-white/10 hover:bg-white/15 text-white font-bold text-xs flex items-center justify-center gap-2 border border-white/20 cursor-pointer transition-all active:scale-[0.98]"
                >
                  <ShieldCheck className="w-4 h-4 text-[#F4B323]" />
                  <span>{isHi ? 'स्कूल डिजिटल पोर्टल लॉगिन' : 'School Digital Portal Login'}</span>
                </button>
              </div>

              {/* Section 1: Navigation Menu List */}
              <div className="space-y-1">
                <div className="px-2 text-[11px] font-black tracking-wider uppercase text-slate-400 flex items-center justify-between">
                  <span>{isHi ? 'मुख्य मेन्यू सूची' : 'Navigation Menu'}</span>
                  <span className="text-[10px] text-slate-500">{isHi ? `${isAdmissionOpen ? '8' : '7'} विकल्प` : `${isAdmissionOpen ? '8' : '7'} Items`}</span>
                </div>

                <div className="divide-y divide-white/5 rounded-2xl bg-[#0c1f38] border border-white/10 overflow-hidden shadow-sm">
                  <button
                    type="button"
                    onClick={() => closeMobileMenuAndNavigate('/about')}
                    className="w-full text-left px-3.5 py-2.5 hover:bg-white/10 active:bg-white/15 transition-colors cursor-pointer flex items-center justify-between group"
                  >
                    <div className="flex items-center gap-3">
                      <div className="w-7 h-7 rounded-lg bg-white/10 flex items-center justify-center text-[#F4B323] flex-shrink-0">
                        <School className="w-4 h-4" />
                      </div>
                      <div>
                        <div className="text-xs font-bold text-white group-hover:text-[#F4B323] transition-colors">{isHi ? 'विद्यालय परिचय' : 'About School'}</div>
                        <div className="text-[10px] text-slate-400">{isHi ? 'मिशन, दृष्टि एवं इतिहास' : 'Vision, Mission & History'}</div>
                      </div>
                    </div>
                    <ChevronRight className="w-4 h-4 text-slate-400 group-hover:text-[#F4B323] transition-transform group-hover:translate-x-0.5" />
                  </button>

                  {isAdmissionOpen && (
                    <button
                      type="button"
                      onClick={() => closeMobileMenuAndNavigate('/admissions')}
                      className="w-full text-left px-3.5 py-2.5 hover:bg-white/10 active:bg-white/15 transition-colors cursor-pointer flex items-center justify-between group bg-amber-500/5"
                    >
                      <div className="flex items-center gap-3">
                        <div className="w-7 h-7 rounded-lg bg-[#F4B323]/20 flex items-center justify-center text-[#F4B323] flex-shrink-0">
                          <Sparkles className="w-4 h-4" />
                        </div>
                        <div>
                          <div className="text-xs font-black text-[#F4B323]">{isHi ? `प्रवेश प्रक्रिया ${currentSession}` : `Admissions ${currentSession}`}</div>
                          <div className="text-[10px] text-slate-300">{isHi ? 'नर्सरी से 8वीं तक ऑनलाइन आवेदन' : 'Nursery to 8th Apply Online'}</div>
                        </div>
                      </div>
                      <ChevronRight className="w-4 h-4 text-[#F4B323] transition-transform group-hover:translate-x-0.5" />
                    </button>
                  )}

                  <button
                    type="button"
                    onClick={() => closeMobileMenuAndNavigate('/academics')}
                    className="w-full text-left px-3.5 py-2.5 hover:bg-white/10 active:bg-white/15 transition-colors cursor-pointer flex items-center justify-between group"
                  >
                    <div className="flex items-center gap-3">
                      <div className="w-7 h-7 rounded-lg bg-white/10 flex items-center justify-center text-[#F4B323] flex-shrink-0">
                        <Award className="w-4 h-4" />
                      </div>
                      <div>
                        <div className="text-xs font-bold text-white group-hover:text-[#F4B323] transition-colors">{isHi ? '5 प्रमुख विशेषताएं' : '5 Signature Features'}</div>
                        <div className="text-[10px] text-slate-400">{isHi ? 'अनुशासन, स्मार्ट क्लास, सुरक्षित कैंपस' : 'Discipline, Smart Class & Safety'}</div>
                      </div>
                    </div>
                    <ChevronRight className="w-4 h-4 text-slate-400 group-hover:text-[#F4B323] transition-transform group-hover:translate-x-0.5" />
                  </button>

                  <button
                    type="button"
                    onClick={() => closeMobileMenuAndNavigate('/about')}
                    className="w-full text-left px-3.5 py-2.5 hover:bg-white/10 active:bg-white/15 transition-colors cursor-pointer flex items-center justify-between group"
                  >
                    <div className="flex items-center gap-3">
                      <div className="w-7 h-7 rounded-lg bg-white/10 flex items-center justify-center text-[#F4B323] flex-shrink-0">
                        <Users className="w-4 h-4" />
                      </div>
                      <div>
                        <div className="text-xs font-bold text-white group-hover:text-[#F4B323] transition-colors">{isHi ? 'विद्यालय नेतृत्व एवं टीम' : 'Leadership & Mentors'}</div>
                        <div className="text-[10px] text-slate-400">{isHi ? 'प्रधानाचार्य एवं शिक्षक गण' : 'Principal & Dedicated Faculty'}</div>
                      </div>
                    </div>
                    <ChevronRight className="w-4 h-4 text-slate-400 group-hover:text-[#F4B323] transition-transform group-hover:translate-x-0.5" />
                  </button>

                  <button
                    type="button"
                    onClick={() => closeMobileMenuAndNavigate('#facilities')}
                    className="w-full text-left px-3.5 py-2.5 hover:bg-white/10 active:bg-white/15 transition-colors cursor-pointer flex items-center justify-between group"
                  >
                    <div className="flex items-center gap-3">
                      <div className="w-7 h-7 rounded-lg bg-white/10 flex items-center justify-center text-[#F4B323] flex-shrink-0">
                        <Building className="w-4 h-4" />
                      </div>
                      <div>
                        <div className="text-xs font-bold text-white group-hover:text-[#F4B323] transition-colors">{isHi ? 'परिसर सुविधाएं' : 'Campus Facilities'}</div>
                        <div className="text-[10px] text-slate-400">{isHi ? 'खेल मैदान, CCTV, पुस्तकालय' : 'Sports, CCTV & Activity Labs'}</div>
                      </div>
                    </div>
                    <ChevronRight className="w-4 h-4 text-slate-400 group-hover:text-[#F4B323] transition-transform group-hover:translate-x-0.5" />
                  </button>

                  <button
                    type="button"
                    onClick={() => closeMobileMenuAndNavigate('/gallery')}
                    className="w-full text-left px-3.5 py-2.5 hover:bg-white/10 active:bg-white/15 transition-colors cursor-pointer flex items-center justify-between group"
                  >
                    <div className="flex items-center gap-3">
                      <div className="w-7 h-7 rounded-lg bg-white/10 flex items-center justify-center text-[#F4B323] flex-shrink-0">
                        <Eye className="w-4 h-4" />
                      </div>
                      <div>
                        <div className="text-xs font-bold text-white group-hover:text-[#F4B323] transition-colors">{isHi ? 'फोटो गैलरी' : 'Campus Photo Gallery'}</div>
                        <div className="text-[10px] text-slate-400">{isHi ? 'समारोह एवं विद्यालय गतिविधियां' : 'Campus Events & Student Activities'}</div>
                      </div>
                    </div>
                    <ChevronRight className="w-4 h-4 text-slate-400 group-hover:text-[#F4B323] transition-transform group-hover:translate-x-0.5" />
                  </button>

                  <button
                    type="button"
                    onClick={() => closeMobileMenuAndNavigate('#reviews')}
                    className="w-full text-left px-3.5 py-2.5 hover:bg-white/10 active:bg-white/15 transition-colors cursor-pointer flex items-center justify-between group"
                  >
                    <div className="flex items-center gap-3">
                      <div className="w-7 h-7 rounded-lg bg-white/10 flex items-center justify-center text-[#F4B323] flex-shrink-0">
                        <MessageSquare className="w-4 h-4" />
                      </div>
                      <div>
                        <div className="text-xs font-bold text-white group-hover:text-[#F4B323] transition-colors">{isHi ? 'अभिभावक समीक्षाएं' : 'Parent Reviews'}</div>
                        <div className="text-[10px] text-slate-400">{isHi ? 'अभिभावकों का विश्वास एवं अनुभव' : 'Parent Trust & Testimonials'}</div>
                      </div>
                    </div>
                    <ChevronRight className="w-4 h-4 text-slate-400 group-hover:text-[#F4B323] transition-transform group-hover:translate-x-0.5" />
                  </button>

                  <button
                    type="button"
                    onClick={() => closeMobileMenuAndNavigate('/download')}
                  className="px-4 py-2.5 rounded-xl hover:bg-white/5 text-amber-300 font-bold transition-colors text-left flex items-center gap-2"
                >
                  <Smartphone className="w-4 h-4 text-[#F4B323]" />
                  <span>{isHi ? 'मोबाइल ऐप डाउनलोड' : 'Download Mobile App'}</span>
                </button>
                <button
                  type="button"
                  onClick={() => closeMobileMenuAndNavigate('/contact')}
                    className="w-full text-left px-3.5 py-2.5 hover:bg-white/10 active:bg-white/15 transition-colors cursor-pointer flex items-center justify-between group"
                  >
                    <div className="flex items-center gap-3">
                      <div className="w-7 h-7 rounded-lg bg-white/10 flex items-center justify-center text-[#F4B323] flex-shrink-0">
                        <Phone className="w-4 h-4" />
                      </div>
                      <div>
                        <div className="text-xs font-bold text-white group-hover:text-[#F4B323] transition-colors">{isHi ? 'कार्यालय एवं संपर्क' : 'Office & Contact'}</div>
                        <div className="text-[10px] text-slate-400">{isHi ? 'पता, हेल्पलाइन एवं समय' : 'Location, Timings & Helpline'}</div>
                      </div>
                    </div>
                    <ChevronRight className="w-4 h-4 text-slate-400 group-hover:text-[#F4B323] transition-transform group-hover:translate-x-0.5" />
                  </button>
                </div>
              </div>

              {/* Section 2: Dedicated Portal Logins List */}
              <div className="space-y-1.5">
                <div className="px-2 text-[11px] font-black tracking-wider uppercase text-slate-400 flex items-center justify-between">
                  <span>{isHi ? 'पोर्टल लॉगिन' : 'Direct Portals'}</span>
                  <span className="text-[10px] text-[#F4B323]">{isHi ? 'विद्यार्थी, शिक्षक व स्टाफ' : 'Student & Staff'}</span>
                </div>

                <div className="grid grid-cols-3 gap-2">
                  <button
                    type="button"
                    onClick={() => openPortalLogin('parent')}
                    className="py-2.5 px-2 rounded-xl bg-[#0c1f38] hover:bg-[#122c4d] border border-white/15 text-white text-center flex flex-col items-center justify-center gap-1 cursor-pointer transition-colors active:scale-95"
                  >
                    <div className="w-6 h-6 rounded-md bg-[#F4B323]/20 flex items-center justify-center text-[#F4B323]">
                      <Users className="w-3.5 h-3.5" />
                    </div>
                    <span className="text-[11px] font-bold">{isHi ? 'अभिभावक' : 'Parents'}</span>
                    <span className="text-[9px] text-slate-400 leading-tight">{isHi ? 'रिजल्ट / फीस' : 'Results'}</span>
                  </button>

                  <button
                    type="button"
                    onClick={() => openPortalLogin('teacher')}
                    className="py-2.5 px-2 rounded-xl bg-[#0c1f38] hover:bg-[#122c4d] border border-white/15 text-white text-center flex flex-col items-center justify-center gap-1 cursor-pointer transition-colors active:scale-95"
                  >
                    <div className="w-6 h-6 rounded-md bg-white/10 flex items-center justify-center text-[#F4B323]">
                      <GraduationCap className="w-3.5 h-3.5" />
                    </div>
                    <span className="text-[11px] font-bold">{isHi ? 'शिक्षक' : 'Teacher'}</span>
                    <span className="text-[9px] text-slate-400 leading-tight">{isHi ? 'हाजिरी व मार्क्स' : 'Marks'}</span>
                  </button>

                  <button
                    type="button"
                    onClick={() => openPortalLogin('principal')}
                    className="py-2.5 px-2 rounded-xl bg-[#0c1f38] hover:bg-[#122c4d] border border-white/15 text-white text-center flex flex-col items-center justify-center gap-1 cursor-pointer transition-colors active:scale-95"
                  >
                    <div className="w-6 h-6 rounded-md bg-white/10 flex items-center justify-center text-[#F4B323]">
                      <ShieldCheck className="w-3.5 h-3.5" />
                    </div>
                    <span className="text-[11px] font-bold">{isHi ? 'प्रधानाचार्य' : 'Principal'}</span>
                    <span className="text-[9px] text-slate-400 leading-tight">{isHi ? 'प्रशासन' : 'Admin'}</span>
                  </button>
                </div>
              </div>

              {/* Section 3: Contact & Help Strip */}
              <div className="pt-2 border-t border-white/10 flex items-center justify-between text-xs text-slate-300">
                <a
                  href={`tel:${primaryPhone}`}
                  className="flex items-center gap-1.5 py-1.5 px-2.5 rounded-lg bg-white/5 hover:bg-white/10 text-white font-bold transition-colors"
                >
                  <Phone className="w-3.5 h-3.5 text-[#F4B323]" />
                  <span>+91 {primaryPhone}</span>
                </a>
                <span className="text-[11px] text-slate-400 truncate">
                  {isHi ? 'मोरा-मैरी, सीवान' : 'Mora-Mairi, Siwan'}
                </span>
              </div>

            </div>
          </>
        )}
      </header>

      {/* ───────────────────────────────────────────────────────────── */}
      {/* 3. HERO SECTION FEATURING THE PANORAMIC INSTITUTIONAL BANNER  */}
      {/* ───────────────────────────────────────────────────────────── */}
      <main className="flex-1 w-full max-w-full overflow-x-hidden">
        {!isLoginModalOpen ? (
          activeRoute === '/about' ? (
            <AboutPageView
              isHi={isHi}
              schoolName={schoolName}
              schoolSubtitle={schoolSubtitle}
              schoolLocation={schoolLocation}
              primaryPhone={primaryPhone}
              navigate={navigate}
            />
          ) : activeRoute === '/admissions' ? (
            <AdmissionsPageView
              isHi={isHi}
              currentSession={currentSession}
              admissionClasses={admissionClasses}
              primaryPhone={primaryPhone}
              onOpenInquiry={() => setIsAdmissionInquiryOpen(true)}
            />
          ) : activeRoute === '/academics' ? (
            <AcademicsPageView isHi={isHi} />
          ) : activeRoute === '/gallery' ? (
            <GalleryPageView isHi={isHi} galleryItems={websiteGallery} />
          ) : activeRoute === '/contact' ? (
            <ContactPageView
              isHi={isHi}
              schoolLocation={schoolLocation}
              primaryPhone={primaryPhone}
              officialEmail={officialEmail}
            />
          ) : activeRoute === '/download' ? (
            <DownloadPageView
              isHi={isHi}
              schoolName={schoolName}
              primaryPhone={primaryPhone}
            />
          ) : (
            <div className="w-full max-w-full overflow-x-hidden space-y-12 sm:space-y-16 pb-10">

            {/* ── SECTION 1: FULL-WIDTH PANORAMIC HERO BANNER (Left to Right Full Width, Balanced Height) ── */}
            <section id="about" className="w-full max-w-full relative overflow-hidden bg-[#07162C] border-b-2 border-[#1E3A60] shadow-2xl scroll-mt-24">

              {/* Clean Campus Collage Background (No baked-in promotional text) */}
              <div
                className="absolute inset-0 bg-cover bg-center transition-transform duration-1000 scale-[1.01]"
                style={{ backgroundImage: "url('/school_campus_banner.jpg')" }}
                aria-hidden="true"
              />

              {/* Vibrant Campus Background Overlay — Brightened so the yellow building, palm trees, and playground are clearly visible */}
              <div
                className="absolute inset-0 bg-gradient-to-r from-[#07172E]/82 via-[#091D38]/65 to-[#061426]/50"
                aria-hidden="true"
              />
              <div
                className="absolute inset-0 bg-gradient-to-t from-[#07172E]/95 via-transparent to-black/25"
                aria-hidden="true"
              />
              <div
                className="absolute top-0 left-0 w-72 h-72 rounded-full bg-[#F4B323]/10 blur-2xl pointer-events-none"
                aria-hidden="true"
              />
              <div
                className="absolute bottom-0 right-0 w-72 h-72 rounded-full bg-blue-500/10 blur-2xl pointer-events-none"
                aria-hidden="true"
              />

              {/* Banner Content Container (Constrained width inside, spanning full width outside) */}
              <div className="relative z-10 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8 sm:py-12 lg:py-14 flex flex-col justify-between min-h-[460px] sm:min-h-[500px] lg:min-h-[530px]">

                {/* Top Strip: 4 Pillars Motto Badge + Academic Session Tag */}
                <div className="flex flex-wrap items-center justify-between gap-3 mb-6">
                  <div className="inline-flex items-center gap-2 px-3 sm:px-4 py-1.5 rounded-full bg-white/10 backdrop-blur-md border border-white/20 text-[10px] sm:text-xs font-bold text-white shadow-md max-w-full">
                    <Sparkles className="w-3.5 h-3.5 text-[#F4B323] flex-shrink-0" />
                    <span className="tracking-wide break-words text-center">
                      {isHi ? 'अनुशासन · ज्ञान · उत्कृष्टता · उज्ज्वल भविष्य' : 'DISCIPLINE · KNOWLEDGE · EXCELLENCE · BRIGHT FUTURE'}
                    </span>
                  </div>

                  <div className="inline-flex items-center gap-2 px-3.5 py-1.5 rounded-full bg-[#F4B323]/15 border border-[#F4B323]/30 backdrop-blur-md text-xs font-black text-[#F4B323] shadow-xs">
                    <Calendar className="w-3.5 h-3.5" />
                    <span>{isHi ? `सत्र ${currentSession}` : `SESSION ${currentSession}`}</span>
                  </div>
                </div>

                {/* Middle Hero Block: Logo + School Name + Tagline + Location */}
                <div className="flex flex-col md:flex-row items-center md:items-start gap-5 sm:gap-6 text-center md:text-left">

                  {/* Official School Crest Logo */}
                  <div className="relative flex-shrink-0 group">
                    <div className="w-20 h-20 sm:w-24 sm:h-24 lg:w-28 lg:h-28 flex items-center justify-center transition-transform group-hover:scale-105 drop-shadow-2xl">
                      <img
                        src={logoSrc}
                        alt="Mission Navodaya Public School Crest"
                        className="w-full h-full object-contain drop-shadow-xl"
                        onError={(e) => {
                          e.currentTarget.onerror = null;
                          e.currentTarget.src = '/logo.png';
                        }}
                      />
                    </div>
                    <div className="absolute -bottom-1 left-1/2 -translate-x-1/2 px-2.5 py-0.5 rounded-full bg-[#102747] border border-[#F4B323] text-[9px] font-black text-[#F4B323] uppercase shadow-lg whitespace-nowrap">
                      {isHi ? 'स्थापना 2025' : 'ESTD 2025'}
                    </div>
                  </div>

                  {/* School Typography & Tagline */}
                  <div className="space-y-2 flex-1">
                    <div className="inline-flex items-center gap-1.5 text-[11px] font-extrabold uppercase tracking-widest text-[#F4B323]">
                      <span>{isHi ? 'अंग्रेजी माध्यम • सह-शिक्षा' : 'English Medium • Co-Educational'}</span>
                    </div>

                    <h1 className="text-2xl sm:text-4xl lg:text-[46px] font-black text-white tracking-tight uppercase leading-[1.12] drop-shadow-md break-words max-w-full">
                      {isHi ? (
                        <>मिशन नवोदय <span className="text-[#F4B323]">पब्लिक स्कूल</span>, मोरा</>
                      ) : (
                        <>MISSION NAVODAYA <span className="text-[#F4B323]">PUBLIC SCHOOL</span>, MORA-MAIRI</>
                      )}
                    </h1>

                    <p className="text-xs sm:text-sm text-slate-300 font-medium italic max-w-2xl">
                      {isHi
                        ? '“उज्ज्वल भविष्य के लिए सुरक्षित और अनुशासित कैंपस।” — शैक्षणिक उत्कृष्टता, नैतिक चरित्र और डिजिटल नवाचार को समर्पित।'
                        : '“A Safe Campus for Brighter Futures.” — Dedicated to Academic Excellence, Moral Character, and Digital Innovation.'
                      }
                    </p>

                    {/* School Location & Timings Quick Micro-Badges */}
                    <div className="pt-1 flex flex-wrap items-center justify-center md:justify-start gap-2 sm:gap-3 text-xs text-slate-300 font-medium">
                      <span className="inline-flex items-center gap-1.5 px-3 py-1 rounded-lg bg-white/10 backdrop-blur-xs border border-white/15">
                        <MapPin className="w-3.5 h-3.5 text-[#F4B323]" />
                        <span>{isHi ? 'मोरा-मैरी, सीवान (बिहार)' : 'Mora-Mairi, Siwan (Bihar)'}</span>
                      </span>
                      <span className="inline-flex items-center gap-1.5 px-3 py-1 rounded-lg bg-white/10 backdrop-blur-xs border border-white/15">
                        <Clock className="w-3.5 h-3.5 text-emerald-400" />
                        <span>{isHi ? 'सोम – शनि: 8:00 पूर्वाह्न – 2:00 अपराह्न' : 'Mon – Sat: 8:00 AM – 2:00 PM'}</span>
                      </span>
                      <span className="inline-flex items-center gap-1.5 px-3 py-1 rounded-lg bg-white/10 backdrop-blur-xs border border-white/15">
                        <Phone className="w-3.5 h-3.5 text-blue-400" />
                        <span>+91 {primaryPhone}</span>
                      </span>
                    </div>
                  </div>
                </div>

                {/* ── DYNAMIC ADMISSION BANNER STUDIO (6 Live Interchangeable Styles via Admin App) ── */}
                {((websiteConfig?.admissionBanner?.isAdmissionOpen !== false) && isAdmissionOpen) && (() => {
                  const bConf = websiteConfig?.admissionBanner || {};
                  const bStyle = bConf.style || 'royal_navy';
                  const bSession = bConf.session || currentSession || '2026-27';
                  const bClasses = bConf.classes || admissionClasses || 'Nursery to 8th';
                  const bTag = isHi
                    ? (bConf.tagTextHi || bConf.tagText || 'विशेष छात्रवृत्ति एवं प्रारंभिक नामांकन छूट उपलब्ध')
                    : (bConf.tagTextEn || (!/[\u0900-\u097F]/.test(bConf.tagText || '') ? bConf.tagText : null) || 'Special Scholarship & Early Admission Offer Available');

                  const bHead = isHi
                    ? (bConf.headlineHi || bConf.headline || 'सत्र 2026-27 हेतु नवीन नामांकन प्रारंभ')
                    : (bConf.headlineEn || (!/[\u0900-\u097F]/.test(bConf.headline || '') ? bConf.headline : null) || `ADMISSIONS OPEN FOR SESSION ${bSession}`);

                  const bSub = isHi
                    ? (bConf.subheadlineHi || bConf.subheadline || `${bClasses} • सीवान एवं मोरा बाज़ार का अग्रणी सीबीएसई पैटर्न अंग्रेजी माध्यम विद्यालय`)
                    : (bConf.subheadlineEn || (!/[\u0900-\u097F]/.test(bConf.subheadline || '') ? bConf.subheadline : null) || `${bClasses} • Leading CBSE Pattern English Medium School in Siwan & Mora Bazar`);
                  const bPhone = bConf.phone || primaryPhone || '8603481865';
                  const bWhatsapp = bConf.whatsapp || primaryPhone || '8603481865';

                  // STYLE 1: ROYAL NAVY & GOLD (Classic Prestigious)
                  if (bStyle === 'royal_navy') {
                    return (
                      <div id="admissions" className="mt-6 p-4 sm:p-5 rounded-2xl bg-gradient-to-r from-[#0C223F]/95 via-[#112F56]/90 to-[#0C223F]/95 border-2 border-[#F4B323]/50 backdrop-blur-md shadow-2xl flex flex-col lg:flex-row items-center justify-between gap-4 scroll-mt-24">
                        <div className="flex flex-col sm:flex-row items-center sm:items-start gap-3.5 text-center sm:text-left">
                          <div className="w-12 h-12 rounded-xl bg-gradient-to-br from-[#F4B323] to-[#E09B10] text-[#091A32] flex items-center justify-center flex-shrink-0 shadow-lg">
                            <GraduationCap className="w-6 h-6 text-[#091A32]" />
                          </div>
                          <div className="space-y-0.5">
                            <div className="flex flex-wrap items-center justify-center sm:justify-start gap-2">
                              <span className="text-lg sm:text-xl lg:text-2xl font-black text-white tracking-tight uppercase flex items-center gap-2">
                                <span className="relative flex h-3 w-3">
                                  <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-[#F4B323] opacity-75"></span>
                                  <span className="relative inline-flex rounded-full h-3 w-3 bg-[#F4B323]"></span>
                                </span>
                                {bHead}
                              </span>
                              <span className="text-xs font-black px-2.5 py-0.5 rounded-md bg-[#F4B323] text-[#091A32] tracking-wider uppercase shadow-xs">
                                {isHi ? `सत्र ${bSession}` : `SESSION ${bSession}`}
                              </span>
                            </div>
                            <div className="text-xs text-[#F4B323] font-bold">{bSub}</div>
                            {bTag && <div className="text-[11px] text-slate-300 font-medium">✨ {bTag}</div>}
                          </div>
                        </div>
                        <div className="flex flex-wrap items-center justify-center gap-3 w-full lg:w-auto flex-shrink-0">
                          <button
                            type="button"
                            onClick={() => {
                              if (setSignUpFormTab) setSignUpFormTab('student');
                              navigate('/signup?tab=admission');
                            }}
                            className="flex-1 sm:flex-initial px-6 py-3.5 rounded-xl bg-[#F4B323] hover:bg-[#e0a21a] text-[#091A32] font-black text-xs sm:text-sm shadow-xl hover:shadow-2xl transition-all flex items-center justify-center gap-2 cursor-pointer hover:scale-105 active:scale-95"
                          >
                            <Sparkles className="w-4 h-4 text-[#091A32]" />
                            <span>{isHi ? 'ऑनलाइन एडमिशन फॉर्म →' : 'Online Admission Form →'}</span>
                          </button>
                          <button
                            type="button"
                            onClick={() => openPortalLogin('parent')}
                            className="flex-1 sm:flex-initial px-5 py-3.5 rounded-xl bg-white/10 hover:bg-white/20 text-white font-bold text-xs sm:text-sm border border-white/25 backdrop-blur-sm transition-all flex items-center justify-center gap-2 cursor-pointer"
                          >
                            <ShieldCheck className="w-4 h-4 text-[#F4B323]" />
                            <span>{isHi ? 'पोर्टल लॉगिन' : 'Portal Login'}</span>
                          </button>
                        </div>
                      </div>
                    );
                  }

                  // STYLE 2: FESTIVE & NEW SESSION CELEBRATION
                  if (bStyle === 'festive') {
                    return (
                      <div id="admissions" className="mt-6 p-4 sm:p-5 rounded-2xl bg-gradient-to-r from-[#1e1b4b] via-[#312e81] to-[#4338ca] border-2 border-amber-400/60 shadow-[0_0_30px_rgba(245,158,11,0.25)] flex flex-col lg:flex-row items-center justify-between gap-4 scroll-mt-24">
                        <div className="flex flex-col sm:flex-row items-center sm:items-start gap-3.5 text-center sm:text-left">
                          <div className="w-12 h-12 rounded-xl bg-gradient-to-br from-amber-400 to-orange-500 text-slate-950 flex items-center justify-center flex-shrink-0 shadow-lg">
                            <Sparkles className="w-6 h-6 text-slate-950 animate-spin" style={{ animationDuration: '6s' }} />
                          </div>
                          <div className="space-y-0.5">
                            <div className="flex flex-wrap items-center justify-center sm:justify-start gap-2">
                              <span className="text-lg sm:text-xl lg:text-2xl font-black text-white tracking-tight uppercase flex items-center gap-2">
                                <span>🎉</span>
                                {bHead}
                              </span>
                              <span className="text-xs font-black px-2.5 py-0.5 rounded-full bg-gradient-to-r from-amber-400 to-yellow-300 text-slate-950 tracking-wider uppercase font-black shadow-md">
                                {isHi ? `उत्सव सत्र ${bSession}` : `CELEBRATION ${bSession}`}
                              </span>
                            </div>
                            <div className="text-xs text-amber-300 font-bold">{bSub}</div>
                            {bTag && <div className="text-[11px] text-emerald-300 font-bold">🎁 {bTag}</div>}
                          </div>
                        </div>
                        <div className="flex flex-wrap items-center justify-center gap-3 w-full lg:w-auto flex-shrink-0">
                          <button
                            type="button"
                            onClick={() => {
                              if (setSignUpFormTab) setSignUpFormTab('student');
                              navigate('/signup?tab=admission');
                            }}
                            className="flex-1 sm:flex-initial px-6 py-3.5 rounded-xl bg-gradient-to-r from-amber-400 to-orange-400 hover:from-amber-300 hover:to-orange-300 text-slate-950 font-black text-xs sm:text-sm shadow-xl transition-all flex items-center justify-center gap-2 cursor-pointer hover:scale-105 active:scale-95"
                          >
                            <Award className="w-4 h-4 text-slate-950" />
                            <span>{isHi ? 'दाखिला फॉर्म भरें (उत्सव छूट) →' : 'Apply Now with Fest Offer →'}</span>
                          </button>
                        </div>
                      </div>
                    );
                  }

                  // STYLE 3: ACADEMIC EXCELLENCE & NAVODAYA PREP
                  if (bStyle === 'academic') {
                    return (
                      <div id="admissions" className="mt-6 p-4 sm:p-5 rounded-2xl bg-gradient-to-r from-[#082f49] via-[#0369a1] to-[#075985] border-2 border-sky-400/50 shadow-2xl flex flex-col lg:flex-row items-center justify-between gap-4 scroll-mt-24">
                        <div className="flex flex-col sm:flex-row items-center sm:items-start gap-3.5 text-center sm:text-left">
                          <div className="w-12 h-12 rounded-xl bg-gradient-to-br from-sky-300 to-blue-500 text-slate-950 flex items-center justify-center flex-shrink-0 shadow-lg">
                            <Trophy className="w-6 h-6 text-slate-950" />
                          </div>
                          <div className="space-y-0.5">
                            <div className="flex flex-wrap items-center justify-center sm:justify-start gap-2">
                              <span className="text-lg sm:text-xl lg:text-2xl font-black text-white tracking-tight uppercase flex items-center gap-2">
                                <span>🏆</span>
                                {bHead}
                              </span>
                              <span className="text-xs font-black px-2.5 py-0.5 rounded-md bg-sky-300 text-sky-950 tracking-wider uppercase shadow-xs">
                                {isHi ? `नवोदय बैच ${bSession}` : `NAVODAYA SCHOLARS ${bSession}`}
                              </span>
                            </div>
                            <div className="text-xs text-sky-200 font-bold">{bSub}</div>
                            {bTag && <div className="text-[11px] text-amber-300 font-bold">⭐ {bTag}</div>}
                          </div>
                        </div>
                        <div className="flex flex-wrap items-center justify-center gap-3 w-full lg:w-auto flex-shrink-0">
                          <button
                            type="button"
                            onClick={() => {
                              if (setSignUpFormTab) setSignUpFormTab('student');
                              navigate('/signup?tab=admission');
                            }}
                            className="flex-1 sm:flex-initial px-6 py-3.5 rounded-xl bg-white hover:bg-sky-50 text-[#0369a1] font-black text-xs sm:text-sm shadow-xl transition-all flex items-center justify-center gap-2 cursor-pointer hover:scale-105 active:scale-95"
                          >
                            <BookOpen className="w-4 h-4 text-[#0369a1]" />
                            <span>{isHi ? 'नवोदय बैच नामांकन फॉर्म →' : 'Enroll in Navodaya Batch →'}</span>
                          </button>
                        </div>
                      </div>
                    );
                  }

                  // STYLE 4: SPORTS & HOLISTIC DEVELOPMENT
                  if (bStyle === 'sports') {
                    return (
                      <div id="admissions" className="mt-6 p-4 sm:p-5 rounded-2xl bg-gradient-to-r from-[#064e3b] via-[#047857] to-[#065f46] border-2 border-emerald-400/60 shadow-2xl flex flex-col lg:flex-row items-center justify-between gap-4 scroll-mt-24">
                        <div className="flex flex-col sm:flex-row items-center sm:items-start gap-3.5 text-center sm:text-left">
                          <div className="w-12 h-12 rounded-xl bg-gradient-to-br from-emerald-300 to-green-500 text-slate-950 flex items-center justify-center flex-shrink-0 shadow-lg">
                            <Activity className="w-6 h-6 text-slate-950" />
                          </div>
                          <div className="space-y-0.5">
                            <div className="flex flex-wrap items-center justify-center sm:justify-start gap-2">
                              <span className="text-lg sm:text-xl lg:text-2xl font-black text-white tracking-tight uppercase flex items-center gap-2">
                                <span>⚽</span>
                                {bHead}
                              </span>
                              <span className="text-xs font-black px-2.5 py-0.5 rounded-md bg-emerald-300 text-emerald-950 tracking-wider uppercase shadow-xs">
                                {isHi ? `सत्र ${bSession}` : `SESSION ${bSession}`}
                              </span>
                            </div>
                            <div className="text-xs text-emerald-200 font-bold">{bSub}</div>
                            {bTag && <div className="text-[11px] text-yellow-300 font-bold">🥇 {bTag}</div>}
                          </div>
                        </div>
                        <div className="flex flex-wrap items-center justify-center gap-3 w-full lg:w-auto flex-shrink-0">
                          <button
                            type="button"
                            onClick={() => {
                              if (setSignUpFormTab) setSignUpFormTab('student');
                              navigate('/signup?tab=admission');
                            }}
                            className="flex-1 sm:flex-initial px-6 py-3.5 rounded-xl bg-gradient-to-r from-emerald-400 to-teal-400 hover:from-emerald-300 hover:to-teal-300 text-slate-950 font-black text-xs sm:text-sm shadow-xl transition-all flex items-center justify-center gap-2 cursor-pointer hover:scale-105 active:scale-95"
                          >
                            <Trophy className="w-4 h-4 text-slate-950" />
                            <span>{isHi ? 'प्रवेश फॉर्म भरें (खेल व शिक्षा) →' : 'Apply for Admission →'}</span>
                          </button>
                        </div>
                      </div>
                    );
                  }

                  // STYLE 5: HIGH URGENCY / LIMITED SEATS ALERT
                  if (bStyle === 'limited_seats') {
                    return (
                      <div id="admissions" className="mt-6 p-4 sm:p-5 rounded-2xl bg-gradient-to-r from-[#450a0a] via-[#7f1d1d] to-[#991b1b] border-2 border-red-400/70 shadow-[0_0_25px_rgba(239,68,68,0.35)] flex flex-col lg:flex-row items-center justify-between gap-4 scroll-mt-24 animate-pulse" style={{ animationDuration: '3s' }}>
                        <div className="flex flex-col sm:flex-row items-center sm:items-start gap-3.5 text-center sm:text-left">
                          <div className="w-12 h-12 rounded-xl bg-gradient-to-br from-red-500 to-amber-500 text-white flex items-center justify-center flex-shrink-0 shadow-lg">
                            <AlertCircle className="w-6 h-6 text-white" />
                          </div>
                          <div className="space-y-0.5">
                            <div className="flex flex-wrap items-center justify-center sm:justify-start gap-2">
                              <span className="text-lg sm:text-xl lg:text-2xl font-black text-white tracking-tight uppercase flex items-center gap-2">
                                <span className="animate-ping text-red-400">⚠️</span>
                                {bHead}
                              </span>
                              <span className="text-xs font-black px-2.5 py-0.5 rounded-full bg-red-500 text-white tracking-wider uppercase font-black shadow-md border border-white/20">
                                {isHi ? 'सीमित सीटें शेष' : 'LIMITED SEATS LEFT'}
                              </span>
                            </div>
                            <div className="text-xs text-red-200 font-bold">{bSub}</div>
                            {bTag && <div className="text-[11px] text-amber-300 font-bold">⚡ {bTag}</div>}
                          </div>
                        </div>
                        <div className="flex flex-wrap items-center justify-center gap-3 w-full lg:w-auto flex-shrink-0">
                          <button
                            type="button"
                            onClick={() => {
                              if (setSignUpFormTab) setSignUpFormTab('student');
                              navigate('/signup?tab=admission');
                            }}
                            className="flex-1 sm:flex-initial px-6 py-3.5 rounded-xl bg-gradient-to-r from-amber-400 to-yellow-400 hover:from-amber-300 hover:to-yellow-300 text-slate-950 font-black text-xs sm:text-sm shadow-xl transition-all flex items-center justify-center gap-2 cursor-pointer hover:scale-105 active:scale-95"
                          >
                            <Sparkles className="w-4 h-4 text-slate-950" />
                            <span>{isHi ? 'अपनी सीट तुरंत आरक्षित करें →' : 'Reserve Seat Immediately →'}</span>
                          </button>
                        </div>
                      </div>
                    );
                  }

                  // STYLE 6: MODERN FROSTED SLATE & MINIMALIST
                  return (
                    <div id="admissions" className="mt-6 p-4 sm:p-5 rounded-2xl bg-slate-900/90 border-2 border-slate-700/80 backdrop-blur-xl shadow-2xl flex flex-col lg:flex-row items-center justify-between gap-4 scroll-mt-24">
                      <div className="flex flex-col sm:flex-row items-center sm:items-start gap-3.5 text-center sm:text-left">
                        <div className="w-12 h-12 rounded-xl bg-slate-800 border border-slate-700 text-cyan-400 flex items-center justify-center flex-shrink-0 shadow-lg">
                          <Compass className="w-6 h-6 text-cyan-400" />
                        </div>
                        <div className="space-y-0.5">
                          <div className="flex flex-wrap items-center justify-center sm:justify-start gap-2">
                            <span className="text-lg sm:text-xl lg:text-2xl font-black text-white tracking-tight uppercase flex items-center gap-2">
                              {bHead}
                            </span>
                            <span className="text-xs font-black px-2.5 py-0.5 rounded-md bg-cyan-500/20 text-cyan-300 border border-cyan-500/30 tracking-wider uppercase">
                              {isHi ? `सत्र ${bSession}` : `SESSION ${bSession}`}
                            </span>
                          </div>
                          <div className="text-xs text-slate-300 font-semibold">{bSub}</div>
                          {bTag && <div className="text-[11px] text-cyan-400 font-medium">✨ {bTag}</div>}
                        </div>
                      </div>
                      <div className="flex flex-wrap items-center justify-center gap-3 w-full lg:w-auto flex-shrink-0">
                        <button
                          type="button"
                          onClick={() => {
                            if (setSignUpFormTab) setSignUpFormTab('student');
                            navigate('/signup?tab=admission');
                          }}
                          className="flex-1 sm:flex-initial px-6 py-3.5 rounded-xl bg-white hover:bg-slate-100 text-slate-950 font-black text-xs sm:text-sm shadow-xl transition-all flex items-center justify-center gap-2 cursor-pointer hover:scale-105 active:scale-95"
                        >
                          <ArrowRight className="w-4 h-4 text-slate-950" />
                          <span>{isHi ? 'ऑनलाइन एडमिशन फॉर्म' : 'Online Admission Form'}</span>
                        </button>
                        <a
                          href={`https://wa.me/91${bWhatsapp}?text=Namaste%2C%20I%20want%20to%20know%20about%20Admissions%20in%20MNP%20School`}
                          target="_blank"
                          rel="noreferrer"
                          className="flex-1 sm:flex-initial px-5 py-3.5 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white font-bold text-xs sm:text-sm shadow-md transition-all flex items-center justify-center gap-2 cursor-pointer"
                        >
                          <MessageSquare className="w-4 h-4 text-white" />
                          <span>WhatsApp</span>
                        </a>
                      </div>
                    </div>
                  );
                })()}

                {/* 4 Pillars Badges from Banner */}
                <div className="mt-6 pt-4 border-t border-white/10 flex flex-wrap items-center justify-center md:justify-start gap-2 sm:gap-3">
                  <div className="inline-flex items-center gap-1.5 px-3.5 py-1.5 rounded-xl bg-white/10 backdrop-blur-xs border border-white/15 text-xs font-bold text-white shadow-xs">
                    <BookOpen className="w-3.5 h-3.5 text-[#F4B323]" />
                    <span>{isHi ? 'गुणवत्तापूर्ण शिक्षा' : 'Quality Education'}</span>
                  </div>
                  <div className="inline-flex items-center gap-1.5 px-3.5 py-1.5 rounded-xl bg-white/10 backdrop-blur-xs border border-white/15 text-xs font-bold text-white shadow-xs">
                    <Shield className="w-3.5 h-3.5 text-blue-400" />
                    <span>{isHi ? 'नैतिक मूल्य व संस्कार' : 'Moral Values'}</span>
                  </div>
                  <div className="inline-flex items-center gap-1.5 px-3.5 py-1.5 rounded-xl bg-white/10 backdrop-blur-xs border border-white/15 text-xs font-bold text-white shadow-xs">
                    <TrendingUp className="w-3.5 h-3.5 text-emerald-400" />
                    <span>{isHi ? 'सर्वांगीण विकास' : 'Holistic Development'}</span>
                  </div>
                  <div className="inline-flex items-center gap-1.5 px-3.5 py-1.5 rounded-xl bg-white/10 backdrop-blur-xs border border-white/15 text-xs font-bold text-white shadow-xs">
                    <Trophy className="w-3.5 h-3.5 text-[#F4B323]" />
                    <span>{isHi ? 'उज्ज्वल कल' : 'Better Tomorrow'}</span>
                  </div>
                </div>

              </div>
            </section>

            {/* ── SECTION 2: INSTITUTIONAL TRUST & KEY METRICS (220+ Active Students, Nursery-8th, 100% Care) ── */}
            <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 -mt-6 sm:-mt-8 relative z-20">
              <div className="bg-white rounded-2xl sm:rounded-3xl p-4 sm:p-6 border border-slate-200/90 shadow-xl shadow-slate-900/5 grid grid-cols-2 lg:grid-cols-4 gap-4 sm:gap-6 divide-y sm:divide-y-0 sm:divide-x divide-slate-100">

                {/* Metric 1: 220+ Students */}
                <div className="flex items-center gap-3.5 sm:gap-4 p-2 sm:p-3">
                  <div className="w-12 h-12 rounded-2xl bg-amber-500/10 border border-amber-500/20 text-[#0c2340] flex items-center justify-center flex-shrink-0 shadow-xs">
                    <GraduationCap className="w-6 h-6 text-[#F4B323]" />
                  </div>
                  <div>
                    <div className="text-xl sm:text-2xl lg:text-3xl font-black text-[#0c2340] tracking-tight">220+</div>
                    <div className="text-[11px] sm:text-xs font-bold text-slate-500 uppercase tracking-wide">
                      {isHi ? 'नामांकित विद्यार्थी' : 'Active Students'}
                    </div>
                  </div>
                </div>

                {/* Metric 2: Nursery to 8th */}
                <div className="flex items-center gap-3.5 sm:gap-4 p-2 sm:p-3 pt-3 sm:pt-3">
                  <div className="w-12 h-12 rounded-2xl bg-blue-500/10 border border-blue-500/20 text-[#0c2340] flex items-center justify-center flex-shrink-0 shadow-xs">
                    <BookOpen className="w-6 h-6 text-blue-600" />
                  </div>
                  <div>
                    <div className="text-xl sm:text-2xl lg:text-3xl font-black text-[#0c2340] tracking-tight">Nursery – 8th</div>
                    <div className="text-[11px] sm:text-xs font-bold text-slate-500 uppercase tracking-wide">
                      {isHi ? 'अंग्रेजी माध्यम कक्षाएं' : 'Co-Ed Classes'}
                    </div>
                  </div>
                </div>

                {/* Metric 3: 100% Care & Guidance */}
                <div className="flex items-center gap-3.5 sm:gap-4 p-2 sm:p-3 pt-3 sm:pt-3">
                  <div className="w-12 h-12 rounded-2xl bg-emerald-500/10 border border-emerald-500/20 text-[#0c2340] flex items-center justify-center flex-shrink-0 shadow-xs">
                    <Award className="w-6 h-6 text-emerald-600" />
                  </div>
                  <div>
                    <div className="text-xl sm:text-2xl lg:text-3xl font-black text-[#0c2340] tracking-tight">100%</div>
                    <div className="text-[11px] sm:text-xs font-bold text-slate-500 uppercase tracking-wide">
                      {isHi ? 'व्यक्तिगत मार्गदर्शन' : 'Individual Care'}
                    </div>
                  </div>
                </div>

                {/* Metric 4: Safe Disciplined Campus */}
                <div className="flex items-center gap-3.5 sm:gap-4 p-2 sm:p-3 pt-3 sm:pt-3">
                  <div className="w-12 h-12 rounded-2xl bg-indigo-500/10 border border-indigo-500/20 text-[#0c2340] flex items-center justify-center flex-shrink-0 shadow-xs">
                    <ShieldCheck className="w-6 h-6 text-indigo-600" />
                  </div>
                  <div>
                    <div className="text-xl sm:text-2xl lg:text-3xl font-black text-[#0c2340] tracking-tight">Smart Campus</div>
                    <div className="text-[11px] sm:text-xs font-bold text-slate-500 uppercase tracking-wide">
                      {isHi ? 'CCTV व सुरक्षित परिसर' : 'Safe & Disciplined'}
                    </div>
                  </div>
                </div>

              </div>
            </div>

            {/* ── SECTION 3: 5 SIGNATURE CAMPUS FEATURES (From Banner Cards) ── */}
            <section id="features" className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 scroll-mt-28">
              <div className="text-center space-y-2 mb-8 sm:mb-10">
                <span className="text-[11px] font-black uppercase tracking-widest text-[#102747] bg-[#102747]/8 px-3.5 py-1 rounded-full border border-[#102747]/15">
                  {isHi ? 'कैंपस विशेषताएं' : 'CAMPUS EXCELLENCE'}
                </span>
                <h2 className="text-2xl sm:text-3xl font-black text-[#14243B] tracking-tight">
                  {isHi ? 'मिशन नवोदय पब्लिक स्कूल के 5 मुख्य आधार' : '5 Pillars of Mission Navodaya Public School'}
                </h2>
                <p className="text-xs sm:text-sm text-[#65748B] max-w-xl mx-auto">
                  {isHi
                    ? 'नर्सरी से कक्षा 8वीं तक के विद्यार्थियों के लिए सुरक्षित, अनुशासित और सर्वांगीण शिक्षा।'
                    : 'Designed for safe, disciplined, and comprehensive schooling for students from Nursery to Grade 8.'}
                </p>
              </div>

              {/* 5 Cards Row matching the Banner Ribbon */}
              <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-5 gap-4 sm:gap-5">

                {/* 1. Enriched Library */}
                <div className="bg-white rounded-2xl p-5 border border-slate-200/80 shadow-xs hover:shadow-xl hover:-translate-y-1.5 hover:border-[#F4B323]/40 transition-all duration-300 space-y-3 group relative overflow-hidden">
                  <div className="w-12 h-12 rounded-xl bg-amber-500/10 text-amber-700 flex items-center justify-center font-bold group-hover:scale-110 transition-transform shadow-2xs">
                    <BookOpen className="w-6 h-6 text-[#F4B323]" />
                  </div>
                  <div>
                    <h3 className="text-sm font-black text-[#14243B] group-hover:text-[#102747] transition-colors">{isHi ? 'समृद्ध पुस्तकालय' : 'Enriched Library'}</h3>
                    <p className="text-xs text-[#65748B] mt-1 leading-relaxed">
                      {isHi
                        ? 'ज्ञानवर्धक पुस्तकों, NCERT पाठ्यपुस्तकों और प्रेरक पठन सामग्रियों का विशाल संग्रह।'
                        : 'Wide range of books, NCERT textbooks, and inspiring learning resources.'}
                    </p>
                  </div>
                </div>

                {/* 2. Computer & Tech Wing */}
                <div className="bg-white rounded-2xl p-5 border border-slate-200/80 shadow-xs hover:shadow-xl hover:-translate-y-1.5 hover:border-blue-400/40 transition-all duration-300 space-y-3 group relative overflow-hidden">
                  <div className="w-12 h-12 rounded-xl bg-blue-500/10 text-blue-700 flex items-center justify-center font-bold group-hover:scale-110 transition-transform shadow-2xs">
                    <Monitor className="w-6 h-6 text-blue-600" />
                  </div>
                  <div>
                    <h3 className="text-sm font-black text-[#14243B] group-hover:text-blue-700 transition-colors">{isHi ? 'कंप्यूटर व तकनीक विंग' : 'Computer & Tech Wing'}</h3>
                    <p className="text-xs text-[#65748B] mt-1 leading-relaxed">
                      {isHi
                        ? 'आधुनिक डिजिटल शिक्षा, सुसज्जित कंप्यूटर लैब और प्रायोगिक तकनीकी कौशल।'
                        : 'Modern digital learning, dedicated computer lab, and practical tech skills.'}
                    </p>
                  </div>
                </div>

                {/* 3. Sports & Physical Fitness */}
                <div className="bg-white rounded-2xl p-5 border border-slate-200/80 shadow-xs hover:shadow-xl hover:-translate-y-1.5 hover:border-emerald-400/40 transition-all duration-300 space-y-3 group relative overflow-hidden">
                  <div className="w-12 h-12 rounded-xl bg-emerald-500/10 text-emerald-700 flex items-center justify-center font-bold group-hover:scale-110 transition-transform shadow-2xs">
                    <Trophy className="w-6 h-6 text-emerald-600" />
                  </div>
                  <div>
                    <h3 className="text-sm font-black text-[#14243B] group-hover:text-emerald-700 transition-colors">{isHi ? 'खेलकूद एवं शारीरिक विकास' : 'Sports & Physical Fitness'}</h3>
                    <p className="text-xs text-[#65748B] mt-1 leading-relaxed">
                      {isHi
                        ? 'फुटबॉल, एथलेटिक्स और शारीरिक तंदुरुस्ती के लिए विशाल खुला खेल का मैदान।'
                        : 'Spacious open playground for football, athletics, and overall development.'}
                    </p>
                  </div>
                </div>

                {/* 4. Safe & Secure Campus */}
                <div className="bg-white rounded-2xl p-5 border border-slate-200/80 shadow-xs hover:shadow-xl hover:-translate-y-1.5 hover:border-indigo-400/40 transition-all duration-300 space-y-3 group relative overflow-hidden">
                  <div className="w-12 h-12 rounded-xl bg-indigo-500/10 text-indigo-700 flex items-center justify-center font-bold group-hover:scale-110 transition-transform shadow-2xs">
                    <ShieldCheck className="w-6 h-6 text-indigo-600" />
                  </div>
                  <div>
                    <h3 className="text-sm font-black text-[#14243B] group-hover:text-indigo-700 transition-colors">{isHi ? 'सुरक्षित एवं अनुशासित परिसर' : 'Safe & Secure Campus'}</h3>
                    <p className="text-xs text-[#65748B] mt-1 leading-relaxed">
                      {isHi
                        ? 'चारदीवारी से सुरक्षित, अनुशासित और स्नेहमयी वातावरण जिससे बच्चे सुरक्षित रहें।'
                        : 'A disciplined, walled, and caring environment ensuring student safety.'}
                    </p>
                  </div>
                </div>

                {/* 5. Dedicated Teachers */}
                <div className="bg-white rounded-2xl p-5 border border-slate-200/80 shadow-xs hover:shadow-xl hover:-translate-y-1.5 hover:border-purple-400/40 transition-all duration-300 space-y-3 group relative overflow-hidden">
                  <div className="w-12 h-12 rounded-xl bg-purple-500/10 text-purple-700 flex items-center justify-center font-bold group-hover:scale-110 transition-transform shadow-2xs">
                    <Users className="w-6 h-6 text-purple-600" />
                  </div>
                  <div>
                    <h3 className="text-sm font-black text-[#14243B] group-hover:text-purple-700 transition-colors">{isHi ? 'समर्पित एवं अनुभवी शिक्षक' : 'Dedicated Teachers'}</h3>
                    <p className="text-xs text-[#65748B] mt-1 leading-relaxed">
                      {isHi
                        ? 'प्रत्येक बच्चे के सर्वांगीण विकास के लिए समर्पित, अनुभवी और स्नेही शिक्षक गण।'
                        : 'Experienced, caring, and supportive faculty devoted to each child.'}
                    </p>
                  </div>
                </div>

              </div>
            </section>

            {/* ── SECTION 4: SCHOOL LEADERSHIP ── */}
            <section id="leadership" className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 scroll-mt-28">
              <div className="text-center space-y-2 mb-8 sm:mb-12">
                <span className="text-[11px] font-black uppercase tracking-widest text-[#102747] bg-[#102747]/8 px-3.5 py-1 rounded-full border border-[#102747]/15">
                  {isHi ? 'मार्गदर्शन एवं नेतृत्व' : 'LEADERSHIP & VISION'}
                </span>
                <h2 className="text-2xl sm:text-3xl font-black text-[#14243B] tracking-tight">
                  {isHi ? 'अनुभव, सत्यनिष्ठा और समर्पण द्वारा निर्देशित' : 'Guided by Experience, Integrity & Dedication'}
                </h2>
                <p className="text-xs sm:text-sm text-[#65748B] max-w-xl mx-auto">
                  {isHi
                    ? 'मिशन नवोदय पब्लिक स्कूल को शैक्षणिक उत्कृष्टता और संस्कारयुक्त शिक्षा की ओर ले जाने वाली नेतृत्व टीम।'
                    : 'Meet the leadership team steering Mission Navodaya Public School toward academic excellence and values-driven education.'}
                </p>
              </div>

              <div className="grid grid-cols-1 md:grid-cols-3 gap-6 sm:gap-8">
                {/* 1. Chairman: Uday Shankar Patel */}
                <div className="bg-white rounded-3xl overflow-hidden border border-[#E2E8F0] shadow-xs hover:shadow-xl transition-all duration-300 flex flex-col justify-between group">
                  <div>
                    <div className="relative h-72 sm:h-80 w-full overflow-hidden bg-slate-100">
                      <img
                        src="/chairman_uday_shankar_patel.jpg"
                        alt="Uday Shankar Patel — Chairman, Mission Navodaya Public School"
                        className="w-full h-full object-cover object-top transition-transform duration-500 group-hover:scale-105"
                      />
                      <div className="absolute top-3.5 left-3.5 px-3 py-1 rounded-full bg-[#F4B323] text-[#091A32] font-black text-[10px] tracking-wider uppercase shadow-md flex items-center gap-1.5">
                        <Award className="w-3.5 h-3.5 text-[#091A32]" />
                        <span>{isHi ? 'संस्थापक एवं अध्यक्ष' : 'CHAIRMAN & FOUNDER'}</span>
                      </div>
                      <div className="absolute inset-0 bg-gradient-to-t from-black/75 via-transparent to-transparent" />
                      <div className="absolute bottom-3.5 left-4 right-4 text-white">
                        <h3 className="text-lg font-black tracking-tight drop-shadow">{isHi ? 'उदय शंकर पटेल' : 'Uday Shankar Patel'}</h3>
                        <p className="text-[11px] text-[#F4B323] font-bold uppercase tracking-wider">{isHi ? 'संस्थापक एवं अध्यक्ष' : 'Chairman & Founder'}</p>
                      </div>
                    </div>
                    <div className="p-6 space-y-3">
                      <p className="text-xs text-[#65748B] leading-relaxed italic">
                        {isHi
                          ? '“शिक्षा केवल डिग्रियां हासिल करना नहीं है; यह नैतिक चरित्र, अनुशासन और एक मजबूत नींव का निर्माण है जो प्रत्येक बच्चे को गर्व से समाज की सेवा करने में सक्षम बनाती है।”'
                          : '“Education is not merely acquiring degrees; it is about cultivating moral character, discipline, and building a foundation that empowers every child to serve society with pride.”'}
                      </p>
                    </div>
                  </div>
                  <div className="px-6 py-4 bg-slate-50 border-t border-[#E2E8F0] flex items-center gap-2 text-xs font-bold text-[#102747]">
                    <Building className="w-4 h-4 text-[#F4B323]" />
                    <span>{isHi ? "अध्यक्षीय सचिवालय · संस्थापक डेस्क" : "Chairman's Secretariat · Founder's Desk"}</span>
                  </div>
                </div>

                {/* 2. Managing Director: Vishal Patel */}
                <div className="bg-white rounded-3xl overflow-hidden border border-[#E2E8F0] shadow-xs hover:shadow-xl transition-all duration-300 flex flex-col justify-between group">
                  <div>
                    <div className="relative h-72 sm:h-80 w-full overflow-hidden bg-slate-100">
                      <img
                        src="/director_vishal_patel.jpg"
                        alt="Vishal Patel — Managing Director, Mission Navodaya Public School"
                        className="w-full h-full object-cover object-top transition-transform duration-500 group-hover:scale-105"
                      />
                      <div className="absolute top-3.5 left-3.5 px-3 py-1 rounded-full bg-[#102747] text-white font-black text-[10px] tracking-wider uppercase shadow-md flex items-center gap-1.5 border border-white/20">
                        <Shield className="w-3.5 h-3.5 text-[#F4B323]" />
                        <span>{isHi ? 'प्रबंध निदेशक' : 'MANAGING DIRECTOR'}</span>
                      </div>
                      <div className="absolute inset-0 bg-gradient-to-t from-black/75 via-transparent to-transparent" />
                      <div className="absolute bottom-3.5 left-4 right-4 text-white">
                        <h3 className="text-lg font-black tracking-tight drop-shadow">{isHi ? 'विशाल पटेल' : 'Vishal Patel'}</h3>
                        <p className="text-[11px] text-blue-200 font-bold uppercase tracking-wider">{isHi ? 'प्रबंध निदेशक' : 'Managing Director'}</p>
                      </div>
                    </div>
                    <div className="p-6 space-y-3">
                      <p className="text-xs text-[#65748B] leading-relaxed italic">
                        {isHi
                          ? '“हम आधुनिक शैक्षणिक बुनियादी ढांचे को मजबूत मानवीय मूल्यों के साथ जोड़ते हैं, जिससे हमारे छात्र पढ़ाई, तकनीक और जीवन कौशल में अव्वल रहें।”'
                          : '“We combine modern educational infrastructure with deep-rooted values, ensuring that our students excel in academics, technology, and life skills.”'}
                      </p>
                    </div>
                  </div>
                  <div className="px-6 py-4 bg-slate-50 border-t border-[#E2E8F0] flex items-center gap-2 text-xs font-bold text-[#102747]">
                    <Shield className="w-4 h-4 text-[#102747]" />
                    <span>{isHi ? 'कार्यकारी संचालन एवं प्रबंधन' : 'Executive Operations & Administration'}</span>
                  </div>
                </div>

                {/* 3. Principal: Soni Madam */}
                <div className="bg-white rounded-3xl overflow-hidden border border-[#E2E8F0] shadow-xs hover:shadow-xl transition-all duration-300 flex flex-col justify-between group">
                  <div>
                    <div className="relative h-72 sm:h-80 w-full overflow-hidden bg-slate-100">
                      <img
                        src="/principal_soni_madam.jpg"
                        alt="Soni Madam — Principal, Mission Navodaya Public School"
                        className="w-full h-full object-cover object-top transition-transform duration-500 group-hover:scale-105"
                      />
                      <div className="absolute top-3.5 left-3.5 px-3 py-1 rounded-full bg-emerald-700 text-white font-black text-[10px] tracking-wider uppercase shadow-md flex items-center gap-1.5">
                        <GraduationCap className="w-3.5 h-3.5 text-white" />
                        <span>{isHi ? 'प्रधानाचार्या' : 'PRINCIPAL'}</span>
                      </div>
                      <div className="absolute inset-0 bg-gradient-to-t from-black/75 via-transparent to-transparent" />
                      <div className="absolute bottom-3.5 left-4 right-4 text-white">
                        <h3 className="text-lg font-black tracking-tight drop-shadow">{isHi ? 'सोनी मैडम' : 'Soni Madam'}</h3>
                        <p className="text-[11px] text-emerald-300 font-bold uppercase tracking-wider">{isHi ? 'प्रधानाचार्या' : 'Principal'}</p>
                      </div>
                    </div>
                    <div className="p-6 space-y-3">
                      <p className="text-xs text-[#65748B] leading-relaxed italic">
                        {isHi
                          ? '“प्रत्येक विद्यार्थी में असीम क्षमताएं होती हैं। हमारे शिक्षक व्यक्तिगत मार्गदर्शन, सर्वांगीण विकास और एक प्रेरक वातावरण में गुणवत्तापूर्ण शिक्षा देने के लिए समर्पित हैं।”'
                          : '“Every student has unique potential. Our faculty is devoted to personalized mentorship, holistic growth, and academic rigor in a nurturing atmosphere.”'}
                      </p>
                    </div>
                  </div>
                  <div className="px-6 py-4 bg-slate-50 border-t border-[#E2E8F0] flex items-center gap-2 text-xs font-bold text-[#102747]">
                    <School className="w-4 h-4 text-emerald-600" />
                    <span>{isHi ? 'शैक्षणिक प्रशासन एवं संकाय प्रमुख' : 'Academic Administration & Faculty Head'}</span>
                  </div>
                </div>
              </div>
            </section>

            {/* ── SECTION 4B: KEY ADMINISTRATION & ACADEMIC LEADERSHIP TEAM ── */}
            <section id="administration-team" className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 scroll-mt-28">
              <div className="text-center space-y-2 mb-8 sm:mb-12">
                <span className="text-[11px] font-black uppercase tracking-widest text-[#F4B323] bg-[#0c2340] px-3.5 py-1 rounded-full border border-[#F4B323]/30 shadow-xs">
                  {isHi ? 'मुख्य प्रशासनिक एवं शैक्षणिक दल' : 'ADMINISTRATIVE & ACADEMIC LEADERSHIP'}
                </span>
                <h2 className="text-2xl sm:text-3xl font-black text-[#14243B] tracking-tight">
                  {isHi ? 'विद्यालय संचालन, अनुशासन एवं शिक्षण नेतृत्व' : 'Key School Administration & Academic Heads'}
                </h2>
                <p className="text-xs sm:text-sm text-[#65748B] max-w-2xl mx-auto">
                  {isHi
                    ? 'दैनिक विद्यालय संचालन, उच्च शैक्षणिक स्तर, सुदृढ़ अनुशासन और पारदर्शी व्यवस्था सुनिश्चित करने वाले हमारे मुख्य स्तंभ।'
                    : 'The dedicated administrative pillars ensuring seamless school operations, disciplined environment, high academic standards, and transparent accounts.'}
                </p>
              </div>

              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
                {((websiteLeadership && websiteLeadership.length > 0) ? websiteLeadership : [
                  {
                    id: 'lead_ravi',
                    name: isHi ? 'रवि सर' : 'Ravi Sir',
                    role: isHi ? 'उप-प्रधानाचार्य' : 'Vice-Principal',
                    subtitle: isHi ? 'उप-प्रधानाचार्य (प्रशासन)' : 'Vice-Principal (Admin)',
                    avatarText: 'RS',
                    avatarUrl: '',
                    bio: isHi ? 'विद्यालय के दैनिक प्रशासनिक संचालन, शिक्षक समन्वय एवं समग्र छात्र अनुशासन के कुशल मार्गदर्शक। विद्यालय प्रबंधन एवं अभिभावकों के बीच निरंतर संवाद स्थापित कर संस्थान के सर्वांगीण विकास और शैक्षणिक गुणवत्ता को नई ऊंचाइयों पर ले जाने हेतु पूर्णतः समर्पित।' : 'Oversees daily school administration, faculty coordination, and student discipline. Dedicated to building strong parent-school communication and elevating academic standards.',
                    keyRoles: [
                      isHi ? 'दैनिक विद्यालय संचालन एवं समय-सारणी (Timetable & Routine) प्रबंधन' : 'Daily school operations & academic routine management',
                      isHi ? 'कक्षा शिक्षण गुणवत्ता निरीक्षण एवं शिक्षक संकाय मार्गदर्शन' : 'Classroom teaching quality monitoring & teacher guidance',
                      isHi ? 'छात्र कल्याण, अभिभावक परामर्श (PTM) एवं प्रशासनिक समन्वय' : 'Student welfare, PTM counseling & admin coordination'
                    ],
                    footerText: isHi ? 'प्रशासनिक सचिवालय एवं छात्र कल्याण' : 'Administration & Student Welfare Desk'
                  },
                  {
                    id: 'lead_ashish',
                    name: isHi ? 'आशीष सर' : 'Ashish Sir',
                    role: isHi ? 'शैक्षणिक प्रमुख' : 'Academic Head',
                    subtitle: isHi ? 'शैक्षणिक प्रमुख (पाठ्यक्रम व परीक्षा)' : 'Academic Head (Syllabus & Exams)',
                    avatarText: 'AS',
                    avatarUrl: '',
                    bio: isHi ? 'आधुनिक पाठ्यक्रम नियोजन, परीक्षा मूल्यांकन, शिक्षक प्रशिक्षण एवं प्रत्येक कक्षा के शिक्षण स्तर को उन्नत बनाने वाले कुशल रणनीतिकार। विद्यार्थियों के बुनियादी ज्ञान से लेकर विशिष्ट प्रतिभा को निखारने हेतु प्रतिबद्ध।' : 'Leads curriculum planning, exam assessments, teacher training, and academic standards across all grades. Focused on deep foundational learning and student merit.',
                    keyRoles: [
                      isHi ? 'पाठ्यक्रम (Syllabus) समयबद्ध पूर्णता एवं परीक्षा योजना' : 'Timely curriculum completion & comprehensive exam schedules',
                      isHi ? 'आधुनिक शिक्षण विधियों (Pedagogy) का क्रियान्वयन व शिक्षक प्रशिक्षण' : 'Modern pedagogy implementation & periodic teacher workshops',
                      isHi ? 'परीक्षा परिणाम विश्लेषण (Result Analysis) व रेमेडियल कक्षा प्रबंधन' : 'Result performance analysis & remedial learning support'
                    ],
                    footerText: isHi ? 'शैक्षणिक उत्कृष्टता एवं परीक्षा प्रकोष्ठ' : 'Academic Excellence & Examination Wing'
                  },
                  {
                    id: 'lead_rozi',
                    name: isHi ? 'रोजी मिस' : 'Rozi Miss',
                    role: isHi ? 'अनुशासन प्रभारी' : 'Discipline Incharge',
                    subtitle: isHi ? 'विद्यालय अनुशासन प्रभारी' : 'School Discipline Incharge',
                    avatarText: 'RM',
                    avatarUrl: '',
                    bio: isHi ? 'विद्यार्थियों में आत्म-अनुशासन, नैतिक संस्कार, स्वच्छता एवं शालीन आचरण के विकास हेतु दृढ़ एवं स्नेहमयी मार्गदर्शिका। परिसर में सुरक्षित, सभ्य और प्रेरणादायक शैक्षिक वातावरण बनाए रखने में अग्रणी भूमिका।' : 'Nurtures student self-discipline, moral ethics, punctuality, and neatness. Ensures a secure, respectful, and motivating school environment for every child.',
                    keyRoles: [
                      isHi ? 'प्रार्थना सभा (Assembly), यूनिफॉर्म एवं समयबद्धता (Punctuality) नियमन' : 'Morning assembly, proper uniform & punctuality enforcement',
                      isHi ? 'विद्यार्थियों में संस्कार, शिष्टाचार और सकारात्मक व्यवहार का विकास' : 'Inculcating moral values, polite etiquette & positive student behavior',
                      isHi ? 'परिसर में सुरक्षा, शांति और अनुशासन नियमों का निष्ठापूर्ण पालन' : 'Campus safety, peaceful environment & strict adherence to rules'
                    ],
                    footerText: isHi ? 'अनुशासन परिषद एवं छात्र आचार संहिता' : 'Discipline Council & Student Conduct'
                  },
                  {
                    id: 'lead_neha',
                    name: isHi ? 'नेहा मिस' : 'Neha Miss',
                    role: isHi ? 'लेखापाल' : 'Accountant',
                    subtitle: isHi ? 'लेखापाल / अकाउंटेंट' : 'School Accountant',
                    avatarText: 'NM',
                    avatarUrl: '',
                    bio: isHi ? 'विद्यालय के समस्त वित्तीय संचालन, डिजिटल फीस प्रणाली और पारदर्शी लेखा-जोखा प्रबंधन की निष्ठावान प्रभारी। अभिभावकों के लिए डिजिटल रसीद, समय पर समाधान एवं पारदर्शी फीस व्यवस्था सुनिश्चित करने में सदैव तत्पर।' : 'Manages school financial accounting, automated fee collection, and digital ledger. Committed to providing instant fee receipts, transparent records, and prompt parent support.',
                    keyRoles: [
                      isHi ? 'ऑनलाइन व ऑफलाइन फीस संग्रहण एवं तुरंत डिजिटल रसीद जारी करना' : 'Online & counter fee collection with instant digital receipt generation',
                      isHi ? 'दैनिक आय-व्यय, ऑडिट और वित्तीय रजिस्टरों का सटीक संधारण' : 'Daily revenue & expense reconciliation, audit ledgers & records',
                      isHi ? 'अभिभावकों को फीस समाधान एवं रसीद संबंधी त्वरित सहायता' : 'Prompt parent assistance with fee inquiries, statements & receipts'
                    ],
                    footerText: isHi ? 'लेखा एवं वित्त कार्यालय' : 'Accounts & Finance Department'
                  }
                ]).map((rawLeader, idx) => {
                  const enMap = {
                    lead_ravi: {
                      name: 'Ravi Sir',
                      role: 'Vice-Principal',
                      subtitle: 'Vice-Principal (Admin)',
                      bio: 'Oversees daily school administration, faculty coordination, and student discipline. Dedicated to building strong parent-school communication and elevating academic standards.',
                      keyRoles: [
                        'Daily school operations & academic routine management',
                        'Classroom teaching quality monitoring & teacher guidance',
                        'Student welfare, PTM counseling & admin coordination'
                      ],
                      footerText: 'Administration & Student Welfare Desk'
                    },
                    lead_ashish: {
                      name: 'Ashish Sir',
                      role: 'Academic Head',
                      subtitle: 'Academic Head (Syllabus & Exams)',
                      bio: 'Leads curriculum planning, exam assessments, teacher training, and academic standards across all grades. Focused on deep foundational learning and student merit.',
                      keyRoles: [
                        'Timely curriculum completion & comprehensive exam schedules',
                        'Modern pedagogy implementation & periodic teacher workshops',
                        'Result performance analysis & remedial learning support'
                      ],
                      footerText: 'Academic Excellence & Examination Wing'
                    },
                    lead_rozi: {
                      name: 'Rozi Miss',
                      role: 'Discipline Incharge',
                      subtitle: 'School Discipline Incharge',
                      bio: 'Nurtures student self-discipline, moral ethics, punctuality, and neatness. Ensures a secure, respectful, and motivating school environment for every child.',
                      keyRoles: [
                        'Morning assembly, proper uniform & punctuality enforcement',
                        'Inculcating moral values, polite etiquette & positive student behavior',
                        'Campus safety, peaceful environment & strict adherence to rules'
                      ],
                      footerText: 'Discipline Council & Student Conduct'
                    },
                    lead_neha: {
                      name: 'Neha Miss',
                      role: 'Accountant',
                      subtitle: 'School Accountant',
                      bio: 'Manages school financial accounting, automated fee collection, and digital ledger. Committed to providing instant fee receipts, transparent records, and prompt parent support.',
                      keyRoles: [
                        'Online & counter fee collection with instant digital receipt generation',
                        'Daily revenue & expense reconciliation, audit ledgers & records',
                        'Prompt parent assistance with fee inquiries, statements & receipts'
                      ],
                      footerText: 'Accounts & Finance Department'
                    }
                  };

                  const enFb = enMap[rawLeader.id] || {};
                  const isDeval = (s) => typeof s === 'string' && /[\u0900-\u097F]/.test(s);

                  const leader = {
                    ...rawLeader,
                    name: isHi ? (rawLeader.nameHi || rawLeader.name) : (rawLeader.nameEn || (!isDeval(rawLeader.name) ? rawLeader.name : null) || enFb.name || rawLeader.name),
                    role: isHi ? (rawLeader.roleHi || rawLeader.role) : (rawLeader.roleEn || (!isDeval(rawLeader.role) ? rawLeader.role : null) || enFb.role || rawLeader.role),
                    subtitle: isHi ? (rawLeader.subtitleHi || rawLeader.subtitle) : (rawLeader.subtitleEn || (!isDeval(rawLeader.subtitle) ? rawLeader.subtitle : null) || enFb.subtitle || rawLeader.role),
                    bio: isHi ? (rawLeader.bioHi || rawLeader.bio) : (rawLeader.bioEn || (!isDeval(rawLeader.bio) ? rawLeader.bio : null) || enFb.bio || rawLeader.bio),
                    keyRoles: isHi ? (rawLeader.keyRolesHi || rawLeader.keyRoles) : (rawLeader.keyRolesEn || (Array.isArray(rawLeader.keyRoles) && rawLeader.keyRoles.length > 0 && !isDeval(rawLeader.keyRoles[0]) ? rawLeader.keyRoles : null) || enFb.keyRoles || rawLeader.keyRoles),
                    footerText: isHi ? (rawLeader.footerText || 'प्रशासनिक संकाय') : (rawLeader.footerTextEn || enFb.footerText || 'Administrative Faculty')
                  };

                  return (
                  <div key={leader.id || idx} className="bg-white rounded-3xl overflow-hidden border border-slate-200/80 shadow-sm hover:shadow-xl hover:border-slate-300 transition-all duration-300 flex flex-col justify-between group hover:-translate-y-1">
                    <div>
                      {/* Header Banner */}
                      <div className="bg-gradient-to-br from-[#0c2340] via-[#102a4d] to-[#173a66] p-6 text-white relative overflow-hidden">
                        <div className="absolute -right-4 -bottom-4 w-24 h-24 rounded-full bg-white/5 blur-xl pointer-events-none" />
                        <div className="flex items-center gap-3.5 relative z-10">
                          {leader.avatarUrl ? (
                            <img
                              src={leader.avatarUrl}
                              alt={leader.name}
                              className="w-14 h-14 rounded-2xl object-cover border border-white/20 shadow-inner flex-shrink-0"
                            />
                          ) : (
                            <div className="w-14 h-14 rounded-2xl bg-white/10 border border-white/20 flex items-center justify-center font-black text-xl text-white shadow-inner flex-shrink-0">
                              {leader.avatarText || leader.name?.substring(0, 2) || 'MN'}
                            </div>
                          )}
                          <div className="min-w-0">
                            <span className="inline-block text-[10px] font-black uppercase tracking-wider text-[#F4B323] bg-[#F4B323]/15 px-2.5 py-0.5 rounded-full border border-[#F4B323]/30 mb-1">
                              {leader.role}
                            </span>
                            <h3 className="text-lg font-black tracking-tight text-white truncate">
                              {leader.name}
                            </h3>
                            <p className="text-xs text-slate-300 font-semibold truncate">
                              {leader.subtitle || leader.role}
                            </p>
                          </div>
                        </div>
                      </div>

                      {/* Content & Description */}
                      <div className="p-5 sm:p-6 space-y-4">
                        <p className="text-xs text-[#475569] leading-relaxed">
                          {leader.bio}
                        </p>

                        {/* Key Roles */}
                        {leader.keyRoles && leader.keyRoles.length > 0 && (
                          <div className="pt-3 border-t border-slate-100 space-y-2">
                            <div className="text-[11px] font-black uppercase tracking-wider text-[#0c2340] flex items-center gap-1.5">
                              <CheckCircle2 className="w-3.5 h-3.5 text-[#0c2340]" />
                              <span>{isHi ? 'मुख्य जिम्मेदारियां (Key Roles)' : 'Key Responsibilities'}</span>
                            </div>
                            <ul className="text-[11px] text-[#64748B] space-y-1.5">
                              {leader.keyRoles.map((roleItem, rIdx) => (
                                <li key={rIdx} className="flex items-start gap-1.5">
                                  <span className="text-[#0c2340] font-bold mt-0.5">•</span>
                                  <span>{roleItem}</span>
                                </li>
                              ))}
                            </ul>
                          </div>
                        )}
                      </div>
                    </div>

                    <div className="px-5 py-3 bg-slate-50 border-t border-slate-100 flex items-center gap-2 text-[11px] font-bold text-[#0c2340]">
                      <Building className="w-3.5 h-3.5 text-[#0c2340]" />
                      <span>{leader.footerText || (isHi ? 'प्रशासनिक संकाय' : 'Administrative Faculty')}</span>
                    </div>
                  </div>
                  );
                })}
              </div>
            </section>

            {/* ── SECTION 5: REAL CAMPUS PHOTO GALLERY ── */}
            <section id="campus-gallery" className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 scroll-mt-28">
              <div className="text-center space-y-2 mb-8 sm:mb-12">
                <span className="text-[11px] font-black uppercase tracking-widest text-[#102747] bg-[#102747]/8 px-3.5 py-1 rounded-full border border-[#102747]/15">
                  {isHi ? 'कैंपस गैलरी' : 'CAMPUS GALLERY'}
                </span>
                <h2 className="text-2xl sm:text-3xl font-black text-[#14243B] tracking-tight">
                  {isHi ? 'मिशन नवोदय पब्लिक स्कूल, मोरा का जीवंत परिसर' : 'Life at Mission Navodaya Public School, Mora'}
                </h2>
                <p className="text-xs sm:text-sm text-[#65748B] max-w-xl mx-auto">
                  {isHi
                    ? 'आधुनिक शिक्षा, खेलकूद और सर्वांगीण चरित्र निर्माण के लिए निर्मित शांत, हरा-भरा और विशाल परिसर।'
                    : 'A serene, green, and spacious campus built for modern learning, sports, and holistic character building.'}
                </p>
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-5">
                {((websiteGallery && websiteGallery.length > 0) ? websiteGallery.slice(0, 4) : [
                  {
                    id: 'gal_1',
                    title: isHi ? 'मुख्य कैंपस प्रवेश द्वार' : 'Main Campus Entrance',
                    description: isHi ? 'स्कूल की आधिकारिक पहचान के साथ सुरक्षित प्रवेश' : 'Secure entrance with official school identification',
                    imageUrl: '/school_gate_banner.jpg'
                  },
                  {
                    id: 'gal_2',
                    title: isHi ? 'खेलकूद एवं फुटबॉल मैदान' : 'Sports & Football Arena',
                    description: isHi ? 'एथलेटिक्स और फुटबॉल के लिए विशाल खुला खेल का मैदान' : 'Expansive open playground for athletics and football',
                    imageUrl: '/campus_playground.jpg'
                  },
                  {
                    id: 'gal_3',
                    title: isHi ? 'शैक्षणिक भवन ब्लॉक' : 'Academic Building Block',
                    description: isHi ? 'हवादार व बड़े क्लासरूम और डिजिटल लर्निंग पॉइंट्स' : 'Spacious, ventilated classrooms and digital study points',
                    imageUrl: '/campus_building.jpg'
                  },
                  {
                    id: 'gal_4',
                    title: isHi ? 'विद्यार्थी आगमन एवं कैंपस जीवन' : 'Student Arrival & Campus Life',
                    description: isHi ? 'अनुशासित कैंपस गेट, साइकिल पार्किंग और आगमन' : 'Disciplined campus gates, bicycle parking and arrival',
                    imageUrl: '/school_entrance.jpg'
                  }
                ]).map((rawPhoto, pIdx) => {
                  const isDeval = (s) => typeof s === 'string' && /[\u0900-\u097F]/.test(s);
                  const galEnMap = {
                    gal_1: {
                      title: 'Main Campus Entrance',
                      description: 'Secure entrance with official school identification'
                    },
                    gal_2: {
                      title: 'Sports & Football Arena',
                      description: 'Expansive open playground for athletics and football'
                    },
                    gal_3: {
                      title: 'Academic Building Block',
                      description: 'Spacious, ventilated classrooms and digital study points'
                    },
                    gal_4: {
                      title: 'Student Arrival & Campus Life',
                      description: 'Disciplined campus gates, bicycle parking and daily arrival'
                    }
                  };
                  const gFb = galEnMap[rawPhoto.id] || {};
                  const photo = {
                    ...rawPhoto,
                    title: isHi ? (rawPhoto.titleHi || rawPhoto.title) : (rawPhoto.titleEn || (!isDeval(rawPhoto.title) ? rawPhoto.title : null) || gFb.title || rawPhoto.title),
                    description: isHi ? (rawPhoto.descriptionHi || rawPhoto.description) : (rawPhoto.descriptionEn || (!isDeval(rawPhoto.description) ? rawPhoto.description : null) || gFb.description || rawPhoto.description)
                  };

                  return (
                    <div key={photo.id || pIdx} className="bg-white rounded-2xl overflow-hidden border border-[#E2E8F0] shadow-xs hover:shadow-md transition-all group">
                      <div className="aspect-[4/3] overflow-hidden bg-slate-100">
                        <img
                          src={photo.imageUrl || photo.src || '/school_campus_banner.jpg'}
                          alt={photo.title}
                          loading="lazy"
                          className="w-full h-full object-cover transition-transform duration-500 group-hover:scale-105"
                          onError={(e) => { e.currentTarget.onerror = null; e.currentTarget.src = '/school_campus_banner.jpg'; }}
                        />
                      </div>
                      <div className="p-4 space-y-1 bg-white">
                        <h3 className="text-sm font-bold text-[#14243B]">{photo.title}</h3>
                        <p className="text-[11px] text-[#65748B]">{photo.description}</p>
                      </div>
                    </div>
                  );
                })}
              </div>
            </section>

            {/* ── SECTION 6: PARENTS & GUARDIANS REVIEWS & TESTIMONIALS ── */}
            <section id="reviews" className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 scroll-mt-28">
              <div className="text-center space-y-2 mb-8 sm:mb-12">
                <span className="text-[11px] font-black uppercase tracking-widest text-[#102747] bg-[#102747]/8 px-3.5 py-1 rounded-full border border-[#102747]/15">
                  {isHi ? 'अभिभावकों के विचार • अभिभावक समीक्षाएं' : 'COMMUNITY VOICES • PARENT TESTIMONIALS'}
                </span>
                <h2 className="text-2xl sm:text-3xl lg:text-4xl font-black text-[#14243B] tracking-tight">
                  {isHi ? 'सीवान और मोरा बाज़ार के अभिभावकों का अटूट विश्वास' : 'Trusted by Parents Across Siwan & Mora Bazar'}
                </h2>
                <p className="text-xs sm:text-sm text-[#65748B] max-w-2xl mx-auto">
                  {isHi
                    ? 'हमारे अनुशासित वातावरण, व्यक्तिगत ध्यान और संस्कारयुक्त अंग्रेजी माध्यम शिक्षा पर अभिभावकों के अनुभव।'
                    : 'Hear directly from parents and guardians about our disciplined environment, individual attention, and values-based English medium education.'}
                </p>

                {/* Rating Overview Pill */}
                <div className="pt-2 flex flex-wrap items-center justify-center gap-3">
                  <div className="inline-flex items-center gap-2 px-4 py-1.5 rounded-full bg-amber-50 border border-amber-200 text-amber-800 text-xs font-black shadow-xs">
                    <div className="flex items-center text-amber-500">
                      {[...Array(5)].map((_, i) => (
                        <Star key={i} className="w-3.5 h-3.5 fill-current" />
                      ))}
                    </div>
                    <span>{isHi ? '4.9 / 5.0 रेटिंग' : '4.9 / 5.0 Rating'}</span>
                    <span className="text-amber-600 font-medium">{isHi ? '• 180+ सत्यापित अभिभावक' : '• 180+ Verified Parents'}</span>
                  </div>
                  <div className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full bg-emerald-50 border border-emerald-200 text-emerald-800 text-xs font-bold">
                    <CheckCircle2 className="w-3.5 h-3.5 text-emerald-600" />
                    <span>{isHi ? '99% संतुष्टि दर' : '99% Recommendation Rate'}</span>
                  </div>
                </div>
              </div>

              {/* Live Reviews Cards Grid (Synced with Admin App) */}
              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-5">
                {((websiteReviews && websiteReviews.length > 0) ? websiteReviews.slice(0, 4) : [
                  {
                    id: 'rev_1',
                    authorName: isHi ? 'राजेश कुमार सिंह' : 'Rajesh Kumar Singh',
                    relation: isHi ? 'आरव के पिता • कक्षा 4' : 'Father of Aarav • Grade 4',
                    rating: 5,
                    text: isHi
                      ? '“स्कूल में पढ़ाई और अनुशासन दोनों बहुत बढ़िया है। आरव की इंग्लिश कम्युनिकेशन और बेसिक मैथ्स में बहुत सुधार हुआ है। शिक्षक हमेशा सहयोगी और स्नेही रहते हैं।”'
                      : '“School me padhai aur discipline dono bahut badhiya hai. Aarav ki English communication aur basic maths me bohot improvement hua hai. Teachers hamesha accessible aur caring hain.”'
                  },
                  {
                    id: 'rev_2',
                    authorName: isHi ? 'सुनीता देवी' : 'Sunita Devi',
                    relation: isHi ? 'प्रिया कुमारी की माता • कक्षा 1' : 'Mother of Priya Kumari • Grade 1',
                    rating: 5,
                    text: isHi
                      ? '“मोरा बाज़ार क्षेत्र में ऐसा अनुशासित, सुरक्षित और प्रेरक स्कूल वातावरण मिलना गर्व की बात है। बच्चों पर व्यक्तिगत रूप से पूरा ध्यान दिया जाता है।”'
                      : '“Mora Bazar area me aisa disciplined, safe aur supportive school environment milna bohot khushi ki baat hai. Bachho par personalized dhyan diya jata hai.”'
                  },
                  {
                    id: 'rev_3',
                    authorName: isHi ? 'मो. शमीम अंसारी' : 'Md. Shamim Ansari',
                    relation: isHi ? 'रेहान के पिता • कक्षा 7' : 'Father of Rehan • Grade 4',
                    rating: 5,
                    text: isHi
                      ? '“स्पोर्ट्स प्लेग्राउंड और कंप्यूटर लैब बहुत बढ़िया है। रेहान फुटबॉल और डिजिटल लर्निंग में सक्रिय रूप से भाग लेता है। प्रबंधन का विजन बहुत स्पष्ट है।”'
                      : '“Sports playground aur computer lab bohot accha hai. Rehan football aur digital learning me active participate karta hai. Management ka vision ekdum clear aur dedicated hai.”'
                  },
                  {
                    id: 'rev_4',
                    authorName: isHi ? 'पूजा शर्मा' : 'Pooja Sharma',
                    relation: isHi ? 'अनन्या की माता • यूकेजी' : 'Mother of Ananya • UKG',
                    rating: 5,
                    text: isHi
                      ? '“एक्टिविटी बेस्ड लर्निंग और फोनिक्स से मेरी बेटी बहुत तेजी से सीख रही है। सोनी मैडम और सभी शिक्षक हर बच्चे का पूरा ख्याल रखते हैं।”'
                      : '“Activity based learning aur phonics se meri beti bahut tezi se seekh rahi hai. Soni Madam aur sabhi teachers har bachhe ka pura khayal rakhte hain.”'
                  }
                ]).map((rawRev, rIdx) => {
                  const isDeval = (s) => typeof s === 'string' && /[\u0900-\u097F]/.test(s);
                  const revEnMap = {
                    rev_1: {
                      authorName: 'Rajesh Kumar Singh',
                      relation: 'Father of Aarav • Grade 4',
                      text: '“The school excels in both academics and discipline. Aarav’s English communication and foundational mathematics have improved tremendously. The teachers are always approachable and caring.”'
                    },
                    rev_2: {
                      authorName: 'Sunita Devi',
                      relation: 'Mother of Priya Kumari • Grade 1',
                      text: '“It is a privilege to have such a disciplined, secure, and inspiring school environment in the Mora Bazar area. Every child receives dedicated, personalized attention.”'
                    },
                    rev_3: {
                      authorName: 'Md. Shamim Ansari',
                      relation: 'Father of Rehan • Grade 7',
                      text: '“The sports playground and computer lab are excellent. Rehan actively participates in football and digital learning. The management’s vision is crystal clear and dedicated.”'
                    },
                    rev_4: {
                      authorName: 'Pooja Sharma',
                      relation: 'Mother of Ananya • UKG',
                      text: '“Activity-based learning and phonics have accelerated my daughter’s learning curve. Soni Madam and all the faculty members take genuine care of each child.”'
                    }
                  };
                  const rFb = revEnMap[rawRev.id] || {};
                  const rev = {
                    ...rawRev,
                    authorName: isHi ? (rawRev.authorNameHi || rawRev.authorName) : (rawRev.authorNameEn || (!isDeval(rawRev.authorName) ? rawRev.authorName : null) || rFb.authorName || rawRev.authorName),
                    relation: isHi ? (rawRev.relationHi || rawRev.relation) : (rawRev.relationEn || (!isDeval(rawRev.relation) ? rawRev.relation : null) || rFb.relation || rawRev.relation),
                    text: isHi ? (rawRev.textHi || rawRev.text) : (rawRev.textEn || (!isDeval(rawRev.text) ? rawRev.text : null) || rFb.text || rawRev.text)
                  };

                  return (
                    <div key={rev.id || rIdx} className="bg-white rounded-3xl p-6 border border-[#E2E8F0] shadow-xs hover:shadow-xl transition-all duration-300 flex flex-col justify-between group">
                      <div className="space-y-4">
                        <div className="flex items-center justify-between">
                          <div className="flex items-center text-amber-500">
                            {[...Array(Number(rev.rating) || 5)].map((_, i) => (
                              <Star key={i} className="w-4 h-4 fill-current" />
                            ))}
                          </div>
                          <Quote className="w-6 h-6 text-slate-200 group-hover:text-[#F4B323] transition-colors" />
                        </div>
                        <p className="text-xs text-[#475569] leading-relaxed italic">
                          {rev.text}
                        </p>
                      </div>

                      <div className="pt-4 mt-4 border-t border-slate-100 flex items-center gap-3">
                        <div className="w-10 h-10 rounded-full bg-[#102747] text-[#F4B323] font-black text-xs flex items-center justify-center flex-shrink-0 shadow-xs">
                          {rev.authorName ? rev.authorName.substring(0, 2).toUpperCase() : 'MN'}
                        </div>
                        <div className="min-w-0">
                          <div className="text-xs font-black text-[#14243B] truncate flex items-center gap-1">
                            <span>{rev.authorName}</span>
                            <CheckCircle2 className="w-3 h-3 text-emerald-500 flex-shrink-0" />
                          </div>
                          <div className="text-[10px] text-[#65748B] font-medium truncate">
                            {rev.relation}
                          </div>
                        </div>
                      </div>
                    </div>
                  );
                })}
              </div>
            </section>

            {/* ── SECTION 7: CONTACT & CAMPUS HELPLINE (Direct from Banner Footer Strip) ── */}
            
            {/* ── SECTION 6: OFFICIAL MNP SCHOOL MOBILE APP DOWNLOAD ── */}
            <section id="download" className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 scroll-mt-28">
              <div className="relative rounded-3xl overflow-hidden bg-gradient-to-br from-[#0c2340] via-[#102747] to-[#091A32] border border-[#F4B323]/30 shadow-2xl p-6 sm:p-10 lg:p-12 text-white">
                
                {/* Background decorative glow */}
                <div className="absolute top-0 right-0 w-96 h-96 bg-amber-500/10 rounded-full blur-3xl pointer-events-none" />
                <div className="absolute bottom-0 left-0 w-80 h-80 bg-blue-500/10 rounded-full blur-3xl pointer-events-none" />

                <div className="relative z-10 grid grid-cols-1 lg:grid-cols-12 gap-8 lg:gap-12 items-center">
                  
                  {/* Left Column: App Information & Features */}
                  <div className="lg:col-span-7 space-y-5 text-center lg:text-left">
                    <div className="inline-flex items-center gap-2 px-3.5 py-1.5 rounded-full bg-[#F4B323]/15 border border-[#F4B323]/30 text-amber-300 text-xs font-black uppercase tracking-wider">
                      <Smartphone className="w-4 h-4 text-[#F4B323]" />
                      <span>{isHi ? 'आधिकारिक मोबाइल ऐप (Android)' : 'Official Android App v1.0.1 (Build 12)'}</span>
                    </div>

                    <h2 className="text-2xl sm:text-3xl lg:text-4xl font-black text-white tracking-tight leading-tight">
                      {isHi ? (
                        <>मिशन नवोदय स्कूल ऐप <span className="text-[#F4B323]">अपने फोन में डाउनलोड करें</span></>
                      ) : (
                        <>Download the Official <span className="text-[#F4B323]">MNP School Mobile App</span></>
                      )}
                    </h2>

                    <p className="text-xs sm:text-sm text-slate-300 leading-relaxed max-w-2xl">
                      {isHi
                        ? 'अभिभावकों, विद्यार्थियों एवं शिक्षकों के लिए विशेष रूप से निर्मित। अब बच्चे की दैनिक उपस्थिति, परीक्षा परिणाम, फीस रसीद और स्कूल नोटिस सीधे अपने मोबाइल पर देखें।'
                        : 'Built exclusively for parents, students, and faculty. Check real-time attendance, examination results, fee receipts, timetable, and school announcements on your phone.'}
                    </p>

                    {/* 4 Feature Badges */}
                    <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 pt-2">
                      <div className="p-3 rounded-2xl bg-white/5 border border-white/10 text-center">
                        <div className="text-base sm:text-lg font-black text-[#F4B323]">📊 100%</div>
                        <div className="text-[11px] font-bold text-slate-300 mt-0.5">{isHi ? 'दैनिक उपस्थिति' : 'Attendance'}</div>
                      </div>
                      <div className="p-3 rounded-2xl bg-white/5 border border-white/10 text-center">
                        <div className="text-base sm:text-lg font-black text-emerald-400">{isHi ? '📄 लाइव' : '📄 LIVE'}</div>
                        <div className="text-[11px] font-bold text-slate-300 mt-0.5">{isHi ? 'रिजल्ट व मार्कशीट' : 'Results'}</div>
                      </div>
                      <div className="p-3 rounded-2xl bg-white/5 border border-white/10 text-center">
                        <div className="text-base sm:text-lg font-black text-blue-400">{isHi ? '💳 डिजिटल' : '💳 DIGITAL'}</div>
                        <div className="text-[11px] font-bold text-slate-300 mt-0.5">{isHi ? 'फीस रसीद' : 'Fee Receipts'}</div>
                      </div>
                      <div className="p-3 rounded-2xl bg-white/5 border border-white/10 text-center">
                        <div className="text-base sm:text-lg font-black text-purple-400">{isHi ? '📢 तुरंत' : '📢 INSTANT'}</div>
                        <div className="text-[11px] font-bold text-slate-300 mt-0.5">{isHi ? 'स्कूल नोटिस' : 'Notices'}</div>
                      </div>
                    </div>

                    {/* Download CTA Buttons */}
                    <div className="pt-4 flex flex-col sm:flex-row items-center justify-center lg:justify-start gap-3.5">
                      {/* Primary 64-bit APK Download */}
                      <a
                        href="https://github.com/Rvsharma1218/MNP-School/releases/download/v1.0.1-build12/MNP_School_arm64-v8a.apk"
                        download="MNP_School_v1.0.1.apk"
                        className="w-full sm:w-auto px-6 py-3.5 rounded-2xl bg-[#F4B323] hover:bg-amber-400 text-[#0c2340] font-black text-sm transition-all shadow-xl shadow-amber-500/20 flex items-center justify-center gap-3 cursor-pointer hover:scale-105 active:scale-95"
                      >
                        <Download className="w-5 h-5 text-[#0c2340]" />
                        <span>{isHi ? 'Android ऐप सीधे डाउनलोड करें (v1.0.1)' : 'Direct Download Android App (v1.0.1)'}</span>
                      </a>

                      {/* Fallback 32-bit APK for older phones */}
                      <a
                        href="https://github.com/Rvsharma1218/MNP-School/releases/download/v1.0.1-build12/MNP_School_armeabi-v7a.apk"
                        download="MNP_School_v1.0.1_v7a.apk"
                        className="w-full sm:w-auto px-5 py-3.5 rounded-2xl bg-white/10 hover:bg-white/15 text-white font-bold text-xs border border-white/20 transition-all flex items-center justify-center gap-2 cursor-pointer"
                      >
                        <Smartphone className="w-4 h-4 text-slate-300" />
                        <span>{isHi ? 'पुराने फोन के लिए (v7a APK)' : 'Older Devices (32-bit v7a)'}</span>
                      </a>
                    </div>

                    <div className="text-[11px] text-slate-400 flex items-center justify-center lg:justify-start gap-2 pt-1 font-medium">
                      <span className="w-2 h-2 rounded-full bg-emerald-400 animate-pulse" />
                      <span>{isHi ? 'सुरक्षित एवं सत्यापित एपीके · साइज: ~50 MB · Android 6.0+' : 'Verified Secure APK · Size: ~50 MB · Android 6.0+'}</span>
                    </div>

                  </div>

                  {/* Right Column: Visual App Mockup Preview */}
                  <div className="lg:col-span-5 flex justify-center">
                    <div className="w-64 sm:w-72 rounded-[2.5rem] p-3 bg-gradient-to-b from-slate-700 via-slate-800 to-slate-900 border-4 border-slate-600 shadow-2xl shadow-black/60">
                      <div className="rounded-[2rem] overflow-hidden bg-[#0c2340] border border-white/10 p-5 text-center space-y-4">
                        
                        {/* Speaker Notch */}
                        <div className="w-16 h-1.5 bg-white/20 rounded-full mx-auto" />

                        {/* App Logo & Badge */}
                        <div className="w-16 h-16 mx-auto drop-shadow-md flex items-center justify-center">
                          <img src={logoSrc} alt={schoolName} className="w-full h-full object-contain" />
                        </div>

                        <div>
                          <div className="text-xs font-black text-white uppercase tracking-wider">MNP SCHOOL APP</div>
                          <div className="text-[10px] text-[#F4B323] font-bold mt-0.5">Mora-Mairi, Siwan</div>
                        </div>

                        {/* Sample App Screen Mockup Items */}
                        <div className="space-y-2 text-left text-xs">
                          <div className="p-2 rounded-xl bg-white/10 flex items-center justify-between text-white">
                            <span className="font-bold">{isHi ? 'आज की उपस्थिति' : "Today's Attendance"}</span>
                            <span className="text-[10px] px-2 py-0.5 rounded-full bg-emerald-500/20 text-emerald-300 font-bold">{isHi ? 'उपस्थित ✓' : 'Present ✓'}</span>
                          </div>
                          <div className="p-2 rounded-xl bg-white/10 flex items-center justify-between text-white">
                            <span className="font-bold">{isHi ? 'सत्र परिणाम' : 'Session Result'}</span>
                            <span className="text-[10px] px-2 py-0.5 rounded-full bg-amber-500/20 text-amber-300 font-bold">{isHi ? 'A+ ग्रेड' : 'Grade A+'}</span>
                          </div>
                          <div className="p-2 rounded-xl bg-white/10 flex items-center justify-between text-white">
                            <span className="font-bold">{isHi ? 'स्कूल नोटिस' : 'School Notice'}</span>
                            <span className="text-[10px] text-slate-300">{isHi ? 'नया अलर्ट' : 'New Alert'}</span>
                          </div>
                        </div>

                        {/* Mock Button */}
                        <a
                          href="https://github.com/Rvsharma1218/MNP-School/releases/download/v1.0.1-build12/MNP_School_arm64-v8a.apk"
                          download="MNP_School_v1.0.1.apk"
                          className="block w-full py-2.5 rounded-xl bg-[#F4B323] text-[#0c2340] font-black text-xs hover:brightness-110 transition-all shadow-md"
                        >
                          {isHi ? 'इंस्टॉल करें' : 'Install APK'}
                        </a>

                      </div>
                    </div>
                  </div>

                </div>

              </div>
            </section>


            <section id="contact" className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 scroll-mt-28">
              <div className="bg-white rounded-3xl border border-[#E2E8F0] shadow-sm p-6 sm:p-10 space-y-8">

                {/* Header */}
                <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 border-b border-[#E2E8F0] pb-6">
                  <div>
                    <span className="text-[11px] font-black uppercase tracking-widest text-[#102747] bg-[#102747]/8 px-3.5 py-1 rounded-full border border-[#102747]/15">
                      {isHi ? 'संपर्क करें' : 'REACH OUT'}
                    </span>
                    <h2 className="text-2xl sm:text-3xl font-black text-[#14243B] tracking-tight mt-2">
                      {isHi ? 'मिशन नवोदय पब्लिक स्कूल से संपर्क करें' : 'Reach Out to Mission Navodaya Public School'}
                    </h2>
                    <p className="text-xs sm:text-sm text-[#65748B] mt-1">
                      {isHi
                        ? 'अभिभावकों के लिए आधिकारिक नामांकन डेस्क, फोन हेल्पलाइन और मिलने का समय।'
                        : 'Official admission desk, phone helpline, and visiting hours for parents and guardians.'}
                    </p>
                  </div>

                  <div className="flex flex-wrap items-center gap-3">
                    <a
                      href={`tel:${primaryPhone}`}
                      className="px-5 py-3 rounded-xl bg-[#102747] hover:bg-[#091A32] text-white text-xs font-bold transition-all shadow-xs inline-flex items-center gap-2 cursor-pointer"
                    >
                      <Phone className="w-4 h-4 text-[#F4B323]" />
                      <span>{isHi ? `हेल्पलाइन: +91 ${primaryPhone}` : `Call Helpline: +91 ${primaryPhone}`}</span>
                    </a>
                    <a
                      href={`https://wa.me/91${primaryPhone}`}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="px-5 py-3 rounded-xl bg-emerald-600 hover:bg-emerald-700 text-white text-xs font-bold transition-all shadow-xs inline-flex items-center gap-2 cursor-pointer"
                    >
                      <MessageSquare className="w-4 h-4" />
                      <span>{isHi ? 'व्हाट्सएप डेस्क' : 'WhatsApp Desk'}</span>
                    </a>
                  </div>
                </div>

                {/* 4 Cards Matching Banner Footer Strip */}
                <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6">
                  {/* Location */}
                  <div className="p-4 rounded-xl bg-slate-50 border border-[#E2E8F0] space-y-2">
                    <div className="w-9 h-9 rounded-lg bg-blue-50 text-blue-700 flex items-center justify-center font-bold">
                      <MapPin className="w-4.5 h-4.5" />
                    </div>
                    <h3 className="text-sm font-bold text-[#14243B]">{schoolLocation}</h3>
                    <p className="text-xs text-[#65748B] leading-relaxed">
                      {isHi ? (
                        <>हमारा स्कूल परिसर<br />मोरा-मैरी, सीवान जिला<br />बिहार, भारत</>
                      ) : (
                        <>Our School Campus<br />Mora-Mairi, Siwan District<br />Bihar, India</>
                      )}
                    </p>
                    <a
                      href="https://www.google.com/maps/dir/?api=1&destination=26.115206775039834,84.62215723091671"
                      target="_blank"
                      rel="noopener noreferrer"
                      className="text-[11px] font-bold text-[#102747] hover:underline inline-flex items-center gap-1 pt-1"
                    >
                      <span>{isHi ? 'गूगल मैप्स पर देखें' : 'Open Google Maps'}</span>
                      <ExternalLink className="w-3 h-3" />
                    </a>
                  </div>

                  {/* Phone & WhatsApp */}
                  <div className="p-4 rounded-xl bg-slate-50 border border-[#E2E8F0] space-y-2">
                    <div className="w-9 h-9 rounded-lg bg-emerald-50 text-emerald-700 flex items-center justify-center font-bold">
                      <Phone className="w-4.5 h-4.5" />
                    </div>
                    <h3 className="text-sm font-bold text-[#14243B]">+91 {primaryPhone}</h3>
                    <p className="text-xs text-[#65748B] leading-relaxed">
                      {isHi ? (
                        <>कॉल / व्हाट्सएप डेस्क<br />आधिकारिक हेल्पलाइन: +91 {primaryPhone}<br />सोमवार से शनिवार</>
                      ) : (
                        <>Call / WhatsApp Desk<br />Official Helpline: +91 {primaryPhone}<br />Monday through Saturday</>
                      )}
                    </p>
                    <a
                      href={`https://wa.me/91${primaryPhone}`}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="text-[11px] font-bold text-emerald-700 hover:underline inline-flex items-center gap-1 pt-1"
                    >
                      <span>{isHi ? 'व्हाट्सएप पर चैट करें' : 'Chat on WhatsApp'}</span>
                      <ExternalLink className="w-3 h-3" />
                    </a>
                  </div>

                  {/* Official Email */}
                  <div className="p-4 rounded-xl bg-slate-50 border border-[#E2E8F0] space-y-2">
                    <div className="w-9 h-9 rounded-lg bg-amber-50 text-amber-700 flex items-center justify-center font-bold">
                      <Mail className="w-4.5 h-4.5" />
                    </div>
                    <h3 className="text-sm font-bold text-[#14243B]">{officialEmail}</h3>
                    <p className="text-xs text-[#65748B] leading-relaxed">
                      {isHi ? (
                        <>आधिकारिक संस्थागत ईमेल<br />नामांकन एवं सत्यापन<br />विद्यार्थी पूछताछ</>
                      ) : (
                        <>Official Institutional Email<br />Admissions &amp; Verification<br />Student Inquiries</>
                      )}
                    </p>
                    <a
                      href={`mailto:${officialEmail}`}
                      className="text-[11px] font-bold text-[#102747] hover:underline inline-flex items-center gap-1 pt-1"
                    >
                      <span>{isHi ? 'सीधे ईमेल भेजें' : 'Send Direct Mail'}</span>
                      <ArrowRight className="w-3 h-3" />
                    </a>
                  </div>

                  {/* School Timings */}
                  <div className="p-4 rounded-xl bg-slate-50 border border-[#E2E8F0] space-y-2">
                    <div className="w-9 h-9 rounded-lg bg-purple-50 text-purple-700 flex items-center justify-center font-bold">
                      <Clock className="w-4.5 h-4.5" />
                    </div>
                    <h3 className="text-sm font-bold text-[#14243B]">{isHi ? 'स्कूल समय सारणी' : 'School Timings'}</h3>
                    <p className="text-xs text-[#65748B] leading-relaxed">
                      {isHi ? (
                        <>सोमवार – शनिवार<br /><strong>8:00 पूर्वाह्न – 2:00 अपराह्न</strong><br />रविवार: अवकाश</>
                      ) : (
                        <>Monday – Saturday<br /><strong>8:00 AM – 2:00 PM</strong><br />Sunday: Closed</>
                      )}
                    </p>
                    <div className="text-[11px] text-purple-700 font-semibold pt-1">
                      <span>{isHi ? 'प्रशासनिक व शुल्क काउंटर खुला है' : 'Administrative & Fee Counter Open'}</span>
                    </div>
                  </div>
                </div>

              </div>
            </section>

          </div>
          )
        ) : (
          /* ───────────────────────────────────────────────────────────── */
          /* STAGE 2: PRESERVED AUTHENTICATION MODAL (100% WORKING LOGIC)  */
          /* ───────────────────────────────────────────────────────────── */
          <div className="w-full max-w-lg mx-auto py-4 sm:py-10 px-3 sm:px-4 animate-in zoom-in-95 duration-200">
            <div className="rounded-3xl bg-white border border-[#E2E8F0] shadow-xl p-4 sm:p-8 relative">

              <button
                type="button"
                onClick={() => setIsLoginModalOpen(false)}
                className="inline-flex items-center gap-2 px-3 py-1.5 rounded-xl bg-slate-100 hover:bg-slate-200 text-xs font-bold text-[#102747] transition-all cursor-pointer mb-5"
              >
                <ArrowLeft className="w-3.5 h-3.5 text-[#102747]" />
                <span>{isHi ? '← स्कूल वेबसाइट पर वापस जाएं' : '← Back to School Website'}</span>
              </button>

              <div className="text-center space-y-1.5 mb-5 sm:mb-6">
                <div className="w-14 h-14 sm:w-16 sm:h-16 mx-auto flex items-center justify-center drop-shadow-md">
                  <img
                    src={logoSrc}
                    alt={schoolName}
                    className="w-full h-full object-contain"
                    onError={(e) => {
                      e.currentTarget.onerror = null;
                      e.currentTarget.src = '/logo.png';
                    }}
                  />
                </div>
                <h2 className="text-lg sm:text-xl font-black text-[#14243B] tracking-tight">
                  {role === 'parent'
                    ? (isHi ? 'अभिभावक पोर्टल लॉगिन' : 'Parent Portal Access')
                    : role === 'teacher'
                      ? (isHi ? 'शिक्षक एवं संकाय लॉगिन' : 'Faculty & Teacher Sign In')
                      : (isHi ? 'प्रधानाचार्य प्रशासन पोर्टल' : 'Principal Administration Portal')}
                </h2>
                <p className="text-xs text-[#65748B] font-medium max-w-sm mx-auto">
                  {role === 'parent'
                    ? (isHi ? 'छात्र प्रवेश संख्या एवं पंजीकृत मोबाइल नंबर दर्ज करें' : 'Enter student admission & registered mobile number')
                    : (isHi ? 'सत्यापित कर्मचारियों और प्रबंधन के लिए सुरक्षित संस्थागत पोर्टल' : 'Secure institutional portal for authenticated staff and administration')}
                </p>
              </div>

              {/* Role Switcher Tabs */}
              <div className="grid grid-cols-3 p-1 rounded-2xl bg-slate-100 border border-[#E2E8F0] mb-5 sm:mb-6">
                <button
                  type="button"
                  onClick={() => { setRole('parent'); setError(''); }}
                  className={`py-2 px-1.5 sm:px-2 rounded-xl text-[11px] sm:text-xs font-black flex flex-col sm:flex-row items-center justify-center gap-1 sm:gap-1.5 transition-all cursor-pointer ${role === 'parent'
                    ? 'bg-white text-[#102747] shadow-sm'
                    : 'text-[#65748B] hover:text-[#102747]'
                    }`}
                >
                  <Users className="w-3.5 h-3.5 text-[#F4B323] flex-shrink-0" />
                  <span className="truncate">{isHi ? 'अभिभावक' : 'Parent'}</span>
                </button>

                <button
                  type="button"
                  onClick={() => { setRole('teacher'); setError(''); }}
                  className={`py-2 px-1.5 sm:px-2 rounded-xl text-[11px] sm:text-xs font-black flex flex-col sm:flex-row items-center justify-center gap-1 sm:gap-1.5 transition-all cursor-pointer ${role === 'teacher'
                    ? 'bg-white text-[#102747] shadow-sm'
                    : 'text-[#65748B] hover:text-[#102747]'
                    }`}
                >
                  <GraduationCap className="w-3.5 h-3.5 text-[#102747] flex-shrink-0" />
                  <span className="truncate">{isHi ? 'शिक्षक' : 'Teacher'}</span>
                </button>

                <button
                  type="button"
                  onClick={() => { setRole('principal'); setError(''); }}
                  className={`py-2 px-1.5 sm:px-2 rounded-xl text-[11px] sm:text-xs font-black flex flex-col sm:flex-row items-center justify-center gap-1 sm:gap-1.5 transition-all cursor-pointer ${role === 'principal'
                    ? 'bg-white text-[#102747] shadow-sm'
                    : 'text-[#65748B] hover:text-[#102747]'
                    }`}
                >
                  <ShieldCheck className="w-3.5 h-3.5 text-emerald-600 flex-shrink-0" />
                  <span className="truncate">{isHi ? 'प्रधानाचार्य' : 'Principal'}</span>
                </button>
              </div>

              {/* Error Alert Box */}
              {error && (
                <div className="mb-5 p-3 rounded-xl bg-rose-50 border border-rose-200 flex items-start gap-2.5 text-rose-700 text-xs animate-in fade-in">
                  <AlertCircle className="w-4 h-4 text-rose-600 flex-shrink-0 mt-0.5" />
                  <span className="leading-relaxed font-semibold">{error}</span>
                </div>
              )}

              {/* Authentication Form */}
              <form onSubmit={handleSubmit} className="space-y-4">
                {role === 'parent' ? (
                  /* PARENT LOGIN FIELDS - EXACTLY MATCHING FLUTTER APP UI */
                  <div className="space-y-4 animate-in fade-in">
                    {/* 1-Tap Camera QR Scan Button matching Flutter App */}
                    <button
                      type="button"
                      onClick={() => {
                        const code = prompt(
                          isHi
                            ? "मार्कशीट, आईडी कार्ड या रसीद का QR Code दर्ज करें (उदा. STU2026001):"
                            : "Scan/Enter Student QR Code (from Marksheet, ID Card, or Receipt):"
                        );
                        if (code && code.trim()) {
                          let clean = code.trim();
                          const match = clean.match(/STUDENT:([^|]+)/i) || clean.match(/ID:([^|]+)/i) || clean.match(/ADM:([^|]+)/i);
                          if (match && match[1]) {
                            clean = match[1].trim();
                          }
                          setParentAdmissionNo(clean);
                        }
                      }}
                      className="w-full p-3 rounded-2xl bg-gradient-to-r from-amber-500 to-amber-600 text-slate-900 shadow-md hover:shadow-lg transition-all flex items-center justify-center gap-3 cursor-pointer text-left group"
                    >
                      <div className="w-9 h-9 rounded-full bg-black/15 flex items-center justify-center flex-shrink-0 group-hover:scale-105 transition-transform">
                        <QrCode className="w-5 h-5 text-slate-950" />
                      </div>
                      <div className="min-w-0">
                        <div className="text-xs font-black text-slate-950 leading-tight">
                          📷 {isHi ? 'QR Code Scan Karein' : 'Scan Student QR Code'}
                        </div>
                        <div className="text-[11px] font-semibold text-slate-900/80 leading-tight mt-0.5">
                          {isHi ? 'ID Card ya Fee Receipt scan karke turant kholein' : 'Scan ID Card or Fee Receipt to fill instantly'}
                        </div>
                      </div>
                    </button>

                    <div className="flex items-center gap-3 my-2">
                      <div className="h-px bg-slate-200 flex-1" />
                      <span className="text-[11px] font-bold text-slate-400 uppercase tracking-wider">
                        {isHi ? 'OR / अथवा हाथ से लिखें' : 'OR / Enter Manually'}
                      </span>
                      <div className="h-px bg-slate-200 flex-1" />
                    </div>

                    <div>
                      <label className="block text-xs font-bold text-[#14243B] mb-1.5">
                        {isHi ? 'Admission No / Student ID (प्रवेश संख्या) *' : 'Admission No / Student ID *'}
                      </label>
                      <div className="relative">
                        <Hash className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
                        <input
                          type="text"
                          required
                          value={parentAdmissionNo}
                          onChange={(e) => setParentAdmissionNo(e.target.value)}
                          placeholder="e.g. ADM-2026-001 or STU2026001"
                          className="w-full pl-10 pr-4 py-3 rounded-xl bg-slate-50 border border-[#E2E8F0] text-xs font-medium text-[#14243B] placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-[#102747]/20 focus:border-[#102747] transition-all"
                        />
                      </div>
                    </div>

                    <div>
                      <label className="block text-xs font-bold text-[#14243B] mb-1.5">
                        {isHi ? 'Registered Mobile Number (पंजीकृत मोबाइल नंबर) *' : 'Registered Mobile Number *'}
                      </label>
                      <div className="relative">
                        <Phone className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
                        <input
                          type="tel"
                          required
                          value={parentMobile}
                          onChange={(e) => setParentMobile(e.target.value)}
                          placeholder="10-digit Mobile Number"
                          className="w-full pl-10 pr-4 py-3 rounded-xl bg-slate-50 border border-[#E2E8F0] text-xs font-medium text-[#14243B] placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-[#102747]/20 focus:border-[#102747] transition-all"
                        />
                      </div>
                    </div>

                    {/* Info Callout Box matching Flutter App */}
                    <div className="p-3 rounded-xl bg-amber-50 border border-amber-200/80 flex items-start gap-2.5 text-amber-900 text-xs leading-relaxed">
                      <HelpCircle className="w-4 h-4 text-amber-600 flex-shrink-0 mt-0.5" />
                      <span>
                        {isHi
                          ? 'अभिभावक लाइव उपस्थिति, मासिक शुल्क विवरण, रसीद पीडीएफ और परीक्षा परिणाम देख सकते हैं।'
                          : 'Parents can view live attendance, monthly fee particulars, receipt PDF, and exam results.'}
                      </span>
                    </div>
                  </div>
                ) : (
                  /* PRINCIPAL & TEACHER LOGIN FIELDS */
                  <div className="space-y-4 animate-in fade-in">
                    <div>
                      <label className="block text-xs font-bold text-[#14243B] mb-1.5">
                        {role === 'teacher'
                          ? (isHi ? 'पंजीकृत स्कूल ईमेल पता *' : 'Registered School Email Address *')
                          : (isHi ? 'प्रधानाचार्य / एडमिन ईमेल *' : 'Principal / Admin Email *')}
                      </label>
                      <div className="relative">
                        <Mail className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
                        <input
                          type="email"
                          required
                          value={email}
                          onChange={(e) => setEmail(e.target.value)}
                          placeholder={role === 'teacher' ? 'teacher@school.com' : 'admin@mnpschool.com'}
                          className="w-full pl-10 pr-4 py-3 rounded-xl bg-slate-50 border border-[#E2E8F0] text-xs font-medium text-[#14243B] placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-[#102747]/20 focus:border-[#102747] transition-all"
                        />
                      </div>
                    </div>

                    {role === 'teacher' && (
                      <div>
                        <label className="block text-xs font-bold text-[#14243B] mb-1.5">
                          {isHi ? 'अपना शिक्षक नाम चुनें *' : 'Select Your Teacher Name *'}
                        </label>
                        <div className="relative">
                          <User className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
                          <select
                            required
                            value={selectedTeacherId}
                            onChange={(e) => setSelectedTeacherId(e.target.value)}
                            className="w-full pl-10 pr-10 py-3 rounded-xl bg-slate-50 border border-[#E2E8F0] text-xs font-semibold text-[#14243B] focus:outline-none focus:ring-2 focus:ring-[#102747]/20 focus:border-[#102747] transition-all appearance-none cursor-pointer"
                          >
                            <option value="">{isHi ? '-- अपनी शिक्षक प्रोफ़ाइल चुनें --' : '-- Choose Your Teacher Profile --'}</option>
                            {teachers.map(t => (
                              <option key={t.authUid || t.id} value={t.authUid || t.id}>
                                {t.name} (Class {t.assignedClass} - Sec {t.assignedSection || 'A'})
                              </option>
                            ))}
                          </select>
                          <ChevronDown className="w-4 h-4 text-slate-400 absolute right-3.5 top-1/2 -translate-y-1/2 pointer-events-none" />
                        </div>
                      </div>
                    )}

                    <div>
                      <div className="flex items-center justify-between mb-1.5">
                        <label className="text-xs font-bold text-[#14243B]">
                          {role === 'teacher'
                            ? (isHi ? 'शिक्षक पासवर्ड *' : 'Teacher Password *')
                            : (isHi ? 'एडमिन पासवर्ड *' : 'Admin Password *')}
                        </label>
                        {role === 'principal' && (
                          <button
                            type="button"
                            onClick={() => navigate('/forgot-password')}
                            className="text-[11px] font-bold text-[#102747] hover:underline cursor-pointer"
                          >
                            {isHi ? 'पासवर्ड भूल गए?' : 'Forgot Password?'}
                          </button>
                        )}
                      </div>
                      <div className="relative">
                        <Lock className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
                        <input
                          type={showPassword ? 'text' : 'password'}
                          required
                          value={password}
                          onChange={(e) => setPassword(e.target.value)}
                          placeholder={isHi ? 'पासवर्ड दर्ज करें' : 'Enter password'}
                          className="w-full pl-10 pr-10 py-3 rounded-xl bg-slate-50 border border-[#E2E8F0] text-xs font-medium text-[#14243B] placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-[#102747]/20 focus:border-[#102747] transition-all"
                        />
                        <button
                          type="button"
                          onClick={() => setShowPassword(p => !p)}
                          className="absolute right-3.5 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600 cursor-pointer"
                        >
                          {showPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4 text-slate-600" />}
                        </button>
                      </div>
                    </div>
                  </div>
                )}

                {/* Remember Me */}
                <div className="flex items-center justify-between pt-1">
                  <label className="flex items-center gap-2 text-xs font-medium text-[#65748B] cursor-pointer">
                    <input
                      type="checkbox"
                      checked={rememberMe}
                      onChange={(e) => setRememberMe(e.target.checked)}
                      className="w-4 h-4 rounded text-[#102747] focus:ring-[#102747]/20 cursor-pointer border-[#E2E8F0]"
                    />
                    <span>{isHi ? 'इस डिवाइस को याद रखें' : 'Remember this device'}</span>
                  </label>
                  <span className="text-[10px] text-emerald-700 font-bold flex items-center gap-1">
                    <ShieldCheck className="w-3 h-3 text-emerald-600" />
                    <span>{isHi ? '256-बिट सुरक्षित' : '256-bit Encrypted'}</span>
                  </span>
                </div>

                {/* Submit Action Button */}
                <button
                  type="submit"
                  disabled={loading}
                  className="w-full py-3.5 rounded-xl bg-[#102747] hover:bg-[#091A32] text-white font-bold text-xs shadow-md transition-all flex items-center justify-center gap-2 cursor-pointer disabled:opacity-50 mt-2"
                >
                  {loading ? (
                    <>
                      <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin" />
                      <span>{isHi ? 'पहचान सत्यापित हो रही है...' : 'Authenticating Credentials...'}</span>
                    </>
                  ) : (
                    <>
                      <span>
                        {role === 'parent'
                          ? (isHi ? 'अभिभावक पोर्टल में प्रवेश करें' : 'Enter Parent Portal')
                          : (isHi
                            ? `लॉगिन करें (${role === 'teacher' ? 'शिक्षक कंसोल' : 'एडमिन पोर्टल'})`
                            : `Sign In to ${role === 'teacher' ? 'Teacher Console' : 'Admin Portal'}`)}
                      </span>
                      <ArrowRight className="w-4 h-4 text-[#F4B323]" />
                    </>
                  )}
                </button>
              </form>

              {/* In-Modal School Contact Help Desk */}
              <div className="mt-6 pt-5 border-t border-[#E2E8F0] text-center space-y-1.5">
                <p className="text-[11px] text-[#65748B]">
                  {role === 'parent'
                    ? (isHi ? 'बच्चे का एडमिशन आईडी ढूंढने में मदद चाहिए? स्कूल हेल्पलाइन पर संपर्क करें:' : 'Need help finding your child admission ID? Contact the school helpline:')
                    : (isHi ? 'लॉगिन क्रेडेंशियल सहायता के लिए, प्रधानाचार्य कार्यालय से संपर्क करें:' : 'For credentials assistance, contact the Principal Secretariat:')}
                </p>
                <div className="flex items-center justify-center gap-3 text-xs font-bold text-[#102747]">
                  <a href={`tel:${primaryPhone}`} className="inline-flex items-center gap-1.5 hover:underline">
                    <Phone className="w-3.5 h-3.5 text-emerald-600" />
                    <span>+91 {primaryPhone}</span>
                  </a>
                  <span>·</span>
                  <a href={`mailto:${officialEmail}`} className="inline-flex items-center gap-1.5 hover:underline">
                    <Mail className="w-3.5 h-3.5 text-blue-600" />
                    <span>{officialEmail}</span>
                  </a>
                </div>
              </div>

            </div>
          </div>
        )}
      </main>

      {/* ───────────────────────────────────────────────────────────── */}
      {/* 4. INSTITUTIONAL FOOTER MATCHING THE BANNER (Navy + Gold)     */}
      {/* ───────────────────────────────────────────────────────────── */}
      <footer className="w-full max-w-full overflow-hidden border-t border-[#1E3A60] bg-[#091A32] text-white mt-12">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12 sm:py-16">

          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-8 lg:gap-10">

            {/* Column 1: School Identity */}
            <div className="space-y-4">
              <div className="flex items-center gap-3">
                <div className="w-11 h-11 flex items-center justify-center flex-shrink-0 drop-shadow-sm">
                  <img src={logoSrc} alt={schoolName} className="w-full h-full object-contain" />
                </div>
                <div>
                  <h3 className="text-sm font-black text-white tracking-tight uppercase">
                    {isHi ? 'मिशन नवोदय पब्लिक स्कूल' : schoolName}
                  </h3>
                  <p className="text-[11px] text-[#F4B323] font-medium">{schoolSubtitle}</p>
                </div>
              </div>
              <p className="text-xs text-slate-300 leading-relaxed">
                {isHi
                  ? 'उज्ज्वल भविष्य के लिए ज्ञान, संस्कार, अनुशासन और जीवन कौशल से विद्यार्थियों के सर्वांगीण विकास हेतु समर्पित।'
                  : 'Dedicated to nurturing young minds with knowledge, character, discipline, and life skills for a brighter future.'}
              </p>
              <div className="inline-flex items-center gap-2 px-3 py-1 rounded-lg bg-[#102747] text-[11px] font-bold text-[#F4B323] border border-[#1E3A60]">
                <span className="w-2 h-2 rounded-full bg-emerald-400 animate-pulse" />
                <span>{isHi ? `सत्र ${currentSession} नर्सरी से 8वीं` : `Session ${currentSession} Nursery to 8th`}</span>
              </div>
            </div>

            {/* Column 2: Quick Links */}
            <div className="space-y-3">
              <h4 className="text-xs font-black uppercase tracking-wider text-[#F4B323]">
                {isHi ? 'कैंपस देखें' : 'Explore Campus'}
              </h4>
              <ul className="space-y-2 text-xs text-slate-300 font-medium">
                <li>
                  <button type="button" onClick={() => { window.scrollTo({top: 0, behavior: "smooth"}); navigate("/about"); }} className="hover:text-[#F4B323] transition-colors cursor-pointer text-left">{isHi ? 'स्कूल के बारे में' : 'About the School'}</button>
                </li>
                {isAdmissionOpen && (
                  <li>
                    <button type="button" onClick={() => { window.scrollTo({top: 0, behavior: "smooth"}); navigate("/admissions"); }} className="hover:text-[#F4B323] transition-colors text-[#F4B323] font-bold cursor-pointer text-left">
                      {isHi ? `दाखिला ${currentSession} →` : `Admissions ${currentSession} →`}
                    </button>
                  </li>
                )}
                <li>
                  <button type="button" onClick={() => { window.scrollTo({top: 0, behavior: "smooth"}); navigate("/academics"); }} className="hover:text-[#F4B323] transition-colors cursor-pointer text-left">{isHi ? 'शिक्षा व 5 मुख्य आधार' : 'Academics & Pillars'}</button>
                </li>
                <li>
                  <a href="#leadership" className="hover:text-[#F4B323] transition-colors">{isHi ? 'मार्गदर्शन एवं नेतृत्व' : 'Leadership & Vision'}</a>
                </li>
                <li>
                  <button type="button" onClick={() => { window.scrollTo({top: 0, behavior: "smooth"}); navigate("/gallery"); }} className="hover:text-[#F4B323] transition-colors cursor-pointer text-left">{isHi ? 'फोटो गैलरी' : 'Photo Gallery'}</button>
                </li>
                <li>
                  <a href="#reviews" className="hover:text-[#F4B323] transition-colors text-amber-300">{isHi ? 'अभिभावक समीक्षाएं' : 'Parent Reviews & Ratings'}</a>
                </li>
                <li>
                  <button type="button" onClick={() => { window.scrollTo({top: 0, behavior: "smooth"}); navigate("/contact"); }} className="hover:text-[#F4B323] transition-colors cursor-pointer text-left">{isHi ? 'संपर्क व हेल्प डेस्क' : 'Contact & Help Desk'}</button>
                </li>
              </ul>
            </div>

            {/* Column 3: Digital Portals */}
            <div className="space-y-3">
              <h4 className="text-xs font-black uppercase tracking-wider text-[#F4B323]">
                {isHi ? 'डिजिटल पोर्टल' : 'Digital Portals'}
              </h4>
              <ul className="space-y-2 text-xs text-slate-300 font-medium">
                <li>
                  <button
                    type="button"
                    onClick={() => openPortalLogin('principal')}
                    className="hover:text-[#F4B323] transition-colors cursor-pointer text-left flex items-center gap-1.5"
                  >
                    <ShieldCheck className="w-3.5 h-3.5 text-[#F4B323]" />
                    <span>{isHi ? 'स्कूल पोर्टल लॉगिन (स्टाफ एवं प्रिंसिपल) →' : 'School Portal Login →'}</span>
                  </button>
                </li>
                <li>
                  <button
                    type="button"
                    onClick={() => openPortalLogin('parent')}
                    className="hover:text-[#F4B323] transition-colors cursor-pointer text-left flex items-center gap-1.5"
                  >
                    <Users className="w-3.5 h-3.5 text-[#F4B323]" />
                    <span>{isHi ? 'अभिभावक पोर्टल लॉगिन →' : 'Parent Portal Login →'}</span>
                  </button>
                </li>
                <li>
                  <button
                    type="button"
                    onClick={() => {
                      if (setSignUpFormTab) setSignUpFormTab('student');
                      navigate('/signup?tab=admission');
                    }}
                    className="hover:text-[#F4B323] transition-colors cursor-pointer text-left flex items-center gap-1.5 text-[#F4B323] font-bold"
                  >
                    <Sparkles className="w-3.5 h-3.5 text-[#F4B323]" />
                    <span>{isHi ? 'विद्यार्थी नामांकन डेस्क →' : 'Student Admission Desk →'}</span>
                  </button>
                </li>
                <li>
                  <button
                    type="button"
                    onClick={() => navigate('/download')}
                    className="hover:text-[#F4B323] transition-colors cursor-pointer text-left flex items-center gap-1.5"
                  >
                    <Smartphone className="w-3.5 h-3.5 text-[#F4B323]" />
                    <span>{isHi ? 'मोबाइल ऐप डाउनलोड करें →' : 'Download Mobile App →'}</span>
                  </button>
                </li>
                <li>
                  <button
                    type="button"
                    onClick={() => navigate('/contact')}
                    className="hover:text-[#F4B323] transition-colors cursor-pointer text-left flex items-center gap-1.5"
                  >
                    <MapPin className="w-3.5 h-3.5 text-slate-400" />
                    <span>{isHi ? 'संपर्क एवं सहायता डेस्क →' : 'Contact & Help Desk →'}</span>
                  </button>
                </li>
              </ul>
            </div>

            {/* Column 4: Contact & Office Strip */}
            <div className="space-y-3">
              <h4 className="text-xs font-black uppercase tracking-wider text-[#F4B323]">
                {isHi ? 'कैंपस एवं कार्यालय' : 'Campus & Office'}
              </h4>
              <div className="space-y-2.5 text-xs text-slate-300">
                <div className="flex items-start gap-2.5">
                  <MapPin className="w-4 h-4 text-[#F4B323] flex-shrink-0 mt-0.5" />
                  <span>{schoolLocation}</span>
                </div>
                <div className="flex items-center gap-2.5">
                  <Phone className="w-4 h-4 text-[#F4B323] flex-shrink-0" />
                  <a href={`tel:${primaryPhone}`} className="hover:underline font-bold text-white">
                    +91 {primaryPhone}
                  </a>
                </div>
                <div className="flex items-center gap-2.5">
                  <Mail className="w-4 h-4 text-[#F4B323] flex-shrink-0" />
                  <a href={`mailto:${officialEmail}`} className="hover:underline text-slate-300">
                    {officialEmail}
                  </a>
                </div>
                <div className="flex items-start gap-2.5 text-[11px] text-slate-400 pt-1">
                  <Clock className="w-3.5 h-3.5 text-[#F4B323] flex-shrink-0 mt-0.5" />
                  <span>{isHi ? 'सोमवार – शनिवार: 8:00 पूर्वाह्न – 2:00 अपराह्न' : 'Monday – Saturday: 8:00 AM – 2:00 PM'}</span>
                </div>
              </div>
            </div>

          </div>

          {/* Local Area & SEO Coverage Strip */}
          <div className="mt-8 pt-4 border-t border-[#1E3A60]/60 text-[11px] text-slate-400 flex flex-wrap items-center gap-x-3 gap-y-1">
            <span className="font-bold text-[#F4B323]">{isHi ? 'प्रमुख क्षेत्र:' : 'Areas Served:'}</span>
            <span>{isHi ? 'Mora (मोरा)' : 'Mora'}</span>
            <span>&bull;</span>
            <span>{isHi ? 'Mora Bazar (मोरा बाजार)' : 'Mora Bazar'}</span>
            <span>&bull;</span>
            <span>{isHi ? 'Mairi (मैरी)' : 'Mairi'}</span>
            <span>&bull;</span>
            <span>{isHi ? 'Ratauli (रतौली)' : 'Ratauli'}</span>
            <span>&bull;</span>
            <span>{isHi ? 'Siwan (सीवान, बिहार)' : 'Siwan (Bihar)'}</span>
            <span className="hidden sm:inline">&bull;</span>
            <span className="hidden sm:inline">{isHi ? 'संस्थापक: उदय शंकर पटेल (उदय सर) एवं विशाल पटेल (विशाल सर)' : 'Leadership: Chairman Uday Shankar Patel (Uday Sir) & Director Vishal Patel (Vishal Sir)'}</span>
          </div>

          {/* Bottom Navy Footer Strip (Matching Image) */}
          <div className="mt-6 pt-4 border-t border-[#1E3A60] flex flex-col sm:flex-row items-center justify-between gap-4 text-xs text-slate-400">
            <div>
              &copy; {new Date().getFullYear()} <strong>{isHi ? 'मिशन नवोदय पब्लिक स्कूल' : schoolName}</strong>. {isHi ? 'सर्वाधिकार सुरक्षित।' : 'All rights reserved.'}
            </div>
            <div className="flex items-center gap-3 text-[11px]">
              <span>{schoolLocation}</span>
              <span>&bull;</span>
              <span>{isHi ? 'आधिकारिक संस्थागत प्रबंधन प्रणाली' : 'Official Institutional Management System'}</span>
            </div>
          </div>

        </div>
      </footer>

      {/* ── PARENT-FRIENDLY FLOATING ACTION BAR (1-Click Voice / WhatsApp & Direct Call) ── */}
      <div className="fixed bottom-4 right-4 sm:bottom-6 sm:right-6 z-50 flex items-center gap-2.5 sm:gap-3 print:hidden">
        {/* Call Now Button */}
        <a
          href={`tel:${primaryPhone}`}
          aria-label="Direct Phone Call to School"
          className="group flex items-center gap-2 bg-[#0c2340] hover:bg-[#15345d] text-white pl-3.5 pr-4 py-2.5 rounded-full shadow-2xl border border-white/20 transition-all duration-300 hover:scale-105 active:scale-95"
        >
          <div className="w-8 h-8 rounded-full bg-amber-500 text-white flex items-center justify-center flex-shrink-0 shadow-inner">
            <Phone className="w-4 h-4 text-white" />
          </div>
          <div className="text-left hidden sm:block">
            <div className="text-[10px] uppercase font-bold text-amber-300 leading-none">
              {isHi ? 'सीधे कॉल करें' : 'Call School'}
            </div>
            <div className="text-xs font-black text-white leading-tight mt-0.5">
              +91 {primaryPhone}
            </div>
          </div>
          <span className="sm:hidden text-xs font-bold text-white">{isHi ? 'कॉल करें' : 'Call'}</span>
        </a>

        {/* WhatsApp Voice / Chat Button */}
        <a
          href={`https://wa.me/91${primaryPhone}?text=${encodeURIComponent(
            isHi 
              ? 'नमस्ते सर, मुझे मिशन नवोदय पब्लिक स्कूल (मोरा-मैरी) में एडमिशन / स्कूल की जानकारी चाहिए।' 
              : 'Hello, I want to inquire about admissions / information for Mission Navodaya Public School, Mora-Mairi.'
          )}`}
          target="_blank"
          rel="noopener noreferrer"
          aria-label="Chat or Voice Message on WhatsApp"
          className="group flex items-center gap-2 bg-[#25D366] hover:bg-[#20ba59] text-white pl-3.5 pr-4 py-2.5 rounded-full shadow-2xl shadow-emerald-900/30 transition-all duration-300 hover:scale-105 active:scale-95"
        >
          {/* WhatsApp SVG Icon */}
          <svg className="w-7 h-7 text-white fill-current flex-shrink-0" viewBox="0 0 24 24">
            <path d="M.057 24l1.687-6.163c-1.041-1.804-1.588-3.849-1.587-5.946.003-6.556 5.338-11.891 11.893-11.891 3.181.001 6.167 1.24 8.413 3.488 2.245 2.248 3.481 5.236 3.48 8.414-.003 6.557-5.338 11.892-11.893 11.892-1.99-.001-3.951-.5-5.688-1.448l-6.305 1.654zm6.597-3.807c1.676.995 3.276 1.591 5.392 1.592 5.448 0 9.886-4.434 9.889-9.885.002-5.462-4.415-9.89-9.881-9.892-5.452 0-9.887 4.434-9.889 9.884-.001 2.225.651 3.891 1.746 5.634l-.999 3.648 3.742-.981zm11.387-5.464c-.074-.124-.272-.198-.57-.347-.297-.149-1.758-.868-2.031-.967-.272-.099-.47-.149-.669.149-.198.297-.768.967-.941 1.165-.173.198-.347.223-.644.074-.297-.149-1.255-.462-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.297-.347.446-.521.151-.172.2-.296.3-.495.099-.198.05-.372-.025-.521-.075-.148-.669-1.611-.916-2.206-.242-.579-.487-.501-.669-.51l-.57-.01c-.198 0-.52.074-.792.372s-1.04 1.016-1.04 2.479 1.065 2.876 1.213 3.074c.149.198 2.095 3.2 5.076 4.487.709.306 1.263.489 1.694.626.712.226 1.36.194 1.872.118.571-.085 1.758-.719 2.006-1.413.248-.695.248-1.29.173-1.414z" />
          </svg>
          <div className="text-left hidden sm:block">
            <div className="text-[10px] uppercase font-bold text-emerald-100 leading-none">
              {isHi ? 'ऑडियो / वॉइस मैसेज भेजें' : 'Voice / Chat'}
            </div>
            <div className="text-xs font-black text-white leading-tight mt-0.5">
              WhatsApp
            </div>
          </div>
          <span className="sm:hidden text-xs font-bold text-white">{isHi ? 'व्हाट्सएप' : 'WhatsApp'}</span>
        </a>
      </div>



    
      {/* ── 100% WORKING POPUP: ADMISSION INQUIRY MODAL FOR PARENTS ── */}
      {isAdmissionInquiryOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-3 sm:p-4 bg-black/75 backdrop-blur-xs animate-in fade-in duration-200">
          <div className="bg-white rounded-3xl max-w-lg w-full max-h-[92vh] overflow-y-auto border border-slate-200 shadow-2xl p-5 sm:p-7 relative text-[#0c2340]">
            
            {/* Close button */}
            <button
              type="button"
              onClick={() => { setIsAdmissionInquiryOpen(false); setInquirySuccess(null); }}
              className="absolute top-4 right-4 w-9 h-9 rounded-full bg-slate-100 hover:bg-slate-200 text-slate-700 flex items-center justify-center font-bold transition-colors cursor-pointer"
            >
              <X className="w-5 h-5" />
            </button>

            {inquirySuccess ? (
              /* Success Screen */
              <div className="text-center py-6 space-y-4">
                <div className="w-16 h-16 rounded-full bg-emerald-100 text-emerald-600 flex items-center justify-center mx-auto shadow-inner">
                  <CheckCircle2 className="w-10 h-10" />
                </div>
                <h3 className="text-xl font-black text-[#0c2340]">
                  {isHi ? 'पूछताछ सफलतापूर्वक जमा हो गई!' : 'Admission Inquiry Submitted!'}
                </h3>
                <div className="p-3.5 rounded-2xl bg-amber-500/10 border border-amber-500/20 text-xs text-[#0c2340] space-y-1">
                  <div className="font-bold">{isHi ? 'आपकी संदर्भ संख्या (Reference No):' : 'Application Reference ID:'}</div>
                  <div className="text-base font-black text-amber-700 font-mono tracking-wide">{inquirySuccess}</div>
                </div>
                <p className="text-xs text-slate-600 leading-relaxed max-w-sm mx-auto">
                  {isHi
                    ? 'मिशन नवोदय पब्लिक स्कूल (मोरा-मैरी) की एडमिशन टीम जल्द ही आपसे संपर्क करेगी।'
                    : 'The admission desk of Mission Navodaya Public School, Mora-Mairi will contact you shortly.'}
                </p>
                <div className="pt-2 flex flex-col sm:flex-row gap-2 justify-center">
                  <a
                    href={`https://wa.me/91${primaryPhone}?text=${encodeURIComponent(
                      isHi
                        ? `नमस्ते सर, मैंने स्कूल में दाखिले के लिए ऑनलाइन फॉर्म भरा है (Ref: ${inquirySuccess})। कृपया जानकारी दें।`
                        : `Hello Sir, I submitted an admission inquiry online (Ref: ${inquirySuccess}). Kindly assist with admission details.`
                    )}`}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="px-5 py-2.5 rounded-xl bg-[#25D366] text-white font-bold text-xs flex items-center justify-center gap-2 shadow-md"
                  >
                    <span>{isHi ? 'व्हाट्सएप पर बात करें' : 'Chat on WhatsApp'}</span>
                  </a>
                  <button
                    type="button"
                    onClick={() => { setIsAdmissionInquiryOpen(false); setInquirySuccess(null); }}
                    className="px-5 py-2.5 rounded-xl bg-slate-100 hover:bg-slate-200 text-[#0c2340] font-bold text-xs cursor-pointer"
                  >
                    {isHi ? 'बंद करें' : 'Close'}
                  </button>
                </div>
              </div>
            ) : (
              /* Inquiry Form */
              <form
                onSubmit={async (e) => {
                  e.preventDefault();
                  if (!inquiryForm.studentName || !inquiryForm.mobile) {
                    alert(isHi ? 'कृपया विद्यार्थी का नाम और मोबाइल नंबर भरें।' : 'Please enter Student Name and Mobile.');
                    return;
                  }
                  setInquiryLoading(true);
                  const refId = `MNP-ADM-${Date.now().toString().slice(-6)}`;
                  try {
                    const { db } = await import('../lib/firebase');
                    const { collection, addDoc, serverTimestamp } = await import('firebase/firestore');
                    await addDoc(collection(db, 'admissionEnquiries'), {
                      refNo: refId,
                      studentName: inquiryForm.studentName,
                      fatherName: inquiryForm.fatherName,
                      mobile: inquiryForm.mobile,
                      admissionClass: inquiryForm.admissionClass,
                      address: inquiryForm.address,
                      message: inquiryForm.message,
                      status: 'pending',
                      createdAt: serverTimestamp()
                    });
                  } catch (err) {
                    console.warn('Saved inquiry locally:', err);
                  }
                  setInquiryLoading(false);
                  setInquirySuccess(refId);
                }}
                className="space-y-4 pt-1"
              >
                <div className="flex items-center gap-3 border-b border-slate-100 pb-3">
                  <div className="w-10 h-10 rounded-xl bg-amber-500/10 text-amber-600 flex items-center justify-center font-bold">
                    <GraduationCap className="w-5 h-5 text-[#F4B323]" />
                  </div>
                  <div>
                    <h3 className="text-base font-black text-[#0c2340]">
                      {isHi ? 'प्रवेश पूछताछ फॉर्म (सत्र 2026-27)' : 'Admission Inquiry Form 2026-27'}
                    </h3>
                    <p className="text-[11px] text-slate-500">
                      {isHi ? 'मोरा-मैरी कैंपस · नर्सरी से 8वीं कक्षा' : 'Mora-Mairi Campus · Classes Nursery to 8th'}
                    </p>
                  </div>
                </div>

                <div className="space-y-3 text-xs">
                  <div>
                    <label className="block font-bold text-slate-700 mb-1">
                      {isHi ? 'विद्यार्थी का नाम (Student Name) *' : 'Student Name *'}
                    </label>
                    <input
                      type="text"
                      required
                      placeholder={isHi ? 'जैसे: राहुल कुमार' : 'e.g. Rahul Kumar'}
                      value={inquiryForm.studentName}
                      onChange={(e) => setInquiryForm({ ...inquiryForm, studentName: e.target.value })}
                      className="w-full px-3.5 py-2.5 rounded-xl border border-slate-200 focus:border-amber-500 focus:ring-1 focus:ring-amber-500 outline-none text-xs"
                    />
                  </div>

                  <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                    <div>
                      <label className="block font-bold text-slate-700 mb-1">
                        {isHi ? 'पिता / अभिभावक का नाम' : 'Father / Guardian Name'}
                      </label>
                      <input
                        type="text"
                        placeholder={isHi ? 'जैसे: राजेश कुमार' : 'e.g. Rajesh Kumar'}
                        value={inquiryForm.fatherName}
                        onChange={(e) => setInquiryForm({ ...inquiryForm, fatherName: e.target.value })}
                        className="w-full px-3.5 py-2.5 rounded-xl border border-slate-200 focus:border-amber-500 focus:ring-1 focus:ring-amber-500 outline-none text-xs"
                      />
                    </div>

                    <div>
                      <label className="block font-bold text-slate-700 mb-1">
                        {isHi ? 'मोबाइल नंबर (Mobile) *' : 'Mobile Number *'}
                      </label>
                      <input
                        type="tel"
                        required
                        maxLength={10}
                        placeholder="10-digit number"
                        value={inquiryForm.mobile}
                        onChange={(e) => setInquiryForm({ ...inquiryForm, mobile: e.target.value.replace(/\D/g, '') })}
                        className="w-full px-3.5 py-2.5 rounded-xl border border-slate-200 focus:border-amber-500 focus:ring-1 focus:ring-amber-500 outline-none text-xs"
                      />
                    </div>
                  </div>

                  <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                    <div>
                      <label className="block font-bold text-slate-700 mb-1">
                        {isHi ? 'कक्षा (Admission Class)' : 'Class'}
                      </label>
                      <select
                        value={inquiryForm.admissionClass}
                        onChange={(e) => setInquiryForm({ ...inquiryForm, admissionClass: e.target.value })}
                        className="w-full px-3.5 py-2.5 rounded-xl border border-slate-200 focus:border-amber-500 outline-none text-xs bg-white"
                      >
                        {['Nursery', 'LKG', 'UKG', 'Class 1st', 'Class 2nd', 'Class 3rd', 'Class 4th', 'Class 5th', 'Class 6th', 'Class 7th', 'Class 8th'].map(c => (
                          <option key={c} value={c}>{c}</option>
                        ))}
                      </select>
                    </div>

                    <div>
                      <label className="block font-bold text-slate-700 mb-1">
                        {isHi ? 'गांव / पता (Village / Address)' : 'Village / Address'}
                      </label>
                      <input
                        type="text"
                        placeholder={isHi ? 'जैसे: मोरा / मैरी / रतौली' : 'e.g. Mora / Mairi / Siwan'}
                        value={inquiryForm.address}
                        onChange={(e) => setInquiryForm({ ...inquiryForm, address: e.target.value })}
                        className="w-full px-3.5 py-2.5 rounded-xl border border-slate-200 focus:border-amber-500 focus:ring-1 focus:ring-amber-500 outline-none text-xs"
                      />
                    </div>
                  </div>

                  <div>
                    <label className="block font-bold text-slate-700 mb-1">
                      {isHi ? 'कोई संदेश या प्रश्न (Message / Remarks)' : 'Message (Optional)'}
                    </label>
                    <textarea
                      rows={2}
                      placeholder={isHi ? 'दाखिले या बस सुविधा से जुड़ा कोई सवाल...' : 'Any queries about admission, fees, or transport...'}
                      value={inquiryForm.message}
                      onChange={(e) => setInquiryForm({ ...inquiryForm, message: e.target.value })}
                      className="w-full px-3.5 py-2 rounded-xl border border-slate-200 focus:border-amber-500 outline-none text-xs"
                    />
                  </div>
                </div>

                <div className="pt-2 flex items-center justify-end gap-2.5 border-t border-slate-100">
                  <button
                    type="button"
                    onClick={() => setIsAdmissionInquiryOpen(false)}
                    className="px-4 py-2.5 rounded-xl text-slate-600 font-bold hover:bg-slate-100 transition-colors cursor-pointer text-xs"
                  >
                    {isHi ? 'रद्द करें' : 'Cancel'}
                  </button>
                  <button
                    type="submit"
                    disabled={inquiryLoading}
                    className="px-6 py-2.5 rounded-xl bg-[#F4B323] hover:bg-amber-400 text-[#0c2340] font-black text-xs transition-all shadow-md cursor-pointer flex items-center gap-2 disabled:opacity-50"
                  >
                    <span>{inquiryLoading ? (isHi ? 'जमा हो रहा है...' : 'Submitting...') : (isHi ? 'पूछताछ जमा करें' : 'Submit Inquiry')}</span>
                    <ArrowRight className="w-4 h-4" />
                  </button>
                </div>
              </form>
            )}

          </div>
        </div>
      )}

</div>
  );
}
