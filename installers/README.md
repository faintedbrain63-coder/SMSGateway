# SMS Gateway App - Installation Guide

## 📱 Available Installers

This directory contains production-ready installers for the SMS Gateway Flutter application with **NEW PROFESSIONAL APP ICONS**.

### 🎨 What's New in This Release
- ✨ **Professional App Icons**: Modern SMS/messaging theme with gradient design
- 🔧 **All Connectivity Fixes**: Enhanced CORS, authentication, and network binding
- 🚀 **Auto-Start Server**: Automatic server startup on app launch
- 📡 **Improved IP Detection**: Better network connectivity handling
- 🔒 **Enhanced Security**: Updated authentication and permissions

### 🤖 Android Installation

**Location:** `android/` directory

**Latest APK File:**
- `app-release.apk` (23.2MB) - **LATEST VERSION WITH NEW ICON**
  - ✨ Professional app icon and branding
  - ✅ Universal compatibility (all Android devices)
  - ✅ All connectivity fixes implemented
  - ✅ Production-ready build

**Installation Steps:**
1. Enable "Unknown Sources" in Android Settings > Security
2. Download the appropriate APK file to your Android device
3. Tap the APK file to install
4. Grant necessary permissions when prompted (SMS, Phone, Storage)

**Recommended APK:** Use `app-arm64-v8a-release.apk` for most modern Android devices for optimal performance and smaller file size.

### 🍎 iOS Installation

**Location:** `ios/` directory

**Latest iOS Build:**
- `Runner.app` (57.3MB) - **LATEST VERSION WITH NEW ICON**
  - ✨ Professional app icon and branding
  - ✅ All connectivity fixes implemented
  - ✅ Production-ready iOS build
  - ⚠️ Unsigned build (requires code signing)

**Installation Requirements:**
- iOS device with developer mode enabled, OR
- Enterprise distribution certificate, OR
- App Store distribution

**Installation Notes:**
- The iOS build is unsigned and requires code signing before installation on physical devices
- For development/testing: Use Xcode to install on connected iOS devices
- For distribution: Sign with appropriate certificates and distribute via TestFlight or App Store

## 🔧 App Configuration

### First Launch Setup
1. **Android:** The app will request SMS and phone permissions on first launch
2. **iOS:** SMS functionality is limited on iOS due to platform restrictions
3. Configure API keys and server settings in the app's Configuration page

### Required Permissions
- **SMS:** Send and receive SMS messages
- **Phone:** Access phone state and numbers
- **Network:** Internet access for HTTP server
- **Storage:** Database and log storage
- **Background:** Keep service running

## 🚀 Features
- Turn your device into an SMS gateway
- HTTP API for sending SMS messages
- Web dashboard for monitoring
- Message logging and statistics
- Background service support
- API key authentication

## 📋 System Requirements

### Android
- Android 5.0 (API level 21) or higher
- SMS and phone capabilities
- Internet connection

### iOS
- iOS 12.0 or higher
- Limited SMS functionality due to iOS restrictions
- Primarily useful for monitoring and configuration

## 🔒 Security Notes
- Change default API keys before production use
- Use HTTPS in production environments
- Regularly update the application
- Monitor access logs for unauthorized usage

## 📞 Support
For issues or questions, please refer to the main project documentation or create an issue in the project repository.

---
**Version:** 1.0.0+1  
**Build Date:** January 2025  
**Platform:** Flutter (Android/iOS)