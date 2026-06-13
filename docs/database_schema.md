# Local Database Schema Guide

SpamCall maintains local storage to support quick offline matches of blacklisted numbers, offline rule evaluations, and detailed history logging for police handovers. The Android implementation uses **Room SQL Database** (Version 2) and iOS uses **SQLite / SwiftData**.

---

## 📊 Entity Definitions

The database contains four tables:

```
┌────────────────────────────────────────────────────────┐
│                        AppDatabase                     │
├───────────────────┬────────────────────────────────────┤
│ Table Name        │ Description                        │
├───────────────────┼────────────────────────────────────┤
│ scam_numbers      │ Blacklist of verified spam numbers │
│ official_rules    │ Contradiction checking procedures  │
│ scam_patterns     │ Police warning keywords & advice   │
│ incident_reports  │ Call/SMS intercepts & tracking log │
└───────────────────┴────────────────────────────────────┘
```

### 1. `scam_numbers` (Spam Blacklist)
Stores numbers flagged as malicious. When incoming calls or SMS arrive from these numbers, the app automatically triggers blocking actions.

| Field Name | Data Type | Key / Constraint | Description |
| :--- | :--- | :--- | :--- |
| `id` | `INTEGER` | Primary Key, Auto-Gen | Unique record identifier |
| `phone_number` | `TEXT` | Non-Null | Normalized E.164 phone string (e.g., `+85261249901`) |
| `entity_name` | `TEXT` | Non-Null | Descriptive label/category (e.g., "Alipay Impersonator") |
| `date_added` | `INTEGER` | Default: Current MS | Epoch millisecond timestamp of insertion |

### 2. `official_procedures` (Contradiction Check Database)
Defines behaviors that legitimate organizations will **never** perform. This is queried by the `SkepticismEngine` to find contradictions in dialogue.

| Field Name | Data Type | Key / Constraint | Description |
| :--- | :--- | :--- | :--- |
| `id` | `INTEGER` | Primary Key, Auto-Gen | Unique record identifier |
| `institution` | `TEXT` | Non-Null | Name of organization (e.g., "Hong Kong Police (香港警務處)") |
| `forbidden_action` | `TEXT` | Non-Null | Semantic forbidden action pattern (e.g., "mail bank card") |
| `warning_text` | `TEXT` | Non-Null | Alert text displayed/spoken if a contradiction occurs |

### 3. `scam_patterns` (Keyword Alert Definitions)
Contains keywords collected from public warning campaigns (like the HK Anti-Deception Coordination Centre alerts).

| Field Name | Data Type | Key / Constraint | Description |
| :--- | :--- | :--- | :--- |
| `id` | `INTEGER` | Primary Key, Auto-Gen | Unique record identifier |
| `source` | `TEXT` | Non-Null | Public warning source (e.g., "Anti-Deception Coordination Centre") |
| `keywords` | `TEXT` | Non-Null | Comma-separated search words (e.g., "安全賬戶,郵寄,資產審查") |
| `advice` | `TEXT` | Non-Null | Defensive advice to offer when keywords match |

### 4. `call_incident_reports` (Incident History & Tracking Logs)
Maintains logs of blocked or screened calls and SMS. This table also captures details grabbed by the honeypot geolocation system.

| Field Name | Data Type | Key / Constraint | Description |
| :--- | :--- | :--- | :--- |
| `id` | `INTEGER` | Primary Key, Auto-Gen | Unique record identifier |
| `timestamp` | `INTEGER` | Default: Current MS | Epoch millisecond timestamp of incident |
| `caller_number` | `TEXT` | Non-Null | Number of caller or SMS sender |
| `carrier_location` | `TEXT` | Non-Null | Network geolocated entry carrier location |
| `risk_score` | `INTEGER` | Non-Null | Calculated engine risk index (0 - 100) |
| `dialog_transcript`| `TEXT` | Non-Null | Plain text or JSON array of dialogue exchanges |
| `link_intercepted` | `TEXT` | Nullable | Phishing URL extracted from intercepted message |
| `spammer_ip` | `TEXT` | Nullable | Geolocation IP address captured via honeypot consent page |
| `spammer_location` | `TEXT` | Nullable | Estimated geographical location of spammer (city/district) |
| `spammer_ua` | `TEXT` | Nullable | Browser User-Agent details of the clicking device |
| `payment_methods` | `TEXT` | Nullable | Comma-separated list of targeted payment channels |

---

## 🌱 Initial Database Seed Data

Upon database creation, SpamCall prepopulates several default rules and patterns specifically targeting trends in Hong Kong:

### Pre-seeded Blacklist
* `+852 6124 9901` (Reported Alipay Impersonator)
* `+852 9123 4567` (Suspected Phishing SMS Sender)
* `+852 5678 1234` (Fake HK Police Fraud Unit)

### Pre-seeded Official Procedures
1. **Hong Kong Police (香港警務處)**:
   * *Forbidden Action*: "mail bank card or transfer funds to secure accounts"
   * *Warning Alert*: `🚨 警務處絕不會要求你郵寄銀行卡或轉賬。請拒絕要求並掛斷電話！`
2. **Alipay Customer Service (支付寶客服)**:
   * *Forbidden Action*: "ask for verification code or transfer money to cancel services"
   * *Warning Alert*: `🚨 支付寶客服絕不會索要驗證碼或要求私下轉賬。小心賬戶被盜用！`
3. **HSBC (滙豐銀行)**:
   * *Forbidden Action*: "send links requesting your security code or full passwords"
   * *Warning Alert*: `🚨 滙豐不會發送鏈接要求輸入密碼或安全編碼。切勿點擊鏈接！`

### Pre-seeded Scam Patterns
* **Anti-Deception Coordination Centre (反詐騙協調中心)**:
   * *Keywords*: "安全賬戶,郵寄,資產審查,刑事案件,凍結資金"
   * *Advice*: `提及「資金審查」或要求「郵寄銀行卡」為典型假冒公安詐騙手法。`
* **HK Police Anti-Deception Alert**:
   * *Keywords*: "客服,開通服務,收費,取消訂閱,驗證碼"
   * *Advice*: `以「取消扣費服務」為由索要驗證碼，是盜取支付寶/信用卡憑證的手法。`
* **Consumer Council Warning (消費者委員會)**:
   * *Keywords*: "快遞,包裹受阻,海關,罰款,違禁品"
   * *Advice*: `假冒快遞客服稱郵包有違禁品，要求配合公安調查並轉賬，是常見套路。`
