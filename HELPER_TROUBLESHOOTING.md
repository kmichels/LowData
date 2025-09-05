# SMAppService Helper Installation Troubleshooting

## ISSUE RESOLVED (2025-09-04)
The helper daemon now works correctly after discovering critical undocumented SMAppService requirements.

### THE SOLUTION
The key issue was that `SMAppService.daemon(plistName:)` requires the full filename INCLUDING the `.plist` extension, contrary to some documentation. Additionally, several other configuration details were critical.

### Symptoms
- SMAppService reports status as `.enabled` (rawValue: 1)
- XPC connection fails with "Couldn't communicate with a helper application"
- launchd shows: `last exit code = 78: EX_CONFIG` and `job state = spawn failed`
- Helper process never actually runs

## What We've Tried

### 1. Basic Setup
- Created helper daemon at `Contents/Library/LaunchDaemons/com.lowdata.helper.xpc`
- Created plist at `Contents/Library/LaunchDaemons/com.lowdata.helper.plist`
- Also copied plist without extension as `com.lowdata.helper` (SMAppService requirement)

### 2. Code Signing Issues
- **Problem**: Helper was getting ad-hoc signature from swiftc
- **Attempted Solutions**:
  - Modified build script to sign with `${CODE_SIGN_IDENTITY}` - but it was "-" (don't sign)
  - Fallback to `${DEVELOPMENT_TEAM}` with "Apple Development" certificate
  - Successfully signed with team ID: 85QL287QYW
  - Helper now shows proper signature with correct team

### 3. App Bundle Identifier
- **Problem**: App was missing CFBundleIdentifier in Info.plist
- **Solution**: Added `com.tonalphoto.tech.LowData` to Info.plist
- App now properly identified

### 4. Helper Info.plist Embedding
- **Problem**: Helper binary had no embedded Info.plist
- **Attempted Solution**: 
  - Created Info.plist with SMAuthorizedClients
  - Embedded using `-Xlinker -sectcreate -Xlinker __TEXT -Xlinker __info_plist`
  - Also embedded launchd plist
  - Verified embedding with `otool -s __TEXT __info_plist`

### 5. Plist Configuration
Current com.lowdata.helper.plist:
```xml
<key>Label</key>
<string>com.lowdata.helper</string>
<key>BundleProgram</key>
<string>com.lowdata.helper.xpc</string>
<key>MachServices</key>
<dict>
    <key>com.lowdata.helper</key>
    <true/>
</dict>
<key>RunAtLoad</key>
<true/>
<key>KeepAlive</key>
<true/>
<key>ProcessType</key>
<string>Interactive</string>
<key>AssociatedBundleIdentifiers</key>
<array>
    <string>com.tonalphoto.tech.LowData</string>
</array>
```

### 6. Build Script
Current script:
- Builds helper with swiftc
- Embeds both Info.plist and launchd plist
- Signs with development team
- Copies to app bundle

## Current State
- Helper is properly signed with correct team ID
- Has embedded Info.plist and launchd plist  
- SMAppService accepts registration (status = .enabled)
- But helper won't actually start (exit code 78: EX_CONFIG)

## Questions to Research
1. Does SMAppService require specific entitlements for the helper?
2. Is ProcessType "Interactive" correct for a daemon?
3. Should this be a LaunchAgent instead of LaunchDaemon?
4. Are there specific Info.plist keys required for SMAppService helpers?
5. Does the helper need a specific bundle structure?
6. Is XPC service registration different for SMAppService daemons?

## CRITICAL FIXES THAT RESOLVED THE ISSUE

1. **plistName MUST include .plist extension**
   ```swift
   // WRONG - Silent failure:
   SMAppService.daemon(plistName: "com.lowdata.helper")
   
   // CORRECT - Must include extension:
   SMAppService.daemon(plistName: "com.lowdata.helper.plist")
   ```

2. **BundleProgram needs full relative path from bundle root**
   ```xml
   <key>BundleProgram</key>
   <string>Contents/Library/LaunchDaemons/com.lowdata.helper.xpc</string>
   ```
   Not just filename!

3. **ProcessType must be "Background" not "Interactive"**
   ```xml
   <key>ProcessType</key>
   <string>Background</string>
   ```

4. **XPC connections require .privileged option**
   ```swift
   let connection = NSXPCConnection(machServiceName: helperBundleID, options: .privileged)
   ```

5. **Async helper status checking to prevent UI blocking**
   - Never use `Process.waitUntilExit()` on main thread
   - This was causing app to hang on startup

## Environment
- macOS 15.0 (Sequoia)
- Xcode 16.0
- Swift 5
- Development signing (not distribution)

## Resources That Helped
- ChatGPT research with multiple working examples from GitHub
- Community examples: DaemonExample by Bryson Tyrrell
- Apple Developer Forums discussions about SMAppService quirks