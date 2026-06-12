import SwiftUI
import SwiftData

struct KnowledgeBaseView: View {
    @Environment(\.modelContext) private var modelContext
    
    // Queries
    @Query(sort: \OfficialProcedure.institution) private var procedures: [OfficialProcedure]
    @Query(sort: \ScamPattern.source) private var patterns: [ScamPattern]
    @Query(sort: \ScamNumber.phoneNumber) private var blacklist: [ScamNumber]
    
    // Form Inputs
    @State private var newInst = ""
    @State private var newRule = ""
    @State private var newWarn = ""
    
    @State private var newSource = ""
    @State private var newKeywords = ""
    @State private var newAdvice = ""
    
    @State private var newBlackNum = ""
    @State private var newBlackTag = ""
    
    var body: some View {
        List {
            // 1. Official Procedures Section
            Section(header: Text("官方流程庫 (用戶可編輯)").foregroundColor(.white).font(.headline).padding(.vertical, 4)) {
                ForEach(procedures) { proc in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(proc.institution)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                            Spacer()
                            Button(action: { deleteProcedure(proc) }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.gray)
                            }
                            .buttonStyle(BorderlessButtonStyle())
                        }
                        Text("禁止事項: \(proc.forbiddenAction)")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                        Text("警告內容: \(proc.warningText)")
                            .font(.system(size: 11))
                            .foregroundColor(.red)
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(Color(white: 0.12))
                }
                
                // Add Form for Procedures
                VStack(alignment: .leading, spacing: 8) {
                    Text("新增官方規則")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.gray)
                    
                    TextField("機構名稱", text: $newInst)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .colorScheme(.dark)
                    TextField("禁止程序規則", text: $newRule)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .colorScheme(.dark)
                    TextField("AI 彈出警告文字", text: $newWarn)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .colorScheme(.dark)
                    
                    Button(action: saveProcedure) {
                        Text("儲存規則")
                            .font(.system(size: 12, weight: .bold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(6)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.vertical, 8)
                .listRowBackground(Color(white: 0.08))
            }
            
            // 2. News Scam Patterns Section
            Section(header: Text("新聞詐騙詞組模式").foregroundColor(.white).font(.headline).padding(.vertical, 4)) {
                ForEach(patterns) { pattern in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(pattern.source)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                            Spacer()
                            Button(action: { deletePattern(pattern) }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.gray)
                            }
                            .buttonStyle(BorderlessButtonStyle())
                        }
                        Text("關鍵字: \(pattern.keywords)")
                            .font(.system(size: 12))
                            .foregroundColor(.yellow)
                        Text("建議: \(pattern.advice)")
                            .font(.system(size: 12))
                            .foregroundColor(.lightGray)
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(Color(white: 0.12))
                }
                
                // Add Form for Patterns
                VStack(alignment: .leading, spacing: 8) {
                    Text("新增詐騙模式")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.gray)
                    
                    TextField("新聞/警方警告來源", text: $newSource)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .colorScheme(.dark)
                    TextField("關鍵字 (逗號分隔)", text: $newKeywords)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .colorScheme(.dark)
                    TextField("建議訊息", text: $newAdvice)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .colorScheme(.dark)
                    
                    Button(action: savePattern) {
                        Text("儲存模式")
                            .font(.system(size: 12, weight: .bold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(6)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.vertical, 8)
                .listRowBackground(Color(white: 0.08))
            }
            
            // 3. Blacklist Numbers Section
            Section(header: Text("黑名單號碼").foregroundColor(.white).font(.headline).padding(.vertical, 4)) {
                ForEach(blacklist) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.phoneNumber)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                            Text(item.entityName)
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        Button(action: { deleteBlackNumber(item) }) {
                            Image(systemName: "trash")
                                .foregroundColor(.gray)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(Color(white: 0.12))
                }
                
                // Add Form for Blacklist Numbers
                VStack(alignment: .leading, spacing: 8) {
                    Text("新增電話黑名單")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.gray)
                    
                    TextField("電話號碼", text: $newBlackNum)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .colorScheme(.dark)
                    TextField("舉報實體標籤", text: $newBlackTag)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .colorScheme(.dark)
                    
                    Button(action: saveBlackNumber) {
                        Text("加入黑名單")
                            .font(.system(size: 12, weight: .bold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(6)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.vertical, 8)
                .listRowBackground(Color(white: 0.08))
            }
        }
        .background(Color.black.edgesIgnoringSafeArea(.all))
        .scrollContentBackground(.hidden)
    }
    
    // CRUD Logic Helpers
    private func saveProcedure() {
        guard !newInst.isEmpty && !newRule.isEmpty else { return }
        let newProc = OfficialProcedure(institution: newInst, forbiddenAction: newRule, warningText: newWarn)
        modelContext.insert(newProc)
        try? modelContext.save()
        newInst = ""; newRule = ""; newWarn = ""
    }
    
    private func deleteProcedure(_ proc: OfficialProcedure) {
        modelContext.delete(proc)
        try? modelContext.save()
    }
    
    private func savePattern() {
        guard !newSource.isEmpty && !newKeywords.isEmpty else { return }
        let newPat = ScamPattern(source: newSource, keywords: newKeywords, advice: newAdvice)
        modelContext.insert(newPat)
        try? modelContext.save()
        newSource = ""; newKeywords = ""; newAdvice = ""
    }
    
    private func deletePattern(_ pattern: ScamPattern) {
        modelContext.delete(pattern)
        try? modelContext.save()
    }
    
    private func saveBlackNumber() {
        guard !newBlackNum.isEmpty else { return }
        let newNum = ScamNumber(phoneNumber: newBlackNum, entityName: newBlackTag)
        modelContext.insert(newNum)
        try? modelContext.save()
        newBlackNum = ""; newBlackTag = ""
    }
    
    private func deleteBlackNumber(_ item: ScamNumber) {
        modelContext.delete(item)
        try? modelContext.save()
    }
}

// Visual color additions
extension Color {
    static let lightGray = Color(white: 0.7)
}
