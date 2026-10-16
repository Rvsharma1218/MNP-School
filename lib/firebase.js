import { initializeApp, getApps, getApp } from 'firebase/app';
import { initializeFirestore, persistentLocalCache, persistentMultipleTabManager, getFirestore } from 'firebase/firestore';
import { getAuth } from 'firebase/auth';

export const firebaseConfig = {
  apiKey: "AIzaSyDogjF42VryLOxvuNmNW7U7Phhz7YrnAjg",
  authDomain: "mnpschool-bb50b.firebaseapp.com",
  projectId: "mnpschool-bb50b",
  storageBucket: "mnpschool-bb50b.firebasestorage.app",
  messagingSenderId: "767112171518",
  appId: "1:767112171518:web:1c3e7ce7f900efd0b5faaf",
  measurementId: "G-QEDYFV1K5R"
};

const app = getApps().length === 0 ? initializeApp(firebaseConfig) : getApp();

let dbInstance;
try {
  if (typeof window !== 'undefined') {
    dbInstance = initializeFirestore(app, {
      localCache: persistentLocalCache({
        tabManager: persistentMultipleTabManager()
      })
    });
  } else {
    dbInstance = getFirestore(app);
  }
} catch (e) {
  dbInstance = getFirestore(app);
}

export const db = dbInstance;
export const auth = getAuth(app);
export default app;
