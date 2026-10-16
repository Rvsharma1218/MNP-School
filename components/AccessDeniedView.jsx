'use client';

import React from 'react';
import { useSchoolStore } from '../lib/store';
import { ShieldAlert, ArrowLeft } from 'lucide-react';

export default function AccessDeniedView() {
  const { navigate } = useSchoolStore();

  return (
    <div className="min-h-[70vh] flex flex-col items-center justify-center text-center p-6 space-y-5 animate-in fade-in duration-200">
      <div className="w-16 h-16 rounded-full bg-rose-50 text-rose-600 flex items-center justify-center border border-rose-200 shadow-xs">
        <ShieldAlert className="w-8 h-8" />
      </div>

      <div className="space-y-1.5 max-w-md">
        <h2 className="text-xl font-bold text-text">Access Denied</h2>
        <p className="text-xs text-text-secondary leading-relaxed">
          You do not have the required permissions to view this administrative resource. Teacher accounts are restricted from accessing financial management, user administration, and system settings.
        </p>
      </div>

      <button
        onClick={() => navigate('/dashboard')}
        className="px-5 py-2.5 bg-primary hover:bg-primary-dark text-white font-bold text-xs rounded-xl shadow-md transition-all flex items-center gap-1.5 cursor-pointer"
      >
        <ArrowLeft className="w-4 h-4" />
        <span>Return to Dashboard</span>
      </button>
    </div>
  );
}
