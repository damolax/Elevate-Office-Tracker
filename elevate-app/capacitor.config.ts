import { CapacitorConfig } from '@capacitor/cli';

const config: CapacitorConfig = {
  appId: 'com.elevate.officetracker',
  appName: 'Elevate Office',
  webDir: 'out',
  server: {
    // Use live Vercel URL so no local build needed
    url: 'https://elevate-office-tracker.vercel.app',
    cleartext: true,
  },
  plugins: {
    PushNotifications: {
      presentationOptions: ['badge', 'sound', 'alert'],
    },
    LocalNotifications: {
      smallIcon: 'ic_stat_icon',
      iconColor: '#6366f1',
    },
  },
};

export default config;
