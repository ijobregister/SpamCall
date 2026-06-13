# SpamCall (防騙衛士 - GuardCall)

SpamCall (防騙衛士) is a comprehensive, dual-platform mobile security application designed to protect users in Hong Kong from fraudulent phone calls and SMS phishing attacks. 

By leveraging a Cantonese-core **Skepticism Engine**, local Room/SwiftData databases, and active system-level call and message blocking services, SpamCall provides real-time protection, automated phishing link interception, and a geolocation-tracking honeypot mechanism to log and report scammers.

---

## 📱 Platforms & Tech Stack

The project features native implementations for both **Android** and **iOS** to ensure deep integration with system call screening and messaging APIs:

| Feature / Detail | Android Application | iOS Application |
| :--- | :--- | :--- |
| **Language** | Kotlin | Swift |
| **UI Framework** | Jetpack Compose (Material 3) | SwiftUI |
| **Database** | Room SQLite Database | SQLite (SwiftData equivalent) |
| **Interception API** | `CallScreeningService` & `SmsReceiver` | `CallDirectoryHandler` & `MessageFilterExtension` |
| **Real-time Monitoring**| `LiveCallAccessibilityService` & Native `SpeechRecognizer` | Local Core Speech Transcription / Screen node scraping |

---

## 🌟 Key Features

1. **Active Blacklist Blocking**: Automatically rejects incoming calls matching database spam lists, logging the attempt silently to keep the user undisturbed yet informed.
2. **AI Skepticism Engine**: Real-time analysis of call transcripts and text messages using local heuristic matching for scam templates, keywords, and contradictions of official procedures (e.g., police asking for cash/cards).
3. **Phishing Link Interception**: Automatically blocks unverified URLs within incoming SMS messages.
4. **Honeypot IP-Tracker**: Prompts scammers (via SMS honeypot responses) to click security tracking consent links, capturing their IP address, geolocation, ISP carrier, and device user-agent details.
5. **Trusted Third-Party Release**: Enables a delegated guardian (e.g., family member) to remotely review and release blocked web links if flagged in error.
6. **Police Handover PDF/TXT Export**: Packages incident logs, call transcripts, and captured geolocation data into standardized handover reports ready for submission to the Hong Kong Police CyberSecurity and Technology Crime Bureau.

---

## 📂 Project Structure

```
├── app/                      # Android Native Application
│   ├── src/main/java/com/guardcall/app/
│   │   ├── data/             # Room Database configuration and entities
│   │   ├── engine/           # Skepticism Engine decision-making logic
│   │   ├── service/          # Android Services (CallScreening, Accessibility, SMS)
│   │   └── ui/               # Jetpack Compose UI (MainActivity, screens)
│   └── build.gradle.kts
│
├── ios/                      # iOS Native Application
│   ├── ScamCall/             # Xcode Project Sources (SwiftUI & Swift)
│   │   ├── AppDatabase.swift
│   │   ├── SkepticismEngine.swift
│   │   ├── LiveMonitorView.swift
│   │   ├── IncidentReportsView.swift
│   │   ├── MessageFilterExtension.swift
│   │   └── ...
│   └── generate_project.ps1
│
└── docs/                     # Comprehensive Project Documentation
    ├── architecture.md       # High-level architecture and honeypot design
    ├── skepticism_engine.md  # Rule engine matching & risk scoring algorithms
    ├── database_schema.md    # Local Room/SQLite entity definition and schemas
    ├── android_implementation.md # Android specific service configurations
    └── ios_implementation.md # iOS specific framework extensions
```

---

## 📖 Documentation Index

For in-depth details about specific components of the SpamCall app, please refer to the documents in the `docs/` directory:

- **[System Architecture](docs/architecture.md)**: Explore the dual-platform flow, communication interceptors, and how the honeypot geolocation tracking functions.
- **[Skepticism Engine](docs/skepticism_engine.md)**: Learn how dialogue templates, keyword matching, and official procedure contradictions are calculated into a dynamic risk index.
- **[Database Schemas](docs/database_schema.md)**: Review structural models for scam lists, contradiction tables, and call incident history records.
- **[Android Implementation](docs/android_implementation.md)**: Technical detail on Android system hooks, speech-to-text recognition, and overlay UI alerts.
- **[iOS Implementation](docs/ios_implementation.md)**: Technical detail on Swift call directory database building, SMS filter extensions, and SwiftUI.

---

## 🛠️ Getting Started & Setup

### Android Prerequisites
* Android Studio (Koala or later)
* Android SDK 35 (compileSdk) / SDK 29 minimum
* Gradle 8.x + JDK 17

### iOS Prerequisites
* macOS with Xcode 15+
* iOS 17.0+ targets
* PowerShell (to execute project generation scripts if needed on Windows/macOS)
