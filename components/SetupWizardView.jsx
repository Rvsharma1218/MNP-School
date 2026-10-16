'use client';

import React, { useState } from 'react';
import { useSchoolStore } from '../lib/store';
import { Building2, Sparkles, Check, School, UploadCloud, ArrowRight, ArrowLeft } from 'lucide-react';

export default function SetupWizardView() {
  const { settings, currentUser, updateSettings, navigate } = useSchoolStore();
  const [step, setStep] = useState(1);
  const [formData, setFormData] = useState({
    instituteName: currentUser?.instituteName || (settings.instituteName !== 'Mission Navodaya Public School' ? settings.instituteName : '') || '',
    instituteType: 'School',
    address: (settings.address !== 'Mora Mairi, Bhagwaanpur, Siwan, Bihar 841507' ? settings.address : '') || '',
    mobile: currentUser?.mobile || (settings.mobile !== '9876543210' ? settings.mobile : '') || '',
    email: currentUser?.email || (settings.email !== 'contact@school.edu.in' ? settings.email : '') || '',
    currentSession: settings.currentSession || '2026-27'
  });

  const handleNext = (e) => {
    e.preventDefault();
    if (step < 2) {
      setStep(prev => prev + 1);
    } else {
      updateSettings({
        ...formData,
        isSetupComplete: true
      });
      setStep(3);
    }
  };

  return (
    <div className="min-h-screen bg-[#f8f9ff] text-[#0b1c30] flex flex-col items-center justify-center p-4 md:p-8 font-sans antialiased">
      
      {/* ── Brand Header ── */}
      <div className="text-center mb-8 space-y-2">
        <div className="w-14 h-14 rounded-2xl bg-gradient-to-br from-[#1f108e] to-[#0f0069] text-white flex items-center justify-center mx-auto shadow-lg">
          <School className="w-7 h-7" />
        </div>
        <h1 className="text-2xl lg:text-3xl font-black text-[#1f108e] tracking-tight">Smart School Setup Wizard</h1>
        <p className="text-xs text-[#464553]">Configure your institution profile to activate your cloud dashboard.</p>
      </div>

      {/* ── Main Wizard Container Card ── */}
      <div className="w-full max-w-2xl bg-white border border-[#c8c4d5]/50 p-6 md:p-10 rounded-3xl shadow-xl space-y-8">
        
        {/* Horizontal Progress Timeline */}
        <div className="flex items-center justify-between max-w-md mx-auto w-full relative">
          <div className="absolute left-6 right-6 top-[15px] h-1 bg-[#dce9ff] -z-0 rounded-full" />
          <div
            className="absolute left-6 top-[15px] h-1 bg-[#316bf3] -z-0 rounded-full transition-all duration-500"
            style={{ width: step === 1 ? '0%' : step === 2 ? '50%' : '100%' }}
          />

          {/* Step 1 */}
          <div className="flex flex-col items-center gap-1.5 relative z-10">
            <div className={`w-8 h-8 rounded-full flex items-center justify-center font-black text-xs transition-all shadow-sm ${
              step >= 1 ? 'bg-[#316bf3] text-white ring-4 ring-[#dce9ff]' : 'bg-[#dce9ff] text-[#777584]'
            }`}>
              1
            </div>
            <span className={`text-[11px] font-bold ${step >= 1 ? 'text-[#1f108e]' : 'text-[#777584]'}`}>Institute Info</span>
          </div>

          {/* Step 2 */}
          <div className="flex flex-col items-center gap-1.5 relative z-10">
            <div className={`w-8 h-8 rounded-full flex items-center justify-center font-black text-xs transition-all shadow-sm ${
              step >= 2 ? 'bg-[#316bf3] text-white ring-4 ring-[#dce9ff]' : 'bg-[#eff4ff] text-[#777584]'
            }`}>
              2
            </div>
            <span className={`text-[11px] font-bold ${step >= 2 ? 'text-[#1f108e]' : 'text-[#777584]'}`}>Academic Session</span>
          </div>

          {/* Step 3 */}
          <div className="flex flex-col items-center gap-1.5 relative z-10">
            <div className={`w-8 h-8 rounded-full flex items-center justify-center font-black text-xs transition-all shadow-sm ${
              step >= 3 ? 'bg-emerald-600 text-white ring-4 ring-emerald-100' : 'bg-[#eff4ff] text-[#777584]'
            }`}>
              3
            </div>
            <span className={`text-[11px] font-bold ${step >= 3 ? 'text-emerald-700' : 'text-[#777584]'}`}>Complete</span>
          </div>
        </div>

        {/* Step Forms */}
        <form onSubmit={handleNext} className="space-y-6">
          
          {step === 1 && (
            <div className="space-y-4 animate-in fade-in duration-300">
              <div className="border-b border-[#c8c4d5]/40 pb-3">
                <h3 className="font-bold text-base text-[#0b1c30] flex items-center gap-2">
                  <Building2 className="w-5 h-5 text-[#0051d5]" />
                  <span>Basic Institution Information</span>
                </h3>
                <p className="text-xs text-[#464553] mt-0.5">Enter your school or coaching center branding credentials.</p>
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div className="sm:col-span-2">
                  <label className="block text-xs font-bold text-[#0b1c30] mb-1.5">Institute / School Name *</label>
                  <input
                    type="text"
                    required
                    value={formData.instituteName}
                    onChange={(e) => setFormData({ ...formData, instituteName: e.target.value })}
                    placeholder="e.g. St. Xavier International Academy"
                    className="w-full px-4 py-2.5 rounded-xl bg-[#eff4ff] border border-[#c8c4d5]/50 text-xs font-medium text-[#0b1c30] focus:outline-none focus:ring-2 focus:ring-[#1f108e]/30 focus:border-[#1f108e] transition-all"
                  />
                </div>

                <div>
                  <label className="block text-xs font-bold text-[#0b1c30] mb-1.5">Institute Type *</label>
                  <select
                    value={formData.instituteType}
                    onChange={(e) => setFormData({ ...formData, instituteType: e.target.value })}
                    className="w-full px-4 py-2.5 rounded-xl bg-[#eff4ff] border border-[#c8c4d5]/50 text-xs font-bold text-[#0b1c30] focus:outline-none cursor-pointer"
                  >
                    <option value="School">School (K-12)</option>
                    <option value="Coaching Institute">Coaching Institute</option>
                    <option value="Computer Institute">Computer Training Institute</option>
                    <option value="Other">Other Educational Academy</option>
                  </select>
                </div>

                <div>
                  <label className="block text-xs font-bold text-[#0b1c30] mb-1.5">Contact Phone Number *</label>
                  <input
                    type="tel"
                    required
                    value={formData.mobile}
                    onChange={(e) => setFormData({ ...formData, mobile: e.target.value })}
                    placeholder="+91 98765 43210"
                    className="w-full px-4 py-2.5 rounded-xl bg-[#eff4ff] border border-[#c8c4d5]/50 text-xs font-medium text-[#0b1c30] focus:outline-none focus:ring-2 focus:ring-[#1f108e]/30"
                  />
                </div>

                <div className="sm:col-span-2">
                  <label className="block text-xs font-bold text-[#0b1c30] mb-1.5">Official Email Address *</label>
                  <input
                    type="email"
                    required
                    value={formData.email}
                    onChange={(e) => setFormData({ ...formData, email: e.target.value })}
                    placeholder="contact@institution.edu"
                    className="w-full px-4 py-2.5 rounded-xl bg-[#eff4ff] border border-[#c8c4d5]/50 text-xs font-medium text-[#0b1c30] focus:outline-none focus:ring-2 focus:ring-[#1f108e]/30"
                  />
                </div>

                <div className="sm:col-span-2">
                  <label className="block text-xs font-bold text-[#0b1c30] mb-1.5">Campus Address</label>
                  <textarea
                    rows={2}
                    value={formData.address}
                    onChange={(e) => setFormData({ ...formData, address: e.target.value })}
                    placeholder="124 Academic Enclave, City, State"
                    className="w-full px-4 py-2.5 rounded-xl bg-[#eff4ff] border border-[#c8c4d5]/50 text-xs font-medium text-[#0b1c30] focus:outline-none focus:ring-2 focus:ring-[#1f108e]/30 resize-none"
                  />
                </div>
              </div>

              <div className="flex justify-end pt-4 border-t border-[#c8c4d5]/30">
                <button
                  type="submit"
                  className="px-6 py-3 rounded-xl bg-[#1f108e] hover:bg-[#0f0069] text-white font-bold text-xs shadow-md transition-all flex items-center gap-2 cursor-pointer"
                >
                  <span>Save & Continue</span>
                  <ArrowRight className="w-4 h-4" />
                </button>
              </div>
            </div>
          )}

          {step === 2 && (
            <div className="space-y-4 animate-in fade-in duration-300">
              <div className="border-b border-[#c8c4d5]/40 pb-3">
                <h3 className="font-bold text-base text-[#0b1c30] flex items-center gap-2">
                  <Sparkles className="w-5 h-5 text-amber-500" />
                  <span>Academic Session Period</span>
                </h3>
                <p className="text-xs text-[#464553] mt-0.5">Configure active admission session tags and invoice batches.</p>
              </div>

              <div className="max-w-md">
                <label className="block text-xs font-bold text-[#0b1c30] mb-1.5">Current Academic Session *</label>
                <input
                  type="text"
                  required
                  value={formData.currentSession}
                  onChange={(e) => setFormData({ ...formData, currentSession: e.target.value })}
                  placeholder="e.g. 2026-27"
                  className="w-full px-4 py-2.5 rounded-xl bg-[#eff4ff] border border-[#c8c4d5]/50 text-xs font-bold text-[#0b1c30] focus:outline-none focus:ring-2 focus:ring-[#1f108e]/30"
                />
                <p className="text-[11px] text-[#777584] mt-1.5">
                  This year identifier will be printed on all student ID cards, admission certificates, and fee receipts.
                </p>
              </div>

              <div className="flex items-center justify-between pt-6 border-t border-[#c8c4d5]/30">
                <button
                  type="button"
                  onClick={() => setStep(1)}
                  className="px-5 py-2.5 rounded-xl bg-[#eff4ff] hover:bg-[#dce9ff] text-[#464553] font-bold text-xs transition-colors flex items-center gap-1.5 cursor-pointer"
                >
                  <ArrowLeft className="w-4 h-4" />
                  <span>Back</span>
                </button>

                <button
                  type="submit"
                  className="px-6 py-3 rounded-xl bg-[#1f108e] hover:bg-[#0f0069] text-white font-bold text-xs shadow-md transition-all flex items-center gap-2 cursor-pointer"
                >
                  <span>Complete Setup & Launch</span>
                  <Check className="w-4 h-4" />
                </button>
              </div>
            </div>
          )}

          {step === 3 && (
            <div className="text-center py-6 space-y-4 animate-in fade-in duration-300">
              <div className="w-16 h-16 rounded-full bg-emerald-50 text-emerald-600 flex items-center justify-center mx-auto border-4 border-emerald-100 shadow-md">
                <Check className="w-8 h-8" />
              </div>
              <div className="space-y-1">
                <h3 className="text-xl font-black text-[#0b1c30]">Your Institution is Live!</h3>
                <p className="text-xs text-[#464553] max-w-sm mx-auto leading-relaxed">
                  Onboarding complete. You can now enroll students, collect fees with automated WhatsApp reminders, and track attendance registers.
                </p>
              </div>
              <div className="pt-4">
                <button
                  type="button"
                  onClick={() => navigate('/dashboard')}
                  className="px-8 py-3.5 rounded-xl bg-[#1f108e] hover:bg-[#0f0069] text-white font-bold text-xs shadow-xl transition-all flex items-center gap-2 mx-auto cursor-pointer"
                >
                  <span>Enter Executive Dashboard</span>
                  <ArrowRight className="w-4 h-4" />
                </button>
              </div>
            </div>
          )}

        </form>

      </div>
    </div>
  );
}
