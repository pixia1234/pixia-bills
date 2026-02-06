import SwiftUI

@main
struct PixiaBillsApp: App {
    @StateObject private var store = BillsStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
        }
    }
}

