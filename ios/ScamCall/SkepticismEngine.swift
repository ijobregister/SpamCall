import Foundation

class SkepticismEngine {
    
    struct AnalysisResult {
        let riskScore: Int
        let advice: String
        let contradictionFound: String?
        let warningText: String?
        let detectedPayments: [String]
    }
    
    func analyzeDialogue(text: String, procedures: [OfficialProcedure], patterns: [ScamPattern]) -> AnalysisResult {
        var calculatedRisk = 0
        var advices: [String] = []
        var contradiction: String? = nil
        var warningText: String? = nil
        
        // 1. Detect protected payment methods
        var detectedPayments: [String] = []
        let defaults = UserDefaults.standard
        
        let checkBankApps = defaults.object(forKey: "protect_bank_apps") == nil ? true : defaults.bool(forKey: "protect_bank_apps")
        let checkInternetBanking = defaults.object(forKey: "protect_internet_banking") == nil ? true : defaults.bool(forKey: "protect_internet_banking")
        let checkVisa = defaults.object(forKey: "protect_visa") == nil ? true : defaults.bool(forKey: "protect_visa")
        let checkFps = defaults.object(forKey: "protect_fps") == nil ? true : defaults.bool(forKey: "protect_fps")
        let checkOctopus = defaults.object(forKey: "protect_octopus") == nil ? true : defaults.bool(forKey: "protect_octopus")
        let checkAlipay = defaults.object(forKey: "protect_alipay") == nil ? true : defaults.bool(forKey: "protect_alipay")
        let checkWeChatPay = defaults.object(forKey: "protect_wechat_pay") == nil ? true : defaults.bool(forKey: "protect_wechat_pay")
        let check7Eleven = defaults.object(forKey: "protect_7_eleven") == nil ? true : defaults.bool(forKey: "protect_7_eleven")
        let checkCircleK = defaults.object(forKey: "protect_circle_k") == nil ? true : defaults.bool(forKey: "protect_circle_k")
        
        if checkBankApps && (text.localizedCaseInsensitiveContains("銀行app") || text.localizedCaseInsensitiveContains("手機銀行") || text.localizedCaseInsensitiveContains("bank app")) {
            detectedPayments.append("Bank Apps")
        }
        if checkInternetBanking && (text.localizedCaseInsensitiveContains("網上銀行") || text.localizedCaseInsensitiveContains("網銀") || text.localizedCaseInsensitiveContains("e-banking") || text.localizedCaseInsensitiveContains("internet banking")) {
            detectedPayments.append("Internet Banking")
        }
        if checkVisa && (text.localizedCaseInsensitiveContains("visa") || text.localizedCaseInsensitiveContains("信用卡") || text.localizedCaseInsensitiveContains("credit card")) {
            detectedPayments.append("Visa")
        }
        if checkFps && (text.localizedCaseInsensitiveContains("轉數快") || text.localizedCaseInsensitiveContains("fps") || text.localizedCaseInsensitiveContains("快速支付")) {
            detectedPayments.append("FPS")
        }
        if checkOctopus && (text.localizedCaseInsensitiveContains("八達通") || text.localizedCaseInsensitiveContains("octopus")) {
            detectedPayments.append("Octopus")
        }
        if checkAlipay && (text.localizedCaseInsensitiveContains("支付寶") || text.localizedCaseInsensitiveContains("alipay") || text.localizedCaseInsensitiveContains("支寶")) {
            detectedPayments.append("Alipay")
        }
        if checkWeChatPay && (text.localizedCaseInsensitiveContains("微信支付") || text.localizedCaseInsensitiveContains("wechat pay") || text.localizedCaseInsensitiveContains("微信過數") || text.localizedCaseInsensitiveContains("微訊")) {
            detectedPayments.append("WeChat Pay")
        }
        if check7Eleven && (text.localizedCaseInsensitiveContains("7-11") || text.localizedCaseInsensitiveContains("7-eleven") || text.localizedCaseInsensitiveContains("便利店") || text.localizedCaseInsensitiveContains("七十一")) {
            detectedPayments.append("7-Eleven")
        }
        if checkCircleK && (text.localizedCaseInsensitiveContains("circle k") || text.localizedCaseInsensitiveContains("ok便利店") || text.localizedCaseInsensitiveContains("ok 點") || text.localizedCaseInsensitiveContains("ok便利")) {
            detectedPayments.append("Circle K")
        }
        
        if !detectedPayments.isEmpty {
            calculatedRisk += 15 * detectedPayments.count
            advices.append("Payment Channel Threatened: \(detectedPayments.joined(separator: ", "))")
        }
        
        // 2. Scan for Scam Patterns / Keywords
        for pattern in patterns {
            let keywordsList = pattern.keywords.components(separatedBy: ",")
            var matchCount = 0
            for kw in keywordsList {
                let trimmed = kw.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty && text.localizedCaseInsensitiveContains(trimmed) {
                    matchCount += 1
                }
            }
            
            if matchCount > 0 {
                calculatedRisk += 25 * matchCount
                advices.append(pattern.advice)
            }
        }
        
        // 3. Scan for Procedure Inconsistencies
        for proc in procedures {
            let matchesInstitution = containsInstitutionRef(text: text, institutionName: proc.institution)
            let matchesForbiddenAction = containsForbiddenActionKeywords(text: text, forbiddenAction: proc.forbiddenAction)
            
            if matchesInstitution && matchesForbiddenAction {
                calculatedRisk += 60
                contradiction = "\(proc.institution) contradiction: claimed procedure involves \(proc.forbiddenAction)."
                warningText = proc.warningText
                advices.append("Inconsistency Detected: \(proc.warningText)")
            }
        }
        
        let finalRiskScore = min(calculatedRisk, 100)
        let finalAdvice = advices.isEmpty ? "No immediate contradictions found. Keep listening." : Array(Set(advices)).joined(separator: "\n")
        
        return AnalysisResult(
            riskScore: finalRiskScore,
            advice: finalAdvice,
            contradictionFound: contradiction,
            warningText: warningText,
            detectedPayments: detectedPayments
        )
    }
    
    private func containsInstitutionRef(text: String, institutionName: String) -> Bool {
        let aliases: [String]
        if institutionName.localizedCaseInsensitiveContains("Police") || institutionName.localizedCaseInsensitiveContains("警察") {
            aliases = ["Police", "警察", "警局", "公安", "反詐"]
        } else if institutionName.localizedCaseInsensitiveContains("Alipay") || institutionName.localizedCaseInsensitiveContains("支付寶") {
            aliases = ["Alipay", "支付寶", "支寶"]
        } else if institutionName.localizedCaseInsensitiveContains("HSBC") || institutionName.localizedCaseInsensitiveContains("滙豐") {
            aliases = ["HSBC", "滙豐", "匯豐", "銀行"]
        } else {
            aliases = [institutionName]
        }
        
        return aliases.contains { text.localizedCaseInsensitiveContains($0) }
    }
    
    private func containsForbiddenActionKeywords(text: String, forbiddenAction: String) -> Bool {
        let keywords: [String]
        if forbiddenAction.localizedCaseInsensitiveContains("mail") || forbiddenAction.localizedCaseInsensitiveContains("card") || forbiddenAction.localizedCaseInsensitiveContains("郵寄") {
            keywords = ["郵寄", "寄過嚟", "寄黎", "銀行卡", "提款卡", "密碼", "mail", "post", "card"]
        } else if forbiddenAction.localizedCaseInsensitiveContains("transfer") || forbiddenAction.localizedCaseInsensitiveContains("account") || forbiddenAction.localizedCaseInsensitiveContains("轉賬") {
            keywords = ["轉賬", "安全賬戶", "安全賬戶", "匯款", "過數", "轉帳", "transfer", "account", "fund"]
        } else if forbiddenAction.localizedCaseInsensitiveContains("security code") || forbiddenAction.localizedCaseInsensitiveContains("verification") || forbiddenAction.localizedCaseInsensitiveContains("驗證碼") {
            keywords = ["驗證碼", "安全編碼", "一次性密碼", "安全碼", "verification", "otp", "code"]
        } else {
            keywords = forbiddenAction.components(separatedBy: " ")
        }
        
        return keywords.contains { text.localizedCaseInsensitiveContains($0) }
    }
}
