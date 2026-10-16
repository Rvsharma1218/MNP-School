import {
  collection, doc, getDocs, getDoc, updateDoc, deleteDoc,
  query, where, orderBy, onSnapshot, setDoc, serverTimestamp
} from 'firebase/firestore';
import { db, auth } from './firebase';

// ─── Path helpers — MUST match Flutter's schools/{uid}/... path ──────────────
// Flutter FirestoreService uses: _db.collection('schools').doc(uid).collection(col)
// Web store.js uses:             collection(db, 'schools', uid, col)
// This file MUST use the same path — old `institutes/school_manager_institute/`
// path was wrong and caused Flutter ↔ Web data to go to different places.

const getUid = () => {
  if (typeof window !== 'undefined') {
    try {
      const sId = localStorage.getItem('school_manager_active_school_uid_v1');
      if (sId && sId !== 'default_school') return sId;
      const savedUser = localStorage.getItem('school_manager_logged_user_v1') || localStorage.getItem('school_manager_user_v1');
      if (savedUser) {
        const u = JSON.parse(savedUser);
        if (u.schoolId && u.schoolId !== 'default_school') return u.schoolId;
      }
    } catch (_) {}
  }
  return 'SCHOOL_001';
};

const root = (col) => {
  const uid = getUid();
  if (!uid) throw new Error('[firestore.js] No authenticated user — cannot build collection path');
  return collection(db, 'schools', uid, col);
};

const rootDoc = (col, id) => {
  const uid = getUid();
  if (!uid) throw new Error('[firestore.js] No authenticated user — cannot build doc path');
  return doc(db, 'schools', uid, col, id);
};

// ─── Students ─────────────────────────────────────────────────────────────────

export async function getStudents() {
  const snap = await getDocs(query(root('students'), orderBy('createdAt', 'desc')));
  return snap.docs.map(d => ({ id: d.id, ...d.data() }));
}

export async function getStudent(id) {
  const snap = await getDoc(rootDoc('students', id));
  return snap.exists() ? { id: snap.id, ...snap.data() } : null;
}

export async function addStudent(student) {
  const data = { ...student, createdAt: serverTimestamp(), syncedAt: serverTimestamp() };
  return setDoc(rootDoc('students', student.id), data, { merge: true });
}

export async function updateStudent(id, data) {
  return setDoc(rootDoc('students', id), { ...data, syncedAt: serverTimestamp() }, { merge: true });
}

export async function deleteStudent(id) {
  await deleteDoc(rootDoc('students', id));
  await deleteDoc(rootDoc('fees', id)).catch(() => {});
}

export function listenStudents(callback, onError) {
  return onSnapshot(
    query(root('students'), orderBy('createdAt', 'desc')),
    snap => callback(snap.docs.map(d => ({ id: d.id, ...d.data() }))),
    onError
  );
}

// ─── Fees ─────────────────────────────────────────────────────────────────────

export async function getFee(studentId) {
  const snap = await getDoc(rootDoc('fees', studentId));
  return snap.exists() ? { id: snap.id, ...snap.data() } : null;
}

export async function getFees() {
  const snap = await getDocs(root('fees'));
  return snap.docs.map(d => ({ id: d.id, ...d.data() }));
}

export async function saveFee(studentId, data) {
  return setDoc(rootDoc('fees', studentId), { ...data, updatedAt: serverTimestamp(), syncedAt: serverTimestamp() }, { merge: true });
}

export async function getPayments(studentId) {
  const snap = await getDocs(
    query(root('payments'), where('studentId', '==', studentId), orderBy('createdAt', 'desc'))
  );
  return snap.docs.map(d => ({ id: d.id, ...d.data() }));
}

export async function getAllPayments() {
  const snap = await getDocs(query(root('payments'), orderBy('createdAt', 'desc')));
  return snap.docs.map(d => ({ id: d.id, ...d.data() }));
}

// ─── Attendance ───────────────────────────────────────────────────────────────
// Flutter stores attendance in two places:
//   1. schools/{uid}/attendance/{date}/records/{studentId}  (hierarchical)
//   2. schools/{uid}/attendance_flat/{studentId}_{date}     (flat, for real-time stream)
// Web reads from attendance_flat for real-time updates (same as Flutter watchAttendance).

export async function getAttendanceForDate(dateKey) {
  const snap = await getDocs(
    query(root('attendance_flat'), where('dateKey', '==', dateKey))
  );
  return snap.docs.map(d => ({ id: d.id, ...d.data() }));
}

export async function markAttendance(dateKey, studentId, status) {
  const flatDocId = `${studentId}_${dateKey}`;
  const dateIso = `${dateKey}T00:00:00.000`;
  const record = {
    id: flatDocId,
    studentId,
    dateKey,
    date: dateIso,
    status,
    updatedAt: serverTimestamp(),
    syncedAt: serverTimestamp()
  };
  // Write to both flat + hierarchical (same as Flutter syncAttendance)
  await Promise.all([
    setDoc(rootDoc('attendance_flat', flatDocId), record, { merge: true }),
    setDoc(doc(db, 'schools', getUid(), 'attendance', dateKey, 'records', studentId), record, { merge: true })
  ]);
}

// ─── Settings ─────────────────────────────────────────────────────────────────

export async function getSettings() {
  const snap = await getDoc(rootDoc('settings', 'config'));
  return snap.exists() ? snap.data() : { instituteName: 'My School', address: '', mobile: '' };
}

export async function saveSettings(data) {
  return setDoc(rootDoc('settings', 'config'),
    { ...data, updatedAt: serverTimestamp() }, { merge: true });
}

// ─── Dashboard Stats ──────────────────────────────────────────────────────────

export async function getDashboardStats() {
  const todayKey = new Date().toISOString().split('T')[0];

  const [studentsSnap, feesSnap, attSnap] = await Promise.all([
    getDocs(root('students')),
    getDocs(root('fees')),
    getDocs(query(root('attendance_flat'), where('dateKey', '==', todayKey)))
  ]);

  const students = studentsSnap.docs.map(d => d.data());
  const fees = feesSnap.docs.map(d => d.data());
  const todayRecords = attSnap.docs.map(d => d.data());

  const totalStudents = students.length;
  const schoolStudents = students.filter(s => s.studentType === 'school').length;
  const computerStudents = students.filter(s => s.studentType === 'computer').length;
  const activeStudents = students.filter(s => s.status === 'active').length;

  const totalFees = fees.reduce((sum, f) => sum + (f.totalFees || 0), 0);
  const paidFees = fees.reduce((sum, f) => sum + (f.paidFees || 0), 0);
  const pendingFees = totalFees - paidFees;

  const presentToday = todayRecords.filter(r => r.status === 'present').length;
  const absentToday = todayRecords.filter(r => r.status === 'absent').length;

  return {
    totalStudents, schoolStudents, computerStudents, activeStudents,
    totalFees, paidFees, pendingFees,
    presentToday, absentToday,
    attendanceMarked: todayRecords.length,
  };
}

// ─── Notices / Circulars ──────────────────────────────────────────────────────

export async function getNotices() {
  const snap = await getDocs(query(root('notices'), orderBy('createdAt', 'desc')));
  return snap.docs.map(d => ({ id: d.id, ...d.data() }));
}

export async function saveNotice(notice) {
  const id = notice.id || doc(root('notices')).id;
  const data = {
    ...notice,
    id,
    updatedAt: serverTimestamp(),
    syncedAt: serverTimestamp()
  };
  if (!notice.createdAt) {
    data.createdAt = new Date().toISOString();
  }
  await setDoc(rootDoc('notices', id), data, { merge: true });
  return { id, ...data };
}

export async function deleteNotice(id) {
  return deleteDoc(rootDoc('notices', id));
}

export async function markNoticeRead(noticeId, userId) {
  if (!userId) return;
  const snap = await getDoc(rootDoc('notices', noticeId));
  if (!snap.exists()) return;
  const currentReadBy = snap.data().readBy || [];
  if (!currentReadBy.includes(userId)) {
    return updateDoc(rootDoc('notices', noticeId), {
      readBy: [...currentReadBy, userId],
      updatedAt: serverTimestamp()
    });
  }
}

export function listenNotices(callback, onError) {
  return onSnapshot(
    query(root('notices'), orderBy('createdAt', 'desc')),
    snap => callback(snap.docs.map(d => ({ id: d.id, ...d.data() }))),
    onError
  );
}
