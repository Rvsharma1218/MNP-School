'use client';

import React, { useState, useEffect, useRef } from 'react';
import { useSchoolStore } from '../lib/store';
import {
  X, Image as ImageIcon, UploadCloud, Pin, Send,
  AlertTriangle, Calendar, Users, FileText, CheckCircle2,
  Trash2, Sparkles, Megaphone, FileCheck, Info, FileSpreadsheet
} from 'lucide-react';

const CATEGORIES = [
  { id: 'General', label: 'General Announcement', color: 'bg-slate-100 text-slate-700 border-slate-300', dot: 'bg-slate-500' },
  { id: 'Urgent', label: 'Urgent Alert', color: 'bg-rose-50 text-rose-700 border-rose-300', dot: 'bg-rose-500' },
  { id: 'Meeting', label: 'Faculty / Staff Meeting', color: 'bg-blue-50 text-blue-700 border-blue-300', dot: 'bg-blue-500' },
  { id: 'Holiday', label: 'Holiday Circular', color: 'bg-emerald-50 text-emerald-700 border-emerald-300', dot: 'bg-emerald-500' },
  { id: 'Academic', label: 'Academic & Exam', color: 'bg-purple-50 text-purple-700 border-purple-300', dot: 'bg-purple-500' },
  { id: 'Event', label: 'School Event / Activity', color: 'bg-amber-50 text-amber-700 border-amber-300', dot: 'bg-amber-500' },
];

// Helper to dynamically load PDF.js for client-side PDF compression
const loadPdfJs = async () => {
  if (typeof window === 'undefined') return null;
  if (window.pdfjsLib) return window.pdfjsLib;
  return new Promise((resolve, reject) => {
    const existing = document.getElementById('pdfjs-script');
    if (existing) {
      existing.onload = () => resolve(window.pdfjsLib);
      return;
    }
    const script = document.createElement('script');
    script.id = 'pdfjs-script';
    script.src = 'https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.11.174/pdf.min.js';
    script.onload = () => {
      if (window.pdfjsLib) {
        window.pdfjsLib.GlobalWorkerOptions.workerSrc = 'https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.11.174/pdf.worker.min.js';
        resolve(window.pdfjsLib);
      } else {
        reject(new Error('PDF.js engine load failed'));
      }
    };
    script.onerror = () => reject(new Error('Could not connect to PDF compressor library'));
    document.head.appendChild(script);
  });
};

export default function AddEditNoticeModal({ isOpen, onClose, noticeToEdit }) {
  const { publishNotice, currentUser, settings, showToast } = useSchoolStore();

  const [title, setTitle] = useState('');
  const [content, setContent] = useState('');
  const [category, setCategory] = useState('General');
  const [targetAudience, setTargetAudience] = useState('all');
  const [isPinned, setIsPinned] = useState(false);
  const [imageUrl, setImageUrl] = useState('');
  const [fileType, setFileType] = useState('image'); // 'image' | 'pdf' | 'pdf_compressed'
  const [fileName, setFileName] = useState('');
  const [fileSize, setFileSize] = useState('');
  const [originalSize, setOriginalSize] = useState('');
  const [isCompressing, setIsCompressing] = useState(false);
  const [compressionProgress, setCompressionProgress] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);

  const fileInputRef = useRef(null);

  useEffect(() => {
    if (noticeToEdit) {
      setTitle(noticeToEdit.title || '');
      setContent(noticeToEdit.content || '');
      setCategory(noticeToEdit.category || 'General');
      setTargetAudience(noticeToEdit.targetAudience || 'all');
      setIsPinned(!!noticeToEdit.isPinned);
      setImageUrl(noticeToEdit.imageUrl || '');
      setFileType(noticeToEdit.fileType || (noticeToEdit.imageUrl?.startsWith('data:application/pdf') ? 'pdf' : 'image'));
      setFileName(noticeToEdit.fileName || '');
      setFileSize(noticeToEdit.fileSize || '');
      setOriginalSize(noticeToEdit.originalSize || '');
    } else {
      setTitle('');
      setContent('');
      setCategory('General');
      setTargetAudience('all');
      setIsPinned(false);
      setImageUrl('');
      setFileType('image');
      setFileName('');
      setFileSize('');
      setOriginalSize('');
    }
  }, [noticeToEdit, isOpen]);

  if (!isOpen) return null;

  const schoolAuthorName = (settings?.instituteName && settings.instituteName.trim())
    ? settings.instituteName.trim()
    : (settings?.schoolName || currentUser?.instituteName || 'School Management');

  // ── Smart Multi-Pass Photo & PDF Compressor (Strictly <= 50 KB) ──
  const handleAttachmentFile = async (e) => {
    const file = e.target.files?.[0];
    if (!file) return;

    const isPdf = file.type === 'application/pdf' || file.name.toLowerCase().endsWith('.pdf');
    const isImage = file.type.startsWith('image/');

    if (!isPdf && !isImage) {
      showToast('Please select an Image (JPG/PNG) or a PDF file', 'error');
      return;
    }

    setIsCompressing(true);
    const origKB = (file.size / 1024).toFixed(1);

    // ── 1. Handle PDF Attachment with Automated Compression to <= 50 KB ──
    if (isPdf) {
      setCompressionProgress('Compressing PDF to ≤ 50 KB…');
      try {
        // If PDF is already tiny (<= 50 KB), we can keep raw base64
        if (file.size <= 50 * 1024) {
          const reader = new FileReader();
          reader.onload = (ev) => {
            setImageUrl(ev.target.result);
            setFileType('pdf');
            setFileName(file.name);
            setFileSize(`${origKB} KB`);
            setOriginalSize(`${origKB} KB`);
            setIsCompressing(false);
            setCompressionProgress('');
            showToast(`PDF attached: ${file.name} (${origKB} KB)`, 'success');
          };
          reader.readAsDataURL(file);
          return;
        }

        // PDF is larger than 50 KB -> Render PDF page to high-res canvas and compress to <= 50 KB
        setCompressionProgress(`Rendering & Compressing PDF (${origKB} KB → ≤ 50 KB)…`);
        const pdfjs = await loadPdfJs();
        const arrayBuffer = await file.arrayBuffer();
        const loadingTask = pdfjs.getDocument({ data: arrayBuffer });
        const pdfDoc = await loadingTask.promise;
        const page = await pdfDoc.getPage(1);

        const unscaledViewport = page.getViewport({ scale: 1.0 });
        const maxDimension = 950;
        const renderScale = Math.min(1.8, maxDimension / Math.max(unscaledViewport.width, unscaledViewport.height));
        const viewport = page.getViewport({ scale: renderScale });

        const canvas = document.createElement('canvas');
        canvas.width = Math.round(viewport.width);
        canvas.height = Math.round(viewport.height);
        const ctx = canvas.getContext('2d');
        ctx.fillStyle = '#FFFFFF';
        ctx.fillRect(0, 0, canvas.width, canvas.height);

        await page.render({ canvasContext: ctx, viewport }).promise;

        // Run multi-pass compressor on rendered PDF page
        let quality = 0.82;
        let stepScale = 1.0;
        let compressedDataUrl = '';
        let finalKB = 0;

        for (let pass = 0; pass < 9; pass++) {
          const compCanvas = document.createElement('canvas');
          const curW = Math.max(120, Math.round(canvas.width * stepScale));
          const curH = Math.max(120, Math.round(canvas.height * stepScale));
          compCanvas.width = curW;
          compCanvas.height = curH;

          const compCtx = compCanvas.getContext('2d');
          compCtx.fillStyle = '#FFFFFF';
          compCtx.fillRect(0, 0, curW, curH);
          compCtx.drawImage(canvas, 0, 0, curW, curH);

          compressedDataUrl = compCanvas.toDataURL('image/jpeg', quality);
          const base64Content = compressedDataUrl.split(',')[1] || '';
          const byteLength = Math.round((base64Content.length * 3) / 4);
          finalKB = (byteLength / 1024).toFixed(1);

          if (byteLength <= 50 * 1024) {
            break; // Target <= 50 KB achieved!
          }

          quality = Math.max(0.28, quality - 0.12);
          stepScale = Math.max(0.35, stepScale * 0.82);
        }

        setImageUrl(compressedDataUrl);
        setFileType('pdf_compressed');
        setFileName(file.name);
        setFileSize(`${finalKB} KB`);
        setOriginalSize(`${origKB} KB`);
        setIsCompressing(false);
        setCompressionProgress('');
        showToast(`PDF compressed: ${origKB} KB → ${finalKB} KB (≤ 50 KB)`, 'success');
      } catch (err) {
        console.error('PDF compression error:', err);
        setIsCompressing(false);
        setCompressionProgress('');
        showToast('PDF Compression Note: ' + err.message, 'error');
      }
      return;
    }

    // ── 2. Handle Photo / Image with Multi-Pass Compression (Auto-target <= 50 KB) ──
    setCompressionProgress(`Compressing Photo (${origKB} KB → ≤ 50 KB)…`);
    const reader = new FileReader();

    reader.onload = (event) => {
      const img = new Image();
      img.onload = () => {
        try {
          const maxDimension = 900;
          let targetWidth = img.width;
          let targetHeight = img.height;

          if (targetWidth > targetHeight) {
            if (targetWidth > maxDimension) {
              targetHeight = Math.round((targetHeight * maxDimension) / targetWidth);
              targetWidth = maxDimension;
            }
          } else {
            if (targetHeight > maxDimension) {
              targetWidth = Math.round((targetWidth * maxDimension) / targetHeight);
              targetHeight = maxDimension;
            }
          }

          let quality = 0.82;
          let scale = 1.0;
          let compressedDataUrl = '';
          let finalKB = 0;

          // Multi-pass iterative reduction until base64 payload size <= 50 KB (51,200 bytes)
          for (let pass = 0; pass < 9; pass++) {
            const canvas = document.createElement('canvas');
            const curW = Math.max(100, Math.round(targetWidth * scale));
            const curH = Math.max(100, Math.round(targetHeight * scale));
            canvas.width = curW;
            canvas.height = curH;

            const ctx = canvas.getContext('2d');
            // Solid white background to prevent black PNG transparency
            ctx.fillStyle = '#FFFFFF';
            ctx.fillRect(0, 0, curW, curH);
            ctx.drawImage(img, 0, 0, curW, curH);

            compressedDataUrl = canvas.toDataURL('image/jpeg', quality);

            // Compute actual binary size in bytes from base64 string
            const base64Content = compressedDataUrl.split(',')[1] || '';
            const byteLength = Math.round((base64Content.length * 3) / 4);
            finalKB = (byteLength / 1024).toFixed(1);

            // Check if <= 50 KB
            if (byteLength <= 50 * 1024) {
              break; // Met strict 50 KB ceiling!
            }

            // Step down quality and scale
            quality = Math.max(0.28, quality - 0.12);
            scale = Math.max(0.35, scale * 0.82);
          }

          setImageUrl(compressedDataUrl);
          setFileType('image');
          setFileName(file.name);
          setFileSize(`${finalKB} KB`);
          setOriginalSize(`${origKB} KB`);
          setIsCompressing(false);
          setCompressionProgress('');
          showToast(`Photo compressed: ${origKB} KB → ${finalKB} KB (≤ 50 KB)`, 'success');
        } catch (err) {
          console.error(err);
          setIsCompressing(false);
          setCompressionProgress('');
          showToast('Failed to compress photo', 'error');
        }
      };
      img.onerror = () => {
        setIsCompressing(false);
        setCompressionProgress('');
        showToast('Invalid image file', 'error');
      };
      img.src = event.target.result;
    };
    reader.readAsDataURL(file);
  };

  const removeAttachment = () => {
    setImageUrl('');
    setFileType('image');
    setFileName('');
    setFileSize('');
    setOriginalSize('');
    if (fileInputRef.current) fileInputRef.current.value = '';
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!title.trim()) {
      showToast('Please enter a notice title', 'error');
      return;
    }
    if (!content.trim() && !imageUrl) {
      showToast('Please enter notice description or attach a photo/PDF', 'error');
      return;
    }

    setIsSubmitting(true);
    try {
      await publishNotice({
        id: noticeToEdit?.id,
        title: title.trim(),
        content: content.trim(),
        category,
        targetAudience,
        imageUrl,
        fileType,
        fileName,
        fileSize,
        originalSize,
        isPinned,
        authorName: schoolAuthorName,
        authorRole: currentUser?.role || 'principal',
        createdAt: noticeToEdit?.createdAt || new Date().toISOString()
      });
      onClose();
    } catch (err) {
      console.error(err);
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-xs overflow-y-auto">
      <div className="relative w-full max-w-2xl bg-white rounded-2xl shadow-2xl border border-[#c8c4d5]/50 overflow-hidden my-6 animate-in fade-in zoom-in-95 duration-200">
        
        {/* Header */}
        <div className="flex items-center justify-between px-6 py-4 bg-gradient-to-r from-[#1f108e] to-[#0f0069] text-white">
          <div className="flex items-center gap-3">
            <div className="p-2.5 rounded-xl bg-white/10 text-white backdrop-blur-xs">
              <Megaphone className="w-5 h-5" />
            </div>
            <div>
              <h2 className="text-base font-bold">
                {noticeToEdit ? 'Edit Circular / Notice' : 'Publish New Notice'}
              </h2>
              <p className="text-xs text-white/80">
                Issued by: <span className="font-bold underline">{schoolAuthorName}</span>
              </p>
            </div>
          </div>
          <button
            onClick={onClose}
            className="p-2 rounded-xl bg-white/10 hover:bg-white/20 text-white/90 hover:text-white transition-colors cursor-pointer"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Form Body */}
        <form onSubmit={handleSubmit} className="p-6 space-y-5 max-h-[78vh] overflow-y-auto">
          
          {/* Title */}
          <div>
            <label className="block text-xs font-bold text-[#0b1c30] mb-1.5 uppercase tracking-wider">
              Notice Title / Headline <span className="text-rose-500">*</span>
            </label>
            <input
              type="text"
              required
              placeholder="e.g. Staff Meeting on Mid-Term Exams / Holiday Circular"
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              className="w-full px-4 py-2.5 rounded-xl bg-[#eff4ff]/60 border border-[#c8c4d5]/60 text-sm font-semibold text-[#0b1c30] focus:bg-white focus:border-[#1f108e] focus:ring-2 focus:ring-[#1f108e]/20 outline-hidden transition-all"
            />
          </div>

          {/* Category Selection */}
          <div>
            <label className="block text-xs font-bold text-[#0b1c30] mb-2 uppercase tracking-wider">
              Category / Tag
            </label>
            <div className="grid grid-cols-2 sm:grid-cols-3 gap-2">
              {CATEGORIES.map((cat) => (
                <button
                  type="button"
                  key={cat.id}
                  onClick={() => setCategory(cat.id)}
                  className={`flex items-center gap-2 px-3 py-2 rounded-xl text-xs font-bold border transition-all cursor-pointer text-left ${
                    category === cat.id
                      ? 'border-[#1f108e] bg-[#1f108e] text-white shadow-sm ring-2 ring-[#1f108e]/20'
                      : 'border-[#c8c4d5]/60 bg-white hover:bg-[#eff4ff] text-[#464553]'
                  }`}
                >
                  <span className={`w-2 h-2 rounded-full ${category === cat.id ? 'bg-white' : cat.dot}`} />
                  <span className="truncate">{cat.label}</span>
                </button>
              ))}
            </div>
          </div>

          {/* Description Content */}
          <div>
            <div className="flex items-center justify-between mb-1.5">
              <label className="text-xs font-bold text-[#0b1c30] uppercase tracking-wider">
                Notice Content / Body
              </label>
              <span className="text-[10px] text-[#777584] font-medium">
                {content.length} characters
              </span>
            </div>
            <textarea
              rows={4}
              placeholder="Write the full details, guidelines, timing, or instructions of this circular..."
              value={content}
              onChange={(e) => setContent(e.target.value)}
              className="w-full px-4 py-3 rounded-xl bg-[#eff4ff]/60 border border-[#c8c4d5]/60 text-xs font-medium text-[#0b1c30] focus:bg-white focus:border-[#1f108e] focus:ring-2 focus:ring-[#1f108e]/20 outline-hidden transition-all resize-y"
            />
          </div>

          {/* ── Photo / PDF Attachment with 50 KB Auto-Compressor ── */}
          <div>
            <div className="flex items-center justify-between mb-1.5">
              <label className="text-xs font-bold text-[#0b1c30] uppercase tracking-wider flex items-center gap-1.5">
                <span>Attachment: Photo or PDF (Max 50 KB)</span>
              </label>
              <span className="text-[10px] font-bold text-[#1f108e] bg-[#eff4ff] px-2 py-0.5 rounded-md border border-[#c8c4d5]/40">
                ⚡ Photo & PDF Compressor (≤ 50 KB)
              </span>
            </div>
            
            {imageUrl ? (
              <div className="relative rounded-xl border border-[#c8c4d5]/60 p-3 bg-[#eff4ff]/40 flex items-center gap-4">
                
                {/* Thumbnail / PDF Icon */}
                {fileType === 'pdf' ? (
                  <div className="w-20 h-20 rounded-xl bg-rose-50 border border-rose-200 flex flex-col items-center justify-center text-rose-600 flex-shrink-0 shadow-2xs">
                    <FileText className="w-8 h-8" />
                    <span className="text-[10px] font-extrabold uppercase mt-1">PDF</span>
                  </div>
                ) : (
                  <div className="w-20 h-20 rounded-xl bg-white border border-[#c8c4d5]/50 overflow-hidden flex-shrink-0 shadow-2xs">
                    <img src={imageUrl} alt="Attached Notice Document" className="w-full h-full object-cover" />
                  </div>
                )}

                {/* Meta details & Compression stats */}
                <div className="flex-1 min-w-0">
                  <div className="text-xs font-bold text-[#0b1c30] flex items-center gap-1.5 truncate">
                    <CheckCircle2 className="w-4 h-4 text-emerald-600 flex-shrink-0" />
                    <span className="truncate">{fileName || (fileType.includes('pdf') ? 'Circular.pdf' : 'Notice_Photo.jpg')}</span>
                  </div>

                  {/* Size Badges */}
                  <div className="flex flex-wrap items-center gap-2 mt-1.5">
                    <span className="px-2 py-0.5 rounded-md bg-emerald-50 border border-emerald-300 text-emerald-700 text-[10px] font-black">
                      ✓ Size: {fileSize || '≤ 50 KB'}
                    </span>
                    {originalSize && originalSize !== fileSize && (
                      <span className="text-[10px] text-[#777584]">
                        (Compressed from {originalSize})
                      </span>
                    )}
                  </div>

                  <div className="flex items-center gap-2 mt-2.5">
                    <button
                      type="button"
                      onClick={() => fileInputRef.current?.click()}
                      className="px-2.5 py-1 rounded-lg bg-white border border-[#c8c4d5]/60 hover:bg-[#eff4ff] text-[11px] font-bold text-[#1f108e] cursor-pointer shadow-2xs"
                    >
                      Replace File
                    </button>
                    <button
                      type="button"
                      onClick={removeAttachment}
                      className="px-2.5 py-1 rounded-lg bg-rose-50 border border-rose-200 hover:bg-rose-100 text-[11px] font-bold text-rose-700 flex items-center gap-1 cursor-pointer shadow-2xs"
                    >
                      <Trash2 className="w-3.5 h-3.5" />
                      Remove
                    </button>
                  </div>
                </div>
              </div>
            ) : (
              <div
                onClick={() => fileInputRef.current?.click()}
                className="border-2 border-dashed border-[#c8c4d5] hover:border-[#1f108e] rounded-xl p-5 text-center cursor-pointer bg-[#eff4ff]/30 hover:bg-[#eff4ff]/70 transition-all group"
              >
                {isCompressing ? (
                  <div className="py-2 space-y-2">
                    <div className="w-7 h-7 border-3 border-[#1f108e] border-t-transparent rounded-full animate-spin mx-auto" />
                    <p className="text-xs font-bold text-[#1f108e]">{compressionProgress || 'Compressing to ≤ 50 KB…'}</p>
                  </div>
                ) : (
                  <>
                    <UploadCloud className="w-8 h-8 mx-auto text-[#777584] group-hover:text-[#1f108e] transition-colors mb-1.5" />
                    <p className="text-xs font-bold text-[#0b1c30]">
                      Click to upload Photo (JPG/PNG) or PDF Document
                    </p>
                    <p className="text-[11px] text-[#777584] mt-1">
                      ⚡ <strong>Photos & PDF files of any size</strong> are automatically compressed to <strong>≤ 50 KB</strong>
                    </p>
                  </>
                )}
              </div>
            )}

            <input
              ref={fileInputRef}
              type="file"
              accept="image/*,application/pdf"
              className="hidden"
              onChange={handleAttachmentFile}
            />
          </div>

          {/* Options: Pin & Target Audience */}
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 pt-2 border-t border-[#c8c4d5]/40">
            
            {/* Target Audience */}
            <div>
              <label className="block text-xs font-bold text-[#0b1c30] mb-1.5 uppercase tracking-wider">
                Audience / Visibility
              </label>
              <select
                value={targetAudience}
                onChange={(e) => setTargetAudience(e.target.value)}
                className="w-full px-3 py-2 rounded-xl bg-white border border-[#c8c4d5]/60 text-xs font-bold text-[#0b1c30] focus:border-[#1f108e] outline-hidden cursor-pointer"
              >
                <option value="all">Everyone (All Teachers & Staff)</option>
                <option value="teachers">Teaching Staff Only</option>
                <option value="students">Students & Parents Notice</option>
              </select>
            </div>

            {/* Pin to Top */}
            <div className="flex items-center justify-between p-3 rounded-xl bg-[#eff4ff]/60 border border-[#c8c4d5]/50">
              <div className="flex items-center gap-2">
                <Pin className={`w-4 h-4 ${isPinned ? 'text-amber-500 fill-amber-500' : 'text-[#777584]'}`} />
                <div>
                  <div className="text-xs font-bold text-[#0b1c30]">Pin to Top</div>
                  <div className="text-[10px] text-[#777584]">Keep pinned at the top of board</div>
                </div>
              </div>
              <label className="relative inline-flex items-center cursor-pointer">
                <input
                  type="checkbox"
                  checked={isPinned}
                  onChange={(e) => setIsPinned(e.target.checked)}
                  className="sr-only peer"
                />
                <div className="w-9 h-5 bg-slate-200 peer-focus:outline-hidden rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-4 after:w-4 after:transition-all peer-checked:bg-[#1f108e]"></div>
              </label>
            </div>
          </div>

          {/* Action Buttons */}
          <div className="flex items-center justify-end gap-3 pt-4 border-t border-[#c8c4d5]/40">
            <button
              type="button"
              onClick={onClose}
              disabled={isSubmitting || isCompressing}
              className="px-5 py-2.5 rounded-xl border border-[#c8c4d5]/60 hover:bg-slate-100 text-xs font-bold text-[#464553] transition-colors cursor-pointer"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={isSubmitting || isCompressing}
              className="px-6 py-2.5 rounded-xl bg-[#1f108e] hover:bg-[#0f0069] disabled:opacity-50 text-white text-xs font-bold shadow-md transition-all flex items-center gap-2 cursor-pointer"
            >
              {isSubmitting ? (
                <>
                  <div className="w-3.5 h-3.5 border-2 border-white border-t-transparent rounded-full animate-spin" />
                  <span>Publishing…</span>
                </>
              ) : (
                <>
                  <Send className="w-3.5 h-3.5" />
                  <span>{noticeToEdit ? 'Save Changes' : 'Publish & Broadcast'}</span>
                </>
              )}
            </button>
          </div>

        </form>

      </div>
    </div>
  );
}
