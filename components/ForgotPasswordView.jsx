'use client';

import React, { useState } from 'react';
import { useSchoolStore } from '../lib/store';
import {
  School, Mail, ArrowRight, ArrowLeft, CheckCircle2,
  AlertCircle, KeyRound, Phone, ShieldCheck, HelpCircle
} from 'lucide-react';

export default function ForgotPasswordView() {
  const { forgotPassword, navigate, settings } = useSchoolStore();
  const [email, setEmail] = useState('');
  const [error, setError] = useState('');
  const [success, setSuccess] = useState(false);
  const [loading, setLoading] = useState(false);

  const schoolName = settings?.instituteName || settings?.schoolName || 'Mission Navodaya Public School';
  const logoSrc = settings?.logoUrl || settings?.logoPath || settings?.logo || '/logo.png';
  const phone = settings?.phone || '8603481865';
  const officialEmail = settings?.email || 'mnpschooledu@gmail.com';

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
      } else if (err.message?.includes('invalid-email')) {
        setError('Please enter a valid email address.');
      } else {
        setError(err.message || 'Failed to send recovery email. Please check the address.');
      }
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen w-full flex flex-col justify-between font-sans antialiased text-[#0f172a] bg-[#f8fafc] selection:bg-[#0c2340] selection:text-white">
      
      {/* Top Header */}
      <header className="w-full px-6 py-4 md:px-12 flex items-center justify-between border-b border-slate-200/80 bg-white/95 backdrop-blur-md shadow-2xs">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl bg-slate-50 border border-slate-200 p-1 flex items-center justify-center flex-shrink-0 overflow-hidden">
            <img src={logoSrc} alt={schoolName} className="w-full h-full object-contain" />
          </div>
          <div>
            <h1 className="text-base font-black tracking-tight text-[#0c2340]">{schoolName}</h1>
            <p className="text-[11px] text-[#64748b] font-medium">Administrative Security Portal &bull; Mora Bazar</p>
          </div>
        </div>

        <button
          type="button"
          onClick={() => navigate('/signin')}
          className="inline-flex items-center gap-2 px-3.5 py-1.5 rounded-xl bg-slate-100 hover:bg-slate-200 text-xs font-bold text-[#0c2340] transition-all cursor-pointer"
        >
          <ArrowLeft className="w-3.5 h-3.5" />
          <span>Back to Login</span>
        </button>
      </header>

      {/* Main Content Card */}
      <main className="flex-1 w-full flex items-center justify-center p-4 sm:p-8">
        <div className="w-full max-w-md bg-white rounded-3xl border border-slate-200 shadow-xl p-6 sm:p-8 space-y-6 animate-in fade-in zoom-in-95 duration-200">
          
          {/* Title Header */}
          <div className="text-center space-y-2">
            <div className="w-12 h-12 mx-auto rounded-2xl bg-amber-50 border border-amber-200 flex items-center justify-center text-amber-700 shadow-2xs">
              <KeyRound className="w-6 h-6" />
            </div>
            <h2 className="text-xl font-black text-[#0c2340] tracking-tight">
              Password Recovery
            </h2>
            <p className="text-xs text-[#64748b] leading-relaxed max-w-sm mx-auto">
              Enter your registered administrator or official school email to receive a secure password reset link.
            </p>
          </div>

          {/* Success Banner */}
          {success && (
            <div className="p-4 rounded-2xl bg-emerald-50 border border-emerald-200 text-emerald-800 text-xs space-y-2 animate-in fade-in">
              <div className="flex items-center gap-2 font-bold">
                <CheckCircle2 className="w-4 h-4 text-emerald-600 flex-shrink-0" />
                <span>Password Reset Email Sent!</span>
              </div>
              <p className="leading-relaxed text-[11px] text-emerald-700">
                A password reset link has been dispatched to <strong>{email}</strong>. Please check your inbox (and spam folder) and follow the instructions to set a new password.
              </p>
              <div className="pt-2">
                <button
                  type="button"
                  onClick={() => navigate('/signin')}
                  className="w-full py-2 rounded-xl bg-emerald-600 hover:bg-emerald-700 text-white font-bold text-xs transition-all cursor-pointer text-center"
                >
                  Return to Portal Login
                </button>
              </div>
            </div>
          )}

          {/* Error Banner */}
          {error && (
            <div className="p-3.5 rounded-xl bg-rose-50 border border-rose-200 flex items-start gap-2.5 text-rose-700 text-xs animate-in fade-in">
              <AlertCircle className="w-4 h-4 text-rose-600 flex-shrink-0 mt-0.5" />
              <span className="leading-relaxed font-semibold">{error}</span>
            </div>
          )}

          {!success && (
            <form onSubmit={handleSubmit} className="space-y-4">
              <div>
                <label className="block text-xs font-bold text-[#0c2340] mb-1.5">
                  Principal / Official School Email *
                </label>
                <div className="relative">
                  <Mail className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
                  <input
                    type="email"
                    required
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    placeholder="e.g. mnpschooledu@gmail.com"
                    className="w-full pl-10 pr-4 py-3 rounded-xl bg-slate-50 border border-slate-300 text-xs font-medium text-[#0f172a] placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-[#0c2340]/20 focus:border-[#0c2340] transition-all"
                  />
                </div>
              </div>

              <button
                type="submit"
                disabled={loading}
                className="w-full py-3.5 px-6 rounded-xl bg-[#0c2340] hover:bg-[#153459] text-white font-bold text-xs shadow-md hover:shadow-lg transition-all flex items-center justify-center gap-2 cursor-pointer disabled:opacity-60 disabled:cursor-not-allowed"
              >
                {loading ? (
                  <span>Sending Reset Link...</span>
                ) : (
                  <>
                    <span>Send Password Reset Link</span>
                    <ArrowRight className="w-4 h-4" />
                  </>
                )}
              </button>
            </form>
          )}

          {/* Help & Contact Notice */}
          <div className="pt-4 border-t border-slate-100 rounded-2xl bg-slate-50 p-3.5 text-xs text-slate-600 space-y-1.5">
            <div className="flex items-center gap-1.5 font-bold text-[#0c2340]">
              <HelpCircle className="w-3.5 h-3.5 text-amber-600" />
              <span>Need Immediate Assistance?</span>
            </div>
            <p className="text-[11px] leading-relaxed text-slate-500">
              For administrative credential issues or urgent portal assistance, contact the school office:
            </p>
            <div className="pt-1 flex flex-col gap-1 text-[11px] font-semibold text-[#0c2340]">
              <div className="flex items-center gap-1.5">
                <Phone className="w-3 h-3 text-emerald-600" />
                <span>Helpline: +91 {phone}</span>
              </div>
              <div className="flex items-center gap-1.5">
                <Mail className="w-3 h-3 text-blue-600" />
                <span>Email: {officialEmail}</span>
              </div>
            </div>
          </div>

          {/* Back link */}
          <div className="text-center">
            <button
              type="button"
              onClick={() => navigate('/signin')}
              className="text-xs font-bold text-[#0c2340] hover:underline cursor-pointer"
            >
              &larr; Remember your password? Sign in here
            </button>
          </div>

        </div>
      </main>

      {/* Footer */}
      <footer className="w-full px-6 py-4 text-center text-xs text-[#64748b] border-t border-slate-200 bg-white">
        <span>&copy; {new Date().getFullYear()} {schoolName} &bull; Mora Bazar Campus. All Rights Reserved.</span>
      </footer>

    </div>
  );
}
