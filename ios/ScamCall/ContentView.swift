import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    
    init() {
        // Configure standard tab bar appearance for iOS
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(white: 0.1, alpha: 1.0)
        
        // Colors for active/inactive items
        appearance.stackedLayoutAppearance.selected.iconColor = .red
        appearance.stackedLayoutAppearance.selected.textColor = .white
        appearance.stackedLayoutAppearance.normal.iconColor = .gray
        appearance.stackedLayoutAppearance.normal.textColor = .gray
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
    
    var body: some View {
        NavigationStack {
            TabView(selection: $selectedTab) {
                LiveMonitorView()
                    .tabItem {
                        Image(systemName: "phone.fill")
                        Text("實時監控")
                    }
                    .tag(0)
                
                KnowledgeBaseView()
                    .tabItem {
                        Image(systemName: "square.and.pencil")
                        Text("知識庫")
                    }
                    .tag(1)
                
                IncidentReportsView()
                    .tabItem {
                        Image(systemName: "list.bullet")
                        Text("事件報告")
                    }
                    .tag(2)
                
                SettingsView()
                    .tabItem {
                        Image(systemName: "gearshape.fill")
                        Text("設置")
                    }
                    .tag(3)
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack {
                        Image(systemName: "shield.fill")
                            .foregroundColor(.red)
                            .font(.system(size: 20))
                        
                        VStack(alignment: .leading, spacing: 1) {
                            Text("防騙衛士 (ScamCall AI)")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.white)
                            Text("實時詐騙攔截與懷疑引擎")
                                .font(.system(size: 9))
                                .foregroundColor(.lightGray)
                        }
                    }
                }
            }
            .toolbarBackground(Color(white: 0.1), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
    
    private var navigationTitle: String {
        switch selectedTab {
        case 0: return "實時監控"
        case 1: return "知識庫"
        case 2: return "事件報告"
        default: return "系統設置"
        }
    }
}

#Preview {
    ContentView()
}
