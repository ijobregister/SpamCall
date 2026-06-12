import Foundation
import CallKit

class CallDirectoryHandler: CXCallDirectoryProvider {

    override func beginRequest(with context: CXCallDirectoryExtensionContext) {
        context.delegate = self

        // 1. Add blocked phone numbers (must be sorted in ascending order)
        // e.g. +85261249901, +85291234567
        addAllBlockingPhoneNumbers(to: context)

        // 2. Add identification phone numbers (must be sorted in ascending order)
        addAllIdentificationPhoneNumbers(to: context)

        context.completeRequest()
    }

    private func addAllBlockingPhoneNumbers(to context: CXCallDirectoryExtensionContext) {
        // Retrieve blacklisted numbers from Shared App Group database or file
        // Phone numbers must be represented as CXCallDirectoryPhoneNumber (Int64)
        // and must be in ascending numerical order, including country code (no leading '+' or '00')
        
        let blockedNumbers: [CXCallDirectoryPhoneNumber] = [
            85256781234,
            85261249901,
            85291234567
        ]
        
        for number in blockedNumbers {
            context.addBlockingEntry(withNextSequentialPhoneNumber: number)
        }
    }

    private func addAllIdentificationPhoneNumbers(to context: CXCallDirectoryExtensionContext) {
        // Identify custom names for callers (e.g. "Suspected Scam Call")
        // Numbers must be sorted in ascending order.
        let identificationNumbers: [CXCallDirectoryPhoneNumber] = [
            85256781234,
            85261249901,
            85291234567
        ]
        
        let labels = [
            "Fake HK Police (ScamCall)",
            "Reported Alipay Impersonator (ScamCall)",
            "Phishing SMS Sender (ScamCall)"
        ]

        for (number, label) in zip(identificationNumbers, labels) {
            context.addIdentificationEntry(withNextSequentialPhoneNumber: number, label: label)
        }
    }
}

extension CallDirectoryHandler: CXCallDirectoryExtensionContextDelegate {

    func requestFailed(for extensionContext: CXCallDirectoryExtensionContext, withError error: Error) {
        // Log error when Call Directory Extension fails
        print("CallDirectoryHandler request failed: \(error.localizedDescription)")
    }
}
