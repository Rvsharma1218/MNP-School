'use client';

import React, { useState, useEffect } from 'react';
import { db } from '../lib/firebase';
import { collection, doc, onSnapshot, updateDoc, setDoc, serverTimestamp, arrayUnion, arrayRemove } from 'firebase/firestore';
import { useSchoolStore } from '../lib/store';
import {
  Smartphone, Monitor, Tablet, Battery, BatteryCharging,
  Wifi, MapPin, ExternalLink, Shield, ShieldAlert, ShieldCheck,
  Ban, CheckCircle2, Search, RefreshCw, Send, AlertTriangle,
  User, Check, Clock, Radio, Sparkles, Navigation, X
} from 'lucide-react';

export default function ConnectedDevicesView() {
  const { settings, currentUser, showToast } = useSchoolStore();
  const schoolId = settings?.schoolId || settings?.instituteId || currentUser?.schoolId || 'mnp_school';

  const [devices, setDevices] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');
  const [activeFilter, setActiveFilter] = useState('all'); // all, online, teachers, parents, revoked

  // Remote Alert Modal state
  const [alertTarget, setAlertTarget] = useState(null);
  const [alertTitle, setAlertTitle] = useState('Important School Notice');
  const [alertMessage, setAlertMessage] = useState('');
  const [isSendingAlert, setIsSendingAlert] = useState(false);

  // Revoke/Restore Confirmation Modal state
  const [revokeTarget, setRevokeTarget] = useState(null);
  const [isProcessingRevoke, setIsProcessingRevoke] = useState(false);

  useEffect(() => {
    if (!schoolId) {
      setLoading(false);
      return;
    }

    setLoading(true);
    // Listen to real-time device sessions for this school
    const unsub = onSnapshot(
      collection(db, 'schools', schoolId, 'device_sessions'),
      (snapshot) => {
        const rawDocs = snapshot.docs.map(d => ({ id: d.id, ...d.data() }));

        // Deduplicate devices by deviceId or sessionId
        const unique = new Map();
        for (const dev of rawDocs) {
          const key = dev.deviceId || dev.sessionId || dev.id;
          if (!unique.has(key)) {
            unique.set(key, dev);
          }
        }
        setDevices(Array.from(unique.values()));
        setLoading(false);
      },
      (err) => {
        console.error('Error listening to device sessions:', err);
        setLoading(false);
      }
    );

    return () => unsub();
  }, [schoolId]);

  // Open Google Maps
  const handleOpenMaps = (lat, lng) => {
    if (!lat || !lng) return;
    const url = `https://www.google.com/maps?q=${lat},${lng}`;
    window.open(url, '_blank', 'noopener,noreferrer');
  };

  // Send Remote Alert to Device
  const handleSendRemoteAlert = async (e) => {
    e.preventDefault();
    if (!alertTarget || !alertMessage.trim()) return;

    setIsSendingAlert(true);
    try {
      const alertPayload = {
        id: Date.now().toString(),
        title: alertTitle.trim() || 'Notice from School Admin',
        message: alertMessage.trim(),
        sentAt: serverTimestamp(),
        sentBy: currentUser?.displayName || currentUser?.name || 'School Administrator',
      };

      // 1. Update in school collection
      await setDoc(
        doc(db, 'schools', schoolId, 'device_sessions', alertTarget.id),
        { remoteAlert: alertPayload },
        { merge: true }
      );

      // 2. Update in master security sessions
      await setDoc(
        doc(db, 'schoolDirectory', 'system_security_sessions', 'sessions', alertTarget.id),
        { remoteAlert: alertPayload },
        { merge: true }
      );

      if (showToast) showToast('Push alert sent successfully to device!', 'success');
      setAlertTarget(null);
      setAlertMessage('');
    } catch (err) {
      console.error('Error sending alert:', err);
      if (showToast) showToast(`Failed to send alert: ${err.message}`, 'error');
    } finally {
      setIsSendingAlert(false);
    }
  };

  // Block / Revoke Device Access
  const handleToggleRevoke = async () => {
    if (!revokeTarget) return;

    const isCurrentlyRevoked = revokeTarget.status === 'revoked';
    const newStatus = isCurrentlyRevoked ? 'online' : 'revoked';

    setIsProcessingRevoke(true);
    try {
      // 1. Update school doc
      await setDoc(
        doc(db, 'schools', schoolId, 'device_sessions', revokeTarget.id),
        {
          status: newStatus,
          [isCurrentlyRevoked ? 'unrevokedAt' : 'revokedAt']: serverTimestamp(),
          revokedBy: currentUser?.displayName || 'School Administrator',
        },
        { merge: true }
      );

      // 2. Update master security doc
      await setDoc(
        doc(db, 'schoolDirectory', 'system_security_sessions', 'sessions', revokeTarget.id),
        {
          status: newStatus,
          [isCurrentlyRevoked ? 'unrevokedAt' : 'revokedAt']: serverTimestamp(),
        },
        { merge: true }
      );

      // 3. Update global revokedSessions array
      await setDoc(
        doc(db, 'schoolDirectory', 'system_security_control'),
        {
          revokedSessions: isCurrentlyRevoked
            ? arrayRemove(revokeTarget.id)
            : arrayUnion(revokeTarget.id)
        },
        { merge: true }
      );

      if (showToast) {
        showToast(
          isCurrentlyRevoked
            ? '✓ Device access restored successfully!'
            : '🚫 Device has been blocked and access revoked!',
          isCurrentlyRevoked ? 'success' : 'warning'
        );
      }
      setRevokeTarget(null);
    } catch (err) {
      console.error('Error revoking device:', err);
      if (showToast) showToast(`Action failed: ${err.message}`, 'error');
    } finally {
      setIsProcessingRevoke(false);
    }
  };

  // Device Stats
  const now = new Date();
  const onlineCount = devices.filter(d => {
    const isRevoked = d.status === 'revoked';
    const lastActive = d.lastActive?.toDate ? d.lastActive.toDate() : (d.lastActive ? new Date(d.lastActive) : null);
    const isRecent = lastActive && (now - lastActive) < 5 * 60 * 1000;
    return !isRevoked && isRecent && d.status !== 'offline';
  }).length;

  const revokedCount = devices.filter(d => d.status === 'revoked').length;

  // Filtered Devices
  const filteredDevices = devices.filter(d => {
    const isRevoked = d.status === 'revoked';
    const role = (d.userRole || '').toLowerCase();
    const lastActive = d.lastActive?.toDate ? d.lastActive.toDate() : (d.lastActive ? new Date(d.lastActive) : null);
    const isOnline = !isRevoked && lastActive && (now - lastActive) < 5 * 60 * 1000 && d.status !== 'offline';

    if (activeFilter === 'online' && !isOnline) return false;
    if (activeFilter === 'revoked' && !isRevoked) return false;
    if (activeFilter === 'teachers' && !role.includes('teacher')) return false;
    if (activeFilter === 'parents' && !role.includes('parent')) return false;

    if (searchQuery.trim()) {
      const q = searchQuery.toLowerCase();
      const content = `${d.deviceModel || ''} ${d.brand || ''} ${d.userName || ''} ${d.userEmail || ''} ${d.ipAddress || ''} ${d.userRole || ''}`.toLowerCase();
      if (!content.includes(q)) return false;
    }

    return true;
  });

  return (
    <div className="space-y-6">
      {/* ── Top Header Banner ── */}
      <div className="relative overflow-hidden rounded-3xl bg-gradient-to-br from-[#1e3a8a] via-[#1e1b4b] to-[#0f172a] p-6 sm:p-8 text-white shadow-xl">
        <div className="relative z-10 flex flex-col md:flex-row md:items-center justify-between gap-6">
          <div>
            <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-white/10 backdrop-blur-md text-xs font-bold text-teal-300 border border-white/10 mb-3">
              <Radio className="w-3.5 h-3.5 animate-pulse text-teal-400" />
              <span>LIVE TELEMETRY &amp; HARDWARE TRACKING</span>
            </div>
            <h1 className="text-2xl sm:text-3xl font-extrabold tracking-tight">Connected Devices &amp; Live GPS</h1>
            <p className="text-sm text-slate-300 mt-1 max-w-2xl">
              Track installed school app mobile devices in real-time, view live GPS location on Google Maps, monitor battery levels, and manage remote access.
            </p>
          </div>

          {/* Quick Counter Chips */}
          <div className="flex items-center gap-3 flex-wrap">
            <div className="bg-white/10 backdrop-blur-md rounded-2xl px-4 py-2.5 border border-white/10 flex items-center gap-3">
              <div className="p-2 rounded-xl bg-blue-500/20 text-blue-300">
                <Smartphone className="w-5 h-5" />
              </div>
              <div>
                <div className="text-xs text-slate-300 font-medium">Total Registered</div>
                <div className="text-xl font-extrabold text-white">{devices.length}</div>
              </div>
            </div>

            <div className="bg-white/10 backdrop-blur-md rounded-2xl px-4 py-2.5 border border-white/10 flex items-center gap-3">
              <div className="p-2 rounded-xl bg-emerald-500/20 text-emerald-300">
                <span className="w-2.5 h-2.5 rounded-full bg-emerald-400 animate-ping inline-block" />
              </div>
              <div>
                <div className="text-xs text-slate-300 font-medium">Online Now</div>
                <div className="text-xl font-extrabold text-emerald-400">{onlineCount}</div>
              </div>
            </div>

            <div className="bg-white/10 backdrop-blur-md rounded-2xl px-4 py-2.5 border border-white/10 flex items-center gap-3">
              <div className="p-2 rounded-xl bg-red-500/20 text-red-300">
                <Ban className="w-5 h-5" />
              </div>
              <div>
                <div className="text-xs text-slate-300 font-medium">Blocked</div>
                <div className="text-xl font-extrabold text-red-400">{revokedCount}</div>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* ── Search & Filter Controls ── */}
      <div className="bg-white rounded-2xl p-4 shadow-sm border border-slate-200 flex flex-col md:flex-row md:items-center justify-between gap-4">
        {/* Search Bar */}
        <div className="relative flex-1 max-w-md">
          <Search className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400" />
          <input
            type="text"
            placeholder="Search device model, brand, teacher or parent..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full pl-10 pr-4 py-2 text-sm rounded-xl bg-slate-50 border border-slate-200 focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-500 font-medium transition-all"
          />
        </div>

        {/* Filter Pills */}
        <div className="flex items-center gap-2 overflow-x-auto pb-1 md:pb-0">
          {[
            { id: 'all', label: `All (${devices.length})` },
            { id: 'online', label: `🟢 Online (${onlineCount})` },
            { id: 'teachers', label: '👨‍🏫 Teachers' },
            { id: 'parents', label: '👨‍👩‍👧 Parents' },
            { id: 'revoked', label: `🔴 Blocked (${revokedCount})` },
          ].map(f => (
            <button
              key={f.id}
              onClick={() => setActiveFilter(f.id)}
              className={`px-3.5 py-1.5 rounded-xl text-xs font-bold transition-all whitespace-nowrap cursor-pointer ${
                activeFilter === f.id
                  ? 'bg-[#1e3a8a] text-white shadow-sm'
                  : 'bg-slate-100 text-slate-600 hover:bg-slate-200'
              }`}
            >
              {f.label}
            </button>
          ))}
        </div>
      </div>

      {/* ── Devices Grid ── */}
      {loading ? (
        <div className="bg-white rounded-3xl p-16 text-center shadow-sm border border-slate-200">
          <RefreshCw className="w-8 h-8 text-blue-600 animate-spin mx-auto mb-3" />
          <div className="text-sm font-bold text-slate-600">Connecting to Live Device Telemetry...</div>
        </div>
      ) : filteredDevices.length === 0 ? (
        <div className="bg-white rounded-3xl p-16 text-center shadow-sm border border-slate-200">
          <div className="w-16 h-16 rounded-2xl bg-slate-100 text-slate-400 flex items-center justify-center mx-auto mb-4">
            <Smartphone className="w-8 h-8" />
          </div>
          <h3 className="text-base font-bold text-slate-700">No Devices Found</h3>
          <p className="text-xs text-slate-400 max-w-md mx-auto mt-1">
            {devices.length === 0
              ? 'Devices will appear automatically in real-time as teachers, parents and staff log into the MNP School mobile app.'
              : 'No devices match your current search and filter criteria.'}
          </p>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-5">
          {filteredDevices.map(dev => {
            const isRevoked = dev.status === 'revoked';
            const lastActive = dev.lastActive?.toDate ? dev.lastActive.toDate() : (dev.lastActive ? new Date(dev.lastActive) : null);
            const isRecent = lastActive && (now - lastActive) < 5 * 60 * 1000;
            const isOnline = !isRevoked && isRecent && dev.status !== 'offline';

            const lat = typeof dev.latitude === 'number' ? dev.latitude : null;
            const lng = typeof dev.longitude === 'number' ? dev.longitude : null;
            const accuracy = dev.accuracyMeters;
            const batteryLevel = dev.batteryLevel;
            const isCharging = dev.batteryCharging === true;

            const lastLocDate = dev.lastLocationUpdate?.toDate ? dev.lastLocationUpdate.toDate() : (dev.lastLocationUpdate ? new Date(dev.lastLocationUpdate) : null);

            return (
              <div
                key={dev.id}
                className={`bg-white rounded-2xl p-5 shadow-xs border transition-all hover:shadow-md flex flex-col justify-between ${
                  isRevoked
                    ? 'border-red-300 ring-1 ring-red-200'
                    : isOnline
                    ? 'border-emerald-300 ring-1 ring-emerald-200'
                    : 'border-slate-200'
                }`}
              >
                <div>
                  {/* Top Header: Device Icon, Model & Status Pill */}
                  <div className="flex items-start justify-between gap-3">
                    <div className="flex items-center gap-3 min-w-0">
                      <div className={`w-11 h-11 rounded-xl flex items-center justify-center flex-shrink-0 ${
                        isRevoked ? 'bg-red-50 text-red-600' : isOnline ? 'bg-emerald-50 text-emerald-600' : 'bg-slate-100 text-slate-600'
                      }`}>
                        <Smartphone className="w-5 h-5" />
                      </div>
                      <div className="min-w-0">
                        <h4 className="text-sm font-extrabold text-slate-900 truncate" title={dev.deviceModel || 'Mobile Device'}>
                          {dev.deviceModel || 'Android Mobile'}
                        </h4>
                        <div className="flex items-center gap-1.5 mt-0.5">
                          <span className="text-[10px] font-extrabold uppercase px-2 py-0.5 rounded-md bg-blue-50 text-blue-700">
                            {dev.userRole || 'USER'}
                          </span>
                          <span className="text-xs text-slate-500 truncate" title={dev.userName || 'App User'}>
                            {dev.userName || 'App User'}
                          </span>
                        </div>
                      </div>
                    </div>

                    {/* Status Badge */}
                    <div className={`px-2.5 py-1 rounded-full text-[10px] font-black uppercase flex items-center gap-1.5 flex-shrink-0 ${
                      isRevoked
                        ? 'bg-red-100 text-red-700'
                        : isOnline
                        ? 'bg-emerald-100 text-emerald-700'
                        : 'bg-slate-100 text-slate-600'
                    }`}>
                      <span className={`w-2 h-2 rounded-full ${
                        isRevoked ? 'bg-red-500' : isOnline ? 'bg-emerald-500' : 'bg-slate-400'
                      }`} />
                      <span>{isRevoked ? 'BLOCKED' : isOnline ? 'ONLINE' : 'OFFLINE'}</span>
                    </div>
                  </div>

                  {/* Hardware & Battery Telemetry Chips */}
                  <div className="mt-4 flex flex-wrap gap-2">
                    {/* Battery */}
                    <div className={`inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg text-xs font-bold ${
                      batteryLevel != null
                        ? isCharging
                          ? 'bg-teal-50 text-teal-700 border border-teal-200'
                          : batteryLevel < 20
                          ? 'bg-red-50 text-red-700 border border-red-200'
                          : 'bg-slate-50 text-slate-700 border border-slate-200'
                        : 'bg-slate-50 text-slate-400 border border-slate-200'
                    }`}>
                      {isCharging ? <BatteryCharging className="w-3.5 h-3.5 text-teal-600" /> : <Battery className="w-3.5 h-3.5" />}
                      <span>{batteryLevel != null ? `${batteryLevel}%${isCharging ? ' ⚡' : ''}` : 'Battery N/A'}</span>
                    </div>

                    {/* IP Address */}
                    <div className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg text-xs font-bold bg-slate-50 text-slate-700 border border-slate-200">
                      <Wifi className="w-3.5 h-3.5 text-slate-500" />
                      <span>{dev.ipAddress || 'IP N/A'}</span>
                    </div>

                    {/* Android Version */}
                    {dev.androidVersion && (
                      <div className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg text-xs font-bold bg-emerald-50 text-emerald-700 border border-emerald-200">
                        <span>Android {dev.androidVersion}</span>
                      </div>
                    )}

                    {/* Last Active */}
                    <div className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg text-xs font-medium bg-slate-50 text-slate-500 border border-slate-200">
                      <Clock className="w-3.5 h-3.5" />
                      <span>
                        {lastActive ? `${lastActive.toLocaleDateString([], { day: '2-digit', month: 'short' })}, ${lastActive.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}` : 'Recently'}
                      </span>
                    </div>
                  </div>

                  {/* Live GPS Tracking Box */}
                  <div className={`mt-4 rounded-xl p-3 border flex items-center justify-between gap-3 ${
                    lat != null
                      ? 'bg-teal-50/70 border-teal-200'
                      : 'bg-amber-50/60 border-amber-200'
                  }`}>
                    <div className="flex items-center gap-2.5 min-w-0">
                      <div className={`p-2 rounded-lg flex-shrink-0 ${
                        lat != null ? 'bg-teal-100 text-teal-700' : 'bg-amber-100 text-amber-700'
                      }`}>
                        <MapPin className="w-4 h-4" />
                      </div>
                      <div className="min-w-0">
                        <div className={`text-xs font-extrabold flex items-center gap-1.5 ${
                          lat != null ? 'text-teal-900' : 'text-amber-900'
                        }`}>
                          <span>{lat != null ? 'Live GPS Coordinates' : 'GPS Offline'}</span>
                          {lastLocDate && (
                            <span className="text-[10px] font-normal text-slate-500">
                              • {lastLocDate.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                            </span>
                          )}
                        </div>
                        <div className={`text-[11px] truncate mt-0.5 ${
                          lat != null ? 'text-teal-800' : 'text-amber-800'
                        }`}>
                          {lat != null
                            ? `${lat.toFixed(5)}, ${lng?.toFixed(5)}${accuracy != null ? ` (±${accuracy}m)` : ''}`
                            : 'Auto-updates whenever user turns on GPS'}
                        </div>
                      </div>
                    </div>

                    {lat != null && lng != null && (
                      <button
                        onClick={() => handleOpenMaps(lat, lng)}
                        className="px-2.5 py-1.5 rounded-lg bg-teal-700 hover:bg-teal-800 text-white text-xs font-bold transition-all flex items-center gap-1.5 flex-shrink-0 cursor-pointer shadow-xs"
                        title="Open on Google Maps"
                      >
                        <Navigation className="w-3.5 h-3.5" />
                        <span>Maps</span>
                      </button>
                    )}
                  </div>
                </div>

                {/* Bottom Actions Row */}
                <div className="mt-5 pt-3 border-t border-slate-100 flex items-center gap-2">
                  <button
                    onClick={() => {
                      setAlertTarget(dev);
                      setAlertTitle('Urgent Notice from School Admin');
                      setAlertMessage('');
                    }}
                    className="flex-1 py-2 px-3 rounded-xl bg-slate-100 hover:bg-slate-200 text-slate-700 text-xs font-bold transition-all flex items-center justify-center gap-1.5 cursor-pointer"
                  >
                    <Send className="w-3.5 h-3.5 text-blue-600" />
                    <span>Send Alert</span>
                  </button>

                  <button
                    onClick={() => setRevokeTarget(dev)}
                    className={`flex-1 py-2 px-3 rounded-xl text-xs font-bold transition-all flex items-center justify-center gap-1.5 cursor-pointer ${
                      isRevoked
                        ? 'bg-emerald-600 hover:bg-emerald-700 text-white shadow-xs'
                        : 'bg-red-600 hover:bg-red-700 text-white shadow-xs'
                    }`}
                  >
                    {isRevoked ? <CheckCircle2 className="w-3.5 h-3.5" /> : <Ban className="w-3.5 h-3.5" />}
                    <span>{isRevoked ? 'Restore Access' : 'Block Device'}</span>
                  </button>
                </div>
              </div>
            );
          })}
        </div>
      )}

      {/* ── Modal 1: Send Remote Push Alert ── */}
      {alertTarget && (
        <div className="fixed inset-0 bg-black/60 z-50 flex items-center justify-center p-4 backdrop-blur-xs">
          <div className="bg-white rounded-3xl w-full max-w-md p-6 shadow-2xl border border-slate-100">
            <div className="flex items-center justify-between pb-4 border-b border-slate-100">
              <div className="flex items-center gap-3">
                <div className="p-2.5 rounded-xl bg-amber-50 text-amber-600">
                  <Send className="w-5 h-5" />
                </div>
                <div>
                  <h3 className="font-extrabold text-base text-slate-900">Send Remote Push Alert</h3>
                  <p className="text-xs text-slate-500 truncate max-w-xs">{alertTarget.deviceModel || 'Mobile Device'}</p>
                </div>
              </div>
              <button
                onClick={() => setAlertTarget(null)}
                className="p-1.5 rounded-lg hover:bg-slate-100 text-slate-400 hover:text-slate-600 cursor-pointer"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <form onSubmit={handleSendRemoteAlert} className="mt-4 space-y-4">
              <div>
                <label className="block text-xs font-bold text-slate-700 mb-1">Alert Title</label>
                <input
                  type="text"
                  value={alertTitle}
                  onChange={(e) => setAlertTitle(e.target.value)}
                  placeholder="e.g. Urgent Notice from School"
                  className="w-full px-3 py-2 text-sm rounded-xl bg-slate-50 border border-slate-200 focus:outline-none focus:ring-2 focus:ring-blue-500/20 font-medium"
                />
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-700 mb-1">Message Body</label>
                <textarea
                  rows={3}
                  value={alertMessage}
                  onChange={(e) => setAlertMessage(e.target.value)}
                  placeholder="Type the message to be displayed as an instant pop-up on this mobile device..."
                  required
                  className="w-full px-3 py-2 text-sm rounded-xl bg-slate-50 border border-slate-200 focus:outline-none focus:ring-2 focus:ring-blue-500/20 font-medium"
                />
              </div>

              <div className="flex items-center justify-end gap-2 pt-2">
                <button
                  type="button"
                  onClick={() => setAlertTarget(null)}
                  className="px-4 py-2 rounded-xl text-xs font-bold text-slate-600 hover:bg-slate-100 cursor-pointer"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={isSendingAlert || !alertMessage.trim()}
                  className="px-5 py-2 rounded-xl text-xs font-bold bg-[#1e3a8a] hover:bg-blue-900 text-white shadow-md transition-all cursor-pointer disabled:opacity-50 flex items-center gap-2"
                >
                  {isSendingAlert ? <RefreshCw className="w-3.5 h-3.5 animate-spin" /> : <Send className="w-3.5 h-3.5" />}
                  <span>Send Alert Now</span>
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* ── Modal 2: Confirm Block / Restore Access ── */}
      {revokeTarget && (
        <div className="fixed inset-0 bg-black/60 z-50 flex items-center justify-center p-4 backdrop-blur-xs">
          <div className="bg-white rounded-3xl w-full max-w-md p-6 shadow-2xl border border-slate-100">
            <div className="flex items-center gap-3 mb-4">
              <div className={`p-3 rounded-2xl ${
                revokeTarget.status === 'revoked' ? 'bg-emerald-50 text-emerald-600' : 'bg-red-50 text-red-600'
              }`}>
                {revokeTarget.status === 'revoked' ? <ShieldCheck className="w-6 h-6" /> : <ShieldAlert className="w-6 h-6" />}
              </div>
              <div>
                <h3 className="font-extrabold text-base text-slate-900">
                  {revokeTarget.status === 'revoked' ? 'Restore Device Access?' : 'Block / Revoke Device?'}
                </h3>
                <p className="text-xs text-slate-500">{revokeTarget.deviceModel || 'Mobile Device'}</p>
              </div>
            </div>

            <p className="text-xs leading-relaxed text-slate-600 mb-6">
              {revokeTarget.status === 'revoked'
                ? `Are you sure you want to restore access for ${revokeTarget.userName || 'this device'}? The user will immediately be permitted to use the MNP School app again.`
                : `Are you sure you want to block ${revokeTarget.userName || 'this device'}? The device will be immediately locked out and denied access to all school databases.`}
            </p>

            <div className="flex items-center justify-end gap-2">
              <button
                type="button"
                onClick={() => setRevokeTarget(null)}
                className="px-4 py-2 rounded-xl text-xs font-bold text-slate-600 hover:bg-slate-100 cursor-pointer"
              >
                Cancel
              </button>
              <button
                type="button"
                onClick={handleToggleRevoke}
                disabled={isProcessingRevoke}
                className={`px-5 py-2 rounded-xl text-xs font-bold text-white shadow-md transition-all cursor-pointer flex items-center gap-2 ${
                  revokeTarget.status === 'revoked'
                    ? 'bg-emerald-600 hover:bg-emerald-700'
                    : 'bg-red-600 hover:bg-red-700'
                }`}
              >
                {isProcessingRevoke ? <RefreshCw className="w-3.5 h-3.5 animate-spin" /> : null}
                <span>{revokeTarget.status === 'revoked' ? 'Restore Access' : 'Block Device'}</span>
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
