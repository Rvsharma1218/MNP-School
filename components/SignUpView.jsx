'use client';

import React, { useState } from 'react';
import { useSchoolStore } from '../lib/store';
import {
  School, User, Building2, Mail, Phone, Lock, Eye, EyeOff,
  ShieldCheck, UserCheck, ArrowRight, CheckCircle2, AlertCircle, Sparkles
} from 'lucide-react';

export default function SignUpView() {
  const { signUp, navigate } = useSchoolStore();
  const [role, setRole] = useState('principal'); // 'principal' | 'teacher'
  const [fullName, setFullName] = useState('');
  const [instituteName, setInstituteName] = useState('');
  const [email, setEmail] = useState('');
  const [mobile, setMobile] = useState('');
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');

    if (password !== confirmPassword) {
      setError('Passwords do not match. Please verify your password confirmation.');
      return;
    }

    if (password.length < 6) {
      setError('Password must be at least 6 characters in length.');
      return;
    }

    setLoading(true);

    try {
      await signUp(
        fullName.trim(),
        role === 'principal' ? (instituteName.trim() || 'My School') : 'Main Branch',
        email.trim(),
        mobile.trim(),
        password,
        role
      );

      // Auto 1-time clean refresh on sign up into dashboard
      if (typeof window !== 'undefined') {
        window.location.href = '/dashboard';
      }
    } catch (err) {
      console.warn('Sign Up error:', err.message);
      if (err.message?.includes('email-already-in-use')) {
        setError('This email address is already registered. Please sign in instead.');
      } else if (err.message?.includes('weak-password')) {
        setError('Password is too weak. Please use a stronger combination.');
      } else {
        setError(err.message || 'Failed to create account. Please try again.');
      }
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen w-full flex items-center justify-center p-4 md:p-8 bg-gradient-to-br from-[#1f108e] via-[#150b69] to-[#0b043b] text-[#0b1c30] font-sans antialiased">
      
      {/* ── Main Split-Screen Container ── */}
      <div className="w-full max-w-5xl grid grid-cols-1 lg:grid-cols-12 rounded-3xl overflow-hidden shadow-2xl bg-white border border-white/20">
        
        {/* ── Left Side: Academic Branding Hero (Desktop) ── */}
        <div className="hidden lg:flex lg:col-span-5 bg-gradient-to-br from-[#1f108e] to-[#0f0069] p-8 lg:p-12 text-white flex-col justify-between relative overflow-hidden">
          
          <div className="absolute -right-16 -top-16 w-64 h-64 bg-white/10 rounded-full blur-2xl pointer-events-none" />
          <div className="absolute -left-16 -bottom-16 w-64 h-64 bg-[#316bf3]/20 rounded-full blur-3xl pointer-events-none" />

          {/* Top Brand Logo */}
          <div className="relative z-10 flex items-center gap-3">
            <div className="w-12 h-12 rounded-2xl bg-white/15 backdrop-blur-md border border-white/25 flex items-center justify-center shadow-lg">
              <School className="w-6 h-6 text-white" />
            </div>
            <div>
              <h2 className="text-xl font-black tracking-tight text-white">Smart School</h2>
              <p className="text-xs text-white/75 font-medium">SaaS Management Platform</p>
            </div>
          </div>

          {/* Middle Content Banner */}
          <div className="relative z-10 my-8 space-y-4">
            <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-white/15 border border-white/20 text-xs font-semibold text-white/90">
              <Sparkles className="w-3.5 h-3.5 text-[#ffb694]" />
              <span>Instant Digital Onboarding</span>
            </div>
            <h1 className="text-2xl lg:text-3xl font-extrabold leading-tight tracking-tight text-white">
              Launch Your Smart Institution in Minutes
            </h1>
            <p className="text-xs lg:text-sm text-white/80 leading-relaxed">
              Join thousands of schools and coaching institutes running high-efficiency admissions, automated ledger reconciliation, and instant parent notifications.
            </p>

            <div className="pt-2 space-y-2 text-xs text-white/90 font-medium">
              <div className="flex items-center gap-2">
                <CheckCircle2 className="w-4 h-4 text-emerald-400 flex-shrink-0" />
                <span>Unlimited Student Records & Profiles</span>
              </div>
              <div className="flex items-center gap-2">
                <CheckCircle2 className="w-4 h-4 text-emerald-400 flex-shrink-0" />
                <span>Custom Fee Heads, Receipts & Invoices</span>
              </div>
              <div className="flex items-center gap-2">
                <CheckCircle2 className="w-4 h-4 text-emerald-400 flex-shrink-0" />
                <span>Automated PDF Marksheets & ID Cards</span>
              </div>
            </div>
          </div>

          {/* Bottom Footer Notice */}
          <div className="relative z-10 pt-4 border-t border-white/15 flex items-center justify-between text-[11px] text-white/70">
            <span>© 2026 Smart School SaaS</span>
            <span className="font-mono">Secure Cloud Sync</span>
          </div>
        </div>

        {/* ── Right Side: Form Panel ── */}
        <div className="col-span-1 lg:col-span-7 bg-[#f8f9ff] p-5 sm:p-8 lg:p-12 flex flex-col justify-center">
          
          <div className="max-w-lg w-full mx-auto space-y-5">
            
            {/* Mobile-Only Header Brand Logo */}
            <div className="flex lg:hidden items-center gap-3 pb-2 border-b border-[#c8c4d5]/40">
              <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-[#1f108e] to-[#0f0069] flex items-center justify-center text-white shadow-sm flex-shrink-0">
                <School className="w-5 h-5" />
              </div>
              <div>
                <h2 className="font-black text-sm text-[#1f108e] leading-tight">Smart School</h2>
                <p className="text-[10px] text-slate-500 font-medium">SaaS Management Platform</p>
              </div>
            </div>

            {/* Header Title */}
            <div>
              <h2 className="text-xl sm:text-2xl font-black text-[#0b1c30] tracking-tight">Create Your Account</h2>
              <p className="text-xs text-[#464553] mt-1">Get started with a free setup for your institute.</p>
            </div>

            {/* Role Toggle Selector */}
            <div className="grid grid-cols-2 p-1 bg-[#dce9ff] rounded-2xl gap-1">
              <button
                type="button"
                onClick={() => setRole('principal')}
                className={`py-2.5 px-4 rounded-xl text-xs font-bold flex items-center justify-center gap-2 transition-all cursor-pointer ${
                  role === 'principal'
                    ? 'bg-white text-[#1f108e] shadow-sm'
                    : 'text-[#464553] hover:text-[#0b1c30]'
                }`}
              >
                <ShieldCheck className="w-4 h-4" />
                <span>Principal / Admin</span>
              </button>

              <button
                type="button"
                onClick={() => setRole('teacher')}
                className={`py-2.5 px-4 rounded-xl text-xs font-bold flex items-center justify-center gap-2 transition-all cursor-pointer ${
                  role === 'teacher'
                    ? 'bg-white text-[#1f108e] shadow-sm'
                    : 'text-[#464553] hover:text-[#0b1c30]'
                }`}
              >
                <UserCheck className="w-4 h-4" />
                <span>Teacher / Faculty</span>
              </button>
            </div>

            {/* Error Message Box */}
            {error && (
              <div className="p-3.5 rounded-xl bg-rose-50 border border-rose-200 text-rose-700 text-xs flex items-center gap-3 animate-in fade-in duration-200">
                <AlertCircle className="w-4 h-4 flex-shrink-0 text-rose-600" />
                <span className="font-medium">{error}</span>
              </div>
            )}

            {/* Sign Up Form */}
            <form onSubmit={handleSubmit} className="space-y-4">
              
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                
                {/* Full Name */}
                <div>
                  <label className="block text-xs font-bold text-[#0b1c30] mb-1.5">Your Full Name *</label>
                  <div className="relative">
                    <User className="w-4 h-4 text-[#777584] absolute left-3.5 top-1/2 -translate-y-1/2" />
                    <input
                      type="text"
                      required
                      value={fullName}
                      onChange={(e) => setFullName(e.target.value)}
                      placeholder="e.g. Dr. Rajesh Sharma"
                      className="w-full pl-10 pr-4 py-2.5 rounded-xl bg-white border border-[#c8c4d5] text-xs font-medium text-[#0b1c30] placeholder-[#777584] focus:outline-none focus:ring-2 focus:ring-[#1f108e]/30 focus:border-[#1f108e] transition-all"
                    />
                  </div>
                </div>

                {/* Institute Name (for Principal) or Branch */}
                <div>
                  <label className="block text-xs font-bold text-[#0b1c30] mb-1.5">
                    {role === 'principal' ? 'Institute Name *' : 'Department / Subject'}
                  </label>
                  <div className="relative">
                    <Building2 className="w-4 h-4 text-[#777584] absolute left-3.5 top-1/2 -translate-y-1/2" />
                    <input
                      type="text"
                      required={role === 'principal'}
                      value={instituteName}
                      onChange={(e) => setInstituteName(e.target.value)}
                      placeholder={role === 'principal' ? 'e.g. St. Xavier Academy' : 'e.g. Mathematics'}
                      className="w-full pl-10 pr-4 py-2.5 rounded-xl bg-white border border-[#c8c4d5] text-xs font-medium text-[#0b1c30] placeholder-[#777584] focus:outline-none focus:ring-2 focus:ring-[#1f108e]/30 focus:border-[#1f108e] transition-all"
                    />
                  </div>
                </div>

                {/* Email Address */}
                <div>
                  <label className="block text-xs font-bold text-[#0b1c30] mb-1.5">Official Email *</label>
                  <div className="relative">
                    <Mail className="w-4 h-4 text-[#777584] absolute left-3.5 top-1/2 -translate-y-1/2" />
                    <input
                      type="email"
                      required
                      value={email}
                      onChange={(e) => setEmail(e.target.value)}
                      placeholder="admin@institution.edu"
                      className="w-full pl-10 pr-4 py-2.5 rounded-xl bg-white border border-[#c8c4d5] text-xs font-medium text-[#0b1c30] placeholder-[#777584] focus:outline-none focus:ring-2 focus:ring-[#1f108e]/30 focus:border-[#1f108e] transition-all"
                    />
                  </div>
                </div>

                {/* Mobile Number */}
                <div>
                  <label className="block text-xs font-bold text-[#0b1c30] mb-1.5">Mobile Phone *</label>
                  <div className="relative">
                    <Phone className="w-4 h-4 text-[#777584] absolute left-3.5 top-1/2 -translate-y-1/2" />
                    <input
                      type="tel"
                      required
                      value={mobile}
                      onChange={(e) => setMobile(e.target.value)}
                      placeholder="+91 98765 43210"
                      className="w-full pl-10 pr-4 py-2.5 rounded-xl bg-white border border-[#c8c4d5] text-xs font-medium text-[#0b1c30] placeholder-[#777584] focus:outline-none focus:ring-2 focus:ring-[#1f108e]/30 focus:border-[#1f108e] transition-all"
                    />
                  </div>
                </div>

                {/* Password */}
                <div>
                  <label className="block text-xs font-bold text-[#0b1c30] mb-1.5">Password *</label>
                  <div className="relative">
                    <Lock className="w-4 h-4 text-[#777584] absolute left-3.5 top-1/2 -translate-y-1/2" />
                    <input
                      type={showPassword ? 'text' : 'password'}
                      required
                      value={password}
                      onChange={(e) => setPassword(e.target.value)}
                      placeholder="Min 6 characters"
                      className="w-full pl-10 pr-9 py-2.5 rounded-xl bg-white border border-[#c8c4d5] text-xs font-medium text-[#0b1c30] placeholder-[#777584] focus:outline-none focus:ring-2 focus:ring-[#1f108e]/30 focus:border-[#1f108e] transition-all"
                    />
                    <button
                      type="button"
                      onClick={() => setShowPassword(p => !p)}
                      className="absolute right-3 top-1/2 -translate-y-1/2 text-[#777584] hover:text-[#0b1c30] cursor-pointer"
                    >
                      {showPassword ? <EyeOff className="w-3.5 h-3.5" /> : <Eye className="w-3.5 h-3.5" />}
                    </button>
                  </div>
                </div>

                {/* Confirm Password */}
                <div>
                  <label className="block text-xs font-bold text-[#0b1c30] mb-1.5">Confirm Password *</label>
                  <div className="relative">
                    <Lock className="w-4 h-4 text-[#777584] absolute left-3.5 top-1/2 -translate-y-1/2" />
                    <input
                      type={showPassword ? 'text' : 'password'}
                      required
                      value={confirmPassword}
                      onChange={(e) => setConfirmPassword(e.target.value)}
                      placeholder="Re-type password"
                      className="w-full pl-10 pr-4 py-2.5 rounded-xl bg-white border border-[#c8c4d5] text-xs font-medium text-[#0b1c30] placeholder-[#777584] focus:outline-none focus:ring-2 focus:ring-[#1f108e]/30 focus:border-[#1f108e] transition-all"
                    />
                  </div>
                </div>

              </div>

              {/* Submit CTA Button */}
              <button
                type="submit"
                disabled={loading}
                className="w-full py-3.5 px-6 rounded-xl bg-[#1f108e] hover:bg-[#0f0069] text-white font-bold text-xs shadow-lg hover:shadow-xl transition-all flex items-center justify-center gap-2 cursor-pointer disabled:opacity-60 disabled:cursor-not-allowed group mt-4"
              >
                {loading ? (
                  <span>Registering Account...</span>
                ) : (
                  <>
                    <span>Create {role === 'principal' ? 'Principal & Institute Account' : 'Teacher Account'}</span>
                    <ArrowRight className="w-4 h-4 group-hover:translate-x-1 transition-transform" />
                  </>
                )}
              </button>
            </form>

            {/* Bottom Sign In Link */}
            <div className="text-center pt-3 border-t border-[#c8c4d5]/50">
              <p className="text-xs text-[#464553]">
                Already have an account?{' '}
                <button
                  type="button"
                  onClick={() => navigate('/signin')}
                  className="font-bold text-[#0051d5] hover:underline cursor-pointer ml-1"
                >
                  Sign In to Portal
                </button>
              </p>
            </div>
          </div>
        </div>

      </div>
    </div>
  );
}
