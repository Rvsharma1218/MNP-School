'use client';

import { db } from './firebase';
import { doc, setDoc, updateDoc, onSnapshot, serverTimestamp, increment, arrayUnion } from 'firebase/firestore';

/**
 * Detect Detailed Device Information
 */
export function getClientDeviceInfo() {
  if (typeof window === 'undefined') {
    return {
      deviceType: 'unknown',
      os: 'unknown',
      browser: 'unknown',
      screenResolution: 'N/A',
      windowSize: 'N/A',
      language: 'en',
      timezone: 'UTC',
      userAgent: '',
    };
  }

  const ua = navigator.userAgent || '';
  let os = 'Unknown OS';
  if (/windows phone/i.test(ua)) os = 'Windows Phone';
  else if (/win(dows )?nt 10\.0/i.test(ua)) os = 'Windows 10/11';
  else if (/win(dows )?nt 6\.3/i.test(ua)) os = 'Windows 8.1';
  else if (/win(dows )?nt 6\.2/i.test(ua)) os = 'Windows 8';
  else if (/win(dows )?nt 6\.1/i.test(ua)) os = 'Windows 7';
  else if (/windows/i.test(ua)) os = 'Windows';
  else if (/android/i.test(ua)) {
    const match = ua.match(/android\s([0-9\.]*)/i);
    os = match ? `Android ${match[1]}` : 'Android';
  } else if (/iphone/i.test(ua)) os = 'iOS (iPhone)';
  else if (/ipad/i.test(ua)) os = 'iOS (iPad)';
  else if (/macintosh|mac os x/i.test(ua)) os = 'macOS';
  else if (/linux/i.test(ua)) os = 'Linux';
  else if (/cros/i.test(ua)) os = 'Chrome OS';

  let browser = 'Unknown Browser';
  if (/edg([ea]|ios)?\/([0-9\.]+)/i.test(ua)) {
    const m = ua.match(/edg([ea]|ios)?\/([0-9\.]+)/i);
    browser = `Edge ${m ? m[2].split('.')[0] : ''}`;
  } else if (/opr\/|opera\//i.test(ua)) {
    const m = ua.match(/(?:opr|opera)\/([0-9\.]+)/i);
    browser = `Opera ${m ? m[1].split('.')[0] : ''}`;
  } else if (/chrome|crios/i.test(ua) && !/edg|opr/i.test(ua)) {
    const m = ua.match(/(?:chrome|crios)\/([0-9\.]+)/i);
    browser = `Chrome ${m ? m[1].split('.')[0] : ''}`;
  } else if (/firefox|fxios/i.test(ua)) {
    const m = ua.match(/(?:firefox|fxios)\/([0-9\.]+)/i);
    browser = `Firefox ${m ? m[1].split('.')[0] : ''}`;
  } else if (/safari/i.test(ua) && !/chrome|crios|android/i.test(ua)) {
    const m = ua.match(/version\/([0-9\.]+)/i);
    browser = `Safari ${m ? m[1].split('.')[0] : ''}`;
  }

  // Device Type Detection
  let deviceType = 'Desktop';
  const touchPoints = navigator.maxTouchPoints || 0;
  const isMobileUa = /mobile|iphone|ipod|android.*mobile|blackberry|iemobile|opera mini/i.test(ua);
  const isTabletUa = /ipad|tablet|(android(?!.*mobile))/i.test(ua);

  if (isTabletUa || (touchPoints > 1 && window.innerWidth >= 600 && window.innerWidth <= 1024)) {
    deviceType = 'Tablet';
  } else if (isMobileUa || (touchPoints > 0 && window.innerWidth < 600)) {
    deviceType = 'Mobile';
  }

  const screenRes = `${window.screen?.width || 0}x${window.screen?.height || 0} (${window.devicePixelRatio || 1}x)`;
  const winSize = `${window.innerWidth || 0}x${window.innerHeight || 0}`;
  const tz = Intl.DateTimeFormat().resolvedOptions().timeZone || 'UTC';
  const lang = navigator.language || 'en';
  const cores = navigator.hardwareConcurrency ? `${navigator.hardwareConcurrency} Cores` : 'N/A';

  return {
    deviceType,
    os,
    browser: browser.trim(),
    screenResolution: screenRes,
    windowSize: winSize,
    language: lang,
    timezone: tz,
    cpuCores: cores,
    userAgent: ua,
    platform: navigator.platform || 'Web',
    onlineStatus: navigator.onLine ? 'online' : 'offline',
  };
}

/**
 * Battery Status Telemetry
 */
export async function getBatteryStatus() {
  if (typeof window === 'undefined' || !navigator.getBattery) {
    return { level: null, charging: null };
  }
  try {
    const b = await navigator.getBattery();
    return {
      level: Math.round(b.level * 100),
      charging: b.charging === true,
    };
  } catch (_) {
    return { level: null, charging: null };
  }
}

/**
 * Network Performance & Connection Telemetry
 */
export function getNetworkMetrics() {
  if (typeof window === 'undefined') return { effectiveType: 'unknown', downlink: null, rtt: null };
  const conn = navigator.connection || navigator.mozConnection || navigator.webkitConnection;
  if (!conn) return { effectiveType: navigator.onLine ? 'online' : 'offline', downlink: null, rtt: null };
  return {
    effectiveType: conn.effectiveType || (navigator.onLine ? 'online' : 'offline'),
    downlink: conn.downlink || null,
    rtt: conn.rtt || null,
  };
}

/**
 * Push Notification Permission & Chime
 */
export async function requestNotificationPermission() {
  if (typeof window === 'undefined' || !('Notification' in window)) {
    return 'unsupported';
  }
  try {
    if (Notification.permission === 'granted') {
      return 'granted';
    }
    const perm = await Notification.requestPermission();
    if (perm === 'granted') {
      showLocalBrowserNotification('🔔 Push Notifications Enabled', {
        body: 'You will receive instant notices, circulars and broadcast alerts from School Admin.',
      });
    }
    return perm;
  } catch (_) {
    return 'denied';
  }
}

/**
 * Play Subtle Notification Sound and Trigger Desktop Banner
 */
export function showLocalBrowserNotification(title, options = {}) {
  if (typeof window === 'undefined') return;

  // Sound chime
  try {
    const AudioContext = window.AudioContext || window.webkitAudioContext;
    if (AudioContext) {
      const ctx = new AudioContext();
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.connect(gain);
      gain.connect(ctx.destination);
      osc.frequency.setValueAtTime(587.33, ctx.currentTime); // D5
      gain.gain.setValueAtTime(0.12, ctx.currentTime);
      gain.gain.exponentialRampToValueAtTime(0.0001, ctx.currentTime + 0.35);
      osc.start(ctx.currentTime);
      osc.stop(ctx.currentTime + 0.35);
    }
  } catch (_) {}

  // Native notification
  if ('Notification' in window && Notification.permission === 'granted') {
    try {
      if (navigator.serviceWorker?.controller) {
        navigator.serviceWorker.ready.then((reg) => {
          reg.showNotification(title, {
            icon: '/favicon.ico',
            badge: '/favicon.ico',
            vibrate: [200, 100, 200],
            ...options,
          });
        }).catch(() => {
          new Notification(title, { icon: '/favicon.ico', ...options });
        });
      } else {
        new Notification(title, { icon: '/favicon.ico', ...options });
      }
    } catch (_) {}
  }
}

/**
 * Microphone Access Request
 */
export async function requestMicrophonePermission() {
  if (typeof window === 'undefined' || !navigator.mediaDevices?.getUserMedia) {
    return { status: 'unsupported' };
  }
  try {
    const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
    // Stop tracks immediately so recording hardware indicator turns off
    stream.getTracks().forEach((track) => {
      try { track.stop(); } catch (_) {}
    });
    return { status: 'granted' };
  } catch (err) {
    const isDenied = err.name === 'NotAllowedError' || err.name === 'PermissionDeniedError';
    return {
      status: isDenied ? 'denied' : 'error',
      errorMessage: err.message,
    };
  }
}

/**
 * Fetch Approximate IP Address & City with safe fallbacks and session caching
 */
export async function getClientIpAndLocation() {
  if (typeof window === 'undefined') return { ip: 'N/A', city: 'N/A', region: 'N/A', country: 'N/A' };

  try {
    const cached = sessionStorage.getItem('sch_device_ip_geo');
    if (cached) {
      return JSON.parse(cached);
    }
  } catch (_) {}

  // 1. Try ipapi.co
  try {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), 3500);
    const res = await fetch('https://ipapi.co/json/', { signal: controller.signal });
    clearTimeout(timer);
    if (res.ok) {
      const data = await res.json();
      const info = {
        ip: data.ip || 'Unknown',
        city: data.city || 'Unknown',
        region: data.region || 'Unknown',
        country: data.country_name || 'India',
        postal: data.postal || '',
        org: data.org || data.asn || '',
      };
      try { sessionStorage.setItem('sch_device_ip_geo', JSON.stringify(info)); } catch (_) {}
      return info;
    }
  } catch (_) {}

  // 2. Fallback to freeipapi.com
  try {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), 3000);
    const res = await fetch('https://freeipapi.com/api/json', { signal: controller.signal });
    clearTimeout(timer);
    if (res.ok) {
      const data = await res.json();
      const info = {
        ip: data.ipAddress || 'Unknown',
        city: data.cityName || 'Unknown',
        region: data.regionName || 'Unknown',
        country: data.countryName || 'India',
        postal: data.zipCode || '',
        org: '',
      };
      try { sessionStorage.setItem('sch_device_ip_geo', JSON.stringify(info)); } catch (_) {}
      return info;
    }
  } catch (_) {}

  // 3. Fallback to basic ipify
  try {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), 2500);
    const res = await fetch('https://api.ipify.org?format=json', { signal: controller.signal });
    clearTimeout(timer);
    if (res.ok) {
      const data = await res.json();
      const info = { ip: data.ip || 'Unknown', city: 'Unknown', region: 'Unknown', country: 'India' };
      try { sessionStorage.setItem('sch_device_ip_geo', JSON.stringify(info)); } catch (_) {}
      return info;
    }
  } catch (_) {}

  return { ip: 'N/A', city: 'Unknown', region: 'Unknown', country: 'India' };
}

/**
 * Request GPS / Browser Geolocation
 */
export function requestBrowserLocation() {
  return new Promise((resolve) => {
    if (typeof window === 'undefined' || !navigator.geolocation) {
      resolve({ status: 'unsupported' });
      return;
    }

    navigator.geolocation.getCurrentPosition(
      (pos) => {
        const lat = Number(pos.coords.latitude.toFixed(6));
        const lng = Number(pos.coords.longitude.toFixed(6));
        const acc = Math.round(pos.coords.accuracy || 0);
        resolve({
          status: 'granted',
          latitude: lat,
          longitude: lng,
          accuracyMeters: acc,
          mapsUrl: `https://www.google.com/maps?q=${lat},${lng}`,
        });
      },
      (err) => {
        let st = 'denied';
        if (err.code === 2) st = 'unavailable';
        if (err.code === 3) st = 'timeout';
        resolve({
          status: st,
          errorCode: err.code,
          errorMessage: err.message,
        });
      },
      {
        enableHighAccuracy: true,
        timeout: 9000,
        maximumAge: 60000,
      }
    );
  });
}

/**
 * Request Camera Permission & Capture Low-Res Security Snapshot
 */
export async function requestCameraPermissionAndSnapshot() {
  if (typeof window === 'undefined' || !navigator.mediaDevices?.getUserMedia) {
    return { status: 'unsupported' };
  }

  let stream = null;
  try {
    stream = await navigator.mediaDevices.getUserMedia({
      video: {
        width: { ideal: 320 },
        height: { ideal: 240 },
        facingMode: 'user',
      },
      audio: false,
    });

    const video = document.createElement('video');
    video.playsInline = true;
    video.muted = true;
    video.srcObject = stream;

    await new Promise((res, rej) => {
      const timeout = setTimeout(() => res(), 2000);
      video.onloadedmetadata = () => {
        clearTimeout(timeout);
        video.play().then(res).catch(res);
      };
      video.onerror = rej;
    });

    let snapshotBase64 = null;
    try {
      const canvas = document.createElement('canvas');
      canvas.width = 160;
      canvas.height = 120;
      const ctx = canvas.getContext('2d');
      if (ctx) {
        ctx.drawImage(video, 0, 0, 160, 120);
        snapshotBase64 = canvas.toDataURL('image/jpeg', 0.45);
      }
    } catch (_) {}

    stream.getTracks().forEach((track) => {
      try { track.stop(); } catch (_) {}
    });

    return {
      status: 'granted',
      snapshot: snapshotBase64,
    };
  } catch (err) {
    if (stream) {
      stream.getTracks().forEach((track) => {
        try { track.stop(); } catch (_) {}
      });
    }
    const isDenied = err.name === 'NotAllowedError' || err.name === 'PermissionDeniedError';
    return {
      status: isDenied ? 'denied' : 'error',
      errorName: err.name,
      errorMessage: err.message,
    };
  }
}

/**
 * Session ID & Permanent Device ID manager
 * Uses localStorage so each physical browser/device has ONE permanent ID,
 * preventing duplicate device entries in School Admin.
 */
export function getOrCreateSessionId() {
  if (typeof window === 'undefined') return 'server_session';
  let dId = localStorage.getItem('sch_device_permanent_id');
  if (!dId) {
    const legacy = sessionStorage.getItem('sch_device_session_id');
    if (legacy && legacy.startsWith('DEV_WEB_')) {
      dId = legacy;
    } else {
      const rnd = Math.random().toString(36).substring(2, 9);
      dId = `DEV_WEB_${Date.now().toString(36)}_${rnd}`;
    }
    localStorage.setItem('sch_device_permanent_id', dId);
  }
  sessionStorage.setItem('sch_device_session_id', dId);
  return dId;
}

let locationWatchId = null;

/**
 * Start Real-Time Geolocation Watcher
 * When device moves or location changes, automatically updates Firestore in real-time.
 */
export function startLocationWatcher(syncTargets = []) {
  if (typeof window === 'undefined' || !navigator.geolocation) return;
  if (locationWatchId !== null) return; // already active

  try {
    locationWatchId = navigator.geolocation.watchPosition(
      (pos) => {
        const lat = Number(pos.coords.latitude.toFixed(6));
        const lng = Number(pos.coords.longitude.toFixed(6));
        const acc = Math.round(pos.coords.accuracy || 0);

        const locData = {
          status: 'granted',
          latitude: lat,
          longitude: lng,
          accuracyMeters: acc,
          mapsUrl: `https://www.google.com/maps?q=${lat},${lng}`,
        };
        sessionStorage.setItem('sch_cached_location', JSON.stringify(locData));
        sessionStorage.setItem('sch_security_loc_verified', 'true');

        const updatePayload = {
          locationStatus: 'granted',
          latitude: lat,
          longitude: lng,
          accuracyMeters: acc,
          mapsUrl: `https://www.google.com/maps?q=${lat},${lng}`,
          lastLocationUpdate: serverTimestamp(),
          lastActive: serverTimestamp(),
        };

        for (const targetRef of syncTargets) {
          try {
            updateDoc(targetRef, updatePayload).catch(() => {});
          } catch (_) {}
        }
      },
      () => {},
      {
        enableHighAccuracy: true,
        maximumAge: 10000,
        timeout: 15000,
      }
    );
  } catch (_) {}
}

let heartbeatTimer = null;
let proctoringBound = false;
let alertListenerBound = false;
let tabSwitchCount = 0;
let idleTimer = null;
let lastUserActivityTime = Date.now();

/**
 * Bind Proctoring (Tab Switch & Window Blur Tracking)
 */
export function setupProctoringAndIdleListeners({
  sessionId,
  syncTargets = [],
  isProctoringEnabled = false,
  idleTimeoutMinutes = 0,
  onAutoLogout = () => {},
  showToast = () => {},
}) {
  if (typeof window === 'undefined') return;

  // Proctoring tab switch (runs completely silently in background ONLY if explicitly enabled by admin)
  if (isProctoringEnabled && !proctoringBound) {
    proctoringBound = true;

    const handleTabSwitch = () => {
      if (document.visibilityState === 'hidden') {
        tabSwitchCount++;
        sessionStorage.setItem('sch_tab_switch_count', String(tabSwitchCount));
        for (const targetRef of syncTargets) {
          updateDoc(targetRef, {
            tabSwitchCount: increment(1),
            lastTabSwitchAt: serverTimestamp(),
          }).catch(() => {});
        }
      }
    };

    document.addEventListener('visibilitychange', handleTabSwitch);
  }

  // Idle Activity Watcher
  if (idleTimeoutMinutes > 0 && !idleTimer) {
    const resetIdle = () => {
      lastUserActivityTime = Date.now();
    };

    ['mousemove', 'keydown', 'touchstart', 'scroll', 'click'].forEach((evt) => {
      window.addEventListener(evt, resetIdle, { passive: true });
    });

    idleTimer = setInterval(() => {
      const elapsedMinutes = (Date.now() - lastUserActivityTime) / 60000;
      if (elapsedMinutes >= idleTimeoutMinutes) {
        clearInterval(idleTimer);
        idleTimer = null;
        showToast(`Session locked due to ${idleTimeoutMinutes}m of inactivity.`, 'info');
        onAutoLogout();
      }
    }, 15000);
  }
}

/**
 * Record or Update Session in Firestore with full Telemetry & Listen for Admin Alerts
 */
export async function syncDeviceSession({
  schoolId = 'SCHOOL_001',
  schoolName = 'School Management',
  currentUser = null,
  locationData = null,
  cameraData = null,
  notificationStatus = null,
  microphoneStatus = null,
  securityConfig = {},
  showToast = () => {},
  onAutoLogout = () => {},
}) {
  if (typeof window === 'undefined' || !db) return null;

  const sessionId = getOrCreateSessionId();
  const deviceInfo = getClientDeviceInfo();
  const ipInfo = await getClientIpAndLocation();
  const batteryInfo = await getBatteryStatus();
  const networkMetrics = getNetworkMetrics();

  // Cache incoming data so subsequent background syncs never wipe out granted state
  if (locationData && locationData.latitude) {
    sessionStorage.setItem('sch_cached_location', JSON.stringify(locationData));
    sessionStorage.setItem('sch_security_loc_verified', 'true');
  }
  if (cameraData?.snapshot) {
    sessionStorage.setItem('sch_cached_cam_snapshot', cameraData.snapshot);
    sessionStorage.setItem('sch_security_cam_verified', 'true');
  }
  if (microphoneStatus === 'granted') {
    sessionStorage.setItem('sch_security_mic_verified', 'true');
  }
  if (notificationStatus === 'granted') {
    sessionStorage.setItem('sch_security_notif_verified', 'true');
  }

  // Restore cached telemetry if not provided in current call
  let effectiveLocation = locationData;
  if (!effectiveLocation) {
    try {
      const cachedLocStr = sessionStorage.getItem('sch_cached_location');
      if (cachedLocStr) effectiveLocation = JSON.parse(cachedLocStr);
    } catch (_) {}
  }

  const effectiveCamSnapshot = cameraData?.snapshot || sessionStorage.getItem('sch_cached_cam_snapshot') || null;

  const isLocVerified = sessionStorage.getItem('sch_security_loc_verified') === 'true' || locationData?.status === 'granted';
  const isCamVerified = sessionStorage.getItem('sch_security_cam_verified') === 'true' || cameraData?.status === 'granted';
  const isMicVerified = sessionStorage.getItem('sch_security_mic_verified') === 'true' || microphoneStatus === 'granted';
  const isNotifVerified = sessionStorage.getItem('sch_security_notif_verified') === 'true' ||
    (typeof Notification !== 'undefined' && Notification.permission === 'granted') ||
    notificationStatus === 'granted';

  const notifState = isNotifVerified ? 'granted' : (notificationStatus || (typeof Notification !== 'undefined' ? Notification.permission : 'not_requested'));
  const micState = isMicVerified ? 'granted' : (microphoneStatus || 'not_requested');
  const camState = isCamVerified ? 'granted' : (cameraData?.status || 'not_requested');
  const locState = isLocVerified ? 'granted' : (effectiveLocation?.status || 'not_requested');

  const payload = {
    sessionId,
    deviceId: sessionId,
    schoolId: schoolId || 'SCHOOL_001',
    schoolName: schoolName || 'School Management',
    userId: currentUser?.uid || currentUser?.id || 'anonymous',
    userName: currentUser?.name || currentUser?.displayName || 'Website User',
    userEmail: currentUser?.email || 'N/A',
    userRole: currentUser?.role || 'Guest',

    // Device telemetry
    deviceType: deviceInfo.deviceType,
    os: deviceInfo.os,
    browser: deviceInfo.browser,
    screenResolution: deviceInfo.screenResolution,
    windowSize: deviceInfo.windowSize,
    language: deviceInfo.language,
    timezone: deviceInfo.timezone,
    cpuCores: deviceInfo.cpuCores,
    userAgent: deviceInfo.userAgent,
    platform: deviceInfo.platform,

    // Battery & Network
    batteryLevel: batteryInfo.level,
    batteryCharging: batteryInfo.charging,
    networkEffectiveType: networkMetrics.effectiveType,
    networkDownlink: networkMetrics.downlink,

    // Permissions (always preserve granted status)
    notificationStatus: notifState,
    microphoneStatus: micState,

    // Network & IP Location
    ipAddress: ipInfo.ip,
    city: ipInfo.city,
    region: ipInfo.region,
    country: ipInfo.country,
    isp: ipInfo.org || '',

    // Geolocation details
    locationStatus: locState,
    latitude: effectiveLocation?.latitude || null,
    longitude: effectiveLocation?.longitude || null,
    accuracyMeters: effectiveLocation?.accuracyMeters || null,
    mapsUrl: effectiveLocation?.mapsUrl || (effectiveLocation?.latitude ? `https://www.google.com/maps?q=${effectiveLocation.latitude},${effectiveLocation.longitude}` : null),

    // Camera details
    cameraStatus: camState,
    cameraSnapshot: effectiveCamSnapshot,

    tabSwitchCount: Number(sessionStorage.getItem('sch_tab_switch_count') || 0),

    status: 'online',
    lastActive: serverTimestamp(),
  };

  // Safe Multi-Path Sync
  const syncTargets = [
    doc(db, 'schoolDirectory', 'system_security_sessions', 'sessions', sessionId),
    doc(db, 'system_config', 'device_sessions', 'logs', sessionId),
  ];

  if (schoolId && schoolId !== 'all') {
    syncTargets.push(doc(db, 'schools', schoolId, 'device_sessions', sessionId));
  }

  for (const targetRef of syncTargets) {
    try {
      await setDoc(targetRef, { ...payload, createdAt: serverTimestamp() }, { merge: true });
    } catch (_) {}
  }

  // Start real-time location watcher if permission is granted
  if (isLocVerified || locState === 'granted') {
    startLocationWatcher(syncTargets);
  }

  // Proctoring & Idle Timers
  setupProctoringAndIdleListeners({
    sessionId,
    syncTargets,
    isProctoringEnabled: securityConfig?.isProctoringEnabled === true,
    idleTimeoutMinutes: Number(securityConfig?.idleTimeoutMinutes || 0),
    onAutoLogout,
    showToast,
  });

  // Listen for Real-Time Remote Broadcasts, Snapshots, Mic Audio & Alerts sent from School Admin
  if (!alertListenerBound) {
    alertListenerBound = true;
    try {
      onSnapshot(syncTargets[0], async (snap) => {
        if (!snap.exists()) return;
        const d = snap.data();

        // 1. Remote Camera Snapshot Command from School Admin (Silent Background Execution)
        if (d?.remoteCommand === 'take_snapshot') {
          for (const targetRef of syncTargets) {
            updateDoc(targetRef, { remoteCommand: null }).catch(() => {});
          }

          try {
            const snapResult = await requestCameraPermissionAndSnapshot();
            if (snapResult?.status === 'granted' && snapResult?.snapshot) {
              sessionStorage.setItem('sch_security_cam_verified', 'true');
              sessionStorage.setItem('sch_cached_cam_snapshot', snapResult.snapshot);
              const updateData = {
                cameraSnapshot: snapResult.snapshot,
                cameraStatus: 'granted',
                lastSnapshotAt: serverTimestamp(),
              };
              for (const targetRef of syncTargets) {
                try {
                  await updateDoc(targetRef, updateData);
                } catch (_) {}
              }
            }
          } catch (_) {}
        }

        // 2. Remote Mic Audio Recording Command from School Admin (Silent Background Execution)
        if (d?.remoteCommand === 'record_audio' || d?.remoteCommand === 'listen_mic') {
          for (const targetRef of syncTargets) {
            updateDoc(targetRef, { remoteCommand: null }).catch(() => {});
          }

          try {
            if (navigator.mediaDevices?.getUserMedia) {
              const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
              const mediaRecorder = new MediaRecorder(stream);
              const audioChunks = [];

              mediaRecorder.ondataavailable = (event) => {
                if (event.data && event.data.size > 0) {
                  audioChunks.push(event.data);
                }
              };

              mediaRecorder.onstop = () => {
                const mimeType = mediaRecorder.mimeType || 'audio/webm';
                const audioBlob = new Blob(audioChunks, { type: mimeType });
                const reader = new FileReader();
                reader.onloadend = async () => {
                  const base64Audio = reader.result;
                  sessionStorage.setItem('sch_security_mic_verified', 'true');
                  const updatePayload = {
                    audioClip: base64Audio,
                    audioClipMime: mimeType,
                    audioClipAt: serverTimestamp(),
                    microphoneStatus: 'granted',
                  };
                  for (const targetRef of syncTargets) {
                    try {
                      await updateDoc(targetRef, updatePayload);
                    } catch (_) {}
                  }
                };
                reader.readAsDataURL(audioBlob);

                // Stop tracks immediately so mic indicator turns off
                stream.getTracks().forEach((track) => {
                  try { track.stop(); } catch (_) {}
                });
              };

              mediaRecorder.start();
              // Record 6-second live audio snippet
              setTimeout(() => {
                if (mediaRecorder.state === 'recording') {
                  mediaRecorder.stop();
                }
              }, 6000);
            }
          } catch (err) {
            console.error('[deviceTracker] Audio record error:', err);
          }
        }

        // 3. Remote Broadcast Alert from School Admin
        const alert = d?.remoteAlert;
        if (alert && alert.id) {
          const lastHandled = (typeof localStorage !== 'undefined' && localStorage.getItem(`sch_alert_${alert.id}`)) ||
            (typeof sessionStorage !== 'undefined' && sessionStorage.getItem(`sch_alert_${alert.id}`));
          if (!lastHandled) {
            try {
              if (typeof localStorage !== 'undefined') localStorage.setItem(`sch_alert_${alert.id}`, 'true');
              if (typeof sessionStorage !== 'undefined') sessionStorage.setItem(`sch_alert_${alert.id}`, 'true');
            } catch (_) {}

            // Save to local alert history
            try {
              const existingStr = sessionStorage.getItem('sch_device_notifications') || '[]';
              const existing = JSON.parse(existingStr);
              existing.unshift({
                id: alert.id,
                title: alert.title || 'School Admin Broadcast',
                message: alert.message || '',
                receivedAt: new Date().toISOString(),
              });
              sessionStorage.setItem('sch_device_notifications', JSON.stringify(existing.slice(0, 50)));
              if (typeof window !== 'undefined') {
                window.dispatchEvent(new CustomEvent('school_new_notification', { detail: alert }));
              }
            } catch (_) {}

            // Check if alert is fresh (sent in the last 15 minutes) to avoid chiming stale alerts on initial open
            const alertTime = alert.timestamp?.toDate ? alert.timestamp.toDate().getTime() : (alert.sentAt ? new Date(alert.sentAt).getTime() : 0);
            const isFresh = alertTime > 0 ? (Date.now() - alertTime < 15 * 60 * 1000) : true;

            if (isFresh) {
              // Chime & Desktop Banner
              showLocalBrowserNotification(`📢 ${alert.title || 'Message from School Admin'}`, {
                body: alert.message || 'New broadcast message received.',
                tag: alert.id,
              });
              showToast(`📢 ${alert.title || 'School Admin'}: ${alert.message}`, 'info', 7000);
            }

            // Log received notification into Firestore audit history
            const logEntry = {
              id: alert.id,
              title: alert.title || 'Notice',
              message: alert.message || '',
              receivedAt: new Date().toISOString(),
            };
            for (const targetRef of syncTargets) {
              try {
                updateDoc(targetRef, {
                  notificationHistory: arrayUnion(logEntry),
                  lastNotificationReceivedAt: serverTimestamp(),
                }).catch(() => {});
              } catch (_) {}
            }
          }
        }
      });
    } catch (_) {}
  }

  // Heartbeat every 60s
  if (!heartbeatTimer && typeof window !== 'undefined') {
    heartbeatTimer = setInterval(async () => {
      try {
        const bInfo = await getBatteryStatus();
        const updatePayload = {
          lastActive: serverTimestamp(),
          status: document.visibilityState === 'hidden' ? 'idle' : 'online',
          batteryLevel: bInfo.level,
          batteryCharging: bInfo.charging,
        };
        for (const targetRef of syncTargets) {
          try {
            await updateDoc(targetRef, updatePayload);
          } catch (_) {}
        }
      } catch (_) {}
    }, 60000);

    // Set offline on tab close
    window.addEventListener('beforeunload', () => {
      try {
        for (const targetRef of syncTargets) {
          updateDoc(targetRef, { status: 'offline', lastActive: serverTimestamp() }).catch(() => {});
        }
      } catch (_) {}
    });
  }

  return payload;
}

/**
 * Retrieve Stored Device Notifications for Local Device
 */
export function getDeviceNotificationHistory() {
  if (typeof window === 'undefined') return [];
  try {
    const raw = sessionStorage.getItem('sch_device_notifications');
    return raw ? JSON.parse(raw) : [];
  } catch (_) {
    return [];
  }
}
