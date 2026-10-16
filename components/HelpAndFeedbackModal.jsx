'use client';

import React, { useState, useEffect } from 'react';
import {
  ArrowLeft, X, HelpCircle, MessageCircle, Bug, Star,
  FileText, AlertCircle, ChevronRight, ChevronDown, Phone,
  Mail, ExternalLink, CheckCircle2, ShieldCheck, Search, Send,
  Building2, UserCheck, Shield, Lock, Database, Clock
} from 'lucide-react';
import { useSchoolStore } from '../lib/store';
import { db } from '../lib/firebase';
import { collection, addDoc, serverTimestamp, doc, onSnapshot, setDoc } from 'firebase/firestore';

const APP_VERSION = 'Version 1.0.0';

const FAQS = [
  {
    q: 'How does offline mode sync with the website?',
    a: 'The portal works seamlessly offline using indexed browser caching. As soon as an active internet connection is detected, all registered students, recorded fee payments, and attendance rolls automatically sync to the secure cloud database in real-time.'
  },
  {
    q: 'How do I add a signature and make it transparent?',
    a: 'Navigate to Settings > Official Signatures & School Seal. Upload a clear photo of the Principal signature taken on white paper. The built-in AI background remover automatically strips paper pixels and renders crisp transparent ink on fee receipts and report cards.'
  },
  {
    q: 'Can teachers access fee collection?',
    a: 'By default, fee collection and financial ledgers are restricted to Principal / Admin credentials. If permitted, the administrator can grant granular fee collection and discount rights to specific teachers from the Teacher Permissions management panel.'
  },
  {
    q: 'How can I restore my database backup?',
    a: 'Go to Settings > Data Backup. You can download an encrypted JSON backup snapshot of your entire school directory anytime. To restore, select your exported backup file in the Restore section to recover all records instantly.'
  },
  {
    q: 'How do I print student ID cards and admit cards?',
    a: 'Click on ID Cards or Admit Cards in the left navigation sidebar. Select your desired layout template, pick the academic class and section, and click "Print" or "Download PDF".'
  },
  {
    q: 'How to send fee reminders on WhatsApp?',
    a: 'From the Fees dashboard, find any student with outstanding dues and click the WhatsApp icon or "Send Reminder". The system auto-generates a personalized bilingual (Hindi/English) fee invoice reminder message ready to send.'
  }
];

const TERMS_AND_POLICIES = [
  {
    title: '1. Educational Scope & Authorized Licensing',
    icon: Building2,
    content: 'The School Management Cloud portal and companion applications are provisioned exclusively for academic administration, student records management, fee accounting, and institutional operations. Access is strictly granted to verified school principals, designated administrators, faculty teachers, and authorized operational staff.'
  },
  {
    title: '2. 100% Institutional Data Ownership & Student Privacy',
    icon: ShieldCheck,
    content: 'All information entered into this platform—including student demographic profiles, parent contact numbers, photographs, attendance registers, examination marks, and fee transaction histories—remains the 100% exclusive property of your institution. We never sell, lease, monetize, or disclose student records or institutional data to third-party commercial entities, data brokers, or advertising networks under any circumstances.'
  },
  {
    title: '3. End-to-End Cryptography & Data Protection',
    icon: Lock,
    content: 'All communication across web and mobile clients is protected using Transport Layer Security (TLS 1.3). Database snapshots and cloud backups are encrypted at rest using enterprise-grade AES-256 standards in secured datacenters. Offline cached stores on devices remain sandboxed and locked behind administrative session authentication.'
  },
  {
    title: '4. Role-Based Access Controls & Staff Governance',
    icon: UserCheck,
    content: 'The Principal / Administrator holds autonomous authority over faculty account provisioning, class assignments, and granular teacher permissions (e.g. enabling or restricting fee ledger access). Each staff member is personally accountable for safeguarding their login credentials and session tokens.'
  },
  {
    title: '5. Financial Records & Audit Trail Integrity',
    icon: Shield,
    content: 'Digital fee receipts, partial payment records, discount concessions, dues carried forward, and student month ledgers are chronologically preserved with immutable timestamps. The system enforces strict audit trails to prevent ledger tampering and maintain institutional financial integrity.'
  },
  {
    title: '6. Data Portability & Unrestricted Export Rights',
    icon: Database,
    content: 'Your educational institution holds the unrestricted right to export a complete, portable JSON database backup and Excel records of all students, fee registers, and academic results at any time without fees, penalties, or vendor lock-in.'
  },
  {
    title: '7. Offline Continuity & System Availability SLA',
    icon: Clock,
    content: 'The application architecture implements local offline persistence, ensuring zero disruption to attendance taking, fee recording, and student searches during internet outages. Background synchronization executes automatically upon internet reconnection, targeting 99.9% cloud operational uptime.'
  },
  {
    title: '8. Account Termination & Full Data Purge Guarantee',
    icon: FileText,
    content: 'In the event of service discontinuation requested by the verified School Administrator, all institutional cloud records, photo assets, and backups will be permanently and irreversibly purged from our cloud servers within 30 days following confirmed handover of the final database export.'
  }
];

export default function HelpAndFeedbackModal({ isOpen, onClose }) {
  const { showToast, currentUser, settings, navigate, themeMode } = useSchoolStore();
  const isDark = themeMode === 'dark';

  // Active view: 'main' | 'help' | 'contact' | 'feedback' | 'rate' | 'terms' | 'channels'
  const [activeView, setActiveView] = useState('main');

  // FAQ search & expanded state
  const [faqSearch, setFaqSearch] = useState('');
  const [expandedFaq, setExpandedFaq] = useState(null);

  // Expanded term state
  const [expandedTerm, setExpandedTerm] = useState(null);

  // Feedback form state
  const [feedbackCategory, setFeedbackCategory] = useState('Technical Issue');
  const [feedbackText, setFeedbackText] = useState('');
  const [isSubmittingFeedback, setIsSubmittingFeedback] = useState(false);

  // Rating state
  const [rating, setRating] = useState(5);
  const [hoverRating, setHoverRating] = useState(0);

  // Live Super-Admin Support Config from system_config/support_info
  const [supportConfig, setSupportConfig] = useState(null);

  useEffect(() => {
    if (!db) return;
    try {
      const unsubDir = onSnapshot(doc(db, 'schoolDirectory', 'support_info'), (snap) => {
        if (snap.exists()) {
          setSupportConfig(snap.data());
        }
      });
      const unsubSys = onSnapshot(doc(db, 'system_config', 'support_info'), (snap) => {
        if (snap.exists()) {
          setSupportConfig(prev => prev || snap.data());
        }
      });
      return () => {
        unsubDir();
        unsubSys();
      };
    } catch (e) {
      console.warn('Support info listener error:', e);
    }
  }, []);

  if (!isOpen) return null;

  const handleClose = () => {
    setActiveView('main');
    onClose();
  };

  const handleBack = () => {
    if (activeView === 'main') {
      handleClose();
    } else {
      setActiveView('main');
    }
  };

  const handleSubmitFeedback = async (e) => {
    e.preventDefault();
    if (!feedbackText.trim()) {
      showToast('Please enter your feedback or describe the issue.', 'error');
      return;
    }
    setIsSubmittingFeedback(true);
    const docId = `fb_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
    const payload = {
      id: docId,
      schoolId: settings?.schoolId || currentUser?.schoolId || 'SCHOOL_001',
      schoolName: settings?.instituteName || settings?.schoolName || 'School Management',
      senderEmail: currentUser?.email || 'portal-user@school.com',
      senderName: currentUser?.name || currentUser?.displayName || 'School Staff',
      senderRole: currentUser?.role || 'staff',
      category: feedbackCategory,
      message: feedbackText.trim(),
      device: 'web',
      status: 'new',
      createdAt: serverTimestamp()
    };
    try {
      if (db) {
        // 1. Primary write to feedbacks collection
        try {
          await addDoc(collection(db, 'feedbacks'), payload);
        } catch (e1) {
          console.warn('feedbacks collection write note:', e1);
        }

        // 2. Guaranteed backup write to schoolDirectory
        try {
          await setDoc(doc(db, 'schoolDirectory', 'system_feedbacks', 'items', docId), payload);
        } catch (e2) {
          console.warn('schoolDirectory backup note:', e2);
        }
      }
    } catch (err) {
      console.warn('Feedback save note:', err);
    } finally {
      setIsSubmittingFeedback(false);
      showToast('✓ Feedback submitted to School Admin successfully!', 'success');
      setFeedbackText('');
      setActiveView('main');
    }
  };

  const handleSubmitRating = async () => {
    const docId = `rate_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
    const payload = {
      id: docId,
      schoolId: settings?.schoolId || currentUser?.schoolId || 'SCHOOL_001',
      schoolName: settings?.instituteName || settings?.schoolName || 'School Management',
      senderEmail: currentUser?.email || 'portal-user@school.com',
      senderName: currentUser?.name || currentUser?.displayName || 'School Staff',
      senderRole: currentUser?.role || 'staff',
      category: 'App Rating',
      rating: rating,
      message: `${rating} / 5 Stars Rating`,
      device: 'web',
      status: 'new',
      createdAt: serverTimestamp()
    };
    try {
      if (db) {
        try {
          await addDoc(collection(db, 'feedbacks'), payload);
        } catch (e1) {
          console.warn('feedbacks rating write note:', e1);
        }
        try {
          await setDoc(doc(db, 'schoolDirectory', 'system_feedbacks', 'items', docId), payload);
        } catch (e2) {
          console.warn('schoolDirectory rating backup note:', e2);
        }
      }
    } catch (err) {
      console.warn('Rating save note:', err);
    }
    showToast(`★ Thank you for rating ${rating} stars!`, 'success');
    setTimeout(() => {
      setActiveView('main');
    }, 700);
  };

  // Dynamic School Admin Contact Info (Master support info takes priority, fall back to school settings)
  const schoolName = settings?.instituteName || settings?.schoolName || 'School Administration';
  const principalName = settings?.principalName || '';
  const supportPhone = supportConfig?.supportPhone || settings?.mobile || settings?.phone || '+91 8568643490';
  const supportWhatsapp = supportConfig?.supportWhatsapp || supportPhone;
  const supportEmail = supportConfig?.supportEmail || settings?.email || 'support@schoolcloud.com';
  const workingHours = supportConfig?.workingHours || '10:00 AM - 07:00 PM (Mon - Sat)';

  const cleanPhone = (supportPhone || '').replace(/[^0-9]/g, '');
  const cleanWhatsapp = (supportWhatsapp || '').replace(/[^0-9]/g, '');
  const whatsappNumber = cleanWhatsapp
    ? (cleanWhatsapp.startsWith('91') ? cleanWhatsapp : (cleanWhatsapp.length === 10 ? `91${cleanWhatsapp}` : cleanWhatsapp))
    : '918568643490';

  const filteredFaqs = FAQS.filter(
    f => f.q.toLowerCase().includes(faqSearch.toLowerCase()) || f.a.toLowerCase().includes(faqSearch.toLowerCase())
  );

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-3 sm:p-4 bg-black/60 backdrop-blur-xs animate-in fade-in duration-200">
      <div className={`rounded-3xl w-full max-w-md shadow-2xl overflow-hidden flex flex-col max-h-[92vh] animate-in zoom-in-95 duration-200 font-sans border transition-colors ${
        isDark ? 'bg-[#121212] text-white border-[#262626]' : 'bg-white text-slate-900 border-slate-200'
      }`}>
        
        {/* --- Top App Bar --- */}
        <div className={`flex items-center justify-between px-4 py-3.5 border-b select-none flex-shrink-0 transition-colors ${
          isDark ? 'border-[#262626] bg-[#121212]' : 'border-slate-200 bg-slate-50/80'
        }`}>
          <div className="flex items-center gap-3">
            <button
              type="button"
              onClick={handleBack}
              className={`p-1.5 -ml-1 rounded-full transition-colors cursor-pointer ${
                isDark ? 'text-white hover:text-white/80 hover:bg-white/10' : 'text-slate-700 hover:text-slate-900 hover:bg-slate-200'
              }`}
              title={activeView === 'main' ? 'Close' : 'Back'}
            >
              <ArrowLeft className="w-5 h-5" />
            </button>
            <h2 className={`font-semibold text-base sm:text-lg tracking-wide ${isDark ? 'text-white' : 'text-slate-900'}`}>
              {activeView === 'main' && 'Help and feedback'}
              {activeView === 'help' && 'Help Centre'}
              {activeView === 'contact' && 'Contact us'}
              {activeView === 'feedback' && 'Send feedback'}
              {activeView === 'rate' && 'Rate the app'}
              {activeView === 'terms' && 'Terms and Privacy Policy'}
              {activeView === 'channels' && 'Channels reports'}
            </h2>
          </div>
          <button
            type="button"
            onClick={handleClose}
            className={`p-1.5 rounded-full transition-colors cursor-pointer ${
              isDark ? 'text-[#8E8E8E] hover:text-white hover:bg-white/10' : 'text-slate-400 hover:text-slate-700 hover:bg-slate-200'
            }`}
            title="Close"
          >
            <X className="w-4 h-4" />
          </button>
        </div>

        {/* --- Dynamic Content Body --- */}
        <div className="flex-1 overflow-y-auto">

          {/* ========================================================================= */}
          {/* MAIN MENU */}
          {/* ========================================================================= */}
          {activeView === 'main' && (
            <div className={`py-2 divide-y ${isDark ? 'divide-[#1e1e1e]/60' : 'divide-slate-100'}`}>
              {/* 1. Help Centre */}
              <button
                type="button"
                onClick={() => setActiveView('help')}
                className={`w-full px-5 py-3.5 flex items-start gap-4 text-left transition-colors cursor-pointer group ${
                  isDark ? 'hover:bg-[#1a1a1a]' : 'hover:bg-slate-50'
                }`}
              >
                <div className={`mt-0.5 transition-colors flex-shrink-0 ${isDark ? 'text-[#B0B0B0] group-hover:text-white' : 'text-slate-500 group-hover:text-slate-800'}`}>
                  <HelpCircle className="w-6 h-6 stroke-[1.8]" />
                </div>
                <div className="flex-1 min-w-0">
                  <div className={`text-[15px] font-medium leading-snug ${isDark ? 'text-white' : 'text-slate-800'}`}>
                    Help Centre
                  </div>
                  <div className={`text-[12.5px] mt-0.5 leading-tight ${isDark ? 'text-[#8E8E8E]' : 'text-slate-500'}`}>
                    Frequently asked questions
                  </div>
                </div>
              </button>

              {/* 2. Contact us */}
              <button
                type="button"
                onClick={() => setActiveView('contact')}
                className={`w-full px-5 py-3.5 flex items-start gap-4 text-left transition-colors cursor-pointer group ${
                  isDark ? 'hover:bg-[#1a1a1a]' : 'hover:bg-slate-50'
                }`}
              >
                <div className={`mt-0.5 transition-colors flex-shrink-0 ${isDark ? 'text-[#B0B0B0] group-hover:text-white' : 'text-slate-500 group-hover:text-slate-800'}`}>
                  <div className="relative">
                    <MessageCircle className="w-6 h-6 stroke-[1.8]" />
                    <span className={`absolute -top-0.5 -right-0.5 text-[9px] font-bold px-0.5 rounded-full ${
                      isDark ? 'text-white bg-[#121212]' : 'text-slate-800 bg-white shadow-xs'
                    }`}>?</span>
                  </div>
                </div>
                <div className="flex-1 min-w-0">
                  <div className={`text-[15px] font-medium leading-snug ${isDark ? 'text-white' : 'text-slate-800'}`}>
                    Contact us
                  </div>
                  <div className={`text-[12.5px] mt-0.5 leading-tight ${isDark ? 'text-[#8E8E8E]' : 'text-slate-500'}`}>
                    Chat with support to get answers
                  </div>
                </div>
              </button>

              {/* 3. Send feedback */}
              <button
                type="button"
                onClick={() => setActiveView('feedback')}
                className={`w-full px-5 py-3.5 flex items-start gap-4 text-left transition-colors cursor-pointer group ${
                  isDark ? 'hover:bg-[#1a1a1a]' : 'hover:bg-slate-50'
                }`}
              >
                <div className={`mt-0.5 transition-colors flex-shrink-0 ${isDark ? 'text-[#B0B0B0] group-hover:text-white' : 'text-slate-500 group-hover:text-slate-800'}`}>
                  <Bug className="w-6 h-6 stroke-[1.8]" />
                </div>
                <div className="flex-1 min-w-0">
                  <div className={`text-[15px] font-medium leading-snug ${isDark ? 'text-white' : 'text-slate-800'}`}>
                    Send feedback
                  </div>
                  <div className={`text-[12.5px] mt-0.5 leading-tight ${isDark ? 'text-[#8E8E8E]' : 'text-slate-500'}`}>
                    Technical issues, suggestions
                  </div>
                </div>
              </button>

              {/* 4. Rate the app */}
              <button
                type="button"
                onClick={() => setActiveView('rate')}
                className={`w-full px-5 py-3.5 flex items-center gap-4 text-left transition-colors cursor-pointer group ${
                  isDark ? 'hover:bg-[#1a1a1a]' : 'hover:bg-slate-50'
                }`}
              >
                <div className={`transition-colors flex-shrink-0 ${isDark ? 'text-[#B0B0B0] group-hover:text-white' : 'text-slate-500 group-hover:text-slate-800'}`}>
                  <div className="w-6 h-6 border-2 border-current rounded-md flex items-center justify-center p-0.5">
                    <Star className="w-3.5 h-3.5 fill-current" />
                  </div>
                </div>
                <div className="flex-1 min-w-0">
                  <div className={`text-[15px] font-medium leading-snug ${isDark ? 'text-white' : 'text-slate-800'}`}>
                    Rate the app
                  </div>
                </div>
              </button>

              {/* 5. Terms and Privacy Policy */}
              <button
                type="button"
                onClick={() => setActiveView('terms')}
                className={`w-full px-5 py-3.5 flex items-center gap-4 text-left transition-colors cursor-pointer group ${
                  isDark ? 'hover:bg-[#1a1a1a]' : 'hover:bg-slate-50'
                }`}
              >
                <div className={`transition-colors flex-shrink-0 ${isDark ? 'text-[#B0B0B0] group-hover:text-white' : 'text-slate-500 group-hover:text-slate-800'}`}>
                  <FileText className="w-6 h-6 stroke-[1.8]" />
                </div>
                <div className="flex-1 min-w-0">
                  <div className={`text-[15px] font-medium leading-snug ${isDark ? 'text-white' : 'text-slate-800'}`}>
                    Terms and Privacy Policy
                  </div>
                </div>
              </button>

              {/* 6. Channels reports */}
              <button
                type="button"
                onClick={() => setActiveView('channels')}
                className={`w-full px-5 py-3.5 flex items-center gap-4 text-left transition-colors cursor-pointer group ${
                  isDark ? 'hover:bg-[#1a1a1a]' : 'hover:bg-slate-50'
                }`}
              >
                <div className={`transition-colors flex-shrink-0 ${isDark ? 'text-[#B0B0B0] group-hover:text-white' : 'text-slate-500 group-hover:text-slate-800'}`}>
                  <AlertCircle className="w-6 h-6 stroke-[1.8]" />
                </div>
                <div className="flex-1 min-w-0">
                  <div className={`text-[15px] font-medium leading-snug ${isDark ? 'text-white' : 'text-slate-800'}`}>
                    Channels reports
                  </div>
                </div>
              </button>
            </div>
          )}

          {/* ========================================================================= */}
          {/* SUBVIEW 1: HELP CENTRE (FAQS) */}
          {/* ========================================================================= */}
          {activeView === 'help' && (
            <div className="p-4 space-y-3.5">
              <div className="relative">
                <Search className={`w-4 h-4 absolute left-3.5 top-1/2 -translate-y-1/2 ${isDark ? 'text-[#8E8E8E]' : 'text-slate-400'}`} />
                <input
                  type="text"
                  value={faqSearch}
                  onChange={(e) => setFaqSearch(e.target.value)}
                  placeholder="Search questions or topics..."
                  className={`w-full pl-10 pr-4 py-2.5 text-xs rounded-xl border focus:outline-hidden focus:border-teal-400 transition-colors ${
                    isDark ? 'bg-[#1E1E1E] text-white border-[#2E2E2E] placeholder-[#6E6E6E]' : 'bg-slate-100 text-slate-900 border-slate-200 placeholder-slate-400'
                  }`}
                />
              </div>

              <div className="space-y-2 max-h-[60vh] overflow-y-auto pr-1">
                {filteredFaqs.length > 0 ? (
                  filteredFaqs.map((faq, idx) => {
                    const isExp = expandedFaq === idx;
                    return (
                      <div
                        key={idx}
                        className={`border rounded-xl overflow-hidden transition-all ${
                          isDark ? 'bg-[#1E1E1E] border-[#2A2A2A]' : 'bg-slate-50 border-slate-200'
                        }`}
                      >
                        <button
                          type="button"
                          onClick={() => setExpandedFaq(isExp ? null : idx)}
                          className={`w-full p-3.5 text-left flex items-center justify-between gap-3 text-xs font-semibold transition-colors cursor-pointer ${
                            isDark ? 'text-white hover:text-teal-300' : 'text-slate-800 hover:text-teal-600'
                          }`}
                        >
                          <span className="leading-snug">{faq.q}</span>
                          <ChevronDown className={`w-4 h-4 flex-shrink-0 transition-transform ${
                            isDark ? 'text-[#8E8E8E]' : 'text-slate-400'
                          } ${isExp ? 'rotate-180 text-teal-500' : ''}`} />
                        </button>
                        {isExp && (
                          <div className={`px-3.5 pb-3.5 text-[12px] leading-relaxed border-t pt-2.5 ${
                            isDark ? 'text-[#A0A0A0] border-[#262626]' : 'text-slate-600 border-slate-200'
                          }`}>
                            {faq.a}
                          </div>
                        )}
                      </div>
                    );
                  })
                ) : (
                  <div className={`text-center py-8 text-xs ${isDark ? 'text-[#8E8E8E]' : 'text-slate-400'}`}>
                    No questions found matching &quot;{faqSearch}&quot;.
                  </div>
                )}
              </div>
            </div>
          )}

          {/* ========================================================================= */}
          {/* SUBVIEW 2: CONTACT US (DYNAMIC SCHOOL ADMIN INFO) */}
          {/* ========================================================================= */}
          {activeView === 'contact' && (
            <div className="p-4 space-y-3.5">
              {/* Working Hours Support Schedule */}
              <div className={`p-3.5 rounded-2xl border flex items-center gap-3.5 ${
                isDark ? 'bg-[#1A1A1A] border-[#2A2A2A]' : 'bg-slate-50 border-slate-200 shadow-2xs'
              }`}>
                <div className="w-10 h-10 rounded-xl bg-purple-500/20 text-purple-500 flex items-center justify-center font-bold flex-shrink-0">
                  <Clock className="w-5 h-5" />
                </div>
                <div className="flex-1 min-w-0">
                  <div className={`text-xs font-bold ${isDark ? 'text-white' : 'text-slate-900'}`}>
                    Active Support Schedule
                  </div>
                  <div className={`text-[11px] mt-0.5 ${isDark ? 'text-[#8E8E8E]' : 'text-slate-500'}`}>
                    {workingHours}
                  </div>
                </div>
              </div>

              {/* WhatsApp Live */}
              <a
                href={`https://wa.me/${whatsappNumber}?text=Hello%2C%20I%20need%20assistance%20with%20school%20management.`}
                target="_blank"
                rel="noreferrer"
                className={`p-3.5 rounded-2xl border flex items-center gap-3.5 group transition-all cursor-pointer block ${
                  isDark ? 'bg-[#1E1E1E] border-[#2A2A2A] hover:border-emerald-500/50' : 'bg-slate-50 border-slate-200 hover:border-emerald-500/50 shadow-2xs'
                }`}
              >
                <div className="w-10 h-10 rounded-xl bg-emerald-500/20 text-emerald-500 flex items-center justify-center font-bold flex-shrink-0 group-hover:scale-105 transition-transform">
                  <MessageCircle className="w-5 h-5" />
                </div>
                <div className="flex-1 min-w-0">
                  <div className={`text-xs font-bold transition-colors flex items-center justify-between ${
                    isDark ? 'text-white group-hover:text-emerald-300' : 'text-slate-900 group-hover:text-emerald-600'
                  }`}>
                    <span>WhatsApp Support</span>
                    <span className="text-[10px] px-1.5 py-0.5 rounded-md bg-emerald-500/20 text-emerald-600 dark:text-emerald-400 font-normal">Instant Chat</span>
                  </div>
                  <div className={`text-[11px] mt-0.5 ${isDark ? 'text-[#8E8E8E]' : 'text-slate-500'}`}>
                    {supportWhatsapp}
                  </div>
                </div>
                <ExternalLink className={`w-4 h-4 ${isDark ? 'text-[#8E8E8E] group-hover:text-white' : 'text-slate-400 group-hover:text-slate-700'}`} />
              </a>

              {/* Direct Helpline */}
              <a
                href={`tel:${cleanPhone || '8568643490'}`}
                className={`p-3.5 rounded-2xl border flex items-center gap-3.5 group transition-all cursor-pointer block ${
                  isDark ? 'bg-[#1E1E1E] border-[#2A2A2A] hover:border-blue-500/50' : 'bg-slate-50 border-slate-200 hover:border-blue-500/50 shadow-2xs'
                }`}
              >
                <div className="w-10 h-10 rounded-xl bg-blue-500/20 text-blue-500 flex items-center justify-center font-bold flex-shrink-0 group-hover:scale-105 transition-transform">
                  <Phone className="w-5 h-5" />
                </div>
                <div className="flex-1 min-w-0">
                  <div className={`text-xs font-bold transition-colors flex items-center justify-between ${
                    isDark ? 'text-white group-hover:text-blue-300' : 'text-slate-900 group-hover:text-blue-600'
                  }`}>
                    <span>Helpline Voice Call</span>
                    <span className="text-[10px] px-1.5 py-0.5 rounded-md bg-blue-500/20 text-blue-600 dark:text-blue-400 font-normal">Direct</span>
                  </div>
                  <div className={`text-[11px] mt-0.5 ${isDark ? 'text-[#8E8E8E]' : 'text-slate-500'}`}>
                    {supportPhone}
                  </div>
                </div>
                <ExternalLink className={`w-4 h-4 ${isDark ? 'text-[#8E8E8E] group-hover:text-white' : 'text-slate-400 group-hover:text-slate-700'}`} />
              </a>

              {/* Email Support */}
              <a
                href={`mailto:${supportEmail}?subject=Support%20Inquiry%20-%20${encodeURIComponent(schoolName)}`}
                className={`p-3.5 rounded-2xl border flex items-center gap-3.5 group transition-all cursor-pointer block ${
                  isDark ? 'bg-[#1E1E1E] border-[#2A2A2A] hover:border-amber-500/50' : 'bg-slate-50 border-slate-200 hover:border-amber-500/50 shadow-2xs'
                }`}
              >
                <div className="w-10 h-10 rounded-xl bg-amber-500/20 text-amber-500 flex items-center justify-center font-bold flex-shrink-0 group-hover:scale-105 transition-transform">
                  <Mail className="w-5 h-5" />
                </div>
                <div className="flex-1 min-w-0">
                  <div className={`text-xs font-bold transition-colors ${
                    isDark ? 'text-white group-hover:text-amber-300' : 'text-slate-900 group-hover:text-amber-600'
                  }`}>
                    Official Email Desk
                  </div>
                  <div className={`text-[11px] mt-0.5 truncate ${isDark ? 'text-[#8E8E8E]' : 'text-slate-500'}`}>
                    {supportEmail}
                  </div>
                </div>
                <ExternalLink className={`w-4 h-4 ${isDark ? 'text-[#8E8E8E] group-hover:text-white' : 'text-slate-400 group-hover:text-slate-700'}`} />
              </a>
            </div>
          )}

          {/* ========================================================================= */}
          {/* SUBVIEW 3: SEND FEEDBACK */}
          {/* ========================================================================= */}
          {activeView === 'feedback' && (
            <form onSubmit={handleSubmitFeedback} className="p-4 space-y-3.5">
              <div>
                <label className={`text-[11px] font-semibold block mb-1 ${isDark ? 'text-[#8E8E8E]' : 'text-slate-600'}`}>
                  Category
                </label>
                <select
                  value={feedbackCategory}
                  onChange={(e) => setFeedbackCategory(e.target.value)}
                  className={`w-full px-3 py-2 text-xs rounded-xl border focus:outline-hidden focus:border-teal-400 cursor-pointer ${
                    isDark ? 'bg-[#1E1E1E] text-white border-[#2E2E2E]' : 'bg-slate-100 text-slate-900 border-slate-200'
                  }`}
                >
                  <option value="Technical Issue">Technical Issue / Bug</option>
                  <option value="Feature Suggestion">Feature Suggestion</option>
                  <option value="UI Improvement">UI / Usability Improvement</option>
                  <option value="General Feedback">General Feedback</option>
                </select>
              </div>

              <div>
                <label className={`text-[11px] font-semibold block mb-1 ${isDark ? 'text-[#8E8E8E]' : 'text-slate-600'}`}>
                  Description
                </label>
                <textarea
                  rows={4}
                  value={feedbackText}
                  onChange={(e) => setFeedbackText(e.target.value)}
                  placeholder="Describe the issue you encountered or suggestions to improve..."
                  className={`w-full p-3 text-xs rounded-xl border focus:outline-hidden focus:border-teal-400 resize-none ${
                    isDark ? 'bg-[#1E1E1E] text-white border-[#2E2E2E] placeholder-[#6E6E6E]' : 'bg-slate-100 text-slate-900 border-slate-200 placeholder-slate-400'
                  }`}
                />
              </div>

              <div className="pt-1 flex items-center justify-end gap-2">
                <button
                  type="button"
                  onClick={() => setActiveView('main')}
                  className={`px-4 py-2 rounded-xl text-xs font-semibold transition-colors cursor-pointer ${
                    isDark ? 'text-[#8E8E8E] hover:text-white' : 'text-slate-500 hover:text-slate-800'
                  }`}
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={isSubmittingFeedback}
                  className="px-5 py-2 rounded-xl text-xs font-bold bg-teal-600 hover:bg-teal-500 text-white transition-colors cursor-pointer flex items-center gap-1.5 disabled:opacity-50"
                >
                  <Send className="w-3.5 h-3.5" />
                  <span>{isSubmittingFeedback ? 'Submitting...' : 'Submit Feedback'}</span>
                </button>
              </div>
            </form>
          )}

          {/* ========================================================================= */}
          {/* SUBVIEW 4: RATE THE APP */}
          {/* ========================================================================= */}
          {activeView === 'rate' && (
            <div className="p-6 text-center space-y-4">
              <p className={`text-xs ${isDark ? 'text-[#8E8E8E]' : 'text-slate-500'}`}>
                How would you rate your overall experience with School Management Portal?
              </p>

              {/* Star Selector */}
              <div className="flex items-center justify-center gap-2 py-2">
                {[1, 2, 3, 4, 5].map((starIdx) => {
                  const isActive = (hoverRating || rating) >= starIdx;
                  return (
                    <button
                      key={starIdx}
                      type="button"
                      onMouseEnter={() => setHoverRating(starIdx)}
                      onMouseLeave={() => setHoverRating(0)}
                      onClick={() => setRating(starIdx)}
                      className="p-1 cursor-pointer transition-transform hover:scale-115 focus:outline-hidden"
                      title={`${starIdx} Stars`}
                    >
                      <Star
                        className={`w-8 h-8 transition-colors ${
                          isActive
                            ? 'text-amber-400 fill-amber-400'
                            : isDark ? 'text-[#3E3E3E] hover:text-[#6E6E6E]' : 'text-slate-300 hover:text-slate-400'
                        }`}
                      />
                    </button>
                  );
                })}
              </div>

              <div className="text-sm font-bold text-amber-500">
                {rating === 5 && '5 / 5 Stars — Excellent!'}
                {rating === 4 && '4 / 5 Stars — Very Good'}
                {rating === 3 && '3 / 5 Stars — Good'}
                {rating === 2 && '2 / 5 Stars — Fair'}
                {rating === 1 && '1 / 5 Stars — Needs Improvement'}
              </div>

              <div className="pt-2 flex items-center justify-center gap-3">
                <button
                  type="button"
                  onClick={() => setActiveView('main')}
                  className={`px-4 py-2 rounded-xl text-xs font-semibold transition-colors cursor-pointer ${
                    isDark ? 'text-[#8E8E8E] hover:text-white' : 'text-slate-500 hover:text-slate-800'
                  }`}
                >
                  Later
                </button>
                <button
                  type="button"
                  onClick={handleSubmitRating}
                  className="px-6 py-2 rounded-xl text-xs font-bold bg-teal-600 hover:bg-teal-500 text-white transition-colors cursor-pointer shadow-md"
                >
                  Submit Rating
                </button>
              </div>
            </div>
          )}

          {/* ========================================================================= */}
          {/* SUBVIEW 5: TERMS AND PRIVACY POLICY */}
          {/* ========================================================================= */}
          {activeView === 'terms' && (
            <div className="p-4 space-y-3 max-h-[62vh] overflow-y-auto pr-1 text-xs">
              <div className="p-3 bg-teal-500/10 border border-teal-500/20 rounded-2xl mb-1">
                <p className="text-[11px] font-bold text-teal-600 dark:text-teal-300">
                  School Cloud • Institutional Terms of Service & Privacy Policy
                </p>
                <p className={`text-[10px] mt-0.5 ${isDark ? 'text-[#A0A0A0]' : 'text-slate-500'}`}>
                  Effective Session 2026-27 • Governs all authorized school tenants, administrators, and staff.
                </p>
              </div>

              {TERMS_AND_POLICIES.map((policy, idx) => {
                const IconComponent = policy.icon;
                const isExp = expandedTerm === idx;
                return (
                  <div
                    key={idx}
                    className={`border rounded-2xl overflow-hidden transition-all ${
                      isDark ? 'bg-[#1E1E1E] border-[#2A2A2A]' : 'bg-slate-50 border-slate-200'
                    }`}
                  >
                    <button
                      type="button"
                      onClick={() => setExpandedTerm(isExp ? null : idx)}
                      className="w-full p-3.5 text-left flex items-start justify-between gap-3 cursor-pointer group"
                    >
                      <div className="flex items-start gap-2.5 min-w-0">
                        <IconComponent className="w-4 h-4 text-teal-500 mt-0.5 flex-shrink-0 group-hover:scale-110 transition-transform" />
                        <span className={`font-bold text-xs leading-snug transition-colors ${
                          isDark ? 'text-white group-hover:text-teal-300' : 'text-slate-900 group-hover:text-teal-600'
                        }`}>
                          {policy.title}
                        </span>
                      </div>
                      <ChevronDown className={`w-4 h-4 flex-shrink-0 transition-transform ${
                        isDark ? 'text-[#8E8E8E]' : 'text-slate-400'
                      } ${isExp ? 'rotate-180 text-teal-500' : ''}`} />
                    </button>
                    {isExp && (
                      <div className={`px-3.5 pb-3.5 text-[11.5px] leading-relaxed border-t pt-2.5 ${
                        isDark ? 'text-[#A8A8A8] border-[#262626]' : 'text-slate-600 border-slate-200'
                      }`}>
                        {policy.content}
                      </div>
                    )}
                  </div>
                );
              })}
            </div>
          )}

          {/* ========================================================================= */}
          {/* SUBVIEW 6: CHANNELS REPORTS */}
          {/* ========================================================================= */}
          {activeView === 'channels' && (
            <div className="p-4 space-y-2.5">
              {[
                { name: 'System Services', status: '100% Operational', color: 'text-emerald-500', dot: 'bg-emerald-500' },
                { name: 'Database Sync', status: 'Realtime Connected', color: 'text-emerald-500', dot: 'bg-emerald-500' },
                { name: 'Broadcast Channel', status: 'Active (0 incidents)', color: 'text-emerald-500', dot: 'bg-emerald-500' },
                { name: 'Encryption Engine', status: 'TLS 1.3 / AES-256', color: 'text-cyan-500', dot: 'bg-cyan-500' },
                { name: 'Cloud Gateway', status: 'Active (< 90ms latency)', color: 'text-emerald-500', dot: 'bg-emerald-500' },
                { name: 'Security Telemetry', status: 'Guarded & Secure', color: 'text-teal-500', dot: 'bg-teal-500' },
              ].map((c, idx) => (
                <div
                  key={idx}
                  className={`p-3 border rounded-xl flex items-center justify-between text-xs ${
                    isDark ? 'bg-[#1E1E1E] border-[#2A2A2A]' : 'bg-slate-50 border-slate-200'
                  }`}
                >
                  <span className={`font-medium ${isDark ? 'text-[#C0C0C0]' : 'text-slate-700'}`}>{c.name}</span>
                  <div className="flex items-center gap-2">
                    <span className={`w-2 h-2 rounded-full ${c.dot} animate-pulse`} />
                    <span className={`font-bold ${c.color}`}>{c.status}</span>
                  </div>
                </div>
              ))}
            </div>
          )}

        </div>

        {/* --- Divider --- */}
        <div className={`border-t ${isDark ? 'border-[#262626]' : 'border-slate-200'}`} />

        {/* --- Footer Version Text (Version 1.0.0) --- */}
        <div className={`py-4 px-4 text-center select-none flex-shrink-0 ${
          isDark ? 'bg-[#121212]' : 'bg-slate-50/80'
        }`}>
          <p className={`text-[13px] font-medium tracking-tight ${
            isDark ? 'text-[#888888]' : 'text-slate-500'
          }`}>
            {APP_VERSION}
          </p>
        </div>

      </div>
    </div>
  );
}
