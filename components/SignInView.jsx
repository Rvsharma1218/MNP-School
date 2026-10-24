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
  Activity, Monitor, Trophy, HelpCircle, MapPin, Clock, MessageSquare, Globe, Briefcase
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
    setSignUpFormTab
  } = useSchoolStore();

  const t = translations[language] || translations.en;

  const [isLoginModalOpen, setIsLoginModalOpen] = useState(false);
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [role, setRole] = useState('parent'); // Default to parent for ease
  const [parentAdmissionNo, setParentAdmissionNo] = useState('');
  const [parentMobile, setParentMobile] = useState('');
  const [selectedTeacherId, setSelectedTeacherId] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [rememberMe, setRememberMe] = useState(true);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  const schoolName = settings?.instituteName || settings?.schoolName || 'Mission Navodaya Public School';
  const principalName = settings?.principalName || 'Vishal Kumar';
  const logoSrc = settings?.logoUrl || settings?.logoPath || settings?.logo || '/logo.png';
  const phone = settings?.phone || '8603481865';
  const officialEmail = settings?.email || 'mnpschooledu@gmail.com';
  const campusAddress = settings?.address || 'Mora Bazar Campus';

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

  const openPortalLogin = (targetRole = 'parent') => {
    setRole(targetRole);
    setError('');
    setIsLoginModalOpen(true);
    window.scrollTo({ top: 0, behavior: 'smooth' });
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
    <div className="min-h-screen w-full relative flex flex-col justify-between font-sans antialiased text-[#0f172a] bg-[#f8fafc] selection:bg-[#0c2340] selection:text-white">

      {/* 🔹 Top Navigation Bar with Language Switcher 🔹 */}
      <header
        className="sticky top-0 z-30 w-full px-3.5 sm:px-6 py-3 md:px-12 flex items-center justify-between border-b border-amber-500/40 shadow-md text-white transition-all relative overflow-hidden backdrop-blur-md"
        style={{
          backgroundImage: "linear-gradient(to right, rgba(6, 20, 44, 0.95), rgba(10, 32, 66, 0.88), rgba(6, 20, 44, 0.95)), url('/header_campus_bg.jpg')",
          backgroundSize: "cover",
          backgroundPosition: "center"
        }}
      >
        <div className="flex items-center gap-3.5">
          <div className="w-11 h-11 rounded-xl bg-slate-50 border border-slate-200 p-1 flex items-center justify-center flex-shrink-0 shadow-2xs overflow-hidden">
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
          <div>
            <h1 className="text-sm sm:text-base md:text-lg font-black tracking-tight text-white drop-shadow-sm truncate max-w-[170px] xs:max-w-[240px] sm:max-w-none">
              {t.schoolName}
            </h1>
            <p className="text-[10px] sm:text-[11px] text-amber-300 font-bold tracking-wide truncate">
              {t.sessionBadge}
            </p>
          </div>
        </div>

        {/* Top Action Buttons & Language Switcher */}
        <div className="flex items-center gap-2.5">
          <nav className="hidden lg:flex items-center gap-5 mr-2 text-xs font-bold text-slate-200">
            <a href="#about" className="hover:text-amber-300 transition-colors">{t.aboutSchool}</a>
            <a href="#leadership" className="hover:text-amber-300 transition-colors">{t.leadership}</a>
            <a href="#facilities" className="hover:text-amber-300 transition-colors">{t.facilities}</a>
            <a href="#contact" className="hover:text-amber-300 transition-colors">{t.helpAndContact}</a>
          </nav>

          {/* Language Switcher */}
          <button
            type="button"
            onClick={toggleLanguage}
            className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-white/12 hover:bg-white/20 border border-white/25 text-xs font-bold text-white transition-all cursor-pointer shadow-2xs"
            title="Toggle English / हिन्दी"
          >
            <Globe className="w-3.5 h-3.5 text-blue-600" />
            <span>{t.langLabel}</span>
          </button>

          {/* Admission Form Link */}
          <button
            type="button"
            onClick={() => navigate('/signup')}
            className="hidden sm:inline-flex items-center gap-1.5 px-3 py-2 rounded-xl text-xs font-bold text-amber-700 bg-amber-50 hover:bg-amber-100 border border-amber-200 transition-all cursor-pointer"
          >
            <Sparkles className="w-3.5 h-3.5 text-amber-600" />
            <span>{t.admissionEnquiry}</span>
          </button>

          <button
            type="button"
            onClick={() => openPortalLogin('parent')}
            className="hidden md:inline-flex items-center gap-2 px-3.5 py-2 rounded-xl text-xs font-bold text-white bg-white/12 hover:bg-white/20 border border-white/25 transition-all cursor-pointer"
          >
            <Users className="w-3.5 h-3.5 text-[#0c2340]" />
            <span>{t.parentLogin}</span>
          </button>

          <button
            type="button"
            onClick={() => openPortalLogin('principal')}
            className="inline-flex items-center gap-2 px-4 py-2 rounded-xl text-xs font-bold text-white bg-[#0c2340] hover:bg-[#153459] shadow-sm hover:shadow transition-all cursor-pointer"
          >
            <ShieldCheck className="w-4 h-4 text-amber-300" />
            <span>{t.portalLogin}</span>
          </button>
        </div>
      </header>

      {/* 🔹 Main Content Area 🔹 */}
      <main className="flex-1 w-full">
        {!isLoginModalOpen ? (
          /* ========================================================== */
          /*  STAGE 1: CLEAN LIGHT LANDING & SCHOOL SHOWCASE            */
          /* ========================================================== */
          <div className="w-full space-y-16 py-8 md:py-12 animate-in fade-in duration-300">

            {/* 1. Hero Showcase Section */}
            <section id="about" className="max-w-6xl mx-auto px-6 text-center space-y-6 scroll-mt-24">
              <div className="inline-flex items-center gap-2 px-4 py-1.5 rounded-full bg-blue-50 border border-blue-200/80 text-xs font-bold text-[#0c2340] shadow-2xs">
                <Sparkles className="w-3.5 h-3.5 text-amber-500" />
                <span>{t.qualityEduBadge}</span>
              </div>

              <h2 className="text-3xl sm:text-5xl font-black text-[#0c2340] tracking-tight leading-[1.2] max-w-4xl mx-auto">
                {t.heroTitle}
              </h2>

              <p className="text-sm sm:text-base text-[#475569] max-w-2xl mx-auto leading-relaxed">
                {t.heroSubtitle}
              </p>

              {/* Action Buttons in Hero */}
              <div className="pt-2 flex flex-wrap items-center justify-center gap-3.5">
                <a
                  id="admission-desk-hero-btn"
                  href="/signup?tab=admission"
                  onClick={(e) => {
                    e.preventDefault();
                    if (setSignUpFormTab) setSignUpFormTab('student');
                    navigate('/signup?tab=admission');
                  }}
                  className="px-6 py-3.5 rounded-xl bg-[#0c2340] hover:bg-[#153459] text-white font-bold text-xs shadow-md hover:shadow-lg transition-all flex items-center gap-2.5 cursor-pointer"
                >
                  <FileText className="w-4 h-4 text-amber-300" />
                  <span>{t.admissionDeskBtn}</span>
                  <ArrowRight className="w-4 h-4" />
                </a>

                <a
                  id="faculty-recruitment-hero-btn"
                  href="/signup?tab=faculty"
                  onClick={(e) => {
                    e.preventDefault();
                    if (setSignUpFormTab) setSignUpFormTab('teacher');
                    navigate('/signup?tab=faculty');
                  }}
                  className="px-6 py-3.5 rounded-xl bg-white hover:bg-slate-50 text-[#0c2340] font-bold text-xs border border-slate-300 shadow-2xs transition-all flex items-center gap-2.5 cursor-pointer"
                >
                  <Briefcase className="w-4 h-4 text-indigo-700" />
                  <span>{t.teacherApplicationBtn}</span>
                </a>
              </div>

              {/* Official School Banner with Campus Gate & Logo */}
              <div className="pt-6 max-w-6xl mx-auto w-full">
                <div className="relative rounded-3xl overflow-hidden shadow-2xl border-2 border-amber-500/40 group bg-[#07182D]">
                  <img
                    src="/school_official_banner.png"
                    alt="Mission Navodaya Public School Banner"
                    className="w-full h-auto max-h-[580px] object-cover object-center transition-transform duration-700 group-hover:scale-[1.01]"
                  />
                </div>
              </div>

              {/* Fast Facts Badge Bar */}
              <div className="pt-6 grid grid-cols-2 sm:grid-cols-4 gap-3 max-w-4xl mx-auto">
                <div className="p-3.5 bg-white rounded-2xl border border-slate-200/90 shadow-2xs text-left">
                  <div className="text-lg font-black text-[#0c2340]">{t.dailyRollTitle}</div>
                  <div className="text-[11px] font-medium text-[#64748b] mt-0.5">{t.dailyRollDesc}</div>
                </div>
                <div className="p-3.5 bg-white rounded-2xl border border-slate-200/90 shadow-2xs text-left">
                  <div className="text-lg font-black text-[#0c2340]">{t.feeCounterTitle}</div>
                  <div className="text-[11px] font-medium text-[#64748b] mt-0.5">{t.feeCounterDesc}</div>
                </div>
                <div className="p-3.5 bg-white rounded-2xl border border-slate-200/90 shadow-2xs text-left">
                  <div className="text-lg font-black text-[#0c2340]">{t.reportCardsTitle}</div>
                  <div className="text-[11px] font-medium text-[#64748b] mt-0.5">{t.reportCardsDesc}</div>
                </div>
                <div className="p-3.5 bg-white rounded-2xl border border-slate-200/90 shadow-2xs text-left">
                  <div className="text-lg font-black text-[#0c2340]">{t.smartCampusTitle}</div>
                  <div className="text-[11px] font-medium text-[#64748b] mt-0.5">{t.smartCampusDesc}</div>
                </div>
              </div>
            </section>

            {/* 2. School Leadership Section */}
            <section id="leadership" className="max-w-6xl mx-auto px-6 scroll-mt-24">
              <div className="text-center space-y-2 mb-8">
                <span className="text-[11px] font-extrabold uppercase tracking-widest text-[#0c2340] bg-slate-100 px-3 py-1 rounded-full border border-slate-200">
                  {t.leadershipBadge}
                </span>
                <h3 className="text-2xl sm:text-3xl font-black text-[#0c2340] tracking-tight">
                  {t.leadershipHeading}
                </h3>
                <p className="text-xs sm:text-sm text-[#64748b] max-w-xl mx-auto">
                  {t.leadershipSubheading}
                </p>
              </div>

              <div className="grid grid-cols-1 md:grid-cols-3 gap-7">
                {/* 1. Chairman: Uday Shankar Patel */}
                <div className="bg-white rounded-3xl overflow-hidden border border-slate-200/80 shadow-sm hover:shadow-xl transition-all duration-300 flex flex-col justify-between group">
                  <div>
                    <div className="relative h-72 sm:h-80 w-full overflow-hidden bg-slate-100">
                      <img
                        src="/chairman_uday_shankar_patel.jpg"
                        alt="Uday Shankar Patel - Chairman"
                        className="w-full h-full object-cover object-top transition-transform duration-500 group-hover:scale-105"
                      />
                      <div className="absolute top-3.5 left-3.5 px-3 py-1 rounded-full bg-amber-500 text-white font-black text-[10px] tracking-wider uppercase shadow-md flex items-center gap-1.5">
                        <Award className="w-3.5 h-3.5" />
                        <span>CHAIRMAN & FOUNDER</span>
                      </div>
                      <div className="absolute inset-0 bg-gradient-to-t from-black/60 via-transparent to-transparent" />
                      <div className="absolute bottom-3 left-4 right-4 text-white">
                        <h4 className="text-lg font-black tracking-tight drop-shadow">Uday Shankar Patel</h4>
                        <p className="text-[11px] text-amber-300 font-semibold uppercase tracking-wider">Chairman</p>
                      </div>
                    </div>
                    <div className="p-6 space-y-3">
                      <p className="text-xs text-[#475569] leading-relaxed italic">
                        {t.chairmanQuote}
                      </p>
                    </div>
                  </div>
                  <div className="px-6 py-4 bg-slate-50/80 border-t border-slate-100 flex items-center gap-2 text-xs font-bold text-[#0c2340]">
                    <Building className="w-4 h-4 text-amber-600" />
                    <span>{t.chairmanOffice}</span>
                  </div>
                </div>

                {/* 2. Director: Vishal Patel */}
                <div className="bg-white rounded-3xl overflow-hidden border border-slate-200/80 shadow-sm hover:shadow-xl transition-all duration-300 flex flex-col justify-between group">
                  <div>
                    <div className="relative h-72 sm:h-80 w-full overflow-hidden bg-slate-100">
                      <img
                        src="/director_vishal_patel.jpg"
                        alt="Vishal Patel - Managing Director"
                        className="w-full h-full object-cover object-top transition-transform duration-500 group-hover:scale-105"
                      />
                      <div className="absolute top-3.5 left-3.5 px-3 py-1 rounded-full bg-blue-600 text-white font-black text-[10px] tracking-wider uppercase shadow-md flex items-center gap-1.5">
                        <ShieldCheck className="w-3.5 h-3.5" />
                        <span>MANAGING DIRECTOR</span>
                      </div>
                      <div className="absolute inset-0 bg-gradient-to-t from-black/60 via-transparent to-transparent" />
                      <div className="absolute bottom-3 left-4 right-4 text-white">
                        <h4 className="text-lg font-black tracking-tight drop-shadow">Vishal Patel</h4>
                        <p className="text-[11px] text-blue-300 font-semibold uppercase tracking-wider">Director</p>
                      </div>
                    </div>
                    <div className="p-6 space-y-3">
                      <p className="text-xs text-[#475569] leading-relaxed italic">
                        {t.directorQuote}
                      </p>
                    </div>
                  </div>
                  <div className="px-6 py-4 bg-slate-50/80 border-t border-slate-100 flex items-center gap-2 text-xs font-bold text-[#0c2340]">
                    <Shield className="w-4 h-4 text-blue-600" />
                    <span>{t.directorOffice}</span>
                  </div>
                </div>

                {/* 3. Principal: Soni Madam */}
                <div className="bg-white rounded-3xl overflow-hidden border border-slate-200/80 shadow-sm hover:shadow-xl transition-all duration-300 flex flex-col justify-between group">
                  <div>
                    <div className="relative h-72 sm:h-80 w-full overflow-hidden bg-slate-100">
                      <img
                        src="/principal_soni_madam.jpg"
                        alt="Soni Madam - Principal"
                        className="w-full h-full object-cover object-top transition-transform duration-500 group-hover:scale-105"
                      />
                      <div className="absolute top-3.5 left-3.5 px-3 py-1 rounded-full bg-emerald-600 text-white font-black text-[10px] tracking-wider uppercase shadow-md flex items-center gap-1.5">
                        <GraduationCap className="w-3.5 h-3.5" />
                        <span>PRINCIPAL</span>
                      </div>
                      <div className="absolute inset-0 bg-gradient-to-t from-black/60 via-transparent to-transparent" />
                      <div className="absolute bottom-3 left-4 right-4 text-white">
                        <h4 className="text-lg font-black tracking-tight drop-shadow">Soni Madam</h4>
                        <p className="text-[11px] text-emerald-300 font-semibold uppercase tracking-wider">Principal</p>
                      </div>
                    </div>
                    <div className="p-6 space-y-3">
                      <p className="text-xs text-[#475569] leading-relaxed italic">
                        {t.principalQuote}
                      </p>
                    </div>
                  </div>
                  <div className="px-6 py-4 bg-slate-50/80 border-t border-slate-100 flex items-center gap-2 text-xs font-bold text-[#0c2340]">
                    <School className="w-4 h-4 text-emerald-600" />
                    <span>{t.principalOffice}</span>
                  </div>
                </div>
              </div>
            </section>

            {/* 3. Campus Facilities */}
            <section id="facilities" className="max-w-6xl mx-auto px-6 scroll-mt-24">
              <div className="text-center space-y-2 mb-8">
                <span className="text-[11px] font-extrabold uppercase tracking-widest text-[#0c2340] bg-slate-100 px-3 py-1 rounded-full border border-slate-200">
                  {t.facilitiesBadge}
                </span>
                <h3 className="text-2xl sm:text-3xl font-black text-[#0c2340] tracking-tight">
                  {t.facilitiesHeading}
                </h3>
                <p className="text-xs sm:text-sm text-[#64748b] max-w-xl mx-auto">
                  {t.facilitiesSubheading}
                </p>
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-5">
                <div className="p-5 rounded-2xl bg-white border border-slate-200/80 shadow-2xs space-y-2.5">
                  <div className="w-10 h-10 rounded-xl bg-indigo-50 text-indigo-700 flex items-center justify-center font-bold">
                    <BookOpen className="w-5 h-5" />
                  </div>
                  <h4 className="text-sm font-bold text-[#0c2340]">{t.libTitle}</h4>
                  <p className="text-xs text-[#64748b] leading-relaxed">{t.libDesc}</p>
                </div>

                <div className="p-5 rounded-2xl bg-white border border-slate-200/80 shadow-2xs space-y-2.5">
                  <div className="w-10 h-10 rounded-xl bg-teal-50 text-teal-700 flex items-center justify-center font-bold">
                    <Monitor className="w-5 h-5" />
                  </div>
                  <h4 className="text-sm font-bold text-[#0c2340]">{t.techTitle}</h4>
                  <p className="text-xs text-[#64748b] leading-relaxed">{t.techDesc}</p>
                </div>

                <div className="p-5 rounded-2xl bg-white border border-slate-200/80 shadow-2xs space-y-2.5">
                  <div className="w-10 h-10 rounded-xl bg-rose-50 text-rose-700 flex items-center justify-center font-bold">
                    <Trophy className="w-5 h-5" />
                  </div>
                  <h4 className="text-sm font-bold text-[#0c2340]">{t.sportsTitle}</h4>
                  <p className="text-xs text-[#64748b] leading-relaxed">{t.sportsDesc}</p>
                </div>

                <div className="p-5 rounded-2xl bg-white border border-slate-200/80 shadow-2xs space-y-2.5">
                  <div className="w-10 h-10 rounded-xl bg-amber-50 text-amber-700 flex items-center justify-center font-bold">
                    <Users className="w-5 h-5" />
                  </div>
                  <h4 className="text-sm font-bold text-[#0c2340]">{t.parentDeskTitle}</h4>
                  <p className="text-xs text-[#64748b] leading-relaxed">{t.parentDeskDesc}</p>
                </div>
              </div>
            </section>

            {/* 3.5 Campus & Infrastructure Photo Gallery */}
            <section id="campus-gallery" className="max-w-6xl mx-auto px-6 scroll-mt-24">
              <div className="text-center space-y-2 mb-8">
                <span className="text-[11px] font-extrabold uppercase tracking-widest text-[#0c2340] bg-slate-100 px-3 py-1 rounded-full border border-slate-200">
                  CAMPUS & FACILITIES
                </span>
                <h3 className="text-2xl sm:text-3xl font-black text-[#0c2340] tracking-tight">
                  Life at Mission Navodaya Public School, Mora
                </h3>
                <p className="text-xs sm:text-sm text-[#64748b] max-w-xl mx-auto">
                  A serene, green, and spacious campus built for modern learning, sports, and holistic character building.
                </p>
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-5">
                {/* Gate Banner */}
                <div className="bg-white rounded-2xl overflow-hidden border border-slate-200/90 shadow-2xs group">
                  <div className="h-48 overflow-hidden bg-slate-100">
                    <img
                      src="/school_gate_banner.jpg"
                      alt="Main Gate - Mission Navodaya Public School"
                      className="w-full h-full object-cover transition-transform duration-500 group-hover:scale-105"
                    />
                  </div>
                  <div className="p-4 space-y-1">
                    <h5 className="text-sm font-bold text-[#0c2340]">Main Campus Entrance</h5>
                    <p className="text-[11px] text-slate-500">Secure gate with official school identification board</p>
                  </div>
                </div>

                {/* Playground */}
                <div className="bg-white rounded-2xl overflow-hidden border border-slate-200/90 shadow-2xs group">
                  <div className="h-48 overflow-hidden bg-slate-100">
                    <img
                      src="/campus_playground.jpg"
                      alt="Sports Ground and Playground"
                      className="w-full h-full object-cover transition-transform duration-500 group-hover:scale-105"
                    />
                  </div>
                  <div className="p-4 space-y-1">
                    <h5 className="text-sm font-bold text-[#0c2340]">Sports & Football Arena</h5>
                    <p className="text-[11px] text-slate-500">Expansive open playground for athletics and football</p>
                  </div>
                </div>

                {/* Academic Building */}
                <div className="bg-white rounded-2xl overflow-hidden border border-slate-200/90 shadow-2xs group">
                  <div className="h-48 overflow-hidden bg-slate-100">
                    <img
                      src="/campus_building.jpg"
                      alt="Academic Building"
                      className="w-full h-full object-cover transition-transform duration-500 group-hover:scale-105"
                    />
                  </div>
                  <div className="p-4 space-y-1">
                    <h5 className="text-sm font-bold text-[#0c2340]">Academic Building Block</h5>
                    <p className="text-[11px] text-slate-500">Spacious, ventilated classrooms and digital study points</p>
                  </div>
                </div>

                {/* School Entrance Life */}
                <div className="bg-white rounded-2xl overflow-hidden border border-slate-200/90 shadow-2xs group">
                  <div className="h-48 overflow-hidden bg-slate-100">
                    <img
                      src="/school_entrance.jpg"
                      alt="School Entrance and Students"
                      className="w-full h-full object-cover transition-transform duration-500 group-hover:scale-105"
                    />
                  </div>
                  <div className="p-4 space-y-1">
                    <h5 className="text-sm font-bold text-[#0c2340]">Student Arrival & Life</h5>
                    <p className="text-[11px] text-slate-500">Safe bicycle parking, disciplined campus gates and arrival</p>
                  </div>
                </div>
              </div>
            </section>

            {/* 4. Contact & Help Desk */}
            <section id="contact" className="max-w-6xl mx-auto px-6 scroll-mt-24">
              <div className="bg-white rounded-3xl border border-slate-200/90 shadow-sm p-6 sm:p-10 space-y-8">
                <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 border-b border-slate-100 pb-6">
                  <div>
                    <span className="text-[11px] font-extrabold uppercase tracking-widest text-[#0c2340] bg-slate-100 px-3 py-1 rounded-full border border-slate-200">
                      {t.contactBadge}
                    </span>
                    <h3 className="text-2xl sm:text-3xl font-black text-[#0c2340] tracking-tight mt-2">
                      {t.contactHeading}
                    </h3>
                    <p className="text-xs sm:text-sm text-[#64748b]">
                      {t.contactSubheading}
                    </p>
                  </div>

                  <div className="flex items-center gap-3">
                    <a
                      href={`tel:${phone}`}
                      className="px-4 py-2.5 rounded-xl bg-[#0c2340] hover:bg-[#153459] text-white text-xs font-bold transition-all shadow-xs inline-flex items-center gap-2 cursor-pointer"
                    >
                      <Phone className="w-3.5 h-3.5" />
                      <span>{t.callOfficeBtn}: +91 {phone}</span>
                    </a>
                    <a
                      href={`mailto:${officialEmail}`}
                      className="px-4 py-2.5 rounded-xl bg-slate-100 hover:bg-slate-200 text-[#0c2340] text-xs font-bold transition-all border border-slate-300 inline-flex items-center gap-2 cursor-pointer"
                    >
                      <Mail className="w-3.5 h-3.5" />
                      <span>{t.emailOfficeBtn}</span>
                    </a>
                  </div>
                </div>

                <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6">
                  {/* Address */}
                  <div className="space-y-2">
                    <div className="w-10 h-10 rounded-xl bg-blue-50 text-blue-700 flex items-center justify-center font-bold">
                      <MapPin className="w-5 h-5" />
                    </div>
                    <h4 className="text-sm font-bold text-[#0c2340]">{t.campusLocTitle}</h4>
                    <p className="text-xs text-[#64748b] leading-relaxed">
                      <strong>{schoolName}</strong><br />
                      {campusAddress}<br />
                      Dist. &amp; State, India
                    </p>
                  </div>

                  {/* Phone Helpline */}
                  <div className="space-y-2">
                    <div className="w-10 h-10 rounded-xl bg-emerald-50 text-emerald-700 flex items-center justify-center font-bold">
                      <Phone className="w-5 h-5" />
                    </div>
                    <h4 className="text-sm font-bold text-[#0c2340]">{t.helplineTitle}</h4>
                    <p className="text-xs text-[#64748b] leading-relaxed">
                      Main Desk: +91 {phone}<br />
                      WhatsApp: +91 {phone}<br />
                      School Working Days
                    </p>
                  </div>

                  {/* Email */}
                  <div className="space-y-2">
                    <div className="w-10 h-10 rounded-xl bg-amber-50 text-amber-700 flex items-center justify-center font-bold">
                      <Mail className="w-5 h-5" />
                    </div>
                    <h4 className="text-sm font-bold text-[#0c2340]">{t.emailTitle}</h4>
                    <p className="text-xs text-[#64748b] leading-relaxed">
                      {officialEmail}<br />
                      Admissions &amp; Queries
                    </p>
                  </div>

                  {/* Office Hours */}
                  <div className="space-y-2">
                    <div className="w-10 h-10 rounded-xl bg-purple-50 text-purple-700 flex items-center justify-center font-bold">
                      <Clock className="w-5 h-5" />
                    </div>
                    <h4 className="text-sm font-bold text-[#0c2340]">{t.visitingHoursTitle}</h4>
                    <p className="text-xs text-[#64748b] leading-relaxed whitespace-pre-line">
                      {t.visitingHoursDesc}
                    </p>
                  </div>
                </div>
              </div>
            </section>

            {/* 5. Bottom Admission & Enquiry Banner */}
            <section className="max-w-6xl mx-auto px-6">
              <div className="rounded-3xl bg-gradient-to-r from-[#0c2340] to-[#153459] text-white p-6 sm:p-8 flex flex-col sm:flex-row items-center justify-between gap-6 shadow-md">
                <div className="space-y-1 text-center sm:text-left">
                  <h4 className="text-xl font-bold">
                    {language === 'hi' ? 'सत्र 2026-27 के लिए नए नामांकन प्रारंभ हैं' : 'Admissions Open for Session 2026-27'}
                  </h4>
                  <p className="text-xs text-slate-300">
                    {language === 'hi'
                      ? 'अपने बच्चे के उज्ज्वल भविष्य के लिए आज ही ऑनलाइन प्रवेश पूछताछ फॉर्म भरें।'
                      : 'Register your interest today to secure admission for your child at Mission Navodaya Public School.'}
                  </p>
                </div>
                <div className="flex items-center gap-3">
                  <a
                    href={`tel:${phone}`}
                    className="px-5 py-3 rounded-xl bg-white/10 hover:bg-white/20 text-white font-bold text-xs border border-white/20 transition-all flex items-center gap-2 cursor-pointer flex-shrink-0"
                  >
                    <Phone className="w-3.5 h-3.5" />
                    <span>{t.callOfficeBtn}</span>
                  </a>
                  <button
                    type="button"
                    onClick={() => {
                      if (setSignUpFormTab) setSignUpFormTab('student');
                      navigate('/signup');
                    }}
                    className="px-6 py-3 rounded-xl bg-white text-[#0c2340] font-black text-xs hover:bg-slate-100 transition-all flex items-center gap-2 cursor-pointer shadow-sm flex-shrink-0"
                  >
                    <span>{t.admissionDeskBtn}</span>
                    <ArrowRight className="w-4 h-4" />
                  </button>
                </div>
              </div>
            </section>

          </div>
        ) : (
          /* ========================================================== */
          /*  STAGE 2: AUTHENTICATION MODAL (CLEAN LIGHT THEME)         */
          /* ========================================================== */
          <div className="w-full max-w-lg mx-auto py-10 px-4 animate-in zoom-in-95 duration-200">
            <div className="rounded-3xl bg-white border border-slate-200 shadow-xl p-6 sm:p-8 relative">

              {/* Back to Campus Landing Button */}
              <button
                type="button"
                onClick={() => setIsLoginModalOpen(false)}
                className="inline-flex items-center gap-2 px-3 py-1.5 rounded-xl bg-slate-100 hover:bg-slate-200 text-xs font-bold text-[#0c2340] transition-all cursor-pointer mb-5"
              >
                <ArrowLeft className="w-3.5 h-3.5" />
                <span>&larr; {t.backToHome}</span>
              </button>

              {/* School Header in Modal */}
              <div className="text-center space-y-1.5 mb-6">
                <div className="w-14 h-14 mx-auto rounded-2xl bg-slate-50 border border-slate-200 p-1.5 shadow-2xs flex items-center justify-center overflow-hidden">
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
                <h2 className="text-xl font-black text-[#0c2340] tracking-tight">
                  {t.modalTitle}
                </h2>
                <p className="text-xs text-[#64748b] font-medium">
                  {t.modalSubtitle}
                </p>
              </div>

              {/* Role Switcher Tabs */}
              <div className="grid grid-cols-3 p-1 rounded-2xl bg-slate-100 border border-slate-200 mb-6">
                <button
                  type="button"
                  onClick={() => { setRole('parent'); setError(''); }}
                  className={`py-2 px-2 rounded-xl text-xs font-extrabold flex flex-col sm:flex-row items-center justify-center gap-1.5 transition-all cursor-pointer ${
                    role === 'parent'
                      ? 'bg-white text-[#0c2340] shadow-sm'
                      : 'text-[#64748b] hover:text-amber-300'
                  }`}
                >
                  <Users className="w-3.5 h-3.5 text-amber-600" />
                  <span>{t.parentRole}</span>
                </button>

                <button
                  type="button"
                  onClick={() => { setRole('teacher'); setError(''); }}
                  className={`py-2 px-2 rounded-xl text-xs font-extrabold flex flex-col sm:flex-row items-center justify-center gap-1.5 transition-all cursor-pointer ${
                    role === 'teacher'
                      ? 'bg-white text-[#0c2340] shadow-sm'
                      : 'text-[#64748b] hover:text-amber-300'
                  }`}
                >
                  <GraduationCap className="w-3.5 h-3.5 text-blue-600" />
                  <span>{t.teacherRole}</span>
                </button>

                <button
                  type="button"
                  onClick={() => { setRole('principal'); setError(''); }}
                  className={`py-2 px-2 rounded-xl text-xs font-extrabold flex flex-col sm:flex-row items-center justify-center gap-1.5 transition-all cursor-pointer ${
                    role === 'principal'
                      ? 'bg-white text-[#0c2340] shadow-sm'
                      : 'text-[#64748b] hover:text-amber-300'
                  }`}
                >
                  <ShieldCheck className="w-3.5 h-3.5 text-emerald-600" />
                  <span>{t.principalRole}</span>
                </button>
              </div>

              {/* Error Alert Box */}
              {error && (
                <div className="mb-5 p-3 rounded-xl bg-rose-50 border border-rose-200 flex items-start gap-2.5 text-rose-700 text-xs animate-in fade-in">
                  <AlertCircle className="w-4 h-4 text-rose-600 flex-shrink-0 mt-0.5" />
                  <span className="leading-relaxed font-semibold">{error}</span>
                </div>
              )}

              {/* Dynamic Authentication Form */}
              <form onSubmit={handleSubmit} className="space-y-4">
                {role === 'parent' ? (
                  /* PARENT LOGIN FIELDS */
                  <div className="space-y-4 animate-in fade-in">
                    <div>
                      <label className="block text-xs font-bold text-[#0c2340] mb-1.5">
                        {t.admissionNoLabel}
                      </label>
                      <div className="relative">
                        <Hash className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
                        <input
                          type="text"
                          required
                          value={parentAdmissionNo}
                          onChange={(e) => setParentAdmissionNo(e.target.value)}
                          placeholder={t.admissionNoPlaceholder}
                          className="w-full pl-10 pr-4 py-3 rounded-xl bg-slate-50 border border-slate-300 text-xs font-medium text-[#0f172a] placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-[#0c2340]/20 focus:border-[#0c2340] transition-all"
                        />
                      </div>
                    </div>

                    <div>
                      <label className="block text-xs font-bold text-[#0c2340] mb-1.5">
                        {t.parentMobileLabel}
                      </label>
                      <div className="relative">
                        <Phone className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
                        <input
                          type="tel"
                          required
                          value={parentMobile}
                          onChange={(e) => setParentMobile(e.target.value)}
                          placeholder={t.parentMobilePlaceholder}
                          className="w-full pl-10 pr-4 py-3 rounded-xl bg-slate-50 border border-slate-300 text-xs font-medium text-[#0f172a] placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-[#0c2340]/20 focus:border-[#0c2340] transition-all"
                        />
                      </div>
                      <p className="text-[10px] text-slate-500 mt-1">
                        {t.parentMobileHelp}
                      </p>
                    </div>
                  </div>
                ) : (
                  /* PRINCIPAL & TEACHER LOGIN FIELDS */
                  <div className="space-y-4 animate-in fade-in">
                    <div>
                      <label className="block text-xs font-bold text-[#0c2340] mb-1.5">
                        {role === 'teacher' ? "School Email Address" : "Principal / Admin Email"}
                      </label>
                      <div className="relative">
                        <Mail className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
                        <input
                          type="email"
                          required
                          value={email}
                          onChange={(e) => setEmail(e.target.value)}
                          placeholder={role === 'teacher' ? "teacher@school.com" : "admin@mnpschool.com"}
                          className="w-full pl-10 pr-4 py-3 rounded-xl bg-slate-50 border border-slate-300 text-xs font-medium text-[#0f172a] placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-[#0c2340]/20 focus:border-[#0c2340] transition-all"
                        />
                      </div>
                    </div>

                    {role === 'teacher' && (
                      <div>
                        <label className="block text-xs font-bold text-[#0c2340] mb-1.5">
                          Select Your Teacher Name *
                        </label>
                        <div className="relative">
                          <User className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
                          <select
                            required
                            value={selectedTeacherId}
                            onChange={(e) => setSelectedTeacherId(e.target.value)}
                            className="w-full pl-10 pr-10 py-3 rounded-xl bg-slate-50 border border-slate-300 text-xs font-semibold text-[#0f172a] focus:outline-none focus:ring-2 focus:ring-[#0c2340]/20 focus:border-[#0c2340] transition-all appearance-none cursor-pointer"
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
                        <label className="text-xs font-bold text-[#0c2340]">
                          {role === 'teacher' ? "Teacher Password" : "Password"}
                        </label>
                        {role === 'principal' && (
                          <button
                            type="button"
                            onClick={() => navigate('/forgot-password')}
                            className="text-[11px] font-bold text-blue-600 hover:underline cursor-pointer"
                          >
                            {t.forgotPasswordLink}
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
                          placeholder={role === 'teacher' ? "Enter your teacher password" : "Enter your secret password"}
                          className="w-full pl-10 pr-10 py-3 rounded-xl bg-slate-50 border border-slate-300 text-xs font-medium text-[#0f172a] placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-[#0c2340]/20 focus:border-[#0c2340] transition-all"
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
                  <label className="flex items-center gap-2 text-xs font-medium text-slate-600 cursor-pointer">
                    <input
                      type="checkbox"
                      checked={rememberMe}
                      onChange={(e) => setRememberMe(e.target.checked)}
                      className="w-4 h-4 rounded text-[#0c2340] focus:ring-[#0c2340] border-slate-300 cursor-pointer"
                    />
                    <span>{t.rememberSession}</span>
                  </label>
                </div>

                {/* Submit Action Button */}
                <button
                  type="submit"
                  disabled={loading}
                  className="w-full py-3.5 px-6 rounded-xl bg-[#0c2340] hover:bg-[#153459] text-white font-bold text-xs shadow-md hover:shadow-lg transition-all flex items-center justify-center gap-2 cursor-pointer disabled:opacity-60 disabled:cursor-not-allowed group mt-4"
                >
                  {loading ? (
                    <span>Verifying Credentials...</span>
                  ) : (
                    <>
                      <span>
                        {role === 'principal'
                          ? (language === 'hi' ? 'प्रधानाचार्य डैशबोर्ड में लॉगिन करें' : 'Sign In to Admin Dashboard')
                          : role === 'teacher'
                          ? (language === 'hi' ? 'शिक्षक पोर्टल में लॉगिन करें' : 'Sign In to Teacher Portal')
                          : (language === 'hi' ? 'अभिभावक पोर्टल में लॉगिन करें' : 'Sign In to Parent Portal')}
                      </span>
                      <ArrowRight className="w-4 h-4 group-hover:translate-x-1 transition-transform" />
                    </>
                  )}
                </button>
              </form>

              {/* In-Modal School Contact Help Desk */}
              <div className="mt-6 pt-5 border-t border-slate-100 rounded-2xl bg-slate-50 p-3.5 text-xs text-slate-600 space-y-2">
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-1.5 font-bold text-[#0c2340]">
                    <HelpCircle className="w-3.5 h-3.5 text-amber-600" />
                    <span>{t.needHelpLoggingIn}</span>
                  </div>
                  <span className="text-[10px] text-slate-400 font-semibold">Campus Office</span>
                </div>
                <p className="text-[11px] leading-relaxed text-slate-500">
                  {role === 'parent' ? t.parentHelpText : "For password reset or credentials help, contact the Principal's office:"}
                </p>
                <div className="flex flex-wrap items-center gap-4 text-[11px] font-semibold text-[#0c2340]">
                  <a href={`tel:${phone}`} className="flex items-center gap-1 text-emerald-700 hover:underline">
                    <Phone className="w-3 h-3" />
                    <span>+91 {phone}</span>
                  </a>
                  <a href={`mailto:${officialEmail}`} className="flex items-center gap-1 text-blue-700 hover:underline">
                    <Mail className="w-3 h-3" />
                    <span>{officialEmail}</span>
                  </a>
                </div>
              </div>

            </div>
          </div>
        )}
      </main>

      {/* 🔹 Comprehensive Institutional Footer 🔹 */}
      <footer className="w-full border-t border-slate-200/90 bg-white mt-12">
        <div className="max-w-6xl mx-auto px-6 py-12">
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-8">
            
            {/* Column 1: School Identity */}
            <div className="space-y-3.5">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-xl bg-slate-50 border border-slate-200 p-1 flex items-center justify-center flex-shrink-0 overflow-hidden">
                  <img src={logoSrc} alt={schoolName} className="w-full h-full object-contain" />
                </div>
                <div>
                  <h4 className="text-sm font-black text-[#0c2340] tracking-tight">{t.schoolName}</h4>
                  <p className="text-[10px] text-slate-500 font-medium">{t.moraBazarCampus}</p>
                </div>
              </div>
              <p className="text-xs text-slate-500 leading-relaxed">
                {t.footerMotto}
              </p>
              <div className="inline-flex items-center gap-2 px-2.5 py-1 rounded-lg bg-slate-100 text-[11px] font-bold text-[#0c2340]">
                <span>{t.sessionActive}</span>
              </div>
            </div>

            {/* Column 2: Quick Links */}
            <div className="space-y-3">
              <h5 className="text-xs font-black uppercase tracking-wider text-[#0c2340]">
                {t.exploreCampus}
              </h5>
              <ul className="space-y-2 text-xs text-slate-600 font-medium">
                <li>
                  <a href="#about" className="hover:text-amber-300 transition-colors">{t.aboutSchool}</a>
                </li>
                <li>
                  <a href="#leadership" className="hover:text-amber-300 transition-colors">{t.leadership}</a>
                </li>
                <li>
                  <a href="#facilities" className="hover:text-amber-300 transition-colors">{t.facilities}</a>
                </li>
                <li>
                  <a
                    href="/signup?tab=admission"
                    onClick={(e) => {
                      e.preventDefault();
                      if (setSignUpFormTab) setSignUpFormTab('student');
                      navigate('/signup?tab=admission');
                    }}
                    className="hover:text-amber-300 transition-colors text-amber-700 font-bold cursor-pointer"
                  >
                    {t.admissionDeskBtn} &rarr;
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
                    className="hover:text-amber-300 transition-colors text-indigo-700 font-bold cursor-pointer"
                  >
                    {t.teacherApplicationBtn} &rarr;
                  </a>
                </li>
              </ul>
            </div>

            {/* Column 3: Portals & Access */}
            <div className="space-y-3">
              <h5 className="text-xs font-black uppercase tracking-wider text-[#0c2340]">
                {t.digitalPortals}
              </h5>
              <ul className="space-y-2 text-xs text-slate-600 font-medium">
                <li>
                  <button
                    type="button"
                    onClick={() => openPortalLogin('parent')}
                    className="hover:text-amber-300 transition-colors cursor-pointer"
                  >
                    {t.parentPortalBtn}
                  </button>
                </li>
                <li>
                  <button
                    type="button"
                    onClick={() => openPortalLogin('teacher')}
                    className="hover:text-amber-300 transition-colors cursor-pointer"
                  >
                    {t.teacherDeskBtn}
                  </button>
                </li>
                <li>
                  <button
                    type="button"
                    onClick={() => openPortalLogin('principal')}
                    className="hover:text-amber-300 transition-colors cursor-pointer"
                  >
                    {language === 'hi' ? 'प्रधानाचार्य प्रशासनिक प्रवेश' : 'Principal Administrative Access'}
                  </button>
                </li>
              </ul>
            </div>

            {/* Column 4: Contact & Office */}
            <div className="space-y-3">
              <h5 className="text-xs font-black uppercase tracking-wider text-[#0c2340]">
                {t.campusContact}
              </h5>
              <div className="space-y-2 text-xs text-slate-600">
                <div className="flex items-start gap-2">
                  <MapPin className="w-3.5 h-3.5 text-slate-400 flex-shrink-0 mt-0.5" />
                  <span>{campusAddress}, District &amp; State, India</span>
                </div>
                <div className="flex items-center gap-2">
                  <Phone className="w-3.5 h-3.5 text-emerald-600 flex-shrink-0" />
                  <a href={`tel:${phone}`} className="hover:underline font-semibold text-[#0c2340]">
                    +91 {phone}
                  </a>
                </div>
                <div className="flex items-center gap-2">
                  <Mail className="w-3.5 h-3.5 text-blue-600 flex-shrink-0" />
                  <a href={`mailto:${officialEmail}`} className="hover:underline text-slate-600">
                    {officialEmail}
                  </a>
                </div>
                <div className="flex items-start gap-2 text-[11px] text-slate-500 pt-1">
                  <Clock className="w-3 h-3 text-slate-400 flex-shrink-0 mt-0.5" />
                  <span>{language === 'hi' ? 'कार्यालय: सोम - शनि: 8:00 AM - 2:00 PM' : 'Office: Mon - Sat: 8:00 AM - 2:00 PM'}</span>
                </div>
              </div>
            </div>

          </div>

          {/* Bottom Copyright & Campus Credit Bar */}
          <div className="mt-10 pt-6 border-t border-slate-100 flex flex-col sm:flex-row items-center justify-between gap-3 text-xs text-slate-400">
            <div>
              &copy; {new Date().getFullYear()} <strong>{schoolName}</strong>. {t.allRightsReserved}
            </div>
            <div className="flex items-center gap-4 text-[11px]">
              <span>{t.moraBazarCampus}</span>
              <span>&bull;</span>
              <span>{t.officialSystem}</span>
            </div>
          </div>
        </div>
      </footer>

    </div>
  );
}
