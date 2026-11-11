'use client';

import React, { useState } from 'react';
import {
  GraduationCap, Mail, Phone, MapPin, Clock, ExternalLink,
  BookOpen, Award, ShieldCheck, Trophy, Users, Sparkles,
  Download, Smartphone, CheckCircle, Check, ArrowRight,
  Calendar, Star, FileText, ChevronRight, HelpCircle
} from 'lucide-react';

/**
 * Common Page Header Banner with Breadcrumbs
 */
export function PageBanner({ title, subtitle, breadcrumb, isHi }) {
  return (
    <div className="w-full bg-gradient-to-r from-[#07172E] via-[#0c2340] to-[#091A32] text-white py-12 sm:py-16 px-4 sm:px-6 lg:px-8 border-b-2 border-[#1E3A60] relative overflow-hidden">
      <div className="absolute top-0 right-0 w-96 h-96 bg-amber-500/10 rounded-full blur-3xl pointer-events-none" />
      <div className="max-w-7xl mx-auto relative z-10 space-y-3">
        {/* Breadcrumb */}
        <div className="flex items-center gap-2 text-xs font-bold text-slate-300">
          <span className="text-[#F4B323]">{isHi ? 'मुख्य पृष्ठ' : 'Home'}</span>
          <ChevronRight className="w-3.5 h-3.5 text-slate-400" />
          <span className="text-white">{breadcrumb}</span>
        </div>
        <h1 className="text-2xl sm:text-4xl lg:text-5xl font-black text-white tracking-tight">
          {title}
        </h1>
        <p className="text-xs sm:text-sm text-slate-300 max-w-2xl leading-relaxed">
          {subtitle}
        </p>
      </div>
    </div>
  );
}

/**
 * 1. ABOUT US PAGE VIEW (/about)
 */
export function AboutPageView({ isHi, schoolName, schoolSubtitle, schoolLocation, primaryPhone, navigate }) {
  return (
    <div className="w-full space-y-12 sm:space-y-16 pb-16">
      <PageBanner
        title={isHi ? 'हमारे बारे में' : 'About Mission Navodaya Public School'}
        subtitle={
          isHi
            ? 'मोरा-मैरी, सीवान में गुणवत्तापूर्ण अंग्रेजी माध्यम शिक्षा, अनुशासन और सर्वांगीण विकास का प्रमुख केंद्र।'
            : 'Premier institution for quality English-medium education, discipline, and holistic student development in Mora-Mairi, Siwan.'
        }
        breadcrumb={isHi ? 'हमारे बारे में' : 'About Us'}
        isHi={isHi}
      />

      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 space-y-12">
        {/* Story Section */}
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 lg:gap-12 items-center">
          <div className="lg:col-span-7 space-y-5">
            <span className="text-[11px] font-black uppercase tracking-widest text-[#102747] bg-[#102747]/8 px-3.5 py-1 rounded-full border border-[#102747]/15">
              {isHi ? 'हमारी पृष्ठभूमि' : 'OUR HERITAGE'}
            </span>
            <h2 className="text-2xl sm:text-3xl font-black text-[#14243B] tracking-tight">
              {isHi
                ? 'मोरा-मैरी और आसपास के क्षेत्रों में शिक्षा की नई क्रांति'
                : 'Pioneering Educational Excellence in Mora-Mairi & Siwan'}
            </h2>
            <div className="space-y-3.5 text-xs sm:text-sm text-[#475569] leading-relaxed">
              <p>
                {isHi
                  ? 'मिशन नवोदय पब्लिक स्कूल (MNP School) की स्थापना मोरा-मैरी (सीवान) में इस उद्देश्य के साथ की गई कि ग्रामीण एवं अर्ध-शहरी क्षेत्र के बच्चों को भी महानगरों जैसी उच्च स्तरीय अंग्रेजी माध्यम शिक्षा, आधुनिक कंप्यूटर तकनीक और मजबूत संस्कार प्राप्त हो सकें।'
                  : 'Mission Navodaya Public School (MNP School) was established in Mora-Mairi, Siwan with the vision to deliver metropolitan-grade English-medium education, digital learning, and strong Indian moral values to students in semi-rural communities.'}
              </p>
              <p>
                {isHi
                  ? 'वर्तमान में 220+ नामांकित विद्यार्थियों और समर्पित शिक्षक दल के साथ, स्कूल नर्सरी से 8वीं कक्षा तक व्यक्तिगत ध्यान, सीसीटीवी-सुरक्षित अनुशासित परिसर और आधुनिक शिक्षण विधियों के माध्यम से बच्चों के भविष्य को संवार रहा है।'
                  : 'Today, serving over 220+ enrolled students with a dedicated teaching faculty, the school provides personalized mentorship from Nursery to Class 8th in a CCTV-secured, disciplined, and nurturing environment.'}
              </p>
            </div>

            {/* Quick Metrics */}
            <div className="grid grid-cols-3 gap-3 pt-3">
              <div className="p-4 rounded-2xl bg-amber-500/10 border border-amber-500/20 text-center">
                <div className="text-xl sm:text-2xl font-black text-[#0c2340]">220+</div>
                <div className="text-[11px] font-bold text-slate-600">{isHi ? 'सक्रिय विद्यार्थी' : 'Active Students'}</div>
              </div>
              <div className="p-4 rounded-2xl bg-blue-500/10 border border-blue-500/20 text-center">
                <div className="text-xl sm:text-2xl font-black text-blue-700">Nursery - 8th</div>
                <div className="text-[11px] font-bold text-slate-600">{isHi ? 'अंग्रेजी माध्यम' : 'English Medium'}</div>
              </div>
              <div className="p-4 rounded-2xl bg-emerald-500/10 border border-emerald-500/20 text-center">
                <div className="text-xl sm:text-2xl font-black text-emerald-700">100%</div>
                <div className="text-[11px] font-bold text-slate-600">{isHi ? 'सुरक्षित परिसर' : 'Safe Campus'}</div>
              </div>
            </div>
          </div>

          {/* Campus Image Frame */}
          <div className="lg:col-span-5">
            <div className="relative rounded-3xl overflow-hidden shadow-2xl border-4 border-white">
              <img
                src="/school_campus_banner.jpg"
                alt="Mission Navodaya Public School Mora-Mairi"
                className="w-full h-80 sm:h-96 object-cover"
              />
              <div className="absolute bottom-0 inset-x-0 p-4 bg-gradient-to-t from-[#0c2340] to-transparent text-white">
                <div className="font-bold text-sm">मोरा-मैरी परिसर · सीवान (बिहार)</div>
                <div className="text-[11px] text-amber-300">Mission Navodaya Public School</div>
              </div>
            </div>
          </div>
        </div>

        {/* Vision & Mission Cards */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6 pt-4">
          <div className="p-6 sm:p-8 rounded-3xl bg-white border border-slate-200/80 shadow-md space-y-3">
            <div className="w-12 h-12 rounded-2xl bg-amber-500/15 text-amber-600 flex items-center justify-center font-bold">
              <Sparkles className="w-6 h-6 text-[#F4B323]" />
            </div>
            <h3 className="text-lg font-black text-[#0c2340]">
              {isHi ? 'हमारा दृष्टिकोण (Our Vision)' : 'Our Vision'}
            </h3>
            <p className="text-xs sm:text-sm text-slate-600 leading-relaxed">
              {isHi
                ? 'प्रत्येक विद्यार्थी में ज्ञान की जिज्ञासा, नैतिक सत्यनिष्ठा, और नेतृत्व क्षमता विकसित करना ताकि वे 21वीं सदी के जिम्मेदार और सफल नागरिक बन सकें।'
                : 'To cultivate intellectual curiosity, ethical character, and future-ready capabilities in every child, inspiring them to become responsible and compassionate citizens.'}
            </p>
          </div>

          <div className="p-6 sm:p-8 rounded-3xl bg-white border border-slate-200/80 shadow-md space-y-3">
            <div className="w-12 h-12 rounded-2xl bg-blue-500/15 text-blue-600 flex items-center justify-center font-bold">
              <ShieldCheck className="w-6 h-6 text-blue-600" />
            </div>
            <h3 className="text-lg font-black text-[#0c2340]">
              {isHi ? 'हमारा मिशन (Our Mission)' : 'Our Mission'}
            </h3>
            <p className="text-xs sm:text-sm text-slate-600 leading-relaxed">
              {isHi
                ? 'सुलभ, अनुशासित और सुरक्षित माहौल में उत्कृष्ट शैक्षणिक सुविधाएं, खेलकूद, कंप्यूटर शिक्षा और व्यक्तिगत मार्गदर्शन प्रदान करना।'
                : 'To provide accessible, disciplined, and safe education backed by robust academic curricula, physical sports, digital literacy, and holistic mentorship.'}
            </p>
          </div>
        </div>

        {/* Leadership Section */}
        <div className="p-6 sm:p-10 rounded-3xl bg-gradient-to-br from-[#0c2340] to-[#102747] text-white space-y-8 shadow-xl">
          <div className="text-center space-y-2 max-w-2xl mx-auto">
            <span className="text-[11px] font-black uppercase tracking-widest text-[#F4B323] bg-white/10 px-3.5 py-1 rounded-full border border-white/15">
              {isHi ? 'संस्थापक एवं नेतृत्व' : 'FOUNDERS & LEADERSHIP'}
            </span>
            <h3 className="text-2xl sm:text-3xl font-black text-white">
              {isHi ? 'अनुभवी एवं समर्पित नेतृत्व' : 'Guiding Leadership'}
            </h3>
            <p className="text-xs sm:text-sm text-slate-300">
              {isHi
                ? 'शिक्षा, सत्यनिष्ठा और बच्चों के सर्वांगीण विकास के प्रति पूर्णतः समर्पित।'
                : 'Guided by lifelong commitment to education, ethical conduct, and student success.'}
            </p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-6 sm:gap-8">
            {/* Chairman */}
            <div className="p-6 rounded-2xl bg-white/10 border border-white/15 space-y-3">
              <div className="flex items-center gap-4">
                <div className="w-14 h-14 rounded-full bg-amber-500/20 text-[#F4B323] flex items-center justify-center font-black text-lg border border-[#F4B323]/30">
                  US
                </div>
                <div>
                  <h4 className="text-base sm:text-lg font-black text-white">Uday Shankar Patel</h4>
                  <p className="text-xs font-bold text-[#F4B323]">{isHi ? 'चेयरमैन (उदय सर)' : 'Chairman (Uday Sir)'}</p>
                </div>
              </div>
              <p className="text-xs text-slate-300 leading-relaxed italic">
                {isHi
                  ? '"हमारा लक्ष्य केवल किताबी ज्ञान देना नहीं, बल्कि बच्चों में चरित्र निर्माण, आत्मविश्वास और समाज के प्रति जिम्मेदारी की भावना जागृत करना है।"'
                  : '"Our commitment is not merely classroom literacy, but instilling self-confidence, strong moral character, and lifelong discipline in every student."'}
              </p>
            </div>

            {/* Director */}
            <div className="p-6 rounded-2xl bg-white/10 border border-white/15 space-y-3">
              <div className="flex items-center gap-4">
                <div className="w-14 h-14 rounded-full bg-blue-500/20 text-blue-300 flex items-center justify-center font-black text-lg border border-blue-400/30">
                  VP
                </div>
                <div>
                  <h4 className="text-base sm:text-lg font-black text-white">Vishal Patel</h4>
                  <p className="text-xs font-bold text-blue-300">{isHi ? 'डायरेक्टर (विशाल सर)' : 'Director (Vishal Sir)'}</p>
                </div>
              </div>
              <p className="text-xs text-slate-300 leading-relaxed italic">
                {isHi
                  ? '"हम मोरा-मैरी में आधुनिक शिक्षा, डिजिटल क्लासरूम और खेलकूद के माध्यम से ग्रामीण प्रतिभाओं को राष्ट्रीय मंच पर चमकाने के लिए संकल्पबद्ध हैं।"'
                  : '"We are determined to bridge the rural-urban education divide through modern digital tools, sports development, and personalized attention."'}
              </p>
            </div>
          </div>
        </div>

      </div>
    </div>
  );
}

/**
 * 2. ADMISSIONS PAGE VIEW (/admissions)
 */
export function AdmissionsPageView({ isHi, currentSession, admissionClasses, primaryPhone, onOpenInquiry }) {
  const ageCriteria = [
    { class: 'Nursery', ageHi: '3+ वर्ष', ageEn: '3+ Years', seats: 'उपलब्ध / Open' },
    { class: 'LKG', ageHi: '4+ वर्ष', ageEn: '4+ Years', seats: 'उपलब्ध / Open' },
    { class: 'UKG', ageHi: '5+ वर्ष', ageEn: '5+ Years', seats: 'उपलब्ध / Open' },
    { class: 'Class 1st', ageHi: '6+ वर्ष', ageEn: '6+ Years', seats: 'सीमित / Limited' },
    { class: 'Class 2nd to 5th', ageHi: '7 से 10 वर्ष', ageEn: '7 to 10 Years', seats: 'मेरिट आधारित / Merit' },
    { class: 'Class 6th to 8th', ageHi: '11 से 14 वर्ष', ageEn: '11 to 14 Years', seats: 'प्रवेश परीक्षा / Test' },
  ];

  const documents = [
    { hi: 'विद्यार्थी का जन्म प्रमाण पत्र (Birth Certificate)', en: 'Birth Certificate of Student' },
    { hi: 'माता-पिता एवं विद्यार्थी का आधार कार्ड (Aadhaar Card)', en: 'Aadhaar Card of Parents & Student' },
    { hi: '4 पासपोर्ट साइज रंगीन फोटो', en: '4 Passport Size Recent Photographs' },
    { hi: 'पिछली कक्षा की मार्कशीट व टीसी (यदि लागू हो)', en: 'Previous School Marksheet & TC (if applicable)' },
  ];

  return (
    <div className="w-full space-y-12 sm:space-y-16 pb-16">
      <PageBanner
        title={isHi ? `दाखिला प्रारंभ सत्र ${currentSession}` : `Admissions Open: Session ${currentSession}`}
        subtitle={
          isHi
            ? `कक्षा ${admissionClasses} में नामांकन जारी। सीमित सीटें, पहले आओ-पहले पाओ के आधार पर प्राथमिकता।`
            : `Enrolling students for classes ${admissionClasses}. Limited seats with individual attention.`
        }
        breadcrumb={isHi ? 'दाखिला (Admissions)' : 'Admissions'}
        isHi={isHi}
      />

      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 space-y-12">
        {/* Step-by-Step Admission Process */}
        <div className="space-y-6">
          <div className="text-center space-y-2">
            <span className="text-[11px] font-black uppercase tracking-widest text-[#102747] bg-[#102747]/8 px-3.5 py-1 rounded-full border border-[#102747]/15">
              {isHi ? 'दाखिला प्रक्रिया' : 'ADMISSION STEPS'}
            </span>
            <h2 className="text-2xl sm:text-3xl font-black text-[#14243B] tracking-tight">
              {isHi ? 'नामांकन के 4 आसान चरण' : 'Simple 4-Step Admission Procedure'}
            </h2>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 sm:gap-6">
            <div className="p-6 rounded-3xl bg-white border border-slate-200 shadow-sm space-y-3 relative">
              <div className="w-10 h-10 rounded-2xl bg-amber-500/10 text-amber-600 flex items-center justify-center font-black text-sm">
                01
              </div>
              <h3 className="font-black text-sm text-[#0c2340]">{isHi ? 'पूछताछ व रजिस्ट्रेशन' : 'Inquiry & Registration'}</h3>
              <p className="text-xs text-slate-500 leading-relaxed">
                {isHi ? 'ऑनलाइन फॉर्म भरें या स्कूल कैंपस में आकर प्रवेश फॉर्म प्राप्त करें।' : 'Fill online inquiry form or visit school campus to collect admission form.'}
              </p>
            </div>

            <div className="p-6 rounded-3xl bg-white border border-slate-200 shadow-sm space-y-3 relative">
              <div className="w-10 h-10 rounded-2xl bg-blue-500/10 text-blue-600 flex items-center justify-center font-black text-sm">
                02
              </div>
              <h3 className="font-black text-sm text-[#0c2340]">{isHi ? 'दस्तावेज सत्यापन' : 'Document Submission'}</h3>
              <p className="text-xs text-slate-500 leading-relaxed">
                {isHi ? 'जन्म प्रमाण पत्र, आधार कार्ड और फोटो के साथ फॉर्म जमा करें।' : 'Submit filled form along with birth certificate, Aadhaar and photos.'}
              </p>
            </div>

            <div className="p-6 rounded-3xl bg-white border border-slate-200 shadow-sm space-y-3 relative">
              <div className="w-10 h-10 rounded-2xl bg-emerald-500/10 text-emerald-600 flex items-center justify-center font-black text-sm">
                03
              </div>
              <h3 className="font-black text-sm text-[#0c2340]">{isHi ? 'संवाद एवं मूल्यांकन' : 'Friendly Assessment'}</h3>
              <p className="text-xs text-slate-500 leading-relaxed">
                {isHi ? 'बच्चे की मूलभूत समझ परखने के लिए शिक्षकों से सरल संवाद।' : 'A warm, stress-free interaction to understand student learning level.'}
              </p>
            </div>

            <div className="p-6 rounded-3xl bg-white border border-slate-200 shadow-sm space-y-3 relative">
              <div className="w-10 h-10 rounded-2xl bg-purple-500/10 text-purple-600 flex items-center justify-center font-black text-sm">
                04
              </div>
              <h3 className="font-black text-sm text-[#0c2340]">{isHi ? 'दाखिला व वेलकम किट' : 'Confirmation & ID Card'}</h3>
              <p className="text-xs text-slate-500 leading-relaxed">
                {isHi ? 'फीस जमा कर डिजिटल आईडी कार्ड व स्टडी किट प्राप्त करें।' : 'Complete fee confirmation, receive official student ID and welcome kit.'}
              </p>
            </div>
          </div>
        </div>

        {/* Age Criteria Table */}
        <div className="bg-white rounded-3xl border border-slate-200 shadow-md p-6 sm:p-8 space-y-6">
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 border-b border-slate-100 pb-4">
            <div>
              <h3 className="text-lg font-black text-[#0c2340]">{isHi ? 'कक्षावार आयु मानदंड (Age Eligibility)' : 'Class-wise Age Eligibility'}</h3>
              <p className="text-xs text-slate-500 mt-0.5">{isHi ? `शैक्षणिक सत्र ${currentSession} हेतु` : `For Academic Session ${currentSession}`}</p>
            </div>
            <button
              type="button"
              onClick={onOpenInquiry}
              className="px-5 py-2.5 rounded-xl bg-[#F4B323] hover:bg-amber-400 text-[#0c2340] font-black text-xs transition-all shadow-md cursor-pointer self-start sm:self-auto"
            >
              {isHi ? 'ऑनलाइन आवेदन करें' : 'Apply Online Now'}
            </button>
          </div>

          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs border-collapse">
              <thead>
                <tr className="bg-slate-50 text-slate-700 font-bold border-b border-slate-200">
                  <th className="py-3 px-4">कक्षा (Class)</th>
                  <th className="py-3 px-4">आयु सीमा (Age Criteria)</th>
                  <th className="py-3 px-4">सीट स्थिति (Seats)</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {ageCriteria.map((item, idx) => (
                  <tr key={idx} className="hover:bg-slate-50/50 transition-colors">
                    <td className="py-3.5 px-4 font-black text-[#0c2340]">{item.class}</td>
                    <td className="py-3.5 px-4 text-slate-600 font-medium">{isHi ? item.ageHi : item.ageEn}</td>
                    <td className="py-3.5 px-4 font-bold text-emerald-600">{item.seats}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>

        {/* Documents Required */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div className="p-6 sm:p-8 rounded-3xl bg-slate-900 text-white space-y-4 shadow-xl">
            <h3 className="text-lg font-black text-amber-300">
              {isHi ? 'नामांकन हेतु आवश्यक दस्तावेज' : 'Documents Required for Admission'}
            </h3>
            <ul className="space-y-3 text-xs sm:text-sm text-slate-300">
              {documents.map((doc, i) => (
                <li key={i} className="flex items-center gap-3">
                  <CheckCircle className="w-4 h-4 text-emerald-400 flex-shrink-0" />
                  <span>{isHi ? doc.hi : doc.en}</span>
                </li>
              ))}
            </ul>
          </div>

          <div className="p-6 sm:p-8 rounded-3xl bg-amber-500/10 border border-amber-500/20 text-[#0c2340] space-y-4 flex flex-col justify-center">
            <h3 className="text-lg font-black text-[#0c2340]">
              {isHi ? 'दाखिला हेल्पलाइन पर सीधे बात करें' : 'Direct Admission Helpline'}
            </h3>
            <p className="text-xs sm:text-sm text-slate-600 leading-relaxed">
              {isHi
                ? 'फीस संरचना, बस सुविधा और सीट उपलब्धता की जानकारी के लिए हमारे एडमिशन कोऑर्डिनेटर से सीधे संपर्क करें।'
                : 'For detailed fee structure, transport routes, and seat availability, speak directly to our admission counselor.'}
            </p>
            <div className="pt-2 flex flex-wrap gap-3">
              <a
                href={`tel:${primaryPhone}`}
                className="px-5 py-3 rounded-xl bg-[#0c2340] text-white font-bold text-xs inline-flex items-center gap-2 shadow-md hover:bg-[#15355d]"
              >
                <Phone className="w-4 h-4 text-[#F4B323]" />
                <span>+91 {primaryPhone}</span>
              </a>
              <button
                type="button"
                onClick={onOpenInquiry}
                className="px-5 py-3 rounded-xl bg-[#F4B323] text-[#0c2340] font-black text-xs inline-flex items-center gap-2 shadow-md hover:bg-amber-400 cursor-pointer"
              >
                <span>{isHi ? 'पूछताछ फॉर्म भरें' : 'Submit Admission Inquiry'}</span>
              </button>
            </div>
          </div>
        </div>

      </div>
    </div>
  );
}

/**
 * 3. ACADEMICS & FACILITIES PAGE VIEW (/academics)
 */
export function AcademicsPageView({ isHi }) {
  const pillars = [
    {
      titleHi: 'इंग्लिश मीडियम व मजबूत आधार',
      titleEn: 'English-Medium Core Foundation',
      descHi: 'एनसीईआरटी आधारित सुनियोजित पाठ्यक्रम, अंग्रेजी बोलचाल, व्याकरण और गणितीय समझ पर विशेष जोर।',
      descEn: 'NCERT aligned rigorous curriculum with dedicated focus on spoken English, grammar, and arithmetic clarity.',
      icon: BookOpen,
      color: 'amber'
    },
    {
      titleHi: 'स्मार्ट क्लास व डिजिटल लर्निंग',
      titleEn: 'Smart Classes & Digital Learning',
      descHi: 'विजुअल एनीमेशन, कंप्यूटर साक्षरता और आधुनिक डिजिटल तकनीकों द्वारा रोचक शिक्षण।',
      descEn: 'Engaging multimedia learning, interactive digital tools, and foundational computer coding literacy.',
      icon: Sparkles,
      color: 'blue'
    },
    {
      titleHi: 'विशाल खुला खेल का मैदान',
      titleEn: 'Sports & Physical Fitness',
      descHi: 'फुटबॉल, एथलेटिक्स, योग और शारीरिक तंदुरुस्ती के लिए विशाल सुरक्षित खेल परिसर।',
      descEn: 'Spacious outdoor athletic field for football, badminton, daily morning PT, and active fitness.',
      icon: Trophy,
      color: 'emerald'
    },
    {
      titleHi: 'सीसीटीवी सुरक्षित व अनुशासित परिसर',
      titleEn: 'Safe & CCTV Protected Campus',
      descHi: 'चारदीवारी से सुरक्षित, 24/7 सीसीटीवी निगरानी और अनुशासित स्नेहमयी वातावरण।',
      descEn: 'Boundary-secured, 24/7 CCTV surveillance with zero-tolerance for indiscipline and utmost child safety.',
      icon: ShieldCheck,
      color: 'indigo'
    },
    {
      titleHi: 'समर्पित एवं अनुभवी शिक्षक',
      titleEn: 'Dedicated Faculty & Personal Care',
      descHi: 'प्रत्येक बच्चे की कमजोरियों को पहचानकर व्यक्तिगत मार्गदर्शन देने वाले स्नेहशील शिक्षक गण।',
      descEn: 'Trained, caring educators who provide individual academic counseling and nurture every child’s unique talent.',
      icon: Users,
      color: 'purple'
    },
  ];

  return (
    <div className="w-full space-y-12 sm:space-y-16 pb-16">
      <PageBanner
        title={isHi ? 'शैक्षणिक उत्कृष्टता एवं आधुनिक सुविधाएं' : 'Academics & Campus Facilities'}
        subtitle={
          isHi
            ? 'नर्सरी से 8वीं तक सुनियोजित इंग्लिश मीडियम पाठ्यक्रम, खेलकूद, कंप्यूटर लैब और संस्कारवान शिक्षा।'
            : 'Structured English-medium curriculum, sports, digital labs, and character development from Nursery to 8th.'
        }
        breadcrumb={isHi ? 'शिक्षा व सुविधाएं (Academics)' : 'Academics'}
        isHi={isHi}
      />

      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 space-y-12">
        {/* 5 Pillars */}
        <div className="space-y-6">
          <div className="text-center space-y-2 max-w-2xl mx-auto">
            <span className="text-[11px] font-black uppercase tracking-widest text-[#102747] bg-[#102747]/8 px-3.5 py-1 rounded-full border border-[#102747]/15">
              {isHi ? 'हमारे 5 मजबूत आधार' : 'OUR 5 PILLARS'}
            </span>
            <h2 className="text-2xl sm:text-3xl font-black text-[#14243B] tracking-tight">
              {isHi ? 'मिशन नवोदय स्कूल की मुख्य विशेषताएं' : 'What Makes Our Academic Model Exceptional'}
            </h2>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
            {pillars.map((p, idx) => {
              const Icon = p.icon;
              return (
                <div
                  key={idx}
                  className="bg-white rounded-3xl p-6 sm:p-8 border border-slate-200/90 shadow-sm hover:shadow-xl hover:-translate-y-1 transition-all duration-300 space-y-4"
                >
                  <div className="w-12 h-12 rounded-2xl bg-[#0c2340]/5 text-[#0c2340] flex items-center justify-center font-bold">
                    <Icon className="w-6 h-6 text-[#F4B323]" />
                  </div>
                  <div>
                    <h3 className="text-base font-black text-[#0c2340]">{isHi ? p.titleHi : p.titleEn}</h3>
                    <p className="text-xs text-slate-500 mt-2 leading-relaxed">
                      {isHi ? p.descHi : p.descEn}
                    </p>
                  </div>
                </div>
              );
            })}
          </div>
        </div>

        {/* Daily Schedule Card */}
        <div className="p-6 sm:p-10 rounded-3xl bg-slate-50 border border-slate-200 space-y-6">
          <h3 className="text-lg font-black text-[#0c2340] border-b border-slate-200 pb-3">
            {isHi ? 'दैनिक शैक्षणिक दिनचर्या (Daily Routine)' : 'Daily Academic Schedule'}
          </h3>
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-4 text-xs">
            <div className="p-4 rounded-2xl bg-white border border-slate-200/80 space-y-1.5">
              <div className="font-bold text-[#F4B323]">08:00 AM - 08:30 AM</div>
              <div className="font-black text-[#0c2340]">{isHi ? 'सुबह की प्रार्थना व योग' : 'Morning Assembly & Yoga'}</div>
              <div className="text-slate-500">{isHi ? 'राष्ट्रगान, दैनिक समाचार, नैतिक विचार' : 'Anthem, news bulletin & moral thought'}</div>
            </div>
            <div className="p-4 rounded-2xl bg-white border border-slate-200/80 space-y-1.5">
              <div className="font-bold text-blue-600">08:30 AM - 11:30 AM</div>
              <div className="font-black text-[#0c2340]">{isHi ? 'कोर एकेडमिक सत्र' : 'Core Academic Sessions'}</div>
              <div className="text-slate-500">{isHi ? 'गणित, अंग्रेजी, विज्ञान, सामाजिक अध्ययन' : 'Maths, English, Science & Social Studies'}</div>
            </div>
            <div className="p-4 rounded-2xl bg-white border border-slate-200/80 space-y-1.5">
              <div className="font-bold text-emerald-600">12:00 PM - 02:00 PM</div>
              <div className="font-black text-[#0c2340]">{isHi ? 'कंप्यूटर व सह-पाठ्यक्रम' : 'Computer Lab, Sports & Library'}</div>
              <div className="text-slate-500">{isHi ? 'प्रैक्टिकल कंप्यूटर, खेलकूद, गृहकार्य समीक्षा' : 'Hands-on IT practice, outdoor games'}</div>
            </div>
          </div>
        </div>

      </div>
    </div>
  );
}

/**
 * 4. CAMPUS GALLERY PAGE VIEW (/gallery)
 */
export function GalleryPageView({ isHi }) {
  const [filter, setFilter] = useState('all');

  const photos = [
    { title: 'School Building & Panoramic View', category: 'campus', src: '/school_campus_banner.jpg' },
    { title: 'Dedicated Teachers & Academic Session', category: 'class', src: '/school_campus_banner.jpg' },
    { title: 'Morning Assembly & Discipline', category: 'events', src: '/school_campus_banner.jpg' },
    { title: 'Sports Field & Athletic Activities', category: 'sports', src: '/school_campus_banner.jpg' },
    { title: 'Smart Classroom & Interactive Learning', category: 'class', src: '/school_campus_banner.jpg' },
    { title: 'Annual Day Celebrations & Awards', category: 'events', src: '/school_campus_banner.jpg' },
  ];

  const filtered = filter === 'all' ? photos : photos.filter(p => p.category === filter);

  return (
    <div className="w-full space-y-12 sm:space-y-16 pb-16">
      <PageBanner
        title={isHi ? 'स्कूल फोटो गैलरी' : 'Campus Photo Gallery'}
        subtitle={
          isHi
            ? 'मिशन नवोदय पब्लिक स्कूल के सुंदर परिसर, खेलकूद, कक्षाओं और सांस्कृतिक गतिविधियों की झलकियां।'
            : 'Glimpses into the vibrant student life, lush playground, classrooms, and celebrations at MNP School.'
        }
        breadcrumb={isHi ? 'फोटो गैलरी (Gallery)' : 'Gallery'}
        isHi={isHi}
      />

      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 space-y-8">
        {/* Filter Pills */}
        <div className="flex flex-wrap items-center justify-center gap-2 sm:gap-3">
          {[
            { id: 'all', labelHi: 'सभी तस्वीरें (All)', labelEn: 'All Photos' },
            { id: 'campus', labelHi: 'स्कूल परिसर (Campus)', labelEn: 'Campus' },
            { id: 'class', labelHi: 'कक्षाएं (Classrooms)', labelEn: 'Classrooms' },
            { id: 'sports', labelHi: 'खेलकूद (Sports)', labelEn: 'Sports' },
            { id: 'events', labelHi: 'सांस्कृतिक कार्यक्रम (Events)', labelEn: 'Events' },
          ].map(tab => (
            <button
              key={tab.id}
              type="button"
              onClick={() => setFilter(tab.id)}
              className={`px-4 py-2 rounded-xl text-xs font-bold transition-all cursor-pointer ${
                filter === tab.id
                  ? 'bg-[#0c2340] text-[#F4B323] shadow-md border border-[#F4B323]/40'
                  : 'bg-white text-slate-600 border border-slate-200 hover:bg-slate-50'
              }`}
            >
              {isHi ? tab.labelHi : tab.labelEn}
            </button>
          ))}
        </div>

        {/* Gallery Grid */}
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
          {filtered.map((item, idx) => (
            <div
              key={idx}
              className="group relative rounded-3xl overflow-hidden bg-white border border-slate-200 shadow-md hover:shadow-2xl transition-all duration-300"
            >
              <div className="aspect-[4/3] w-full overflow-hidden bg-slate-100">
                <img
                  src={item.src}
                  alt={item.title}
                  className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-500"
                />
              </div>
              <div className="p-4 bg-white">
                <h4 className="text-xs font-bold text-[#0c2340] line-clamp-1">{item.title}</h4>
                <p className="text-[10px] text-slate-400 uppercase tracking-wider mt-0.5">Mora-Mairi Campus · Siwan</p>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

/**
 * 5. CONTACT US PAGE VIEW (/contact)
 */
export function ContactPageView({ isHi, schoolLocation, primaryPhone, officialEmail }) {
  return (
    <div className="w-full space-y-12 sm:space-y-16 pb-16">
      <PageBanner
        title={isHi ? 'हमसे संपर्क करें' : 'Contact Mission Navodaya Public School'}
        subtitle={
          isHi
            ? 'मोरा-मैरी, सीवान। प्रवेश पूछताछ, अभिभावक परामर्श, हेल्पलाइन और लाइव गूगल मैप नेविगेशन।'
            : 'Mora-Mairi, Siwan. Direct admission hotline, office timings, WhatsApp support, and Google Map directions.'
        }
        breadcrumb={isHi ? 'संपर्क (Contact)' : 'Contact Us'}
        isHi={isHi}
      />

      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 space-y-12">
        {/* 4 Cards */}
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6">
          {/* Location */}
          <div className="p-6 rounded-3xl bg-white border border-slate-200 shadow-sm space-y-3">
            <div className="w-12 h-12 rounded-2xl bg-blue-500/10 text-blue-600 flex items-center justify-center font-bold">
              <MapPin className="w-6 h-6 text-blue-600" />
            </div>
            <div>
              <h3 className="text-sm font-black text-[#0c2340]">{isHi ? 'स्कूल का पता' : 'Campus Location'}</h3>
              <p className="text-xs text-slate-500 mt-1 leading-relaxed">
                {schoolLocation}
                <br />
                {isHi ? 'मोरा बाजार, मैरी - रतौली रोड' : 'Mora Bazar, Near Mairi - Ratauli Road'}
              </p>
            </div>
            <a
              href="https://www.google.com/maps/dir/?api=1&destination=26.115206775039834,84.62215723091671"
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex items-center gap-1.5 text-xs font-bold text-blue-600 hover:underline pt-1"
            >
              <span>{isHi ? 'रास्ता देखें (Map)' : 'Get Directions'}</span>
              <ExternalLink className="w-3.5 h-3.5" />
            </a>
          </div>

          {/* Phone */}
          <div className="p-6 rounded-3xl bg-white border border-slate-200 shadow-sm space-y-3">
            <div className="w-12 h-12 rounded-2xl bg-amber-500/10 text-amber-600 flex items-center justify-center font-bold">
              <Phone className="w-6 h-6 text-[#F4B323]" />
            </div>
            <div>
              <h3 className="text-sm font-black text-[#0c2340]">{isHi ? 'फोन हेल्पलाइन' : 'Phone Helpline'}</h3>
              <p className="text-xs text-slate-500 mt-1 leading-relaxed">
                +91 {primaryPhone}
                <br />
                {isHi ? 'सोमवार से शनिवार (कॉल सहायता)' : 'Monday through Saturday'}
              </p>
            </div>
            <a
              href={`tel:${primaryPhone}`}
              className="inline-flex items-center gap-1.5 text-xs font-bold text-amber-600 hover:underline pt-1"
            >
              <span>{isHi ? 'सीधे कॉल करें' : 'Call Now'}</span>
              <ArrowRight className="w-3.5 h-3.5" />
            </a>
          </div>

          {/* WhatsApp */}
          <div className="p-6 rounded-3xl bg-white border border-slate-200 shadow-sm space-y-3">
            <div className="w-12 h-12 rounded-2xl bg-emerald-500/10 text-emerald-600 flex items-center justify-center font-bold">
              <Smartphone className="w-6 h-6 text-emerald-600" />
            </div>
            <div>
              <h3 className="text-sm font-black text-[#0c2340]">{isHi ? 'व्हाट्सएप डेस्क' : 'WhatsApp Desk'}</h3>
              <p className="text-xs text-slate-500 mt-1 leading-relaxed">
                +91 {primaryPhone}
                <br />
                {isHi ? 'वॉइस मैसेज व चैट सहायता' : 'Voice Notes & Direct Chat'}
              </p>
            </div>
            <a
              href={`https://wa.me/91${primaryPhone}`}
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex items-center gap-1.5 text-xs font-bold text-emerald-600 hover:underline pt-1"
            >
              <span>{isHi ? 'व्हाट्सएप चैट' : 'Open WhatsApp'}</span>
              <ExternalLink className="w-3.5 h-3.5" />
            </a>
          </div>

          {/* Timings */}
          <div className="p-6 rounded-3xl bg-white border border-slate-200 shadow-sm space-y-3">
            <div className="w-12 h-12 rounded-2xl bg-purple-500/10 text-purple-600 flex items-center justify-center font-bold">
              <Clock className="w-6 h-6 text-purple-600" />
            </div>
            <div>
              <h3 className="text-sm font-black text-[#0c2340]">{isHi ? 'कार्यालय समय' : 'Office Timings'}</h3>
              <p className="text-xs text-slate-500 mt-1 leading-relaxed">
                {isHi ? 'प्रातः 08:00 से दोपहर 02:00' : '08:00 AM – 02:00 PM'}
                <br />
                {isHi ? 'रविवार: साप्ताहिक अवकाश' : 'Sunday: Closed'}
              </p>
            </div>
            <div className="text-[11px] font-bold text-purple-600 pt-1">
              {isHi ? 'प्रशासनिक काउंटर सक्रिय' : 'Admission Counter Open'}
            </div>
          </div>
        </div>

        {/* Embedded Interactive Google Map */}
        <div className="rounded-3xl overflow-hidden border border-slate-200 shadow-xl bg-white">
          <div className="bg-[#0c2340] text-white px-5 py-4 flex flex-wrap items-center justify-between gap-4">
            <div className="flex items-center gap-3">
              <div className="w-8 h-8 rounded-full bg-amber-500/20 text-[#F4B323] flex items-center justify-center">
                <MapPin className="w-4 h-4" />
              </div>
              <div>
                <div className="font-black text-sm sm:text-base text-white">
                  {isHi ? 'सटीक स्कूल स्थान (Google Maps)' : 'Precise Campus Location'}
                </div>
                <div className="text-[10px] sm:text-xs text-amber-300 font-mono">
                  GPS: 26.115207° N, 84.622157° E · Mora-Mairi, Siwan (Bihar)
                </div>
              </div>
            </div>
            <a
              href="https://www.google.com/maps/dir/?api=1&destination=26.115206775039834,84.62215723091671"
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex items-center gap-2 px-4 py-2 rounded-xl bg-[#F4B323] hover:bg-amber-400 text-[#0c2340] font-black text-xs transition-all shadow-md"
            >
              <span>{isHi ? 'सीधे रास्ता देखें (Get Directions)' : 'Get Live Directions'}</span>
              <ExternalLink className="w-3.5 h-3.5" />
            </a>
          </div>
          <div className="p-6 sm:p-8 bg-gradient-to-br from-slate-50 to-amber-50/30 text-center space-y-4">
            <p className="text-xs sm:text-sm text-slate-600 max-w-xl mx-auto leading-relaxed">
              {isHi
                ? 'स्कूल परिसर: मोरा-मैरी, मोरा बाजार, सीवान (बिहार)। नीचे दिए गए बटन पर क्लिक करके अपने फोन में गूगल मैप्स नेविगेशन चालू करें।'
                : 'Campus: Mora-Mairi, Mora Bazar, Siwan (Bihar). Click the button below to launch turn-by-turn navigation on your mobile.'}
            </p>
            <a
              href="https://www.google.com/maps/dir/?api=1&destination=26.115206775039834,84.62215723091671"
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex items-center gap-2 px-6 py-3.5 rounded-2xl bg-blue-600 hover:bg-blue-700 text-white font-bold text-xs sm:text-sm shadow-lg transition-all"
            >
              <MapPin className="w-4 h-4 text-[#F4B323]" />
              <span>{isHi ? 'गूगल मैप्स पर सीधा रास्ता देखें (Open in Google Maps)' : 'Open in Google Maps Application'}</span>
              <ExternalLink className="w-4 h-4" />
            </a>
          </div>
        </div>
      </div>
    </div>
  );
}

/**
 * 6. DOWNLOAD MOBILE APP PAGE VIEW (/download)
 */
export function DownloadPageView({ isHi, schoolName, primaryPhone }) {
  return (
    <div className="w-full space-y-12 sm:space-y-16 pb-16">
      <PageBanner
        title={isHi ? 'आधिकारिक मोबाइल ऐप डाउनलोड करें' : 'Download MNP School Official Mobile App'}
        subtitle={
          isHi
            ? 'अभिभावकों एवं शिक्षकों के लिए विशेष रूप से निर्मित Android ऐप। दैनिक उपस्थिति, रिजल्ट और फीस रसीद अपने फोन में देखें।'
            : 'Official Android application for parents, students, and educators. Real-time attendance, results & fee receipts.'
        }
        breadcrumb={isHi ? 'ऐप डाउनलोड (Download)' : 'Download App'}
        isHi={isHi}
      />

      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="rounded-3xl bg-gradient-to-br from-[#0c2340] via-[#102747] to-[#091A32] text-white p-6 sm:p-12 border border-amber-500/30 shadow-2xl space-y-8">
          <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 items-center">
            
            <div className="lg:col-span-7 space-y-5">
              <span className="px-3.5 py-1 rounded-full bg-amber-500/20 text-amber-300 font-bold text-xs uppercase border border-amber-500/30">
                Android APK v1.0.1 (Build 8)
              </span>
              <h2 className="text-2xl sm:text-4xl font-black text-white">
                {isHi ? 'स्मार्ट स्कूल अब आपके हाथ में' : 'Next-Gen School Portal in Your Pocket'}
              </h2>
              <p className="text-xs sm:text-sm text-slate-300 leading-relaxed">
                {isHi
                  ? 'मिशन नवोदय पब्लिक स्कूल के अभिभावकों के लिए सबसे सरल और सुरक्षित ऐप। 1-टैप में बच्चे की उपस्थिति, रिजल्ट मार्कशीट और सभी स्कूल नोटिस देखें।'
                  : 'Fast, secure, and intuitive application built for parents and teachers. Instant notifications, marksheet download, and fee status.'}
              </p>

              {/* Download Buttons */}
              <div className="pt-3 flex flex-col sm:flex-row gap-4">
                <a
                  href="https://github.com/Rvsharma1218/MNP-School/releases/download/v1.0.1-build8/MNP_School_arm64-v8a.apk"
                  download="MNP_School_v1.0.1.apk"
                  className="px-6 py-4 rounded-2xl bg-[#F4B323] hover:bg-amber-400 text-[#0c2340] font-black text-sm flex items-center justify-center gap-3 shadow-xl cursor-pointer hover:scale-105 active:scale-95 transition-all"
                >
                  <Download className="w-5 h-5" />
                  <span>{isHi ? 'Android APK सीधे डाउनलोड करें (v1.0.1)' : 'Direct Download APK (v1.0.1)'}</span>
                </a>

                <a
                  href="https://github.com/Rvsharma1218/MNP-School/releases/download/v1.0.1-build8/MNP_School_armeabi-v7a.apk"
                  download="MNP_School_v1.0.1_v7a.apk"
                  className="px-5 py-4 rounded-2xl bg-white/10 hover:bg-white/15 text-white font-bold text-xs flex items-center justify-center gap-2 border border-white/20 transition-all cursor-pointer"
                >
                  <Smartphone className="w-4 h-4 text-slate-300" />
                  <span>{isHi ? 'पुराने फोन के लिए (32-bit v7a)' : 'Older Devices (32-bit v7a)'}</span>
                </a>
              </div>

              <div className="flex flex-wrap items-center gap-3 text-xs text-slate-400 pt-1">
                <span>✓ 100% सुरक्षित · 52 MB · Android 6.0+</span>
                <span className="text-slate-600">|</span>
                <a
                  href={`https://wa.me/91${primaryPhone}?text=${encodeURIComponent('नमस्ते सर, मुझे MNP School App (v1.0.1) इनस्टॉल करने में सहायता चाहिए।')}`}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="text-amber-400 hover:text-amber-300 font-bold inline-flex items-center gap-1 hover:underline"
                >
                  <span>{isHi ? 'व्हाट्सएप सहायता चाहिए?' : 'Need WhatsApp Help?'}</span>
                </a>
              </div>
            </div>

            {/* Installation Instructions */}
            <div className="lg:col-span-5 p-6 rounded-2xl bg-white/5 border border-white/10 space-y-4">
              <h4 className="font-black text-sm text-amber-300">
                {isHi ? 'इंस्टॉल करने के आसान चरण:' : 'Installation Instructions:'}
              </h4>
              <ol className="space-y-3 text-xs text-slate-300 list-decimal list-inside">
                <li>{isHi ? 'ऊपर दिए गए "डाउनलोड करें" बटन पर टैप करें।' : 'Tap the Download button above.'}</li>
                <li>{isHi ? 'डाउनलोड पूरा होने पर नोटिफिकेशन बार से फाइल खोलें।' : 'Open the downloaded APK from notification bar.'}</li>
                <li>{isHi ? 'यदि "Unknown Sources" का विकल्प आए, तो "Allow" करें।' : 'Allow "Install from Unknown Sources" if prompted.'}</li>
                <li>{isHi ? 'Install पर टैप करें और ऐप शुरू करें।' : 'Tap Install and open the MNP School App.'}</li>
              </ol>
            </div>

          </div>
        </div>
      </div>
    </div>
  );
}

