import SwiftUI
import MapKit
import CoreLocation

struct SettingsView: View {

    @ObservedObject var controller: AppearanceController
    let locationProvider: LocationProvider
    let loginItems: LoginItemManager

    @StateObject private var cities = CityResolver()
    @AppStorage(PreferencesKey.useAutoLocation) private var useAutoLocation: Bool = true
    @AppStorage(PreferencesKey.launchAtLogin) private var launchAtLogin: Bool = true
    @State private var locationAuthStatus: CLAuthorizationStatus = .notDetermined

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("General", systemImage: "gear") }
        }
        .frame(width: 520, height: 380)
        .onAppear { locationAuthStatus = locationProvider.authorizationStatus }
    }

    private var generalTab: some View {
        Form {
            Section("Location") {
                Picker("Source", selection: $useAutoLocation) {
                    Text("Use my location").tag(true)
                    Text("Manual").tag(false)
                }
                .pickerStyle(.radioGroup)
                .onChange(of: useAutoLocation) { newValue in
                    if newValue {
                        locationProvider.setAutoMode()
                    }
                }

                if !useAutoLocation {
                    TextField("Search city", text: $cities.query)
                        .textFieldStyle(.roundedBorder)
                    if !cities.suggestions.isEmpty {
                        List(cities.suggestions, id: \.title) { suggestion in
                            Button {
                                Task {
                                    if let loc = await cities.resolve(suggestion) {
                                        locationProvider.setManualLocation(loc)
                                        cities.query = loc.displayName ?? ""
                                    }
                                }
                            } label: {
                                VStack(alignment: .leading) {
                                    Text(suggestion.title)
                                    Text(suggestion.subtitle).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        .frame(height: 120)
                    }
                }

                if let loc = controller.location {
                    Text("Using: \(loc.displayName ?? String(format: "%.3f, %.3f", loc.latitude, loc.longitude))")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            Section("Launch") {
                Toggle("Launch Twilight at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { newValue in
                        loginItems.setEnabled(newValue)
                    }
            }

            Section("Permissions") {
                LabeledContent("Location") {
                    permissionRow(text: locationAuthLabel,
                                  granted: locationAuthStatus == .authorizedAlways || locationAuthStatus == .authorized)
                }
                LabeledContent("Automation (System Events)") {
                    permissionRow(text: controller.hasAutomationPermission ? "Granted" : "Required",
                                  granted: controller.hasAutomationPermission) {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }
            }

            Section("About") {
                Text("Twilight v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0")")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(20)
    }

    @ViewBuilder
    private func permissionRow(text: String, granted: Bool, action: (() -> Void)? = nil) -> some View {
        HStack(spacing: 8) {
            Image(systemName: granted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(granted ? .green : .yellow)
            Text(text)
            if !granted, let action {
                Button("Open Settings", action: action).buttonStyle(.link)
            }
        }
    }

    private var locationAuthLabel: String {
        switch locationAuthStatus {
        case .authorizedAlways, .authorized: return "Granted"
        case .denied, .restricted: return "Denied"
        case .notDetermined: return "Not requested"
        @unknown default: return "Unknown"
        }
    }
}
