'use client';

import React, { useState, useEffect } from 'react';
import { getDeviceNotificationHistory } from '../lib/deviceTracker';

export default function NotificationHistoryModal({
  isOpen = false,
  onClose = () => {},
}) {
  const [notifications, setNotifications] = useState([]);

  useEffect(() => {
    if (isOpen) {
      setNotifications(getDeviceNotificationHistory());
    }

    const handleNew = () => {
      setNotifications(getDeviceNotificationHistory());
    };

    if (typeof window !== 'undefined') {
      window.addEventListener('school_new_notification', handleNew);
    }
    return () => {
      if (typeof window !== 'undefined') {
        window.removeEventListener('school_new_notification', handleNew);
      }
    };
  }, [isOpen]);

  if (!isOpen) return null;

  const clearHistory = () => {
    try {
      sessionStorage.removeItem('sch_device_notifications');
      setNotifications([]);
    } catch (_) {}
  };

  return (
    <div className="fixed inset-0 z-[99999] bg-black/80 backdrop-blur-sm flex items-center justify-center p-4">
      <div className="max-w-md w-full bg-slate-900 border border-slate-700/80 rounded-2xl p-5 shadow-2xl flex flex-col max-h-[85vh]">
        {/* Header */}
        <div className="flex items-center justify-between pb-3 border-b border-slate-800">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 bg-amber-500/20 text-amber-400 rounded-xl flex items-center justify-center text-lg">
              📢
            </div>
            <div>
              <h3 className="text-base font-bold text-white">Device Alerts History</h3>
              <p className="text-xs text-slate-400">Broadcasts & notices from School Admin</p>
            </div>
          </div>
          <button
            onClick={onClose}
            className="text-slate-400 hover:text-white p-1 rounded-lg hover:bg-slate-800 transition"
          >
            ✕
          </button>
        </div>

        {/* Content list */}
        <div className="flex-1 overflow-y-auto py-3 space-y-2.5 pr-1">
          {notifications.length === 0 ? (
            <div className="text-center py-10 text-slate-500 text-xs">
              <span className="text-3xl block mb-2 opacity-50">📭</span>
              No administrative alerts received on this device yet.
            </div>
          ) : (
            notifications.map((item, idx) => (
              <div
                key={item.id || idx}
                className="p-3 bg-slate-950/60 border border-slate-800/80 rounded-xl hover:border-amber-500/30 transition"
              >
                <div className="flex items-start justify-between gap-2 mb-1">
                  <h4 className="text-xs font-bold text-amber-400 flex items-center gap-1.5">
                    <span>🔔</span> {item.title || 'Notice'}
                  </h4>
                  <span className="text-[10px] text-slate-500 whitespace-nowrap">
                    {item.receivedAt ? new Date(item.receivedAt).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) : ''}
                  </span>
                </div>
                <p className="text-xs text-slate-300 leading-relaxed">{item.message}</p>
              </div>
            ))
          )}
        </div>

        {/* Footer */}
        <div className="pt-3 border-t border-slate-800 flex justify-between items-center text-xs">
          {notifications.length > 0 ? (
            <button
              onClick={clearHistory}
              className="text-rose-400 hover:text-rose-300 hover:underline"
            >
              Clear Logs
            </button>
          ) : (
            <span />
          )}
          <button
            onClick={onClose}
            className="px-4 py-2 bg-slate-800 hover:bg-slate-700 text-white rounded-xl font-medium transition"
          >
            Close
          </button>
        </div>
      </div>
    </div>
  );
}
