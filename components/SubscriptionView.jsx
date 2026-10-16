'use client';

import React, { useState, useEffect } from 'react';
import { useSchoolStore, getActiveSchoolId } from '../lib/store';
import { db } from '../lib/firebase';
import { doc, getDoc, setDoc, serverTimestamp, onSnapshot } from 'firebase/firestore';
import {
  Sparkles, CheckCircle2, ShieldCheck, Zap, Crown,
  Headphones, ArrowRight, Check,
  QrCode, PhoneCall, MessageCircle,
  Star, KeyRound, AlertTriangle, Users
} from 'lucide-react';

export default function SubscriptionView() {
  const { settings, students, showToast, isSubscriptionEnabled, systemPlansConfig, updateSettings } = useSchoolStore();
  const [billingCycle, setBillingCycle] = useState('monthly'); // 'monthly' | 'yearly'
  const [selectedPlanModal, setSelectedPlanModal] = useState(null);
  const [isLicenseModalOpen, setIsLicenseModalOpen] = useState(false);
  const [licenseKeyInput, setLicenseKeyInput] = useState('');
  const [supportConfig, setSupportConfig] = useState(null);

  useEffect(() => {
    if (!db) return;
    try {
      const unsub = onSnapshot(doc(db, 'schoolDirectory', 'support_info'), (snap) => {
        if (snap.exists()) setSupportConfig(snap.data());
      });
      return () => unsub();
    } catch (_) {}
  }, []);

  const schoolName = settings.instituteName || settings.schoolName || 'My Institute';
  const currentSession = settings.currentSession || '2026-27';
  const activePlanId = isSubscriptionEnabled ? (settings.subscriptionPlan || 'free_trial') : 'pro_unlimited';
  const rawStudentLimit = !isSubscriptionEnabled ? 0 : (
    settings.studentLimit !== undefined ? Number(settings.studentLimit) :
    (settings.maxStudents !== undefined ? Number(settings.maxStudents) :
    (systemPlansConfig?.trialLimit ? Number(systemPlansConfig.trialLimit) : 10))
  );
  const isUnlimited = !isSubscriptionEnabled || rawStudentLimit <= 0 || rawStudentLimit >= 99999;
  const studentCount = (students || []).length;
  const capacityPercent = isUnlimited ? 0 : Math.min(100, Math.round((studentCount / rawStudentLimit) * 100));

  const plans = [
    {
      id: 'free_trial',
      name: 'Free Trial',
      badge: 'Test Drive',
      badgeStyle: 'bg-slate-100 text-slate-800 border border-slate-300',
      monthlyPrice: '₹0',
      yearlyPrice: '₹0',
      period: 'forever',
      studentLimit: systemPlansConfig?.trialLimit || 10,
      studentLimitLabel: `Max ${systemPlansConfig?.trialLimit || 10} Students`,
      description: `Test drive all 15+ features with up to ${systemPlansConfig?.trialLimit || 10} student records.`,
      features: [
        `Max ${systemPlansConfig?.trialLimit || 10} Student Admissions`,
        'Mark Entry Desk (Theory, Pract, Int)',
        'Marksheet PDF & Statement of Marks',
        'Fee Collection & Multi-Format Receipts',
        'Student ID Card & Admit Card Studio',
        'Daily Student & Teacher Attendance',
        'Android App & Web Real-time Sync',
      ],
      popular: false,
    },
    {
      id: 'starter',
      name: 'Starter Plan',
      badge: 'Affordable',
      badgeStyle: 'bg-blue-100 text-blue-800 border border-blue-300',
      monthlyPrice: systemPlansConfig?.starterMonthPrice ? `₹${systemPlansConfig.starterMonthPrice}` : '₹199',
      yearlyPrice: systemPlansConfig?.starterYearPrice ? `₹${systemPlansConfig.starterYearPrice}` : '₹1,790',
      period: billingCycle === 'monthly' ? '/ month' : '/ year',
      savings: billingCycle === 'yearly' ? 'Save 25%' : null,
      studentLimit: systemPlansConfig?.starterLimit || 50,
      studentLimitLabel: `Up to ${systemPlansConfig?.starterLimit || 50} Students`,
      description: 'Ideal for coaching institutes & small computer centers.',
      features: [
        `Up to ${systemPlansConfig?.starterLimit || 50} Student Admissions`,
        'Everything in Free Trial',
        'Class & Course Batch Management',
        'Automated Monthly Fee Dues Tracker',
        'WhatsApp Payment Reminders & Notices',
        'Offline Local DB + Cloud Backup',
        'Standard Email & WhatsApp Support',
      ],
      popular: false,
    },
    {
      id: 'standard',
      name: 'Standard School',
      badge: 'Most Popular',
      badgeStyle: 'bg-amber-100 text-amber-900 border border-amber-300',
      monthlyPrice: systemPlansConfig?.standardMonthPrice ? `₹${systemPlansConfig.standardMonthPrice}` : '₹399',
      yearlyPrice: systemPlansConfig?.standardYearPrice ? `₹${systemPlansConfig.standardYearPrice}` : '₹3,590',
      period: billingCycle === 'monthly' ? '/ month' : '/ year',
      savings: billingCycle === 'yearly' ? 'Save 25%' : null,
      studentLimit: systemPlansConfig?.standardLimit || 200,
      studentLimitLabel: `Up to ${systemPlansConfig?.standardLimit || 200} Students`,
      description: 'Recommended for primary & secondary schools.',
      features: [
        `Up to ${systemPlansConfig?.standardLimit || 200} Student Admissions`,
        'Everything in Starter Plan',
        'Official School Seal & Stamp Integration',
        'Admit Card & Exam Roll Sheet Generator',
        'Teacher Role & Permission Access Controls',
        'Timetable & Class Schedule Generator',
        'Priority Phone & WhatsApp Support',
      ],
      popular: true,
    },
    {
      id: 'pro_unlimited',
      name: 'Pro Unlimited',
      badge: 'Unlimited Growth',
      badgeStyle: 'bg-purple-100 text-purple-900 border border-purple-300',
      monthlyPrice: systemPlansConfig?.proMonthPrice ? `₹${systemPlansConfig.proMonthPrice}` : '₹699',
      yearlyPrice: systemPlansConfig?.proYearPrice ? `₹${systemPlansConfig.proYearPrice}` : '₹6,290',
      period: billingCycle === 'monthly' ? '/ month' : '/ year',
      savings: billingCycle === 'yearly' ? 'Save 25%' : null,
      studentLimit: 0,
      studentLimitLabel: 'Unlimited Students',
      description: 'Uncapped student enrollment for large institutions.',
      features: [
        'Unlimited Student Admissions (No Cap)',
        'Everything in Standard Plan',
        'Multi-Branch & Multi-Teacher Staff',
        'Automated Daily Cloud Backups',
        'Custom Marksheet Formats on Request',
        'VIP Helpline & Instant Remote Setup',
        'Guaranteed Zero Price Escalation',
      ],
      popular: false,
    },
  ];

  const handleOpenPlan = (plan) => {
    setSelectedPlanModal(plan);
  };

  const getActivePlanName = () => {
    if (!isSubscriptionEnabled) return 'Unlimited Access (Free)';
    const norm = (activePlanId || '').toLowerCase();
    if (norm.includes('starter')) return 'Starter Plan';
    if (norm.includes('standard')) return 'Standard School';
    if (norm.includes('pro')) return 'Pro Unlimited';
    if (norm.includes('trial')) return 'Free Trial';
    const found = plans.find(p => p.id === activePlanId);
    return found ? found.name : (settings.subscriptionPlanName || settings.subscriptionPlan || 'Active Plan');
  };

  const helplinePhone = supportConfig?.supportPhone || settings.mobile || settings.phone || '+91 8568643490';
  const cleanPhone = helplinePhone.replace(/[^0-9]/g, '');
  const helplineWhatsapp = supportConfig?.supportWhatsapp || helplinePhone;
  const cleanWhatsapp = helplineWhatsapp.replace(/[^0-9]/g, '');
  const fullWhatsapp = cleanWhatsapp.startsWith('91') ? cleanWhatsapp : (cleanWhatsapp.length === 10 ? `91${cleanWhatsapp}` : cleanWhatsapp);
  const upiId = supportConfig?.supportUpi || supportConfig?.upiId || `${cleanPhone || '8568643490'}@upi`;

  const handleWhatsAppContact = (planName) => {
    const promoNote = systemPlansConfig?.isOfferActive
      ? `\nCoupon Applied: ${systemPlansConfig.promoCode || 'OFFER'} (${systemPlansConfig.offerDiscount || 25}% Discount)`
      : '';
    const text = encodeURIComponent(
      `Hello Admin, I want to activate/upgrade the "${planName || 'Standard School'}" plan for ${schoolName}.${promoNote}\nSchool ID: ${settings.schoolId || 'N/A'}. Please guide me with payment details.`
    );
    window.open(`https://wa.me/${fullWhatsapp || '918568643490'}?text=${text}`, '_blank');
  };

  const handleActivateLicense = async () => {
    if (!licenseKeyInput.trim()) {
      showToast('Please enter your license activation key', 'error');
      return;
    }
    const cleanKey = licenseKeyInput.trim().toUpperCase();
    if (cleanKey.length < 5) {
      showToast('Invalid license key format.', 'error');
      return;
    }

    try {
      showToast('Verifying license key with database...', 'info', 2000);

      // 1. Check primary licenseKeys collection
      let docSnap = null;
      try {
        const snap = await getDoc(doc(db, 'licenseKeys', cleanKey));
        if (snap.exists()) docSnap = snap;
      } catch (_) {}

      // 2. Check schoolDirectory backup collection
      if (!docSnap || !docSnap.exists()) {
        try {
          const snap = await getDoc(doc(db, 'schoolDirectory', 'system_license_keys', 'keys', cleanKey));
          if (snap.exists()) docSnap = snap;
        } catch (_) {}
      }

      if (!docSnap || !docSnap.exists()) {
        showToast('Invalid License Key. Contact administrator for a valid key.', 'error');
        return;
      }

      const keyData = docSnap.data();
      if (keyData.status === 'used') {
        showToast('This License Key has already been redeemed by a school.', 'error');
        return;
      }

      // Valid active key!
      const planId = keyData.planId === 'pro' ? 'pro_unlimited' : keyData.planId;
      const planName = keyData.planName || 'Pro Unlimited';
      const studentLimit = keyData.maxStudents === -1 ? 0 : (keyData.maxStudents || 50);
      const maxStudents = keyData.maxStudents || -1;
      const activeSchool = getActiveSchoolId?.() || 'SCHOOL_001';

      await updateSettings?.({
        subscriptionPlan: planId,
        subscriptionPlanName: planName,
        studentLimit: studentLimit,
        maxStudents: maxStudents,
        subscriptionStatus: 'active',
      });

      // Mark key as redeemed
      const updatePayload = {
        status: 'used',
        usedBySchoolId: activeSchool,
        usedAt: serverTimestamp(),
      };

      try {
        await setDoc(doc(db, 'licenseKeys', cleanKey), updatePayload, { merge: true });
      } catch (_) {}
      try {
        await setDoc(doc(db, 'schoolDirectory', 'system_license_keys', 'keys', cleanKey), updatePayload, { merge: true });
      } catch (_) {}

      showToast(`✓ ${planName} activated successfully!`, 'success');
      setIsLicenseModalOpen(false);
      setLicenseKeyInput('');
    } catch (err) {
      showToast('Failed to activate license: ' + (err.message || 'Error'), 'error');
    }
  };

  return (
    <div className="space-y-6 max-w-7xl mx-auto pb-12 animate-in fade-in duration-200">
      {/* ─── Promotional Offer Banner (When Active in Super Admin) ─── */}
      {systemPlansConfig?.isOfferActive && (
        <div className="bg-gradient-to-r from-purple-900 via-indigo-900 to-slate-900 border border-amber-400/40 rounded-2xl p-4 sm:p-5 text-white flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4 shadow-lg animate-in slide-in-from-top-2 duration-300">
          <div className="flex items-center gap-3">
            <div className="p-2.5 rounded-xl bg-amber-400 text-purple-950 font-black shadow-md">
              <Zap className="w-5 h-5" />
            </div>
            <div>
              <div className="flex items-center gap-2">
                <span className="px-2 py-0.5 rounded text-[10px] font-black bg-amber-400 text-purple-950 uppercase tracking-wider">
                  Special Offer Active
                </span>
                <span className="text-xs text-amber-300 font-bold">
                  {systemPlansConfig.offerDiscount || 25}% Instant Discount
                </span>
              </div>
              <h4 className="text-sm font-bold text-white mt-0.5">
                {systemPlansConfig.offerBanner || 'Special Festival Offer on All Plans!'}
              </h4>
            </div>
          </div>
          {systemPlansConfig.promoCode && (
            <div className="flex items-center gap-2 bg-white/10 px-3 py-1.5 rounded-xl border border-white/20">
              <span className="text-xs text-slate-300">Use Coupon:</span>
              <code className="text-xs font-mono font-black text-amber-300 bg-black/40 px-2 py-0.5 rounded">
                {systemPlansConfig.promoCode}
              </code>
            </div>
          )}
        </div>
      )}

      {/* ─── Master Switch Status Notice ─── */}
      {!isSubscriptionEnabled && (
        <div className="bg-emerald-500/10 border-2 border-emerald-500/30 rounded-2xl p-5 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
          <div className="flex items-center gap-3">
            <div className="p-2.5 rounded-xl bg-emerald-500 text-white shadow-md">
              <Sparkles className="w-5 h-5" />
            </div>
            <div>
              <h4 className="text-sm font-black text-emerald-900 dark:text-emerald-200">
                Full Unrestricted Version Active (Master Subscription Switch OFF)
              </h4>
              <p className="text-xs text-emerald-700 dark:text-emerald-300">
                Subscription system is currently disabled by Super Admin. Your institution has 100% full access to all modules and unlimited student admissions without any charge.
              </p>
            </div>
          </div>
          <span className="shrink-0 px-3 py-1 rounded-full text-xs font-black bg-emerald-500 text-white shadow-sm">
            100% FREE UNRESTRICTED
          </span>
        </div>
      )}

      {/* ─── Top Header Banner ─── */}
      <div className="relative overflow-hidden rounded-3xl bg-gradient-to-r from-[#1f108e] via-[#281ab5] to-[#160b6a] p-6 sm:p-8 text-white shadow-xl">
        <div className="relative z-10 flex flex-col md:flex-row md:items-center justify-between gap-6">
          <div className="space-y-2">
            <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-white/15 text-white text-xs font-black backdrop-blur-md">
              <Crown className="w-3.5 h-3.5 text-amber-300" />
              <span>INSTITUTION SUBSCRIPTION & LICENSES</span>
            </div>
            <h1 className="text-2xl sm:text-3xl font-black tracking-tight text-white">
              Affordable School Management Plans
            </h1>
            <p className="text-sm text-white/85 max-w-2xl leading-relaxed">
              Transparent, student-friendly pricing starting at just ₹199/month.
              <strong className="text-amber-300 font-bold ml-1">
                Every single plan includes 100% full access to all 15+ features & modules.
              </strong>
            </p>
          </div>

          {/* Active Plan & Capacity Card */}
          <div className="bg-white/10 backdrop-blur-md border border-white/20 rounded-2xl p-4 sm:p-5 min-w-[300px] space-y-3">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2">
                <ShieldCheck className="w-5 h-5 text-emerald-300" />
                <span className="text-xs font-black uppercase tracking-wider text-emerald-300">
                  CURRENT: {getActivePlanName().toUpperCase()}
                </span>
              </div>
              <button
                onClick={() => setIsLicenseModalOpen(true)}
                className="text-[11px] font-bold text-amber-300 hover:text-white flex items-center gap-1 underline underline-offset-2 cursor-pointer"
              >
                <KeyRound className="w-3 h-3" />
                <span>Enter Key</span>
              </button>
            </div>

            <div className="space-y-1.5">
              <div className="flex items-center justify-between text-xs">
                <span className="text-white/80 flex items-center gap-1.5 font-medium">
                  <Users className="w-3.5 h-3.5" />
                  <span>Student Capacity</span>
                </span>
                <span className="font-black text-white">
                  {studentCount} / {isUnlimited ? '∞ Unlimited' : `${rawStudentLimit} Students`}
                </span>
              </div>
              <div className="w-full bg-white/20 rounded-full h-2.5 overflow-hidden">
                <div
                  className={`h-full rounded-full transition-all duration-300 ${
                    capacityPercent >= 90 ? 'bg-rose-400' : capacityPercent >= 70 ? 'bg-amber-400' : 'bg-emerald-400'
                  }`}
                  style={{ width: `${isUnlimited ? 15 : Math.max(5, capacityPercent)}%` }}
                />
              </div>
              {!isUnlimited && capacityPercent >= 80 && (
                <div className="text-[10px] text-amber-200 font-semibold flex items-center gap-1">
                  <AlertTriangle className="w-3 h-3" />
                  <span>Approaching plan capacity limit ({studentCount}/{rawStudentLimit})</span>
                </div>
              )}
            </div>

            <div className="text-[11px] text-white/70 pt-1 border-t border-white/10 flex items-center justify-between">
              <span className="font-semibold">{schoolName}</span>
              <span>Session: {currentSession}</span>
            </div>
          </div>
        </div>
      </div>

      {/* ─── Billing Cycle Toggle ─── */}
      <div className="flex flex-col sm:flex-row items-center justify-between gap-4 bg-white border border-slate-200 rounded-2xl p-4 shadow-sm">
        <div className="flex items-center gap-3">
          <div className="w-9 h-9 rounded-xl bg-blue-50 text-[#1f108e] flex items-center justify-center flex-shrink-0">
            <Zap className="w-4 h-4" />
          </div>
          <div>
            <h3 className="font-bold text-sm text-[#0b1c30]">Choose Billing Cycle</h3>
            <p className="text-xs text-slate-500">Switch to annual billing to save 25% on all plans.</p>
          </div>
        </div>

        <div className="flex flex-wrap items-center gap-3">
          <button
            onClick={() => setIsLicenseModalOpen(true)}
            className="px-3.5 py-2 rounded-xl bg-gradient-to-r from-amber-500 to-amber-600 hover:from-amber-600 hover:to-amber-700 text-slate-950 font-black text-xs shadow-sm flex items-center gap-1.5 cursor-pointer transition-all hover:scale-[1.02]"
          >
            <KeyRound className="w-3.5 h-3.5 text-slate-950" />
            <span>Redeem License Key</span>
          </button>

          <div className="flex items-center gap-2 bg-slate-100 p-1.5 rounded-xl border border-slate-200">
            <button
              onClick={() => setBillingCycle('monthly')}
              className={`px-4 py-1.5 rounded-lg text-xs font-bold transition-all cursor-pointer ${
                billingCycle === 'monthly'
                  ? 'bg-[#1f108e] text-white shadow-sm'
                  : 'text-slate-600 hover:text-slate-900'
              }`}
            >
              Monthly
            </button>
            <button
              onClick={() => setBillingCycle('yearly')}
              className={`px-4 py-1.5 rounded-lg text-xs font-bold transition-all flex items-center gap-1.5 cursor-pointer ${
                billingCycle === 'yearly'
                  ? 'bg-[#1f108e] text-white shadow-sm'
                  : 'text-slate-600 hover:text-slate-900'
              }`}
            >
              <span>Annual (12 Months)</span>
              <span className="px-1.5 py-0.5 rounded-full text-[9px] font-black bg-amber-400 text-slate-900">
                SAVE 25%
              </span>
            </button>
          </div>
        </div>
      </div>

      {/* ─── Subscription Plans Grid (4 Plans) ─── */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-5">
        {plans.map((p) => {
          const normActive = (activePlanId || '').toLowerCase();
          const isCurrentActive = isSubscriptionEnabled && (
            activePlanId === p.id ||
            (p.id === 'pro_unlimited' && normActive.includes('pro')) ||
            (p.id === 'free_trial' && (normActive.includes('trial') || normActive === 'free_trial')) ||
            (p.id === 'standard' && normActive.includes('standard')) ||
            (p.id === 'starter' && normActive.includes('starter'))
          );
          const displayPrice = billingCycle === 'monthly' ? p.monthlyPrice : p.yearlyPrice;

          return (
            <div
              key={p.id}
              className={`relative rounded-3xl bg-white border transition-all duration-200 flex flex-col ${
                p.popular
                  ? 'border-[#1f108e] ring-2 ring-[#1f108e]/20 shadow-xl lg:-translate-y-1'
                  : 'border-slate-200 shadow-sm hover:shadow-md hover:border-[#1f108e]/40'
              }`}
            >
              {p.popular && (
                <div className="absolute -top-3.5 left-1/2 -translate-x-1/2 px-3.5 py-1 rounded-full bg-[#1f108e] text-white text-[10px] font-black tracking-wide shadow-md flex items-center gap-1 z-10">
                  <Star className="w-3 h-3 fill-amber-300 text-amber-300" />
                  <span>RECOMMENDED</span>
                </div>
              )}

              <div className="p-5 border-b border-slate-100 space-y-3">
                {/* Badge & Student Limit Row */}
                <div className="flex items-center justify-between gap-2">
                  <span className={`text-[10px] font-black uppercase tracking-wider px-2.5 py-1 rounded-full ${p.badgeStyle}`}>
                    {p.badge}
                  </span>
                  <span className="text-[10px] font-bold text-[#1f108e] bg-blue-50 border border-blue-100 px-2 py-0.5 rounded-md">
                    {p.studentLimitLabel}
                  </span>
                </div>

                {/* Plan Name & Current Badge */}
                <div>
                  <div className="flex items-center justify-between">
                    <h3 className="text-lg font-black text-[#0b1c30] tracking-tight">
                      {p.name}
                    </h3>
                    {isCurrentActive && (
                      <span className="text-[9px] font-black uppercase px-2 py-0.5 rounded-md bg-emerald-600 text-white">
                        ACTIVE
                      </span>
                    )}
                  </div>
                  <p className="text-xs text-[#475569] mt-1 leading-snug font-medium min-h-[36px]">
                    {p.description}
                  </p>
                </div>

                {/* Price Display */}
                {systemPlansConfig?.isOfferActive && p.id !== 'free_trial' ? (
                  <div>
                    <div className="pt-1 flex items-baseline gap-1.5 flex-wrap">
                      <span className="text-sm line-through text-slate-400 font-bold">
                        {displayPrice}
                      </span>
                      <span className="text-3xl font-black text-purple-950 tracking-tight">
                        ₹{Math.max(0, Math.round(Number(displayPrice.replace(/[^0-9]/g, '')) * (1 - (Number(systemPlansConfig.offerDiscount) || 25) / 100)))}
                      </span>
                      <span className="text-xs font-bold text-slate-500">
                        {p.period}
                      </span>
                      <span className="px-1.5 py-0.5 rounded text-[10px] font-black bg-amber-400 text-purple-950">
                        {systemPlansConfig.offerDiscount || 25}% OFF
                      </span>
                    </div>
                    <div className="text-[11px] font-bold text-purple-700 mt-0.5">
                      Coupon {systemPlansConfig.promoCode || 'APPLIED'} applied
                    </div>
                  </div>
                ) : (
                  <>
                    <div className="pt-1 flex items-baseline gap-1.5">
                      <span className="text-3xl font-black text-[#0b1c30] tracking-tight">
                        {displayPrice}
                      </span>
                      <span className="text-xs font-bold text-slate-500">
                        {p.period}
                      </span>
                    </div>
                    {p.savings ? (
                      <div className="text-[11px] font-bold text-emerald-600">
                        {p.savings}
                      </div>
                    ) : (
                      <div className="text-[11px] font-bold text-slate-400">
                        100% Unlocked Features
                      </div>
                    )}
                  </>
                )}

                {/* Action Button */}
                <button
                  onClick={() => handleOpenPlan(p)}
                  className={`w-full py-2.5 rounded-xl text-xs font-black flex items-center justify-center gap-1.5 cursor-pointer transition-all shadow-sm active:scale-95 ${
                    isCurrentActive
                      ? 'bg-emerald-600 hover:bg-emerald-700 text-white'
                      : p.popular
                      ? 'bg-[#1f108e] hover:bg-[#150a66] text-white shadow-[#1f108e]/25'
                      : 'bg-slate-100 hover:bg-slate-200 text-[#0b1c30] border border-slate-200 hover:border-[#1f108e]/40'
                  }`}
                >
                  <span>
                    {isCurrentActive
                      ? 'Active Plan Details'
                      : p.id === 'free_trial'
                      ? 'Start Free Trial'
                      : 'Subscribe & Activate'}
                  </span>
                  <ArrowRight className="w-3.5 h-3.5" />
                </button>
              </div>

              {/* Plan Feature List */}
              <div className="p-5 flex-1 flex flex-col justify-between space-y-4">
                <div className="space-y-2.5 text-xs">
                  <div className="text-[10px] font-black uppercase tracking-wider text-slate-500">
                    Plan Features:
                  </div>
                  {p.features.map((feat, idx) => (
                    <div key={idx} className="flex items-start gap-2.5">
                      <CheckCircle2 className="w-4 h-4 text-emerald-600 flex-shrink-0 mt-0.5" />
                      <span className="text-xs text-[#1e293b] font-medium leading-snug">
                        {feat}
                      </span>
                    </div>
                  ))}
                </div>

                <div className="pt-3 border-t border-slate-100 flex items-center justify-between text-[11px] text-slate-500">
                  <span>Android + Web App</span>
                  <span className="font-bold text-emerald-600">All 15+ Modules</span>
                </div>
              </div>
            </div>
          );
        })}
      </div>

      {/* ─── Zero Lock Guarantee Callout ─── */}
      <div className="bg-gradient-to-r from-emerald-50 via-teal-50 to-blue-50 border border-emerald-200 rounded-2xl p-4 sm:p-5 shadow-sm flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div className="flex items-center gap-3.5">
          <div className="w-10 h-10 rounded-xl bg-emerald-600 text-white flex items-center justify-center flex-shrink-0 shadow-sm">
            <Zap className="w-5 h-5 text-amber-300" />
          </div>
          <div>
            <h3 className="font-extrabold text-sm text-[#0b1c30] flex items-center gap-2">
              <span>All 15+ Modules Included in Every Plan</span>
              <span className="text-[10px] px-2 py-0.5 rounded-full bg-emerald-600 text-white font-black">
                ZERO HIDDEN CHARGES
              </span>
            </h3>
            <p className="text-xs text-slate-600 mt-0.5 font-medium">
              Fees collection, marksheet generator, ID cards, admit cards, and attendance are included across all plans.
            </p>
          </div>
        </div>
        <div className="flex items-center gap-2">
          <button
            onClick={() => handleWhatsAppContact('General Inquiry')}
            className="px-4 py-2 rounded-xl bg-emerald-600 hover:bg-emerald-700 text-white text-xs font-bold flex items-center gap-2 shadow-sm transition-colors cursor-pointer"
          >
            <MessageCircle className="w-4 h-4" />
            <span>WhatsApp Helpline</span>
          </button>
        </div>
      </div>

      {/* ─── Feature Comparison Matrix Table ─── */}
      <div className="bg-white border border-slate-200 rounded-3xl p-6 shadow-sm space-y-4">
        <div>
          <h3 className="text-base font-black text-[#0b1c30]">Feature Comparison Matrix</h3>
          <p className="text-xs text-slate-500 mt-0.5">
            Compare student capacity and features across all available tiers.
          </p>
        </div>

        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs border-collapse">
            <thead>
              <tr className="bg-slate-50 border-b border-slate-200 text-slate-600 font-bold text-[10px] uppercase">
                <th className="py-3 px-4">Feature / Module</th>
                <th className="py-3 px-3 text-center">Free Trial</th>
                <th className="py-3 px-3 text-center">Starter (₹199)</th>
                <th className="py-3 px-3 text-center bg-blue-50 text-[#1f108e]">Standard (₹399)</th>
                <th className="py-3 px-3 text-center">Pro (₹699)</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100 text-[#0b1c30] font-medium">
              {[
                { title: 'Student Capacity Limit', free: '10 Students', start: '50 Students', std: '200 Students', pro: 'Unlimited (∞)' },
                { title: 'Student Admissions & Bio', free: '✓', start: '✓', std: '✓', pro: '✓' },
                { title: 'Monthly Fees & Receipts Studio', free: '✓', start: '✓', std: '✓', pro: '✓' },
                { title: 'Marks Entry & Marksheets PDF', free: '✓', start: '✓', std: '✓', pro: '✓' },
                { title: 'ID Cards & Admit Cards Studio', free: '✓', start: '✓', std: '✓', pro: '✓' },
                { title: 'Teacher Attendance & Log', free: '✓', start: '✓', std: '✓', pro: '✓' },
                { title: 'Class Timetable Generator', free: '✓', start: '✓', std: '✓', pro: '✓' },
                { title: 'WhatsApp Fee Reminder Alerts', free: '✓', start: '✓', std: '✓', pro: '✓' },
                { title: 'Android App Real-time Sync', free: '✓', start: '✓', std: '✓', pro: '✓' },
                { title: 'Dedicated Priority Helpline', free: 'Community', start: 'WhatsApp', std: 'Phone + Chat', pro: '24/7 VIP' },
              ].map((row, idx) => (
                <tr key={idx} className="hover:bg-slate-50/60 transition-colors">
                  <td className="py-3 px-4 font-bold text-[#1e293b]">{row.title}</td>
                  <td className="py-3 px-3 text-center font-semibold text-slate-600">{row.free}</td>
                  <td className="py-3 px-3 text-center font-semibold text-slate-600">{row.start}</td>
                  <td className="py-3 px-3 text-center font-black text-[#1f108e] bg-blue-50/50">{row.std}</td>
                  <td className="py-3 px-3 text-center font-bold text-emerald-600">{row.pro}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* ─── Direct UPI & Helpline Assistance Card ─── */}
      <div className="bg-slate-50 border border-slate-200 rounded-3xl p-6 flex flex-col sm:flex-row items-center justify-between gap-6">
        <div className="flex items-center gap-4">
          <div className="w-12 h-12 rounded-2xl bg-[#1f108e] text-white flex items-center justify-center flex-shrink-0 shadow-md">
            <Headphones className="w-6 h-6" />
          </div>
          <div>
            <h4 className="font-extrabold text-sm text-[#0b1c30]">Need Custom Billing or Institution Invoice?</h4>
            <p className="text-xs text-slate-600 mt-0.5">
              Contact our direct merchant desk for GST invoice, official quotation, or custom school licenses.
            </p>
          </div>
        </div>

        <div className="flex items-center gap-3">
          <a
            href={`tel:${cleanPhone || '8568643490'}`}
            className="px-4 py-2.5 rounded-xl bg-white hover:bg-slate-100 text-[#0b1c30] border border-slate-300 text-xs font-bold flex items-center gap-2 cursor-pointer transition-colors shadow-xs"
          >
            <PhoneCall className="w-3.5 h-3.5 text-[#1f108e]" />
            <span>Call: {helplinePhone}</span>
          </a>
          <button
            onClick={() => handleWhatsAppContact('Quick Inquiry')}
            className="px-4 py-2.5 rounded-xl bg-emerald-600 hover:bg-emerald-700 text-white text-xs font-bold flex items-center gap-2 cursor-pointer transition-colors shadow-xs"
          >
            <MessageCircle className="w-3.5 h-3.5" />
            <span>Chat on WhatsApp</span>
          </button>
        </div>
      </div>

      {/* ─── Plan Activation / Upgrade Modal ─── */}
      {selectedPlanModal && (
        <div className="fixed inset-0 z-50 bg-black/60 backdrop-blur-xs flex items-center justify-center p-4 animate-in fade-in duration-150">
          <div className="bg-white border border-slate-200 rounded-3xl max-w-md w-full p-6 shadow-2xl space-y-5">
            <div className="flex items-center justify-between border-b border-slate-100 pb-3">
              <div className="flex items-center gap-2">
                <Crown className="w-5 h-5 text-amber-500" />
                <h3 className="font-extrabold text-base text-[#0b1c30]">
                  {selectedPlanModal.id === 'free_trial' ? 'Free Trial Details' : 'Subscribe to Plan'}
                </h3>
              </div>
              <button
                onClick={() => setSelectedPlanModal(null)}
                className="p-1 rounded-lg hover:bg-slate-100 text-slate-400 hover:text-slate-700 cursor-pointer text-sm font-bold"
              >
                ✕
              </button>
            </div>

            <div className="p-4 rounded-2xl bg-slate-50 border border-slate-200 space-y-2.5">
              <div className="flex items-center justify-between">
                <span className="text-xs text-slate-500 font-bold">Selected Plan:</span>
                <span className="text-sm font-black text-[#1f108e]">{selectedPlanModal.name}</span>
              </div>
              <div className="flex items-center justify-between">
                <span className="text-xs text-slate-500 font-bold">Price ({billingCycle}):</span>
                <span className="text-lg font-black text-[#0b1c30]">
                  {billingCycle === 'monthly' ? selectedPlanModal.monthlyPrice : selectedPlanModal.yearlyPrice}
                </span>
              </div>
              <div className="flex items-center justify-between">
                <span className="text-xs text-slate-500 font-bold">Student Capacity:</span>
                <span className="text-xs font-black text-emerald-700 bg-emerald-100 px-2 py-0.5 rounded-md">
                  {selectedPlanModal.studentLimitLabel}
                </span>
              </div>
              <div className="flex items-center justify-between">
                <span className="text-xs text-slate-500 font-bold">School Name:</span>
                <span className="text-xs font-bold text-[#0b1c30] truncate max-w-[200px]">{schoolName}</span>
              </div>
            </div>

            {selectedPlanModal.id !== 'free_trial' && (
              <div className="p-4 rounded-2xl bg-emerald-50 border border-emerald-200 text-xs space-y-2">
                <div className="font-black text-emerald-900 flex items-center gap-1.5">
                  <QrCode className="w-4 h-4 text-emerald-600" />
                  <span>Direct UPI Transfer (0% Gateway Charges):</span>
                </div>
                <p className="text-[11px] text-slate-600 leading-relaxed font-medium">
                  UPI ID: <strong className="text-slate-900 font-mono font-bold">{upiId}</strong> or pay using PhonePe / Google Pay / Paytm, then send the payment screenshot on WhatsApp.
                </p>
              </div>
            )}

            <div className="flex items-center justify-end gap-3 pt-2">
              <button
                onClick={() => setSelectedPlanModal(null)}
                className="px-4 py-2 rounded-xl text-xs font-bold text-slate-600 hover:bg-slate-100 cursor-pointer transition-colors"
              >
                Close
              </button>
              {selectedPlanModal.id === 'free_trial' ? (
                <button
                  onClick={() => {
                    showToast('Free Trial is active with 10 students limit!', 'info');
                    setSelectedPlanModal(null);
                  }}
                  className="px-5 py-2.5 rounded-xl bg-slate-700 hover:bg-slate-800 text-white text-xs font-black shadow-md cursor-pointer transition-all"
                >
                  Trial Active
                </button>
              ) : (
                <button
                  onClick={() => {
                    handleWhatsAppContact(selectedPlanModal.name);
                    setSelectedPlanModal(null);
                  }}
                  className="px-5 py-2.5 rounded-xl bg-emerald-600 hover:bg-emerald-700 text-white text-xs font-black shadow-md cursor-pointer transition-all flex items-center gap-1.5"
                >
                  <MessageCircle className="w-3.5 h-3.5" />
                  <span>Activate via WhatsApp</span>
                </button>
              )}
            </div>
          </div>
        </div>
      )}

      {/* ─── Enter License Key Modal ─── */}
      {isLicenseModalOpen && (
        <div className="fixed inset-0 z-50 bg-black/60 backdrop-blur-xs flex items-center justify-center p-4 animate-in fade-in duration-150">
          <div className="bg-white border border-slate-200 rounded-3xl max-w-md w-full p-6 shadow-2xl space-y-5">
            <div className="flex items-center justify-between border-b border-slate-100 pb-3">
              <div className="flex items-center gap-2">
                <KeyRound className="w-5 h-5 text-[#1f108e]" />
                <h3 className="font-extrabold text-base text-[#0b1c30]">Activate License Key</h3>
              </div>
              <button
                onClick={() => setIsLicenseModalOpen(false)}
                className="p-1 rounded-lg hover:bg-slate-100 text-slate-400 hover:text-slate-700 cursor-pointer"
              >
                ✕
              </button>
            </div>

            <p className="text-xs text-slate-600">
              If you received an offline license activation code or institution key from admin, enter it below to activate your plan immediately.
            </p>

            <div className="space-y-1.5">
              <label className="text-[11px] font-bold text-slate-500 uppercase">License Key</label>
              <input
                type="text"
                placeholder="e.g. SCH-PRO-8492-2026"
                value={licenseKeyInput}
                onChange={(e) => setLicenseKeyInput(e.target.value)}
                className="w-full px-3.5 py-2.5 rounded-xl border border-slate-200 bg-slate-50 font-mono text-sm uppercase tracking-wider text-slate-900 focus:outline-hidden focus:border-[#1f108e] focus:bg-white"
              />
            </div>

            <div className="flex items-center justify-end gap-3 pt-2">
              <button
                onClick={() => setIsLicenseModalOpen(false)}
                className="px-4 py-2 rounded-xl text-xs font-bold text-slate-600 hover:bg-slate-100 cursor-pointer transition-colors"
              >
                Cancel
              </button>
              <button
                onClick={handleActivateLicense}
                className="px-5 py-2.5 rounded-xl bg-[#1f108e] hover:bg-[#150a66] text-white text-xs font-black shadow-md cursor-pointer transition-all"
              >
                Verify & Activate
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
