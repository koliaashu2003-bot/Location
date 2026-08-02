# Family Location Tracker

A free-tier family safety system with two parts:

- **`agent/`** — a Flutter Android app installed on a family member's phone.
  It tracks GPS location every 15 minutes, collects daily screen-time usage,
  and pushes updates to a **Telegram bot** and **Firebase Firestore**. It runs
  as a foreground service so Android won't kill it, and restarts on reboot.
- **`dashboard/`** — a React (Vite + Tailwind) web app that reads the same
  Firestore data and shows a **Leaflet/OpenStreetMap** map with each device's
  location, a 24-hour trail, and screen-time cards. Auto-refreshes every 60s.

Everything runs on **free tiers only** — Firebase Spark plan (no Cloud
Functions), Telegram Bot API, and OpenStreetMap tiles. No Google Maps, no paid
APIs.

```
family-tracker/
├── agent/          # Flutter Android app ("the Agent")
├── dashboard/      # React web dashboard
├── firebase/       # Firestore security rules + config
└── README.md
```

---

## How it works

```
   ┌─────────────────────┐        every 15 min         ┌───────────────┐
   │  Android phone       │  ── location + battery ──►  │  Telegram bot │
   │  (Flutter agent,     │                             └───────────────┘
   │   foreground svc)    │  ── location + screen ───►  ┌───────────────┐
   └─────────────────────┘        time to               │   Firestore   │
                                                         └───────┬───────┘
                                                                 │ read
                                                         ┌───────▼───────┐
                                                         │ React dashboard│
                                                         │ (Leaflet map)  │
                                                         └───────────────┘
```

- Location goes **straight to Telegram** over HTTPS — no Cloud Functions.
- Location + screen time are also **saved to Firestore** for the dashboard.
- The daily screen-time report is sent to Telegram and saved at **9 PM**.

---

## Prerequisites — install on your machine

1. **Flutter SDK** — https://docs.flutter.dev/get-started/install
2. **Android Studio** (for the Android SDK + an emulator) —
   https://developer.android.com/studio
3. Run `flutter doctor` and fix anything it reports.
4. **Node.js** (v18+) — https://nodejs.org

---

## 1. Firebase setup (free Spark plan)

1. Go to https://console.firebase.google.com and **create a project**
   named `family-tracker`.
2. **Build → Firestore Database → Create database.** Start in **test mode**
   for initial setup (you'll lock it down with the included rules later).
3. **Build → Authentication → Get started → Email/Password → Enable.**
   Then **Users → Add user** and create at least one account — you'll use it to
   sign into the dashboard.
4. **Add an Android app** with package name **`com.family.tracker.agent`**.
   - Download **`google-services.json`** and place it at
     **`agent/android/app/google-services.json`**
     (a `google-services.json.example` shows the expected shape).
5. **Add a Web app**, copy the config object, and either paste it into
   `dashboard/src/firebase.js` or fill in `dashboard/.env` (see
   `dashboard/.env.example`).

### Deploy the Firestore security rules

The rules in `firebase/firestore.rules` restrict all reads/writes to
authenticated users. Deploy them with the Firebase CLI:

```bash
npm install -g firebase-tools
firebase login
cd firebase
firebase use --add          # pick your family-tracker project
firebase deploy --only firestore:rules
```

> **Important — agent writes and auth.** The included rules require
> `request.auth != null`. The Flutter agent as written does **not** sign in, so
> for it to write to Firestore you have two options:
>
> - **Easiest for testing:** keep Firestore in **test mode** while you try it
>   out (rules allow open access for 30 days).
> - **Recommended for real use:** enable **Anonymous** sign-in
>   (Authentication → Sign-in method → Anonymous) and add
>   `firebase_auth` + a `signInAnonymously()` call in the agent so its writes
>   satisfy the rules. Telegram delivery works regardless — it doesn't touch
>   Firestore.

---

## 2. Telegram bot setup

1. In Telegram, open **@BotFather**, send `/newbot`, follow the prompts, and
   **save the bot token** (looks like `123456789:ABCdef...`).
2. Open a chat with your new bot and **send it any message** (e.g. "hi").
3. Visit `https://api.telegram.org/bot<YOUR_TOKEN>/getUpdates` in a browser and
   find your **chat id** (the `"chat":{"id": ...}` value).
4. You'll enter the **token** and **chat id** into the agent app on the phone.

---

## 3. Build & install the agent (phone app)

```bash
cd agent
# Regenerate any missing binary platform assets (launcher icons, the Gradle
# wrapper JAR, etc.) without touching the source in lib/ or the manifest.
# flutter create never overwrites files that already exist.
flutter create --platforms=android --project-name family_tracker_agent .
flutter pub get
```

Connect an Android phone via USB with **USB debugging** enabled, then:

```bash
flutter run --release
```

On the phone:

1. Enter the **Device Name** (e.g. `Aarav's Phone`).
2. Paste the **Telegram Bot Token** and **Chat ID**.
3. (Optional) Enter your **Firebase Project ID**.
4. Tap **Save Settings**, then flip the **toggle to Start**.
5. Grant the permission prompts:
   - **Location** — choose **Allow all the time** for background tracking.
   - **Notifications** — allow (Android 13+).
   - **Battery optimization** — allow the exemption so Android won't kill it.
   - **Usage access** (for screen time) — the app shows a banner; tap it to
     open Settings and enable "Usage access" for this app.

### Verifying it survives

Test that tracking keeps running after:
- swiping the app away from **Recents**,
- a **phone restart** (auto-starts on boot),
- **battery optimization** being active (you granted the exemption).

You should see the persistent **"Family Safety Active"** notification and get a
Telegram location message within ~15 minutes (the first one is sent
immediately on start).

---

## 4. Run the dashboard

```bash
cd dashboard
cp .env.example .env      # then fill in your Firebase web config
npm install
npm run dev
```

Open **http://localhost:5173**, sign in with the Email/Password account you
created in Firebase Auth, and you'll see the map, 24-hour trail, and
screen-time cards. The device selector lets you switch between family members;
data auto-refreshes every 60 seconds.

---

## Data model (Firestore)

```
locations/{deviceId}                      # denormalised "latest" summary
locations/{deviceId}/history/{timestamp}  # { latitude, longitude, battery,
                                          #   timestamp, deviceName }

screentime/{deviceId}                      # summary
screentime/{deviceId}/daily/{yyyy-MM-dd}   # { date, deviceName,
                                          #   apps: [{ appName, durationMinutes }],
                                          #   totalMinutes }
```

---

## Telegram message formats

**Location (every 15 min):**
```
📍 Location Update
Aarav's Phone's location:
https://www.google.com/maps?q=12.9716,77.5946
Battery: 84%
Time: 2026-08-02 14:30:00
```

**Screen time (daily at 9 PM):**
```
📱 Screen Time Report
Aarav's Phone's usage today:
1. Youtube - 2h 15m
2. Instagram - 1h 30m
...
```

---

## Permissions used (Android)

`ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `ACCESS_BACKGROUND_LOCATION`,
`FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION`, `RECEIVE_BOOT_COMPLETED`,
`WAKE_LOCK`, `PACKAGE_USAGE_STATS`, `INTERNET`,
`REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`, `POST_NOTIFICATIONS`.

---

## Notes & limitations

- **Screen time** relies on Android's `UsageStatsManager`, which needs the
  special **Usage access** permission granted manually in Settings. The app
  detects when it's missing and shows instructions.
- Exact 15-minute timing is best-effort — Android may batch or delay wake-ups
  under aggressive battery savers on some OEM skins (Xiaomi, Oppo, etc.).
  Granting the battery-optimization exemption and locking the app in Recents
  helps.
- This tool is intended for **consensual family safety** use. Make sure every
  tracked person knows and agrees to being tracked, and comply with local law.
