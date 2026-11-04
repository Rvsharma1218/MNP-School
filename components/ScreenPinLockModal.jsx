'use client';

import React, { useState, useEffect, useCallback, useRef } from 'react';
import { Lock, Unlock, ShieldCheck, LogOut, KeyRound, AlertCircle, Building2 } from 'lucide-react';
import { useSchoolStore } from '../lib/store';

export function lockScreenNow() {
  if (typeof window !== 'undefined') {
    try {
      sessionStorage.setItem('sch_screen_locked', 'true');
    } catch (_) {}
    window.dispatchEvent(new CustomEvent('sch_lock_screen'));
  }
}

export function getStoredScreenPin(currentUser, settings) {
  if (typeof window === 'undefined') return '1234';
  try {
    const local = localStorage.getItem('sch_screen_pin');
    if (local && local.trim().length === 4) return local.trim();
  } catch (_) {}
  if (currentUser?.screenLockPin && String(currentUser.screenLockPin).trim().length === 4) {
    return String(currentUser.screenLockPin).trim();
  }
  if (settings?.screenLockPin && String(settings.screenLockPin).trim().length === 4) {
    return String(settings.screenLockPin).trim();
  }
  return '1234';
}

export default function ScreenPinLockModal() {
  const { currentUser, settings, logout, showToast } = useSchoolStore();
  const [isLocked, setIsLocked] = useState(false);
  const [pin, setPin] = useState('');
  const [errorMsg, setErrorMsg] = useState('');
  const [shake, setShake] = useState(false);
  const [isSuccess, setIsSuccess] = useState(false);
  const lastActivityRef = useRef(Date.now());

  // Check initial lock state
  useEffect(() => {
    if (typeof window === 'undefined') return;
    try {
      if (sessionStorage.getItem('sch_screen_locked') === 'true') {
        setIsLocked(true);
      }
    } catch (_) {}

    const handleLockEvent = () => {
      setIsLocked(true);
      setPin('');
      setErrorMsg('');
      try {
        sessionStorage.setItem('sch_screen_locked', 'true');
      } catch (_) {}
    };

    window.addEventListener('sch_lock_screen', handleLockEvent);
    return () => window.removeEventListener('sch_lock_screen', handleLockEvent);
  }, []);

  // Inactivity Auto-Lock Timer
  useEffect(() => {
    if (typeof window === 'undefined') return;

    const resetActivity = () => {
      lastActivityRef.current = Date.now();
    };

    const events = ['mousedown', 'mousemove', 'keydown', 'scroll', 'touchstart'];
    events.forEach(e => window.addEventListener(e, resetActivity, { passive: true }));

    const checkInterval = setInterval(() => {
      try {
        const timeoutMins = Number(localStorage.getItem('sch_autolock_minutes') || 0);
        if (timeoutMins > 0 && !isLocked) {
          const elapsedMs = Date.now() - lastActivityRef.current;
          if (elapsedMs >= timeoutMins * 60 * 1000) {
            lockScreenNow();
          }
        }
      } catch (_) {}
    }, 15000);

    return () => {
      events.forEach(e => window.removeEventListener(e, resetActivity));
      clearInterval(checkInterval);
    };
  }, [isLocked]);

  const expectedPin = getStoredScreenPin(currentUser, settings);

  const handleDigit = useCallback((digit) => {
    if (pin.length >= 4) return;
    setErrorMsg('');
    const newPin = pin + digit;
    setPin(newPin);

    if (newPin.length === 4) {
      if (newPin === expectedPin) {
        setIsSuccess(true);
        setTimeout(() => {
          setIsLocked(false);
          setPin('');
          setIsSuccess(false);
          setErrorMsg('');
          try {
            sessionStorage.removeItem('sch_screen_locked');
          } catch (_) {}
        }, 300);
      } else {
        setShake(true);
        setErrorMsg('Invalid Security PIN. Please try again.');
        setTimeout(() => {
          setShake(false);
          setPin('');
        }, 500);
      }
    }
  }, [pin, expectedPin]);

  const handleBackspace = useCallback(() => {
    if (pin.length > 0) {
      setPin(prev => prev.slice(0, -1));
      setErrorMsg('');
    }
  }, [pin]);

  // Physical keyboard support
  useEffect(() => {
    if (!isLocked) return;

    const handleKeyDown = (e) => {
      if (e.key >= '0' && e.key <= '9') {
        e.preventDefault();
        handleDigit(e.key);
      } else if (e.key === 'Backspace') {
        e.preventDefault();
        handleBackspace();
      } else if (e.key === 'Escape') {
        e.preventDefault();
        setPin('');
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [isLocked, handleDigit, handleBackspace]);

  if (!isLocked) return null;

  const schoolName = settings.instituteName || settings.schoolName || 'School Management';
  const userName = currentUser?.name || currentUser?.displayName || (currentUser?.role === 'principal' ? 'Principal' : 'Faculty Teacher');
  const userRole = currentUser?.role === 'principal' ? 'Principal / Super Admin' : 'Class Teacher / Faculty';

  return (
    <div className="fixed inset-0 z-[99999] bg-[#0b1329]/95 backdrop-blur-xl flex items-center justify-center p-4 animate-in fade-in duration-200 font-sans select-none">
      <div className={`w-full max-w-sm bg-white dark:bg-[#131d38] border border-white/20 dark:border-blue-900/40 rounded-3xl p-6 sm:p-7 shadow-2xl flex flex-col items-center text-center transition-transform ${shake ? 'animate-bounce text-rose-500' : ''}`}>
        
        {/* School Logo / Icon */}
        <div className="w-16 h-16 rounded-2xl bg-gradient-to-tr from-[#1f108e] to-[#316bf3] text-white flex items-center justify-center shadow-lg shadow-blue-500/30 mb-3 border border-white/20">
          {settings.logoUrl || settings.logo ? (
            <img src={settings.logoUrl || settings.logo} alt="Logo" className="w-11 h-11 object-contain rounded-xl" />
          ) : (
            <ShieldCheck className="w-8 h-8 text-white" />
          )}
        </div>

        <h2 className="text-base font-black text-slate-800 dark:text-white tracking-tight line-clamp-1">
          {schoolName}
        </h2>
        <div className="flex items-center gap-1.5 mt-0.5 text-xs text-slate-500 dark:text-slate-400 font-medium">
          <Lock className="w-3.5 h-3.5 text-amber-500" />
          <span>Screen Locked • सुरक्षा लॉक</span>
        </div>

        {/* User Badge */}
        <div className="mt-3 px-3 py-1.5 rounded-xl bg-slate-100 dark:bg-slate-800/80 border border-slate-200 dark:border-slate-700/60 w-full text-left flex items-center justify-between">
          <div className="min-w-0">
            <div className="text-xs font-bold text-slate-800 dark:text-slate-200 truncate">{userName}</div>
            <div className="text-[10px] text-slate-500 dark:text-slate-400 font-medium capitalize truncate">{userRole}</div>
          </div>
          <span className="w-2 h-2 rounded-full bg-emerald-500 ring-2 ring-emerald-500/30 shrink-0" />
        </div>

        {/* PIN Dots */}
        <div className="my-5 flex items-center justify-center gap-3.5">
          {[0, 1, 2, 3].map(idx => {
            const isFilled = pin.length > idx;
            return (
              <div
                key={idx}
                className={`w-3.5 h-3.5 rounded-full transition-all duration-150 ${
                  isSuccess
                    ? 'bg-emerald-500 ring-4 ring-emerald-500/30 scale-110'
                    : isFilled
                      ? 'bg-[#1f108e] dark:bg-blue-400 ring-4 ring-blue-500/20 scale-110'
                      : 'border-2 border-slate-300 dark:border-slate-600 bg-transparent'
                }`}
              />
            );
          })}
        </div>

        {errorMsg ? (
          <div className="text-[11px] font-bold text-rose-500 flex items-center gap-1 mb-3 animate-in fade-in">
            <AlertCircle className="w-3.5 h-3.5 shrink-0" />
            <span>{errorMsg}</span>
          </div>
        ) : (
          <div className="text-[11px] text-slate-400 dark:text-slate-500 mb-3">
            Enter 4-digit Screen Lock PIN (Default: 1234)
          </div>
        )}

        {/* Numeric Keypad */}
        <div className="grid grid-cols-3 gap-2 w-full max-w-[260px] mb-4">
          {[1, 2, 3, 4, 5, 6, 7, 8, 9].map(num => (
            <button
              key={num}
              type="button"
              onClick={() => handleDigit(String(num))}
              className="h-11 rounded-xl bg-slate-100 hover:bg-slate-200 dark:bg-slate-800/80 dark:hover:bg-slate-700 font-mono font-bold text-lg text-slate-800 dark:text-slate-100 active:scale-95 transition-all cursor-pointer border border-slate-200/80 dark:border-slate-700/50"
            >
              {num}
            </button>
          ))}
          <button
            type="button"
            onClick={() => setPin('')}
            className="h-11 rounded-xl bg-slate-50 hover:bg-slate-100 dark:bg-slate-800/40 dark:hover:bg-slate-700/60 font-bold text-[11px] text-slate-500 dark:text-slate-400 active:scale-95 transition-all cursor-pointer border border-slate-200/50 dark:border-slate-700/30"
          >
            Clear
          </button>
          <button
            type="button"
            onClick={() => handleDigit('0')}
            className="h-11 rounded-xl bg-slate-100 hover:bg-slate-200 dark:bg-slate-800/80 dark:hover:bg-slate-700 font-mono font-bold text-lg text-slate-800 dark:text-slate-100 active:scale-95 transition-all cursor-pointer border border-slate-200/80 dark:border-slate-700/50"
          >
            0
          </button>
          <button
            type="button"
            onClick={handleBackspace}
            className="h-11 rounded-xl bg-slate-50 hover:bg-slate-100 dark:bg-slate-800/40 dark:hover:bg-slate-700/60 font-bold text-xs text-rose-500 active:scale-95 transition-all cursor-pointer border border-slate-200/50 dark:border-slate-700/30 flex items-center justify-center"
          >
            ⌫
          </button>
        </div>

        {/* Footer Actions: Forgot / Switch Account / Logout */}
        <div className="flex items-center justify-between w-full pt-3 border-t border-slate-200/60 dark:border-slate-700/60 text-xs text-slate-500">
          <button
            type="button"
            onClick={() => {
              if (window.confirm('Resetting PIN requires logging out and signing in again. Continue?')) {
                try {
                  sessionStorage.removeItem('sch_screen_locked');
                } catch (_) {}
                setIsLocked(false);
                logout();
              }
            }}
            className="hover:text-blue-500 font-semibold cursor-pointer transition-colors"
          >
            Forgot PIN?
          </button>

          <button
            type="button"
            onClick={() => {
              try {
                sessionStorage.removeItem('sch_screen_locked');
              } catch (_) {}
              setIsLocked(false);
              logout();
            }}
            className="flex items-center gap-1 text-rose-500 hover:text-rose-600 font-bold cursor-pointer transition-colors"
          >
            <LogOut className="w-3.5 h-3.5" />
            <span>Sign Out</span>
          </button>
        </div>
      </div>
    </div>
  );
}
