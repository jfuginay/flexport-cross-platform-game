# Android Testing Distribution Guide

## Option 1: Direct APK Distribution (Quickest for Testing)

### Step 1: Generate a Debug APK

```bash
# Open Android Studio
npx cap open android

# Or build from command line
cd android
./gradlew assembleDebug
```

The debug APK will be located at:
`android/app/build/outputs/apk/debug/app-debug.apk`

### Step 2: Share the APK

You can share the debug APK directly with testers via:
- Google Drive
- Dropbox  
- Email
- Discord
- WeTransfer

Testers will need to:
1. Enable "Install from Unknown Sources" in Android settings
2. Download and install the APK

## Option 2: Firebase App Distribution (Recommended)

### Step 1: Set up Firebase

1. Install Firebase CLI:
```bash
npm install -g firebase-tools
```

2. Add Firebase to your Android app:
```bash
# In your project root
npm install @react-native-firebase/app
npm install @react-native-firebase/app-distribution
```

### Step 2: Build Release APK

1. Generate a signing key (first time only):
```bash
cd android/app
keytool -genkey -v -keystore flexport-release-key.keystore -alias flexport-alias -keyalg RSA -keysize 2048 -validity 10000
```

2. Configure signing in `android/app/build.gradle`:
```gradle
android {
    ...
    signingConfigs {
        release {
            storeFile file('flexport-release-key.keystore')
            storePassword 'YOUR_STORE_PASSWORD'
            keyAlias 'flexport-alias'
            keyPassword 'YOUR_KEY_PASSWORD'
        }
    }
    buildTypes {
        release {
            signingConfig signingConfigs.release
            minifyEnabled false
            proguardFiles getDefaultProguardFile('proguard-android.txt'), 'proguard-rules.pro'
        }
    }
}
```

3. Build release APK:
```bash
cd android
./gradlew assembleRelease
```

### Step 3: Upload to Firebase

```bash
firebase appdistribution:distribute android/app/build/outputs/apk/release/app-release.apk \
  --app YOUR_FIREBASE_APP_ID \
  --groups "beta-testers" \
  --release-notes "Beta version for testing"
```

## Option 3: Google Play Console Beta Testing

### Prerequisites
- Google Play Developer Account ($25 one-time fee)
- App must be signed

### Step 1: Build App Bundle (AAB)

```bash
cd android
./gradlew bundleRelease
```

Output: `android/app/build/outputs/bundle/release/app-release.aab`

### Step 2: Upload to Play Console

1. Go to [Google Play Console](https://play.google.com/console)
2. Create new app
3. Go to "Testing" → "Internal testing"
4. Create new release
5. Upload the AAB file
6. Add tester emails

## Quick Start Commands

```bash
# 1. Make sure the app is built
npm run build
npx cap sync android

# 2. Generate debug APK for immediate testing
cd android && ./gradlew assembleDebug

# 3. The APK is now at:
# android/app/build/outputs/apk/debug/app-debug.apk
```

## Sharing with Testers

### For Debug APK:
1. Upload `app-debug.apk` to Google Drive
2. Share the link with testers
3. Include these instructions:

```
To install FlexPort 3D Beta:

1. On your Android device, go to Settings → Security
2. Enable "Unknown sources" or "Install unknown apps"
3. Download the APK from the link
4. Open the downloaded file and tap "Install"
5. Launch FlexPort 3D and enjoy!

Note: You may see a security warning - this is normal for test apps.
```

## Testing Checklist

Before sharing with testers:
- [ ] Test on at least one physical device
- [ ] Verify all permissions work (if any)
- [ ] Check that the app doesn't crash on startup
- [ ] Ensure the 3D globe loads properly
- [ ] Test basic gameplay functions

## Gathering Feedback

Create a simple Google Form with:
- Device model and Android version
- Performance (1-5 rating)
- Any crashes or bugs
- Feature suggestions
- Overall experience

## Next Steps

Once you have 10-20 beta testers and positive feedback:
1. Fix any critical bugs
2. Build a signed release APK/AAB
3. Submit to Google Play Store
4. Set up proper crash reporting (Firebase Crashlytics)

Remember: The debug APK is perfect for quick testing with friends and early feedback!