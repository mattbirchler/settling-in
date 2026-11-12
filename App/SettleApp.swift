import SwiftUI
import SettleCore

@main
struct SettleApp: App {
    @State private var model = Model()

    var body: some Scene {
        MenuBarExtra {
            PanelView(model: model)
        } label: {
            MenuBarLabel(model: model)
                .task { model.start() }
        }
        .menuBarExtraStyle(.window)

        // Opens the panel as a normal window, used to check the layout: "Settling In" --preview-window
        Window("Settling In Preview", id: "preview") {
            PanelView(model: model)
                .task {
                    model.start()
                    // Come to the front so controls draw in their active colors.
                    NSApplication.shared.activate()
                }
        }
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(CommandLine.arguments.contains("--preview-window") ? .presented : .suppressed)
    }
}

struct MenuBarLabel: View {
    let model: Model

    var body: some View {
        let settling = model.verdict.isSettling
        if settling, let photos = model.photos, photos.remaining > 0 {
            Label(Format.percent(photos.fraction), systemImage: "hourglass")
                .labelStyle(.titleAndIcon)
        } else {
            Image(systemName: settling ? "hourglass" : "checkmark.circle")
        }
    }
}
