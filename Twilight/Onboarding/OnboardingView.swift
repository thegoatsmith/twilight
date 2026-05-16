import SwiftUI
import CoreLocation
import AppKit

@MainActor
final class OnboardingPermissionDriver: NSObject, ObservableObject, CLLocationManagerDelegate {

    @Published var locationStatus: CLAuthorizationStatus
    @Published var automationChecked: Bool = false
    @Published var automationGranted: Bool = false

    private let manager = CLLocationManager()

    override init() {
        self.locationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
    }

    func requestLocation() {
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        } else if manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted {
            openLocationSettings()
        }
    }

    func requestAutomation() {
        // A read-only AppleScript provokes the System Events TCC prompt without
        // changing the user's appearance. We mirror the error-code check in
        // AppleScriptThemeApplier.
        let src = #"tell application "System Events" to get name"#
        guard let script = NSAppleScript(source: src) else {
            automationChecked = true
            automationGranted = false
            return
        }
        var errorDict: NSDictionary?
        script.executeAndReturnError(&errorDict)
        automationChecked = true
        if let err = errorDict {
            let n = (err[NSAppleScript.errorNumber] as? Int) ?? 0
            automationGranted = !(n == -1743 || n == -600 || n == -609)
            if !automationGranted { openAutomationSettings() }
        } else {
            automationGranted = true
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in self.locationStatus = status }
    }

    private func openLocationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices") {
            NSWorkspace.shared.open(url)
        }
    }

    private func openAutomationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
            NSWorkspace.shared.open(url)
        }
    }
}

struct OnboardingView: View {

    let onFinish: () -> Void

    @StateObject private var driver = OnboardingPermissionDriver()
    @State private var step: Int = 0

    private let totalSteps = 3

    var body: some View {
        VStack(spacing: 0) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 32)
                .padding(.top, 32)
            footer
        }
        .frame(width: 460, height: 460)
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case 0: welcomePane
        case 1: permissionsPane
        default: donePane
        }
    }

    private var welcomePane: some View {
        VStack(spacing: 18) {
            HStack(spacing: 16) {
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.orange)
                Image(systemName: "arrow.right")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.indigo)
            }
            .padding(.top, 8)

            Text("Welcome to Twilight")
                .font(.title)
                .fontWeight(.semibold)

            VStack(spacing: 8) {
                Text("Twilight switches macOS between Light and Dark mode automatically at sunrise and sunset.")
                Text("Look for the sun (or moon) icon in your menu bar — top-right of the screen.")
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
    }

    private var permissionsPane: some View {
        VStack(spacing: 16) {
            Text("Two permissions to grant")
                .font(.title2)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .center)

            permissionRow(
                icon: "location.fill",
                title: "Location",
                description: "Used to calculate your local sunrise and sunset.",
                granted: locationGranted,
                denied: locationDenied,
                action: { driver.requestLocation() }
            )

            permissionRow(
                icon: "lock.shield.fill",
                title: "Automation",
                description: "Used to toggle Light and Dark mode via System Events.",
                granted: driver.automationChecked && driver.automationGranted,
                denied: driver.automationChecked && !driver.automationGranted,
                action: { driver.requestAutomation() }
            )

            Text("You can change these later in System Settings.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 4)

            Spacer(minLength: 0)
        }
    }

    private var donePane: some View {
        VStack(spacing: 18) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.green)
                .padding(.top, 4)

            Text("You're all set")
                .font(.title)
                .fontWeight(.semibold)

            VStack(spacing: 8) {
                Text("Twilight is now running in your menu bar.")
                Text("Click the sun (or moon) icon any time to switch manually or open Preferences.")
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func permissionRow(
        icon: String,
        title: String,
        description: String,
        granted: Bool,
        denied: Bool,
        action: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 24, alignment: .center)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).fontWeight(.semibold)
                Text(description)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            statusControl(granted: granted, denied: denied, action: action)
        }
        .padding(12)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private func statusControl(granted: Bool, denied: Bool, action: @escaping () -> Void) -> some View {
        if granted {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(.green)
                .help("Granted")
        } else if denied {
            Button("Open Settings", action: action)
                .buttonStyle(.bordered)
                .controlSize(.small)
        } else {
            Button("Allow", action: action)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
    }

    private var footer: some View {
        HStack {
            Button("Skip") { step = totalSteps - 1 }
                .buttonStyle(.link)
                .opacity(step == 1 ? 1 : 0)
                .disabled(step != 1)

            Spacer()
            HStack(spacing: 6) {
                ForEach(0..<totalSteps, id: \.self) { i in
                    Circle()
                        .fill(i == step ? Color.primary : Color.secondary.opacity(0.3))
                        .frame(width: 6, height: 6)
                }
            }
            Spacer()

            Button(primaryActionLabel) {
                if step == totalSteps - 1 {
                    onFinish()
                } else {
                    step += 1
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(.thinMaterial)
    }

    private var primaryActionLabel: String {
        step == totalSteps - 1 ? "Get Started" : "Continue"
    }

    private var locationGranted: Bool {
        switch driver.locationStatus {
        case .authorizedAlways, .authorizedWhenInUse: return true
        default: return false
        }
    }

    private var locationDenied: Bool {
        switch driver.locationStatus {
        case .denied, .restricted: return true
        default: return false
        }
    }
}
