'use client';

import React, { useState } from 'react';
import { useSchoolStore } from '../lib/store';
import {
  MessageSquare, Send, CheckCircle, Clock, AlertCircle, Play, Settings,
  Users, Layers, ArrowRight, ToggleLeft, ToggleRight, MessageCircle, HelpCircle
} from 'lucide-react';

export default function CommunicationView() {
  const { students, settings, showToast } = useSchoolStore();
  const [targetAudience, setTargetAudience] = useState('all');
  const [template, setTemplate] = useState('none');
  const [messageBody, setMessageBody] = useState('');
  
  // Workflows states matching mockup
  const [workflows, setWorkflows] = useState({
    attendance: true,
    fee: true,
    result: false
  });

  const handleSendBroadcast = (e) => {
    e.preventDefault();
    if (!messageBody.trim()) {
      showToast("Please enter message body.", "error");
      return;
    }
    showToast(`Broadcast sent to ${targetAudience === 'all' ? 'All Parents' : 'Target Group'}!`, "success");
    setMessageBody('');
  };

  return (
    <div className="space-y-6 pb-12 animate-in fade-in duration-200">
      <div>
        <h2 className="text-xl lg:text-2xl font-bold text-text tracking-tight">Communication Center</h2>
        <p className="text-xs text-text-secondary mt-0.5">Manage WhatsApp integrations, automated workflows, and bulk messaging.</p>
      </div>

      {/* Top Metrics Cards */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4 text-xs font-semibold">
        {/* API connection status card */}
        <div className="bg-white border border-border rounded-2xl p-5 shadow-xs flex flex-col justify-between">
          <div className="flex justify-between items-start">
            <div>
              <div className="text-[10px] font-bold text-text-secondary uppercase">WhatsApp API</div>
              <div className="text-base font-bold text-emerald-600 mt-2 flex items-center gap-1.5">
                <span className="w-2.5 h-2.5 rounded-full bg-emerald-500 inline-block animate-ping"></span>
                <span>Connected</span>
              </div>
              <p className="text-[10px] text-text-muted mt-1">Last synced: 2 mins ago</p>
            </div>
            <MessageCircle className="w-6 h-6 text-emerald-500" />
          </div>
          <button
            onClick={() => showToast("WhatsApp API configure modal...", "info")}
            className="w-full mt-4 py-2 border border-border rounded-xl bg-surface2 hover:bg-border text-text text-center transition-colors cursor-pointer"
          >
            Configure
          </button>
        </div>

        {/* Messages sent */}
        <div className="bg-white border border-border rounded-2xl p-5 shadow-xs flex items-center justify-between">
          <div>
            <div className="text-[10px] font-bold text-text-secondary uppercase">Messages Sent (30D)</div>
            <div className="text-2xl font-black text-text mt-1.5">14,285</div>
            <p className="text-[10px] text-emerald-600 font-bold mt-1">↑ +12% from last month</p>
          </div>
          <div className="w-10 h-10 rounded-xl bg-primary/10 text-primary flex items-center justify-center font-bold">▶</div>
        </div>

        {/* Delivery rate */}
        <div className="bg-white border border-border rounded-2xl p-5 shadow-xs flex items-center justify-between">
          <div>
            <div className="text-[10px] font-bold text-text-secondary uppercase">Delivery Rate</div>
            <div className="text-2xl font-black text-emerald-600 mt-1.5">98.4%</div>
            <p className="text-[10px] text-emerald-600 font-bold mt-1">● Outstanding</p>
          </div>
          <div className="w-10 h-10 rounded-xl bg-emerald-50 text-emerald-600 flex items-center justify-center">✔</div>
        </div>
      </div>

      {/* Main Broadcast and Workflows panel */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6 items-start">
        {/* Left Side: Quick Broadcast Form */}
        <div className="lg:col-span-8 bg-white border border-border rounded-2xl p-6 shadow-sm space-y-5">
          <h3 className="font-bold text-base text-text flex items-center gap-2">
            <MessageSquare className="w-5 h-5 text-primary" />
            <span>Quick Broadcast</span>
          </h3>

          <form onSubmit={handleSendBroadcast} className="space-y-4">
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 text-xs font-semibold text-text-secondary">
              <div>
                <label className="block mb-1">Target Audience</label>
                <select
                  value={targetAudience}
                  onChange={e => setTargetAudience(e.target.value)}
                  className="w-full px-3 py-2 rounded-xl bg-surface2 border border-border text-text focus:outline-none"
                >
                  <option value="all">All Students / Parents</option>
                  <option value="school">School Only</option>
                  <option value="computer">Computer Only</option>
                </select>
              </div>

              <div>
                <label className="block mb-1">Message Template (Optional)</label>
                <select
                  value={template}
                  onChange={e => {
                    setTemplate(e.target.value);
                    if (e.target.value === 'dues') {
                      setMessageBody("Dear {parent_name}, this is a gentle reminder that school dues for {student_name} are pending. Please pay at the earliest.");
                    } else if (e.target.value === 'attendance') {
                      setMessageBody("Dear Parent, {student_name} is absent from class today without prior permission. Please report reason.");
                    } else {
                      setMessageBody('');
                    }
                  }}
                  className="w-full px-3 py-2 rounded-xl bg-surface2 border border-border text-text focus:outline-none"
                >
                  <option value="none">None (Custom Message)</option>
                  <option value="dues">Fee Dues Reminder</option>
                  <option value="attendance">Daily Absentee Notice</option>
                </select>
              </div>
            </div>

            <div className="text-xs font-semibold text-text-secondary">
              <label className="block mb-1">Message Body</label>
              <textarea
                rows={4}
                required
                value={messageBody}
                onChange={e => setMessageBody(e.target.value)}
                placeholder="Type your message here... Variables available: {student_name}, {parent_name}"
                className="w-full px-3 py-2 rounded-xl bg-surface2 border border-border text-text focus:outline-none resize-none"
              />
            </div>

            <div className="flex justify-end gap-3 text-xs font-bold">
              <button
                type="button"
                onClick={() => showToast(messageBody ? `Preview: "${messageBody.slice(0, 60)}..."` : "Message is empty", "info")}
                className="px-4 py-2 border border-border bg-surface2 hover:bg-border text-text rounded-xl cursor-pointer"
              >
                Preview
              </button>
              <button
                type="submit"
                className="px-5 py-2 bg-primary hover:bg-primary-dark text-white rounded-xl cursor-pointer flex items-center gap-1.5 shadow-sm"
              >
                <Send className="w-3.5 h-3.5" />
                <span>Send Broadcast</span>
              </button>
            </div>
          </form>
        </div>

        {/* Right Side: Automated Workflows checklist */}
        <div className="lg:col-span-4 bg-white border border-border rounded-2xl p-6 shadow-sm space-y-4">
          <div className="flex justify-between items-center pb-2 border-b border-border">
            <h3 className="font-bold text-base text-text">Automated Workflows</h3>
            <button className="text-primary font-bold text-xl leading-none" title="Create workflow">+</button>
          </div>

          <div className="space-y-4 text-xs font-semibold">
            {/* Workflow 1 */}
            <div className="p-3 bg-surface2/30 border border-border rounded-xl space-y-2">
              <div className="flex justify-between items-start">
                <div className="space-y-0.5">
                  <p className="font-bold text-text flex items-center gap-1.5">
                    <span className="w-2 h-2 rounded-full bg-rose-500" />
                    <span>Low Attendance Alert</span>
                  </p>
                  <p className="text-[10px] text-text-muted leading-snug">Triggers when student drops below 80% attendance.</p>
                </div>
                <button onClick={() => setWorkflows(p => ({ ...p, attendance: !p.attendance }))}>
                  {workflows.attendance ? <ToggleRight className="w-8 h-8 text-primary" /> : <ToggleLeft className="w-8 h-8 text-text-muted" />}
                </button>
              </div>
              <button className="text-[10px] text-primary hover:underline font-bold">Edit Template</button>
            </div>

            {/* Workflow 2 */}
            <div className="p-3 bg-surface2/30 border border-border rounded-xl space-y-2">
              <div className="flex justify-between items-start">
                <div className="space-y-0.5">
                  <p className="font-bold text-text flex items-center gap-1.5">
                    <span className="w-2 h-2 rounded-full bg-primary" />
                    <span>Fee Due Reminder</span>
                  </p>
                  <p className="text-[10px] text-text-muted leading-snug">Sends 3 days before fee deadline to parents.</p>
                </div>
                <button onClick={() => setWorkflows(p => ({ ...p, fee: !p.fee }))}>
                  {workflows.fee ? <ToggleRight className="w-8 h-8 text-primary" /> : <ToggleLeft className="w-8 h-8 text-text-muted" />}
                </button>
              </div>
              <button className="text-[10px] text-primary hover:underline font-bold">Edit Template</button>
            </div>

            {/* Workflow 3 */}
            <div className="p-3 bg-surface2/30 border border-border rounded-xl space-y-2">
              <div className="flex justify-between items-start">
                <div className="space-y-0.5">
                  <p className="font-bold text-text flex items-center gap-1.5">
                    <span className="w-2 h-2 rounded-full bg-slate-400" />
                    <span>Result Published</span>
                  </p>
                  <p className="text-[10px] text-text-muted leading-snug">Notifies parents when exam term results are live.</p>
                </div>
                <button onClick={() => setWorkflows(p => ({ ...p, result: !p.result }))}>
                  {workflows.result ? <ToggleRight className="w-8 h-8 text-primary" /> : <ToggleLeft className="w-8 h-8 text-text-muted" />}
                </button>
              </div>
              <button className="text-[10px] text-primary hover:underline font-bold">Edit Template</button>
            </div>
          </div>
        </div>
      </div>

      {/* Bottom Table: Recent Logs */}
      <div className="bg-white border border-border rounded-2xl shadow-sm overflow-hidden flex flex-col">
        <div className="px-5 py-4 border-b border-border bg-surface2/40 flex items-center justify-between">
          <span className="font-bold text-xs text-text uppercase">Recent Logs</span>
          <span className="text-[10px] font-bold text-primary cursor-pointer hover:underline">View All</span>
        </div>

        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs border-collapse">
            <thead>
              <tr className="bg-surface2/60 border-b border-border text-text-secondary font-bold text-[10px] uppercase">
                <th className="py-3 px-4">Recipient</th>
                <th className="py-3 px-4">Message Type</th>
                <th className="py-3 px-4">Time</th>
                <th className="py-3 px-4">Status</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-border text-text-secondary">
              {[
                { name: 'John Doe (Parent)', type: 'FEE DUE', time: '10:45 AM', status: 'Read', color: 'bg-emerald-100 text-emerald-700' },
                { name: 'Sarah Smith (Staff)', type: 'BROADCAST', time: '09:12 AM', status: 'Delivered', color: 'bg-primary/10 text-primary' },
                { name: 'Mike Johnson (Parent)', type: 'LOW ATTENDANCE', time: 'Yesterday', status: 'Failed', color: 'bg-rose-100 text-rose-700' }
              ].map((log, idx) => (
                <tr key={idx} className="hover:bg-surface2/30 transition-colors">
                  <td className="py-3.5 px-4 font-bold text-text">{log.name}</td>
                  <td className="py-3.5 px-4">
                    <span className="px-2 py-0.5 rounded bg-surface2 border border-border text-[9px] font-bold font-mono text-text">
                      {log.type}
                    </span>
                  </td>
                  <td className="py-3.5 px-4">{log.time}</td>
                  <td className="py-3.5 px-4">
                    <span className={`px-2 py-0.5 rounded-full text-[9px] font-bold uppercase tracking-wider ${log.color}`}>
                      {log.status}
                    </span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
