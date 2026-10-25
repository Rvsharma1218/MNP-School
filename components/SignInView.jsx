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
      <div className="bg-[#091A32] text-white text-[11px] font-bold px-4 py-2 border-b border-[#1E3A60] hidden sm:block">
        <div className="max-w-7xl mx-auto flex items-center justify-between gap-4">
          <div className="flex items-center gap-3">
            {isAdmissionOpen ? (
              <>
                <span className="px-2.5 py-0.5 rounded-full bg-[#F4B323] text-[#091A32] text-[10px] font-black uppercase tracking-wider">
                  Admissions {currentSession}
                </span>
                <span className="text-slate-200">
                  Now Enrolling {admissionClasses} · {schoolLocation}
                </span>
              </>
            ) : (
              <>
                <span className="px-2.5 py-0.5 rounded-full bg-slate-700 text-slate-200 text-[10px] font-bold uppercase tracking-wider border border-slate-600">
                  Session {currentSession}
                </span>
                <span className="text-slate-200">
                  Academic Session in Progress · {schoolLocation}
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
              <span>Mon – Sat: 8:00 AM – 2:00 PM</span>
            </span>
          </div>
        </div>
      </div>

      {/* ───────────────────────────────────────────────────────────── */}
      {/* 2. MAIN HEADER & INSTITUTIONAL NAVIGATION                    */}
      {/* ───────────────────────────────────────────────────────────── */}
      <header className="sticky top-0 z-40 w-full bg-[#102747] text-white border-b border-[#1E3A60] shadow-md backdrop-blur-md">
        <div className="w-full max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 h-18 sm:h-20 flex items-center justify-between gap-4">
          
          {/* Brand Seal, School Title & Subtitle */}
          <a href="#about" className="flex items-center gap-3 sm:gap-3.5 min-w-0 flex-shrink-0 group">
            <div className="w-11 h-11 sm:w-12 sm:h-12 rounded-xl bg-white border border-[#E2E8F0] p-1 flex items-center justify-center flex-shrink-0 shadow-sm overflow-hidden transition-transform group-hover:scale-105">
              <img
                src={logoSrc}
                alt="Mission Navodaya Public School Mora Official Seal"
                className="w-full h-full object-contain"
                onError={(e) => {
                  e.currentTarget.onerror = null;
                  e.currentTarget.src = '/logo.png';
                }}
              />
            </div>
            <div className="min-w-0">
              <div className="text-sm sm:text-base lg:text-lg font-black tracking-tight text-white leading-tight truncate uppercase">
                {schoolName}
              </div>
              <div className="text-[10px] sm:text-[11px] font-bold text-[#F4B323] tracking-wide truncate flex items-center gap-1.5 mt-0.5">
                <span className="w-1.5 h-1.5 rounded-full bg-[#F4B323] animate-pulse" />
                <span>Mora Bazar, Siwan (Bihar) · Session 2026–27</span>
              </div>
            </div>
          </a>

          {/* Desktop Navigation Links */}
          <nav className="hidden xl:flex items-center gap-6 text-[13px] font-bold text-slate-200">
            <a href="#about" className="hover:text-[#F4B323] transition-colors py-1">About School</a>
            <a href="#admissions" className="hover:text-[#F4B323] transition-colors py-1 text-[#F4B323]">Admissions 2026–27</a>
            <a href="#features" className="hover:text-[#F4B323] transition-colors py-1">Campus Features</a>
            <a href="#leadership" className="hover:text-[#F4B323] transition-colors py-1">Leadership</a>
            <a href="#facilities" className="hover:text-[#F4B323] transition-colors py-1">Facilities</a>
            <a href="#campus-gallery" className="hover:text-[#F4B323] transition-colors py-1">Gallery</a>
            <a href="#contact" className="hover:text-[#F4B323] transition-colors py-1">Contact</a>
          </nav>

          {/* Desktop Action Buttons */}
          <div className="hidden md:flex items-center gap-2.5 sm:gap-3 flex-shrink-0">
            {/* Language Toggle */}
            <button
              type="button"
              onClick={toggleLanguage}
              className="inline-flex items-center gap-1.5 px-3 py-2 rounded-xl bg-white/10 hover:bg-white/15 border border-white/20 text-xs font-bold text-slate-100 transition-all cursor-pointer"
              title="Toggle Language"
            >
              <Globe className="w-3.5 h-3.5 text-[#F4B323]" />
              <span>{language === 'hi' ? 'English' : 'हिन्दी'}</span>
            </button>

            {/* Parent Login */}
            <button
              type="button"
              onClick={() => openPortalLogin('parent')}
              className="inline-flex items-center gap-1.5 px-3.5 py-2 rounded-xl text-xs font-bold text-white bg-white/10 hover:bg-white/20 border border-white/25 transition-all cursor-pointer shadow-2xs"
            >
              <Users className="w-3.5 h-3.5 text-[#F4B323]" />
              <span>Parent Portal</span>
            </button>

            {/* Staff / Principal Login */}
            <button
              type="button"
              onClick={() => openPortalLogin('principal')}
              className="inline-flex items-center gap-1.5 px-3.5 py-2 rounded-xl text-xs font-bold text-white bg-white/10 hover:bg-white/20 border border-white/25 transition-all cursor-pointer shadow-2xs"
            >
              <ShieldCheck className="w-3.5 h-3.5 text-[#F4B323]" />
              <span>Portal Login</span>
            </button>

            {/* Online Admission Form Button */}
            <button
              type="button"
              onClick={() => {
                if (setSignUpFormTab) setSignUpFormTab('student');
                navigate('/signup?tab=admission');
              }}
              className="inline-flex items-center gap-2 px-4 py-2 rounded-xl text-xs font-black text-[#091A32] bg-[#F4B323] hover:bg-[#e0a21a] shadow-md hover:shadow-lg transition-all cursor-pointer flex-shrink-0"
            >
              <Sparkles className="w-3.5 h-3.5 text-[#091A32]" />
              <span>Online Admission</span>
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
              <span className="text-[11px]">{language === 'hi' ? 'EN' : 'हिन्दी'}</span>
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
                <span>Session 2026–27 · Nursery to 8th Admissions Open</span>
              </div>

              <div className="space-y-1 font-bold text-sm text-slate-200">
                <button
                  type="button"
                  onClick={() => closeMobileMenuAndNavigate('#about')}
                  className="w-full text-left px-3 py-2.5 rounded-xl hover:bg-white/10 transition-colors cursor-pointer flex items-center justify-between"
                >
                  <span>About School</span>
                  <ArrowRight className="w-4 h-4 text-slate-400" />
                </button>
                <button
                  type="button"
                  onClick={() => closeMobileMenuAndNavigate('#admissions')}
                  className="w-full text-left px-3 py-2.5 rounded-xl hover:bg-white/10 transition-colors cursor-pointer flex items-center justify-between text-[#F4B323]"
                >
                  <span>Admissions 2026–27 (Nursery – 8th)</span>
                  <ArrowRight className="w-4 h-4 text-[#F4B323]" />
                </button>
                <button
                  type="button"
                  onClick={() => closeMobileMenuAndNavigate('#features')}
                  className="w-full text-left px-3 py-2.5 rounded-xl hover:bg-white/10 transition-colors cursor-pointer flex items-center justify-between"
                >
                  <span>5 Signature Features</span>
                  <ArrowRight className="w-4 h-4 text-slate-400" />
                </button>
                <button
                  type="button"
                  onClick={() => closeMobileMenuAndNavigate('#leadership')}
                  className="w-full text-left px-3 py-2.5 rounded-xl hover:bg-white/10 transition-colors cursor-pointer flex items-center justify-between"
                >
                  <span>School Leadership</span>
                  <ArrowRight className="w-4 h-4 text-slate-400" />
                </button>
                <button
                  type="button"
                  onClick={() => closeMobileMenuAndNavigate('#facilities')}
                  className="w-full text-left px-3 py-2.5 rounded-xl hover:bg-white/10 transition-colors cursor-pointer flex items-center justify-between"
                >
                  <span>Campus Facilities</span>
                  <ArrowRight className="w-4 h-4 text-slate-400" />
                </button>
                <button
                  type="button"
                  onClick={() => closeMobileMenuAndNavigate('#campus-gallery')}
                  className="w-full text-left px-3 py-2.5 rounded-xl hover:bg-white/10 transition-colors cursor-pointer flex items-center justify-between"
                >
                  <span>Photo Gallery</span>
                  <ArrowRight className="w-4 h-4 text-slate-400" />
                </button>
                <button
                  type="button"
                  onClick={() => closeMobileMenuAndNavigate('#contact')}
                  className="w-full text-left px-3 py-2.5 rounded-xl hover:bg-white/10 transition-colors cursor-pointer flex items-center justify-between"
                >
                  <span>Office Helpline &amp; Contact</span>
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
                  <span>Online Admission Form</span>
                </button>

                <div className="grid grid-cols-2 gap-2.5">
                  <button
                    type="button"
                    onClick={() => openPortalLogin('parent')}
                    className="py-3 px-3 rounded-xl bg-white/12 hover:bg-white/20 border border-white/25 text-white font-bold text-xs flex items-center justify-center gap-1.5 cursor-pointer"
                  >
                    <Users className="w-3.5 h-3.5 text-[#F4B323]" />
                    <span>Parent Portal</span>
                  </button>

                  <button
                    type="button"
                    onClick={() => openPortalLogin('principal')}
                    className="py-3 px-3 rounded-xl bg-white/12 hover:bg-white/20 border border-white/25 text-white font-bold text-xs flex items-center justify-center gap-1.5 cursor-pointer"
                  >
                    <ShieldCheck className="w-3.5 h-3.5 text-[#F4B323]" />
                    <span>Portal Login</span>
                  </button>
                </div>
              </div>
            </div>

            <div className="pt-6 border-t border-white/10 text-center text-xs text-slate-400 space-y-1">
              <div>Office Call/WhatsApp: <a href={`tel:${primaryPhone}`} className="text-[#F4B323] font-bold">+91 {primaryPhone}</a></div>
              <div>{schoolLocation}</div>
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

              {/* Rich Glassmorphism Gradient Overlays — Enhances readability of all text while keeping the campus and students visible */}
              <div
                className="absolute inset-0 bg-gradient-to-r from-[#07172E]/96 via-[#091D38]/88 to-[#061426]/75"
                aria-hidden="true"
              />
              <div
                className="absolute inset-0 bg-gradient-to-t from-[#07172E] via-transparent to-[#07172E]/60"
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
                    <span className="tracking-wide break-words text-center">DISCIPLINE · KNOWLEDGE · EXCELLENCE · BRIGHT FUTURE</span>
                  </div>

                  <div className="inline-flex items-center gap-2 px-3.5 py-1.5 rounded-full bg-[#F4B323]/15 border border-[#F4B323]/30 backdrop-blur-md text-xs font-black text-[#F4B323] shadow-xs">
                    <Calendar className="w-3.5 h-3.5" />
                    <span>SESSION {currentSession}</span>
                  </div>
                </div>

                {/* Middle Hero Block: Logo + School Name + Tagline + Location */}
                <div className="flex flex-col md:flex-row items-center md:items-start gap-5 sm:gap-6 text-center md:text-left">
                  
                  {/* Official School Crest Logo */}
                  <div className="relative flex-shrink-0 group">
                    <div className="w-20 h-20 sm:w-24 sm:h-24 lg:w-28 lg:h-28 rounded-2xl bg-white p-2.5 shadow-2xl border-2 border-[#F4B323] flex items-center justify-center transition-transform group-hover:scale-105">
                      <img
                        src={logoSrc}
                        alt="Mission Navodaya Public School Crest"
                        className="w-full h-full object-contain"
                        onError={(e) => {
                          e.currentTarget.onerror = null;
                          e.currentTarget.src = '/logo.png';
                        }}
                      />
                    </div>
                    <div className="absolute -bottom-1 -right-1 px-1.5 py-0.5 rounded-md bg-[#102747] border border-[#F4B323] text-[9px] font-black text-[#F4B323] uppercase">
                      ESTD 2021
                    </div>
                  </div>

                  {/* School Typography & Tagline */}
                  <div className="space-y-2 flex-1">
                    <div className="inline-flex items-center gap-1.5 text-[11px] font-extrabold uppercase tracking-widest text-[#F4B323]">
                      <span>CBSE Curriculum Pattern &bull; English Medium Co-Educational</span>
                    </div>

                    <h1 className="text-2xl sm:text-4xl lg:text-[46px] font-black text-white tracking-tight uppercase leading-[1.12] drop-shadow-md break-words max-w-full">
                      MISSION NAVODAYA <span className="text-[#F4B323]">PUBLIC SCHOOL</span>, MORA
                    </h1>

                    <p className="text-xs sm:text-sm text-slate-300 font-medium italic max-w-2xl">
                      &ldquo;A Safe Campus for Brighter Futures.&rdquo; &mdash; Dedicated to Academic Excellence, Moral Character, and Digital Innovation.
                    </p>

                    {/* School Location & Timings Quick Micro-Badges */}
                    <div className="pt-1 flex flex-wrap items-center justify-center md:justify-start gap-2 sm:gap-3 text-xs text-slate-300 font-medium">
                      <span className="inline-flex items-center gap-1.5 px-3 py-1 rounded-lg bg-white/10 backdrop-blur-xs border border-white/15">
                        <MapPin className="w-3.5 h-3.5 text-[#F4B323]" />
                        <span>Mora Bazar, Siwan (Bihar)</span>
                      </span>
                      <span className="inline-flex items-center gap-1.5 px-3 py-1 rounded-lg bg-white/10 backdrop-blur-xs border border-white/15">
                        <Clock className="w-3.5 h-3.5 text-emerald-400" />
                        <span>Mon &ndash; Sat: 8:00 AM &ndash; 2:00 PM</span>
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
                  <div className="mt-6 p-4 sm:p-5 rounded-2xl bg-gradient-to-r from-[#0C223F]/92 via-[#112F56]/88 to-[#0C223F]/92 border-2 border-[#F4B323]/50 backdrop-blur-md shadow-2xl flex flex-col lg:flex-row items-center justify-between gap-4">
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
                            ADMISSIONS OPEN
                          </span>
                          <span className="text-xs font-black px-2.5 py-0.5 rounded-md bg-[#F4B323] text-[#091A32] tracking-wider uppercase shadow-xs">
                            SESSION {currentSession}
                          </span>
                        </div>
                        <div className="text-xs text-[#F4B323] font-bold">
                          {admissionClasses} &bull; Limited Seats Available for New Enrolments
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
                        <span>Online Admission Form &rarr;</span>
                      </button>

                      <a
                        href="#contact"
                        className="flex-1 sm:flex-initial px-5 py-3.5 rounded-xl bg-white/10 hover:bg-white/20 text-white font-bold text-xs sm:text-sm border border-white/25 backdrop-blur-sm transition-all flex items-center justify-center gap-2 cursor-pointer"
                      >
                        <Calendar className="w-4 h-4 text-[#F4B323]" />
                        <span>Book Campus Visit</span>
                      </a>
                    </div>
                  </div>
                ) : (
                  <div className="mt-6 p-4 sm:p-5 rounded-2xl bg-gradient-to-r from-[#0C223F]/92 via-[#112F56]/88 to-[#0C223F]/92 border border-white/20 backdrop-blur-md shadow-2xl flex flex-col lg:flex-row items-center justify-between gap-4">
                    {/* Left: Academic Session in Progress */}
                    <div className="flex flex-col sm:flex-row items-center sm:items-start gap-3.5 text-center sm:text-left">
                      <div className="w-12 h-12 rounded-xl bg-white/10 text-[#F4B323] border border-white/20 flex items-center justify-center flex-shrink-0 shadow-lg">
                        <School className="w-6 h-6 text-[#F4B323]" />
                      </div>
                      <div className="space-y-0.5">
                        <div className="flex flex-wrap items-center justify-center sm:justify-start gap-2">
                          <span className="text-lg sm:text-xl lg:text-2xl font-black text-white tracking-tight uppercase">
                            ACADEMIC SESSION {currentSession}
                          </span>
                          <span className="text-xs font-bold px-2.5 py-0.5 rounded-md bg-slate-700/80 text-slate-200 border border-slate-600 tracking-wider uppercase">
                            Admissions Closed
                          </span>
                        </div>
                        <div className="text-xs text-slate-300 font-medium">
                          Academic curriculum in progress &bull; Enquire now for next academic session or campus tour
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
                        <span>Enquire for Next Session &rarr;</span>
                      </button>

                      <a
                        href="#campus-gallery"
                        className="flex-1 sm:flex-initial px-5 py-3.5 rounded-xl bg-white/10 hover:bg-white/20 text-white font-bold text-xs sm:text-sm border border-white/25 backdrop-blur-sm transition-all flex items-center justify-center gap-2 cursor-pointer"
                      >
                        <Building className="w-4 h-4 text-[#F4B323]" />
                        <span>Explore Campus Life</span>
                      </a>
                    </div>
                  </div>
                )}

                {/* 4 Pillars Badges from Banner */}
                <div className="mt-6 pt-4 border-t border-white/10 flex flex-wrap items-center justify-center md:justify-start gap-2 sm:gap-3">
                  <div className="inline-flex items-center gap-1.5 px-3.5 py-1.5 rounded-xl bg-white/10 backdrop-blur-xs border border-white/15 text-xs font-bold text-white shadow-xs">
                    <BookOpen className="w-3.5 h-3.5 text-[#F4B323]" />
                    <span>Quality Education</span>
                  </div>
                  <div className="inline-flex items-center gap-1.5 px-3.5 py-1.5 rounded-xl bg-white/10 backdrop-blur-xs border border-white/15 text-xs font-bold text-white shadow-xs">
                    <Shield className="w-3.5 h-3.5 text-blue-400" />
                    <span>Moral Values</span>
                  </div>
                  <div className="inline-flex items-center gap-1.5 px-3.5 py-1.5 rounded-xl bg-white/10 backdrop-blur-xs border border-white/15 text-xs font-bold text-white shadow-xs">
                    <TrendingUp className="w-3.5 h-3.5 text-emerald-400" />
                    <span>Holistic Development</span>
                  </div>
                  <div className="inline-flex items-center gap-1.5 px-3.5 py-1.5 rounded-xl bg-white/10 backdrop-blur-xs border border-white/15 text-xs font-bold text-white shadow-xs">
                    <Trophy className="w-3.5 h-3.5 text-[#F4B323]" />
                    <span>Better Tomorrow</span>
                  </div>
                </div>

              </div>
            </section>

            {/* ── SECTION 2: ADMISSIONS CALLOUT & CTAS (Dynamic with Settings) ── */}
            <section id="admissions" className="w-full max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 scroll-mt-28 overflow-hidden">
              <div className="rounded-3xl bg-gradient-to-r from-[#102747] via-[#091A32] to-[#102747] border border-[#1E3A60] p-6 sm:p-8 text-white shadow-xl flex flex-col lg:flex-row items-center justify-between gap-6">
                
                {/* Left: Admissions Title & Classes */}
                <div className="flex flex-col sm:flex-row items-center sm:items-start gap-4 text-center sm:text-left">
                  <div className="w-14 h-14 rounded-2xl bg-[#F4B323] text-[#091A32] flex items-center justify-center flex-shrink-0 shadow-md">
                    <GraduationCap className="w-8 h-8 text-[#091A32]" />
                  </div>
                  <div className="space-y-1">
                    <div className="flex flex-wrap items-center justify-center sm:justify-start gap-2">
                      <span className="text-xl sm:text-2xl lg:text-3xl font-black text-white tracking-tight uppercase">
                        {isAdmissionOpen ? 'ADMISSIONS OPEN' : 'ACADEMIC SESSION'}
                      </span>
                      <span className="text-xs font-extrabold px-2.5 py-1 rounded-md bg-[#F4B323] text-[#091A32] uppercase tracking-wider">
                        SESSION {currentSession}
                      </span>
                    </div>
                    <div className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-white/10 text-xs font-bold text-[#F4B323] border border-white/15">
                      <span>{isAdmissionOpen ? admissionClasses : 'Session In Progress · Admissions Closed'}</span>
                    </div>
                    <p className="text-xs text-slate-300 max-w-xl pt-0.5">
                      {isAdmissionOpen
                        ? 'Empower your child with disciplined learning, modern digital education, and holistic values at our Mora Bazar campus.'
                        : 'Current academic session is actively underway. You can submit advance enquiries for future enrolments or book a campus visit.'}
                    </p>
                  </div>
                </div>

                {/* Right: The 2 Action CTAs */}
                <div className="flex flex-wrap items-center justify-center gap-3.5 flex-shrink-0 w-full lg:w-auto">
                  {isAdmissionOpen ? (
                    <button
                      type="button"
                      onClick={() => {
                        if (setSignUpFormTab) setSignUpFormTab('student');
                        navigate('/signup?tab=admission');
                      }}
                      className="flex-1 sm:flex-initial px-7 py-4 rounded-xl bg-[#F4B323] hover:bg-[#e0a21a] text-[#091A32] font-black text-sm shadow-lg hover:shadow-xl transition-all flex items-center justify-center gap-2.5 cursor-pointer"
                    >
                      <FileText className="w-4 h-4 text-[#091A32]" />
                      <span>Online Admission Form &rarr;</span>
                    </button>
                  ) : (
                    <button
                      type="button"
                      onClick={() => {
                        if (openEnquiriesModal) {
                          openEnquiriesModal('admissions');
                        } else if (setIsEnquiriesModalOpen) {
                          setIsEnquiriesModalOpen(true);
                        }
                      }}
                      className="flex-1 sm:flex-initial px-7 py-4 rounded-xl bg-[#F4B323] hover:bg-[#e0a21a] text-[#091A32] font-black text-sm shadow-lg hover:shadow-xl transition-all flex items-center justify-center gap-2.5 cursor-pointer"
                    >
                      <MessageSquare className="w-4 h-4 text-[#091A32]" />
                      <span>Enquire for Next Session &rarr;</span>
                    </button>
                  )}

                  <a
                    href="#contact"
                    className="flex-1 sm:flex-initial px-6 py-4 rounded-xl bg-[#091A32] hover:bg-[#102747] text-white font-bold text-sm border border-white/20 shadow-md hover:shadow-lg transition-all flex items-center justify-center gap-2.5 cursor-pointer"
                  >
                    <Calendar className="w-4 h-4 text-[#F4B323]" />
                    <span>Book a School Visit &rarr;</span>
                  </a>
                </div>

              </div>
            </section>

            {/* ── SECTION 3: 5 SIGNATURE CAMPUS FEATURES (From Banner Cards) ── */}
            <section id="features" className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 scroll-mt-28">
              <div className="text-center space-y-2 mb-8 sm:mb-10">
                <span className="text-[11px] font-black uppercase tracking-widest text-[#102747] bg-[#102747]/8 px-3.5 py-1 rounded-full border border-[#102747]/15">
                  CAMPUS EXCELLENCE
                </span>
                <h2 className="text-2xl sm:text-3xl font-black text-[#14243B] tracking-tight">
                  5 Pillars of Mission Navodaya Public School
                </h2>
                <p className="text-xs sm:text-sm text-[#65748B] max-w-xl mx-auto">
                  Designed for safe, disciplined, and comprehensive schooling for students from Nursery to Grade 8.
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
                    <h3 className="text-sm font-black text-[#14243B]">Enriched Library</h3>
                    <p className="text-xs text-[#65748B] mt-1 leading-relaxed">
                      Wide range of books, NCERT textbooks, and inspiring learning resources.
                    </p>
                  </div>
                </div>

                {/* 2. Computer & Tech Wing */}
                <div className="bg-white rounded-2xl p-5 border border-[#E2E8F0] shadow-xs hover:shadow-md transition-all space-y-3 group">
                  <div className="w-12 h-12 rounded-xl bg-blue-50 text-blue-700 flex items-center justify-center font-bold group-hover:scale-105 transition-transform shadow-2xs">
                    <Monitor className="w-6 h-6 text-blue-600" />
                  </div>
                  <div>
                    <h3 className="text-sm font-black text-[#14243B]">Computer &amp; Tech Wing</h3>
                    <p className="text-xs text-[#65748B] mt-1 leading-relaxed">
                      Modern digital learning, dedicated computer lab, and practical tech skills.
                    </p>
                  </div>
                </div>

                {/* 3. Sports & Physical Fitness */}
                <div className="bg-white rounded-2xl p-5 border border-[#E2E8F0] shadow-xs hover:shadow-md transition-all space-y-3 group">
                  <div className="w-12 h-12 rounded-xl bg-emerald-50 text-emerald-700 flex items-center justify-center font-bold group-hover:scale-105 transition-transform shadow-2xs">
                    <Trophy className="w-6 h-6 text-emerald-600" />
                  </div>
                  <div>
                    <h3 className="text-sm font-black text-[#14243B]">Sports &amp; Physical Fitness</h3>
                    <p className="text-xs text-[#65748B] mt-1 leading-relaxed">
                      Spacious open playground for football, athletics, and overall development.
                    </p>
                  </div>
                </div>

                {/* 4. Safe & Secure Campus */}
                <div className="bg-white rounded-2xl p-5 border border-[#E2E8F0] shadow-xs hover:shadow-md transition-all space-y-3 group">
                  <div className="w-12 h-12 rounded-xl bg-indigo-50 text-indigo-700 flex items-center justify-center font-bold group-hover:scale-105 transition-transform shadow-2xs">
                    <ShieldCheck className="w-6 h-6 text-indigo-600" />
                  </div>
                  <div>
                    <h3 className="text-sm font-black text-[#14243B]">Safe &amp; Secure Campus</h3>
                    <p className="text-xs text-[#65748B] mt-1 leading-relaxed">
                      A disciplined, walled, and caring environment ensuring student safety.
                    </p>
                  </div>
                </div>

                {/* 5. Dedicated Teachers */}
                <div className="bg-white rounded-2xl p-5 border border-[#E2E8F0] shadow-xs hover:shadow-md transition-all space-y-3 group">
                  <div className="w-12 h-12 rounded-xl bg-purple-50 text-purple-700 flex items-center justify-center font-bold group-hover:scale-105 transition-transform shadow-2xs">
                    <Users className="w-6 h-6 text-purple-600" />
                  </div>
                  <div>
                    <h3 className="text-sm font-black text-[#14243B]">Dedicated Teachers</h3>
                    <p className="text-xs text-[#65748B] mt-1 leading-relaxed">
                      Experienced, caring, and supportive faculty devoted to each child.
                    </p>
                  </div>
                </div>

              </div>
            </section>

            {/* ── SECTION 4: SCHOOL LEADERSHIP ── */}
            <section id="leadership" className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 scroll-mt-28">
              <div className="text-center space-y-2 mb-8 sm:mb-12">
                <span className="text-[11px] font-black uppercase tracking-widest text-[#102747] bg-[#102747]/8 px-3.5 py-1 rounded-full border border-[#102747]/15">
                  LEADERSHIP &amp; VISION
                </span>
                <h2 className="text-2xl sm:text-3xl font-black text-[#14243B] tracking-tight">
                  Guided by Experience, Integrity &amp; Dedication
                </h2>
                <p className="text-xs sm:text-sm text-[#65748B] max-w-xl mx-auto">
                  Meet the leadership team steering Mission Navodaya Public School toward academic excellence and values-driven education.
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
                        <span>CHAIRMAN &amp; FOUNDER</span>
                      </div>
                      <div className="absolute inset-0 bg-gradient-to-t from-black/75 via-transparent to-transparent" />
                      <div className="absolute bottom-3.5 left-4 right-4 text-white">
                        <h3 className="text-lg font-black tracking-tight drop-shadow">Uday Shankar Patel</h3>
                        <p className="text-[11px] text-[#F4B323] font-bold uppercase tracking-wider">Chairman &amp; Founder</p>
                      </div>
                    </div>
                    <div className="p-6 space-y-3">
                      <p className="text-xs text-[#65748B] leading-relaxed italic">
                        &ldquo;Education is not merely acquiring degrees; it is about cultivating moral character, discipline, and building a foundation that empowers every child to serve society with pride.&rdquo;
                      </p>
                    </div>
                  </div>
                  <div className="px-6 py-4 bg-slate-50 border-t border-[#E2E8F0] flex items-center gap-2 text-xs font-bold text-[#102747]">
                    <Building className="w-4 h-4 text-[#F4B323]" />
                    <span>Chairman&apos;s Secretariat · Founder&apos;s Desk</span>
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
                        <span>MANAGING DIRECTOR</span>
                      </div>
                      <div className="absolute inset-0 bg-gradient-to-t from-black/75 via-transparent to-transparent" />
                      <div className="absolute bottom-3.5 left-4 right-4 text-white">
                        <h3 className="text-lg font-black tracking-tight drop-shadow">Vishal Patel</h3>
                        <p className="text-[11px] text-blue-200 font-bold uppercase tracking-wider">Managing Director</p>
                      </div>
                    </div>
                    <div className="p-6 space-y-3">
                      <p className="text-xs text-[#65748B] leading-relaxed italic">
                        &ldquo;We combine modern educational infrastructure with deep-rooted values, ensuring that our students excel in academics, technology, and life skills.&rdquo;
                      </p>
                    </div>
                  </div>
                  <div className="px-6 py-4 bg-slate-50 border-t border-[#E2E8F0] flex items-center gap-2 text-xs font-bold text-[#102747]">
                    <Shield className="w-4 h-4 text-[#102747]" />
                    <span>Executive Operations &amp; Administration</span>
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
                        <span>PRINCIPAL</span>
                      </div>
                      <div className="absolute inset-0 bg-gradient-to-t from-black/75 via-transparent to-transparent" />
                      <div className="absolute bottom-3.5 left-4 right-4 text-white">
                        <h3 className="text-lg font-black tracking-tight drop-shadow">Soni Madam</h3>
                        <p className="text-[11px] text-emerald-300 font-bold uppercase tracking-wider">Principal</p>
                      </div>
                    </div>
                    <div className="p-6 space-y-3">
                      <p className="text-xs text-[#65748B] leading-relaxed italic">
                        &ldquo;Every student has unique potential. Our faculty is devoted to personalized mentorship, holistic growth, and academic rigor in a nurturing atmosphere.&rdquo;
                      </p>
                    </div>
                  </div>
                  <div className="px-6 py-4 bg-slate-50 border-t border-[#E2E8F0] flex items-center gap-2 text-xs font-bold text-[#102747]">
                    <School className="w-4 h-4 text-emerald-600" />
                    <span>Academic Administration &amp; Faculty Head</span>
                  </div>
                </div>
              </div>
            </section>

            {/* ── SECTION 5: REAL CAMPUS PHOTO GALLERY ── */}
            <section id="campus-gallery" className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 scroll-mt-28">
              <div className="text-center space-y-2 mb-8 sm:mb-12">
                <span className="text-[11px] font-black uppercase tracking-widest text-[#102747] bg-[#102747]/8 px-3.5 py-1 rounded-full border border-[#102747]/15">
                  CAMPUS GALLERY
                </span>
                <h2 className="text-2xl sm:text-3xl font-black text-[#14243B] tracking-tight">
                  Life at Mission Navodaya Public School, Mora
                </h2>
                <p className="text-xs sm:text-sm text-[#65748B] max-w-xl mx-auto">
                  A serene, green, and spacious campus built for modern learning, sports, and holistic character building.
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
                    <h3 className="text-sm font-bold text-[#14243B]">Main Campus Entrance</h3>
                    <p className="text-[11px] text-[#65748B]">Secure entrance with official school identification</p>
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
                    <h3 className="text-sm font-bold text-[#14243B]">Sports &amp; Football Arena</h3>
                    <p className="text-[11px] text-[#65748B]">Expansive open playground for athletics and football</p>
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
                    <h3 className="text-sm font-bold text-[#14243B]">Academic Building Block</h3>
                    <p className="text-[11px] text-[#65748B]">Spacious, ventilated classrooms and digital study points</p>
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
                    <h3 className="text-sm font-bold text-[#14243B]">Student Arrival &amp; Life</h3>
                    <p className="text-[11px] text-[#65748B]">Disciplined campus gates, bicycle parking and arrival</p>
                  </div>
                </div>
              </div>
            </section>

            {/* ── SECTION 6: CONTACT & CAMPUS HELPLINE (Direct from Banner Footer Strip) ── */}
            <section id="contact" className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 scroll-mt-28">
              <div className="bg-white rounded-3xl border border-[#E2E8F0] shadow-sm p-6 sm:p-10 space-y-8">
                
                {/* Header */}
                <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 border-b border-[#E2E8F0] pb-6">
                  <div>
                    <span className="text-[11px] font-black uppercase tracking-widest text-[#102747] bg-[#102747]/8 px-3.5 py-1 rounded-full border border-[#102747]/15">
                      REACH OUT
                    </span>
                    <h2 className="text-2xl sm:text-3xl font-black text-[#14243B] tracking-tight mt-2">
                      Reach Out to Mission Navodaya Public School
                    </h2>
                    <p className="text-xs sm:text-sm text-[#65748B] mt-1">
                      Official admission desk, phone helpline, and visiting hours for parents and guardians.
                    </p>
                  </div>

                  <div className="flex flex-wrap items-center gap-3">
                    <a
                      href={`tel:${primaryPhone}`}
                      className="px-5 py-3 rounded-xl bg-[#102747] hover:bg-[#091A32] text-white text-xs font-bold transition-all shadow-xs inline-flex items-center gap-2 cursor-pointer"
                    >
                      <Phone className="w-4 h-4 text-[#F4B323]" />
                      <span>Call Helpline: +91 {primaryPhone}</span>
                    </a>
                    <a
                      href={`https://wa.me/91${primaryPhone}`}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="px-5 py-3 rounded-xl bg-emerald-600 hover:bg-emerald-700 text-white text-xs font-bold transition-all shadow-xs inline-flex items-center gap-2 cursor-pointer"
                    >
                      <MessageSquare className="w-4 h-4" />
                      <span>WhatsApp Desk</span>
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
                      Our School Campus<br />
                      Mora, Siwan District<br />
                      Bihar, India
                    </p>
                    <a
                      href="https://maps.google.com/?q=Mission+Navodaya+Public+School+Mora+Bihar"
                      target="_blank"
                      rel="noopener noreferrer"
                      className="text-[11px] font-bold text-[#102747] hover:underline inline-flex items-center gap-1 pt-1"
                    >
                      <span>Open Google Maps</span>
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
                      Call / WhatsApp Desk<br />
                      Alt Helpline: +91 {altPhone}<br />
                      Monday through Saturday
                    </p>
                    <a
                      href={`https://wa.me/91${primaryPhone}`}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="text-[11px] font-bold text-emerald-700 hover:underline inline-flex items-center gap-1 pt-1"
                    >
                      <span>Chat on WhatsApp</span>
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
                      Official Institutional Email<br />
                      Admissions &amp; Verification<br />
                      Student Inquiries
                    </p>
                    <a
                      href={`mailto:${officialEmail}`}
                      className="text-[11px] font-bold text-[#102747] hover:underline inline-flex items-center gap-1 pt-1"
                    >
                      <span>Send Direct Mail</span>
                      <ArrowRight className="w-3 h-3" />
                    </a>
                  </div>

                  {/* School Timings */}
                  <div className="p-4 rounded-xl bg-slate-50 border border-[#E2E8F0] space-y-2">
                    <div className="w-9 h-9 rounded-lg bg-purple-50 text-purple-700 flex items-center justify-center font-bold">
                      <Clock className="w-4.5 h-4.5" />
                    </div>
                    <h3 className="text-sm font-bold text-[#14243B]">School Timings</h3>
                    <p className="text-xs text-[#65748B] leading-relaxed">
                      Monday – Saturday<br />
                      <strong>8:00 AM – 2:00 PM</strong><br />
                      Sunday: Closed
                    </p>
                    <div className="text-[11px] text-purple-700 font-semibold pt-1">
                      <span>Administrative &amp; Fee Counter Open</span>
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
                <span>&larr; Back to School Website</span>
              </button>

              <div className="text-center space-y-1.5 mb-6">
                <div className="w-14 h-14 mx-auto rounded-2xl bg-white border border-[#E2E8F0] p-1.5 shadow-xs flex items-center justify-center overflow-hidden">
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
                  {role === 'parent' ? 'Parent Portal Sign In' : role === 'teacher' ? 'Faculty & Teacher Sign In' : 'Principal Administration Portal'}
                </h2>
                <p className="text-xs text-[#65748B] font-medium">
                  {role === 'parent'
                    ? 'Access your child’s fee statement, attendance records and report cards'
                    : 'Secure institutional portal for authenticated staff and administration'}
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
                  <span>Parent</span>
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
                  <span>Teacher</span>
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
                  <span>Principal</span>
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
                        Child Admission ID or Roll Number *
                      </label>
                      <div className="relative">
                        <Hash className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
                        <input
                          type="text"
                          required
                          value={parentAdmissionNo}
                          onChange={(e) => setParentAdmissionNo(e.target.value)}
                          placeholder="e.g. MNP-2026-0042 or Roll Number"
                          className="w-full pl-10 pr-4 py-3 rounded-xl bg-slate-50 border border-[#E2E8F0] text-xs font-medium text-[#14243B] placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-[#102747]/20 focus:border-[#102747] transition-all"
                        />
                      </div>
                    </div>

                    <div>
                      <label className="block text-xs font-bold text-[#14243B] mb-1.5">
                        Registered Parent Mobile Number *
                      </label>
                      <div className="relative">
                        <Phone className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
                        <input
                          type="tel"
                          required
                          value={parentMobile}
                          onChange={(e) => setParentMobile(e.target.value)}
                          placeholder="Enter 10-digit mobile number"
                          className="w-full pl-10 pr-4 py-3 rounded-xl bg-slate-50 border border-[#E2E8F0] text-xs font-medium text-[#14243B] placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-[#102747]/20 focus:border-[#102747] transition-all"
                        />
                      </div>
                      <p className="text-[10px] text-[#65748B] mt-1">
                        Used to verify enrollment and safeguard your child’s records.
                      </p>
                    </div>
                  </div>
                ) : (
                  /* PRINCIPAL & TEACHER LOGIN FIELDS */
                  <div className="space-y-4 animate-in fade-in">
                    <div>
                      <label className="block text-xs font-bold text-[#14243B] mb-1.5">
                        {role === 'teacher' ? 'Registered School Email Address *' : 'Principal / Admin Email *'}
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
                          Select Your Teacher Name *
                        </label>
                        <div className="relative">
                          <User className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
                          <select
                            required
                            value={selectedTeacherId}
                            onChange={(e) => setSelectedTeacherId(e.target.value)}
                            className="w-full pl-10 pr-10 py-3 rounded-xl bg-slate-50 border border-[#E2E8F0] text-xs font-semibold text-[#14243B] focus:outline-none focus:ring-2 focus:ring-[#102747]/20 focus:border-[#102747] transition-all appearance-none cursor-pointer"
                          >
                            <option value="">-- Choose Your Teacher Profile --</option>
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
                          {role === 'teacher' ? 'Teacher Password *' : 'Admin Password *'}
                        </label>
                        {role === 'principal' && (
                          <button
                            type="button"
                            onClick={() => navigate('/forgot-password')}
                            className="text-[11px] font-bold text-[#102747] hover:underline cursor-pointer"
                          >
                            Forgot Password?
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
                          placeholder="Enter password"
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
                    <span>Remember this device</span>
                  </label>
                  <span className="text-[10px] text-emerald-700 font-bold flex items-center gap-1">
                    <ShieldCheck className="w-3 h-3 text-emerald-600" />
                    <span>256-bit Encrypted</span>
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
                      <span>Authenticating Credentials...</span>
                    </>
                  ) : (
                    <>
                      <span>Sign In to {role === 'parent' ? 'Parent Desk' : role === 'teacher' ? 'Teacher Console' : 'Admin Portal'}</span>
                      <ArrowRight className="w-4 h-4 text-[#F4B323]" />
                    </>
                  )}
                </button>
              </form>

              {/* In-Modal School Contact Help Desk */}
              <div className="mt-6 pt-5 border-t border-[#E2E8F0] text-center space-y-1.5">
                <p className="text-[11px] text-[#65748B]">
                  {role === 'parent'
                    ? 'Need help finding your child admission ID? Contact the school helpline:'
                    : 'For credentials assistance, contact the Principal Secretariat:'}
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
                <div className="w-11 h-11 rounded-xl bg-white border border-[#E2E8F0] p-1 flex items-center justify-center flex-shrink-0 overflow-hidden shadow-xs">
                  <img src={logoSrc} alt={schoolName} className="w-full h-full object-contain" />
                </div>
                <div>
                  <h3 className="text-sm font-black text-white tracking-tight uppercase">{schoolName}</h3>
                  <p className="text-[11px] text-[#F4B323] font-medium">{schoolSubtitle}</p>
                </div>
              </div>
              <p className="text-xs text-slate-300 leading-relaxed">
                Dedicated to nurturing young minds with knowledge, character, discipline, and life skills for a brighter future.
              </p>
              <div className="inline-flex items-center gap-2 px-3 py-1 rounded-lg bg-[#102747] text-[11px] font-bold text-[#F4B323] border border-[#1E3A60]">
                <span className="w-2 h-2 rounded-full bg-emerald-400 animate-pulse" />
                <span>Session 2026–27 Nursery to 8th</span>
              </div>
            </div>

            {/* Column 2: Quick Links */}
            <div className="space-y-3">
              <h4 className="text-xs font-black uppercase tracking-wider text-[#F4B323]">
                Explore Campus
              </h4>
              <ul className="space-y-2 text-xs text-slate-300 font-medium">
                <li>
                  <a href="#about" className="hover:text-[#F4B323] transition-colors">About the School</a>
                </li>
                <li>
                  <a href="#admissions" className="hover:text-[#F4B323] transition-colors text-[#F4B323] font-bold">Admissions 2026–27 &rarr;</a>
                </li>
                <li>
                  <a href="#features" className="hover:text-[#F4B323] transition-colors">5 Campus Pillars</a>
                </li>
                <li>
                  <a href="#leadership" className="hover:text-[#F4B323] transition-colors">Leadership &amp; Vision</a>
                </li>
                <li>
                  <a href="#campus-gallery" className="hover:text-[#F4B323] transition-colors">Photo Gallery</a>
                </li>
                <li>
                  <a href="#contact" className="hover:text-[#F4B323] transition-colors">Help &amp; Office Desk</a>
                </li>
              </ul>
            </div>

            {/* Column 3: Digital Portals */}
            <div className="space-y-3">
              <h4 className="text-xs font-black uppercase tracking-wider text-[#F4B323]">
                Digital Portals
              </h4>
              <ul className="space-y-2 text-xs text-slate-300 font-medium">
                <li>
                  <button
                    type="button"
                    onClick={() => openPortalLogin('parent')}
                    className="hover:text-[#F4B323] transition-colors cursor-pointer text-left"
                  >
                    Parent Portal Login &rarr;
                  </button>
                </li>
                <li>
                  <button
                    type="button"
                    onClick={() => openPortalLogin('teacher')}
                    className="hover:text-[#F4B323] transition-colors cursor-pointer text-left"
                  >
                    Faculty &amp; Teacher Console &rarr;
                  </button>
                </li>
                <li>
                  <button
                    type="button"
                    onClick={() => openPortalLogin('principal')}
                    className="hover:text-[#F4B323] transition-colors cursor-pointer text-left"
                  >
                    Principal Administrative Access &rarr;
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
                    Student Admission Desk &rarr;
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
                    Teacher Recruitment Application &rarr;
                  </a>
                </li>
              </ul>
            </div>

            {/* Column 4: Contact & Office Strip */}
            <div className="space-y-3">
              <h4 className="text-xs font-black uppercase tracking-wider text-[#F4B323]">
                Campus &amp; Office
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
                  <span>Monday – Saturday: 8:00 AM – 2:00 PM</span>
                </div>
              </div>
            </div>

          </div>

          {/* Bottom Navy Footer Strip (Matching Image) */}
          <div className="mt-12 pt-6 border-t border-[#1E3A60] flex flex-col sm:flex-row items-center justify-between gap-4 text-xs text-slate-400">
            <div>
              &copy; {new Date().getFullYear()} <strong>{schoolName}</strong>. All rights reserved.
            </div>
            <div className="flex items-center gap-3 text-[11px]">
              <span>{schoolLocation}</span>
              <span>&bull;</span>
              <span>Official Institutional Management System</span>
            </div>
          </div>

        </div>
      </footer>

    </div>
  );
}
