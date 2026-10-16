'use client';

import React, { useState, useEffect } from 'react';
import { useSchoolStore } from '../lib/store';
import {
  GraduationCap, Mail, Lock, Eye, EyeOff, ShieldCheck,
  School, UserCheck, ArrowRight, Sparkles, AlertCircle, CheckCircle2, User, ChevronDown
} from 'lucide-react';

export default function SignInView() {
  const { signIn, teacherSignIn, parentSignIn, fetchSchoolTeachersByEmail, teachers, settings, currentUser, navigate, demoSignIn } = useSchoolStore();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [role, setRole] = useState('principal'); // 'principal' | 'teacher' | 'parent'
  const [parentSchoolIdentifier, setParentSchoolIdentifier] = useState('');
  const [parentAdmissionNo, setParentAdmissionNo] = useState('');
  const [parentMobile, setParentMobile] = useState('');
  const [selectedTeacherId, setSelectedTeacherId] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [rememberMe, setRememberMe] = useState(true);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

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
  }, [role, email]);

  useEffect(() => {
    // If teachers are available and in teacher mode, pre-select first teacher
    if (teachers && teachers.length > 0 && !selectedTeacherId) {
      setSelectedTeacherId(teachers[0].authUid || teachers[0].id || '');
    }
  }, [teachers, role]);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');
    setLoading(true);

    try {
      if (role === 'parent') {
        if (!parentAdmissionNo.trim()) {
          throw new Error("Please enter your child's Admission Number or Roll Number.");
        }
        await parentSignIn(parentSchoolIdentifier.trim(), parentAdmissionNo.trim(), parentMobile.trim());
      } else if (role === 'teacher') {
        if (!selectedTeacherId) {
          throw new Error("Please select your teacher name from the dropdown.");
        }
        await teacherSignIn(email.trim(), selectedTeacherId, password);
      } else {
        await signIn(email.trim(), password);
      }
      
      // Auto 1-time clean refresh on login into dashboard
      if (typeof window !== 'undefined') {
        window.location.href = '/dashboard';
      }
    } catch (err) {
      console.warn('Sign In attempt error:', err.message);
      // Friendly readable error messages
      if (err.message?.includes('user-not-found') || err.message?.includes('invalid-credential')) {
        setError('Invalid email or password. Please verify your credentials.');
      } else if (err.message?.includes('wrong-password')) {
        setError('Incorrect password. Please try again or use Forgot Password.');
      } else if (err.message?.includes('invalid-email')) {
        setError('Please enter a valid email address.');
      } else {
        setError(err.message || 'Failed to sign in. Please try again.');
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
          
          {/* Subtle decorative background circles */}
          <div className="absolute -right-16 -top-16 w-64 h-64 bg-white/10 rounded-full blur-2xl pointer-events-none" />
          <div className="absolute -left-16 -bottom-16 w-64 h-64 bg-[#316bf3]/20 rounded-full blur-3xl pointer-events-none" />

          {/* Top Brand Logo */}
          <div className="relative z-10 flex items-center gap-3">
            <div className="w-12 h-12 rounded-2xl bg-white/15 backdrop-blur-md border border-white/25 flex items-center justify-center shadow-lg">
              <School className="w-6 h-6 text-white" />
            </div>
            <div>
              <h2 className="text-xl font-black tracking-tight text-white">{settings.instituteName || 'Smart School'}</h2>
              <p className="text-xs text-white/75 font-medium">SaaS Management Platform</p>
            </div>
          </div>

          {/* Middle Content Banner */}
          <div className="relative z-10 my-8 space-y-4">
            <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-white/15 border border-white/20 text-xs font-semibold text-white/90">
              <Sparkles className="w-3.5 h-3.5 text-[#ffb694]" />
              <span>Next-Gen Institution OS</span>
            </div>
            <h1 className="text-2xl lg:text-3xl font-extrabold leading-tight tracking-tight text-white">
              Empowering Educational Excellence
            </h1>
            <p className="text-xs lg:text-sm text-white/80 leading-relaxed">
              Complete student administration, automated recurring fees, real-time attendance, exam marksheets, and faculty portals.
            </p>

            {/* Quick Feature Checklist */}
            <div className="pt-2 space-y-2 text-xs text-white/90 font-medium">
              <div className="flex items-center gap-2">
                <CheckCircle2 className="w-4 h-4 text-emerald-400 flex-shrink-0" />
                <span>Single School Email Login with Faculty Dropdown</span>
              </div>
              <div className="flex items-center gap-2">
                <CheckCircle2 className="w-4 h-4 text-emerald-400 flex-shrink-0" />
                <span>Auto-Rolled Monthly Dues & Instant Print Receipts</span>
              </div>
              <div className="flex items-center gap-2">
                <CheckCircle2 className="w-4 h-4 text-emerald-400 flex-shrink-0" />
                <span>Dedicated Class Teacher Attendance & Results Desk</span>
              </div>
            </div>
          </div>

          {/* Bottom Footer Notice */}
          <div className="relative z-10 pt-4 border-t border-white/15 flex items-center justify-between text-[11px] text-white/70">
            <span>© 2026 {settings.instituteName || 'Smart School SaaS'}</span>
            <span className="font-mono">v2.5.0</span>
          </div>
        </div>

        {/* ── Right Side: Modern Glass Form Panel ── */}
        <div className="col-span-1 lg:col-span-7 bg-[#f8f9ff] p-5 sm:p-8 lg:p-12 flex flex-col justify-center">
          
          <div className="max-w-md w-full mx-auto space-y-5">
            
            {/* Mobile-Only Header Brand Logo */}
            <div className="flex lg:hidden items-center gap-3 pb-2 border-b border-[#c8c4d5]/40">
              <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-[#1f108e] to-[#0f0069] flex items-center justify-center text-white shadow-sm flex-shrink-0">
                <School className="w-5 h-5" />
              </div>
              <div>
                <h2 className="font-black text-sm text-[#1f108e] leading-tight">{settings.instituteName || 'Smart School'}</h2>
                <p className="text-[10px] text-slate-500 font-medium">SaaS Management Platform</p>
              </div>
            </div>

            {/* Header Title */}
            <div>
              <h2 className="text-xl sm:text-2xl font-black text-[#0b1c30] tracking-tight">Sign In to Your Portal</h2>
              <p className="text-xs text-[#464553] mt-1">
                {role === 'principal'
                  ? 'Enter principal credentials to access full administrative controls.'
                  : role === 'teacher'
                  ? 'Enter School Email and select your Teacher name to login.'
                  : 'Enter School Email/Code, Student Admission No & Mobile to access Parent Portal.'}
              </p>
            </div>

            {/* Role Toggle Selector (3 Tabs) */}
            <div className="grid grid-cols-3 p-1 bg-[#dce9ff] rounded-2xl gap-1">
              <button
                type="button"
                onClick={() => { setRole('principal'); setError(''); }}
                className={`py-2 px-2.5 rounded-xl text-xs font-bold flex items-center justify-center gap-1.5 transition-all cursor-pointer ${
                  role === 'principal'
                    ? 'bg-white text-[#1f108e] shadow-sm'
                    : 'text-[#464553] hover:text-[#0b1c30]'
                }`}
              >
                <ShieldCheck className="w-3.5 h-3.5" />
                <span>Principal</span>
              </button>

              <button
                type="button"
                onClick={() => { setRole('teacher'); setError(''); }}
                className={`py-2 px-2.5 rounded-xl text-xs font-bold flex items-center justify-center gap-1.5 transition-all cursor-pointer ${
                  role === 'teacher'
                    ? 'bg-white text-[#1f108e] shadow-sm'
                    : 'text-[#464553] hover:text-[#0b1c30]'
                }`}
              >
                <UserCheck className="w-3.5 h-3.5" />
                <span>Teacher</span>
              </button>

              <button
                type="button"
                onClick={() => { setRole('parent'); setError(''); }}
                className={`py-2 px-2.5 rounded-xl text-xs font-bold flex items-center justify-center gap-1.5 transition-all cursor-pointer ${
                  role === 'parent'
                    ? 'bg-white text-[#1f108e] shadow-sm'
                    : 'text-[#464553] hover:text-[#0b1c30]'
                }`}
              >
                <GraduationCap className="w-3.5 h-3.5" />
                <span>Parent</span>
              </button>
            </div>

                        {/* Quick 1-Click Instant Demo Access (Guaranteed to open on Vercel & localhost) */}
            <div className="p-3 bg-gradient-to-r from-blue-50 to-indigo-50 border border-blue-200/80 rounded-2xl space-y-2">
              <div className="flex items-center justify-between">
                <span className="text-[11px] font-black uppercase text-indigo-950 flex items-center gap-1.5">
                  <Sparkles className="w-3.5 h-3.5 text-amber-500" />
                  Instant 1-Click Demo Login:
                </span>
                <span className="text-[10px] text-indigo-600 font-semibold bg-white px-2 py-0.5 rounded-full border border-indigo-100">
                  No Password Needed
                </span>
              </div>
              <div className="grid grid-cols-3 gap-1.5">
                <button
                  type="button"
                  onClick={() => {
                    if (demoSignIn) demoSignIn('principal');
                    else {
                      setEmail('admin@example.com');
                      setPassword('123456');
                    }
                  }}
                  className="py-2 px-2 rounded-xl bg-[#1f108e] hover:bg-[#150b69] text-white text-[10px] font-bold shadow-sm transition-all flex items-center justify-center gap-1 cursor-pointer active:scale-95"
                >
                  <ShieldCheck className="w-3 h-3" />
                  <span>Principal</span>
                </button>
                <button
                  type="button"
                  onClick={() => {
                    if (demoSignIn) demoSignIn('teacher');
                    else {
                      setRole('teacher');
                      setEmail('admin@example.com');
                      setPassword('123456');
                    }
                  }}
                  className="py-2 px-2 rounded-xl bg-white hover:bg-slate-100 text-[#1f108e] border border-[#1f108e]/30 text-[10px] font-bold shadow-sm transition-all flex items-center justify-center gap-1 cursor-pointer active:scale-95"
                >
                  <UserCheck className="w-3 h-3" />
                  <span>Teacher</span>
                </button>
                <button
                  type="button"
                  onClick={() => {
                    if (demoSignIn) demoSignIn('parent');
                    else {
                      setRole('parent');
                      setParentAdmissionNo('ADM-2026-001');
                      setParentMobile('9876543210');
                    }
                  }}
                  className="py-2 px-2 rounded-xl bg-emerald-600 hover:bg-emerald-700 text-white text-[10px] font-bold shadow-sm transition-all flex items-center justify-center gap-1 cursor-pointer active:scale-95"
                >
                  <GraduationCap className="w-3 h-3" />
                  <span>Parent</span>
                </button>
              </div>
            </div>

            {/* Error Message Box */}
            {error && (
              <div className="p-3.5 rounded-xl bg-rose-50 border border-rose-200 text-rose-700 text-xs flex items-center gap-3 animate-in fade-in duration-200">
                <AlertCircle className="w-4 h-4 flex-shrink-0 text-rose-600" />
                <span className="font-medium">{error}</span>
              </div>
            )}

            {/* Sign In Form */}
            <form onSubmit={handleSubmit} className="space-y-4">
              
              {/* PARENT MODE FORM FIELDS */}
              {role === 'parent' ? (
                <div className="space-y-3.5 animate-in fade-in duration-200">
                  <div>
                    <label className="block text-xs font-bold text-[#0b1c30] mb-1">
                      School Email or Code (Optional)
                    </label>
                    <div className="relative">
                      <School className="w-4 h-4 text-[#777584] absolute left-3.5 top-1/2 -translate-y-1/2" />
                      <input
                        type="text"
                        value={parentSchoolIdentifier}
                        onChange={(e) => setParentSchoolIdentifier(e.target.value)}
                        placeholder="e.g. mnpschooledu@gmail.com or SCHOOL_007 (leave empty for default)"
                        className="w-full pl-10 pr-4 py-3 rounded-xl bg-white border border-[#c8c4d5] text-xs font-medium text-[#0b1c30] placeholder-[#777584] focus:outline-none focus:ring-2 focus:ring-[#1f108e]/30 focus:border-[#1f108e] transition-all"
                      />
                    </div>
                  </div>

                  <div>
                    <label className="block text-xs font-bold text-[#0b1c30] mb-1">
                      Child's Admission Number or Roll No *
                    </label>
                    <div className="relative">
                      <GraduationCap className="w-4 h-4 text-[#777584] absolute left-3.5 top-1/2 -translate-y-1/2" />
                      <input
                        type="text"
                        required
                        value={parentAdmissionNo}
                        onChange={(e) => setParentAdmissionNo(e.target.value)}
                        placeholder="e.g. ADM-2026-001 or 1"
                        className="w-full pl-10 pr-4 py-3 rounded-xl bg-white border border-[#c8c4d5] text-xs font-medium text-[#0b1c30] placeholder-[#777584] focus:outline-none focus:ring-2 focus:ring-[#1f108e]/30 focus:border-[#1f108e] transition-all font-mono"
                      />
                    </div>
                    <p className="text-[10px] text-slate-500 mt-1">
                      Find on school fee receipt, student ID card or report card.
                    </p>
                  </div>

                  <div>
                    <label className="block text-xs font-bold text-[#0b1c30] mb-1">
                      Registered Mobile Number *
                    </label>
                    <div className="relative">
                      <Phone className="w-4 h-4 text-[#777584] absolute left-3.5 top-1/2 -translate-y-1/2" />
                      <input
                        type="tel"
                        required
                        maxLength={10}
                        value={parentMobile}
                        onChange={(e) => setParentMobile(e.target.value.replace(/[^0-9]/g, ''))}
                        placeholder="e.g. 9876543210 (10 digits)"
                        className="w-full pl-10 pr-4 py-3 rounded-xl bg-white border border-[#c8c4d5] text-xs font-medium text-[#0b1c30] placeholder-[#777584] focus:outline-none focus:ring-2 focus:ring-[#1f108e]/30 focus:border-[#1f108e] transition-all font-mono"
                      />
                    </div>
                    <p className="text-[10px] text-slate-500 mt-1">
                      The contact phone registered at the time of student admission.
                    </p>
                  </div>
                </div>
              ) : (
                /* PRINCIPAL & TEACHER MODE FORM FIELDS */
                <>
                  {/* 1. Main School Email Input */}
                  <div>
                    <label className="block text-xs font-bold text-[#0b1c30] mb-1.5">
                      {role === 'teacher' ? "School's Main Email Address" : "Principal / Admin Email"}
                    </label>
                    <div className="relative">
                      <Mail className="w-4 h-4 text-[#777584] absolute left-3.5 top-1/2 -translate-y-1/2" />
                      <input
                        type="email"
                        required
                        value={email}
                        onChange={(e) => setEmail(e.target.value)}
                        placeholder="admin@example.com"
                        className="w-full pl-10 pr-4 py-3 rounded-xl bg-white border border-[#c8c4d5] text-xs font-medium text-[#0b1c30] placeholder-[#777584] focus:outline-none focus:ring-2 focus:ring-[#1f108e]/30 focus:border-[#1f108e] transition-all"
                      />
                    </div>
                    {role === 'teacher' && (
                      <p className="text-[10px] text-slate-500 mt-1">
                        Enter the school email registered by your Principal.
                      </p>
                    )}
                  </div>

                  {/* 2. Teacher Dropdown (Only visible in Teacher mode) */}
                  {role === 'teacher' && (
                    <div className="animate-in fade-in duration-200">
                      <label className="block text-xs font-bold text-[#0b1c30] mb-1.5">
                        Select Your Teacher Name *
                      </label>
                      <div className="relative">
                        <User className="w-4 h-4 text-[#777584] absolute left-3.5 top-1/2 -translate-y-1/2" />
                        <select
                          required
                          value={selectedTeacherId}
                          onChange={(e) => setSelectedTeacherId(e.target.value)}
                          className="w-full pl-10 pr-10 py-3 rounded-xl bg-white border border-[#c8c4d5] text-xs font-semibold text-[#0b1c30] focus:outline-none focus:ring-2 focus:ring-[#1f108e]/30 focus:border-[#1f108e] transition-all appearance-none cursor-pointer"
                        >
                          <option value="">-- Choose Your Teacher Profile --</option>
                          {teachers.map(t => (
                            <option key={t.authUid || t.id} value={t.authUid || t.id}>
                              {t.name} (Class {t.assignedClass} - Sec {t.assignedSection || 'A'})
                            </option>
                          ))}
                        </select>
                        <ChevronDown className="w-4 h-4 text-[#777584] absolute right-3.5 top-1/2 -translate-y-1/2 pointer-events-none" />
                      </div>
                      {teachers.length === 0 && (
                        <p className="text-[10px] text-amber-600 font-medium mt-1">
                          No teachers found. Please ask Principal to add faculty profiles in Faculty Management.
                        </p>
                      )}
                    </div>
                  )}

                  {/* 3. Password Input with Show/Hide */}
                  <div>
                    <div className="flex items-center justify-between mb-1.5">
                      <label className="text-xs font-bold text-[#0b1c30]">
                        {role === 'teacher' ? "Teacher Password" : "Password"}
                      </label>
                      {role === 'principal' && (
                        <button
                          type="button"
                          onClick={() => navigate('/forgot-password')}
                          className="text-[11px] font-bold text-[#0051d5] hover:underline cursor-pointer"
                        >
                          Forgot Password?
                        </button>
                      )}
                    </div>
                    <div className="relative">
                      <Lock className="w-4 h-4 text-[#777584] absolute left-3.5 top-1/2 -translate-y-1/2" />
                      <input
                        type={showPassword ? 'text' : 'password'}
                        required
                        value={password}
                        onChange={(e) => setPassword(e.target.value)}
                        placeholder={role === 'teacher' ? "Enter your teacher password (default: 123456)" : "Enter your secret password"}
                        className="w-full pl-10 pr-10 py-3 rounded-xl bg-white border border-[#c8c4d5] text-xs font-medium text-[#0b1c30] placeholder-[#777584] focus:outline-none focus:ring-2 focus:ring-[#1f108e]/30 focus:border-[#1f108e] transition-all"
                      />
                      <button
                        type="button"
                        onClick={() => setShowPassword(p => !p)}
                        className="absolute right-3.5 top-1/2 -translate-y-1/2 text-[#777584] hover:text-[#0b1c30] cursor-pointer"
                      >
                        {showPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4 text-primary" />}
                      </button>
                    </div>
                  </div>
                </>
              )}

              {/* Remember Me Checkbox */}
              <div className="flex items-center justify-between pt-1">
                <label className="flex items-center gap-2 text-xs font-semibold text-[#464553] cursor-pointer">
                  <input
                    type="checkbox"
                    checked={rememberMe}
                    onChange={(e) => setRememberMe(e.target.checked)}
                    className="w-4 h-4 rounded text-[#1f108e] focus:ring-[#1f108e] border-[#c8c4d5] cursor-pointer"
                  />
                  <span>Remember my session</span>
                </label>
              </div>

              {/* Submit CTA Button */}
              <button
                type="submit"
                disabled={loading}
                className="w-full py-3.5 px-6 rounded-xl bg-[#1f108e] hover:bg-[#0f0069] text-white font-bold text-xs shadow-lg hover:shadow-xl transition-all flex items-center justify-center gap-2 cursor-pointer disabled:opacity-60 disabled:cursor-not-allowed group mt-2"
              >
                {loading ? (
                  <span>Authenticating...</span>
                ) : (
                  <>
                    <span>
                      {role === 'principal'
                        ? 'Sign In to Admin Dashboard'
                        : role === 'teacher'
                        ? 'Sign In to Teacher Portal'
                        : 'Sign In to Parent Portal'}
                    </span>
                    <ArrowRight className="w-4 h-4 group-hover:translate-x-1 transition-transform" />
                  </>
                )}
              </button>
            </form>

            {/* Bottom Create Account Link */}
            <div className="text-center pt-4 border-t border-[#c8c4d5]/50">
              <p className="text-xs text-[#464553]">
                Don't have an institution account?{' '}
                <button
                  type="button"
                  onClick={() => navigate('/signup')}
                  className="font-bold text-[#0051d5] hover:underline cursor-pointer ml-1"
                >
                  Create Account / Register
                </button>
              </p>
            </div>
          </div>
        </div>

      </div>
    </div>
  );
}
