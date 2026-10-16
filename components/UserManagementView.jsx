'use client';

import React, { useState } from 'react';
import { useSchoolStore } from '../lib/store';
import { Users, UserCheck, ShieldCheck, Trash2, Edit, Check, X, ShieldAlert, Key, Search, Plus } from 'lucide-react';

export default function UserManagementView() {
  const {
    users,
    signUp,
    addTeacher,
    settings,
    updateUserStatus,
    updateUserRole,
    resetUserPassword,
    showToast
  } = useSchoolStore();

  const [searchQuery, setSearchQuery] = useState('');
  const [isAddUserOpen, setIsAddUserOpen] = useState(false);
  const [isPasswordResetOpen, setIsPasswordResetOpen] = useState(false);
  const [selectedUser, setSelectedUser] = useState(null);

  // Add User Form
  const [newName, setNewName] = useState('');
  const [newEmail, setNewEmail] = useState('');
  const [newMobile, setNewMobile] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [newRole, setNewRole] = useState('teacher');
  const [errorMsg, setErrorMsg] = useState('');

  // Password reset form
  const [resetPassVal, setResetPassVal] = useState('');

  const handleOpenAdd = () => {
    setNewName('');
    setNewEmail('');
    setNewMobile('');
    setNewPassword('teacher123');
    setNewRole('teacher');
    setErrorMsg('');
    setIsAddUserOpen(true);
  };

  const handleAddUser = async (e) => {
    e.preventDefault();
    setErrorMsg('');
    try {
      if (newRole === 'teacher') {
        await addTeacher({
          name: newName,
          mobile: newMobile,
          password: newPassword,
          authEmail: newEmail,
          assignedClass: settings.schoolClasses?.[0] || '10th',
          assignedSection: 'A'
        });
      } else {
        await signUp(newName, settings.instituteName || settings.schoolName || "Smart School", newEmail, newMobile, newPassword, newRole);
      }
      setIsAddUserOpen(false);
      showToast("New user account created successfully!", "success");
    } catch (err) {
      setErrorMsg(err.message || "Failed to create user account.");
    }
  };

  const handleOpenPasswordReset = (usr) => {
    setSelectedUser(usr);
    setResetPassVal('');
    setIsPasswordResetOpen(true);
  };

  const handlePasswordResetSubmit = (e) => {
    e.preventDefault();
    if (!resetPassVal.trim() || resetPassVal.length < 6) {
      showToast("Password must be at least 6 characters long.", "error");
      return;
    }
    resetUserPassword(selectedUser.uid, resetPassVal);
    setIsPasswordResetOpen(false);
    showToast(`Password for ${selectedUser.name} reset successfully!`, "success");
  };

  const handleToggleStatus = (usr) => {
    const next = usr.status === 'active' ? 'inactive' : 'active';
    updateUserStatus(usr.uid, next);
  };

  const handleToggleRole = (usr) => {
    const next = usr.role === 'principal' ? 'teacher' : 'principal';
    updateUserRole(usr.uid, next);
  };

  // Filter users
  const filteredUsers = users.filter(u => {
    if (!searchQuery.trim()) return true;
    const q = searchQuery.toLowerCase();
    return u.name?.toLowerCase().includes(q) || u.email?.toLowerCase().includes(q);
  });

  return (
    <div className="space-y-6 pb-12 animate-in fade-in duration-200">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h2 className="text-xl lg:text-2xl font-bold text-text tracking-tight">User Management</h2>
          <p className="text-xs text-text-secondary mt-0.5 font-medium">Control system access rights, roles, passwords, and status for faculty members.</p>
        </div>

        <button
          onClick={handleOpenAdd}
          className="px-4 py-2 rounded-xl bg-primary hover:bg-primary-dark text-white font-bold text-xs shadow-md transition-all cursor-pointer flex items-center gap-1.5"
        >
          <Plus className="w-4 h-4" />
          <span>Add User Account</span>
        </button>
      </div>

      {/* Search filters */}
      <div className="bg-white border border-border rounded-2xl p-4 shadow-xs flex items-center bg-surface2/30">
        <div className="relative flex-1">
          <Search className="w-4 h-4 text-text-muted absolute left-3 top-1/2 -translate-y-1/2" />
          <input
            type="text"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            placeholder="Search users by name or email..."
            className="w-full pl-9 pr-4 py-2 rounded-xl bg-white border border-border text-xs text-text focus:outline-none focus:border-primary"
          />
        </div>
      </div>

      {/* Users database list table */}
      <div className="bg-white border border-border rounded-2xl shadow-sm overflow-hidden flex flex-col">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs border-collapse">
            <thead>
              <tr className="bg-surface2/60 border-b border-border text-text-secondary font-bold text-[10px] uppercase">
                <th className="py-3 px-4">User</th>
                <th className="py-3 px-4">Email</th>
                <th className="py-3 px-4">Role</th>
                <th className="py-3 px-4 text-center">Status</th>
                <th className="py-3 px-4 text-right">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-border text-text font-medium">
              {filteredUsers.map((usr, idx) => (
                <tr key={usr.uid || usr.id || usr.email || idx} className="hover:bg-surface2/30 transition-colors">
                  <td className="py-3.5 px-4 font-bold text-text">
                    <div className="flex items-center gap-2.5">
                      <div className="w-8 h-8 rounded-full bg-primary/10 text-primary flex items-center justify-center font-bold text-xs">
                        {usr.name?.charAt(0)}
                      </div>
                      <span>{usr.name}</span>
                    </div>
                  </td>
                  <td className="py-3.5 px-4 text-text-secondary font-mono">{usr.email}</td>
                  <td className="py-3.5 px-4">
                    <span className={`px-2.5 py-0.5 rounded text-[9px] font-bold uppercase tracking-wider ${
                      usr.role === 'principal' ? 'bg-amber-100 text-amber-700' : 'bg-indigo-100 text-indigo-700'
                    }`}>
                      {usr.role === 'principal' ? 'Principal / Admin' : 'Teacher'}
                    </span>
                  </td>
                  <td className="py-3.5 px-4 text-center">
                    <button
                      onClick={() => handleToggleStatus(usr)}
                      className={`px-2.5 py-0.5 rounded-full text-[9px] font-bold uppercase tracking-wider cursor-pointer ${
                        usr.status === 'active' ? 'bg-emerald-100 text-emerald-700 hover:bg-emerald-200' : 'bg-rose-100 text-rose-700 hover:bg-rose-200'
                      }`}
                      title="Click to toggle status"
                    >
                      {usr.status || 'Active'}
                    </button>
                  </td>
                  <td className="py-3.5 px-4 text-right">
                    <div className="flex items-center justify-end gap-2">
                      <button
                        onClick={() => handleToggleRole(usr)}
                        className="px-2 py-1 rounded bg-surface2 hover:bg-border text-text-secondary text-[10px] font-bold border border-border cursor-pointer"
                        title="Change Access Role"
                      >
                        Swap Role
                      </button>
                      <button
                        onClick={() => handleOpenPasswordReset(usr)}
                        className="p-1.5 rounded bg-surface2 hover:bg-border text-text-secondary cursor-pointer"
                        title="Reset password"
                      >
                        <Key className="w-3.5 h-3.5 text-primary" />
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* Add User Modal */}
      {isAddUserOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-xs">
          <div className="bg-card border border-border rounded-2xl w-full max-w-md shadow-2xl overflow-hidden animate-in fade-in zoom-in-95 duration-200">
            <div className="px-5 py-4 border-b border-border bg-primary/10 flex items-center justify-between">
              <h3 className="font-bold text-sm uppercase text-text tracking-wider">Add User Account</h3>
              <button onClick={() => setIsAddUserOpen(false)} className="p-1 rounded text-text-muted hover:text-text cursor-pointer">
                <X className="w-5 h-5" />
              </button>
            </div>

            <form onSubmit={handleAddUser} className="p-5 space-y-4 text-xs font-semibold text-text-secondary">
              {errorMsg && (
                <div className="p-3 bg-rose-500/10 text-rose-600 rounded-lg text-[10px]">
                  {errorMsg}
                </div>
              )}

              <div>
                <label className="block mb-1 text-text">Full Name</label>
                <input
                  type="text"
                  required
                  value={newName}
                  onChange={e => setNewName(e.target.value)}
                  className="w-full px-3 py-2 rounded-xl bg-surface2 border border-border text-text"
                />
              </div>

              <div>
                <label className="block mb-1 text-text">Email Address</label>
                <input
                  type="email"
                  required
                  value={newEmail}
                  onChange={e => setNewEmail(e.target.value)}
                  className="w-full px-3 py-2 rounded-xl bg-surface2 border border-border text-text"
                />
              </div>

              <div>
                <label className="block mb-1 text-text">Mobile Number</label>
                <input
                  type="text"
                  required
                  value={newMobile}
                  onChange={e => setNewMobile(e.target.value)}
                  className="w-full px-3 py-2 rounded-xl bg-surface2 border border-border text-text"
                />
              </div>

              <div>
                <label className="block mb-1 text-text">Password</label>
                <input
                  type="password"
                  required
                  value={newPassword}
                  onChange={e => setNewPassword(e.target.value)}
                  className="w-full px-3 py-2 rounded-xl bg-surface2 border border-border text-text"
                />
              </div>

              <div>
                <label className="block mb-1 text-text">Role</label>
                <select
                  value={newRole}
                  onChange={e => setNewRole(e.target.value)}
                  className="w-full px-3 py-2 rounded-xl bg-surface2 border border-border text-text cursor-pointer"
                >
                  <option value="teacher">Teacher (Restricted Access)</option>
                  <option value="principal">Principal / Admin (Full Access)</option>
                </select>
              </div>

              <div className="pt-2 flex justify-end gap-2">
                <button
                  type="button"
                  onClick={() => setIsAddUserOpen(false)}
                  className="px-4 py-2 border border-border bg-surface2 rounded-xl text-text font-bold"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="px-5 py-2 bg-primary text-white font-bold rounded-xl shadow-xs"
                >
                  Create Account
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Password Reset Modal */}
      {isPasswordResetOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-xs">
          <div className="bg-card border border-border rounded-2xl w-full max-w-sm shadow-2xl overflow-hidden">
            <div className="px-5 py-4 border-b border-border bg-primary/10 flex items-center justify-between">
              <h3 className="font-bold text-xs uppercase text-text tracking-wider">Reset User Password</h3>
              <button onClick={() => setIsPasswordResetOpen(false)} className="p-1 rounded text-text-muted hover:text-text cursor-pointer">
                <X className="w-5 h-5" />
              </button>
            </div>

            <form onSubmit={handlePasswordResetSubmit} className="p-5 space-y-4 text-xs font-semibold text-text-secondary">
              <p className="text-[10px] text-text-muted">Set new password for user **{selectedUser?.name}**.</p>
              
              <div>
                <label className="block mb-1 text-text">New Password</label>
                <input
                  type="password"
                  required
                  placeholder="Minimum 6 characters"
                  value={resetPassVal}
                  onChange={e => setResetPassVal(e.target.value)}
                  className="w-full px-3 py-2 rounded-xl bg-surface2 border border-border text-text"
                />
              </div>

              <div className="pt-2 flex justify-end gap-2">
                <button
                  type="button"
                  onClick={() => setIsPasswordResetOpen(false)}
                  className="px-4 py-2 border border-border bg-surface2 rounded-xl text-text font-bold"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="px-5 py-2 bg-primary text-white font-bold rounded-xl shadow-xs"
                >
                  Reset Password
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
