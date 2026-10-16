'use client';

import React, { useState, useEffect } from 'react';
import {
  collection, query, orderBy, onSnapshot, doc, updateDoc, where
} from 'firebase/firestore';
import { db } from '../lib/firebase';
import { useSchoolStore } from '../lib/store';
import {
  MessageSquare, AlertCircle, CheckCircle2, Clock, Phone,
  Send, Reply, Filter, Search, User, ShieldAlert,
  ExternalLink, Check, RefreshCw, Sparkles, X, ChevronRight
} from 'lucide-react';

export default function ParentComplaintsView() {
  const { settings, currentUser, showToast } = useSchoolStore();
  const [complaints, setComplaints] = useState([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState('all'); // 'all' | 'pending' | 'urgent' | 'resolved'
  const [searchQuery, setSearchQuery] = useState('');
  
  // Reply Modal State
  const [replyingComplaint, setReplyingComplaint] = useState(null);
  const [replyText, setReplyText] = useState('');
  const [markResolvedOnReply, setMarkResolvedOnReply] = useState(true);
  const [sendingReply, setSendingReply] = useState(false);

  // Real-time Firestore Feedbacks / Complaints Stream
  useEffect(() => {
    let unsubscribe = null;
    try {
      const q = query(
        collection(db, 'feedbacks'),
        orderBy('createdAt', 'desc')
      );

      unsubscribe = onSnapshot(
        q,
        (snapshot) => {
          const list = [];
          snapshot.forEach((docSnap) => {
            const data = docSnap.data();
            list.push({
              docId: docSnap.id,
              id: docSnap.id,
              ...data
            });
          });
          setComplaints(list);
          setLoading(false);
        },
        (error) => {
          console.warn('Realtime complaints snapshot fallback:', error);
          // If orderBy('createdAt') fails due to index or missing field, fallback to plain query
          const fallbackQ = collection(db, 'feedbacks');
          unsubscribe = onSnapshot(fallbackQ, (snapshot) => {
            const list = [];
            snapshot.forEach((docSnap) => {
              list.push({ docId: docSnap.id, id: docSnap.id, ...docSnap.data() });
            });
            // Sort client-side
            list.sort((a, b) => {
              const dateA = new Date(a.createdAt || a.date || 0);
              const dateB = new Date(b.createdAt || b.date || 0);
              return dateB - dateA;
            });
            setComplaints(list);
            setLoading(false);
          });
        }
      );
    } catch (err) {
      console.error('Error initiating complaints stream:', err);
      setLoading(false);
    }

    return () => {
      if (unsubscribe) unsubscribe();
    };
  }, []);

  // Filter & Search Logic
  const filteredComplaints = complaints.filter((c) => {
    // Only show parent complaints or general feedback
    const isParentComplaint = c.type === 'parent_complaint' || c.studentName || c.studentId || c.admissionNo;
    if (!isParentComplaint && c.type !== 'feedback') return false;

    const isResolved = c.status === 'resolved' || c.resolved === true;
    const isUrgent = c.urgent === true || c.priority === 'urgent';

    if (filter === 'pending' && isResolved) return false;
    if (filter === 'resolved' && !isResolved) return false;
    if (filter === 'urgent' && !isUrgent) return false;

    if (searchQuery.trim()) {
      const q = searchQuery.toLowerCase();
      const match =
        (c.studentName && c.studentName.toLowerCase().includes(q)) ||
        (c.senderName && c.senderName.toLowerCase().includes(q)) ||
        (c.admissionNo && c.admissionNo.toLowerCase().includes(q)) ||
        (c.subject && c.subject.toLowerCase().includes(q)) ||
        (c.message && c.message.toLowerCase().includes(q)) ||
        (c.category && c.category.toLowerCase().includes(q)) ||
        (c.senderPhone && c.senderPhone.includes(q));
      if (!match) return false;
    }

    return true;
  });

  // KPI Counts
  const totalCount = complaints.length;
  const pendingCount = complaints.filter(c => c.status !== 'resolved' && !c.resolved).length;
  const urgentCount = complaints.filter(c => (c.urgent === true || c.priority === 'urgent') && c.status !== 'resolved' && !c.resolved).length;
  const resolvedCount = complaints.filter(c => c.status === 'resolved' || c.resolved).length;

  // Toggle Status Handler
  const handleToggleStatus = async (item) => {
    const isResolved = item.status === 'resolved' || item.resolved === true;
    const newStatus = isResolved ? 'in_progress' : 'resolved';
    const targetDocId = item.docId || item.id;

    try {
      const updateData = {
        status: newStatus,
        resolved: !isResolved,
        resolvedAt: !isResolved ? new Date().toISOString() : null,
      };

      await updateDoc(doc(db, 'feedbacks', targetDocId), updateData);
      
      // Also update redundant copy in system_feedbacks if it exists
      try {
        await updateDoc(doc(db, 'schoolDirectory', 'system_feedbacks', 'items', targetDocId), updateData);
      } catch (_) {}

      showToast(`Complaint marked as ${!isResolved ? 'Resolved' : 'Pending Review'}`, 'success');
    } catch (e) {
      console.error('Error updating complaint status:', e);
      showToast('Failed to update status: ' + e.message, 'error');
    }
  };

  // Submit Official Reply Handler
  const handleSendReply = async () => {
    if (!replyText.trim() || !replyingComplaint) return;
    setSendingReply(true);
    const targetDocId = replyingComplaint.docId || replyingComplaint.id;
    const now = new Date();

    try {
      const updateData = {
        reply: replyText.trim(),
        adminReply: replyText.trim(),
        repliedAt: now.toLocaleString('en-IN', { dateStyle: 'medium', timeStyle: 'short' }),
        repliedAtIso: now.toISOString(),
        repliedBy: currentUser?.name || 'Principal Office',
        unreadByParent: true,
        status: markResolvedOnReply ? 'resolved' : 'in_progress',
        resolved: markResolvedOnReply,
      };

      await updateDoc(doc(db, 'feedbacks', targetDocId), updateData);
      
      try {
        await updateDoc(doc(db, 'schoolDirectory', 'system_feedbacks', 'items', targetDocId), updateData);
      } catch (_) {}

      showToast('Official reply sent to parent successfully! They will see it in their portal.', 'success');
      setReplyingComplaint(null);
      setReplyText('');
    } catch (e) {
      console.error('Error sending reply:', e);
      showToast('Failed to send reply: ' + e.message, 'error');
    } finally {
      setSendingReply(false);
    }
  };

  return (
    <div className="space-y-6 pb-16 w-full animate-in fade-in duration-300 font-sans">
      
      {/* ── Top Header Banner ── */}
      <div className="bg-gradient-to-r from-[#eff4ff] via-[#dce9ff] to-[#eff4ff] p-6 rounded-3xl border border-[#c8c4d5]/40 shadow-xs flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div>
          <div className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-white/80 text-[11px] font-bold text-[#1f108e] mb-2 shadow-2xs">
            <MessageSquare className="w-3.5 h-3.5 text-[#316bf3]" />
            <span>Executive Grievance & Inquiries Desk</span>
          </div>
          <h2 className="text-2xl font-black text-[#0b1c30] tracking-tight">Parent Complaints & Messages</h2>
          <p className="text-xs text-[#464553] font-medium mt-0.5">
            Direct real-time communications from Parent Mobile App & Student Portal · Principal Response Center
          </p>
        </div>

        {/* Quick Metrics */}
        <div className="flex items-center gap-2">
          {urgentCount > 0 && (
            <div className="px-3.5 py-2 rounded-2xl bg-rose-50 border border-rose-200 text-rose-700 text-xs font-bold flex items-center gap-1.5 animate-pulse shadow-xs">
              <ShieldAlert className="w-4 h-4 text-rose-600" />
              <span>{urgentCount} Urgent Inquiries</span>
            </div>
          )}
          <div className="px-3.5 py-2 rounded-2xl bg-white border border-[#c8c4d5]/50 text-[#0b1c30] text-xs font-bold flex items-center gap-1.5 shadow-2xs">
            <Clock className="w-4 h-4 text-amber-500" />
            <span>{pendingCount} Pending Response</span>
          </div>
        </div>
      </div>

      {/* ── Metric Summary Tiles ── */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <button
          onClick={() => setFilter('all')}
          className={`p-4 rounded-2xl border text-left transition-all cursor-pointer ${
            filter === 'all'
              ? 'bg-[#1f108e] text-white border-transparent shadow-md'
              : 'bg-white border-[#c8c4d5]/50 text-[#0b1c30] hover:border-[#1f108e]/30'
          }`}
        >
          <p className={`text-xs font-bold ${filter === 'all' ? 'text-white/80' : 'text-[#464553]'}`}>All Messages</p>
          <h3 className="text-2xl font-black mt-1">{totalCount}</h3>
          <p className={`text-[10px] mt-1 ${filter === 'all' ? 'text-white/70' : 'text-[#777584]'}`}>Total logged</p>
        </button>

        <button
          onClick={() => setFilter('pending')}
          className={`p-4 rounded-2xl border text-left transition-all cursor-pointer ${
            filter === 'pending'
              ? 'bg-amber-500 text-white border-transparent shadow-md'
              : 'bg-white border-[#c8c4d5]/50 text-[#0b1c30] hover:border-amber-400'
          }`}
        >
          <div className="flex items-center justify-between">
            <p className={`text-xs font-bold ${filter === 'pending' ? 'text-white/80' : 'text-[#464553]'}`}>Pending Review</p>
            {pendingCount > 0 && <span className="w-2 h-2 rounded-full bg-amber-400 animate-ping" />}
          </div>
          <h3 className="text-2xl font-black mt-1">{pendingCount}</h3>
          <p className={`text-[10px] mt-1 ${filter === 'pending' ? 'text-white/70' : 'text-[#777584]'}`}>Awaiting your reply</p>
        </button>

        <button
          onClick={() => setFilter('urgent')}
          className={`p-4 rounded-2xl border text-left transition-all cursor-pointer ${
            filter === 'urgent'
              ? 'bg-rose-600 text-white border-transparent shadow-md'
              : 'bg-white border-[#c8c4d5]/50 text-[#0b1c30] hover:border-rose-400'
          }`}
        >
          <div className="flex items-center justify-between">
            <p className={`text-xs font-bold ${filter === 'urgent' ? 'text-white/80' : 'text-[#464553]'}`}>Urgent Escalations</p>
            {urgentCount > 0 && <span className="w-2 h-2 rounded-full bg-rose-500 animate-pulse" />}
          </div>
          <h3 className="text-2xl font-black mt-1 text-rose-600 group-data-[active]:text-white">{urgentCount}</h3>
          <p className={`text-[10px] mt-1 ${filter === 'urgent' ? 'text-white/70' : 'text-[#777584]'}`}>High-priority flags</p>
        </button>

        <button
          onClick={() => setFilter('resolved')}
          className={`p-4 rounded-2xl border text-left transition-all cursor-pointer ${
            filter === 'resolved'
              ? 'bg-emerald-600 text-white border-transparent shadow-md'
              : 'bg-white border-[#c8c4d5]/50 text-[#0b1c30] hover:border-emerald-400'
          }`}
        >
          <p className={`text-xs font-bold ${filter === 'resolved' ? 'text-white/80' : 'text-[#464553]'}`}>Resolved</p>
          <h3 className="text-2xl font-black mt-1">{resolvedCount}</h3>
          <p className={`text-[10px] mt-1 ${filter === 'resolved' ? 'text-white/70' : 'text-[#777584]'}`}>Successfully closed</p>
        </button>
      </div>

      {/* ── Search & Filter Controls ── */}
      <div className="flex flex-col sm:flex-row gap-3">
        <div className="relative flex-1">
          <Search className="w-4 h-4 text-[#777584] absolute left-3.5 top-1/2 -translate-y-1/2" />
          <input
            type="text"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            placeholder="Search by student name, roll no, admission no, parent mobile, or subject..."
            className="w-full pl-10 pr-4 py-2.5 rounded-2xl bg-white border border-[#c8c4d5]/50 text-xs font-medium text-[#0b1c30] placeholder-[#777584] focus:outline-none focus:border-[#316bf3] shadow-2xs"
          />
          {searchQuery && (
            <button
              onClick={() => setSearchQuery('')}
              className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600"
            >
              <X className="w-4 h-4" />
            </button>
          )}
        </div>

        {/* Tab Filter Pills */}
        <div className="flex items-center gap-1.5 p-1 bg-[#dce9ff]/60 rounded-2xl overflow-x-auto">
          {[
            { id: 'all', label: 'All' },
            { id: 'pending', label: `Pending (${pendingCount})` },
            { id: 'urgent', label: `Urgent (${urgentCount})` },
            { id: 'resolved', label: `Resolved (${resolvedCount})` },
          ].map((tab) => (
            <button
              key={tab.id}
              onClick={() => setFilter(tab.id)}
              className={`px-3 py-1.5 rounded-xl text-xs font-bold transition-all cursor-pointer whitespace-nowrap ${
                filter === tab.id
                  ? 'bg-white text-[#1f108e] shadow-xs'
                  : 'text-[#464553] hover:text-[#0b1c30]'
              }`}
            >
              {tab.label}
            </button>
          ))}
        </div>
      </div>

      {/* ── Complaints List ── */}
      {loading ? (
        <div className="p-12 text-center bg-white rounded-3xl border border-[#c8c4d5]/50 shadow-xs">
          <RefreshCw className="w-6 h-6 text-[#316bf3] animate-spin mx-auto mb-2" />
          <p className="text-xs font-bold text-[#464553]">Loading parent inquiries and messages...</p>
        </div>
      ) : filteredComplaints.length === 0 ? (
        <div className="p-12 text-center bg-white rounded-3xl border border-[#c8c4d5]/50 shadow-xs space-y-2">
          <div className="w-12 h-12 rounded-2xl bg-[#eff4ff] text-[#1f108e] flex items-center justify-center mx-auto">
            <CheckCircle2 className="w-6 h-6 text-emerald-500" />
          </div>
          <h4 className="font-bold text-sm text-[#0b1c30]">No messages found</h4>
          <p className="text-xs text-[#777584] max-w-sm mx-auto">
            {searchQuery
              ? 'No complaints matched your search keywords.'
              : filter === 'urgent'
              ? 'There are no pending urgent escalations from parents.'
              : 'All parent inquiries have been reviewed and addressed.'}
          </p>
        </div>
      ) : (
        <div className="space-y-4">
          {filteredComplaints.map((item) => {
            const isResolved = item.status === 'resolved' || item.resolved === true;
            const isUrgent = item.urgent === true || item.priority === 'urgent';
            const hasReply = !!(item.reply || item.adminReply);
            const parentPhone = item.senderPhone || item.mobile || '';

            return (
              <div
                key={item.docId || item.id}
                className={`bg-white rounded-3xl p-5 sm:p-6 border transition-all shadow-xs ${
                  isUrgent && !isResolved
                    ? 'border-rose-300 ring-2 ring-rose-100'
                    : isResolved
                    ? 'border-[#c8c4d5]/40 opacity-90'
                    : 'border-[#c8c4d5]/60 hover:border-[#316bf3]/40'
                }`}
              >
                {/* Top Badge Row */}
                <div className="flex flex-wrap items-center justify-between gap-2 pb-3 border-b border-[#c8c4d5]/30">
                  <div className="flex flex-wrap items-center gap-2">
                    {/* Status Pill */}
                    <span
                      className={`inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-[10px] font-black uppercase tracking-wider ${
                        isResolved
                          ? 'bg-emerald-50 text-emerald-700 border border-emerald-200'
                          : 'bg-amber-50 text-amber-700 border border-amber-200'
                      }`}
                    >
                      {isResolved ? <CheckCircle2 className="w-3 h-3" /> : <Clock className="w-3 h-3" />}
                      <span>{isResolved ? 'Resolved' : 'Pending Review'}</span>
                    </span>

                    {/* Urgent Tag */}
                    {isUrgent && (
                      <span className="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-[10px] font-black uppercase tracking-wider bg-rose-50 text-rose-700 border border-rose-200 animate-pulse">
                        <AlertCircle className="w-3 h-3 text-rose-600" />
                        <span>Urgent Priority</span>
                      </span>
                    )}

                    {/* Category Tag */}
                    <span className="px-2.5 py-0.5 rounded-full text-[10px] font-bold bg-[#eff4ff] text-[#0051d5] border border-[#dce9ff]">
                      {item.category || 'General Inquiries'}
                    </span>
                  </div>

                  {/* Submission Timestamp */}
                  <span className="text-[11px] font-semibold text-[#777584]">
                    {item.date || item.createdAt ? new Date(item.createdAt || item.date).toLocaleString('en-IN', { dateStyle: 'medium', timeStyle: 'short' }) : 'Recent'}
                  </span>
                </div>

                {/* Main Content & Dossier */}
                <div className="py-4 space-y-3">
                  {/* Student & Parent Dossier Box */}
                  <div className="p-3 rounded-2xl bg-[#eff4ff]/60 border border-[#dce9ff] flex flex-wrap items-center justify-between gap-3 text-xs">
                    <div className="flex items-center gap-2.5">
                      <div className="w-8 h-8 rounded-xl bg-gradient-to-br from-[#1f108e] to-[#0f0069] text-white flex items-center justify-center font-bold text-xs shadow-2xs">
                        {item.studentName ? item.studentName.charAt(0) : 'S'}
                      </div>
                      <div>
                        <p className="font-bold text-[#0b1c30]">
                          {item.studentName || 'Student'} &nbsp;
                          <span className="text-[#0051d5] font-semibold">
                            (Class {item.className || '—'} · Sec {item.section || 'A'})
                          </span>
                        </p>
                        <p className="text-[11px] text-[#777584]">
                          Adm No: <strong className="text-[#0b1c30]">{item.admissionNo || '—'}</strong> · Parent: <strong className="text-[#0b1c30]">{item.senderName || 'Parent'}</strong>
                        </p>
                      </div>
                    </div>

                    {/* Direct Contact Phone Actions */}
                    {parentPhone && (
                      <div className="flex items-center gap-2">
                        <a
                          href={`tel:${parentPhone}`}
                          className="px-3 py-1.5 rounded-xl bg-white hover:bg-emerald-50 text-emerald-700 border border-emerald-200 text-xs font-bold transition-all flex items-center gap-1.5 shadow-2xs"
                          title="Call Parent"
                        >
                          <Phone className="w-3.5 h-3.5" />
                          <span>Call {parentPhone}</span>
                        </a>
                        <a
                          href={`https://wa.me/91${parentPhone.replace(/[^0-9]/g, '')}?text=${encodeURIComponent(`Dear Parent, regarding your inquiry about ${item.studentName || 'your child'}...`)}`}
                          target="_blank"
                          rel="noreferrer"
                          className="px-3 py-1.5 rounded-xl bg-emerald-600 hover:bg-emerald-700 text-white text-xs font-bold transition-all flex items-center gap-1.5 shadow-2xs"
                          title="WhatsApp Parent"
                        >
                          <span>WhatsApp</span>
                        </a>
                      </div>
                    )}
                  </div>

                  {/* Subject & Message Content */}
                  <div>
                    <h3 className="font-black text-sm text-[#0b1c30] mb-1">{item.subject || 'Parent Inquiry'}</h3>
                    <p className="text-xs text-[#464553] leading-relaxed whitespace-pre-wrap">{item.message}</p>
                  </div>

                  {/* Existing Principal Reply Banner */}
                  {hasReply && (
                    <div className="p-3.5 rounded-2xl bg-emerald-50/70 border border-emerald-200 text-xs space-y-1">
                      <div className="flex items-center justify-between font-bold text-emerald-800 text-[11px]">
                        <span className="flex items-center gap-1.5">
                          <CheckCircle2 className="w-3.5 h-3.5 text-emerald-600" />
                          <span>Official Principal Office Reply</span>
                        </span>
                        <span className="text-emerald-600 font-normal">{item.repliedAt || 'Replied'}</span>
                      </div>
                      <p className="text-emerald-950 font-medium leading-relaxed pl-5 whitespace-pre-wrap">
                        {item.reply || item.adminReply}
                      </p>
                    </div>
                  )}
                </div>

                {/* Action Buttons Row */}
                <div className="flex flex-wrap items-center justify-end gap-2 pt-3 border-t border-[#c8c4d5]/30">
                  <button
                    onClick={() => handleToggleStatus(item)}
                    className={`px-3.5 py-2 rounded-xl text-xs font-bold transition-all cursor-pointer flex items-center gap-1.5 ${
                      isResolved
                        ? 'bg-[#eff4ff] text-[#0051d5] hover:bg-[#dce9ff]'
                        : 'bg-emerald-50 text-emerald-700 hover:bg-emerald-100 border border-emerald-200'
                    }`}
                  >
                    {isResolved ? (
                      <>
                        <Clock className="w-3.5 h-3.5" />
                        <span>Reopen as Pending</span>
                      </>
                    ) : (
                      <>
                        <Check className="w-3.5 h-3.5" />
                        <span>Mark as Resolved</span>
                      </>
                    )}
                  </button>

                  <button
                    onClick={() => {
                      setReplyingComplaint(item);
                      setReplyText(item.reply || item.adminReply || '');
                      setMarkResolvedOnReply(true);
                    }}
                    className="px-4 py-2 rounded-xl bg-[#1f108e] hover:bg-[#0f0069] text-white text-xs font-bold shadow-md transition-all cursor-pointer flex items-center gap-1.5"
                  >
                    <Reply className="w-3.5 h-3.5" />
                    <span>{hasReply ? 'Edit Reply' : 'Reply to Parent'}</span>
                  </button>
                </div>
              </div>
            );
          })}
        </div>
      )}

      {/* ── Reply to Parent Modal ── */}
      {replyingComplaint && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-xs animate-in fade-in duration-200">
          <div className="w-full max-w-lg bg-white rounded-3xl p-6 shadow-2xl border border-slate-200 space-y-4">
            <div className="flex items-center justify-between pb-3 border-b border-slate-100">
              <div className="flex items-center gap-2">
                <div className="w-8 h-8 rounded-xl bg-[#eff4ff] text-[#1f108e] flex items-center justify-center">
                  <Reply className="w-4 h-4" />
                </div>
                <div>
                  <h3 className="font-bold text-sm text-[#0b1c30]">
                    Reply to {replyingComplaint.senderName || 'Parent'}
                  </h3>
                  <p className="text-[11px] text-[#777584]">
                    Student: {replyingComplaint.studentName} (Class {replyingComplaint.className})
                  </p>
                </div>
              </div>
              <button
                onClick={() => setReplyingComplaint(null)}
                className="p-1 rounded-lg text-slate-400 hover:text-slate-600 cursor-pointer"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            {/* Parent Message Preview */}
            <div className="p-3 rounded-2xl bg-slate-50 border border-slate-200/80 text-xs text-slate-700 space-y-1">
              <span className="font-bold text-slate-900 block truncate">"{replyingComplaint.subject}"</span>
              <p className="line-clamp-3 text-slate-600 text-[11px]">{replyingComplaint.message}</p>
            </div>

            {/* Reply Textarea */}
            <div className="space-y-1.5">
              <label className="text-xs font-bold text-[#0b1c30]">Your Official Response</label>
              <textarea
                rows={4}
                value={replyText}
                onChange={(e) => setReplyText(e.target.value)}
                placeholder="Type your official answer or resolution details here. This message will be instantly delivered to the parent's app and student web portal."
                className="w-full p-3 rounded-2xl border border-slate-200 focus:outline-none focus:border-[#316bf3] text-xs font-medium text-slate-800 leading-relaxed shadow-2xs"
              />
            </div>

            {/* Resolve Checkbox */}
            <label className="flex items-center gap-2 cursor-pointer select-none">
              <input
                type="checkbox"
                checked={markResolvedOnReply}
                onChange={(e) => setMarkResolvedOnReply(e.target.checked)}
                className="w-4 h-4 rounded text-[#1f108e] border-slate-300 focus:ring-0"
              />
              <span className="text-xs font-bold text-[#0b1c30]">Also mark this complaint as Resolved</span>
            </label>

            {/* Actions */}
            <div className="flex items-center justify-end gap-2 pt-2">
              <button
                onClick={() => setReplyingComplaint(null)}
                disabled={sendingReply}
                className="px-4 py-2 rounded-xl text-xs font-bold text-slate-600 hover:bg-slate-100 cursor-pointer"
              >
                Cancel
              </button>
              <button
                onClick={handleSendReply}
                disabled={sendingReply || !replyText.trim()}
                className="px-5 py-2.5 rounded-xl bg-[#1f108e] hover:bg-[#0f0069] text-white text-xs font-bold shadow-md transition-all cursor-pointer flex items-center gap-1.5 disabled:opacity-50"
              >
                {sendingReply ? (
                  <RefreshCw className="w-3.5 h-3.5 animate-spin" />
                ) : (
                  <Send className="w-3.5 h-3.5" />
                )}
                <span>Send Reply to Parent</span>
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
