import Foundation
import SwiftData

@Model
final class ScamNumber {
    var id: String
    var phoneNumber: String
    var entityName: String
    var dateAdded: Date
    
    init(phoneNumber: String, entityName: String, dateAdded: Date = Date()) {
        self.id = UUID().uuidString
        self.phoneNumber = phoneNumber
        self.entityName = entityName
        self.dateAdded = dateAdded
    }
}

@Model
final class OfficialProcedure {
    var id: String
    var institution: String
    var forbiddenAction: String
    var warningText: String
    
    init(institution: String, forbiddenAction: String, warningText: String) {
        self.id = UUID().uuidString
        self.institution = institution
        self.forbiddenAction = forbiddenAction
        self.warningText = warningText
    }
}

@Model
final class ScamPattern {
    var id: String
    var source: String
    var keywords: String // Comma-separated list of keywords
    var advice: String
    
    init(source: String, keywords: String, advice: String) {
        self.id = UUID().uuidString
        self.source = source
        self.keywords = keywords
        self.advice = advice
    }
}

@Model
final class CallIncidentReport {
    var id: String
    var timestamp: Date
    var callerNumber: String
    var carrierLocation: String
    var riskScore: Int
    var dialogTranscript: String
    var linkIntercepted: String?
    var spammerIp: String?
    var spammerLocation: String?
    var spammerUa: String?
    var paymentMethodsTargeted: String?
    
    init(callerNumber: String, carrierLocation: String, riskScore: Int, dialogTranscript: String, linkIntercepted: String? = nil, spammerIp: String? = nil, spammerLocation: String? = nil, spammerUa: String? = nil, paymentMethodsTargeted: String? = nil) {
        self.id = UUID().uuidString
        self.timestamp = Date()
        self.callerNumber = callerNumber
        self.carrierLocation = carrierLocation
        self.riskScore = riskScore
        self.dialogTranscript = dialogTranscript
        self.linkIntercepted = linkIntercepted
        self.spammerIp = spammerIp
        self.spammerLocation = spammerLocation
        self.spammerUa = spammerUa
        self.paymentMethodsTargeted = paymentMethodsTargeted
    }
}

// Database initial state creator
@MainActor
struct AppDatabaseInitializer {
    static func prepopulate(modelContext: ModelContext) {
        // Only prepopulate if database is empty
        do {
            let fetchDescriptor = FetchDescriptor<ScamNumber>()
            let count = try modelContext.fetchCount(fetchDescriptor)
            guard count == 0 else { return }
            
            // 1. Blacklist Numbers
            modelContext.insert(ScamNumber(phoneNumber: "+852 6124 9901", entityName: "Reported Alipay Impersonator"))
            modelContext.insert(ScamNumber(phoneNumber: "+852 9123 4567", entityName: "Suspected Phishing SMS Sender"))
            modelContext.insert(ScamNumber(phoneNumber: "+852 5678 1234", entityName: "Fake HK Police Fraud Unit"))
            
            // 2. HK Official Procedures
            modelContext.insert(OfficialProcedure(
                institution: "Hong Kong Police (香港警務處)",
                forbiddenAction: "mail bank card or transfer funds to secure accounts",
                warningText: "🚨 警務處絕不會要求你郵寄銀行卡或轉賬。請拒絕要求並掛斷電話！"
            ))
            modelContext.insert(OfficialProcedure(
                institution: "Alipay Customer Service (支付寶客服)",
                forbiddenAction: "ask for verification code or transfer money to cancel services",
                warningText: "🚨 支付寶客服絕不會索要驗證碼或要求私下轉賬。小心賬戶被盜用！"
            ))
            modelContext.insert(OfficialProcedure(
                institution: "HSBC (滙豐銀行)",
                forbiddenAction: "send links requesting your security code or full passwords",
                warningText: "🚨 滙豐不會發送鏈接要求輸入密碼或安全編碼。切勿點擊鏈接！"
            ))
            
            // 3. News & Police Scam Patterns
            modelContext.insert(ScamPattern(
                source: "Anti-Deception Coordination Centre (反詐騙協調中心)",
                keywords: "安全賬戶,郵寄,資產審查,刑事案件,凍結資金",
                advice: "提及「資金審查」或要求「郵寄銀行卡」為典型假冒公安詐騙手法。"
            ))
            modelContext.insert(ScamPattern(
                source: "HK Police Anti-Deception Alert",
                keywords: "客服,開通服務,收費,取消訂閱,驗證碼",
                advice: "以「取消扣費服務」為由索要驗證碼，是盜取支付寶/信用卡憑證的手法。"
            ))
            modelContext.insert(ScamPattern(
                source: "Consumer Council Warning (消費者委員會)",
                keywords: "快遞,包裹受阻,海關,罰款,違禁品",
                advice: "假冒快遞客服稱郵包有違禁品，要求配合公安調查並轉賬，是常見套路。"
            ))
            
            // 4. Sample Report
            let mockTranscript = """
            [{"speaker":"Spammer","text":"你好，我係支付寶客服。系統檢測到你嘅賬戶有異常扣費，請配合作資產審查。"},
             {"speaker":"Receiver","text":"我冇用過你哋個扣費服務喎。"},
             {"speaker":"Spammer","text":"你要即刻郵寄你張銀行卡去反詐中心，或者轉賬去我哋個安全賬戶先可以取消扣費。"}]
            """
            modelContext.insert(CallIncidentReport(
                callerNumber: "+852 6124 9901",
                carrierLocation: "Kowloon City, HK",
                riskScore: 92,
                dialogTranscript: mockTranscript,
                linkIntercepted: "https://scam-verify-alipay.com",
                spammerIp: "42.200.180.12",
                spammerLocation: "Sham Shui Po, Hong Kong",
                spammerUa: "Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X)",
                paymentMethodsTargeted: "Alipay, Bank Apps"
            ))
            
            try modelContext.save()
        } catch {
            print("Failed to prepopulate database: \(error.localizedDescription)")
        }
    }
}
