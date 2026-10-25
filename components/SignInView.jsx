'use client';

import React, { useState, useEffect } from 'react';
import { useSchoolStore } from '../lib/store';
import { translations } from '../lib/translations';
import {
  GraduationCap, Mail, Lock, Eye, EyeOff, ShieldCheck,
  School, ArrowRight, AlertCircle, CheckCircle2,
  User, ChevronDown, Phone, Hash, ArrowLeft, BookOpen,
  Users, CalendarCheck, CreditCard, Shield, FileText, CheckCircle,
  Award, Heart, Compass, Sparkles, Building, Quote, Check,
  Activity, Monitor, Trophy, HelpCircle, MapPin, Clock, MessageSquare,
  Globe, Briefcase, Menu, X, ExternalLink, Calendar, Star,
  TrendingUp, CheckCircle as CheckIcon
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
    navigate,
    language = 'en',
    toggleLanguage,
    setSignUpFormTab,
    openEnquiriesModal,
    setIsEnquiriesModalOpen
  } = useSchoolStore();

  const t = translations[language] || translations.en;
  const isHi = language === 'hi';

  const [isLoginModalOpen, setIsLoginModalOpen] = useState(false);
  const [isMobileMenuOpen, setIsMobileMenuOpen] = useState(false);
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

  // Institution Verified Details from Official School Banner
  const schoolName = settings?.instituteName || settings?.schoolName || 'MISSION NAVODAYA PUBLIC SCHOOL';
  const schoolSubtitle = 'PUBLIC SCHOOL, MORA';
  const schoolLocation = 'Mora Bazar, Siwan (Bihar)';
  const logoSrc = settings?.logoUrl || settings?.logoPath || settings?.logo || '/logo.png';
  const primaryPhone = '9162724680';
  const altPhone = settings?.phone || settings?.mobile || '8603481865';
  const officialEmail = settings?.email || 'mnpschooledu@gmail.com';
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

  const closeMobileMenuAndNavigate = (hash) => {
    setIsMobileMenuOpen(false);
    const el = document.querySelector(hash);
    if (el) {
      el.scrollIntoView({ behavior: 'smooth' });
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');
    setLoading(true);

    try {
      if (role === 'parent') {
        if (!parentAdmissionNo.trim()) {
          throw new Error(language === 'hi' ? 'कृपया छात्र प्रवेश संख्या या रोल नंबर दर्ज करें।' : "Please enter your child's Admission Number or Roll Number.");
        }
        await parentSignIn('', parentAdmissionNo.trim(), parentMobile.trim());
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
                  {isHi ? `नर्सरी से 8वीं तक नामांकन जारी · मोरा बाजार, सीवान (बिहार)` : `Now Enrolling ${admissionClasses} · ${schoolLocation}`}
                </span>
              </>
            ) : (
              <>
                <span className="px-2.5 py-0.5 rounded-full bg-slate-700 text-slate-200 text-[10px] font-bold uppercase tracking-wider border border-slate-600">
                  {isHi ? `सत्र ${currentSession}` : `Session ${currentSession}`}
                </span>
                <span className="text-slate-200">
                  {isHi ? `शैक्षणिक सत्र प्रगति पर है · मोरा बाजार, सीवान (बिहार)` : `Academic Session in Progress · ${schoolLocation}`}
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
        <div className="w-full px-4 sm:px-6 lg:px-8 h-18 sm:h-20 flex items-center justify-between gap-4">
          
          {/* Brand Seal, School Title & Subtitle */}
          <a href="#about" className="flex items-center gap-3 sm:gap-3.5 min-w-0 flex-shrink-0 group">
            <div className="w-11 h-11 sm:w-12 sm:h-12 flex items-center justify-center flex-shrink-0 transition-transform group-hover:scale-105 drop-shadow-md">
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
            <div className="min-w-0">
              <div className="text-sm sm:text-base lg:text-lg font-black tracking-tight text-white leading-tight truncate uppercase">
                {isHi ? 'मिशन नवोदय पब्लिक स्कूल' : schoolName}
              </div>
              <div className="text-[10px] sm:text-[11px] font-bold text-[#F4B323] tracking-wide truncate flex items-center gap-1.5 mt-0.5">
                <span className="w-1.5 h-1.5 rounded-full bg-[#F4B323] animate-pulse" />
                <span>{isHi ? `मोरा बाजार, सीवान (बिहार) · सत्र ${currentSession}` : `Mora Bazar, Siwan (Bihar) · Session ${currentSession}`}</span>
              </div>
            </div>
          </a>

          {/* Desktop Navigation Links */}
          <nav className="hidden xl:flex items-center gap-6 text-[13px] font-bold text-slate-200">
            <a href="#about" className="hover:text-[#F4B323] transition-colors py-1">{isHi ? 'विद्यालय परिचय' : 'About School'}</a>
            <a href="#admissions" className="hover:text-[#F4B323] transition-colors py-1 text-[#F4B323]">{isHi ? 'प्रवेश 2026–27' : 'Admissions 2026–27'}</a>
            <a href="#features" className="hover:text-[#F4B323] transition-colors py-1">{isHi ? 'विशेषताएं' : 'Campus Features'}</a>
            <a href="#leadership" className="hover:text-[#F4B323] transition-colors py-1">{isHi ? 'नेतृत्व' : 'Leadership'}</a>
            <a href="#campus-gallery" className="hover:text-[#F4B323] transition-colors py-1">{isHi ? 'गैलरी' : 'Gallery'}</a>
            <a href="#reviews" className="hover:text-[#F4B323] transition-colors py-1">{isHi ? 'अभिभावक समीक्षाएं' : 'Parent Reviews'}</a>
            <a href="#contact" className="hover:text-[#F4B323] transition-colors py-1">{isHi ? 'संपर्क' : 'Contact'}</a>
          </nav>

          {/* Desktop Action Buttons */}
          <div className="hidden md:flex items-center gap-2 sm:gap-2.5 flex-shrink-0">
            {/* Language Toggle */}
            <button
              type="button"
              onClick={toggleLanguage}
              className="inline-flex items-center gap-1.5 px-2.5 py-1.5 rounded-xl bg-white/10 hover:bg-white/15 border border-white/20 text-xs font-bold text-slate-100 transition-all cursor-pointer"
              title="Toggle Language"
            >
              <Globe className="w-3.5 h-3.5 text-[#F4B323]" />
              <span>{isHi ? 'English' : 'हिन्दी'}</span>
            </button>

            {/* Faculty / Teacher Desk Button */}
            <button
              type="button"
              onClick={() => openPortalLogin('teacher')}
              className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-bold text-white bg-white/10 hover:bg-white/20 border border-white/20 transition-all cursor-pointer shadow-2xs"
              title="Faculty & Teacher Console"
            >
              <GraduationCap className="w-3.5 h-3.5 text-[#F4B323]" />
              <span>{isHi ? 'शिक्षक पटल' : 'Faculty Desk'}</span>
            </button>

            {/* Parent Login */}
            <button
              type="button"
              onClick={() => openPortalLogin('parent')}
              className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-bold text-white bg-white/10 hover:bg-white/20 border border-white/20 transition-all cursor-pointer shadow-2xs"
            >
              <Users className="w-3.5 h-3.5 text-[#F4B323]" />
              <span>{isHi ? 'अभिभावक पोर्टल' : 'Parent Portal'}</span>
            </button>

            {/* Staff / Principal Login */}
            <button
              type="button"
              onClick={() => openPortalLogin('principal')}
              className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-bold text-white bg-white/10 hover:bg-white/20 border border-white/20 transition-all cursor-pointer shadow-2xs"
            >
              <ShieldCheck className="w-3.5 h-3.5 text-[#F4B323]" />
              <span>{isHi ? 'पोर्टल लॉगिन' : 'Portal Login'}</span>
            </button>

            {/* Online Admission Form Button */}
            <button
              type="button"
              onClick={() => {
                if (setSignUpFormTab) setSignUpFormTab('student');
                navigate('/signup?tab=admission');
              }}
              className="inline-flex items-center gap-2 px-3.5 py-1.5 rounded-xl text-xs font-black text-[#091A32] bg-[#F4B323] hover:bg-[#e0a21a] shadow-md hover:shadow-lg transition-all cursor-pointer flex-shrink-0"
            >
              <Sparkles className="w-3.5 h-3.5 text-[#091A32]" />
              <span>{isHi ? 'ऑनलाइन प्रवेश' : 'Online Admission'}</span>
            </button>
          </div>

          {/* Mobile Right Action Area (Language + Hamburger) */}
          <div className="flex md:hidden items-center gap-2">
            <button
              type="button"
              onClick={toggleLanguage}
              className="inline-flex items-center gap-1 px-2.5 py-1.5 rounded-lg bg-white/10 text-xs font-bold text-white border border-white/20"
              title="Toggle Language"
            >
              <Globe className="w-3 h-3 text-[#F4B323]" />
              <span className="text-[11px]">{isHi ? 'EN' : 'हिन्दी'}</span>
            </button>

            <button
              type="button"
              onClick={() => setIsMobileMenuOpen(prev => !prev)}
              aria-label="Toggle Mobile Navigation Menu"
              className="p-2.5 rounded-xl bg-white/10 hover:bg-white/20 text-white border border-white/20 transition-colors cursor-pointer flex items-center justify-center"
            >
              {isMobileMenuOpen ? <X className="w-5 h-5 text-[#F4B323]" /> : <Menu className="w-5 h-5" />}
            </button>
          </div>

        </div>

        {/* Mobile Slide-down Drawer Menu */}
        {isMobileMenuOpen && (
          <div className="md:hidden fixed inset-x-0 top-18 sm:top-20 bottom-0 bg-[#091A32]/98 backdrop-blur-lg z-50 overflow-y-auto px-5 py-6 flex flex-col justify-between border-t border-[#1E3A60] animate-in slide-in-from-top-4 duration-200 text-white">
            <div className="space-y-6">
              <div className="p-3 rounded-xl bg-[#102747] border border-[#1E3A60] flex items-center gap-2.5 text-xs font-bold text-[#F4B323]">
                <Sparkles className="w-4 h-4 flex-shrink-0 text-[#F4B323]" />
                <span>{isHi ? 'सत्र 2026–27 · नर्सरी से 8वीं तक प्रवेश प्रारंभ' : 'Session 2026–27 · Nursery to 8th Admissions Open'}</span>
              </div>

              <div className="space-y-1 font-bold text-sm text-slate-200">
                <button
                  type="button"
                  onClick={() => closeMobileMenuAndNavigate('#about')}
                  className="w-full text-left px-3 py-2.5 rounded-xl hover:bg-white/10 transition-colors cursor-pointer flex items-center justify-between"
                >
                  <span>{isHi ? 'विद्यालय परिचय' : 'About School'}</span>
                  <ArrowRight className="w-4 h-4 text-slate-400" />
                </button>
                <button
                  type="button"
                  onClick={() => closeMobileMenuAndNavigate('#admissions')}
                  className="w-full text-left px-3 py-2.5 rounded-xl hover:bg-white/10 transition-colors cursor-pointer flex items-center justify-between text-[#F4B323]"
                >
                  <span>{isHi ? 'प्रवेश 2026–27 (नर्सरी – 8वीं)' : 'Admissions 2026–27 (Nursery – 8th)'}</span>
                  <ArrowRight className="w-4 h-4 text-[#F4B323]" />
                </button>
                <button
                  type="button"
                  onClick={() => closeMobileMenuAndNavigate('#features')}
                  className="w-full text-left px-3 py-2.5 rounded-xl hover:bg-white/10 transition-colors cursor-pointer flex items-center justify-between"
                >
                  <span>{isHi ? '5 प्रमुख विशेषताएं' : '5 Signature Features'}</span>
                  <ArrowRight className="w-4 h-4 text-slate-400" />
                </button>
                <button
                  type="button"
                  onClick={() => closeMobileMenuAndNavigate('#leadership')}
                  className="w-full text-left px-3 py-2.5 rounded-xl hover:bg-white/10 transition-colors cursor-pointer flex items-center justify-between"
                >
                  <span>{isHi ? 'विद्यालय नेतृत्व' : 'School Leadership'}</span>
                  <ArrowRight className="w-4 h-4 text-slate-400" />
                </button>
                <button
                  type="button"
                  onClick={() => closeMobileMenuAndNavigate('#facilities')}
                  className="w-full text-left px-3 py-2.5 rounded-xl hover:bg-white/10 transition-colors cursor-pointer flex items-center justify-between"
                >
                  <span>{isHi ? 'परिसर सुविधाएं' : 'Campus Facilities'}</span>
                  <ArrowRight className="w-4 h-4 text-slate-400" />
                </button>
                <button
                  type="button"
                  onClick={() => closeMobileMenuAndNavigate('#campus-gallery')}
                  className="w-full text-left px-3 py-2.5 rounded-xl hover:bg-white/10 transition-colors cursor-pointer flex items-center justify-between"
                >
                  <span>{isHi ? 'फोटो गैलरी' : 'Photo Gallery'}</span>
                  <ArrowRight className="w-4 h-4 text-slate-400" />
                </button>
                <button
                  type="button"
                  onClick={() => closeMobileMenuAndNavigate('#reviews')}
                  className="w-full text-left px-3 py-2.5 rounded-xl hover:bg-white/10 transition-colors cursor-pointer flex items-center justify-between text-[#F4B323]"
                >
                  <span>{isHi ? 'अभिभावक समीक्षाएं' : 'Parent & Community Reviews'}</span>
                  <ArrowRight className="w-4 h-4 text-[#F4B323]" />
                </button>
                <button
                  type="button"
                  onClick={() => closeMobileMenuAndNavigate('#contact')}
                  className="w-full text-left px-3 py-2.5 rounded-xl hover:bg-white/10 transition-colors cursor-pointer flex items-center justify-between"
                >
                  <span>{isHi ? 'हेल्पलाइन एवं संपर्क' : 'Office Helpline & Contact'}</span>
                  <ArrowRight className="w-4 h-4 text-slate-400" />
                </button>
              </div>

              <div className="space-y-3 pt-2">
                <button
                  type="button"
                  onClick={() => {
                    setIsMobileMenuOpen(false);
                    if (setSignUpFormTab) setSignUpFormTab('student');
                    navigate('/signup?tab=admission');
                  }}
                  className="w-full py-3.5 px-4 rounded-xl bg-[#F4B323] hover:bg-[#e0a21a] text-[#091A32] font-black text-sm flex items-center justify-center gap-2 shadow-md cursor-pointer"
                >
                  <Sparkles className="w-4 h-4 text-[#091A32]" />
                  <span>{isHi ? 'ऑनलाइन प्रवेश प्रपत्र' : 'Online Admission Form'}</span>
                </button>

                <div className="grid grid-cols-3 gap-2">
                  <button
                    type="button"
                    onClick={() => openPortalLogin('teacher')}
                    className="py-2.5 px-1.5 rounded-xl bg-white/12 hover:bg-white/20 border border-white/25 text-white font-bold text-[11px] flex flex-col items-center justify-center gap-1 cursor-pointer text-center"
                  >
                    <GraduationCap className="w-4 h-4 text-[#F4B323]" />
                    <span>{isHi ? 'शिक्षक' : 'Faculty'}</span>
                  </button>

                  <button
                    type="button"
                    onClick={() => openPortalLogin('parent')}
                    className="py-2.5 px-1.5 rounded-xl bg-white/12 hover:bg-white/20 border border-white/25 text-white font-bold text-[11px] flex flex-col items-center justify-center gap-1 cursor-pointer text-center"
                  >
                    <Users className="w-4 h-4 text-[#F4B323]" />
                    <span>{isHi ? 'अभिभावक' : 'Parents'}</span>
                  </button>

                  <button
                    type="button"
                    onClick={() => openPortalLogin('principal')}
                    className="py-2.5 px-1.5 rounded-xl bg-white/12 hover:bg-white/20 border border-white/25 text-white font-bold text-[11px] flex flex-col items-center justify-center gap-1 cursor-pointer text-center"
                  >
                    <ShieldCheck className="w-4 h-4 text-[#F4B323]" />
                    <span>{isHi ? 'प्रधानाचार्य' : 'Principal'}</span>
                  </button>
                </div>
              </div>
            </div>

            <div className="pt-6 border-t border-white/10 text-center text-xs text-slate-400 space-y-1">
              <div>{isHi ? 'कार्यालय कॉल/व्हाट्सएप:' : 'Office Call/WhatsApp:'} <a href={`tel:${primaryPhone}`} className="text-[#F4B323] font-bold">+91 {primaryPhone}</a></div>
              <div>{isHi ? 'मोरा बाजार, सीवान (बिहार)' : schoolLocation}</div>
            </div>
          </div>
        )}
      </header>

      {/* ───────────────────────────────────────────────────────────── */}
      {/* 3. HERO SECTION FEATURING THE PANORAMIC INSTITUTIONAL BANNER  */}
      {/* ───────────────────────────────────────────────────────────── */}
      <main className="flex-1 w-full max-w-full overflow-x-hidden">
        {!isLoginModalOpen ? (
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
                      <span>{isHi ? 'सीबीएसई पाठ्यक्रम प्रारूप • अंग्रेजी माध्यम सह-शिक्षा' : 'CBSE Curriculum Pattern • English Medium Co-Educational'}</span>
                    </div>

                    <h1 className="text-2xl sm:text-4xl lg:text-[46px] font-black text-white tracking-tight uppercase leading-[1.12] drop-shadow-md break-words max-w-full">
                      {isHi ? (
                        <>मिशन नवोदय <span className="text-[#F4B323]">पब्लिक स्कूल</span>, मोरा</>
                      ) : (
                        <>MISSION NAVODAYA <span className="text-[#F4B323]">PUBLIC SCHOOL</span>, MORA</>
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
                        <span>{isHi ? 'मोरा बाज़ार, सीवान (बिहार)' : 'Mora Bazar, Siwan (Bihar)'}</span>
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

                {/* ── DYNAMIC ADMISSION BANNER CARD (Controlled from Settings / App) ── */}
                {isAdmissionOpen ? (
                  <div id="admissions" className="mt-6 p-4 sm:p-5 rounded-2xl bg-gradient-to-r from-[#0C223F]/92 via-[#112F56]/88 to-[#0C223F]/92 border-2 border-[#F4B323]/50 backdrop-blur-md shadow-2xl flex flex-col lg:flex-row items-center justify-between gap-4 scroll-mt-24">
                    {/* Left: Admissions Open Title + Session + Classes */}
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
                            {isHi ? 'नामांकन प्रारंभ' : 'ADMISSIONS OPEN'}
                          </span>
                          <span className="text-xs font-black px-2.5 py-0.5 rounded-md bg-[#F4B323] text-[#091A32] tracking-wider uppercase shadow-xs">
                            {isHi ? `सत्र ${currentSession}` : `SESSION ${currentSession}`}
                          </span>
                        </div>
                        <div className="text-xs text-[#F4B323] font-bold">
                          {isHi ? `${admissionClasses} • नए दाखिले के लिए सीमित सीटें उपलब्ध` : `${admissionClasses} • Limited Seats Available for New Enrolments`}
                        </div>
                      </div>
                    </div>

                    {/* Right: Action CTAs */}
                    <div className="flex flex-wrap items-center justify-center gap-3 w-full lg:w-auto flex-shrink-0">
                      <button
                        type="button"
                        onClick={() => {
                          if (setSignUpFormTab) setSignUpFormTab('student');
                          navigate('/signup?tab=admission');
                        }}
                        className="flex-1 sm:flex-initial px-6 py-3.5 rounded-xl bg-[#F4B323] hover:bg-[#e0a21a] text-[#091A32] font-black text-xs sm:text-sm shadow-xl hover:shadow-2xl transition-all flex items-center justify-center gap-2 cursor-pointer"
                      >
                        <FileText className="w-4 h-4 text-[#091A32]" />
                        <span>{isHi ? 'ऑनलाइन एडमिशन फॉर्म →' : 'Online Admission Form →'}</span>
                      </button>

                      <a
                        href="#contact"
                        className="flex-1 sm:flex-initial px-5 py-3.5 rounded-xl bg-white/10 hover:bg-white/20 text-white font-bold text-xs sm:text-sm border border-white/25 backdrop-blur-sm transition-all flex items-center justify-center gap-2 cursor-pointer"
                      >
                        <Calendar className="w-4 h-4 text-[#F4B323]" />
                        <span>{isHi ? 'कैंपस विज़िट बुक करें' : 'Book Campus Visit'}</span>
                      </a>
                    </div>
                  </div>
                ) : (
                  <div id="admissions" className="mt-6 p-4 sm:p-5 rounded-2xl bg-gradient-to-r from-[#0C223F]/92 via-[#112F56]/88 to-[#0C223F]/92 border border-white/20 backdrop-blur-md shadow-2xl flex flex-col lg:flex-row items-center justify-between gap-4 scroll-mt-24">
                    {/* Left: Academic Session in Progress */}
                    <div className="flex flex-col sm:flex-row items-center sm:items-start gap-3.5 text-center sm:text-left">
                      <div className="w-12 h-12 rounded-xl bg-white/10 text-[#F4B323] border border-white/20 flex items-center justify-center flex-shrink-0 shadow-lg">
                        <School className="w-6 h-6 text-[#F4B323]" />
                      </div>
                      <div className="space-y-0.5">
                        <div className="flex flex-wrap items-center justify-center sm:justify-start gap-2">
                          <span className="text-lg sm:text-xl lg:text-2xl font-black text-white tracking-tight uppercase">
                            {isHi ? `शैक्षणिक सत्र ${currentSession}` : `ACADEMIC SESSION ${currentSession}`}
                          </span>
                          <span className="text-xs font-bold px-2.5 py-0.5 rounded-md bg-slate-700/80 text-slate-200 border border-slate-600 tracking-wider uppercase">
                            {isHi ? 'नामांकन बंद' : 'Admissions Closed'}
                          </span>
                        </div>
                        <div className="text-xs text-slate-300 font-medium">
                          {isHi
                            ? 'कक्षाएं नियमित रूप से जारी हैं • आगामी सत्र या कैंपस टूर हेतु पूछताछ करें'
                            : 'Academic curriculum in progress • Enquire now for next academic session or campus tour'}
                        </div>
                      </div>
                    </div>

                    {/* Right: Action CTAs when closed */}
                    <div className="flex flex-wrap items-center justify-center gap-3 w-full lg:w-auto flex-shrink-0">
                      <button
                        type="button"
                        onClick={() => {
                          if (openEnquiriesModal) {
                            openEnquiriesModal('admissions');
                          } else if (setIsEnquiriesModalOpen) {
                            setIsEnquiriesModalOpen(true);
                          }
                        }}
                        className="flex-1 sm:flex-initial px-6 py-3.5 rounded-xl bg-[#F4B323] hover:bg-[#e0a21a] text-[#091A32] font-black text-xs sm:text-sm shadow-xl hover:shadow-2xl transition-all flex items-center justify-center gap-2 cursor-pointer"
                      >
                        <MessageSquare className="w-4 h-4 text-[#091A32]" />
                        <span>{isHi ? 'अगले सत्र हेतु पूछताछ →' : 'Enquire for Next Session →'}</span>
                      </button>

                      <a
                        href="#campus-gallery"
                        className="flex-1 sm:flex-initial px-5 py-3.5 rounded-xl bg-white/10 hover:bg-white/20 text-white font-bold text-xs sm:text-sm border border-white/25 backdrop-blur-sm transition-all flex items-center justify-center gap-2 cursor-pointer"
                      >
                        <Building className="w-4 h-4 text-[#F4B323]" />
                        <span>{isHi ? 'कैंपस जीवन देखें' : 'Explore Campus Life'}</span>
                      </a>
                    </div>
                  </div>
                )}

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
                <div className="bg-white rounded-2xl p-5 border border-[#E2E8F0] shadow-xs hover:shadow-md transition-all space-y-3 group">
                  <div className="w-12 h-12 rounded-xl bg-amber-50 text-amber-700 flex items-center justify-center font-bold group-hover:scale-105 transition-transform shadow-2xs">
                    <BookOpen className="w-6 h-6 text-[#F4B323]" />
                  </div>
                  <div>
                    <h3 className="text-sm font-black text-[#14243B]">{isHi ? 'समृद्ध पुस्तकालय' : 'Enriched Library'}</h3>
                    <p className="text-xs text-[#65748B] mt-1 leading-relaxed">
                      {isHi
                        ? 'ज्ञानवर्धक पुस्तकों, NCERT पाठ्यपुस्तकों और प्रेरक पठन सामग्रियों का विशाल संग्रह।'
                        : 'Wide range of books, NCERT textbooks, and inspiring learning resources.'}
                    </p>
                  </div>
                </div>

                {/* 2. Computer & Tech Wing */}
                <div className="bg-white rounded-2xl p-5 border border-[#E2E8F0] shadow-xs hover:shadow-md transition-all space-y-3 group">
                  <div className="w-12 h-12 rounded-xl bg-blue-50 text-blue-700 flex items-center justify-center font-bold group-hover:scale-105 transition-transform shadow-2xs">
                    <Monitor className="w-6 h-6 text-blue-600" />
                  </div>
                  <div>
                    <h3 className="text-sm font-black text-[#14243B]">{isHi ? 'कंप्यूटर व तकनीक विंग' : 'Computer & Tech Wing'}</h3>
                    <p className="text-xs text-[#65748B] mt-1 leading-relaxed">
                      {isHi
                        ? 'आधुनिक डिजिटल शिक्षा, सुसज्जित कंप्यूटर लैब और प्रायोगिक तकनीकी कौशल।'
                        : 'Modern digital learning, dedicated computer lab, and practical tech skills.'}
                    </p>
                  </div>
                </div>

                {/* 3. Sports & Physical Fitness */}
                <div className="bg-white rounded-2xl p-5 border border-[#E2E8F0] shadow-xs hover:shadow-md transition-all space-y-3 group">
                  <div className="w-12 h-12 rounded-xl bg-emerald-50 text-emerald-700 flex items-center justify-center font-bold group-hover:scale-105 transition-transform shadow-2xs">
                    <Trophy className="w-6 h-6 text-emerald-600" />
                  </div>
                  <div>
                    <h3 className="text-sm font-black text-[#14243B]">{isHi ? 'खेलकूद एवं शारीरिक विकास' : 'Sports & Physical Fitness'}</h3>
                    <p className="text-xs text-[#65748B] mt-1 leading-relaxed">
                      {isHi
                        ? 'फुटबॉल, एथलेटिक्स और शारीरिक तंदुरुस्ती के लिए विशाल खुला खेल का मैदान।'
                        : 'Spacious open playground for football, athletics, and overall development.'}
                    </p>
                  </div>
                </div>

                {/* 4. Safe & Secure Campus */}
                <div className="bg-white rounded-2xl p-5 border border-[#E2E8F0] shadow-xs hover:shadow-md transition-all space-y-3 group">
                  <div className="w-12 h-12 rounded-xl bg-indigo-50 text-indigo-700 flex items-center justify-center font-bold group-hover:scale-105 transition-transform shadow-2xs">
                    <ShieldCheck className="w-6 h-6 text-indigo-600" />
                  </div>
                  <div>
                    <h3 className="text-sm font-black text-[#14243B]">{isHi ? 'सुरक्षित एवं अनुशासित परिसर' : 'Safe & Secure Campus'}</h3>
                    <p className="text-xs text-[#65748B] mt-1 leading-relaxed">
                      {isHi
                        ? 'चारदीवारी से सुरक्षित, अनुशासित और स्नेहमयी वातावरण जिससे बच्चे सुरक्षित रहें।'
                        : 'A disciplined, walled, and caring environment ensuring student safety.'}
                    </p>
                  </div>
                </div>

                {/* 5. Dedicated Teachers */}
                <div className="bg-white rounded-2xl p-5 border border-[#E2E8F0] shadow-xs hover:shadow-md transition-all space-y-3 group">
                  <div className="w-12 h-12 rounded-xl bg-purple-50 text-purple-700 flex items-center justify-center font-bold group-hover:scale-105 transition-transform shadow-2xs">
                    <Users className="w-6 h-6 text-purple-600" />
                  </div>
                  <div>
                    <h3 className="text-sm font-black text-[#14243B]">{isHi ? 'समर्पित एवं अनुभवी शिक्षक' : 'Dedicated Teachers'}</h3>
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
                {/* 1. Main Gate Banner */}
                <div className="bg-white rounded-2xl overflow-hidden border border-[#E2E8F0] shadow-xs hover:shadow-md transition-all group">
                  <div className="aspect-[4/3] overflow-hidden bg-slate-100">
                    <img
                      src="/school_gate_banner.jpg"
                      alt="Main Campus Entrance - Mission Navodaya Public School"
                      loading="lazy"
                      className="w-full h-full object-cover transition-transform duration-500 group-hover:scale-105"
                    />
                  </div>
                  <div className="p-4 space-y-1 bg-white">
                    <h3 className="text-sm font-bold text-[#14243B]">{isHi ? 'मुख्य कैंपस प्रवेश द्वार' : 'Main Campus Entrance'}</h3>
                    <p className="text-[11px] text-[#65748B]">{isHi ? 'स्कूल की आधिकारिक पहचान के साथ सुरक्षित प्रवेश' : 'Secure entrance with official school identification'}</p>
                  </div>
                </div>

                {/* 2. Playground */}
                <div className="bg-white rounded-2xl overflow-hidden border border-[#E2E8F0] shadow-xs hover:shadow-md transition-all group">
                  <div className="aspect-[4/3] overflow-hidden bg-slate-100">
                    <img
                      src="/campus_playground.jpg"
                      alt="Sports & Football Arena - Mission Navodaya Public School"
                      loading="lazy"
                      className="w-full h-full object-cover transition-transform duration-500 group-hover:scale-105"
                    />
                  </div>
                  <div className="p-4 space-y-1 bg-white">
                    <h3 className="text-sm font-bold text-[#14243B]">{isHi ? 'खेलकूद एवं फुटबॉल मैदान' : 'Sports & Football Arena'}</h3>
                    <p className="text-[11px] text-[#65748B]">{isHi ? 'एथलेटिक्स और फुटबॉल के लिए विशाल खुला खेल का मैदान' : 'Expansive open playground for athletics and football'}</p>
                  </div>
                </div>

                {/* 3. Academic Building Block */}
                <div className="bg-white rounded-2xl overflow-hidden border border-[#E2E8F0] shadow-xs hover:shadow-md transition-all group">
                  <div className="aspect-[4/3] overflow-hidden bg-slate-100">
                    <img
                      src="/campus_building.jpg"
                      alt="Academic Building Block - Mission Navodaya Public School"
                      loading="lazy"
                      className="w-full h-full object-cover transition-transform duration-500 group-hover:scale-105"
                    />
                  </div>
                  <div className="p-4 space-y-1 bg-white">
                    <h3 className="text-sm font-bold text-[#14243B]">{isHi ? 'शैक्षणिक भवन ब्लॉक' : 'Academic Building Block'}</h3>
                    <p className="text-[11px] text-[#65748B]">{isHi ? 'हवादार व बड़े क्लासरूम और डिजिटल लर्निंग पॉइंट्स' : 'Spacious, ventilated classrooms and digital study points'}</p>
                  </div>
                </div>

                {/* 4. Student Arrival & Campus Life */}
                <div className="bg-white rounded-2xl overflow-hidden border border-[#E2E8F0] shadow-xs hover:shadow-md transition-all group">
                  <div className="aspect-[4/3] overflow-hidden bg-slate-100">
                    <img
                      src="/school_entrance.jpg"
                      alt="Student Arrival & Campus Life - Mission Navodaya Public School"
                      loading="lazy"
                      className="w-full h-full object-cover transition-transform duration-500 group-hover:scale-105"
                    />
                  </div>
                  <div className="p-4 space-y-1 bg-white">
                    <h3 className="text-sm font-bold text-[#14243B]">{isHi ? 'विद्यार्थी आगमन एवं कैंपस जीवन' : 'Student Arrival & Life'}</h3>
                    <p className="text-[11px] text-[#65748B]">{isHi ? 'अनुशासित कैंपस गेट, साइकिल पार्किंग और आगमन' : 'Disciplined campus gates, bicycle parking and arrival'}</p>
                  </div>
                </div>
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
                    ? 'हमारे अनुशासित वातावरण, व्यक्तिगत ध्यान और संस्कारयुक्त सीबीएसई शिक्षा पर अभिभावकों के अनुभव।'
                    : 'Hear directly from parents and guardians about our disciplined environment, individual attention, and values-based CBSE education.'}
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

              {/* 4 Cards Grid */}
              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-5">
                
                {/* Review 1 */}
                <div className="bg-white rounded-3xl p-6 border border-[#E2E8F0] shadow-xs hover:shadow-xl transition-all duration-300 flex flex-col justify-between group">
                  <div className="space-y-4">
                    <div className="flex items-center justify-between">
                      <div className="flex items-center text-amber-500">
                        {[...Array(5)].map((_, i) => (
                          <Star key={i} className="w-4 h-4 fill-current" />
                        ))}
                      </div>
                      <Quote className="w-6 h-6 text-slate-200 group-hover:text-[#F4B323] transition-colors" />
                    </div>
                    <p className="text-xs text-[#475569] leading-relaxed italic">
                      {isHi
                        ? '“स्कूल में पढ़ाई और अनुशासन दोनों बहुत बढ़िया है। आरव की इंग्लिश कम्युनिकेशन और बेसिक मैथ्स में बहुत सुधार हुआ है। शिक्षक हमेशा सहयोगी और स्नेही रहते हैं।”'
                        : '“School me padhai aur discipline dono bahut badhiya hai. Aarav ki English communication aur basic maths me bohot improvement hua hai. Teachers hamesha accessible aur caring hain.”'}
                    </p>
                  </div>

                  <div className="pt-4 mt-4 border-t border-slate-100 flex items-center gap-3">
                    <div className="w-10 h-10 rounded-full bg-[#102747] text-[#F4B323] font-black text-xs flex items-center justify-center flex-shrink-0 shadow-xs">
                      RK
                    </div>
                    <div className="min-w-0">
                      <div className="text-xs font-black text-[#14243B] truncate flex items-center gap-1">
                        <span>{isHi ? 'राजेश कुमार सिंह' : 'Rajesh Kumar Singh'}</span>
                        <CheckCircle2 className="w-3 h-3 text-emerald-500 flex-shrink-0" />
                      </div>
                      <div className="text-[10px] text-[#65748B] font-medium truncate">
                        {isHi ? 'आरव के पिता • कक्षा 4' : 'Father of Aarav • Grade 4'}
                      </div>
                    </div>
                  </div>
                </div>

                {/* Review 2 */}
                <div className="bg-white rounded-3xl p-6 border border-[#E2E8F0] shadow-xs hover:shadow-xl transition-all duration-300 flex flex-col justify-between group">
                  <div className="space-y-4">
                    <div className="flex items-center justify-between">
                      <div className="flex items-center text-amber-500">
                        {[...Array(5)].map((_, i) => (
                          <Star key={i} className="w-4 h-4 fill-current" />
                        ))}
                      </div>
                      <Quote className="w-6 h-6 text-slate-200 group-hover:text-[#F4B323] transition-colors" />
                    </div>
                    <p className="text-xs text-[#475569] leading-relaxed italic">
                      {isHi
                        ? '“मोरा बाज़ार क्षेत्र में ऐसा अनुशासित, सुरक्षित और प्रेरक स्कूल वातावरण मिलना गर्व की बात है। बच्चों पर व्यक्तिगत रूप से पूरा ध्यान दिया जाता है।”'
                        : '“Mora Bazar area me aisa disciplined, safe aur supportive school environment milna bohot khushi ki baat hai. Bachho par personalized dhyan diya jata hai.”'}
                    </p>
                  </div>

                  <div className="pt-4 mt-4 border-t border-slate-100 flex items-center gap-3">
                    <div className="w-10 h-10 rounded-full bg-[#091A32] text-amber-400 font-black text-xs flex items-center justify-center flex-shrink-0 shadow-xs">
                      SD
                    </div>
                    <div className="min-w-0">
                      <div className="text-xs font-black text-[#14243B] truncate flex items-center gap-1">
                        <span>{isHi ? 'सुनीता देवी' : 'Sunita Devi'}</span>
                        <CheckCircle2 className="w-3 h-3 text-emerald-500 flex-shrink-0" />
                      </div>
                      <div className="text-[10px] text-[#65748B] font-medium truncate">
                        {isHi ? 'प्रिया कुमारी की माता • कक्षा 1' : 'Mother of Priya Kumari • Grade 1'}
                      </div>
                    </div>
                  </div>
                </div>

                {/* Review 3 */}
                <div className="bg-white rounded-3xl p-6 border border-[#E2E8F0] shadow-xs hover:shadow-xl transition-all duration-300 flex flex-col justify-between group">
                  <div className="space-y-4">
                    <div className="flex items-center justify-between">
                      <div className="flex items-center text-amber-500">
                        {[...Array(5)].map((_, i) => (
                          <Star key={i} className="w-4 h-4 fill-current" />
                        ))}
                      </div>
                      <Quote className="w-6 h-6 text-slate-200 group-hover:text-[#F4B323] transition-colors" />
                    </div>
                    <p className="text-xs text-[#475569] leading-relaxed italic">
                      {isHi
                        ? '“स्पोर्ट्स प्लेग्राउंड और कंप्यूटर लैब बहुत बढ़िया है। रेहान फुटबॉल और डिजिटल लर्निंग में सक्रिय रूप से भाग लेता है। प्रबंधन का विजन बहुत स्पष्ट है।”'
                        : '“Sports playground aur computer lab bohot accha hai. Rehan football aur digital learning me active participate karta hai. Management ka vision ekdum clear aur dedicated hai.”'}
                    </p>
                  </div>

                  <div className="pt-4 mt-4 border-t border-slate-100 flex items-center gap-3">
                    <div className="w-10 h-10 rounded-full bg-emerald-800 text-white font-black text-xs flex items-center justify-center flex-shrink-0 shadow-xs">
                      MS
                    </div>
                    <div className="min-w-0">
                      <div className="text-xs font-black text-[#14243B] truncate flex items-center gap-1">
                        <span>{isHi ? 'मो. शमीम अंसारी' : 'Md. Shamim Ansari'}</span>
                        <CheckCircle2 className="w-3 h-3 text-emerald-500 flex-shrink-0" />
                      </div>
                      <div className="text-[10px] text-[#65748B] font-medium truncate">
                        {isHi ? 'रेहान के पिता • कक्षा 7' : 'Father of Rehan • Grade 7'}
                      </div>
                    </div>
                  </div>
                </div>

                {/* Review 4 */}
                <div className="bg-white rounded-3xl p-6 border border-[#E2E8F0] shadow-xs hover:shadow-xl transition-all duration-300 flex flex-col justify-between group">
                  <div className="space-y-4">
                    <div className="flex items-center justify-between">
                      <div className="flex items-center text-amber-500">
                        {[...Array(5)].map((_, i) => (
                          <Star key={i} className="w-4 h-4 fill-current" />
                        ))}
                      </div>
                      <Quote className="w-6 h-6 text-slate-200 group-hover:text-[#F4B323] transition-colors" />
                    </div>
                    <p className="text-xs text-[#475569] leading-relaxed italic">
                      {isHi
                        ? '“एक्टिविटी बेस्ड लर्निंग और फोनिक्स से मेरी बेटी बहुत तेजी से सीख रही है। सोनी मैडम और सभी शिक्षक हर बच्चे का पूरा ख्याल रखते हैं।”'
                        : '“Activity based learning aur phonics se meri beti bahut tezi se seekh rahi hai. Soni Madam aur sabhi teachers har bachhe ka pura khayal rakhte hain.”'}
                    </p>
                  </div>

                  <div className="pt-4 mt-4 border-t border-slate-100 flex items-center gap-3">
                    <div className="w-10 h-10 rounded-full bg-purple-900 text-amber-300 font-black text-xs flex items-center justify-center flex-shrink-0 shadow-xs">
                      PS
                    </div>
                    <div className="min-w-0">
                      <div className="text-xs font-black text-[#14243B] truncate flex items-center gap-1">
                        <span>{isHi ? 'पूजा शर्मा' : 'Pooja Sharma'}</span>
                        <CheckCircle2 className="w-3 h-3 text-emerald-500 flex-shrink-0" />
                      </div>
                      <div className="text-[10px] text-[#65748B] font-medium truncate">
                        {isHi ? 'अनन्या की माता • यूकेजी' : 'Mother of Ananya • UKG'}
                      </div>
                    </div>
                  </div>
                </div>

              </div>
            </section>

            {/* ── SECTION 7: CONTACT & CAMPUS HELPLINE (Direct from Banner Footer Strip) ── */}
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
                        <>हमारा स्कूल परिसर<br />मोरा, सीवान जिला<br />बिहार, भारत</>
                      ) : (
                        <>Our School Campus<br />Mora, Siwan District<br />Bihar, India</>
                      )}
                    </p>
                    <a
                      href="https://maps.google.com/?q=Mission+Navodaya+Public+School+Mora+Bihar"
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
                        <>कॉल / व्हाट्सएप डेस्क<br />अन्य हेल्पलाइन: +91 {altPhone}<br />सोमवार से शनिवार</>
                      ) : (
                        <>Call / WhatsApp Desk<br />Alt Helpline: +91 {altPhone}<br />Monday through Saturday</>
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
        ) : (
          /* ───────────────────────────────────────────────────────────── */
          /* STAGE 2: PRESERVED AUTHENTICATION MODAL (100% WORKING LOGIC)  */
          /* ───────────────────────────────────────────────────────────── */
          <div className="w-full max-w-lg mx-auto py-10 px-4 animate-in zoom-in-95 duration-200">
            <div className="rounded-3xl bg-white border border-[#E2E8F0] shadow-xl p-6 sm:p-8 relative">

              <button
                type="button"
                onClick={() => setIsLoginModalOpen(false)}
                className="inline-flex items-center gap-2 px-3 py-1.5 rounded-xl bg-slate-100 hover:bg-slate-200 text-xs font-bold text-[#102747] transition-all cursor-pointer mb-5"
              >
                <ArrowLeft className="w-3.5 h-3.5 text-[#102747]" />
                <span>{isHi ? '← स्कूल वेबसाइट पर वापस जाएं' : '← Back to School Website'}</span>
              </button>

              <div className="text-center space-y-1.5 mb-6">
                <div className="w-16 h-16 mx-auto flex items-center justify-center drop-shadow-md">
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
                <h2 className="text-xl font-black text-[#14243B] tracking-tight">
                  {role === 'parent'
                    ? (isHi ? 'अभिभावक पोर्टल लॉगिन' : 'Parent Portal Sign In')
                    : role === 'teacher'
                    ? (isHi ? 'शिक्षक एवं संकाय लॉगिन' : 'Faculty & Teacher Sign In')
                    : (isHi ? 'प्रधानाचार्य प्रशासन पोर्टल' : 'Principal Administration Portal')}
                </h2>
                <p className="text-xs text-[#65748B] font-medium">
                  {role === 'parent'
                    ? (isHi ? 'अपने बच्चे का शुल्क विवरण, उपस्थिति रिकॉर्ड और रिपोर्ट कार्ड देखें' : 'Access your child’s fee statement, attendance records and report cards')
                    : (isHi ? 'सत्यापित कर्मचारियों और प्रबंधन के लिए सुरक्षित संस्थागत पोर्टल' : 'Secure institutional portal for authenticated staff and administration')}
                </p>
              </div>

              {/* Role Switcher Tabs */}
              <div className="grid grid-cols-3 p-1 rounded-2xl bg-slate-100 border border-[#E2E8F0] mb-6">
                <button
                  type="button"
                  onClick={() => { setRole('parent'); setError(''); }}
                  className={`py-2 px-2 rounded-xl text-xs font-black flex flex-col sm:flex-row items-center justify-center gap-1.5 transition-all cursor-pointer ${
                    role === 'parent'
                      ? 'bg-white text-[#102747] shadow-sm'
                      : 'text-[#65748B] hover:text-[#102747]'
                  }`}
                >
                  <Users className="w-3.5 h-3.5 text-[#F4B323]" />
                  <span>{isHi ? 'अभिभावक' : 'Parent'}</span>
                </button>

                <button
                  type="button"
                  onClick={() => { setRole('teacher'); setError(''); }}
                  className={`py-2 px-2 rounded-xl text-xs font-black flex flex-col sm:flex-row items-center justify-center gap-1.5 transition-all cursor-pointer ${
                    role === 'teacher'
                      ? 'bg-white text-[#102747] shadow-sm'
                      : 'text-[#65748B] hover:text-[#102747]'
                  }`}
                >
                  <GraduationCap className="w-3.5 h-3.5 text-[#102747]" />
                  <span>{isHi ? 'शिक्षक' : 'Teacher'}</span>
                </button>

                <button
                  type="button"
                  onClick={() => { setRole('principal'); setError(''); }}
                  className={`py-2 px-2 rounded-xl text-xs font-black flex flex-col sm:flex-row items-center justify-center gap-1.5 transition-all cursor-pointer ${
                    role === 'principal'
                      ? 'bg-white text-[#102747] shadow-sm'
                      : 'text-[#65748B] hover:text-[#102747]'
                  }`}
                >
                  <ShieldCheck className="w-3.5 h-3.5 text-emerald-600" />
                  <span>{isHi ? 'प्रधानाचार्य' : 'Principal'}</span>
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
                  /* PARENT LOGIN FIELDS */
                  <div className="space-y-4 animate-in fade-in">
                    <div>
                      <label className="block text-xs font-bold text-[#14243B] mb-1.5">
                        {isHi ? 'बच्चे का एडमिशन नंबर या रोल नंबर *' : 'Child Admission ID or Roll Number *'}
                      </label>
                      <div className="relative">
                        <Hash className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
                        <input
                          type="text"
                          required
                          value={parentAdmissionNo}
                          onChange={(e) => setParentAdmissionNo(e.target.value)}
                          placeholder={isHi ? 'जैसे MNP-2026-0042 या रोल नंबर' : 'e.g. MNP-2026-0042 or Roll Number'}
                          className="w-full pl-10 pr-4 py-3 rounded-xl bg-slate-50 border border-[#E2E8F0] text-xs font-medium text-[#14243B] placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-[#102747]/20 focus:border-[#102747] transition-all"
                        />
                      </div>
                    </div>

                    <div>
                      <label className="block text-xs font-bold text-[#14243B] mb-1.5">
                        {isHi ? 'पंजीकृत अभिभावक मोबाइल नंबर *' : 'Registered Parent Mobile Number *'}
                      </label>
                      <div className="relative">
                        <Phone className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
                        <input
                          type="tel"
                          required
                          value={parentMobile}
                          onChange={(e) => setParentMobile(e.target.value)}
                          placeholder={isHi ? '10 अंकों का मोबाइल नंबर दर्ज करें' : 'Enter 10-digit mobile number'}
                          className="w-full pl-10 pr-4 py-3 rounded-xl bg-slate-50 border border-[#E2E8F0] text-xs font-medium text-[#14243B] placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-[#102747]/20 focus:border-[#102747] transition-all"
                        />
                      </div>
                      <p className="text-[10px] text-[#65748B] mt-1">
                        {isHi
                          ? 'दाखिला सत्यापन और आपके बच्चे के रिकॉर्ड की सुरक्षा के लिए उपयोग किया जाता है।'
                          : 'Used to verify enrollment and safeguard your child’s records.'}
                      </p>
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
                        {isHi
                          ? `लॉगिन करें (${role === 'parent' ? 'अभिभावक डेस्क' : role === 'teacher' ? 'शिक्षक कंसोल' : 'एडमिन पोर्टल'})`
                          : `Sign In to ${role === 'parent' ? 'Parent Desk' : role === 'teacher' ? 'Teacher Console' : 'Admin Portal'}`}
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
                  <a href="#about" className="hover:text-[#F4B323] transition-colors">{isHi ? 'स्कूल के बारे में' : 'About the School'}</a>
                </li>
                <li>
                  <a href="#admissions" className="hover:text-[#F4B323] transition-colors text-[#F4B323] font-bold">
                    {isHi ? `दाखिला ${currentSession} →` : `Admissions ${currentSession} →`}
                  </a>
                </li>
                <li>
                  <a href="#features" className="hover:text-[#F4B323] transition-colors">{isHi ? '5 मुख्य आधार' : '5 Campus Pillars'}</a>
                </li>
                <li>
                  <a href="#leadership" className="hover:text-[#F4B323] transition-colors">{isHi ? 'मार्गदर्शन एवं नेतृत्व' : 'Leadership & Vision'}</a>
                </li>
                <li>
                  <a href="#campus-gallery" className="hover:text-[#F4B323] transition-colors">{isHi ? 'फोटो गैलरी' : 'Photo Gallery'}</a>
                </li>
                <li>
                  <a href="#reviews" className="hover:text-[#F4B323] transition-colors text-amber-300">{isHi ? 'अभिभावक समीक्षाएं' : 'Parent Reviews & Ratings'}</a>
                </li>
                <li>
                  <a href="#contact" className="hover:text-[#F4B323] transition-colors">{isHi ? 'हेल्प एवं ऑफिस डेस्क' : 'Help & Office Desk'}</a>
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
                    onClick={() => openPortalLogin('teacher')}
                    className="inline-flex items-center gap-2 px-3 py-1.5 rounded-lg bg-white/10 hover:bg-[#F4B323] text-white hover:text-[#091A32] font-black text-xs transition-all cursor-pointer border border-white/20 shadow-xs mb-1"
                  >
                    <GraduationCap className="w-3.5 h-3.5 text-[#F4B323] group-hover:text-[#091A32]" />
                    <span>{isHi ? 'शिक्षक एवं संकाय पोर्टल →' : 'Faculty & Teacher Portal →'}</span>
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
                    onClick={() => openPortalLogin('principal')}
                    className="hover:text-[#F4B323] transition-colors cursor-pointer text-left flex items-center gap-1.5"
                  >
                    <ShieldCheck className="w-3.5 h-3.5 text-emerald-400" />
                    <span>{isHi ? 'प्रधानाचार्य एडमिन लॉगिन →' : 'Principal Admin Access →'}</span>
                  </button>
                </li>
                <li>
                  <a
                    href="/signup?tab=admission"
                    onClick={(e) => {
                      e.preventDefault();
                      if (setSignUpFormTab) setSignUpFormTab('student');
                      navigate('/signup?tab=admission');
                    }}
                    className="hover:text-[#F4B323] transition-colors cursor-pointer text-left"
                  >
                    {isHi ? 'विद्यार्थी नामांकन डेस्क →' : 'Student Admission Desk →'}
                  </a>
                </li>
                <li>
                  <a
                    href="/signup?tab=faculty"
                    onClick={(e) => {
                      e.preventDefault();
                      if (setSignUpFormTab) setSignUpFormTab('teacher');
                      navigate('/signup?tab=faculty');
                    }}
                    className="hover:text-[#F4B323] transition-colors cursor-pointer text-left"
                  >
                    {isHi ? 'शिक्षक भर्ती आवेदन →' : 'Teacher Recruitment Application →'}
                  </a>
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
                  <span className="text-slate-500">·</span>
                  <a href={`tel:${altPhone}`} className="hover:underline text-slate-300">
                    +91 {altPhone}
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

          {/* Bottom Navy Footer Strip (Matching Image) */}
          <div className="mt-12 pt-6 border-t border-[#1E3A60] flex flex-col sm:flex-row items-center justify-between gap-4 text-xs text-slate-400">
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

    </div>
  );
}
