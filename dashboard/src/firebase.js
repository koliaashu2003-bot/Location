// Firebase initialisation for the dashboard.
//
// Replace the config object below with the one from your Firebase project:
//   Firebase Console → Project settings → Your apps → Web app → Config.
//
// You can also supply these via Vite env vars (see .env.example) so you don't
// commit secrets: values from import.meta.env take precedence when present.
import { initializeApp } from 'firebase/app';
import { getFirestore } from 'firebase/firestore';
import { getAuth } from 'firebase/auth';

const firebaseConfig = {
  apiKey: import.meta.env.VITE_FIREBASE_API_KEY || 'REPLACE_ME',
  authDomain:
    import.meta.env.VITE_FIREBASE_AUTH_DOMAIN || 'family-tracker.firebaseapp.com',
  projectId: import.meta.env.VITE_FIREBASE_PROJECT_ID || 'family-tracker',
  storageBucket:
    import.meta.env.VITE_FIREBASE_STORAGE_BUCKET || 'family-tracker.appspot.com',
  messagingSenderId:
    import.meta.env.VITE_FIREBASE_MESSAGING_SENDER_ID || '000000000000',
  appId: import.meta.env.VITE_FIREBASE_APP_ID || 'REPLACE_ME',
};

const app = initializeApp(firebaseConfig);

export const db = getFirestore(app);
export const auth = getAuth(app);
export default app;
