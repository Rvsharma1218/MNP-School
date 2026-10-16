'use client';

/**
 * Modular Audio & Voice Recorder Utility for Viva, Oral Tests and Voice Notes
 */

let mediaRecorder = null;
let audioChunks = [];
let audioStream = null;
let recordingStartTime = null;

export async function startAudioRecording() {
  if (typeof window === 'undefined' || !navigator.mediaDevices?.getUserMedia) {
    throw new Error('Audio recording is not supported in this browser.');
  }

  audioChunks = [];
  audioStream = await navigator.mediaDevices.getUserMedia({ audio: true });

  const mimeType = MediaRecorder.isTypeSupported('audio/webm')
    ? 'audio/webm'
    : MediaRecorder.isTypeSupported('audio/mp4')
    ? 'audio/mp4'
    : '';

  mediaRecorder = new MediaRecorder(audioStream, mimeType ? { mimeType } : undefined);

  mediaRecorder.ondataavailable = (event) => {
    if (event.data && event.data.size > 0) {
      audioChunks.push(event.data);
    }
  };

  recordingStartTime = Date.now();
  mediaRecorder.start(250); // Slice chunks every 250ms

  return {
    status: 'recording',
    startedAt: recordingStartTime,
  };
}

export function stopAudioRecording() {
  return new Promise((resolve, reject) => {
    if (!mediaRecorder || mediaRecorder.state === 'inactive') {
      resolve(null);
      return;
    }

    mediaRecorder.onstop = () => {
      const durationSeconds = recordingStartTime ? Math.round((Date.now() - recordingStartTime) / 1000) : 0;
      const mimeType = mediaRecorder.mimeType || 'audio/webm';
      const audioBlob = new Blob(audioChunks, { type: mimeType });
      const audioUrl = URL.createObjectURL(audioBlob);

      // Stop hardware tracks
      if (audioStream) {
        audioStream.getTracks().forEach((track) => {
          try { track.stop(); } catch (_) {}
        });
        audioStream = null;
      }
      mediaRecorder = null;
      audioChunks = [];

      resolve({
        audioBlob,
        audioUrl,
        durationSeconds,
        mimeType,
        sizeBytes: audioBlob.size,
      });
    };

    mediaRecorder.onerror = (err) => {
      reject(err);
    };

    mediaRecorder.stop();
  });
}

export function isAudioRecordingActive() {
  return mediaRecorder !== null && mediaRecorder.state === 'recording';
}
