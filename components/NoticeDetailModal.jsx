'use client';

import React, { useEffect, useState } from 'react';
import { useSchoolStore } from '../lib/store';
import {
  X, Pin, Calendar, User, Clock, Eye,
  Maximize2, Share2, Printer, Edit2, Trash2,
  CheckCircle2, Megaphone, Download, FileText,
  ExternalLink
} from 'lucide-react';

const CATEGORY_STYLES = {
  Urgent: { bg: 'bg-rose-50 text-rose-700 border-rose-200', dot: 'bg-rose-500' },
  Meeting: { bg: 'bg-blue-50 text-blue-700 border-blue-200', dot: 'bg-blue-500' },
  Holiday: { bg: 'bg-emerald-50 text-emerald-700 border-emerald-200', dot: 'bg-emerald-500' },
  Academic: { bg: 'bg-purple-50 text-purple-700 border-purple-200', dot: 'bg-purple-500' },
  Event: { bg: 'bg-amber-50 text-amber-700 border-amber-200', dot: 'bg-amber-500' },
  General: { bg: 'bg-slate-100 text-slate-700 border-slate-200', dot: 'bg-slate-500' }
};

export default function NoticeDetailModal({ notice, onClose, onEdit }) {
  const { markNoticeAsRead, deleteNotice, currentUser, confirmAction, settings } = useSchoolStore();
  const [isPhotoZoomed, setIsPhotoZoomed] = useState(false);

  const isPrincipal = currentUser?.role === 'principal';

  useEffect(() => {
    if (notice?.id) {
      markNoticeAsRead(notice.id);
    }
  }, [notice?.id]);

  if (!notice) return null;

  const style = CATEGORY_STYLES[notice.category] || CATEGORY_STYLES.General;
  const createdDate = notice.createdAt ? new Date(notice.createdAt) : new Date();

  const formattedDate = createdDate.toLocaleDateString('en-IN', {
    weekday: 'long',
    day: 'numeric',
    month: 'short',
    year: 'numeric'
  });

  const formattedTime = createdDate.toLocaleTimeString('en-IN', {
    hour: '2-digit',
    minute: '2-digit',
    hour12: true
  }).toUpperCase();

  const isPdf = notice.fileType === 'pdf' || notice.imageUrl?.startsWith('data:application/pdf') || notice.fileName?.toLowerCase().endsWith('.pdf');

  const handleDelete = () => {
    confirmAction({
      title: 'Delete Notice?',
      message: `Are you sure you want to permanently delete "${notice.title}"?`,
      confirmText: 'Delete',
      type: 'danger',
      onConfirm: async () => {
        await deleteNotice(notice.id);
        onClose();
      }
    });
  };

  const handleShareWhatsApp = () => {
    const text = `📢 *NOTICE: ${notice.title}*\n🏫 *${settings.instituteName || 'Smart School'}*\n📅 Date: ${formattedDate} (${formattedTime})\n🏷️ Category: ${notice.category}\n\n${notice.content || ''}\n\n— Issued by ${notice.authorName || 'Principal'}`;
    const url = `https://wa.me/?text=${encodeURIComponent(text)}`;
    window.open(url, '_blank');
  };

  const handlePrint = () => {
    window.print();
  };

  const handleDownloadPdf = () => {
    if (!notice.imageUrl) return;
    const a = document.createElement('a');
    a.href = notice.imageUrl;
    a.download = notice.fileName || 'School_Circular.pdf';
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
  };

  const handleOpenPdfNewTab = () => {
    if (!notice.imageUrl) return;
    const win = window.open();
    if (win) {
      win.document.write(
        `<iframe src="${notice.imageUrl}" frameborder="0" style="border:0; top:0px; left:0px; bottom:0px; right:0px; width:100%; height:100%;" allowfullscreen></iframe>`
      );
    }
  };

  return (
    <>
      <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-xs overflow-y-auto print:p-0 print:bg-white">
        <div className="relative w-full max-w-2xl bg-white rounded-2xl shadow-2xl border border-[#c8c4d5]/50 overflow-hidden my-6 animate-in fade-in zoom-in-95 duration-200 print:shadow-none print:border-none">
          
          {/* Header Banner */}
          <div className="flex items-center justify-between px-6 py-4 bg-gradient-to-r from-[#1f108e] to-[#0f0069] text-white print:bg-none print:text-[#0b1c30] print:border-b print:border-slate-300">
            <div className="flex items-center gap-3">
              <div className="p-2 rounded-xl bg-white/10 text-white backdrop-blur-xs print:hidden">
                <Megaphone className="w-5 h-5" />
              </div>
              <div>
                <span className="text-[11px] uppercase tracking-wider text-white/80 font-extrabold print:text-slate-500">
                  School Circular / Notice
                </span>
                <h2 className="text-base font-bold text-white print:text-xl">
                  {settings.instituteName || 'Smart School'}
                </h2>
              </div>
            </div>
            <div className="flex items-center gap-2 print:hidden">
              {isPrincipal && (
                <>
                  <button
                    onClick={() => { onClose(); onEdit(notice); }}
                    className="p-2 rounded-xl bg-white/10 hover:bg-white/20 text-white transition-colors cursor-pointer"
                    title="Edit Notice"
                  >
                    <Edit2 className="w-4 h-4" />
                  </button>
                  <button
                    onClick={handleDelete}
                    className="p-2 rounded-xl bg-rose-500/20 hover:bg-rose-500/40 text-rose-200 transition-colors cursor-pointer"
                    title="Delete Notice"
                  >
                    <Trash2 className="w-4 h-4" />
                  </button>
                </>
              )}
              <button
                onClick={onClose}
                className="p-2 rounded-xl bg-white/10 hover:bg-white/20 text-white/90 hover:text-white transition-colors cursor-pointer"
              >
                <X className="w-5 h-5" />
              </button>
            </div>
          </div>

          {/* Notice Content Card */}
          <div className="p-6 space-y-5 max-h-[80vh] overflow-y-auto">
            
            {/* Meta Tags Bar */}
            <div className="flex flex-wrap items-center justify-between gap-3 pb-3 border-b border-[#c8c4d5]/40">
              <div className="flex items-center gap-2">
                <span className={`inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-bold border ${style.bg}`}>
                  <span className={`w-2 h-2 rounded-full ${style.dot}`} />
                  {notice.category}
                </span>

                {notice.isPinned && (
                  <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-xs font-bold bg-amber-50 text-amber-700 border border-amber-300">
                    <Pin className="w-3 h-3 fill-amber-500 text-amber-500" />
                    Pinned
                  </span>
                )}
              </div>

              <div className="flex items-center gap-4 text-xs text-[#777584]">
                <div className="flex items-center gap-1.5 font-medium">
                  <Calendar className="w-3.5 h-3.5 text-[#1f108e]" />
                  <span>{formattedDate}</span>
                </div>
                <div className="flex items-center gap-1.5 font-medium">
                  <Clock className="w-3.5 h-3.5 text-[#1f108e]" />
                  <span>{formattedTime}</span>
                </div>
              </div>
            </div>

            {/* Title */}
            <div>
              <h1 className="text-xl font-black text-[#0b1c30] leading-snug">
                {notice.title}
              </h1>
              <div className="flex items-center gap-2 mt-1.5 text-xs text-[#464553]">
                <span className="font-semibold">Issued by:</span>
                <span className="font-bold text-[#1f108e]">{notice.authorName || settings.instituteName || 'School Management'}</span>
                <span className="text-[#c8c4d5]">•</span>
                <span className="text-[11px] bg-[#eff4ff] text-[#0051d5] px-2 py-0.5 rounded-md font-bold uppercase">
                  {settings.instituteName || notice.authorRole || 'School Management'}
                </span>
              </div>
            </div>

            {/* Notice Body */}
            {notice.content && (
              <div className="p-4 rounded-xl bg-[#eff4ff]/40 border border-[#c8c4d5]/40 text-sm text-[#0b1c30] leading-relaxed whitespace-pre-wrap font-sans">
                {notice.content}
              </div>
            )}

            {/* ── Attachment Rendering (PDF or Image) ── */}
            {notice.imageUrl && (
              <div className="space-y-2">
                <div className="flex items-center justify-between text-xs font-bold text-[#0b1c30]">
                  <span>Attached Document:</span>
                  {notice.fileSize && (
                    <span className="text-[11px] font-bold text-emerald-700 bg-emerald-50 px-2 py-0.5 rounded-md border border-emerald-200">
                      ✓ {notice.fileSize} (≤ 50 KB)
                    </span>
                  )}
                </div>

                {isPdf ? (
                  /* PDF Attachment Card */
                  <div className="p-4 rounded-xl border border-rose-200 bg-rose-50/40 flex flex-col sm:flex-row sm:items-center justify-between gap-3 shadow-2xs">
                    <div className="flex items-center gap-3 min-w-0">
                      <div className="w-12 h-12 rounded-xl bg-rose-600 text-white flex items-center justify-center flex-shrink-0 shadow-sm">
                        <FileText className="w-6 h-6" />
                      </div>
                      <div className="min-w-0">
                        <p className="text-xs font-bold text-[#0b1c30] truncate">
                          {notice.fileName || 'School_Circular.pdf'}
                        </p>
                        <p className="text-[11px] text-[#777584]">
                          Official PDF Document &bull; {notice.fileSize || '≤ 50 KB'}
                        </p>
                      </div>
                    </div>

                    <div className="flex items-center gap-2 flex-shrink-0">
                      <button
                        type="button"
                        onClick={handleOpenPdfNewTab}
                        className="px-3 py-1.5 rounded-lg bg-white border border-[#c8c4d5]/60 hover:bg-[#eff4ff] text-xs font-bold text-[#1f108e] flex items-center gap-1.5 cursor-pointer shadow-2xs"
                      >
                        <ExternalLink className="w-3.5 h-3.5" />
                        <span>Open PDF</span>
                      </button>
                      <button
                        type="button"
                        onClick={handleDownloadPdf}
                        className="px-3 py-1.5 rounded-lg bg-rose-600 hover:bg-rose-700 text-white text-xs font-bold flex items-center gap-1.5 cursor-pointer shadow-2xs"
                      >
                        <Download className="w-3.5 h-3.5" />
                        <span>Download</span>
                      </button>
                    </div>
                  </div>
                ) : (
                  /* Photo Image Attachment */
                  <div
                    onClick={() => setIsPhotoZoomed(true)}
                    className="relative rounded-xl border border-[#c8c4d5]/60 overflow-hidden bg-slate-50 cursor-pointer group max-h-96 flex items-center justify-center shadow-sm"
                  >
                    <img
                      src={notice.imageUrl}
                      alt={notice.title}
                      className="w-full h-auto object-contain max-h-96 group-hover:scale-101 transition-transform duration-200"
                    />
                    <div className="absolute inset-0 bg-black/30 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center text-white text-xs font-bold gap-2">
                      <Maximize2 className="w-4 h-4" />
                      <span>View Full Size ({notice.fileSize || '≤ 50 KB'})</span>
                    </div>
                  </div>
                )}
              </div>
            )}

            {/* Footer Actions */}
            <div className="flex flex-wrap items-center justify-between gap-3 pt-4 border-t border-[#c8c4d5]/40 print:hidden">
              <div className="text-[11px] text-[#777584] flex items-center gap-1.5">
                <CheckCircle2 className="w-4 h-4 text-emerald-600" />
                <span>Notice acknowledged and marked as read</span>
              </div>

              <div className="flex items-center gap-2">
                <button
                  type="button"
                  onClick={handleShareWhatsApp}
                  className="px-3.5 py-2 rounded-xl bg-emerald-50 hover:bg-emerald-100 border border-emerald-300 text-xs font-bold text-emerald-700 transition-colors flex items-center gap-1.5 cursor-pointer"
                >
                  <Share2 className="w-3.5 h-3.5" />
                  <span>WhatsApp</span>
                </button>
                <button
                  type="button"
                  onClick={handlePrint}
                  className="px-3.5 py-2 rounded-xl bg-[#eff4ff] hover:bg-[#dce9ff] border border-[#c8c4d5]/60 text-xs font-bold text-[#1f108e] transition-colors flex items-center gap-1.5 cursor-pointer"
                >
                  <Printer className="w-3.5 h-3.5" />
                  <span>Print</span>
                </button>
                <button
                  type="button"
                  onClick={onClose}
                  className="px-4 py-2 rounded-xl bg-[#1f108e] hover:bg-[#0f0069] text-white text-xs font-bold transition-colors cursor-pointer"
                >
                  Done
                </button>
              </div>
            </div>

          </div>

        </div>
      </div>

      {/* Lightbox / Zoom Modal */}
      {isPhotoZoomed && (
        <div
          className="fixed inset-0 z-60 bg-black/90 backdrop-blur-md flex items-center justify-center p-4"
          onClick={() => setIsPhotoZoomed(false)}
        >
          <div className="relative max-w-4xl max-h-[90vh] w-full flex flex-col items-center">
            <button
              onClick={() => setIsPhotoZoomed(false)}
              className="absolute -top-12 right-0 p-2 rounded-full bg-white/20 hover:bg-white/30 text-white transition-colors cursor-pointer"
            >
              <X className="w-6 h-6" />
            </button>
            <img
              src={notice.imageUrl}
              alt="Zoomed Notice Document"
              className="max-w-full max-h-[85vh] object-contain rounded-xl shadow-2xl border border-white/20"
              onClick={(e) => e.stopPropagation()}
            />
          </div>
        </div>
      )}
    </>
  );
}
