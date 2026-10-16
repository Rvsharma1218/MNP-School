'use client';

import React, { useState, useEffect, useRef } from 'react';
import { startAudioRecording, stopAudioRecording } from '../lib/audioRecorder';

export default function AudioVoiceNoteModal({
  isOpen = false,
  title = 'Voice Response / Oral Recording',
  onClose = () => {},
  onSave = () => {},
}) {
  const [isRecording, setIsRecording] = useState(false);
  const [recordingTime, setRecordingTime] = useState(0);
  const [audioResult, setAudioResult] = useState(null);
  const [errorMsg, setErrorMsg] = useState('');
  const timerRef = useRef(null);

  useEffect(() => {
    if (isRecording) {
      setRecordingTime(0);
      timerRef.current = setInterval(() => {
        setRecordingTime((prev) => prev + 1);
      }, 1000);
    } else {
      if (timerRef.current) clearInterval(timerRef.current);
    }
    return () => {
      if (timerRef.current) clearInterval(timerRef.current);
    };
  }, [isRecording]);

  if (!isOpen) return null;

  const handleStart = async () => {
    setErrorMsg('');
    try {
      await startAudioRecording();
      setIsRecording(true);
      setAudioResult(null);
    } catch (e) {
      setErrorMsg(e.message || 'Microphone access is not available.');
    }
  };

  const handleStop = async () => {
    try {
      const res = await stopAudioRecording();
      setIsRecording(false);
      setAudioResult(res);
    } catch (e) {
      setErrorMsg('Error stopping recording: ' + e.message);
    }
  };

  const formatSec = (s) => {
    const mins = Math.floor(s / 60);
    const secs = s % 60;
    return `${String(mins).padStart(2, '0')}:${String(secs).padStart(2, '0')}`;
  };

  return (
    <div className="fixed inset-0 z-[99999] bg-black/80 backdrop-blur-sm flex items-center justify-center p-4">
      <div className="max-w-md w-full bg-slate-900 border border-slate-700/80 rounded-2xl p-6 shadow-2xl">
        <div className="flex items-center justify-between mb-4">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 bg-cyan-500/20 text-cyan-400 rounded-xl flex items-center justify-center">
              <span className="text-xl">🎤</span>
            </div>
            <div>
              <h3 className="text-base font-bold text-white">{title}</h3>
              <p className="text-xs text-slate-400">Oral examination & audio feedback</p>
            </div>
          </div>
          <button
            onClick={onClose}
            className="text-slate-400 hover:text-white p-1 rounded-lg hover:bg-slate-800 transition"
          >
            ✕
          </button>
        </div>

        {errorMsg && (
          <div className="mb-4 p-3 bg-red-950/40 border border-red-500/40 rounded-xl text-red-300 text-xs">
            ⚠️ {errorMsg}
          </div>
        )}

        <div className="py-6 flex flex-col items-center justify-center bg-slate-950/50 rounded-2xl border border-slate-800 mb-5">
          <div className={`text-4xl font-mono font-bold mb-3 ${isRecording ? 'text-rose-500 animate-pulse' : 'text-slate-300'}`}>
            {formatSec(recordingTime)}
          </div>
          <div className="text-xs text-slate-400">
            {isRecording ? '🔴 Recording in progress...' : audioResult ? '✓ Recording completed' : 'Press start to record voice'}
          </div>

          {audioResult && (
            <div className="mt-4 w-full px-6">
              <audio controls src={audioResult.audioUrl} className="w-full h-10" />
            </div>
          )}
        </div>

        <div className="flex gap-2">
          {!isRecording ? (
            <button
              onClick={handleStart}
              className="flex-1 py-2.5 px-4 bg-cyan-600 hover:bg-cyan-500 text-white rounded-xl text-xs font-semibold transition flex items-center justify-center gap-2"
            >
              <span>{audioResult ? '🔄 Record Again' : '🎙️ Start Recording'}</span>
            </button>
          ) : (
            <button
              onClick={handleStop}
              className="flex-1 py-2.5 px-4 bg-rose-600 hover:bg-rose-500 text-white rounded-xl text-xs font-semibold transition flex items-center justify-center gap-2"
            >
              <span>⏹️ Stop Recording</span>
            </button>
          )}

          {audioResult && (
            <button
              onClick={() => {
                onSave(audioResult);
                onClose();
              }}
              className="flex-1 py-2.5 px-4 bg-emerald-600 hover:bg-emerald-500 text-white rounded-xl text-xs font-semibold transition"
            >
              ✓ Save Audio
            </button>
          )}
        </div>
      </div>
    </div>
  );
}
