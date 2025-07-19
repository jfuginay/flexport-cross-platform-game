# FlexPort 3D Mobile App

This project now includes native iOS and Android apps built with Capacitor. The mobile version provides a streamlined interface for managing your global shipping empire on the go.

## Mobile Features

- **Fleet Management**: View all your ships, their status, cargo, and location
- **Contract Management**: Browse available contracts and assign ships
- **Real-time Alerts**: Get notifications about ship arrivals, contract deadlines, and opportunities
- **3D Globe View**: Interactive 3D visualization optimized for mobile performance
- **Responsive Navigation**: Bottom navigation bar for easy access to all features

## Running the Mobile Apps

### iOS (Requires macOS with Xcode)

1. Open the iOS project in Xcode:
   ```bash
   npx cap open ios
   ```

2. Select your target device or simulator
3. Click the Run button (or press Cmd+R)

### Android

1. Open the Android project in Android Studio:
   ```bash
   npx cap open android
   ```

2. Select your target device or emulator
3. Click the Run button

### Live Development

For live reload during development:

1. Start the development server:
   ```bash
   npm start
   ```

2. Update the capacitor.config.ts to point to your local dev server:
   ```typescript
   server: {
     url: 'http://YOUR_IP:3000',
     cleartext: true
   }
   ```

3. Run on device:
   ```bash
   npx cap run ios --livereload --external
   # or
   npx cap run android --livereload --external
   ```

## Building for Production

### iOS
1. Build the React app: `npm run build`
2. Sync with Capacitor: `npx cap sync`
3. Open in Xcode: `npx cap open ios`
4. Archive and distribute through App Store Connect

### Android
1. Build the React app: `npm run build`
2. Sync with Capacitor: `npx cap sync`
3. Open in Android Studio: `npx cap open android`
4. Build APK or App Bundle for distribution

## Mobile-Specific Components

- `MobileNavigation`: Bottom navigation bar with fleet, contracts, and alerts
- `MobileFleetView`: Full-screen fleet management interface
- `MobileContractsView`: Contract browsing and acceptance
- `MobileAlertsView`: Real-time notifications and alerts

## Performance Optimizations

The mobile version includes:
- Reduced shadow map resolution for better performance
- Touch-optimized controls
- Responsive layouts for various screen sizes
- Native haptic feedback on supported devices

## Next Steps

To add push notifications:
1. Install the Push Notifications plugin: `npm install @capacitor/push-notifications`
2. Configure FCM for Android and APNS for iOS
3. Implement notification handlers in the app

For offline support:
1. Install the Storage plugin: `npm install @capacitor/storage`
2. Implement data persistence layer
3. Add sync mechanisms for when connectivity returns