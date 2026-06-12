import SwiftUI

struct SettingsView: View {
    @AppStorage("voice_alert_enabled") private var voiceAlertEnabled = true
    @AppStorage("auth_contact_name") private var contactName = "Gabriel (孫子)"
    @AppStorage("auth_contact_phone") private var contactPhone = "+852 9876 5432"
    @AppStorage("region_policy") private var selectedRegion = "HK"
    
    // Payment Protection Channels
    @AppStorage("protect_bank_apps") private var protectBankApps = true
    @AppStorage("protect_internet_banking") private var protectInternetBanking = true
    @AppStorage("protect_visa") private var protectVisa = true
    @AppStorage("protect_fps") private var protectFps = true
    @AppStorage("protect_octopus") private var protectOctopus = true
    @AppStorage("protect_alipay") private var protectAlipay = true
    @AppStorage("protect_wechat_pay") private var protectWeChatPay = true
    @AppStorage("protect_7_eleven") private var protect7Eleven = true
    @AppStorage("protect_circle_k") private var protectCircleK = true
    
    // Translation Language
    @AppStorage("speech_language_code") private var speechLanguageCode = "zh-HK"
    
    @State private var showingRegionToast = false
    @State private var toastRegion = ""
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("系統設置")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                // 1. Voice Alerts Toggle
                VStack(alignment: .leading, spacing: 8) {
                    Toggle(isOn: $voiceAlertEnabled) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("語音警報 (無障礙功能)")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.white)
                            Text("在通話過程中為視障用戶朗讀警告文字。")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }
                    }
                    .tint(.red)
                }
                .padding()
                .background(Color(white: 0.12))
                .cornerRadius(10)
                
                Divider().background(Color.gray)
                
                // 2. Speech & Translation Language Selector
                VStack(alignment: .leading, spacing: 12) {
                    Text("語音偵測及翻譯語言")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                    Text("選擇通話實時聽取及翻譯的目標語言（支援廣東話、普通話及英文）。")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                    
                    HStack(spacing: 8) {
                        let langs = [
                            ("zh-HK", "廣東話 (HK)"),
                            ("zh-CN", "普通話 (CN)"),
                            ("en-US", "英語 (US)")
                        ]
                        ForEach(langs, id: \.0) { lang in
                            let isSelected = speechLanguageCode == lang.0
                            Button(action: {
                                speechLanguageCode = lang.0
                            }) {
                                Text(lang.1)
                                    .font(.system(size: 11, weight: .bold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(isSelected ? Color.red : Color(white: 0.2))
                                    .foregroundColor(.white)
                                    .cornerRadius(6)
                            }
                        }
                    }
                }
                .padding()
                .background(Color(white: 0.12))
                .cornerRadius(10)
                
                Divider().background(Color.gray)
                
                // 3. Protected Payment Channels
                VStack(alignment: .leading, spacing: 12) {
                    Text("受防護支付管道 (Payment Protection)")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                    Text("選取在通話過程中需要被監控並標記為高危的支付途徑。")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                    
                    let payments = [
                        ("Bank Apps", "銀行App", $protectBankApps),
                        ("Internet Banking", "網上銀行", $protectInternetBanking),
                        ("Visa", "Visa卡", $protectVisa),
                        ("FPS", "轉數快", $protectFps),
                        ("Octopus", "八達通", $protectOctopus),
                        ("Alipay", "支付寶", $protectAlipay),
                        ("WeChat Pay", "微信支付", $protectWeChatPay),
                        ("7-Eleven", "7-11", $protect7Eleven),
                        ("Circle K", "Circle K", $protectCircleK)
                    ]
                    
                    VStack(spacing: 8) {
                        ForEach(0..<3) { row in
                            HStack(spacing: 6) {
                                ForEach(0..<3) { col in
                                    let idx = row * 3 + col
                                    if idx < payments.count {
                                        let item = payments[idx]
                                        Button(action: {
                                            item.2.wrappedValue.toggle()
                                        }) {
                                            Text(item.1)
                                                .font(.system(size: 11, weight: .semibold))
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 8)
                                                .background(item.2.wrappedValue ? Color.red : Color(white: 0.2))
                                                .foregroundColor(.white)
                                                .cornerRadius(6)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
                .background(Color(white: 0.12))
                .cornerRadius(10)
                
                Divider().background(Color.gray)
                
                // 4. Trusted Contact Config
                VStack(alignment: .leading, spacing: 12) {
                    Text("受信任第三方授權聯絡人")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                    Text("授權遠程釋放被攔截的短訊/通話釣魚連結的聯絡人。")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                    
                    VStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("聯絡人姓名")
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                            TextField("聯絡人姓名", text: $contactName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .colorScheme(.dark)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("電話號碼")
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                            TextField("電話號碼", text: $contactPhone)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .colorScheme(.dark)
                        }
                    }
                }
                .padding()
                .background(Color(white: 0.12))
                .cornerRadius(10)
                
                Divider().background(Color.gray)
                
                // 5. Region Selector
                VStack(alignment: .leading, spacing: 12) {
                    Text("區域目標規則政策")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                    Text("當前區域決定了程序驗證數據庫的檢查規則。")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                    
                    HStack(spacing: 8) {
                        ForEach(["HK", "SG", "UK"], id: \.self) { region in
                            let isSelected = selectedRegion == region
                            Button(action: {
                                selectedRegion = region
                                toastRegion = region
                                withAnimation {
                                    showingRegionToast = true
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                    showingRegionToast = false
                                }
                            }) {
                                Text(region)
                                    .font(.system(size: 13, weight: .bold))
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 10)
                                    .background(isSelected ? Color.red : Color(white: 0.2))
                                    .foregroundColor(.white)
                                    .cornerRadius(6)
                            }
                        }
                    }
                }
                .padding()
                .background(Color(white: 0.12))
                .cornerRadius(10)
            }
            .padding()
        }
        .background(Color.black.edgesIgnoringSafeArea(.all))
        .overlay(
            Group {
                if showingRegionToast {
                    VStack {
                        Spacer()
                        Text("規則數據庫已切換至 \(toastRegion) 政策！")
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
}
