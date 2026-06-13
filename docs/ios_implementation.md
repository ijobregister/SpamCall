# iOS Implementation Details

The iOS application is written in **Swift** targeting **iOS 17+**. It is structured using the **SwiftUI** declaration system and utilizes native iOS system extensions for call and message filtering.

---

## ⚙️ Apple Framework Extension Hooks

To maintain sandbox integrity, iOS delegates filtering to system extensions. SpamCall utilizes two main targets:

```
                  ┌────────────────────────────────────────┐
                  │            iOS Extension Hooks         │
                  └───────────────────┬────────────────────┘
                                      │
                 ┌────────────────────┴────────────────────┐
                 ▼                                         ▼
   ┌───────────────────────────┐             ┌───────────────────────────┐
   │    CallDirectoryExtension │             │   MessageFilterExtension  │
   │         (CallKit)         │             │      (IdentityLookup)     │
   └─────────────┬─────────────┘             └─────────────┬─────────────┘
                 │                                         │
        Injects sequential                        Categorizes SMS as Junk
        phone lists for blocking                  by parsing sender/body
```

### 1. Call Blocking Extension (`CallDirectoryHandler`)
Inherits from CallKit's `CXCallDirectoryProvider`.
* **Method**: `beginRequest(with context: CXCallDirectoryExtensionContext)`
* **Protocol Requirements**:
  1. Phone numbers must be represented as 64-bit integers (`CXCallDirectoryPhoneNumber`).
  2. Numbers must include the country code without any punctuation (e.g. `+852 9123 4567` becomes `85291234567`).
  3. All blocking and identification lists **must be added in ascending numerical order**. Adding out-of-order numbers causes the extension compilation request to fail.
* **APIs Used**:
  * Blocking: `context.addBlockingEntry(withNextSequentialPhoneNumber:)`
  * Identification Labeling: `context.addIdentificationEntry(withNextSequentialPhoneNumber:label:)` (e.g. labeling number `85261249901` as *"Reported Alipay Impersonator (ScamCall)"*).

### 2. Message Filter Extension (`MessageFilterExtension`)
Inherits from IdentityLookup's `ILMessageFilterProvider`.
* **Method**: `handle(_ queryRequest: ILMessageFilterQueryRequest, context: ILMessageFilterExtensionContext, completion: @escaping (ILMessageFilterQueryResponse) -> Void)`
* **Filter Evaluation**:
  1. Compares sender numbers against defaults or variables read via App Groups.
  2. Scrapes the text body for HK scam keywords (`"安全賬戶"`, `"資產審查"`, `"驗證碼"`, `"取消扣費"`, `"郵寄銀行卡"`).
  3. Uses `NSDataDetector` to extract links:
     ```swift
     private func containsLink(_ text: String) -> Bool {
         let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
         let matches = detector?.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
         return !(matches?.isEmpty ?? true)
     }
     ```
  4. Returns `ILMessageFilterAction.filter` to send the SMS to the system "Junk" category, or `.none` to route it to the inbox.

---

## 🎨 iOS Application Layout

The core container app is built using SwiftUI view structures mirroring the Android user experience:

* **`ScamCallApp.swift`**: Initializes the database container and runs layout configurations.
* **`LiveMonitorView.swift`**: Simulates call streams, tracks current warning alerts, and shows animated radar sweeps mapping spoofed locations.
* **`KnowledgeBaseView.swift`**: A view to add/edit rules and patterns.
* **`IncidentReportsView.swift`**: Details logging. Includes sharing controllers to export incidents as PDFs/TXTs.
* **`SettingsView.swift`**: Selects target speech translation languages, enables voice descriptions, and manages App Group user defaults.
