import SwiftUI

@main
struct TwilightApp: App {
    var body: some Scene {
        MenuBarExtra("Twilight", systemImage: "sun.max") {
            Text("Hello, Twilight")
            Button("Quit") { NSApp.terminate(nil) }
        }
        .menuBarExtraStyle(.window)
    }
}
