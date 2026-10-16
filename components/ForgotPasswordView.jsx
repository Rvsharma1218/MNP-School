'use client';

import React, { useState } from 'react';
import { useSchoolStore } from '../lib/store';
import { School, Mail, ArrowRight, ArrowLeft, CheckCircle2, AlertCircle, Sparkles, KeyRound } from 'lucide-react';

export default function ForgotPasswordView() {
  const { forgotPassword, navigate } = useSchoolStore();
  const [email, setEmail] = useState('');
  const [error, setError] = useState('');
  const [success, setSuccess] = useState(false);
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');
    setSuccess(false);
    setLoading(true);

    try {
      await forgotPassword(email.trim());
      setSuccess(true);
    } catch (err) {
      console.warn('Password recovery error:', err.message);
      if (err.message?.includes('user-not-found')) {
        setError('No active account found with this email address.');
      } else {
        setError(err.message || 'Failed to send recovery email. Please check the address.');
      }
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen w-full flex items-center justify-center p-4 md:p-8 bg-gradient-to-br from-[#1f108e] via-[#150b69] to-[#0b043b] text-[#0b1c30] font-sans antialiased">
      
      <div className="w-full max-w-5xl grid grid-cols-1 lg:grid-cols-12 rounded-3xl overflow-hidden shadow-2xl bg-white border border-white/20">
        
        {/* ── Left Side: Academic Branding Hero ── */}
        <div className="lg:col-span-5 bg-gradient-to-br from-[#1f108e] to-[#0f0069] p-8 lg:p-12 text-white flex flex-col justify-between relative overflow-hidden">
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
              <span>Instant Recovery Protocol</span>
            </div>
            <h1 className="text-2xl lg:text-3xl font-extrabold leading-tight tracking-tight text-white">
              Secure Account Access Recovery
            </h1>
            <p className="text-xs lg:text-sm text-white/80 leading-relaxed">
              Enter your registered institute email address and we will dispatch an encrypted one-time password reset link to your inbox.
            </p>
          </div>

          <div className="relative z-10 pt-4 border-t border-white/15 flex items-center justify-between text-[11px] text-white/70">
            <span>© 2026 Smart School SaaS</span>
            <span className="font-mono">Security Verified</span>
          </div>
        </div>

        {/* ── Right Side: Form Panel ── */}
        <div className="lg:col-span-7 bg-[#f8f9ff] p-8 lg:p-12 flex flex-col justify-center">
          <div className="max-w-md w-full mx-auto space-y-6">
            
            <div className="w-12 h-12 rounded-2xl bg-[#eff4ff] text-[#1f108e] flex items-center justify-center border border-[#dce9ff]">
              <KeyRound className="w-6 h-6" />
            </div>

            <div>
              <h2 className="text-2xl font-black text-[#0b1c30] tracking-tight">Forgot Your Password?</h2>
              <p className="text-xs text-[#464553] mt-1">
                Don't worry! Enter your email below and we'll send you reset instructions.
              </p>
            </div>

            {error && (
              <div className="p-3.5 rounded-xl bg-rose-50 border border-rose-200 text-rose-700 text-xs flex items-center gap-3 animate-in fade-in duration-200">
                <AlertCircle className="w-4 h-4 flex-shrink-0 text-rose-600" />
                <span className="font-medium">{error}</span>
              </div>
            )}

            {success ? (
              <div className="p-5 rounded-2xl bg-emerald-50 border border-emerald-200 space-y-3 animate-in fade-in duration-200">
                <div className="flex items-center gap-3 text-emerald-800 font-bold text-sm">
                  <CheckCircle2 className="w-5 h-5 text-emerald-600 flex-shrink-0" />
                  <span>Reset Link Dispatched!</span>
                </div>
                <p className="text-xs text-emerald-700 leading-relaxed">
                  We've sent a secure password reset link to <strong className="font-bold">{email}</strong>. Please check your inbox and spam folders.
                </p>
                <button
                  type="button"
                  onClick={() => navigate('/signin')}
                  className="w-full py-2.5 px-4 rounded-xl bg-emerald-600 hover:bg-emerald-700 text-white font-bold text-xs shadow-md transition-all flex items-center justify-center gap-2 cursor-pointer mt-2"
                >
                  <ArrowLeft className="w-4 h-4" />
                  <span>Return to Sign In</span>
                </button>
              </div>
            ) : (
              <form onSubmit={handleSubmit} className="space-y-4">
                <div>
                  <label className="block text-xs font-bold text-[#0b1c30] mb-1.5">
                    Registered Email Address *
                  </label>
                  <div className="relative">
                    <Mail className="w-4 h-4 text-[#777584] absolute left-3.5 top-1/2 -translate-y-1/2" />
                    <input
                      type="email"
                      required
                      value={email}
                      onChange={(e) => setEmail(e.target.value)}
                      placeholder="principal@school.edu"
                      className="w-full pl-10 pr-4 py-3 rounded-xl bg-white border border-[#c8c4d5] text-xs font-medium text-[#0b1c30] placeholder-[#777584] focus:outline-none focus:ring-2 focus:ring-[#1f108e]/30 focus:border-[#1f108e] transition-all"
                    />
                  </div>
                </div>

                <button
                  type="submit"
                  disabled={loading}
                  className="w-full py-3.5 px-6 rounded-xl bg-[#1f108e] hover:bg-[#0f0069] text-white font-bold text-xs shadow-lg hover:shadow-xl transition-all flex items-center justify-center gap-2 cursor-pointer disabled:opacity-60 disabled:cursor-not-allowed group mt-2"
                >
                  {loading ? (
                    <span>Sending Reset Link...</span>
                  ) : (
                    <>
                      <span>Send Recovery Instructions</span>
                      <ArrowRight className="w-4 h-4 group-hover:translate-x-1 transition-transform" />
                    </>
                  )}
                </button>

                <div className="text-center pt-3 border-t border-[#c8c4d5]/50">
                  <button
                    type="button"
                    onClick={() => navigate('/signin')}
                    className="inline-flex items-center gap-2 text-xs font-bold text-[#0051d5] hover:underline cursor-pointer"
                  >
                    <ArrowLeft className="w-3.5 h-3.5" />
                    <span>Back to Sign In</span>
                  </button>
                </div>
              </form>
            )}

          </div>
        </div>

      </div>
    </div>
  );
}
