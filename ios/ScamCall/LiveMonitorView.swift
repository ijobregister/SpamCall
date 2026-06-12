import SwiftUI
import SwiftData
import AVFoundation

struct TranscriptItem: Identifiable, Codable {
    var id = UUID()
    let speaker: String
    let text: String
    let timestamp: Date
}

struct LiveMonitorView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var procedures: [OfficialProcedure]
    @Query private var patterns: [ScamPattern]
    
    // State Variables
    @State private var liveTranscript: [TranscriptItem] = []
    @State private var liveRiskScore: Int = 0
    @State private var liveAdvice: String = "Ready. Waiting for call simulation..."
    @State private var activeWarningBanner: String? = nil
    @State private var isCallActive = false
    @State private var activeCallerNumber = ""
    @State private var activeCallerName = ""
    @State private var isSmsMode = false
    @State private var smsBodyText = ""
    @State private var smsLinkUrl = ""
    @State private var isLinkBlocked = false
    @State private var isLinkApprovedByThirdParty = false
    @State private var showLinkReleaseRequest = false
    @State private var currentIncidentReportId: String? = nil
    @State private var detectedPaymentsThisSession: Set<String> = []
    
    // Honeypot Tracker details
    @State private var spammerIpAddress = ""
    @State private var spammerGeographicalLoc = ""
    @State private var spammerIspCarrier = ""
    @State private var spammerDeviceUserAgent = ""
    
    // UI Visual states
    @State private var radarAngle: Double = 0.0
    @State private var toastMessage: String? = nil
    
    private let speechSynthesizer = AVSpeechSynthesizer()
    private let skepticismEngine = SkepticismEngine()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 1. Scenario Simulation Panel
                VStack(alignment: .leading, spacing: 8) {
                    Text("模擬詐騙場景")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    HStack(spacing: 8) {
                        Button(action: { triggerSimulatedCall(scenario: "alipay_scam") }) {
                            Text("支付寶客服")
                                .font(.system(size: 13, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.green.opacity(0.8))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        
                        Button(action: { triggerSimulatedCall(scenario: "police_scam") }) {
                            Text("香港警察")
                                .font(.system(size: 13, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.red.opacity(0.8))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        
                        Button(action: { triggerSimulatedSMS() }) {
                            Text("匯豐短訊")
                                .font(.system(size: 13, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.blue.opacity(0.8))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                }
                .padding()
                .background(Color(white: 0.12))
                .cornerRadius(12)
                
                // 2. Active Warning Banner
                if let warning = activeWarningBanner {
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.white)
                            .font(.title2)
                        
                        Text(warning)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.leading)
                        
                        Spacer()
                    }
                    .padding()
                    .background(Color.red)
                    .cornerRadius(8)
                    .transition(.slide.combined(with: .opacity))
                }
                
                // 3. Dialogue Transcript Panel
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("對話實時轉錄")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        if isCallActive {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 8, height: 8)
                                Text("實時分析中")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    
                    Divider().background(Color.gray)
                    
                    if liveTranscript.isEmpty {
                        Text("暫無通話記錄。請選擇上方場景開始模擬通話攔截檢測。")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 32)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(liveTranscript) { item in
                                let isSpammer = item.speaker == "Spammer" || item.speaker == "騙徒"
                                HStack {
                                    if !isSpammer { Spacer() }
                                    
                                    Text("\(isSpammer ? "騙徒" : "受話人"): \(item.text)")
                                        .font(.system(size: 13))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 10)
                                        .background(isSpammer ? Color(white: 0.2) : Color.red.opacity(0.8))
                                        .cornerRadius(8)
                                    
                                    if isSpammer { Spacer() }
                                }
                            }
                        }
                    }
                }
                .padding()
                .background(Color(white: 0.12))
                .cornerRadius(12)
                
                // 4. Risk & Skepticism Index
                VStack(alignment: .leading, spacing: 12) {
                    Text("AI 懷疑指數")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    HStack(alignment: .bottom) {
                        Text("\(liveRiskScore)%")
                            .font(.system(size: 36, weight: .black))
                            .foregroundColor(riskColor)
                        
                        Spacer()
                        
                        Text(riskText)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.gray)
                    }
                    
                    ProgressView(value: Double(liveRiskScore), total: 100.0)
                        .accentColor(riskColor)
                        .scaleEffect(x: 1, y: 1.5, anchor: .center)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("分析邏輯：")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                        Text(liveAdvice)
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 4)
                }
                .padding()
                .background(Color(white: 0.12))
                .cornerRadius(12)
                
                // 5. Geolocation Radar Simulation
                if isCallActive && !spammerIpAddress.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("誘餌 IP 追蹤器已啟動")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("IP: \(spammerIpAddress)")
                                    .font(.system(.subheadline, design: .monospaced))
                                    .foregroundColor(.red)
                                Text("預計位置: \(spammerGeographicalLoc)")
                                    .font(.system(size: 13))
                                    .foregroundColor(.white)
                                Text("營運商: \(spammerIspCarrier)")
                                    .font(.system(size: 13))
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                            
                            // Visual Radar sweep
                            ZStack {
                                Circle()
                                    .stroke(Color.green.opacity(0.3), lineWidth: 1)
                                Circle()
                                    .stroke(Color.green.opacity(0.3), lineWidth: 1)
                                    .frame(width: 50, height: 50)
                                
                                // Sweep Line
                                GeometryReader { geo in
                                    Path { path in
                                        path.move(to: CGPoint(x: geo.size.width/2, y: geo.size.height/2))
                                        path.addLine(to: CGPoint(x: geo.size.width/2 + cos(radarAngle * .pi / 180) * geo.size.width/2,
                                                                 y: geo.size.height/2 + sin(radarAngle * .pi / 180) * geo.size.height/2))
                                    }
                                    .stroke(Color.green, lineWidth: 2)
                                }
                                
                                // Target dot
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 8, height: 8)
                                    .offset(x: 20, y: -20)
                            }
                            .frame(width: 90, height: 90)
                            .background(Color.black.cornerRadius(45))
                            .onAppear {
                                withAnimation(Animation.linear(duration: 3.0).repeatForever(autoreverses: false)) {
                                    radarAngle = 360
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(white: 0.12))
                    .cornerRadius(12)
                }
                
                // 6. Link Intercept Box
                if isSmsMode && showLinkReleaseRequest {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("偵測到釣魚連結！")
                            .font(.headline)
                            .foregroundColor(.red)
                        
                        Text("網域: \(smsLinkUrl)")
                            .font(.system(size: 13))
                            .foregroundColor(.white)
                        
                        Text("已鎖定。正等待受信任聯絡人 (Gabriel) 或遠程點擊批准。")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                        
                        HStack(spacing: 8) {
                            Button(action: { respondToRelease(approved: false) }) {
                                Text("拒絕")
                                    .font(.system(size: 13, weight: .bold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Color.gray.opacity(0.3))
                                    .foregroundColor(.white)
                                    .cornerRadius(6)
                            }
                            
                            Button(action: { respondToRelease(approved: true) }) {
                                Text("批准並釋放")
                                    .font(.system(size: 13, weight: .bold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Color.green)
                                    .foregroundColor(.white)
                                    .cornerRadius(6)
                            }
                        }
                    }
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.red, lineWidth: 1)
                    )
                }
                
                // 7. End Call Button
                if isCallActive || isSmsMode {
                    Button(action: { hangupActiveSession() }) {
                        Text("結束模擬 / 掛斷")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .padding(.top, 8)
                }
            }
            .padding()
        }
        .background(Color.black.edgesIgnoringSafeArea(.all))
        .overlay(
            Group {
                if let msg = toastMessage {
                    VStack {
                        Spacer()
                        Text(msg)
                            .font(.system(size: 13))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color(white: 0.2))
                            .cornerRadius(20)
                            .shadow(radius: 5)
                            .padding(.bottom, 64)
                    }
                    .transition(.opacity)
                }
            }
        )
    }
    
    // UI Helper Variables
    private var riskColor: Color {
        if liveRiskScore > 75 { return .red }
        else if liveRiskScore > 40 { return .yellow }
        return .green
    }
    
    private var riskText: String {
        if liveRiskScore > 75 { return "偵測到嚴重詐騙風險" }
        else if liveRiskScore > 40 { return "對話內容可疑" }
        return "通話安全"
    }
    
    // Actions & Simulators
    private func triggerSimulatedCall(scenario: String) {
        hangupActiveSession()
        isCallActive = true
        detectedPaymentsThisSession.removeAll()
        
        let prefs = UserDefaults.standard
        let isVoiceAlertEnabled = prefs.bool(forKey: "voice_alert_enabled")
        
        if scenario == "alipay_scam" {
            activeCallerNumber = "+852 6124 9901"
            activeCallerName = "Unknown Mobile Number"
            
            // Simulating dialogue events
            liveTranscript.append(TranscriptItem(speaker: "Spammer", text: "你好，我係支付寶客服。系統檢測到你個賬戶有異常轉賬，需要立即處理。", timestamp: Date()))
            liveRiskScore = 35
            liveAdvice = "Matching introductory greeting phrases..."
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                guard isCallActive else { return }
                liveTranscript.append(TranscriptItem(speaker: "Receiver", text: "我今日冇做過轉賬喎，咩事？", timestamp: Date()))
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    guard isCallActive else { return }
                    liveTranscript.append(TranscriptItem(speaker: "Spammer", text: "為咗確保資金安全，你需要向我哋個安全賬戶做資產審查轉賬，或者提供你張卡嘅驗證碼。", timestamp: Date()))
                    
                    // Run skepticism check
                    let result = skepticismEngine.analyzeDialogue(
                        text: "為咗確保資金安全，你需要向我哋個安全賬戶做資產審查轉賬，或者提供你張卡嘅驗證碼。",
                        procedures: procedures,
                        patterns: patterns
                    )
                    
                    liveRiskScore = result.riskScore
                    activeWarningBanner = result.warningText
                    liveAdvice = "CRITICAL MATCH: Alipay official procedures state they will NEVER ask for verification codes or transfers. This is a scam!"
                    
                    detectedPaymentsThisSession.formUnion(result.detectedPayments)
                    
                    if let warning = result.warningText, isVoiceAlertEnabled {
                        speakTTS(warning)
                    }
                    
                    spammerIpAddress = "42.200.180.12"
                    spammerGeographicalLoc = "Sham Shui Po, Hong Kong"
                    spammerIspCarrier = "China Mobile Hong Kong"
                    spammerDeviceUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X)"
                }
            }
        } else if scenario == "police_scam" {
            activeCallerNumber = "+852 5678 1234"
            activeCallerName = "Fake HK Police Fraud Unit"
            
            liveTranscript.append(TranscriptItem(speaker: "Spammer", text: "你好，呢度係香港警務處反詐騙小組。你涉嫌參與一宗跨境刑事洗錢案。", timestamp: Date()))
            liveRiskScore = 40
            liveAdvice = "Matching legal/police keywords..."
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                guard isCallActive else { return }
                liveTranscript.append(TranscriptItem(speaker: "Receiver", text: "啊？我點會參與洗錢案？", timestamp: Date()))
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    guard isCallActive else { return }
                    liveTranscript.append(TranscriptItem(speaker: "Spammer", text: "依家法庭要求你將你嘅實體銀行卡，用快遞郵寄黎我哋反詐中心進行清查。", timestamp: Date()))
                    
                    let result = skepticismEngine.analyzeDialogue(
                        text: "依家法庭要求你將你嘅實體銀行卡，用快遞郵寄黎我哋反詐中心進行清查。",
                        procedures: procedures,
                        patterns: patterns
                    )
                    
                    liveRiskScore = result.riskScore
                    activeWarningBanner = result.warningText
                    liveAdvice = "CRITICAL MATCH: Police never ask you to mail physical bank cards! Hand card over or mail requests are 100% scam."
                    
                    detectedPaymentsThisSession.formUnion(result.detectedPayments)
                    
                    if let warning = result.warningText, isVoiceAlertEnabled {
                        speakTTS(warning)
                    }
                    
                    spammerIpAddress = "202.40.137.9"
                    spammerGeographicalLoc = "Mong Kok, Hong Kong"
                    spammerIspCarrier = "HKT Netvigator"
                    spammerDeviceUserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/120.0.0"
                }
            }
        }
    }
    
    private func triggerSimulatedSMS() {
        hangupActiveSession()
        isSmsMode = true
        activeCallerNumber = "+852 9123 4567"
        smsBodyText = "Dear customer, abnormal transactions were detected. Please click the link to verify: "
        smsLinkUrl = "https://scam-verify-alipay.com"
        isLinkBlocked = true
        showLinkReleaseRequest = true
        liveRiskScore = 80
        liveAdvice = "SMS contains unverified link. Automatically intercepting domain click routing."
        detectedPaymentsThisSession = ["Alipay"]
    }
    
    private func respondToRelease(approved: Bool) {
        showLinkReleaseRequest = false
        if approved {
            isLinkApprovedByThirdParty = true
            isLinkBlocked = false
            showToast("Link Released by Trusted Third Party!")
        } else {
            isLinkApprovedByThirdParty = false
            showToast("Link Blocked Permanently.")
        }
    }
    
    private func hangupActiveSession() {
        if isCallActive || isSmsMode {
            // Write incident report to Database
            let transcriptText: String
            if isSmsMode {
                transcriptText = "[SMS Received]: \(smsBodyText) \(smsLinkUrl)"
            } else {
                let encodedData = try? JSONEncoder().encode(liveTranscript)
                transcriptText = String(data: encodedData ?? Data(), encoding: .utf8) ?? "Empty Transcript"
            }
            
            let paymentsStr = detectedPaymentsThisSession.isEmpty ? nil : detectedPaymentsThisSession.joined(separator: ", ")
            
            let newReport = CallIncidentReport(
                callerNumber: activeCallerNumber,
                carrierLocation: isSmsMode ? "SMS Network Carrier" : "Kowloon City, HK",
                riskScore: liveRiskScore,
                dialogTranscript: transcriptText,
                linkIntercepted: isSmsMode ? smsLinkUrl : nil,
                spammerIp: spammerIpAddress.isEmpty ? nil : spammerIpAddress,
                spammerLocation: spammerGeographicalLoc.isEmpty ? nil : spammerGeographicalLoc,
                spammerUa: spammerDeviceUserAgent.isEmpty ? nil : spammerDeviceUserAgent,
                paymentMethodsTargeted: paymentsStr
            )
            
            modelContext.insert(newReport)
            try? modelContext.save()
        }
        
        isCallActive = false
        isSmsMode = false
        liveTranscript.removeAll()
        liveRiskScore = 0
        liveAdvice = "Ready. Waiting for call simulation..."
        activeWarningBanner = nil
        spammerIpAddress = ""
        spammerGeographicalLoc = ""
        spammerIspCarrier = ""
        spammerDeviceUserAgent = ""
        showLinkReleaseRequest = false
        currentIncidentReportId = nil
        detectedPaymentsThisSession.removeAll()
    }
    
    private func speakTTS(_ message: String) {
        let utterance = AVSpeechUtterance(string: message)
        let langCode = UserDefaults.standard.string(forKey: "speech_language_code") ?? "zh-HK"
        utterance.voice = AVSpeechSynthesisVoice(language: langCode)
        speechSynthesizer.speak(utterance)
    }
    
    private func showToast(_ message: String) {
        toastMessage = message
        DispatchQueue.main.onQueueIfNeeded {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                if toastMessage == message {
                    toastMessage = nil
                }
            }
        }
    }
}

// Thread safety extension
extension DispatchQueue {
    func onQueueIfNeeded(_ block: @escaping () -> Void) {
        if self == DispatchQueue.main && Thread.isMainThread {
            block()
        } else {
            self.async(execute: block)
        }
    }
}
