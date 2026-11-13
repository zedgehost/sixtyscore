# 🔐 60Score — Google Play Console Release & Keystore Credentials

**Document Date:** November 2026  
**Application Name:** 60Score (Cricket Scorer, Draft & Tournaments)  
**Package / Application ID:** `com.cricscore.cricket_scorer_app`  
**Current Version:** `1.4.9+32` (Version Name: `1.4.9`, Version Code: `32`)

---

## 🔑 Production Keystore Credentials (Google Play Signing)

> [!CAUTION]
> **CRITICAL BACKUP REQUIREMENT:**  
> The keystore file `upload-keystore.jks` and these credentials are required for ALL future updates of this app on Google Play. If this file or password is lost, Google Play will **PERMANENTLY REJECT** any future updates, requiring a new app submission under a different package name. Keep a copy in Google Drive or a secure password vault.

| Property | Value | Notes |
|---|---|---|
| **Keystore File Name** | `upload-keystore.jks` | Located in `cricket_scorer_app/android/` |
| **Keystore Type** | `PKCS12` (Standard) | Migrated to industry standard format |
| **Key Alias** | `upload` | Production release alias |
| **Keystore Password** | `Score60@Release2026!` | Store & Key password |
| **Key Password** | `Score60@Release2026!` | Matches store password |
| **Key Algorithm** | RSA 2048-bit | SHA384withRSA self-signed |
| **Validity** | 10,000 Days | Valid until ~July 2054 |
| **Certificate DN** | `CN=60Score Scorer, OU=App, O=60Score, L=Lahore, ST=Punjab, C=PK` | Super Sixty League Authority |

---

## ⚙️ Configuration Files in Project

### 1. `cricket_scorer_app/android/key.properties`
This file connects Gradle directly to the keystore for automated release signing:
```properties
storePassword=Score60@Release2026!
keyPassword=Score60@Release2026!
keyAlias=upload
storeFile=../upload-keystore.jks
```
*(Note: Both `key.properties` and `upload-keystore.jks` are protected in `.gitignore` so they are never leaked to public git repositories).*

### 2. Gradle Integration (`android/app/build.gradle.kts`)
Automatically detects `key.properties` and applies the `release` signing configuration:
```kotlin
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
```

---

## 🚀 How to Build New Releases for Google Play Console

### Step 1: Increment Version Code (For every new update)
Google Play requires a higher `versionCode` for every upload.
In `cricket_scorer_app/pubspec.yaml`, edit:
```yaml
# Before:
version: 1.4.8+31

# For next update (increment the number after +):
version: 1.4.9+32
```

### Step 2: Build the App Bundle (.aab)
Run this command from inside `cricket_scorer_app`:
```bash
flutter build appbundle --release
```

### Step 3: Locate the Upload Bundle
Once the build completes, the signed `.aab` file will be here:
```
cricket_scorer_app/build/app/outputs/bundle/release/app-release.aab
```
- **Verified Bundle Status:** ✅ Generated & Signed Successfully (`jar verified.`)
- **Bundle Upload Size:** ~67.4 MB (`70,642,867 bytes`)
- **Actual End-User Download Size on Play Store:** **~16.4 MB** (via Google Play Dynamic Delivery)
- **Package ID:** `com.cricscore.cricket_scorer_app`
- **Target Platform:** Android SDK 24–35 (supports all modern Android devices)

Upload this `app-release.aab` directly to Google Play Console under **Production** or **Closed Testing**.

---

## 📋 Google Play Store Listing Essentials

1. **App Name:** `60Score - Cricket Scorer`
2. **Short Description:** `Professional offline-first cricket scorer, player draft & tournament manager.`
3. **Category:** Sports
4. **Privacy Policy Link:** Host the included [`docs/privacy-policy.html`](file:///docs/privacy-policy.html) file on GitHub Pages, Netlify, or your domain.
5. **Content Rating:** Suitable for all ages / Everyone.
