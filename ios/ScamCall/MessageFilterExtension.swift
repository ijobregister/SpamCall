import Foundation
import IdentityLookup

class MessageFilterExtension: ILMessageFilterProvider {

    override func handle(_ queryRequest: ILMessageFilterQueryRequest, context: ILMessageFilterExtensionContext, completion: @escaping (ILMessageFilterQueryResponse) -> Void) {
        let response = ILMessageFilterQueryResponse()
        
        // Retrieve incoming SMS message properties
        let sender = queryRequest.sender ?? ""
        let messageBody = queryRequest.messageBody ?? ""
        
        // Call blocking analysis
        let action = evaluateSmsMessage(sender: sender, body: messageBody)
        
        response.action = action
        completion(response)
    }
    
    private func evaluateSmsMessage(sender: String, body: String) -> ILMessageFilterAction {
        // 1. Check if sender matches blacklisted numbers
        // (Shared App Group settings/defaults can be read here on iOS)
        if sender.contains("91234567") || sender.contains("61249901") {
            return .filter // Categorizes SMS as Junk
        }
        
        // 2. Perform spam word detection or URL detection
        // e.g. HSBC scams, safety accounts, link intercepts
        let scamKeywords = ["安全賬戶", "資產審查", "驗證碼", "取消扣費", "郵寄銀行卡"]
        for kw in scamKeywords {
            if body.contains(kw) {
                return .filter
            }
        }
        
        // Check for suspicious URLs
        if containsLink(body) && (body.localizedCaseInsensitiveContains("verify") || body.localizedCaseInsensitiveContains("hsbc") || body.localizedCaseInsensitiveContains("alipay")) {
            return .filter
        }
        
        return .none // Let system handle default routing (Inbox)
    }
    
    private func containsLink(_ text: String) -> Bool {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let matches = detector?.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
        return !(matches?.isEmpty ?? true)
    }
}
