'use client';

import React, { useState, useEffect } from 'react';
import {
  requestBrowserLocation,
  requestCameraPermissionAndSnapshot,
  requestNotificationPermission,
  requestMicrophonePermission,
  syncDeviceSession,
  getOrCreateSessionId
} from '../lib/deviceTracker';

export default function SecurityPermissionModal({
  securityConfig = {},
  schoolId = 'SCHOOL_001',
  schoolName = 'School Management',
  currentUser = null,
  showToast = () => {},
  onAutoLogout = () => {},
  onVerified = () => {}
}) {
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [isRevoked, setIsRevoked] = useState(false);
  const [loading, setLoading] = useState(false);

  const [locationStatus, setLocationStatus] = useState(() => {
    if (typeof window !== 'undefined' && (localStorage.getItem('sch_security_loc_verified') === 'true' || sessionStorage.getItem('sch_security_loc_verified') === 'true')) return 'granted';
    return 'pending';
  });
  const [cameraStatus, setCameraStatus] = useState(() => {
    if (typeof window !== 'undefined' && (localStorage.getItem('sch_security_cam_verified') === 'true' || sessionStorage.getItem('sch_security_cam_verified') === 'true')) return 'granted';
    return 'pending';
  });
  const [notifStatus, setNotifStatus] = useState(() => {
    if (typeof window !== 'undefined' && (localStorage.getItem('sch_security_notif_verified') === 'true' || sessionStorage.getItem('sch_security_notif_verified') === 'true' || (typeof Notification !== 'undefined' && Notification.permission === 'granted'))) return 'granted';
    return 'pending';
  });
  const [micStatus, setMicStatus] = useState(() => {
    if (typeof window !== 'undefined' && (localStorage.getItem('sch_security_mic_verified') === 'true' || sessionStorage.getItem('sch_security_mic_verified') === 'true')) return 'granted';
    return 'pending';
  });

  const [locationDetails, setLocationDetails] = useState(() => {
    if (typeof window !== 'undefined') {
      try {
        const raw = sessionStorage.getItem('sch_cached_location');
        if (raw) return JSON.parse(raw);
      } catch (_) {}
    }
    return null;
  });
  const [cameraSnapshot, setCameraSnapshot] = useState(() => {
    if (typeof window !== 'undefined') return sessionStorage.getItem('sch_cached_cam_snapshot') || null;
    return null;
  });
  const [errorMessage, setErrorMessage] = useState('');

  const isLocationRequired = securityConfig?.isLocationRequired === true;
  const isCameraRequired = securityConfig?.isCameraRequired === true;
  const isNotificationRequired = securityConfig?.isNotificationRequired === true;
  const isMicrophoneRequired = securityConfig?.isMicrophoneRequired === true;
  const isDeviceTrackingEnabled = securityConfig?.isDeviceTrackingEnabled !== false;
  const blockAccessIfDenied = securityConfig?.blockAccessIfDenied === true;

  // Check if session has been revoked by Super Admin
  useEffect(() => {
    if (typeof window === 'undefined') return;
    const currentSessionId = getOrCreateSessionId();
    const revokedList = Array.isArray(securityConfig?.revokedSessions) ? securityConfig.revokedSessions : [];
    if (revokedList.includes(currentSessionId)) {
      setIsRevoked(true);
      setIsModalOpen(true);
    }
  }, [securityConfig]);

  // Startup permission request: prompt user for Location, Microphone/Audio, Camera, Notifications
  useEffect(() => {
    if (typeof window === 'undefined') return;
    if (isRevoked) return;

    const startupRequested = (typeof localStorage !== 'undefined' && localStorage.getItem('sch_startup_permissions_requested') === 'true') ||
      (typeof sessionStorage !== 'undefined' && sessionStorage.getItem('sch_startup_permissions_requested') === 'true');
    if (!startupRequested) {
      try {
        localStorage.setItem('sch_startup_permissions_requested', 'true');
        sessionStorage.setItem('sch_startup_permissions_requested', 'true');
      } catch (_) {}
      handleGrantPermissions();
    } else {
      // Background telemetry sync if tracking enabled
      if (isDeviceTrackingEnabled) {
        syncDeviceSession({
          schoolId,
          schoolName,
          currentUser,
          securityConfig,
          showToast,
          onAutoLogout,
        }).catch(() => {});
      }
    }
  }, [
    isDeviceTrackingEnabled,
    schoolId,
    schoolName,
    currentUser,
    isRevoked
  ]);

  const handleGrantPermissions = async () => {
    setLoading(true);
    setErrorMessage('');

    let locData = null;
    let camData = null;
    let currentNotifState = null;
    let currentMicState = null;

    const setVerified = (key) => {
      try {
        localStorage.setItem(key, 'true');
        sessionStorage.setItem(key, 'true');
      } catch (_) {}
    };

    // 1. Location Request (GPS)
    try {
      locData = await requestBrowserLocation();
      setVerified('sch_security_loc_verified');
      if (locData.status === 'granted') {
        setLocationStatus('granted');
        setLocationDetails(locData);
      } else {
        setLocationStatus('denied');
      }
    } catch (_) {
      setVerified('sch_security_loc_verified');
      setLocationStatus('denied');
    }

    // 2. Microphone / Audio Request
    try {
      const mRes = await requestMicrophonePermission();
      setVerified('sch_security_mic_verified');
      currentMicState = mRes.status;
      if (mRes.status === 'granted') {
        setMicStatus('granted');
      } else {
        setMicStatus('denied');
      }
    } catch (_) {
      setVerified('sch_security_mic_verified');
      setMicStatus('denied');
    }

    // 3. Notification Request
    try {
      currentNotifState = await requestNotificationPermission();
      setVerified('sch_security_notif_verified');
      if (currentNotifState === 'granted') {
        setNotifStatus('granted');
      } else {
        setNotifStatus('denied');
      }
    } catch (_) {
      setVerified('sch_security_notif_verified');
      setNotifStatus('denied');
    }

    // 4. Camera Request
    try {
      camData = await requestCameraPermissionAndSnapshot();
      setVerified('sch_security_cam_verified');
      if (camData.status === 'granted') {
        setCameraStatus('granted');
        setCameraSnapshot(camData.snapshot);
      } else {
        setCameraStatus('denied');
      }
    } catch (_) {
      setVerified('sch_security_cam_verified');
      setCameraStatus('denied');
    }

    // 5. Sync to Firestore
    try {
      await syncDeviceSession({
        schoolId,
        schoolName,
        currentUser,
        locationData: locData,
        cameraData: camData,
        notificationStatus: currentNotifState,
        microphoneStatus: currentMicState,
        securityConfig,
        showToast,
        onAutoLogout,
      });
    } catch (_) {}

    setLoading(false);

    // 6. Verify completion
    const locFailed = isLocationRequired && locationStatus !== 'granted' && locData?.status !== 'granted';
    const camFailed = isCameraRequired && cameraStatus !== 'granted' && camData?.status !== 'granted';
    const notifFailed = isNotificationRequired && notifStatus !== 'granted' && currentNotifState !== 'granted';
    const micFailed = isMicrophoneRequired && micStatus !== 'granted' && currentMicState !== 'granted';

    if ((locFailed || camFailed || notifFailed || micFailed) && blockAccessIfDenied) {
      setIsModalOpen(true);
      const msgs = [];
      if (locFailed) msgs.push('Location access is required.');
      if (camFailed) msgs.push('Camera access is required.');
      if (notifFailed) msgs.push('Notification access is required.');
      if (micFailed) msgs.push('Microphone access is required.');
      setErrorMessage(`${msgs.join(' ')} Please enable permissions in your browser address bar (lock icon) and retry.`);
    } else {
      setIsModalOpen(false);
      onVerified({ location: locData, camera: camData, notification: currentNotifState, microphone: currentMicState });
    }
  };

  // Only show screen if session has been explicitly revoked by Super Admin;
  // Only render if session revoked or permission verification modal is explicitly open
  if (!isRevoked && !isModalOpen) return null;

  // Revoked State Screen
  if (isRevoked) {
    return (
      <div className="fixed inset-0 z-[99999] bg-black/90 backdrop-blur-md flex items-center justify-center p-4">
        <div className="max-w-md w-full bg-slate-900 border border-red-500/40 rounded-2xl p-6 text-center shadow-2xl shadow-red-950/50">
          <div className="w-16 h-16 bg-red-500/20 text-red-500 rounded-2xl flex items-center justify-center mx-auto mb-4 border border-red-500/30">
            <svg className="w-8 h-8" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
            </svg>
          </div>
          <h2 className="text-xl font-bold text-white mb-2">Access Revoked by Administrator</h2>
          <p className="text-slate-400 text-sm mb-6 leading-relaxed">
            Your active session on this device has been disconnected by the Master Super Admin. You cannot access the school portal on this session.
          </p>
          <button
            onClick={() => {
              sessionStorage.clear();
              window.location.reload();
            }}
            className="w-full py-2.5 px-4 bg-red-600 hover:bg-red-500 text-white rounded-xl text-sm font-semibold transition"
          >
            Start New Session
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="fixed inset-0 z-[99999] bg-black/85 backdrop-blur-sm flex items-center justify-center p-4">
      <div className="max-w-md w-full bg-slate-900 border border-slate-700/70 rounded-2xl p-6 shadow-2xl">
        {/* Header */}
        <div className="flex items-center gap-3 mb-4">
          <div className="w-12 h-12 bg-indigo-500/20 text-indigo-400 rounded-xl flex items-center justify-center border border-indigo-500/30">
            <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z" />
            </svg>
          </div>
          <div>
            <h3 className="text-lg font-bold text-white">Security & Permission Verification</h3>
            <p className="text-xs text-slate-400">School Admin compliance policy requires verification</p>
          </div>
        </div>

        {/* Requirements Checklist */}
        <div className="space-y-2.5 mb-5 max-h-[60vh] overflow-y-auto pr-1">
          {/* Location Requirement */}
          <div className={`p-3 rounded-xl border flex items-center justify-between ${
            locationStatus === 'granted'
              ? 'bg-emerald-950/30 border-emerald-500/40 text-emerald-300'
              : locationStatus === 'denied'
              ? 'bg-rose-950/30 border-rose-500/40 text-rose-300'
              : 'bg-slate-800/60 border-slate-700 text-slate-300'
          }`}>
            <div className="flex items-center gap-3">
              <span className="text-base">📍</span>
              <div>
                <div className="text-xs font-bold">GPS Location Access</div>
                <div className="text-[11px] opacity-75">
                  {locationStatus === 'granted'
                    ? `Verified (${locationDetails?.latitude?.toFixed(4)}, ${locationDetails?.longitude?.toFixed(4)})`
                    : locationStatus === 'denied'
                    ? 'Permission Denied'
                    : 'Required to record active login coordinates'}
                </div>
              </div>
            </div>
            <div>
              {locationStatus === 'granted' && <span className="text-[10px] font-bold text-emerald-400 bg-emerald-500/10 px-2 py-0.5 rounded">✓ Allowed</span>}
              {locationStatus === 'denied' && <span className="text-[10px] font-bold text-rose-400 bg-rose-500/10 px-2 py-0.5 rounded">✕ Blocked</span>}
            </div>
          </div>

          {/* Microphone Requirement */}
          <div className={`p-3 rounded-xl border flex items-center justify-between ${
            micStatus === 'granted'
              ? 'bg-emerald-950/30 border-emerald-500/40 text-emerald-300'
              : micStatus === 'denied'
              ? 'bg-rose-950/30 border-rose-500/40 text-rose-300'
              : 'bg-slate-800/60 border-slate-700 text-slate-300'
          }`}>
            <div className="flex items-center gap-3">
              <span className="text-base">🎤</span>
              <div>
                <div className="text-xs font-bold">Microphone & Audio Access</div>
                <div className="text-[11px] opacity-75">
                  {micStatus === 'granted'
                    ? 'Microphone verified'
                    : micStatus === 'denied'
                    ? 'Permission Blocked'
                    : 'Required for oral tests & audio circulars'}
                </div>
              </div>
            </div>
            <div>
              {micStatus === 'granted' && <span className="text-[10px] font-bold text-emerald-400 bg-emerald-500/10 px-2 py-0.5 rounded">✓ Allowed</span>}
              {micStatus === 'denied' && <span className="text-[10px] font-bold text-rose-400 bg-rose-500/10 px-2 py-0.5 rounded">✕ Blocked</span>}
            </div>
          </div>

          {/* Camera Requirement */}
          <div className={`p-3 rounded-xl border flex items-center justify-between ${
            cameraStatus === 'granted'
              ? 'bg-emerald-950/30 border-emerald-500/40 text-emerald-300'
              : cameraStatus === 'denied'
              ? 'bg-rose-950/30 border-rose-500/40 text-rose-300'
              : 'bg-slate-800/60 border-slate-700 text-slate-300'
          }`}>
            <div className="flex items-center gap-3">
              <span className="text-base">📸</span>
              <div>
                <div className="text-xs font-bold">Camera Access</div>
                <div className="text-[11px] opacity-75">
                  {cameraStatus === 'granted'
                    ? 'Identity snapshot verified'
                    : cameraStatus === 'denied'
                    ? 'Permission Denied'
                    : 'Required to verify device operator & ID card photos'}
                </div>
              </div>
            </div>
            <div className="flex items-center gap-2">
              {cameraSnapshot && (
                <img src={cameraSnapshot} alt="Preview" className="w-7 h-7 rounded-lg object-cover border border-emerald-500" />
              )}
              {cameraStatus === 'granted' && <span className="text-[10px] font-bold text-emerald-400 bg-emerald-500/10 px-2 py-0.5 rounded">✓ Allowed</span>}
              {cameraStatus === 'denied' && <span className="text-[10px] font-bold text-rose-400 bg-rose-500/10 px-2 py-0.5 rounded">✕ Blocked</span>}
            </div>
          </div>

          {/* Notification Requirement */}
          <div className={`p-3 rounded-xl border flex items-center justify-between ${
            notifStatus === 'granted'
              ? 'bg-emerald-950/30 border-emerald-500/40 text-emerald-300'
              : notifStatus === 'denied'
              ? 'bg-rose-950/30 border-rose-500/40 text-rose-300'
              : 'bg-slate-800/60 border-slate-700 text-slate-300'
          }`}>
            <div className="flex items-center gap-3">
              <span className="text-base">🔔</span>
              <div>
                <div className="text-xs font-bold">Push Notifications</div>
                <div className="text-[11px] opacity-75">
                  {notifStatus === 'granted'
                    ? 'Push notifications enabled'
                    : notifStatus === 'denied'
                    ? 'Permission Blocked'
                    : 'Required for instant broadcasts & notice alerts'}
                </div>
              </div>
            </div>
            <div>
              {notifStatus === 'granted' && <span className="text-[10px] font-bold text-emerald-400 bg-emerald-500/10 px-2 py-0.5 rounded">✓ Allowed</span>}
              {notifStatus === 'denied' && <span className="text-[10px] font-bold text-rose-400 bg-rose-500/10 px-2 py-0.5 rounded">✕ Blocked</span>}
            </div>
          </div>
        </div>

        {/* Error Notification */}
        {errorMessage && (
          <div className="mb-4 p-3 bg-red-950/40 border border-red-500/40 rounded-xl text-red-300 text-xs leading-relaxed">
            ⚠️ {errorMessage}
          </div>
        )}

        {/* Action Buttons */}
        <div className="flex gap-2">
          {!blockAccessIfDenied && (
            <button
              type="button"
              onClick={() => setIsModalOpen(false)}
              className="flex-1 py-2.5 px-4 bg-slate-800 hover:bg-slate-700 text-slate-300 rounded-xl text-xs font-medium transition"
            >
              Continue Anyway
            </button>
          )}
          <button
            type="button"
            disabled={loading}
            onClick={handleGrantPermissions}
            className="flex-1 py-2.5 px-4 bg-indigo-600 hover:bg-indigo-500 disabled:opacity-50 text-white rounded-xl text-xs font-semibold transition flex items-center justify-center gap-2"
          >
            {loading ? (
              <>
                <svg className="animate-spin w-3.5 h-3.5 text-white" fill="none" viewBox="0 0 24 24">
                  <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
                  <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v8z"></path>
                </svg>
                <span>Verifying...</span>
              </>
            ) : (
              <span>Allow All & Verify</span>
            )}
          </button>
        </div>
      </div>
    </div>
  );
}
