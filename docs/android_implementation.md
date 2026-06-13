# Android Implementation details

The Android application is written in **Kotlin** and targets **SDK 35 (Android 15)**. It uses modern jetpack frameworks, including Jetpack Compose for the UI and Room for database management.

---

## ⚙️ Core System Service Hooks

Android restricts background activities to maintain user privacy. SpamCall relies on three system services to intercept calls, text messages, and dialogue transcripts.

```
                  ┌────────────────────────────────────────┐
                  │          Android System Hooks          │
                  └───────────────────┬────────────────────┘
                                      │
         ┌────────────────────────────┼───────────────────────────┐
         ▼                            ▼                           ▼
┌─────────────────┐          ┌─────────────────┐         ┌─────────────────┐
│  CallScreening  │          │   SmsReceiver   │         │  Accessibility  │
│     Service     │          │  (Broadcast)    │         │     Service     │
└────────┬────────┘          └────────┬────────┘         └────────┬────────┘
         │                            │                           │
  Blocks blacklisted           Extracts links,             Transcribes audio,
  numbers, runs overlays       sends honeypot reply        scrapes screen nodes
```

### 1. Call Interceptor (`CallScreeningServiceImpl`)
Extends Android's system `CallScreeningService`.
* **API Entry**: `onScreenCall(callDetails: Call.Details)`
* **Logic**:
  1. Checks if the direction is `DIRECTION_INCOMING`.
  2. Extracts the phone number from `callDetails.handle.schemeSpecificPart`.
  3. Queries the database off-thread using Coroutine scopes.
  4. If a match is found in the blacklist:
     * Disallows the call (`response.setDisallowCall(true)`).
     * Rejects the connection (`response.setRejectCall(true)`).
     * Skips standard notification banners (`response.setSkipNotification(true)`).
     * Passes a broadcast intent (`com.guardcall.app.SHOW_CALL_ALERT`) to launch custom system-level warnings.
  5. If the caller is an unknown international number (not starting with `+852`), it triggers a warning broadcast without blocking.

### 2. Live Dialogue Monitor (`LiveCallAccessibilityService`)
This service uses dual strategies to capture call audio/text:
* **Audio Speech-to-Text**: If active call audio transcription is started (triggered via `START_REAL_TIME_TRANSCRIPTION` intent actions), it instantiates an Android `SpeechRecognizer` targeting `zh-HK` (Cantonese) or user-configured locales. Transcription pieces are evaluated by the `SkepticismEngine`.
* **Screen Scraping**: For systems that natively transcribe call dialogues on the dialing interface, the service traverses the active window node hierarchy recursively:
  ```kotlin
  private fun findSuspiciousTextInNodes(node: AccessibilityNodeInfo) {
      val text = node.text?.toString() ?: ""
      if (text.isNotEmpty() && text.length > 5) {
          val analysis = skepticismEngine.analyzeDialogue(this, text)
          if (analysis.riskScore > 50) broadcastSkepticismAlert(analysis)
      }
      for (i in 0 until node.childCount) {
          node.getChild(i)?.let { findSuspiciousTextInNodes(it) }
      }
  }
  ```

### 3. Text Message Interception (`SmsReceiver`)
A standard subclass of `BroadcastReceiver` registered for `android.provider.Telephony.Sms.Intents.SMS_RECEIVED_ACTION`.
* **Link Scanning**: Uses regex matching to scan the body text for URLs.
* **Incident Creation**: Saves SMS details, logs a risk rating of `85%`, and triggers alerts.
* **Active Defense Honeypot**: Sends an automated SMS response containing the honeypot location tracking link to the sender using the `SmsManager` API.

---

## 🎨 User Interface & Exporter Details

The UI is built with Jetpack Compose (`MainActivity.kt`) following dark-mode aesthetics:

* **Tab 1: Live Monitor (實時監控)**: Houses simulators to test Alipay, Police, and HSBC fraud scenarios. Displays real-time Cantonese transcripts, progress bars showing the calculated AI suspicion index, and a simulated geolocation radar detailing the tracked IP address.
* **Tab 2: Knowledge Base (知識庫)**: Provides editors for blacklist numbers, official corporate rules, and warnings.
* **Tab 3: Incident Reports (事件報告)**: Provides logs of call transcripts.
* **Tab 4: Settings (設置)**: Manages preferences stored in `GuardCallPrefs` (speech locales, protected payments list, regional policies).

### Handover Package PDF Generation
The app features native PDF compiling using Android's `PdfDocument` API. It outputs a formatted A4 page layout (`595x842` scale) containing:
1. Incident headers and geocoded locations.
2. Targeted payment channels and captured tracker IPs.
3. Character-wrapped dialog transcripts parsed line-by-line.
4. Saving target: `Environment.DIRECTORY_DOWNLOADS`.
