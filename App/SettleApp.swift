import SwiftUI
import SettleCore

@main
struct SettleApp: App {
    var body: some Scene {
        MenuBarExtra("Settle", systemImage: "hourglass") {
            Text("Settle")
                .padding()
        }
        .menuBarExtraStyle(.window)
    }
}
