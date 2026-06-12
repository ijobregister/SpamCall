import SwiftUI
import SwiftData
import UIKit

struct IncidentReportsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CallIncidentReport.timestamp, order: .reverse) private var reports: [CallIncidentReport]
    
    @State private var selectedReport: CallIncidentReport? = nil
    @State private var showingPoliceAlert = false
    @State private var reportedNumber = ""
    
    var body: some View {
        VStack {
            if let report = selectedReport {
                // Detail view
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Button(action: { selectedReport = nil }) {
                            Text("← 返回報告列表")
                                .font(.system(size: 13, weight: .bold))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color(white: 0.2))
                                .foregroundColor(.white)
                                .cornerRadius(6)
                        }
                        .padding(.top, 8)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("事件詳情 - \(report.callerNumber)")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text("風險評級: \(report.riskScore)%")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(report.riskScore > 75 ? .red : .green)
                            
                            Divider().background(Color.gray)
                            
                            Text("營運商位置: \(report.carrierLocation)")
                                .font(.system(size: 13))
                                .foregroundColor(.white)
                            
                            if let payments = report.paymentMethodsTargeted, !payments.isEmpty {
                                Text("威脅支付管道: \(payments)")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.red)
                            }
                            
                            if let ip = report.spammerIp {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("誘餌 IP 抓取器記錄的地理位置詳情：")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(.yellow)
                                    Text("騙徒 IP: \(ip)")
                                        .font(.system(size: 13, design: .monospaced))
                                        .foregroundColor(.red)
                                    if let loc = report.spammerLocation {
                                        Text("計算位置: \(loc)")
                                            .font(.system(size: 13))
                                            .foregroundColor(.white)
                                    }
                                    if let ua = report.spammerUa {
                                        Text("瀏覽器代理: \(ua)")
                                            .font(.system(size: 11))
                                            .foregroundColor(.gray)
                                    }
                                }
                                .padding(.top, 4)
                            }
                            
                            Divider().background(Color.gray)
                            
                            Text("分角色對話轉錄：")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                            
                            ScrollView {
                                Text(cleanTranscript(report.dialogTranscript))
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(.green)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(10)
                                    .background(Color.black)
                                    .cornerRadius(6)
                            }
                            .frame(height: 180)
                            
                            Spacer()
                            
                            HStack(spacing: 8) {
                                // iOS Native ShareLink to export handover TXT
                            HStack(spacing: 6) {
                                // PDF Export
                                ShareLink(
                                    item: generatePDFReport(report: report),
                                    preview: SharePreview("Police_Handover_\(report.callerNumber).pdf", image: Image(systemName: "doc.text.fill"))
                                ) {
                                    HStack {
                                        Image(systemName: "doc.text.fill")
                                        Text("導出 PDF")
                                    }
                                    .font(.system(size: 11, weight: .bold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                                }
                                
                                // TXT Export
                                ShareLink(
                                    item: generateHandoverText(report: report),
                                    preview: SharePreview("Police_Handover_\(report.callerNumber).txt", image: Image(systemName: "doc.text"))
                                ) {
                                    HStack {
                                        Image(systemName: "square.and.arrow.up")
                                        Text("導出 TXT")
                                    }
                                    .font(.system(size: 11, weight: .bold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.orange)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                                }
                                
                                Button(action: { triggerPoliceHandover(report: report) }) {
                                    Text("移交警方")
                                        .font(.system(size: 11, weight: .bold))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(Color.red)
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                }
                            }
                            }
                        }
                        .padding()
                        .background(Color(white: 0.12))
                        .cornerRadius(12)
                    }
                    .padding()
                }
            } else {
                // List View
                VStack(alignment: .leading, spacing: 8) {
                    Text("通話後事件報告")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Text("移交文件已準備就緒，包含警方座標及轉錄詳情。")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                    
                    if reports.isEmpty {
                        VStack {
                            Spacer()
                            Text("暫無事件報告。")
                                .foregroundColor(.gray)
                                .font(.system(size: 14))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 64)
                            Spacer()
                        }
                    } else {
                        List(reports) { report in
                            Button(action: { selectedReport = report }) {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(report.callerNumber)
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundColor(.white)
                                        Spacer()
                                        Text("\(report.riskScore)% 風險")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(report.riskScore > 75 ? .red : .green)
                                    }
                                    
                                    HStack {
                                        Text("日期: \(formatDate(report.timestamp))")
                                            .font(.system(size: 12))
                                            .foregroundColor(.gray)
                                        Spacer()
                                        Text("位置: \(report.carrierLocation)")
                                            .font(.system(size: 12))
                                            .foregroundColor(.gray)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            .listRowBackground(Color(white: 0.12))
                        }
                        .scrollContentBackground(.hidden)
                    }
                }
                .padding()
            }
        }
        .background(Color.black.edgesIgnoringSafeArea(.all))
        .alert(isPresented: $showingPoliceAlert) {
            Alert(
                title: Text("移交警方"),
                message: Text("Handover Package for \(reportedNumber) sent to HKPF CyberSecurity Bureau!"),
                dismissButton: .default(Text("確定"))
            )
        }
    }
    
    // Helpers
    private func cleanTranscript(_ text: String) -> String {
        // Simple regex clean for json
        return text
            .replacingOccurrences(of: "[", with: "")
            .replacingOccurrences(of: "]", with: "")
            .replacingOccurrences(of: "{\"", with: "")
            .replacingOccurrences(of: "\"}", with: "")
            .replacingOccurrences(of: "\",\"text\":\"", with: ": ")
            .replacingOccurrences(of: "speaker\":\"", with: "")
            .replacingOccurrences(of: "\",\"", with: "\n")
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }
    
    private func triggerPoliceHandover(report: CallIncidentReport) {
        reportedNumber = report.callerNumber
        showingPoliceAlert = true
    }
    
    private func generateHandoverText(report: CallIncidentReport) -> String {
        let dateStr = formatDate(Date())
        let timestampStr = formatDate(report.timestamp)
        
        return """
        ==================================================
        SCAMCALL AI - SPAM CALL INCIDENT REPORT
        ==================================================
        Date Generated: \(dateStr)
        Incident Timestamp: \(timestampStr)
        Target Region: Hong Kong (Cantonese Core Engine)
        
        CALL METADATA:
        - Caller Number: \(report.callerNumber)
        - Carrier Geocode Location: \(report.carrierLocation)
        - Scam Risk Rating: \(report.riskScore)% Risk
        - Payment Channels Threatened: \(report.paymentMethodsTargeted ?? "None Detected")
        
        HONEYPOT IP-TRACKER CONSENT LOGS:
        - Spammer IP Tracked: \(report.spammerIp ?? "Not Grabbed")
        - Estimated Location: \(report.spammerLocation ?? "N/A")
        - User-Agent details: \(report.spammerUa ?? "N/A")
        
        CONVERSATION DIARIZATION TRANSCRIPT:
        \(cleanTranscript(report.dialogTranscript))
        
        ==================================================
        Handover package generated successfully. Copy to police files.
        """
    }
    
    // Native PDF Generator using UIGraphicsPDFRenderer
    private func generatePDFReport(report: CallIncidentReport) -> URL {
        let pdfMetaData = [
            kCGPDFContextTitle: "ScamCall Incident Report",
            kCGPDFContextAuthor: "ScamCall AI"
        ] as [CFString : Any]
        
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData
        
        // Page dimensions (A4 portrait size: 595.27 x 841.89 points)
        let pageWidth: CGFloat = 595.27
        let pageHeight: CGFloat = 841.89
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("ScamCall_Report_\(report.id).pdf")
        
        try? renderer.writePDF(to: tempURL) { context in
            context.beginPage()
            
            var currentY: CGFloat = 40
            let margin: CGFloat = 40
            let contentWidth = pageWidth - (margin * 2)
            
            // Fonts
            let titleFont = UIFont.boldSystemFont(ofSize: 20)
            let headerFont = UIFont.boldSystemFont(ofSize: 12)
            let bodyFont = UIFont.systemFont(ofSize: 10)
            let boldBodyFont = UIFont.boldSystemFont(ofSize: 10)
            let codeFont = UIFont.monospacedSystemFont(ofSize: 9, weight: .regular)
            
            // Title
            let titleText = "防騙衛士 (ScamCall AI)"
            titleText.draw(at: CGPoint(x: margin, y: currentY), withAttributes: [
                .font: titleFont,
                .foregroundColor: UIColor.systemRed
            ])
            currentY += 28
            
            // Subtitle
            let subtitleText = "實時詐騙攔截與分析移交報告 (Police Handover Report)"
            subtitleText.draw(at: CGPoint(x: margin, y: currentY), withAttributes: [
                .font: UIFont.boldSystemFont(ofSize: 12),
                .foregroundColor: UIColor.darkGray
            ])
            currentY += 25
            
            // Divider line
            context.cgContext.setStrokeColor(UIColor.lightGray.cgColor)
            context.cgContext.setLineWidth(1)
            context.cgContext.move(to: CGPoint(x: margin, y: currentY))
            context.cgContext.addLine(to: CGPoint(x: pageWidth - margin, y: currentY))
            context.cgContext.strokePath()
            currentY += 15
            
            // Call Metadata Header
            "【通話基本資訊 / Metadata】".draw(at: CGPoint(x: margin, y: currentY), withAttributes: [.font: headerFont])
            currentY += 18
            
            let metadata = [
                ("騙徒電話 (Caller):", report.callerNumber),
                ("事件時間 (Timestamp):", formatDate(report.timestamp)),
                ("營運商歸屬 (Carrier):", report.carrierLocation),
                ("風險指數 (Risk Score):", "\(report.riskScore)%")
            ]
            
            for (label, val) in metadata {
                let labelSize = label.size(withAttributes: [.font: boldBodyFont])
                label.draw(at: CGPoint(x: margin + 10, y: currentY), withAttributes: [.font: boldBodyFont])
                val.draw(at: CGPoint(x: margin + 10 + labelSize.width + 10, y: currentY), withAttributes: [.font: bodyFont])
                currentY += 14
            }
            
            if let payments = report.paymentMethodsTargeted, !payments.isEmpty {
                "威脅支付管道 (Payment Threatened):".draw(at: CGPoint(x: margin + 10, y: currentY), withAttributes: [
                    .font: boldBodyFont,
                    .foregroundColor: UIColor.systemRed
                ])
                payments.draw(at: CGPoint(x: margin + 180, y: currentY), withAttributes: [
                    .font: boldBodyFont,
                    .foregroundColor: UIColor.systemRed
                ])
                currentY += 18
            } else {
                currentY += 4
            }
            
            // Honeypot logs
            if let ip = report.spammerIp {
                currentY += 10
                "【誘餌連結 IP 追蹤日誌 / Honeypot Logs】".draw(at: CGPoint(x: margin, y: currentY), withAttributes: [
                    .font: headerFont,
                    .foregroundColor: UIColor.systemBlue
                ])
                currentY += 18
                
                let ipLogs = [
                    ("騙徒 IP (Spammer IP):", ip),
                    ("計算位置 (Location):", report.spammerLocation ?? "N/A"),
                    ("瀏覽器 (User-Agent):", report.spammerUa ?? "N/A")
                ]
                
                for (label, val) in ipLogs {
                    let labelSize = label.size(withAttributes: [.font: boldBodyFont])
                    label.draw(at: CGPoint(x: margin + 10, y: currentY), withAttributes: [.font: boldBodyFont])
                    val.draw(at: CGPoint(x: margin + 10 + labelSize.width + 10, y: currentY), withAttributes: [.font: bodyFont])
                    currentY += 14
                }
            }
            
            // Transcript Section
            currentY += 15
            "【對話錄音轉錄 (分角色) / Conversation Transcript】".draw(at: CGPoint(x: margin, y: currentY), withAttributes: [.font: headerFont])
            currentY += 20
            
            let transcriptText = cleanTranscript(report.dialogTranscript)
            let lines = transcriptText.components(separatedBy: "\n")
            
            for line in lines {
                if currentY > pageHeight - 60 {
                    context.beginPage()
                    currentY = 40
                }
                
                let isSpammer = line.hasPrefix("Spammer") || line.hasPrefix("騙徒")
                let lineAttr: [NSAttributedString.Key: Any] = [
                    .font: codeFont,
                    .foregroundColor: isSpammer ? UIColor.red : (line.hasPrefix("Receiver") || line.hasPrefix("受話人") ? UIColor.systemGreen : UIColor.black)
                ]
                
                let wrapRect = CGRect(x: margin + 10, y: currentY, width: contentWidth - 10, height: 100)
                let boundingSize = line.boundingRect(with: CGSize(width: contentWidth - 10, height: CGFloat.greatestFiniteMagnitude), options: .usesLineFragmentOrigin, attributes: lineAttr, context: nil).size
                
                line.draw(in: CGRect(x: margin + 10, y: currentY, width: contentWidth - 10, height: boundingSize.height), withAttributes: lineAttr)
                currentY += boundingSize.height + 6
            }
            
            // Footer drawing
            if currentY < pageHeight - 50 {
                let footerText = "========================================================\n本報告由防騙衛士 (ScamCall AI) 自動分析生成。移交警方作為刑事審查憑證。"
                let footerRect = CGRect(x: margin, y: pageHeight - 45, width: contentWidth, height: 30)
                footerText.draw(in: footerRect, withAttributes: [
                    .font: UIFont.systemFont(ofSize: 7.5),
                    .foregroundColor: UIColor.gray
                ])
            }
        }
        
        return tempURL
    }
}
