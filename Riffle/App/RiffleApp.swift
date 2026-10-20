import OSLog
import RiffleDesign
import RiffleStore
import SwiftData
import SwiftUI

@main
struct RiffleApp: App {
    private let container: ModelContainer

    init() {
        do {
            container = try RiffleStore.makeContainer()
        } catch {
            // Keep the app usable if the store can't open; progress just won't persist this launch.
            Logger(subsystem: "app.riffle", category: "store").error("Opening the store failed: \(error)")
            container = try! RiffleStore.makeContainer(inMemory: true)
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
                .tint(RiffleColor.lime)
        }
        .modelContainer(container)
    }
}
