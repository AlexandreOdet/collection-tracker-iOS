import SwiftUI
import SwiftData

@main
struct collection_trackerApp: App {
    private let container: ModelContainer
    @State private var syncService: SyncService

    init() {
        do {
            container = try ModelContainer(for: CollectionItem.self)
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
        _syncService = State(initialValue: SyncService(context: container.mainContext))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(syncService)
        }
        .modelContainer(container)
    }
}
