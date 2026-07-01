# Building the Elevate Office Tracker APK

## What this does
Capacitor wraps your live Vercel app (https://elevate-office-tracker.vercel.app) in a native Android shell.
No need to rebuild on every update — the app always shows the latest Vercel deployment.

## One-time setup (do this once)

### 1. Install dependencies
```bash
npm install @capacitor/core @capacitor/cli @capacitor/android @capacitor/push-notifications
npx cap init
```

### 2. Add Android platform
```bash
npx cap add android
```

### 3. Sync
```bash
npx cap sync android
```

### 4. Open in Android Studio
```bash
npx cap open android
```

### 5. Build APK in Android Studio
- Menu → Build → Build Bundle(s) / APK(s) → Build APK(s)
- Find APK at: `android/app/build/outputs/apk/debug/app-debug.apk`

### 6. Send APK to users
- Share the .apk file via WhatsApp, email, or any file sharing
- Users tap to install (they need "Install from unknown sources" enabled)
- Settings → Security → Unknown Sources → Enable

## Requirements
- Android Studio installed: https://developer.android.com/studio
- Java JDK 17+
- Node.js 18+

## Push Notifications (optional)
To add push notifications to the APK:
1. Create Firebase project at console.firebase.google.com
2. Add Android app with package ID: com.elevate.officetracker
3. Download google-services.json → place in android/app/
4. Follow Capacitor Push Notifications guide

## Updates
When you update the Vercel deployment, the APK automatically shows the new version
(since it uses the live URL). No need to rebuild the APK for content updates.
