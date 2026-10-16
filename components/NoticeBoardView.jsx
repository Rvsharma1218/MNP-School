'use client';

import React, { useState, useMemo } from 'react';
import { useSchoolStore } from '../lib/store';
import { t } from '../lib/translations';
import {
  Megaphone, FileText, Plus, Search, Pin, Calendar,
  Clock, Eye, Image as ImageIcon, CheckCircle2,
  Trash2, Edit2, AlertCircle, Share2, Filter,
  Sparkles, Bell, ExternalLink
} from 'lucide-react';

const CATEGORIES = ['All', 'Urgent', 'Meeting', 'Holiday', 'Academic', 'Event', 'General'];

const CATEGORY_STYLES = {
  Urgent: { bg: 'bg-rose-50 text-rose-700 border-rose-200', dot: 'bg-rose-500' },
  Meeting: { bg: 'bg-blue-50 text-blue-700 border-blue-200', dot: 'bg-blue-500' },
  Holiday: { bg: 'bg-emerald-50 text-emerald-700 border-emerald-200', dot: 'bg-emerald-500' },
  Academic: { bg: 'bg-purple-50 text-purple-700 border-purple-200', dot: 'bg-purple-500' },
  Event: { bg: 'bg-amber-50 text-amber-700 border-amber-200', dot: 'bg-amber-500' },
  General: { bg: 'bg-slate-100 text-slate-700 border-slate-200', dot: 'bg-slate-500' }
};

export default function NoticeBoardView({ onOpenPublish, onOpenView, onOpenEdit }) {
  const { notices, currentUser, markAllNoticesAsRead, deleteNotice, publishNotice, confirmAction, teacherPermissions, settings } = useSchoolStore();

  const lang = settings?.appLanguage || 'en';

  const [searchQuery, setSearchQuery] = useState('');
  const [selectedCategory, setSelectedCategory] = useState('All');
  const [filterAudience, setFilterAudience] = useState('all');

  const isPrincipal = currentUser?.role === 'principal';
  const currentUserId = currentUser?.uid || currentUser?.teacherId || currentUser?.id || '';

  // Filtered & Sorted Notices
  const filteredNotices = useMemo(() => {
    return notices.filter((n) => {
      // Category filter
      if (selectedCategory !== 'All' && n.category !== selectedCategory) return false;

      // Audience filter
      if (filterAudience !== 'all' && n.targetAudience && n.targetAudience !== filterAudience && n.targetAudience !== 'all') {
        return false;
      }

      // Search query
      if (searchQuery.trim()) {
        const q = searchQuery.toLowerCase();
        const matchesTitle = n.title?.toLowerCase().includes(q);
        const matchesContent = n.content?.toLowerCase().includes(q);
        const matchesAuthor = n.authorName?.toLowerCase().includes(q);
        const matchesCat = n.category?.toLowerCase().includes(q);
        if (!matchesTitle && !matchesContent && !matchesAuthor && !matchesCat) return false;
      }

      return true;
    });
  }, [notices, selectedCategory, filterAudience, searchQuery]);

  const stats = useMemo(() => {
    const total = notices.length;
    const pinned = notices.filter(n => n.isPinned).length;
    const urgent = notices.filter(n => n.category === 'Urgent').length;
    const unread = notices.filter(n => currentUserId ? !(n.readBy || []).includes(currentUserId) : false).length;
    return { total, pinned, urgent, unread };
  }, [notices, currentUserId]);

  const handleTogglePin = async (e, notice) => {
    e.stopPropagation();
    try {
      await publishNotice({
        ...notice,
        isPinned: !notice.isPinned
      });
    } catch (err) {
      console.error(err);
    }
  };

  const handleDelete = (e, notice) => {
    e.stopPropagation();
    confirmAction({
      title: 'Delete Notice?',
      message: `Are you sure you want to permanently delete "${notice.title}"?`,
      confirmText: 'Delete',
      type: 'danger',
      onConfirm: async () => {
        await deleteNotice(notice.id);
      }
    });
  };

  return (
    <div className="p-5 lg:p-8 space-y-6 max-w-7xl mx-auto">
      
      {/* ── Top Header & Stats ── */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 bg-gradient-to-r from-[#1f108e] to-[#0f0069] rounded-2xl p-6 text-white shadow-lg relative overflow-hidden">
        <div className="relative z-10">
          <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-white/10 text-white text-xs font-bold mb-2 backdrop-blur-xs">
            <Megaphone className="w-3.5 h-3.5" />
            <span>Official Circulars & Notice Board</span>
          </div>
          <h1 className="text-2xl lg:text-3xl font-black tracking-tight">
            School Notice Board
          </h1>
          <p className="text-xs text-white/80 mt-1 max-w-xl">
            Real-time announcements, circulars, exam schedules, and holiday notifications for staff and teachers.
          </p>
        </div>

        <div className="flex items-center gap-3 relative z-10 flex-shrink-0">
          {stats.unread > 0 && (
            <button
              onClick={markAllNoticesAsRead}
              className="px-3.5 py-2.5 rounded-xl bg-white/15 hover:bg-white/25 text-white text-xs font-bold backdrop-blur-xs transition-all flex items-center gap-1.5 cursor-pointer"
            >
              <CheckCircle2 className="w-4 h-4 text-emerald-400" />
              <span>Mark All Read</span>
            </button>
          )}

          {(isPrincipal || teacherPermissions?.canPostNotices !== false) && (
            <button
              onClick={onOpenPublish}
              className="px-5 py-2.5 rounded-xl bg-white hover:bg-[#eff4ff] text-[#1f108e] font-black text-xs shadow-md transition-all flex items-center gap-2 cursor-pointer hover:scale-102"
            >
              <Plus className="w-4 h-4 stroke-[3]" />
              <span>{t('publishNotice', lang)}</span>
            </button>
          )}
        </div>

        {/* Subtle Background Pattern */}
        <div className="absolute right-0 top-0 bottom-0 w-1/3 bg-white/5 skew-x-12 pointer-events-none" />
      </div>

      {/* ── Metric Summary Badges ── */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-3.5">
        <div className="p-4 rounded-xl bg-white border border-[#c8c4d5]/50 shadow-xs flex items-center justify-between">
          <div>
            <div className="text-[11px] font-bold text-[#777584] uppercase tracking-wider">Total Notices</div>
            <div className="text-xl font-black text-[#0b1c30] mt-0.5">{stats.total}</div>
          </div>
          <div className="p-2.5 rounded-xl bg-[#eff4ff] text-[#1f108e]">
            <Megaphone className="w-5 h-5" />
          </div>
        </div>

        <div className="p-4 rounded-xl bg-white border border-[#c8c4d5]/50 shadow-xs flex items-center justify-between">
          <div>
            <div className="text-[11px] font-bold text-[#777584] uppercase tracking-wider">Unread Alerts</div>
            <div className={`text-xl font-black mt-0.5 ${stats.unread > 0 ? 'text-rose-600' : 'text-emerald-600'}`}>
              {stats.unread}
            </div>
          </div>
          <div className={`p-2.5 rounded-xl ${stats.unread > 0 ? 'bg-rose-50 text-rose-600' : 'bg-emerald-50 text-emerald-600'}`}>
            <Bell className="w-5 h-5" />
          </div>
        </div>

        <div className="p-4 rounded-xl bg-white border border-[#c8c4d5]/50 shadow-xs flex items-center justify-between">
          <div>
            <div className="text-[11px] font-bold text-[#777584] uppercase tracking-wider">Pinned Circulars</div>
            <div className="text-xl font-black text-[#0b1c30] mt-0.5">{stats.pinned}</div>
          </div>
          <div className="p-2.5 rounded-xl bg-amber-50 text-amber-600">
            <Pin className="w-5 h-5 fill-amber-500" />
          </div>
        </div>

        <div className="p-4 rounded-xl bg-white border border-[#c8c4d5]/50 shadow-xs flex items-center justify-between">
          <div>
            <div className="text-[11px] font-bold text-[#777584] uppercase tracking-wider">Urgent Action</div>
            <div className="text-xl font-black text-[#0b1c30] mt-0.5">{stats.urgent}</div>
          </div>
          <div className="p-2.5 rounded-xl bg-rose-50 text-rose-600">
            <AlertCircle className="w-5 h-5" />
          </div>
        </div>
      </div>

      {/* ── Search & Filter Controls ── */}
      <div className="flex flex-col md:flex-row items-stretch md:items-center justify-between gap-3 bg-white p-3.5 rounded-xl border border-[#c8c4d5]/50 shadow-xs">
        
        {/* Category Pills */}
        <div className="flex items-center gap-1.5 overflow-x-auto pb-1 md:pb-0 scrollbar-none">
          {CATEGORIES.map((cat) => {
            const count = cat === 'All' ? notices.length : notices.filter(n => n.category === cat).length;
            const active = selectedCategory === cat;
            return (
              <button
                key={cat}
                onClick={() => setSelectedCategory(cat)}
                className={`px-3 py-1.5 rounded-xl text-xs font-bold whitespace-nowrap transition-all cursor-pointer flex items-center gap-1.5 ${
                  active
                    ? 'bg-[#1f108e] text-white shadow-xs'
                    : 'bg-[#eff4ff]/60 hover:bg-[#eff4ff] text-[#464553] border border-[#c8c4d5]/40'
                }`}
              >
                <span>{cat}</span>
                <span className={`text-[10px] px-1.5 py-0.2 rounded-full font-bold ${active ? 'bg-white/20 text-white' : 'bg-[#dce9ff] text-[#0051d5]'}`}>
                  {count}
                </span>
              </button>
            );
          })}
        </div>

        {/* Search Bar */}
        <div className="relative min-w-[240px]">
          <Search className="w-4 h-4 text-[#777584] absolute left-3.5 top-1/2 -translate-y-1/2" />
          <input
            type="text"
            placeholder="Search notices, circulars…"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full pl-9.5 pr-4 py-2 rounded-xl bg-[#eff4ff]/60 border border-[#c8c4d5]/60 text-xs font-semibold text-[#0b1c30] focus:bg-white focus:border-[#1f108e] outline-hidden transition-all"
          />
        </div>

      </div>

      {/* ── Notice Cards Grid ── */}
      {filteredNotices.length > 0 ? (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-5">
          {filteredNotices.map((notice) => {
            const isRead = currentUserId ? (notice.readBy || []).includes(currentUserId) : true;
            const style = CATEGORY_STYLES[notice.category] || CATEGORY_STYLES.General;
            const date = notice.createdAt ? new Date(notice.createdAt) : new Date();
            const dateStr = date.toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric' });
            const timeStr = date.toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit', hour12: true });

            return (
              <div
                key={notice.id}
                onClick={() => onOpenView(notice)}
                className={`relative rounded-2xl bg-white border transition-all duration-200 hover:shadow-md cursor-pointer flex flex-col justify-between overflow-hidden group ${
                  notice.isPinned
                    ? 'border-amber-300 ring-2 ring-amber-100 shadow-xs'
                    : (!isRead ? 'border-[#1f108e]/50 ring-2 ring-[#1f108e]/10 shadow-xs' : 'border-[#c8c4d5]/50')
                }`}
              >
                {/* Pinned Ribbon */}
                {notice.isPinned && (
                  <div className="bg-gradient-to-r from-amber-500 to-amber-600 text-white text-[10px] font-black px-3 py-0.5 flex items-center justify-between">
                    <span className="flex items-center gap-1">
                      <Pin className="w-3 h-3 fill-white" />
                      PINNED CIRCULAR
                    </span>
                    <span className="opacity-90">High Priority</span>
                  </div>
                )}

                <div className="p-5 space-y-3.5">
                  
                  {/* Category & Date */}
                  <div className="flex items-center justify-between gap-2">
                    <span className={`inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-[11px] font-bold border ${style.bg}`}>
                      <span className={`w-1.5 h-1.5 rounded-full ${style.dot}`} />
                      {notice.category}
                    </span>

                    <div className="flex items-center gap-1.5 text-[11px] text-[#777584]">
                      <Calendar className="w-3 h-3 text-[#1f108e]" />
                      <span>{dateStr}</span>
                    </div>
                  </div>

                  {/* Title & Unread Indicator */}
                  <div>
                    <div className="flex items-start justify-between gap-2">
                      <h3 className="font-bold text-sm text-[#0b1c30] group-hover:text-[#1f108e] transition-colors leading-snug line-clamp-2">
                        {notice.title}
                      </h3>
                      {!isRead && (
                        <span className="w-2.5 h-2.5 rounded-full bg-rose-500 ring-4 ring-rose-100 flex-shrink-0 mt-1 animate-pulse" title="New / Unread" />
                      )}
                    </div>

                    {/* Excerpt */}
                    {notice.content && (
                      <p className="text-xs text-[#464553] mt-2 line-clamp-3 leading-relaxed font-sans">
                        {notice.content}
                      </p>
                    )}
                  </div>

                  {/* Attached Photo or PDF Thumbnail */}
                  {notice.imageUrl && (
                    <>
                      {notice.fileType === 'pdf' || notice.imageUrl?.startsWith('data:application/pdf') || notice.fileName?.toLowerCase().endsWith('.pdf') ? (
                        <div className="p-3 rounded-xl border border-rose-200 bg-rose-50/50 flex items-center justify-between gap-2.5">
                          <div className="flex items-center gap-2.5 min-w-0">
                            <div className="w-9 h-9 rounded-lg bg-rose-600 text-white flex items-center justify-center flex-shrink-0 shadow-2xs">
                              <FileText className="w-5 h-5" />
                            </div>
                            <div className="min-w-0">
                              <p className="text-xs font-bold text-[#0b1c30] truncate">
                                {notice.fileName || 'Circular_Document.pdf'}
                              </p>
                              <p className="text-[10px] text-rose-700 font-semibold">
                                PDF Attached &bull; {notice.fileSize || '≤ 50 KB'}
                              </p>
                            </div>
                          </div>
                          <span className="text-[10px] font-bold text-rose-700 bg-white border border-rose-200 px-2 py-0.5 rounded-md flex-shrink-0">
                            View PDF
                          </span>
                        </div>
                      ) : (
                        <div className="relative rounded-xl border border-[#c8c4d5]/50 overflow-hidden bg-slate-100 h-32 flex items-center justify-center">
                          <img
                            src={notice.imageUrl}
                            alt={notice.title}
                            className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-300"
                          />
                          <div className="absolute bottom-2 right-2 px-2 py-0.5 rounded-md bg-black/75 text-white text-[10px] font-bold flex items-center gap-1 backdrop-blur-xs shadow-sm">
                            <ImageIcon className="w-3 h-3" />
                            <span>Photo ({notice.fileSize || '≤ 50 KB'})</span>
                          </div>
                        </div>
                      )}
                    </>
                  )}

                </div>

                {/* Card Footer */}
                <div className="px-5 py-3 bg-[#eff4ff]/40 border-t border-[#c8c4d5]/40 flex items-center justify-between gap-2">
                  <div className="text-[11px] text-[#777584] truncate">
                    <span className="font-semibold">Issued by: </span>
                    <span className="font-bold text-[#0b1c30]">{notice.authorName || settings.instituteName || 'School Management'}</span>
                  </div>

                  <div className="flex items-center gap-1.5">
                    {isPrincipal && (
                      <>
                        <button
                          onClick={(e) => handleTogglePin(e, notice)}
                          className={`p-1.5 rounded-lg border transition-colors cursor-pointer ${
                            notice.isPinned
                              ? 'bg-amber-100 border-amber-300 text-amber-700'
                              : 'bg-white hover:bg-slate-100 border-[#c8c4d5]/50 text-[#777584]'
                          }`}
                          title={notice.isPinned ? 'Unpin Notice' : 'Pin Notice to Top'}
                        >
                          <Pin className={`w-3.5 h-3.5 ${notice.isPinned ? 'fill-amber-600' : ''}`} />
                        </button>
                        <button
                          onClick={(e) => { e.stopPropagation(); onOpenEdit(notice); }}
                          className="p-1.5 rounded-lg bg-white hover:bg-[#eff4ff] border border-[#c8c4d5]/50 text-[#1f108e] transition-colors cursor-pointer"
                          title="Edit Notice"
                        >
                          <Edit2 className="w-3.5 h-3.5" />
                        </button>
                        <button
                          onClick={(e) => handleDelete(e, notice)}
                          className="p-1.5 rounded-lg bg-white hover:bg-rose-50 border border-[#c8c4d5]/50 text-rose-600 transition-colors cursor-pointer"
                          title="Delete Notice"
                        >
                          <Trash2 className="w-3.5 h-3.5" />
                        </button>
                      </>
                    )}

                    <span className="text-xs font-bold text-[#1f108e] group-hover:underline flex items-center gap-1 pl-1">
                      <span>View</span>
                      <ExternalLink className="w-3 h-3" />
                    </span>
                  </div>
                </div>

              </div>
            );
          })}
        </div>
      ) : (
        <div className="p-12 text-center bg-white rounded-2xl border border-dashed border-[#c8c4d5] space-y-3">
          <div className="w-14 h-14 rounded-2xl bg-[#eff4ff] text-[#1f108e] flex items-center justify-center mx-auto">
            <Megaphone className="w-7 h-7" />
          </div>
          <h3 className="text-base font-bold text-[#0b1c30]">No Notices Found</h3>
          <p className="text-xs text-[#777584] max-w-sm mx-auto">
            {searchQuery
              ? `No circulars match "${searchQuery}". Try clearing search or category filters.`
              : 'There are currently no circulars or notices posted on the Notice Board.'}
          </p>
          {isPrincipal && (
            <button
              onClick={onOpenPublish}
              className="mt-2 px-5 py-2.5 rounded-xl bg-[#1f108e] hover:bg-[#0f0069] text-white text-xs font-bold shadow-md transition-all cursor-pointer inline-flex items-center gap-2"
            >
              <Plus className="w-4 h-4" />
              <span>Publish First Notice</span>
            </button>
          )}
        </div>
      )}

    </div>
  );
}
