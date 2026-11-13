# 🚀 60Score — Google Play Console Publishing Kit

This document provides **every single detail, asset, declaration, and copy-paste text** required to publish **60Score** on the Google Play Console.

---

## 📑 Quick Navigation
1. [General App Information](#1-general-app-information)
2. [Store Listing (Copy-Paste Text)](#2-store-listing-copy-paste-text)
3. [Store Graphics & Media](#3-store-graphics--media)
4. [App Content & Policy Declarations (Questionnaire Answers)](#4-app-content--policy-declarations-questionnaire-answers)
5. [Data Safety Form Answers](#5-data-safety-form-answers)
6. [Release & App Bundle (.aab) Upload](#6-release--app-bundle-aab-upload)
7. [Privacy Policy Hosting Guide](#7-privacy-policy-hosting-guide)

---

## 1. General App Information

| Field | Value | Notes |
|---|---|---|
| **App Name** | `60Score - Cricket Scorer` | Exactly 24 characters (Limit: 30) |
| **Package Name / App ID** | `com.cricscore.cricket_scorer_app` | Matches Android namespace |
| **Default Language** | English (United States) - en-US | Can add Urdu later |
| **App or Game?** | App | |
| **Free or Paid?** | Free | |
| **Category** | Sports | Under `App > Sports` |
| **Tags / Keywords** | Cricket, Scorekeeper, Sports, Tournament Manager | Select in Store Settings |
| **Contact Email** | `support@60score.com` *(or your developer email)* | Visible on Play Store |

---

## 2. Store Listing (Copy-Paste Text)

### 📌 Title (Max 30 characters)
```text
60Score - Cricket Scorer
```

### 📌 Short Description (Max 80 characters)
```text
Professional offline cricket scorer, tournament manager & player draft app.
```

### 📌 Full Description (Max 4000 characters)
```text
60Score is the ultimate all-in-one cricket scoring, player auction, and tournament management app built for club cricket, street leagues, and tournament organizers. Designed with an offline-first architecture, 60Score ensures you can score every match seamlessly without needing an active internet connection.

KEY FEATURES:

🏏 PROFESSIONAL BALL-BY-BALL SCORING
• Intuitive one-tap scoring interface for dots, 1s, 2s, 3s, 4s, 6s, extras, and wickets.
• Full support for No-Balls, Wides, Byes, Leg-Byes, and Penalty runs.
• Advanced wicket modes: Bowled, Caught, LBW, Run Out, Stumped, Hit Wicket, Obstructing Field, and Retired Hurt.
• Bowler incapacitation / mid-over bowler injury replacement according to MCC Law 17.8.
• Live ball-by-ball commentary and full bowler/batsman performance tracking.
• Complete Undo and Scorecard Edit capabilities with outcome recalculation.

🌧️ ICC STANDARD DLS CALCULATOR (Duckworth-Lewis-Stern)
• Real-time DLS target calculation for rain-curtailed limited-overs matches.
• Accurate Net Run Rate (NRR) computation adhering strictly to ICC Clause 16.10.2 regulations.
• Automatic revision of overs, targets, and par scores during active matches.

⚡ SUPER OVER ENGINE
• Dedicated one-over eliminator mode for tied matches.
• Automatic winner determination with boundary count and playoff bracket advancement.

🏆 COMPLETE TOURNAMENT & LEAGUE MANAGER
• Create Round-Robin, Double Round-Robin, Knockout, and Group Stage tournaments.
• Automated Points Table with Win, Loss, Tie, No Result, Points, and precision Net Run Rate (NRR).
• Automated Playoff Brackets: Qualifiers, Eliminators, and Grand Finals with dynamic winner assignment.

👥 PLAYER DRAFT & AUCTION SYSTEM
• Conduct live team drafts and auctions with budget caps, base prices, and category tiers (Platinum, Gold, Silver, Emerging).
• Real-time team purse calculation, squad limits, and auto-generated rosters.

📊 DEEP STATS & EXPORTS
• Detailed scorecards showing batting strike rates, bowling economy, fall of wickets, and partnership charts.
• Export and share beautiful match summaries and tournament reports.
• 100% offline functionality — never worry about pitch-side network dropouts.

Download 60Score today and take your cricket tournament organization to the professional level!
```

---

## 3. Store Graphics & Media

Google Play Console requires specific dimensions for graphics. Both required assets have already been generated and placed in the [`play_store_assets/`](file:///c:/Users/Muhammad%20Aliyan/Desktop/crciketscoree/60score/play_store_assets/) folder:

| Asset | Required Specs | Prepared File Path |
|---|---|---|
| **App Icon** | 512 x 512 px, 32-bit PNG, max 1 MB | [`play_store_assets/app_icon_512x512.png`](file:///c:/Users/Muhammad%20Aliyan/Desktop/crciketscoree/60score/play_store_assets/app_icon_512x512.png) |
| **Feature Graphic** | 1024 x 500 px, PNG/JPEG, max 15 MB | [`play_store_assets/feature_graphic_1024x500.png`](file:///c:/Users/Muhammad%20Aliyan/Desktop/crciketscoree/60score/play_store_assets/feature_graphic_1024x500.png) |
| **Phone Screenshots (6 Ready)** | 1080 x 1920 px (9:16 aspect ratio), PNG | 📂 [`play_store_assets/screenshots/`](file:///c:/Users/Muhammad%20Aliyan/Desktop/crciketscoree/60score/play_store_assets/screenshots/) |
| • Screenshot 1 | Live Ball-by-Ball Match Scorer | [`1_live_scoring.png`](file:///c:/Users/Muhammad%20Aliyan/Desktop/crciketscoree/60score/play_store_assets/screenshots/1_live_scoring.png) |
| • Screenshot 2 | ICC Standard DLS Calculator & NRR | [`2_dls_calculator.png`](file:///c:/Users/Muhammad%20Aliyan/Desktop/crciketscoree/60score/play_store_assets/screenshots/2_dls_calculator.png) |
| • Screenshot 3 | Super Over Eliminator Engine | [`3_super_over.png`](file:///c:/Users/Muhammad%20Aliyan/Desktop/crciketscoree/60score/play_store_assets/screenshots/3_super_over.png) |
| • Screenshot 4 | Tournaments & Live Points Table | [`4_tournaments.png`](file:///c:/Users/Muhammad%20Aliyan/Desktop/crciketscoree/60score/play_store_assets/screenshots/4_tournaments.png) |
| • Screenshot 5 | Live Player Draft & Auction | [`5_player_draft.png`](file:///c:/Users/Muhammad%20Aliyan/Desktop/crciketscoree/60score/play_store_assets/screenshots/5_player_draft.png) |
| • Screenshot 6 | Detailed Scorecards & Stats Export | [`6_stats_scorecard.png`](file:///c:/Users/Muhammad%20Aliyan/Desktop/crciketscoree/60score/play_store_assets/screenshots/6_stats_scorecard.png) |

---

## 4. App Content & Policy Declarations (Questionnaire Answers)

In Google Play Console, go to **Policy and programs > App content** and answer each section as follows:

### 1. Privacy Policy
- Provide the hosted URL of your privacy policy (see [Section 7](#7-privacy-policy-hosting-guide)).

### 2. App Access
- Select: **"All functionality is available without special access"**  
  *(The app works completely offline; users do not require credentials to use the scorer).*

### 3. Ads
- Select: **"No, my app does not contain ads"**

### 4. Content Rating (IARC Questionnaire)
- Enter your contact email.
- Category: Select **"Utility, Productivity, Communication, or Other"** (or **"Sports"**).
- Violence: **No**
- Sexuality / Nudity: **No**
- Language / Profanity: **No**
- Controlled Substance: **No**
- Miscellaneous:
  - Can users share personal info? **No**
  - Does app share physical location? **No**
  - Can users purchase digital goods? **No**
- **Result:** You will be granted **PEGI 3 / Everyone (All ages)** rating.

### 5. Target Audience & Content
- Target age group: Check **13-15**, **16-17**, and **18 and over**.
  > [!TIP]
  > Selecting 13+ prevents your app from being classified under the strict "Designed for Families" / COPPA program, which requires specialized child privacy certifications.
- Could your store listing appeal to children? Select **"No"**.

### 6. News Apps
- Select: **"No, my app is not a news app"**.

### 7. COVID-19 Contact Tracing & Status
- Select: **"My app is not a publicly available COVID-19 contact tracing or status app"**.

### 8. Financial Features
- Select: **"My app does not provide financial features"**.

### 9. Government Apps
- Select: **"No, my app is not developed by or on behalf of a government"**.

---

## 5. Data Safety Form Answers

Google Play mandates the **Data safety** questionnaire:

1. **Does your app collect or share any user data?**
   - If using 100% offline mode: Select **"No"**.
   - If optional Firebase login (Email/Google) is active: Select **"Yes"**.
2. **Is all user data encrypted in transit?**
   - Select: **"Yes"** (Firebase uses HTTPS/TLS).
3. **Do you provide a way for users to request data deletion?**
   - Select: **"Yes"** (via support email).
4. **Data Types Collected (Only if account login is active):**
   - *Personal info > Name, Email address*: Used for **App functionality** & **Account management**.
   - Not shared with third parties.

---

## 6. Release & App Bundle (.aab) Upload

1. Go to **Release > Production** (or **Testing > Closed testing**).
2. Click **Create new release**.
3. Under **App bundles**, upload:
   ```
   cricket_scorer_app/build/app/outputs/bundle/release/app-release.aab
   ```
   - **Upload Size:** ~67.4 MB
   - **Download Size on User Phones:** ~16.4 MB (Google Play Dynamic Delivery)
4. **Release Name:**
   ```
   1.4.9 (32)
   ```
5. **Release Notes (What's new in this release?):**
```text
en-US
• Official release of 60Score Cricket Scorer!
• Offline-first ball-by-ball cricket scoring with Super Over engine.
• ICC standard Duckworth-Lewis-Stern (DLS) target calculator.
• Complete tournament manager with automated Points Table & Net Run Rate (NRR).
• Interactive Player Draft and Auction system with real-time budget tracking.
• Full scorecard editing and match statistics exports.
```

---

## 7. Privacy Policy & Legal Portal Hosting Guide

Google Play requires live public HTTPS URLs for your Privacy Policy and Data Deletion pages. We have built a complete, self-contained, responsive website located in the [`website/`](file:///c:/Users/Muhammad%20Aliyan/Desktop/crciketscoree/60score/website/) directory:

- 🏠 **Home / Landing:** `website/index.html`
- 🔒 **Privacy Policy:** `website/privacy-policy.html`
- 📜 **Terms of Service:** `website/terms-of-service.html`
- 🗑️ **Data Deletion Request:** `website/data-deletion.html`
- 📬 **Support & Contact:** `website/contact.html`

### Option A: Free Netlify Drop (Fastest — 30 Seconds, No Code)
1. Go to [app.netlify.com/drop](https://app.netlify.com/drop).
2. Drag and drop the `website/` folder into your browser.
3. You immediately get a live HTTPS URL (e.g. `https://60score.netlify.app/`).
4. Enter these into Google Play Console:
   - **Privacy Policy URL:** `https://<your-subdomain>.netlify.app/privacy-policy.html`
   - **Data Deletion URL:** `https://<your-subdomain>.netlify.app/data-deletion.html`

### Option B: Free GitHub Pages (Permanent)
1. In your GitHub repository, enable Pages under **Settings > Pages**.
2. Select `main` branch.
3. Your live link: `https://<username>.github.io/<repo>/website/privacy-policy.html`.

---

## 🔐 Credentials & Keystore Reference
For keystore passwords, alias, and certificate details, refer to:
👉 📄 [`docs/PLAY_CONSOLE_RELEASE_CREDENTIALS.md`](file:///c:/Users/Muhammad%20Aliyan/Desktop/crciketscoree/60score/docs/PLAY_CONSOLE_RELEASE_CREDENTIALS.md)
