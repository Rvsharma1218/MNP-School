'use client';

import React, { useState, useEffect, useRef } from 'react';
import { useSchoolStore } from '../lib/store';
import {
  QrCode,
  Search,
  Camera,
  CheckCircle2,
  AlertCircle,
  User,
  CreditCard,
  CalendarCheck,
  Eye,
  Sparkles
} from 'lucide-react';

export default function QrScannerView() {
  const {
    students,
    settings,
    attendance,
    markStudentAttendance,
    setSelectedStudentId,
    setActiveView,
    showToast
  } = useSchoolStore();

  const [searchCode, setSearchCode] = useState('');
  const [scannedStudent, setScannedStudent] = useState(null);
  const [isCameraActive, setIsCameraActive] = useState(false);
  const [isMarkedSuccess, setIsMarkedSuccess] = useState(false);

  const videoRef = useRef(null);
  const streamRef = useRef(null);

  const todayStr = new Date().toISOString().split('T')[0];

  const handleSearch = (e) => {
    e.preventDefault();
    if (!searchCode.trim()) return;

    const q = searchCode.trim().toLowerCase();
    const found = students.find(s => 
      s.studentId?.toLowerCase() === q ||
      s.admissionNumber?.toLowerCase() === q ||
      s.rollNumber?.toLowerCase() === q ||
      s.name?.toLowerCase().includes(q) ||
      s.mobile === q
    );

    if (found) {
      setScannedStudent(found);
      setIsMarkedSuccess(false);
      showToast(`Student found: ${found.name}`, "success");
    } else {
      showToast("No student found with this ID or Code.", "error");
    }
  };

  const handleSimulateScan = (student) => {
    setScannedStudent(student);
    setIsMarkedSuccess(false);
  };

  const handleMarkPresent = () => {
    if (!scannedStudent) return;
    markStudentAttendance(todayStr, scannedStudent.id, 'present');
    setIsMarkedSuccess(true);
    showToast(`Marked ${scannedStudent.name} present for today!`, "success");
  };

  // Camera start/stop
  const toggleCamera = async () => {
    if (isCameraActive) {
      if (streamRef.current) {
        streamRef.current.getTracks().forEach(track => track.stop());
      }
      setIsCameraActive(false);
    } else {
      try {
        const stream = await navigator.mediaDevices.getUserMedia({ video: { facingMode: 'environment' } });
        streamRef.current = stream;
        if (videoRef.current) {
          videoRef.current.srcObject = stream;
        }
        setIsCameraActive(true);
      } catch (err) {
        showToast("Camera access not available or denied. You can use manual student lookup below.", "warning");
      }
    }
  };

  useEffect(() => {
    return () => {
      if (streamRef.current) {
        streamRef.current.getTracks().forEach(track => track.stop());
      }
    };
  }, []);

  const currentAttendanceStatus = scannedStudent ? attendance[todayStr]?.[scannedStudent.id] : null;

  return (
    <div className="space-y-6 pb-12">
      {/* Header */}
      <div>
        <h2 className="text-xl lg:text-2xl font-extrabold text-text tracking-tight">
          QR Code Scanner & Instant Verification
        </h2>
        <p className="text-xs lg:text-sm text-text-secondary">
          Scan student ID card QR codes for identity verification and instant 1-click attendance check-in
        </p>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Scanner / Search Card */}
        <div className="bg-card border border-border rounded-2xl p-6 shadow-xs space-y-6">
          {/* Camera Viewfinder */}
          <div className="relative w-full aspect-4/3 rounded-2xl bg-slate-950 overflow-hidden flex flex-col items-center justify-center border border-border">
            {isCameraActive ? (
              <video
                ref={videoRef}
                autoPlay
                playsInline
                className="w-full h-full object-cover"
              />
            ) : (
              <div className="text-center p-6 space-y-3">
                <div className="w-16 h-16 rounded-2xl bg-white/10 text-white flex items-center justify-center mx-auto">
                  <Camera className="w-8 h-8 text-primary" />
                </div>
                <div className="text-sm font-bold text-white">Live Camera Scanner</div>
                <p className="text-xs text-slate-400 max-w-xs">
                  Position the Student ID card QR code in front of your camera
                </p>
              </div>
            )}

            {/* Scanner Grid Overlay */}
            <div className="absolute inset-0 pointer-events-none flex items-center justify-center p-8">
              <div className="w-48 h-48 border-2 border-dashed border-amber-400/80 rounded-2xl relative">
                <div className="absolute top-0 left-0 w-4 h-4 border-t-4 border-l-4 border-amber-400" />
                <div className="absolute top-0 right-0 w-4 h-4 border-t-4 border-r-4 border-amber-400" />
                <div className="absolute bottom-0 left-0 w-4 h-4 border-b-4 border-l-4 border-amber-400" />
                <div className="absolute bottom-0 right-0 w-4 h-4 border-b-4 border-r-4 border-amber-400" />
              </div>
            </div>

            {/* Camera Toggle Button */}
            <button
              onClick={toggleCamera}
              className="absolute bottom-4 z-10 px-4 py-2 rounded-xl bg-white text-slate-900 font-bold text-xs shadow-lg flex items-center gap-2 cursor-pointer hover:bg-slate-100"
            >
              <Camera className="w-4 h-4" />
              <span>{isCameraActive ? 'Stop Camera' : 'Start Camera'}</span>
            </button>
          </div>

          {/* Manual ID Search Input */}
          <form onSubmit={handleSearch} className="space-y-2">
            <label className="block text-xs font-bold text-text uppercase tracking-wider">
              Or Enter Student ID / Roll / Admission No:
            </label>
            <div className="flex gap-2">
              <input
                type="text"
                value={searchCode}
                onChange={(e) => setSearchCode(e.target.value)}
                placeholder="e.g. STU00101 or 101"
                className="flex-1 px-4 py-2.5 rounded-xl bg-surface2 border border-border text-xs text-text font-bold focus:outline-none focus:border-primary"
              />
              <button
                type="submit"
                className="px-5 py-2.5 rounded-xl bg-primary hover:bg-primary-dark text-white font-bold text-xs shadow-md cursor-pointer"
              >
                Search
              </button>
            </div>
          </form>

          {/* Quick Simulation Chips */}
          <div className="space-y-2">
            <span className="text-[11px] font-bold text-text-secondary uppercase">Quick Test Scan:</span>
            <div className="flex flex-wrap gap-2">
              {students.slice(0, 4).map(s => (
                <button
                  key={s.id}
                  onClick={() => handleSimulateScan(s)}
                  className="px-2.5 py-1 rounded-lg bg-surface2 hover:bg-primary/10 hover:text-primary text-[11px] font-semibold text-text border border-border cursor-pointer transition-colors"
                >
                  Scan {s.name} ({s.studentId})
                </button>
              ))}
            </div>
          </div>
        </div>

        {/* Scanned Student Result Card */}
        <div className="bg-card border border-border rounded-2xl p-6 shadow-xs flex flex-col justify-between">
          <div>
            <h3 className="text-sm font-bold text-text uppercase tracking-wider mb-4 flex items-center gap-2">
              <CheckCircle2 className="w-4 h-4 text-emerald-500" />
              <span>Scanned Record Details</span>
            </h3>

            {scannedStudent ? (
              <div className="space-y-5">
                <div className="flex items-center gap-4 p-4 rounded-xl bg-surface2/60 border border-border">
                  <div className="w-16 h-16 rounded-2xl bg-primary text-white flex items-center justify-center font-black text-xl overflow-hidden shadow-md flex-shrink-0">
                    {scannedStudent.photoPath ? (
                      <img src={scannedStudent.photoPath} alt={scannedStudent.name} className="w-full h-full object-cover" />
                    ) : (
                      scannedStudent.name?.charAt(0) || 'S'
                    )}
                  </div>

                  <div className="min-w-0 flex-1">
                    <h4 className="text-base font-black text-text truncate">{scannedStudent.name}</h4>
                    <p className="text-xs text-text-secondary">
                      {scannedStudent.studentType === 'school' 
                        ? `Class ${scannedStudent.className || ''} (${scannedStudent.section || 'A'})` 
                        : scannedStudent.course}
                    </p>
                    <div className="text-[11px] text-text-muted mt-1">
                      ID: <strong className="text-text">{scannedStudent.studentId}</strong> • Adm: {scannedStudent.admissionNumber}
                    </div>
                  </div>
                </div>

                {/* Particulars */}
                <div className="grid grid-cols-2 gap-3 text-xs">
                  <div className="p-3 rounded-xl bg-surface2/40 border border-border">
                    <span className="text-text-secondary text-[10px] font-bold uppercase">Father</span>
                    <div className="font-bold text-text mt-0.5">{scannedStudent.fatherName || '—'}</div>
                  </div>

                  <div className="p-3 rounded-xl bg-surface2/40 border border-border">
                    <span className="text-text-secondary text-[10px] font-bold uppercase">Mobile</span>
                    <div className="font-bold text-text mt-0.5">{scannedStudent.mobile}</div>
                  </div>

                  <div className="p-3 rounded-xl bg-surface2/40 border border-border">
                    <span className="text-text-secondary text-[10px] font-bold uppercase">Fee Balance</span>
                    <div className="font-bold text-rose-600 mt-0.5">
                      ₹{Math.max(0, (scannedStudent.totalFees || 0) - (scannedStudent.paidFees || 0))}
                    </div>
                  </div>

                  <div className="p-3 rounded-xl bg-surface2/40 border border-border">
                    <span className="text-text-secondary text-[10px] font-bold uppercase">Today Status</span>
                    <div className="font-bold capitalize text-text mt-0.5">
                      {currentAttendanceStatus || 'Not Marked'}
                    </div>
                  </div>
                </div>

                {/* Quick Check-in Button */}
                <div className="pt-2 space-y-2">
                  <button
                    onClick={handleMarkPresent}
                    className="w-full py-3 rounded-xl bg-emerald-600 hover:bg-emerald-700 text-white font-bold text-sm shadow-lg shadow-emerald-600/20 flex items-center justify-center gap-2 cursor-pointer transition-all transform active:scale-98"
                  >
                    <CalendarCheck className="w-5 h-5" />
                    <span>Mark Present for Today ({todayStr})</span>
                  </button>

                  {isMarkedSuccess && (
                    <div className="p-2.5 rounded-xl bg-emerald-500/15 border border-emerald-500/30 text-emerald-600 text-xs font-bold text-center animate-in fade-in">
                      ✅ Attendance marked as PRESENT successfully!
                    </div>
                  )}
                </div>
              </div>
            ) : (
              <div className="py-16 text-center text-text-muted space-y-2">
                <QrCode className="w-12 h-12 mx-auto text-text-muted/40" />
                <p className="text-xs">No student scanned yet. Scan a QR code or use the search bar on the left.</p>
              </div>
            )}
          </div>

          {scannedStudent && (
            <div className="pt-4 border-t border-border flex justify-end">
              <button
                onClick={() => {
                  setSelectedStudentId(scannedStudent.id);
                  setActiveView('students');
                }}
                className="text-xs font-bold text-primary hover:underline flex items-center gap-1 cursor-pointer"
              >
                <Eye className="w-3.5 h-3.5" />
                <span>Open Full Student Profile</span>
              </button>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
