# iOS Installation Guide

## 🍎 SMS Gateway iOS App

### 🎨 New Professional App Icon
The SMS Gateway iOS app now features a professional new icon with:
- Modern SMS/messaging theme with phone and envelope symbols
- Professional gradient design (purple to blue)
- Gateway connectivity visualization with signal waves
- Optimized for all iOS icon sizes and Retina displays
- Meets Apple App Store design guidelines

### Available Files

- **Runner.app** (57.4MB) - **LATEST VERSION - JANUARY 2025**
  - ✨ **NEW**: Fresh build with latest updates
  - ✅ Complete WiFi network integration support
  - ✅ Enhanced multi-platform connectivity (C#, Django, Next.js, React.js, Node.js)
  - ✅ All connectivity fixes implemented
  - ✅ Enhanced CORS and authentication
  - ✅ Automatic server startup and background service
  - ✅ Improved IP detection and network discovery
  - ✅ Production-ready iOS build with comprehensive API documentation
  - ⚠️ Unsigned build (requires code signing for device installation)

### Installation Methods

#### Method 1: Development Installation (Xcode Required)

1. **Prerequisites:**
   - macOS with Xcode installed
   - iOS device connected via USB
   - Apple Developer account (free or paid)

2. **Installation Steps:**
   - Open Terminal and navigate to the project root
   - Connect your iOS device
   - Run: `flutter install --device-id=<your-device-id>`
   - Or use Xcode to install the Runner.app bundle

#### Method 2: Enterprise Distribution

1. **Requirements:**
   - Apple Enterprise Developer Program membership
   - Enterprise distribution certificate
   - Provisioning profile

2. **Steps:**
   - Sign the Runner.app with enterprise certificate
   - Distribute via MDM or direct installation
   - Users must trust the enterprise certificate

#### Method 3: App Store Distribution

1. **Requirements:**
   - Apple Developer Program membership ($99/year)
   - App Store review approval

2. **Process:**
   - Code sign with distribution certificate
   - Upload to App Store Connect
   - Submit for review
   - Distribute via App Store or TestFlight

### iOS Limitations

⚠️ **Important iOS Restrictions:**

- **SMS Functionality:** iOS does not allow third-party apps to send SMS messages programmatically
- **Background Processing:** Limited background execution capabilities
- **System Integration:** Restricted access to system SMS functions

### Recommended Use Cases for iOS

✅ **What works well:**
- Configuration and monitoring interface
- HTTP server for receiving requests
- Message logging and statistics
- API key management
- Device information display

❌ **What doesn't work:**
- Sending SMS messages (iOS restriction)
- Background SMS processing
- System-level SMS integration

### Installation Troubleshooting

**"Untrusted Developer" Error:**
- Go to Settings > General > VPN & Device Management
- Find the developer profile
- Tap "Trust [Developer Name]"

**App Won't Install:**
- Ensure device is in developer mode
- Check provisioning profile validity
- Verify code signing certificates

**App Crashes:**
- Check iOS version compatibility (iOS 12.0+)
- Ensure proper entitlements are configured
- Review device logs in Xcode Console

### Alternative Solutions for iOS

Since iOS restricts SMS functionality, consider:

1. **Shortcuts App Integration:**
   - Create iOS Shortcuts for SMS automation
   - Use the SMS Gateway app for configuration only

2. **Companion Android Device:**
   - Use iOS app for monitoring
   - Use Android device for actual SMS gateway

3. **Web Interface:**
   - Access the HTTP server from iOS Safari
   - Use web-based controls and monitoring

### Security Considerations

- iOS apps are sandboxed by default
- Network permissions are automatically granted
- No SMS permissions needed (since SMS is restricted)
- Regular security updates via App Store

### Network Integration

After installation, the iOS app provides:
- **WiFi Network Discovery**: Automatically detects and displays the device IP address
- **Multi-Platform Support**: Ready for integration with C#, Django, Next.js, React.js, and Node.js applications
- **API Documentation**: Complete examples and code samples in the main README.md
- **Default API Key**: `sms-gateway-default-key-2024` (change immediately in production)
- **Default Port**: 8080 (configurable in app settings)
- **HTTP Server**: Full REST API server functionality for monitoring and configuration

---
**Latest Build Information:**
- **File Size**: 57.4MB (iOS App Bundle)
- **Build Date**: January 2025
- **Flutter Version**: Latest stable
- **iOS Target**: iOS 12.0+
- **Architecture**: Universal (ARM64 + x86_64 for simulator)

**Note:** For full SMS gateway functionality, an Android device is recommended. The iOS version serves primarily as a monitoring and configuration interface due to iOS SMS restrictions.