import { initializeApp, getApps, getApp } from 'firebase/app';
import { initializeFirestore, persistentLocalCache, persistentMultipleTabManager, getFirestore } from 'firebase/firestore';
import { getAuth } from 'firebase/auth';

export const firebaseConfig = {
  apiKey: "AIzaSyAtdW6QpcFjnvfrNHOkPwNCXeuX47qoijs",
  authDomain: "school-app-c24f9.firebaseapp.com",
  projectId: "school-app-c24f9",
  storageBucket: "school-app-c24f9.firebasestorage.app",
  messagingSenderId: "905557514986",
  appId: "1:905557514986:web:d996f41e3cda177b01d593"
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
