# 🏫 Mission Navodaya Public School, Mora (MNP School Web Portal)

Official Web Portal for **Mission Navodaya Public School (Mora Bazar, Siwan, Bihar)**.
Built with **Next.js 16**, **React 19**, **Tailwind CSS**, and **Firebase**.

---

## 🚀 Portals & Features
* **Official School Landing Page:** Panoramic institutional campus banner, admissions Nursery–8th, 5 core pillars, campus photo gallery, parent reviews, and helpline.
* **Online Admission Form (सत्र 2026–27):** English medium online admission application with instant registration tracking.
* **School Digital Portals:**
  * **Parent Portal:** Admission number & registered mobile matching, report cards, fee records, and student profile.
  * **Teacher Portal:** Attendance register, marks grading, and classroom tools.
  * **Principal Portal:** Administrative controls, live admissions toggle, fees management, admit card studio, and reports.

## ✨ Features & Modules

1. **Admit Card & Hall Ticket Studio (`/admitcards`):**
   * Student **Aadhaar Card No (Official ID)** print on all cards.
   * Scannable **QR Code** verification with student details.
   * Class schedule timetable table.
   * Single Student search by Name, Roll No, or Aadhaar.
   * Full Class Booklet bulk PDF print & Share.

2. **Routine & Timetable Studio (`/timetable`):**
   * Class-wise schedules saved per class.
   * Real generation date/time stamped on booklets.
   * Print and Share options.

3. **Classes & Sections Management (`/classes`):**
   * Student demographics (Boys, Girls, Total).
   * 1-Click **Take Attendance** link that directly filters Daily Attendance to that class.

4. **Student ID Cards Studio (`/idcards`):**
   * Dual-sided (Front + Back) gold accent layout.
   * Scannable QR code and Aadhaar identification.
   * Bulk print and individual PDF cards.

5. **Faculty Management & Payroll (`/teachers`):**
   * Teacher base salary and class allocation.
   * **Salary History Register** popup with payment records and individual Payslip download/print.

6. **Institutional Reports Hub (`/reports`):**
   * Student Master Database with Excel Import/Export.
   * Staff Payroll & Teacher Salary Register.
   * Weekly School Routine & Timetables report.
   * Date-range attendance analytics.

---

## 🛠 Local Development

```bash
npm install
npm run dev
```

Open [http://localhost:3000](http://localhost:3000) in your browser.
