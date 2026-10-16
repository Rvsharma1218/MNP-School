'use client';

import React from 'react';
import { useSchoolStore } from '../lib/store';
import { CheckCircle2, AlertCircle, AlertTriangle, Info, X, Trash2 } from 'lucide-react';

export function ToastContainer() {
  const { toasts, removeToast } = useSchoolStore();

  if (!toasts || toasts.length === 0) return null;

  return (
    <div className="fixed top-5 right-5 z-[100] flex flex-col gap-2.5 max-w-sm w-full pointer-events-none font-sans">
      {toasts.map((t) => {
        let bg = 'bg-[#0f172a] text-white border-[#334155]';
        let Icon = CheckCircle2;
        let iconColor = 'text-emerald-400';
        let barColor = 'bg-emerald-500';

        if (t.type === 'error' || t.type === 'danger') {
          bg = 'bg-[#1e1014] text-white border-rose-500/40';
          Icon = AlertCircle;
          iconColor = 'text-rose-400';
          barColor = 'bg-rose-500';
        } else if (t.type === 'warning') {
          bg = 'bg-[#1e1708] text-white border-amber-500/40';
          Icon = AlertTriangle;
          iconColor = 'text-amber-400';
          barColor = 'bg-amber-500';
        } else if (t.type === 'info') {
          bg = 'bg-[#0c192e] text-white border-indigo-500/40';
          Icon = Info;
          iconColor = 'text-indigo-400';
          barColor = 'bg-indigo-500';
        }

        return (
          <div
            key={t.id}
            className={`pointer-events-auto border rounded-2xl shadow-2xl p-4 flex items-start gap-3 relative overflow-hidden animate-in slide-in-from-top-4 fade-in duration-250 backdrop-blur-md ${bg}`}
          >
            <div className="mt-0.5 shrink-0">
              <Icon className={`w-5 h-5 ${iconColor}`} />
            </div>
            
            <div className="flex-1 pr-2">
              <p className="text-xs font-semibold leading-snug">{t.message}</p>
            </div>

            <button
              onClick={() => removeToast(t.id)}
              className="text-slate-400 hover:text-white p-0.5 rounded-lg transition-colors cursor-pointer shrink-0"
            >
              <X className="w-4 h-4" />
            </button>

            {/* Bottom Accent Bar */}
            <div className={`absolute bottom-0 left-0 right-0 h-0.5 ${barColor}`} />
          </div>
        );
      })}
    </div>
  );
}

export function ConfirmDialog() {
  const { confirmDialog } = useSchoolStore();

  if (!confirmDialog) return null;

  const {
    title = 'Are you sure?',
    message = 'Are you sure you want to proceed? This action cannot be reversed.',
    confirmText = 'Yes, Delete',
    cancelText = 'No, Cancel',
    type = 'danger',
    onConfirm,
    onCancel
  } = confirmDialog;

  const isDanger = type === 'danger';
  const isWarning = type === 'warning';

  return (
    <div className="fixed inset-0 z-[110] flex items-center justify-center p-4 bg-black/70 backdrop-blur-xs animate-in fade-in duration-150 font-sans">
      <div className="bg-[#0f172a] text-white border border-[#1e293b] rounded-3xl w-full max-w-md shadow-2xl overflow-hidden animate-in zoom-in-95 duration-200">
        
        <div className="p-6 space-y-4">
          <div className="flex items-center gap-3.5">
            <div className={`w-11 h-11 rounded-2xl flex items-center justify-center shrink-0 ${
              isDanger ? 'bg-rose-500/10 text-rose-400 border border-rose-500/20' : 
              isWarning ? 'bg-amber-500/10 text-amber-400 border border-amber-500/20' : 
              'bg-indigo-500/10 text-indigo-400 border border-indigo-500/20'
            }`}>
              {isDanger ? <Trash2 className="w-5 h-5" /> : <AlertTriangle className="w-5 h-5" />}
            </div>

            <div>
              <h3 className="text-base font-bold text-white tracking-tight">{title}</h3>
              <p className="text-xs text-slate-400 mt-0.5">Please confirm this action</p>
            </div>
          </div>

          <div className="bg-[#1e293b]/60 border border-[#334155] rounded-xl p-3.5 text-xs text-slate-300 leading-relaxed">
            {message}
          </div>

          <div className="flex items-center justify-end gap-2.5 pt-2">
            <button
              type="button"
              onClick={onCancel}
              className="px-4 py-2.5 rounded-xl bg-[#1e293b] hover:bg-[#334155] text-slate-300 hover:text-white text-xs font-bold transition-colors cursor-pointer"
            >
              {cancelText}
            </button>

            <button
              type="button"
              onClick={onConfirm}
              className={`px-5 py-2.5 rounded-xl text-white text-xs font-bold shadow-md transition-all cursor-pointer ${
                isDanger
                  ? 'bg-rose-600 hover:bg-rose-500 shadow-rose-600/20'
                  : isWarning
                  ? 'bg-amber-600 hover:bg-amber-500 shadow-amber-600/20'
                  : 'bg-indigo-600 hover:bg-indigo-500 shadow-indigo-600/20'
              }`}
            >
              {confirmText}
            </button>
          </div>
        </div>

      </div>
    </div>
  );
}
