import SwiftUI

struct MenuBarView: View {
    @ObservedObject var controller: AppearanceController

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            if !controller.hasAutomationPermission {
                automationWarning
            }
            Divider()
            actionButtons
            Divider()
            HStack {
                Button("Preferences…") { Self.openSettings() }
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
            }
        }
        .padding(12)
        .frame(width: 260)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(headerTitle).font(.headline)
            if let subline = subline {
                Text(subline).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var headerTitle: String {
        switch controller.mode {
        case .auto:         return "Auto Mode"
        case .manualLight:  return "Manual: Light"
        case .manualDark:   return "Manual: Dark"
        }
    }

    private var subline: String? {
        guard let next = controller.nextEventAt else {
            if controller.location == nil { return "Waiting for location…" }
            return nil
        }
        let df = DateFormatter()
        df.dateStyle = .none; df.timeStyle = .short
        let kind: String
        switch controller.mode {
        case .auto:
            kind = (next == controller.todaySun?.sunset) ? "Switches to Dark at" : "Switches to Light at"
        case .manualLight, .manualDark:
            kind = "Resumes Auto at"
        }
        return "\(kind) \(df.string(from: next))"
    }

    private var actionButtons: some View {
        VStack(spacing: 6) {
            Button {
                controller.switchToLight()
            } label: {
                Label("Switch to Light", systemImage: "sun.max")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .disabled(controller.mode == .manualLight)

            Button {
                controller.switchToDark()
            } label: {
                Label("Switch to Dark", systemImage: "moon.stars")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .disabled(controller.mode == .manualDark)

            Button {
                controller.resumeAuto()
            } label: {
                Label("Resume Auto", systemImage: "arrow.triangle.2.circlepath")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .disabled(controller.mode == .auto)
        }
        .buttonStyle(.borderless)
    }

    static func openSettings() {
        if #available(macOS 14, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    private var automationWarning: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("⚠️ Automation permission required").font(.caption).bold()
            Button("Open System Settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.link)
            .font(.caption)
        }
        .padding(8)
        .background(Color.yellow.opacity(0.15))
        .cornerRadius(6)
    }
}
