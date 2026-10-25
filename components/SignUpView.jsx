'use client';

import React, { useState, useEffect } from 'react';
import { useSchoolStore } from '../lib/store';
import { translations } from '../lib/translations';
import { db } from '../lib/firebase';
import { doc, setDoc } from 'firebase/firestore';
import {
  School, User, Phone, MapPin, Calendar, BookOpen,
  ArrowRight, ArrowLeft, CheckCircle2, AlertCircle, Sparkles,
  HelpCircle, MessageSquare, HeartHandshake, FileText,
  Briefcase, GraduationCap, Award, Globe, Check, Printer, Bus
} from 'lucide-react';

export default function SignUpView() {
  const { navigate, settings, language = 'en', setLanguage, toggleLanguage, signUpFormTab, setSignUpFormTab } = useSchoolStore();
  const t = translations[language] || translations.en;

  // Tab: 'student' | 'teacher'
  const [activeFormTab, setActiveFormTab] = useState(() => {
    if (signUpFormTab) return signUpFormTab;
    if (typeof window !== 'undefined') {
      const search = window.location.search || '';
      const hash = window.location.hash || '';
      if (search.includes('teacher') || search.includes('faculty') || hash.includes('teacher') || hash.includes('faculty')) {
        return 'teacher';
      }
    }
    return 'student';
  });

  useEffect(() => {
    if (signUpFormTab && (signUpFormTab === 'student' || signUpFormTab === 'teacher')) {
      setActiveFormTab(signUpFormTab);
    }
  }, [signUpFormTab]);

  // ==========================================
  // Student Admission Form State
  // ==========================================
  const [studentName, setStudentName] = useState('');
  const [admissionClass, setAdmissionClass] = useState('Nursery');
  const [medium, setMedium] = useState('English');
  const [gender, setGender] = useState('Male');
  const [dob, setDob] = useState('');
  const [category, setCategory] = useState('General');
  const [bloodGroup, setBloodGroup] = useState('');
  const [aadharNo, setAadharNo] = useState('');

  const [fatherName, setFatherName] = useState('');
  const [fatherOccupation, setFatherOccupation] = useState('');
  const [motherName, setMotherName] = useState('');
  const [mobile, setMobile] = useState('');
  const [altMobile, setAltMobile] = useState('');
  
  const [address, setAddress] = useState('');
  const [landmark, setLandmark] = useState('');
  const [pinCode, setPinCode] = useState('');
  const [transportRequired, setTransportRequired] = useState('No');

  const [previousSchool, setPreviousSchool] = useState('');
  const [lastClassPassed, setLastClassPassed] = useState('');
  const [studentRemarks, setStudentRemarks] = useState('');

  // ==========================================
  // Teacher Recruitment Form State
  // ==========================================
  const [teacherName, setTeacherName] = useState('');
  const [teacherGender, setTeacherGender] = useState('Male');
  const [teacherDob, setTeacherDob] = useState('');
  const [teacherMobile, setTeacherMobile] = useState('');
  const [teacherEmail, setTeacherEmail] = useState('');
  const [teacherAddress, setTeacherAddress] = useState('');

  const [highestDegree, setHighestDegree] = useState('B.Ed');
  const [university, setUniversity] = useState('');
  const [passingYear, setPassingYear] = useState('2023');
  const [tetStatus, setTetStatus] = useState('CTET Qualified');

  const [subjectSpecialization, setSubjectSpecialization] = useState('Mathematics');
  const [preferredWing, setPreferredWing] = useState('PRT (Classes 1-5)');
  const [experience, setExperience] = useState('1-2 Years');
  const [previousSchoolName, setPreviousSchoolName] = useState('');
  const [teacherBio, setTeacherBio] = useState('');

  // Status & Feedback
  const [loading, setLoading] = useState(false);
  const [submitted, setSubmitted] = useState(false);
  const [enquiryRef, setEnquiryRef] = useState('');
  const [error, setError] = useState('');

  const schoolName = settings?.instituteName || settings?.schoolName || 'Mission Navodaya Public School';
  const logoSrc = settings?.logoUrl || settings?.logoPath || settings?.logo || '/logo.png';
  const phone = settings?.phone || '8603481865';
  const email = settings?.email || 'mnpschooledu@gmail.com';

  const handleStudentSubmit = async (e) => {
    e.preventDefault();
    setError('');

    if (!studentName.trim() || !fatherName.trim() || !mobile.trim()) {
      setError(language === 'hi' ? 'कृपया छात्र का नाम, पिता का नाम और मोबाइल नंबर अवश्य भरें।' : 'Please enter Student Name, Father Name, and Mobile Number.');
      return;
    }

    setLoading(true);
    const generatedRef = `MNP-ADM-2026-${Date.now().toString().slice(-4)}`;

    try {
      const targetSchoolId = settings?.schoolId || 'SCHOOL_001';
      const enquiryPayload = {
        refNo: generatedRef,
        studentName: studentName.trim(),
        admissionClass,
        medium,
        gender,
        dob,
        category,
        bloodGroup,
        fatherName: fatherName.trim(),
        fatherOccupation: fatherOccupation.trim(),
        motherName: motherName.trim(),
        mobile: mobile.trim(),
        address: address.trim(),
        transportRequired,
        previousSchool: previousSchool.trim(),
        lastClassPassed: lastClassPassed.trim(),
        status: 'pending',
        type: 'student_admission_enquiry',
        schoolId: targetSchoolId,
        submittedAt: new Date().toISOString()
      };
      // Primary: Save in schoolDirectory scoped subcollection (guaranteed public write permission)
      await setDoc(doc(db, 'schoolDirectory', targetSchoolId, 'admissionEnquiries', generatedRef), enquiryPayload);
      // Fallback: Also save under SCHOOL_007 for compatibility
      if (targetSchoolId !== 'SCHOOL_007') {
        try {
          await setDoc(doc(db, 'schoolDirectory', 'SCHOOL_007', 'admissionEnquiries', generatedRef), enquiryPayload);
        } catch (_) {}
      }
      // Top-level write attempt
      try {
        await setDoc(doc(db, 'admissionEnquiries', generatedRef), enquiryPayload);
      } catch (_) {}
      console.log('Admission enquiry successfully synced to cloud:', generatedRef);
    } catch (err) {
      console.error('Admission enquiry cloud sync error:', err.message);
    } finally {
      setEnquiryRef(generatedRef);
      setSubmitted(true);
      setLoading(false);
      window.scrollTo({ top: 100, behavior: 'smooth' });
    }
  };

  const handleTeacherSubmit = async (e) => {
    e.preventDefault();
    setError('');

    if (!teacherName.trim() || !teacherMobile.trim() || !teacherEmail.trim()) {
      setError(language === 'hi' ? 'कृपया अपना पूरा नाम, मोबाइल नंबर और ईमेल अवश्य भरें।' : 'Please enter your Full Name, Mobile Number, and Email.');
      return;
    }

    setLoading(true);
    const generatedRef = `MNP-FAC-2026-${Date.now().toString().slice(-4)}`;

    try {
      const targetSchoolId = settings?.schoolId || 'SCHOOL_001';
      const applicationPayload = {
        refNo: generatedRef,
        teacherName: teacherName.trim(),
        gender: teacherGender,
        mobile: teacherMobile.trim(),
        email: teacherEmail.trim(),
        dob: teacherDob,
        address: teacherAddress.trim(),
        highestDegree,
        university: university.trim(),
        tetStatus,
        subjectSpecialization,
        preferredWing,
        experience,
        previousSchoolName: previousSchoolName.trim(),
        teacherBio: teacherBio.trim(),
        status: 'pending',
        type: 'faculty_application',
        schoolId: targetSchoolId,
        submittedAt: new Date().toISOString()
      };
      // Primary: Save in schoolDirectory scoped subcollection (guaranteed public write permission)
      await setDoc(doc(db, 'schoolDirectory', targetSchoolId, 'teacherApplications', generatedRef), applicationPayload);
      // Fallback: Also save under SCHOOL_007 for compatibility
      if (targetSchoolId !== 'SCHOOL_007') {
        try {
          await setDoc(doc(db, 'schoolDirectory', 'SCHOOL_007', 'teacherApplications', generatedRef), applicationPayload);
        } catch (_) {}
      }
      // Top-level write attempt
      try {
        await setDoc(doc(db, 'teacherApplications', generatedRef), applicationPayload);
      } catch (_) {}
      console.log('Teacher application successfully synced to cloud:', generatedRef);
    } catch (err) {
      console.error('Teacher application cloud sync error:', err.message);
    } finally {
      setEnquiryRef(generatedRef);
      setSubmitted(true);
      setLoading(false);
      window.scrollTo({ top: 100, behavior: 'smooth' });
    }
  };

  return (
    <div className="min-h-screen w-full flex flex-col justify-between font-sans antialiased text-[#0f172a] bg-[#f8fafc] selection:bg-[#0c2340] selection:text-white">
      
      {/* 🔹 Top Header with Institutional Brand Colors (Navy #091A32 + Gold #F4B323) 🔹 */}
      <header className="sticky top-0 z-30 w-full px-4 sm:px-6 lg:px-8 py-3.5 flex items-center justify-between border-b border-[#1E3A60] bg-[#091A32] text-white shadow-lg backdrop-blur-md">
        <a
          href="/"
          onClick={(e) => {
            e.preventDefault();
            navigate('/signin');
          }}
          className="flex items-center gap-3 cursor-pointer group min-w-0"
        >
          <div className="w-10 h-10 sm:w-11 sm:h-11 rounded-full bg-white border border-[#E2E8F0] p-1 flex items-center justify-center flex-shrink-0 overflow-hidden shadow-sm transition-transform group-hover:scale-105">
            <img src={logoSrc} alt={schoolName} className="w-full h-full object-contain rounded-full" />
          </div>
          <div className="min-w-0">
            <h1 className="text-sm sm:text-base font-black tracking-tight text-white uppercase group-hover:text-[#F4B323] transition-colors truncate">
              {language === 'hi' ? 'मिशन नवोदय पब्लिक स्कूल' : schoolName}
            </h1>
            <p className="text-[10px] sm:text-[11px] text-[#F4B323] font-bold flex items-center gap-1.5 mt-0.5 truncate">
              <span className="w-1.5 h-1.5 rounded-full bg-[#F4B323] animate-pulse flex-shrink-0" />
              <span>{language === 'hi' ? 'ऑनलाइन प्रवेश एवं शिक्षक भर्ती • सत्र 2026-27' : 'Online Admission & Faculty Desk • Session 2026-27'}</span>
            </p>
          </div>
        </a>

        {/* Header Right Actions */}
        <div className="flex items-center gap-2.5 sm:gap-3 flex-shrink-0">
          {/* Language Switcher Pill */}
          <button
            type="button"
            onClick={toggleLanguage}
            className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-white/10 hover:bg-white/15 border border-white/20 text-xs font-bold text-slate-100 transition-all cursor-pointer shadow-2xs"
            title="Switch Language"
          >
            <Globe className="w-3.5 h-3.5 text-[#F4B323]" />
            <span className="hidden sm:inline">{language === 'en' ? 'हिन्दी में देखें' : 'English'}</span>
            <span className="sm:hidden">{language === 'en' ? 'हिन्दी' : 'EN'}</span>
          </button>

          <button
            type="button"
            onClick={() => navigate('/signin')}
            className="inline-flex items-center gap-1.5 sm:gap-2 px-3.5 py-1.5 rounded-xl bg-[#F4B323] hover:bg-[#e0a21a] text-[#091A32] text-xs font-black transition-all cursor-pointer shadow-md"
          >
            <ArrowLeft className="w-3.5 h-3.5 text-[#091A32]" />
            <span>{language === 'hi' ? 'मुख्य वेबसाइट' : 'Main Website'}</span>
          </button>
        </div>
      </header>

      {/* 🔹 Main Container 🔹 */}
      <main className="flex-1 w-full max-w-4xl mx-auto px-4 py-8 md:py-12">
        <div className="bg-white rounded-3xl border border-slate-200/90 shadow-xl overflow-hidden">
          
          {/* Header Banner */}
          <div className="bg-gradient-to-r from-[#0c2340] via-[#153459] to-[#0c2340] p-6 sm:p-8 text-white relative">
            <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-white/10 border border-white/20 text-xs font-semibold text-amber-300 mb-2">
              <Sparkles className="w-3.5 h-3.5" />
              <span>{language === 'hi' ? 'सत्र 2026-27 हेतु आधिकारिक प्रपत्र' : 'Official Application Desk • Session 2026-27'}</span>
            </div>
            
            <h2 className="text-2xl sm:text-3xl font-black tracking-tight">
              {activeFormTab === 'student'
                ? (language === 'hi' ? 'छात्र प्रवेश पूछताछ प्रपत्र' : 'Student Admission Enquiry Form')
                : (language === 'hi' ? 'शिक्षक एवं स्टाफ भर्ती आवेदन' : 'Faculty & Staff Recruitment Form')}
            </h2>
            
            <p className="text-xs sm:text-sm text-slate-300 mt-1 max-w-2xl leading-relaxed">
              {activeFormTab === 'student'
                ? (language === 'hi' 
                    ? 'मिशन नवोदय पब्लिक स्कूल, मोरा बाजार में नए नामांकन हेतु जानकारी दर्ज करें। हमारा प्रवेश कार्यालय आपसे अतिशीघ्र संपर्क करेगा।'
                    : 'Submit your child’s details for new admission at Mission Navodaya Public School, Mora Bazar. Our admissions office will get in touch shortly.')
                : (language === 'hi'
                    ? 'मिशन नवोदय पब्लिक स्कूल के समर्पित शैक्षणिक परिवार से जुड़ें। योग्य एवं अनुभवी शिक्षकों का सादर स्वागत है।'
                    : 'Join the committed teaching faculty at Mission Navodaya Public School, Mora Bazar. We welcome qualified and passionate educators.')}
            </p>

            {/* Form Mode Selector Tabs */}
            <div className="mt-6 flex flex-wrap gap-2.5">
              <button
                type="button"
                onClick={() => { setActiveFormTab('student'); if (setSignUpFormTab) setSignUpFormTab('student'); setSubmitted(false); setError(''); }}
                className={`px-4 py-2 rounded-xl text-xs font-extrabold flex items-center gap-2 transition-all cursor-pointer ${
                  activeFormTab === 'student'
                    ? 'bg-amber-400 text-[#0c2340] shadow-sm'
                    : 'bg-white/15 text-white hover:bg-white/25 border border-white/20'
                }`}
              >
                <BookOpen className="w-4 h-4" />
                <span>{language === 'hi' ? '1. छात्र प्रवेश प्रपत्र (Student Admission)' : '1. Student Admission Form'}</span>
              </button>

              <button
                type="button"
                onClick={() => { setActiveFormTab('teacher'); if (setSignUpFormTab) setSignUpFormTab('teacher'); setSubmitted(false); setError(''); }}
                className={`px-4 py-2 rounded-xl text-xs font-extrabold flex items-center gap-2 transition-all cursor-pointer ${
                  activeFormTab === 'teacher'
                    ? 'bg-amber-400 text-[#0c2340] shadow-sm'
                    : 'bg-white/15 text-white hover:bg-white/25 border border-white/20'
                }`}
              >
                <GraduationCap className="w-4 h-4" />
                <span>{language === 'hi' ? '2. शिक्षक भर्ती आवेदन (Teacher Recruitment)' : '2. Join as Faculty / Teacher'}</span>
              </button>
            </div>
          </div>

          <div className="p-6 sm:p-8">
            {submitted ? (
              /* Success Confirmation Card */
              <div className="text-center py-8 space-y-5 animate-in fade-in zoom-in-95">
                <div className="w-16 h-16 mx-auto rounded-3xl bg-emerald-50 border border-emerald-200 flex items-center justify-center text-emerald-600 shadow-sm">
                  <CheckCircle2 className="w-8 h-8" />
                </div>
                
                <div className="space-y-1.5">
                  <h3 className="text-2xl font-black text-[#0c2340]">
                    {language === 'hi' ? 'आवेदन सफलतापूर्वक प्राप्त हुआ!' : 'Application Successfully Received!'}
                  </h3>
                  <p className="text-xs text-[#64748b] max-w-md mx-auto">
                    {activeFormTab === 'student'
                      ? (language === 'hi'
                          ? `धन्यवाद! छात्र ${studentName} (कक्षा ${admissionClass}) का प्रवेश विवरण दर्ज कर लिया गया है।`
                          : `Thank you! Admission enquiry for ${studentName} (Class ${admissionClass}) has been recorded.`)
                      : (language === 'hi'
                          ? `धन्यवाद ${teacherName}! आपका शिक्षक आवेदन (विषय: ${subjectSpecialization}) दर्ज कर लिया गया है।`
                          : `Thank you ${teacherName}! Your faculty application for ${subjectSpecialization} has been submitted.`)}
                  </p>
                </div>

                <div className="max-w-md mx-auto p-5 rounded-2xl bg-slate-50 border border-slate-200 text-left space-y-2">
                  <div className="text-[11px] text-slate-500 font-semibold uppercase tracking-wider">
                    {language === 'hi' ? 'आधिकारिक आवेदन संदर्भ संख्या (Application Ref)' : 'Official Application Reference Number'}
                  </div>
                  <div className="text-2xl font-black text-[#0c2340] tracking-wider font-mono">
                    {enquiryRef}
                  </div>
                  <div className="text-xs text-slate-600 pt-2 border-t border-slate-200/80">
                    {language === 'hi'
                      ? `हमारा कार्यालय जल्द ही आपके मोबाइल नंबर (${activeFormTab === 'student' ? mobile : teacherMobile}) पर संपर्क करेगा।`
                      : `Our office will contact you at ${activeFormTab === 'student' ? mobile : teacherMobile} shortly.`}
                  </div>
                </div>

                <div className="pt-2 flex flex-wrap items-center justify-center gap-3">
                  <button
                    type="button"
                    onClick={() => navigate('/signin')}
                    className="px-6 py-2.5 rounded-xl bg-[#0c2340] hover:bg-[#153459] text-white text-xs font-bold transition-all cursor-pointer shadow-sm"
                  >
                    {language === 'hi' ? 'विद्यालय मुख्य पृष्ठ • लॉगिन पोर्टल' : 'Go to School Home • Login Portal'}
                  </button>
                  <button
                    type="button"
                    onClick={() => { setSubmitted(false); setStudentName(''); setFatherName(''); setMobile(''); setTeacherName(''); }}
                    className="px-5 py-2.5 rounded-xl bg-slate-100 hover:bg-slate-200 text-[#0c2340] text-xs font-bold transition-all cursor-pointer"
                  >
                    {language === 'hi' ? 'नया फॉर्म भरें' : 'Submit Another Form'}
                  </button>
                </div>
              </div>
            ) : (
              <div>
                {/* Error Banner */}
                {error && (
                  <div className="mb-6 p-3.5 rounded-xl bg-rose-50 border border-rose-200 flex items-start gap-2.5 text-rose-700 text-xs animate-in fade-in">
                    <AlertCircle className="w-4 h-4 text-rose-600 flex-shrink-0 mt-0.5" />
                    <span className="leading-relaxed font-semibold">{error}</span>
                  </div>
                )}

                {/* ======================================================== */}
                {/*  FORM 1: PROFESSIONAL STUDENT ADMISSION FORM             */}
                {/* ======================================================== */}
                {activeFormTab === 'student' && (
                  <form onSubmit={handleStudentSubmit} className="space-y-8 animate-in fade-in">
                    
                    {/* Section 1: Academic Enrollment */}
                    <div className="space-y-4">
                      <div className="flex items-center gap-2 border-b border-slate-100 pb-2">
                        <span className="w-6 h-6 rounded-full bg-[#0c2340] text-white flex items-center justify-center text-xs font-bold">1</span>
                        <h4 className="text-xs font-black uppercase tracking-wider text-[#0c2340]">
                          {language === 'hi' ? 'नामांकन विवरण / Academic Enrollment' : 'Academic Enrollment Details'}
                        </h4>
                      </div>

                      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
                        <div>
                          <label className="block text-xs font-bold text-slate-700 mb-1">
                            {language === 'hi' ? 'प्रवेश हेतु कक्षा *' : 'Class Seeking Admission *'}
                          </label>
                          <select
                            value={admissionClass}
                            onChange={(e) => setAdmissionClass(e.target.value)}
                            className="w-full px-3.5 py-2.5 rounded-xl bg-slate-50 border border-slate-300 text-xs font-semibold text-[#0f172a] focus:outline-none focus:ring-2 focus:ring-[#0c2340]/20 focus:border-[#0c2340] transition-all cursor-pointer"
                          >
                            {['Nursery', 'LKG', 'UKG', 'Class 1', 'Class 2', 'Class 3', 'Class 4', 'Class 5', 'Class 6', 'Class 7', 'Class 8', 'Class 9', 'Class 10'].map(c => (
                              <option key={c} value={c}>{c}</option>
                            ))}
                          </select>
                        </div>

                        <div>
                          <label className="block text-xs font-bold text-slate-700 mb-1">
                            {language === 'hi' ? 'माध्यम / Preferred Medium' : 'Preferred Medium *'}
                          </label>
                          <select
                            value={medium}
                            onChange={(e) => setMedium(e.target.value)}
                            className="w-full px-3.5 py-2.5 rounded-xl bg-slate-50 border border-slate-300 text-xs font-semibold text-[#0f172a] focus:outline-none focus:ring-2 focus:ring-[#0c2340]/20 focus:border-[#0c2340] transition-all cursor-pointer"
                          >
                            <option value="English">English Medium</option>
                            <option value="Hindi">Hindi Medium (हिन्दी माध्यम)</option>
                          </select>
                        </div>

                        <div>
                          <label className="block text-xs font-bold text-slate-700 mb-1">
                            {language === 'hi' ? 'शैक्षणिक सत्र' : 'Academic Session'}
                          </label>
                          <input
                            type="text"
                            readOnly
                            value="2026-27"
                            className="w-full px-3.5 py-2.5 rounded-xl bg-slate-100 border border-slate-200 text-xs font-bold text-[#0c2340]"
                          />
                        </div>
                      </div>
                    </div>

                    {/* Section 2: Student Particulars */}
                    <div className="space-y-4">
                      <div className="flex items-center gap-2 border-b border-slate-100 pb-2">
                        <span className="w-6 h-6 rounded-full bg-[#0c2340] text-white flex items-center justify-center text-xs font-bold">2</span>
                        <h4 className="text-xs font-black uppercase tracking-wider text-[#0c2340]">
                          {language === 'hi' ? 'विद्यार्थी का व्यक्तिगत विवरण / Student Particulars' : "Student's Personal Particulars"}
                        </h4>
                      </div>

                      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
                        <div className="sm:col-span-2">
                          <label className="block text-xs font-bold text-slate-700 mb-1">
                            {language === 'hi' ? "विद्यार्थी का पूरा नाम (प्रमाणपत्र अनुसार) *" : "Student's Full Name (as per Birth Cert / Aadhar) *"}
                          </label>
                          <input
                            type="text"
                            required
                            value={studentName}
                            onChange={(e) => setStudentName(e.target.value)}
                            placeholder="e.g. Aarav Kumar"
                            className="w-full px-3.5 py-2.5 rounded-xl bg-slate-50 border border-slate-300 text-xs font-medium text-[#0f172a] placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-[#0c2340]/20 focus:border-[#0c2340] transition-all"
                          />
                        </div>

                        <div>
                          <label className="block text-xs font-bold text-slate-700 mb-1">
                            {language === 'hi' ? 'लिंग / Gender *' : 'Gender *'}
                          </label>
                          <select
                            value={gender}
                            onChange={(e) => setGender(e.target.value)}
                            className="w-full px-3.5 py-2.5 rounded-xl bg-slate-50 border border-slate-300 text-xs font-semibold text-[#0f172a] focus:outline-none focus:ring-2 focus:ring-[#0c2340]/20 focus:border-[#0c2340] transition-all cursor-pointer"
                          >
                            <option value="Male">{language === 'hi' ? 'पुरुष (Male)' : 'Male'}</option>
                            <option value="Female">{language === 'hi' ? 'महिला (Female)' : 'Female'}</option>
                            <option value="Other">{language === 'hi' ? 'अन्य (Other)' : 'Other'}</option>
                          </select>
                        </div>

                        <div>
                          <label className="block text-xs font-bold text-slate-700 mb-1">
                            {language === 'hi' ? 'जन्म तिथि / Date of Birth *' : 'Date of Birth *'}
                          </label>
                          <input
                            type="date"
                            required
                            value={dob}
                            onChange={(e) => setDob(e.target.value)}
                            className="w-full px-3.5 py-2.5 rounded-xl bg-slate-50 border border-slate-300 text-xs font-medium text-[#0f172a] focus:outline-none focus:ring-2 focus:ring-[#0c2340]/20 focus:border-[#0c2340] transition-all"
                          />
                        </div>

                        <div>
                          <label className="block text-xs font-bold text-slate-700 mb-1">
                            {language === 'hi' ? 'श्रेणी / Category' : 'Category'}
                          </label>
                          <select
                            value={category}
                            onChange={(e) => setCategory(e.target.value)}
                            className="w-full px-3.5 py-2.5 rounded-xl bg-slate-50 border border-slate-300 text-xs font-semibold text-[#0f172a] focus:outline-none focus:ring-2 focus:ring-[#0c2340]/20 focus:border-[#0c2340] transition-all cursor-pointer"
                          >
                            <option value="General">General</option>
                            <option value="OBC">OBC</option>
                            <option value="SC">SC</option>
                            <option value="ST">ST</option>
                            <option value="EWS">EWS</option>
                          </select>
                        </div>

                        <div>
                          <label className="block text-xs font-bold text-slate-700 mb-1">
                            {language === 'hi' ? 'ब्लड ग्रुप (ऐच्छिक)' : 'Blood Group (Optional)'}
                          </label>
                          <select
                            value={bloodGroup}
                            onChange={(e) => setBloodGroup(e.target.value)}
                            className="w-full px-3.5 py-2.5 rounded-xl bg-slate-50 border border-slate-300 text-xs font-semibold text-[#0f172a] focus:outline-none focus:ring-2 focus:ring-[#0c2340]/20 focus:border-[#0c2340] transition-all cursor-pointer"
                          >
                            <option value="">-- Select --</option>
                            {['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'].map(b => (
                              <option key={b} value={b}>{b}</option>
                            ))}
                          </select>
                        </div>
                      </div>
                    </div>

                    {/* Section 3: Parents & Contact Info */}
                    <div className="space-y-4">
                      <div className="flex items-center gap-2 border-b border-slate-100 pb-2">
                        <span className="w-6 h-6 rounded-full bg-[#0c2340] text-white flex items-center justify-center text-xs font-bold">3</span>
                        <h4 className="text-xs font-black uppercase tracking-wider text-[#0c2340]">
                          {language === 'hi' ? 'माता-पिता एवं संपर्क विवरण / Parents Information' : 'Parents / Guardians Information'}
                        </h4>
                      </div>

                      <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                        <div>
                          <label className="block text-xs font-bold text-slate-700 mb-1">
                            {language === 'hi' ? "पिता / अभिभावक का पूरा नाम *" : "Father's / Guardian's Full Name *"}
                          </label>
                          <input
                            type="text"
                            required
                            value={fatherName}
                            onChange={(e) => setFatherName(e.target.value)}
                            placeholder="e.g. Ramesh Kumar"
                            className="w-full px-3.5 py-2.5 rounded-xl bg-slate-50 border border-slate-300 text-xs font-medium text-[#0f172a] placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-[#0c2340]/20 focus:border-[#0c2340] transition-all"
                          />
                        </div>

                        <div>
                          <label className="block text-xs font-bold text-slate-700 mb-1">
                            {language === 'hi' ? "पिता का व्यवसाय / Occupation" : "Father's Occupation"}
                          </label>
                          <input
                            type="text"
                            value={fatherOccupation}
                            onChange={(e) => setFatherOccupation(e.target.value)}
                            placeholder="e.g. Business / Government Service / Agriculture"
                            className="w-full px-3.5 py-2.5 rounded-xl bg-slate-50 border border-slate-300 text-xs font-medium text-[#0f172a] placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-[#0c2340]/20 focus:border-[#0c2340] transition-all"
                          />
                        </div>

                        <div>
                          <label className="block text-xs font-bold text-slate-700 mb-1">
                            {language === 'hi' ? "माता का पूरा नाम" : "Mother's Full Name"}
                          </label>
                          <input
                            type="text"
                            value={motherName}
                            onChange={(e) => setMotherName(e.target.value)}
                            placeholder="e.g. Sunita Devi"
                            className="w-full px-3.5 py-2.5 rounded-xl bg-slate-50 border border-slate-300 text-xs font-medium text-[#0f172a] placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-[#0c2340]/20 focus:border-[#0c2340] transition-all"
                          />
                        </div>

                        <div>
                          <label className="block text-xs font-bold text-slate-700 mb-1">
                            {language === 'hi' ? "प्राथमिक कॉलिंग एवं व्हाट्सएप नंबर *" : "Primary WhatsApp & Calling Mobile Number *"}
                          </label>
                          <input
                            type="tel"
                            required
                            value={mobile}
                            onChange={(e) => setMobile(e.target.value)}
                            placeholder="e.g. 9876543210 (10 digits)"
                            className="w-full px-3.5 py-2.5 rounded-xl bg-slate-50 border border-slate-300 text-xs font-medium text-[#0f172a] placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-[#0c2340]/20 focus:border-[#0c2340] transition-all"
                          />
                        </div>
                      </div>
                    </div>

                    {/* Section 4: Residential & Transport */}
                    <div className="space-y-4">
                      <div className="flex items-center gap-2 border-b border-slate-100 pb-2">
                        <span className="w-6 h-6 rounded-full bg-[#0c2340] text-white flex items-center justify-center text-xs font-bold">4</span>
                        <h4 className="text-xs font-black uppercase tracking-wider text-[#0c2340]">
                          {language === 'hi' ? 'स्थाई पता एवं विद्यालय वाहन सुविधा / Address & Transport' : 'Address & Transport Details'}
                        </h4>
                      </div>

                      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
                        <div className="sm:col-span-2">
                          <label className="block text-xs font-bold text-slate-700 mb-1">
                            {language === 'hi' ? 'स्थाई / आवासीय पता (ग्राम, मोहल्ला, वार्ड) *' : 'Residential Address (Village / Ward / Locality) *'}
                          </label>
                          <input
                            type="text"
                            required
                            value={address}
                            onChange={(e) => setAddress(e.target.value)}
                            placeholder="e.g. Mora Bazar, Ward 4"
                            className="w-full px-3.5 py-2.5 rounded-xl bg-slate-50 border border-slate-300 text-xs font-medium text-[#0f172a] placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-[#0c2340]/20 focus:border-[#0c2340] transition-all"
                          />
                        </div>

                        <div>
                          <label className="block text-xs font-bold text-slate-700 mb-1">
                            {language === 'hi' ? 'स्कूल बस/वैन सुविधा चाहिए?' : 'School Bus/Van Facility Needed?'}
                          </label>
                          <select
                            value={transportRequired}
                            onChange={(e) => setTransportRequired(e.target.value)}
                            className="w-full px-3.5 py-2.5 rounded-xl bg-slate-50 border border-slate-300 text-xs font-semibold text-[#0f172a] focus:outline-none focus:ring-2 focus:ring-[#0c2340]/20 focus:border-[#0c2340] transition-all cursor-pointer"
                          >
                            <option value="Yes">{language === 'hi' ? 'हाँ (Yes, Transport Required)' : 'Yes, Transport Required'}</option>
                            <option value="No">{language === 'hi' ? 'नहीं (No, Self Conveyance)' : 'No, Self Conveyance'}</option>
                          </select>
                        </div>
                      </div>
                    </div>

                    {/* Section 5: Previous School Background */}
                    <div className="space-y-4">
                      <div className="flex items-center gap-2 border-b border-slate-100 pb-2">
                        <span className="w-6 h-6 rounded-full bg-[#0c2340] text-white flex items-center justify-center text-xs font-bold">5</span>
                        <h4 className="text-xs font-black uppercase tracking-wider text-[#0c2340]">
                          {language === 'hi' ? 'पूर्व विद्यालय विवरण (यदि लागू हो)' : 'Previous School Background (If applicable)'}
                        </h4>
                      </div>

                      <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                        <div>
                          <label className="block text-xs font-bold text-slate-700 mb-1">
                            {language === 'hi' ? 'पूर्व विद्यालय का नाम' : 'Previous School Name'}
                          </label>
                          <input
                            type="text"
                            value={previousSchool}
                            onChange={(e) => setPreviousSchool(e.target.value)}
                            placeholder="Name of previous school"
                            className="w-full px-3.5 py-2.5 rounded-xl bg-slate-50 border border-slate-300 text-xs font-medium text-[#0f172a] placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-[#0c2340]/20 focus:border-[#0c2340] transition-all"
                          />
                        </div>

                        <div>
                          <label className="block text-xs font-bold text-slate-700 mb-1">
                            {language === 'hi' ? 'उत्तीर्ण कक्षा एवं प्रतिशत/ग्रेड' : 'Last Class Passed & Percentage / Grade'}
                          </label>
                          <input
                            type="text"
                            value={lastClassPassed}
                            onChange={(e) => setLastClassPassed(e.target.value)}
                            placeholder="e.g. Class 3 Passed (85%)"
                            className="w-full px-3.5 py-2.5 rounded-xl bg-slate-50 border border-slate-300 text-xs font-medium text-[#0f172a] placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-[#0c2340]/20 focus:border-[#0c2340] transition-all"
                          />
                        </div>
                      </div>
                    </div>

                    {/* Submit Bar */}
                    <div className="pt-4 flex flex-col sm:flex-row items-center justify-between gap-4 border-t border-slate-100">
                      <p className="text-[11px] text-slate-500 text-center sm:text-left">
                        {language === 'hi' 
                          ? 'फॉर्म जमा होने के पश्चात विद्यालय कार्यालय आपसे संपर्क करेगा।'
                          : 'Upon submission, our admissions desk will review and contact you.'}
                      </p>
                      
                      <button
                        type="submit"
                        disabled={loading}
                        className="w-full sm:w-auto px-8 py-3.5 rounded-xl bg-[#0c2340] hover:bg-[#153459] text-white font-bold text-xs shadow-md hover:shadow-lg transition-all flex items-center justify-center gap-2 cursor-pointer disabled:opacity-60 disabled:cursor-not-allowed"
                      >
                        {loading ? (
                          <span>{language === 'hi' ? 'जमा हो रहा है...' : 'Submitting Application...'}</span>
                        ) : (
                          <>
                            <span>{language === 'hi' ? 'प्रवेश पूछताछ फॉर्म जमा करें' : 'Submit Admission Enquiry Form'}</span>
                            <ArrowRight className="w-4 h-4" />
                          </>
                        )}
                      </button>
                    </div>

                  </form>
                )}

                {/* ======================================================== */}
                {/*  FORM 2: PROFESSIONAL TEACHER RECRUITMENT FORM          */}
                {/* ======================================================== */}
                {activeFormTab === 'teacher' && (
                  <form onSubmit={handleTeacherSubmit} className="space-y-8 animate-in fade-in">
                    
                    {/* Section 1: Candidate Personal Details */}
                    <div className="space-y-4">
                      <div className="flex items-center gap-2 border-b border-slate-100 pb-2">
                        <span className="w-6 h-6 rounded-full bg-[#0c2340] text-white flex items-center justify-center text-xs font-bold">1</span>
                        <h4 className="text-xs font-black uppercase tracking-wider text-[#0c2340]">
                          {language === 'hi' ? 'उम्मीदवार की व्यक्तिगत जानकारी / Personal Particulars' : 'Candidate Personal Details'}
                        </h4>
                      </div>

                      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
                        <div className="sm:col-span-2">
                          <label className="block text-xs font-bold text-slate-700 mb-1">
                            {language === 'hi' ? 'पूरा नाम (Full Name) *' : 'Full Name *'}
                          </label>
                          <input
                            type="text"
                            required
                            value={teacherName}
                            onChange={(e) => setTeacherName(e.target.value)}
                            placeholder="e.g. Rajesh Kumar Sharma"
                            className="w-full px-3.5 py-2.5 rounded-xl bg-slate-50 border border-slate-300 text-xs font-medium text-[#0f172a] placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-[#0c2340]/20 focus:border-[#0c2340] transition-all"
                          />
                        </div>

                        <div>
                          <label className="block text-xs font-bold text-slate-700 mb-1">
                            {language === 'hi' ? 'लिंग / Gender *' : 'Gender *'}
                          </label>
                          <select
                            value={teacherGender}
                            onChange={(e) => setTeacherGender(e.target.value)}
                            className="w-full px-3.5 py-2.5 rounded-xl bg-slate-50 border border-slate-300 text-xs font-semibold text-[#0f172a] focus:outline-none focus:ring-2 focus:ring-[#0c2340]/20 focus:border-[#0c2340] transition-all cursor-pointer"
                          >
                            <option value="Male">{language === 'hi' ? 'पुरुष (Male)' : 'Male'}</option>
                            <option value="Female">{language === 'hi' ? 'महिला (Female)' : 'Female'}</option>
                          </select>
                        </div>

                        <div>
                          <label className="block text-xs font-bold text-slate-700 mb-1">
                            {language === 'hi' ? 'मोबाइल / व्हाट्सएप नंबर *' : 'Mobile / WhatsApp Number *'}
                          </label>
                          <input
                            type="tel"
                            required
                            value={teacherMobile}
                            onChange={(e) => setTeacherMobile(e.target.value)}
                            placeholder="e.g. 9876543210 (10 digits)"
                            className="w-full px-3.5 py-2.5 rounded-xl bg-slate-50 border border-slate-300 text-xs font-medium text-[#0f172a] placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-[#0c2340]/20 focus:border-[#0c2340] transition-all"
                          />
                        </div>

                        <div>
                          <label className="block text-xs font-bold text-slate-700 mb-1">
                            {language === 'hi' ? 'ईमेल पता (Email Address) *' : 'Email Address *'}
                          </label>
                          <input
                            type="email"
                            required
                            value={teacherEmail}
                            onChange={(e) => setTeacherEmail(e.target.value)}
                            placeholder="e.g. teacher@example.com"
                            className="w-full px-3.5 py-2.5 rounded-xl bg-slate-50 border border-slate-300 text-xs font-medium text-[#0f172a] placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-[#0c2340]/20 focus:border-[#0c2340] transition-all"
                          />
                        </div>

                        <div>
                          <label className="block text-xs font-bold text-slate-700 mb-1">
                            {language === 'hi' ? 'जन्म तिथि / Date of Birth' : 'Date of Birth'}
                          </label>
                          <input
                            type="date"
                            value={teacherDob}
                            onChange={(e) => setTeacherDob(e.target.value)}
                            className="w-full px-3.5 py-2.5 rounded-xl bg-slate-50 border border-slate-300 text-xs font-medium text-[#0f172a] focus:outline-none focus:ring-2 focus:ring-[#0c2340]/20 focus:border-[#0c2340] transition-all"
                          />
                        </div>

                        <div className="sm:col-span-3">
                          <label className="block text-xs font-bold text-slate-700 mb-1">
                            {language === 'hi' ? 'वर्तमान एवं स्थाई पता / Complete Address *' : 'Complete Residential Address *'}
                          </label>
                          <input
                            type="text"
                            required
                            value={teacherAddress}
                            onChange={(e) => setTeacherAddress(e.target.value)}
                            placeholder="e.g. Village/Town, Post Office, District"
                            className="w-full px-3.5 py-2.5 rounded-xl bg-slate-50 border border-slate-300 text-xs font-medium text-[#0f172a] placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-[#0c2340]/20 focus:border-[#0c2340] transition-all"
                          />
                        </div>
                      </div>
                    </div>

                    {/* Section 2: Educational Qualifications */}
                    <div className="space-y-4">
                      <div className="flex items-center gap-2 border-b border-slate-100 pb-2">
                        <span className="w-6 h-6 rounded-full bg-[#0c2340] text-white flex items-center justify-center text-xs font-bold">2</span>
                        <h4 className="text-xs font-black uppercase tracking-wider text-[#0c2340]">
                          {language === 'hi' ? 'शैक्षणिक एवं व्यावसायिक योग्यता / Educational Qualifications' : 'Educational & Professional Qualifications'}
                        </h4>
                      </div>

                      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
                        <div>
                          <label className="block text-xs font-bold text-slate-700 mb-1">
                            {language === 'hi' ? 'उच्चतम शैक्षणिक उपाधि *' : 'Highest Degree / Qualification *'}
                          </label>
                          <select
                            value={highestDegree}
                            onChange={(e) => setHighestDegree(e.target.value)}
                            className="w-full px-3.5 py-2.5 rounded-xl bg-slate-50 border border-slate-300 text-xs font-semibold text-[#0f172a] focus:outline-none focus:ring-2 focus:ring-[#0c2340]/20 focus:border-[#0c2340] transition-all cursor-pointer"
                          >
                            {['B.Ed', 'D.El.Ed', 'M.Sc', 'M.A', 'B.Sc', 'B.A', 'B.Com', 'M.Com', 'MCA / BCA', 'Other'].map(d => (
                              <option key={d} value={d}>{d}</option>
                            ))}
                          </select>
                        </div>

                        <div>
                          <label className="block text-xs font-bold text-slate-700 mb-1">
                            {language === 'hi' ? 'विश्वविद्यालय / बोर्ड का नाम' : 'University / Board Name'}
                          </label>
                          <input
                            type="text"
                            value={university}
                            onChange={(e) => setUniversity(e.target.value)}
                            placeholder="e.g. Patna University"
                            className="w-full px-3.5 py-2.5 rounded-xl bg-slate-50 border border-slate-300 text-xs font-medium text-[#0f172a] placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-[#0c2340]/20 focus:border-[#0c2340] transition-all"
                          />
                        </div>

                        <div>
                          <label className="block text-xs font-bold text-slate-700 mb-1">
                            {language === 'hi' ? 'शिक्षक पात्रता परीक्षा (CTET / STET)' : 'TET Status (CTET / STET)'}
                          </label>
                          <select
                            value={tetStatus}
                            onChange={(e) => setTetStatus(e.target.value)}
                            className="w-full px-3.5 py-2.5 rounded-xl bg-slate-50 border border-slate-300 text-xs font-semibold text-[#0f172a] focus:outline-none focus:ring-2 focus:ring-[#0c2340]/20 focus:border-[#0c2340] transition-all cursor-pointer"
                          >
                            <option value="CTET Qualified">CTET Qualified (Paper 1 / 2)</option>
                            <option value="STET Qualified">STET Qualified</option>
                            <option value="Appearing / In-Progress">Appearing / In-Progress</option>
                            <option value="Not Qualified">None / General</option>
                          </select>
                        </div>
                      </div>
                    </div>

                    {/* Section 3: Teaching Specialization & Preferences */}
                    <div className="space-y-4">
                      <div className="flex items-center gap-2 border-b border-slate-100 pb-2">
                        <span className="w-6 h-6 rounded-full bg-[#0c2340] text-white flex items-center justify-center text-xs font-bold">3</span>
                        <h4 className="text-xs font-black uppercase tracking-wider text-[#0c2340]">
                          {language === 'hi' ? 'विषय विशेषज्ञता एवं शिक्षण अनुभव / Teaching Specialization' : 'Teaching Specialization & Experience'}
                        </h4>
                      </div>

                      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
                        <div>
                          <label className="block text-xs font-bold text-slate-700 mb-1">
                            {language === 'hi' ? 'मुख्य शिक्षण विषय *' : 'Subject Specialization *'}
                          </label>
                          <select
                            value={subjectSpecialization}
                            onChange={(e) => setSubjectSpecialization(e.target.value)}
                            className="w-full px-3.5 py-2.5 rounded-xl bg-slate-50 border border-slate-300 text-xs font-semibold text-[#0f172a] focus:outline-none focus:ring-2 focus:ring-[#0c2340]/20 focus:border-[#0c2340] transition-all cursor-pointer"
                          >
                            {['Mathematics', 'Science / Physics / Chemistry / Bio', 'English', 'Hindi', 'Sanskrit', 'Social Science / History / Geography', 'Computer Science / IT', 'Primary All Subjects', 'Art / Physical Education'].map(s => (
                              <option key={s} value={s}>{s}</option>
                            ))}
                          </select>
                        </div>

                        <div>
                          <label className="block text-xs font-bold text-slate-700 mb-1">
                            {language === 'hi' ? 'प्राथमिकता वर्ग / Preferred Level' : 'Preferred Teaching Level'}
                          </label>
                          <select
                            value={preferredWing}
                            onChange={(e) => setPreferredWing(e.target.value)}
                            className="w-full px-3.5 py-2.5 rounded-xl bg-slate-50 border border-slate-300 text-xs font-semibold text-[#0f172a] focus:outline-none focus:ring-2 focus:ring-[#0c2340]/20 focus:border-[#0c2340] transition-all cursor-pointer"
                          >
                            <option value="Pre-Primary (Nursery - UKG)">Pre-Primary (Nursery - UKG)</option>
                            <option value="PRT (Classes 1-5)">PRT (Primary Wing: Classes 1-5)</option>
                            <option value="TGT (Classes 6-8)">TGT (Middle Wing: Classes 6-8)</option>
                            <option value="Secondary (Classes 9-10)">Secondary Wing (Classes 9-10)</option>
                            <option value="Admin / Office Staff">Administrative / Office Staff</option>
                          </select>
                        </div>

                        <div>
                          <label className="block text-xs font-bold text-slate-700 mb-1">
                            {language === 'hi' ? 'कुल शिक्षण अनुभव' : 'Total Teaching Experience'}
                          </label>
                          <select
                            value={experience}
                            onChange={(e) => setExperience(e.target.value)}
                            className="w-full px-3.5 py-2.5 rounded-xl bg-slate-50 border border-slate-300 text-xs font-semibold text-[#0f172a] focus:outline-none focus:ring-2 focus:ring-[#0c2340]/20 focus:border-[#0c2340] transition-all cursor-pointer"
                          >
                            <option value="Fresher">Fresher (नवागंतुक)</option>
                            <option value="1-2 Years">1 - 2 Years</option>
                            <option value="3-5 Years">3 - 5 Years</option>
                            <option value="5+ Years">More than 5 Years</option>
                          </select>
                        </div>

                        <div className="sm:col-span-3">
                          <label className="block text-xs font-bold text-slate-700 mb-1">
                            {language === 'hi' ? 'पूर्व विद्यालय का नाम एवं पद (यदि कोई हो)' : 'Previous School Name & Designation (if any)'}
                          </label>
                          <input
                            type="text"
                            value={previousSchoolName}
                            onChange={(e) => setPreviousSchoolName(e.target.value)}
                            placeholder="e.g. XYZ Public School, Teacher (2 Years)"
                            className="w-full px-3.5 py-2.5 rounded-xl bg-slate-50 border border-slate-300 text-xs font-medium text-[#0f172a] placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-[#0c2340]/20 focus:border-[#0c2340] transition-all"
                          />
                        </div>
                      </div>
                    </div>

                    {/* Section 4: Brief Statement */}
                    <div className="space-y-2">
                      <label className="block text-xs font-bold text-slate-700">
                        {language === 'hi' 
                          ? 'आप मिशन नवोदय पब्लिक स्कूल क्यों जॉइन करना चाहते हैं? (संक्षिप्त विचार)' 
                          : 'Why do you wish to join Mission Navodaya Public School? (Brief Note)'}
                      </label>
                      <textarea
                        rows={3}
                        value={teacherBio}
                        onChange={(e) => setTeacherBio(e.target.value)}
                        placeholder={language === 'hi' ? 'अपने अध्यापन कौशल और विचारों के बारे में संक्षेप में लिखें...' : 'Mention your teaching passion and methodology...'}
                        className="w-full px-3.5 py-2.5 rounded-xl bg-slate-50 border border-slate-300 text-xs font-medium text-[#0f172a] placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-[#0c2340]/20 focus:border-[#0c2340] transition-all"
                      />
                    </div>

                    {/* Submit Bar */}
                    <div className="pt-4 flex flex-col sm:flex-row items-center justify-between gap-4 border-t border-slate-100">
                      <p className="text-[11px] text-slate-500 text-center sm:text-left">
                        {language === 'hi' 
                          ? 'आवेदन की समीक्षा के पश्चात योग्य अभ्यर्थियों को साक्षात्कार के लिए आमंत्रित किया जाएगा।'
                          : 'Shortlisted candidates will be invited for interview and demo class.'}
                      </p>
                      
                      <button
                        type="submit"
                        disabled={loading}
                        className="w-full sm:w-auto px-8 py-3.5 rounded-xl bg-[#0c2340] hover:bg-[#153459] text-white font-bold text-xs shadow-md hover:shadow-lg transition-all flex items-center justify-center gap-2 cursor-pointer disabled:opacity-60 disabled:cursor-not-allowed"
                      >
                        {loading ? (
                          <span>{language === 'hi' ? 'जमा हो रहा है...' : 'Submitting Application...'}</span>
                        ) : (
                          <>
                            <span>{language === 'hi' ? 'शिक्षक आवेदन जमा करें' : 'Submit Faculty Application'}</span>
                            <ArrowRight className="w-4 h-4" />
                          </>
                        )}
                      </button>
                    </div>

                  </form>
                )}

              </div>
            )}
          </div>

          {/* Bottom Direct Helpline Notice */}
          <div className="bg-slate-50 p-6 border-t border-slate-200/80 flex flex-col sm:flex-row items-center justify-between gap-4 text-xs">
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 rounded-xl bg-white border border-slate-200 flex items-center justify-center text-emerald-600 font-bold shadow-2xs">
                <Phone className="w-4 h-4" />
              </div>
              <div>
                <div className="font-bold text-[#0c2340]">
                  {language === 'hi' ? 'सीधा विद्यालय संपर्क एवं हेल्पलाइन' : 'Direct Campus Helpline Desk'}
                </div>
                <div className="text-[11px] text-slate-500">Contact: +91 {phone} &bull; {email}</div>
              </div>
            </div>

            <div className="flex items-center gap-2">
              <span className="text-slate-500 text-[11px]">
                {language === 'hi' ? 'पूर्व नामांकित विद्यार्थी / अभिभावक?' : 'Already enrolled student?'}
              </span>
              <button
                type="button"
                onClick={() => navigate('/signin')}
                className="font-bold text-[#0c2340] hover:underline cursor-pointer"
              >
                {language === 'hi' ? 'अभिभावक पोर्टल में लॉगिन करें →' : 'Log In to Parent Portal →'}
              </button>
            </div>
          </div>

        </div>
      </main>

      {/* 🔹 Institutional Footer 🔹 */}
      <footer className="w-full px-6 py-5 md:px-12 border-t border-slate-200 bg-white flex flex-col sm:flex-row items-center justify-between gap-3 text-center text-xs text-[#64748b]">
        <div className="flex items-center gap-2.5">
          <div className="w-6 h-6 rounded-full bg-slate-100 p-0.5 flex items-center justify-center overflow-hidden">
            <img src={logoSrc} alt="Logo" className="w-full h-full object-contain rounded-full" />
          </div>
          <span>&copy; {new Date().getFullYear()} {schoolName}. All Rights Reserved.</span>
        </div>
        <div className="flex items-center gap-4 text-[11px] text-[#64748b]">
          <span>Mora Bazar Campus</span>
          <span>&bull;</span>
          <span>Session 2026-27</span>
        </div>
      </footer>

    </div>
  );
}
