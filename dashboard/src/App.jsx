import { useCallback, useEffect, useState } from 'react';
import {
  collection,
  doc,
  getDoc,
  getDocs,
  query,
  orderBy,
} from 'firebase/firestore';
import {
  onAuthStateChanged,
  signInWithEmailAndPassword,
  signOut,
} from 'firebase/auth';
import { db, auth } from './firebase';
import MapView from './components/MapView';
import ScreenTimeCard from './components/ScreenTimeCard';
import DeviceSelector from './components/DeviceSelector';

const REFRESH_MS = 60 * 1000; // Auto-refresh every 60 seconds.

function todayKey() {
  const now = new Date();
  const y = now.getFullYear();
  const m = String(now.getMonth() + 1).padStart(2, '0');
  const d = String(now.getDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}

export default function App() {
  const [user, setUser] = useState(null);
  const [authChecked, setAuthChecked] = useState(false);

  const [devices, setDevices] = useState([]);
  const [selectedId, setSelectedId] = useState(null);
  const [current, setCurrent] = useState(null);
  const [history, setHistory] = useState([]);
  const [screenTime, setScreenTime] = useState(null);
  const [lastRefresh, setLastRefresh] = useState(null);

  // Auth state.
  useEffect(() => {
    const unsub = onAuthStateChanged(auth, (u) => {
      setUser(u);
      setAuthChecked(true);
    });
    return unsub;
  }, []);

  // Load the list of tracked devices.
  const loadDevices = useCallback(async () => {
    const snap = await getDocs(collection(db, 'locations'));
    const list = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
    setDevices(list);
    setSelectedId((prev) => prev || (list.length > 0 ? list[0].id : null));
  }, []);

  // Load data for the selected device.
  const loadDeviceData = useCallback(async (deviceId) => {
    if (!deviceId) return;

    // Latest summary doc.
    const summarySnap = await getDoc(doc(db, 'locations', deviceId));
    const summary = summarySnap.exists() ? summarySnap.data() : {};

    // Location history (last 24h).
    const historyQ = query(
      collection(db, 'locations', deviceId, 'history'),
      orderBy('timestamp', 'asc')
    );
    const historySnap = await getDocs(historyQ);
    const cutoff = Date.now() - 24 * 60 * 60 * 1000;
    const historyDocs = historySnap.docs
      .map((d) => d.data())
      .filter((h) => new Date(h.timestamp).getTime() >= cutoff);

    setHistory(historyDocs);

    const latest =
      historyDocs.length > 0
        ? historyDocs[historyDocs.length - 1]
        : summary.lastLatitude != null
        ? {
            latitude: summary.lastLatitude,
            longitude: summary.lastLongitude,
            battery: summary.lastBattery,
            timestamp: summary.lastUpdate,
            deviceName: summary.deviceName,
          }
        : null;
    setCurrent(latest);

    // Today's screen time.
    const stSnap = await getDoc(
      doc(db, 'screentime', deviceId, 'daily', todayKey())
    );
    setScreenTime(stSnap.exists() ? stSnap.data() : null);

    setLastRefresh(new Date());
  }, []);

  // Initial + polling refresh once authenticated.
  useEffect(() => {
    if (!user) return;
    loadDevices();
  }, [user, loadDevices]);

  useEffect(() => {
    if (!user || !selectedId) return;
    loadDeviceData(selectedId);
    const interval = setInterval(() => {
      loadDevices();
      loadDeviceData(selectedId);
    }, REFRESH_MS);
    return () => clearInterval(interval);
  }, [user, selectedId, loadDeviceData, loadDevices]);

  if (!authChecked) {
    return (
      <div className="flex h-screen items-center justify-center text-gray-500">
        Loading…
      </div>
    );
  }

  if (!user) {
    return <LoginScreen />;
  }

  const selectedDevice = devices.find((d) => d.id === selectedId);

  return (
    <div className="min-h-screen bg-gray-50">
      <header className="bg-indigo-600 text-white shadow">
        <div className="mx-auto flex max-w-6xl items-center justify-between px-4 py-4">
          <h1 className="text-xl font-bold">👨‍👩‍👧 Family Location Tracker</h1>
          <button
            onClick={() => signOut(auth)}
            className="rounded-md bg-indigo-500 px-3 py-1.5 text-sm hover:bg-indigo-400"
          >
            Sign out
          </button>
        </div>
      </header>

      <main className="mx-auto max-w-6xl space-y-6 px-4 py-6">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <DeviceSelector
            devices={devices}
            selectedId={selectedId}
            onSelect={setSelectedId}
          />
          {lastRefresh && (
            <span className="text-xs text-gray-400">
              Last refreshed: {lastRefresh.toLocaleTimeString()}
            </span>
          )}
        </div>

        <div className="grid grid-cols-1 gap-6 lg:grid-cols-3">
          <div className="lg:col-span-2">
            <MapView current={current} history={history} />
          </div>
          <div>
            <ScreenTimeCard
              deviceName={selectedDevice?.deviceName}
              apps={screenTime?.apps}
              totalMinutes={screenTime?.totalMinutes}
            />
          </div>
        </div>
      </main>
    </div>
  );
}

function LoginScreen() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  const handleLogin = async (e) => {
    e.preventDefault();
    setError('');
    setLoading(true);
    try {
      await signInWithEmailAndPassword(auth, email, password);
    } catch (err) {
      setError(err.message || 'Login failed');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="flex min-h-screen items-center justify-center bg-gray-50 px-4">
      <form
        onSubmit={handleLogin}
        className="w-full max-w-sm space-y-4 rounded-xl bg-white p-8 shadow"
      >
        <h1 className="text-center text-2xl font-bold text-gray-800">
          Family Tracker
        </h1>
        <p className="text-center text-sm text-gray-500">
          Sign in to view your family's dashboard
        </p>

        {error && (
          <div className="rounded-md bg-red-50 p-3 text-sm text-red-600">
            {error}
          </div>
        )}

        <input
          type="email"
          placeholder="Email"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          required
          className="w-full rounded-md border border-gray-300 px-3 py-2 text-sm focus:border-indigo-500 focus:outline-none focus:ring-1 focus:ring-indigo-500"
        />
        <input
          type="password"
          placeholder="Password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          required
          className="w-full rounded-md border border-gray-300 px-3 py-2 text-sm focus:border-indigo-500 focus:outline-none focus:ring-1 focus:ring-indigo-500"
        />
        <button
          type="submit"
          disabled={loading}
          className="w-full rounded-md bg-indigo-600 py-2 text-sm font-medium text-white hover:bg-indigo-500 disabled:opacity-50"
        >
          {loading ? 'Signing in…' : 'Sign in'}
        </button>
      </form>
    </div>
  );
}
