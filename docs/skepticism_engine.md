# Skepticism Engine: Analysis & Decision Algorithms

The **Skepticism Engine** (`SkepticismEngine`) is the core analytical module of SpamCall. It parses speech transcriptions and text message contents to calculate a real-time risk index, pinpoint specific scam tactics, and flag behavior that violates official corporate and government protocols.

---

## ⚙️ Risk Score Calculation Algorithm

The engine calculates risk on a scale from **0% to 100%**. Risk is accumulated using three primary scanning layers:

$$\text{Risk Score} = \min\left(100, \text{Score}_{\text{Payments}} + \text{Score}_{\text{Patterns}} + \text{Score}_{\text{Contradictions}}\right)$$

### 1. Layer 1: Protected Payment Channel Detection ($\text{Score}_{\text{Payments}}$)
The engine scans for mentions of sensitive payment channels configured by the user in settings. Each match indicates that a payment vector is being targeted by the caller.
* **Weight**: $+15$ points per unique payment channel detected.
* **Payment Channels Tracked**:
  * **Bank Apps**: Matches "銀行app", "手機銀行", "bank app"
  * **Internet Banking**: Matches "網上銀行", "網銀", "e-banking", "internet banking"
  * **Visa/Credit Cards**: Matches "visa", "信用卡", "credit card"
  * **FPS (轉數快)**: Matches "轉數快", "fps", "快速支付"
  * **Octopus**: Matches "八達通", "octopus"
  * **Alipay**: Matches "支付寶", "alipay", "支寶"
  * **WeChat Pay**: Matches "微信支付", "wechat pay", "微信過數", "微訊"
  * **7-Eleven / Circle K**: Matches "7-11", "便利店", "circle k", "ok便利店"

### 2. Layer 2: Scam Pattern Keyword Matching ($\text{Score}_{\text{Patterns}}$)
The engine queries the database of known scam patterns compiled from warnings issued by the **Hong Kong Police Anti-Deception Coordination Centre (反詐騙協調中心)** and the **Consumer Council (消費者委員會)**.
* **Weight**: $+25$ points per matching keyword inside a pattern.
* **Tactics Tracked**:
  * **Asset Audits**: Keywords: "安全賬戶", "資產審查", "刑事案件", "凍結資金" (Typical fake security force scam)
  * **Subscription Cancellations**: Keywords: "客服", "開通服務", "收費", "取消訂閱", "驗證碼" (Typical fake Alipay/WeChat service scam)
  * **Customs/Courier Fines**: Keywords: "快遞", "包裹受阻", "海關", "罰款", "違禁品" (Typical fake courier scam)

### 3. Layer 3: Official Procedure Contradictions ($\text{Score}_{\text{Contradictions}}$)
This is the most critical detection layer. It stores rules about what official institutions **NEVER** ask users to do. If the engine detects that a caller is claiming to represent an institution and requests a forbidden action, it flags a severe protocol violation.
* **Weight**: $+60$ points per contradiction.
* **Severe Contradiction Rule Examples**:
  * **Hong Kong Police**: Forbidden action = "mail bank card or transfer funds to secure accounts". If the caller mentions "Police" and asks to "mail card" or "transfer funds", this rule triggers.
  * **Alipay Customer Service**: Forbidden action = "ask for verification code or transfer money to cancel services". If the caller mentions "Alipay" and asks to "provide code", this rule triggers.
  * **HSBC**: Forbidden action = "send links requesting your security code or full passwords".

---

## 🧠 Decision Processing Flow

```
                   [ Dialogue Transcript / SMS Input ]
                                   │
                                   ▼
                   ┌───────────────────────────────┐
                   │ Scan Protected Payment Terms  │ ──► +15 pts per match
                   └───────────────┬───────────────┘
                                   │
                                   ▼
                   ┌───────────────────────────────┐
                   │ Scan ADCC/Police Scam Pattern │ ──► +25 pts per keyword
                   └───────────────┬───────────────┘
                                   │
                                   ▼
                   ┌───────────────────────────────┐
                   │ Verify Institution Rules DB   │
                   │ (Police, Alipay, HSBC, etc.)  │
                   └───────────────┬───────────────┘
                                   │
                    Matches Forbidden Action?
                                   ├───► [Yes] ──► +60 pts & Speech TTS Warning
                                   └───► [No]  ──► Continue
                                   │
                                   ▼
                   ┌───────────────────────────────┐
                   │ Cap final score at 100%       │
                   │ Generate advice text array    │
                   └───────────────────────────────┘
```

---

## 🔊 Accessibility Speech warning Integration

When a contradiction occurs ($\text{Score}_{\text{Contradictions}} > 0$), the engine alerts the user through both visual UI banners and real-time audio:
* **Audio Alerts**: Utilizes Android's `TextToSpeech` API configured with a Cantonese voice engine (`Locale("zh", "HK")`) to speak warning text directly into the phone's audio output (e.g., *"香港警務處絕不會要求你郵寄銀行卡，請掛斷電話！"*).
* **Target Audience**: Designed specifically to protect elderly and visually impaired users who are highly targeted by imposter scam operators.
