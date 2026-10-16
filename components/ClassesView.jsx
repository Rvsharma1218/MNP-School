'use client';

import React from 'react';
import { useSchoolStore } from '../lib/store';
import {
  Building2, Users, CalendarCheck, CreditCard, Award, Contact, ArrowRight, UserCheck
} from 'lucide-react';

export default function ClassesView() {
  const { students, settings, navigate, setAttendanceTargetClass } = useSchoolStore();

  const allClasses = ['Nursery', 'LKG', 'UKG', '1st', '2nd', '3rd', '4th', '5th', '6th', '7th', '8th', '9th', '10th', '11th', '12th'];

  const classData = allClasses.map(className => {
    const classStudents = students.filter(s => s.className === className);
    const boys = classStudents.filter(s => (s.gender || '').toLowerCase() === 'male').length;
    const girls = classStudents.filter(s => (s.gender || '').toLowerCase() === 'female').length;
    return {
      className,
      total: classStudents.length,
      boys,
      girls,
    };
  });

  return (
    <div className="space-y-6 animate-in fade-in duration-200">
      {/* Header */}
      <div className="bg-card border border-border p-6 rounded-2xl shadow-xs">
        <h2 className="text-xl sm:text-2xl font-black text-text-primary flex items-center gap-2.5">
          <Building2 className="w-6 h-6 text-primary" />
          <span>Classes & Sections Management</span>
        </h2>
        <p className="text-xs sm:text-sm text-text-muted mt-1">
          Detailed metrics, boy/girl ratio, and quick shortcuts for every grade in the school.
        </p>
      </div>

      {/* Grid of Classes */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        {classData.map(c => (
          <div
            key={c.className}
            className="bg-card border border-border hover:border-primary/50 transition-all rounded-2xl p-5 shadow-xs flex flex-col justify-between"
          >
            <div>
              <div className="flex items-center justify-between border-b border-border pb-3 mb-3">
                <div className="flex items-center gap-2.5">
                  <div className="w-9 h-9 rounded-xl bg-primary/10 text-primary font-black text-sm flex items-center justify-center">
                    {c.className.substring(0, 2)}
                  </div>
                  <div>
                    <h3 className="font-extrabold text-sm text-text-primary">Class {c.className}</h3>
                    <p className="text-[11px] text-text-muted">{c.total} Students Registered</p>
                  </div>
                </div>
                <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-green-500/10 text-green-600">
                  Active
                </span>
              </div>

              {/* Student Demographics */}
              <div className="grid grid-cols-3 gap-2 bg-muted/30 p-2.5 rounded-xl border border-border text-center text-xs mb-3">
                <div>
                  <div className="text-[10px] text-text-muted font-bold">TOTAL</div>
                  <div className="font-black text-text-primary">{c.total}</div>
                </div>
                <div>
                  <div className="text-[10px] text-blue-500 font-bold">BOYS</div>
                  <div className="font-black text-blue-600">{c.boys}</div>
                </div>
                <div>
                  <div className="text-[10px] text-pink-500 font-bold">GIRLS</div>
                  <div className="font-black text-pink-600">{c.girls}</div>
                </div>
              </div>
            </div>

            {/* Quick Actions */}
            <div className="pt-2 border-t border-dashed border-border flex items-center justify-between text-xs">
              <button
                onClick={() => {
                  if (typeof window !== 'undefined') {
                    localStorage.setItem('school_students_target_class', c.className);
                  }
                  navigate('/students');
                }}
                className="text-primary hover:text-primary-dark font-bold flex items-center gap-1 cursor-pointer"
              >
                <span>View Students</span>
                <ArrowRight className="w-3.5 h-3.5" />
              </button>
              <button
                onClick={() => {
                  if (typeof window !== 'undefined') {
                    localStorage.setItem('school_attendance_target_class', c.className);
                  }
                  if (setAttendanceTargetClass) setAttendanceTargetClass(c.className);
                  navigate('/attendance');
                }}
                className="px-2.5 py-1 rounded-lg bg-primary/10 text-primary hover:bg-primary hover:text-white font-bold text-xs transition-colors cursor-pointer"
              >
                Take Attendance &rarr;
              </button>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
