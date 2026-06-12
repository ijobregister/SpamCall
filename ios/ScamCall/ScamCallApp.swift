import SwiftUI
import SwiftData

@main
struct ScamCallApp: App {
    let container: ModelContainer
    
    init() {
        do {
            container = try ModelContainer(for: ScamNumber.self, OfficialProcedure.self, ScamPattern.self, CallIncidentReport.self)
            
            // Database prepopulation on main thread
            Task { @MainActor in
                AppDatabaseInitializer.prepopulate(modelContext: container.mainContext)
            }
        } catch {
            fatalError("Could not initialize ModelContainer: \(error.localizedDescription)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
